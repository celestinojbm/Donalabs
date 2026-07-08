#!/usr/bin/env bash
# =============================================================================
# DonaLabs — update services to the image tags currently pinned in .env
#
#   ./update.sh                update everything (backup first, then pull + recreate)
#   ./update.sh n8n            update only the named service(s)
#   ./update.sh --no-backup    skip the pre-update backup
#
# To upgrade a service, bump its *_IMAGE_TAG in .env, then run this script.
# Always review each project's release notes before a major version bump.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/scripts/lib.sh"

require_docker
require_env
ensure_network

DO_BACKUP=1
if [ "${1:-}" = "--no-backup" ]; then DO_BACKUP=0; shift; fi

if [ "$DO_BACKUP" -eq 1 ]; then
  info "taking a safety backup before updating..."
  "${DONALABS_ROOT}/backup.sh" || warn "backup failed — continuing (use --no-backup to skip intentionally)"
fi

info "pulling images..."
dc pull "$@"

info "recreating containers with the new images..."
dc up -d "$@"

info "pruning dangling images..."
docker image prune -f >/dev/null 2>&1 || true

ok "update complete. Verify with: ./scripts/health.sh"
