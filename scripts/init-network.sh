#!/usr/bin/env bash
# =============================================================================
# DonaLabs — create the shared external Docker network.
# Other projects attach their containers to this network to consume DonaLabs
# services by name (e.g. http://vaultwarden:80, http://n8n:5678).
# Safe to run repeatedly. ./start.sh calls this automatically.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/lib.sh"
require_docker
ensure_network
ok "shared network ready: $(edge_network)"
