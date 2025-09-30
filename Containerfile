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
FROM registry.access.redhat.com/ubi9/nginx-120:latest
COPY --from=builder /tmp/site /usr/share/nginx/html
# SPA routing
RUN printf '%s\n' \
 'server { listen 8080; server_name _; root /usr/share/nginx/html; index index.html;' \
 '  location / { try_files $uri /index.html; } }' > /etc/nginx/conf.d/default.conf
EXPOSE 8080