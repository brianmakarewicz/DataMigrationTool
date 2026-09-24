--------------------------------------------------------------------------------
-- dmt_fusion_id_audit.sql
--
-- POST-REGRESSION FUSION-ID AUDITOR -- STRICTLY READ-ONLY (SELECT ONLY).
--
-- Purpose
--   After a regression run, prove that every row a reconciler marked LOADED
--   carries positive base-table proof of load: a populated, unique Fusion
--   base-table id. Catches false-positive LOADEDs (recon claimed success with
--   no id, or matched the same Fusion record twice).
--
--   This script NEVER modifies the database. It runs only SELECT statements
--   (including SELECT ... INTO via EXECUTE IMMEDIATE, which is a read). There is
--   NO UPDATE / INSERT / DELETE / MERGE / DDL / status change anywhere in this
--   file. Nothing is committed because nothing is written.
--
-- What it checks, per audited object, for one RUN_ID, over rows whose
-- TFM_STATUS = 'LOADED':
--   1. POPULATED  -- any LOADED row whose FUSION_ID_COLUMN IS NULL is a
--                    violation (recon claimed success with no proof of load).
--   2. UNIQUE     -- any Fusion id value shared by two or more LOADED rows in
--                    the same audited TFM table + RUN_ID is a violation
--                    (matched the same Fusion record twice -- a false positive).
--
-- Registry driven -- NO per-object hardcoding
--   The set of objects and their (TFM_TABLE, FUSION_ID_COLUMN) pairs comes from
--   DMT_BIP_REPORT_TBL. Every audited object's TFM table has a FUSION_*_ID
--   column documented "written only by BIP reconciliation (positive proof of
--   load)". Table/column identifiers are validated with
--   DBMS_ASSERT.SIMPLE_SQL_NAME before they are ever concatenated into dynamic
--   SQL.
--
-- Skips (reported, never counted as a failure)
--   * No FUSION_ID_COLUMN in the registry -> the object does not stamp a Fusion
--     id (nothing to audit).
--   * FUSION_ID_COLUMN or TFM_TABLE is not a single plain SQL identifier -> the
--     object is a multi-table / multi-id family (e.g. Customers, whose recon
--     stamps seven per-record-type id columns across seven TFM tables). The
--     shared single-column audit cannot express its grain, so it is skipped with
--     that reason. Weakening the check globally to accommodate it is not done.
--
-- Shared TFM tables (audited once)
--   Some objects share one physical TFM table (e.g. PurchaseOrders, BlanketPOs
--   and Contracts all land in DMT_PO_HEADERS_INT_TFM_TBL, discriminated by
--   DOCUMENT_TYPE_CODE). The audit runs ONCE per distinct (TFM_TABLE,
--   FUSION_ID_COLUMN) pair and lists every CEMLI that shares it, so a shared
--   table is neither double-counted nor cross-attributed. Fusion base-table ids
--   are globally unique, so a table-level uniqueness check over such a shared
--   table is correct (a real id collision is a real double-match regardless of
--   which sharing object produced it).
--
-- Grain: every audited id is at its TFM table's own grain
--   Every FUSION_*_ID column stores proof of load at the grain of the TFM
--   table that carries it. GLBalances used to be the one exception -- its
--   TFM table is line-grained but it stored the header id FUSION_JE_HEADER_ID,
--   so many LOADED lines shared one id. That is fixed: GLBalances now stores
--   the per-line composite JE_HEADER_ID~JE_LINE_NUM, so each line's id is
--   unique. With no header-grained id left, the UNIQUE check runs for every
--   object with no exception -- a duplicate is always a real double-match.
--
-- Note on RECON_PROC
--   Several HDL objects (Workers, Salaries, Assignments, ...) carry RECON_PROC
--   NULL in DMT_PIPELINE_DEF_TBL yet DO stamp a Fusion id (they reconcile via
--   the shared Contract-v1 parser, not the queue's RECON_PROC). The honest
--   "does this object stamp a Fusion id" signal is therefore the presence of a
--   usable FUSION_ID_COLUMN in the registry, which is what drives this audit.
--   RECON_PROC is not used to skip a genuinely stamping object.
--
-- Usage
--   sql dmt_owner/****@//localhost:1523/FREEPDB1 @scripts/dmt_fusion_id_audit.sql 121
--   (or run interactively and supply RUN_ID at the prompt)
--------------------------------------------------------------------------------

set serveroutput on size unlimited
set feedback off
set verify off
set linesize 200
set define on

-- RUN_ID comes from the first script argument (&1); if absent, prompt for it.
column run_id_val new_value run_id_val noprint
set termout off
select nvl('&1', '&&run_id_prompt') as run_id_val from dual;
set termout on

declare
  -- ------------------------------------------------------------------------
  -- Target run.
  -- ------------------------------------------------------------------------
  c_run_id      constant number := to_number('&run_id_val');

  -- ------------------------------------------------------------------------
  -- The loaded-status contract. TFM lifecycle is STAGED > GENERATED >
  -- LOADED / FAILED, in column TFM_STATUS. We audit only the LOADED rows.
  -- ------------------------------------------------------------------------
  c_loaded_status constant varchar2(30) := 'LOADED';

  -- running verdict
  l_overall_fail boolean := false;
  l_audited      pls_integer := 0;
  l_skipped      pls_integer := 0;

  -- de-dup of shared physical (table,id) pairs
  type t_seen is table of boolean index by varchar2(400);
  l_seen t_seen;

  function safe_name(p_id in varchar2) return varchar2 is
  begin
    -- DBMS_ASSERT.SIMPLE_SQL_NAME raises for anything that is not a single
    -- plain SQL identifier (spaces, parentheses, '+' etc.). We use that as the
    -- "is this a real single column/table name" test.
    return dbms_assert.simple_sql_name(p_id);
  exception
    when others then
      return null;
  end;

begin
  dbms_output.put_line('==============================================================================');
  dbms_output.put_line(' DMT FUSION-ID AUDIT (READ-ONLY)  --  RUN_ID = ' || c_run_id);
  dbms_output.put_line(' Invariants per object: every LOADED row has a POPULATED and UNIQUE Fusion id.');
  dbms_output.put_line('==============================================================================');
  dbms_output.put_line(rpad('OBJECT', 26) || rpad('TFM TABLE', 32) ||
                       lpad('LOADED', 8) || lpad('NULL-ID', 9) || lpad('DUP-ID', 8) || '  VERDICT');
  dbms_output.put_line(rpad('-', 26, '-') || rpad('-', 32, '-') ||
                       lpad('-', 8, '-') || lpad('-', 9, '-') || lpad('-', 8, '-') || '  -------');

  for r in (
    select cemli_code, tfm_table, fusion_id_column,
           -- every CEMLI sharing this exact (table,id) pair, so a shared table
           -- is audited once but attributed to all its objects
           listagg(cemli_code, ',') within group (order by cemli_code)
             over (partition by upper(tfm_table), upper(fusion_id_column)) as sharing_cemlis
    from   dmt_bip_report_tbl
    where  fusion_id_column is not null
    order  by tfm_table, cemli_code
  ) loop
    declare
      l_tab     varchar2(128) := safe_name(r.tfm_table);
      l_col     varchar2(128) := safe_name(r.fusion_id_column);
      l_key     varchar2(400);
      l_loaded  number;
      l_nullid  number;
      l_dupid   number := 0;
      l_label   varchar2(200);
      l_verdict varchar2(60);
      l_obj_fail boolean := false;
    begin
      l_label := nvl(r.sharing_cemlis, r.cemli_code);

      -- SKIP: compound / multi-table id (e.g. Customers) -> not a single column.
      if l_tab is null or l_col is null then
        l_skipped := l_skipped + 1;
        dbms_output.put_line('SKIP  ' || rpad(r.cemli_code, 20) ||
          ' -- multi-table / multi-id family; FUSION_ID_COLUMN "' ||
          r.fusion_id_column || '" is not a single plain column (grain not expressible).');
        goto next_row;
      end if;

      -- Audit each distinct physical (table,id) pair only once.
      l_key := upper(l_tab) || '.' || upper(l_col);
      if l_seen.exists(l_key) then
        goto next_row;
      end if;
      l_seen(l_key) := true;

      -- ------ POPULATED check (read): LOADED count and null-id LOADED count.
      execute immediate
        'select count(*), count(case when "' || l_col || '" is null then 1 end) ' ||
        'from "' || l_tab || '" where run_id = :b_run and tfm_status = :b_stat'
        into l_loaded, l_nullid
        using c_run_id, c_loaded_status;

      -- ------ UNIQUE check (read): number of LOADED rows sharing an id value.
      -- Every audited id is now at the TFM table's own grain (GLBalances stores
      -- the per-line composite JE_HEADER_ID~JE_LINE_NUM, not the header id), so
      -- a duplicate is always a real double-match -- no exceptions.
      execute immediate
        'select nvl(sum(cnt),0) from (' ||
        '  select count(*) cnt from "' || l_tab || '" ' ||
        '  where run_id = :b_run and tfm_status = :b_stat ' ||
        '    and "' || l_col || '" is not null ' ||
        '  group by "' || l_col || '" having count(*) > 1' ||
        ')'
        into l_dupid
        using c_run_id, c_loaded_status;

      l_obj_fail := (l_nullid > 0) or (l_dupid > 0);
      if l_obj_fail then
        l_overall_fail := true;
        l_verdict := 'FAIL';
      else
        l_verdict := 'PASS';
      end if;
      l_audited := l_audited + 1;

      dbms_output.put_line(
        rpad(substr(l_label, 1, 25), 26) ||
        rpad(l_tab, 32) ||
        lpad(l_loaded, 8) || lpad(l_nullid, 9) || lpad(l_dupid, 8) ||
        '  ' || l_verdict);

      -- ------ Offending rows: null-id LOADED rows (read).
      if l_nullid > 0 then
        declare
          type t_rc is ref cursor;
          rc   t_rc;
          l_rk varchar2(4000);
        begin
          open rc for
            'select recon_key from "' || l_tab || '" ' ||
            'where run_id = :b_run and tfm_status = :b_stat and "' || l_col || '" is null'
            using c_run_id, c_loaded_status;
          loop
            fetch rc into l_rk;
            exit when rc%notfound;
            dbms_output.put_line('        NULL-ID  RECON_KEY=' || l_rk);
          end loop;
          close rc;
        end;
      end if;

      -- ------ Offending rows: duplicate id values among LOADED rows (read).
      if l_dupid > 0 then
        declare
          type t_rc is ref cursor;
          rc   t_rc;
          l_id varchar2(4000);
          l_ct number;
          l_ks varchar2(4000);
        begin
          open rc for
            'select to_char("' || l_col || '") idv, count(*) ct, ' ||
            '       listagg(recon_key, '', '') within group (order by recon_key) keys ' ||
            'from "' || l_tab || '" ' ||
            'where run_id = :b_run and tfm_status = :b_stat and "' || l_col || '" is not null ' ||
            'group by "' || l_col || '" having count(*) > 1'
            using c_run_id, c_loaded_status;
          loop
            fetch rc into l_id, l_ct, l_ks;
            exit when rc%notfound;
            dbms_output.put_line('        DUP-ID   ' || l_col || '=' || l_id ||
                                 ' shared by ' || l_ct || ' LOADED rows: RECON_KEY=' || l_ks);
          end loop;
          close rc;
        end;
      end if;

      <<next_row>>
      null;
    end;
  end loop;

  dbms_output.put_line('==============================================================================');
  dbms_output.put_line(' Objects audited: ' || l_audited || '   Skipped: ' || l_skipped);
  if l_overall_fail then
    dbms_output.put_line(' OVERALL: FAIL -- at least one LOADED row lacks a populated/unique Fusion id.');
  else
    dbms_output.put_line(' OVERALL: PASS -- every LOADED row has a populated and unique Fusion id.');
  end if;
  dbms_output.put_line('==============================================================================');
  dbms_output.put_line(' Read-only: this audit ran SELECT statements only; nothing was modified.');
end;
/

set feedback on
