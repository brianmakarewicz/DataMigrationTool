#!/usr/bin/env python
"""
Build the RegressionTestExpanded scenario = a COPY of every RegressionTest STG
row (SOURCE_ID 'RT-...' -> 'RTX-...', tagged to the new scenario) so the
baseline is never touched. Expert rows are layered on separately by
insert_expanded_expert_data.py using SOURCE_ID 'RTX-EXP-...'.

Idempotent: only ever deletes rows for the expanded scenario / SOURCE_ID
LIKE 'RTX-%'. Never matches 'RT-%'.

Env: DMT2_CONN / DMT2_WALLET / DMT2_WALLET_PW (same as the rest of the toolchain).
"""
import os, sys, oracledb

ORIG_SCENARIO = "RegressionTest"
NEW_SCENARIO  = "RegressionTestExpanded"


def connect():
    cs = os.environ["DMT2_CONN"]
    user, rest = cs.split("/", 1)
    pw, dsn = rest.split("@", 1)
    w = os.environ.get("DMT2_WALLET")
    kw = dict(config_dir=w, wallet_location=w,
              wallet_password=os.environ.get("DMT2_WALLET_PW")) if w else {}
    return oracledb.connect(user=user, password=pw, dsn=dsn, **kw)


def scenario_id(cur, name, create=False):
    if create:
        sid = cur.var(oracledb.NUMBER); err = cur.var(oracledb.STRING)
        cur.execute("""BEGIN DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
                         p_scenario_name=>:n, x_scenario_id=>:sid, x_error_code=>:err); END;""",
                    n=name, sid=sid, err=err)
        v = sid.getvalue()
        return int(v[0] if isinstance(v, list) else v)
    cur.execute("SELECT SCENARIO_ID FROM DMT_SCENARIO_TBL WHERE SCENARIO_NAME=:n", n=name)
    r = cur.fetchone()
    return int(r[0]) if r else None


def stg_tables(cur):
    cur.execute("""SELECT table_name FROM user_tables
                   WHERE table_name LIKE 'DMT!_%!_STG!_TBL' ESCAPE '!' ORDER BY 1""")
    return [r[0] for r in cur.fetchall()]


def cols(cur, t):
    cur.execute("""SELECT column_name, identity_column FROM user_tab_columns
                   WHERE table_name=:t ORDER BY column_id""", t=t)
    return cur.fetchall()


def main():
    conn = connect(); cur = conn.cursor()
    orig = scenario_id(cur, ORIG_SCENARIO)
    if orig is None:
        sys.exit(f"Baseline scenario {ORIG_SCENARIO!r} not found -- run insert_regression_test_data.py first.")
    new = scenario_id(cur, NEW_SCENARIO, create=True)
    print(f"orig scenario_id={orig}  new scenario_id={new}")

    total_copied = 0
    for t in stg_tables(cur):
        cn = cols(cur, t)
        names = [c[0] for c in cn]
        if "SCENARIO_ID" not in names or "SOURCE_ID" not in names:
            continue  # not a scenario-scoped source table
        # idempotent: clear any prior expanded copy for this table
        cur.execute(f"DELETE FROM {t} WHERE SCENARIO_ID=:s OR SOURCE_ID LIKE 'RTX-%'", s=new)
        # STG_SEQUENCE_ID is an identity col on some tables and a plain PK on
        # others. For plain PKs we must mint fresh unique values, so compute a
        # base above the current max and assign base+ROWNUM.
        seq_is_identity = any(name == "STG_SEQUENCE_ID" and is_id == "YES" for name, is_id in cn)
        seq_base = 0
        if not seq_is_identity:
            cur.execute(f"SELECT NVL(MAX(STG_SEQUENCE_ID),0) FROM {t}")
            seq_base = int(cur.fetchone()[0])
        # build column list; override control cols; skip/assign the PK
        sel, ins = [], []
        for name, is_id in cn:
            if name == "STG_SEQUENCE_ID":
                if seq_is_identity:
                    continue  # let identity generate
                ins.append(name); sel.append(f"{seq_base} + ROWNUM")
                continue
            ins.append(name)
            if name == "SCENARIO_ID":
                sel.append(str(new))
            elif name == "SOURCE_ID":
                sel.append("'RTX-'||SUBSTR(SOURCE_ID,4)")  # RT-xxx -> RTX-xxx
            elif name == "STG_STATUS":
                sel.append("'NEW'")
            else:
                sel.append(name)
        sql = (f"INSERT INTO {t} ({', '.join(ins)}) "
               f"SELECT {', '.join(sel)} FROM {t} WHERE SCENARIO_ID=:orig")
        cur.execute(sql, orig=orig)
        n = cur.rowcount
        if n:
            print(f"  {t}: copied {n}")
            total_copied += n
    conn.commit()
    print(f"DONE: copied {total_copied} STG rows into scenario {NEW_SCENARIO} (id {new})")
    conn.close()


if __name__ == "__main__":
    main()
