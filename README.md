# NGINX + Brotli + PHP 8.4 FPM — Debian 13 (trixie-slim) Image

[![Daily NGINX image](https://github.com/dgcosenza/nginx-docker/actions/workflows/daily.yml/badge.svg)](https://github.com/dgcosenza/nginx-docker/actions/workflows/daily.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/dgcosenza/nginx)](https://hub.docker.com/r/dgcosenza/nginx)
[![Docker Image Size](https://img.shields.io/docker/image-size/dgcosenza/nginx/latest)](https://hub.docker.com/r/dgcosenza/nginx)

A source-built **NGINX** (stable 1.30.x with **HTTP/3**, **Brotli**, and **PHP 8.4 FPM**) container image on **Debian 13 (`trixie-slim`)** with drop-in `/config` layout compatibility, maintained by **Daniel G. Cosenza from FNX Labs**.

- **Docker Hub:** [`dgcosenza/nginx`](https://hub.docker.com/r/dgcosenza/nginx)
- **Source Repository:** [`dgcosenza/nginx-docker`](https://github.com/dgcosenza/nginx-docker)
- **Upstream Projects:** [NGINX](https://nginx.org/) (2-clause BSD), [`google/ngx_brotli`](https://github.com/google/ngx_brotli) (2-clause BSD), [PHP 8.4](https://www.php.net/)
- **Packaging License:** MIT (see [`LICENSE`](https://github.com/dgcosenza/nginx-docker/blob/main/LICENSE) and [`THIRD-PARTY-NOTICES.md`](https://github.com/dgcosenza/nginx-docker/blob/main/THIRD-PARTY-NOTICES.md))

---

## Overview

`dgcosenza/nginx` builds the latest official stable **NGINX** release from `nginx.org` alongside dynamic `ngx_brotli` modules (linked dynamically to Debian 13's `libbrotli1`) and Debian 13's **PHP 8.4 FPM** stack on fully upgraded `debian:trixie-slim`:

- **Drop-in `/config` compatibility:** Preserves `PUID`/`PGID` (user `abc`), `/config/nginx/nginx.conf` (included from `/etc/nginx/nginx.conf`), `/config/nginx/site-confs/*.conf`, `/config/nginx/ssl.conf`, `/config/keys/cert.{crt,key}`, `/config/php/php-local.ini`, `/config/php/www2.conf`, `/config/log/`, and `/config/www/`.
- **Built-in Brotli & PHP-FPM:** Ships `/etc/nginx/modules/10_http_brotli.conf` (`ngx_http_brotli_filter_module.so` + `ngx_http_brotli_static_module.so`) and `php-fpm8.4` listening on `127.0.0.1:9000` with common extensions (`apcu`, `bcmath`, `bz2`, `curl`, `gd`, `gmp`, `igbinary`, `intl`, `ldap`, `mbstring`, `memcached`, `msgpack`, `mysql`, `pgsql`, `redis`, `soap`, `sqlite3`, `xml`, `xsl`, `zip`).
- **Built-in config auto-reload:** Enable `AUTO_RELOAD=true` (or keep `DOCKER_MODS=linuxserver/mods:swag-auto-reload`) to watch `/config/nginx` via `inotifywait` and reload NGINX automatically after `nginx -t` validation — no external runtime mod downloads needed.
- **Hardened & CVE-gated:** Runs with `tini` as PID 1, compatible with `security_opt: no-new-privileges:true`, workers run as non-root `abc`, and every daily build enforces **0 fixable Critical/High** findings in both Trivy and Grype.

---

## Current Versions

<!-- versions:start -->
| Component | Resolved Version |
| --- | --- |
| NGINX | `1.30.8` |
| ngx_brotli | `53e0fb5` |
| PHP-FPM | `8.4` |
| Base OS | `Debian 13.8 (trixie-slim)` |
| Last verified build (UTC) | `2026-11-24` |
| Security gate (Trivy + Grype) | **0 fixable Critical/High** (0 upstream-unfixed) |
<!-- versions:end -->

---

## Supported Tags

| Tag | Policy | Description |
| --- | --- | --- |
| `<version>-<YYYYMMDD>` (e.g. `1.30.8-20261124`) | **Immutable** | Date-stamped daily rebuild pinning the NGINX stable release and UTC build date. |
| `sha-<short>` | **Immutable** | Packaging repository Git commit tag. |
| `<version>` (e.g. `1.30.8`) | Moving | Latest verified Debian 13 rebuild of that NGINX release. |
| `latest` | Moving | Latest verified build tracking the newest official stable NGINX release. |

**Production pinning:** Pin by registry digest rather than pulling unpinned `:latest`:

```yaml
image: dgcosenza/nginx:latest@sha256:<digest>
```

---

## Supported Architectures

| Architecture | Status | Notes |
| --- | --- | --- |
| `linux/amd64` | **Published & tested** | Built, smoke-tested, scanned with Trivy and Grype, and published to Docker Hub (`dgcosenza/nginx`). |

---

## Quick Start

### `docker run`

```bash
docker run -d \
  --name nginx \
  --restart unless-stopped \
  --security-opt no-new-privileges:true \
  -p 192.0.2.10:443:443 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e AUTO_RELOAD=true \
  -v "$(pwd)/config:/config" \
  dgcosenza/nginx:latest
```

### Docker Compose

See [`docker-compose.example.yml`](https://github.com/dgcosenza/nginx-docker/blob/main/docker-compose.example.yml):

```yaml
services:
  nginx:
    image: dgcosenza/nginx:latest
    container_name: nginx
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "192.0.2.10:443:443"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - AUTO_RELOAD=true
    volumes:
      - ./config:/config
    healthcheck:
      test: ["CMD-SHELL", "curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://127.0.0.1/ | grep -qE '^(200|301|302|401)$$'"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
```

---

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `PUID` | No | `1000` | UID assigned to the `abc` NGINX/PHP-FPM worker user. |
| `PGID` | No | `1000` | GID assigned to the `abc` NGINX/PHP-FPM worker group. |
| `TZ` | No | `Etc/UTC` | Container timezone (IANA timezone name). |
| `AUTO_RELOAD` | No | `false` | Set `true` to watch `/config/nginx` with `inotifywait` and reload NGINX after `nginx -t` succeeds. Also activates automatically if `DOCKER_MODS` contains `auto-reload`. |

### Volumes, Ports, and UID/GID

| Path / Port | Mode / Owner | Purpose |
| --- | --- | --- |
| `/config/nginx/` | `PUID:PGID` | `nginx.conf`, `ssl.conf`, `worker_processes.conf`, `resolver.conf`, `real-ip.conf`, `dhparams.pem`, `site-confs/*.conf`. Existing files are never overwritten. |
| `/config/keys/` | `PUID:PGID` | TLS certificate (`cert.crt`) and private key (`cert.key`, auto-generated self-signed on fresh boot if absent). |
| `/config/php/` | `PUID:PGID` | `php-local.ini` (loaded into FPM & CLI) and `www2.conf` (appended to `[www]` pool overrides). |
| `/config/www/` | `PUID:PGID` | Default web root for static and PHP content. |
| `/config/log/` | `PUID:PGID` | `nginx/access.log`, `nginx/error.log`, `php/error.log`. |
| `80/tcp`, `443/tcp` | Container ports | HTTP and HTTPS listeners (bind explicitly to your LAN/proxy interface). |

---

## Healthcheck

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["sh", "-c", "curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://127.0.0.1/ | grep -qE '^(200|301|302|401)$'"]
```

Probes the local HTTPS endpoint and succeeds on HTTP `200`, `301`, `302`, or `401` (supporting HTTP Basic Auth default vhosts).

---

## Upgrading and Migrating from `lscr.io/linuxserver/nginx`

This image is designed as a drop-in replacement for existing `/config` volumes:

1. Back up `./config` and tag your outgoing image for rollback.
2. Test side-by-side against a **copy** of `./config` on non-conflicting loopback ports and run `docker exec <trial> nginx -t`.
3. Note: If any custom vhost relies on third-party dynamic NGINX modules other than `ngx_brotli` (such as Lua or RTMP), remove those directives or build with the extra module before cutover. Standard reverse-proxy, TLS, Brotli, HTTP Basic Auth, and PHP-FPM (`127.0.0.1:9000`) configurations work without changes.
4. Pin `image: dgcosenza/nginx:latest@sha256:<digest>` in Compose and recreate the service (`docker compose up -d nginx`).

---

## Security

- **Vulnerability scan policy:** Every CI build runs **Trivy** (table, JSON, SARIF upload to Code Scanning, and blocking `--ignore-unfixed` gate) and **Grype** (`--only-fixed`, severity cutoff `high`, blocking gate), plus generates an **SPDX SBOM** (`sbom.spdx.json`) and provenance artifact. Publication is blocked on any fixable `CRITICAL` or `HIGH` finding.
- **Current status:** **0 fixable Critical/High** vulnerabilities across Debian 13 OS packages, PHP 8.4, and source-built NGINX.
- **Hardening:** `tini` PID 1, `no-new-privileges:true` compatible, worker processes drop to non-root `abc` (`PUID:PGID`), compilers excluded from runtime layer, `server_tokens off` and `expose_php = Off` in defaults.
- See [`SECURITY.md`](https://github.com/dgcosenza/nginx-docker/blob/main/SECURITY.md).

---

## Build Locally

```bash
git clone https://github.com/dgcosenza/nginx-docker.git
cd nginx-docker

docker buildx build \
  --platform linux/amd64 \
  --load \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg IMAGE_REVISION="$(git rev-parse HEAD)" \
  -t dgcosenza/nginx:local \
  .
```

| Build Arg | Default | Purpose |
| --- | --- | --- |
| `NGINX_VERSION` | `1.30.8` | Official stable NGINX release from `nginx.org` (overridden daily by CI). |
| `NGX_BROTLI_COMMIT` | `53e0fb55f250f48fe80c0ddbf6c0f7103cdbaae1` | Pinned `google/ngx_brotli` commit SHA. |
| `DEBIAN_BASE` | `debian:trixie-slim` | Base OS image. |
| `BUILD_DATE` | `unknown` | RFC 3339 UTC build timestamp. |
| `IMAGE_REVISION` | `""` | Packaging repository Git SHA. |
| `IMAGE_SOURCE` | `https://github.com/dgcosenza/nginx-docker` | Source URL for OCI labels. |

---

## Update Policy

[`.github/workflows/daily.yml`](https://github.com/dgcosenza/nginx-docker/blob/main/.github/workflows/daily.yml) runs automatically every day at **04:31 UTC**, on pushes to `main`, on pull requests (verification only, without pushing), and via `workflow_dispatch`. Every scheduled run executes a seven-step automated pipeline (gated by `.github/workflows/public-check.yml`):

1. **Upstream check:** Resolves the latest official stable NGINX release from `nginx.org` and the `debian:trixie-slim` base digest, diffs against `versions.json`, and emits `upstream-changes.md`.
2. **No-cache rebuild:** Rebuilds `linux/amd64` with `--no-cache` on schedule, compiles NGINX + `ngx_brotli`, upgrades Debian 13 packages and PHP 8.4 security updates (`apt-get update && apt-get -y upgrade`), and generates an **SPDX SBOM** (`sbom.spdx.json`) and provenance artifact.
3. **Vulnerability fix and gate:** Runs **Trivy** (table, JSON, SARIF upload, blocking `--ignore-unfixed` gate) and **Grype** (blocking `--only-fixed` gate, severity cutoff `high`), diffs findings against the previous scan to record resolved CVEs, and retains reports for 90 days.
4. **Smoke test:** Runs [`tests/smoke.sh`](https://github.com/dgcosenza/nginx-docker/blob/main/tests/smoke.sh) to verify fresh `/config` initialization, `tini` PID 1, non-root `abc` NGINX and PHP-FPM workers, HTTPS 200, Brotli (`Content-Encoding: br`), PHP 8.4 execution, and a negative closed-port healthcheck test.
5. **Publish:** On non-PR builds when Docker Hub secrets are configured, pushes `latest`, `<version>`, `<version>-<YYYYMMDD>`, and `sha-<short>` tags to Docker Hub and records the immutable digest.
6. **Automated documentation sync:** Commits updated `versions.json`, the README `Current Versions` block, and a dated `CHANGELOG.md` entry via `github-actions[bot]` with `[skip ci]` when content changes, then syncs Docker Hub overview and short description via `peter-evans/dockerhub-description`.
7. **Failure alerting:** If any step fails on `main` or a scheduled run, CI opens or updates a single GitHub issue labeled `ci-failure` with the failing job and run link, and automatically closes it on the next green run.

---

## Design Decisions

- **Source-built official stable NGINX (`1.30.x`) on Debian 13 (`trixie-slim`):** Avoids downgrading to Debian 13's distro-frozen `nginx 1.26.x` while retaining Debian 13 glibc, OpenSSL 3, PHP 8.4, and daily Debian Security updates.
- **Dynamically linked `ngx_brotli`:** Links `ngx_brotli` against Debian 13's `libbrotli1` rather than bundling static C sources so Debian Security patches apply automatically.
- **Built-in `inotifywait` auto-reload:** Eliminates third-party runtime container mod downloads while maintaining drop-in compatibility with existing `DOCKER_MODS` / `AUTO_RELOAD` Compose configurations.

---

## License and Credits

- **Container packaging, entrypoint, CI, and documentation:** [MIT License](https://github.com/dgcosenza/nginx-docker/blob/main/LICENSE) — maintained by **Daniel G. Cosenza from FNX Labs**.
- **NGINX:** [nginx.org](https://nginx.org/) — 2-clause BSD License.
- **ngx_brotli:** [`google/ngx_brotli`](https://github.com/google/ngx_brotli) — 2-clause BSD License.
- **PHP:** [The PHP Group](https://www.php.net/) — PHP License v3.01.
- Full third-party notices: [`THIRD-PARTY-NOTICES.md`](https://github.com/dgcosenza/nginx-docker/blob/main/THIRD-PARTY-NOTICES.md).
- Release history: [`CHANGELOG.md`](https://github.com/dgcosenza/nginx-docker/blob/main/CHANGELOG.md).
