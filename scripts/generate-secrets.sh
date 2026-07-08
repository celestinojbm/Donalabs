#!/usr/bin/env bash
# =============================================================================
# DonaLabs — secret generator
#
# Creates .env from .env.example (if missing) and fills every placeholder
# secret (value "GENERATE" or empty) with a strong random value.
#
# Idempotent: values that are already set are left untouched, so it is safe to
# re-run after adding a new service to .env.example.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
EXAMPLE_FILE="${REPO_ROOT}/.env.example"

command -v openssl >/dev/null 2>&1 || { echo "error: openssl is required" >&2; exit 1; }

if [ ! -f "$ENV_FILE" ]; then
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  echo "Created .env from .env.example"
fi

# --- secret generators ---------------------------------------------------
gen_b64()  { openssl rand -base64 "$1" | tr -d '\n'; }
gen_hex()  { openssl rand -hex "$1" | tr -d '\n'; }
gen_penpot_key() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets; print(secrets.token_urlsafe(64))"
  else
    gen_b64 48
  fi
}

# Map of VAR -> generator invocation (evaluated only when the var is a placeholder).
declare -A SECRETS=(
  [VW_ADMIN_TOKEN]="gen_b64 48"
  [CALCOM_DB_PASSWORD]="gen_hex 24"
  [CALCOM_NEXTAUTH_SECRET]="gen_b64 32"
  [CALCOM_ENCRYPTION_KEY]="gen_b64 24"
  [PLAUSIBLE_SECRET_KEY_BASE]="gen_b64 48"
  [PLAUSIBLE_TOTP_VAULT_KEY]="gen_b64 32"
  [PLAUSIBLE_DB_PASSWORD]="gen_hex 24"
  [PENPOT_SECRET_KEY]="gen_penpot_key"
  [PENPOT_DB_PASSWORD]="gen_hex 24"
  [N8N_ENCRYPTION_KEY]="gen_hex 32"
  [N8N_DB_PASSWORD]="gen_hex 24"
  [OPENWEBUI_SECRET_KEY]="gen_hex 32"
)

# Vars whose value must be single-quoted in the .env file (may contain '$').
declare -A SINGLE_QUOTE=( [VW_ADMIN_TOKEN]=1 )

is_placeholder() {
  # strip optional surrounding single/double quotes
  local v="$1"
  v="${v%\'}"; v="${v#\'}"
  v="${v%\"}"; v="${v#\"}"
  [ -z "$v" ] || [ "$v" = "GENERATE" ]
}

TMP="$(mktemp)"
changed=0
while IFS= read -r line || [ -n "$line" ]; do
  # Only touch simple KEY=VALUE lines whose KEY is a known secret.
  if [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    if [ -n "${SECRETS[$key]+x}" ] && is_placeholder "$val"; then
      newval="$(${SECRETS[$key]})"
      if [ -n "${SINGLE_QUOTE[$key]+x}" ]; then
        printf "%s='%s'\n" "$key" "$newval" >> "$TMP"
      else
        printf "%s=%s\n" "$key" "$newval" >> "$TMP"
      fi
      echo "  generated $key" >&2
      changed=$((changed+1))
      continue
    fi
  fi
  printf '%s\n' "$line" >> "$TMP"
done < "$ENV_FILE"

# Preserve permissions, replace atomically, lock down the file.
cat "$TMP" > "$ENV_FILE"
rm -f "$TMP"
chmod 600 "$ENV_FILE"

if [ "$changed" -gt 0 ]; then
  echo "Filled $changed secret(s) in .env (file permissions set to 600)."
else
  echo "No placeholders found — all secrets already set. (.env permissions set to 600)"
fi
