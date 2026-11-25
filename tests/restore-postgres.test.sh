#!/usr/bin/env bash
# restore.sh against a REAL PostgreSQL: backup.sh runs the real pg_dump and
# restore.sh the real psql (tests/fakes/docker forwards `docker exec C psql|
# pg_dump` to a throwaway local cluster via FAKE_PG_SOCKET). This is the only
# way to check that a restore really puts the old rows back: a plain pg_dump
# applied on top of a live database does not, and psql still exits 0.
#
# Needs the PostgreSQL server binaries (initdb, pg_ctl), preinstalled on the
# GitHub ubuntu runners. Locally they are optional: without them the test is
# skipped, but in CI (CI=true) a missing server is a failure, never a skip.
#
#   bash tests/restore-postgres.test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

echo "restore.sh (real PostgreSQL)"

PG_BIN=""
for d in "$(pg_config --bindir 2>/dev/null || true)" \
         $(find /usr/lib/postgresql -mindepth 2 -maxdepth 2 -name bin -type d 2>/dev/null | sort -rV); do
  [ -n "$d" ] && [ -x "$d/initdb" ] && [ -x "$d/pg_ctl" ] && { PG_BIN="$d"; break; }
done
if [ -z "$PG_BIN" ]; then
  if [ "${CI:-}" = "true" ]; then
    echo "  FAIL  PostgreSQL server binaries (initdb, pg_ctl) not found; this test must run in CI"
    exit 1
  fi
  echo "  skip  PostgreSQL server binaries not found (install postgresql to run this test)"
  exit 0
fi
export PATH="$PG_BIN:$PATH"   # psql / pg_dump of the same version as the server

PASS=0 FAIL=0
pass() { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name" "command: $*"; fi; }
# eq <name> <expected> <actual>
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi; }

# --- throwaway cluster ----------------------------------------------------------
PGROOT="$(mktemp -d)"
SB="$(mktemp -d)"
# initdb refuses to run as root: run the server as `postgres` when we are root.
as_pg() { if [ "$(id -u)" -eq 0 ]; then runuser -u postgres -- "$@"; else "$@"; fi; }
[ "$(id -u)" -ne 0 ] || chown postgres "$PGROOT"
cleanup() {
  as_pg pg_ctl -D "$PGROOT/data" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$PGROOT" "$SB"
}
trap cleanup EXIT
as_pg initdb -D "$PGROOT/data" -U postgres -A trust --no-sync >/dev/null
as_pg pg_ctl -D "$PGROOT/data" -l "$PGROOT/log" -w \
  -o "-k $PGROOT -c listen_addresses= -c fsync=off" start >/dev/null
export FAKE_PG_SOCKET="$PGROOT"

q() { local u="$1" d="$2"; shift 2; psql -h "$PGROOT" -U "$u" -d "$d" -X -q -At -v ON_ERROR_STOP=1 "$@"; }

# container:user:db, as in .env below (one cluster stands in for all four).
DBS="donalabs-calcom-db:calcom:calendso donalabs-plausible-db:plausible:plausible_db donalabs-penpot-db:penpot:penpot donalabs-n8n-db:n8n:n8n"
for e in $DBS; do
  IFS=: read -r _ u d <<< "$e"
  q postgres postgres -c "CREATE ROLE $u SUPERUSER LOGIN" -c "CREATE DATABASE $d OWNER $u"
  q "$u" "$d" <<'SQL'
CREATE EXTENSION IF NOT EXISTS citext;            -- Plausible uses citext
CREATE TABLE users (id serial PRIMARY KEY, email citext UNIQUE NOT NULL);
CREATE TABLE items (id serial PRIMARY KEY, owner int REFERENCES users(id), v text);
CREATE TABLE extra (k text PRIMARY KEY);
INSERT INTO users (email) VALUES ('a@x.io'), ('b@x.io');
INSERT INTO items (owner, v) VALUES (1, 'orig1'), (2, 'orig2'), (1, 'orig3');
INSERT INTO extra VALUES ('keep');
SQL
done
# Rows of items and users, plus the list of tables (works whatever was dropped).
snapshot() {
  q "$1" "$2" -c "SELECT concat_ws(' | ',
    (SELECT string_agg(id || ':' || owner || ':' || v, ',' ORDER BY id) FROM items),
    (SELECT string_agg(email::text, ',' ORDER BY id) FROM users),
    (SELECT string_agg(tablename, ',' ORDER BY tablename) FROM pg_tables WHERE schemaname = 'public'))"
}
ORIG="$(snapshot calcom calendso)"

# Damage every database: changed and new rows, a dropped and a new table.
damage() {
  local e u d
  for e in $DBS; do
    IFS=: read -r _ u d <<< "$e"
    q "$u" "$d" -c "SET client_min_messages = warning" -c "UPDATE items SET v = 'changed'" -c "INSERT INTO items (owner, v) VALUES (2, 'new')" \
      -c "DROP TABLE IF EXISTS extra" -c "CREATE TABLE IF NOT EXISTS junk (x int)"
  done
}
db_exists() { [ "$(q postgres postgres -c "SELECT count(*) FROM pg_database WHERE datname = '$1'")" = 1 ]; }
not_exists_tmp() { ! db_exists "$1__restoring"; }
not_complete() { ! grep -q 'restore complete' <<< "$OUT"; }
# How many kept copies <db>__pre_restore_* exist that accept connections.
old_copies() { q postgres postgres -c "SELECT count(*) FROM pg_database WHERE datname LIKE '$1\_\_pre\_restore\_%' AND datallowconn"; }
drop_old_copies() {
  local n
  for n in $(q postgres postgres -c "SELECT datname FROM pg_database WHERE datname LIKE '%__pre_restore_%'"); do
    q postgres postgres -c "DROP DATABASE \"$n\""
  done
}

# --- sandbox: backup.sh + restore.sh with the fake docker -----------------------
mkdir -p "$SB/scripts" "$SB/backups" "$SB/bin"
cp "$REPO/backup.sh" "$SB/"
cp "$REPO/scripts/lib.sh" "$REPO/scripts/restore.sh" "$SB/scripts/"
cp "$HERE/fakes/docker" "$SB/bin/docker"
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
export FAKE_RUNNING="donalabs-calcom-db donalabs-plausible-db donalabs-penpot-db donalabs-n8n-db"
export FAKE_VOLUMES="" FAKE_LOG="$SB/docker.log"
unset FAKE_VOLROOT FAKE_PSQL_DIR FAKE_PSQL_FAIL FAKE_TAR_FAIL FAKE_PGDUMP_FAIL BACKUP_RETENTION

set +e
OUT="$(PATH="$SB/bin:$PATH" "$SB/backup.sh" --allow-partial 2>&1)"; RC=$?
set -e
BK="$(find "$SB/backups" -mindepth 1 -maxdepth 1 -type d | head -1)"
check "backup with real pg_dump succeeds" [ "$RC" -eq 0 ]
check "dump is real SQL" bash -c "gunzip -c '$BK/donalabs-calcom-db_pg.sql.gz' | grep -q 'CREATE TABLE public.items'"

# Old copies are named <db>__pre_restore_<second>: two restores that start in
# the same second would collide (the second one then fails safely). Never let
# the test do that.
LAST_START=""
run_restore() {
  # restore.sh names its copies <db>__pre_restore_<second>, taken AFTER its
  # pre-prompt checks. Start in a second later than the one the previous run
  # ENDED in: its stamp is <= that, so two runs never share one (waiting from
  # the previous start was not enough under load).
  while [ "$(date -u +%s)" = "$LAST_START" ]; do sleep 0.1; done
  set +e
  OUT="$(PATH="$SB/bin:$PATH" "$SB/scripts/restore.sh" "$@" 2>&1 <<< yes)"; RC=$?
  set -e
  LAST_START="$(date -u +%s)"
}

# --- 1. backup -> damage -> restore gives back exactly the backed-up rows ---------
damage
check "setup: damage changed the data" [ "$(snapshot calcom calendso)" != "$ORIG" ]
# An app holding a connection to the live database (it must not block the swap).
psql -h "$PGROOT" -U calcom -d calendso -X -q -c "SELECT pg_sleep(60)" >/dev/null 2>&1 &
APP=$!
for _ in $(seq 50); do
  [ "$(q postgres postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'calendso' AND query LIKE '%pg_sleep%'")" = 1 ] && break
  sleep 0.1
done
run_restore "$BK"
wait "$APP" 2>/dev/null || true
check "restore exits 0" [ "$RC" -eq 0 ]
[ "$RC" -eq 0 ] || printf '%s\n' "$OUT" | sed 's/^/        | /'
for e in $DBS; do
  IFS=: read -r _ u d <<< "$e"
  eq "$d: rows, emails and tables are exactly the backup's" "$ORIG" "$(snapshot "$u" "$d" 2>&1)"
  eq "$d: table dropped after the backup is back, with its rows" "keep" "$(q "$u" "$d" -c "SELECT string_agg(k, ',') FROM extra" 2>&1)"
  eq "$d: sequences restored (next id is 4)" "4" "$(q "$u" "$d" -c "SELECT nextval('items_id_seq')")"
  eq "$d: previous data kept as ${d}__pre_restore_*" "1" "$(old_copies "$d")"
  check "$d: no temporary database left" not_exists_tmp "$d"
done
eq "calendso: live database accepts connections" "t" "$(q postgres postgres -c "SELECT datallowconn FROM pg_database WHERE datname = 'calendso'")"
old="$(q postgres postgres -c "SELECT datname FROM pg_database WHERE datname LIKE 'calendso__pre_restore_%'")"
eq "the kept copy holds the pre-restore (damaged) data" "1" "$(q calcom "$old" -c "SELECT count(*) FROM items WHERE v = 'new'")"

# --- 2. a dump that fails midway leaves the live database untouched ------------
drop_old_copies
damage
BEFORE="$(snapshot n8n n8n)"
gunzip -c "$BK/donalabs-n8n-db_pg.sql.gz" \
  | sed '0,/^CREATE TABLE public.items/s//SELECT 1\/0;\n&/' | gzip > "$SB/bad.sql.gz"
mv "$SB/bad.sql.gz" "$BK/donalabs-n8n-db_pg.sql.gz"
run_restore "$BK"
check "SQL error in a dump: restore exits 1" [ "$RC" -eq 1 ]
check "SQL error in a dump: reported as NOT restored" grep -q 'NOT restored: database donalabs-n8n-db' <<< "$OUT"
eq "SQL error in a dump: live n8n database untouched" "$BEFORE" "$(snapshot n8n n8n)"
check "SQL error in a dump: no temporary database left" not_exists_tmp n8n
eq "SQL error in a dump: no old copy made for n8n" "0" "$(old_copies n8n)"
eq "SQL error in n8n: the other databases are still restored" "$ORIG" "$(snapshot calcom calendso)"

# Put the good dump back for the next sections (section 2 broke n8n's).


set +e
OUT="$(PATH="$SB/bin:$PATH" "$SB/backup.sh" --allow-partial 2>&1)"; RC=$?
set -e
check "setup: fresh backup for the next sections" [ "$RC" -eq 0 ]
BK="$(find "$SB/backups" -mindepth 1 -maxdepth 1 -type d ! -path "$BK" | sort | tail -1)"
allows_conn() { q postgres postgres -c "SELECT datallowconn FROM pg_database WHERE datname = '$1'"; }
locked_dbs() { q postgres postgres -c "SELECT coalesce(string_agg(datname, ',' ORDER BY datname), '') FROM pg_database WHERE NOT datallowconn AND datname <> 'template0'"; }

# --- 3. an interrupted restore never leaves a database refusing connections -----
# FAKE_KILL_ON sends SIGTERM to restore.sh right after the matching docker call,
# like a Ctrl-C / SSH drop / kill at that exact point.
interrupt_at() {   # <ERE of the docker call> -> runs restore.sh, killed there
  rm -f "$FAKE_LOG.killed"
  FAKE_KILL_ON="$1" run_restore "$BK"
  rm -f "$FAKE_LOG.killed"
}

# 3a. Killed right after the live database was locked, before the swap.
drop_old_copies; damage
BEFORE="$(snapshot calcom calendso)"
interrupt_at 'donalabs-calcom-db .*"calendso" WITH ALLOW_CONNECTIONS false'
check "killed after the lock: exits non-zero" [ "$RC" -ne 0 ]
check "killed after the lock: says it was interrupted" grep -q 'interrupted' <<< "$OUT"
check "killed after the lock: does not say restore complete" not_complete
eq "killed after the lock: no database left refusing connections" "" "$(locked_dbs)"
eq "killed after the lock: live calendso untouched" "$BEFORE" "$(snapshot calcom calendso)"
check "killed after the lock: no temporary database left" not_exists_tmp calendso
eq "killed after the lock: no old copy made" "0" "$(old_copies calendso)"
check "killed after the lock: says the swap did not happen" grep -q "'calendso' still holds its previous data" <<< "$OUT"
check "killed after the lock: 'accepts connections' only after checking" grep -q "'calendso' accepts connections (checked)" <<< "$OUT"; printf '%s\n' "$OUT" | grep -A30 'Type' | sed 's/^/        | /'

# 3b. Killed right after the swap committed, before the old copy was reopened.
drop_old_copies; damage
interrupt_at 'donalabs-calcom-db .*RENAME TO "calendso"'
check "killed after the swap: exits non-zero" [ "$RC" -ne 0 ]
eq "killed after the swap: no database left refusing connections" "" "$(locked_dbs)"
eq "killed after the swap: restored data is live" "$ORIG" "$(snapshot calcom calendso)"
eq "killed after the swap: old copy kept and reopened" "1" "$(old_copies calendso)"
check "killed after the swap: says the swap completed" grep -q "swap completed: 'calendso' now holds the restored data" <<< "$OUT"

# 3c. Killed while the dump was loading into the temporary database.
drop_old_copies; damage
BEFORE="$(snapshot n8n n8n)"
interrupt_at 'donalabs-n8n-db psql .* -d dbname=n8n__restoring .*--single-transaction'
check "killed during the load: exits non-zero" [ "$RC" -ne 0 ]
eq "killed during the load: live n8n untouched" "$BEFORE" "$(snapshot n8n n8n)"
check "killed during the load: temporary database dropped" not_exists_tmp n8n
eq "killed during the load: no database left refusing connections" "" "$(locked_dbs)"

# 3d/3e. With a real `docker exec`, killing the client does not stop the psql
# inside the container: its statement may still be running (uncommitted) when
# the trap runs. FAKE_DETACH_ON reproduces that. The trap must wait for it and
# only then reopen, and never report "accepts connections" while it is not.
detach_at() {   # <ERE of the docker call> -> restore.sh, that call left running
  rm -f "$FAKE_LOG.killed"
  FAKE_DETACH_ON="$1" run_restore "$BK"
  rm -f "$FAKE_LOG.killed"
  # Give the detached session time to COMMIT (it sleeps 2 s) before checking.
  for _ in $(seq 100); do
    [ "$(q postgres postgres -c "SELECT count(*) FROM pg_stat_activity WHERE query LIKE '%fake-detached-%' AND pid <> pg_backend_pid()")" = 0 ] && break
    sleep 0.1
  done
}
drop_old_copies; damage
BEFORE="$(snapshot calcom calendso)"
detach_at 'donalabs-calcom-db .*"calendso" WITH ALLOW_CONNECTIONS false'
eq "lock still running in the container: no database left refusing connections" "" "$(locked_dbs)"
check "lock still running in the container: no false 'accepts connections'" \
  bash -c "[ -z \"\$1\" ] || grep -q \"'calendso' accepts connections\" <<< \"\$2\"" _ "$(locked_dbs)" "$OUT"
eq "lock still running in the container: live calendso untouched" "$BEFORE" "$(snapshot calcom calendso)"

drop_old_copies; damage
detach_at 'donalabs-calcom-db .* -1 .*RENAME TO "calendso"'
eq "swap still running in the container: no database left refusing connections" "" "$(locked_dbs)"
eq "swap still running in the container: it completed, restored data is live" "$ORIG" "$(snapshot calcom calendso)"
eq "swap still running in the container: old copy kept" "1" "$(old_copies calendso)"
check "swap still running in the container: the trap says the swap completed" \
  grep -q "swap completed: 'calendso' now holds the restored data" <<< "$OUT"

# A plain restore afterwards works (nothing left behind blocks it).
drop_old_copies
run_restore "$BK"
check "restore after the interruptions exits 0" [ "$RC" -eq 0 ]

# --- 4. database-level grants and settings survive the swap ---------------------
# pg_dump without --create does not carry them: GRANT ... ON DATABASE, ALTER
# DATABASE ... SET, ALTER ROLE ... IN DATABASE ... SET, the owner, the
# connection limit and the comment live on the database itself, and the swap
# replaces the database.
drop_old_copies
q postgres postgres \
  -c "CREATE ROLE reader NOLOGIN" -c "CREATE ROLE app_owner NOLOGIN" \
  -c "REVOKE ALL ON DATABASE calendso FROM PUBLIC" \
  -c "GRANT CONNECT ON DATABASE calendso TO reader" \
  -c "GRANT CREATE ON DATABASE calendso TO reader WITH GRANT OPTION" \
  -c "ALTER DATABASE calendso SET statement_timeout = '7s'" \
  -c "ALTER DATABASE calendso SET search_path = \"\$user\", public, \"Odd, schema\"" \
  -c "ALTER ROLE reader IN DATABASE calendso SET work_mem = '5MB'" \
  -c "ALTER DATABASE calendso CONNECTION LIMIT 50" \
  -c "COMMENT ON DATABASE calendso IS 'Cal.com'" \
  -c "ALTER DATABASE calendso OWNER TO app_owner"
q calcom calendso -c "GRANT SELECT ON items TO reader"   # object grant: in the dump
set +e
OUT="$(PATH="$SB/bin:$PATH" "$SB/backup.sh" --allow-partial 2>&1)"; RC=$?
set -e
PREV_BK="$BK"
BK="$(find "$SB/backups" -mindepth 1 -maxdepth 1 -type d ! -path "$PREV_BK" | sort | tail -1)"
check "setup: backup with the table grant" [ "$RC" -eq 0 ] && [ "$BK" != "$PREV_BK" ]
db_props() {
  q postgres postgres -c "SELECT concat_ws(' | ', pg_get_userbyid(d.datdba), d.datconnlimit,
      (SELECT string_agg(a, ',' ORDER BY a) FROM unnest(d.datacl::text[]) a),
      (SELECT string_agg(coalesce(r.rolname, '-') || ':' || array_to_string(s.setconfig, ';'), ',' ORDER BY r.rolname NULLS FIRST)
         FROM pg_db_role_setting s LEFT JOIN pg_roles r ON r.oid = s.setrole WHERE s.setdatabase = d.oid),
      shobj_description(d.oid, 'pg_database'))
    FROM pg_database d WHERE d.datname = '$1'"
}
PROPS="$(db_props calendso)"
check "setup: database properties are set" grep -q 'app_owner | 50 | .*reader=C\*c/app_owner.*statement_timeout=7s.*reader:work_mem=5MB | Cal.com' <<< "$PROPS"
run_restore "$BK"
check "restore with database grants exits 0" [ "$RC" -eq 0 ]
[ "$RC" -eq 0 ] || printf '%s\n' "$OUT" | sed 's/^/        | /'
eq "owner, connection limit, grants, settings and comment carried over" "$PROPS" "$(db_props calendso)"
eq "PUBLIC still has no CONNECT on the restored database" "f" \
  "$(q postgres postgres -c "SELECT has_database_privilege('public', 'calendso', 'CONNECT')")"
eq "table grants from the dump are there too" "t" \
  "$(q calcom calendso -c "SELECT has_table_privilege('reader', 'items', 'SELECT')")"
eq "search_path setting still works in a new session" '"$user", public, "Odd, schema"' \
  "$(q calcom calendso -c "SHOW search_path")"

# An empty list setting (SET search_path = '') is stored as "" and needs care.
q postgres postgres -c "ALTER DATABASE plausible_db SET search_path = ''"
run_restore "$BK"
check "empty search_path setting is copied too (exit 0)" [ "$RC" -eq 0 ]; [ "$RC" -eq 0 ] || printf "%s\n" "$OUT" | sed "s/^/        | /"
eq "empty search_path carried over" '""' "$(q plausible plausible_db -c "SHOW search_path")"
q postgres postgres -c "ALTER DATABASE plausible_db RESET search_path"

# --- 5. old copies are pruned: RESTORE_KEEP_PREVIOUS (default 2) per database ---
drop_old_copies
for _ in 1 2 3; do run_restore "$BK"; done
check "three restores in a row exit 0" [ "$RC" -eq 0 ]
for e in $DBS; do
  IFS=: read -r _ _ d <<< "$e"
  eq "$d: only the 2 newest old copies are kept" "2" "$(old_copies "$d")"
done
check "pruning is reported" grep -q 'dropped old copy calendso__pre_restore_' <<< "$OUT"
# ... and announced BEFORE the confirmation, by name.
TO_DROP="$(q postgres postgres -c "SELECT min(datname) FROM pg_database WHERE datname LIKE 'calendso\_\_pre\_restore\_%'")"
run_restore_answer() { local a="$1"; shift; set +e; OUT="$(PATH="$SB/bin:$PATH" "$SB/scripts/restore.sh" "$@" 2>&1 <<< "$a")"; RC=$?; set -e; }
run_restore_answer no "$BK"
check "before the prompt: names the old copy that will be dropped" \
  bash -c "printf '%s\n' \"\$1\" | sed -n \"/Type 'yes'/q;p\" | grep -q \"will drop old copy $TO_DROP\"" _ "$OUT"
eq "answering no: nothing was dropped" "2" "$(old_copies calendso)"
NEWEST="$(q postgres postgres -c "SELECT max(datname) FROM pg_database WHERE datname LIKE 'calendso\_\_pre\_restore\_%'")"
RESTORE_KEEP_PREVIOUS=1 run_restore "$BK"
check "RESTORE_KEEP_PREVIOUS=1: restore exits 0" [ "$RC" -eq 0 ]
eq "RESTORE_KEEP_PREVIOUS=1: one old copy left" "1" "$(old_copies calendso)"
check "RESTORE_KEEP_PREVIOUS=1: it is the one just made" \
  bash -c "[ \"\$1\" \\> \"\$2\" ]" _ "$(q postgres postgres -c "SELECT max(datname) FROM pg_database WHERE datname LIKE 'calendso\_\_pre\_restore\_%'")" "$NEWEST"
# Copies that do not follow the exact naming are never touched.
q postgres postgres -c "CREATE DATABASE calendso__pre_restore_mine" -c "CREATE DATABASE calendso__pre_restore_20200101000000x"
RESTORE_KEEP_PREVIOUS=1 run_restore "$BK"
check "hand-made look-alike databases are not pruned" \
  bash -c "db() { [ \"\$(psql -h '$PGROOT' -U postgres -d postgres -XAtc \"SELECT count(*) FROM pg_database WHERE datname = '\$1'\")\" = 1 ]; }; db calendso__pre_restore_mine && db calendso__pre_restore_20200101000000x"
# A copy someone is connected to is not force-dropped: warn, restore still OK.
drop_old_copies
run_restore "$BK"
held="$(q postgres postgres -c "SELECT datname FROM pg_database WHERE datname LIKE 'n8n\_\_pre\_restore\_%'")"
psql -h "$PGROOT" -U n8n -d "$held" -X -q -c "SELECT pg_sleep(30)" >/dev/null 2>&1 &
HOLD=$!
for _ in $(seq 50); do
  [ "$(q postgres postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '$held'")" = 1 ] && break
  sleep 0.1
done
RESTORE_KEEP_PREVIOUS=1 run_restore "$BK"
check "old copy in use: restore still exits 0" [ "$RC" -eq 0 ]
check "old copy in use: warned, not dropped" bash -c "grep -q 'could not drop old copy $held' <<< \"\$1\" && [ \"\$(psql -h '$PGROOT' -U postgres -d postgres -XAtc \"SELECT count(*) FROM pg_database WHERE datname = '$held'\")\" = 1 ]" _ "$OUT"
kill "$HOLD" 2>/dev/null || true; wait "$HOLD" 2>/dev/null || true

RESTORE_KEEP_PREVIOUS=0 run_restore "$BK"
check "RESTORE_KEEP_PREVIOUS=0 is refused before touching anything" bash -c "[ $RC -eq 1 ] && grep -q 'RESTORE_KEEP_PREVIOUS must be an integer >= 1' <<< \"\$1\"" _ "$OUT"

echo
echo "restore.sh (real PostgreSQL): $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
