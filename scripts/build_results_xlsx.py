#!/usr/bin/env python
"""
Update the expert 'Data Migration Objects.xlsx' with the expanded-run results and
reconcile its object list against our master DMT2_object_list.xlsx.

Adds columns: Records Added, Records In Expert File, Records Successful,
Value-Add Summary, Corrections Made, Still-Stuck (params + Job ID).

Env: DMT2_CONN / DMT2_WALLET / DMT2_WALLET_PW.  Args: <corrective_scenario_name>
"""
import os, sys, json, glob, shutil, oracledb, openpyxl
from openpyxl.styles import Font, PatternFill, Alignment

SC = r"C:\Users\Monroe\AppData\Local\Temp\claude\C--Users-Monroe\c70b5852-eb81-4686-8ce4-7aa3786df67b\scratchpad"
EXPERT_XLSX = os.path.join(SC, "expert", "Data Migration Objects.xlsx")
MASTER_XLSX = r"C:\Users\Monroe\DMT2_object_list.xlsx"
OUT_XLSX    = os.path.join(SC, "Data Migration Objects - RESULTS.xlsx")
CORR_SCEN   = sys.argv[1] if len(sys.argv) > 1 else open("/tmp/corrective_scenario.txt").read().strip()

# expert-sheet object label -> DMT2 cemli code(s)
NORM = {
    "suppliers": ["Suppliers"], "supplieraddresses": ["SupplierAddresses"],
    "suppliersites": ["SupplierSites"], "suppliersiteassignments": ["SupplierSiteAssignments"],
    "suppliersiteassignment": ["SupplierSiteAssignments"], "suppliercontacts": ["SupplierContacts"],
    "categories": ["ItemCategories"], "purchaseorders": ["PurchaseOrders"],
    "blanket purchase agreements": ["BlanketPOs"], "contract purchase agreements": ["Contracts"],
    "requisitions": ["Requisitions"], "apinvoices": ["APInvoices"], "arinvoices": ["ARInvoices"],
    "miscreceipts (receivables)": ["MiscReceipts"], "customers": ["Customers"],
    "glbalances": ["GLBalances"], "glbudgets": ["GLBudgets"], "assets": ["Assets"],
    "projects": ["Projects"], "expenditures": ["Expenditures"], "projectbudgets": ["ProjectBudgets"],
    "billingevents": ["BillingEvents"], "grants - awards": ["Grants"], "items": ["Items"],
}
# our expert_summary.json object key -> cemli codes (SupplierFamily fans out)
SUMMARY_TO_CEMLI = {
    "SupplierFamily": ["SupplierAddresses", "SupplierSites", "SupplierSiteAssignments"],
}


def connect():
    cs = os.environ["DMT2_CONN"]; u, r = cs.split("/", 1); pw, dsn = r.split("@", 1)
    w = os.environ.get("DMT2_WALLET")
    return oracledb.connect(user=u, password=pw, dsn=dsn, config_dir=w, wallet_location=w,
                            wallet_password=os.environ.get("DMT2_WALLET_PW"))


def run_rollup(cur, scen):
    cur.execute("""SELECT o.cemli_code, NVL(SUM(o.loaded_rows),0), NVL(SUM(o.failed_rows),0), NVL(SUM(o.total_rows),0), MAX(o.run_id)
                   FROM dmt_object_detail_v o
                   JOIN dmt_pipeline_run_tbl r ON r.run_id=o.run_id
                   WHERE r.scenario_name=:s AND o.run_id=(SELECT MAX(run_id) FROM dmt_pipeline_run_tbl WHERE scenario_name=:s)
                   GROUP BY o.cemli_code""", s=scen)
    return {r[0]: {"loaded": r[1], "failed": r[2], "total": r[3], "run": r[4]} for r in cur.fetchall()}


def main():
    conn = connect(); cur = conn.cursor()
    corr = run_rollup(cur, CORR_SCEN)
    first = run_rollup(cur, "RegressionTestExpanded")
    run_id = (next(iter(corr.values()))["run"] if corr else "?")
    summ = {d["object"]: d for d in json.load(open(os.path.join(SC, "expert_summary.json"), encoding="utf-8"))}
    # expand SupplierFamily into its cemli members
    per_cemli_expert = {}
    for obj, d in summ.items():
        for code in SUMMARY_TO_CEMLI.get(obj, [obj]):
            per_cemli_expert.setdefault(code, {"mapped": 0, "in_file": 0, "quality": d.get("quality"),
                                               "job": d.get("ess_job_id"), "params": d.get("params"),
                                               "notes": d.get("notes")})
            per_cemli_expert[code]["mapped"] += d.get("mapped", 0) if "mapped" in d else 0

    wb = openpyxl.load_workbook(EXPERT_XLSX)
    ws = wb[wb.sheetnames[0]]
    hdr = [ (c.value or "") for c in ws[1] ]
    oi = next((i for i, h in enumerate(hdr) if str(h).strip().lower() == "object"), 0)
    newcols = ["Records Added (expanded run)", "Records Successful (LOADED)",
               "Value-Add Summary", "Corrections Made", "Still-Stuck (params / Job ID)"]
    start = len(hdr)
    for j, name in enumerate(newcols):
        c = ws.cell(row=1, column=start + j + 1, value=name)
        c.font = Font(bold=True); c.fill = PatternFill("solid", fgColor="1F4E78")
        c.font = Font(bold=True, color="FFFFFF")
    # master object set for reconciliation
    mwb = openpyxl.load_workbook(MASTER_XLSX, read_only=True, data_only=True); mws = mwb[mwb.sheetnames[0]]
    mrows = list(mws.iter_rows(values_only=True)); mhdr = [str(c).strip() if c else "" for c in mrows[0]]
    moi = next((i for i, h in enumerate(mhdr) if h.lower() == "object"), 1)
    master_objs = [str(r[moi]).strip() for r in mrows[1:] if moi < len(r) and r[moi]]
    master_norm = {m.lower() for m in master_objs}

    expert_labels = []
    for row in range(2, ws.max_row + 1):
        label = ws.cell(row=row, column=oi + 1).value
        if not label or not str(label).strip():
            continue
        label = str(label).strip(); expert_labels.append(label)
        codes = NORM.get(label.lower(), [])
        added = sum(per_cemli_expert.get(c, {}).get("mapped", 0) for c in codes)
        loaded = sum(corr.get(c, {}).get("loaded", 0) for c in codes)
        total = sum(corr.get(c, {}).get("total", 0) for c in codes)
        # value-add / stuck text
        q = next((per_cemli_expert.get(c, {}).get("quality") for c in codes if c in per_cemli_expert), None)
        job = next((per_cemli_expert.get(c, {}).get("job") for c in codes if per_cemli_expert.get(c, {}).get("job")), None)
        params = next((per_cemli_expert.get(c, {}).get("params") for c in codes if per_cemli_expert.get(c, {}).get("params")), None)
        va = corr_txt = stuck = ""
        if not codes:
            va = "Not a DMT2 pipeline object (no entry on our sheet / not staged)."
        elif added == 0:
            va = "No expert rows ingested this pass."
        else:
            va = f"{added} expert row(s) ingested (quality={q}). "
            if loaded > 0:
                va += f"{loaded} reached Fusion base tables."
            else:
                va += "0 reached base tables (see Still-Stuck)."
        if loaded == 0 and total and codes:
            stuck = f"0/{total} loaded in run {run_id}. "
            if job: stuck += f"expert ESS Job {job}. "
            if params: stuck += f"params: {json.dumps(params)[:120]}"
        ws.cell(row=row, column=start + 1, value=added)
        ws.cell(row=row, column=start + 2, value=loaded)
        ws.cell(row=row, column=start + 3, value=va)
        ws.cell(row=row, column=start + 4, value=corr_txt)
        ws.cell(row=row, column=start + 5, value=stuck)
        # flag expert-only objects with no master entry
        if label.lower() not in master_norm and not codes:
            ws.cell(row=row, column=start + 3).value = "NO ENTRY ON OUR MASTER SHEET. " + (va or "")

    # append master objects the expert sheet is missing (normalize both directions)
    expert_norm = set()
    for lbl in expert_labels:
        expert_norm.add(lbl.lower())
        for c in NORM.get(lbl.lower(), []): expert_norm.add(c.lower())
    missing = [m for m in master_objs if m.lower() not in expert_norm]
    r = ws.max_row + 2
    ws.cell(row=r, column=1, value="--- OBJECTS ON OUR MASTER SHEET MISSING FROM THIS EXPERT SHEET (add next pass) ---").font = Font(bold=True, color="C00000")
    for m in missing:
        r += 1; ws.cell(row=r, column=1, value=m)
        ws.cell(row=r, column=start + 3, value="On DMT2_object_list.xlsx but absent here; added for the experts' next pass.")

    wb.save(OUT_XLSX)
    print(f"corrective run_id={run_id}; wrote {OUT_XLSX}")
    print(f"expert-only (no master entry): {[l for l in expert_labels if l.lower() not in master_norm and not NORM.get(l.lower())][:40]}")
    print(f"master-only (added to expert sheet): {missing}")
    conn.close()


if __name__ == "__main__":
    main()
