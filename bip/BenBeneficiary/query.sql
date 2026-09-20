-- DMT_BEN_BENFY_RECON_DM query (BIP reconciliation report contract v1).
-- Mirror of the CDATA SQL in DMT_BEN_BENFY_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six Contract v1
-- parameters).
--
-- BenBeneficiary (Benefit beneficiary designations) loads through HCM Data Loader
-- as the BeneficiaryEnrollment business object (parent) with the DesignateBeneficiary
-- child (DMT_BEN_BENFY_HDL_GEN_PKG writes a BeneficiaryEnrollment.dat). An HDL load
-- has no interface table, so this report returns the BASE tier only: one row per
-- migrated enrollment positively confirmed by a HRC_INTEGRATION_KEY_MAP entry, with
-- the Fusion-assigned SURROGATE_ID as FUSION_ID. Per-record HDL failures are captured
-- separately (RECONCILE_HDL tags [FUSION_ERROR] from the HDL response before this
-- report runs), so this report returns BASE / SUCCESS rows only.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE('BASE'), FUSION_STATUS('SUCCESS'),
--   FUSION_ID (SURROGATE_ID), ERROR_MESSAGE (NULL), LOAD_REQUEST_ID (NULL),
--   SOURCE_REF (= SourceSystemId), DMT_REFERENCE (NULL).
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX,
--   P_CHUNK_SIZE, P_AFTER_KEY.  Keyset pagination by RECORD_KEY (P_AFTER_KEY).
--
-- RECORD_KEY / SOURCE_REF = the SourceSystemId written onto the parent
-- BeneficiaryEnrollment component = (prefixed PERSON_NUMBER) || '_BENENRL' = the
-- BenBeneficiary TFM row's RECON_KEY. Rows are filtered to
-- SOURCE_SYSTEM_OWNER='HRC_SQLLOADER' so Fusion-seeded rows (owner FUSION) are never
-- counted.
--
-- Verified live 2026-09-20 (fin_impl / ApplicationDB_FSCM):
--   * OBJECT_NAME 'BeneficiaryEnrollment' has NO rows yet in HRC_INTEGRATION_KEY_MAP
--     on this pod — beneficiary designation has not been re-loaded through the
--     corrected generator here. This report therefore returns zero rows against the
--     live pod today (honest empty result, not a failure).
--   * The historical HRC_SQLLOADER beneficiary loads are recorded under the WRONG
--     object PersonBenefitBalance with the OLD suffix '_BENBNFY' (e.g.
--     67936DMTBNFY001_BENBNFY -> SURROGATE_ID 300000331552758). Their SURROGATE_ID
--     values are real populated Fusion base ids, which validates the map-row +
--     SURROGATE_ID base-tier shape this report depends on. They are excluded here
--     because this report targets the correct object and the new _BENENRL suffix.
--   * Standalone nine-column population and keyset paging (page then empty page) were
--     validated best-effort against the structurally identical PersonBenefitBalance
--     key rows — see the PR body for the exact rows returned and the empty-page
--     confirmation.
--   * BASE-TABLE NOTE: beneficiary designation lands in Benefits (BEN_*) base tables
--     that are not selectable by name from the FSCM BIP reporting user (same
--     restriction Salaries and BenParticipant hit); HRC_INTEGRATION_KEY_MAP is the
--     authoritative base-tier source and SURROGATE_ID is the Fusion base id.

SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'BenBeneficiary'               AS object_type,
           m.source_system_id             AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(m.surrogate_id)            AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           m.source_system_id             AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   hrc_integration_key_map m
    WHERE  m.object_name         = 'BeneficiaryEnrollment'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENENRL' ESCAPE '\'
    GROUP BY m.source_system_id
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
