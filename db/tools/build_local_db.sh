#!/bin/sh
# ============================================================================
# build_local_db.sh — stand up a LOCAL Docker Oracle Free DB and install the
# full DMT_OWNER schema from db_full/install.sql. Never touches ATP.
#
# Usage (Git Bash):  sh db_full/tools/build_local_db.sh [--fresh]
#   --fresh : remove any existing dmt2-local container first (full rebuild)
#
# Passwords are local-only throwaways (this DB holds no real data/creds).
# Override via env: ORA_PWD (SYSTEM), DMT_LOCAL_PWD (DMT_OWNER),
# DMT_LOCAL_PORT (host port for the listener; use when another container
# already holds 1521, e.g. rt-oracle-free).
# ============================================================================
set -e
ORA_PWD="${ORA_PWD:-OraLocal#2026}"
DMT_LOCAL_PWD="${DMT_LOCAL_PWD:-DmtLocal#2026}"
LKP_LOCAL_PWD="${LKP_LOCAL_PWD:-LkpLocal#2026}"
DMT_LOCAL_PORT="${DMT_LOCAL_PORT:-1523}"
IMG="${IMG:-container-registry.oracle.com/database/free:latest}"
SQLCL=/c/Users/Monroe/tools/sqlcl/bin/sql
export JAVA_HOME=/c/Users/Monroe/tools/jdk-21.0.11+10
export PATH="$JAVA_HOME/bin:$PATH"
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$1" = "--fresh" ]; then
  docker rm -f dmt2-local 2>/dev/null || true
fi

if ! docker ps --format '{{.Names}}' | grep -q '^dmt2-local$'; then
  if docker ps -a --format '{{.Names}}' | grep -q '^dmt2-local$'; then
    docker start dmt2-local
  else
    # ORACLE_PWD = official Oracle image; ORACLE_PASSWORD = gvenzl image
    docker run -d --name dmt2-local -p "$DMT_LOCAL_PORT":1521 \
      -e ORACLE_PWD="$ORA_PWD" -e ORACLE_PASSWORD="$ORA_PWD" "$IMG"
  fi
fi

echo "Waiting for database to be ready ..."
i=0
until docker logs dmt2-local 2>&1 | grep -q "DATABASE IS READY TO USE"; do
  i=$((i+1)); [ $i -gt 120 ] && { echo "DB not ready after 10 min"; exit 1; }
  sleep 5
done
echo "DB ready."

echo "Creating DMT_OWNER (as SYSTEM, once) ..."
# stdin must be piped: SQLcl crashes ("java.io.IOException: Incorrect
# function") on a non-tty stdin under Git Bash if left attached.
echo exit | "$SQLCL" -S system/"$ORA_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1 \
  @"$DIR/tools/local_db_setup.sql" "$DMT_LOCAL_PWD"
echo exit | "$SQLCL" -S system/"$ORA_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1 \
  @"$DIR/tools/local_lookup_setup.sql" "$LKP_LOCAL_PWD"

# SYS-owned package grants SYSTEM cannot make (see local_*_setup.sql notes)
docker exec dmt2-local bash -c "echo 'alter session set container=FREEPDB1;
grant execute on dbms_network_acl_admin to DMT_OWNER;
grant execute on utl_http to DMT_LOOKUP;
grant execute on utl_raw to DMT_LOOKUP;
grant execute on dbms_lob to DMT_LOOKUP;
exit' | sqlplus -S / as sysdba"

echo "Running db_full/install.sql as DMT_OWNER ..."
cd "$DIR"
echo exit | "$SQLCL" dmt_owner/"$DMT_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1 @install.sql \
  | tee /tmp/dmt2_install.log
echo "Install log: /tmp/dmt2_install.log"

echo "Granting DMT_OWNER objects to DMT_LOOKUP (live-ATP equivalent) ..."
echo "grant select on DMT_CONFIG_TBL to DMT_LOOKUP;
grant select on DMT_LOG_ID_SEQ to DMT_LOOKUP;
grant select, insert on DMT_LOG_TBL to DMT_LOOKUP;
exit" | "$SQLCL" -S dmt_owner/"$DMT_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1

echo "Running db_full/install_dmt_lookup.sql as DMT_LOOKUP ..."
echo exit | "$SQLCL" dmt_lookup/"$LKP_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1 @install_dmt_lookup.sql \
  | tee /tmp/dmt2_lookup_install.log

echo "Recompiling DMT_OWNER now that DMT_LOOKUP exists ..."
echo "exec dbms_utility.compile_schema(schema => 'DMT_OWNER', compile_all => false)
select count(*) as invalid_count from user_objects where status = 'INVALID';
exit" | "$SQLCL" -S dmt_owner/"$DMT_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1
echo "Logs: /tmp/dmt2_install.log, /tmp/dmt2_lookup_install.log"
