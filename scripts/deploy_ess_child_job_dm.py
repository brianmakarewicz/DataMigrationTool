#!/usr/bin/env python
"""Dev/test shim: deploy the common ESS child-job data model to /Custom/DMT2/common
via the DB's own DMT_BIP_DEPLOY_PKG (git-first: reads the committed .xdm file),
then optionally run a parametrized runReport self-test.

No pipeline logic here -- deployment + verification only. The catalog write and
the /Custom/DMT2 folder guard are enforced server-side by the PL/SQL package.

Usage:
    python scripts/deploy_ess_child_job_dm.py            # deploy DM only
    python scripts/deploy_ess_child_job_dm.py --test     # deploy + parametrized runReport self-test
"""
import os, re, sys
import oracledb

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
XDM_PATH = os.path.join(REPO, "bip", "common", "DMT_ESS_CHILD_JOB_DM.xdm")
FOLDER = "/Custom/DMT2/common"
DM_NAME = "DMT_ESS_CHILD_JOB_DM"
RPT_PATH = "/Custom/DMT2/common/DMT_ESS_CHILD_JOB_RPT.xdo"
JOB_DEF = "ItemImportJobDef"
DEFAULT_CONN = "dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1"


def connect():
    m = re.match(r"^([^/]+)/(.+)@(?://)?(.+)$", os.environ.get("DMT2_CONN", DEFAULT_CONN))
    u, p, dsn = m.groups()
    return oracledb.connect(user=u, password=p, dsn=dsn)


def run_report(cur, load_ess, batch_id):
    """Call runReport exactly as get_import_ess_id does, via the DB SOAP helper."""
    plsql = r"""
DECLARE
  l_base VARCHAR2(500) := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'),'/');
  l_u VARCHAR2(100) := DMT_UTIL_PKG.GET_CONFIG('BIP_USERNAME');
  l_p VARCHAR2(100) := DMT_UTIL_PKG.GET_CONFIG('BIP_PASSWORD');
  l_url VARCHAR2(500); l_env CLOB; l_r CLOB; l_bb VARCHAR2(32767);
  l_x VARCHAR2(4000);
BEGIN
  l_url := l_base || '/xmlpserver/services/v2/ReportService';
  DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
  DBMS_LOB.APPEND(l_env, TO_CLOB(
    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">'
    ||'<soapenv:Header/><soapenv:Body><v2:runReport><v2:reportRequest>'
    ||'<v2:reportAbsolutePath>'||:rpt||'</v2:reportAbsolutePath>'
    ||'<v2:attributeFormat>xml</v2:attributeFormat>'
    ||'<v2:parameterNameValues><v2:listOfParamNameValues>'
    ||'<v2:item><v2:name>P_LOAD_ESS_ID</v2:name><v2:values><v2:item>'||:load||'</v2:item></v2:values></v2:item>'
    ||'<v2:item><v2:name>P_JOB_DEF</v2:name><v2:values><v2:item>'||:jdef||'</v2:item></v2:values></v2:item>'
    ||'<v2:item><v2:name>P_BATCH_ID</v2:name><v2:values><v2:item>'||:batch||'</v2:item></v2:values></v2:item>'
    ||'</v2:listOfParamNameValues></v2:parameterNameValues>'
    ||'<v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload></v2:reportRequest>'
    ||'<v2:userID>'||l_u||'</v2:userID><v2:password>'||l_p||'</v2:password>'
    ||'</v2:runReport></soapenv:Body></soapenv:Envelope>'));
  l_r := DMT_BIP_DEPLOY_PKG.SOAP_POST(l_url,
           'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest', l_env);
  IF INSTR(l_r,'Fault') > 0 THEN :out := 'FAULT: '||SUBSTR(l_r,1,400); RETURN; END IF;
  DECLARE
    s INTEGER := DBMS_LOB.INSTR(l_r,'<reportBytes>');
    e INTEGER;
  BEGIN
    IF s = 0 THEN :out := 'NO_BYTES: '||SUBSTR(l_r,1,300); RETURN; END IF;
    s := s + LENGTH('<reportBytes>');
    e := DBMS_LOB.INSTR(l_r,'</reportBytes>',s);
    l_bb := DBMS_LOB.SUBSTR(l_r, e - s, s);
  END;
  l_x := UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(l_bb)));
  :out := NVL(REGEXP_SUBSTR(l_x,'<REQUESTID>(\d+)</REQUESTID>',1,1,NULL,1),
              '(none) raw='||SUBSTR(l_x,1,200));
END;
"""
    out = cur.var(oracledb.STRING)
    cur.execute(plsql, {"rpt": RPT_PATH, "load": str(load_ess), "jdef": JOB_DEF,
                        "batch": str(batch_id), "out": out})
    return out.getvalue()


def main():
    do_test = "--test" in sys.argv
    xdm = open(XDM_PATH, "r", encoding="utf-8").read()
    conn = connect(); cur = conn.cursor()
    # Deploy the DM + its XML-output report wrapper together (single sanctioned
    # call; deletes prior versions, redeploys both so the report re-surfaces the
    # DM's parameters including the new P_BATCH_ID). Report name matches the path
    # get_import_ess_id calls: DMT_ESS_CHILD_JOB_RPT.xdo.
    cur.execute("""BEGIN DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT(
                       p_folder=>:f, p_dm_name=>:dm, p_rpt_name=>:rpt, p_xdm_xml=>:d); END;""",
                {"f": FOLDER, "dm": DM_NAME, "rpt": "DMT_ESS_CHILD_JOB_RPT", "d": xdm})
    conn.commit()
    print(f"Deployed {FOLDER}/{DM_NAME}.xdm + DMT_ESS_CHILD_JOB_RPT.xdo ({len(xdm)} bytes).")

    if do_test:
        print("\n=== Parametrized runReport self-test (run 351 loads) ===")
        for batch, load in (("8101", "10010820"), ("8102", "10010821")):
            rid = run_report(cur, load, batch)
            print(f"  batch {batch}  load {load}  -> import REQUESTID = {rid}")
        print("=== Backward-compat test (no batch id -> proximity/absparent fallback) ===")
        rid = run_report(cur, "10010820", "")
        print(f"  batch (empty) load 10010820 -> {rid}")
    cur.close(); conn.close()


if __name__ == "__main__":
    main()
