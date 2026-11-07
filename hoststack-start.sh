#!/bin/bash
set -euo pipefail
PORT="${PORT:-8080}"; UUID="${UUID:?UUID required}"; WSPATH="${WSPATH:-/ws}"; TRANSPORT="${TRANSPORT:-ws}"
case "$WSPATH" in /*) ;; *) WSPATH="/$WSPATH";; esac
DIR=/tmp/xr; mkdir -p "$DIR"; cd "$DIR"
need() { command -v "$1" >/dev/null 2>&1 || return 1; }
if ! need curl || ! need unzip || ! need tar; then
  if need apk; then apk add --no-cache curl unzip tar ca-certificates
  elif need apt-get; then apt-get update -y && apt-get install -y curl unzip tar ca-certificates
  fi
fi
arch=$(uname -m)
case "$arch" in x86_64) XA=64; CA=amd64;; aarch64|arm64) XA=arm64-v8a; CA=arm64;; *) echo badarch; exit 1;; esac
if [ ! -x ./xray ]; then
  curl -fsSL -o x.zip "https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-linux-${XA}.zip"
  unzip -o x.zip xray; chmod +x xray
fi
if [ ! -x ./caddy ]; then
  curl -fsSL -o c.tgz "https://github.com/caddyserver/caddy/releases/download/v2.10.2/caddy_2.10.2_linux_${CA}.tar.gz"
  tar -xzf c.tgz caddy; chmod +x caddy
fi
cat > Caddyfile <<EOC
{
  admin off
  auto_https off
  persist_config off
}
:${PORT} {
  handle /healthz { respond "ok" 200 }
  handle ${WSPATH} { reverse_proxy 127.0.0.1:10000 }
  handle ${WSPATH}/* { reverse_proxy 127.0.0.1:10000 }
  handle / { respond "ok" 200 }
  respond 404
}
EOC
if [ "$TRANSPORT" = xhttp ]; then
  STREAM='"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"'"$WSPATH"'","mode":"packet-up"}}'
else
  STREAM='"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"'"$WSPATH"'"}}'
fi
cat > config.json <<EOJ
{"log":{"loglevel":"warning"},"inbounds":[{"listen":"127.0.0.1","port":10000,"protocol":"vless","settings":{"clients":[{"id":"$UUID"}],"decryption":"none"},$STREAM}],"outbounds":[{"protocol":"freedom","settings":{}}]}
EOJ
./xray run -c config.json &
exec ./caddy run --config Caddyfile --adapter caddyfile
