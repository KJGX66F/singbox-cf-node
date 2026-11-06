# CF + sing-box + decoy-site VLESS node — single container.
# Front door: Caddy serves a normal-looking website on every path
# except the secret WS path, which it reverse-proxies to sing-box.
# Intended to sit behind Cloudflare (orange-cloud proxied) so the
# public endpoint looks and behaves like an ordinary website.
FROM ghcr.io/sagernet/sing-box:v1.14.4 AS singbox
FROM caddy:2.11.9-alpine AS caddyimg

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY --from=singbox /usr/local/bin/sing-box /usr/local/bin/sing-box
COPY --from=caddyimg /usr/bin/caddy /usr/local/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY site/ /srv/site/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]
