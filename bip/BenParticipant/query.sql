-- DMT_BENPARTICIPANT_RECON_DM query (Contract v1, nine-column, design section 5).
-- Mirror of the CDATA SQL in DMT_BENPARTICIPANT_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- RE-POINTED 2026-09-22 to the CORRECT Fusion object. BenParticipant loads through the
-- HCM Data Loader as the ParticipantEnrollment business object (ParticipantEnrollment.dat
-- -- see db/packages/dmt_ben_partic_hdl_gen_pkg.pkb.sql). The prior model loaded/
-- reconciled as PersonBenefitBalance (benefit BALANCES, not enrollments) and collided on
-- the file name PersonBenefitBalance.dat with the Dependent/Beneficiary generators.
--
-- ORACLE DOC AUTHORITY:
--   * Base table BEN_PRTT_ENRT_RSLT (Tables and Views for HCM, oedmh): identifies the
--     plans/options a participant is enrolled in; PRTT_ENRT_RSLT_ID is the primary key.
--     https://docs.oracle.com/en/cloud/saas/human-resources/oedmh/benprttenrtrslt-4213.html
--
-- Returns the BASE tier for the BenParticipant HDL load: one row per migrated worker
-- positively confirmed in BEN_PRTT_ENRT_RSLT (joined to PER_ALL_PEOPLE_F by PERSON_ID),
-- with the real Fusion PRTT_ENRT_RSLT_ID as FUSION_ID. HDL per-record failures are
-- captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs).
--
-- ParticipantEnrollment is create-only and carries NO SourceSystemId, and there is no
-- HRC_INTEGRATION_KEY_MAP row for it, so base-tier matching is by the worker's prefixed
-- PERSON_NUMBER; keyset pagination by RECORD_KEY. RECORD_KEY = the prefixed PERSON_NUMBER
-- = the BenParticipant TFM row's RECON_KEY.
--
-- SOURCE_REF (col 8) = the prefixed PERSON_NUMBER read back (= RECORD_KEY).
-- DMT_REFERENCE (col 9) = DFF stamp; not deployed for this HDL load, so NULL.
--
-- LIVE PROBE (original PR, cred fin_impl): BEN_PRTT_ENRT_RSLT ~38,411 rows; both tables
-- reachable by name; PRTT_ENRT_RSLT_ID returns as FUSION_ID (e.g. person 39 -> 337499).
-- Re-probe at re-cut was environment-blocked (BIP credential 401).

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'BenParticipant'               AS object_type,
           p.person_number                AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(r.prtt_enrt_rslt_id)       AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           :P_LOAD_REQUEST_ID             AS load_request_id,
           p.person_number                AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   ben_prtt_enrt_rslt r
    JOIN   per_all_people_f   p ON p.person_id = r.person_id
    WHERE  p.person_number LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR p.person_number > :P_AFTER_KEY)
    GROUP BY p.person_number
    ORDER BY p.person_number
)
WHERE ROWNUM <= :P_CHUNK_SIZE
