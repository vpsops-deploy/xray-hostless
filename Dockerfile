FROM alpine:3.20
ARG XRAY_VERSION=26.10.31
ARG CADDY_VERSION=2.10.2
# DormHost (and other small PaaS) build on aarch64. Download the matching release.
RUN set -eux; \
    apk add --no-cache ca-certificates curl unzip; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64) XRAY_ARCH=64; CADDY_ARCH=amd64 ;; \
      aarch64|arm64) XRAY_ARCH=arm64-v8a; CADDY_ARCH=arm64 ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    echo "arch=$arch xray=Xray-linux-${XRAY_ARCH} caddy=linux_${CADDY_ARCH}"; \
    curl -fsSL -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"; \
    unzip /tmp/xray.zip xray -d /usr/local/bin; \
    chmod +x /usr/local/bin/xray; \
    curl -fsSL -o /tmp/caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_${CADDY_ARCH}.tar.gz"; \
    tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin caddy; \
    chmod +x /usr/local/bin/caddy; \
    rm -f /tmp/xray.zip /tmp/caddy.tar.gz; \
    apk del curl unzip; \
    mkdir -p /etc/caddy
COPY Caddyfile.template /etc/caddy/Caddyfile.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PORT=8080 UUID= WSPATH=/ws TRANSPORT=ws
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
