#!/bin/sh
set -eu
PORT="${PORT:-8080}"
UUID="${UUID:?UUID env required}"
WSPATH="${WSPATH:-/ws}"
TRANSPORT="${TRANSPORT:-ws}"
case "$WSPATH" in /*) ;; *) WSPATH="/$WSPATH" ;; esac

# Hostless root filesystem is read-only; only /tmp is writable.
CONF_DIR="/tmp/xray-runtime"
mkdir -p "$CONF_DIR" /tmp/nginx-logs
export PORT WSPATH
envsubst '${PORT} ${WSPATH}' < /etc/nginx/nginx.conf.template > "$CONF_DIR/nginx.conf"

# Point nginx temp/log paths into /tmp (template uses /dev/stdout already for access)
# Ensure pid path is writable
sed -i 's|pid /tmp/nginx.pid;|pid '"$CONF_DIR"'/nginx.pid;|' "$CONF_DIR/nginx.conf" 2>/dev/null || true

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

cat > "$CONF_DIR/config.json" <<JSON
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

echo "starting xray on 127.0.0.1:10000 transport=${TRANSPORT} path=${WSPATH}; nginx on 0.0.0.0:${PORT}"
/usr/local/bin/xray run -c "$CONF_DIR/config.json" &
XRAY_PID=$!
nginx -c "$CONF_DIR/nginx.conf" -g 'daemon off;' &
NGINX_PID=$!
trap 'kill $XRAY_PID $NGINX_PID 2>/dev/null || true' TERM INT
wait -n $XRAY_PID $NGINX_PID
EXIT=$?
kill $XRAY_PID $NGINX_PID 2>/dev/null || true
exit $EXIT
