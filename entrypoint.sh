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

WS_PATH="${WS_PATH:-/ray}"
case "$WS_PATH" in
  /*) ;;
  *) WS_PATH="/$WS_PATH" ;;
esac
WS_PATH=$(printf '%s' "$WS_PATH" | tr -cd 'A-Za-z0-9/._-')
[ -z "$WS_PATH" ] && WS_PATH="/ray"
PORT="${PORT:-3000}"
export WS_PATH PORT

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

echo "starting sing-box (loopback) + caddy on :${PORT}, ws path ${WS_PATH}"
sing-box run -c /etc/sing-box/config.json &
SB_PID=$!
trap 'kill $SB_PID 2>/dev/null || true' TERM INT EXIT
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
