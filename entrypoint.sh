#!/bin/sh
# Render xray entrypoint — generates the xray config at container start from
# environment variables, then runs xray. Per DEPLOY_MEMORY.md §5 route B.
#
# Required env:
#   PORT     — provided by Render, never hardcoded (Render injects it; default 10000)
#   UUID     — VLESS client id (set as a Render variable; never bake into image)
# Optional env:
#   WS_PATH  — WebSocket path, default /railway-vless (kept from credentials)
#   XRAY_BIN — xray binary path, default /usr/local/bin/xray
#   XRAY_CONFIG — where to write the generated config, default /tmp/xray/config.json
#
# Render's load balancer terminates TLS (*.onrender.com :443) and forwards plain
# HTTP to $PORT, so the inbound is plain WS here; the client uses wss:// on 443.

set -eu

: "${PORT:?PORT is required (Render provides it)}"
: "${UUID:?UUID is required (set as a Render variable)}"
WS_PATH="${WS_PATH:-/railway-vless}"
XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"
XRAY_CONFIG="${XRAY_CONFIG:-/tmp/xray/config.json}"

# Basic sanity: PORT must be numeric, WS_PATH must start with /
case "$PORT" in
  ''|*[!0-9]*) echo "error: PORT must be numeric, got '$PORT'" >&2; exit 1 ;;
esac
case "$WS_PATH" in
  /*) ;;
  *) echo "error: WS_PATH must start with /, got " >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$XRAY_CONFIG")"

cat > "$XRAY_CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "$WS_PATH" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "blocked" }
  ]
}
EOF

# Validate the generated config before serving traffic; aborts the container
# loudly on a bad config instead of boot-looping silently.
"$XRAY_BIN" run -test -c "$XRAY_CONFIG"

echo "xray config OK: VLESS+WS on 0.0.0.0:$PORT path $WS_PATH"
exec "$XRAY_BIN" run -c "$XRAY_CONFIG"
