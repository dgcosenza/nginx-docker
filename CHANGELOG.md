# Changelog

All notable changes to the `dgcosenza/nginx` Debian 13 container packaging and CI workflows are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Maintained by **Daniel G. Cosenza from FNX Labs**.

---
<!-- changelog:auto -->

## [1.30.8] — 2026-11-24

### Added
- Initial source-built **NGINX 1.30.8** (with HTTP/3 and dynamically linked `ngx_brotli`) + **PHP 8.4 FPM** image on **Debian 13 (`trixie-slim`)**.
- Full drop-in `/config` layout compatibility (`PUID`/`PGID` user `abc`, `/config/nginx`, `/config/keys`, `/config/php/php-local.ini`, `/config/php/www2.conf`, `/config/log`, `/config/www`), built-in `inotifywait` auto-reload, and `tini` PID 1 supervision.
- Seven-step automated daily CI pipeline (`.github/workflows/daily.yml`) with Trivy and Grype fixable Critical/High blocking gates, Syft SPDX SBOM, smoke test (`tests/smoke.sh`), automated docs/Hub sync, and `ci-failure` issue alerting.
