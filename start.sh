#!/usr/bin/env bash
# =============================================================================
# DonaLabs — start services
#
#   ./start.sh                 start every service
#   ./start.sh n8n vaultwarden start only the named services (+ dependencies)
#
# Creates the shared network and verifies .env exists first.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/scripts/lib.sh"

require_docker
require_env
ensure_network

if [ "$#" -gt 0 ]; then
  info "starting: $*"
  dc up -d "$@"
else
  info "starting all DonaLabs services..."
  dc up -d
fi

echo
ok "Services started. Current status:"
dc ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || dc ps

echo
info "Access URLs (default local binding on 127.0.0.1):"
load_env
cat <<EOF
  Vaultwarden (passwords)   ${VW_DOMAIN:-http://localhost:8200}
  Cal.com     (scheduling)  ${CALCOM_WEBAPP_URL:-http://localhost:3000}
  Plausible   (analytics)   ${PLAUSIBLE_BASE_URL:-http://localhost:8210}
  Penpot      (design)      ${PENPOT_PUBLIC_URI:-http://localhost:9001}
  n8n         (automation)  ${N8N_WEBHOOK_URL:-http://localhost:5678/}
  Open WebUI  (AI)          http://localhost:${OPENWEBUI_HOST_PORT:-3001}

  Health check:  ./scripts/health.sh
  yt-dlp:        ./services/ytdlp/ytdlp.sh help
EOF
