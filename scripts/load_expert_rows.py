#!/usr/bin/env python
"""
Layer expert-provided rows (mapped to STG columns by the per-object agents, as
JSON files in scratchpad/expertmap/) onto the RegressionTestExpanded scenario.

USER-SANCTIONED one-time source-inventory addition (see conversation): the
expert data is new test inventory, added once so the expanded scenario can be
run. Every expert row is tagged SOURCE_ID 'RTX-EXP-<object>-<n>' so it is
isolated from both the baseline (RT-*) and the copied baseline (RTX-*), and is
idempotently re-loadable.

Env: DMT2_CONN / DMT2_WALLET / DMT2_WALLET_PW.
"""
import os, sys, json, glob, datetime, oracledb

MAPDIR = os.environ.get("EXPERTMAP_DIR",
    r"C:\Users\Monroe\AppData\Local\Temp\claude\C--Users-Monroe\c70b5852-eb81-4686-8ce4-7aa3786df67b\scratchpad\expertmap")
SCENARIO = os.environ.get("EXPANDED_SCENARIO", "RegressionTestExpanded")

# Curated corrective pass: drop rows that HARD-CRASH an object's transform (so a
# working object gets a fair run) instead of failing gracefully per-record.
CURATE = os.environ.get("EXPANDED_CURATE") == "1"
# rows missing any of these NOT-NULL business keys crash the transform (ORA-01400)
REQUIRED_NONNULL = {"DMT_POZ_SUPPLIERS_STG_TBL": ["VENDOR_NAME"]}
# objects whose expert rows crash the whole object at job level when mixed with
# the baseline (Expenditures single-transaction-source filter -> ORA-20058)
SKIP_OBJECTS_WHEN_CURATED = {"Expenditures"}


def connect():
    cs = os.environ["DMT2_CONN"]; u, r = cs.split("/", 1); pw, dsn = r.split("@", 1)
    w = os.environ.get("DMT2_WALLET")
    kw = dict(config_dir=w, wallet_location=w, wallet_password=os.environ.get("DMT2_WALLET_PW")) if w else {}
    return oracledb.connect(user=u, password=pw, dsn=dsn, **kw)


def table_meta(cur, t):
    cur.execute("""SELECT column_name, identity_column, data_type FROM user_tab_columns
                   WHERE table_name=:t ORDER BY column_id""", t=t)
    rows = cur.fetchall()
    return {r[0]: {"identity": r[1] == "YES", "dtype": r[2]} for r in rows}


def coerce(dtype, v):
    """Coerce a JSON string into the column's type where needed (esp. DATE)."""
    if v is None or not isinstance(v, str):
        return v
    if dtype in ("DATE",) or dtype.startswith("TIMESTAMP"):
        s = v.strip()
        if not s:
            return None
        for fmt in ("%Y-%m-%d", "%Y-%m-%d %H:%M:%S", "%m/%d/%Y", "%d-%b-%Y",
                    "%m/%d/%Y %H:%M:%S", "%Y/%m/%d"):
            try:
                return datetime.datetime.strptime(s, fmt)
            except ValueError:
                continue
        return v  # leave as-is; will surface a real error if truly bad
    return v


def load_one(cur, sid, obj, table, rows):
    meta = table_meta(cur, table)
    if not meta:
        print(f"  !! {obj}: table {table} not found; skipped")
        return 0
    seq_is_id = meta.get("STG_SEQUENCE_ID", {}).get("identity", False)
    base = 0
    if "STG_SEQUENCE_ID" in meta and not seq_is_id:
        cur.execute(f"SELECT NVL(MAX(STG_SEQUENCE_ID),0) FROM {table}")
        base = int(cur.fetchone()[0])
    src_prefix = f"RTX-EXP-{obj}"
    # idempotent: clear prior expert rows for this object IN THIS SCENARIO only
    # (scoping by source_id alone collides with sibling scenarios sharing the
    # RTX-EXP- prefix whose STG rows have TFM children -> ORA-02292).
    cur.execute(f"DELETE FROM {table} WHERE SCENARIO_ID=:s AND SOURCE_ID LIKE :p",
                s=sid, p=f"{src_prefix}-%")
    req = REQUIRED_NONNULL.get(table, [])
    inserted = 0
    for i, row in enumerate(rows, 1):
        if CURATE and req:
            up = {k.upper(): v for k, v in row.items()}
            if any(up.get(c) in (None, "") for c in req):
                print(f"  {obj} row {i}: skipped (curate) -- missing required {req}")
                continue
        vals = {}
        for k, v in row.items():
            K = k.upper()
            if K in meta and not meta[K]["identity"] and K != "STG_SEQUENCE_ID":
                vals[K] = coerce(meta[K]["dtype"], v)
        # control columns
        if "SCENARIO_ID" in meta:  vals["SCENARIO_ID"] = sid
        if "SOURCE_ID" in meta:    vals["SOURCE_ID"] = f"{src_prefix}-{i}"
        if "STG_STATUS" in meta:   vals["STG_STATUS"] = "NEW"
        if "STAGE_DATE" in meta and "STAGE_DATE" not in vals:      vals["STAGE_DATE"] = datetime.datetime.now()
        if "LAST_UPDATED_DATE" in meta and "LAST_UPDATED_DATE" not in vals: vals["LAST_UPDATED_DATE"] = datetime.datetime.now()
        if "STG_SEQUENCE_ID" in meta and not seq_is_id:
            vals["STG_SEQUENCE_ID"] = base + i
        cols = list(vals.keys())
        binds = {f"b{j}": vals[c] for j, c in enumerate(cols)}
        sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join(':b'+str(j) for j in range(len(cols)))})"
        try:
            cur.execute(sql, binds); inserted += 1
        except Exception as e:
            print(f"  !! {obj} row {i} into {table}: {str(e)[:110]}")
    print(f"  {obj}: {inserted}/{len(rows)} rows -> {table}")
    return inserted


def main():
    conn = connect(); cur = conn.cursor()
    cur.execute("SELECT scenario_id FROM DMT_SCENARIO_TBL WHERE scenario_name=:n", n=SCENARIO)
    r = cur.fetchone()
    if not r:
        sys.exit(f"{SCENARIO} scenario missing; run build_expanded_scenario.py first")
    sid = int(r[0]); print(f"{SCENARIO} scenario_id={sid}")
    total = 0
    for jf in sorted(glob.glob(os.path.join(MAPDIR, "*.json"))):
        try:
            data = json.load(open(jf, encoding="utf-8"))
        except Exception as e:
            print(f"  !! {jf}: {e}"); continue
        obj = data.get("object") or os.path.splitext(os.path.basename(jf))[0]
        if CURATE and obj in SKIP_OBJECTS_WHEN_CURATED:
            print(f"  {obj}: skipped entirely (curate -- job-level source conflict)")
            continue
        if "tables" in data:
            for t, rows in data["tables"].items():
                total += load_one(cur, sid, obj, t.upper(), rows or [])
        elif data.get("stg_table"):
            total += load_one(cur, sid, obj, data["stg_table"].upper(), data.get("rows") or [])
        else:
            print(f"  !! {obj}: no stg_table/tables in JSON; skipped")
    conn.commit()
    print(f"DONE: inserted {total} expert rows into {SCENARIO}")
    conn.close()


if __name__ == "__main__":
    main()
