-- ============================================================
-- BillingEvents (project billing) reconciliation data model V2 --
-- BIP reconciliation report contract v1 (nine columns, keyset
-- pagination, the six standard parameters). V2 (2026-10-07) is
-- deployed ALONGSIDE BILLING_EVENT_DM (V1); BIP objects are never
-- overwritten.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
--
-- SIX parameters (Contract v1): P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY.
--   No P_OFFSET / P_LIMIT.
--
-- OBJECT MODEL. BillingEvents is ONE object: one FBDI zip
-- (PjbBillEventsInterface), one interface table
-- (PJB_BILLING_EVENTS_INT), one base table (PJB_BILLING_EVENTS),
-- loaded by the ImportBillingEventJob ESS job. OBJECT_TYPE is the
-- constant 'BillingEvents'.
--
-- Row selection (owner decision 2026-10-07): rows are FOUND only by
-- the Fusion job ids of ONE work item (one load = one Import Billing
-- Events job). The reconciler calls this report once per work item
-- with that item's own ids.
--   BASE rows: PJB_BILLING_EVENTS.REQUEST_ID = :P_IMPORT_ESS_ID
--     (Fusion stamps the ImportBillingEventJob id on every event it
--     creates; verified live: run prefix 93294 events -> 10070690).
--   INTERFACE rows: PJB_BILLING_EVENTS_INT.LOAD_REQUEST_ID =
--     :P_LOAD_REQUEST_ID that did not process. This table is purged
--     after import (MOS 2534525.1), so the tier normally returns zero
--     rows; it is kept for a pre-purge reconciliation.
-- The run prefix and run id are never used to select rows (no LIKE
-- anywhere). P_RUN_ID and P_PREFIX are declared for contract symmetry
-- only. SOURCEREF is used only as RECORD_KEY, to match a row Fusion
-- returned back to its TFM row.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (row present in PJB_BILLING_EVENTS)               => SUCCESS
--   INTERFACE (unpurged, unprocessed row still in interface) => ERROR
-- FUSION_ID is non-null on every BASE row (EVENT_ID).
-- ERROR_MESSAGE: PJB_BILLING_EVENTS_INT has no error-text column, so
-- an INTERFACE/ERROR row returns the literal marker #IMPORT_REPORT#,
-- telling the reconciler to take the real Fusion message from the
-- ImportBillingEventReportJob output.
-- Keyset: ORDER BY RECORD_KEY (pinned to BINARY so the ordering and
-- the > comparison agree), only rows whose RECORD_KEY sorts after
-- :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE tier: events the work item's Import Billing Events job
    -- created, found by the job's REQUEST_ID. DMT_REFERENCE =
    -- ATTRIBUTE1 (the DFF slot; NULL until the segment is deployed).
    SELECT
        'BillingEvents'                      AS object_type,
        be.sourceref                         AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        be.event_id                          AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        be.request_id                        AS load_request_id,
        be.sourceref                         AS source_ref,
        be.attribute1                        AS dmt_reference
    FROM   pjb_billing_events be
    WHERE  be.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- INTERFACE tier: rejections of this load only (IMPORT_STATUS not
    -- a success value). SUCCESS is proven by the BASE tier, so nothing
    -- is counted twice.
    SELECT
        'BillingEvents'                      AS object_type,
        b.sourceref                          AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '#IMPORT_REPORT#'                    AS error_message,
        b.load_request_id                    AS load_request_id,
        b.sourceref                          AS source_ref,
        b.attribute1                         AS dmt_reference
    FROM   pjb_billing_events_int b
    WHERE  b.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID)
    AND    NVL(UPPER(b.import_status),'X')
             NOT IN ('COMPLETE','COMPLETED','IMPORTED','Y','PROCESSED','SUCCESS','P')
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned. The
-- ordering and the comparison are both pinned to BINARY so they agree.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
