#!/bin/sh
# ============================================================
# test_suppliers_golden.sh — Stage D golden-file byte compare
# for the FIVE supplier-family FBDI generators (Suppliers,
# SupplierAddresses, SupplierSites, SupplierSiteAssignments,
# SupplierContacts).
#
# Pipeline exercised, all via the packages' own APIs on the
# local Docker DB (dmt2-local, port 1523):
#   1. Land the five test/golden/inputs/Supplier*_input.csv files
#      into DMT_CSV_LANDING_TBL and load them to the five STG
#      tables via DMT_CSV_LOADER_PKG.LOAD_CSV (scenario-mandatory).
#   2. Create ONE run row + prefix via DMT_PIPELINE_INIT_PKG.INIT_RUN
#      (the goldens all come from one old-stack run: 116 / 9627).
#   3. DMT_POZ_SUP_TRANSFORM_PKG.TRANSFORM_* for all five objects.
#   4. The five DMT_POZ_SUP*_FBDI_GEN_PKG.GENERATE_FBDI calls.
#   5. Extract each zip from DMT_FBDI_ZIP_TBL (base64 over
#      dbms_output) and byte-compare against the run-116 goldens
#      with compare_fbdi.py + normalization_map.json.
#
# Input provenance: the rows reproduce the old stack's supplier
# regression rows (ConversionTool/scripts/insert_regression_test_data.py
# sections 1-5) — the exact data behind the run-116 goldens. The
# pre-existing "Allied Manufacturing" rows (inserted with STATUS
# 'LOADED' by that script) are excluded: LOADED rows never
# transform, so they are not in the golden FBDI files.
#
# DELIBERATE: the upstream validator (DMT_POZ_SUP_VALIDATOR_PKG)
# is NOT called here. The run-116 goldens predate the
# pre-validation ordering fix, so the BAD rows (ghost supplier,
# invalid BU) ARE in the golden files; offline, no parent can be
# LOADED anyway (LOADED requires a Fusion load — phase 2). The
# validator's contract is proven in test/unit/test_suppliers.sql.
#
# Usage:  sh test/golden/test_suppliers_golden.sh
# Env overrides: DMT2_CONN, SQLCL, JAVA_HOME, PYTHON
# Exit 0 only if ALL FIVE compare verdicts are byte-identical
# after the declared normalization.
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

WORK_DIR="${TMPDIR:-/tmp}/dmt2_golden_suppliers"
mkdir -p "$WORK_DIR"
SQL_FILE="$WORK_DIR/run_suppliers.sql"
LOG_FILE="$WORK_DIR/run_suppliers.log"

fail () {
    echo "FAIL  test_suppliers_golden.sh  ($1)  [log: $LOG_FILE]"
    exit 1
}

for f in Suppliers SupplierAddresses SupplierSites SupplierSiteAssignments SupplierContacts; do
    [ -f "$SCRIPT_DIR/inputs/${f}_input.csv" ] || fail "missing input CSV inputs/${f}_input.csv"
done

CSV_SUP=$(cat "$SCRIPT_DIR/inputs/Suppliers_input.csv")                || fail "read Suppliers input"
CSV_ADDR=$(cat "$SCRIPT_DIR/inputs/SupplierAddresses_input.csv")       || fail "read Addresses input"
CSV_SITE=$(cat "$SCRIPT_DIR/inputs/SupplierSites_input.csv")           || fail "read Sites input"
CSV_ASSN=$(cat "$SCRIPT_DIR/inputs/SupplierSiteAssignments_input.csv") || fail "read Assignments input"
CSV_CONT=$(cat "$SCRIPT_DIR/inputs/SupplierContacts_input.csv")        || fail "read Contacts input"

# ------------------------------------------------------------
# Build the SQL driver. Marker GOLDEN_SUP scopes every row we
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

-- Pre-clean residue from earlier runs (scenario-scoped; TFM first for FKs)
declare
    l_scn number;
begin
    select max(scenario_id) into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'GOLDEN_SUP_SCN';
    if l_scn is not null then
        delete from dmt_poz_suppliers_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_suppliers_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_addr_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_addr_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_site_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_site_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_site_assn_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_sup_contacts_tfm_tbl
        where  stg_sequence_id in (select stg_sequence_id from dmt_poz_sup_contacts_stg_tbl where scenario_id = l_scn);
        delete from dmt_poz_suppliers_stg_tbl     where scenario_id = l_scn;
        delete from dmt_poz_sup_addr_stg_tbl      where scenario_id = l_scn;
        delete from dmt_poz_sup_site_stg_tbl      where scenario_id = l_scn;
        delete from dmt_poz_sup_site_assn_stg_tbl where scenario_id = l_scn;
        delete from dmt_poz_sup_contacts_stg_tbl  where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'GOLDEN_SUP%';
    commit;
end;
/

-- 1. Land + load all five input CSVs through DMT_CSV_LOADER_PKG
declare
    procedure land_one (p_batch varchar2, p_table varchar2, p_file varchar2, p_csv clob) is
        l_id     number;
        l_status varchar2(30);
        l_err    clob;
    begin
        insert into dmt_csv_landing_tbl
            (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
        values
            (p_batch, p_batch || '_VIEW', p_table, p_file, p_csv, 'GOLDEN_SUP_SCN')
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
    land_one('GOLDEN_SUP_1', 'DMT_POZ_SUPPLIERS_STG_TBL',     'Suppliers_input.csv',               to_clob(q'[${CSV_SUP}]'));
    land_one('GOLDEN_SUP_2', 'DMT_POZ_SUP_ADDR_STG_TBL',      'SupplierAddresses_input.csv',       to_clob(q'[${CSV_ADDR}]'));
    land_one('GOLDEN_SUP_3', 'DMT_POZ_SUP_SITE_STG_TBL',      'SupplierSites_input.csv',           to_clob(q'[${CSV_SITE}]'));
    land_one('GOLDEN_SUP_4', 'DMT_POZ_SUP_SITE_ASSN_STG_TBL', 'SupplierSiteAssignments_input.csv', to_clob(q'[${CSV_ASSN}]'));
    land_one('GOLDEN_SUP_5', 'DMT_POZ_SUP_CONTACTS_STG_TBL',  'SupplierContacts_input.csv',        to_clob(q'[${CSV_CONT}]'));
end;
/

-- 2-4. One run row via INIT_RUN; transform all five; generate all five;
-- 5. dump each zip as base64 between ZIPSTART/ZIPEND markers.
declare
    l_run     number;
    l_prefix  varchar2(20);
    l_scn     number;
    l_zip     blob;
    l_fn      varchar2(200);

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
        p_orchestration_code => 'Suppliers',
        p_scenario_name      => 'GOLDEN_SUP_SCN',
        p_source_filename    => 'Suppliers_input.csv',
        p_instance_id        => 'GOLDEN_TEST',
        x_integration_id     => l_run,
        x_prefix             => l_prefix);
    if l_prefix is null then
        raise_application_error(-20999, 'INIT_RUN returned no prefix (USE_PREFIX must be Y for tests)');
    end if;

    select scenario_id into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'GOLDEN_SUP_SCN';

    -- Upstream validator deliberately NOT called — see the header comment.
    dmt_poz_sup_transform_pkg.transform_suppliers(l_run, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_addresses(l_run, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_sites(l_run, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_site_assignments(l_run, p_scenario_id => l_scn);
    dmt_poz_sup_transform_pkg.transform_contacts(l_run, p_scenario_id => l_scn);

    dbms_output.put_line('RUNID:'  || l_run);
    dbms_output.put_line('PREFIX:' || l_prefix);

    dmt_poz_sup_fbdi_gen_pkg.generate_fbdi(l_run, l_zip, l_fn);
    dump_zip('Suppliers', l_zip);
    dmt_poz_sup_addr_fbdi_gen_pkg.generate_fbdi(l_run, l_zip, l_fn);
    dump_zip('SupplierAddresses', l_zip);
    dmt_poz_sup_site_fbdi_gen_pkg.generate_fbdi(l_run, l_zip, l_fn);
    dump_zip('SupplierSites', l_zip);
    dmt_poz_sup_site_assn_fbdi_gen_pkg.generate_fbdi(l_run, l_zip, l_fn);
    dump_zip('SupplierSiteAssignments', l_zip);
    dmt_poz_sup_cont_fbdi_gen_pkg.generate_fbdi(l_run, l_zip, l_fn);
    dump_zip('SupplierContacts', l_zip);
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
# Extract each zip from the log and compare against its golden
# ------------------------------------------------------------
OVERALL=0
for OBJ in Suppliers SupplierAddresses SupplierSites SupplierSiteAssignments SupplierContacts; do
    GEN_ZIP="$WORK_DIR/${OBJ}_generated_${RUN_ID}.zip"
    sed -n "/^ZIPSTART:${OBJ}\$/,/^ZIPEND:${OBJ}\$/p" "$LOG_FILE" \
        | grep '^B64:' | sed 's/^B64://' | tr -d '\r' | base64 -d > "$GEN_ZIP" \
        || fail "$OBJ: base64 decode of generated zip failed"
    [ -s "$GEN_ZIP" ] || fail "$OBJ: generated zip is empty"

    "$PYTHON" "$SCRIPT_DIR/compare_fbdi.py" \
        --object "$OBJ" \
        --generated "$GEN_ZIP" \
        --map "$MAP_JSON" \
        --prefix "$PREFIX" \
        --run-id "$RUN_ID"
    crc=$?
    if [ $crc -ne 0 ]; then
        echo "DIFF  $OBJ: compare exit $crc — generated output differs from golden (see diff above)"
        OVERALL=1
    fi
done

if [ $OVERALL -eq 0 ]; then
    echo "PASS  test_suppliers_golden.sh  (all 5 supplier-family files byte-identical after declared normalization; run $RUN_ID prefix $PREFIX)"
    exit 0
fi
fail "one or more supplier-family files differ from their goldens"
