# Security Policy

Maintained by **Daniel G. Cosenza from FNX Labs**.

## Supported Versions

Only the latest daily build of `dgcosenza/nginx` built from the latest official stable NGINX release with PHP 8.4 FPM on Debian 13 (`trixie-slim`) is actively maintained and receives automated security rebuilds.

## Automated Vulnerability Scanning

Every build in GitHub Actions enforces:
- **Trivy** (`--ignore-unfixed`, severity `CRITICAL,HIGH`) blocking gate + full table/JSON reports + SARIF upload to GitHub Code Scanning.
- **Grype** (`--only-fixed`, severity cutoff `high`) blocking gate + persisted report artifact.
- **Syft** SPDX SBOM (`sbom.spdx.json`) and build provenance artifacts.

Daily scheduled builds run with `--no-cache`, upgrade all Debian 13 packages and PHP 8.4 security updates, and track the latest official stable NGINX release from `nginx.org`.

## Reporting a Vulnerability

- **Container packaging or CI issues:** Open a private security advisory via GitHub Security Advisories on [`dgcosenza/nginx-docker`](https://github.com/dgcosenza/nginx-docker/security/advisories/new).
- **Upstream NGINX issues:** Report to [nginx.org/en/security_advisories.html](https://nginx.org/en/security_advisories.html).
