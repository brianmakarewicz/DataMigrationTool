-- ============================================================
-- GLBudgets BIP Reconciliation Query  (rewritten 2026-06-30)
-- Data source: ApplicationDB_FSCM
--
-- Budgets are CELLS, not transactions. GL_BUDGET_BALANCES holds one row per
-- (ledger + budget_name + period + account segments + currency + currency_type)
-- and carries NO run_name/request_id/interface id. So reconciliation is:
--
--   * POSITIVE (LOADED): a matching cell exists in GL_BUDGET_BALANCES that was
--     touched SINCE THE RUN STARTED (LAST_UPDATE_DATE >= :P_RUN_START) with the
--     expected DR/CR amount. The run-start filter eliminates false positives from
--     the mountain of pre-existing budget data on the same accounts.
--   * NEGATIVE (FAILED): a row still lingers in GL_BUDGET_INTERFACE (successful
--     rows are consumed/deleted on load) created since run start, carrying
--     ERROR_MESSAGE. Matched back to the staged cell by account/budget/period.
--
-- Parameters:
--   :P_RUN_START  = 'YYYY-MM-DD HH24:MI:SS' — pipeline run start (with a safety
--                   buffer applied by the caller for clock skew).
--   :P_LEDGER_ID  = optional ledger scope; NULL = all ledgers in the window.
--
-- ACCOUNT_KEY normalises all 30 segments (NVL to '#') so the results package can
-- build the same key from the TFM row regardless of NULL-vs-empty segments.
-- ============================================================
SELECT 'BAL'                                              AS rec_type,
       bb.ledger_id                                       AS ledger_id,
       bb.budget_name                                     AS budget_name,
       bb.period_name                                     AS period_name,
       bb.currency_code                                   AS currency_code,
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
                                                          AS account_key,
       bb.period_net_dr                                   AS dr_amount,
       bb.period_net_cr                                   AS cr_amount,
       CAST(NULL AS VARCHAR2(2000))                       AS error_message,
       TO_CHAR(bb.last_update_date,'YYYY-MM-DD HH24:MI:SS') AS event_date
FROM   gl_budget_balances bb
WHERE  bb.last_update_date >= TO_TIMESTAMP(:P_RUN_START,'YYYY-MM-DD HH24:MI:SS')
AND    (:P_LEDGER_ID IS NULL OR bb.ledger_id = TO_NUMBER(:P_LEDGER_ID))

UNION ALL

SELECT 'IFACE'                                            AS rec_type,
       bi.ledger_id                                       AS ledger_id,
       bi.budget_name                                     AS budget_name,
       bi.period_name                                     AS period_name,
       bi.currency_code                                   AS currency_code,
       NVL(bi.segment1,'#')||'|'||NVL(bi.segment2,'#')||'|'||NVL(bi.segment3,'#')||'|'||
       NVL(bi.segment4,'#')||'|'||NVL(bi.segment5,'#')||'|'||NVL(bi.segment6,'#')||'|'||
       NVL(bi.segment7,'#')||'|'||NVL(bi.segment8,'#')||'|'||NVL(bi.segment9,'#')||'|'||
       NVL(bi.segment10,'#')||'|'||NVL(bi.segment11,'#')||'|'||NVL(bi.segment12,'#')||'|'||
       NVL(bi.segment13,'#')||'|'||NVL(bi.segment14,'#')||'|'||NVL(bi.segment15,'#')||'|'||
       NVL(bi.segment16,'#')||'|'||NVL(bi.segment17,'#')||'|'||NVL(bi.segment18,'#')||'|'||
       NVL(bi.segment19,'#')||'|'||NVL(bi.segment20,'#')||'|'||NVL(bi.segment21,'#')||'|'||
       NVL(bi.segment22,'#')||'|'||NVL(bi.segment23,'#')||'|'||NVL(bi.segment24,'#')||'|'||
       NVL(bi.segment25,'#')||'|'||NVL(bi.segment26,'#')||'|'||NVL(bi.segment27,'#')||'|'||
       NVL(bi.segment28,'#')||'|'||NVL(bi.segment29,'#')||'|'||NVL(bi.segment30,'#')
                                                          AS account_key,
       CASE WHEN bi.budget_amount >= 0 THEN bi.budget_amount ELSE 0 END   AS dr_amount,
       CASE WHEN bi.budget_amount <  0 THEN -bi.budget_amount ELSE 0 END  AS cr_amount,
       bi.error_message                                   AS error_message,
       TO_CHAR(bi.creation_date,'YYYY-MM-DD HH24:MI:SS')  AS event_date
FROM   gl_budget_interface bi
WHERE  bi.creation_date >= TO_TIMESTAMP(:P_RUN_START,'YYYY-MM-DD HH24:MI:SS')
AND    (:P_LEDGER_ID IS NULL OR bi.ledger_id = TO_NUMBER(:P_LEDGER_ID))
