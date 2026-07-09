#!/usr/bin/env bash
# =============================================================================
# DonaLabs — shared shell helpers, sourced by the top-level scripts.
# =============================================================================
set -euo pipefail

# Resolve the repo root regardless of where a script is invoked from.
DONALABS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DONALABS_ROOT
ENV_FILE="${DONALABS_ROOT}/.env"

# --- pretty output -----------------------------------------------------------
if [ -t 1 ]; then
  C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RED='\033[0;31m'; C_BLUE='\033[0;34m'; C_RESET='\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_BLUE=''; C_RESET=''
fi
info()  { printf "${C_BLUE}▸ %s${C_RESET}\n" "$*"; }
ok()    { printf "${C_GREEN}✓ %s${C_RESET}\n" "$*"; }
warn()  { printf "${C_YELLOW}! %s${C_RESET}\n" "$*"; }
err()   { printf "${C_RED}✗ %s${C_RESET}\n" "$*" >&2; }

# --- preconditions -----------------------------------------------------------
require_docker() {
  command -v docker >/dev/null 2>&1 || { err "docker is not installed"; exit 1; }
  docker compose version >/dev/null 2>&1 || { err "docker compose v2 is required"; exit 1; }
  docker info >/dev/null 2>&1 || { err "cannot reach the Docker daemon (is it running?)"; exit 1; }
}

require_env() {
  if [ ! -f "$ENV_FILE" ]; then
    err "no .env found. Run: ./scripts/generate-secrets.sh"
    exit 1
  fi
}

# Load .env into the environment WITHOUT shell-evaluating it (values may contain
# spaces, e.g. PENPOT_FLAGS). Mirrors how Compose parses .env: literal KEY=VALUE.
load_env() {
  require_env
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    # strip one layer of surrounding single or double quotes
    case "$val" in
      \"*\") val="${val%\"}"; val="${val#\"}" ;;
      \'*\') val="${val%\'}"; val="${val#\'}" ;;
    esac
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && export "$key=$val"
  done < "$ENV_FILE"
}

# --- shared network ----------------------------------------------------------
edge_network() { grep -E '^EDGE_NETWORK=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2 || echo "donalabs_edge"; }

ensure_network() {
  local net; net="$(edge_network)"; net="${net:-donalabs_edge}"
  if ! docker network inspect "$net" >/dev/null 2>&1; then
    docker network create "$net" >/dev/null
    ok "created shared network '$net'"
  fi
}

# --- compose wrapper (always runs from repo root, uses root .env) -------------
dc() { ( cd "$DONALABS_ROOT" && docker compose "$@" ); }

# --- service metadata --------------------------------------------------------
# Postgres databases as "container:user_var:db_var".
# shellcheck disable=SC2034  # consumed by backup.sh / restore.sh which source this file
PG_DATABASES=(
  "donalabs-calcom-db:CALCOM_DB_USER:CALCOM_DB_NAME"
  "donalabs-plausible-db:PLAUSIBLE_DB_USER:PLAUSIBLE_DB_NAME"
  "donalabs-penpot-db:PENPOT_DB_USER:PENPOT_DB_NAME"
  "donalabs-n8n-db:N8N_DB_USER:N8N_DB_NAME"
)

# Named data volumes to snapshot (Postgres data is captured via pg_dump instead).
# shellcheck disable=SC2034  # consumed by backup.sh / restore.sh which source this file
DATA_VOLUMES=(
  "donalabs_vaultwarden_data"
  "donalabs_open_webui_data"
  "donalabs_n8n_data"
  "donalabs_penpot_assets"
  "donalabs_plausible_data"
  "donalabs_plausible_event_data"
)

# Health probes as "label|url" (checked from the host against published ports).
health_targets() {
  load_env
  cat <<EOF
vaultwarden|http://127.0.0.1:${VW_HOST_PORT:-8200}/alive
calcom|http://127.0.0.1:${CALCOM_HOST_PORT:-3000}/auth/login
plausible|http://127.0.0.1:${PLAUSIBLE_HOST_PORT:-8210}/api/health
penpot|http://127.0.0.1:${PENPOT_HOST_PORT:-9001}/readyz
n8n|http://127.0.0.1:${N8N_HOST_PORT:-5678}/healthz
open-webui|http://127.0.0.1:${OPENWEBUI_HOST_PORT:-3001}/health
EOF
}
