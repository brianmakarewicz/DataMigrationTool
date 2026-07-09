#!/bin/sh
# ============================================================
# test_customers_golden.sh — Wave-1 golden-file byte compare
# for the Customers FBDI generator.
#
# Customers is ONE object whose single FBDI zip carries SEVEN
# HZ CSVs (parties, locations, party sites, party site uses,
# accounts, account sites, account site uses). One zip, one ESS
# job — contrast the supplier family (five separate objects).
#
# Pipeline exercised, all via the packages' own APIs on the
# local Docker DB (dmt2-local, port 1523):
#   1. Land the seven test/golden/inputs/Customer*_input.csv files
#      into DMT_CSV_LANDING_TBL and load them to the seven HZ STG
#      tables via DMT_CSV_LOADER_PKG.LOAD_CSV (scenario-mandatory).
#   2. Create ONE run row + prefix via DMT_PIPELINE_INIT_PKG.INIT_RUN
#      (the golden comes from old-stack run 116 / prefix 9627).
#   3. DMT_CUST_TRANSFORM_PKG.TRANSFORM_* for all seven record types.
#   4. ONE DMT_CUST_FBDI_GEN_PKG.GENERATE_FBDI call.
#   5. Extract the zip from DMT_FBDI_ZIP_TBL (base64 over dbms_output)
#      and byte-compare against the run-116 golden with
#      compare_fbdi.py + normalization_map.json.
#
# Input provenance: the rows reproduce the old stack's Customers
# regression rows (ConversionTool/scripts/insert_regression_test_data.py
# sections 6-12) — the exact data behind the run-116 golden.
#
# DELIBERATE: the upstream validator (DMT_CUST_VALIDATOR_PKG) is
# NOT called here. The run-116 golden predates the pre-validation
# ordering fix, so the BAD rows (invalid party type, missing
# country, ghost parents, invalid use codes) ARE in the golden
# file; offline, no parent can be LOADED anyway (LOADED requires a
# Fusion load — the live phase). The validator's contract is proven
# in test/unit/test_customers.sql.
#
# Usage:  sh test/golden/test_customers_golden.sh
# Env overrides: DMT2_CONN, SQLCL, JAVA_HOME, PYTHON
# Exit 0 only if the compare verdict is byte-identical after the
# declared normalization ({RUN_ID}, {PREFIX}).
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

WORK_DIR="${TMPDIR:-/tmp}/dmt2_golden_customers"
mkdir -p "$WORK_DIR"
SQL_FILE="$WORK_DIR/run_customers.sql"
LOG_FILE="$WORK_DIR/run_customers.log"

fail () {
    echo "FAIL  test_customers_golden.sh  ($1)  [log: $LOG_FILE]"
    exit 1
}

for f in CustomerParties CustomerLocations CustomerPartySites CustomerPartySiteUses \
         CustomerAccounts CustomerAcctSites CustomerAcctSiteUses; do
    [ -f "$SCRIPT_DIR/inputs/${f}_input.csv" ] || fail "missing input CSV inputs/${f}_input.csv"
done

CSV_PTY=$(cat "$SCRIPT_DIR/inputs/CustomerParties_input.csv")          || fail "read Parties input"
CSV_LOC=$(cat "$SCRIPT_DIR/inputs/CustomerLocations_input.csv")        || fail "read Locations input"
CSV_PS=$(cat "$SCRIPT_DIR/inputs/CustomerPartySites_input.csv")        || fail "read PartySites input"
CSV_PSU=$(cat "$SCRIPT_DIR/inputs/CustomerPartySiteUses_input.csv")    || fail "read PartySiteUses input"
CSV_ACC=$(cat "$SCRIPT_DIR/inputs/CustomerAccounts_input.csv")         || fail "read Accounts input"
CSV_AS=$(cat "$SCRIPT_DIR/inputs/CustomerAcctSites_input.csv")         || fail "read AcctSites input"
CSV_ASU=$(cat "$SCRIPT_DIR/inputs/CustomerAcctSiteUses_input.csv")     || fail "read AcctSiteUses input"

# ------------------------------------------------------------
# Build the SQL driver. Marker GOLDEN_CUST scopes every row we
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
    where  upper(scenario_name) = 'GOLDEN_CUST_SCN';
    if l_scn is not null then
        delete from dmt_hz_parties_tfm_tbl        where stg_sequence_id in (select stg_sequence_id from dmt_hz_parties_stg_tbl        where scenario_id = l_scn);
        delete from dmt_hz_locations_tfm_tbl      where stg_sequence_id in (select stg_sequence_id from dmt_hz_locations_stg_tbl      where scenario_id = l_scn);
        delete from dmt_hz_party_sites_tfm_tbl    where stg_sequence_id in (select stg_sequence_id from dmt_hz_party_sites_stg_tbl    where scenario_id = l_scn);
        delete from dmt_hz_party_site_uses_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_hz_party_site_uses_stg_tbl where scenario_id = l_scn);
        delete from dmt_hz_accounts_tfm_tbl       where stg_sequence_id in (select stg_sequence_id from dmt_hz_accounts_stg_tbl       where scenario_id = l_scn);
        delete from dmt_hz_acct_sites_tfm_tbl     where stg_sequence_id in (select stg_sequence_id from dmt_hz_acct_sites_stg_tbl     where scenario_id = l_scn);
        delete from dmt_hz_acct_site_uses_tfm_tbl where stg_sequence_id in (select stg_sequence_id from dmt_hz_acct_site_uses_stg_tbl where scenario_id = l_scn);
        delete from dmt_hz_parties_stg_tbl         where scenario_id = l_scn;
        delete from dmt_hz_locations_stg_tbl       where scenario_id = l_scn;
        delete from dmt_hz_party_sites_stg_tbl     where scenario_id = l_scn;
        delete from dmt_hz_party_site_uses_stg_tbl where scenario_id = l_scn;
        delete from dmt_hz_accounts_stg_tbl        where scenario_id = l_scn;
        delete from dmt_hz_acct_sites_stg_tbl      where scenario_id = l_scn;
        delete from dmt_hz_acct_site_uses_stg_tbl  where scenario_id = l_scn;
    end if;
    delete from dmt_csv_landing_tbl where batch_id like 'GOLDEN_CUST%';
    commit;
end;
/

-- 1. Land + load all seven input CSVs through DMT_CSV_LOADER_PKG
declare
    procedure land_one (p_batch varchar2, p_table varchar2, p_file varchar2, p_csv clob) is
        l_id     number;
        l_status varchar2(30);
        l_err    clob;
    begin
        insert into dmt_csv_landing_tbl
            (batch_id, view_name, atp_table_name, file_name, csv_data, scenario_name)
        values
            (p_batch, p_batch || '_VIEW', p_table, p_file, p_csv, 'GOLDEN_CUST_SCN')
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
    land_one('GOLDEN_CUST_1', 'DMT_HZ_PARTIES_STG_TBL',         'CustomerParties_input.csv',        to_clob(q'[${CSV_PTY}]'));
    land_one('GOLDEN_CUST_2', 'DMT_HZ_LOCATIONS_STG_TBL',       'CustomerLocations_input.csv',      to_clob(q'[${CSV_LOC}]'));
    land_one('GOLDEN_CUST_3', 'DMT_HZ_PARTY_SITES_STG_TBL',     'CustomerPartySites_input.csv',     to_clob(q'[${CSV_PS}]'));
    land_one('GOLDEN_CUST_4', 'DMT_HZ_PARTY_SITE_USES_STG_TBL', 'CustomerPartySiteUses_input.csv',  to_clob(q'[${CSV_PSU}]'));
    land_one('GOLDEN_CUST_5', 'DMT_HZ_ACCOUNTS_STG_TBL',        'CustomerAccounts_input.csv',       to_clob(q'[${CSV_ACC}]'));
    land_one('GOLDEN_CUST_6', 'DMT_HZ_ACCT_SITES_STG_TBL',      'CustomerAcctSites_input.csv',      to_clob(q'[${CSV_AS}]'));
    land_one('GOLDEN_CUST_7', 'DMT_HZ_ACCT_SITE_USES_STG_TBL',  'CustomerAcctSiteUses_input.csv',   to_clob(q'[${CSV_ASU}]'));
end;
/

-- 2-4. One run row via INIT_RUN; transform all seven record types;
-- generate the single zip; 5. dump it as base64 between markers.
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
        p_orchestration_code => 'Customers',
        p_scenario_name      => 'GOLDEN_CUST_SCN',
        p_source_filename    => 'CustomerParties_input.csv',
        p_instance_id        => 'GOLDEN_TEST',
        x_integration_id     => l_run,
        x_prefix             => l_prefix);
    if l_prefix is null then
        raise_application_error(-20999, 'INIT_RUN returned no prefix (USE_PREFIX must be Y for tests)');
    end if;

    select scenario_id into l_scn
    from   dmt_scenario_tbl
    where  upper(scenario_name) = 'GOLDEN_CUST_SCN';

    -- Upstream validator deliberately NOT called — see the header comment.
    dmt_cust_transform_pkg.transform_parties(l_run, p_scenario_id => l_scn);
    dmt_cust_transform_pkg.transform_locations(l_run, p_scenario_id => l_scn);
    dmt_cust_transform_pkg.transform_party_sites(l_run, p_scenario_id => l_scn);
    dmt_cust_transform_pkg.transform_party_site_uses(l_run, p_scenario_id => l_scn);
    dmt_cust_transform_pkg.transform_accounts(l_run, p_scenario_id => l_scn);
    dmt_cust_transform_pkg.transform_acct_sites(l_run, p_scenario_id => l_scn);
    dmt_cust_transform_pkg.transform_acct_site_uses(l_run, p_scenario_id => l_scn);

    dbms_output.put_line('RUNID:'  || l_run);
    dbms_output.put_line('PREFIX:' || l_prefix);

    dmt_cust_fbdi_gen_pkg.generate_fbdi(l_run, l_zip, l_fn, l_csv_id);
    dump_zip('Customers', l_zip);
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
GEN_ZIP="$WORK_DIR/Customers_generated_${RUN_ID}.zip"
sed -n "/^ZIPSTART:Customers\$/,/^ZIPEND:Customers\$/p" "$LOG_FILE" \
    | grep '^B64:' | sed 's/^B64://' | tr -d '\r' | base64 -d > "$GEN_ZIP" \
    || fail "Customers: base64 decode of generated zip failed"
[ -s "$GEN_ZIP" ] || fail "Customers: generated zip is empty"

"$PYTHON" "$SCRIPT_DIR/compare_fbdi.py" \
    --object Customers \
    --generated "$GEN_ZIP" \
    --map "$MAP_JSON" \
    --prefix "$PREFIX" \
    --run-id "$RUN_ID"
crc=$?

if [ $crc -eq 0 ]; then
    echo "PASS  test_customers_golden.sh  (all 7 Customer CSVs byte-identical after declared normalization; run $RUN_ID prefix $PREFIX)"
    exit 0
fi
fail "Customers FBDI differs from the golden (compare exit $crc)"
