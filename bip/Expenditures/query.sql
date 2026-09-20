-- ============================================================
-- Expenditures (project costs) BIP reconciliation query -- BIP
-- reconciliation report contract v1 (nine columns, keyset
-- pagination). Data source: ApplicationDB_FSCM. This mirrors the
-- SQL embedded in DMT_EXP_RECON_DM.xdm for review; the .xdm is
-- authoritative.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- ONE object, two tiers. Expenditures is a single FBDI zip loaded by
-- "Import and Process Cost Transactions": interface table
-- PJC_TXN_XFACE_STAGE_ALL, base table PJC_EXP_ITEMS_ALL.
--
-- RECON KEY = ORIG_TRANSACTION_REFERENCE (Slot A native reference).
-- The transform stamps the run prefix onto it and that prefixed value
-- survives verbatim on the base row, so it is both the read-back key
-- and the run-scoped selector (LIKE :P_PREFIX || '%'). Load/import
-- ESS ids are not durably captured per row on this pod, so
-- :P_LOAD_REQUEST_ID / :P_IMPORT_ESS_ID cannot select the run alone;
-- they are declared for contract symmetry and stamped for traceability.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in PJC_EXP_ITEMS_ALL) => SUCCESS
--   INTERFACE (unprocessed, TRANSACTION_STATUS_CODE <> 'P') => ERROR
-- FUSION_ID non-null on every BASE row (EXPENDITURE_ITEM_ID).
--
-- ERROR_MESSAGE limitation (verified live): the cost interface has NO
-- error-text column, and PJC_TXN_ERRORS carries no
-- ORIG_TRANSACTION_REFERENCE, so a rejected row cannot be joined to
-- its real Fusion message from a queryable table. The per-row
-- rejection text lives in the import report XML, which the pipeline
-- harvests into DMT TFM.ERROR_TEXT. This query reports the interface
-- status code (the only signal the interface carries).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE tier -- SUCCESS. RECORD_KEY = prefixed ORIG_TRANSACTION_REFERENCE,
    -- persisted verbatim on the base row. DMT_REFERENCE = ATTRIBUTE1.
    SELECT
        'Expenditures'                       AS object_type,
        ei.orig_transaction_reference        AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        ei.expenditure_item_id               AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        ei.orig_transaction_reference        AS source_ref,
        ei.attribute1                        AS dmt_reference
    FROM   pjc_exp_items_all ei
    WHERE  ei.orig_transaction_reference LIKE :P_PREFIX || '%'

    UNION ALL

    -- INTERFACE tier -- rejections only (TRANSACTION_STATUS_CODE <> 'P').
    -- SUCCESS rows are covered by the BASE tier, so nothing is counted
    -- twice. ERROR_MESSAGE reports the interface status code; the real
    -- per-row Fusion text is retained by the reconciler from the report XML.
    SELECT
        'Expenditures'                       AS object_type,
        st.orig_transaction_reference        AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[INTERFACE] Rejected by Import and Process Cost Transactions '
             || '(TRANSACTION_STATUS_CODE=' || NVL(st.transaction_status_code,'NULL')
             || '; not costed to PJC_EXP_ITEMS_ALL). The cost interface has no '
             || 'error-text column; the per-row Fusion rejection message is in the '
             || 'import report XML, harvested to DMT TFM.ERROR_TEXT.'
                                             AS error_message,
        st.load_request_id                   AS load_request_id,
        st.orig_transaction_reference        AS source_ref,
        st.attribute1                        AS dmt_reference
    FROM   pjc_txn_xface_stage_all st
    WHERE  st.orig_transaction_reference LIKE :P_PREFIX || '%'
    AND    NVL(st.transaction_status_code,'X') <> 'P'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
