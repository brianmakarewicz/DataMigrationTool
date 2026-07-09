#!/usr/bin/env python
"""
DMT run-detail correctness harness (DB-assertion layer).

Reproduces exactly what the LIVE run-detail UI does and asserts the invariants
it relies on, for a given RUN_ID. Fast, repeatable gate — no browser.

LIVE wiring (verified against app 155 export + deployed DB, 2026-07-01):
  * Page 82 tiles  -> DMT_RUN_DETAIL_TILES reads DMT_WORK_QUEUE_TBL.CEMLI_CODE and
                      drills Page 52 (f?p=:52:) passing P52_INTEGRATION_ID,P52_CEMLI_CODE.
  * Page 52 break  -> inline region cursors DMT_V_CEMLI_TFM_TABLES WHERE CEMLI_CODE=code,
                      builds a per-TFM-table dynamic COUNT (WHEN OTHERS => 0), and drills
                      Page 57 passing the branch DISPLAY_NAME as P57_SUB_OBJECT + status.
                      Emits "No TFM table configuration found for CEMLI: X" when the cursor
                      returns 0 rows (f155:60679).
  * Page 57 list   -> DMT_RECORD_DETAIL_V filtered INTEGRATION_ID(=run_id)+SUB_OBJECT[+status].

  IMPORTANT: the PAGE-52 breakdown is driven by DMT_V_CEMLI_TFM_TABLES — NOT
  DMT_OBJECT_DETAIL_V. (DMT_OBJECT_DETAIL_V drives the separate Page 55 and the Page-52
  ESS-job header lookup; it is off the tile path.) APEX inline-region SQL does not appear
  in ALL_DEPENDENCIES, so DMT_V_CEMLI_TFM_TABLES looks unreferenced but is very much live.

Assertions (per RUN_ID):
  A. code-resolves : every DMT_WORK_QUEUE_TBL.CEMLI_CODE returns >=1 DMT_V_CEMLI_TFM_TABLES
                     row (else Page-52 shows "No TFM table configuration found"). Catches the
                     GLBudgets/PayrollRels short-dispatch-code leak.                     [C1]
  B. drill-integrity: for every Page-52 breakdown (code, display_name) with rows, Page 57
                     (DMT_RECORD_DETAIL_V keyed on run+sub_object, exactly as the UI filters)
                     returns the SAME per-status counts. Missing label = broken drill (C3);
                     count>list = phantom / missing parent filter (C2).                [C2/C3]
  C. loaded&failed : every object at WORK_STATUS=DONE has >=1 record and >=1 LOADED;
                     DONE-with-zero is a RULE#1 violation. FAILED==0 warns.              [C7]
  D. one-row (2nd) : DMT_OBJECT_DETAIL_V returns exactly ONE row per (run, code, sub_object).
                     Guards the join fan-out fixed in that view (Page 55 + ESS lookup).
                     Secondary — not the user's page.                              [fan-out]
  E. catalog health: every DMT_V_CEMLI_TFM_TABLES row's table + status column exists
                     (via DMT_V_CATALOG_HEALTH). Data-independent — catches a broken
                     catalog row that the page-52 region would silently show as 0.   [C4]

Usage:  python dmt_run_assert.py [RUN_ID]   (default 113)
Exit 0 = all hard assertions pass, 1 = one or more failed.
"""
import sys
sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import connect_atp

RUN_ID = int(sys.argv[1]) if len(sys.argv) > 1 else 113
conn = connect_atp('queryapp', 'DMT_OWNER')
cur = conn.cursor()
fails, warns = [], []

print(f"\n{'='*70}\nDMT run-detail assertions — RUN_ID={RUN_ID}\n{'='*70}")

# ---- page-52 catalog: code -> [ (tfm_table, display_name, status_col, row_filter) ] ----
cur.execute("""SELECT cemli_code, tfm_table, display_name, status_column, row_filter, sort_order
               FROM DMT_V_CEMLI_TFM_TABLES ORDER BY cemli_code, sort_order""")
catalog = {}
for code, tbl, disp, col, filt, so in cur.fetchall():
    catalog.setdefault(code, []).append((tbl, disp, col, filt))

cur.execute("SELECT DISTINCT cemli_code FROM DMT_WORK_QUEUE_TBL WHERE run_id=:1", [RUN_ID])
queue_codes = sorted(r[0] for r in cur.fetchall())

# ================= A. code-resolves (C1) =================
unresolved = [c for c in queue_codes if c not in catalog]
print(f"\n[A] code-resolves: {len(queue_codes)} tile codes; {len(unresolved)} with no page-52 config")
for c in unresolved:
    fails.append(f"A/C1: tile code '{c}' has no DMT_V_CEMLI_TFM_TABLES row -> 'No TFM table configuration found for CEMLI: {c}'")
    print(f"    FAIL  {c}: 'No TFM table configuration found for CEMLI: {c}'")
if not unresolved:
    print("    OK    every tile code resolves to a page-52 config")

# ---- helpers replicating the live regions ----
def page52(code):
    """Page-52 region: per-TFM-table dynamic count with WHEN OTHERS => 0.
       Returns {display_name: {LOADED:n, FAILED:n, TOTAL:n}}."""
    out = {}
    for tbl, disp, col, filt in catalog.get(code, []):
        sql = (f"SELECT NVL(SUM(CASE WHEN {col}='LOADED' THEN 1 ELSE 0 END),0), "
               f"NVL(SUM(CASE WHEN {col}='FAILED' THEN 1 ELSE 0 END),0), COUNT(*) "
               f"FROM DMT_OWNER.{tbl} WHERE RUN_ID=:1")
        if filt:
            sql += " AND " + filt
        try:
            cur.execute(sql, [RUN_ID]); l, f, t = cur.fetchone()
            out[disp] = {'LOADED': int(l), 'FAILED': int(f), 'TOTAL': int(t)}
        except Exception as e:
            fails.append(f"C4: page-52 count errored (silently zeroed in UI) for {code}/{disp}: {str(e)[:70]}")
            out[disp] = {'__ERR__': 1}
    return out

def page57(sub):
    """Page-57 list: DMT_RECORD_DETAIL_V keyed on run+sub_object (NOT code)."""
    cur.execute("""SELECT tfm_status, COUNT(*) FROM DMT_RECORD_DETAIL_V
                   WHERE run_id=:1 AND sub_object=:2 GROUP BY tfm_status""", [RUN_ID, sub])
    d = {st: n for st, n in cur.fetchall()}
    return {'LOADED': d.get('LOADED', 0), 'FAILED': d.get('FAILED', 0),
            'TOTAL': sum(d.values())}

# labels the record view can ever emit (to distinguish label-drift from count-drift)
cur.execute("SELECT DISTINCT sub_object FROM DMT_RECORD_DETAIL_V")
known_subs = {r[0] for r in cur.fetchall()}

# ================= B. drill-integrity (C2/C3) =================
print(f"\n[B] drill-integrity: Page-52 breakdown count == the Page-57 list it opens")
broken = 0
for code in queue_codes:
    if code not in catalog:
        continue
    for disp, bmap in page52(code).items():
        if '__ERR__' in bmap or bmap['TOTAL'] == 0:
            continue
        r = page57(disp)
        if bmap != r:
            broken += 1
            if disp not in known_subs:
                kind = "C3 label drift: drill label absent from record view -> empty drill"
            else:
                kind = "C2 count/filter: label exists, counts differ"
            fails.append(f"B: {code}/'{disp}' page52 {bmap} vs page57 {r} [{kind}]")
            print(f"    FAIL  {code} / '{disp}': page52={bmap}  page57={r}  [{kind}]")
if not broken:
    print("    OK    every non-empty breakdown row opens a matching Page-57 list")

# ================= C. loaded&failed / no DONE-with-zero (C7) =================
print(f"\n[C] loaded&failed per DONE object (RULE#1 / no DONE-with-zero)")
cur.execute("""SELECT cemli_code, MAX(work_status) FROM DMT_WORK_QUEUE_TBL
               WHERE run_id=:1 GROUP BY cemli_code""", [RUN_ID])
qstatus = dict(cur.fetchall())
for code in queue_codes:
    if code not in catalog:
        continue
    loaded = failed = total = 0
    for disp, m in page52(code).items():
        if '__ERR__' in m:
            continue
        loaded += m['LOADED']; failed += m['FAILED']; total += m['TOTAL']
    ws = qstatus.get(code, '')
    if ws == 'DONE' and total == 0:
        fails.append(f"C/C7: {code} is DONE with 0 records (RULE#1 violation)")
        print(f"    FAIL  {code}: DONE but 0 records")
    elif total > 0 and loaded == 0:
        fails.append(f"C: {code} has {total} records but 0 LOADED (nothing reached Fusion)")
        print(f"    FAIL  {code}: {total} records, 0 LOADED, {failed} FAILED")
    elif total > 0 and failed == 0:
        warns.append(f"C: {code} has no FAILED row (no bad-seed coverage?)")
        print(f"    warn  {code}: {loaded} LOADED, 0 FAILED (no bad seed?)")
    elif total > 0:
        print(f"    OK    {code}: {loaded} LOADED, {failed} FAILED, {total} total")

# ================= D. one-row invariant on DMT_OBJECT_DETAIL_V (secondary) =================
print(f"\n[D] one-row per (run, code, sub_object) in DMT_OBJECT_DETAIL_V  (page-55/ESS guard)")
cur.execute("""SELECT cemli_code, sub_object, COUNT(*) FROM DMT_OBJECT_DETAIL_V
               WHERE run_id=:1 GROUP BY cemli_code, sub_object HAVING COUNT(*)>1""", [RUN_ID])
dupes = cur.fetchall()
for c, s, n in dupes:
    fails.append(f"D/fan-out: DMT_OBJECT_DETAIL_V {c}/'{s}' returns {n} rows (join fan-out)")
    print(f"    FAIL  {c} / '{s}': {n} rows (should be 1)")
if not dupes:
    print("    OK    DMT_OBJECT_DETAIL_V collapses to one row per (code, sub_object)")

# ================= E. catalog health (C4, data-independent) =================
print(f"\n[E] catalog health — every DMT_V_CEMLI_TFM_TABLES row's table + status column exists")
cur.execute("SELECT cemli_code, tfm_table, status_column, issue FROM DMT_V_CATALOG_HEALTH")
health = cur.fetchall()
for code, tbl, col, issue in health:
    fails.append(f"E/C4: {code} -> {tbl}.{col}: {issue} (would show a silent 0 in the page-52 region)")
    print(f"    FAIL  {code}: {tbl}.{col} -> {issue}")
if not health:
    print("    OK    every catalog row resolves to a real table + status column")

# ================= summary =================
print(f"\n{'='*70}")
print(f"RESULT for RUN_ID={RUN_ID}: {len(fails)} failure(s), {len(warns)} warning(s)")
print('='*70)
for x in fails:
    print("  FAIL  " + x)
for w in warns:
    print("  warn  " + w)

cur.close(); conn.close()
sys.exit(1 if fails else 0)
