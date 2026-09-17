-- DMT_W2BALANCES_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_W2BALANCES_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- CORRECTED MODEL (2026-09-17): W2Balances loads through the HCM Data Loader as the
-- "Balance Initialization" business object -- TWO HDL objects in one zip:
--   InitializeBalanceBatchHeader -> InitializeBalanceBatchHeader.dat
--     METADATA: BatchName|UploadDate|LegislativeDataGroupName
--   InitializeBalanceBatchLine   -> InitializeBalanceBatchLine.dat
--     METADATA: LegislativeDataGroupName|BatchName|LineSequence|
--       PayrollRelationshipNumber|TermNumber|AssignmentNumber|PayrollName|
--       TaxUnitName|BalanceName|DimensionName|Value|ContextOneName|
--       ContextOneValue|AreaOne
-- One run = ONE batch; every line references the header by BatchName (no worker
-- record repeated). A "Load Initial Balances" (Transfer Batch) payroll flow is run
-- in Fusion afterwards to apply the staged batch. This replaces the outdated
-- PayrollBalanceInitialization.dat model, which Fusion rejects.
--
-- Returns the BASE tier: one row per migrated balance-initialization batch
-- positively confirmed in the Fusion payroll balance base table
-- PAY_BAL_BATCH_HEADERS, with the real Fusion BATCH_ID as FUSION_ID. HDL
-- per-record failures are captured separately (RECONCILE_HDL tags [FUSION_ERROR]
-- before this report runs), so this report returns BASE/SUCCESS rows only; the
-- shared parser marks a W2Balances row LOADED only from a BASE / SUCCESS /
-- FUSION_ID-not-null row.
--
-- MATCH KEY: the batch's user key BATCH_NAME, which we control and prefix.
--   BatchName = <run prefix> || '_W2BAL'  (the generator's BatchName)
--            = PAY_BAL_BATCH_HEADERS.BATCH_NAME
--            = the W2Balances TFM row's RECON_KEY.
-- Balance-initialization batch objects are keyed by BatchName (a user key), not by
-- a person SourceSystemId, so BATCH_NAME matching is correct and robust.
--
-- Verified live 2026-09-16/17 (--cred fin_impl):
--   -- object names confirmed on this pod:
--   SELECT object_name, COUNT(*) FROM hrc_integration_key_map
--   WHERE  object_name LIKE 'InitializeBalanceBatch%' GROUP BY object_name;
--     -> InitializeBalanceBatchHeader 7 ; InitializeBalanceBatchLine 13
--   -- base table + business key directly queryable:
--   SELECT batch_id, batch_name FROM pay_bal_batch_headers
--   WHERE  batch_name LIKE 'DMT%';
--     -> 300000331552768 DMTW232147 ; 300000331553085 DMTW210163 ; ...
-- NOTE: existing batches carry no DMT '_W2BAL' BatchName yet, so this report
-- returns zero rows for a DMT prefix until a real DMT HDL balance batch lands.
-- Zero rows is never LOADED.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'W2Balances'                    AS object_type,
           h.batch_name                    AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(h.batch_id)                 AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   pay_bal_batch_headers   h
    WHERE  h.batch_name LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR h.batch_name > :P_AFTER_KEY)
    GROUP BY h.batch_name
    ORDER BY h.batch_name
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
