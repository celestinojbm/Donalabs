#!/usr/bin/env bash
# =============================================================================
# DonaLabs — restore from a backup directory produced by ./backup.sh
#
#   ./scripts/restore.sh backups/<timestamp>
#   ./scripts/restore.sh backups/<timestamp> --allow-incomplete
#
#   --allow-incomplete     restore what a backup contains even though its
#                          MANIFEST.txt is not "STATUS: COMPLETE" (an incomplete
#                          backup, an interrupted one, or one from before the
#                          marker existed) or lists a file that is missing.
#   --ignore-key-mismatch  restore even though an encryption key in .env differs
#                          from the one in the backup's env.backup (the data it
#                          protects will NOT be readable with the current key).
#
#   RESTORE_KEEP_PREVIOUS  (env or .env, default 2, integer >= 1) how many old
#                          copies <db>__pre_restore_<timestamp> to keep per
#                          database; older ones are dropped after a restore.
#
# Restores Postgres logical dumps and named-volume tarballs. The databases must
# be running. Every file is integrity-checked BEFORE anything is touched, and the
# encryption keys in .env are compared with the backup's env.backup: restored
# n8n / Cal.com / Plausible / Open WebUI data is only readable with the key it
# was written with, so a mismatch is refused (nothing touched) until .env holds
# the backup's keys.
#
#   Postgres: each dump is loaded into a temporary database with ON_ERROR_STOP
#     in a single transaction, given the live database's own grants, settings,
#     owner, connection limit and comment (a dump without --create does not
#     carry them), then swapped in by renaming. The live database is only
#     replaced if all of that worked; the previous one is kept as
#     <db>__pre_restore_<timestamp> so the restore can be undone, and only the
#     RESTORE_KEEP_PREVIOUS newest such copies are kept.
#   Interrupted (Ctrl-C, SSH drop, kill, unexpected error): an exit trap reopens
#     any database the restore had locked and drops its temporary database.
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

usage() { sed -n '4,18p' "$0" | sed 's/^# \{0,1\}//'; }
USAGE="usage: ./scripts/restore.sh backups/<timestamp> [--allow-incomplete] [--ignore-key-mismatch]"

SRC="" ALLOW_INCOMPLETE=0 IGNORE_KEYS=0
for arg in "$@"; do
  case "$arg" in
    --allow-incomplete) ALLOW_INCOMPLETE=1 ;;
    --ignore-key-mismatch) IGNORE_KEYS=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) err "unknown option: $arg"; err "$USAGE"; exit 1 ;;
    *) [ -z "$SRC" ] || { err "only one backup directory, got '$SRC' and '$arg'"; exit 1; }
       SRC="$arg" ;;
  esac
done

require_docker
load_env

# Validate retention BEFORE touching anything (as backup.sh does).
KEEP_PREVIOUS="${RESTORE_KEEP_PREVIOUS:-2}"
if ! [[ "$KEEP_PREVIOUS" =~ ^[0-9]+$ ]] || [ "$KEEP_PREVIOUS" -lt 1 ]; then
  err "RESTORE_KEEP_PREVIOUS must be an integer >= 1 (got '${KEEP_PREVIOUS}')"
  exit 1
fi

if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  err "$USAGE"; exit 1
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
  # "env  .env -> env.backup (SENSITIVE)": the keys needed to read the data.
  if grep -q '^env .*-> env\.backup' "$MANIFEST" && [ ! -f "${SRC}/env.backup" ]; then
    problems+=("MANIFEST lists env.backup but it is missing (the encryption keys of this backup)")
  fi
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

# --- 3. Can the restored data be read with the keys in .env? (read-only) -------
# Apps encrypt part of what they store with a key from .env. Data restored from
# this backup was written with the key in its env.backup; with any other key it
# is unreadable (n8n does not even start). Only keys of what is being restored
# count. Values are compared, never printed.
#   "KEY|containers/volumes whose data depends on it|what breaks"
DATA_KEYS=(
  "N8N_ENCRYPTION_KEY|donalabs-n8n-db donalabs_n8n_data|n8n refuses to start and its stored credentials are unreadable"
  "CALCOM_ENCRYPTION_KEY|donalabs-calcom-db|Cal.com cannot decrypt stored calendar/OAuth credentials"
  "PLAUSIBLE_TOTP_VAULT_KEY|donalabs-plausible-db|Plausible cannot read 2FA secrets (users with 2FA cannot log in)"
  "OPENWEBUI_SECRET_KEY|donalabs_open_webui_data|Open WebUI logs everyone out and cannot read the data it encrypted"
)
# Keys that only sign sessions/tokens: a change logs people out, no data is lost.
SESSION_KEYS=(
  "CALCOM_NEXTAUTH_SECRET|donalabs-calcom-db"
  "PLAUSIBLE_SECRET_KEY_BASE|donalabs-plausible-db"
  "PENPOT_SECRET_KEY|donalabs-penpot-db donalabs_penpot_assets"
)
PLANNED=" "
for entry in "${PLAN_PG[@]+"${PLAN_PG[@]}"}"; do PLANNED+="${entry%%:*} "; done
for vol in "${PLAN_VOL[@]+"${PLAN_VOL[@]}"}"; do PLANNED+="$vol "; done
key_is_relevant() { local t; for t in $1; do [[ "$PLANNED" == *" $t "* ]] && return 0; done; return 1; }
# key_state KEY -> same | differs | unknown (env.backup does not set it)
key_state() {
  local b c
  if ! b="$(env_get "$ENV_BACKUP" "$1")"; then
    env_get "$ENV_FILE" "$1" >/dev/null && echo unknown || echo same; return
  fi
  if c="$(env_get "$ENV_FILE" "$1")" && [ "$c" = "$b" ]; then echo same; else echo differs; fi
}

ENV_BACKUP="${SRC}/env.backup"
mismatched=()
if [ ! -e "$ENV_BACKUP" ]; then
  warn "no env.backup in this backup: cannot check that the encryption keys in .env match the data"
elif [ ! -r "$ENV_BACKUP" ]; then
  mismatched+=("env.backup is not readable by $(id -un): the encryption keys cannot be checked")
else
  for k in "${DATA_KEYS[@]}"; do
    IFS='|' read -r key targets why <<< "$k"
    key_is_relevant "$targets" || continue
    case "$(key_state "$key")" in
      differs) mismatched+=("$key differs from env.backup: $why") ;;
      unknown) warn "env.backup has no $key (older backup?): cannot check it matches the restored data" ;;
    esac
  done
  for k in "${SESSION_KEYS[@]}"; do
    IFS='|' read -r key targets <<< "$k"
    key_is_relevant "$targets" || continue
    [ "$(key_state "$key")" != differs ] \
      || warn "$key differs from env.backup: sessions signed with the old key end (users log in again)"
  done
fi
if [ "${#mismatched[@]}" -gt 0 ]; then
  for m in "${mismatched[@]}"; do err "$m"; done
  if [ "$IGNORE_KEYS" -eq 0 ]; then
    err "refusing to restore data the current .env cannot read. Nothing was touched. To fix:"
    err "  1. copy the KEY=... line of each key above from ${ENV_BACKUP} into .env"
    err "  2. re-run this restore"
    err "  3. run ./start.sh so the containers pick up the key (a restart keeps the old one)"
    err "to restore with the current keys anyway, re-run with --ignore-key-mismatch"
    exit 1
  fi
  warn "--ignore-key-mismatch: restoring anyway; the data above will NOT be readable with the current .env"
fi

info "will restore from: $SRC"
for entry in "${PLAN_PG[@]+"${PLAN_PG[@]}"}"; do info "  database ${entry%%:*}"; done
for vol in "${PLAN_VOL[@]+"${PLAN_VOL[@]}"}"; do info "  volume   $vol"; done
warn "This will OVERWRITE current data from: $SRC"
printf "Type 'yes' to continue: "; read -r ans
[ "$ans" = "yes" ] || { info "aborted"; exit 0; }

STAMP="$(date -u +%Y%m%d%H%M%S)"
FAILED=()

# --- cleanup on interruption ----------------------------------------------------
# What is in flight, for the exit trap. Set right BEFORE the step that needs
# undoing, cleared right after it is settled.
#   PG_INFLIGHT  "container|user|db|tmp|old": the dump is loading into tmp, or
#                db is locked (ALLOW_CONNECTIONS false) for the swap
#   VOL_INFLIGHT volume whose containers are stopped and whose contents are
#                being replaced (state unknown if we stop here)
PG_INFLIGHT="" VOL_INFLIGHT=""
on_exit() {
  local rc=$?
  set +e                        # after an SSH drop even printing fails: keep cleaning
  trap '' INT TERM HUP          # a second Ctrl-C must not cut the cleanup short
  trap - EXIT
  if [ -n "$PG_INFLIGHT" ]; then
    local c u db tmp old
    IFS='|' read -r c u db tmp old <<< "$PG_INFLIGHT"
    err "interrupted while restoring $c ($db): undoing the in-flight step"
    # Whichever side of the swap we stopped on, nothing may stay locked: the
    # database called $db (old or restored) and the kept copy $old.
    reopen_or_tell "$c" "$u" "$db" "$old" && ok "$c: '$db' accepts connections"
    pg "$c" "$u" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 \
      || warn "$c: could not drop temporary database '$tmp' (the next restore drops it)"
  fi
  if [ -n "$VOL_INFLIGHT" ]; then
    err "interrupted while restoring volume $VOL_INFLIGHT: its contents may be partial"
    [ "${#stopped[@]}" -eq 0 ] \
      || err "left STOPPED on purpose (check the volume, then: docker start ${stopped[*]})"
  fi
  if [ "$rc" -ne 0 ] && { [ -n "$PG_INFLIGHT" ] || [ -n "$VOL_INFLIGHT" ]; }; then
    err "restore interrupted (exit $rc): NOT complete. Everything finished before this point stays restored."
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# Reopen databases $3... of container $1 (user $2); if that fails, say exactly
# how to do it by hand. Never leaves a lock unreported.
reopen_or_tell() {
  local c="$1" u="$2" n; shift 2
  pg "$c" "$u" -c "$(reopen_sql "$@")" >/dev/null 2>&1 && return 0
  err "$c: could not make these databases accept connections again: $*. Run:"
  for n in "$@"; do
    err "  docker exec $c psql -U $u -d postgres -c 'ALTER DATABASE \"$n\" WITH ALLOW_CONNECTIONS true'"
  done
  return 1
}

# SQL that reopens the given databases if they exist and are locked (no error
# if they do not exist: the trap does not know which side of the swap it is on).
reopen_sql() {
  local list="" n
  for n in "$@"; do list+="${list:+, }'$n'"; done
  cat <<SQL
DO \$\$
DECLARE n name;
BEGIN
  FOR n IN SELECT datname FROM pg_database WHERE datname IN ($list) AND NOT datallowconn LOOP
    EXECUTE format('ALTER DATABASE %I WITH ALLOW_CONNECTIONS true', n);
  END LOOP;
END \$\$
SQL
}

# Snapshot running containers once. Piping `docker ps` straight into `grep -q`
# under pipefail can report "not running" when grep exits early (SIGPIPE).
RUNNING="$(docker ps --format '{{.Names}}')"
is_running() { grep -qx -- "$1" <<< "$RUNNING"; }

# --- 4. Postgres --------------------------------------------------------------
# A plain pg_dump (no --clean) applied to a live database does NOT restore it:
# CREATE TABLE fails with "already exists", COPY collides with existing rows,
# and psql still exits 0. So: load into an empty temporary database, stop on the
# first error, and only then swap it in.
pg() {
  local c="$1" u="$2"; shift 2
  docker exec "$c" psql -U "$u" -d postgres -X -q -v ON_ERROR_STOP=1 \
    -c "SET client_min_messages = warning" "$@"
}

# Give database $2 the database-level properties of $1: owner, connection
# limit, comment, GRANTs ON DATABASE, ALTER DATABASE ... SET and ALTER ROLE ...
# IN DATABASE ... SET. A plain pg_dump (no --create) carries none of them, and
# the swap replaces the database they belong to. One DO block: all or nothing.
copy_db_props_sql() {
  cat <<SQL
DO \$\$
DECLARE
  d pg_database%ROWTYPE;
  dst CONSTANT text := '$2';
  r record;
  k text;
  v text;
  -- GUCs stored as a list of already-quoted identifiers ("\$user", public):
  -- they are re-applied verbatim, not as one string (pg_dump's list).
  listq CONSTANT text[] := ARRAY['local_preload_libraries', 'search_path',
    'session_preload_libraries', 'shared_preload_libraries', 'temp_tablespaces',
    'unix_socket_directories'];
BEGIN
  SELECT * INTO STRICT d FROM pg_database WHERE datname = '$1';
  EXECUTE format('ALTER DATABASE %I OWNER TO %I', dst, pg_get_userbyid(d.datdba));
  EXECUTE format('ALTER DATABASE %I CONNECTION LIMIT %s', dst, d.datconnlimit);
  EXECUTE format('COMMENT ON DATABASE %I IS %L', dst, shobj_description(d.oid, 'pg_database'));
  IF d.datacl IS NOT NULL THEN     -- NULL = defaults, which dst already has
    EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', dst);
    EXECUTE format('REVOKE ALL ON DATABASE %I FROM %I', dst, pg_get_userbyid(d.datdba));
    FOR r IN SELECT * FROM aclexplode(d.datacl) LOOP
      EXECUTE format('GRANT %s ON DATABASE %I TO %s%s', r.privilege_type, dst,
        CASE WHEN r.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(r.grantee)) END,
        CASE WHEN r.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
    END LOOP;
  END IF;
  FOR r IN SELECT s.setrole, unnest(s.setconfig) AS kv
             FROM pg_db_role_setting s WHERE s.setdatabase = d.oid LOOP
    k := split_part(r.kv, '=', 1);
    v := substr(r.kv, length(k) + 2);
    v := CASE WHEN k <> ALL (listq) THEN quote_literal(v)
              WHEN v = '""' THEN quote_literal('') ELSE v END;  -- SET search_path = ''
    IF r.setrole = 0 THEN
      EXECUTE format('ALTER DATABASE %I SET %I TO %s', dst, k, v);
    ELSE
      EXECUTE format('ALTER ROLE %I IN DATABASE %I SET %I TO %s',
                     pg_get_userbyid(r.setrole), dst, k, v);
    END IF;
  END LOOP;
END \$\$
SQL
}

# Drop the oldest <db>__pre_restore_<14 digits> copies beyond KEEP_PREVIOUS. The
# copy this run just made ($2) always counts as kept, whatever the clock says.
# Only exact names are matched, and a copy someone is connected to is not forced.
prune_old_copies() {
  local container="$1" user="$2" db="$3" just_made="$4" prefix="${3}__pre_restore_" n
  local names
  names="$(pg "$container" "$user" -At -c "SELECT datname FROM pg_database
      WHERE left(datname, length('$prefix')) = '$prefix'
        AND substr(datname, length('$prefix') + 1) ~ '^[0-9]{14}\$'
      ORDER BY datname = '$just_made' DESC, datname DESC OFFSET $KEEP_PREVIOUS")" \
    || { warn "$container: could not list old copies of '$db' to prune"; return 0; }
  for n in $names; do
    if pg "$container" "$user" -c "DROP DATABASE \"$n\"" >/dev/null 2>&1; then
      info "dropped old copy $n (RESTORE_KEEP_PREVIOUS=$KEEP_PREVIOUS)"
    else
      warn "could not drop old copy $n (in use?); drop it by hand once free"
    fi
  done
}

restore_pg() {
  local container="$1" user="$2" db="$3" dump="$4"
  local tmp="${db}__restoring" old="${db}__pre_restore_${STAMP}"

  # Names are spliced into SQL (as quoted identifiers and literals): be strict.
  if ! [[ "$user" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ && "$db" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] \
     || [ "${#old}" -gt 63 ]; then
    err "$container: unsupported user/database name ('$user' / '$db')"; return 1
  fi

  PG_INFLIGHT="$container|$user|$db|$tmp|$old"
  pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" \
                          -c "CREATE DATABASE \"$tmp\" OWNER \"$user\"" >/dev/null \
    || { err "$container: could not create temporary database $tmp"; PG_INFLIGHT=""; return 1; }

  if ! gunzip -c "$dump" | docker exec -i "$container" \
         psql -U "$user" -d "$tmp" -X -q -v ON_ERROR_STOP=1 --single-transaction >/dev/null; then
    err "$container: the dump did not load cleanly; live database '$db' left untouched"
    pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 || true
    PG_INFLIGHT=""; return 1
  fi

  if ! pg "$container" "$user" -c "$(copy_db_props_sql "$db" "$tmp")" >/dev/null; then
    err "$container: could not give the restored database the grants/settings of '$db'; live database left untouched"
    pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 || true
    PG_INFLIGHT=""; return 1
  fi

  # Swap. New connections are refused first (committed on its own so it takes
  # effect), then the existing ones are closed and both renames happen in ONE
  # transaction: either the restored database is live, or nothing changed.
  pg "$container" "$user" -c "ALTER DATABASE \"$db\" WITH ALLOW_CONNECTIONS false" >/dev/null \
    || { err "$container: could not lock database '$db' for the swap"
         reopen_or_tell "$container" "$user" "$db" || true
         pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 || true
         PG_INFLIGHT=""; return 1; }
  if ! pg "$container" "$user" -1 \
         -c "SELECT pg_terminate_backend(pid, 10000) FROM pg_stat_activity WHERE datname = '$db' AND pid <> pg_backend_pid()" \
         -c "ALTER DATABASE \"$db\" RENAME TO \"$old\"" \
         -c "ALTER DATABASE \"$tmp\" RENAME TO \"$db\"" >/dev/null; then
    err "$container: could not swap in the restored database; live database '$db' left untouched"
    # A failed swap may still have committed (e.g. the connection dropped after
    # COMMIT): reopen whichever of the two names exists.
    reopen_or_tell "$container" "$user" "$db" "$old" || true
    pg "$container" "$user" -c "DROP DATABASE IF EXISTS \"$tmp\"" >/dev/null 2>&1 || true
    PG_INFLIGHT=""; return 1
  fi
  # The restored database is live. If only the undo copy stays locked, say how
  # to open it; the restore itself succeeded.
  reopen_or_tell "$container" "$user" "$old" || warn "$container: (the old copy is only needed to undo)"
  PG_INFLIGHT=""
  ok "restored $container ($db); previous data kept as database '$old'"
  PREVIOUS_DBS+=("$container|$user|$old")
  prune_old_copies "$container" "$user" "$db" "$old"
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

# --- 5. Volumes ---------------------------------------------------------------
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
  VOL_INFLIGHT="$vol"
  for c in $users; do
    if docker stop "$c" >/dev/null 2>&1; then stopped+=("$c"); else stop_failed="$c"; break; fi
  done

  if [ -n "$stop_failed" ]; then
    err "could not stop $stop_failed: volume $vol NOT restored (it is still in use)"
    restart_stopped; VOL_INFLIGHT=""; FAILED+=("volume $vol"); continue
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
  VOL_INFLIGHT=""
done

# --- 6. Verdict -----------------------------------------------------------------
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
[ "${#PREVIOUS_DBS[@]}" -eq 0 ] \
  || info "(older copies beyond RESTORE_KEEP_PREVIOUS=$KEEP_PREVIOUS per database are dropped automatically)"
ok "restore complete. Verify with: ./scripts/health.sh"
