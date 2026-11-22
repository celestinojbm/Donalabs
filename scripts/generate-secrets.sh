#!/usr/bin/env bash
# =============================================================================
# DonaLabs — secret generator
#
# Creates .env from .env.example (if missing) and fills every placeholder
# secret (value "GENERATE" or empty) with a strong random value.
#
# Idempotent: values that are already set are left untouched, so it is safe to
# re-run after adding a new service to .env.example.
#
# Safety guarantees:
#   * Atomic: the result is written to a 0600 temp file next to .env and
#     renamed over it, so .env is never truncated or half-written (a failed
#     run, a full disk or Ctrl-C leaves the previous .env byte-for-byte intact).
#     A symlinked .env is resolved and its target is updated; ownership is kept
#     when run as root.
#   * Tolerant parsing: CRLF line endings, an `export ` prefix and leading
#     whitespace are understood and preserved.
#   * Fail closed: if any line still holds a literal GENERATE value afterwards
#     (no generator for that key, or a form this script does not parse), it
#     exits non-zero and does NOT write .env, so "GENERATE" can never ship as a
#     password.
#   * Never prints secret values, only key names.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
EXAMPLE_FILE="${REPO_ROOT}/.env.example"

die() { echo "error: $*" >&2; exit 1; }

command -v openssl >/dev/null 2>&1 || die "openssl is required"

# A symlinked .env (e.g. into a secrets directory) is updated in place at its
# target; renaming over the link itself would silently replace it with a file.
if [ -L "$ENV_FILE" ]; then
  target="$(readlink -f "$ENV_FILE" 2>/dev/null)" || die ".env is a symlink that cannot be resolved"
  ENV_FILE="$target"
fi

CREATED=0
if [ -f "$ENV_FILE" ]; then
  SOURCE_FILE="$ENV_FILE"
else
  [ -f "$EXAMPLE_FILE" ] || die ".env.example not found"
  SOURCE_FILE="$EXAMPLE_FILE"
  CREATED=1
fi

# --- secret generators ---------------------------------------------------
gen_b64()  { openssl rand -base64 "$1" | tr -d '\n'; }
gen_hex()  { openssl rand -hex "$1" | tr -d '\n'; }
gen_penpot_key() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets; print(secrets.token_urlsafe(64))"
  else
    # Same 64 bytes of entropy as token_urlsafe(64).
    gen_b64 64
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

# Strip surrounding whitespace, then one layer of single/double quotes.
unquote() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  v="${v%\'}"; v="${v#\'}"
  v="${v%\"}"; v="${v#\"}"
  printf '%s' "$v"
}
is_placeholder() {
  local v; v="$(unquote "$1")"
  [ -z "$v" ] || [ "$v" = "GENERATE" ]
}

# Temp file in the SAME directory as .env, so the final mv is an atomic rename
# on one filesystem. mktemp creates it 0600 whatever the umask.
TMP="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
trap 'exit 130' INT TERM

# KEY=VALUE, optionally indented and/or prefixed with `export`.
SECRET_RE='^([[:space:]]*(export[[:space:]]+)?)([A-Z0-9_]+)=(.*)$'
# Anything that still looks like an assignment of the literal GENERATE.
LEFTOVER_RE='^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*['"'"'"]?GENERATE(['"'"'"[:space:]#]|$)'

changed=0 crlf=0
declare -a leftover=()
while IFS= read -r raw || [ -n "$raw" ]; do
  # Remember a Windows line ending so it can be written back unchanged.
  cr=""
  if [[ "$raw" == *$'\r' ]]; then cr=$'\r'; crlf=1; fi
  line="${raw%$'\r'}"
  if [[ "$line" =~ $SECRET_RE ]]; then
    prefix="${BASH_REMATCH[1]}"
    key="${BASH_REMATCH[3]}"
    val="${BASH_REMATCH[4]}"
    if [ -n "${SECRETS[$key]+x}" ] && is_placeholder "$val"; then
      newval="$(${SECRETS[$key]})"
      [ -n "$newval" ] || die "generator for $key produced an empty value"
      if [ -n "${SINGLE_QUOTE[$key]+x}" ]; then
        printf "%s%s='%s'%s\n" "$prefix" "$key" "$newval" "$cr" >> "$TMP"
      else
        printf "%s%s=%s%s\n" "$prefix" "$key" "$newval" "$cr" >> "$TMP"
      fi
      echo "  generated $key" >&2
      changed=$((changed+1))
      continue
    fi
  fi
  if [[ "$line" =~ $LEFTOVER_RE ]]; then leftover+=("${BASH_REMATCH[2]}"); fi
  printf '%s\n' "$raw" >> "$TMP"
done < "$SOURCE_FILE"

if [ "${#leftover[@]}" -gt 0 ]; then
  echo "error: literal GENERATE left for: ${leftover[*]}" >&2
  echo "       (no generator for that key, or a form like 'KEY = GENERATE' /" >&2
  echo "        'KEY=GENERATE # comment'). Fix those lines and re-run." >&2
  echo "       .env was NOT modified." >&2
  exit 1
fi

if [ "$CREATED" -eq 0 ] && [ "$changed" -eq 0 ]; then
  # Nothing to fill: leave the file (and its inode/mtime) alone.
  chmod 600 "$ENV_FILE"
  echo "No placeholders found — all secrets already set. (.env permissions set to 600)"
  exit 0
fi

# Keep the owner when run as root (e.g. `sudo`), so the user can still read it.
if [ "$CREATED" -eq 0 ] && [ "$(id -u)" -eq 0 ]; then
  owner="$(stat -c %u:%g "$ENV_FILE" 2>/dev/null || stat -f %u:%g "$ENV_FILE")"
  chown "$owner" "$TMP"
fi
chmod 600 "$TMP"
mv -f "$TMP" "$ENV_FILE"
trap - EXIT

[ "$CREATED" -eq 0 ] || echo "Created .env from .env.example"
[ "$crlf" -eq 0 ] || echo "note: .env uses CRLF line endings; they were kept as is." >&2
echo "Filled $changed secret(s) in .env (file permissions set to 600)."
