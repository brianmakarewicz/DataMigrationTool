-- ============================================================================
-- check_column_dictionary.sql — STG/TFM conformance check (DMT_DESIGN.html
-- section 7: "STG/TFM infra-column dictionary" + "Contract-index dictionary",
-- both accepted 2026-07-08). Extended 2026-07-09 (blind conformance-tranche
-- review F2) to assert the FULL accepted dictionaries.
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
--   2. The status column's declaration: STG_STATUS is VARCHAR2(30)
--      DEFAULT 'NEW' NOT NULL; TFM_STATUS is VARCHAR2(30) DEFAULT 'STAGED'
--      NOT NULL (dictionary text, accepted 2026-07-08).
--   3. Its indexes against the contract-index dictionary (an index whose
--      ordered column list exactly equals the contract entry must exist;
--      the index name is not checked here — naming is enforced in review):
--        TFM: (RUN_ID) · (RUN_ID, TFM_STATUS) · (FBDI_CSV_ID)
--             · (STG_SEQUENCE_ID) · (RECON_KEY)
--        STG: (STG_STATUS) · (SCENARIO_ID)
--   4. The two infrastructure tables' contract indexes:
--        DMT_LOG_TBL: (RUN_ID) · (QUEUE_ID)
--        DMT_WORK_QUEUE_TBL: (RUN_ID) · (WORK_STATUS) · (NEXT_POLL_AFTER)
--   5. Identity-PK status (dictionary: STG_SEQUENCE_ID / TFM_SEQUENCE_ID are
--      identity columns). The accepted identity rule (2026-07-08) schedules
--      conversion PER OBJECT during the Stage B/C/D ports, so a not-yet-
--      converted table is reported as an explicit SANCTIONED-DEFERRAL line,
--      not a failure. A table whose PK column IS identity passes silently.
--   6. Named-FK presence (SCENARIO_ID on STG; RUN_ID / STG_SEQUENCE_ID /
--      FBDI_CSV_ID on TFM). Counted and REPORTED (summary lines at the end);
--      SYS_C-named and missing FKs are the tracked F5 unnamed-FK sweep
--      (docs/tranche-reviews/2026-07-09-conformance-review.md) — they are
--      not failures here because the fix (dictionary-driven renames plus new
--      constraints across ~140 committed table files) is that sweep's scope.
--
-- Dictionary statements this script deliberately does NOT check are printed
-- as explicit 'NOT CHECKED: <item>' lines at the end of the run, each with
-- the reason (behavioral/code-path properties a schema diff cannot see, or
-- work tracked elsewhere).
--
-- Prints one PASS/FAIL line per table (FAIL lines list every violation)
-- and a summary; exits FAILURE when any table fails, so the script can
-- gate CI / the regression suite. SANCTIONED-DEFERRAL, TRACKED and
-- NOT CHECKED lines are informational and do not fail the gate.
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

  -- identity-PK deferral bookkeeping (accepted identity rule: per-object
  -- conversion during stage ports — reported, never failed)
  l_identity_ok       pls_integer := 0;
  l_identity_deferred pls_integer := 0;

  -- named-FK bookkeeping (tracked F5 unnamed-FK sweep — reported, not failed)
  l_fk_named    pls_integer := 0;
  l_fk_sysnamed pls_integer := 0;
  l_fk_missing  pls_integer := 0;

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
  -- FK columns whose presence is reported (tracked F5, not failed)
  c_stg_fk_cols constant t_vc_tab := t_vc_tab('SCENARIO_ID');
  c_tfm_fk_cols constant t_vc_tab := t_vc_tab(
      'RUN_ID', 'STG_SEQUENCE_ID', 'FBDI_CSV_ID');

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

  -- status-column declaration: VARCHAR2(30) DEFAULT '<dflt>' NOT NULL
  procedure check_status_column(p_table in varchar2, p_column in varchar2,
                                p_default in varchar2) is
    l_type     varchar2(128);
    l_len      number;
    l_nullable varchar2(1);
    l_dflt     varchar2(4000);
  begin
    select data_type, char_length, nullable, data_default
      into l_type, l_len, l_nullable, l_dflt
      from user_tab_columns
     where table_name = p_table and column_name = p_column;
    if l_type != 'VARCHAR2' or l_len != 30 then
      add_problem(p_column || ' is ' || l_type || '(' || l_len
                  || ') - dictionary says VARCHAR2(30)');
    end if;
    if l_nullable = 'Y' then
      add_problem(p_column || ' is nullable - dictionary says NOT NULL');
    end if;
    if l_dflt is null
       or upper(trim(l_dflt)) not like '''' || p_default || '''%' then
      add_problem(p_column || ' default is ' || nvl(trim(l_dflt), '<none>')
                  || ' - dictionary says DEFAULT ''' || p_default || '''');
    end if;
  exception
    when no_data_found then
      null;  -- missing-column violation already reported by the column loop
  end check_status_column;

  -- named-FK presence on one column: counts named / SYS-named / missing.
  -- Reported in the summary; the fix is the tracked F5 unnamed-FK sweep.
  procedure tally_fk(p_table in varchar2, p_column in varchar2) is
    l_named pls_integer;
    l_sys   pls_integer;
  begin
    select count(case when c.constraint_name not like 'SYS\_%' escape '\'
                      then 1 end),
           count(case when c.constraint_name like 'SYS\_%' escape '\'
                      then 1 end)
      into l_named, l_sys
      from user_constraints c
      join user_cons_columns cc
        on cc.constraint_name = c.constraint_name
     where c.constraint_type = 'R'
       and c.table_name  = p_table
       and cc.column_name = p_column;
    if l_named > 0 then
      l_fk_named := l_fk_named + 1;
    elsif l_sys > 0 then
      l_fk_sysnamed := l_fk_sysnamed + 1;
    else
      l_fk_missing := l_fk_missing + 1;
    end if;
  end tally_fk;

  -- identity-PK status: dictionary says the sequence-id PK is an identity
  -- column; the accepted identity rule converts per object during the stage
  -- ports, so a non-identity PK is a SANCTIONED-DEFERRAL line, not a FAIL.
  procedure check_identity_pk(p_table in varchar2, p_pk_col in varchar2) is
    l_ident varchar2(3);
  begin
    select identity_column into l_ident
      from user_tab_columns
     where table_name = p_table and column_name = p_pk_col;
    if l_ident = 'YES' then
      l_identity_ok := l_identity_ok + 1;
    else
      l_identity_deferred := l_identity_deferred + 1;
      dbms_output.put_line('SANCTIONED-DEFERRAL  ' || rpad(p_table, 34)
        || ' PK ' || p_pk_col || ' not yet an identity column - the accepted'
        || ' identity rule (2026-07-08) schedules conversion per object'
        || ' during the Stage B/C/D ports');
    end if;
  exception
    when no_data_found then
      null;  -- missing-column violation already reported by the column loop
  end check_identity_pk;

  procedure check_table(p_table in varchar2, p_kind in varchar2) is
    l_n pls_integer;
    l_required t_vc_tab;
    l_indexes  t_vc_tab;
    l_fk_cols  t_vc_tab;
  begin
    l_problems := null;
    if p_kind = 'STG' then
      l_required := c_stg_columns; l_indexes := c_stg_indexes;
      l_fk_cols  := c_stg_fk_cols;
    else
      l_required := c_tfm_columns; l_indexes := c_tfm_indexes;
      l_fk_cols  := c_tfm_fk_cols;
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

    -- status-column declaration (NOT NULL + DEFAULT + datatype)
    if p_kind = 'STG' then
      check_status_column(p_table, 'STG_STATUS', 'NEW');
    else
      check_status_column(p_table, 'TFM_STATUS', 'STAGED');
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

    -- named-FK presence tally (reported in summary; tracked F5)
    for i in 1 .. l_fk_cols.count loop
      tally_fk(p_table, l_fk_cols(i));
    end loop;

    -- identity-PK (SANCTIONED-DEFERRAL when not yet converted)
    check_identity_pk(p_table,
        case p_kind when 'STG' then 'STG_SEQUENCE_ID'
                    else 'TFM_SEQUENCE_ID' end);

    if l_problems is null then
      dbms_output.put_line('PASS  ' || rpad(p_table, 34) || ' [' || p_kind || ']');
    else
      l_fail_tables := l_fail_tables + 1;
      dbms_output.put_line('FAIL  ' || rpad(p_table, 34) || ' [' || p_kind || ']');
      dbms_output.put_line(rtrim(l_problems, chr(10)));
    end if;
  end check_table;

  -- infrastructure contract indexes (DMT_LOG_TBL / DMT_WORK_QUEUE_TBL),
  -- checked once as their own PASS/FAIL lines
  procedure check_infra_table(p_table in varchar2, p_indexes in t_vc_tab) is
  begin
    l_problems := null;
    for i in 1 .. p_indexes.count loop
      if not index_on(p_table, p_indexes(i)) then
        add_problem('missing contract index on (' || p_indexes(i) || ')');
      end if;
    end loop;
    if l_problems is null then
      dbms_output.put_line('PASS  ' || rpad(p_table, 34) || ' [infra indexes]');
    else
      l_fail_tables := l_fail_tables + 1;
      dbms_output.put_line('FAIL  ' || rpad(p_table, 34) || ' [infra indexes]');
      dbms_output.put_line(rtrim(l_problems, chr(10)));
    end if;
  end check_infra_table;

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

  l_step := 'checking infrastructure contract indexes';
  check_infra_table('DMT_LOG_TBL',        t_vc_tab('RUN_ID', 'QUEUE_ID'));
  check_infra_table('DMT_WORK_QUEUE_TBL', t_vc_tab('RUN_ID', 'WORK_STATUS',
                                                   'NEXT_POLL_AFTER'));

  dbms_output.put_line('----');
  dbms_output.put_line('identity PKs: ' || l_identity_ok || ' converted, '
      || l_identity_deferred || ' sanctioned deferrals (identity rule:'
      || ' per-object conversion during stage ports)');
  dbms_output.put_line('named FKs (scenario/lineage): ' || l_fk_named
      || ' named, ' || l_fk_sysnamed || ' SYS-named, ' || l_fk_missing
      || ' missing -> TRACKED: F5 unnamed-FK sweep'
      || ' (2026-07-09 conformance review dispositions)');
  dbms_output.put_line('NOT CHECKED: FK constraint naming and creation of'
      || ' missing scenario/lineage FKs - SYS_C names are environment-'
      || 'generated so committed files cannot reference them; the fix'
      || ' (dictionary-driven renames + new named constraints across ~140'
      || ' table files) is the tracked F5 unnamed-FK sweep');
  dbms_output.put_line('NOT CHECKED: SOURCE_ID traceability to the source'
      || ' extract - content property, not visible to a schema diff');
  dbms_output.put_line('NOT CHECKED: SCENARIO_ID bound in the creating'
      || ' INSERT - code-path property (scenario-guard rule), enforced in'
      || ' review and by the upload-package scenario guard work item (F9)');
  dbms_output.put_line('NOT CHECKED: forward-only status transitions'
      || ' (NEW>TRANSFORMED/FAILED, STAGED>GENERATED>LOADED/FAILED) -'
      || ' runtime behavior, covered by the engine unit suites');
  dbms_output.put_line('NOT CHECKED: ERROR_TEXT append-only (accumulate,'
      || ' never overwrite) - runtime behavior, covered by unit suites');
  dbms_output.put_line('NOT CHECKED: FUSION_*_ID written only by'
      || ' reconciliation - code-path property, enforced in review');
  dbms_output.put_line('NOT CHECKED: RECON_KEY content (pre-concatenated'
      || ' business key incl. prefix) - content property; asserted per'
      || ' object by the golden-file tests');
  dbms_output.put_line('NOT CHECKED: non-status infra column datatypes'
      || ' (ERROR_TEXT CLOB, date columns) - presence is checked above;'
      || ' datatype conformance rides with the one-controlled-datatype'
      || ' sweep of the shared-identifier rule');
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
