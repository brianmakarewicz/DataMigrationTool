#!/usr/bin/env python
"""
dmt_upload_verify.py - per-object upload test through the Smart Upload page (backlog #786).

An object is "ready for functional testing" when three checks pass:
  1. header format: the object's source CSVs, with our column headers (one
     DMT_<TABLE>_STG_TBL.csv per staging table, columns named as in
     DMT_UPLOAD_DICT_TBL), upload through page 25 (Smart Upload);
  2. FBDI format: the object's Oracle FBDI files (headerless CSVs named per
     DMT_UPLOAD_OBJECT_TBL.FBDI_CSV_FILENAME, one value per FBDI slot) upload
     through the same page (not applicable to HCM/HDL objects or to objects with
     no or only part of an FBDI mapping);
  3. the uploaded data, run through the pipeline into Fusion, ends with every
     GOOD row LOADED with a Fusion id, every BAD row FAILED with a real error,
     and nothing unaccounted.

For each object and format this script:
  a. reads the object's rows from the current regression baseline scenario
     (scripts/regression_scenario.json) on the target database, read-only, and
     writes them as a zip in the format under test. Objects that need upstream
     objects in the same run (DMT_PIPELINE_DEF_TBL.DEPENDS_ON, followed
     transitively) get those objects' rows too, uploaded the same way;
  b. drives a real browser (test/playwright/dmt_upload_verify.js): page 14
     creates a new scenario UPL-HDR-<Object>-<yymmddHHMM> or
     UPL-FBDI-<Object>-<yymmddHHMM>, page 25 uploads the zip into it;
  c. checks staging: per table, the scenario holds exactly the file's rows and
     every written value came through unchanged; DMT_UPLOAD_ERROR_TBL has no row
     for the scenario;
  d. syncs the prefix (scripts/ci_promote.py sync_prefix_for), submits the
     object plus its upstream objects with DMT_SCHEDULER_PKG.SUBMIT_OBJECTS for
     that scenario, waits for the run (the regression harness's wait), and
     checks the prefix is not used on the other instance (assert_prefix_unique);
  e. judges every row of the object from DMT_RECORD_DETAIL_V. GOOD and BAD come
     from the regression's own classification of the same source row in the
     baseline regression run (scripts/regression_scenario.json expected outcomes,
     else the harness's bad-key rule, scripts/dmt_regression_run.py), so the
     test expects exactly what the regression expects.

A step that fails stops that object/format: a failed upload is never run (it
would spend a prefix on data that is already known to be wrong).

Usage:
  python test/playwright/dmt_upload_verify.py --target atp --objects Suppliers --formats header \
      --json-out docs/findings/upload_verify_<stamp>.json
  python test/playwright/dmt_upload_verify.py --target atp --objects all --formats header,fbdi \
      --json-out <path> [--md-out <path>] [--skip-done] [--upload-only]

The JSON file is rewritten after every object/format, so a long run can be
watched and resumed (--skip-done keeps finished entries of an existing file).
Exit codes: 0 = every applicable entry PASS, 1 = any FAIL, 2 = setup problem.
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

TERMINAL_RUN = {"COMPLETED", "COMPLETED_ERRORS", "FAILED", "NO_ROWS_PROCESSED", "CANCELLED"}
PASSING_RUN = {"COMPLETED", "COMPLETED_ERRORS"}
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
        return sorted(seen, key=lambda o: (self.pipe[o]["pipeline"], self.pipe[o]["sort"]))


# ---------------------------------------------------------------- source rows
def stg_columns(cur, stg):
    cur.execute("SELECT COLUMN_NAME FROM USER_TAB_COLUMNS WHERE TABLE_NAME = :t ORDER BY COLUMN_ID", t=stg)
    return [r[0] for r in cur.fetchall()]


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
def header_member(reg, stg, rows):
    """One header CSV: SOURCE_ID first (the dictionary marks it admin, but the
    loader honours a SOURCE_ID header - DMT_UPLOAD_DICT_PKG), then every
    dictionary column that holds data in any row, in dictionary order.
    Returns (name, bytes, columns, notes)."""
    up = reg.upload[stg]
    dict_cols = (["SOURCE_ID"] if "SOURCE_ID" in rows[0] else []) + reg.dict_cols.get(up["object_code"], [])
    present = [c for c in dict_cols if c in rows[0]]
    cols = [c for c in present if c == "SOURCE_ID" or any(r.get(c) is not None for r in rows)]
    lost = sorted(c for c in rows[0] if c not in dict_cols and c not in ADMIN_COLS
                  and any(r.get(c) is not None for r in rows))
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\r\n")
    w.writerow(cols)
    for r in rows:
        w.writerow([fmt(r.get(c)) for c in cols])
    notes = [f"populated columns not in the upload dictionary (cannot be uploaded): {', '.join(lost)}"] if lost else []
    return up["csv"], buf.getvalue().encode("utf-8"), cols, notes


def fbdi_member(reg, stg, rows):
    """One FBDI CSV, headerless, one value per slot as laid out in the committed
    FBDI map (test/upload_samples/fbdi_column_maps.py, the source of
    db/seed/dmt_upload_fbdi_metadata.sql). Returns (name, bytes, columns, notes)."""
    up = reg.upload[stg]
    fname, colmap = FBDI_MAPS[up["object_code"]]
    slots = [c if (c and c in rows[0]) else None for c in colmap]
    cols = [c for c in slots if c]
    lost = sorted(c for c in rows[0] if c not in cols and c not in ADMIN_COLS
                  and any(r.get(c) is not None for r in rows))
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\r\n", quoting=csv.QUOTE_ALL)
    for r in rows:
        w.writerow([fmt(r.get(c)) if c else "" for c in slots])
    notes = [f"populated columns the FBDI file has no slot for (not carried): {', '.join(lost)}"] if lost else []
    return fname, buf.getvalue().encode("utf-8"), cols, notes


ADMIN_COLS = {"STG_SEQUENCE_ID", "STAGE_DATE", "STG_STATUS", "ERROR_TEXT", "LAST_UPDATED_DATE",
              "SCENARIO_ID", "CREATED_BY", "CREATED_DATE", "LAST_UPDATED_BY"}


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


def build_zip(reg, fmt_name, objects, src, path):
    """Write the upload zip for every object of the run; returns the manifest."""
    manifest = []
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for o in objects:
            for stg, rows in src[o].items():
                name, data, cols, notes = (header_member if fmt_name == "header" else fbdi_member)(reg, stg, rows)
                z.writestr(name, data)
                manifest.append({"object": o, "stg": stg, "file": name, "rows_in_file": len(rows),
                                 "columns": cols, "notes": notes,
                                 "dict_fbdi_positions": reg.dict_fbdi.get(reg.upload[stg]["object_code"], 0),
                                 "source_seqs": [r["STG_SEQUENCE_ID"] for r in rows]})
    return manifest


# ---------------------------------------------------------------- browser
def browser_upload(target, scenario, zip_path, description, work):
    base = cp.console_base(target)
    tgt = urltarget.resolve(base_url=base)
    if not tgt["password"]:
        raise SystemExit(f"no password resolved for {tgt['user']} (connections.json); never hardcoded")
    jobs = os.path.join(work, f"{scenario}.jobs.json")
    with open(jobs, "w", encoding="utf-8") as fh:
        json.dump([{"scenario": scenario, "file": zip_path, "description": description}], fh)
    env = dict(os.environ)
    env.update({"DMT2_UI_BASE": tgt["base_url"], "DMT2_UI_APP": tgt["app_path"],
                "DMT2_UI_APPID": tgt["app_id"], "DMT2_UI_USER": tgt["user"],
                "DMT2_UI_PASS": tgt["password"], "DMT2_PW_NODE_MODULES": PW_NODE_MODULES,
                "DMT2_UPL_JOBS": jobs, "DMT2_UPL_SHOTS": work})
    p = subprocess.run(["node", JS], env=env, capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=1800)
    try:
        res = json.loads(p.stdout)
    except ValueError:
        return {"uploaded": False, "errorMessage": f"node output unreadable (exit {p.returncode}): "
                + (p.stderr or p.stdout)[-500:]}
    if not (res.get("login") or {}).get("ok"):
        return {"uploaded": False, "errorMessage": f"login failed: {res.get('fatal') or res.get('login')}"}
    job = (res.get("jobs") or [{}])[0]
    if res.get("fatal"):
        job["errorMessage"] = (job.get("errorMessage") or "") + " | " + res["fatal"]
    return job


# ---------------------------------------------------------------- staging check
def check_staging(cur, scenario, manifest, src_by_seq):
    """Per table: staged count == file count and every written value round-trips.
    Returns (ok, details, seq_map {(stg, new_seq): source_seq}, upload_errors)."""
    cur.execute("SELECT SCENARIO_ID FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME = :n", n=scenario)
    row = cur.fetchone()
    if not row:
        return False, [{"problem": f"scenario {scenario} not found"}], {}, []
    sid = row[0]
    ok, details, seq_map = True, [], {}
    for m in manifest:
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
        d = {"object": m["object"], "stg": stg, "file": m["file"], "rows_in_file": m["rows_in_file"],
             "staged": len(staged), "rows_matching_source": len(staged) - len(unmatched),
             "dict_fbdi_positions": m["dict_fbdi_positions"], "notes": m["notes"]}
        if unmatched:
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
    cur.execute("""SELECT ROW_NUMBER, COLUMN_NAME, ERROR_TYPE, SUBSTR(ERROR_MESSAGE, 1, 300)
                   FROM DMT_UPLOAD_ERROR_TBL WHERE BATCH_TAG LIKE :p ESCAPE '\\' ORDER BY ERROR_ID""",
                p=scenario.replace("_", "\\_") + "~%")
    errors = [{"row": r[0], "column": r[1], "type": r[2], "message": r[3]} for r in cur.fetchall()]
    if errors:
        ok = False
    return ok, details, seq_map, errors


def upload_failure_reason(obj, up):
    """Plain-English reason an upload failed, separating the object's own files
    from the upstream objects' files, with the loader's own error text."""
    bad = [d for d in up["tables"] if d.get("problem")]
    own = [d for d in bad if d["object"] == obj]
    upstream = sorted({d["object"] for d in bad if d["object"] != obj})
    loader = [f"{x['object_code']}: {x['error']}" for x in up.get("upload_log") or []
              if x.get("error") and (x.get("status") != "COMPLETED" or str(x.get("rows_errored") or 0) != "0")]
    parts = ([f"page said: {up['error']}"] if up.get("error") else [])
    parts += [f"{d['stg']}: {d['problem']}"
              + (f" (first difference: {'; '.join(d['first_difference'][:3])})" if d.get("first_difference") else "")
              for d in own][:4]
    if upstream:
        parts.append(f"the file of upstream object(s) {', '.join(upstream)} did not stage "
                     f"(this object's own files staged {'correctly' if not own else 'with problems'})")
    if up.get("upload_error_count"):
        parts.append(f"{up['upload_error_count']} row(s) in DMT_UPLOAD_ERROR_TBL")
    parts += [f"loader said {x}" for x in dict.fromkeys(loader)][:3]
    return "upload: " + "; ".join(parts) + " (run not submitted)"


def upload_log(cur, batch_id):
    if not batch_id:
        return []
    try:
        bid = int(batch_id)
    except ValueError:
        return []
    cur.execute("""SELECT OBJECT_CODE, FILE_NAME, ROWS_IN_FILE, ROWS_LOADED, ROWS_ERRORED, STATUS,
                          SUBSTR(ERROR_MSG, 1, 300)
                   FROM DMT_UPLOAD_LOG_TBL WHERE BATCH_ID = :b ORDER BY LOG_ID""", b=bid)
    return [dict(zip(("object_code", "file", "rows_in_file", "rows_loaded", "rows_errored",
                      "status", "error"), r)) for r in cur.fetchall()]


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


def baseline_expectations(cur, rr, reg, scenario, scenario_id):
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
                            s=scenario_id)
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


def submit_objects(target, objects, scenario):
    con = cp._oracle(target)
    try:
        cur = con.cursor()
        v = cur.var(oracledb.NUMBER)
        cur.callproc("DMT_SCHEDULER_PKG.SUBMIT_OBJECTS", keyword_parameters={
            "p_objects": "|".join(objects), "p_scenario_name": scenario, "p_run_mode": "ALL",
            "p_on_failure": "CONTINUE", "p_submitted_by": "UPLOAD_VERIFY", "x_run_id": v})
        con.commit()
        return int(v.getvalue())
    finally:
        con.close()


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
                    s["samples"].append(f"{label} ({sub} {key}): LOADED without a Fusion id")
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
                       + (f" ({s['good_loaded_no_fusion_id']} LOADED without a Fusion id)"
                          if s["good_loaded_no_fusion_id"] else ""))
    if s["bad_failed_with_error"] != s["bad_total"]:
        reasons.append(f"BAD {s['bad_failed_with_error']}/{s['bad_total']} FAILED with an error"
                       + (f" ({s['bad_loaded']} LOADED)" if s["bad_loaded"] else ""))
    if s["unaccounted"]:
        reasons.append(f"{s['unaccounted']} unaccounted"
                       + (f" ({s['not_in_run']} not in the run)" if s["not_in_run"] else ""))
    return reasons


def run_entry(args, reg, rr, obj, fmt_name, src_all, src_by_seq, expected, stamp, work, prior=None):
    """One object in one format. `prior` is an earlier --upload-only entry whose
    upload passed: its scenario is reused (staging is checked again) instead of
    uploading the same file a second time."""
    objects = reg.closure(obj)
    tag = "HDR" if fmt_name == "header" else "FBDI"
    scenario = prior["scenario"] if prior else f"UPL-{tag}-{obj}-{stamp}"
    e = {"object": obj, "format": fmt_name, "objects_in_run": objects, "scenario": scenario,
         "verdict": None, "reason": None}
    src = {o: src_all[o] for o in objects}
    if fmt_name == "fbdi":
        na = fbdi_applicability(reg, obj, objects, src)
        if na:
            e.update(verdict="NOT APPLICABLE", reason=na, scenario=None)
            return e
    empty = [o for o in objects if not src[o]]
    if empty:
        e.update(verdict="FAIL", reason=f"no rows in the baseline scenario for {', '.join(empty)}")
        return e
    zip_path = os.path.join(work, f"{scenario}.zip")
    manifest = build_zip(reg, fmt_name, objects, src, zip_path)
    e["files"] = [{k: m[k] for k in ("object", "stg", "file", "rows_in_file", "notes")} for m in manifest]
    if prior:
        log(f"{scenario}: reusing the scenario uploaded earlier (batch {prior['upload'].get('batch_id')})")
        p = prior["upload"]
        up = {"uploaded": p["page_ok"], "scenarioCreated": p["scenario_created"], "successMessage": p["message"],
              "errorMessage": p["error"], "batchId": p["batch_id"], "shot": p.get("screenshot")}
    else:
        log(f"{scenario}: uploading {os.path.basename(zip_path)} "
            f"({sum(m['rows_in_file'] for m in manifest)} rows, {len(manifest)} files) through page 25")
        up = browser_upload(args.target, scenario, zip_path,
                            f"Backlog #786 upload test: {obj} in {fmt_name} format", work)
    con = cp._oracle(args.target)
    try:
        cur = con.cursor()
        ok, details, seq_map, errs = check_staging(cur, scenario, manifest, src_by_seq)
        e["upload"] = {"page_ok": bool(up.get("uploaded")), "scenario_created": up.get("scenarioCreated"),
                       "message": up.get("successMessage") or "", "error": up.get("errorMessage") or "",
                       "batch_id": up.get("batchId"), "screenshot": up.get("shot"),
                       "upload_log": upload_log(cur, up.get("batchId")),
                       "tables": details, "upload_errors": errs[:20], "upload_error_count": len(errs),
                       "ok": bool(up.get("uploaded")) and ok}
    finally:
        con.close()
    if not e["upload"]["ok"]:
        e.update(verdict="FAIL", reason=upload_failure_reason(obj, e["upload"]))
        return e
    log(f"{scenario}: upload OK, staged rows match the file")
    if args.upload_only:
        e.update(verdict="UPLOAD ONLY", reason="upload passed; run not submitted yet (--upload-only)")
        return e
    # ---- run: one at a time, prefix synced first, checked after -------------
    if not wait_until_idle(args.target):
        e.update(verdict="FAIL", reason="another run stayed active; not submitted")
        return e
    nxt = cp.sync_prefix_for(args.target)
    try:
        run_id = submit_objects(args.target, objects, scenario)
    except Exception as ex:  # noqa: BLE001 - reported, never retried by hand
        e.update(verdict="FAIL", reason=f"SUBMIT_OBJECTS refused: {' '.join(str(ex).split())[:300]}")
        return e
    rr.ensure_poller()
    log(f"{scenario}: run {run_id} submitted (prefix expected {nxt}) for {'|'.join(objects)}")
    final = rr.wait_for_run(run_id, args.timeout_min, 20)
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
        per = judge(cur, reg, run_id, objects, seq_map, expected, manifest)
    finally:
        con.close()
    e["run"] = {"run_id": run_id, "prefix": prefix, "status": status, "timed_out": not final,
                "error": run_err, "prefix_unique": unique, "queue": queue}
    e["result"] = per[obj]
    e["upstream"] = {o: {k: v for k, v in per[o].items() if k != "samples"} for o in objects if o != obj}
    reasons = verdict_of(e)
    if status not in PASSING_RUN:
        reasons.insert(0, f"run status {status}" + (" (timed out)" if not final else ""))
    if not unique:
        reasons.insert(0, f"prefix {prefix} was also used on the other instance")
    e.update(verdict="PASS" if not reasons else "FAIL", reason="; ".join(reasons) or None)
    log(f"{scenario}: run {run_id} prefix {prefix} {status} -> {e['verdict']}"
        + (f" ({e['reason']})" if e["reason"] else ""))
    return e


def new_stamp(target, obj, fmt_name):
    """yymmddHHMM for a scenario name that does not exist yet (every test gets a
    new scenario; a rerun within the same minute waits for the next minute)."""
    tag = "HDR" if fmt_name == "header" else "FBDI"
    while True:
        stamp = datetime.datetime.now().strftime("%y%m%d%H%M")
        con = cp._oracle(target)
        try:
            cur = con.cursor()
            cur.execute("SELECT COUNT(*) FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME = :n",
                        n=f"UPL-{tag}-{obj}-{stamp}")
            taken = cur.fetchone()[0]
        finally:
            con.close()
        if not taken:
            return stamp
        time.sleep(61 - datetime.datetime.now().second)


# ---------------------------------------------------------------- report
def write_outputs(args, results, meta):
    payload = dict(meta, finished_at=datetime.datetime.now().isoformat(timespec="seconds"),
                   entries=results, ready_for_functional_testing=readiness(results))
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=1, default=str)
    if args.md_out:
        with open(args.md_out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(markdown(payload))


def readiness(results):
    by = {}
    for r in results:
        by.setdefault(r["object"], {})[r["format"]] = r
    out = {}
    for o, f in by.items():
        h, fb = f.get("header"), f.get("fbdi")
        if not h or not fb:
            continue
        if h["verdict"] == "PASS" and fb["verdict"] in ("PASS", "NOT APPLICABLE"):
            out[o] = "yes"
        elif "FAIL" in (h["verdict"], fb["verdict"]):
            out[o] = "no: " + ", ".join(x for x, r in (("header", h), ("FBDI", fb)) if r["verdict"] == "FAIL") \
                     + " failed"
        else:
            out[o] = "not yet: run not done"
    return out


def markdown(p):
    lines = [f"# Upload verification ({p['target']}) - {p['started_at'][:16]}", "",
             f"Backlog #786. Smart Upload (page 25) in a real browser, then a pipeline run per "
             f"object scenario on {p['target']} (console {p['console']}). Baseline data: "
             f"{p['baseline_scenario']} (regression run {p['baseline_run_id']} gives each row's "
             f"expected outcome). Code: {p['git_commit']}.", "",
             "| Object | Format | Upload | Run | GOOD | BAD | Unaccounted | Verdict |",
             "|---|---|---|---|---|---|---|---|"]
    for r in p["entries"]:
        up, run, s = r.get("upload"), r.get("run"), r.get("result")
        if up:
            own = [d for d in up["tables"] if d["object"] == r["object"]]
            ups = [d for d in up["tables"] if d["object"] != r["object"]]
            tabs = ", ".join(f"{d['rows_matching_source']}/{d['rows_in_file']} rows -> {d['stg']}" for d in own)
            if ups:
                n_bad = sum(1 for d in ups if d.get("problem"))
                tabs += (f"; plus {len(ups)} upstream file(s)"
                         + (f", {n_bad} of them failed" if n_bad else ", all OK"))
            upc = ("upload OK" if up["ok"] else "upload FAILED") + f" ({tabs})"
        else:
            upc = "-"
        runc = f"run {run['run_id']}, prefix {run['prefix']}, {run['status']}" if run else "-"
        good = f"GOOD {s['good_loaded']}/{s['good_total']} LOADED" if s else "-"
        bad = f"BAD {s['bad_failed_with_error']}/{s['bad_total']} FAILED with error" if s else "-"
        una = f"unaccounted {s['unaccounted']}" if s else "-"
        verdict = r["verdict"] + (f": {r['reason']}" if r.get("reason") else "")
        lines.append(f"| {r['object']} | {r['format']} | {upc} | {runc} | {good} | {bad} | {una} | "
                     f"{verdict.replace('|', '/')} |")
    rd = p["ready_for_functional_testing"]
    lines += ["", "## Ready for functional testing", "",
              "Header PASS, FBDI PASS or not applicable, and the run PASS.", "",
              "| Object | Ready |", "|---|---|"]
    lines += [f"| {o} | {v} |" for o, v in rd.items()]
    lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Per-object upload test through Smart Upload (backlog #786)")
    ap.add_argument("--target", choices=["atp", "local"], default="atp")
    ap.add_argument("--objects", default="all", help="comma list of object codes, or 'all' (the 27)")
    ap.add_argument("--formats", default="header,fbdi")
    ap.add_argument("--json-out", required=True)
    ap.add_argument("--md-out")
    ap.add_argument("--work-dir", help="where zips and screenshots go (default: a temp folder)")
    ap.add_argument("--timeout-min", type=int, default=120, help="per-run wait limit")
    ap.add_argument("--upload-only", action="store_true", help="upload and check staging; no run")
    ap.add_argument("--skip-done", action="store_true",
                    help="keep entries already in --json-out that have a verdict; run the rest")
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
    cur.execute("SELECT SCENARIO_ID FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME = :n", n=baseline)
    row = cur.fetchone()
    if not row:
        sys.exit(f"baseline scenario {baseline} is not on {args.target}")
    base_sid = row[0]
    needed = sorted({o for ob in objs for o in reg.closure(ob)})
    src_all = {o: source_rows(cur, reg, o, base_sid) for o in needed}
    src_by_seq = {(stg, r["STG_SEQUENCE_ID"]): r for o in needed for stg, rows in src_all[o].items()
                  for r in rows}
    base_run, expected = baseline_expectations(cur, rr, reg, baseline, base_sid)
    con.close()
    git = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"], capture_output=True,
                         text=True).stdout.strip()
    meta = {"target": args.target, "console": cp.console_base(args.target), "baseline_scenario": baseline,
            "baseline_run_id": base_run, "git_commit": git, "work_dir": work,
            "started_at": datetime.datetime.now().isoformat(timespec="seconds")}
    log(f"target {args.target}; baseline {baseline} (run {base_run}); work dir {work}")

    results, priors = [], {}
    if args.skip_done and os.path.exists(args.json_out):
        with open(args.json_out, encoding="utf-8") as fh:
            old = json.load(fh)
        for r in old.get("entries", []):
            if r.get("verdict") == "UPLOAD ONLY" and not args.upload_only:
                priors[(r["object"], r["format"])] = r      # uploaded, not run yet: run it now
            elif r.get("verdict"):
                results.append(r)
        meta["started_at"] = old.get("started_at", meta["started_at"])
    done = {(r["object"], r["format"]) for r in results}
    for obj in objs:
        for f in formats:
            if (obj, f) in done:
                continue
            prior = priors.get((obj, f))
            stamp = None if prior else new_stamp(args.target, obj, f)
            try:
                e = run_entry(args, reg, rr, obj, f, src_all, src_by_seq, expected, stamp, work, prior)
            except SystemExit:
                raise
            except Exception as ex:  # noqa: BLE001 - one object's crash must not stop the rest
                e = {"object": obj, "format": f, "verdict": "FAIL",
                     "reason": f"test error: {type(ex).__name__}: {' '.join(str(ex).split())[:300]}"}
            results.append(e)
            write_outputs(args, results, meta)
    write_outputs(args, results, meta)
    fails = [r for r in results if r["verdict"] == "FAIL"]
    log(f"done: {len(results)} entries, {len(fails)} FAIL")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
