-- DMT_BEN_PARTIC_RECON_DM query (BIP reconciliation report contract v1).
-- Mirror of the CDATA SQL in DMT_BEN_PARTIC_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six
-- Contract v1 parameters).
--
-- BenParticipant (Participant Enrollment) loads through HCM Data Loader as the
-- PersonBenefitBalance business object (DMT_BEN_PARTIC_HDL_GEN_PKG writes a
-- PersonBenefitBalance.dat). An HDL load has no interface table, so this report
-- returns the BASE tier only: one row per migrated record positively confirmed
-- by a HRC_INTEGRATION_KEY_MAP entry, with the Fusion-assigned SURROGATE_ID as
-- FUSION_ID. Per-record HDL failures are captured separately (RECONCILE tags
-- [FUSION_ERROR] from the HDL response before this report runs), so this report
-- returns BASE / SUCCESS rows only.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE('BASE'), FUSION_STATUS('SUCCESS'),
--   FUSION_ID (SURROGATE_ID), ERROR_MESSAGE (NULL), LOAD_REQUEST_ID (NULL),
--   SOURCE_REF (= SourceSystemId), DMT_REFERENCE (NULL).
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX,
--   P_CHUNK_SIZE, P_AFTER_KEY.  Keyset pagination by RECORD_KEY (P_AFTER_KEY).
--
-- RECORD_KEY / SOURCE_REF = the SourceSystemId written into
-- PersonBenefitBalance.dat = (prefixed PERSON_NUMBER) || '_BENENRL' = the
-- BenParticipant TFM row's RECON_KEY. Rows are filtered to
-- SOURCE_SYSTEM_OWNER='HRC_SQLLOADER' so Fusion-seeded PersonBenefitBalance
-- rows (owner FUSION) are never counted.
--
-- Verified live 2026-09-20 (fin_impl / ApplicationDB_FSCM):
--   * OBJECT_NAME 'PersonBenefitBalance' exists (838 rows: 10 HRC_SQLLOADER-
--     owned = our loads, 828 FUSION-seeded). SURROGATE_ID = the Fusion base id.
--   * BASE-TABLE NOTE: the brief named base table BEN_PRTT_ENRT_RSLT with
--     FUSION_ID = PRTT_ENRT_RSLT_ID. That mapping is INCORRECT for this load
--     path: PersonBenefitBalance SURROGATE_IDs do NOT join to
--     BEN_PRTT_ENRT_RSLT.PRTT_ENRT_RSLT_ID (zero matches on the pod), because
--     PersonBenefitBalance is a benefit-balance object, not an enrollment-
--     result object. The benefit-balance base table is not selectable by name
--     from the BIP reporting user, so HRC_INTEGRATION_KEY_MAP is the
--     authoritative base-tier source and SURROGATE_ID is the Fusion base id
--     (same approach as Salaries; faithful to the design doc's HDL note).
--   * Standalone paging behaviour confirmed against the current pod data — see
--     the PR body for the exact rows returned and the empty-page confirmation.

SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'BenParticipant'               AS object_type,
           m.source_system_id             AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(m.surrogate_id)            AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           m.source_system_id             AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   hrc_integration_key_map m
    WHERE  m.object_name         = 'PersonBenefitBalance'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENENRL' ESCAPE '\'
    GROUP BY m.source_system_id
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
