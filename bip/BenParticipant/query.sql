-- DMT_BENPARTICIPANT_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_BENPARTICIPANT_RECON_DM.xdm, kept here for
-- review and for running the query standalone against live Fusion (bind the six
-- parameters).
--
-- Returns the BASE tier for the BenParticipant HDL load: one row per migrated
-- worker whose benefit participant enrollment is positively confirmed in the
-- Fusion enrollment base table BEN_PRTT_ENRT_RSLT, with the real Fusion
-- PRTT_ENRT_RSLT_ID as FUSION_ID. HDL per-record failures are captured
-- separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so
-- this report returns BASE/SUCCESS rows only; the shared parser marks a
-- BenParticipant TFM row LOADED only from a BASE / SUCCESS / FUSION_ID-not-null
-- row.
--
-- BenParticipant loads through HCM Data Loader as the ParticipantEnrollment
-- business object (see DMT_BEN_PARTIC_HDL_GEN_PKG) -- NOT PersonBenefitBalance.
-- ParticipantEnrollment is create-only and carries NO SourceSystemId, so it does
-- not register a row in HRC_INTEGRATION_KEY_MAP. Reconciliation therefore reads
-- the enrollment base table directly, joined to PER_ALL_PEOPLE_F by the worker's
-- PersonNumber (the prefixed number the Workers pipeline loaded).
--
-- RECORD_KEY = the prefixed PERSON_NUMBER = the PersonNumber written into
-- ParticipantEnrollment.dat = the BenParticipant TFM row's RECON_KEY.
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by
-- RECORD_KEY (P_AFTER_KEY). P_LOAD_REQUEST_ID / P_IMPORT_ESS_ID do not survive
-- into the base for an HDL load; LOAD_REQUEST_ID is echoed back for audit.
--
-- Verified live 2026-09-17 (fin_impl / ApplicationDB_FSCM):
--   * Benefits IS configured on the pod: BEN_PGM_F = 24 programs,
--     BEN_PRTT_ENRT_RSLT = 38,411 enrollment results.
--   * 'ParticipantEnrollment' is absent from HRC_INTEGRATION_KEY_MAP (create-only
--     object, no SourceSystemId) -- confirming the base-table approach.
--   * BEN_PRTT_ENRT_RSLT and PER_ALL_PEOPLE_F are both reachable by name from the
--     BIP reporting user; this exact SELECT returns real base rows with
--     PRTT_ENRT_RSLT_ID as FUSION_ID (e.g. person 39 -> 337499).
--   * With a test P_PREFIX it returns ZERO rows until our HDL loads enrollments
--     -- an honest zero-row result, not a broken query.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'BenParticipant'               AS object_type,
           p.person_number                AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(r.prtt_enrt_rslt_id)       AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           :P_LOAD_REQUEST_ID             AS load_request_id
    FROM   ben_prtt_enrt_rslt r
    JOIN   per_all_people_f   p ON p.person_id = r.person_id
    WHERE  p.person_number LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR p.person_number > :P_AFTER_KEY)
    GROUP BY p.person_number
    ORDER BY p.person_number
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
