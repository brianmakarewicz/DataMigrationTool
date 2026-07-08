-- ============================================================
-- Grants BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID)
--             :P_IMPORT_ESS_ID = Import ESS request ID (for base table lookup)
--
-- Tier 1 (INTERFACE): Rows in GMS_AWARD_HEADERS_INT after import.
--   PROCESSED_STATUS indicates per-row outcome.
--   Error detail comes from PROCESSED_MESSAGE + MESSAGE_USER_DETAILS +
--   MESSAGE_USER_ACTION columns (real error text, not CAST(NULL)).
--   No separate rejection table exists (verified: no GMS%ERR% tables).
--
-- Tier 2 (BASE): Rows that reached GMS_AWARD_HEADERS_B.
--   PK=ID. Linked via SUMMARY_REQUEST_ID = Import ESS job ID.
--
-- AD#19 compliant: uses real error message columns from interface table.
-- ============================================================
SELECT
    h.award_interface_id                AS award_id,
    h.award_name,
    h.award_number,
    'INTERFACE'                         AS source_type,
    h.processed_status                  AS fusion_status,
    h.award_interface_id                AS fusion_id,
    CASE
        WHEN h.processed_message IS NOT NULL THEN
            h.processed_message ||
            CASE WHEN h.message_user_details IS NOT NULL
                 THEN ' | ' || h.message_user_details ELSE '' END ||
            CASE WHEN h.message_user_action IS NOT NULL
                 THEN ' | Action: ' || h.message_user_action ELSE '' END
        ELSE NULL
    END                                 AS error_message
FROM   gms_award_headers_int h
WHERE  h.load_request_id = :P_BATCH_ID

UNION ALL

-- Tier 2 (BASE): GMS_AWARD_HEADERS_B — PK=ID, filter=SUMMARY_REQUEST_ID
SELECT
    b.id                                AS award_id,
    CAST(NULL AS VARCHAR2(300))         AS award_name,
    b.sponsor_award_number              AS award_number,
    'BASE'                              AS source_type,
    'SUCCESS'                           AS fusion_status,
    b.id                                AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))        AS error_message
FROM   gms_award_headers_b b
WHERE  b.summary_request_id = :P_IMPORT_ESS_ID
AND    :P_IMPORT_ESS_ID IS NOT NULL
