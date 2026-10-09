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
# SQLCL (path to the sql binary) and LOG_DIR (where the install logs go,
# default /tmp) can be overridden too.
#
# APEX static images (backlog #159, owner-approved 2026-10-09): every build,
# --fresh included, restores the console's /i/ images and repairs the web tier
# automatically (db/tools/provision_apex_images.sh): once right after the
# container step, so a failure later in the DB install can never skip it, and
# once more at the end as the strict live check. A rebuild therefore never
# leaves the console login broken. Proven offline with mocked docker/curl/sqlcl:
# test/unit/test_apex_images_rebuild.sh.
# ============================================================================
set -e
ORA_PWD="${ORA_PWD:-OraLocal#2026}"
DMT_LOCAL_PWD="${DMT_LOCAL_PWD:-DmtLocal#2026}"
LKP_LOCAL_PWD="${LKP_LOCAL_PWD:-LkpLocal#2026}"
DMT_LOCAL_PORT="${DMT_LOCAL_PORT:-1523}"
CONTAINER="${CONTAINER:-dmt2-local}"
DATA_DIR="${DATA_DIR:-}"          # when set, bind-mount container oradata here
IMG="${IMG:-container-registry.oracle.com/database/free:latest}"
SQLCL="${SQLCL:-/c/Users/Monroe/tools/sqlcl/bin/sql}"
LOG_DIR="${LOG_DIR:-/tmp}"
export JAVA_HOME=/c/Users/Monroe/tools/jdk-21.0.11+10
export PATH="$JAVA_HOME/bin:$PATH"
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$1" = "--fresh" ]; then
  docker rm -f "$CONTAINER" 2>/dev/null || true
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}\$"; then
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}\$"; then
    docker start "$CONTAINER"
  else
    # ORACLE_PWD = official Oracle image; ORACLE_PASSWORD = gvenzl image
    docker run -d --name "$CONTAINER" -p "$DMT_LOCAL_PORT":1521 \
      -e ORACLE_PWD="$ORA_PWD" -e ORACLE_PASSWORD="$ORA_PWD" \
      ${DATA_DIR:+-v "$DATA_DIR":/opt/oracle/oradata} "$IMG"
  fi
fi

# Backlog #159: restore the APEX /i/ images (and repair the web tier) FIRST.
# It never touches the DB, so it runs before the long install: a later failure
# under `set -e` cannot leave the console login broken. A problem here only
# warns; the strict check runs again at the end of the build.
echo "Restoring APEX /i/ static images before the DB install (backlog #159) ..."
sh "$DIR/tools/provision_apex_images.sh" \
  || echo "WARNING: APEX image restore reported a problem; it is re-checked at the end of the build." >&2

echo "Waiting for database to be ready ..."
i=0
until docker logs "$CONTAINER" 2>&1 | grep -q "DATABASE IS READY TO USE"; do
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

# SYS-owned package grants SYSTEM cannot make (see local_*_setup.sql notes).
# Backlog #144: also raise job_queue_processes so a stray orphaned worker job
# can never starve the poller. 32 clears the ~34-object pipeline's realistic
# peak of in-flight workers (~15-20) plus the poller, with headroom; the
# startup trigger below clears zombies so no extra padding is needed.
docker exec "$CONTAINER" bash -c "echo 'alter session set container=FREEPDB1;
grant execute on dbms_network_acl_admin to DMT_OWNER;
grant execute on utl_http to DMT_LOOKUP;
grant execute on utl_raw to DMT_LOOKUP;
grant execute on dbms_lob to DMT_LOOKUP;
alter system set job_queue_processes=32 scope=both;
exit' | sqlplus -S / as sysdba"

# Backlog #144: SYS-owned AFTER STARTUP ON DATABASE trigger that force-drops
# orphaned one-shot worker jobs (DMT_WQ_/DMT_PL_/DMT_PF_) left behind by a
# mid-run shutdown, so a `docker restart` self-heals. Source of truth is the
# committed db/tools/sys_startup_reap_trigger.sql; copy it into the container
# and run it as sysdba. Preserves the persistent poller (not in those families).
docker cp "$DIR/tools/sys_startup_reap_trigger.sql" "$CONTAINER":/tmp/sys_startup_reap_trigger.sql
docker exec "$CONTAINER" bash -c "echo 'alter session set container=FREEPDB1;
@/tmp/sys_startup_reap_trigger.sql
exit' | sqlplus -S / as sysdba"

# Assert the trigger compiled clean (CREATE OR REPLACE succeeds even on an
# invalid body) AND the slot raise took, so either failing stops the build
# loudly instead of silently disabling the self-heal. The assertion query lives
# in its own committed .sql file (run exactly like the trigger file above) so no
# SQL string literal is nested inside a bash single-quoted echo -- that nesting
# strips the quotes and yields ORA-00904. The file prints "REAP144 <status>
# <slots>", e.g. "REAP144 ENABLED 32".
docker cp "$DIR/tools/sys_startup_reap_assert.sql" "$CONTAINER":/tmp/sys_startup_reap_assert.sql
REAP_ASSERT=$(docker exec "$CONTAINER" bash -c "echo '@/tmp/sys_startup_reap_assert.sql' | sqlplus -S / as sysdba" | grep '^REAP144' | tr -s ' ')
if [ "$REAP_ASSERT" != "REAP144 ENABLED 32" ]; then
  echo "ERROR: startup reap self-check failed. Expected 'REAP144 ENABLED 32', got '$REAP_ASSERT'" >&2
  echo "       (trigger status must be ENABLED and job_queue_processes must be 32)" >&2
  exit 1
fi
echo "Startup reap trigger ENABLED and job_queue_processes=32 confirmed ($REAP_ASSERT)."

echo "Running db_full/install.sql as DMT_OWNER ..."
cd "$DIR"
echo exit | "$SQLCL" dmt_owner/"$DMT_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1 @install.sql \
  | tee "$LOG_DIR"/dmt2_install.log
echo "Install log: $LOG_DIR/dmt2_install.log"

echo "Granting DMT_OWNER objects to DMT_LOOKUP (live-ATP equivalent) ..."
echo "grant select on DMT_CONFIG_TBL to DMT_LOOKUP;
grant select on DMT_LOG_ID_SEQ to DMT_LOOKUP;
grant select, insert on DMT_LOG_TBL to DMT_LOOKUP;
exit" | "$SQLCL" -S dmt_owner/"$DMT_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1

echo "Creating DMT_LOOKUP synonyms to the owner's config/log/seq (schema-relative refresh pkg) ..."
echo "create or replace synonym DMT_CONFIG_TBL for DMT_OWNER.DMT_CONFIG_TBL;
create or replace synonym DMT_LOG_TBL for DMT_OWNER.DMT_LOG_TBL;
create or replace synonym DMT_LOG_ID_SEQ for DMT_OWNER.DMT_LOG_ID_SEQ;
exit" | "$SQLCL" -S dmt_lookup/"$LKP_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1

echo "Running db_full/install_dmt_lookup.sql as DMT_LOOKUP ..."
echo exit | "$SQLCL" dmt_lookup/"$LKP_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1 @install_dmt_lookup.sql \
  | tee "$LOG_DIR"/dmt2_lookup_install.log

echo "Recompiling DMT_OWNER now that DMT_LOOKUP exists ..."
echo "exec dbms_utility.compile_schema(schema => 'DMT_OWNER', compile_all => false)
select count(*) as invalid_count from user_objects where status = 'INVALID';
exit" | "$SQLCL" -S dmt_owner/"$DMT_LOCAL_PWD"@//localhost:"$DMT_LOCAL_PORT"/FREEPDB1
echo "Logs: $LOG_DIR/dmt2_install.log, $LOG_DIR/dmt2_lookup_install.log"

# Backlog #159: re-provision the APEX static image set the dmt2-ords web tier
# serves at "/i/". Those ~29k 26.1 image files live on the apex/installer/apex
# bind-mount but are NOT committed to git, so a fresh clone or rebuild leaves
# the folder empty and the browser login to the console breaks (unstyled page,
# dead Sign In button). This step restores them from APEX_IMAGES_SRC (see the
# script header) into the folder dmt2-ords actually mounts, if missing or
# version-mismatched. Idempotent + version-checked — a no-op once the right
# images are already in place; only warns (never fails the build) when no image
# source is configured. Never touches the DB.
echo "Final check: APEX /i/ static images present and served (backlog #159) ..."
sh "$DIR/tools/provision_apex_images.sh"
