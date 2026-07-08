#!/usr/bin/env bash
# =============================================================================
# DonaLabs — restore from a backup directory produced by ./backup.sh
#
#   ./scripts/restore.sh backups/<timestamp>
#
# Restores Postgres logical dumps and named-volume tarballs. The stack should be
# running (databases up) for the Postgres restores; volume restores stop the
# affected container, replace the volume contents, and restart it.
#
# WARNING: this OVERWRITES current data. Take a fresh backup first if unsure.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/lib.sh"

require_docker
load_env

SRC="${1:-}"
[ -n "$SRC" ] && [ -d "$SRC" ] || { err "usage: ./scripts/restore.sh backups/<timestamp>"; exit 1; }
SRC="$(cd "$SRC" && pwd)"

warn "This will OVERWRITE current data from: $SRC"
printf "Type 'yes' to continue: "; read -r ans
[ "$ans" = "yes" ] || { info "aborted"; exit 0; }

# --- Postgres restores -------------------------------------------------------
for entry in "${PG_DATABASES[@]}"; do
  IFS=: read -r container uvar dvar <<< "$entry"
  user="${!uvar:-}"; db="${!dvar:-}"
  dump="${SRC}/${container}_pg.sql.gz"
  [ -f "$dump" ] || { warn "no dump for $container, skipping"; continue; }
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    info "restoring $container ($db)..."
    gunzip -c "$dump" | docker exec -i "$container" psql -U "$user" -d "$db" >/dev/null \
      && ok "restored $container" || err "restore failed for $container"
  else
    warn "$container not running, skipping"
  fi
done

# --- Volume restores ---------------------------------------------------------
for vol in "${DATA_VOLUMES[@]}"; do
  tar="${SRC}/${vol}_vol.tar.gz"
  [ -f "$tar" ] || continue
  info "restoring volume $vol..."
  # stop containers using the volume to avoid corruption
  users=$(docker ps -a --filter "volume=$vol" --format '{{.Names}}')
  for c in $users; do docker stop "$c" >/dev/null 2>&1 || true; done
  docker run --rm -v "${vol}:/dst" -v "${SRC}:/backup:ro" alpine:3.21 \
    sh -c "rm -rf /dst/* /dst/..?* /dst/.[!.]* 2>/dev/null; tar xzf /backup/$(basename "$tar") -C /dst" \
    && ok "restored volume $vol" || err "restore failed for volume $vol"
  for c in $users; do docker start "$c" >/dev/null 2>&1 || true; done
done

ok "restore complete. Verify with: ./scripts/health.sh"
