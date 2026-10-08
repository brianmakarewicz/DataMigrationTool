#!/usr/bin/env python
"""Dev/test shim: deploy the common ESS child-job data model (V3) to /Custom/DMT2/common
via the DB's own DMT_BIP_DEPLOY_PKG (git-first: reads the committed .xdm file),
then optionally run a parametrized runReport self-test.

No pipeline logic here -- deployment + verification only. The catalog write and
the /Custom/DMT2 folder guard are enforced server-side by the PL/SQL package.

V2 (2026-10-07) adds P_BATCH_ARG_POS -- which submitted argument of the import
job carries the batch id (Items 1, Requisitions 2). It is deployed under its own
name ALONGSIDE the original DMT_ESS_CHILD_JOB_DM / _RPT, which are never
overwritten (this script no longer deploys V1).

V3 (2026-10-08, backlog #501) adds an optional second argument match
(P_MATCH2_ARG_POS / P_MATCH2_VALUE): ARInvoices matches the business unit id on
argument 1 as well as the transaction source on argument 2. Deployed under its
own name alongside V1 and V2 (neither is overwritten; this script now deploys V3).

Usage:
    python scripts/deploy_ess_child_job_dm.py            # deploy DM only
    python scripts/deploy_ess_child_job_dm.py --test     # deploy + parametrized runReport self-test
"""
import os, re, sys
import oracledb

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
XDM_PATH = os.path.join(REPO, "bip", "common", "DMT_ESS_CHILD_JOB_V3_DM.xdm")
FOLDER = "/Custom/DMT2/common"
DM_NAME = "DMT_ESS_CHILD_JOB_V3_DM"
RPT_NAME = "DMT_ESS_CHILD_JOB_V3_RPT"
RPT_PATH = "/Custom/DMT2/common/DMT_ESS_CHILD_JOB_V3_RPT.xdo"
DEFAULT_CONN = "dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1"


def connect():
    m = re.match(r"^([^/]+)/(.+)@(?://)?(.+)$", os.environ.get("DMT2_CONN", DEFAULT_CONN))
    u, p, dsn = m.groups()
    return oracledb.connect(user=u, password=p, dsn=dsn)


def run_report(cur, load_ess, batch_id, cemli="Items", arg_pos=None):
    """Resolve the import id through the real code path,
    DMT_LOADER_PKG.GET_IMPORT_ESS_ID, which calls this report. (The earlier
    hand-built SOAP self-test used DMT_BIP_DEPLOY_PKG.SOAP_POST, which no longer
    exists.) Only call it for loads whose import already exists -- the function
    polls for up to 15 minutes when nothing matches."""
    return cur.callfunc("DMT_LOADER_PKG.GET_IMPORT_ESS_ID", str,
                        keyword_parameters={"p_run_id": None, "p_cemli_code": cemli,
                                            "p_load_ess_id": str(load_ess),
                                            "p_batch_id": (str(batch_id) or None),
                                            "p_batch_arg_pos": arg_pos})


def main():
    do_test = "--test" in sys.argv
    xdm = open(XDM_PATH, "r", encoding="utf-8").read()
    conn = connect(); cur = conn.cursor()
    # Deploy the DM + its XML-output report wrapper together (single sanctioned
    # call; deletes prior versions, redeploys both so the report re-surfaces the
    # DM's parameters including the new P_BATCH_ID). Report name matches the path
    # get_import_ess_id calls: DMT_ESS_CHILD_JOB_V3_RPT.xdo.
    cur.execute("""BEGIN DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT(
                       p_folder=>:f, p_dm_name=>:dm, p_rpt_name=>:rpt, p_xdm_xml=>:d); END;""",
                {"f": FOLDER, "dm": DM_NAME, "rpt": RPT_NAME, "d": xdm})
    conn.commit()
    print(f"Deployed {FOLDER}/{DM_NAME}.xdm + {RPT_NAME}.xdo ({len(xdm)} bytes).")

    if do_test:
        print("\n=== Items: batch id is argument 1 (run 351 loads) ===")
        for batch, load in (("8101", "10010820"), ("8102", "10010821")):
            rid = run_report(cur, load, batch)
            print(f"  batch {batch}  load {load}  -> import REQUESTID = {rid}")
        print("=== Requisitions: batch id is argument 2 (run 251 loads; expect 10074973 / 10074977) ===")
        for batch, load in (("7001", "10074966"), ("7002", "10074968")):
            rid = run_report(cur, load, batch, cemli="Requisitions", arg_pos=2)
            print(f"  batch {batch}  load {load}  -> import REQUESTID = {rid}")
        print("=== Backward-compat test (no batch id -> proximity/absparent fallback) ===")
        rid = run_report(cur, "10010820", "")
        print(f"  batch (empty) load 10010820 -> {rid}")
    cur.close(); conn.close()


if __name__ == "__main__":
    main()
