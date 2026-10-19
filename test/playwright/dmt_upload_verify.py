#!/usr/bin/env python
"""
dmt_upload_verify.py - upload test through the Smart Upload page (backlog #786).

An object is "ready for functional testing" when it passes in the header run AND
(passes in the FBDI run, or the FBDI format does not apply to it):
  1. header format: the object's source CSVs, with our column headers (one
     DMT_<TABLE>_STG_TBL.csv per staging table, columns named as in
     DMT_UPLOAD_DICT_TBL), upload through page 25 (Smart Upload);
  2. FBDI format: the object's Oracle FBDI files (headerless CSVs named per
     DMT_UPLOAD_OBJECT_TBL.FBDI_CSV_FILENAME, one value per FBDI slot) upload
     through the same page (not applicable to HCM/HDL objects or to objects with
     no or only part of an FBDI mapping);
  3. the uploaded data, run through the pipeline into Fusion, ends with every
     GOOD row LOADED with its own Fusion id, every BAD row FAILED with a real
     error, and nothing unaccounted.

Design (owner decision 2026-10-19): it mirrors the regression. Per format there
is ONE scenario, ONE zip upload and ONE run:
  a. read every in-scope object's rows (and its upstream objects' rows,
     DMT_PIPELINE_DEF_TBL.DEPENDS_ON followed transitively) from the current
     regression baseline scenario (scripts/regression_scenario.json) on the
     target, read-only, and write ONE zip holding every staging table's file in
     the format under test (a staging table shared by several objects, such as
     the PO tables, is one file holding all their rows);
  b. a real browser (test/playwright/dmt_upload_verify.js): page 14 creates the
     scenario UPL-HDR-<yymmddHHMM> or UPL-FBDI-<yymmddHHMM>, page 25 uploads the
     zip once in "Auto-detect by Filename" mode. Page 25 sends a whole zip down
     one path (header or FBDI) by its first recognised file name, which is why
     there are two zips; the mixed-format loader (UPLOAD_ZIP_AUTO) is not wired
     to the page;
  c. check staging per file: the scenario holds exactly the file's rows, every
     written value came through unchanged, and DMT_UPLOAD_ERROR_TBL has no row;
  d. sync the prefix (scripts/ci_promote.py sync_prefix_for), submit ONE run for
     the scenario with DMT_SCHEDULER_PKG.SUBMIT_PIPELINE for every pipeline the
     objects belong to, exactly as the regression submits
     (scripts/dmt_regression_run.py submit_run), wait (its wait_for_run) and
     check the prefix is not used on the other instance (assert_prefix_unique).
     The run is tagged UPLOAD_VERIFY, not REGRESSION_AGENT;
  e. judge every uploaded row per object from DMT_RECORD_DETAIL_V. GOOD and BAD
     come from the regression's own classification of the same source row in
     the baseline regression run, so the test expects exactly what the
     regression expects. An object whose own file did not stage fails; a
     failure in one object never holds the others back.

Negative tests (--negative, owner addition 2026-10-19; test and report only):
  1. mixed rows: correctly named files for Suppliers, APInvoices and Projects
     (plus their upstream objects) carrying good rows and, per file, one row
     with text in a number column, one with an over-length value and one with an
     unparseable date. Expected: the good rows stage, each bad row is in
     DMT_UPLOAD_ERROR_TBL with a readable error (the Oracle error, or for a bad
     date the loader's own message naming the line and column), the file's log says
     COMPLETED_WITH_ERRORS; then the scenario is run and the staged rows are
     judged with the normal pass rule;
  2. wrong layout: a file named for Suppliers that carries the Projects
     columns (header), or the Suppliers FBDI file with its slots shifted
     (FBDI). Expected: nothing stages and the rejection is visible;
  3. the page message: a file that failed, or partly failed, must not be shown
     as plain success (backlog #788).

Usage:
  python test/playwright/dmt_upload_verify.py --target atp --formats header,fbdi \
      --json-out docs/findings/upload_verify_<stamp>.json [--md-out <path>]
  python test/playwright/dmt_upload_verify.py --target atp --negative --json-out <path> [--md-out <path>]
  Add --upload-only to stop after the staging check; --resume to continue a
  --json-out file whose upload or run was interrupted (an uploaded scenario is
  reused, a submitted run is waited for again; nothing is uploaded or run twice).
  --objects narrows the zip to some objects (and their upstream objects).

The JSON file is rewritten after every step, so a long run can be watched and
resumed. Exit codes: 0 = every applicable verdict PASS, 1 = any FAIL, 2 = setup.
Credentials: the DB through scripts/ci_promote.py (connections.json); the
console user through scripts/dmt_apex_url_target.py. Nothing is hardcoded.
"""
import argparse
import csv
import datetime
import decimal
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
SCRIPTS = os.path.join(REPO, "scripts")
sys.path.insert(0, SCRIPTS)
sys.path.insert(0, os.path.join(REPO, "test", "upload_samples"))

import oracledb  # noqa: E402
import ci_promote as cp  # noqa: E402  prefix sync, DB connections, console URL
import dmt_apex_url_target as urltarget  # noqa: E402  the one URL knob
from fbdi_column_maps import MAPS as FBDI_MAPS  # noqa: E402  committed FBDI slot layout

oracledb.defaults.fetch_lobs = False
oracledb.defaults.fetch_decimals = True

JS = os.path.join(HERE, "dmt_upload_verify.js")
PW_NODE_MODULES = os.environ.get(
    "DMT2_PW_NODE_MODULES", r"C:\Users\Monroe\workspace\fusion-config-migrator\node_modules")

# The 27 objects that pass the regression's good/bad test (owner list, 2026-10-19).
IN_SCOPE = ["Items", "Suppliers", "SupplierAddresses", "SupplierSites", "SupplierSiteAssignments",
            "SupplierContacts", "Requisitions", "PurchaseOrders", "BlanketPOs", "Contracts",
            "APInvoices", "MiscReceipts", "Customers", "ARInvoices", "GLBalances", "GLBudgets",
            "Assets", "Projects", "BillingEvents", "Expenditures", "Grants", "ProjectBudgets",
            "Workers", "Salaries", "SalaryBases", "Absences", "TalentProfiles"]
# Objects with no Oracle FBDI file mapping in the tool (owner list, 2026-10-19).
NO_FBDI_MAPPING = {"BlanketPOs", "Contracts", "MiscReceipts", "Assets"}
HDL_PIPELINE = "HCM"
PIPELINE_ORDER = ["P2P", "O2C", "FINANCIALS", "PROJECTS", "HCM"]   # the regression's set and order

# Negative tests: the objects whose files get bad rows, and the wrong-layout pair.
NEG_OBJECTS = ["Suppliers", "APInvoices", "Projects"]
NEG_TABLES = ["DMT_POZ_SUPPLIERS_STG_TBL", "DMT_AP_INVOICES_INT_STG_TBL", "DMT_PJF_PROJECTS_STG_TBL"]
LAYOUT_TARGET, LAYOUT_SOURCE = "DMT_POZ_SUPPLIERS_STG_TBL", "DMT_PJF_PROJECTS_STG_TBL"
FBDI_SHIFT = 3          # empty slots put in front of every row of the wrong-layout FBDI file

DOC_ERROR_MARKER = "Rejected with document:"
_IDENT = re.compile(r"^[A-Z][A-Z0-9_$#]{0,127}$")


def log(msg):
    print(f"[{datetime.datetime.now():%H:%M:%S}] {msg}", flush=True)


def ident(name):
    """A table/column name read from the registry, checked before it goes into SQL."""
    if not name or not _IDENT.match(name):
        raise SystemExit(f"refusing unsafe identifier {name!r}")
    return name


def fmt(v):
    """One value as text, the same way for the file and for the staged read-back."""
    if v is None:
        return ""
    if isinstance(v, datetime.datetime):
        if v.microsecond:
            return v.strftime("%Y/%m/%d %H:%M:%S.%f")
        if v.hour or v.minute or v.second:
            return v.strftime("%Y/%m/%d %H:%M:%S")
        return v.strftime("%Y/%m/%d")
    if isinstance(v, datetime.date):
        return v.strftime("%Y/%m/%d")
    if isinstance(v, decimal.Decimal):
        s = format(v, "f")
        return s.rstrip("0").rstrip(".") if "." in s else s
    return str(v)


def oneline(x, n=300):
    return " ".join(str(x or "").split())[:n]


# ---------------------------------------------------------------- registry
class Registry:
    """Everything the test reads from the target's seed registries (read-only)."""

    def __init__(self, cur):
        cur.execute("""SELECT c.CEMLI_CODE, c.DISPLAY_NAME, c.TFM_TABLE, c.ROW_FILTER, c.SORT_ORDER
                       FROM DMT_CEMLI_CATALOG_TBL c WHERE c.TFM_TABLE IS NOT NULL
                       ORDER BY c.CEMLI_CODE, c.SORT_ORDER""")
        self.tables = {}          # cemli -> [{sub, tfm, stg, filter}]
        self.sub_stg = {}         # (cemli, sub) -> stg
        for cemli, sub, tfm, flt, _so in cur.fetchall():
            stg = ident(tfm.replace("_TFM_TBL", "_STG_TBL"))
            self.tables.setdefault(cemli, []).append({"sub": sub, "tfm": tfm, "stg": stg, "filter": flt})
            self.sub_stg[(cemli, sub)] = stg
        cur.execute("""SELECT CEMLI_CODE, PIPELINE_CODE, SORT_ORDER, DEPENDS_ON
                       FROM DMT_PIPELINE_DEF_TBL""")
        self.pipe = {r[0]: {"pipeline": r[1], "sort": r[2], "depends": r[3]} for r in cur.fetchall()}
        cur.execute("""SELECT STAGING_TABLE, OBJECT_CODE, CSV_FILENAME, FBDI_CSV_FILENAME, DISPLAY_ORDER
                       FROM DMT_UPLOAD_OBJECT_TBL WHERE IS_ACTIVE = 'Y'""")
        self.upload = {r[0]: {"object_code": r[1], "csv": r[2], "fbdi": r[3], "order": r[4]}
                       for r in cur.fetchall()}
        cur.execute("""SELECT OBJECT_CODE, COLUMN_NAME, FBDI_POSITION FROM DMT_UPLOAD_DICT_TBL
                       WHERE IS_ADMIN_COLUMN = 'N' ORDER BY OBJECT_CODE, COLUMN_ORDER""")
        self.dict_cols, self.dict_fbdi = {}, {}
        for oc, col, pos in cur.fetchall():
            self.dict_cols.setdefault(oc, []).append(col)
            if pos is not None:
                self.dict_fbdi[oc] = self.dict_fbdi.get(oc, 0) + 1

    def order(self, objects):
        return sorted(set(objects), key=lambda o: (PIPELINE_ORDER.index(self.pipe[o]["pipeline"])
                                                   if self.pipe[o]["pipeline"] in PIPELINE_ORDER else 99,
                                                   self.pipe[o]["sort"]))

    def closure(self, obj):
        """The object plus every object it depends on (DEPENDS_ON, transitively),
        in pipeline order: the minimum set that can load in one run."""
        seen, todo = set(), [obj]
        while todo:
            o = todo.pop()
            if o in seen:
                continue
            seen.add(o)
            deps = (self.pipe.get(o) or {}).get("depends") or ""
            todo += [d.strip() for d in deps.split(",") if d.strip()]
        return self.order(seen)


# ---------------------------------------------------------------- source rows
def stg_columns(cur, stg):
    cur.execute("SELECT COLUMN_NAME FROM USER_TAB_COLUMNS WHERE TABLE_NAME = :t ORDER BY COLUMN_ID", t=stg)
    return [r[0] for r in cur.fetchall()]


def stg_types(cur, stg):
    """{column: (data_type, char_length)} of a staging table."""
    cur.execute("SELECT COLUMN_NAME, DATA_TYPE, CHAR_LENGTH FROM USER_TAB_COLUMNS WHERE TABLE_NAME = :t",
                t=stg)
    return {c: (t, int(n or 0)) for c, t, n in cur.fetchall()}


def source_rows(cur, reg, cemli, scenario_id):
    """{stg: [row dict]} - the object's rows in the baseline scenario. A staging
    table shared by several objects (PO headers/lines for PurchaseOrders,
    BlanketPOs, Contracts) is narrowed by the catalog ROW_FILTER, read against
    the staging tables instead of the transform tables."""
    out = {}
    for t in reg.tables.get(cemli, []):
        stg = t["stg"]
        cols = stg_columns(cur, stg)
        where = "SCENARIO_ID = :s"
        if t["filter"]:
            where += " AND (" + t["filter"].replace("_TFM_TBL", "_STG_TBL") + ")"
        cur.execute(f"SELECT {', '.join(cols)} FROM {stg} WHERE {where} ORDER BY STG_SEQUENCE_ID",
                    s=scenario_id)
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        if rows:
            out.setdefault(stg, [])
            have = {r["STG_SEQUENCE_ID"] for r in out[stg]}
            out[stg] += [r for r in rows if r["STG_SEQUENCE_ID"] not in have]
    return out


# ---------------------------------------------------------------- file builders
ADMIN_COLS = {"STG_SEQUENCE_ID", "STAGE_DATE", "STG_STATUS", "ERROR_TEXT", "LAST_UPDATED_DATE",
              "SCENARIO_ID", "CREATED_BY", "CREATED_DATE", "LAST_UPDATED_BY"}


def header_layout(reg, stg, rows):
    """Columns of one header CSV: SOURCE_ID first (the dictionary marks it admin,
    but the loader honours a SOURCE_ID header - DMT_UPLOAD_DICT_PKG), then every
    dictionary column that holds data in any row, in dictionary order.
    Returns (file name, columns, notes)."""
    up = reg.upload[stg]
    dict_cols = (["SOURCE_ID"] if "SOURCE_ID" in rows[0] else []) + reg.dict_cols.get(up["object_code"], [])
    present = [c for c in dict_cols if c in rows[0]]
    cols = [c for c in present if c == "SOURCE_ID" or any(r.get(c) is not None for r in rows)]
    lost = sorted(c for c in rows[0] if c not in dict_cols and c not in ADMIN_COLS
                  and any(r.get(c) is not None for r in rows))
    notes = [f"populated columns not in the upload dictionary (cannot be uploaded): {', '.join(lost)}"] if lost else []
    return up["csv"], cols, notes


def fbdi_layout(reg, stg, rows):
    """Slots of one FBDI CSV, headerless, as laid out in the committed FBDI map
    (test/upload_samples/fbdi_column_maps.py, the source of
    db/seed/dmt_upload_fbdi_metadata.sql). Returns (file name, slots, columns, notes)."""
    up = reg.upload[stg]
    fname, colmap = FBDI_MAPS[up["object_code"]]
    slots = [c if (c and c in rows[0]) else None for c in colmap]
    cols = [c for c in slots if c]
    lost = sorted(c for c in rows[0] if c not in cols and c not in ADMIN_COLS
                  and any(r.get(c) is not None for r in rows))
    notes = [f"populated columns the FBDI file has no slot for (not carried): {', '.join(lost)}"] if lost else []
    return fname, slots, cols, notes


def render(fmt_name, cols_or_slots, rows, raw_rows=()):
    """The CSV bytes. rows are source rows (formatted with fmt); raw_rows are
    {column: text} rows written as given (the negative tests' bad rows)."""
    buf = io.StringIO()
    if fmt_name == "header":
        w = csv.writer(buf, lineterminator="\r\n")
        w.writerow(cols_or_slots)
    else:
        w = csv.writer(buf, lineterminator="\r\n", quoting=csv.QUOTE_ALL)
    for r in rows:
        w.writerow([fmt(r.get(c)) if c else "" for c in cols_or_slots])
    for r in raw_rows:
        w.writerow([r.get(c, "") if c else "" for c in cols_or_slots])
    return buf.getvalue().encode("utf-8")


def fbdi_applicability(reg, obj, objects, src):
    """None when the FBDI format applies, else the reason it does not."""
    if reg.pipe[obj]["pipeline"] == HDL_PIPELINE:
        return "not applicable: HCM object loaded by HCM Data Loader, no FBDI file"
    if obj in NO_FBDI_MAPPING:
        return "no FBDI mapping"
    unmapped = [f"{o}:{stg}" for o in objects for stg in src[o]
                if not reg.upload.get(stg, {}).get("fbdi") or reg.upload[stg]["object_code"] not in FBDI_MAPS]
    if unmapped:
        return "partial FBDI mapping: no FBDI file for " + ", ".join(unmapped)
    return None


def plan_files(reg, fmt_name, objects, src):
    """One file per staging table across every object of the run (a table shared
    by several objects carries all their rows). Returns (files, manifest):
    files are what goes in the zip; manifest has one entry per (object, table)
    with that object's source rows, for judging."""
    by_stg, manifest = {}, []
    for o in objects:
        for stg, rows in src[o].items():
            f = by_stg.setdefault(stg, {"stg": stg, "objects": [], "rows": []})
            f["objects"].append(o)
            have = {r["STG_SEQUENCE_ID"] for r in f["rows"]}
            f["rows"] += [r for r in rows if r["STG_SEQUENCE_ID"] not in have]
            manifest.append({"object": o, "stg": stg, "source_seqs": [r["STG_SEQUENCE_ID"] for r in rows]})
    files = []
    for stg in sorted(by_stg, key=lambda s: reg.upload[s]["order"] or 0):
        f = by_stg[stg]
        if fmt_name == "header":
            name, cols, notes = header_layout(reg, stg, f["rows"])
            layout = cols
        else:
            name, layout, cols, notes = fbdi_layout(reg, stg, f["rows"])
        files.append({"stg": stg, "file": name, "objects": f["objects"], "layout": layout, "columns": cols,
                      "notes": notes, "rows": f["rows"], "raw_rows": [], "rows_in_file": len(f["rows"]),
                      "dict_fbdi_positions": reg.dict_fbdi.get(reg.upload[stg]["object_code"], 0),
                      "source_seqs": [r["STG_SEQUENCE_ID"] for r in f["rows"]]})
    return files, manifest


def write_zip(fmt_name, files, path):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.writestr(f["file"], render(fmt_name, f["layout"], f["rows"], f["raw_rows"]))


def file_summary(f):
    return {k: f[k] for k in ("stg", "file", "objects", "rows_in_file", "notes") if k in f} | (
        {"bad_rows_added": [b["what"] for b in f.get("bad", [])]} if f.get("bad") else {})


# ---------------------------------------------------------------- browser
def browser_upload(target, jobs_list, work):
    """Create each scenario on page 14 and upload its zip on page 25, in one
    browser session that is closed afterwards. Returns {scenario: job result}."""
    base = cp.console_base(target)
    tgt = urltarget.resolve(base_url=base)
    if not tgt["password"]:
        raise SystemExit(f"no password resolved for {tgt['user']} (connections.json); never hardcoded")
    jobs = os.path.join(work, f"{jobs_list[0]['scenario']}.jobs.json")
    with open(jobs, "w", encoding="utf-8") as fh:
        json.dump(jobs_list, fh)
    env = dict(os.environ)
    env.update({"DMT2_UI_BASE": tgt["base_url"], "DMT2_UI_APP": tgt["app_path"],
                "DMT2_UI_APPID": tgt["app_id"], "DMT2_UI_USER": tgt["user"],
                "DMT2_UI_PASS": tgt["password"], "DMT2_PW_NODE_MODULES": PW_NODE_MODULES,
                "DMT2_UPL_JOBS": jobs, "DMT2_UPL_SHOTS": work})
    p = subprocess.run(["node", JS], env=env, capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=3600)
    try:
        res = json.loads(p.stdout)
    except ValueError:
        err = f"node output unreadable (exit {p.returncode}): " + (p.stderr or p.stdout)[-500:]
        return {j["scenario"]: {"uploaded": False, "errorMessage": err} for j in jobs_list}
    if not (res.get("login") or {}).get("ok"):
        err = f"login failed: {res.get('fatal') or res.get('login')}"
        return {j["scenario"]: {"uploaded": False, "errorMessage": err} for j in jobs_list}
    out = {j.get("scenario"): j for j in res.get("jobs") or []}
    for j in jobs_list:
        r = out.setdefault(j["scenario"], {"uploaded": False, "errorMessage": "not reached by the browser"})
        if res.get("fatal"):
            r["errorMessage"] = (r.get("errorMessage") or "") + " | " + res["fatal"]
    return out


def page_result(up):
    return {"page_ok": bool(up.get("uploaded")), "scenario_created": up.get("scenarioCreated"),
            "message": up.get("successMessage") or "", "error": up.get("errorMessage") or "",
            "batch_id": up.get("batchId"), "screenshot": up.get("shot")}


# ---------------------------------------------------------------- staging check
def scenario_id(cur, scenario):
    cur.execute("SELECT SCENARIO_ID FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME = :n", n=scenario)
    row = cur.fetchone()
    return row[0] if row else None


def check_staging(cur, scenario, files, src_by_seq):
    """Per file: staged count == the file's good rows and every written value
    round-trips (bad rows of the negative tests must not stage at all).
    Returns (ok, details, seq_map {(stg, new_seq): source_seq})."""
    sid = scenario_id(cur, scenario)
    if not sid:
        return False, [{"problem": f"scenario {scenario} not found"}], {}
    ok, details, seq_map = True, [], {}
    for m in files:
        stg, cols = m["stg"], m["columns"]
        cur.execute(f"SELECT STG_SEQUENCE_ID{''.join(', ' + c for c in cols)} FROM {stg} "
                    f"WHERE SCENARIO_ID = :s ORDER BY STG_SEQUENCE_ID", s=sid)
        staged = cur.fetchall()
        # Match each staged row to a source row by the values written for it.
        pool = {}
        for sseq in m["source_seqs"]:
            r = src_by_seq[(stg, sseq)]
            pool.setdefault(tuple(fmt(r.get(c)) for c in cols), []).append(sseq)
        unmatched = []
        for srow in staged:
            sig = tuple(fmt(v) for v in srow[1:])
            if pool.get(sig):
                seq_map[(stg, srow[0])] = pool[sig].pop(0)
            else:
                unmatched.append(srow[0])
        missing = sum(len(v) for v in pool.values())
        d = {"objects": m["objects"], "stg": stg, "file": m["file"], "rows_in_file": m["rows_in_file"],
             "staged": len(staged), "rows_matching_source": len(staged) - len(unmatched),
             "dict_fbdi_positions": m.get("dict_fbdi_positions"), "notes": m.get("notes", [])}
        if unmatched and m["source_seqs"]:
            # Name the columns that differ on the first unmatched row (closest source row).
            cur.execute(f"SELECT {', '.join(cols)} FROM {stg} WHERE STG_SEQUENCE_ID = :q", q=unmatched[0])
            got = [fmt(v) for v in cur.fetchone()]
            best = min(m["source_seqs"], key=lambda s: sum(
                1 for c, g in zip(cols, got) if fmt(src_by_seq[(stg, s)].get(c)) != g))
            diff = [f"{c}: file '{fmt(src_by_seq[(stg, best)].get(c))[:40]}' staged '{g[:40]}'"
                    for c, g in zip(cols, got) if fmt(src_by_seq[(stg, best)].get(c)) != g]
            d["first_difference"] = diff[:6] + ([f"... {len(diff) - 6} more columns"] if len(diff) > 6 else [])
        if len(staged) != m["rows_in_file"] or unmatched or missing:
            ok = False
            d["problem"] = (f"staged {len(staged)} of {m['rows_in_file']} rows; "
                            f"{len(unmatched)} staged row(s) do not match the file")
        details.append(d)
    return ok, details, seq_map


def upload_errors(cur, scenario):
    """DMT_UPLOAD_ERROR_TBL rows of the scenario (BATCH_TAG = scenario~stamp~file,
    the file name possibly cut short at the column width)."""
    cur.execute("""SELECT BATCH_TAG, ROW_NUMBER, COLUMN_NAME, ERROR_TYPE, SUBSTR(ERROR_MESSAGE, 1, 300)
                   FROM DMT_UPLOAD_ERROR_TBL WHERE BATCH_TAG LIKE :p ESCAPE '\\' ORDER BY ERROR_ID""",
                p=scenario.replace("_", "\\_") + "~%")
    return [{"file": (t or "").split("~")[-1], "row": r, "column": c,
             "type": ty, "message": m} for t, r, c, ty, m in cur.fetchall()]


def upload_log(cur, batch_id):
    try:
        bid = int(batch_id)
    except (TypeError, ValueError):
        return []
    cur.execute("""SELECT OBJECT_CODE, FILE_NAME, ROWS_IN_FILE, ROWS_LOADED, ROWS_ERRORED, STATUS,
                          SUBSTR(ERROR_MSG, 1, 300)
                   FROM DMT_UPLOAD_LOG_TBL WHERE BATCH_ID = :b ORDER BY LOG_ID""", b=bid)
    return [dict(zip(("object_code", "file", "rows_in_file", "rows_loaded", "rows_errored",
                      "status", "error"), r)) for r in cur.fetchall()]


def check_upload(target, scenario, files, src_by_seq, page):
    """Everything about one uploaded zip: the page's result, the loader's log,
    the staging check per file and the upload errors."""
    con = cp._oracle(target)
    try:
        cur = con.cursor()
        ok, details, seq_map = check_staging(cur, scenario, files, src_by_seq)
        errs = upload_errors(cur, scenario)
        if page.get("error") or not page.get("batch_id"):
            # The page showed an error without reloading, so the batch id it
            # holds is the previous one: take the batch of this scenario's
            # upload errors instead (every rejected file writes one).
            cur.execute("""SELECT MAX(l.BATCH_ID) FROM DMT_UPLOAD_ERROR_TBL e
                           JOIN DMT_UPLOAD_LOG_TBL l ON l.LOG_ID = e.LOG_ID
                           WHERE e.BATCH_TAG LIKE :p ESCAPE '\\'""", p=scenario.replace("_", "\\_") + "~%")
            found = cur.fetchone()[0]
            if found:
                page = dict(page, batch_id=found)
        ulog = upload_log(cur, page.get("batch_id"))
    finally:
        con.close()
    return dict(page, upload_log=ulog, tables=details, upload_errors=errs[:40],
                upload_error_count=len(errs), staging_ok=ok,
                ok=page["page_ok"] and ok and not errs), seq_map


def object_upload_problem(obj, up):
    """None when every file holding this object's rows staged exactly; else why not."""
    own = [d for d in up["tables"] if obj in (d.get("objects") or []) and d.get("problem")]
    if not own:
        return None
    loader = {x["file"]: x for x in up.get("upload_log") or []}
    parts = []
    for d in own[:4]:
        lg = loader.get(d["file"]) or {}
        parts.append(f"{d['stg']}: {d['problem']}"
                     + (f" (first difference: {'; '.join(d['first_difference'][:3])})"
                        if d.get("first_difference") else "")
                     + (f" (loader said: {lg['error']})" if lg.get("error") else ""))
    return "upload: " + "; ".join(parts)


# ---------------------------------------------------------------- expected outcomes
def regression_harness(target):
    """Import scripts/dmt_regression_run.py pointed at the target (its connect()
    reads DMT2_CONN / DMT2_WALLET, exactly as ci_promote.run_regression sets them)."""
    t = cp.TARGET[target]()
    os.environ["DMT2_CONN"] = (f"{t['schema']}/{t['pw']}@{t['dsn'].replace('//', '')}"
                               if target == "local" else f"{t['schema']}/{t['pw']}@{t['dsn']}")
    if t["tns"]:
        os.environ["DMT2_WALLET"] = t["tns"]
        os.environ["DMT2_WALLET_PW"] = cp._conns()["atp_queryapp"]["wallet_password"]
    import dmt_regression_run as rr  # noqa: E402
    return rr


def baseline_expectations(cur, rr, reg, scenario, scenario_id_):
    """{(stg, source_seq): 'LOADED' | 'FAILED' | 'FAILED_WITH_DOCUMENT'} - the
    regression's own verdict rule applied to the source row in the latest
    completed regression run of the baseline scenario on this target."""
    cur.execute("""SELECT MAX(RUN_ID) FROM DMT_PIPELINE_RUN_TBL
                   WHERE SCENARIO_NAME = :s AND RUN_STATUS IN ('COMPLETED', 'COMPLETED_ERRORS')""",
                s=scenario)
    run_id = cur.fetchone()[0]
    if not run_id:
        raise SystemExit(f"no completed regression run of {scenario} on this target")
    spec = rr.load_expected_outcomes(scenario)
    cur.execute("""SELECT CEMLI_CODE, SUB_OBJECT, DISPLAY_KEY, DBMS_LOB.SUBSTR(ERROR_TEXT, 300, 1),
                          STG_SEQUENCE_ID
                   FROM DMT_RECORD_DETAIL_V WHERE RUN_ID = :r AND STG_SEQUENCE_ID IS NOT NULL""", r=run_id)
    exp = {}
    keycache = {}
    for cemli, sub, key, err, seq in cur.fetchall():
        stg = reg.sub_stg.get((cemli, sub))
        if not stg or (stg, seq) in exp:
            continue
        outcome = None
        d = spec.get(sub)
        if d and d.get("stg_table") == stg:
            kc = rr._key_col(d)
            if (stg, kc) not in keycache:
                cur.execute(f"SELECT STG_SEQUENCE_ID, {ident(kc)} FROM {stg} WHERE SCENARIO_ID = :s",
                            s=scenario_id_)
                keycache[(stg, kc)] = dict(cur.fetchall())
            outcome = d["rows"].get(keycache[(stg, kc)].get(seq))
        if outcome is None:
            outcome = rr.EXPECT_FAILED if rr.is_bad_row(key, " ".join(str(err or "").split())) \
                else rr.EXPECT_LOADED
        exp[(stg, seq)] = outcome
    return run_id, exp


# ---------------------------------------------------------------- run
def active_runs(cur):
    cur.execute("SELECT RUN_ID, RUN_STATUS FROM DMT_PIPELINE_RUN_TBL "
                "WHERE RUN_STATUS NOT IN ('COMPLETED','COMPLETED_ERRORS','FAILED','NO_ROWS_PROCESSED','CANCELLED')")
    return cur.fetchall()


def wait_until_idle(target, max_min=180):
    """Runs on the target are one at a time: wait (bounded) until none is active."""
    deadline = time.time() + max_min * 60
    while True:
        con = cp._oracle(target)
        try:
            act = active_runs(con.cursor())
        finally:
            con.close()
        if not act:
            return True
        if time.time() > deadline:
            return False
        log(f"waiting: another run is active on {target}: {act}")
        time.sleep(60)


def submit(target, proc, what_param, what, scenario):
    """One submission through DMT_SCHEDULER_PKG (its one-active-run guard always
    applies; a refusal is reported, never bypassed or retried)."""
    con = cp._oracle(target)
    try:
        cur = con.cursor()
        v = cur.var(oracledb.NUMBER)
        cur.callproc(f"DMT_SCHEDULER_PKG.{proc}", keyword_parameters={
            what_param: what, "p_scenario_name": scenario, "p_run_mode": "ALL",
            "p_on_failure": "CONTINUE", "p_submitted_by": "UPLOAD_VERIFY", "x_run_id": v})
        con.commit()
        return int(v.getvalue())
    finally:
        con.close()


def start_run(args, rr, reg, scenario, objects, by_pipeline):
    """Prefix sync, then one submission. by_pipeline: SUBMIT_PIPELINE for every
    pipeline the objects belong to (the regression's way); else SUBMIT_OBJECTS
    for exactly these objects. Returns (run_id, prefix_expected) or raises."""
    if not wait_until_idle(args.target):
        raise RuntimeError("another run stayed active; not submitted")
    nxt = cp.sync_prefix_for(args.target)
    if by_pipeline:
        # The regression's submission (scripts/dmt_regression_run.py submit_run):
        # SUBMIT_PIPELINE, run mode ALL, on failure CONTINUE; tagged UPLOAD_VERIFY.
        what = ",".join(p for p in PIPELINE_ORDER if any(reg.pipe[o]["pipeline"] == p for o in objects))
        run_id = submit(args.target, "SUBMIT_PIPELINE", "p_pipeline_codes", what, scenario)
    else:
        what = "|".join(objects)
        run_id = submit(args.target, "SUBMIT_OBJECTS", "p_objects", what, scenario)
    rr.ensure_poller()
    log(f"{scenario}: run {run_id} submitted (prefix expected {nxt}) for {what}")
    return run_id, nxt


def finish_run(args, rr, run_id):
    """Wait for the run (bounded), then read its status, prefix and queue."""
    final = rr.wait_for_run(run_id, args.timeout_min, 30)
    unique = cp.assert_prefix_unique(args.target, run_id)
    con = cp._oracle(args.target)
    try:
        cur = con.cursor()
        cur.execute("SELECT RUN_STATUS, PREFIX, ERROR_MESSAGE FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = :r",
                    r=run_id)
        status, prefix, run_err = cur.fetchone()
        cur.execute("SELECT CEMLI_CODE, WORK_STATUS, SUBSTR(ERROR_MESSAGE, 1, 200) FROM DMT_WORK_QUEUE_TBL "
                    "WHERE RUN_ID = :r ORDER BY SORT_ORDER", r=run_id)
        queue = {c: {"status": w, "error": m} for c, w, m in cur.fetchall()}
    finally:
        con.close()
    return {"run_id": run_id, "prefix": prefix, "status": status, "timed_out": not final,
            "error": oneline(run_err), "prefix_unique": unique, "queue": queue}


def judge(cur, reg, run_id, objects, seq_map, expected, manifest):
    """Every uploaded row of every object in the run, judged against its expected
    outcome. The totals come from the uploaded rows, so a row the run never
    showed still counts (as unaccounted) in its GOOD or BAD total."""
    cur.execute("""SELECT CEMLI_CODE, SUB_OBJECT, DISPLAY_KEY, TFM_STATUS,
                          DBMS_LOB.SUBSTR(ERROR_TEXT, 400, 1), STG_SEQUENCE_ID, FUSION_ID
                   FROM DMT_RECORD_DETAIL_V WHERE RUN_ID = :r""", r=run_id)
    recs = {}
    for cemli, sub, key, status, err, seq, fid in cur.fetchall():
        recs.setdefault((cemli, reg.sub_stg.get((cemli, sub)), seq), []).append(
            (sub, key, status, " ".join(str(err or "").split()), fid))
    per = {o: {"good_total": 0, "good_loaded": 0, "good_loaded_no_fusion_id": 0, "good_failed": 0,
               "bad_total": 0, "bad_failed_with_error": 0, "bad_loaded": 0, "unaccounted": 0,
               "not_in_run": 0, "samples": []} for o in objects}
    inverse = {(stg, src): new for (stg, new), src in seq_map.items()}
    for m in manifest:
        o, stg = m["object"], m["stg"]
        if o not in per:
            continue
        s = per[o]
        for sseq in m["source_seqs"]:
            exp = expected[(stg, sseq)]
            good = exp == "LOADED"
            s["good_total" if good else "bad_total"] += 1
            new = inverse.get((stg, sseq))
            rows = recs.get((o, stg, new)) if new is not None else None
            label = f"{'GOOD' if good else 'BAD'} {stg} source row {sseq}"
            if not rows:
                s["not_in_run"] += 1
                s["unaccounted"] += 1
                s["samples"].append(f"{label}: not in the run (unaccounted)")
                continue
            # One staged row can have several transform rows; each must be accounted.
            for sub, key, status, err, fid in rows:
                if good and status == "LOADED" and fid:
                    s["good_loaded"] += 1
                elif good and status == "LOADED":
                    s["good_loaded_no_fusion_id"] += 1
                    s["samples"].append(f"{label} ({sub} {key}): LOADED without its own Fusion id")
                elif good and status == "FAILED" and err:
                    s["good_failed"] += 1
                    s["samples"].append(f"{label} ({sub} {key}): FAILED - {err[:160]}")
                elif (not good and status == "FAILED" and err
                      and (exp != "FAILED_WITH_DOCUMENT" or DOC_ERROR_MARKER in err)):
                    s["bad_failed_with_error"] += 1
                elif not good and status == "FAILED" and err:
                    s["samples"].append(f"{label} ({sub} {key}): FAILED without "
                                        f"'{DOC_ERROR_MARKER}' - {err[:120]}")
                elif not good and status == "LOADED":
                    s["bad_loaded"] += 1
                    s["samples"].append(f"{label} ({sub} {key}): LOADED")
                else:
                    s["unaccounted"] += 1
                    s["samples"].append(f"{label} ({sub} {key}): {status} (unaccounted)")
            if len(rows) > 1:
                s["good_total" if good else "bad_total"] += len(rows) - 1
    for s in per.values():
        s["samples"] = s["samples"][:12]
    return per


def verdict_of(r):
    s = r["result"]
    reasons = []
    if s["good_total"] == 0:
        reasons.append("no GOOD rows")
    if s["bad_total"] == 0:
        reasons.append("no BAD rows (a run with no errors reported is not a pass)")
    if s["good_loaded"] != s["good_total"]:
        reasons.append(f"GOOD {s['good_loaded']}/{s['good_total']} LOADED with a Fusion id"
                       + (f" ({s['good_failed']} FAILED)" if s["good_failed"] else "")
                       + (f" ({s['good_loaded_no_fusion_id']} LOADED without their own Fusion id)"
                          if s["good_loaded_no_fusion_id"] else ""))
    if s["bad_failed_with_error"] != s["bad_total"]:
        reasons.append(f"BAD {s['bad_failed_with_error']}/{s['bad_total']} FAILED with an error"
                       + (f" ({s['bad_loaded']} LOADED)" if s["bad_loaded"] else ""))
    if s["unaccounted"]:
        reasons.append(f"{s['unaccounted']} unaccounted"
                       + (f" ({s['not_in_run']} not in the run)" if s["not_in_run"] else ""))
    return reasons


def judge_run(args, reg, run, objects, seq_map, expected, manifest, scored):
    """Per-object entries from one run. scored: the objects that get a verdict
    (the upstream-only objects are judged too but reported under 'upstream')."""
    con = cp._oracle(args.target)
    try:
        per = judge(con.cursor(), reg, run["run_id"], objects, seq_map, expected, manifest)
    finally:
        con.close()
    out = {}
    for o in scored:
        e = {"result": per[o], "queue": run["queue"].get(o)}
        reasons = verdict_of(e)
        if run["timed_out"]:
            reasons.insert(0, f"run {run['run_id']} did not finish within {args.timeout_min} min")
        if not run["prefix_unique"]:
            reasons.insert(0, f"prefix {run['prefix']} was also used on the other instance")
        e.update(verdict="PASS" if not reasons else "FAIL", reason="; ".join(reasons) or None)
        out[o] = e
    return out


# ---------------------------------------------------------------- one format, one run
def new_stamp(target, names):
    """yymmddHHMM such that no scenario named names(stamp) exists yet (every test
    gets new scenarios; a rerun within the same minute waits for the next minute)."""
    while True:
        stamp = datetime.datetime.now().strftime("%y%m%d%H%M")
        con = cp._oracle(target)
        try:
            cur = con.cursor()
            taken = 0
            for n in names(stamp):
                cur.execute("SELECT COUNT(*) FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME = :n", n=n)
                taken += cur.fetchone()[0]
        finally:
            con.close()
        if not taken:
            return stamp
        time.sleep(61 - datetime.datetime.now().second)


def run_format(args, ctx, fmt_name, block, save):
    """The header or FBDI half: one zip, one scenario, one run. `block` is the
    saved state of an interrupted earlier attempt (--resume), else {}."""
    reg, rr, src_all, src_by_seq, expected = (ctx[k] for k in ("reg", "rr", "src", "src_by_seq", "expected"))
    objs = ctx["objects"]
    na = {}
    if fmt_name == "fbdi":
        for o in objs:
            r = fbdi_applicability(reg, o, reg.closure(o), {x: src_all[x] for x in reg.closure(o)})
            if r:
                na[o] = r
    scored = [o for o in objs if o not in na]
    run_objects = reg.order({x for o in scored for x in reg.closure(o)})
    block.setdefault("format", fmt_name)
    block["not_applicable"] = na
    block["objects_scored"] = scored
    block["objects_in_run"] = run_objects
    if not scored:
        return block
    empty = [o for o in run_objects if not src_all[o]]
    files, manifest = plan_files(reg, fmt_name, [o for o in run_objects if src_all[o]], src_all)
    block["files"] = [file_summary(f) for f in files]
    tag = "HDR" if fmt_name == "header" else "FBDI"
    # ---- upload (once) -------------------------------------------------------
    if not (block.get("upload") or {}).get("batch_id"):
        stamp = new_stamp(args.target, lambda s: [f"UPL-{tag}-{s}"])
        scenario = f"UPL-{tag}-{stamp}"
        zip_path = os.path.join(ctx["work"], f"{scenario}.zip")
        write_zip(fmt_name, files, zip_path)
        block.update(scenario=scenario, zip=zip_path)
        log(f"{scenario}: uploading {os.path.basename(zip_path)} "
            f"({sum(f['rows_in_file'] for f in files)} rows, {len(files)} files) through page 25")
        page = page_result(browser_upload(args.target, [{
            "scenario": scenario, "file": zip_path,
            "description": f"Backlog #786 upload test: all objects in {fmt_name} format"}], ctx["work"])[scenario])
        block["upload"] = page
    else:
        log(f"{block['scenario']}: reusing the scenario uploaded earlier (batch {block['upload']['batch_id']})")
    up, seq_map = check_upload(args.target, block["scenario"], files, src_by_seq,
                               {k: block["upload"].get(k) for k in
                                ("page_ok", "scenario_created", "message", "error", "batch_id", "screenshot")})
    block["upload"] = up
    if empty:
        block["upload"]["no_rows_in_baseline"] = empty
    log(f"{block['scenario']}: upload {'OK' if up['ok'] else 'with problems'}: "
        f"{sum(1 for d in up['tables'] if not d.get('problem'))}/{len(up['tables'])} files staged exactly, "
        f"{up['upload_error_count']} upload error row(s)")
    save()
    if args.upload_only:
        block["objects"] = {o: {"verdict": "UPLOAD ONLY",
                                "reason": object_upload_problem(o, up) or "upload passed; run not submitted"}
                            for o in scored}
        return block
    if not any(d["staged"] for d in up["tables"]):
        block["objects"] = {o: {"verdict": "FAIL", "reason": object_upload_problem(o, up) or "nothing staged"}
                            for o in scored}
        return block
    # ---- run (once) ------------------------------------------------------------
    if not (block.get("run") or {}).get("run_id"):
        try:
            run_id, nxt = start_run(args, rr, reg, block["scenario"], run_objects, by_pipeline=True)
        except Exception as ex:  # noqa: BLE001 - reported, never retried by hand
            block["run"] = {"error": f"not submitted: {oneline(ex)}"}
            block["objects"] = {o: {"verdict": "FAIL", "reason": block["run"]["error"]} for o in scored}
            return block
        block["run"] = {"run_id": run_id, "prefix_expected": nxt}
        save()
    run = finish_run(args, rr, block["run"]["run_id"])
    block["run"] = dict(block["run"], **run)
    log(f"{block['scenario']}: run {run['run_id']} prefix {run['prefix']} {run['status']}")
    per = judge_run(args, reg, run, run_objects, seq_map, expected, manifest, run_objects)
    block["objects"] = {}
    for o in scored:
        e = per[o]
        prob = object_upload_problem(o, up)
        if prob:
            e.update(verdict="FAIL", reason=prob + ("; " + e["reason"] if e.get("reason") else ""))
        ups = [u for u in reg.closure(o) if u != o and per[u]["verdict"] != "PASS"]
        if ups:
            e["upstream_not_passing"] = ups
        block["objects"][o] = e
    block["upstream_only"] = {o: {k: v for k, v in per[o].items()}
                              for o in run_objects if o not in scored}
    return block


# ---------------------------------------------------------------- negative tests
def pick_bad_columns(types, candidates, in_file):
    """Per kind, a column for the bad value: a number column, the shortest text
    column, a date column; columns already in the file first."""
    def first(pred, key=None):
        pool = [c for c in candidates if c in types and pred(types[c])]
        pool.sort(key=lambda c: (c not in in_file, key(types[c]) if key else 0))
        return pool[0] if pool else None
    return {"number": first(lambda t: t[0] == "NUMBER"),
            "length": first(lambda t: t[0] in ("VARCHAR2", "CHAR") and (t[1] or 0) > 0, key=lambda t: t[1]),
            "date": first(lambda t: t[0] == "DATE" or t[0].startswith("TIMESTAMP"))}


def add_bad_rows(cur, reg, fmt_name, f):
    """Three bad copies of the file's first row, one bad value each."""
    types = stg_types(cur, f["stg"])
    cand = [c for c in f["columns"] if c != "SOURCE_ID"]
    if fmt_name == "header":
        oc = reg.upload[f["stg"]]["object_code"]
        cand += [c for c in reg.dict_cols.get(oc, []) if c not in cand and c != "SOURCE_ID"]
    pick = pick_bad_columns(types, cand, f["columns"])
    base = {c: fmt(f["rows"][0].get(c)) for c in f["columns"]}
    f["bad"] = []
    for kind, col in pick.items():
        if not col:
            f.setdefault("notes", []).append(f"no {kind} column to break in {f['stg']}")
            continue
        if fmt_name == "header" and col not in f["layout"]:
            f["layout"] = f["layout"] + [col]
            f["columns"] = f["columns"] + [col]
        val = {"number": "NOT_A_NUMBER", "date": "NOT-A-DATE",
               "length": "X" * ((types[col][1] or 1) + 10)}[kind]
        row = dict(base, **{col: val})
        f["raw_rows"].append(row)
        f["bad"].append({"kind": kind, "column": col,
                         "what": f"{kind}: {col} = '{val[:20]}{'...' if len(val) > 20 else ''}'"})


def layout_file(cur, reg, fmt_name, src_all):
    """The wrong-layout file: named for Suppliers, carrying the wrong columns."""
    sup = src_all["Suppliers"][LAYOUT_TARGET]
    if fmt_name == "header":
        rows = src_all["Projects"][LAYOUT_SOURCE]
        _n, cols, _x = header_layout(reg, LAYOUT_SOURCE, rows)
        name = reg.upload[LAYOUT_TARGET]["csv"]
        return {"stg": LAYOUT_TARGET, "file": name, "objects": ["Suppliers"], "layout": cols, "columns": [],
                "rows": rows, "raw_rows": [], "rows_in_file": 0, "source_seqs": [],
                "what": f"{name} carrying the {LAYOUT_SOURCE} columns and its {len(rows)} rows"}
    name, slots, _c, _x = fbdi_layout(reg, LAYOUT_TARGET, sup)
    return {"stg": LAYOUT_TARGET, "file": name, "objects": ["Suppliers"], "layout": [None] * FBDI_SHIFT + slots,
            "columns": [], "rows": sup, "raw_rows": [], "rows_in_file": 0, "source_seqs": [],
            "what": f"{name} with every value moved {FBDI_SHIFT} slots right ({len(sup)} rows, "
                    f"{len(slots) + FBDI_SHIFT} slots instead of {len(slots)})"}


def visible_rejection(up, fname):
    """What a user sees for a file: an error notification on the page, or rows in
    the Upload Errors region (DMT_UPLOAD_ERROR_TBL). The log alone is not visible."""
    errs = [e for e in up["upload_errors"] if e["file"] and fname.startswith(e["file"])]
    return {"page_error": bool(up["error"]), "upload_error_rows": len(errs),
            "visible": bool(up["error"]) or bool(errs)}


def run_negative(args, ctx, block, save):
    reg, rr, src_all, src_by_seq, expected = (ctx[k] for k in ("reg", "rr", "src", "src_by_seq", "expected"))
    objs = reg.order({x for o in NEG_OBJECTS for x in reg.closure(o)})
    block.update(objects_in_zip=objs, mixed={}, layout={})
    stamp = block.get("stamp") or new_stamp(args.target, lambda s: [
        f"UPL-NEG-{t}-{s}" for t in ("HDR", "FBDI", "HDR-LAYOUT", "FBDI-LAYOUT")])
    block["stamp"] = stamp
    plans, jobs = {}, []
    con = cp._oracle(args.target)
    try:
        cur = con.cursor()
        for fmt_name, tag in (("header", "HDR"), ("fbdi", "FBDI")):
            files, manifest = plan_files(reg, fmt_name, objs, src_all)
            for f in files:
                if f["stg"] in NEG_TABLES:
                    add_bad_rows(cur, reg, fmt_name, f)
            lay = layout_file(cur, reg, fmt_name, src_all)
            sc1, sc2 = f"UPL-NEG-{tag}-{stamp}", f"UPL-NEG-{tag}-LAYOUT-{stamp}"
            z1, z2 = (os.path.join(ctx["work"], f"{s}.zip") for s in (sc1, sc2))
            write_zip(fmt_name, files, z1)
            write_zip(fmt_name, [lay], z2)
            plans[fmt_name] = (sc1, files, manifest, sc2, lay)
            jobs += [{"scenario": sc1, "file": z1, "description": f"Backlog #786 negative test 1 ({fmt_name})"},
                     {"scenario": sc2, "file": z2, "description": f"Backlog #786 negative test 2 ({fmt_name})"}]
    finally:
        con.close()
    if not block.get("pages"):
        log(f"negative tests: uploading {len(jobs)} zips through page 25")
        block["pages"] = {k: page_result(v) for k, v in browser_upload(args.target, jobs, ctx["work"]).items()}
        save()
    for fmt_name, (sc1, files, manifest, sc2, lay) in plans.items():
        # ---- test 1: mixed good and bad rows --------------------------------
        up, seq_map = check_upload(args.target, sc1, files, src_by_seq, block["pages"][sc1])
        per_file = []
        logs = {x["file"]: x for x in up["upload_log"]}
        for f, d in zip(files, up["tables"]):
            nbad = len(f.get("bad", []))
            errs = [e for e in up["upload_errors"] if e["file"] and f["file"].startswith(e["file"])]
            lg = logs.get(f["file"]) or {}
            if nbad:
                want = (not d.get("problem") and len(errs) == nbad
                        and all((e["message"] or "").strip() for e in errs)
                        and lg.get("status") == "COMPLETED_WITH_ERRORS")
            else:
                want = not d.get("problem") and not errs
            per_file.append({"file": f["file"], "stg": f["stg"], "good_rows": f["rows_in_file"],
                             "bad_rows": [b["what"] for b in f.get("bad", [])], "staged": d["staged"],
                             "good_rows_staged_exactly": not d.get("problem"),
                             "upload_error_rows": len(errs),
                             "errors": [f"row {e['row']} {e['column'] or ''}: {e['message']}" for e in errs][:4],
                             "unexpected_staged_row": d.get("first_difference"),
                             "log_status": lg.get("status"), "log_rows_errored": lg.get("rows_errored"),
                             "log_error": lg.get("error"), "as_expected": bool(want)})
        t1 = {"scenario": sc1, "page": {k: up[k] for k in ("page_ok", "message", "error", "batch_id")},
              "files": per_file, "upload_as_expected": all(p["as_expected"] for p in per_file)}
        t1["verdict"] = "PASS" if t1["upload_as_expected"] else "FAIL"
        t1["reason"] = None if t1["upload_as_expected"] else "; ".join(
            f"{p['file']}: staged {p['staged']} (good rows {p['good_rows']}), "
            f"{p['upload_error_rows']} upload error row(s) for {len(p['bad_rows'])} bad row(s), "
            f"log {p['log_status']}" + (f" ({p['log_error'][:120]})" if p.get("log_error") else "")
            for p in per_file if not p["as_expected"])
        # test 3 for this upload: a partly failed upload must not look like plain success
        t1["page_message_as_expected"] = bool(up["error"])
        block["mixed"][fmt_name] = t1
        save()
        if t1["upload_as_expected"] and not args.upload_only:
            prior = t1.get("run") or block.get(f"run_{fmt_name}") or {}
            if not prior.get("run_id"):
                try:
                    run_id, nxt = start_run(args, rr, reg, sc1, objs, by_pipeline=False)
                    prior = {"run_id": run_id, "prefix_expected": nxt}
                    block[f"run_{fmt_name}"] = prior
                    save()
                except Exception as ex:  # noqa: BLE001
                    prior = {"error": f"not submitted: {oneline(ex)}"}
            if prior.get("run_id"):
                run = finish_run(args, rr, prior["run_id"])
                per = judge_run(args, reg, run, objs, seq_map, expected, manifest, objs)
                t1["run"] = dict(prior, **{k: run[k] for k in ("run_id", "prefix", "status", "timed_out")})
                t1["run_objects"] = {o: {"verdict": e["verdict"], "reason": e["reason"],
                                         "result": {k: v for k, v in e["result"].items() if k != "samples"},
                                         "samples": e["result"]["samples"][:4]} for o, e in per.items()}
                if any(e["verdict"] != "PASS" for e in per.values()):
                    t1["verdict"] = "FAIL"
                    t1["reason"] = "run: " + "; ".join(f"{o} {e['reason']}" for o, e in per.items()
                                                       if e["verdict"] != "PASS")
            else:
                t1.update(run=prior, verdict="FAIL", reason=prior.get("error"))
        elif not t1["upload_as_expected"]:
            t1["run"] = {"skipped": "upload not as expected; the scenario is not run"}
        block["mixed"][fmt_name] = t1
        save()
        # ---- test 2: correctly named file, wrong layout ------------------------
        up2, _ = check_upload(args.target, sc2, [lay], src_by_seq, block["pages"][sc2])
        d = up2["tables"][0]
        lg = (up2["upload_log"] or [{}])[0]
        vis = visible_rejection(up2, lay["file"])
        t2 = {"scenario": sc2, "file": lay["what"], "staged": d["staged"],
              "page": {k: up2[k] for k in ("page_ok", "message", "error", "batch_id")},
              "log_status": lg.get("status"), "log_rows_loaded": lg.get("rows_loaded"),
              "log_rows_errored": lg.get("rows_errored"), "log_error": lg.get("error"),
              "upload_errors": up2["upload_errors"][:4], **vis}
        if d["staged"]:
            con = cp._oracle(args.target)
            try:
                cur = con.cursor()
                sid = scenario_id(cur, sc2)
                cols = [c for c in stg_columns(cur, LAYOUT_TARGET) if c not in ADMIN_COLS]
                cur.execute(f"SELECT {', '.join(cols)} FROM {LAYOUT_TARGET} WHERE SCENARIO_ID = :s "
                            f"AND ROWNUM = 1", s=sid)
                r = cur.fetchone()
                t2["first_staged_row_populated"] = {c: fmt(v)[:40] for c, v in zip(cols, r) if v is not None}
            finally:
                con.close()
        t2["verdict"] = "PASS" if (d["staged"] == 0 and vis["visible"]) else "FAIL"
        t2["reason"] = None if t2["verdict"] == "PASS" else (
            (f"{d['staged']} row(s) staged from a file with the wrong layout" if d["staged"]
             else "nothing staged, but the rejection is not visible (no page error, no Upload Errors row)"))
        t2["page_message_as_expected"] = bool(up2["error"])
        block["layout"][fmt_name] = t2
        save()
    block["page_message"] = {
        f"{t} ({f})": ("PASS" if block[k][f]["page_message_as_expected"] else "FAIL")
        + f": page showed error '{oneline(block[k][f]['page']['error'], 160)}'"
        if block[k][f]["page_message_as_expected"] else
        ("FAIL: shown as success: '" + oneline(block[k][f]["page"]["message"], 200) + "'")
        for k, t in (("mixed", "test 1 mixed rows"), ("layout", "test 2 wrong layout")) for f in block[k]}
    return block


# ---------------------------------------------------------------- report
def entries_of(payload):
    """Flat per-object/format rows for the table and the readiness list."""
    out = []
    for fmt_name in ("header", "fbdi"):
        b = payload.get("formats", {}).get(fmt_name)
        if not b:
            continue
        for o, reason in (b.get("not_applicable") or {}).items():
            out.append({"object": o, "format": fmt_name, "verdict": "NOT APPLICABLE", "reason": reason})
        for o, e in (b.get("objects") or {}).items():
            out.append(dict(e, object=o, format=fmt_name))
    order = {o: i for i, o in enumerate(IN_SCOPE)}
    return sorted(out, key=lambda r: (order.get(r["object"], 99), r["format"] != "header"))


def readiness(entries):
    by = {}
    for r in entries:
        by.setdefault(r["object"], {})[r["format"]] = r
    out = {}
    for o, f in by.items():
        h, fb = f.get("header"), f.get("fbdi")
        if not h or not fb:
            out[o] = "not yet: " + ("header" if not h else "FBDI") + " not tested"
        elif h["verdict"] == "PASS" and fb["verdict"] in ("PASS", "NOT APPLICABLE"):
            out[o] = "yes"
        elif "FAIL" in (h["verdict"], fb["verdict"]):
            out[o] = "no: " + ", ".join(x for x, r in (("header", h), ("FBDI", fb)) if r["verdict"] == "FAIL") \
                     + " failed"
        else:
            out[o] = "not yet: run not done"
    return out


def write_outputs(args, payload):
    payload["finished_at"] = datetime.datetime.now().isoformat(timespec="seconds")
    payload["entries"] = entries_of(payload)
    if payload["entries"]:
        payload["ready_for_functional_testing"] = readiness(payload["entries"])
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=1, default=str)
    if args.md_out:
        with open(args.md_out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(markdown(payload))


def markdown(p):
    lines = [f"# Upload verification ({p['target']}) - {p['started_at'][:16]}", "",
             f"Backlog #786. Per format one zip of every object, uploaded once through Smart Upload "
             f"(page 25) in a real browser into its own scenario, then one pipeline run of that scenario on "
             f"{p['target']} (console {p['console']}). Baseline data: {p['baseline_scenario']} "
             f"(regression run {p['baseline_run_id']} gives each row's expected outcome). Code: "
             f"{p['git_commit']}.", ""]
    for fmt_name, b in (p.get("formats") or {}).items():
        up, run = b.get("upload") or {}, b.get("run") or {}
        lines.append(f"**{fmt_name} format:** scenario {b.get('scenario', '-')}, "
                     f"{len(b.get('files') or [])} files, page "
                     f"{'OK' if up.get('page_ok') else 'reported a problem'}"
                     + (f" ({oneline(up.get('error'), 200)})" if up.get("error") else "")
                     + f", {up.get('upload_error_count', 0)} upload error row(s); run "
                     + (f"{run['run_id']}, prefix {run.get('prefix')}, {run.get('status')}"
                        if run.get("run_id") else (run.get("error") or "not submitted")) + ".")
        bad_files = [d for d in up.get("tables") or [] if d.get("problem")]
        for d in bad_files:
            lg = {x["file"]: x for x in up.get("upload_log") or []}.get(d["file"]) or {}
            lines.append(f"- {d['file']} ({d['stg']}): {d['problem']}"
                         + (f"; first difference: {'; '.join(d['first_difference'][:3])}"
                            if d.get("first_difference") else "")
                         + (f"; loader said: {lg['error']}" if lg.get("error") else ""))
        lines.append("")
    lines += ["| Object | Format | Upload | Run | GOOD | BAD | Unaccounted | Verdict |",
              "|---|---|---|---|---|---|---|---|"]
    for r in p.get("entries") or []:
        b = (p.get("formats") or {}).get(r["format"]) or {}
        up, run, s = b.get("upload"), b.get("run") or {}, r.get("result")
        if up and r["verdict"] != "NOT APPLICABLE":
            own = [d for d in up["tables"] if r["object"] in (d.get("objects") or [])]
            upc = (("upload OK" if not any(d.get("problem") for d in own) else "upload FAILED") + " ("
                   + ", ".join(f"{d['rows_matching_source']}/{d['rows_in_file']} rows -> {d['stg']}"
                               for d in own) + ")")
        else:
            upc = "-"
        runc = f"run {run['run_id']}, prefix {run.get('prefix')}" if run.get("run_id") and s else "-"
        good = f"GOOD {s['good_loaded']}/{s['good_total']} LOADED" if s else "-"
        bad = f"BAD {s['bad_failed_with_error']}/{s['bad_total']} FAILED with error" if s else "-"
        una = f"unaccounted {s['unaccounted']}" if s else "-"
        verdict = r["verdict"] + (f": {r['reason']}" if r.get("reason") else "")
        lines.append(f"| {r['object']} | {r['format']} | {upc} | {runc} | {good} | {bad} | {una} | "
                     f"{verdict.replace('|', '/')} |")
    rd = p.get("ready_for_functional_testing")
    if rd:
        lines += ["", "## Ready for functional testing", "",
                  "Passes in the header run, and passes in the FBDI run or the FBDI format does not apply.", "",
                  "| Object | Ready |", "|---|---|"]
        lines += [f"| {o} | {v} |" for o, v in rd.items()]
    neg = p.get("negative")
    if neg:
        lines += ["", "## Negative upload tests", "",
                  f"Objects in the zips: {', '.join(neg.get('objects_in_zip') or [])}. Bad rows were added to "
                  f"{', '.join(NEG_TABLES)}.", "",
                  "| Test | Format | Scenario | Result | Verdict |", "|---|---|---|---|---|"]
        for fmt_name, t in (neg.get("mixed") or {}).items():
            res = "; ".join(f"{x['file']}: {x['staged']} staged of {x['good_rows']} good, "
                            f"{x['upload_error_rows']} error row(s) for {len(x['bad_rows'])} bad, "
                            f"log {x['log_status']}"
                            + (f" (a bad row staged: {'; '.join(x['unexpected_staged_row'][:2])})"
                               if x.get("unexpected_staged_row") else "")
                            + (f" (errors: {' / '.join(e[:90] for e in x['errors'][:3])})" if x.get("errors") else "")
                            for x in t["files"] if x["bad_rows"] or not x["as_expected"])
            if t.get("run", {}).get("run_id"):
                res += f"; run {t['run']['run_id']} prefix {t['run'].get('prefix')} {t['run'].get('status')}"
            elif t.get("run"):
                res += f"; run: {t['run'].get('skipped') or t['run'].get('error')}"
            lines.append(f"| 1 mixed rows | {fmt_name} | {t['scenario']} | {res.replace('|', '/')} | "
                         f"{t['verdict']}{': ' + t['reason'].replace('|', '/') if t.get('reason') else ''} |")
        for fmt_name, t in (neg.get("layout") or {}).items():
            res = (f"{t['file']}: {t['staged']} row(s) staged, log {t['log_status']} "
                   f"(loaded {t['log_rows_loaded']}, errored {t['log_rows_errored']})"
                   + (f", loader said: {oneline(t['log_error'], 150)}" if t.get("log_error") else "")
                   + f", page error shown: {'yes' if t['page_error'] else 'no'}, "
                     f"Upload Errors rows: {t['upload_error_rows']}"
                   + (f"; first staged row holds: {', '.join(f'{k}={v}' for k, v in list(t['first_staged_row_populated'].items())[:5])}"
                      if t.get("first_staged_row_populated") else ""))
            lines.append(f"| 2 wrong layout | {fmt_name} | {t['scenario']} | {res.replace('|', '/')} | "
                         f"{t['verdict']}{': ' + t['reason'] if t.get('reason') else ''} |")
        for k, v in (neg.get("page_message") or {}).items():
            lines.append(f"| 3 page message | {k} | - | {v.replace('|', '/')} | {v.split(':')[0]} |")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description="Upload test through Smart Upload (backlog #786)")
    ap.add_argument("--target", choices=["atp", "local"], default="atp")
    ap.add_argument("--objects", default="all", help="comma list of object codes, or 'all' (the 27)")
    ap.add_argument("--formats", default="header,fbdi")
    ap.add_argument("--negative", action="store_true", help="run the negative upload tests instead")
    ap.add_argument("--json-out", required=True)
    ap.add_argument("--md-out")
    ap.add_argument("--work-dir", help="where zips and screenshots go (default: a temp folder)")
    ap.add_argument("--timeout-min", type=int, default=180, help="per-run wait limit")
    ap.add_argument("--upload-only", action="store_true", help="upload and check staging; no run")
    ap.add_argument("--resume", action="store_true",
                    help="continue the --json-out file: reuse its uploads, wait for its submitted runs")
    args = ap.parse_args()

    objs = IN_SCOPE if args.objects == "all" else [o.strip() for o in args.objects.split(",") if o.strip()]
    bad = [o for o in objs if o not in IN_SCOPE]
    if bad:
        sys.exit(f"not in scope: {bad}")
    formats = [f.strip() for f in args.formats.split(",") if f.strip()]
    if any(f not in ("header", "fbdi") for f in formats):
        sys.exit("--formats takes header and/or fbdi")
    work = args.work_dir or tempfile.mkdtemp(prefix="dmt2_upload_")
    os.makedirs(work, exist_ok=True)

    with open(os.path.join(SCRIPTS, "regression_scenario.json"), encoding="utf-8") as fh:
        baseline = json.load(fh)["current_scenario"]
    rr = regression_harness(args.target)
    con = cp._oracle(args.target)
    cur = con.cursor()
    reg = Registry(cur)
    base_sid = scenario_id(cur, baseline)
    if not base_sid:
        sys.exit(f"baseline scenario {baseline} is not on {args.target}")
    scope = NEG_OBJECTS if args.negative else objs
    needed = sorted({o for ob in scope for o in reg.closure(ob)})
    src_all = {o: source_rows(cur, reg, o, base_sid) for o in needed}
    src_by_seq = {(stg, r["STG_SEQUENCE_ID"]): r for o in needed for stg, rows in src_all[o].items()
                  for r in rows}
    base_run, expected = baseline_expectations(cur, rr, reg, baseline, base_sid)
    con.close()
    git = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"], capture_output=True,
                         text=True).stdout.strip()
    payload = {}
    if args.resume and os.path.exists(args.json_out):
        with open(args.json_out, encoding="utf-8") as fh:
            payload = json.load(fh)
    payload.update({"target": args.target, "console": cp.console_base(args.target),
                    "baseline_scenario": baseline, "baseline_run_id": base_run, "git_commit": git,
                    "work_dir": work})
    payload.setdefault("started_at", datetime.datetime.now().isoformat(timespec="seconds"))
    log(f"target {args.target}; baseline {baseline} (run {base_run}); work dir {work}")
    ctx = {"reg": reg, "rr": rr, "src": src_all, "src_by_seq": src_by_seq, "expected": expected,
           "objects": objs, "work": work}

    def save():
        write_outputs(args, payload)

    fails = []
    if args.negative:
        block = payload.setdefault("negative", {})
        run_negative(args, ctx, block, save)
        fails = [t for k in ("mixed", "layout") for t in block[k].values() if t["verdict"] == "FAIL"]
        fails += [v for v in block["page_message"].values() if v.startswith("FAIL")]
    else:
        payload.setdefault("formats", {})
        for f in formats:
            block = payload["formats"].setdefault(f, {})
            if block.get("objects") and not args.resume:
                block.clear()
            try:
                run_format(args, ctx, f, block, save)
            except SystemExit:
                raise
            except Exception as ex:  # noqa: BLE001 - one format's crash must not stop the other
                block["error"] = f"test error: {type(ex).__name__}: {oneline(ex)}"
                log(block["error"])
            save()
        fails = [r for r in entries_of(payload) if r["verdict"] == "FAIL"]
    save()
    log(f"done: {len(fails)} FAIL")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
