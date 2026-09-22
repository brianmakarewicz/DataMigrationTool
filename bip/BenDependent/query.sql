-- DMT_BENDEPENDENT_RECON_DM query (Contract v1, nine-column, design section 5).
-- Mirror of the CDATA SQL in DMT_BENDEPENDENT_RECON_DM.xdm, kept here for review and for
-- running the query standalone against live Fusion (bind the six parameters).
--
-- RE-POINTED 2026-09-22 to the CORRECT Fusion object. BenDependent loads through the HCM
-- Data Loader as the DependentEnrollment business object with its child component
-- DesignateDependent (DependentEnrollment.dat -- see
-- db/packages/dmt_ben_depend_hdl_gen_pkg.pkb.sql). The prior model loaded/reconciled as
-- PersonBenefitBalance against BEN_PER_BNFTS_BAL_F (benefit BALANCES, not dependent
-- designations) and collided on the file name PersonBenefitBalance.dat with the
-- Participant/Beneficiary generators.
--
-- ORACLE DOC AUTHORITY:
--   * HCM Data Loader "Example of Loading Dependent Enrollments":
--     https://docs.oracle.com/en/cloud/saas/human-resources/24d/fahbo/example-of-loading-dependent-enrollments.html
--   * Enrollment results base table BEN_PRTT_ENRT_RSLT (oedmh), PK PRTT_ENRT_RSLT_ID:
--     https://docs.oracle.com/en/cloud/saas/human-resources/oedmh/benprttenrtrslt-4213.html
--
-- Returns the BASE tier for the BenDependent HDL load: one row per migrated dependent
-- designation positively confirmed in HRC_INTEGRATION_KEY_MAP
-- (OBJECT_NAME='DesignateDependent'), with the real Fusion designation id (SURROGATE_ID)
-- as FUSION_ID. HDL per-record failures are captured separately (RECONCILE_HDL tags
-- [FUSION_ERROR] before this report runs).
--
-- RECORD_KEY = the DesignateDependent SourceSystemId our generator writes:
--   <prefixed PERSON_NUMBER>_<prefixed DEPENDENT_PERSON_NUMBER>_<LINE_NO>_BENDEP
-- = the BenDependent TFM row's RECON_KEY (finalized in the transform's MERGE with the
-- SAME per-person LINE_NO window the generator uses, so they never disagree on retry).
--
-- SOURCE_REF (col 8) = the SourceSystemId read back (= RECORD_KEY).
-- DMT_REFERENCE (col 9) = not applicable to a key-map row, so NULL.
--
-- Re-probe at re-cut was environment-blocked (BIP credential 401).

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'BenDependent'                  AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id,
           m.source_system_id              AS source_ref,
           CAST(NULL AS VARCHAR2(4000))    AS dmt_reference
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'DesignateDependent'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENDEP' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE
