#!/bin/sh
# ============================================================
# test_glbalances_golden.sh — Stage B4 golden-file byte compare
# for the GLBalances FBDI generator (reference object).
#
# Pipeline exercised, all via the packages' own APIs on the
# local Docker DB (dmt2-local, port 1523):
#   1. Land test/golden/inputs/GLBalances_input.csv into
#      DMT_CSV_LANDING_TBL and load to DMT_GL_INTERFACE_STG_TBL
#      via DMT_CSV_LOADER_PKG.LOAD_CSV (scenario-mandatory path).
#   2. Create a run row + prefix via DMT_PIPELINE_INIT_PKG.INIT_RUN.
#   3. DMT_GL_TRANSFORM_PKG.TRANSFORM (scoped to the test scenario).
#   4. DMT_GL_FBDI_GEN_PKG.GENERATE_FBDI.
#   5. Extract the zip from DMT_FBDI_ZIP_TBL (base64 over
#      dbms_output) and byte-compare against the golden
#      (test/fbdi_zips/GLBalances_100000740.zip) with
#      compare_fbdi.py + normalization_map.json.
#
# Input provenance: the 3 rows reproduce the old stack's
# regression GL journal rows (ConversionTool/scripts/
# insert_regression_test_data.py section 20) — the exact data
# behind the golden. The repo-level regression_test_bundle.zip
# GL_INTERFACE.csv holds DIFFERENT data (dictionary-built) and
# cannot reproduce this golden.
#
# Usage:  sh test/golden/test_glbalances_golden.sh
# Env overrides: DMT2_CONN, SQLCL, JAVA_HOME, PYTHON
# Exit 0 only if the compare verdict is byte-identical after
# the declared normalization.
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
INPUT_CSV="$SCRIPT_DIR/inputs/GLBalances_input.csv"
MAP_JSON="$SCRIPT_DIR/normalization_map.json"

WORK_DIR="${TMPDIR:-/tmp}/dmt2_golden_glbalances"
mkdir -p "$WORK_DIR"
SQL_FILE="$WORK_DIR/run_glbalances.sql"
LOG_FILE="$WORK_DIR/run_glbalances.log"

fail () {
    echo "FAIL  test_glbalances_golden.sh  ($1)  [log: $LOG_FILE]"
    exit 1
}

[ -f "$INPUT_CSV" ] || fail "missing input CSV $INPUT_CSV"
CSV_CONTENT=$(cat "$INPUT_CSV") || fail "cannot read input CSV"

# ------------------------------------------------------------
# Build the SQL driver. Marker GOLDEN_GLBAL scopes every row we
# create; cleanup at start keeps reruns stable (STG rows are
# never status-reset — each rerun lands fresh rows + new run).
# ------------------------------------------------------------
cat > "$SQL_FILE" <<EOF
whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off
set linesize 32767
set trimout on

-- Pre-clean residue from earlier runs (scenario-scoped)
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'GOLDEN_GLBAL_SCN';
    if l_scn is not null then
        delete from dmt_gl_interface_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id
                                   from   dmt_gl_interface_stg_tbl
                                   where  scenario_id = l_scn);
        delete from dmt_gl_interface_stg_tbl where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id = 'GOLDEN_GLBAL';
    commit;
end;
/

-- 1. Land + load the input CSV through DMT_CSV_LOADER_PKG
declare
    l_id     number;
    l_status varchar2(30);
    l_err    clob;
begin
    insert into dmt_csv_landing_tbl
        (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
    values
        ('GOLDEN_GLBAL', 'GOLDEN_GLBAL_VIEW', 'DMT_GL_INTERFACE_STG_TBL',
         'GLBalances_input.csv',
         to_clob(q'[${CSV_CONTENT}]'),
         'GOLDEN_GLBAL_SCN')
    returning csv_landing_id into l_id;
    commit;

    dmt_csv_loader_pkg.load_csv(p_csv_landing_id => l_id);

    select status, error_text into l_status, l_err
    from   dmt_csv_landing_tbl where csv_landing_id = l_id;
    if l_status <> 'LOADED' then
        raise_application_error(-20999,
            'CSV load failed (' || l_status || '): ' ||
            dbms_lob.substr(l_err, 3000, 1));
    end if;
    dbms_output.put_line('LOADED_OK');
end;
/

-- 2-4. Run row via INIT_RUN, transform, generate; 5. dump zip as base64
declare
    l_run     number;
    l_prefix  varchar2(20);
    l_scn     number;
    l_zip     blob;
    l_fn      varchar2(200);
    l_csv_id  number;
    l_len     integer;
    l_pos     integer := 1;
    l_b64     varchar2(32000);
begin
    dmt_pipeline_init_pkg.init_run(
        p_orchestration_code => 'GLBalances',
        p_scenario_name      => 'GOLDEN_GLBAL_SCN',
        p_source_filename    => 'GLBalances_input.csv',
        p_instance_id        => 'GOLDEN_TEST',
        x_integration_id     => l_run,
        x_prefix             => l_prefix);
    if l_prefix is null then
        raise_application_error(-20999, 'INIT_RUN returned no prefix (USE_PREFIX must be Y for tests)');
    end if;

    select scenario_id into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'GOLDEN_GLBAL_SCN';

    dmt_gl_transform_pkg.transform(
        p_run_id      => l_run,
        p_scenario_id => l_scn);

    dmt_gl_fbdi_gen_pkg.generate_fbdi(
        p_run_id      => l_run,
        x_fbdi_zip    => l_zip,
        x_filename    => l_fn,
        x_fbdi_csv_id => l_csv_id);
    commit;

    if l_zip is null then
        raise_application_error(-20999, 'GENERATE_FBDI produced no zip (0 STAGED rows?)');
    end if;

    dbms_output.put_line('RUNID:'  || l_run);
    dbms_output.put_line('PREFIX:' || l_prefix);
    dbms_output.put_line('FILENAME:' || l_fn);

    l_len := dbms_lob.getlength(l_zip);
    while l_pos <= l_len loop
        l_b64 := utl_raw.cast_to_varchar2(
                     utl_encode.base64_encode(dbms_lob.substr(l_zip, 2400, l_pos)));
        l_b64 := replace(replace(l_b64, chr(13), ''), chr(10), '');
        dbms_output.put_line('B64:' || l_b64);
        l_pos := l_pos + 2400;
    end loop;
    dbms_output.put_line('B64END');
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
grep -q '^B64END' "$LOG_FILE" || fail "zip dump incomplete (no B64END marker)"

RUN_ID=$(grep '^RUNID:'  "$LOG_FILE" | head -1 | cut -d: -f2 | tr -d '[:space:]')
PREFIX=$(grep '^PREFIX:' "$LOG_FILE" | head -1 | cut -d: -f2 | tr -d '[:space:]')
[ -n "$RUN_ID" ] && [ -n "$PREFIX" ] || fail "could not parse RUN_ID/PREFIX from log"

GEN_ZIP="$WORK_DIR/GLBalances_generated_${RUN_ID}.zip"
grep '^B64:' "$LOG_FILE" | sed 's/^B64://' | tr -d '\r' | base64 -d > "$GEN_ZIP" \
    || fail "base64 decode of generated zip failed"
[ -s "$GEN_ZIP" ] || fail "generated zip is empty"

# ------------------------------------------------------------
# Compare against golden
# ------------------------------------------------------------
echo "run_id=$RUN_ID prefix=$PREFIX generated=$GEN_ZIP"
"$PYTHON" "$SCRIPT_DIR/compare_fbdi.py" \
    --object GLBalances \
    --generated "$GEN_ZIP" \
    --map "$MAP_JSON" \
    --prefix "$PREFIX" \
    --run-id "$RUN_ID"
crc=$?

if [ $crc -eq 0 ]; then
    echo "PASS  test_glbalances_golden.sh  (GLBalances byte-identical after declared normalization; run $RUN_ID prefix $PREFIX)"
    exit 0
fi
fail "compare exit $crc — generated output differs from golden (see diff above)"
