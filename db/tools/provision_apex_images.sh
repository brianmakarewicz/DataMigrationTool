#!/bin/sh
# ============================================================================
# provision_apex_images.sh  (Backlog #159)
#
# Make sure the APEX static image set that the dmt2-ords web tier serves at
# "/i/" is present and is the right version, so a browser login to the Data
# Migration Console never breaks after a fresh local rebuild.
#
# WHY THIS EXISTS
#   The dmt2-ords container serves APEX static files from a host bind-mount:
#       host  C:\Users\Monroe\workspace\DMT2\apex\installer\apex
#         ->  container /opt/oracle/apex   (read-only)
#   and "/i/" is the images/ subfolder of that mount. The ~29k image files
#   (~500 MB of APEX 26.1 JS/CSS) are deliberately NOT committed to git, so a
#   fresh clone or a "--fresh" rebuild leaves that folder empty. When it is
#   empty, "/i/" returns 404, the APEX 26.1 browser JS/CSS never load, and the
#   Sign In button does nothing. This script restores the images from a known
#   populated APEX 26.1 distribution so the rebuild handles it automatically.
#
# WHAT IT DOES (idempotent + version-checked — safe to run on every build)
#   1. If the served images folder already holds the right version (26.1),
#      do nothing.
#   2. Otherwise copy the image set from the known-good 26.1 source into the
#      mount folder.
#   3. Verify the copy by reading images/apex_version.txt.
#   4. If dmt2-ords is running, verify "/i/apex_version.txt" serves HTTP 200.
#
# Override via env:
#   APEX_IMAGES_DEST  served mount folder (default: <repo>/apex/installer/apex/images)
#   APEX_IMAGES_SRC   known-good 26.1 image set to copy FROM
#                     (default: APEXResourceTracker/cicd/docker/downloads/apex/images)
#   APEX_VERSION      expected version string fragment (default: 26.1)
#   ORDS_BASE_URL     base URL of the running web tier (default: http://localhost:8182)
# ============================================================================
set -e

EXPECT_VER="${APEX_VERSION:-26.1}"
ORDS_BASE_URL="${ORDS_BASE_URL:-http://localhost:8182}"

# Repo root = parent of this script's db/tools dir.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${APEX_IMAGES_DEST:-$DIR/apex/installer/apex/images}"
SRC="${APEX_IMAGES_SRC:-/c/Users/Monroe/workspace/APEXResourceTracker/cicd/docker/downloads/apex/images}"

ver_of() {
  # Print the version fragment from an apex_version.txt, or empty if absent.
  if [ -f "$1/apex_version.txt" ]; then
    # File reads e.g. "Oracle APEX Version:  26.1"
    tr -d '\r' < "$1/apex_version.txt" | grep -o '[0-9][0-9]*\.[0-9][0-9]*' | head -1
  fi
}

echo "APEX images: expecting version $EXPECT_VER in $DEST"

DEST_VER="$(ver_of "$DEST" || true)"
if [ "$DEST_VER" = "$EXPECT_VER" ]; then
  echo "APEX images: already present and version $DEST_VER — nothing to do."
else
  if [ -n "$DEST_VER" ]; then
    echo "APEX images: found version '$DEST_VER' (want '$EXPECT_VER') — refreshing from source."
  else
    echo "APEX images: missing or empty — restoring from source."
  fi

  SRC_VER="$(ver_of "$SRC" || true)"
  if [ ! -d "$SRC" ] || [ -z "$SRC_VER" ]; then
    echo "ERROR: APEX image source not found or has no apex_version.txt: $SRC" >&2
    echo "       Point APEX_IMAGES_SRC at a populated APEX $EXPECT_VER image set." >&2
    exit 1
  fi
  if [ "$SRC_VER" != "$EXPECT_VER" ]; then
    echo "ERROR: source image set is version '$SRC_VER', not '$EXPECT_VER': $SRC" >&2
    echo "       The DB APEX is $EXPECT_VER; the images MUST match or the browser breaks." >&2
    exit 1
  fi

  mkdir -p "$DEST"
  # Mirror the source into the destination. robocopy is the fast path on this
  # Windows host (handles the ~29k files well); fall back to cp -a elsewhere.
  if command -v robocopy >/dev/null 2>&1; then
    # Convert the Git-Bash /c/... paths to Windows paths for robocopy.
    # Prefer cygpath (handles any path); fall back to a simple drive rewrite.
    if command -v cygpath >/dev/null 2>&1; then
      winpath() { cygpath -w "$1"; }
    else
      winpath() { printf '%s\n' "$1" | sed -e 's;^/\([a-zA-Z]\)/;\1:/;' -e 's;/;\\;g'; }
    fi
    # robocopy exit codes 0-7 are success (8+ is a real failure); never let a
    # success code trip `set -e`. The flags use a leading "//" so Git-Bash's
    # MSYS path mangling does not rewrite "/MIR" into a bogus "C:/.../MIR" arg.
    robocopy "$(winpath "$SRC")" "$(winpath "$DEST")" //MIR //NFL //NDL //NJH //NJS //NP >/dev/null || \
      { rc=$?; [ "$rc" -ge 8 ] && { echo "ERROR: robocopy failed (code $rc)" >&2; exit 1; }; }
  else
    cp -a "$SRC/." "$DEST/"
  fi

  DEST_VER="$(ver_of "$DEST" || true)"
  if [ "$DEST_VER" != "$EXPECT_VER" ]; then
    echo "ERROR: after copy, $DEST reports version '$DEST_VER', expected '$EXPECT_VER'" >&2
    exit 1
  fi
  FILES="$(find "$DEST" -type f 2>/dev/null | wc -l | tr -d ' ')"
  echo "APEX images: restored version $DEST_VER ($FILES files)."
fi

# If the web tier is up, prove the browser path actually serves the images.
# (A fresh DB rebuild does not start dmt2-ords, so this is best-effort: a
# non-200 only warns when the container is actually running.)
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^dmt2-ords$'; then
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$ORDS_BASE_URL/i/apex_version.txt" 2>/dev/null || echo 000)"
  if [ "$CODE" = "200" ]; then
    SERVED="$(curl -s "$ORDS_BASE_URL/i/apex_version.txt" 2>/dev/null | tr -d '\r' | grep -o '[0-9][0-9]*\.[0-9][0-9]*' | head -1)"
    echo "APEX images: $ORDS_BASE_URL/i/apex_version.txt serves HTTP 200 (version $SERVED)."
  else
    echo "WARNING: dmt2-ords is running but $ORDS_BASE_URL/i/ returned HTTP $CODE, not 200." >&2
    echo "         The files are in place; ORDS may need 'standalone.static.path'" >&2
    echo "         set to /opt/oracle/apex/images and a container restart." >&2
    echo "         See memory/reference_dmt2_ords_startup.md." >&2
  fi
else
  echo "APEX images: dmt2-ords not running — skipping the live /i/ 200 check (files are in place)."
fi
