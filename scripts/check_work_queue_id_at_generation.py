#!/usr/bin/env python3
"""check_work_queue_id_at_generation.py -- conformance checker for the owner decision of
2026-10-11 (backlog #777): every ERP object records WORK_QUEUE_ID on its TFM rows at FBDI
file generation, one way everywhere, and its reconciler scopes by that work item.

THE RULE (DMT_DESIGN.html section 7, "The work queue item is the unit of processing", and
its 2026-10-11 amendment "WORK_QUEUE_ID is stamped at FBDI generation")
---------------------------------------------------------------------------------------
The FBDI generator stamps WORK_QUEUE_ID = DMT_LOADER_PKG.g_gen_queue_id in the same UPDATE
that marks the rows GENERATED (the rows that went into the file), and nowhere else. The
transform never writes WORK_QUEUE_ID. The reconciler's Contract v1 apply scopes every
UPDATE with (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id).

WHAT IS CHECKED (statically, committed files only)
--------------------------------------------------
1. WQ-GEN-FLIP|<pkg>|<table>: every UPDATE in a db/packages/*_fbdi_gen_pkg.pkb.sql whose
   SET clause writes TFM_STATUS = 'GENERATED' also writes
   WORK_QUEUE_ID = DMT_LOADER_PKG.g_gen_queue_id.
2. WQ-GEN-ONE-WAY|<pkg>|<table>: a generator writes WORK_QUEUE_ID only in such a
   GENERATED UPDATE, and only from g_gen_queue_id (no pre-stamp, no g_work_queue_id).
3. WQ-GEN-COVER|<CEMLI>|<table>: every TFM table that db/seed/dmt_cemli_catalog_tbl.sql
   registers to an ERP object (pipelines P2P, O2C, PROJECTS, FINANCIALS in
   db/seed/dmt_pipeline_def_tbl.sql) is marked GENERATED, with the stamp, by some generator.
4. WQ-NO-TRANSFORM-STAMP|<pkg>: no db/packages/*_transform_pkg.pkb.sql writes the
   WORK_QUEUE_ID column.
5. WQ-RECON-SCOPE|<pkg>|<line-key>: every UPDATE inside the APPLY_CONTRACT_V1* procedure of
   an ERP object's registered reconciler (RECON_PROC in the pipeline seed) carries
   WORK_QUEUE_ID = p_work_queue_id in its WHERE clause.

NOT CHECKED (printed every run, per the "checker fidelity" rule): HCM (HDL) and
configuration objects (deferred by the owner, backlog #778); whether the queue item that
generated a row is the one RECONCILE_ONE later passes (proven by the regression); and the
reconcilers' other UPDATE procedures (PROPAGATE_DOCUMENT_ERRORS, RESET_UNACCOUNTED and the
legacy report-parsing paths), which keep their current scoping.

Violations that existed when the rule was introduced would be listed in
scripts/standards_known_violations.json (checker "check_work_queue_id_at_generation");
there were none. Only a NEW violation fails.

Exit codes: 0 = no new violations, 1 = new violations, 2 = inputs not found.
"""

import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import standards_known_violations as skv  # noqa: E402

CHECKER = "check_work_queue_id_at_generation"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CATALOG = os.path.join(REPO, "db", "seed", "dmt_cemli_catalog_tbl.sql")
PIPELINE = os.path.join(REPO, "db", "seed", "dmt_pipeline_def_tbl.sql")
PKG_DIR = os.path.join(REPO, "db", "packages")
ERP_PIPELINES = {"P2P", "O2C", "PROJECTS", "FINANCIALS"}

UPDATE_RE = re.compile(r"\bUPDATE\s+(DMT_[A-Z0-9_]+_TFM_TBL)\b(?:\s+\w+)?\s+SET\b(.*?)\bWHERE\b(.*?);",
                       re.I | re.S)
GENERATED_RE = re.compile(r"\bTFM_STATUS\s*=\s*'GENERATED'", re.I)
STAMP_RE = re.compile(r"\bWORK_QUEUE_ID\s*=\s*DMT_LOADER_PKG\.g_gen_queue_id\b", re.I)
WQ_ASSIGN_RE = re.compile(r"\bWORK_QUEUE_ID\s*=", re.I)
RECON_SCOPE_RE = re.compile(r"\bWORK_QUEUE_ID\s*=\s*p_work_queue_id\b", re.I)


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def erp_objects():
    """Return {cemli: recon_proc_or_None} for the ERP pipelines' objects."""
    text = read(PIPELINE)
    members = {}
    for m in re.finditer(r"select\s+'([A-Z0-9]+)'(?:\s+pipeline_code)?,\s*\d+(?:\s+sort_order)?,\s*'([A-Za-z0-9]+)'",
                         text, re.I):
        members[m.group(2)] = m.group(1).upper()
    erp = {c for c, p in members.items() if p in ERP_PIPELINES}
    recon = {}
    for m in re.finditer(r"select\s+'([A-Za-z0-9]+)'(?:\s+cemli_code)?,\s*(?:'[^']*'|null)(?:\s+exec_proc)?,"
                         r"\s*'[A-Z]+'(?:\s+exec_mode)?,\s*('([A-Z0-9_.]+)'|null)", text, re.I):
        recon[m.group(1)] = m.group(3)
    return {c: recon.get(c) for c in erp}


def catalog_tables():
    out = {}
    for m in re.finditer(r"select\s+'([^']+)'(?:\s+cemli_code)?,\s*'[^']*'(?:\s+display_name)?,\s*'(DMT_[A-Z0-9_]+)'",
                         read(CATALOG), re.I):
        out.setdefault(m.group(1), set()).add(m.group(2).upper())
    return out


def apply_procedures(text):
    """Yield (name, body) for each top-level APPLY_CONTRACT_V1* procedure."""
    for m in re.finditer(r"^    PROCEDURE\s+(APPLY_CONTRACT_V1[A-Za-z0-9_]*)\b", text, re.M | re.I):
        name = m.group(1)
        end = re.search(r"^    END\s+%s\s*;" % re.escape(name), text[m.end():], re.M | re.I)
        if end:
            yield name, text[m.start():m.end() + end.end()]


def main():
    print("WORK_QUEUE_ID is stamped at FBDI generation; reconcilers scope by work item (#777)")
    print("=" * 80)
    for p in (CATALOG, PIPELINE, PKG_DIR):
        if not os.path.exists(p):
            print("ERROR: input not found: " + p)
            return 2
    found = []
    stamped_tables = set()

    gens = sorted(glob.glob(os.path.join(PKG_DIR, "*_fbdi_gen_pkg.pkb.sql")))
    for path in gens:
        pkg = os.path.basename(path).split(".")[0].upper()
        text = strip_comments(read(path))
        flips = 0
        for m in UPDATE_RE.finditer(text):
            table, setc = m.group(1).upper(), m.group(2)
            generated = bool(GENERATED_RE.search(setc))
            if generated:
                flips += 1
                if STAMP_RE.search(setc):
                    stamped_tables.add(table)
                else:
                    found.append(("WQ-GEN-FLIP|%s|%s" % (pkg, table),
                                  "%s marks %s GENERATED without WORK_QUEUE_ID = "
                                  "DMT_LOADER_PKG.g_gen_queue_id" % (pkg, table)))
            elif WQ_ASSIGN_RE.search(setc):
                found.append(("WQ-GEN-ONE-WAY|%s|%s" % (pkg, table),
                              "%s writes WORK_QUEUE_ID on %s outside the UPDATE that marks the "
                              "rows GENERATED" % (pkg, table)))
            if generated and re.search(r"WORK_QUEUE_ID\s*=\s*DMT_LOADER_PKG\.g_work_queue_id", setc, re.I):
                found.append(("WQ-GEN-ONE-WAY|%s|%s" % (pkg, table),
                              "%s stamps %s from g_work_queue_id, not g_gen_queue_id" % (pkg, table)))
        print("  %s  %-44s %d GENERATED update%s"
              % ("PASS" if not any(k.split("|")[1] == pkg for k, _ in found) else "FAIL",
                 pkg, flips, "" if flips == 1 else "s"))

    erp = erp_objects()
    catalog = catalog_tables()
    print("\nERP record types covered by a stamping generator:")
    for cemli in sorted(erp):
        tables = sorted(catalog.get(cemli, set()))
        if not tables:
            print("  SKIP  %-24s (no TFM table in the catalog)" % cemli)
            continue
        missing = [t for t in tables if t not in stamped_tables]
        for t in missing:
            found.append(("WQ-GEN-COVER|%s|%s" % (cemli, t),
                          "no FBDI generator marks %s (%s) GENERATED with the WORK_QUEUE_ID stamp"
                          % (t, cemli)))
        print("  %s  %-24s %d record type%s"
              % ("MISS" if missing else "PASS", cemli, len(tables), "" if len(tables) == 1 else "s"))

    print("\nTransforms do not write WORK_QUEUE_ID:")
    bad = 0
    for path in sorted(glob.glob(os.path.join(PKG_DIR, "*_transform_pkg.pkb.sql"))):
        pkg = os.path.basename(path).split(".")[0].upper()
        if re.search(r"\bWORK_QUEUE_ID\b", strip_comments(read(path)), re.I):
            bad += 1
            found.append(("WQ-NO-TRANSFORM-STAMP|%s" % pkg,
                          "%s writes WORK_QUEUE_ID; it is stamped only at FBDI generation" % pkg))
    print("  %s  %d transform package%s write it" % ("PASS" if not bad else "FAIL", bad,
                                                     "" if bad == 1 else "s"))

    print("\nERP reconcilers' Contract v1 apply is scoped by work item:")
    for cemli in sorted(erp):
        proc = erp[cemli]
        if not proc:
            print("  SKIP  %-24s (no RECON_PROC registered)" % cemli)
            continue
        pkg = proc.split(".")[0]
        path = os.path.join(PKG_DIR, pkg.lower() + ".pkb.sql")
        if not os.path.exists(path):
            print("  SKIP  %-24s (%s not found)" % (cemli, pkg))
            continue
        text = strip_comments(read(path))
        procs = list(apply_procedures(text))
        if not procs:
            print("  SKIP  %-24s %s has no APPLY_CONTRACT_V1 procedure" % (cemli, pkg))
            continue
        n = miss = 0
        for name, body in procs:
            for i, m in enumerate(UPDATE_RE.finditer(body), 1):
                n += 1
                if not RECON_SCOPE_RE.search(m.group(3)):
                    miss += 1
                    found.append(("WQ-RECON-SCOPE|%s|%s#%d" % (pkg, name, i),
                                  "%s.%s UPDATE #%d of %s is not scoped by "
                                  "WORK_QUEUE_ID = p_work_queue_id" % (pkg, name, i, m.group(1))))
        print("  %s  %-24s %s: %d of %d UPDATEs scoped"
              % ("PASS" if not miss else "FAIL", cemli, pkg, n - miss, n))

    print("\nNot checked: HCM (HDL) and configuration objects (deferred, backlog #778); that the "
          "item which generated a row is the one RECONCILE_ONE passes (proven by the regression); "
          "the reconcilers' non-Contract-v1 UPDATE procedures.")
    return skv.report(CHECKER, found)


if __name__ == "__main__":
    sys.exit(main())
