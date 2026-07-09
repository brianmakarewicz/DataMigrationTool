#!/bin/sh
# ============================================================
# test_projects_golden.sh — golden-file byte compare for the
# Projects FBDI generator.
#
# Projects is ONE object whose single FBDI zip carries four
# record-type CSVs (PjfProjectsAllXface, PjfProjElementsXface,
# PjfProjectPartiesInt, PjcTxnControlsStage) — like
# PurchaseOrders, not a family of separate objects. One
# GENERATE_FBDI call produces the one zip; compare_fbdi.py
# compares all four members against the run-116 golden.
#
# Pipeline exercised, all via the packages' own APIs on the
# local Docker DB (dmt2-local, port 1523):
#   1. Land the four test/golden/inputs/Project*_input.csv files
#      into DMT_CSV_LANDING_TBL and load them to the four STG
#      tables via DMT_CSV_LOADER_PKG.LOAD_CSV (scenario-mandatory).
#   2. Create ONE run row + prefix via DMT_PIPELINE_INIT_PKG.INIT_RUN
#      (the golden comes from one old-stack run: 116 / 9627).
#   3. DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_* for all four record types.
#   4. The single DMT_PROJECT_FBDI_GEN_PKG.GENERATE_FBDI call.
#   5. Extract the zip from DMT_FBDI_ZIP_TBL (base64 over
#      dbms_output) and byte-compare against the run-116 golden
#      with compare_fbdi.py + normalization_map.json.
#
# Input provenance: the rows reproduce the old stack's Projects
# regression rows (ConversionTool/scripts/insert_regression_test_data.py
# sections 23-26) — the exact data behind the run-116 golden.
#
# DELIBERATE: the upstream validator (DMT_PROJECT_VALIDATOR_PKG)
# is NOT called here. The run-116 golden predates the pre-
# validation ordering fix, so the BAD project (missing org) and
# the orphan task (non-existent project) ARE in the golden files;
# offline, no parent can be LOADED anyway (LOADED requires a
# Fusion load — phase 2). The validator's contract is proven in
# test/unit/test_projects.sql.
#
# Usage:  sh test/golden/test_projects_golden.sh
# Env overrides: DMT2_CONN, SQLCL, JAVA_HOME, PYTHON
# Exit 0 only if the compare verdict is byte-identical after the
# declared normalization.
# ============================================================

set -u

JAVA_HOME="${JAVA_HOME:-/c/Users/Monroe/tools/jdk-21.0.11+10}"
export JAVA_HOME
PATH="$JAVA_HOME/bin:$PATH"
export PATH

SQLCL="${SQLCL:-/c/Users/Monroe/tools/sqlcl/bin/sql}"
PYTHON="${PYTHON:-python}"
DMT2_CONN="${DMT2_CONN:-dmt_owner/DmtLocal#2026@//localhost:1523/FREEPDB1}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MAP_JSON="$SCRIPT_DIR/normalization_map.json"

WORK_DIR="${TMPDIR:-/tmp}/dmt2_golden_projects"
mkdir -p "$WORK_DIR"
SQL_FILE="$WORK_DIR/run_projects.sql"
LOG_FILE="$WORK_DIR/run_projects.log"

fail () {
    echo "FAIL  test_projects_golden.sh  ($1)  [log: $LOG_FILE]"
    exit 1
}

for f in Projects ProjectTasks ProjectTeamMembers ProjectTxnControls; do
    [ -f "$SCRIPT_DIR/inputs/${f}_input.csv" ] || fail "missing input CSV inputs/${f}_input.csv"
done

CSV_PRJ=$(cat "$SCRIPT_DIR/inputs/Projects_input.csv")            || fail "read Projects input"
CSV_TSK=$(cat "$SCRIPT_DIR/inputs/ProjectTasks_input.csv")        || fail "read Tasks input"
CSV_TM=$(cat  "$SCRIPT_DIR/inputs/ProjectTeamMembers_input.csv")  || fail "read TeamMembers input"
CSV_TC=$(cat  "$SCRIPT_DIR/inputs/ProjectTxnControls_input.csv")  || fail "read TxnControls input"

# ------------------------------------------------------------
# Build the SQL driver. Scenario GOLDEN_PRJ_SCN scopes every row
# we create; cleanup at start keeps reruns stable (STG rows are
# never status-reset — each rerun lands fresh rows + a new run).
# ------------------------------------------------------------
cat > "$SQL_FILE" <<EOF
whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off
set linesize 32767
set trimout on

-- Pre-clean residue from earlier runs (scenario-scoped; TFM first for FKs)
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'GOLDEN_PRJ_SCN';
    if l_scn is not null then
        delete from dmt_pjf_projects_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_projects_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_tasks_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_tasks_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_team_members_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjf_team_members_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjc_txn_controls_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_pjc_txn_controls_stg_tbl where scenario_id = l_scn);
        delete from dmt_pjf_projects_stg_tbl     where scenario_id = l_scn;
        delete from dmt_pjf_tasks_stg_tbl         where scenario_id = l_scn;
        delete from dmt_pjf_team_members_stg_tbl  where scenario_id = l_scn;
        delete from dmt_pjc_txn_controls_stg_tbl  where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'GOLDEN_PRJ%';
    commit;
end;
/

-- 1. Land + load all four input CSVs through DMT_CSV_LOADER_PKG
declare
    procedure land_one (p_batch varchar2, p_table varchar2, p_file varchar2, p_csv clob) is
        l_id     number;
        l_status varchar2(30);
        l_err    clob;
    begin
        insert into dmt_csv_landing_tbl
            (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
        values
            (p_batch, p_batch || '_VIEW', p_table, p_file, p_csv, 'GOLDEN_PRJ_SCN')
        returning csv_landing_id into l_id;
        commit;

        dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);

        select status, error_text into l_status, l_err
        from   dmt_csv_landing_tbl where csv_landing_id = l_id;
        if l_status <> 'LOADED' then
            raise_application_error(-20999,
                p_batch || ' CSV load failed (' || l_status || '): ' ||
                dbms_lob.substr(l_err, 3000, 1));
        end if;
        dbms_output.put_line('LOADED_OK:' || p_batch);
    end land_one;
begin
    land_one('GOLDEN_PRJ_1', 'DMT_PJF_PROJECTS_STG_TBL',     'Projects_input.csv',            to_clob(q'[${CSV_PRJ}]'));
    land_one('GOLDEN_PRJ_2', 'DMT_PJF_TASKS_STG_TBL',        'ProjectTasks_input.csv',        to_clob(q'[${CSV_TSK}]'));
    land_one('GOLDEN_PRJ_3', 'DMT_PJF_TEAM_MEMBERS_STG_TBL', 'ProjectTeamMembers_input.csv',  to_clob(q'[${CSV_TM}]'));
    land_one('GOLDEN_PRJ_4', 'DMT_PJC_TXN_CONTROLS_STG_TBL', 'ProjectTxnControls_input.csv',  to_clob(q'[${CSV_TC}]'));
end;
/

-- 2-4. One run row via INIT_RUN; transform all four record types;
-- generate the ONE zip; 5. dump the zip as base64.
declare
    l_run     number;
    l_prefix  varchar2(20);
    l_scn     number;
    l_zip     blob;
    l_fn      varchar2(200);
    l_csv_id  number;

    procedure dump_zip (p_object varchar2, p_zip blob) is
        l_len integer;
        l_pos integer := 1;
        l_b64 varchar2(32000);
    begin
        if p_zip is null then
            raise_application_error(-20999,
                p_object || ': GENERATE_FBDI produced no zip (0 STAGED rows?)');
        end if;
        dbms_output.put_line('ZIPSTART:' || p_object);
        l_len := dbms_lob.getlength(p_zip);
        while l_pos <= l_len loop
            l_b64 := utl_raw.cast_to_varchar2(
                         utl_encode.base64_encode(dbms_lob.substr(p_zip, 2400, l_pos)));
            l_b64 := replace(replace(l_b64, chr(13), ''), chr(10), '');
            dbms_output.put_line('B64:' || l_b64);
            l_pos := l_pos + 2400;
        end loop;
        dbms_output.put_line('ZIPEND:' || p_object);
    end dump_zip;
begin
    dmt_pipeline_init_pkg.init_run(
        p_orchestration_code => 'Projects',
        p_scenario_name      => 'GOLDEN_PRJ_SCN',
        p_source_filename    => 'Projects_input.csv',
        p_instance_id        => 'GOLDEN_TEST',
        x_integration_id     => l_run,
        x_prefix             => l_prefix);
    if l_prefix is null then
        raise_application_error(-20999, 'INIT_RUN returned no prefix (USE_PREFIX must be Y for tests)');
    end if;

    select scenario_id into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'GOLDEN_PRJ_SCN';

    -- Upstream validator deliberately NOT called — see the header comment.
    dmt_project_transform_pkg.transform_projects(l_run, p_scenario_id => l_scn);
    dmt_project_transform_pkg.transform_tasks(l_run, p_scenario_id => l_scn);
    dmt_project_transform_pkg.transform_team_members(l_run, p_scenario_id => l_scn);
    dmt_project_transform_pkg.transform_txn_controls(l_run, p_scenario_id => l_scn);

    dbms_output.put_line('RUNID:'  || l_run);
    dbms_output.put_line('PREFIX:' || l_prefix);

    dmt_project_fbdi_gen_pkg.generate_fbdi(l_run, l_zip, l_fn, l_csv_id);
    dump_zip('Projects', l_zip);
    commit;
    dbms_output.put_line('ALLZIPSDONE');
end;
/
exit success
EOF

# ------------------------------------------------------------
# Execute
# ------------------------------------------------------------
echo exit | "$SQLCL" -S "$DMT2_CONN" "@$SQL_FILE" > "$LOG_FILE" 2>&1
rc=$?
[ $rc -eq 0 ] || fail "SQL driver exit $rc: $(grep -E 'ORA-|SP2-' "$LOG_FILE" | head -1)"
grep -q '^ALLZIPSDONE' "$LOG_FILE" || fail "zip dump incomplete (no ALLZIPSDONE marker)"

RUN_ID=$(grep '^RUNID:'  "$LOG_FILE" | head -1 | cut -d: -f2 | tr -d '[:space:]')
PREFIX=$(grep '^PREFIX:' "$LOG_FILE" | head -1 | cut -d: -f2 | tr -d '[:space:]')
[ -n "$RUN_ID" ] && [ -n "$PREFIX" ] || fail "could not parse RUN_ID/PREFIX from log"
echo "run_id=$RUN_ID prefix=$PREFIX work_dir=$WORK_DIR"

# ------------------------------------------------------------
# Extract the zip from the log and compare against the golden
# ------------------------------------------------------------
GEN_ZIP="$WORK_DIR/Projects_generated_${RUN_ID}.zip"
sed -n "/^ZIPSTART:Projects\$/,/^ZIPEND:Projects\$/p" "$LOG_FILE" \
    | grep '^B64:' | sed 's/^B64://' | tr -d '\r' | base64 -d > "$GEN_ZIP" \
    || fail "base64 decode of generated zip failed"
[ -s "$GEN_ZIP" ] || fail "generated zip is empty"

"$PYTHON" "$SCRIPT_DIR/compare_fbdi.py" \
    --object Projects \
    --generated "$GEN_ZIP" \
    --map "$MAP_JSON" \
    --prefix "$PREFIX" \
    --run-id "$RUN_ID"
crc=$?
if [ $crc -ne 0 ]; then
    echo "DIFF  Projects: compare exit $crc — generated output differs from golden (see diff above)"
    fail "Projects zip differs from its golden"
fi

echo "PASS  test_projects_golden.sh  (Projects 4-CSV zip byte-identical after declared normalization; run $RUN_ID prefix $PREFIX)"
exit 0
