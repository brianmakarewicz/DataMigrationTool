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
#       host  <repo>/apex/installer/apex
#         ->  container /opt/oracle/apex   (read-only)
#   and "/i/" is the images/ subfolder of that mount. The ~29k image files
#   (~500 MB of APEX 26.1 JS/CSS) are deliberately NOT committed to git, so a
#   fresh clone or a "--fresh" rebuild leaves that folder empty. When it is
#   empty, "/i/" returns 404, the APEX 26.1 browser JS/CSS never load, and the
#   Sign In button does nothing. This script restores the images from a
#   populated APEX 26.1 image distribution so the rebuild handles it.
#
# WHAT IT DOES (idempotent + version-checked — safe to run on every build)
#   1. Resolve the destination: APEX_IMAGES_DEST, else the host folder that
#      the dmt2-ords container ACTUALLY bind-mounts at /opt/oracle/apex (plus
#      /images), else <repo>/apex/installer/apex/images.
#   2. If that folder already holds the expected version (26.1), do nothing.
#   3. Otherwise, if a source image set is configured, copy it in (additive:
#      new/changed files are written, nothing in the destination is deleted).
#      If no source is configured, print a WARNING and exit 0 — the step never
#      breaks a DB build on a machine (or CI runner) without the image set.
#   4. Verify the copy by reading images/apex_version.txt.
#   5. If dmt2-ords is running, verify "/i/apex_version.txt" serves HTTP 200;
#      a non-200 there is a hard failure (exit 1), because the files are
#      believed to be in place and the browser would still be broken.
#
# Configuration (env):
#   APEX_IMAGES_SRC   populated APEX 26.1 images/ folder to copy FROM. No
#                     machine-specific default is committed. If unset, the
#                     sibling-workspace convention
#                       <repo>/../APEXResourceTracker/cicd/docker/downloads/apex/images
#                     is used when that folder exists.
#   APEX_IMAGES_DEST  served images folder (see step 1 for the default)
#   APEX_VERSION      expected version string fragment (default: 26.1)
#   ORDS_CONTAINER    web-tier container name (default: dmt2-ords)
#   ORDS_BASE_URL     base URL of the running web tier (default: http://localhost:8182)
# ============================================================================
set -e

EXPECT_VER="${APEX_VERSION:-26.1}"
ORDS_CONTAINER="${ORDS_CONTAINER:-dmt2-ords}"
ORDS_BASE_URL="${ORDS_BASE_URL:-http://localhost:8182}"

# This script lives in <repo>/db/tools, so the repo root is two levels up.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

to_unix_path() {
  # docker inspect reports Windows host paths (C:\...); normalise for sh.
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}

ords_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${ORDS_CONTAINER}\$"
}

# --- 1. Resolve the destination ---------------------------------------------
if [ -n "$APEX_IMAGES_DEST" ]; then
  DEST="$APEX_IMAGES_DEST"
  DEST_HOW="APEX_IMAGES_DEST"
else
  MOUNT_SRC="$(docker inspect "$ORDS_CONTAINER" \
      --format '{{range .Mounts}}{{if eq .Destination "/opt/oracle/apex"}}{{.Source}}{{end}}{{end}}' \
      2>/dev/null || true)"
  if [ -n "$MOUNT_SRC" ]; then
    DEST="$(to_unix_path "$MOUNT_SRC")/images"
    DEST_HOW="$ORDS_CONTAINER bind-mount of /opt/oracle/apex"
  else
    DEST="$REPO_ROOT/apex/installer/apex/images"
    DEST_HOW="repo default (no $ORDS_CONTAINER container found)"
  fi
fi

# Guard: only ever write into an APEX images folder.
case "$DEST" in
  */images|*/images/) ;;
  *) echo "ERROR: refusing to provision into '$DEST' — destination must be an APEX 'images' folder." >&2
     exit 1 ;;
esac

# --- source resolution ------------------------------------------------------
if [ -n "$APEX_IMAGES_SRC" ]; then
  SRC="$APEX_IMAGES_SRC"
elif [ -d "$REPO_ROOT/../APEXResourceTracker/cicd/docker/downloads/apex/images" ]; then
  SRC="$(cd "$REPO_ROOT/../APEXResourceTracker/cicd/docker/downloads/apex/images" && pwd)"
else
  SRC=""
fi

ver_of() {
  # Print the version fragment from an apex_version.txt, or empty if absent.
  if [ -f "$1/apex_version.txt" ]; then
    # File reads e.g. "Oracle APEX Version:  26.1"
    tr -d '\r' < "$1/apex_version.txt" | grep -o '[0-9][0-9]*\.[0-9][0-9]*' | head -1
  fi
}

echo "APEX images: expecting version $EXPECT_VER in $DEST ($DEST_HOW)"

# --- 2. already in place? ---------------------------------------------------
DEST_VER="$(ver_of "$DEST" || true)"
if [ "$DEST_VER" = "$EXPECT_VER" ]; then
  echo "APEX images: already present and version $DEST_VER — nothing to copy."
else
  if [ -n "$DEST_VER" ]; then
    echo "APEX images: found version '$DEST_VER' (want '$EXPECT_VER') — refreshing from source."
  else
    echo "APEX images: missing or empty — restoring from source."
  fi

  # --- 3. no source configured: warn, never break the build -----------------
  if [ -z "$SRC" ]; then
    echo "WARNING: no APEX image source configured, so $DEST was NOT provisioned." >&2
    echo "         The console's /i/ will 404 (unstyled page, dead Sign In) until it is." >&2
    echo "         Set APEX_IMAGES_SRC to a populated APEX $EXPECT_VER images/ folder and" >&2
    echo "         re-run: sh db/tools/provision_apex_images.sh" >&2
    exit 0
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
  # Additive copy on both paths: write new/changed files, never delete
  # anything already in DEST. robocopy /E (not /MIR) is the fast path on this
  # Windows host (handles the ~29k files well); cp -a is the equivalent
  # elsewhere.
  if command -v robocopy >/dev/null 2>&1; then
    # Convert the Git-Bash /c/... paths to Windows paths for robocopy.
    if command -v cygpath >/dev/null 2>&1; then
      winpath() { cygpath -w "$1"; }
    else
      winpath() { printf '%s\n' "$1" | sed -e 's;^/\([a-zA-Z]\)/;\1:/;' -e 's;/;\\;g'; }
    fi
    # robocopy exit codes 0-7 are success (8+ is a real failure); never let a
    # success code trip `set -e`. The flags use a leading "//" so Git-Bash's
    # MSYS path mangling does not rewrite "/E" into a bogus "C:/.../E" arg.
    rc=0
    robocopy "$(winpath "$SRC")" "$(winpath "$DEST")" //E //NFL //NDL //NJH //NJS //NP >/dev/null || rc=$?
    if [ "$rc" -ge 8 ]; then
      echo "ERROR: robocopy failed (code $rc)" >&2
      exit 1
    fi
  else
    cp -a "$SRC/." "$DEST/"
  fi

  # --- 4. verify the copy ---------------------------------------------------
  DEST_VER="$(ver_of "$DEST" || true)"
  if [ "$DEST_VER" != "$EXPECT_VER" ]; then
    echo "ERROR: after copy, $DEST reports version '$DEST_VER', expected '$EXPECT_VER'" >&2
    exit 1
  fi
  FILES="$(find "$DEST" -type f 2>/dev/null | wc -l | tr -d ' ')"
  echo "APEX images: restored version $DEST_VER ($FILES files)."
fi

# --- 5. prove the browser path actually serves the images -------------------
# A DB rebuild does not start the web tier, so this only runs when it is up.
# When it IS up and /i/ is not 200, the browser is broken even though the
# files are in place — that is a failure, not a warning.
if ords_running; then
  CODE="$(curl -s -o /dev/null -w '%{http_code}' "$ORDS_BASE_URL/i/apex_version.txt" 2>/dev/null || true)"
  [ -n "$CODE" ] || CODE=000
  if [ "$CODE" = "200" ]; then
    SERVED="$(curl -s "$ORDS_BASE_URL/i/apex_version.txt" 2>/dev/null | tr -d '\r' | grep -o '[0-9][0-9]*\.[0-9][0-9]*' | head -1)"
    if [ "$SERVED" != "$EXPECT_VER" ]; then
      echo "ERROR: $ORDS_BASE_URL/i/apex_version.txt serves version '$SERVED', expected '$EXPECT_VER'." >&2
      echo "       $ORDS_CONTAINER is not serving the folder this script provisioned ($DEST)." >&2
      exit 1
    fi
    echo "APEX images: $ORDS_BASE_URL/i/apex_version.txt serves HTTP 200 (version $SERVED)."
  else
    echo "ERROR: $ORDS_CONTAINER is running but $ORDS_BASE_URL/i/apex_version.txt returned HTTP $CODE, not 200." >&2
    echo "       The files are in $DEST; ORDS may need 'standalone.static.path' set to" >&2
    echo "       /opt/oracle/apex/images and a container restart (see apex/README.md)." >&2
    exit 1
  fi
else
  echo "APEX images: $ORDS_CONTAINER not running — skipping the live /i/ 200 check."
fi
