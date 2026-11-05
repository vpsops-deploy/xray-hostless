FROM alpine:3.20
ARG XRAY_VERSION=26.10.31
RUN apk add --no-cache ca-certificates curl unzip nginx gettext \
 && curl -fsSL -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" \
 && unzip /tmp/xray.zip xray -d /usr/local/bin \
 && chmod +x /usr/local/bin/xray \
 && rm -f /tmp/xray.zip \
 && apk del curl unzip \
 && mkdir -p /run/nginx /etc/xray
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PORT=8080 UUID= WSPATH=/ws TRANSPORT=ws
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
