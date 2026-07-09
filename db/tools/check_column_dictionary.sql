-- ============================================================================
-- check_column_dictionary.sql — STG/TFM conformance check (DMT_DESIGN.html
-- section 7: "STG/TFM infra-column dictionary" + "Contract-index dictionary",
-- both accepted 2026-07-08).
--
-- For every DMT_%_STG_TBL and DMT_%_TFM_TBL in the connected schema, diffs:
--   1. Its columns against the accepted infra-column dictionary:
--        STG: STG_SEQUENCE_ID, SOURCE_ID, SCENARIO_ID, STG_STATUS,
--             ERROR_TEXT, STAGE_DATE, LAST_UPDATED_DATE
--        TFM: TFM_SEQUENCE_ID, STG_SEQUENCE_ID, RUN_ID, FBDI_CSV_ID,
--             RECON_KEY, at least one FUSION_* identifier column,
--             TFM_STATUS, ERROR_TEXT, RESULTS_UPDATED_DATE,
--             LAST_UPDATED_DATE
--      A column still named STATUS (the retired pre-rename name) is a
--      violation in both table kinds.
--   2. Its indexes against the contract-index dictionary (an index whose
--      ordered column list exactly equals the contract entry must exist;
--      the index name is not checked here — naming is enforced in review):
--        TFM: (RUN_ID) · (RUN_ID, TFM_STATUS) · (FBDI_CSV_ID)
--             · (STG_SEQUENCE_ID) · (RECON_KEY)
--        STG: (STG_STATUS) · (SCENARIO_ID)
--
-- Prints one PASS/FAIL line per table (FAIL lines list every violation)
-- and a summary; exits FAILURE when any table fails, so the script can
-- gate CI / the regression suite.
--
-- Exemption: DMT_MOCK_TFM_TBL is the sanctioned engine-test fixture
-- (section 7 "Named test fixtures", accepted 2026-07-08). It is not an
-- object TFM table — it has no staged lineage, no FBDI file, and no
-- Fusion counterpart — so the infra-column dictionary does not apply.
-- It is still checked for one thing: its status column must be named
-- TFM_STATUS (the catalog-driven engine reads the column name from
-- DMT_CEMLI_CATALOG_TBL.STATUS_COLUMN, which is uniformly TFM_STATUS).
--
-- Usage (dmt2-local):
--   echo exit | sql -S dmt_owner/<pwd>@//localhost:1523/FREEPDB1 \
--     @db/tools/check_column_dictionary.sql
-- ============================================================================
set serveroutput on size unlimited
set linesize 200
whenever sqlerror exit failure

declare
  c_success  constant pls_integer := 0;
  l_fail_tables   pls_integer := 0;
  l_violations    pls_integer := 0;
  l_tables        pls_integer := 0;
  l_step          varchar2(400);

  type t_vc_tab is table of varchar2(200);

  -- one entry per required index: comma-separated ordered column list
  c_tfm_indexes constant t_vc_tab := t_vc_tab(
      'RUN_ID', 'RUN_ID,TFM_STATUS', 'FBDI_CSV_ID', 'STG_SEQUENCE_ID',
      'RECON_KEY');
  c_stg_indexes constant t_vc_tab := t_vc_tab(
      'STG_STATUS', 'SCENARIO_ID');
  c_stg_columns constant t_vc_tab := t_vc_tab(
      'STG_SEQUENCE_ID', 'SOURCE_ID', 'SCENARIO_ID', 'STG_STATUS',
      'ERROR_TEXT', 'STAGE_DATE', 'LAST_UPDATED_DATE');
  c_tfm_columns constant t_vc_tab := t_vc_tab(
      'TFM_SEQUENCE_ID', 'STG_SEQUENCE_ID', 'RUN_ID', 'FBDI_CSV_ID',
      'RECON_KEY', 'TFM_STATUS', 'ERROR_TEXT', 'RESULTS_UPDATED_DATE',
      'LAST_UPDATED_DATE');

  l_problems varchar2(4000);

  procedure add_problem(p_text in varchar2) is
  begin
    l_problems   := l_problems || '    - ' || p_text || chr(10);
    l_violations := l_violations + 1;
  end add_problem;

  function column_exists(p_table in varchar2, p_column in varchar2)
    return boolean is
    l_n pls_integer;
  begin
    select count(*) into l_n
      from user_tab_columns
     where table_name = p_table and column_name = p_column;
    return l_n > 0;
  end column_exists;

  function index_on(p_table in varchar2, p_cols in varchar2)
    return boolean is
    l_n pls_integer;
  begin
    -- an index whose full ordered column list exactly equals p_cols
    select count(*) into l_n
      from (select index_name,
                   listagg(column_name, ',')
                     within group (order by column_position) as col_list
              from user_ind_columns
             where table_name = p_table
             group by index_name)
     where col_list = p_cols;
    return l_n > 0;
  end index_on;

  procedure check_table(p_table in varchar2, p_kind in varchar2) is
    l_n pls_integer;
    l_required t_vc_tab;
    l_indexes  t_vc_tab;
  begin
    l_problems := null;
    if p_kind = 'STG' then
      l_required := c_stg_columns; l_indexes := c_stg_indexes;
    else
      l_required := c_tfm_columns; l_indexes := c_tfm_indexes;
    end if;

    for i in 1 .. l_required.count loop
      if not column_exists(p_table, l_required(i)) then
        add_problem('missing column ' || l_required(i));
      end if;
    end loop;

    -- the retired pre-rename column name is itself a violation
    if column_exists(p_table, 'STATUS') then
      add_problem('legacy STATUS column present (rename to '
                  || p_kind || '_STATUS)');
    end if;

    if p_kind = 'TFM' then
      -- at least one Fusion identifier column (FUSION_*), the positive
      -- proof of load written only by reconciliation
      select count(*) into l_n
        from user_tab_columns
       where table_name = p_table
         and column_name like 'FUSION\_%' escape '\';
      if l_n = 0 then
        add_problem('no FUSION_* identifier column');
      end if;
    end if;

    for i in 1 .. l_indexes.count loop
      if not index_on(p_table, l_indexes(i)) then
        add_problem('missing contract index on (' || l_indexes(i) || ')');
      end if;
    end loop;

    if l_problems is null then
      dbms_output.put_line('PASS  ' || rpad(p_table, 34) || ' [' || p_kind || ']');
    else
      l_fail_tables := l_fail_tables + 1;
      dbms_output.put_line('FAIL  ' || rpad(p_table, 34) || ' [' || p_kind || ']');
      dbms_output.put_line(rtrim(l_problems, chr(10)));
    end if;
  end check_table;

begin
  l_step := 'scanning user_tables for STG/TFM tables';
  for t in (select table_name,
                   case when table_name like '%\_STG\_TBL' escape '\'
                        then 'STG' else 'TFM' end as kind
              from user_tables
             where (table_name like 'DMT\_%\_STG\_TBL' escape '\'
                    or table_name like 'DMT\_%\_TFM\_TBL' escape '\')
             order by table_name) loop
    l_tables := l_tables + 1;
    if t.table_name = 'DMT_MOCK_TFM_TBL' then
      -- sanctioned test fixture (section 7 "Named test fixtures"):
      -- only its status column name is checked
      if column_exists(t.table_name, 'TFM_STATUS')
         and not column_exists(t.table_name, 'STATUS') then
        dbms_output.put_line('PASS  ' || rpad(t.table_name, 34)
                             || ' [test fixture - status name only]');
      else
        l_fail_tables := l_fail_tables + 1;
        l_violations  := l_violations + 1;
        dbms_output.put_line('FAIL  ' || rpad(t.table_name, 34)
                             || ' [test fixture] status column must be TFM_STATUS');
      end if;
    else
      l_step := 'checking ' || t.table_name;
      check_table(t.table_name, t.kind);
    end if;
  end loop;

  dbms_output.put_line('----');
  dbms_output.put_line('column-dictionary check: ' || l_tables || ' tables, '
                       || (l_tables - l_fail_tables) || ' pass, '
                       || l_fail_tables || ' fail, '
                       || l_violations || ' violation(s)');
  if l_fail_tables > 0 then
    raise_application_error(-20001,
      'STG/TFM dictionary conformance failed: ' || l_violations
      || ' violation(s) across ' || l_fail_tables || ' table(s)');
  end if;
exception
  when others then
    if sqlcode = -20001 then raise; end if;
    dbms_output.put_line('ERROR during "' || l_step || '": ' || sqlerrm);
    raise;
end;
/
