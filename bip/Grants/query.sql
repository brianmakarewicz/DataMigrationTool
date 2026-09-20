-- ============================================================
-- Grants BIP reconciliation query -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination). Data source:
-- ApplicationDB_FSCM. This mirrors the SQL embedded in
-- DMT_GRANT_RECON_DM.xdm for review; the .xdm is authoritative.
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
-- OBJECT: Grants award headers (AwardMassImportJob). Awards import
-- as ONE object (the header). The award children -- projects,
-- funding, personnel, terms, etc. -- have NO persistent Fusion base
-- or interface tables to reconcile against on this pod (verified:
-- no GMS_AWARD_PROJ% tables exist; the *_INT interface tables are
-- PURGED by Fusion right after import). So this DM reconciles the
-- award HEADER tier only; per-award children are covered indirectly
-- (a header that reached the base table imported its children with
-- it, and a rejected header carries its real Fusion message).
--
-- TWO tiers, discriminated by OBJECT_TYPE / SOURCE_TYPE and
-- UNION ALL-ed, then ordered by RECORD_KEY:
--
--   BASE      -- rows that reached GMS_AWARD_HEADERS_B for this run.
--     Run scoping: DC_REQUEST_ID = :P_IMPORT_ESS_ID. (VERIFIED on
--     the live pod: for AWARD_SOURCE='FBDI' rows, SUMMARY_REQUEST_ID
--     is always NULL and DC_REQUEST_ID carries the real import ESS
--     request id -- e.g. DC_REQUEST_ID=8317302. The old two-column
--     stub filtered on SUMMARY_REQUEST_ID and would have returned
--     zero base rows.) AWARD_SOURCE='FBDI' excludes UI-entered awards.
--     FUSION_ID = ID (award id). RECORD_KEY = SPONSOR_AWARD_NUMBER
--     when present, else a stable 'AWARD_ID:'||ID key so the keyset
--     order is never null. SOURCE_REF = AWARD_SOURCE ('FBDI'/'UI').
--     DMT_REFERENCE = ATTRIBUTE1 (DMT descriptive-flexfield slot).
--
--   INTERFACE -- rows still in GMS_AWARD_HEADERS_INT after import
--     that Fusion did not mark successful. These are per-award
--     rejections. Run scoping: LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID.
--     RECORD_KEY = AWARD_NUMBER (the prefixed number DMT stamps at
--     transform, so it reads back exactly). Real Fusion error text
--     from PROCESSED_MESSAGE + MESSAGE_USER_DETAILS + MESSAGE_USER_ACTION
--     (never CAST(NULL) -- AD#19).
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in base table) => SUCCESS.
--   INTERFACE (rejection left behind)          => ERROR.
-- FUSION_ID non-null on every BASE row; ERROR_MESSAGE non-null on
-- every ERROR row.
--
-- POD NOTE: Grants is NOT configured on the demo pod, so a live DMT
-- run rejects every award at import and the INTERFACE tier is the
-- populated one. GMS_AWARD_HEADERS_B still holds 117 historical rows
-- (57 FBDI / 44 UI from earlier work), so the BASE tier's shape is
-- proven against real data even though a fresh run lands zero there.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Tier: BASE -- award headers that reached GMS_AWARD_HEADERS_B
    -- for this import request. Run-scoped by DC_REQUEST_ID.
    SELECT
        'Grants'                             AS object_type,
        NVL(b.sponsor_award_number,
            'AWARD_ID:' || b.id)             AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        b.id                                 AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        b.award_source                       AS source_ref,
        b.attribute1                         AS dmt_reference
    FROM   gms_award_headers_b b
    WHERE  b.dc_request_id = :P_IMPORT_ESS_ID
    AND    b.award_source  = 'FBDI'

    UNION ALL

    -- Tier: INTERFACE -- award headers still in the interface table
    -- after import that Fusion did not mark successful = rejections.
    SELECT
        'Grants'                             AS object_type,
        h.award_number                       AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[AWARD] ' || NVL(
            NULLIF(
                h.processed_message
                || CASE WHEN h.message_user_details IS NOT NULL
                        THEN ' | ' || h.message_user_details ELSE '' END
                || CASE WHEN h.message_user_action IS NOT NULL
                        THEN ' | Action: ' || h.message_user_action ELSE '' END,
                ''),
            'Rejected by Award Import (processed_status='
                || NVL(h.processed_status,'NULL')
                || '; no message written -- e.g. rejected pre-validation).')
                                             AS error_message,
        h.load_request_id                    AS load_request_id,
        h.award_number                       AS source_ref,
        h.attribute1                         AS dmt_reference
    FROM   gms_award_headers_int h
    WHERE  h.load_request_id = :P_LOAD_REQUEST_ID
    AND    NVL(UPPER(h.processed_status),'X') NOT IN ('SUCCESS','S','PROCESSED')
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
