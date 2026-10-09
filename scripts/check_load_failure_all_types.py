#!/usr/bin/env python3
"""check_load_failure_all_types.py -- conformance checker for failure shape (d) of the
cross-grain checklist (DMT_DESIGN.html section 5, "Cross-grain failure shapes every
object must handle", added 2026-10-09 with backlog #633 / #672).

THE RULE
--------
One object = one FBDI zip = one load ESS job. When that load fails at job level and the
loader writes the synchronous [LOAD_ERROR] (design section 5, ERROR_TEXT tag table:
"every GENERATED row of that ZIP is marked FAILED"), EVERY record type of the object
must be marked -- not only the header table. A record type the load-failure path
forgets is left GENERATED and ends UNACCOUNTED although its whole zip failed with a
known error (MiscReceipts lots and serials before backlog #633).

WHAT IS CHECKED (statically, committed files only)
--------------------------------------------------
1. The object's record types are its TFM tables in db/seed/dmt_cemli_catalog_tbl.sql
   (the registry is the truth for an object's structure).
2. Every load-failure path in db/packages/dmt_loader_pkg.pkb.sql is found:
     a. a helper procedure that builds a [LOAD_ERROR] text and branches on
        p_cemli_code = '<CEMLI>' (sup_mark_generated_failed, po_mark_bu_failed,
        fin_mark_generated_failed, ...): each branch is one path for that CEMLI;
     b. a RUN_<object> procedure (C_CEMLI constant) whose body writes a [LOAD_ERROR]
        literal itself: the procedure is one path for its CEMLI.
3. The TFM tables a path marks are the targets of its UPDATE ... TFM_STATUS = 'FAILED'
   statements (including a nested mark_batch_failed procedure), plus the tables marked
   by any <PKG>.FAIL_GENERATED_ROWS procedure the path calls (resolved from that
   package body, so an object package may own the marking -- the MiscReceipts shape).
4. A path that misses any registered TFM table of its CEMLI is a violation:
       LOADFAIL-ALL-TYPES|<CEMLI>|<path>     (message names the missing tables)

NOT CHECKED (printed every run, per the "checker fidelity" rule): whether each UPDATE is
scoped to exactly the failed zip's rows (partition / batch predicates), and load-failure
paths outside DMT_LOADER_PKG (the asynchronous queue-worker paths no longer write
[LOAD_ERROR]; they leave rows GENERATED for reconciliation and the shared unaccounted
sweep, which covers every catalog table).

Violations that existed when the rule was introduced are listed in
scripts/standards_known_violations.json (checker "check_load_failure_all_types"), each
tied to the backlog item that fixes it; only a NEW violation fails.

Exit codes: 0 = no new violations, 1 = new violations, 2 = inputs not found.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import standards_known_violations as skv  # noqa: E402

CHECKER = "check_load_failure_all_types"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CATALOG = os.path.join(REPO, "db", "seed", "dmt_cemli_catalog_tbl.sql")
PKG_DIR = os.path.join(REPO, "db", "packages")
LOADER = os.path.join(PKG_DIR, "dmt_loader_pkg.pkb.sql")

UPDATE_FAILED_RE = re.compile(
    r"UPDATE\s+(DMT_[A-Z0-9_]+_TFM_TBL)\b[^;]*?\bTFM_STATUS\s*=\s*'FAILED'", re.I | re.S)
FAIL_CALL_RE = re.compile(r"\b(DMT_[A-Z0-9_]+_PKG)\.FAIL_GENERATED_ROWS\b", re.I)
LOAD_ERROR_RE = re.compile(r"'\[LOAD_ERROR\]")
CEMLI_BRANCH_RE = re.compile(r"\b(?:ELSIF|IF)\s+p_cemli_code\s*=\s*'([A-Za-z0-9]+)'\s+THEN", re.I)


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def catalog_tables():
    with open(CATALOG, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    out = {}
    for m in re.finditer(r"select\s+'([^']+)',\s*'[^']*',\s*'(DMT_[A-Z0-9_]+)'", text, re.I):
        out.setdefault(m.group(1), set()).add(m.group(2).upper())
    return out


def top_level_procedures(text):
    """Yield (name, body) for each top-level PROCEDURE ... END name; of a package body."""
    for m in re.finditer(r"^    PROCEDURE\s+([A-Za-z0-9_]+)\b", text, re.M):
        name = m.group(1)
        end = re.search(r"^    END\s+%s\s*;" % re.escape(name), text[m.end():], re.M | re.I)
        if not end:
            continue
        yield name, text[m.start():m.end() + end.end()]


def procedure_body(path, proc):
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = strip_comments(fh.read())
    for name, body in top_level_procedures(text):
        if name.upper() == proc.upper():
            return body
    return ""


def marked_tables(body):
    tables = {m.group(1).upper() for m in UPDATE_FAILED_RE.finditer(body)}
    for m in FAIL_CALL_RE.finditer(body):
        pkg_file = os.path.join(PKG_DIR, m.group(1).lower() + ".pkb.sql")
        if os.path.exists(pkg_file):
            tables |= {t.group(1).upper() for t in
                       UPDATE_FAILED_RE.finditer(procedure_body(pkg_file, "FAIL_GENERATED_ROWS"))}
    return tables


def load_failure_paths(text):
    """Return a list of (cemli, path_name, marked_tables)."""
    paths = []
    for name, body in top_level_procedures(text):
        if not LOAD_ERROR_RE.search(body) and not FAIL_CALL_RE.search(body):
            continue
        branches = list(CEMLI_BRANCH_RE.finditer(body))
        if branches:
            for i, b in enumerate(branches):
                end = branches[i + 1].start() if i + 1 < len(branches) else len(body)
                paths.append((b.group(1), name, marked_tables(body[b.end():end])))
            continue
        c = re.search(r"\bC_CEMLI\s+CONSTANT\s+VARCHAR2\(\d+\)\s*:=\s*'([A-Za-z0-9]+)'", body, re.I)
        if c:
            paths.append((c.group(1), name, marked_tables(body)))
    return paths


def main():
    print("Load-failure path reaches every record type (cross-grain failure shape (d))")
    print("=" * 76)
    if not (os.path.exists(CATALOG) and os.path.exists(LOADER)):
        print("ERROR: catalog seed or loader body not found")
        return 2
    catalog = catalog_tables()
    with open(LOADER, encoding="utf-8", errors="replace") as fh:
        loader = strip_comments(fh.read())
    paths = load_failure_paths(loader)
    if not paths:
        print("ERROR: no [LOAD_ERROR] path found in " + LOADER)
        return 2
    found = []
    for cemli, pname, tables in sorted(paths):
        expected = catalog.get(cemli)
        if not expected:
            print("  SKIP  %-24s %s (no catalog row)" % (cemli, pname))
            continue
        missing = sorted(expected - tables)
        if missing:
            print("  MISS  %-24s %s -- leaves GENERATED: %s" % (cemli, pname, ", ".join(missing)))
            found.append(("LOADFAIL-ALL-TYPES|%s|%s" % (cemli, pname),
                          "%s load-failure path in %s does not mark %s"
                          % (cemli, pname, ", ".join(missing))))
        else:
            print("  PASS  %-24s %s (%d record type%s)"
                  % (cemli, pname, len(expected), "" if len(expected) == 1 else "s"))
    print("\nNot checked: row scoping of each UPDATE to the failed zip (partition / batch "
          "predicates), and load-failure handling outside DMT_LOADER_PKG.")
    return skv.report(CHECKER, found)


if __name__ == "__main__":
    sys.exit(main())
