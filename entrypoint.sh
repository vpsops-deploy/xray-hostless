#!/bin/sh
set -eu
PORT="${PORT:-8080}"
UUID="${UUID:?UUID env required}"
WSPATH="${WSPATH:-/ws}"
TRANSPORT="${TRANSPORT:-ws}"
case "$WSPATH" in /*) ;; *) WSPATH="/$WSPATH" ;; esac

CONF_DIR="/tmp/xray-runtime"
mkdir -p "$CONF_DIR"
export PORT WSPATH
# Caddy uses {$VAR} in Caddyfile
sed -e "s|\${PORT}|${PORT}|g" -e "s|\${WSPATH}|${WSPATH}|g" /etc/caddy/Caddyfile.template > "$CONF_DIR/Caddyfile"

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

echo "starting xray on 127.0.0.1:10000 transport=${TRANSPORT} path=${WSPATH}; caddy on 0.0.0.0:${PORT}"
/usr/local/bin/xray run -c "$CONF_DIR/config.json" &
XRAY_PID=$!
/usr/local/bin/caddy run --config "$CONF_DIR/Caddyfile" --adapter caddyfile &
CADDY_PID=$!
trap 'kill $XRAY_PID $CADDY_PID 2>/dev/null || true' TERM INT
wait -n $XRAY_PID $CADDY_PID
EXIT=$?
kill $XRAY_PID $CADDY_PID 2>/dev/null || true
exit $EXIT
