"""Shared read-only BIP ephemeral-data-model relay.

One place for the "run a SELECT against the live Fusion pod through
FBT_BIP_PKG.RUN_DATA_MODEL_EPHEMERAL on ATP queryapp" mechanism, mirroring
scripts/fusion_bip_query.py. Both discovery (find a real reference value on the
TARGET pod) and verification (read base/interface tables) use it.

Read-only only. No writes, no DMT pipeline tables. The BIP data source is
ApplicationDB_FSCM; with hcm_impl credentials it also reaches the HCM base
tables (PER_ALL_PEOPLE_F etc.) -- verified live 2026-07-19 -- so no separate
HCM data source is needed.
"""
import os
import re
import sys
import base64
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conn  # noqa: E402
import oracledb  # noqa: E402


def bip_select(sql, cols, role='fin_impl'):
    """Run one read-only SELECT through the ephemeral BIP relay.

    sql  : a SELECT whose output columns are aliased to the upper-case names in
           `cols` (BIP serializes by tag name).
    cols : list of output column aliases, in order.
    role : Fusion credential role for the relay -- 'fin_impl' (Financials/
           Procurement/Projects), 'scm_impl' (SCM/Items), or 'hcm_impl' (HCM
           base tables). The DB relay itself runs on ATP queryapp as DMT_OWNER.

    Returns a list of dict rows keyed by the aliases.
    """
    user, pwd = conn.fusion_creds(role)
    url = conn.fusion_url()
    elems = "".join(
        f'<element name="{c}" value="{c}" dataType="xsd:string" tagName="{c}"/>'
        for c in cols)
    xdm = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<dataModel xmlns="http://xmlns.oracle.com/oxp/xmlp" version="2.1" '
        'defaultDataSourceRef="ApplicationDB_FSCM">'
        '<dataProperties><property name="include_rowsettag" value="false"/>'
        '<property name="xml_tag_case" value="upper"/></dataProperties>'
        '<dataSets><dataSet name="Q" type="complex">'
        f'<sql dataSourceRef="ApplicationDB_FSCM"><![CDATA[{sql}]]></sql>'
        '</dataSet></dataSets>'
        '<output rootName="DATA_DS" uniqueRowName="false"><nodeList name="data-structure">'
        '<dataStructure tagName="DATA_DS"><group name="G_1" label="G_1" source="Q">'
        f'{elems}</group></dataStructure></nodeList></output>'
        '<eventTriggers/><lexicals/><parameters/><valueSets/><bursting/></dataModel>')

    dbconn = conn.atp_queryapp()
    cur = dbconn.cursor()
    out = cur.var(oracledb.DB_TYPE_CLOB)
    try:
        cur.execute(
            "BEGIN :out:=FBT_BIP_PKG.RUN_DATA_MODEL_EPHEMERAL("
            "p_base_url=>:u,p_username=>:us,p_password=>:p,p_xdm_xml=>:x,p_name=>:n); END;",
            {'u': url, 'us': user, 'p': pwd, 'x': xdm, 'out': out,
             'n': 'GOLDQ_' + uuid.uuid4().hex[:10]})
        lob = out.getvalue()
        s = lob.read() if hasattr(lob, 'read') else str(lob)
    finally:
        cur.close()
        dbconn.close()

    m = re.search(r'<reportBytes>(.*?)</reportBytes>', s, re.S)
    if m:
        xml = base64.b64decode(m.group(1)).decode('utf-8', 'replace')
    else:
        # Some relay configs return the decoded XML directly.
        xml = s
    rows = []
    for grp in re.findall(r'<G_1>(.*?)</G_1>', xml, re.S):
        row = {}
        for c in cols:
            mm = re.search(rf'<{c}>(.*?)</{c}>', grp, re.S)
            row[c] = mm.group(1) if mm else None
        rows.append(row)
    return rows
