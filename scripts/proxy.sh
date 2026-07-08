#!/usr/bin/env bash
# =============================================================================
# DonaLabs — control the optional Caddy reverse proxy.
#
#   ./scripts/proxy.sh up        start Caddy (single HTTPS entrypoint)
#   ./scripts/proxy.sh down       stop and remove Caddy
#   ./scripts/proxy.sh validate   check the Caddyfile syntax
#   ./scripts/proxy.sh logs       follow Caddy logs
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/lib.sh"

require_docker
require_env
PROXY_COMPOSE="${DONALABS_ROOT}/proxy/docker-compose.yml"

case "${1:-}" in
  up)
    ensure_network
    docker compose -f "$PROXY_COMPOSE" --env-file "$ENV_FILE" up -d
    ok "Caddy started. Configured hostnames come from CADDY_* in .env."
    ;;
  down)
    docker compose -f "$PROXY_COMPOSE" --env-file "$ENV_FILE" down
    ok "Caddy stopped."
    ;;
  validate)
    docker run --rm -v "${DONALABS_ROOT}/proxy/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
      "caddy:$(grep -E '^CADDY_IMAGE_TAG=' "$ENV_FILE" | cut -d= -f2 || echo 2-alpine)" \
      caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    ;;
  logs)
    docker compose -f "$PROXY_COMPOSE" --env-file "$ENV_FILE" logs -f
    ;;
  *)
    echo "usage: ./scripts/proxy.sh {up|down|validate|logs}"; exit 1 ;;
esac
