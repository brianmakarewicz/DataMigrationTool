-- =============================================================================
-- Issue #466 (RECOVERY / Option 2) — STG_SEQUENCE_ID collision fix for EXISTING DBs
-- 2026-09-25
--
-- Fresh installs create the 73 sequence-default STG tables as
-- GENERATED ALWAYS AS IDENTITY (the durable fix, in the table DDL).
--
-- EXISTING databases cannot be converted in place: Oracle does not allow turning
-- a plain column into an identity column via ALTER TABLE MODIFY (ORA-30673). This
-- migration therefore applies issue #466's Option 2 for existing tables:
--   1. ensure STG_SEQUENCE_ID defaults from its paired sequence, and
--   2. advance that sequence past the current MAX(STG_SEQUENCE_ID)
-- so the next load cannot violate the PK (ORA-00001).
--
-- The (table -> sequence) map below is authoritative, taken from each table's
-- original DEFAULT clause (git 796edc4, pre-identity). 15 Grants (GMS_AWD_*)
-- tables use abbreviated sequence names, so the map is explicit, not derived.
--
-- Idempotent and safe to re-run. Tables already on IDENTITY are skipped, so this
-- is a no-op on a fresh install.
-- =============================================================================
set serveroutput on size unlimited
prompt == Issue #466 recovery: restore STG_SEQUENCE_ID default + advance sequence past max ==
DECLARE
  TYPE t_pair  IS RECORD (tbl VARCHAR2(128), seq VARCHAR2(128));
  TYPE t_pairs IS TABLE OF t_pair;
  l_pairs t_pairs := t_pairs(
    t_pair(q'[DMT_ABSENCE_STG_TBL]', q'[DMT_ABSENCE_STG_SEQ]'),
    t_pair(q'[DMT_AP_INVOICES_INT_STG_TBL]', q'[DMT_AP_INVOICES_INT_STG_SEQ]'),
    t_pair(q'[DMT_AP_INVOICE_LINES_INT_STG_TBL]', q'[DMT_AP_INVOICE_LINES_INT_STG_SEQ]'),
    t_pair(q'[DMT_AP_PAY_TERM_HDR_STG_TBL]', q'[DMT_AP_PAY_TERM_HDR_STG_SEQ]'),
    t_pair(q'[DMT_AP_PAY_TERM_LINE_STG_TBL]', q'[DMT_AP_PAY_TERM_LINE_STG_SEQ]'),
    t_pair(q'[DMT_ASSIGNMENT_STG_TBL]', q'[DMT_ASSIGNMENT_STG_SEQ]'),
    t_pair(q'[DMT_BEN_BENFY_STG_TBL]', q'[DMT_BEN_BENFY_STG_SEQ]'),
    t_pair(q'[DMT_BEN_DEPEND_STG_TBL]', q'[DMT_BEN_DEPEND_STG_SEQ]'),
    t_pair(q'[DMT_BEN_PARTIC_STG_TBL]', q'[DMT_BEN_PARTIC_STG_SEQ]'),
    t_pair(q'[DMT_CE_BANK_ACCT_STG_TBL]', q'[DMT_CE_BANK_ACCT_STG_SEQ]'),
    t_pair(q'[DMT_CE_BANK_STG_TBL]', q'[DMT_CE_BANK_STG_SEQ]'),
    t_pair(q'[DMT_CE_BRANCH_STG_TBL]', q'[DMT_CE_BRANCH_STG_SEQ]'),
    t_pair(q'[DMT_EGP_ITEM_CAT_STG_TBL]', q'[DMT_EGP_ITEM_CAT_STG_SEQ]'),
    t_pair(q'[DMT_EGP_ITEM_STG_TBL]', q'[DMT_EGP_ITEM_STG_SEQ]'),
    t_pair(q'[DMT_FA_ASSET_ASSIGN_STG_TBL]', q'[DMT_FA_ASSET_ASSIGN_STG_SEQ]'),
    t_pair(q'[DMT_FA_ASSET_BOOK_STG_TBL]', q'[DMT_FA_ASSET_BOOK_STG_SEQ]'),
    t_pair(q'[DMT_FA_ASSET_HDR_STG_TBL]', q'[DMT_FA_ASSET_HDR_STG_SEQ]'),
    t_pair(q'[DMT_FND_LOOKUP_TYPE_STG_TBL]', q'[DMT_FND_LOOKUP_TYPE_STG_SEQ]'),
    t_pair(q'[DMT_FND_LOOKUP_VALUE_STG_TBL]', q'[DMT_FND_LOOKUP_VALUE_STG_SEQ]'),
    t_pair(q'[DMT_FND_VS_SET_STG_TBL]', q'[DMT_FND_VS_SET_STG_SEQ]'),
    t_pair(q'[DMT_FND_VS_VALUE_STG_TBL]', q'[DMT_FND_VS_VALUE_STG_SEQ]'),
    t_pair(q'[DMT_GL_BUDGET_INT_STG_TBL]', q'[DMT_GL_BUDGET_INT_STG_SEQ]'),
    t_pair(q'[DMT_GL_CALENDAR_STG_TBL]', q'[DMT_GL_CALENDAR_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_BDGT_PRDS_STG_TBL]', q'[DMT_GMS_AWD_BDGT_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_CERTS_STG_TBL]', q'[DMT_GMS_AWD_CERT_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_CFDAS_STG_TBL]', q'[DMT_GMS_AWD_CFDA_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_FUNDING_STG_TBL]', q'[DMT_GMS_AWD_FUND_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_FUND_ALLOC_STG_TBL]', q'[DMT_GMS_AWD_FALLOC_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_FUND_SRC_STG_TBL]', q'[DMT_GMS_AWD_FSRC_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_HEADERS_STG_TBL]', q'[DMT_GMS_AWD_HDR_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_KEYWORDS_STG_TBL]', q'[DMT_GMS_AWD_KW_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_ORG_CREDITS_STG_TBL]', q'[DMT_GMS_AWD_ORGCR_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_PERSONNEL_STG_TBL]', q'[DMT_GMS_AWD_PERS_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL]', q'[DMT_GMS_AWD_PFSRC_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL]', q'[DMT_GMS_AWD_PTBRD_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_PROJECTS_STG_TBL]', q'[DMT_GMS_AWD_PROJ_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_REFERENCES_STG_TBL]', q'[DMT_GMS_AWD_REF_STG_SEQ]'),
    t_pair(q'[DMT_GMS_AWD_TERMS_STG_TBL]', q'[DMT_GMS_AWD_TERM_STG_SEQ]'),
    t_pair(q'[DMT_INV_TRX_LOTS_STG_TBL]', q'[DMT_INV_TRX_LOTS_STG_SEQ]'),
    t_pair(q'[DMT_INV_TRX_SERIALS_STG_TBL]', q'[DMT_INV_TRX_SERIALS_STG_SEQ]'),
    t_pair(q'[DMT_INV_TRX_STG_TBL]', q'[DMT_INV_TRX_STG_SEQ]'),
    t_pair(q'[DMT_INV_UOM_STG_TBL]', q'[DMT_INV_UOM_STG_SEQ]'),
    t_pair(q'[DMT_PAY_REL_STG_TBL]', q'[DMT_PAY_REL_STG_SEQ]'),
    t_pair(q'[DMT_PERF_EVAL_RATING_STG_TBL]', q'[DMT_PERF_EVAL_RATING_STG_SEQ]'),
    t_pair(q'[DMT_PERF_EVAL_STG_TBL]', q'[DMT_PERF_EVAL_STG_SEQ]'),
    t_pair(q'[DMT_PJB_BILL_EVENTS_STG_TBL]', q'[DMT_PJB_BILL_EVENTS_STG_SEQ]'),
    t_pair(q'[DMT_PJC_EXPENDITURES_STG_TBL]', q'[DMT_PJC_EXPENDITURES_STG_SEQ]'),
    t_pair(q'[DMT_PLAN_BUDGET_STG_TBL]', q'[DMT_PLAN_BUDGET_STG_SEQ]'),
    t_pair(q'[DMT_POR_REQ_DISTS_STG_TBL]', q'[DMT_POR_REQ_DISTS_STG_SEQ]'),
    t_pair(q'[DMT_POR_REQ_HEADERS_STG_TBL]', q'[DMT_POR_REQ_HEADERS_STG_SEQ]'),
    t_pair(q'[DMT_POR_REQ_LINES_STG_TBL]', q'[DMT_POR_REQ_LINES_STG_SEQ]'),
    t_pair(q'[DMT_PO_DISTS_INT_STG_TBL]', q'[DMT_PO_DISTS_INT_STG_SEQ]'),
    t_pair(q'[DMT_PO_HEADERS_INT_STG_TBL]', q'[DMT_PO_HEADERS_INT_STG_SEQ]'),
    t_pair(q'[DMT_PO_LINES_INT_STG_TBL]', q'[DMT_PO_LINES_INT_STG_SEQ]'),
    t_pair(q'[DMT_PO_LINE_LOCS_INT_STG_TBL]', q'[DMT_PO_LINE_LOCS_INT_STG_SEQ]'),
    t_pair(q'[DMT_PRJ_BUDGET_STG_TBL]', q'[DMT_PRJ_BUDGET_STG_SEQ]'),
    t_pair(q'[DMT_RA_DISTS_STG_TBL]', q'[DMT_RA_DISTS_STG_SEQ]'),
    t_pair(q'[DMT_RA_LINES_STG_TBL]', q'[DMT_RA_LINES_STG_SEQ]'),
    t_pair(q'[DMT_RCV_HEADERS_STG_TBL]', q'[DMT_RCV_HEADERS_STG_SEQ]'),
    t_pair(q'[DMT_RCV_TRANSACTIONS_STG_TBL]', q'[DMT_RCV_TRANSACTIONS_STG_SEQ]'),
    t_pair(q'[DMT_SALARY_STG_TBL]', q'[DMT_SALARY_STG_SEQ]'),
    t_pair(q'[DMT_SAL_BASIS_STG_TBL]', q'[DMT_SAL_BASIS_STG_SEQ]'),
    t_pair(q'[DMT_TALENT_PROF_ITEM_STG_TBL]', q'[DMT_TALENT_PROF_ITEM_STG_SEQ]'),
    t_pair(q'[DMT_TALENT_PROF_STG_TBL]', q'[DMT_TALENT_PROF_STG_SEQ]'),
    t_pair(q'[DMT_TAX_CARD_COMP_STG_TBL]', q'[DMT_TAX_CARD_COMP_STG_SEQ]'),
    t_pair(q'[DMT_TAX_CARD_STG_TBL]', q'[DMT_TAX_CARD_STG_SEQ]'),
    t_pair(q'[DMT_W2_BAL_DTL_STG_TBL]', q'[DMT_W2_BAL_DTL_STG_SEQ]'),
    t_pair(q'[DMT_W2_BAL_STG_TBL]', q'[DMT_W2_BAL_STG_SEQ]'),
    t_pair(q'[DMT_WORK_REL_STG_TBL]', q'[DMT_WORK_REL_STG_SEQ]'),
    t_pair(q'[DMT_WORK_SCHED_DTL_STG_TBL]', q'[DMT_WORK_SCHED_DTL_STG_SEQ]'),
    t_pair(q'[DMT_WORK_SCHED_STG_TBL]', q'[DMT_WORK_SCHED_STG_SEQ]'),
    t_pair(q'[DMT_ZX_RATE_STG_TBL]', q'[DMT_ZX_RATE_STG_SEQ]'),
    t_pair(q'[DMT_ZX_REGIME_STG_TBL]', q'[DMT_ZX_REGIME_STG_SEQ]')
  );
  l_is_ident PLS_INTEGER;
  l_has_col  PLS_INTEGER;
  l_has_seq  PLS_INTEGER;
  l_max      NUMBER;
  l_cur      NUMBER;
  l_gap      NUMBER;
  l_dummy    NUMBER;
  l_ok       PLS_INTEGER := 0;
  l_skip     PLS_INTEGER := 0;
BEGIN
  FOR i IN 1 .. l_pairs.COUNT LOOP
    BEGIN
      -- Skip fresh/identity tables and anything missing its column/sequence.
      SELECT COUNT(*) INTO l_is_ident FROM user_tab_identity_cols
        WHERE table_name = l_pairs(i).tbl AND column_name = 'STG_SEQUENCE_ID';
      SELECT COUNT(*) INTO l_has_col FROM user_tab_columns
        WHERE table_name = l_pairs(i).tbl AND column_name = 'STG_SEQUENCE_ID';
      SELECT COUNT(*) INTO l_has_seq FROM user_sequences
        WHERE sequence_name = l_pairs(i).seq;
      IF l_is_ident > 0 OR l_has_col = 0 OR l_has_seq = 0 THEN
        l_skip := l_skip + 1;
        CONTINUE;
      END IF;

      -- 1. Restore the sequence DEFAULT (also recovers a cleared default).
      EXECUTE IMMEDIATE 'ALTER TABLE "' || l_pairs(i).tbl ||
        '" MODIFY ("STG_SEQUENCE_ID" DEFAULT "' || l_pairs(i).seq || '".NEXTVAL)';

      -- 2. Advance the sequence past MAX(id) so the next NEXTVAL cannot collide.
      EXECUTE IMMEDIATE 'SELECT NVL(MAX(STG_SEQUENCE_ID),0) FROM "' || l_pairs(i).tbl || '"' INTO l_max;
      EXECUTE IMMEDIATE 'SELECT "' || l_pairs(i).seq || '".NEXTVAL FROM dual' INTO l_cur;
      IF l_max >= l_cur THEN
        l_gap := l_max - l_cur + 1;
        EXECUTE IMMEDIATE 'ALTER SEQUENCE "' || l_pairs(i).seq || '" INCREMENT BY ' || l_gap;
        EXECUTE IMMEDIATE 'SELECT "' || l_pairs(i).seq || '".NEXTVAL FROM dual' INTO l_dummy;
        EXECUTE IMMEDIATE 'ALTER SEQUENCE "' || l_pairs(i).seq || '" INCREMENT BY 1';
      END IF;

      l_ok := l_ok + 1;
      DBMS_OUTPUT.PUT_LINE('466 OK ' || l_pairs(i).tbl ||
        ' (default=' || l_pairs(i).seq || '.NEXTVAL, next > ' || l_max || ')');
    EXCEPTION
      WHEN OTHERS THEN
        l_skip := l_skip + 1;
        DBMS_OUTPUT.PUT_LINE('466 SKIP ' || l_pairs(i).tbl || ': ' || SQLERRM);
    END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('466 recovery summary: fixed=' || l_ok || ', skipped=' || l_skip ||
    ' (of ' || l_pairs.COUNT || ')');
END;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-25_stg_seq_recover_466.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'stgseqrecover466', USER);

commit;
set feedback on
