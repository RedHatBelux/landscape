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
#FROM ghcr.io/cncf/landscape2:latest AS builder
FROM quay.io/plewyllie/landscape2:builder as builder
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

# Inject a small runtime script & hook it into index.html
# 1) write /opt/app-root/src/custom.js
RUN printf '%s\n' \
'(() => {' \
'  const RH_COLOR = "#ee0000";' \
'  const RH_MAP = new Map([' \
'    ["Argo","OpenShift GitOps"],' \
'    ["Tekton Pipelines","OpenShift Pipelines"],' \
'    ["Quay","Red Hat Quay"],' \
'    ["Clair","Red Hat Quay (Clair)"],' \
'    ["Ansible","Red Hat Ansible Automation Platform"],' \
'    ["Quarkus","Red Hat build of Quarkus"],' \
'    ["KubeVirt","OpenShift Virtualization"],' \
'    ["Istio","OpenShift Service Mesh"],' \
'    ["Knative","OpenShift Serverless"],' \
'    ["Keycloak","Red Hat Single Sign-On"],' \
'  ]);' \
'' \
'  function paint() {' \
'    // Match tiles by their accessible label or title (Landscape2 sets those to the item name).' \
'    const nodes = document.querySelectorAll("[title], [aria-label]");' \
'    nodes.forEach(el => {' \
'      const name = (el.getAttribute("aria-label") || el.getAttribute("title") || "").trim();' \
'      if (!name || !RH_MAP.has(name)) return;' \
'      // Colorize the surrounding clickable card container if present, otherwise the element itself' \
'      const card = el.closest("a, button, div") || el;' \
'      card.style.setProperty("--rh-bg", RH_COLOR);' \
'      card.style.background = "var(--rh-bg)";' \
'      card.style.color = "white";' \
'      card.style.borderRadius = "8px";' \
'      card.style.boxShadow = "0 0 0 2px rgba(0,0,0,.05)";' \
'      // Tooltip: show product name on hover' \
'      const product = RH_MAP.get(name);' \
'      el.setAttribute("title", product);' \
'      el.setAttribute("aria-label", `${name} — ${product}`);' \
'      // Optional inline badge' \
'      if (!card.querySelector(".rh-badge")) {' \
'        const b = document.createElement("span");' \
'        b.className = "rh-badge";' \
'        b.textContent = "Red Hat";' \
'        b.style.cssText = "margin-left:.5rem;padding:.1rem .35rem;border-radius:.35rem;background:rgba(255,255,255,.2);font-size:.75rem;";' \
'        (card.querySelector("span, h3, h4") || card).appendChild(b);' \
'      }' \
'    });' \
'  }' \
'' \
'  // Re-run after route changes/renders using a MutationObserver' \
'  const mo = new MutationObserver(() => { requestAnimationFrame(paint); });' \
'  mo.observe(document.documentElement, {childList:true, subtree:true});' \
'  window.addEventListener("load", paint);' \
'})();' \
> /opt/app-root/src/custom.js \
&& sed -i "s#</head>#  <script src=\"/custom.js\"></script>\n</head>#g" /opt/app-root/src/index.html

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

