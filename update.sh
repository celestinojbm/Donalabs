#!/usr/bin/env bash
# =============================================================================
# DonaLabs — update services to the image tags currently pinned in .env
#
#   ./update.sh                update everything (backup first, then pull + recreate)
#   ./update.sh n8n            update only the named service(s)
#   ./update.sh --no-backup    skip the pre-update backup (Open WebUI still
#                              requires a backup < OPENWEBUI_BACKUP_MAX_AGE_MIN)
#
# To upgrade a service, bump its *_IMAGE_TAG in .env, then run this script.
# Always review each project's release notes before a major version bump.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/scripts/lib.sh"

require_docker
load_env
ensure_network

DO_BACKUP=1
if [ "${1:-}" = "--no-backup" ]; then DO_BACKUP=0; shift; fi

# --- Open WebUI guard --------------------------------------------------------
# Open WebUI releases (e.g. 0.12.3) can migrate its database irreversibly.
# Updating it therefore REQUIRES a pinned tag and a fresh backup of its volume.
OWUI_VOL="donalabs_open_webui_data"
OWUI_MAX_AGE_MIN="${OPENWEBUI_BACKUP_MAX_AGE_MIN:-60}"
touches_openwebui() {
  [ "$#" -eq 0 ] && return 0
  local s; for s in "$@"; do [ "$s" = "open-webui" ] && return 0; done
  return 1
}
fresh_openwebui_backup() {
  # prints the newest backup dir (names are sortable UTC stamps) whose MANIFEST
  # is newer than the max age, was taken with --consistent (containers stopped,
  # so the SQLite DB is not mid-write) and holds a readable Open WebUI tarball
  local d
  while IFS= read -r d; do
    [ -n "$(find "${d}MANIFEST.txt" -mmin "-${OWUI_MAX_AGE_MIN}" 2>/dev/null)" ] || continue
    grep -qx "mode consistent" "${d}MANIFEST.txt" || continue
    grep -q "^vol  ${OWUI_VOL} " "${d}MANIFEST.txt" || continue
    [ -s "${d}${OWUI_VOL}_vol.tar.gz" ] || continue
    tar tzf "${d}${OWUI_VOL}_vol.tar.gz" >/dev/null 2>&1 || continue
    printf '%s\n' "${d%/}"; return 0
  done < <(ls -1dr "${DONALABS_ROOT}/backups"/*/ 2>/dev/null)
  return 1
}
OWUI=0
if touches_openwebui "$@"; then
  OWUI=1
  [[ "${OPENWEBUI_IMAGE_TAG:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$ ]] \
    || die "OPENWEBUI_IMAGE_TAG must be an explicit version vX.Y.Z (e.g. v0.10.2), got '${OPENWEBUI_IMAGE_TAG:-<empty>}'"
fi

if [ "$DO_BACKUP" -eq 1 ]; then
  info "taking a safety backup before updating..."
  BACKUP_ARGS=()
  # Open WebUI uses SQLite: only a backup with its container stopped is safe
  # before an irreversible migration (brief downtime for the app containers).
  [ "$OWUI" -eq 1 ] && BACKUP_ARGS=(--consistent)
  if ! "${DONALABS_ROOT}/backup.sh" "${BACKUP_ARGS[@]}"; then
    [ "$OWUI" -eq 1 ] && die "backup failed — refusing to update Open WebUI without a backup"
    warn "backup failed — continuing (use --no-backup to skip intentionally)"
  fi
fi

if [ "$OWUI" -eq 1 ]; then
  VOLS="$(docker volume ls -q)" || die "cannot list Docker volumes — refusing to update Open WebUI"
  if grep -qx "$OWUI_VOL" <<< "$VOLS"; then
    B="$(fresh_openwebui_backup || true)"
    [ -n "$B" ] || die "no consistent Open WebUI backup newer than ${OWUI_MAX_AGE_MIN} min in backups/ — run ./backup.sh --consistent first (update aborted)"
    ok "Open WebUI backup verified: backups/$(basename "$B") (rollback: services/open-webui/README.md)"
  else
    info "Open WebUI volume does not exist yet (fresh install) — no backup needed"
  fi
fi

info "pulling images..."
dc pull "$@"

info "recreating containers with the new images..."
dc up -d "$@"

info "pruning dangling images..."
docker image prune -f >/dev/null 2>&1 || true

ok "update complete. Verify with: ./scripts/health.sh"
