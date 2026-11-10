#!/usr/bin/env python3
"""Bootstrap Xray+Caddy in a non-root HostKB container (writable /tmp only)."""
import os, sys, urllib.request, zipfile, tarfile, subprocess, time

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
        t.extract("caddy")
    os.chmod("caddy", 0o755)
    os.remove("c.tgz")

open("Caddyfile", "w").write("""{
  admin off
  auto_https off
  persist_config off
}
:%s {
  handle /healthz { respond "ok" 200 }
  handle %s { reverse_proxy 127.0.0.1:10000 }
  handle %s/* { reverse_proxy 127.0.0.1:10000 }
  handle / { respond "ok" 200 }
  respond 404
}
""" % (PORT, WSPATH, WSPATH))

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
os.execv("./caddy", ["./caddy", "run", "--config", "Caddyfile", "--adapter", "caddyfile"])
