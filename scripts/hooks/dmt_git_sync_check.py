#!/usr/bin/env python3
"""SessionStart guard for DMT2 — warns (never blocks) when the local working copy
has drifted from origin/main, so a stale/dirty tree is caught on day one instead of
rotting for a week (see the 2026-07-22 incident).

Checks the DMT2 repo:
  1. current branch is not `main`
  2. working tree has uncommitted TRACKED changes
  3. local `main` is behind `origin/main`

Prints a concise warning to stdout (added to the session context). Always exits 0 —
this is advisory only. Fast and offline-safe: the fetch is time-boxed and failure is
non-fatal.
"""
import subprocess
import sys

REPO = r"C:\Users\Monroe\workspace\DMT2"
FETCH_TIMEOUT = 12  # seconds — keep session start snappy


def git(*args, timeout=8):
    """Run a git command in REPO. Returns (rc, stdout) or (None, '') on error/timeout."""
    try:
        p = subprocess.run(
            ["git", "-C", REPO, *args],
            capture_output=True, text=True, timeout=timeout,
        )
        return p.returncode, p.stdout.strip()
    except Exception:
        return None, ""


def main():
    # Bail silently if this isn't a git repo (e.g. running from a machine without DMT2).
    rc, _ = git("rev-parse", "--is-inside-work-tree")
    if rc != 0:
        sys.exit(0)

    # Refresh origin/main; ignore failure (offline is fine — we still check local state).
    git("fetch", "origin", "main", "--quiet", timeout=FETCH_TIMEOUT)

    warnings = []

    _, branch = git("rev-parse", "--abbrev-ref", "HEAD")
    if branch and branch != "main":
        warnings.append(f"- On branch `{branch}`, not `main`.")

    _, porcelain = git("status", "--porcelain", "--untracked-files=no")
    if porcelain:
        n = len(porcelain.splitlines())
        warnings.append(f"- Working tree has {n} uncommitted TRACKED change(s) -- commit to a branch or discard.")

    _, behind = git("rev-list", "--count", "main..origin/main")
    if behind and behind.isdigit() and int(behind) > 0:
        warnings.append(f"- Local `main` is {behind} commit(s) BEHIND `origin/main` -- fast-forward before working.")

    if warnings:
        print("DMT2 GIT SYNC WARNING -- the working copy has drifted:")
        print("\n".join(warnings))
        print("Fix first: `git checkout main && git fetch && git merge --ff-only origin/main`, "
              "then confirm a clean tree before starting new work. "
              "(Snapshot any wanted drift to a .patch before discarding.)")

    sys.exit(0)


if __name__ == "__main__":
    main()
