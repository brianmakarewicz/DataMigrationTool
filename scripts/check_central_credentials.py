#!/usr/bin/env python3
"""
check_central_credentials.py -- conformance checker for the central Fusion user
(DMT_DESIGN.html section 6 "Credentials" and section 7 "One fact, one seeded home";
backlog #309, #430).

THE RULE
--------
Every Fusion call (loads, ESS, BIP, HDL, REST loads, the Verify-in-Fusion lookup,
the run preflight) gets its user and password TOGETHER from
DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS, which reads the per-object row of
DMT_ERP_INTERFACE_OPTIONS_TBL and falls back to the global
DMT_CONFIG_TBL FUSION_USERNAME / FUSION_PASSWORD. No other code reads a Fusion
credential on its own.

WHAT THIS CHECKS (committed files only -- no database, no Fusion)
-----------------------------------------------------------------
  CRED-RETIRED-KEY  The retired per-family config keys HCM_USERNAME, HCM_PASSWORD,
                    BIP_USERNAME, BIP_PASSWORD appear as a quoted literal ('KEY' or
                    "KEY") in non-comment code under db/ (except db/migrations),
                    apex/, scripts/ or test/. A read, a write and a seed row all
                    fail: the keys have no reader, so a new one would be a second
                    credential home that silently drifts from the options rows.
  CRED-BYPASS       Runtime code (db/packages, db/views, db/procedures, db/jobs,
                    db/types, db/lookup, apex/) names FUSION_USERNAME or
                    FUSION_PASSWORD -- as a config-key literal or as the options
                    table column -- outside the central utility's body
                    db/packages/dmt_util_pkg.pkb.sql. SQL '--' comments are ignored.

NOT CHECKED (declared so a green run stays honest)
--------------------------------------------------
  * db/migrations: historical, run once; a migration may legitimately delete a
    retired key.
  * Offline tools and tests (db/tools, scripts/, test/) for CRED-BYPASS: they set
    or read the global pair to configure a database or drive a unit test, not to
    make a pipeline Fusion call.
  * Credentials built from string concatenation of key fragments, or a key read
    through a variable holding the key name.

Exit 0 = PASS, 1 = a violation not listed in scripts/standards_known_violations.json.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import standards_known_violations as known  # noqa: E402

CHECKER = "check_central_credentials"
SELF = os.path.abspath(__file__)

RETIRED_KEYS = ("HCM_USERNAME", "HCM_PASSWORD", "BIP_USERNAME", "BIP_PASSWORD")
RETIRED_RE = re.compile(r"""['"](%s)['"]""" % "|".join(RETIRED_KEYS))
RETIRED_DIRS = ("db", "apex", "scripts", "test")
RETIRED_SKIP = (os.path.join("db", "migrations"),)

BYPASS_RE = re.compile(r"\b(FUSION_USERNAME|FUSION_PASSWORD)\b")
RUNTIME_DIRS = (os.path.join("db", d) for d in
                ("packages", "views", "procedures", "jobs", "types", "lookup"))
RUNTIME_DIRS = tuple(RUNTIME_DIRS) + ("apex",)
CENTRAL_UTILITY = os.path.join("db", "packages", "dmt_util_pkg.pkb.sql")

TEXT_EXT = (".sql", ".pks", ".pkb", ".py", ".apx", ".json", ".js", ".yml", ".yaml")


def walk(rel_dirs, skip=()):
    for rel in rel_dirs:
        base = os.path.join(ROOT, rel)
        for dirpath, dirnames, filenames in os.walk(base):
            relpath = os.path.relpath(dirpath, ROOT)
            if any(relpath == s or relpath.startswith(s + os.sep) for s in skip):
                dirnames[:] = []
                continue
            for fn in sorted(filenames):
                if fn.lower().endswith(TEXT_EXT):
                    full = os.path.join(dirpath, fn)
                    if os.path.abspath(full) != SELF:
                        yield full


def code_lines(path):
    """(line_no, code) with whole-line and trailing comments removed."""
    comment = "#" if path.endswith(".py") else "--"
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            stripped = line.lstrip()
            if stripped.startswith(comment):
                continue
            # Trailing comment: cut at the marker only when it is outside quotes.
            out, q = [], None
            i = 0
            while i < len(line):
                ch = line[i]
                if q:
                    if ch == q:
                        q = None
                elif ch in "'\"":
                    q = ch
                elif line.startswith(comment, i):
                    break
                out.append(ch)
                i += 1
            yield n, "".join(out)


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def main():
    print("Central Fusion credential conformance check (backlog #309, #430)")
    print("=" * 76)
    found = []  # (key, message)

    for path in walk(RETIRED_DIRS, RETIRED_SKIP):
        for n, code in code_lines(path):
            for m in RETIRED_RE.finditer(code):
                key = "CRED-RETIRED-KEY|%s|%s" % (rel(path), m.group(1))
                found.append((key, "%s:%d retired credential key %s -- use "
                              "DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS"
                              % (rel(path), n, m.group(1))))

    central = os.path.join(ROOT, CENTRAL_UTILITY)
    for path in walk(RUNTIME_DIRS):
        if os.path.abspath(path) == os.path.abspath(central):
            continue
        for n, code in code_lines(path):
            for m in BYPASS_RE.finditer(code):
                key = "CRED-BYPASS|%s|%s" % (rel(path), m.group(1))
                found.append((key, "%s:%d reads %s outside the central utility -- "
                              "use DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS"
                              % (rel(path), n, m.group(1))))

    # One message per key (a file may name the same key on several lines).
    by_key = {}
    for key, msg in found:
        by_key.setdefault(key, []).append(msg)
    rc = known.report(CHECKER, [(k, "; ".join(v)) for k, v in sorted(by_key.items())])
    print("=" * 76)
    if rc:
        print("RESULT: FAIL -- new credential-bypass violation(s). Resolve the "
              "Fusion user and password together through "
              "DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS (DMT_ERP_INTERFACE_OPTIONS_TBL).")
        return 1
    print("RESULT: PASS -- no retired credential key and no direct Fusion "
          "credential read outside DMT_UTIL_PKG.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
