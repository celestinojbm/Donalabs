#!/usr/bin/env bash
# Tests for scripts/generate-secrets.sh: the .env.example <-> SECRETS contract,
# value formats, idempotency, and that user-set / non-secret values survive.
# Runs in a throwaway copy of the repo bits it needs; never touches the real .env.
#   bash tests/generate-secrets.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPT="$REPO/scripts/generate-secrets.sh"
EXAMPLE="$REPO/.env.example"

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }
not() { ! "$@"; }

new_sandbox() {
  SB="$(mktemp -d)"
  mkdir -p "$SB/scripts"
  cp "$SCRIPT" "$SB/scripts/"
  cp "$EXAMPLE" "$SB/.env.example"
  chmod +x "$SB/scripts/generate-secrets.sh"
}

run_gen() {
  set +e
  OUT="$("$SB/scripts/generate-secrets.sh" 2>&1)"
  RC=$?
  set -e
}

# Value of KEY in a .env file, with one layer of surrounding quotes stripped.
env_val() {
  local v
  v="$(sed -n "s/^$1=//p" "$2" | head -1)"
  v="${v%\'}"; v="${v#\'}"; v="${v%\"}"; v="${v#\"}"
  printf '%s' "$v"
}

# Keys the template marks as placeholders (value GENERATE, optionally quoted).
example_placeholders() {
  sed -nE "s/^([A-Z0-9_]+)=['\"]?GENERATE['\"]?$/\1/p" "$EXAMPLE" | sort
}
# Keys the script knows how to generate (entries of `declare -A SECRETS=( ... )`).
script_secrets() {
  sed -n '/^declare -A SECRETS=(/,/^)/p' "$SCRIPT" | sed -nE 's/^[[:space:]]*\[([A-Z0-9_]+)\]=.*/\1/p' | sort
}

echo "generate-secrets.sh"

# --- 1. contract: every GENERATE in .env.example has a generator, and back ----
# A placeholder with no generator would ship the literal string "GENERATE" as a
# password; a generator with no placeholder is dead config (likely a rename).
PH="$(example_placeholders)"
SS="$(script_secrets)"
check "template declares placeholders" [ -n "$PH" ]
missing="$(comm -23 <(echo "$PH") <(echo "$SS") | tr '\n' ' ')"
if [ -z "$missing" ]; then pass "every GENERATE key has a generator"
else fail "every GENERATE key has a generator" "no generator for: $missing"; fi
orphan="$(comm -13 <(echo "$PH") <(echo "$SS") | tr '\n' ' ')"
if [ -z "$orphan" ]; then pass "every generator has a GENERATE key in .env.example"
else fail "every generator has a GENERATE key in .env.example" "not in template: $orphan"; fi

# --- 2. fresh run: creates .env, fills everything, locks it down -------------
new_sandbox
run_gen
E="$SB/.env"
check "fresh run exits 0" [ "$RC" -eq 0 ]
check ".env created from template" [ -f "$E" ]
check ".env is mode 600" [ "$(stat -c %a "$E")" = "600" ]
check "no GENERATE value left" not grep -qE "^[A-Z0-9_]+=['\"]?GENERATE['\"]?$" "$E"
check "same number of lines as template" [ "$(wc -l < "$E")" -eq "$(wc -l < "$EXAMPLE")" ]
check "comments and non-secret lines unchanged" \
  diff <(grep -vE "^[A-Z0-9_]+=['\"]?GENERATE['\"]?$" "$EXAMPLE") \
       <(grep -vxFf <(for k in $PH; do grep "^$k=" "$E"; done) "$E")

empty="" ; vals=""
for k in $PH; do
  v="$(env_val "$k" "$E")"
  [ -n "$v" ] || empty="$empty $k"
  vals="$vals$v"$'\n'
done
check "every secret is non-empty${empty:+ (empty:$empty)}" [ -z "$empty" ]
check "every secret is distinct" [ "$(printf '%s' "$vals" | sort -u | grep -c .)" -eq "$(echo "$PH" | wc -w)" ]

# Formats follow the generator: `gen_hex N` -> 2N lowercase hex chars.
is_hex() { [[ "$(env_val "$1" "$E")" =~ ^[0-9a-f]{$2}$ ]]; }
check "DB password is 48 hex chars"      is_hex CALCOM_DB_PASSWORD 48
check "N8N_ENCRYPTION_KEY is 64 hex"     is_hex N8N_ENCRYPTION_KEY 64
check "OPENWEBUI_SECRET_KEY is 64 hex"   is_hex OPENWEBUI_SECRET_KEY 64
# `gen_b64 24` -> 32 base64 chars (Cal.com needs a 32-byte key; see .env.example).
is_b64() { [[ "$(env_val "$1" "$E")" =~ ^[A-Za-z0-9+/=]{$2}$ ]]; }
check "CALCOM_ENCRYPTION_KEY is 32 base64 chars" is_b64 CALCOM_ENCRYPTION_KEY 32
check "VW_ADMIN_TOKEN is single-quoted" grep -qE "^VW_ADMIN_TOKEN='[^']+'$" "$E"
check "SMTP passwords are NOT generated" [ -z "$(env_val CALCOM_SMTP_PASSWORD "$E")" ]

# --- 3. idempotent: a second run changes nothing -------------------------------
cp "$E" "$SB/first"
run_gen
check "second run exits 0" [ "$RC" -eq 0 ]
check "second run leaves .env byte-identical" cmp -s "$E" "$SB/first"
check "second run reports nothing to fill" grep -q "No placeholders found" <<< "$OUT"
rm -rf "$SB"

# --- 4. existing .env: user values kept, only placeholders filled -------------
new_sandbox
E="$SB/.env"
sed -e 's/^CALCOM_DB_PASSWORD=GENERATE$/CALCOM_DB_PASSWORD=my-own-pass/' \
    -e 's/^N8N_DB_PASSWORD=GENERATE$/N8N_DB_PASSWORD=/' \
    -e "s/^OPENWEBUI_SECRET_KEY=GENERATE\$/OPENWEBUI_SECRET_KEY=''/" \
    "$EXAMPLE" > "$E"
printf 'CUSTOM_LINE=keep me' >> "$E"   # no trailing newline on the last line
chmod 644 "$E"
run_gen
check "existing .env run exits 0" [ "$RC" -eq 0 ]
check "user-set secret is kept" [ "$(env_val CALCOM_DB_PASSWORD "$E")" = "my-own-pass" ]
check "empty secret (KEY=) is filled"   is_hex N8N_DB_PASSWORD 48
check "quoted-empty secret (KEY='') is filled" is_hex OPENWEBUI_SECRET_KEY 64
check "last line without newline is kept" grep -qx 'CUSTOM_LINE=keep me' "$E"
check "permissions tightened 644 -> 600" [ "$(stat -c %a "$E")" = "600" ]
check "reports one fewer secret than placeholders" \
  grep -q "Filled $(( $(echo "$PH" | wc -w) - 1 )) secret(s)" <<< "$OUT"
rm -rf "$SB"

# --- 5. openssl missing: fail fast, write nothing ------------------------------
new_sandbox
mkdir -p "$SB/bin"
for t in bash dirname cp mktemp cat rm chmod tr; do
  ln -s "$(command -v "$t")" "$SB/bin/$t"
done
set +e
OUT="$(PATH="$SB/bin" bash "$SB/scripts/generate-secrets.sh" 2>&1)"
RC=$?
set -e
check "missing openssl exits non-zero" [ "$RC" -ne 0 ]
check "missing openssl says why" grep -q "openssl is required" <<< "$OUT"
check "missing openssl creates no .env" [ ! -e "$SB/.env" ]
rm -rf "$SB"

echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
