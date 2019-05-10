FROM alpine:3.9

LABEL maintainer="Aleksey Maydokin <amaydokin@gmail.com>"

ENV NGINX_VERSION 1.16.0
ENV NGX_BROTLI_VERSION 0.1.2
ENV BROTLI_VERSION 1.0.7

RUN set -x \
# create group and user for nginx
    && addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
# install packages needed to build nginx and ngx_brotli
    && apk add --no-cache --virtual .build-deps \
            gcc \
            libc-dev \
            make \
            linux-headers \
            curl \
    && mkdir -p /usr/src \
# dowload and extract source files
    && curl -LSs https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz | tar xzf - -C /usr/src \
    && curl -LSs https://github.com/eustas/ngx_brotli/archive/v$NGX_BROTLI_VERSION.tar.gz | tar xzf - -C /usr/src \
    && curl -LSs https://github.com/google/brotli/archive/v$BROTLI_VERSION.tar.gz | tar xzf - -C /usr/src \
# ngx_brotli needs brotli files under its deps/brotli directory
    && rm -rf /usr/src/ngx_brotli-$NGX_BROTLI_VERSION/deps/brotli/ \
    && ln -s /usr/src/brotli-$BROTLI_VERSION /usr/src/ngx_brotli-$NGX_BROTLI_VERSION/deps/brotli \
    && cd /usr/src/nginx-$NGINX_VERSION \
    && CNF="\
            --prefix=/etc/nginx \
            --sbin-path=/usr/sbin/nginx \
            --modules-path=/usr/lib/nginx/modules \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --http-log-path=/var/log/nginx/access.log \
            --pid-path=/var/run/nginx.pid \
            --lock-path=/var/run/nginx.lock \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            --user=nginx \
            --group=nginx \
            --without-http_ssi_module \
            --without-http_userid_module \
            --without-http_access_module \
            --without-http_auth_basic_module \
            --without-http_mirror_module \
            --without-http_autoindex_module \
            --without-http_geo_module \
            --without-http_split_clients_module \
            --without-http_referer_module \
            --without-http_rewrite_module \
            --without-http_proxy_module \
            --without-http_fastcgi_module \
            --without-http_uwsgi_module \
            --without-http_scgi_module \
            --without-http_grpc_module \
            --without-http_memcached_module \
            --without-http_limit_conn_module \
            --without-http_limit_req_module \
            --without-http_empty_gif_module \
            --without-http_browser_module \
            --without-http_upstream_hash_module \
            --without-http_upstream_ip_hash_module \
            --without-http_upstream_least_conn_module \
            --without-http_upstream_keepalive_module \
            --without-http_upstream_zone_module \
            --without-http_gzip_module \
            --with-http_gzip_static_module \
            --with-threads \
            --with-compat \
            --with-file-aio \
            --add-dynamic-module=/usr/src/ngx_brotli-$NGX_BROTLI_VERSION \
    " \
# build
    && ./configure $CNF \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && rm -rf /usr/src/ \
# remove brotli filter module, as we need only static one
    && rm /usr/lib/nginx/modules/ngx_http_brotli_filter_module.so \
    && sed -i '$ d' /etc/apk/repositories \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .build-deps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Bring in tzdata so users could set the timezones through the environment
# variables
    && apk add --no-cache tzdata \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
