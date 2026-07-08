#!/usr/bin/env bash
# =============================================================================
# DonaLabs — stop services
#
#   ./stop.sh              stop all containers (data volumes are preserved)
#   ./stop.sh n8n          stop only the named service(s)
#   ./stop.sh --down       stop AND remove containers/networks (volumes kept)
#
# Data in named volumes is never touched by this script.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/scripts/lib.sh"

require_docker
require_env

if [ "${1:-}" = "--down" ]; then
  shift
  info "removing containers and networks (named volumes are preserved)..."
  dc down "$@"
  ok "stack down. Volumes kept — run ./start.sh to bring it back."
else
  if [ "$#" -gt 0 ]; then
    info "stopping: $*"
    dc stop "$@"
  else
    info "stopping all DonaLabs services..."
    dc stop
  fi
  ok "stopped. Data preserved. Run ./start.sh to resume."
fi
