-- DMT_SALARYBASES_RECON_DM query (Contract v1, design section 5; nine-column response).
-- Mirror of the CDATA SQL in DMT_SALARYBASES_RECON_DM.xdm, kept here for review and for
-- running the query standalone against live Fusion (bind the six parameters).
--
-- BASE-TIER-ONLY HDL recipe (mirrors Salaries/Assignments/BenParticipant): driven off
-- the HDL integration key map HRC_INTEGRATION_KEY_MAP, scoped to OUR loader by
-- SOURCE_SYSTEM_OWNER='HRC_SQLLOADER', to this object by OBJECT_NAME='SalaryBasis', and
-- to this run by SOURCE_SYSTEM_ID LIKE :P_PREFIX||'%'. The owner scope is essential:
-- OBJECT_NAME='SalaryBasis' has 155 rows on the pod but only 8 are ours (owner
-- HRC_SQLLOADER); the other 147 are FUSION-seeded and their numeric SOURCE_SYSTEM_ID
-- (e.g. 300000047957113) could otherwise match a numeric run prefix and be misreported
-- as a fabricated BASE/SUCCESS row. OBJECT_TYPE is the literal
-- DMT object code 'SalaryBases' (the CEMLI_CODE, per the Contract v1 rule that
-- single-record-type objects return the object-code constant); SURROGATE_ID is the
-- real Fusion base-table PK. HDL per-record failures
-- are captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs),
-- so this report returns BASE/SUCCESS rows only; the shared parser marks a SalaryBases
-- row LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = SOURCE_SYSTEM_ID = the prefixed SalaryBasisName = the SourceSystemId
-- written into SalaryBasis.dat = the SalaryBases TFM row's RECON_KEY. SOURCE_REF echoes
-- the same SOURCE_SYSTEM_ID; DMT_REFERENCE is NULL (no DFF reference carried for HDL).
-- Verified live 2026-09-20:
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME       = 'SalaryBasis'
--   HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID == the prefixed SalaryBasisName we wrote
--   HRC_INTEGRATION_KEY_MAP.SURROGATE_ID     == CMP_SALARY_BASES.SALARY_BASIS_ID
--                                               (round-tripped for all 8 loaded keys)
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'SalaryBases'                   AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id,
           m.source_system_id              AS source_ref,
           CAST(NULL AS VARCHAR2(4000))    AS dmt_reference
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'SalaryBasis'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
