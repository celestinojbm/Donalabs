#!/usr/bin/env bash
# =============================================================================
# DonaLabs — backup
#
#   ./backup.sh                 back up all databases + data volumes + .env
#   ./backup.sh --consistent    stop app containers during volume snapshots for
#                               crash-consistent copies (brief downtime)
#
# Output: backups/<timestamp>/ containing:
#   *_pg.sql.gz     logical Postgres dumps (Cal.com, Plausible, Penpot, n8n)
#   *_vol.tar.gz    tarballs of named data volumes (Vaultwarden, Open WebUI,
#                   n8n, Penpot assets, Plausible app data, ClickHouse events)
#   env.backup      a copy of .env (SECRETS — keep this backup private!)
#   MANIFEST.txt    what was captured
#
# Old backups beyond BACKUP_RETENTION (default 7) are pruned.
# Restore with: ./scripts/restore.sh backups/<timestamp>
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/scripts/lib.sh"

require_docker
load_env

CONSISTENT=0
[ "${1:-}" = "--consistent" ] && CONSISTENT=1

STAMP="$(date -u +%Y%m%d-%H%M%S)"
DEST="${DONALABS_ROOT}/backups/${STAMP}"
mkdir -p "$DEST"
MANIFEST="${DEST}/MANIFEST.txt"
echo "DonaLabs backup ${STAMP} (UTC)" > "$MANIFEST"

info "backup destination: backups/${STAMP}"

# --- 1. Postgres logical dumps ----------------------------------------------
for entry in "${PG_DATABASES[@]}"; do
  IFS=: read -r container uvar dvar <<< "$entry"
  user="${!uvar:-}"; db="${!dvar:-}"
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    out="${DEST}/${container}_pg.sql.gz"
    if docker exec "$container" pg_dump -U "$user" -d "$db" 2>/dev/null | gzip > "$out"; then
      ok "pg_dump $container ($db) -> $(basename "$out") ($(du -h "$out" | cut -f1))"
      echo "pg   $container db=$db -> $(basename "$out")" >> "$MANIFEST"
    else
      warn "pg_dump failed for $container (is it running?)"; rm -f "$out"
    fi
  else
    warn "skip $container (not running)"
  fi
done

# --- 2. Named data volume snapshots -----------------------------------------
# app containers that write to the volumes we tar (for --consistent mode)
STOP_FOR_CONSISTENCY=(donalabs-vaultwarden donalabs-open-webui donalabs-n8n donalabs-plausible donalabs-penpot-backend)
if [ "$CONSISTENT" -eq 1 ]; then
  info "consistent mode: stopping app containers during snapshot..."
  for c in "${STOP_FOR_CONSISTENCY[@]}"; do docker stop "$c" >/dev/null 2>&1 || true; done
fi

for vol in "${DATA_VOLUMES[@]}"; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    out="${DEST}/${vol}_vol.tar.gz"
    docker run --rm -v "${vol}:/src:ro" -v "${DEST}:/backup" alpine:3.21 \
      sh -c "tar czf /backup/$(basename "$out") -C /src ." \
      && { ok "volume $vol -> $(basename "$out") ($(du -h "$out" | cut -f1))"; \
           echo "vol  $vol -> $(basename "$out")" >> "$MANIFEST"; } \
      || { warn "tar failed for volume $vol"; rm -f "$out"; }
  else
    warn "skip volume $vol (does not exist)"
  fi
done

if [ "$CONSISTENT" -eq 1 ]; then
  info "restarting app containers..."
  for c in "${STOP_FOR_CONSISTENCY[@]}"; do docker start "$c" >/dev/null 2>&1 || true; done
fi

# --- 3. .env (contains encryption keys needed to decrypt restored data) ------
cp "${DONALABS_ROOT}/.env" "${DEST}/env.backup"
chmod 600 "${DEST}/env.backup"
echo "env  .env -> env.backup (SENSITIVE)" >> "$MANIFEST"
ok ".env copied to env.backup (keep this backup private)"

# --- 4. Retention ------------------------------------------------------------
RETENTION="${BACKUP_RETENTION:-7}"
mapfile -t OLD < <(ls -1dt "${DONALABS_ROOT}/backups"/*/ 2>/dev/null | tail -n +"$((RETENTION+1))")
for d in "${OLD[@]:-}"; do [ -n "$d" ] && rm -rf "$d" && info "pruned old backup $(basename "$d")"; done

echo
ok "backup complete: backups/${STAMP} ($(du -sh "$DEST" | cut -f1))"
