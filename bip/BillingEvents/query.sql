-- ============================================================
-- BillingEvents BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--             :P_IMPORT_ESS_ID = Import ESS request ID (for base table lookup)
--             :P_PREFIX = Run prefix for SOURCEREF matching on base table
--
-- Tier 1 (INTERFACE): Rows in PJB_BILLING_EVENTS_INT after import.
--   NOTE: This table is ALWAYS purged after ImportBillingEventJob completes
--   (both success and failure). Tier 1 will typically return 0 rows.
--   Kept for the rare case where reconciliation runs before purge.
--
-- Tier 2 (BASE): Rows that reached PJB_BILLING_EVENTS.
--   Matched via prefix-based SOURCEREF pattern. Interface table subquery
--   removed because the table is always purged (MOS 2534525.1).
--
-- AD#19 note: PJB_BILLING_EVENTS_INT has NO error message column (verified:
-- no %MSG%, %ERR%, %DETAIL% columns exist). Error detail comes from
-- ImportBillingEventReportJob ESS output.
-- ============================================================
SELECT
    b.sourceref,
    b.project_number,
    b.task_number,
    'INTERFACE'                         AS source_type,
    b.load_status,
    b.import_status,
    CAST(NULL AS NUMBER)                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjb_billing_events_int b
WHERE  b.load_request_id = :P_BATCH_ID

UNION ALL

-- Tier 2 (BASE): PJB_BILLING_EVENTS — PK=EVENT_ID, key=SOURCEREF
-- Uses prefix-based matching since interface table is always purged
SELECT
    be.sourceref,
    CAST(NULL AS VARCHAR2(25))          AS project_number,
    CAST(NULL AS VARCHAR2(100))         AS task_number,
    'BASE'                              AS source_type,
    'SUCCESS'                           AS load_status,
    'SUCCESS'                           AS import_status,
    be.event_id                         AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   pjb_billing_events be
WHERE  be.sourceref LIKE :P_PREFIX || '%'
AND    :P_PREFIX IS NOT NULL
