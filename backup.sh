#!/usr/bin/env bash
# =============================================================================
# DonaLabs — backup
#
#   ./backup.sh                  back up all databases + data volumes + .env
#   ./backup.sh --consistent     stop app containers during volume snapshots for
#                                crash-consistent copies (brief downtime)
#   ./backup.sh --allow-partial  accept skipped components (a container that is
#                                not running, a volume that does not exist), e.g.
#                                when you deliberately run only a subset of the
#                                stack. Real failures (pg_dump/tar errors) still
#                                fail the backup.
#
# Output: backups/<timestamp>/ containing:
#   *_pg.sql.gz     logical Postgres dumps (Cal.com, Plausible, Penpot, n8n)
#   *_vol.tar.gz    tarballs of named data volumes (Vaultwarden, Open WebUI,
#                   n8n, Penpot assets, Plausible app data, ClickHouse events)
#   env.backup      a copy of .env (SECRETS — keep this backup private!)
#   MANIFEST.txt    what was captured, ending in "STATUS: COMPLETE" or
#                   "STATUS: INCOMPLETE"
#
# Exit status: 0 when the backup is complete, 1 when it is INCOMPLETE (anything
# skipped or failed), so cron mail / update.sh notice it. An incomplete backup is
# kept for inspection but NEVER triggers retention: old backups are pruned only
# after a complete one, so a stopped stack cannot rotate good backups away.
#
# Old backups beyond BACKUP_RETENTION (default 7, integer >= 1) are pruned.
# Restore with: ./scripts/restore.sh backups/<timestamp>
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/scripts/lib.sh"

usage() { sed -n '4,12p' "$0" | sed 's/^# \{0,1\}//'; }

CONSISTENT=0
ALLOW_PARTIAL=0
for arg in "$@"; do
  case "$arg" in
    --consistent)    CONSISTENT=1 ;;
    --allow-partial) ALLOW_PARTIAL=1 ;;
    -h|--help)       usage; exit 0 ;;
    *) err "unknown option: $arg"; usage >&2; exit 2 ;;
  esac
done

require_docker
load_env

# Validate retention BEFORE touching anything: 0, negatives or text would make the
# prune step delete every backup, including the one just taken.
RETENTION="${BACKUP_RETENTION:-7}"
if ! [[ "$RETENTION" =~ ^[0-9]+$ ]] || [ "$RETENTION" -lt 1 ]; then
  err "BACKUP_RETENTION must be an integer >= 1 (got '${RETENTION}')"
  exit 2
fi

STAMP="$(date -u +%Y%m%d-%H%M%S)"
DEST="${DONALABS_ROOT}/backups/${STAMP}"
mkdir -p "$DEST"
MANIFEST="${DEST}/MANIFEST.txt"
echo "DonaLabs backup ${STAMP} (UTC)" > "$MANIFEST"

info "backup destination: backups/${STAMP}"

FAILED=()   # hard errors: always make the backup incomplete
SKIPPED=()  # missing components: incomplete unless --allow-partial

# Snapshot running containers once. Piping `docker ps` straight into `grep -q`
# under pipefail can report "not running" when grep exits early (SIGPIPE).
RUNNING="$(docker ps --format '{{.Names}}')"
is_running() { grep -qx -- "$1" <<< "$RUNNING"; }

# --- 1. Postgres logical dumps ----------------------------------------------
for entry in "${PG_DATABASES[@]}"; do
  IFS=: read -r container uvar dvar <<< "$entry"
  user="${!uvar:-}"; db="${!dvar:-}"
  if is_running "$container"; then
    out="${DEST}/${container}_pg.sql.gz"
    if docker exec "$container" pg_dump -U "$user" -d "$db" 2>/dev/null | gzip > "$out"; then
      ok "pg_dump $container ($db) -> $(basename "$out") ($(du -h "$out" | cut -f1))"
      echo "pg   $container db=$db -> $(basename "$out")" >> "$MANIFEST"
    else
      err "pg_dump failed for $container"; rm -f "$out"
      FAILED+=("pg_dump $container")
      echo "FAIL pg   $container" >> "$MANIFEST"
    fi
  else
    warn "skip $container (not running)"
    SKIPPED+=("pg $container (not running)")
    echo "SKIP pg   $container (not running)" >> "$MANIFEST"
  fi
done

# --- 2. Named data volume snapshots -----------------------------------------
# app containers that write to the volumes we tar (for --consistent mode)
STOP_FOR_CONSISTENCY=(donalabs-vaultwarden donalabs-open-webui donalabs-n8n donalabs-plausible donalabs-penpot-backend)
STOPPED=()
restart_stopped() {
  [ "${#STOPPED[@]}" -gt 0 ] || return 0
  info "restarting app containers..."
  for c in "${STOPPED[@]}"; do docker start "$c" >/dev/null 2>&1 || warn "could not restart $c"; done
  STOPPED=()
}
# Whatever happens below (error, Ctrl-C), never leave the apps stopped.
trap restart_stopped EXIT

if [ "$CONSISTENT" -eq 1 ]; then
  info "consistent mode: stopping app containers during snapshot..."
  for c in "${STOP_FOR_CONSISTENCY[@]}"; do
    # only restart what we actually stopped (don't start something that was off)
    if is_running "$c" && docker stop "$c" >/dev/null 2>&1; then STOPPED+=("$c"); fi
  done
fi

for vol in "${DATA_VOLUMES[@]}"; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    out="${DEST}/${vol}_vol.tar.gz"
    if docker run --rm -v "${vol}:/src:ro" -v "${DEST}:/backup" alpine:3.21 \
         sh -c "tar czf /backup/$(basename "$out") -C /src ."; then
      ok "volume $vol -> $(basename "$out") ($(du -h "$out" | cut -f1))"
      echo "vol  $vol -> $(basename "$out")" >> "$MANIFEST"
    else
      err "tar failed for volume $vol"; rm -f "$out"
      FAILED+=("tar $vol")
      echo "FAIL vol  $vol" >> "$MANIFEST"
    fi
  else
    warn "skip volume $vol (does not exist)"
    SKIPPED+=("vol $vol (does not exist)")
    echo "SKIP vol  $vol (does not exist)" >> "$MANIFEST"
  fi
done

restart_stopped

# --- 3. .env (contains encryption keys needed to decrypt restored data) ------
cp "${DONALABS_ROOT}/.env" "${DEST}/env.backup"
chmod 600 "${DEST}/env.backup"
echo "env  .env -> env.backup (SENSITIVE)" >> "$MANIFEST"
ok ".env copied to env.backup (keep this backup private)"

# --- 4. Verdict ---------------------------------------------------------------
complete=1
[ "${#FAILED[@]}" -eq 0 ] || complete=0
if [ "${#SKIPPED[@]}" -gt 0 ] && [ "$ALLOW_PARTIAL" -eq 0 ]; then complete=0; fi

if [ "$complete" -eq 0 ]; then
  echo "STATUS: INCOMPLETE" >> "$MANIFEST"
  echo
  for f in "${FAILED[@]+"${FAILED[@]}"}"; do err "failed:  $f"; done
  for s in "${SKIPPED[@]+"${SKIPPED[@]}"}"; do err "skipped: $s"; done
  err "backup INCOMPLETE: backups/${STAMP} kept for inspection; old backups NOT pruned."
  [ "${#FAILED[@]}" -gt 0 ] || err "if running only part of the stack is intentional, re-run with --allow-partial"
  exit 1
fi

echo "STATUS: COMPLETE" >> "$MANIFEST"

# --- 5. Retention (only after a complete backup) ------------------------------
# Keep the newest RETENTION backups that are NOT marked incomplete (backups from
# before this marker existed count as good). Incomplete backups newer than the
# oldest kept one stay for inspection; older ones are pruned.
kept=0
while IFS= read -r d; do
  [ -n "$d" ] || continue
  d="$(cd "$d" && pwd)"
  if [ "$d" = "$DEST" ]; then kept=$((kept+1)); continue; fi  # never prune this run
  if ! grep -qx 'STATUS: INCOMPLETE' "$d/MANIFEST.txt" 2>/dev/null && [ "$kept" -lt "$RETENTION" ]; then
    kept=$((kept+1)); continue
  fi
  [ "$kept" -ge "$RETENTION" ] || continue  # incomplete but still within the window
  rm -rf "$d" && info "pruned old backup $(basename "$d")"
done < <(ls -1dt "${DONALABS_ROOT}/backups"/*/ 2>/dev/null)

echo
ok "backup complete: backups/${STAMP} ($(du -sh "$DEST" | cut -f1))"
