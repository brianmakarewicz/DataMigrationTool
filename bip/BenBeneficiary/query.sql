-- DMT_BENBENEFICIARY_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_BENBENEFICIARY_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- 2026-09-17 RE-MODEL: beneficiary designation loads via the HDL business object
-- BeneficiaryEnrollment (child DesignateBeneficiary), NOT PersonBenefitBalance.
-- PersonBenefitBalance is accumulated benefit balances and had collided on file
-- name/discriminator with BenParticipant and BenDependent. This report reconciles
-- against OBJECT_NAME='BeneficiaryEnrollment'.
--
-- Returns the BASE tier for the BeneficiaryEnrollment HDL load: one row per migrated
-- worker's beneficiary enrollment positively confirmed in Fusion, with the real Fusion
-- base-table id as FUSION_ID. HDL per-record failures are captured separately
-- (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so this report returns
-- BASE/SUCCESS rows only; the shared parser marks a BenBeneficiary row LOADED only from a
-- BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed PERSON_NUMBER || '_BENENRL' = the SourceSystemId written onto
-- the parent BeneficiaryEnrollment component = the BenBeneficiary TFM row's RECON_KEY.
-- Live probe 2026-09-17 (scripts/fusion_bip_query.py --cred fin_impl): no
-- BeneficiaryEnrollment rows exist yet on this pod (never exercised via the correct
-- object); the historical '..._BENBNFY' rows are recorded under the WRONG object
-- PersonBenefitBalance — the defect this re-model fixes.
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
    WHERE  m.object_name = 'BeneficiaryEnrollment'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENENRL' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
