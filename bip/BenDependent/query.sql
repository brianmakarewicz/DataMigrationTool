-- DMT_BEN_DEPEND_RECON_DM query (BIP reconciliation report contract v1).
-- Mirror of the CDATA SQL in DMT_BEN_DEPEND_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six
-- Contract v1 parameters).
--
-- BenDependent (Benefit dependents / person contacts) loads through HCM Data
-- Loader as the PersonBenefitBalance business object (DMT_BEN_DEPEND_HDL_GEN_PKG
-- writes a PersonBenefitBalance.dat; DependentBenefitBalance is NOT a valid HDL
-- discriminator, so all three benefit sub-objects share PersonBenefitBalance).
-- An HDL load has no interface table, so this report returns the BASE tier only:
-- one row per migrated dependent positively confirmed in the HCM Benefits base
-- table BEN_PER_BNFTS_BAL_F, with the real Fusion PER_BNFTS_BAL_ID as FUSION_ID.
-- Per-record HDL failures are captured separately (RECONCILE tags [FUSION_ERROR]
-- from the HDL response before this report runs), so this report returns
-- BASE / SUCCESS rows only.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE('BASE'), FUSION_STATUS('SUCCESS'),
--   FUSION_ID (base PER_BNFTS_BAL_ID), ERROR_MESSAGE (NULL),
--   LOAD_REQUEST_ID (NULL), SOURCE_REF (= SourceSystemId), DMT_REFERENCE (NULL).
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX,
--   P_CHUNK_SIZE, P_AFTER_KEY.  Keyset pagination by RECORD_KEY (P_AFTER_KEY).
--
-- RECORD_KEY / SOURCE_REF = the SourceSystemId written into
-- PersonBenefitBalance.dat = (prefixed PERSON_NUMBER) || '_BENDEP' = the
-- BenDependent TFM row's RECON_KEY. Rows are filtered to
-- SOURCE_SYSTEM_OWNER='HRC_SQLLOADER' so Fusion-seeded PersonBenefitBalance rows
-- (owner FUSION) are never counted, and JOINED to the base table so FUSION_ID is
-- guaranteed a real base-table primary key.
--
-- Verified live 2026-09-20 (fin_impl / ApplicationDB_FSCM):
--   * OBJECT_NAME 'PersonBenefitBalance' exists (838 rows: 10 HRC_SQLLOADER-
--     owned = our loads, 828 FUSION-seeded).
--   * BASE-TABLE JOIN PROVEN: all 10 HRC_SQLLOADER PersonBenefitBalance
--     SURROGATE_IDs join BEN_PER_BNFTS_BAL_F.PER_BNFTS_BAL_ID one-for-one, so
--     FUSION_ID is a real base primary key (round-tripped a key back to its PK).
--   * NINE-column shape + keyset paging confirmed against the current pod data:
--     page 1 (chunk 3, no cursor) returned 3 rows with real base PKs; page 2
--     (cursor = page 1's last RECORD_KEY) skipped page 1 and returned the next
--     3 keys; the production _BENDEP predicate returns ZERO rows.
--   * OUR _BENDEP rows are NOT present: employee benefit enrollment is not
--     configured on the demo instance and the migrated workers are not enrolled
--     in any plan, so the dependent load is rejected upstream (documented
--     BLOCKER, objects/Benefits/README.md). The report is correct and its shape
--     is proven live; it will return our rows once enrollment is configured.

SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'BenDependent'                 AS object_type,
           m.source_system_id             AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(b.per_bnfts_bal_id)        AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           m.source_system_id             AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   hrc_integration_key_map m
    JOIN   ben_per_bnfts_bal_f b
           ON b.per_bnfts_bal_id = m.surrogate_id
    WHERE  m.object_name         = 'PersonBenefitBalance'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENDEP' ESCAPE '\'
    GROUP BY m.source_system_id
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
