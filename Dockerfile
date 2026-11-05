FROM alpine:3.20
ARG XRAY_VERSION=26.10.31
ARG CADDY_VERSION=2.10.2
RUN apk add --no-cache ca-certificates curl unzip \
 && curl -fsSL -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" \
 && unzip /tmp/xray.zip xray -d /usr/local/bin \
 && chmod +x /usr/local/bin/xray \
 && curl -fsSL -o /tmp/caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" \
 && tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin caddy \
 && chmod +x /usr/local/bin/caddy \
 && rm -f /tmp/xray.zip /tmp/caddy.tar.gz \
 && apk del curl unzip \
 && mkdir -p /etc/caddy
COPY Caddyfile.template /etc/caddy/Caddyfile.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PORT=8080 UUID= WSPATH=/ws TRANSPORT=ws
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
