# Changelog

All notable changes to the `dgcosenza/nginx` Debian 13 container packaging and CI workflows are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Maintained by **Daniel G. Cosenza from FNX Labs**.

---
<!-- changelog:auto -->

## [1.30.8] — 2026-11-26

### Automated Daily Build
- Verified components: NGINX `1.30.8`, ngx_brotli `53e0fb5`, PHP-FPM `8.4.28`, Base OS `Debian 13.8 (trixie-slim)`.
- Architectures verified: `linux/amd64, linux/arm64` (native smoke tests + Dive efficiency gate).
- Upstream status: no new upstream release since previous build; refreshed base OS and dependencies.
- Vulnerability gate: **0 fixable Critical/High** in Trivy and Grype (SBOM scan) (30 upstream-unfixed).
- Published multi-arch digest (Docker Hub + GHCR): `dgcosenza/nginx@sha256:c84d33742f2474a0aa61ebba66afadeaa815d7149bcdce8e4890da7ef1056a81` (Cosign OIDC signed + SPDX/CycloneDX SBOM + SLSA L3 provenance).

---

## [1.30.8] — 2026-11-25

### Automated Daily Build
- Verified components: NGINX `1.30.8`, ngx_brotli `53e0fb5`, PHP-FPM `8.4.28`, Base OS `Debian 13.8 (trixie-slim)`.
- Architectures verified: `linux/amd64, linux/arm64` (native smoke tests + Dive efficiency gate).
- Upstream status: no new upstream release since previous build; refreshed base OS and dependencies.
- Vulnerability gate: **0 fixable Critical/High** in Trivy and Grype (SBOM scan) (30 upstream-unfixed).
- Published multi-arch digest (Docker Hub + GHCR): `dgcosenza/nginx@sha256:00210f923bb355cb9b9718e20e72d0c181b3319f413f715777c3b837eb0c6039` (Cosign OIDC signed + SPDX/CycloneDX SBOM + SLSA L3 provenance).
---

## [1.30.8] — 2026-11-24

### Added
- Initial source-built **NGINX 1.30.8** (with HTTP/3 and dynamically linked `ngx_brotli`) + **PHP 8.4 FPM** image on **Debian 13 (`trixie-slim`)**.
- Full drop-in `/config` layout compatibility (`PUID`/`PGID` user `abc`, `/config/nginx`, `/config/keys`, `/config/php/php-local.ini`, `/config/php/www2.conf`, `/config/log`, `/config/www`), built-in `inotifywait` auto-reload, and `tini` PID 1 supervision.
- Seven-step automated daily CI pipeline (`.github/workflows/daily.yml`) with Trivy and Grype fixable Critical/High blocking gates, Syft SPDX SBOM, smoke test (`tests/smoke.sh`), automated docs/Hub sync, and `ci-failure` issue alerting.
