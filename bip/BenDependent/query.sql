-- DMT_BENDEPENDENT_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_BENDEPENDENT_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the BenDependent HDL load: one row per migrated
-- dependent benefit balance positively confirmed in the HCM Benefits base table
-- BEN_PER_BNFTS_BAL_F, with the real Fusion PER_BNFTS_BAL_ID as FUSION_ID.
-- BenDependent loads through the HCM Data Loader as the PersonBenefitBalance object
-- (PersonBenefitBalance.dat). HDL per-record failures are captured separately
-- (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so this report
-- returns BASE/SUCCESS rows only; the shared parser marks a BenDependent LOADED
-- only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed PERSON_NUMBER || '_BENDEP' = the SourceSystemId written
-- into PersonBenefitBalance.dat (DMT_BEN_DEPEND_HDL_GEN_PKG) = the BenDependent TFM
-- row's RECON_KEY. Verified live 2026-09-16 (--cred fin_impl):
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME='PersonBenefitBalance' (838 rows)
--   HRC_INTEGRATION_KEY_MAP.SURROGATE_ID == BEN_PER_BNFTS_BAL_F.PER_BNFTS_BAL_ID
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.
--
-- Note: our own '_BENDEP' records are not yet present — employee benefit enrollment
-- is not configured on the demo instance and the migrated workers are not enrolled
-- in any plan, so the load is rejected upstream (documented BLOCKER,
-- objects/Benefits/README.md). The report is correct and its shape is proven live.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'BenDependent'                  AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(b.per_bnfts_bal_id)         AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    JOIN   ben_per_bnfts_bal_f b
           ON b.per_bnfts_bal_id = m.surrogate_id
    WHERE  m.object_name = 'PersonBenefitBalance'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENDEP' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
