#!/bin/sh
# ============================================================================
# test_apex_images_rebuild.sh - offline proof that a local rebuild restores the
# APEX /i/ images and repairs the web tier automatically (backlog #159,
# owner-approved 2026-10-09).
#
# NOTHING REAL IS TOUCHED. docker, curl and SQLcl are fakes on a private PATH
# (only the fakes plus /usr/bin and /bin), the scripts under test are COPIED into
# a throwaway repo tree under a temp dir (so the sibling-workspace image source
# can never be picked up), every container name is a fake one, and the test
# refuses to start unless `docker` resolves to the fake. build_local_db.sh is run
# with --fresh only against the fake docker: no container is removed, no
# database is built (owner rule: never run a real fresh rebuild).
#
# Proves, for db/tools/provision_apex_images.sh:
#   A. empty images folder + web tier down  -> images restored, no restart
#   B. images present + web tier serving     -> nothing copied, nothing restarted
#   C. web tier up, static path unset        -> path set, container restarted, served
#   D. web tier up, stale mount (wiped+recreated folder) -> restart re-mounts, served
#   E. web tier never serves                 -> exit 1 after a bounded wait
#   F. no image source configured            -> warning, exit 0 (build not broken)
#   G. source of the wrong APEX version      -> exit 1
# and for db/tools/build_local_db.sh --fresh (fakes only):
#   H. images restored + web tier repaired BEFORE the DB install starts, and the
#      fake container (never dmt2-local) is the one removed
#   I. a DB-install failure still leaves the images restored and served
#
#   sh test/unit/test_apex_images_rebuild.sh        (exit 0 = all passed)
# ============================================================================
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
T="$(mktemp -d 2>/dev/null || echo "/tmp/apximg_test_$$")"
mkdir -p "$T"
trap 'rm -rf "$T"' EXIT

PASSED=0
FAILED=0
ok()   { PASSED=$((PASSED + 1)); echo "PASS  $1"; }
bad()  { FAILED=$((FAILED + 1)); echo "FAIL  $1"; }
check() { if eval "$1"; then ok "$2"; else bad "$2"; fi; }

# --- fakes ------------------------------------------------------------------
BIN="$T/bin"
mkdir -p "$BIN"

cat > "$BIN/docker" <<'EOF'
#!/bin/sh
S="$FAKE_STATE"
echo "docker $*" >> "$S/docker.log"
case "$1" in
  ps)
    if [ "${2:-}" = "-a" ]; then cat "$S/exists" 2>/dev/null; else cat "$S/running" 2>/dev/null; fi ;;
  inspect) cat "$S/mount_src" 2>/dev/null ;;
  logs) echo "DATABASE IS READY TO USE" ;;
  exec)
    case "$*" in
      *"config get standalone.static.path"*) cat "$S/static_path" 2>/dev/null ;;
      *"config set standalone.static.path"*)
        for a in "$@"; do last="$a"; done
        printf '%s\n' "$last" > "$S/static_path" ;;
      *reap_assert*) echo "REAP144 ENABLED 32" ;;
    esac ;;
  restart) touch "$S/restarted" ;;
esac
exit 0
EOF

# Serves /i/apex_version.txt from FAKE_SERVED_DIR only when the web tier is
# healthy: either marked healthy, or the static path is set AND the container
# was restarted (which is what re-mounts a wiped folder).
cat > "$BIN/curl" <<'EOF'
#!/bin/sh
S="$FAKE_STATE"
echo "curl $*" >> "$S/curl.log"
up=0
[ -f "$S/healthy" ] && up=1
if [ "$(cat "$S/static_path" 2>/dev/null)" = "/opt/oracle/apex/images" ] && [ -f "$S/restarted" ]; then up=1; fi
[ -f "$S/never_serves" ] && up=0
[ -f "$FAKE_SERVED_DIR/apex_version.txt" ] || up=0
case "$*" in
  *"%{http_code}"*) if [ $up = 1 ]; then printf 200; else printf 404; fi ;;
  *) [ $up = 1 ] && cat "$FAKE_SERVED_DIR/apex_version.txt" ;;
esac
exit 0
EOF

cat > "$BIN/sql" <<'EOF'
#!/bin/sh
S="$FAKE_STATE"
cat > /dev/null
echo "sql $*" >> "$S/sql.log"
if [ -n "${FAKE_SQLCL_FAIL_ON:-}" ]; then
  case "$*" in *"$FAKE_SQLCL_FAIL_ON"*) echo "SP2-0310: unable to open file" >&2; exit 1 ;; esac
fi
exit 0
EOF
chmod +x "$BIN/docker" "$BIN/curl" "$BIN/sql"

PATH="$BIN:/usr/bin:/bin"
export PATH
if [ "$(command -v docker)" != "$BIN/docker" ]; then
  echo "ABORT: docker does not resolve to the fake ($(command -v docker)); refusing to run." >&2
  exit 2
fi

# --- a throwaway repo tree holding copies of the scripts under test ----------
FAKE_REPO="$T/repo"
mkdir -p "$FAKE_REPO/db/tools"
cp "$REPO/db/tools/provision_apex_images.sh" "$REPO/db/tools/build_local_db.sh" "$FAKE_REPO/db/tools/"
PROVISION="$FAKE_REPO/db/tools/provision_apex_images.sh"
BUILD="$FAKE_REPO/db/tools/build_local_db.sh"
# The build script must take SQLCL and LOG_DIR from the environment, or it would
# call the real SQLcl against the real local database. Refuse otherwise.
if ! grep -q 'SQLCL="${SQLCL:-' "$BUILD" || ! grep -q 'LOG_DIR="${LOG_DIR:-' "$BUILD"; then
  echo "ABORT: build_local_db.sh does not honour SQLCL/LOG_DIR overrides; refusing to run it." >&2
  exit 2
fi

# A populated APEX 26.1 image source and a 24.2 one.
SRC="$T/src/images"
mkdir -p "$SRC/libraries"
printf 'Oracle APEX Version:  26.1\r\n' > "$SRC/apex_version.txt"
echo "js" > "$SRC/libraries/apex.min.js"
OLD="$T/old/images"
mkdir -p "$OLD"
printf 'Oracle APEX Version:  24.2\n' > "$OLD/apex_version.txt"

# Fresh fake state per case. $1 = case name. Mount source = $T/<case>/apex.
new_case() {
  FAKE_STATE="$T/$1/state"
  MNT="$T/$1/apex"
  rm -rf "$T/$1"
  mkdir -p "$FAKE_STATE" "$MNT"
  : > "$FAKE_STATE/docker.log"
  : > "$FAKE_STATE/running"
  : > "$FAKE_STATE/exists"
  printf '%s\n' "$MNT" > "$FAKE_STATE/mount_src"
  FAKE_SERVED_DIR="$MNT/images"
  export FAKE_STATE FAKE_SERVED_DIR
  unset FAKE_SQLCL_FAIL_ON 2>/dev/null || true
}
ords_up() { echo "dmt2-ords-fake" >> "$FAKE_STATE/running"; echo "dmt2-ords-fake" >> "$FAKE_STATE/exists"; }

run_provision() {
  ORDS_CONTAINER=dmt2-ords-fake ORDS_BASE_URL=http://fake:1 ORDS_WAIT_S=2 ORDS_POLL_S=1 \
    sh "$PROVISION" > "$FAKE_STATE/out.txt" 2>&1
}

# A. empty images folder, web tier down
new_case A
APEX_IMAGES_SRC="$SRC" run_provision; rc=$?
check '[ $rc = 0 ] && grep -q "26.1" "$MNT/images/apex_version.txt" && [ -f "$MNT/images/libraries/apex.min.js" ] && [ ! -f "$FAKE_STATE/restarted" ]' \
  "A: empty images folder is restored from the source; web tier down so nothing restarted"

# B. already in place and served
new_case B
mkdir -p "$MNT/images"; cp "$SRC/apex_version.txt" "$MNT/images/"; ords_up; touch "$FAKE_STATE/healthy"
APEX_IMAGES_SRC="$SRC" run_provision; rc=$?
check '[ $rc = 0 ] && [ ! -f "$MNT/images/libraries/apex.min.js" ] && [ ! -f "$FAKE_STATE/restarted" ] && ! grep -q "config set" "$FAKE_STATE/docker.log"' \
  "B: images present and served -> no copy, no config change, no restart"

# C. web tier up, images wiped, static path never set
new_case C
ords_up
APEX_IMAGES_SRC="$SRC" run_provision; rc=$?
check '[ $rc = 0 ] && grep -q "config set standalone.static.path /opt/oracle/apex/images" "$FAKE_STATE/docker.log" && grep -q "^docker restart dmt2-ords-fake" "$FAKE_STATE/docker.log" && grep -q "repaired" "$FAKE_STATE/out.txt"' \
  "C: static path unset -> set automatically, ORDS restarted, /i/ serves 26.1"

# D. static path set, but the mount is stale (folder wiped and recreated)
new_case D
ords_up; echo "/opt/oracle/apex/images" > "$FAKE_STATE/static_path"
APEX_IMAGES_SRC="$SRC" run_provision; rc=$?
check '[ $rc = 0 ] && ! grep -q "config set" "$FAKE_STATE/docker.log" && grep -q "^docker restart dmt2-ords-fake" "$FAKE_STATE/docker.log"' \
  "D: stale mount -> container restarted (re-mount) without touching the config, then served"

# E. never serves -> bounded failure
new_case E
ords_up; touch "$FAKE_STATE/never_serves"
APEX_IMAGES_SRC="$SRC" run_provision; rc=$?
check '[ $rc = 1 ] && grep -q "still returns HTTP 404" "$FAKE_STATE/out.txt"' \
  "E: web tier still broken after the repair -> exit 1 after a bounded wait"

# F. no source configured (the throwaway tree has no sibling image workspace)
new_case F
APEX_IMAGES_SRC= run_provision; rc=$?
check '[ $rc = 0 ] && grep -q "WARNING: no APEX image source" "$FAKE_STATE/out.txt"' \
  "F: no image source -> warning only, exit 0 (a DB build is never broken by it)"

# G. wrong-version source
new_case G
APEX_IMAGES_SRC="$OLD" run_provision; rc=$?
check '[ $rc = 1 ] && grep -q "version .24.2." "$FAKE_STATE/out.txt"' \
  "G: a 24.2 image source is refused (images must match APEX 26.1)"

# H. build_local_db.sh --fresh with fakes: restore happens before the DB install
run_build() {
  CONTAINER=dmt2-unittest-fake SQLCL="$BIN/sql" LOG_DIR="$FAKE_STATE" \
  APEX_IMAGES_SRC="$SRC" ORDS_CONTAINER=dmt2-ords-fake ORDS_BASE_URL=http://fake:1 \
  ORDS_WAIT_S=2 ORDS_POLL_S=1 \
    sh "$BUILD" --fresh > "$FAKE_STATE/build.txt" 2>&1
}
new_case H
ords_up
run_build; rc=$?
first_restore=$(grep -n "Restoring APEX /i/" "$FAKE_STATE/build.txt" | head -1 | cut -d: -f1)
db_wait=$(grep -n "Waiting for database" "$FAKE_STATE/build.txt" | head -1 | cut -d: -f1)
check '[ $rc = 0 ] && grep -q "26.1" "$MNT/images/apex_version.txt" && grep -q "^docker restart dmt2-ords-fake" "$FAKE_STATE/docker.log"' \
  "H: --fresh rebuild restores the images and repairs the web tier automatically"
check '[ -n "$first_restore" ] && [ -n "$db_wait" ] && [ "$first_restore" -lt "$db_wait" ] && grep -q "install.sql" "$FAKE_STATE/sql.log"' \
  "H: the restore runs BEFORE the DB install starts, and the install still runs"
check 'grep -q "^docker rm -f dmt2-unittest-fake" "$FAKE_STATE/docker.log" && ! grep -q "dmt2-local" "$FAKE_STATE/docker.log"' \
  "H: only the fake container was removed (dmt2-local never named)"
check 'grep -q "Final check: APEX" "$FAKE_STATE/build.txt" && [ "$(grep -c "^docker restart" "$FAKE_STATE/docker.log")" = 1 ]' \
  "H: the final check re-verifies without a second restart"

# I. the DB install fails early: the images are still restored and served
new_case I
ords_up
FAKE_SQLCL_FAIL_ON=local_db_setup.sql
export FAKE_SQLCL_FAIL_ON
run_build; rc=$?
check '[ $rc != 0 ] && grep -q "26.1" "$MNT/images/apex_version.txt" && grep -q "^docker restart dmt2-ords-fake" "$FAKE_STATE/docker.log" && ! grep -q "install.sql" "$FAKE_STATE/sql.log"' \
  "I: a failed DB install no longer skips the image restore (login not left broken)"

echo "TEST_APEX_IMAGES_REBUILD: $PASSED passed, $FAILED failed"
[ "$FAILED" = 0 ]
