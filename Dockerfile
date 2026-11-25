# syntax=docker/dockerfile:1.7

ARG DEBIAN_BASE=debian:trixie-slim
ARG NGINX_VERSION=1.30.8
ARG NGX_BROTLI_COMMIT=53e0fb55f250f48fe80c0ddbf6c0f7103cdbaae1

# ---- Stage 1: compile official NGINX stable + ngx_brotli dynamic modules ----
FROM ${DEBIAN_BASE} AS nginx-builder

ARG NGINX_VERSION
ARG NGX_BROTLI_COMMIT
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends \
       build-essential ca-certificates curl git libbrotli-dev libpcre2-dev \
       libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN set -eux; \
    curl -fsSLo /src/nginx.tar.gz "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"; \
    tar -xzf /src/nginx.tar.gz -C /src; \
    mv "/src/nginx-${NGINX_VERSION}" /src/nginx; \
    git init /src/ngx_brotli; \
    git -C /src/ngx_brotli remote add origin https://github.com/google/ngx_brotli.git; \
    git -C /src/ngx_brotli fetch --depth 1 origin "${NGX_BROTLI_COMMIT}"; \
    git -C /src/ngx_brotli checkout --detach FETCH_HEAD; \
    test "$(git -C /src/ngx_brotli rev-parse HEAD)" = "${NGX_BROTLI_COMMIT}"; \
    mkdir -p /src/ngx_brotli/deps/brotli/c; \
    ln -s /usr/include /src/ngx_brotli/deps/brotli/c/include; \
    ln -s /usr/lib/x86_64-linux-gnu /src/ngx_brotli/deps/brotli/out

WORKDIR /src/nginx

RUN set -eux; \
    ./configure \
      --prefix=/var/lib/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/run/nginx.pid \
      --lock-path=/run/nginx.lock \
      --http-client-body-temp-path=/var/lib/nginx/tmp/client_body \
      --http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
      --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi \
      --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
      --http-scgi-temp-path=/var/lib/nginx/tmp/scgi \
      --user=abc \
      --group=abc \
      --with-compat \
      --with-threads \
      --with-file-aio \
      --with-pcre-jit \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_v3_module \
      --with-http_realip_module \
      --with-http_addition_module \
      --with-http_sub_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_mp4_module \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-http_auth_request_module \
      --with-http_random_index_module \
      --with-http_secure_link_module \
      --with-http_slice_module \
      --with-http_stub_status_module \
      --with-stream \
      --with-stream_ssl_module \
      --with-stream_realip_module \
      --with-stream_ssl_preread_module \
      --add-dynamic-module=/src/ngx_brotli; \
    make -j"$(nproc)"; \
    make DESTDIR=/out install; \
    rm -rf /out/var/log/nginx

# ---- Stage 2: hardened Debian 13 (trixie-slim) NGINX + PHP 8.4 FPM runtime ----
FROM ${DEBIAN_BASE} AS runtime

ARG NGINX_VERSION
ARG NGX_BROTLI_COMMIT
ARG BUILD_DATE=unknown
ARG IMAGE_REVISION=""
ARG IMAGE_SOURCE="https://github.com/dgcosenza/nginx-docker"
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl inotify-tools libbrotli1 libpcre2-8-0 libssl3t64 \
       openssl passwd procps tini tzdata zlib1g \
       php8.4-fpm php8.4-cli php8.4-bcmath php8.4-bz2 php8.4-curl \
       php8.4-gd php8.4-gmp php8.4-intl php8.4-ldap php8.4-mbstring \
       php8.4-mysql php8.4-pgsql php8.4-soap php8.4-sqlite3 php8.4-xml \
       php8.4-xsl php8.4-zip php-apcu php-igbinary php-memcached \
       php-msgpack php-redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create default abc user/group (UID/GID 1000, adjusted at boot via PUID/PGID)
RUN groupadd --gid 1000 abc \
    && useradd --uid 1000 --gid 1000 --create-home --home-dir /config \
       --shell /usr/sbin/nologin --comment 'NGINX service user' abc

# Install compiled NGINX binary, dynamic brotli modules, and config scaffolding
COPY --from=nginx-builder --chown=0:0 /out/usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx-builder --chown=0:0 /out/usr/lib/nginx/modules /usr/lib/nginx/modules
COPY --from=nginx-builder --chown=0:0 /out/etc/nginx/mime.types /etc/nginx/mime.types
COPY --from=nginx-builder --chown=0:0 /out/etc/nginx/fastcgi_params /etc/nginx/fastcgi_params
COPY --from=nginx-builder --chown=0:0 /out/etc/nginx/fastcgi.conf /etc/nginx/fastcgi.conf
COPY --from=nginx-builder --chown=0:0 /out/etc/nginx/uwsgi_params /etc/nginx/uwsgi_params
COPY --from=nginx-builder --chown=0:0 /out/etc/nginx/scgi_params /etc/nginx/scgi_params

RUN set -eux; \
    mkdir -p /etc/nginx/modules /etc/nginx/conf.d /etc/nginx/http.d \
      /var/lib/nginx/tmp/client_body /var/lib/nginx/tmp/proxy \
      /var/lib/nginx/tmp/fastcgi /var/lib/nginx/tmp/uwsgi /var/lib/nginx/tmp/scgi \
      /var/log/nginx /run/php /defaults /config; \
    printf 'include /config/nginx/nginx.conf;\n' > /etc/nginx/nginx.conf; \
    printf 'load_module /usr/lib/nginx/modules/ngx_http_brotli_filter_module.so;\nload_module /usr/lib/nginx/modules/ngx_http_brotli_static_module.so;\n' \
      > /etc/nginx/modules/10_http_brotli.conf; \
    chown -R abc:abc /var/lib/nginx /var/log/nginx /run/php; \
    ldd /usr/sbin/nginx | grep -v 'not found'

# Configure base PHP 8.4 FPM pool (listens on 127.0.0.1:9000 as user abc)
COPY defaults/ /defaults/
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

ENV PUID=1000 \
    PGID=1000 \
    TZ=Etc/UTC \
    AUTO_RELOAD=false

EXPOSE 80 443
VOLUME ["/config"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["sh", "-c", "curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://127.0.0.1/ | grep -qE '^(200|301|302|401)$'"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="NGINX + PHP 8.4 FPM (Debian 13)" \
      org.opencontainers.image.description="Source-built NGINX with ngx_brotli and PHP 8.4 FPM on Debian 13 (trixie-slim), maintained by Daniel G. Cosenza from FNX Labs." \
      org.opencontainers.image.url="https://hub.docker.com/r/dgcosenza/nginx" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.documentation="${IMAGE_SOURCE}#readme" \
      org.opencontainers.image.version="${NGINX_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Daniel G. Cosenza from FNX Labs" \
      org.opencontainers.image.authors="Daniel G. Cosenza from FNX Labs" \
      org.opencontainers.image.base.name="debian:trixie-slim" \
      io.github.dgcosenza.nginx.upstream_version="${NGINX_VERSION}" \
      io.github.dgcosenza.nginx.ngx_brotli_commit="${NGX_BROTLI_COMMIT}"
