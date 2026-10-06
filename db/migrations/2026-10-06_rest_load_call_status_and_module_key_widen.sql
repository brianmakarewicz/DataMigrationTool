-- =========================================================================
-- Migration: Close the "hollow LOADED" hole on the REST config load path, and
--            unblock Lookups by (a) a configurable/valid standardLookups
--            ModuleId and (b) a wider MODULE_KEY so a per-record 32-char module
--            GUID fits.  (2026-10-06)
--
-- Backlog #130 (the two linked REST-config fixes found in the #130 live
-- investigation). Follows PR #584, which made REST LOADED require
-- ERROR_TEXT IS NULL and stopped stamping blank HTTP codes as errors.
-- docs/DMT_DESIGN.html section 5 ("BIP reconciliation report contract - v1")
-- and the mission rule "LOADED only with a real base-table row ... never a
-- made-up verdict".
--
-- -------------------------------------------------------------------------
-- WHY (two independent changes, one file):
--
-- FIX 2 -- the "hollow LOADED" hole. PR #584's guard promotes a REST row to
-- LOADED when the base-table report returns its natural key AND ERROR_TEXT IS
-- NULL. But a create that fails with a BLANK body (e.g. Payment Terms / Taxes
-- POST to a non-existent resource -> HTTP 404, empty body) stashes NO error
-- (correct, per #161), so ERROR_TEXT stays NULL. If a row with the SAME natural
-- key already PRE-EXISTS in the Fusion base table, the reconcile returns it and
-- the row is marked LOADED even though DMT never created it. That is a false
-- success: "a row with this key exists" was conflated with "WE created this
-- row". The honest rule is: a REST row may be LOADED only when OUR OWN create
-- call for THIS record returned success (2xx). This migration adds a per-record
-- positive marker, LOAD_CALL_STATUS, that the results packages stamp 'CREATED'
-- on a 2xx POST of that record. PARSE_AND_UPDATE then promotes to LOADED only
-- when the base-table key matches AND LOAD_CALL_STATUS = 'CREATED'. A row whose
-- create 404'd (LOAD_CALL_STATUS left NULL) can no longer be rescued to LOADED
-- by a pre-existing key collision; it falls to the FAILED sweep (if a real
-- error was stashed) or stays GENERATED (honestly UNACCOUNTED).
--   Column:  LOAD_CALL_STATUS VARCHAR2(12)  NULL
--            NULL      = our create was never attempted / never returned 2xx
--            'CREATED' = our own POST for THIS record returned HTTP 2xx
--            'REJECTED'= our own POST for THIS record returned non-2xx
--   Objects (10 REST transform tables, one marker each):
--     DMT_INV_UOM_TFM_TBL                (UnitsOfMeasure)
--     DMT_FND_LOOKUP_TYPE_TFM_TBL        (Lookups - type tier)
--     DMT_FND_LOOKUP_VALUE_TFM_TBL       (Lookups - value tier)
--     DMT_AP_PAY_TERM_HDR_TFM_TBL        (APPaymentTerms - header tier)
--     DMT_AP_PAY_TERM_LINE_TFM_TBL       (APPaymentTerms - line tier)
--     DMT_CE_BANK_TFM_TBL                (CashBanks - bank tier)
--     DMT_CE_BRANCH_TFM_TBL              (CashBanks - branch tier)
--     DMT_CE_BANK_ACCT_TFM_TBL           (CashBanks - account tier)
--     DMT_ZX_REGIME_TFM_TBL              (Taxes - regime tier)
--     DMT_ZX_RATE_TFM_TBL                (Taxes - rate tier)
-- The create-table scripts (db/tables/...) now carry the column for fresh
-- installs; this migration converges an EXISTING database. NON-DESTRUCTIVE:
-- the column is only ADDED when absent; nothing is dropped or re-typed.
-- Historical LOADED rows keep their status (they were already proven by the
-- base table under the pre-#584 rule); the new guard only affects FUTURE runs.
--
-- FIX 1 -- Lookups module id. DMT_FND_LOOKUP_RESULTS_PKG hard-coded the
-- standardLookups ModuleId constant '40B3FA7250D19380E040449823C67A1A', which
-- the #130 live investigation observed returning HTTP 400 "Invalid Module ID"
-- on the demo pod. '817AA25E27D8124DE0401490D3C54C17' is a proven-valid
-- instance module id (direct POST -> HTTP 201, type confirmed in
-- FND_LOOKUP_TYPES). This migration seeds that proven-valid default into
-- DMT_CONFIG_TBL under key LOOKUP_DEFAULT_MODULE_ID so the id is CONFIGURABLE
-- per instance (via DMT_UTIL_PKG.GET_CONFIG) rather than a bare hard-code; the
-- package reads the config and falls back to the proven-valid literal if the
-- key is absent. ALSO: DMT_FND_LOOKUP_TYPE_STG_TBL.MODULE_KEY and
-- DMT_FND_LOOKUP_TYPE_TFM_TBL.MODULE_KEY were VARCHAR2(30) -- too narrow for a
-- 32-char module GUID carried per-record. Widen both to VARCHAR2(64). A MODIFY
-- that only GROWS a VARCHAR2 is safe and loss-less (no data rewrite, no
-- ORA-01441); guarded so it runs only when the column is still < 64.
--
-- -------------------------------------------------------------------------
-- IDEMPOTENT: every step is guarded on USER_TAB_COLUMNS / a MERGE, so running
-- the file twice is a no-op. Deploy as DMT2_OWNER (never ADMIN). ci_promote
-- runs every db/migrations file in chronological filename order, so this
-- deploys to GOLD as well as local.
-- =========================================================================
set define off
set serveroutput on

prompt == FIX 2: add LOAD_CALL_STATUS marker to the 10 REST transform tables (guarded) ==
declare
  -- one guarded ADD per table
  procedure add_marker(p_table in varchar2) is
    l_n pls_integer;
  begin
    select count(*) into l_n
      from user_tab_columns
     where table_name = p_table
       and column_name = 'LOAD_CALL_STATUS';
    if l_n = 0 then
      execute immediate
        'ALTER TABLE "' || p_table || '" ADD ("LOAD_CALL_STATUS" VARCHAR2(12))';
      execute immediate
        'COMMENT ON COLUMN "' || p_table || '"."LOAD_CALL_STATUS" IS '
        || '''Honest proof that OUR OWN REST create for THIS record returned 2xx '
        || '(backlog #130). NULL = never attempted / never 2xx; CREATED = our POST '
        || 'returned HTTP 2xx; REJECTED = our POST returned non-2xx. A row may be '
        || 'promoted to LOADED by the base-table reconcile ONLY when its key matches '
        || 'AND LOAD_CALL_STATUS = CREATED, so a create-failed row can never be '
        || 'rescued to LOADED by a pre-existing/duplicate key collision.''';
      dbms_output.put_line('Added LOAD_CALL_STATUS to ' || p_table || '.');
    else
      dbms_output.put_line('LOAD_CALL_STATUS already present on ' || p_table || ' (idempotent).');
    end if;
  end add_marker;
begin
  add_marker('DMT_INV_UOM_TFM_TBL');
  add_marker('DMT_FND_LOOKUP_TYPE_TFM_TBL');
  add_marker('DMT_FND_LOOKUP_VALUE_TFM_TBL');
  add_marker('DMT_AP_PAY_TERM_HDR_TFM_TBL');
  add_marker('DMT_AP_PAY_TERM_LINE_TFM_TBL');
  add_marker('DMT_CE_BANK_TFM_TBL');
  add_marker('DMT_CE_BRANCH_TFM_TBL');
  add_marker('DMT_CE_BANK_ACCT_TFM_TBL');
  add_marker('DMT_ZX_REGIME_TFM_TBL');
  add_marker('DMT_ZX_RATE_TFM_TBL');
end;
/

prompt == FIX 1a: widen Lookups MODULE_KEY to VARCHAR2(64) (STG + TFM, grow-only, guarded) ==
declare
  procedure widen_module_key(p_table in varchar2) is
    l_len pls_integer;
  begin
    select char_length into l_len
      from user_tab_columns
     where table_name = p_table
       and column_name = 'MODULE_KEY';
    if l_len < 64 then
      execute immediate
        'ALTER TABLE "' || p_table || '" MODIFY ("MODULE_KEY" VARCHAR2(64))';
      dbms_output.put_line('Widened ' || p_table || '.MODULE_KEY to VARCHAR2(64).');
    else
      dbms_output.put_line(p_table || '.MODULE_KEY already >= 64 (idempotent).');
    end if;
  exception
    when no_data_found then
      dbms_output.put_line(p_table || '.MODULE_KEY not present -- skipped.');
  end widen_module_key;
begin
  widen_module_key('DMT_FND_LOOKUP_TYPE_STG_TBL');
  widen_module_key('DMT_FND_LOOKUP_TYPE_TFM_TBL');
end;
/

prompt == FIX 1b: seed configurable, proven-valid standardLookups ModuleId default ==
-- '817AA25E27D8124DE0401490D3C54C17' is proven valid on the demo pod (direct
-- POST -> HTTP 201, type confirmed in FND_LOOKUP_TYPES). MERGE so an existing
-- value an operator set for another instance is NOT overwritten.
merge into DMT_CONFIG_TBL t
using (select 'LOOKUP_DEFAULT_MODULE_ID' config_key from dual) s
on (t.CONFIG_KEY = s.config_key)
when not matched then
  insert (CONFIG_KEY, CONFIG_VALUE)
  values ('LOOKUP_DEFAULT_MODULE_ID', '817AA25E27D8124DE0401490D3C54C17');

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-10-06_rest_load_call_status_and_module_key_widen.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'restloadcallstatus130', USER);

commit;
