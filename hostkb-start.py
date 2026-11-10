#!/usr/bin/env python3
"""Bootstrap Xray+Caddy in a non-root HostKB container (writable /tmp only)."""
import json, os, sys, urllib.request, zipfile, tarfile, subprocess, time

PORT = os.environ.get("PORT", "8080")
UUID = os.environ.get("UUID") or sys.exit("UUID required")
WSPATH = os.environ.get("WSPATH", "/ws")
if not WSPATH.startswith("/"):
    WSPATH = "/" + WSPATH
TRANSPORT = os.environ.get("TRANSPORT", "ws")
DIR = "/tmp/xr"
os.makedirs(DIR, exist_ok=True)
os.chdir(DIR)

arch = os.uname().machine
if arch == "x86_64":
    xa, ca = "64", "amd64"
elif arch in ("aarch64", "arm64"):
    xa, ca = "arm64-v8a", "arm64"
else:
    sys.exit("unsupported arch: " + arch)

def fetch(url, dest):
    print("fetch", url, flush=True)
    urllib.request.urlretrieve(url, dest)

if not os.access("xray", os.X_OK):
    fetch("https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-linux-%s.zip" % xa, "x.zip")
    with zipfile.ZipFile("x.zip") as z:
        z.extract("xray")
    os.chmod("xray", 0o755)
    os.remove("x.zip")

if not os.access("caddy", os.X_OK):
    fetch("https://github.com/caddyserver/caddy/releases/download/v2.10.2/caddy_2.10.2_linux_%s.tar.gz" % ca, "c.tgz")
    with tarfile.open("c.tgz") as t:
        t.extract("caddy", filter="data")
    os.chmod("caddy", 0o755)
    os.remove("c.tgz")

# JSON config avoids Caddyfile adapter parse errors seen on this image.
cfg = {
    "admin": {"disabled": True},
    "apps": {
        "http": {
            "servers": {
                "srv0": {
                    "listen": [":" + str(PORT)],
                    "automatic_https": {"disable": True},
                    "routes": [
                        {
                            "match": [{"path": ["/healthz"]}],
                            "handle": [{"handler": "static_response", "status_code": 200, "body": "ok"}],
                        },
                        {
                            "match": [{"path": [WSPATH, WSPATH + "/"]}],
                            "handle": [{"handler": "reverse_proxy", "upstreams": [{"dial": "127.0.0.1:10000"}]}],
                        },
                        {
                            "match": [{"path": ["/"]}],
                            "handle": [{"handler": "static_response", "status_code": 200, "body": "ok"}],
                        },
                    ],
                }
            }
        }
    },
}
open("caddy.json", "w").write(json.dumps(cfg))
print("wrote caddy.json listen=:" + str(PORT) + " path=" + WSPATH, flush=True)

if TRANSPORT == "xhttp":
    stream = '"streamSettings":{"network":"xhttp","security":"none","xhttpSettings":{"path":"%s","mode":"packet-up"}}' % WSPATH
else:
    stream = '"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"%s"}}' % WSPATH

open("config.json", "w").write(
    '{"log":{"loglevel":"warning"},"inbounds":[{"listen":"127.0.0.1","port":10000,"protocol":"vless","settings":{"clients":[{"id":"%s"}],"decryption":"none"},%s}],"outbounds":[{"protocol":"freedom","settings":{}}]}'
    % (UUID, stream)
)

print("starting xray+caddy transport=%s path=%s port=%s" % (TRANSPORT, WSPATH, PORT), flush=True)
xray = subprocess.Popen(["./xray", "run", "-c", "config.json"])
time.sleep(1)
if xray.poll() is not None:
    sys.exit("xray exited %s" % xray.returncode)
os.execv("./caddy", ["./caddy", "run", "--config", "caddy.json"])
