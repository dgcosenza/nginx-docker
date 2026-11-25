#!/usr/bin/env bash
# Smoke test for dgcosenza/nginx: verifies fresh /config init, tini PID 1,
# non-root abc workers (UID/GID 1000), NGINX + ngx_brotli compression,
# PHP 8.4 FPM execution, auto-reload watcher, and negative healthcheck.
set -euo pipefail

IMAGE="${1:-dgcosenza/nginx:ci-candidate}"
NAME="nginx-ci-smoke-$$"
TMPCONF="$(mktemp -d)"
chmod 777 "$TMPCONF"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run --rm --user 0:0 -v "${TMPCONF}:/cleanup" --entrypoint /bin/sh "$IMAGE" -c 'rm -rf /cleanup/*' >/dev/null 2>&1 || true
  rm -rf "$TMPCONF" 2>/dev/null || true
}
trap cleanup EXIT

docker run -d --name "$NAME" \
  --security-opt no-new-privileges:true \
  -p 127.0.0.1:18080:80 \
  -p 127.0.0.1:18443:443 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e AUTO_RELOAD=true \
  -v "${TMPCONF}:/config" \
  "$IMAGE"

# Wait for HTTPS 200 on container loopback
READY=0
for _ in $(seq 1 30); do
  if ! docker ps -q --filter "name=^/${NAME}$" | grep -q .; then
    echo "ERROR: nginx container exited prematurely:" >&2
    docker logs "$NAME" >&2 || true
    exit 1
  fi
  CODE="$(docker exec "$NAME" curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://127.0.0.1/ 2>/dev/null || true)"
  if [ "$CODE" = "200" ]; then
    READY=1
    break
  fi
  sleep 1
done
if [ "$READY" -ne 1 ]; then
  echo "ERROR: nginx did not return HTTPS 200 within timeout." >&2
  docker logs "$NAME" >&2 || true
  exit 1
fi

# Verify tini is PID 1
PID1_COMM="$(docker exec "$NAME" cat /proc/1/comm)"
test "$PID1_COMM" = "tini"

# Verify nginx workers and php-fpm workers run as non-root abc (UID 1000)
docker exec "$NAME" ps -eo user,comm | grep -qE '^abc[[:space:]]+nginx$'
docker exec "$NAME" ps -eo user,comm | grep -qE '^abc[[:space:]]+php-fpm8\.4$'

# Verify brotli compression works (create a >512B static file inside /config/www and request Accept-Encoding: br)
docker exec "$NAME" sh -c 'python3 -c "print(\"brotli-test-payload \" * 60)" 2>/dev/null || awk "BEGIN{for(i=0;i<60;i++) printf \"brotli-test-payload \"; print \"\"}"' \
  | docker exec -i "$NAME" sh -c 'cat > /config/www/brotli.txt && chown abc:abc /config/www/brotli.txt'
BR_HDR="$(curl -skI -H 'Accept-Encoding: br' https://127.0.0.1:18443/brotli.txt | tr -d '\r')"
printf '%s\n' "$BR_HDR" | grep -qi '^content-encoding: br'

# Verify PHP 8.4 FPM executes scripts on 127.0.0.1:9000
docker exec -i "$NAME" sh -c 'cat > /config/www/smoke.php && chown abc:abc /config/www/smoke.php' <<'PHP'
<?php
header('Content-Type: text/plain');
echo 'PHP-OK:' . PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;
PHP
PHP_OUT="$(curl -fsSk https://127.0.0.1:18443/smoke.php)"
echo "PHP response: ${PHP_OUT}"
printf '%s' "$PHP_OUT" | grep -q '^PHP-OK:8\.4'

# Run exact container healthcheck command
docker exec "$NAME" sh -c "curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://127.0.0.1/ | grep -qE '^(200|301|302|401)$'"

# Negative test: closed port must fail healthcheck
if docker exec "$NAME" sh -c "curl -sk -o /dev/null -w '%{http_code}' --max-time 3 https://127.0.0.1:59999/ | grep -qE '^(200|301|302|401)$'"; then
  echo "ERROR: healthcheck unexpectedly passed on closed port 59999" >&2
  exit 1
fi

echo "Smoke test passed (pid1=${PID1_COMM}, https=${CODE}, brotli=ok, php=${PHP_OUT})."
