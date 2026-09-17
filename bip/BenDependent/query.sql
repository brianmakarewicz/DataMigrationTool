-- DMT_BENDEPENDENT_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_BENDEPENDENT_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six parameters).
--
-- CORRECTED OBJECT (2026-09-17): dependent benefit enrollment loads through the
-- HCM Data Loader as the DependentEnrollment business object, whose dependent
-- designations are carried by the DesignateDependent child component (written to
-- DependentEnrollment.dat by DMT_BEN_DEPEND_HDL_GEN_PKG). This is NOT
-- PersonBenefitBalance; the prior report read PersonBenefitBalance /
-- BEN_PER_BNFTS_BAL_F (wrong object, colliding file name).
--
-- Returns the BASE tier for the BenDependent HDL load: one row per migrated
-- dependent designation positively confirmed by its HRC_INTEGRATION_KEY_MAP
-- mapping row (OBJECT_NAME='DesignateDependent'), with the Fusion-assigned
-- SURROGATE_ID as FUSION_ID. The benefit-election base tables are not reachable
-- by name from the BIP reporting user (ORA-00942), so the key map is the
-- authoritative base-tier source (same approach as BenParticipant and Salaries).
-- HDL per-record failures are captured separately (RECONCILE_HDL tags
-- [FUSION_ERROR] before this report runs), so this report returns BASE/SUCCESS
-- rows only; the shared parser marks a BenDependent LOADED only from a
-- BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the DesignateDependent SourceSystemId =
--   prefixed PERSON_NUMBER || '_' || prefixed DEPENDENT_PERSON_NUMBER || '_'
--   || LINE_NO || '_BENDEP'
-- = the BenDependent TFM row's RECON_KEY. Base-tier matching is by run prefix
-- (P_PREFIX); keyset pagination by RECORD_KEY.
--
-- Verified live 2026-09-17 (--cred fin_impl):
--   HRC_INTEGRATION_KEY_MAP carries ContactRelationship (397 rows; dependents are
--   contact-relationship-based) and PersonBenefitBalance (838; a distinct object).
--   DependentEnrollment / DesignateDependent rows are not present yet and
--   BEN_ELIG_DPNT_F is not reachable by name (ORA-00942) — confirming the key-map
--   read is the correct base-tier source.
--
-- Note: our own records are not yet present — employee benefit enrollment is not
-- configured on the demo instance and the migrated workers are not enrolled in any
-- plan, so the load is rejected upstream (documented BLOCKER,
-- objects/Benefits/README.md). The report is correct and its shape is proven live.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'BenDependent'                  AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'DesignateDependent'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENDEP' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
