#!/usr/bin/env bash
# =============================================================================
# DonaLabs — restore from a backup directory produced by ./backup.sh
#
#   ./scripts/restore.sh backups/<timestamp>
#   ./scripts/restore.sh backups/<timestamp> --allow-incomplete
#
#   --allow-incomplete  restore what a backup contains even though its
#                       MANIFEST.txt is not "STATUS: COMPLETE" (an incomplete
#                       backup, an interrupted one, or one from before the
#                       marker existed) or lists a file that is missing.
#
# Restores Postgres logical dumps and named-volume tarballs. The databases must
# be running. Every file is integrity-checked BEFORE anything is touched.
#
#   Postgres: each dump is loaded into a temporary database with ON_ERROR_STOP
#     in a single transaction, then swapped in by renaming. The live database is
#     only replaced if the whole dump loaded; the previous one is kept as
#     <db>__pre_restore_<timestamp> so the restore can be undone.
#   Volumes: running containers that use the volume are stopped, the tarball is
#     extracted into a staging dir inside the volume, and only then does it
#     replace the old contents. If extraction fails the old data is untouched.
#
# Exit status: 0 only if everything in the backup was restored, 1 otherwise.
#
# WARNING: this OVERWRITES current data. Take a fresh backup first if unsure.
# =============================================================================
set -euo pipefail
. "$(dirname "$0")/lib.sh"

usage() { sed -n '4,10p' "$0" | sed 's/^# \{0,1\}//'; }

SRC="" ALLOW_INCOMPLETE=0
for arg in "$@"; do
  case "$arg" in
    --allow-incomplete) ALLOW_INCOMPLETE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) err "unknown option: $arg"; err "usage: ./scripts/restore.sh backups/<timestamp> [--allow-incomplete]"; exit 1 ;;
    *) [ -z "$SRC" ] || { err "only one backup directory, got '$SRC' and '$arg'"; exit 1; }
       SRC="$arg" ;;
  esac
done

require_docker
load_env

if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  err "usage: ./scripts/restore.sh backups/<timestamp> [--allow-incomplete]"; exit 1
fi
SRC="$(cd "$SRC" && pwd)"   # absolute: a relative path would be a named volume to `docker -v`

# --- 1. Is this backup complete? (read-only) ----------------------------------
MANIFEST="${SRC}/MANIFEST.txt"
problems=()
if [ ! -f "$MANIFEST" ]; then
  problems+=("no MANIFEST.txt")
elif grep -qx 'STATUS: COMPLETE' "$MANIFEST"; then
  # Every file the manifest says was captured must still be there.
  while IFS= read -r f; do
    [ -f "${SRC}/${f}" ] || problems+=("MANIFEST lists ${f} but it is missing")
  done < <(awk '($1 == "pg" || $1 == "vol") && $(NF-1) == "->" { print $NF }' "$MANIFEST")
elif grep -qx 'STATUS: INCOMPLETE' "$MANIFEST"; then
  problems+=("MANIFEST.txt says STATUS: INCOMPLETE")
  while IFS= read -r l; do problems+=("  $l"); done < <(grep -E '^(FAIL|SKIP) ' "$MANIFEST" || true)
else
  problems+=("MANIFEST.txt has no STATUS line (interrupted backup, or one from before the marker)")
fi
if [ "${#problems[@]}" -gt 0 ]; then
  for p in "${problems[@]}"; do warn "$p"; done
  if [ "$ALLOW_INCOMPLETE" -eq 0 ]; then
    err "refusing to restore a backup that is not known to be complete: $SRC"
    err "to restore what it does contain anyway, re-run with --allow-incomplete"
    exit 1
  fi
  warn "--allow-incomplete: restoring whatever this backup contains"
fi

# --- 2. What will be restored, and is every file readable? (read-only) --------
PLAN_PG=() PLAN_VOL=() corrupt=()
for entry in "${PG_DATABASES[@]}"; do
  IFS=: read -r container _ _ <<< "$entry"
  dump="${SRC}/${container}_pg.sql.gz"
  [ -f "$dump" ] || { warn "no dump for $container, skipping"; continue; }
  if gzip -t "$dump" 2>/dev/null; then PLAN_PG+=("$entry"); else corrupt+=("$(basename "$dump")"); fi
done
for vol in "${DATA_VOLUMES[@]}"; do
  tar="${SRC}/${vol}_vol.tar.gz"
  [ -f "$tar" ] || continue
  if tar tzf "$tar" >/dev/null 2>&1; then PLAN_VOL+=("$vol"); else corrupt+=("$(basename "$tar")"); fi
done
if [ "${#corrupt[@]}" -gt 0 ]; then
  for f in "${corrupt[@]}"; do err "corrupt or unreadable: $f"; done
  err "nothing was touched. Move the corrupt file(s) out of the backup and re-run"
  err "with --allow-incomplete to restore the rest."
  exit 1
fi
if [ "$(( ${#PLAN_PG[@]} + ${#PLAN_VOL[@]} ))" -eq 0 ]; then
  err "nothing to restore in $SRC (no *_pg.sql.gz or *_vol.tar.gz)"
  exit 1
fi

info "will restore from: $SRC"
for entry in "${PLAN_PG[@]+"${PLAN_PG[@]}"}"; do info "  database ${entry%%:*}"; done
for vol in "${PLAN_VOL[@]+"${PLAN_VOL[@]}"}"; do info "  volume   $vol"; done
warn "This will OVERWRITE current data from: $SRC"
printf "Type 'yes' to continue: "; read -r ans
[ "$ans" = "yes" ] || { info "aborted"; exit 0; }

STAMP="$(date -u +%Y%m%d%H%M%S)"
FAILED=()

# Snapshot running containers once. Piping `docker ps` straight into `grep -q`
# under pipefail can report "not running" when grep exits early (SIGPIPE).
RUNNING="$(docker ps --format '{{.Names}}')"
is_running() { grep -qx -- "$1" <<< "$RUNNING"; }

# --- 3. Postgres --------------------------------------------------------------
# A plain pg_dump (no --clean) applied to a live database does NOT restore it:
# CREATE TABLE fails with "already exists", COPY collides with existing rows,
# and psql still exits 0. So: load into an empty temporary database, stop on the
# first error, and only then swap it in.
pg() {
  local c="$1" u="$2"; shift 2
  docker exec "$c" psql -U "$u" -d postgres -X -q -v ON_ERROR_STOP=1 \
    -c "SET client_min_messages = warning" "$@"
}

restore_pg() {
  local container="$1" user="$2" db="$3" dump="$4"
  local tmp="${db}__restoring" old="${db}__pre_restore_${STAMP}"

  # Names are spliced into SQL (as quoted identifiers and literals): be strict.
  if ! [[ "$user" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ && "$db" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] \
     || [ "${#old}" -gt 63 ]; then
    err "$container: unsupported user/database name ('$user' / '$db')"; return 1
  fi

  pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" \
                          -c "CREATE DATABASE \"$tmp\" OWNER \"$user\"" >/dev/null \
    || { err "$container: could not create temporary database $tmp"; return 1; }

  if ! gunzip -c "$dump" | docker exec -i "$container" \
         psql -U "$user" -d "$tmp" -X -q -v ON_ERROR_STOP=1 --single-transaction >/dev/null; then
    err "$container: the dump did not load cleanly; live database '$db' left untouched"
    pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 || true
    return 1
  fi

  # Swap. New connections are refused first (committed on its own so it takes
  # effect), then the existing ones are closed and both renames happen in ONE
  # transaction: either the restored database is live, or nothing changed.
  pg "$container" "$user" -c "ALTER DATABASE \"$db\" WITH ALLOW_CONNECTIONS false" >/dev/null \
    || { err "$container: could not lock database '$db' for the swap"
         pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 || true
         return 1; }
  if ! pg "$container" "$user" -1 \
         -c "SELECT pg_terminate_backend(pid, 10000) FROM pg_stat_activity WHERE datname = '$db' AND pid <> pg_backend_pid()" \
         -c "ALTER DATABASE \"$db\" RENAME TO \"$old\"" \
         -c "ALTER DATABASE \"$tmp\" RENAME TO \"$db\"" >/dev/null; then
    err "$container: could not swap in the restored database; live database '$db' left untouched"
    pg "$container" "$user" -c "ALTER DATABASE \"$db\" WITH ALLOW_CONNECTIONS true" >/dev/null 2>&1 || true
    pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 || true
    return 1
  fi
  pg "$container" "$user" -c "ALTER DATABASE \"$old\" WITH ALLOW_CONNECTIONS true" >/dev/null 2>&1 || true
  ok "restored $container ($db); previous data kept as database '$old'"
  PREVIOUS_DBS+=("$container|$user|$old")
}

PREVIOUS_DBS=()
for entry in "${PLAN_PG[@]+"${PLAN_PG[@]}"}"; do
  IFS=: read -r container uvar dvar <<< "$entry"
  user="${!uvar:-}"; db="${!dvar:-}"
  if ! is_running "$container"; then
    err "$container not running: its dump was NOT restored"
    FAILED+=("database $container (not running)"); continue
  fi
  info "restoring $container ($db)..."
  restore_pg "$container" "$user" "$db" "${SRC}/${container}_pg.sql.gz" || FAILED+=("database $container")
done

# --- 4. Volumes ---------------------------------------------------------------
# Extract into a staging dir on the same volume; only after tar succeeds is the
# old content removed and the staged files moved (renamed) into place.
# Exit 3 = tar failed, old data untouched. Anything else non-zero = unknown.
STAGE=.donalabs-restore
volume_script() {   # $1 = tarball name inside /backup (fixed names from lib.sh)
  cat <<EOS
cd /dst || exit 5
rm -rf $STAGE && mkdir $STAGE || exit 3
tar xzf /backup/$1 -C $STAGE || { rm -rf $STAGE; exit 3; }
find . -mindepth 1 -maxdepth 1 ! -name $STAGE -exec rm -rf {} \\; || exit 4
cd $STAGE && find . -mindepth 1 -maxdepth 1 -exec mv {} .. \\; || exit 4
cd .. && rmdir $STAGE || exit 4
EOS
}
stopped=()
restart_stopped() {
  for c in "${stopped[@]+"${stopped[@]}"}"; do docker start "$c" >/dev/null 2>&1 || warn "could not restart $c"; done
}

for vol in "${PLAN_VOL[@]+"${PLAN_VOL[@]}"}"; do
  tarname="${vol}_vol.tar.gz"
  info "restoring volume $vol..."
  # Only containers that are RUNNING: a stopped one is not writing, and must
  # not be started at the end just because it mounts the volume.
  users="$(docker ps --filter "volume=$vol" --format '{{.Names}}')"
  stopped=() stop_failed=""
  for c in $users; do
    if docker stop "$c" >/dev/null 2>&1; then stopped+=("$c"); else stop_failed="$c"; break; fi
  done

  if [ -n "$stop_failed" ]; then
    err "could not stop $stop_failed: volume $vol NOT restored (it is still in use)"
    restart_stopped; FAILED+=("volume $vol"); continue
  fi

  rc=0
  docker run --rm -v "${vol}:/dst" -v "${SRC}:/backup:ro" alpine:3.21 \
    sh -c "$(volume_script "$tarname")" || rc=$?
  case "$rc" in
    0) ok "restored volume $vol"; restart_stopped ;;
    3) err "extracting $tarname failed; volume $vol left as it was"; restart_stopped; FAILED+=("volume $vol") ;;
    *) err "restore of volume $vol failed midway (exit $rc): its contents may be partial"
       [ "${#stopped[@]}" -eq 0 ] || err "left STOPPED on purpose so they do not run on partial data: ${stopped[*]}"
       FAILED+=("volume $vol (partial, containers left stopped)") ;;
  esac
done

# --- 5. Verdict -----------------------------------------------------------------
echo
if [ "${#FAILED[@]}" -gt 0 ]; then
  for f in "${FAILED[@]}"; do err "NOT restored: $f"; done
  err "restore INCOMPLETE (see above). Everything not listed was restored."
  exit 1
fi
for p in "${PREVIOUS_DBS[@]+"${PREVIOUS_DBS[@]}"}"; do
  IFS='|' read -r c u old <<< "$p"
  info "once verified, free the old copy: docker exec $c psql -U $u -d postgres -c 'DROP DATABASE \"$old\"'"
done
ok "restore complete. Verify with: ./scripts/health.sh"
