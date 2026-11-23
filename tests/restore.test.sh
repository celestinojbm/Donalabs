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
ALL_APPS="donalabs-vaultwarden donalabs-open-webui donalabs-n8n donalabs-plausible donalabs-plausible-clickhouse donalabs-penpot-backend donalabs-penpot-frontend"
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
  export FAKE_PGDUMP_FAIL="" FAKE_TAR_FAIL="" FAKE_PSQL_FAIL="" FAKE_STOP_FAIL="" FAKE_LOG="$SB/docker.log"
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
touched_data() { grep -Eq '^(exec |run |stop |start )' "$FAKE_LOG"; }
# The calls that restore database <container> as <user>/<db>: load the dump into
# <db>__restoring with ON_ERROR_STOP in one transaction, then swap it in.
pg_restored() {
  grep -qx "exec -i $1 psql -U $2 -d $3__restoring -X -q -v ON_ERROR_STOP=1 --single-transaction" "$FAKE_LOG" \
    && grep -q "^exec $1 psql -U $2 -d postgres .* -1 .*ALTER DATABASE \"$3__restoring\" RENAME TO \"$3\"\$" "$FAKE_LOG"
}
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
check "missing backup dir prints usage" grep -q 'usage: ./scripts/restore.sh' <<< "$OUT"
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
check "calcom psql uses .env user/db" pg_restored donalabs-calcom-db calcom calendso
check "plausible psql uses .env user/db" pg_restored donalabs-plausible-db plausible plausible_db
check "penpot psql uses .env user/db" pg_restored donalabs-penpot-db penpot penpot
check "n8n psql uses .env user/db" pg_restored donalabs-n8n-db n8n n8n
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
check "n8n database restored" pg_restored donalabs-n8n-db n8n n8n
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
# A running container whose name merely CONTAINS the down DB's name must not
# count as that DB being up (the check has to match whole names).
export FAKE_RUNNING="${ALL_PG/donalabs-penpot-db/donalabs-penpot-db-old} $ALL_APPS"
run_restore yes "$BK"
# A dump that could not be applied is a failed restore, not a success.
check "restore with a DB down exits 1" [ "$RC" -eq 1 ]
check "down DB gets no psql" not grep -Eq '^exec (-i )?donalabs-penpot-db ' "$FAKE_LOG"
check "down DB is reported" grep -q 'donalabs-penpot-db not running: its dump was NOT restored' <<< "$OUT"
check "down DB is in the final NOT restored list" grep -q 'NOT restored: database donalabs-penpot-db' <<< "$OUT"
check "a DB down does not say restore complete" not grep -q 'restore complete' <<< "$OUT"
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

# --- 7. the fake itself never runs a command outside the sandbox -------------
# The fake executes the script's real `sh -c` on the host. A command that names
# any other absolute path, or escapes with "..", must be refused, not run.
new_sandbox
mkdir -p "$SB/canary" && echo keep > "$SB/canary/file"
fake_run() { PATH="$SB/bin:$PATH" docker run --rm -v "donalabs_n8n_data:/dst" \
  -v "$SB/backups:/backup:ro" alpine:3.21 sh -c "$1" >/dev/null 2>&1; }
check "fake refuses a host path outside the sandbox" not fake_run "rm -rf $SB/canary /dst/*"
check "fake refuses '..' escaping the volume" not fake_run "rm -rf /dst/../../canary"
check "refused commands deleted nothing" [ -f "$SB/canary/file" ]
check "fake still runs a mapped command" fake_run "rm -rf /dst/* 2>/dev/null; true"
check "mapped command acted on the volume only" \
  bash -c "[ ! -e '$SB/vols/donalabs_n8n_data/data.txt' ] && [ -f '$SB/canary/file' ]"

# =============================================================================
# Regression tests for the restore.sh bugs found by the tests above. Each one
# FAILED against the previous restore.sh (see the PR description).
# =============================================================================

# Snapshot of every volume, to prove "left untouched".
snap_vols() { rm -rf "$SB/before"; cp -a "$SB/vols" "$SB/before"; }
vol_unchanged() { diff -r "$SB/before/$1" "$SB/vols/$1" >/dev/null 2>&1; }

# --- 8. a failed psql is a failed restore (bug 2) -----------------------------
new_sandbox
take_backup
export FAKE_PSQL_FAIL=donalabs-n8n-db
run_restore yes "$BK"
check "psql failure exits 1" [ "$RC" -eq 1 ]
check "psql failure does not say restore complete" not grep -q 'restore complete' <<< "$OUT"
check "psql failure is in the NOT restored list" grep -q 'NOT restored: database donalabs-n8n-db' <<< "$OUT"
check "failed database is never swapped in" not grep -q 'RENAME TO "n8n"' "$FAKE_LOG"
check "the other databases are still restored" pg_restored donalabs-calcom-db calcom calendso
check "failed load drops its temporary database" grep -q '^exec donalabs-n8n-db psql .*DROP DATABASE IF EXISTS "n8n__restoring"$' "$FAKE_LOG"

# --- 9. corrupt files are caught before anything is touched (bug 3) -----------
new_sandbox
take_backup
head -c 100 "$BK/donalabs_n8n_data_vol.tar.gz" > "$SB/t" && mv "$SB/t" "$BK/donalabs_n8n_data_vol.tar.gz"
echo "changed" > "$SB/vols/donalabs_n8n_data/data.txt"
snap_vols
run_restore yes "$BK"
check "corrupt tarball exits 1" [ "$RC" -eq 1 ]
check "corrupt tarball is named" grep -q 'corrupt or unreadable: donalabs_n8n_data_vol.tar.gz' <<< "$OUT"
check "corrupt tarball: nothing touched (not even other volumes/DBs)" not touched_data
check "corrupt tarball: its volume keeps its current data" vol_unchanged donalabs_n8n_data
check "corrupt tarball: not even asked to confirm" not grep -q "Type 'yes'" <<< "$OUT"

new_sandbox
take_backup
printf 'not gzip' > "$BK/donalabs-penpot-db_pg.sql.gz"
run_restore yes "$BK"
check "corrupt dump exits 1 and touches nothing" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"
check "corrupt dump is named" grep -q 'corrupt or unreadable: donalabs-penpot-db_pg.sql.gz' <<< "$OUT"

# A tarball that lists fine but cannot be extracted (a member "sub" that is a
# file, then "sub/x"): the old volume content must survive, with no leftovers.
new_sandbox
take_backup
mkdir -p "$SB/bad/a" "$SB/bad/b/sub" && echo f > "$SB/bad/a/sub" && echo x > "$SB/bad/b/sub/x"
tar cf "$SB/bad/t.tar" -C "$SB/bad/a" sub && tar rf "$SB/bad/t.tar" -C "$SB/bad/b" sub/x
gzip -c "$SB/bad/t.tar" > "$BK/donalabs_n8n_data_vol.tar.gz"
echo "changed" > "$SB/vols/donalabs_n8n_data/data.txt"
snap_vols
run_restore yes "$BK"
check "failed extraction exits 1" [ "$RC" -eq 1 ]
check "failed extraction: old volume content is intact" vol_unchanged donalabs_n8n_data
check "failed extraction: no staging dir left behind" [ ! -e "$SB/vols/donalabs_n8n_data/.donalabs-restore" ]
check "failed extraction: its container is restarted (data is intact)" grep -qx 'start donalabs-n8n' "$FAKE_LOG"
check "failed extraction is reported" grep -q 'NOT restored: volume donalabs_n8n_data$' <<< "$OUT"
check "failed extraction: other volumes still restored" \
  diff -r "$SB/before/donalabs_vaultwarden_data" "$SB/vols/donalabs_vaultwarden_data"

# The container run itself fails (state unknown): do NOT start apps on it.
new_sandbox
take_backup
export FAKE_TAR_FAIL=donalabs_penpot_assets
run_restore yes "$BK"
check "unknown volume failure exits 1" [ "$RC" -eq 1 ]
check "unknown volume failure: its containers are left stopped" \
  bash -c "! grep -Eqx 'start donalabs-penpot-(frontend|backend)' '$FAKE_LOG'"
check "unknown volume failure: says they were left stopped" grep -q 'left STOPPED on purpose' <<< "$OUT"
check "unknown volume failure: other containers restarted" grep -qx 'start donalabs-n8n' "$FAKE_LOG"

# --- 10. a stopped container that mounts a volume is not started (bug 4) -------
new_sandbox
take_backup
export FAKE_RUNNING="${FAKE_RUNNING/donalabs-vaultwarden /}"
run_restore yes "$BK"
check "restore with a stopped app exits 0" [ "$RC" -eq 0 ]
check "stopped app is not started by the restore" not grep -qx 'start donalabs-vaultwarden' "$FAKE_LOG"
check "its volume is still restored" grep -q -- '-v donalabs_vaultwarden_data:/dst ' "$FAKE_LOG"
check "running apps are still restarted" grep -qx 'start donalabs-open-webui' "$FAKE_LOG"

# A container that cannot be stopped: its volume is not rewritten under it.
export FAKE_STOP_FAIL=donalabs-penpot-backend
run_restore yes "$BK"
check "unstoppable container exits 1" [ "$RC" -eq 1 ]
check "unstoppable container: its volume is not rewritten" not grep -q -- '-v donalabs_penpot_assets:/dst ' "$FAKE_LOG"
check "unstoppable container: what was stopped is restarted" \
  bash -c "! grep -qx 'stop donalabs-penpot-frontend' '$FAKE_LOG' || grep -qx 'start donalabs-penpot-frontend' '$FAKE_LOG'"
check "unstoppable container is reported" grep -q 'could not stop donalabs-penpot-backend' <<< "$OUT"

# --- 11. MANIFEST.txt is read (bug 5) -----------------------------------------
new_sandbox
export FAKE_RUNNING="${FAKE_RUNNING/donalabs-penpot-db /}"
take_backup                                       # penpot DB down: INCOMPLETE
check "setup: backup is INCOMPLETE" grep -qx 'STATUS: INCOMPLETE' "$BK/MANIFEST.txt"
export FAKE_RUNNING="$ALL_PG $ALL_APPS"
run_restore yes "$BK"
check "incomplete backup is refused (exit 1)" [ "$RC" -eq 1 ]
check "incomplete backup: nothing touched" not touched_data
check "incomplete backup: says why" grep -q 'STATUS: INCOMPLETE' <<< "$OUT"
check "incomplete backup: shows what was skipped" grep -q 'SKIP pg   donalabs-penpot-db' <<< "$OUT"
check "incomplete backup: suggests --allow-incomplete" grep -q -- '--allow-incomplete' <<< "$OUT"
run_restore yes "$BK" --allow-incomplete
check "--allow-incomplete restores what is there (exit 0)" [ "$RC" -eq 0 ]
check "--allow-incomplete restored a database" pg_restored donalabs-calcom-db calcom calendso
check "--allow-incomplete leaves the missing one alone" not grep -q 'donalabs-penpot-db' "$FAKE_LOG"

new_sandbox
take_backup
sed -i '/^STATUS:/d' "$BK/MANIFEST.txt"
run_restore yes "$BK"
check "manifest without STATUS (interrupted backup) is refused" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"
rm "$BK/MANIFEST.txt"
run_restore yes "$BK"
check "backup without MANIFEST.txt is refused" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"

new_sandbox
take_backup
rm "$BK/donalabs_open_webui_data_vol.tar.gz"
run_restore yes "$BK"
check "COMPLETE backup with a listed file missing is refused" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"
check "the missing file is named" grep -q 'lists donalabs_open_webui_data_vol.tar.gz but it is missing' <<< "$OUT"

# --- 12. a long `docker ps` cannot fake "not running" via SIGPIPE (bug 6) -------
# grep -q stops reading at the first match; with more than a pipe buffer still
# to write, `docker ps` dies of SIGPIPE and pipefail turned that into "no".
new_sandbox
take_backup
# ~100 KB: more than a pipe buffer (64 KB), less than the 128 KB a single
# environment variable may hold.
filler="$(seq -f 'donalabs-filler-container-%06g' 1 3000 | tr '\n' ' ')"
export FAKE_RUNNING="$ALL_PG $ALL_APPS $filler"
run_restore yes "$BK"
check "long docker ps list: restore exits 0" [ "$RC" -eq 0 ]
check "long docker ps list: all 4 databases restored" bash -c "[ \$(grep -c '^exec -i ' '$FAKE_LOG') -eq 4 ]"

# --- 13. misc guards ------------------------------------------------------------
new_sandbox
take_backup
run_restore yes "$BK" --bogus
check "unknown option exits 1 and touches nothing" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"
run_restore yes --help
check "--help exits 0" [ "$RC" -eq 0 ]
check "--help documents --allow-incomplete" grep -q -- '--allow-incomplete' <<< "$OUT"
mkdir "$SB/backups/empty" && printf 'x\nSTATUS: COMPLETE\n' > "$SB/backups/empty/MANIFEST.txt"
run_restore yes "$SB/backups/empty"
check "a backup with nothing to restore exits 1" [ "$RC" -eq 1 ]
check "a backup with nothing to restore says so" grep -q 'nothing to restore' <<< "$OUT"

# --- 14. encryption keys: .env must match the backup's env.backup (bug 7) -----
# Restored n8n / Cal.com / Plausible / Open WebUI data is only readable with the
# key it was written with. A different key in .env is refused before anything is
# touched (or asked), and no key value is ever printed.
OLD_N8N=old-n8n-key-0123456789abcdef OLD_CAL=old-calcom-key-0123456789
keyed_env() {   # a sandbox whose .env has real-looking keys
  new_sandbox
  cat >> "$SB/.env" <<EOF
N8N_ENCRYPTION_KEY=$OLD_N8N
CALCOM_ENCRYPTION_KEY='$OLD_CAL'
PLAUSIBLE_TOTP_VAULT_KEY=old-totp-key
OPENWEBUI_SECRET_KEY=old-webui-key
CALCOM_NEXTAUTH_SECRET=old-nextauth
PLAUSIBLE_SECRET_KEY_BASE=old-skb
PENPOT_SECRET_KEY=old-penpot
EOF
}
keyed_sandbox() { keyed_env; take_backup; }   # ... and a full backup of it
set_env() { sed -i "/^$1=/d" "$SB/.env"; [ "$#" -lt 2 ] || echo "$1=$2" >> "$SB/.env"; }
no_secret_printed() { ! grep -qE "$OLD_N8N|new-n8n-key|$OLD_CAL|new-calcom-key" <<< "$OUT"; }

keyed_sandbox
check "setup: backup with keys is complete" [ "$RC" -eq 0 ]
# Same keys, different format (CRLF, quotes, export, reordered): not a mismatch.
{ printf 'export N8N_ENCRYPTION_KEY="%s"\r\n' "$OLD_N8N"; grep -v '^N8N_ENCRYPTION_KEY=' "$SB/.env"; } > "$SB/env.new"
mv "$SB/env.new" "$SB/.env"
run_restore yes "$BK"
check "same keys in another format: restore exits 0" [ "$RC" -eq 0 ]
check "same keys: no key warning" not grep -q 'differs from env.backup' <<< "$OUT"

keyed_sandbox
set_env N8N_ENCRYPTION_KEY new-n8n-key-regenerated
run_restore yes "$BK"
check "n8n key changed: refused (exit 1)" [ "$RC" -eq 1 ]
check "n8n key changed: nothing touched" not touched_data
check "n8n key changed: not even asked to confirm" not grep -q "Type 'yes'" <<< "$OUT"
check "n8n key changed: names the key" grep -q 'N8N_ENCRYPTION_KEY differs from env.backup' <<< "$OUT"
check "n8n key changed: says to copy the key from env.backup" grep -qF "above from $BK/env.backup into .env" <<< "$OUT"
check "n8n key changed: offers --ignore-key-mismatch" grep -q -- '--ignore-key-mismatch' <<< "$OUT"
check "n8n key changed: says to recreate the containers" grep -q './start.sh' <<< "$OUT"
check "n8n key changed: no key value is printed" no_secret_printed
check "n8n key changed: only that key is reported" not grep -q 'CALCOM_ENCRYPTION_KEY' <<< "$OUT"

run_restore yes "$BK" --ignore-key-mismatch
check "--ignore-key-mismatch restores anyway (exit 0)" [ "$RC" -eq 0 ]
check "--ignore-key-mismatch warns what will be unreadable" grep -q 'will NOT be readable' <<< "$OUT"
check "--ignore-key-mismatch restored n8n" pg_restored donalabs-n8n-db n8n n8n
check "--ignore-key-mismatch: no key value is printed" no_secret_printed

keyed_sandbox
set_env CALCOM_ENCRYPTION_KEY            # removed from .env entirely
set_env OPENWEBUI_SECRET_KEY ""           # or emptied
run_restore yes "$BK"
check "key removed / emptied in .env: refused" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"
check "removed key is reported" grep -q 'CALCOM_ENCRYPTION_KEY differs' <<< "$OUT"
check "emptied key is reported" grep -q 'OPENWEBUI_SECRET_KEY differs' <<< "$OUT"

# Only keys of what is being restored count: an n8n-only backup does not care
# about Cal.com's key.
keyed_env
export FAKE_RUNNING="donalabs-n8n-db donalabs-n8n" FAKE_VOLUMES="donalabs_n8n_data"
take_backup --allow-partial
check "setup: n8n-only backup" bash -c "[ $RC -eq 0 ] && [ ! -e '$BK/donalabs-calcom-db_pg.sql.gz' ]"
export FAKE_RUNNING="$ALL_PG $ALL_APPS" FAKE_VOLUMES="$ALL_VOLS"
set_env CALCOM_ENCRYPTION_KEY new-calcom-key
run_restore yes "$BK"
check "key of a service not in the backup: restore exits 0" [ "$RC" -eq 0 ]
check "key of a service not in the backup: not reported" not grep -q 'CALCOM_ENCRYPTION_KEY' <<< "$OUT"

# A session-only key: warn, do not block (people log in again, no data lost).
keyed_sandbox
set_env PENPOT_SECRET_KEY new-penpot
run_restore yes "$BK"
check "session key changed: restore exits 0" [ "$RC" -eq 0 ]
check "session key changed: warned" grep -q 'PENPOT_SECRET_KEY differs from env.backup: sessions' <<< "$OUT"

# env.backup missing: a COMPLETE manifest lists it, so the backup is incomplete.
keyed_sandbox
rm "$BK/env.backup"
run_restore yes "$BK"
check "env.backup missing: refused, nothing touched" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"
check "env.backup missing: says so" grep -q 'MANIFEST lists env.backup but it is missing' <<< "$OUT"
run_restore yes "$BK" --allow-incomplete
check "env.backup missing + --allow-incomplete: restores (exit 0)" [ "$RC" -eq 0 ]
check "env.backup missing + --allow-incomplete: warns keys are unchecked" grep -q 'cannot check that the encryption keys' <<< "$OUT"

# A key the backup's env.backup never had (older backup): cannot check, warn.
keyed_sandbox
sed -i '/^OPENWEBUI_SECRET_KEY=/d' "$BK/env.backup"
run_restore yes "$BK"
check "key absent from env.backup: restore exits 0" [ "$RC" -eq 0 ]
check "key absent from env.backup: warned" grep -q 'env.backup has no OPENWEBUI_SECRET_KEY' <<< "$OUT"

# env.backup the restoring user cannot read: refuse (root reads anything, skip).
if [ "$(id -u)" -ne 0 ]; then
  keyed_sandbox
  chmod 000 "$BK/env.backup"
  run_restore yes "$BK"
  check "unreadable env.backup: refused, nothing touched" bash -c "[ $RC -eq 1 ] && ! grep -Eq '^(exec |run |stop |start )' '$FAKE_LOG'"
  check "unreadable env.backup: says so" grep -q 'env.backup is not readable' <<< "$OUT"
  chmod 600 "$BK/env.backup"
fi

run_restore yes --help
check "--help documents --ignore-key-mismatch" grep -q -- '--ignore-key-mismatch' <<< "$OUT"

echo
echo "restore.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
