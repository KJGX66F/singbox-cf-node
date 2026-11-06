#!/bin/sh
# Render the sing-box config from environment, then run:
#   sing-box (VLESS+WS) on 127.0.0.1:10000  — never exposed directly
#   Caddy on :$PORT                          — the public front door
# Required env: UUID (no default — fail fast if missing).
# Optional env: WS_PATH (default /ray), PORT (default 3000).
set -eu

if [ -z "${UUID:-}" ]; then
  echo "FATAL: UUID env var is required" >&2
  exit 1
fi
# A malformed UUID would make sing-box refuse to start while the decoy site
# keeps working — a very confusing failure. Fail fast with a clear message.
if ! printf '%s' "$UUID" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; then
  echo "FATAL: UUID env var is not a valid UUID: ${UUID}" >&2
  exit 1
fi

WS_PATH="${WS_PATH:-/ray}"
case "$WS_PATH" in
  /*) ;;
  *) WS_PATH="/$WS_PATH" ;;
esac
WS_PATH=$(printf '%s' "$WS_PATH" | tr -cd 'A-Za-z0-9/._-')
[ -z "$WS_PATH" ] && WS_PATH="/ray"
PORT="${PORT:-3000}"

# Subscription page path: the UUID itself is the suffix — it is already the
# node's key, so there is nothing extra to set or remember. Whoever opens
# https://<host>/<UUID> gets a page that assembles the full vless:// import
# link. (The full path is deliberately NOT printed in the boot log.)
SUB_PATH="/${UUID}"
export WS_PATH PORT SUB_PATH

mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<EOF
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "127.0.0.1",
      "listen_port": 10000,
      "tcp_fast_open": true,
      "users": [ { "uuid": "${UUID}" } ],
      "transport": { "type": "ws", "path": "${WS_PATH}", "early_data_header_name": "Sec-WebSocket-Protocol" }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct", "tcp_fast_open": true } ]
}
EOF

# Render the subscription page under the secret suffix (a plain static page,
# indistinguishable from a blog sub-page; it assembles the link in the
# browser from the current host + the baked-in UUID/WS path).
mkdir -p "/srv/site${SUB_PATH}"
sed -e "s/__UUID__/${UUID}/g" -e "s|__WS_PATH__|${WS_PATH}|g" \
  /app/sub-template.html > "/srv/site${SUB_PATH}/index.html"

echo "starting sing-box (loopback) + caddy on :${PORT}, ws path ${WS_PATH}"
echo "subscription page ready (its path is /<your UUID>)"
sing-box run -c /etc/sing-box/config.json &
SB_PID=$!
trap 'kill $SB_PID 2>/dev/null || true' TERM INT EXIT
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
