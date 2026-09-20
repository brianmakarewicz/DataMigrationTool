-- ============================================================
-- BillingEvents (project billing) BIP reconciliation query --
-- BIP reconciliation report contract v1 (nine columns, keyset
-- pagination). Data source: ApplicationDB_FSCM. This mirrors the
-- SQL embedded in BILLING_EVENT_DM.xdm for review; the .xdm is
-- authoritative.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. (P_BATCH_ID retired.)
--   No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- ONE object, two tiers. BillingEvents is a single FBDI zip loaded by
-- ImportBillingEventJob: interface table PJB_BILLING_EVENTS_INT, base
-- table PJB_BILLING_EVENTS. OBJECT_TYPE = constant 'BillingEvents'.
--
-- RECON KEY = SOURCEREF (Slot A native reference). The transform stamps
-- the run prefix onto it and that prefixed value survives verbatim on
-- the base row, so it is both the read-back key and the run-scoped
-- selector (LIKE :P_PREFIX || '%'). REQUEST_ID is present on the base
-- row on this pod but the prefix is the durable selector; the base
-- REQUEST_ID is returned as LOAD_REQUEST_ID for audit.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in PJB_BILLING_EVENTS)                    => SUCCESS
--   INTERFACE (unpurged, unprocessed row still in interface) => ERROR
-- FUSION_ID non-null on every BASE row (EVENT_ID).
--
-- SPECIAL / no-carrier case (verified live): PJB_BILLING_EVENTS_INT is
-- ALWAYS purged after import (MOS 2534525.1) and has no error-text
-- column, so the INTERFACE tier normally returns zero rows and cannot
-- carry a Fusion message. Per Contract v1 an INTERFACE/ERROR row
-- returns the literal marker #IMPORT_REPORT#, telling the reconciler to
-- harvest the real per-row message from the ImportBillingEventReportJob
-- output XML rather than fabricating one here.
-- DMT_REFERENCE = base-row ATTRIBUTE1 (DFF slot; NULL until the segment
-- is deployed -- verified NULL live, honest, not fabricated).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE tier -- SUCCESS. RECORD_KEY / SOURCE_REF = prefixed SOURCEREF,
    -- persisted verbatim on the base row. FUSION_ID = EVENT_ID.
    -- DMT_REFERENCE = ATTRIBUTE1.
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
    WHERE  :P_PREFIX IS NOT NULL
    AND    be.sourceref LIKE :P_PREFIX || '%'

    UNION ALL

    -- INTERFACE tier -- rejections only (IMPORT_STATUS not a success value).
    -- Normally empty (interface purged after import). SUCCESS rows are
    -- covered by the BASE tier, so nothing is counted twice.
    -- ERROR_MESSAGE = #IMPORT_REPORT# marker; the real per-row Fusion text
    -- is harvested by the reconciler from the import report XML.
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
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
