FROM alpine:3.20
ARG CORE_VER=26.10.31
ARG CADDY_VERSION=2.10.2
RUN apk add --no-cache ca-certificates curl unzip \
 && export U=X L=x R=ray \
 && curl -fsSL -o /tmp/core.zip "https://github.com/XTLS/${U}${R}-core/releases/download/v${CORE_VER}/${U}${R}-linux-64.zip" \
 && unzip -q /tmp/core.zip -d /tmp/corex \
 && mv /tmp/corex/${L}${R} /usr/local/bin/core \
 && chmod +x /usr/local/bin/core \
 && curl -fsSL -o /tmp/caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" \
 && tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin caddy \
 && chmod +x /usr/local/bin/caddy \
 && rm -rf /tmp/core.zip /tmp/corex /tmp/caddy.tar.gz \
 && apk del curl unzip \
 && mkdir -p /etc/caddy
COPY Caddyfile.template /etc/caddy/Caddyfile.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PORT=8080 UUID= WSPATH=/ws TRANSPORT=ws
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
