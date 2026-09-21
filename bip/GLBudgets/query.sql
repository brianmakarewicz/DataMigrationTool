-- ============================================================
-- GLBudgets BIP reconciliation query — BIP reconciliation
-- report Contract v1 (nine columns, keyset pagination).
-- Data source: ApplicationDB_FSCM. This mirrors the SQL embedded
-- in GL_BUDGET_DM.xdm for review; the .xdm is authoritative.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT,
--   no P_RUN_START / P_LEDGER_ID.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- WHY GLBudgets differs (structural, proven live 2026-09-20 —
-- see objects/GLBudget/README.md and DMT_DESIGN section 5):
--   * Budgets are CELLS, not transactions. GL_BUDGET_BALANCES holds
--     one row per (ledger + budget + period + 30 segments + currency
--     + currency_type) with NO surrogate id, run id, request id or
--     prefix. RECORD_KEY IS that composite cell key.
--   * No reachable Fusion surrogate id: GL_BUDGET_VERSIONS is
--     VPD-blocked (live SELECT -> ORA-00942). The honest, non-null
--     Fusion base-table id for a loaded cell is the GL account it
--     sits on: GL_CODE_COMBINATIONS.CODE_COMBINATION_ID.
--
-- Row selection:
--   BASE rows are loaded cells in GL_BUDGET_BALANCES scoped to the run
--     by a LAST_UPDATE_DATE window. A budget cell carries no run id,
--     request id or prefix, and import CONSUMES (deletes) the interface
--     rows of every cell it loads successfully -- so on a clean
--     all-success run there is no surviving interface footprint to join
--     back to. The signal that survives success is the cell's own
--     LAST_UPDATE_DATE: a cell this run loaded was touched at or after
--     the run's Validate and Load Budgets job (:P_IMPORT_ESS_ID) began.
--     BASE = cells with LAST_UPDATE_DATE >= that job's PROCESSSTART in
--     ESS_REQUEST_HISTORY. If :P_IMPORT_ESS_ID does not resolve, the
--     window is NULL and BASE returns nothing (never the whole cube).
--     FUSION_ID = the cell's CODE_COMBINATION_ID (30-segment join).
--   INTERFACE rows are the FAILED GL_BUDGET_INTERFACE rejections the
--     load left carrying :P_LOAD_REQUEST_ID, with real error text.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (loaded cell) => SUCCESS; INTERFACE (FAILED) => ERROR.
--
-- Keys:
--   RECORD_KEY / SOURCE_REF = composite cell key
--       ledger|budget|period|currency|seg1..seg30 (~ NULL as '#').
--   DMT_REFERENCE           = NULL (no DFF carrier on a budget cell).
--   FUSION_ID               = GL_CODE_COMBINATIONS.CODE_COMBINATION_ID.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT
        'GLBudgets'                          AS object_type,
        bb.ledger_id || '|' || bb.budget_name || '|' || bb.period_name
          || '|' || bb.currency_code || '|' ||
          NVL(bb.segment1,'#')||'|'||NVL(bb.segment2,'#')||'|'||NVL(bb.segment3,'#')||'|'||
          NVL(bb.segment4,'#')||'|'||NVL(bb.segment5,'#')||'|'||NVL(bb.segment6,'#')||'|'||
          NVL(bb.segment7,'#')||'|'||NVL(bb.segment8,'#')||'|'||NVL(bb.segment9,'#')||'|'||
          NVL(bb.segment10,'#')||'|'||NVL(bb.segment11,'#')||'|'||NVL(bb.segment12,'#')||'|'||
          NVL(bb.segment13,'#')||'|'||NVL(bb.segment14,'#')||'|'||NVL(bb.segment15,'#')||'|'||
          NVL(bb.segment16,'#')||'|'||NVL(bb.segment17,'#')||'|'||NVL(bb.segment18,'#')||'|'||
          NVL(bb.segment19,'#')||'|'||NVL(bb.segment20,'#')||'|'||NVL(bb.segment21,'#')||'|'||
          NVL(bb.segment22,'#')||'|'||NVL(bb.segment23,'#')||'|'||NVL(bb.segment24,'#')||'|'||
          NVL(bb.segment25,'#')||'|'||NVL(bb.segment26,'#')||'|'||NVL(bb.segment27,'#')||'|'||
          NVL(bb.segment28,'#')||'|'||NVL(bb.segment29,'#')||'|'||NVL(bb.segment30,'#')
                                             AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        gcc.code_combination_id              AS fusion_id,
        CAST(NULL AS VARCHAR2(2000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        bb.ledger_id || '|' || bb.budget_name || '|' || bb.period_name
          || '|' || bb.currency_code || '|' ||
          NVL(bb.segment1,'#')||'|'||NVL(bb.segment2,'#')||'|'||NVL(bb.segment3,'#')||'|'||
          NVL(bb.segment4,'#')||'|'||NVL(bb.segment5,'#')||'|'||NVL(bb.segment6,'#')||'|'||
          NVL(bb.segment7,'#')||'|'||NVL(bb.segment8,'#')||'|'||NVL(bb.segment9,'#')||'|'||
          NVL(bb.segment10,'#')||'|'||NVL(bb.segment11,'#')||'|'||NVL(bb.segment12,'#')||'|'||
          NVL(bb.segment13,'#')||'|'||NVL(bb.segment14,'#')||'|'||NVL(bb.segment15,'#')||'|'||
          NVL(bb.segment16,'#')||'|'||NVL(bb.segment17,'#')||'|'||NVL(bb.segment18,'#')||'|'||
          NVL(bb.segment19,'#')||'|'||NVL(bb.segment20,'#')||'|'||NVL(bb.segment21,'#')||'|'||
          NVL(bb.segment22,'#')||'|'||NVL(bb.segment23,'#')||'|'||NVL(bb.segment24,'#')||'|'||
          NVL(bb.segment25,'#')||'|'||NVL(bb.segment26,'#')||'|'||NVL(bb.segment27,'#')||'|'||
          NVL(bb.segment28,'#')||'|'||NVL(bb.segment29,'#')||'|'||NVL(bb.segment30,'#')
                                             AS source_ref,
        CAST(NULL AS VARCHAR2(2000))         AS dmt_reference
    FROM   gl_budget_balances bb
    JOIN   gl_ledgers led
      ON   led.ledger_id = bb.ledger_id
    -- Resolve the cell's real GL account id from ALL 30 segments (the
    -- same 30 that build RECORD_KEY). Matching only the first 10 could
    -- bind the wrong CODE_COMBINATION_ID or fan the join out on any
    -- chart of accounts that uses more than 10 significant segments.
    JOIN   gl_code_combinations gcc
      ON   gcc.chart_of_accounts_id = led.chart_of_accounts_id
     AND   NVL(gcc.segment1 ,'#') = NVL(bb.segment1 ,'#')
     AND   NVL(gcc.segment2 ,'#') = NVL(bb.segment2 ,'#')
     AND   NVL(gcc.segment3 ,'#') = NVL(bb.segment3 ,'#')
     AND   NVL(gcc.segment4 ,'#') = NVL(bb.segment4 ,'#')
     AND   NVL(gcc.segment5 ,'#') = NVL(bb.segment5 ,'#')
     AND   NVL(gcc.segment6 ,'#') = NVL(bb.segment6 ,'#')
     AND   NVL(gcc.segment7 ,'#') = NVL(bb.segment7 ,'#')
     AND   NVL(gcc.segment8 ,'#') = NVL(bb.segment8 ,'#')
     AND   NVL(gcc.segment9 ,'#') = NVL(bb.segment9 ,'#')
     AND   NVL(gcc.segment10,'#') = NVL(bb.segment10,'#')
     AND   NVL(gcc.segment11,'#') = NVL(bb.segment11,'#')
     AND   NVL(gcc.segment12,'#') = NVL(bb.segment12,'#')
     AND   NVL(gcc.segment13,'#') = NVL(bb.segment13,'#')
     AND   NVL(gcc.segment14,'#') = NVL(bb.segment14,'#')
     AND   NVL(gcc.segment15,'#') = NVL(bb.segment15,'#')
     AND   NVL(gcc.segment16,'#') = NVL(bb.segment16,'#')
     AND   NVL(gcc.segment17,'#') = NVL(bb.segment17,'#')
     AND   NVL(gcc.segment18,'#') = NVL(bb.segment18,'#')
     AND   NVL(gcc.segment19,'#') = NVL(bb.segment19,'#')
     AND   NVL(gcc.segment20,'#') = NVL(bb.segment20,'#')
     AND   NVL(gcc.segment21,'#') = NVL(bb.segment21,'#')
     AND   NVL(gcc.segment22,'#') = NVL(bb.segment22,'#')
     AND   NVL(gcc.segment23,'#') = NVL(bb.segment23,'#')
     AND   NVL(gcc.segment24,'#') = NVL(bb.segment24,'#')
     AND   NVL(gcc.segment25,'#') = NVL(bb.segment25,'#')
     AND   NVL(gcc.segment26,'#') = NVL(bb.segment26,'#')
     AND   NVL(gcc.segment27,'#') = NVL(bb.segment27,'#')
     AND   NVL(gcc.segment28,'#') = NVL(bb.segment28,'#')
     AND   NVL(gcc.segment29,'#') = NVL(bb.segment29,'#')
     AND   NVL(gcc.segment30,'#') = NVL(bb.segment30,'#')
    -- Scope each cell to THIS run by a LAST_UPDATE_DATE window that
    -- opens at the run's Validate and Load Budgets PROCESSSTART. This
    -- survives a fully-successful load (unlike the consumed interface
    -- rows). If :P_IMPORT_ESS_ID does not resolve, the window is NULL
    -- and the >= comparison selects nothing -- never the whole cube.
    WHERE  bb.last_update_date >= (
             SELECT MIN(erh.processstart)
             FROM   fusion.ess_request_history erh
             WHERE  erh.requestid = TO_NUMBER(:P_IMPORT_ESS_ID)
           )

    UNION ALL

    SELECT
        'GLBudgets'                          AS object_type,
        gi.ledger_id || '|' || gi.budget_name || '|' || gi.period_name
          || '|' || gi.currency_code || '|' ||
          NVL(gi.segment1,'#')||'|'||NVL(gi.segment2,'#')||'|'||NVL(gi.segment3,'#')||'|'||
          NVL(gi.segment4,'#')||'|'||NVL(gi.segment5,'#')||'|'||NVL(gi.segment6,'#')||'|'||
          NVL(gi.segment7,'#')||'|'||NVL(gi.segment8,'#')||'|'||NVL(gi.segment9,'#')||'|'||
          NVL(gi.segment10,'#')||'|'||NVL(gi.segment11,'#')||'|'||NVL(gi.segment12,'#')||'|'||
          NVL(gi.segment13,'#')||'|'||NVL(gi.segment14,'#')||'|'||NVL(gi.segment15,'#')||'|'||
          NVL(gi.segment16,'#')||'|'||NVL(gi.segment17,'#')||'|'||NVL(gi.segment18,'#')||'|'||
          NVL(gi.segment19,'#')||'|'||NVL(gi.segment20,'#')||'|'||NVL(gi.segment21,'#')||'|'||
          NVL(gi.segment22,'#')||'|'||NVL(gi.segment23,'#')||'|'||NVL(gi.segment24,'#')||'|'||
          NVL(gi.segment25,'#')||'|'||NVL(gi.segment26,'#')||'|'||NVL(gi.segment27,'#')||'|'||
          NVL(gi.segment28,'#')||'|'||NVL(gi.segment29,'#')||'|'||NVL(gi.segment30,'#')
                                             AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[LINE] ' || NVL(gi.error_message,
             'Rejected by Validate and Load Budgets (cell not created in GL_BUDGET_BALANCES).')
                                             AS error_message,
        gi.load_request_id                   AS load_request_id,
        gi.ledger_id || '|' || gi.budget_name || '|' || gi.period_name
          || '|' || gi.currency_code || '|' ||
          NVL(gi.segment1,'#')||'|'||NVL(gi.segment2,'#')||'|'||NVL(gi.segment3,'#')||'|'||
          NVL(gi.segment4,'#')||'|'||NVL(gi.segment5,'#')||'|'||NVL(gi.segment6,'#')||'|'||
          NVL(gi.segment7,'#')||'|'||NVL(gi.segment8,'#')||'|'||NVL(gi.segment9,'#')||'|'||
          NVL(gi.segment10,'#')||'|'||NVL(gi.segment11,'#')||'|'||NVL(gi.segment12,'#')||'|'||
          NVL(gi.segment13,'#')||'|'||NVL(gi.segment14,'#')||'|'||NVL(gi.segment15,'#')||'|'||
          NVL(gi.segment16,'#')||'|'||NVL(gi.segment17,'#')||'|'||NVL(gi.segment18,'#')||'|'||
          NVL(gi.segment19,'#')||'|'||NVL(gi.segment20,'#')||'|'||NVL(gi.segment21,'#')||'|'||
          NVL(gi.segment22,'#')||'|'||NVL(gi.segment23,'#')||'|'||NVL(gi.segment24,'#')||'|'||
          NVL(gi.segment25,'#')||'|'||NVL(gi.segment26,'#')||'|'||NVL(gi.segment27,'#')||'|'||
          NVL(gi.segment28,'#')||'|'||NVL(gi.segment29,'#')||'|'||NVL(gi.segment30,'#')
                                             AS source_ref,
        CAST(NULL AS VARCHAR2(2000))         AS dmt_reference
    FROM   gl_budget_interface gi
    WHERE  gi.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    gi.status = 'FAILED'
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
