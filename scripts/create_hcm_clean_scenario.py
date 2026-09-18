#!/usr/bin/env python3
"""
create_hcm_clean_scenario.py - build a clean HCM regression scenario.

The default 'RegressionTest' scenario (id 1) accumulated 3x duplicate rows per
worker over repeated seed inserts, which makes the HDL generator emit multiple
lines per person and Fusion rejects them ("multiple data lines for the same
record / WorkRelationship isn't date-effective"). Rather than mutate scenario 1,
this creates a NEW scenario 'RegressionTestHCM' with ONE row per business key,
copied from scenario 1's HCM staging tables (owner decision 2026-09-17: don't
dedup, create a new scenario).

Idempotent: re-running clears the target scenario's rows first and repopulates.

Target: local Docker (DMT2_CONN or default localhost:1523). Dev seed tooling.
"""
import os, re, sys
import oracledb

SRC_SCENARIO = 1
NEW_NAME = 'RegressionTestHCM'

# table -> business-key columns to dedup on (keep one row per key)
TABLES = {
    'DMT_WORKER_STG_TBL':           ['PERSON_NUMBER'],
    'DMT_PERSON_NAME_STG_TBL':      ['PERSON_NUMBER'],
    'DMT_ASSIGNMENT_STG_TBL':       ['PERSON_NUMBER', 'ASSIGNMENT_NUMBER'],
    'DMT_SALARY_STG_TBL':           ['PERSON_NUMBER'],
    'DMT_TALENT_PROF_STG_TBL':      ['PERSON_NUMBER'],
    'DMT_TALENT_PROF_ITEM_STG_TBL': ['PERSON_NUMBER'],
}

def connect():
    cs = os.environ.get('DMT2_CONN', 'dmt_owner/DmtLocal#2026@localhost:1523/FREEPDB1')
    m = re.match(r'^([^/]+)/(.+)@(?://)?(.+)$', cs)
    u, p, dsn = m.groups()
    return oracledb.connect(user=u, password=p, dsn=dsn)

def main():
    c = connect(); cur = c.cursor()

    # 1) scenario row (reuse if present, else create with a fresh id)
    cur.execute("SELECT scenario_id FROM dmt_scenario_tbl WHERE scenario_name=:1", [NEW_NAME])
    row = cur.fetchone()
    if row:
        new_id = row[0]
        print(f"scenario {NEW_NAME} exists (id {new_id}); refreshing")
    else:
        new_id_var = cur.var(oracledb.NUMBER)
        cur.execute("""INSERT INTO dmt_scenario_tbl
              (scenario_name, description, status, created_by, created_date)
              VALUES (:1,:2,'ACTIVE','ci_clean_scenario',SYSDATE)
              RETURNING scenario_id INTO :3""",
              [NEW_NAME, 'Clean HCM regression (one row per key, from scenario 1)', new_id_var])
        new_id = int(new_id_var.getvalue()[0])
        print(f"created scenario {NEW_NAME} = id {new_id}")

    # 2) per table: clear target rows, copy one row per business key from source
    for tbl, keys in TABLES.items():
        cols = [r[0] for r in cur.execute(
            f"SELECT column_name FROM user_tab_columns WHERE table_name=:1 ORDER BY column_id",
            [tbl]).fetchall()]
        if 'SCENARIO_ID' not in cols or 'STG_SEQUENCE_ID' not in cols:
            print(f"  SKIP {tbl} (no scenario/seq column)"); continue

        cur.execute(f"DELETE FROM {tbl} WHERE scenario_id=:1", [new_id])

        # STG_SEQUENCE_ID is a generated-always identity -> omit it (auto-generated).
        # SCENARIO_ID -> the new scenario; everything else copied as-is.
        part = ", ".join(keys)
        ins_cols = [col for col in cols if col != 'STG_SEQUENCE_ID']
        sel = [f"{new_id} AS scenario_id" if col == 'SCENARIO_ID' else col
               for col in ins_cols]
        insert_cols = ", ".join(ins_cols)
        sql = (f"INSERT INTO {tbl} ({insert_cols})\n"
               f"SELECT {', '.join(sel)}\n"
               f"FROM (SELECT * FROM (\n"
               f"        SELECT t.*, ROW_NUMBER() OVER (PARTITION BY {part} "
               f"ORDER BY stg_sequence_id) rn\n"
               f"        FROM {tbl} t WHERE scenario_id={SRC_SCENARIO}) WHERE rn=1)")
        cur.execute(sql)
        n = cur.rowcount
        print(f"  {tbl}: copied {n} clean row(s)")

    c.commit()
    print(f"\nDone. Scenario '{NEW_NAME}' (id {new_id}) ready.")
    print(f"Run:  DMT2_CONN=... python scripts/ci_promote.py test-local --pipelines HCM   "
          f"(after pointing the runner's scenario at {NEW_NAME})")

if __name__ == '__main__':
    main()
