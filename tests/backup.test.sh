#!/usr/bin/env bash
# Tests for backup.sh: completeness verdict, exit status, retention safety and
# --consistent restarts. Runs against tests/fakes/docker — no Docker daemon needed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

ALL_PG="donalabs-calcom-db donalabs-plausible-db donalabs-penpot-db donalabs-n8n-db"
ALL_APPS="donalabs-vaultwarden donalabs-open-webui donalabs-n8n donalabs-plausible donalabs-penpot-backend"
ALL_VOLS="donalabs_vaultwarden_data donalabs_open_webui_data donalabs_n8n_data donalabs_penpot_assets donalabs_plausible_data donalabs_plausible_event_data"

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }

# Fresh copy of the repo bits backup.sh needs, a .env and the fake docker on PATH.
new_sandbox() {
  SB="$(mktemp -d)"
  mkdir -p "$SB/scripts" "$SB/backups" "$SB/bin"
  cp "$REPO/backup.sh" "$SB/"
  cp "$REPO/scripts/lib.sh" "$SB/scripts/"
  cp "$HERE/fakes/docker" "$SB/bin/docker"
  chmod +x "$SB/bin/docker" "$SB/backup.sh"
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
  export FAKE_RUNNING="$ALL_PG $ALL_APPS" FAKE_VOLUMES="$ALL_VOLS"
  export FAKE_PGDUMP_FAIL="" FAKE_TAR_FAIL="" FAKE_LOG="$SB/docker.log"
  unset BACKUP_RETENTION
}

# Pre-existing backup dirs, oldest first, with real past mtimes.
# old_backups <count> [incomplete]
old_backups() {
  local n="$1" status="${2:-COMPLETE}" i
  for i in $(seq "$n" -1 1); do
    local d="$SB/backups/2020010${i}-000000"
    mkdir -p "$d"
    printf 'old\nSTATUS: %s\n' "$status" > "$d/MANIFEST.txt"
    touch -d "$((i + 10)) days ago" "$d"
  done
}

run_backup() {
  set +e
  OUT="$(PATH="$SB/bin:$PATH" "$SB/backup.sh" "$@" 2>&1)"
  RC=$?
  set -e
}

# The backup this run created (the only dir not named 2020...).
new_dir() { find "$SB/backups" -mindepth 1 -maxdepth 1 -type d ! -name '2020*' | head -1; }
count_dirs() { find "$SB/backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '; }

echo "backup.sh"

# --- 1. everything up: complete, exit 0, all artifacts present -----------------
new_sandbox
run_backup
D="$(new_dir)"
check "complete run exits 0" [ "$RC" -eq 0 ]
check "4 pg dumps written" [ "$(find "$D" -name '*_pg.sql.gz' | wc -l | tr -d ' ')" -eq 4 ]
check "6 volume tarballs written" [ "$(find "$D" -name '*_vol.tar.gz' | wc -l | tr -d ' ')" -eq 6 ]
check "env.backup is mode 600" [ "$(stat -c %a "$D/env.backup")" = "600" ]
check "manifest says COMPLETE" grep -qx 'STATUS: COMPLETE' "$D/MANIFEST.txt"
rm -rf "$SB"

# --- 2. stack stopped: INCOMPLETE, exit 1, good backups NOT rotated away ------
new_sandbox
old_backups 7
export FAKE_RUNNING=""   # every container down (e.g. after ./stop.sh)
run_backup
D="$(new_dir)"
check "stopped stack exits 1" [ "$RC" -eq 1 ]
check "manifest says INCOMPLETE" grep -qx 'STATUS: INCOMPLETE' "$D/MANIFEST.txt"
check "skips are listed in manifest" grep -q '^SKIP pg   donalabs-n8n-db' "$D/MANIFEST.txt"
check "all 7 old backups kept (no prune)" [ "$(find "$SB/backups" -name '2020*' -type d | wc -l | tr -d ' ')" -eq 7 ]
check "output suggests --allow-partial" grep -q -- '--allow-partial' <<< "$OUT"
rm -rf "$SB"

# --- 3. same situation repeated: still never prunes ---------------------------
new_sandbox
old_backups 7
export FAKE_RUNNING=""
for _ in 1 2 3; do run_backup; sleep 1; done
check "3 incomplete runs keep all 7 good backups" [ "$(find "$SB/backups" -name '2020*' -type d | wc -l | tr -d ' ')" -eq 7 ]
rm -rf "$SB"

# --- 4. --allow-partial accepts skips (subset of the stack) -------------------
new_sandbox
old_backups 7
export FAKE_RUNNING="donalabs-n8n-db donalabs-n8n" FAKE_VOLUMES="donalabs_n8n_data"
run_backup --allow-partial
D="$(new_dir)"
check "--allow-partial with skips exits 0" [ "$RC" -eq 0 ]
check "--allow-partial manifest says COMPLETE" grep -qx 'STATUS: COMPLETE' "$D/MANIFEST.txt"
check "retention applied: 7 dirs remain" [ "$(count_dirs)" -eq 7 ]
check "oldest backup pruned" [ ! -d "$SB/backups/20200107-000000" ]
rm -rf "$SB"

# --- 5. real failures are fatal even with --allow-partial ---------------------
new_sandbox
old_backups 7
export FAKE_PGDUMP_FAIL="donalabs-calcom-db"
run_backup --allow-partial
D="$(new_dir)"
check "pg_dump failure exits 1" [ "$RC" -eq 1 ]
check "failed dump file removed" [ ! -e "$D/donalabs-calcom-db_pg.sql.gz" ]
check "failure recorded in manifest" grep -q '^FAIL pg   donalabs-calcom-db' "$D/MANIFEST.txt"
check "no prune after failure" [ "$(find "$SB/backups" -name '2020*' -type d | wc -l | tr -d ' ')" -eq 7 ]
rm -rf "$SB"

new_sandbox
export FAKE_TAR_FAIL="donalabs_vaultwarden_data"
run_backup
check "volume tar failure exits 1" [ "$RC" -eq 1 ]
rm -rf "$SB"

# --- 6. retention counts only good backups ------------------------------------
new_sandbox
old_backups 3                       # 3 good ones, 11-13 days old
for i in 1 2; do                    # 2 newer incomplete ones, 1-2 days old
  d="$SB/backups/2020020${i}-000000"; mkdir -p "$d"
  printf 'STATUS: INCOMPLETE\n' > "$d/MANIFEST.txt"; touch -d "$i days ago" "$d"
done
export BACKUP_RETENTION=3
run_backup
check "complete run exits 0 (retention 3)" [ "$RC" -eq 0 ]
check "newest good old backup kept" [ -d "$SB/backups/20200101-000000" ]
check "2nd good old backup kept" [ -d "$SB/backups/20200102-000000" ]
check "3rd good backup pruned (new + 2 = 3 good)" [ ! -d "$SB/backups/20200103-000000" ]
check "recent incomplete backup 1 kept for inspection" [ -d "$SB/backups/20200201-000000" ]
check "recent incomplete backup 2 kept for inspection" [ -d "$SB/backups/20200202-000000" ]
rm -rf "$SB"

# --- 7. invalid BACKUP_RETENTION refuses to run -------------------------------
for bad in 0 -1 abc ""; do
  new_sandbox
  old_backups 2
  export BACKUP_RETENTION="$bad"
  [ -z "$bad" ] && unset BACKUP_RETENTION   # empty means "unset" -> default 7
  run_backup
  if [ -z "$bad" ]; then
    check "unset BACKUP_RETENTION uses default and succeeds" [ "$RC" -eq 0 ]
  else
    check "BACKUP_RETENTION='$bad' exits 2" [ "$RC" -eq 2 ]
    check "BACKUP_RETENTION='$bad' creates no backup and prunes nothing" [ "$(count_dirs)" -eq 2 ]
  fi
  rm -rf "$SB"
done

# --- 8. --consistent restarts exactly what it stopped -------------------------
new_sandbox
export FAKE_RUNNING="$ALL_PG donalabs-vaultwarden donalabs-n8n"   # other apps off
run_backup --consistent
check "--consistent exits 0" [ "$RC" -eq 0 ]
check "stopped vaultwarden" grep -qx 'stop donalabs-vaultwarden' "$FAKE_LOG"
check "restarted vaultwarden" grep -qx 'start donalabs-vaultwarden' "$FAKE_LOG"
check "restarted n8n" grep -qx 'start donalabs-n8n' "$FAKE_LOG"
check "did not start containers that were off" bash -c "! grep -qx 'start donalabs-open-webui' '$FAKE_LOG'"
check "restart happens after the volume snapshots" \
  bash -c "[ \$(grep -n '^run ' '$FAKE_LOG' | tail -1 | cut -d: -f1) -lt \$(grep -n '^start ' '$FAKE_LOG' | head -1 | cut -d: -f1) ]"
rm -rf "$SB"

# --- 9. unknown flags are rejected before doing anything ----------------------
new_sandbox
run_backup --consistant
check "typo'd flag exits 2" [ "$RC" -eq 2 ]
check "typo'd flag creates no backup" [ "$(count_dirs)" -eq 0 ]
rm -rf "$SB"

echo
echo "backup.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
