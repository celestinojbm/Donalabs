#!/usr/bin/env bash
# Tests for services/plausible/start-plausible.sh, the start-up wrapper of the
# Plausible app container (createdb -> migrate -> run, retrying the first two).
#
# The contract:
#   - the steps run in order, each retried with a doubling wait capped at
#     DONALABS_START_MAX_DELAY, and `run` is exec'd (same PID, its exit code);
#   - a step that fails every attempt stops the script with that step's exit
#     code and `run` never starts (Docker's restart policy takes over);
#   - a bad setting fails at once (exit 2) without touching the databases;
#   - SIGTERM (docker stop) ends it at once, also during a wait, and is passed
#     on to the running step.
#
# The upstream /entrypoint.sh and `sleep` are replaced by fakes that log their
# calls (via DONALABS_ENTRYPOINT / DONALABS_SLEEP, not PATH: Ubuntu's busybox
# prefers its own sleep applet over PATH), so no Docker daemon or image is needed. The script runs under every
# POSIX shell found among sh, dash and busybox sh (the image uses busybox ash).
#
#   bash tests/plausible-start.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SCRIPT="$REPO/services/plausible/start-plausible.sh"

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }
skip() { printf '  skip  %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected $(printf '%q' "$2"), got $(printf '%q' "$3")"; fi; }

REAL_SLEEP="$(command -v sleep)"
export HANG_SLEEP="$REAL_SLEEP"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/bin"

# Fake upstream entrypoint. Per step NAME, files in $STATE:
#   NAME.fail  number of calls that still fail (decremented per call)
#   NAME.rc    exit code of a failing call (default 1)
#   NAME.hang  if present, the call blocks until it gets SIGTERM
# `run` logs its PID (to prove exec) and exits with $RUN_RC (default 0).
cat > "$SB/entrypoint" <<'EOF'
#!/bin/sh
echo "$*" >> "$LOG"
if [ "$1" = run ]; then
  echo "run pid=$$" >> "$LOG"
  exit "${RUN_RC:-0}"
fi
s="$STATE/$2"
if [ -e "$s.hang" ]; then
  trap 'echo "$2 got TERM" >> "$LOG"; exit 143' TERM
  echo "$2 hanging" >> "$LOG"
  # Bounded, so a wrapper that never forwards SIGTERM fails the test instead of
  # leaving this behind. Background + wait so the trap fires during the wait.
  i=0
  while [ "$i" -lt 100 ]; do "$HANG_SLEEP" 0.2 & wait $!; i=$((i + 1)); done
  exit 99
fi
n=$(cat "$s.fail" 2>/dev/null || echo 0)
if [ "$n" -gt 0 ]; then
  echo $((n - 1)) > "$s.fail"
  exit "$(cat "$s.rc" 2>/dev/null || echo 1)"
fi
exit 0
EOF
# Fake sleep: logs the wait and returns at once, unless $REAL_SLEEP_PATH is set.
cat > "$SB/bin/sleep" <<'EOF'
#!/bin/sh
echo "sleep $*" >> "$LOG"
[ -z "${REAL_SLEEP_PATH:-}" ] || exec "$REAL_SLEEP_PATH" "$@"
exit 0
EOF
chmod +x "$SB/entrypoint" "$SB/bin/sleep"

# reset: fresh log/state and default settings for one case.
reset() {
  export LOG="$SB/log" STATE="$SB/state"
  rm -rf "$STATE" "$LOG" "$SB/err"; mkdir -p "$STATE"; : > "$LOG"
  unset RUN_RC REAL_SLEEP_PATH DONALABS_START_ATTEMPTS DONALABS_START_DELAY DONALABS_START_MAX_DELAY
}
# start SHELL: run the wrapper; sets RC, OUT_LOG (calls, one per line), ERR.
# Killed after 30 s, so a regression that loops forever fails (RC 137).
start() {
  set +e
  timeout -s KILL 30 env DONALABS_ENTRYPOINT="$SB/entrypoint" DONALABS_SLEEP="$SB/bin/sleep" "$1" "$SCRIPT" 2> "$SB/err"
  RC=$?
  set -e
  OUT_LOG="$(cat "$LOG")"
  ERR="$(cat "$SB/err")"
}
# bounded_wait PID: wait up to 10 s for a background wrapper; sets RC (124 and
# kills it and its children if it is still running).
bounded_wait() {
  local _
  for _ in $(seq 1 100); do kill -0 "$1" 2>/dev/null || break; "$REAL_SLEEP" 0.1; done
  if kill -0 "$1" 2>/dev/null; then
    pkill -KILL -P "$1" 2>/dev/null || true
    kill -KILL "$1" 2>/dev/null || true
    wait "$1" 2>/dev/null || true
    RC=124
    return
  fi
  set +e; wait "$1"; RC=$?; set -e
}
calls() { grep -v '^run pid=' <<< "$OUT_LOG" | tr '\n' ',' | sed 's/,$//'; }

# Each distinct shell once (sh is often a link to dash).
SHELLS=() SEEN=" "
for c in sh dash; do
  p="$(command -v "$c" 2>/dev/null)" || continue
  r="$(readlink -f "$p")"
  case "$SEEN" in *" $r "*) continue ;; esac
  SEEN="$SEEN$r "; SHELLS+=("$p")
done
if command -v busybox >/dev/null 2>&1 && [[ "$SEEN" != *busybox* ]]; then
  printf '#!/bin/sh\nexec busybox sh "$@"\n' > "$SB/busybox-sh"; chmod +x "$SB/busybox-sh"
  SHELLS+=("$SB/busybox-sh")
fi

check "script parses as POSIX sh" sh -n "$SCRIPT"
if command -v busybox >/dev/null 2>&1; then :; else skip "busybox not installed: busybox sh not exercised (the image runs it; validated by hand)"; fi

for SH in "${SHELLS[@]}"; do
  label="$(basename "$SH")"
  echo "start-plausible.sh under $label"

  # --- order, exec, exit code ---------------------------------------------------
  reset
  start "$SH"
  eq "[$label] happy path: createdb, migrate, run" "db createdb,db migrate,run" "$(calls)"
  eq "[$label] happy path: exit 0" 0 "$RC"
  eq "[$label] happy path: no wait" "" "$(grep '^sleep' <<< "$OUT_LOG" || true)"

  reset
  set +e
  DONALABS_ENTRYPOINT="$SB/entrypoint" DONALABS_SLEEP="$SB/bin/sleep" "$SH" "$SCRIPT" 2>/dev/null &
  pid=$!
  set -e
  bounded_wait "$pid"
  eq "[$label] run is exec'd (same PID as the wrapper)" "run pid=$pid" "$(grep '^run pid=' "$LOG")"

  reset; export RUN_RC=5
  start "$SH"
  eq "[$label] run's exit code is the script's" 5 "$RC"

  # --- retries and backoff -------------------------------------------------------
  reset; echo 2 > "$STATE/createdb.fail"
  start "$SH"
  eq "[$label] createdb retried until it works" "db createdb,sleep 5,db createdb,sleep 10,db createdb,db migrate,run" "$(calls)"
  eq "[$label] recovered start exits 0" 0 "$RC"
  check "[$label] each retry is logged with attempt number" grep -q 'db createdb failed (exit 1) on attempt 2/10; retrying in 10s' <<< "$ERR"

  reset; echo 5 > "$STATE/createdb.fail"
  export DONALABS_START_ATTEMPTS=6 DONALABS_START_DELAY=3 DONALABS_START_MAX_DELAY=10
  start "$SH"
  eq "[$label] wait doubles and is capped" "3 6 10 10 10" "$(grep '^sleep' <<< "$OUT_LOG" | cut -d' ' -f2 | tr '\n' ' ' | sed 's/ $//')"
  eq "[$label] success on the last attempt still starts" 0 "$RC"

  reset; echo 1 > "$STATE/migrate.fail"; export DONALABS_START_DELAY=0
  start "$SH"
  eq "[$label] migrate retried too; delay 0 allowed" "db createdb,db migrate,sleep 0,db migrate,run" "$(calls)"

  reset; echo 1 > "$STATE/createdb.fail"; export DONALABS_START_DELAY=08
  start "$SH"
  eq "[$label] leading zero is decimal (08 -> 8)" "sleep 8" "$(grep '^sleep' <<< "$OUT_LOG")"

  # Without DONALABS_SLEEP (as in the container) the wait is a real `sleep`.
  reset; echo 1 > "$STATE/createdb.fail"; export DONALABS_START_DELAY=1
  t0=$(date +%s%N)
  set +e
  timeout -s KILL 30 env DONALABS_ENTRYPOINT="$SB/entrypoint" "$SH" "$SCRIPT" 2>/dev/null
  RC=$?
  set -e
  ms=$(( ($(date +%s%N) - t0) / 1000000 ))
  eq "[$label] default sleep: recovered start exits 0" 0 "$RC"
  check "[$label] default sleep: really waits (>= 1 s, got ${ms} ms)" test "$ms" -ge 1000
  eq "[$label] default sleep: the fake is not used" "" "$(grep '^sleep' "$LOG" || true)"

  # --- giving up -----------------------------------------------------------------
  reset; echo 99 > "$STATE/migrate.fail"; echo 7 > "$STATE/migrate.rc"; export DONALABS_START_ATTEMPTS=3
  start "$SH"
  eq "[$label] migrate tried exactly ATTEMPTS times" 3 "$(grep -c '^db migrate$' <<< "$OUT_LOG")"
  eq "[$label] run never starts after giving up" 0 "$(grep -c '^run$' <<< "$OUT_LOG" || true)"
  eq "[$label] exit code is the failing step's" 7 "$RC"
  check "[$label] giving up is logged" grep -q 'db migrate failed (exit 7) on attempt 3/3; giving up' <<< "$ERR"

  reset; echo 99 > "$STATE/createdb.fail"; export DONALABS_START_ATTEMPTS=1
  start "$SH"
  eq "[$label] ATTEMPTS=1: one try, no wait, no migrate" "db createdb" "$(calls)"
  eq "[$label] ATTEMPTS=1: exit 1" 1 "$RC"

  # --- settings ------------------------------------------------------------------
  for bad in "DONALABS_START_ATTEMPTS=abc" "DONALABS_START_ATTEMPTS=0" "DONALABS_START_ATTEMPTS=-1" \
             "DONALABS_START_DELAY=1.5" "DONALABS_START_DELAY= 5" "DONALABS_START_MAX_DELAY=1234567"; do
    reset; export "${bad%%=*}=${bad#*=}"
    start "$SH"
    if [ "$RC" -eq 2 ] && [ -z "$OUT_LOG" ] && grep -q "invalid ${bad%%=*}" <<< "$ERR"; then
      pass "[$label] rejects $bad (exit 2, nothing run)"
    else
      fail "[$label] rejects $bad (exit 2, nothing run)" "rc=$RC calls=$(calls) err=$ERR"
    fi
  done

  reset; export DONALABS_START_ATTEMPTS="" DONALABS_START_DELAY=""
  start "$SH"
  eq "[$label] empty settings fall back to the defaults" "0 db createdb,db migrate,run" "$RC $(calls)"

  # --- signals -------------------------------------------------------------------
  reset; echo 99 > "$STATE/createdb.fail"; export DONALABS_START_DELAY=30 REAL_SLEEP_PATH="$REAL_SLEEP"
  DONALABS_ENTRYPOINT="$SB/entrypoint" DONALABS_SLEEP="$SB/bin/sleep" "$SH" "$SCRIPT" 2> "$SB/err" &
  pid=$!
  for _ in $(seq 1 50); do grep -q '^sleep 30' "$LOG" && break; "$REAL_SLEEP" 0.1; done
  t0=$SECONDS
  kill -TERM "$pid"
  bounded_wait "$pid"
  eq "[$label] SIGTERM during a 30 s wait: exit 143" 143 "$RC"
  check "[$label] SIGTERM during a wait: stops at once (< 5 s)" test $((SECONDS - t0)) -lt 5
  check "[$label] SIGTERM during a wait: logged" grep -q 'received TERM during start-up' "$SB/err"
  eq "[$label] SIGTERM during a wait: nothing runs after" 0 "$(grep -c '^db migrate$' "$LOG" || true)"

  reset; touch "$STATE/createdb.hang"
  DONALABS_ENTRYPOINT="$SB/entrypoint" DONALABS_SLEEP="$SB/bin/sleep" "$SH" "$SCRIPT" 2>/dev/null &
  pid=$!
  for _ in $(seq 1 50); do grep -q '^createdb hanging' "$LOG" && break; "$REAL_SLEEP" 0.1; done
  kill -TERM "$pid"
  bounded_wait "$pid"
  eq "[$label] SIGTERM during a step: exit 143" 143 "$RC"
  check "[$label] SIGTERM during a step: passed on to the step" grep -q '^createdb got TERM$' "$LOG"
  echo
done

# --- the compose file actually uses the script ------------------------------------
echo "docker-compose.yml wiring"
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  if [ "${CI:-}" = "true" ]; then fail "docker compose CLI available in CI"; else skip "docker compose CLI not installed: wiring not checked"; fi
else
  # Client-side parse only (no daemon). Unset secrets just produce warnings.
  if json="$(cd "$REPO/services/plausible" && docker compose -f docker-compose.yml config --format json 2>/dev/null)"; then
    got="$(python3 -c '
import json, sys
s = json.load(sys.stdin)["services"]["plausible"]
cmd = " ".join(s.get("command") or [])
mount = [v for v in s.get("volumes", []) if v.get("target") == "/donalabs/start-plausible.sh"]
src = mount[0]["source"] if mount else ""
ro = mount[0].get("read_only", False) if mount else False
env = s.get("environment", {})
print(cmd)
print(src)
print(ro)
print(env.get("DONALABS_START_ATTEMPTS"), env.get("DONALABS_START_DELAY"), env.get("DONALABS_START_MAX_DELAY"))
' <<< "$json")"
    eq "command runs the wrapper with sh" "sh /donalabs/start-plausible.sh" "$(sed -n 1p <<< "$got")"
    eq "wrapper is bind-mounted from services/plausible/" "$REPO/services/plausible/start-plausible.sh" "$(sed -n 2p <<< "$got")"
    eq "wrapper mount is read-only" "True" "$(sed -n 3p <<< "$got")"
    eq "retry settings default to 10 / 5 / 30" "10 5 30" "$(sed -n 4p <<< "$got")"
  else
    fail "docker compose config parses services/plausible/docker-compose.yml"
  fi
fi

echo
echo "start-plausible.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
