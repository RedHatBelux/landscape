# ---------- Stage 0: fetch sources (no secrets) ----------
FROM alpine:3.20 AS fetch
RUN apk add --no-cache git curl
# Your fork (data + logos)
RUN git clone --depth=1 https://github.com/RedHatBelux/landscape /src/landscape
# Canonical CNCF settings/guide
RUN mkdir -p /src/cncf && \
    curl -L -o /src/cncf/settings.yml https://raw.githubusercontent.com/cncf/landscape2-sites/main/cncf/settings.yml && \
    curl -L -o /src/cncf/guide.yml    https://raw.githubusercontent.com/cncf/landscape2-sites/main/cncf/guide.yml

# ---------- Stage 1: build the static site ----------
FROM ghcr.io/cncf/landscape2:latest AS builder
ENV OUTPUT_DIR=/tmp/site CACHE_DIR=/tmp/cache
RUN mkdir -p "$OUTPUT_DIR" "$CACHE_DIR"
COPY --from=fetch /src/landscape /workspace/landscape
COPY --from=fetch /src/cncf      /workspace/cncf

# Build from local files (robust even if network/CAs are restricted at build time)
RUN landscape2 build \
  --data-file     /workspace/landscape/landscape.yml \
  --settings-file /workspace/cncf/settings.yml \
  --guide-file    /workspace/cncf/guide.yml \
  --logos-path    /workspace/landscape/hosted_logos \
  --cache-dir     "$CACHE_DIR" \
  --output-dir    "$OUTPUT_DIR"

# ---------- Stage 2: serve ----------
FROM registry.access.redhat.com/ubi9/nginx-122:latest

# become root to write config/content and fix perms
USER 0
RUN rm -rf /opt/app-root/src/* /etc/nginx/conf.d/*

# copy built site
COPY --from=builder /tmp/site /opt/app-root/src

# SPA config on 8080
RUN printf '%s\n' \
'server {                               ' \
'  listen 8080;                         ' \
'  server_name _;                       ' \
'  root /opt/app-root/src;              ' \
'  index index.html;                    ' \
'  location / { try_files $uri /index.html; }' \
'}                                       ' \
> /etc/nginx/conf.d/landscape.conf

# OpenShift: allow arbitrary UID (gid 0) to write needed dirs
RUN mkdir -p /var/cache/nginx /var/run \
 && chgrp -R 0 /var/cache/nginx /var/run /etc/nginx /opt/app-root/src \
 && chmod -R g+rwX /var/cache/nginx /var/run /etc/nginx /opt/app-root/src

# drop privileges again
USER 1001

# IMPORTANT: override the S2I entrypoint to run nginx directly
ENTRYPOINT ["/usr/sbin/nginx","-g","daemon off;"]
EXPOSE 8080

