#!/bin/sh
# =============================================================================
# DonaLabs — Plausible app start-up wrapper (bind-mounted into the container).
#
# Runs, in order:  db createdb  ->  db migrate  ->  run
# exactly like the upstream Community Edition command, except that createdb and
# migrate are RETRIED with a doubling wait.
#
# Why: on a host reboot Docker's `restart: unless-stopped` ignores
# `depends_on: service_healthy`, so the app can start before Postgres and
# ClickHouse resolve or accept connections. createdb then fails (it logs
# `RuntimeError "killed"` after the connection errors) and the whole container
# restarts, several times in a row (docs/operational-readiness.md §8).
# Retrying inside the container absorbs that race without restarts.
#
# A step that still fails after the last attempt makes the script exit with
# that step's exit code: the container stops and Docker's restart policy takes
# over, as before. Retrying does not fix a real misconfiguration (wrong DB
# password, ClickHouse out of memory); it only delays its failure.
#
# The app is started with `exec`, so it stays PID 1 and gets the SIGTERM of
# `docker stop`, as with the upstream command.
#
# Settings (environment, all optional):
#   DONALABS_START_ATTEMPTS   attempts per step, integer >= 1      (default 10)
#   DONALABS_START_DELAY      first wait in seconds, integer >= 0  (default 5)
#   DONALABS_START_MAX_DELAY  cap for the doubling wait, >= 0      (default 30)
#   DONALABS_ENTRYPOINT       upstream entrypoint (tests only) (/entrypoint.sh)
#
# POSIX sh: the image is Alpine (busybox ash), there is no bash.
# =============================================================================

ENTRYPOINT="${DONALABS_ENTRYPOINT:-/entrypoint.sh}"
ATTEMPTS="${DONALABS_START_ATTEMPTS:-10}"
DELAY="${DONALABS_START_DELAY:-5}"
MAX_DELAY="${DONALABS_START_MAX_DELAY:-30}"

log() { echo "[donalabs-start] $*" >&2; }

# uint NAME VALUE: print VALUE without leading zeros ("08" is not octal for
# $(( ))), or fail if it is not a non-negative integer of at most 6 digits.
uint() {
  case "$2" in
    '' | *[!0-9]*) log "invalid $1='$2': must be a non-negative integer"; return 1 ;;
  esac
  v=$2
  while [ "${#v}" -gt 1 ] && [ "${v#0}" != "$v" ]; do v=${v#0}; done
  if [ "${#v}" -gt 6 ]; then
    log "invalid $1='$2': too large"
    return 1
  fi
  echo "$v"
}

ATTEMPTS=$(uint DONALABS_START_ATTEMPTS "$ATTEMPTS") || exit 2
DELAY=$(uint DONALABS_START_DELAY "$DELAY") || exit 2
MAX_DELAY=$(uint DONALABS_START_MAX_DELAY "$MAX_DELAY") || exit 2
if [ "$ATTEMPTS" -lt 1 ]; then
  log "invalid DONALABS_START_ATTEMPTS=0: must be at least 1"
  exit 2
fi

# As PID 1 a shell ignores SIGTERM unless it traps it. Children run in the
# background and are waited for, so the trap fires at once (not when a 30 s
# sleep or a migration ends). The running step is sent SIGTERM (background
# children of a non-interactive shell ignore SIGINT, so INT is not forwarded).
child=""
on_signal() {
  log "received $1 during start-up; stopping"
  if [ -n "$child" ]; then
    kill -s TERM "$child" 2>/dev/null
    wait "$child" 2>/dev/null
  fi
  exit "$2"
}
trap 'on_signal TERM 143' TERM
trap 'on_signal INT 130' INT

# run_child CMD...: run CMD in the background, wait for it, return its status.
run_child() {
  "$@" &
  child=$!
  wait "$child"
  rc=$?
  child=""
  return "$rc"
}

# step NAME: `$ENTRYPOINT db NAME` with retries and doubling waits.
step() {
  n=1
  wait_s=$DELAY
  while :; do
    run_child "$ENTRYPOINT" db "$1" && return 0
    rc=$?
    if [ "$n" -ge "$ATTEMPTS" ]; then
      log "db $1 failed (exit $rc) on attempt $n/$ATTEMPTS; giving up"
      return "$rc"
    fi
    log "db $1 failed (exit $rc) on attempt $n/$ATTEMPTS; retrying in ${wait_s}s"
    run_child sleep "$wait_s"
    n=$((n + 1))
    wait_s=$((wait_s * 2))
    [ "$wait_s" -gt "$MAX_DELAY" ] && wait_s=$MAX_DELAY
  done
}

step createdb || exit
step migrate || exit

trap - TERM INT
exec "$ENTRYPOINT" run
