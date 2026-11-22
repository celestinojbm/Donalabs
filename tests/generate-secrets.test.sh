#!/usr/bin/env bash
# Tests for scripts/generate-secrets.sh: the .env.example <-> SECRETS contract,
# value formats, idempotency, and that user-set / non-secret values survive.
#
# Hygiene rules this file follows (it handles freshly generated secrets):
#   * Everything runs in throwaway sandboxes (TMPDIR included), removed on ANY
#     exit by a trap. The real .env is never read for content, only fingerprinted
#     to prove the test did not modify it.
#   * Failure messages name KEYS, never values: no check receives a secret value
#     as an argument (they would be echoed by `check` on failure) and diff output
#     is redacted.
#
#   bash tests/generate-secrets.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPT="$REPO/scripts/generate-secrets.sh"
EXAMPLE="$REPO/.env.example"

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
# Never pass a secret VALUE to check: on failure its arguments are printed.
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }
# Report a list of offending keys (empty list = pass).
check_none() { if [ -z "$2" ]; then pass "$1"; else fail "$1" "keys:$2"; fi; }
not() { ! "$@"; }

SANDBOXES=()
cleanup() { [ "${#SANDBOXES[@]}" -eq 0 ] || rm -rf "${SANDBOXES[@]}"; }
trap cleanup EXIT

new_sandbox() {
  SB="$(mktemp -d)"
  SANDBOXES+=("$SB")
  mkdir -p "$SB/scripts" "$SB/tmp"
  cp "$SCRIPT" "$SB/scripts/"
  cp "$EXAMPLE" "$SB/.env.example"
  chmod +x "$SB/scripts/generate-secrets.sh"
  E="$SB/.env"
}

# Run the script inside the sandbox. Its mktemp lands in $SB/tmp so a leftover
# temp file (which would hold secrets) is detectable and never escapes.
#   run_gen [PATH-override]
run_gen() {
  set +e
  if [ -n "${1:-}" ]; then
    OUT="$(PATH="$1" TMPDIR="$SB/tmp" bash "$SB/scripts/generate-secrets.sh" 2>&1)"
  else
    OUT="$(TMPDIR="$SB/tmp" "$SB/scripts/generate-secrets.sh" 2>&1)"
  fi
  RC=$?
  set -e
}

# A PATH containing only the given tools (symlinked into the sandbox). System
# binaries are preferred over whatever `command -v` finds first, because PATH
# shims/wrappers often re-resolve the real tool via PATH and break here.
minimal_path() {
  mkdir -p "$SB/bin"
  local t d src
  for t in "$@"; do
    src=""
    for d in /usr/bin /bin; do [ -x "$d/$t" ] && { src="$d/$t"; break; }; done
    ln -sf "${src:-$(command -v "$t")}" "$SB/bin/$t"
  done
  printf '%s' "$SB/bin"
}
BASE_TOOLS=(bash dirname cp mktemp cat rm chmod tr)

file_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }   # GNU || BSD/macOS

# Value of KEY in a .env file, with one layer of surrounding quotes stripped.
env_val() {
  local v
  v="$(sed -n "s/^$1=//p" "$2" | head -1)"
  v="${v%\'}"; v="${v#\'}"; v="${v%\"}"; v="${v#\"}"
  printf '%s' "$v"
}
# Exact comparison without exposing the actual value on failure.
val_eq() { [ "$(env_val "$1" "$E")" = "$2" ]; }

# Keys the template marks as placeholders (value GENERATE, optionally quoted).
example_placeholders() {
  sed -nE "s/^([A-Z0-9_]+)=['\"]?GENERATE['\"]?$/\1/p" "$EXAMPLE" | sort
}
secrets_block() { sed -n '/^declare -A SECRETS=(/,/^)/p' "$SCRIPT"; }
# Keys the script knows how to generate (entries of `declare -A SECRETS=( ... )`).
script_secrets() { secrets_block | sed -nE 's/^[[:space:]]*\[([A-Z0-9_]+)\]=.*/\1/p' | sort; }
# Generator spec of KEY, e.g. "gen_hex 24".
generator_of() { secrets_block | sed -nE "s/^[[:space:]]*\[$1\]=\"([^\"]*)\".*/\1/p"; }

# Does KEY's value match what its generator produces? Derived from the SECRETS
# map, so a secret added later is covered automatically and an unknown
# generator fails until this function learns its format.
#   format_ok KEY FILE PYTHON(yes|no)
B64_RE='^[A-Za-z0-9+/]+={0,2}$'
HEX_RE='^[0-9a-f]+$'
URLSAFE86_RE='^[A-Za-z0-9_-]{86}$'
format_ok() {
  local spec v n
  spec="$(generator_of "$1")"; v="$(env_val "$1" "$2")"
  case "$spec" in
    "gen_hex "*) n="${spec#gen_hex }"; [[ $v =~ $HEX_RE ]] && [ "${#v}" -eq $((2*n)) ] ;;
    "gen_b64 "*) n="${spec#gen_b64 }"; [[ $v =~ $B64_RE ]] && [ "${#v}" -eq $((4*((n+2)/3))) ] ;;
    gen_penpot_key)
      # secrets.token_urlsafe(64) -> 86 url-safe chars; fallback gen_b64 48 -> 64.
      if [ "$3" = yes ]; then [[ $v =~ $URLSAFE86_RE ]]
      else [[ $v =~ $B64_RE ]] && [ "${#v}" -eq 64 ]; fi ;;
    *) return 1 ;;
  esac
}
bad_formats() {  # FILE PYTHON -> " KEY KEY" of malformed values
  local k bad=""
  for k in $SS; do format_ok "$k" "$1" "$2" || bad="$bad $k"; done
  printf '%s' "$bad"
}
# Random bytes behind a generator spec (penpot: token_urlsafe(64) = 64 bytes).
generator_bytes() {
  local spec; spec="$(generator_of "$1")"
  case "$spec" in
    "gen_hex "*|"gen_b64 "*) printf '%s' "${spec#* }" ;;
    gen_penpot_key) printf '64' ;;
    *) printf '0' ;;
  esac
}
MIN_BYTES=24   # 192 bits; the weakest generator today is 24 bytes
weak_generators() {
  local k bad=""
  for k in $SS; do [ "$(generator_bytes "$k")" -ge "$MIN_BYTES" ] || bad="$bad $k"; done
  printf '%s' "$bad"
}
b64_decoded_len() { env_val "$1" "$E" | base64 -d 2>/dev/null | wc -c | tr -d ' '; }

# Keys whose generated value appears in the script's output ($OUT).
leaked_in_output() {
  local k v bad=""
  for k in $SS; do
    v="$(env_val "$k" "$E")"
    if [ -n "$v" ] && grep -qF -- "$v" <<< "$OUT"; then bad="$bad $k"; fi
  done
  printf '%s' "$bad"
}
no_temp_left() { [ -z "$(ls -A "$SB/tmp")" ]; }

# Fingerprint of the real .env (mode + CRC, never the content) to prove the
# test leaves it alone. In CI it exists: infra.yml generates it before tests.
real_env_fp() {
  if [ -e "$REPO/.env" ]; then printf '%s %s' "$(file_mode "$REPO/.env")" "$(cksum < "$REPO/.env")"
  else printf 'absent'; fi
}
REAL_FP_BEFORE="$(real_env_fp)"

echo "generate-secrets.sh"

# --- 1. contract: every GENERATE in .env.example has a generator, and back ----
# A placeholder with no generator would ship the literal string "GENERATE" as a
# password; a generator with no placeholder is dead config (likely a rename).
PH="$(example_placeholders)"
SS="$(script_secrets)"
NSECRETS="$(echo "$SS" | wc -w | tr -d ' ')"
check "template declares placeholders" [ -n "$PH" ]
check "script declares generators (SECRETS block parsed)" [ -n "$SS" ]
check_none "every GENERATE key has a generator" "$(comm -23 <(echo "$PH") <(echo "$SS") | sed 's/^/ /' | tr -d '\n')"
check_none "every generator has a GENERATE key in .env.example" "$(comm -13 <(echo "$PH") <(echo "$SS") | sed 's/^/ /' | tr -d '\n')"
# The committed template must not carry a real credential: every secret-looking
# key is either a GENERATE placeholder or empty.
committed=""
while IFS= read -r line; do
  k="${line%%=*}"; v="${line#*=}"
  case "$v" in GENERATE|"'GENERATE'"|'"GENERATE"'|""|"''"|'""') ;; *) committed="$committed $k" ;; esac
done < <(grep -E '^[A-Z0-9_]*(PASSWORD|SECRET|TOKEN|_KEY|KEY_BASE)=' "$EXAMPLE")
check_none ".env.example holds no real credential" "$committed"
if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  check ".env is git-ignored" git -C "$REPO" check-ignore -q .env
  check ".env.example is NOT git-ignored" not git -C "$REPO" check-ignore -q .env.example
fi

# --- 2. fresh run: creates .env, fills everything, locks it down -------------
# umask 000 is the worst case: cp would create .env world-writable; the script
# must still end at 600.
new_sandbox
OLD_UMASK="$(umask)"; umask 000
run_gen
umask "$OLD_UMASK"
HAS_PY=no; command -v python3 >/dev/null 2>&1 && HAS_PY=yes
check "fresh run exits 0" [ "$RC" -eq 0 ]
check ".env created from template" [ -f "$E" ]
check ".env is mode 600 (even under umask 000)" [ "$(file_mode "$E")" = "600" ]
check "no GENERATE value left" not grep -qE "^[A-Z0-9_]+=['\"]?GENERATE['\"]?$" "$E"
check "same number of lines as template" [ "$(wc -l < "$E")" -eq "$(wc -l < "$EXAMPLE")" ]
# Secret lines are filtered out before diffing; any residual secret-looking
# value in the diff output is redacted anyway.
if d="$(diff <(grep -vE "^[A-Z0-9_]+=['\"]?GENERATE['\"]?$" "$EXAMPLE") \
             <(grep -vxFf <(for k in $PH; do grep "^$k=" "$E"; done) "$E"))"; then
  pass "comments and non-secret lines unchanged"
else
  fail "comments and non-secret lines unchanged" \
       "$(sed -E 's/^([<>] [A-Za-z0-9_]+=).*/\1<redacted>/' <<< "$d" | head -20)"
fi

empty="" ; vals=""
for k in $SS; do
  v="$(env_val "$k" "$E")"
  [ -n "$v" ] || empty="$empty $k"
  vals="$vals$v"$'\n'
done
check_none "every secret is non-empty" "$empty"
check "every secret is distinct" [ "$(printf '%s' "$vals" | sort -u | grep -c .)" -eq "$NSECRETS" ]
check_none "every secret matches its generator's format (python3: $HAS_PY)" "$(bad_formats "$E" "$HAS_PY")"
# Formats above follow the script, so they cannot catch a weakened generator.
# These pin what the services and the security floor actually require.
check_none "every generator yields >= $MIN_BYTES random bytes" "$(weak_generators)"
check "CALCOM_ENCRYPTION_KEY is exactly 32 chars (Cal.com AES key)" \
  [ "$(env_val CALCOM_ENCRYPTION_KEY "$E" | wc -c | tr -d ' ')" -eq 32 ]
check "PLAUSIBLE_TOTP_VAULT_KEY decodes to 32 bytes" [ "$(b64_decoded_len PLAUSIBLE_TOTP_VAULT_KEY)" -eq 32 ]
check "PLAUSIBLE_SECRET_KEY_BASE is >= 64 chars" \
  [ "$(env_val PLAUSIBLE_SECRET_KEY_BASE "$E" | wc -c | tr -d ' ')" -ge 64 ]
check "VW_ADMIN_TOKEN is single-quoted" grep -qE "^VW_ADMIN_TOKEN='[^']+'$" "$E"
check "CALCOM_SMTP_PASSWORD is NOT generated" val_eq CALCOM_SMTP_PASSWORD ""
check "PENPOT_SMTP_PASSWORD is NOT generated" val_eq PENPOT_SMTP_PASSWORD ""
check "output names every generated key" [ "$(grep -c '^  generated ' <<< "$OUT")" -eq "$NSECRETS" ]
check_none "output never contains a secret value" "$(leaked_in_output)"
check "no temp file left behind" no_temp_left

# --- 3. idempotent: a second run changes nothing -------------------------------
cp "$E" "$SB/first"
run_gen
check "second run exits 0" [ "$RC" -eq 0 ]
check "second run leaves .env byte-identical" cmp -s "$E" "$SB/first"
check "second run reports nothing to fill" grep -q "No placeholders found" <<< "$OUT"
check_none "second run output never contains a secret value" "$(leaked_in_output)"

# --- 4. existing .env: user values kept, only placeholders filled -------------
# The user value deliberately contains '=', '$' and a backslash: it must
# survive byte-for-byte (no expansion, no splitting on '=', no escape handling).
new_sandbox
# shellcheck disable=SC2016  # literal '$' on purpose
USER_VAL='my=own$pass\x'
# shellcheck disable=SC2016
sed -e 's/^CALCOM_DB_PASSWORD=GENERATE$/CALCOM_DB_PASSWORD=my=own$pass\\x/' \
    -e 's/^N8N_DB_PASSWORD=GENERATE$/N8N_DB_PASSWORD=/' \
    -e "s/^OPENWEBUI_SECRET_KEY=GENERATE\$/OPENWEBUI_SECRET_KEY=''/" \
    -e 's/^PENPOT_DB_PASSWORD=GENERATE$/PENPOT_DB_PASSWORD=""/' \
    -e 's/^PLAUSIBLE_DB_PASSWORD=GENERATE$/PLAUSIBLE_DB_PASSWORD="GENERATE"/' \
    "$EXAMPLE" > "$E"
printf 'CUSTOM_LINE=keep me' >> "$E"   # no trailing newline on the last line
chmod 644 "$E"
run_gen
check "existing .env run exits 0" [ "$RC" -eq 0 ]
check "user-set secret is kept byte-for-byte" val_eq CALCOM_DB_PASSWORD "$USER_VAL"
check "empty secret (KEY=) is filled"            format_ok N8N_DB_PASSWORD "$E" "$HAS_PY"
check "quoted-empty secret (KEY='') is filled"   format_ok OPENWEBUI_SECRET_KEY "$E" "$HAS_PY"
check 'double-quoted empty (KEY="") is filled'   format_ok PENPOT_DB_PASSWORD "$E" "$HAS_PY"
check 'double-quoted KEY="GENERATE" is filled'   format_ok PLAUSIBLE_DB_PASSWORD "$E" "$HAS_PY"
check "last line without newline is kept" grep -qx 'CUSTOM_LINE=keep me' "$E"
check "permissions tightened 644 -> 600" [ "$(file_mode "$E")" = "600" ]
check "reports one fewer secret than placeholders" \
  grep -q "Filled $((NSECRETS - 1)) secret(s)" <<< "$OUT"
check_none "output never contains a secret value" "$(leaked_in_output)"
check "no temp file left behind" no_temp_left

# --- 5. openssl missing: fail fast, write nothing ------------------------------
new_sandbox
run_gen "$(minimal_path "${BASE_TOOLS[@]}")"
check "missing openssl exits non-zero" [ "$RC" -ne 0 ]
check "missing openssl says why" grep -q "openssl is required" <<< "$OUT"
check "missing openssl creates no .env" [ ! -e "$E" ]

# --- 6. python3 missing: PENPOT_SECRET_KEY falls back to openssl ---------------
new_sandbox
run_gen "$(minimal_path "${BASE_TOOLS[@]}" openssl)"
check "no-python3 run exits 0" [ "$RC" -eq 0 ]
check "no-python3: PENPOT_SECRET_KEY uses the base64 fallback" format_ok PENPOT_SECRET_KEY "$E" no
check_none "no-python3: every secret matches its format" "$(bad_formats "$E" no)"

# --- 7. the real .env was never touched ------------------------------------------
check "real .env untouched by this test" [ "$(real_env_fp)" = "$REAL_FP_BEFORE" ]

echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
