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
    q "$u" "$d" -c "UPDATE items SET v = 'changed'" -c "INSERT INTO items (owner, v) VALUES (2, 'new')" \
      -c "DROP TABLE IF EXISTS extra" -c "CREATE TABLE IF NOT EXISTS junk (x int)"
  done
}
db_exists() { [ "$(q postgres postgres -c "SELECT count(*) FROM pg_database WHERE datname = '$1'")" = 1 ]; }
not_exists_tmp() { ! db_exists "$1__restoring"; }
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

run_restore() {
  set +e
  OUT="$(PATH="$SB/bin:$PATH" "$SB/scripts/restore.sh" "$@" 2>&1 <<< yes)"; RC=$?
  set -e
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

echo
echo "restore.sh (real PostgreSQL): $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
