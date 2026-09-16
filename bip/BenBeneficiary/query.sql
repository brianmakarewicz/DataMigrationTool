-- DMT_BENBENEFICIARY_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_BENBENEFICIARY_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the BenBeneficiary HDL load: one row per migrated
-- beneficiary positively confirmed in Fusion, with the real Fusion PersonBenefitBalance
-- base-table id as FUSION_ID. The object loads via HDL under the discriminator
-- PersonBenefitBalance (see DMT_BEN_BENFY_HDL_GEN_PKG). HDL per-record failures are
-- captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so
-- this report returns BASE/SUCCESS rows only; the shared parser marks a BenBeneficiary
-- LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed PERSON_NUMBER || '_BENBNFY' = the SourceSystemId written
-- into PersonBenefitBalance.dat = the BenBeneficiary TFM row's RECON_KEY.
-- Verified live 2026-09-16 (scripts/fusion_bip_query.py --cred fin_impl):
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME       = 'PersonBenefitBalance'
--       (10 HRC_SQLLOADER-owned HDL rows; e.g. SOURCE_SYSTEM_ID '67936DMTBNFY001_BENBNFY')
--   HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID  == the SourceSystemId we wrote (ends _BENBNFY)
--   HRC_INTEGRATION_KEY_MAP.SURROGATE_ID      == the Fusion PersonBenefitBalance id
--       (e.g. 300000331552758) — a real base-table id
--   Running this SQL with :P_PREFIX='67936' returned two BASE/SUCCESS rows with real ids.
-- The physical Benefits base table (BEN_*) is not visible to the FSCM BIP data source, so
-- — like Salaries — BASE-tier proof is the map row whose SURROGATE_ID is the base-table id.
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'BenBeneficiary'                 AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'PersonBenefitBalance'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENBNFY' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
