#!/usr/bin/env bash
# Tests for scripts/restore.sh: argument and confirmation guards, and a real
# backup.sh -> restore.sh round trip. Runs against tests/fakes/docker — no Docker
# daemon needed. With FAKE_VOLROOT the fake maps each volume to a sandbox
# directory and runs the scripts' real `tar` / `rm` commands there, so the round
# trip checks actual file contents, not just which commands were issued.
#
#   bash tests/restore.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

ALL_PG="donalabs-calcom-db donalabs-plausible-db donalabs-penpot-db donalabs-n8n-db"
ALL_APPS="donalabs-vaultwarden donalabs-open-webui donalabs-n8n donalabs-plausible donalabs-penpot-backend"
ALL_VOLS="donalabs_vaultwarden_data donalabs_open_webui_data donalabs_n8n_data donalabs_penpot_assets donalabs_plausible_data donalabs_plausible_event_data"
# Which containers mount each volume (what `docker ps -a --filter volume=` returns).
VOLUME_USERS="donalabs_vaultwarden_data=donalabs-vaultwarden donalabs_open_webui_data=donalabs-open-webui donalabs_n8n_data=donalabs-n8n donalabs_penpot_assets=donalabs-penpot-frontend,donalabs-penpot-backend donalabs_plausible_data=donalabs-plausible donalabs_plausible_event_data=donalabs-plausible-clickhouse"

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }
# Report a list of offenders (empty list = pass).
check_none() { if [ -z "$2" ]; then pass "$1"; else fail "$1" "offenders:$2"; fi; }
not() { ! "$@"; }

SANDBOXES=()
cleanup() { [ "${#SANDBOXES[@]}" -eq 0 ] || rm -rf "${SANDBOXES[@]}"; }
trap cleanup EXIT

# Fresh copy of the repo bits backup.sh + restore.sh need, a .env, the fake
# docker on PATH, and one directory per volume with regular, hidden and nested
# files.
new_sandbox() {
  SB="$(mktemp -d)"
  SANDBOXES+=("$SB")
  mkdir -p "$SB/scripts" "$SB/backups" "$SB/bin" "$SB/vols" "$SB/psql"
  cp "$REPO/backup.sh" "$SB/"
  cp "$REPO/scripts/lib.sh" "$REPO/scripts/restore.sh" "$SB/scripts/"
  cp "$HERE/fakes/docker" "$SB/bin/docker"
  chmod +x "$SB/bin/docker" "$SB/backup.sh" "$SB/scripts/restore.sh"
  cat > "$SB/.env" <<'EOF'
CALCOM_DB_USER=calcom
CALCOM_DB_NAME=calendso
PLAUSIBLE_DB_USER=plausible
PLAUSIBLE_DB_NAME=plausible_db
PENPOT_DB_USER=penpot
PENPOT_DB_NAME=penpot
N8N_DB_USER=n8n
N8N_DB_NAME=n8n
EOF
  local v
  for v in $ALL_VOLS; do
    mkdir -p "$SB/vols/$v/sub"
    echo "data of $v" > "$SB/vols/$v/data.txt"
    echo "hidden of $v" > "$SB/vols/$v/.hidden"
    echo "nested of $v" > "$SB/vols/$v/sub/nested.txt"
  done
  export FAKE_RUNNING="$ALL_PG $ALL_APPS" FAKE_VOLUMES="$ALL_VOLS"
  export FAKE_VOLUME_USERS="$VOLUME_USERS" FAKE_VOLROOT="$SB/vols" FAKE_PSQL_DIR="$SB/psql"
  export FAKE_PGDUMP_FAIL="" FAKE_TAR_FAIL="" FAKE_PSQL_FAIL="" FAKE_LOG="$SB/docker.log"
  unset BACKUP_RETENTION
}

# Take a real backup in the sandbox; BK = its directory. Extra args go to backup.sh.
take_backup() {
  set +e
  OUT="$(PATH="$SB/bin:$PATH" "$SB/backup.sh" "$@" 2>&1)"
  RC=$?
  set -e
  BK="$(find "$SB/backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
}

# run_restore <answer> [args...]   (answer "<EOF>" = closed stdin)
# Starts from an empty fake-docker log so checks only see restore.sh's calls.
run_restore() {
  local answer="$1"; shift
  : > "$FAKE_LOG"
  set +e
  if [ "$answer" = "<EOF>" ]; then
    OUT="$(PATH="$SB/bin:$PATH" "$SB/scripts/restore.sh" "$@" 2>&1 < /dev/null)"
  else
    OUT="$(PATH="$SB/bin:$PATH" "$SB/scripts/restore.sh" "$@" 2>&1 <<< "$answer")"
  fi
  RC=$?
  set -e
}

# True if restore.sh wrote to a database or a volume, or stopped/started anything.
touched_data() { grep -Eq '^(exec -i |run |stop |start )' "$FAKE_LOG"; }
# Line number of the first fake-docker call matching an ERE (0 if none).
line_of() { local n; n="$(grep -nE -m1 -- "$1" "$FAKE_LOG" | cut -d: -f1)"; echo "${n:-0}"; }

echo "restore.sh"

# --- 1. argument guards: nothing is touched -----------------------------------
new_sandbox
run_restore yes
check "no argument exits 1" [ "$RC" -eq 1 ]
check "no argument prints usage" grep -q 'usage: ./scripts/restore.sh' <<< "$OUT"
check "no argument touches no data" not touched_data

run_restore yes "$SB/backups/does-not-exist"
check "missing backup dir exits 1" [ "$RC" -eq 1 ]
check "missing backup dir touches no data" not touched_data

take_backup
rm "$SB/.env"
run_restore yes "$BK"
check "missing .env exits 1" [ "$RC" -eq 1 ]
check "missing .env touches no data" not touched_data

# --- 2. confirmation: only a literal "yes" proceeds ----------------------------
new_sandbox
take_backup
for answer in no y YES "yes please" ""; do
  run_restore "$answer" "$BK"
  check "answer '$answer' aborts with exit 0" [ "$RC" -eq 0 ]
  check "answer '$answer' touches no data" not touched_data
done
check "abort says so" grep -q 'aborted' <<< "$OUT"
run_restore "<EOF>" "$BK"
check "closed stdin (cron, no tty) exits non-zero" [ "$RC" -ne 0 ]
check "closed stdin touches no data" not touched_data

# --- 3. round trip: backup -> damage -> restore gives back the snapshot -------
new_sandbox
take_backup
check "backup for the round trip is complete" [ "$RC" -eq 0 ]
cp -a "$SB/vols" "$SB/snapshot"
for v in $ALL_VOLS; do                  # damage every volume after the backup
  echo "changed" > "$SB/vols/$v/data.txt"
  rm "$SB/vols/$v/sub/nested.txt"
  echo "stale" > "$SB/vols/$v/new.txt"
  echo "stale" > "$SB/vols/$v/.stale"   # matched by .[!.]*
  echo "stale" > "$SB/vols/$v/..odd"    # matched by ..?*
done
run_restore yes "$BK"
check "restore exits 0" [ "$RC" -eq 0 ]
check "restore reports completion" grep -q 'restore complete' <<< "$OUT"

bad=""
for v in $ALL_VOLS; do diff -r "$SB/snapshot/$v" "$SB/vols/$v" >/dev/null 2>&1 || bad="$bad $v"; done
check_none "every volume is byte-identical to its backup" "$bad"
bad=""
for v in $ALL_VOLS; do [ ! -e "$SB/vols/$v/.stale" ] && [ ! -e "$SB/vols/$v/..odd" ] || bad="$bad $v"; done
check_none "hidden files created after the backup are removed" "$bad"

bad=""
for c in $ALL_PG; do
  [ "$(cat "$SB/psql/$c.sql" 2>/dev/null)" = "-- fake dump of $c" ] || bad="$bad $c"
done
check_none "each database gets its own dump back (through gzip)" "$bad"
check "calcom psql uses .env user/db" grep -qx 'exec -i donalabs-calcom-db psql -U calcom -d calendso' "$FAKE_LOG"
check "plausible psql uses .env user/db" grep -qx 'exec -i donalabs-plausible-db psql -U plausible -d plausible_db' "$FAKE_LOG"
check "penpot psql uses .env user/db" grep -qx 'exec -i donalabs-penpot-db psql -U penpot -d penpot' "$FAKE_LOG"
check "n8n psql uses .env user/db" grep -qx 'exec -i donalabs-n8n-db psql -U n8n -d n8n' "$FAKE_LOG"
check "backup dir is mounted read-only" \
  bash -c "[ \$(grep -c ':/dst ' '$FAKE_LOG') -eq 6 ] && [ \$(grep ':/dst ' '$FAKE_LOG' | grep -c -- '-v $BK:/backup:ro ') -eq 6 ]"

# Every container that mounts a volume is stopped before the volume is rewritten
# and started again after it.
bad=""
for pair in $VOLUME_USERS; do
  v="${pair%%=*}"; users="${pair#*=}"
  r="$(line_of "^run .* -v $v:/dst ")"
  for c in ${users//,/ }; do
    s="$(line_of "^stop $c\$")"; t="$(line_of "^start $c\$")"
    [ "$s" -gt 0 ] && [ "$s" -lt "$r" ] && [ "$r" -lt "$t" ] || bad="$bad $c($v)"
  done
done
check_none "volume users are stopped before and restarted after their volume" "$bad"

# --- 4. partial backup: only what is in the backup is touched -----------------
new_sandbox
export FAKE_RUNNING="donalabs-n8n-db donalabs-n8n" FAKE_VOLUMES="donalabs_n8n_data"
take_backup --allow-partial
check "partial backup (n8n only) succeeds" [ "$RC" -eq 0 ]
export FAKE_RUNNING="$ALL_PG $ALL_APPS" FAKE_VOLUMES="$ALL_VOLS"   # full stack up now
echo "changed" > "$SB/vols/donalabs_vaultwarden_data/data.txt"
run_restore yes "$BK"
check "partial restore exits 0" [ "$RC" -eq 0 ]
check "n8n database restored" grep -qx 'exec -i donalabs-n8n-db psql -U n8n -d n8n' "$FAKE_LOG"
check "n8n volume restored" grep -q -- '-v donalabs_n8n_data:/dst ' "$FAKE_LOG"
check "databases without a dump are left alone" \
  bash -c "[ \$(grep -c '^exec -i ' '$FAKE_LOG') -eq 1 ]"
check "skipped databases are reported" grep -q 'no dump for donalabs-calcom-db, skipping' <<< "$OUT"
check "volumes without a tarball are left alone" bash -c "[ \$(grep -c '^run ' '$FAKE_LOG') -eq 1 ]"
check "vaultwarden data not overwritten" grep -qx 'changed' "$SB/vols/donalabs_vaultwarden_data/data.txt"
check "containers of untouched volumes are not stopped" not grep -qx 'stop donalabs-vaultwarden' "$FAKE_LOG"

# --- 5. database container down: that dump is skipped, the rest restored ------
new_sandbox
take_backup
export FAKE_RUNNING="${ALL_PG/donalabs-penpot-db/} $ALL_APPS"
run_restore yes "$BK"
check "restore with a DB down exits 0" [ "$RC" -eq 0 ]
check "down DB gets no psql" not grep -q '^exec -i donalabs-penpot-db ' "$FAKE_LOG"
check "down DB is reported" grep -q 'donalabs-penpot-db not running, skipping' <<< "$OUT"
check "running DBs are still restored" bash -c "[ \$(grep -c '^exec -i ' '$FAKE_LOG') -eq 3 ]"

# --- 6. relative backup path is mounted as an absolute path -------------------
new_sandbox
take_backup
rel="backups/$(basename "$BK")"
: > "$FAKE_LOG"
set +e
OUT="$(cd "$SB" && PATH="$SB/bin:$PATH" ./scripts/restore.sh "$rel" 2>&1 <<< yes)"
RC=$?
set -e
check "relative path restore exits 0" [ "$RC" -eq 0 ]
check "relative path is mounted absolute" grep -q -- "-v $BK:/backup:ro " "$FAKE_LOG"
check "relative path still restores volumes" bash -c "[ \$(grep -c '^run ' '$FAKE_LOG') -eq 6 ]"

echo
echo "restore.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
