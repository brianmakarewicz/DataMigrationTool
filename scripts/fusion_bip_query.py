#!/usr/bin/env python
"""Ad-hoc Fusion query via BIP ephemeral data model (read-only).

Runs arbitrary SELECT SQL against the live Fusion instance through the
APEX_QUERY_APP BIP helper on ATP queryapp (FBT_BIP_PKG.RUN_DATA_MODEL_EPHEMERAL),
and prints the decoded rows. Use for discovery: find a real good record to mimic,
inspect interface/base tables, validate reference data.

Usage:
    python scripts/fusion_bip_query.py --cred fin_impl --cols A,B,C "SELECT a,b,c FROM t WHERE ..."

Notes:
  - --cred: fin_impl (Financials/Projects/Procurement tables via ApplicationDB_FSCM)
            or scm_impl (SCM/Item tables). Default fin_impl.
  - --cols: comma-separated OUTPUT column aliases, in order, matching the SELECT.
            Column aliases must be simple upper-case identifiers (alias them in SQL).
  - SQL is read-only. No trailing semicolon needed.
  - Returns at most what BIP will serialize; keep result sets small (add WHERE/ROWNUM).
"""
import sys, os, base64, re, argparse, uuid
sys.path.insert(0, r'C:\Users\Monroe\workspace')
from conn_helper import connect_atp, get_fusion_url, get_fusion_user
import oracledb

def run(sql, cols, cred='fin_impl'):
    url = get_fusion_url()
    usr, pwd = get_fusion_user(cred)
    elems = "".join(f'<element name="{c}" value="{c}" dataType="xsd:string" tagName="{c}"/>' for c in cols)
    xdm = f'''<?xml version="1.0" encoding="utf-8"?>
<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" defaultDataSourceRef="ApplicationDB_FSCM">
<dataProperties><property name="include_rowsettag" value="false"/><property name="xml_tag_case" value="upper"/></dataProperties>
<dataSets><dataSet name="Q" type="complex"><sql dataSourceRef="ApplicationDB_FSCM"><![CDATA[{sql}]]></sql></dataSet></dataSets>
<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure"><dataStructure tagName="DATA_DS"><group name="G_1" label="G_1" source="Q">{elems}</group></dataStructure></nodeList></output>
<eventTriggers/><lexicals/><parameters/><valueSets/><bursting/></dataModel>'''
    conn = connect_atp('queryapp', 'DMT_OWNER'); cur = conn.cursor()
    out = cur.var(oracledb.DB_TYPE_CLOB)
    try:
        cur.execute("BEGIN :out:=FBT_BIP_PKG.RUN_DATA_MODEL_EPHEMERAL(p_base_url=>:u,p_username=>:us,p_password=>:p,p_xdm_xml=>:x,p_name=>:n); END;",
                    {'u': url, 'us': usr, 'p': pwd, 'x': xdm, 'out': out,
                     'n': 'ADHOCQ_' + uuid.uuid4().hex[:10]})
        lob = out.getvalue(); s = lob.read() if hasattr(lob, 'read') else str(lob)
        m = re.search(r'<reportBytes>(.*?)</reportBytes>', s, re.S)
        if m:
            print(base64.b64decode(m.group(1)).decode('utf-8', 'replace'))
        else:
            print(s[:2000])
    finally:
        cur.close(); conn.close()

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--cred', default='fin_impl')
    ap.add_argument('--cols', required=True, help='comma-separated output column aliases in SELECT order')
    ap.add_argument('sql')
    a = ap.parse_args()
    run(a.sql, [c.strip() for c in a.cols.split(',')], a.cred)
