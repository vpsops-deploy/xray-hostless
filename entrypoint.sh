#!/bin/sh
set -eu
PORT="${PORT:-8080}"
UUID="${UUID:?UUID env required}"
WSPATH="${WSPATH:-/ws}"
TRANSPORT="${TRANSPORT:-ws}"
case "$WSPATH" in /*) ;; *) WSPATH="/$WSPATH" ;; esac
# escape path for nginx location (no regex specials expected)
export PORT WSPATH
envsubst '${PORT} ${WSPATH}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

if [ "$TRANSPORT" = "xhttp" ]; then
  STREAM=$(cat <<JSON
    "streamSettings": {
      "network": "xhttp",
      "security": "none",
      "xhttpSettings": {"path": "${WSPATH}", "mode": "packet-up"}
    }
JSON
)
else
  STREAM=$(cat <<JSON
    "streamSettings": {
      "network": "ws",
      "security": "none",
      "wsSettings": {"path": "${WSPATH}"}
    }
JSON
)
fi

cat > /etc/xray/config.json <<JSON
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "listen": "127.0.0.1",
    "port": 10000,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "${UUID}"}],
      "decryption": "none"
    },
${STREAM}
  }],
  "outbounds": [{"protocol": "freedom", "settings": {}}]
}
JSON

echo "starting xray on 127.0.0.1:10000 transport=${TRANSPORT} path=${WSPATH}; nginx on :${PORT}"
/usr/local/bin/xray run -c /etc/xray/config.json &
XRAY_PID=$!
nginx -g 'daemon off;' &
NGINX_PID=$!
trap 'kill $XRAY_PID $NGINX_PID 2>/dev/null || true' TERM INT
wait -n $XRAY_PID $NGINX_PID
EXIT=$?
kill $XRAY_PID $NGINX_PID 2>/dev/null || true
exit $EXIT
