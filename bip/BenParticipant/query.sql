-- DMT_BENPARTICIPANT_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_BENPARTICIPANT_RECON_DM.xdm, kept here for
-- review and for running the query standalone against live Fusion (bind the six
-- parameters).
--
-- Returns the BASE tier for the BenParticipant HDL load: one row per migrated
-- record positively confirmed by a HRC_INTEGRATION_KEY_MAP entry
-- (OBJECT_NAME='PersonBenefitBalance'), with the Fusion-assigned SURROGATE_ID as
-- FUSION_ID. HDL per-record failures are captured separately (RECONCILE_HDL tags
-- [FUSION_ERROR] before this report runs), so this report returns BASE/SUCCESS
-- rows only; the shared parser marks a BenParticipant TFM row LOADED only from a
-- BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the SourceSystemId we wrote into PersonBenefitBalance.dat =
-- (prefixed PERSON_NUMBER) || '_BENENRL' = the BenParticipant TFM row's
-- RECON_KEY. BenParticipant loads through HDL as the PersonBenefitBalance
-- business object (see DMT_BEN_PARTIC_HDL_GEN_PKG). Base-tier matching is by run
-- prefix (P_PREFIX); keyset pagination by RECORD_KEY.
--
-- Verified live 2026-09-16 (fin_impl / ApplicationDB_FSCM):
--   * OBJECT_NAME 'PersonBenefitBalance' exists in HRC_INTEGRATION_KEY_MAP (838
--     rows on the pod today); the SELECT below runs cleanly and returns real
--     base rows with SURROGATE_ID as FUSION_ID when the _BENENRL filter is
--     removed.
--   * With the '%\_BENENRL' filter it returns ZERO rows: our HDL has not yet
--     loaded any BenParticipant records. Honest zero-row result (the object is
--     upstream-blocked / unloaded) — not a broken query.
--   * The benefit-balance base table is not reachable by name from the BIP
--     reporting user (ORA-00942 on all BEN_PER_BNFT_BAL* candidates), so
--     HRC_INTEGRATION_KEY_MAP is the authoritative base-tier source (same
--     approach as Salaries).

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'BenParticipant'               AS object_type,
           m.source_system_id             AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)            AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           :P_LOAD_REQUEST_ID             AS load_request_id
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'PersonBenefitBalance'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_BENENRL' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
