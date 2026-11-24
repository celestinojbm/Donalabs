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

# One .env line -> ENV_LINE_KEY / ENV_LINE_VAL, the way Docker Compose reads it,
# so the scripts see the same values as the containers (checked against
# `docker compose config` in tests/lib.test.sh). Returns 1 for blank lines,
# comments and anything that is not KEY=VALUE. Never shell-evaluates the value.
#   * CRLF line endings, leading indentation, an `export ` prefix and spaces
#     around `=` are accepted.
#   * Unquoted value: surrounding whitespace is trimmed and an inline comment
#     (` #` and everything after it) is dropped; `a#b` stays `a#b`.
#   * 'single quotes': literal up to the closing quote.
#   * "double quotes": up to the closing quote, with \\ \" \n \t \r \$ escapes.
#   * Whatever follows the closing quote (e.g. a comment) is ignored.
# Not supported (Compose does them, these scripts do not): ${VAR} interpolation
# inside values and multi-line quoted values. An unterminated quote, which makes
# Compose itself refuse the file, is kept literally.
env_parse_line() {
  local line="${1%$'\r'}" val out="" c i
  [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]] || return 1
  ENV_LINE_KEY="${BASH_REMATCH[2]}"
  val="${BASH_REMATCH[3]}"
  val="${val#"${val%%[![:space:]]*}"}"
  case "$val" in
    \'*\'*)
      val="${val#\'}"; val="${val%%\'*}" ;;
    \"*)
      for (( i = 1; i < ${#val}; i++ )); do
        c="${val:i:1}"
        if [ "$c" = '"' ]; then ENV_LINE_VAL="$out"; return 0; fi
        if [ "$c" = "\\" ] && [ $(( i + 1 )) -lt ${#val} ]; then
          i=$(( i + 1 ))
          case "${val:i:1}" in
            n) c=$'\n' ;; t) c=$'\t' ;; r) c=$'\r' ;;
            "\\"|'"'|'$') c="${val:i:1}" ;;
            *) c="\\${val:i:1}" ;;
          esac
        fi
        out+="$c"
      done
      val="${val%"${val##*[![:space:]]}"}" ;;   # unterminated: literal
    *)
      val="${val%% #*}"
      val="${val%"${val##*[![:space:]]}"}" ;;
  esac
  ENV_LINE_VAL="$val"
}

# Load .env into the environment WITHOUT shell-evaluating it (values may contain
# spaces, e.g. PENPOT_FLAGS), parsed by env_parse_line. Last assignment wins.
load_env() {
  require_env
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    env_parse_line "$line" || continue
    export "$ENV_LINE_KEY=$ENV_LINE_VAL"
  done < "$ENV_FILE"
}

# Print the value KEY has in env FILE, parsed as load_env does (env_parse_line,
# last assignment wins), so two copies of the same .env that differ only in
# format compare equal. Returns 1 (prints nothing) if KEY is not assigned in FILE.
#   if v="$(env_get "$f" KEY)"; then ...; fi     # never bare under set -e
env_get() {
  local file="$1" want="$2" line found=1 out=""
  while IFS= read -r line || [ -n "$line" ]; do
    env_parse_line "$line" || continue
    [ "$ENV_LINE_KEY" = "$want" ] || continue
    out="$ENV_LINE_VAL" found=0
  done < "$file"
  [ "$found" -eq 0 ] && printf '%s' "$out"
  return "$found"
}

# --- shared network ----------------------------------------------------------
# EDGE_NETWORK from .env, or the default when it is unset, empty or there is no
# .env yet. Parsed like Compose does: a CRLF .env must not yield "name\r".
edge_network() {
  local net=""
  [ -f "$ENV_FILE" ] && net="$(env_get "$ENV_FILE" EDGE_NETWORK)" || true
  printf '%s\n' "${net:-donalabs_edge}"
}

ensure_network() {
  local net; net="$(edge_network)"
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
