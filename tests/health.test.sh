#!/usr/bin/env bash
# Tests for scripts/health.sh: what it prints in the HTTP column and, above all,
# its exit status, which is what cron or a deploy script acts on.
#
# Uses the REAL curl against a throwaway local HTTP server (python3), because the
# bug this guards against lives in how curl reports codes and exit statuses:
# `curl -f ... -w '%{http_code}' || echo 000` printed "503000" / "000000".
# Docker is a small stub local to this test (only `compose ps` matters here).
#
# Needs python3 (preinstalled on the GitHub ubuntu runners). Locally it is
# optional: without it the test is skipped, but in CI (CI=true) a missing
# python3 is a failure, never a skip.
#
#   bash tests/health.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

echo "health.sh"

if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  if [ "${CI:-}" = "true" ]; then
    echo "  FAIL  python3 and curl are required; this test must run in CI"
    exit 1
  fi
  echo "  skip  python3 or curl not found"
  exit 0
fi

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }
not() { ! "$@"; }

WORK="$(mktemp -d)"
SERVER_PID=""
cleanup() {
  [ -z "$SERVER_PID" ] || kill "$SERVER_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- local HTTP server -------------------------------------------------------
# Answers each path with the status code listed in $WORK/status ("path code"
# per line, re-read on every request); unlisted paths get 200.
cat > "$WORK/server.py" <<'PY'
import http.server, sys
status_file, port_file = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        code = 200
        with open(status_file) as f:
            for line in f:
                parts = line.split()
                if len(parts) == 2 and parts[0] == self.path:
                    code = int(parts[1])
        self.send_response(code)
        self.send_header("Content-Length", "0")
        self.end_headers()
    def log_message(self, *args):
        pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
with open(port_file + ".tmp", "w") as f:
    f.write(str(srv.server_address[1]))
import os; os.rename(port_file + ".tmp", port_file)
srv.serve_forever()
PY
: > "$WORK/status"
python3 -I "$WORK/server.py" "$WORK/status" "$WORK/port" &
SERVER_PID=$!
for _ in $(seq 1 100); do [ -s "$WORK/port" ] && break; sleep 0.05; done
[ -s "$WORK/port" ] || { echo "  FAIL  local HTTP server did not start"; exit 1; }
PORT="$(cat "$WORK/port")"

# A port with nothing listening: bind one, then release it.
DEAD_PORT="$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"

# --- sandbox -----------------------------------------------------------------
new_sandbox() {
  SB="$WORK/sb.$RANDOM$RANDOM"
  mkdir -p "$SB/scripts" "$SB/bin"
  cp "$REPO/scripts/health.sh" "$REPO/scripts/lib.sh" "$SB/scripts/"
  # Every service on the local server; the health paths tell them apart.
  cat > "$SB/.env" <<EOF
VW_HOST_PORT=$PORT
CALCOM_HOST_PORT=$PORT
PLAUSIBLE_HOST_PORT=$PORT
PENPOT_HOST_PORT=$PORT
N8N_HOST_PORT=$PORT
OPENWEBUI_HOST_PORT=$PORT
EOF
  # docker stub: `compose ps --format` with .State prints $FAKE_PS (one
  # "name state health" per line); any other compose call prints a table.
  cat > "$SB/bin/docker" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  info) exit 0 ;;
  compose)
    [ "${2:-}" = "version" ] && { echo "Docker Compose version v2-stub"; exit 0; }
    if [ "${2:-}" = "ps" ]; then
      case "$*" in
        *'{{.State}}'*) [ -z "${FAKE_PS:-}" ] || printf '%s\n' "$FAKE_PS" ;;
        *) echo "NAME STATUS" ;;
      esac
    fi
    exit 0 ;;
  *) echo "docker stub: unsupported: $*" >&2; exit 1 ;;
esac
SH
  chmod +x "$SB/bin/docker" "$SB/scripts/health.sh"
  : > "$WORK/status"
  export FAKE_PS=""
}

run_health() {
  set +e
  OUT="$(PATH="$SB/bin:$PATH" "$SB/scripts/health.sh" 2>&1)"
  RC=$?
  set -e
}

# Row of the endpoint table for a service, spaces squeezed: "<label> <code> <url>".
# (No colours to strip: lib.sh only colours a terminal, and OUT is captured.)
row() { grep "^$1 " <<< "$OUT" | tr -s ' ' || true; }

# --- 1. everything up --------------------------------------------------------
new_sandbox
run_health
check "all up: exit 0" [ "$RC" -eq 0 ]
check "all up: says how many were probed" grep -q 'all 6 probed services reachable' <<< "$OUT"
check "all up: vaultwarden shows 200" grep -q "^vaultwarden 200 http://127.0.0.1:$PORT/alive$" <<< "$(row vaultwarden)"

# --- 2. a service answers 503 ------------------------------------------------
new_sandbox
echo "/api/health 503" > "$WORK/status"
run_health
check "503: exit 1" [ "$RC" -eq 1 ]
check "503: the HTTP column says 503, not 503000" grep -q '^plausible 503 ' <<< "$(row plausible)"
check "503: the others still show 200" grep -q '^n8n 200 ' <<< "$(row n8n)"
check "503: does not claim success" not grep -qE 'all [0-9 ]*probed services reachable' <<< "$OUT"

# 4xx counts as down too (a 404 on the health path is not healthy).
new_sandbox
echo "/healthz 404" > "$WORK/status"
run_health
check "404: exit 1" [ "$RC" -eq 1 ]
check "404: the HTTP column says 404" grep -q '^n8n 404 ' <<< "$(row n8n)"

# 3xx counts as reachable (some apps redirect their health path).
new_sandbox
echo "/auth/login 302" > "$WORK/status"
run_health
check "302: still exit 0" [ "$RC" -eq 0 ]
check "302: the HTTP column says 302" grep -q '^calcom 302 ' <<< "$(row calcom)"

# --- 3. nothing listening ----------------------------------------------------
new_sandbox
sed -i "s/^N8N_HOST_PORT=.*/N8N_HOST_PORT=$DEAD_PORT/" "$SB/.env"
run_health
check "connection refused: exit 1" [ "$RC" -eq 1 ]
check "connection refused: the HTTP column says 000, not 000000" grep -q '^n8n 000 ' <<< "$(row n8n)"

# --- 4. a check that checked nothing never succeeds ---------------------------
new_sandbox
rm "$SB/.env"
run_health
check "no .env: exit 1" [ "$RC" -eq 1 ]
check "no .env: says so" grep -q 'no .env found' <<< "$OUT"
check "no .env: does not claim success" not grep -qE 'all [0-9 ]*probed services reachable' <<< "$OUT"

# lib.sh's health_targets returns nothing (e.g. a future edit breaks it).
new_sandbox
printf '\nhealth_targets() { :; }\n' >> "$SB/scripts/lib.sh"
run_health
check "zero targets: exit 1" [ "$RC" -eq 1 ]
check "zero targets: says nothing was checked" grep -q 'no endpoint was probed' <<< "$OUT"

# health_targets fails outright.
new_sandbox
printf '\nhealth_targets() { return 3; }\n' >> "$SB/scripts/lib.sh"
run_health
check "targets fail: exit 1" [ "$RC" -eq 1 ]
check "targets fail: does not claim success" not grep -qE 'all [0-9 ]*probed services reachable' <<< "$OUT"

# --- 5. container health -----------------------------------------------------
new_sandbox
export FAKE_PS=$'donalabs-n8n running healthy\ndonalabs-plausible running unhealthy\ndonalabs-calcom running '
run_health
check "unhealthy container: exit 1 even with every endpoint up" [ "$RC" -eq 1 ]
check "unhealthy container: named" grep -q 'container not healthy: donalabs-plausible (unhealthy)' <<< "$OUT"
check "unhealthy container: healthy ones not named" not grep -q 'container not healthy: donalabs-n8n' <<< "$OUT"
check "unhealthy container: one without a healthcheck is not named" not grep -q 'container not healthy: donalabs-calcom' <<< "$OUT"

new_sandbox
export FAKE_PS='donalabs-plausible restarting '
run_health
check "restart loop: exit 1" [ "$RC" -eq 1 ]
check "restart loop: named" grep -q 'container not healthy: donalabs-plausible (restarting)' <<< "$OUT"

# Still starting (health: starting) or exited one-shot jobs are not failures.
new_sandbox
export FAKE_PS=$'donalabs-calcom running starting\ndonalabs-init exited '
run_health
check "starting / exited one-shot: exit 0" [ "$RC" -eq 0 ]

echo "health.sh: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
