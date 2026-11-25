#!/usr/bin/env bash
set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Reconcile abc user/group to PUID/PGID when running as root
if [ "$(id -u)" -eq 0 ]; then
  CUR_GID="$(id -g abc)"
  CUR_UID="$(id -u abc)"
  if [ "$CUR_GID" != "$PGID" ]; then
    groupmod -o -g "$PGID" abc
  fi
  if [ "$CUR_UID" != "$PUID" ]; then
    usermod -o -u "$PUID" abc
  fi
fi

# Ensure runtime directories exist (never overwrite existing user files)
mkdir -p \
  /config/nginx/site-confs \
  /config/keys \
  /config/log/nginx \
  /config/log/php \
  /config/php \
  /config/www \
  /var/lib/nginx/tmp/client_body \
  /var/lib/nginx/tmp/proxy \
  /var/lib/nginx/tmp/fastcgi \
  /var/lib/nginx/tmp/uwsgi \
  /var/lib/nginx/tmp/scgi \
  /run/php

# Seed default config files only if missing
if [ ! -f /config/nginx/worker_processes.conf ]; then
  printf 'worker_processes auto;\n' > /config/nginx/worker_processes.conf
fi

if [ ! -f /config/nginx/resolver.conf ]; then
  NS="$(awk '/^nameserver[[:space:]]+/{print $2; exit}' /etc/resolv.conf || true)"
  [ -n "$NS" ] || NS="127.0.0.11"
  case "$NS" in
    *:*) NS="[${NS}]" ;;
  esac
  printf 'resolver %s valid=30s;\n' "$NS" > /config/nginx/resolver.conf
fi

if [ ! -f /config/nginx/real-ip.conf ]; then
  printf '# Optional real-IP / trusted proxy directives\n' > /config/nginx/real-ip.conf
fi

if [ ! -f /config/nginx/dhparams.pem ]; then
  cp /defaults/dhparams.pem /config/nginx/dhparams.pem
fi

if [ ! -f /config/keys/cert.crt ] || [ ! -f /config/keys/cert.key ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -subj "/CN=localhost" \
    -keyout /config/keys/cert.key \
    -out /config/keys/cert.crt >/dev/null 2>&1
  chmod 0600 /config/keys/cert.key
  chmod 0644 /config/keys/cert.crt
fi

for pair in \
  "nginx.conf:/config/nginx/nginx.conf" \
  "ssl.conf:/config/nginx/ssl.conf" \
  "default.conf:/config/nginx/site-confs/default.conf" \
  "index.html:/config/www/index.html" \
  "php-local.ini:/config/php/php-local.ini" \
  "www2.conf:/config/php/www2.conf"; do
  src="/defaults/${pair%%:*}"
  dst="${pair#*:}"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
  fi
done

# Wire /config/php/php-local.ini into PHP 8.4 FPM and CLI
ln -sfn /config/php/php-local.ini /etc/php/8.4/fpm/conf.d/99-local.ini
ln -sfn /config/php/php-local.ini /etc/php/8.4/cli/conf.d/99-local.ini

# Build merged PHP-FPM pool config supporting /config/php/www2.conf overrides
{
  cat /defaults/php-fpm-www.conf
  if [ -f /config/php/www2.conf ]; then
    echo ""
    echo "; User overrides from /config/php/www2.conf"
    sed '/^[[:space:]]*\[www\][[:space:]]*$/d' /config/php/www2.conf
  fi
} > /etc/php/8.4/fpm/pool.d/www.conf

# Configure php-fpm error log path
sed -i 's|^error_log = .*|error_log = /config/log/php/error.log|' /etc/php/8.4/fpm/php-fpm.conf

# Fix ownership on runtime/log dirs without recursively crawling huge /config/www mounts
if [ "$(id -u)" -eq 0 ]; then
  chown -R abc:abc /var/lib/nginx /var/log/nginx /run/php /config/log /config/keys
  chown abc:abc /config /config/nginx /config/nginx/site-confs /config/php /config/www
fi

# Validate NGINX configuration before starting
/usr/sbin/nginx -t

# Start PHP-FPM 8.4 in foreground child process
/usr/sbin/php-fpm8.4 --nodaemonize --fpm-config /etc/php/8.4/fpm/php-fpm.conf &
PHP_PID=$!

# Optional config auto-reload watcher (AUTO_RELOAD=true or DOCKER_MODS containing auto-reload)
WATCH_PID=""
if [ "${AUTO_RELOAD:-false}" = "true" ] || printf '%s' "${DOCKER_MODS:-}" | grep -qi 'auto-reload'; then
  (
    while inotifywait -q -r -e close_write,moved_to,create,delete /config/nginx >/dev/null 2>&1; do
      sleep 1
      if /usr/sbin/nginx -t >/dev/null 2>&1; then
        /usr/sbin/nginx -s reload || true
      else
        echo "[auto-reload] nginx -t failed; skipping reload" >&2
      fi
    done
  ) &
  WATCH_PID=$!
fi

# Detect whether user's /config/nginx/nginx.conf already sets 'daemon off;'
NGINX_ARGS=()
if ! grep -Eq '^[[:space:]]*daemon[[:space:]]+off[[:space:]]*;' /config/nginx/nginx.conf; then
  NGINX_ARGS=(-g "daemon off;")
fi

/usr/sbin/nginx "${NGINX_ARGS[@]}" &
NGINX_PID=$!

shutdown_all() {
  [ -n "$WATCH_PID" ] && kill -TERM "$WATCH_PID" 2>/dev/null || true
  kill -QUIT "$NGINX_PID" 2>/dev/null || true
  kill -QUIT "$PHP_PID" 2>/dev/null || true
  wait "$NGINX_PID" 2>/dev/null || true
  wait "$PHP_PID" 2>/dev/null || true
}
trap shutdown_all TERM INT

# Exit if either core daemon exits unexpectedly
wait -n "$NGINX_PID" "$PHP_PID"
STATUS=$?
shutdown_all
exit "$STATUS"
