#!/usr/bin/env bash
# Tests for the .env parsing in scripts/lib.sh (env_parse_line, load_env,
# env_get, edge_network) and its callers.
#
# The contract: the scripts must read .env exactly as Docker Compose does, or
# backup.sh / restore.sh / start.sh act on different values than the containers
# run with. A .env with CRLF endings, `export` lines or an inline comment used to
# work for Compose but gave the scripts "calcom\r", nothing, or
# "n8n # main db" (pg_dump of a database that does not exist).
#
#   1. a fixed table of lines -> expected values (no Docker needed);
#   2. load_env / env_get / edge_network on whole files;
#   3. end to end: backup.sh and proxy.sh with such a .env;
#   4. differential: the same fixture through `docker compose config`, when the
#      Compose CLI is installed (no daemon needed). Skipped otherwise.
#
#   bash tests/lib.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }
skip() { printf '  skip  %s\n' "$1"; }
# eq NAME EXPECTED ACTUAL (values here are test fixtures, never secrets)
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected $(printf '%q' "$2"), got $(printf '%q' "$3")"; fi; }

SANDBOXES=()
cleanup() { [ "${#SANDBOXES[@]}" -eq 0 ] || rm -rf "${SANDBOXES[@]}"; }
trap cleanup EXIT
new_sandbox() {
  SB="$(mktemp -d)"
  SANDBOXES+=("$SB")
  mkdir -p "$SB/scripts" "$SB/bin" "$SB/backups" "$SB/proxy/caddy"
  cp "$REPO/scripts/lib.sh" "$REPO/scripts/proxy.sh" "$SB/scripts/"
  cp "$REPO/backup.sh" "$SB/"
  cp "$HERE/fakes/docker" "$SB/bin/docker"
  chmod +x "$SB/bin/docker" "$SB/backup.sh" "$SB/scripts/proxy.sh"
}

# Run a lib.sh function in a clean subshell of the sandbox: libfn FN [ARGS...]
# Never fails the caller: a broken lib.sh must show up as FAILed checks, not
# abort the whole file under set -e.
libfn() { ( cd "$SB" && . scripts/lib.sh && "$@" ) 2>/dev/null || true; }

# --- 1. one line -> key/value ---------------------------------------------------
echo "env_parse_line: one line at a time"
new_sandbox
# parse LINE -> prints "KEY=VALUE" (VALUE %q-quoted) or "<none>"
parse() { ( . "$SB/scripts/lib.sh"; if env_parse_line "$1"; then printf '%s=%q' "$ENV_LINE_KEY" "$ENV_LINE_VAL"; else printf '<none>'; fi ) 2>/dev/null || true; }
t() { eq "$1" "$3" "$(parse "$2")"; }

t "plain"                         'A=plain'                    'A=plain'
t "CRLF ending is dropped"        $'A=crlf\r'                  'A=crlf'
t "export prefix"                 'export A=x'                 'A=x'
t "export with several spaces"    'export   A=x'               'A=x'
t "leading indentation"           $'  \tA=x'                   'A=x'
t "spaces around ="               'A = spaced'                 'A=spaced'
t "empty value"                   'A='                         "A=''"
t "value with = signs"            'A=k=v=w'                    'A=k=v=w'
t "inner spaces kept"             'A=one two  three'           "A=one\\ two\\ \\ three"
t "trailing whitespace trimmed"   $'A=x \t '                   'A=x'
t "inline comment dropped"        'A=n8n # main db'            'A=n8n'
t "# without a space is data"     'A=a#b'                      "A=a#b"
t "tab then # is data"            $'A=a\t#b'                   "A=$(printf '%q' $'a\t#b')"
t "value that starts with #"      'A= #c'                      "A=\\#c"
t "double quotes stripped"        'A="x y"'                    "A=x\\ y"
t "single quotes stripped"        "A='x y'"                    "A=x\\ y"
t "comment after double quotes"   'A="q" # c'                  'A=q'
t "comment after single quotes"   "A='s' #c"                   'A=s'
t "# inside quotes is data"       "A='a # b'"                  "A=$(printf '%q' 'a # b')"
t "junk after closing quote"      'A="a"b'                     'A=a'
t "quoted CRLF line"              $'A="q"\r'                   'A=q'
t "dq escape \\\""                'A="e\"q"'                   "A=e\\\"q"
t "dq escape \\\\"                'A="a\\b"'                   "A=a\\\\b"
t "dq escape \\n"                 'A="a\nb"'                   "A=$(printf '%q' $'a\nb')"
t "dq escape \\t"                 'A="a\tb"'                   "A=$(printf '%q' $'a\tb')"
t "single quotes are literal"     "A='lit\\n'"                 "A=lit\\\\n"
t "unquoted backslash literal"    'A=un\"q'                    "A=un\\\\\\\"q"
t "\$ is never expanded"          'A=$HOME'                    "A=\\\$HOME"
t "unterminated quote: literal"   'A="open'                    "A=\\\"open"
t "comment line"                  '# A=x'                      '<none>'
t "indented comment line"         '   # A=x'                   '<none>'
t "blank line"                    ''                           '<none>'
t "no ="                          'just text'                  '<none>'
t "invalid key (digit first)"     '1A=x'                       '<none>'
t "invalid key (dash)"            'A-B=x'                      '<none>'
t "key named export"              'export=1'                   'export=1'
t "key starting with export"      'exportA=1'                  'exportA=1'

# --- 2. whole files -------------------------------------------------------------
echo "load_env / env_get / edge_network"
new_sandbox
printf '%s\r\n' '# DonaLabs' 'CALCOM_DB_USER=calcom' 'export CALCOM_DB_NAME=calendso' \
  'PENPOT_FLAGS=enable-a enable-b' 'N8N_DB_NAME=n8n # main db' 'EDGE_NETWORK=donalabs_edge' \
  'DUP=first' 'DUP=last' > "$SB/.env"
got="$(libfn bash -c '. scripts/lib.sh; load_env; printf "%s|%s|%s|%s|%s" "${CALCOM_DB_USER-}" "${CALCOM_DB_NAME-}" "${PENPOT_FLAGS-}" "${N8N_DB_NAME-}" "${DUP-}"')"
eq "load_env: CRLF .env gives clean values" 'calcom|calendso|enable-a enable-b|n8n|last' "$got"
check "load_env: no value ends in CR" \
  bash -c "cd '$SB' && . scripts/lib.sh && load_env && ! env | grep -q \$'\\r'"

eq "env_get: CRLF + export"       'calendso' "$(libfn env_get "$SB/.env" CALCOM_DB_NAME)"
eq "env_get: last assignment"     'last'     "$(libfn env_get "$SB/.env" DUP)"
check "env_get: missing key -> exit 1" bash -c "cd '$SB' && . scripts/lib.sh && ! env_get .env NOPE"
eq "env_get: missing key prints nothing" '' "$(libfn env_get "$SB/.env" NOPE)"
printf '%s\n' 'K="v"' > "$SB/lf.env"; printf '%s\r\n' "export K=v" > "$SB/crlf.env"
eq "env_get: same key in other formats compares equal" \
  "$(libfn env_get "$SB/lf.env" K)" "$(libfn env_get "$SB/crlf.env" K)"

eq "edge_network: CRLF .env has no CR" 'donalabs_edge' "$(libfn edge_network)"
printf 'EDGE_NETWORK="my_edge" # shared\n' > "$SB/.env"
eq "edge_network: quoted + comment"   'my_edge'       "$(libfn edge_network)"
printf 'EDGE_NETWORK=\n' > "$SB/.env"
eq "edge_network: empty -> default"   'donalabs_edge' "$(libfn edge_network)"
printf 'OTHER=1\n' > "$SB/.env"
eq "edge_network: unset -> default"   'donalabs_edge' "$(libfn edge_network)"
rm -f "$SB/.env"
eq "edge_network: no .env -> default" 'donalabs_edge' "$(libfn edge_network)"

# --- 3. end to end --------------------------------------------------------------
echo "callers: backup.sh and proxy.sh with a CRLF / export / commented .env"
new_sandbox
printf '%s\r\n' 'CALCOM_DB_USER=calcom' 'export CALCOM_DB_NAME=calendso' \
  'PLAUSIBLE_DB_USER=plausible' 'PLAUSIBLE_DB_NAME="plausible_db"' \
  'PENPOT_DB_USER=penpot' 'PENPOT_DB_NAME=penpot # design' \
  '  N8N_DB_USER=n8n' 'N8N_DB_NAME=n8n' 'CADDY_IMAGE_TAG=2.10-alpine # pinned' > "$SB/.env"
export FAKE_RUNNING="donalabs-calcom-db donalabs-plausible-db donalabs-penpot-db donalabs-n8n-db"
export FAKE_VOLUMES="donalabs_vaultwarden_data donalabs_open_webui_data donalabs_n8n_data donalabs_penpot_assets donalabs_plausible_data donalabs_plausible_event_data"
export FAKE_LOG="$SB/docker.log"
set +e; ( cd "$SB" && PATH="$SB/bin:$PATH" ./backup.sh >/dev/null 2>&1 ); rc=$?; set -e
eq "backup.sh exits 0" 0 "$rc"
for db in "calcom-db pg_dump -U calcom -d calendso" "plausible-db pg_dump -U plausible -d plausible_db" \
          "penpot-db pg_dump -U penpot -d penpot" "n8n-db pg_dump -U n8n -d n8n"; do
  check "backup.sh: exec donalabs-$db" grep -qxF "exec donalabs-$db" "$FAKE_LOG"
done
check "backup.sh: no CR reached docker" bash -c "! grep -q \$'\\r' '$FAKE_LOG'"

: > "$FAKE_LOG"
( cd "$SB" && PATH="$SB/bin:$PATH" ./scripts/proxy.sh validate >/dev/null 2>&1 ) || true
check "proxy.sh validate: image tag parsed like Compose" grep -q ' caddy:2.10-alpine caddy validate' "$FAKE_LOG"
printf 'OTHER=1\n' > "$SB/.env"; : > "$FAKE_LOG"
( cd "$SB" && PATH="$SB/bin:$PATH" ./scripts/proxy.sh validate >/dev/null 2>&1 ) || true
check "proxy.sh validate: default tag when unset" grep -q ' caddy:2-alpine caddy validate' "$FAKE_LOG"
unset FAKE_RUNNING FAKE_VOLUMES FAKE_LOG

# --- 4. differential: same fixture through Docker Compose ----------------------
echo "differential: env_get vs docker compose config"
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1 \
   || ! command -v python3 >/dev/null 2>&1 || docker compose version 2>/dev/null | grep -q fake; then
  skip "docker compose CLI or python3 not available"
else
  new_sandbox
  D="$SB/compose"; mkdir -p "$D"
  # Every line here is one Compose accepts; ${VAR} interpolation is left out on
  # purpose (documented as unsupported in lib.sh).
  {
    printf '%s\r\n' 'P_CRLF=crlf' 'P_DQ_CRLF="dq crlf"'
    printf '%s\n' '# comment' '' 'export P_EXPORT=exported' '   P_INDENT=indented' 'P_SPACES = spaced' \
      "P_SQ='single # not comment'" 'P_DQ_COMMENT="q" # c' "P_SQ_COMMENT='s' #c" \
      'P_INLINE=unq # comment' 'P_HASH=a#b' $'P_TABHASH=a\t#tab' 'P_LEADHASH= #c' \
      'P_TRAIL=x   ' $'P_LEAD=\t tabbed\t' 'P_EQ=k=v=w' 'P_SPACE_VAL=sp ace val' \
      'P_LAST=first' 'P_LAST=last' 'P_ESC_DQ="esc\"q"' 'P_ESC_BS="a\\b"' 'P_ESC_N="a\nb"' \
      'P_ESC_T="a\tb"' 'P_UNQ_BS=un\"q' "P_SQ_BS='lit\\n'" 'P_EMPTY=' 'P_EMPTY_DQ=""' \
      'P_AFTER="a"b' 'P_FLAGS=enable-a enable-b'
  } > "$D/.env"
  keys="$(grep -oE '^[[:space:]]*(export[[:space:]]+)?P_[A-Z_]+' "$D/.env" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//' | sort -u)"
  { echo 'services:'; echo '  x:'; echo '    image: scratch'; echo '    environment:'
    for k in $keys; do echo "      $k: \"[\${$k}]\""; done; } > "$D/compose.yml"
  if ! ( cd "$D" && docker compose config --format json ) > "$SB/compose.json" 2> "$SB/compose.err"; then
    fail "docker compose config ran" "$(head -3 "$SB/compose.err")"
  else
    # ours: KEY \0 VALUE \0, through load_env (what the scripts export)
    ( cd "$D" && . "$SB/scripts/lib.sh"; ENV_FILE="$D/.env"; load_env
      for k in $keys; do printf '%s\0[%s]\0' "$k" "${!k-}"; done ) > "$SB/ours.bin" || true
    mism="$(python3 -I - "$SB/compose.json" "$SB/ours.bin" <<'PY'
import json, sys
env = json.load(open(sys.argv[1]))["services"]["x"]["environment"]
parts = open(sys.argv[2], "rb").read().decode().split("\0")[:-1]
ours = dict(zip(parts[0::2], parts[1::2]))
for k in sorted(ours):
    if env.get(k) != ours[k]:
        print(f"{k}: compose={env.get(k)!r} ours={ours[k]!r}")
PY
)"
    n="$(wc -w <<< "$keys")"
    if [ -z "$mism" ]; then pass "all $n fixture keys match docker compose ($(docker compose version --short 2>/dev/null))"
    else fail "fixture keys differ from docker compose" "$(printf '%s\n        ' "$mism")"; fi
  fi
fi

echo
echo "lib.sh (.env parsing): $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
