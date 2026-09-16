-- DMT_ASSIGNMENTS_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_ASSIGNMENTS_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six
-- parameters).
--
-- Assignments is an HDL object whose RECONCILE_BATCH loads TWO record types into
-- two TFM tables, so this ONE Contract v1 report returns BOTH base tiers (the
-- OBJECT_TYPE discriminator, design section 5, lets one report serve them):
--
--   OBJECT_TYPE='WorkRelationship'  -> DMT_WORK_REL_TFM_TBL
--       base tier: PER_PERIODS_OF_SERVICE. FUSION_ID = the real PERSON_ID.
--       RECORD_KEY = the .dat SourceSystemId '<prefixed PERSON_NUMBER>_POS'.
--   OBJECT_TYPE='Assignment'        -> DMT_ASSIGNMENT_TFM_TBL
--       base tier: PER_ALL_ASSIGNMENTS_M. FUSION_ID = the real ASSIGNMENT_ID.
--       RECORD_KEY = the .dat SourceSystemId '<ASSIGNMENT_NUMBER>_ASG' (and the
--       WorkTerms sibling '<ASSIGNMENT_NUMBER>_TRM', also a per_all_assignments_m
--       row) — the same values RECONCILE_HDL matches with the '_TRM,_ASG'
--       suffixes and the assignment TFM row's RECON_KEY.
--
-- The tie from our .dat SourceSystemId to the base row is HRC_INTEGRATION_KEY_MAP
-- (SOURCE_SYSTEM_ID we wrote -> SURROGATE_ID = the base id). Verified live
-- 2026-09-16 (fin_impl):
--   object_name='PeriodOfService', source_system_id '<PNUM>_POS'
--       SURROGATE_ID == PER_PERIODS_OF_SERVICE.PERIOD_OF_SERVICE_ID
--       -> per_periods_of_service.person_id is the real PERSON_ID.
--   object_name='Assignment', source_system_id '<ASGNUM>_ASG'/'_TRM'
--       SURROGATE_ID == PER_ALL_ASSIGNMENTS_M.ASSIGNMENT_ID
--         (e.g. '10052RT-WKR-G1_ASG' -> ASSIGNMENT_ID 300000331500388,
--          ASSIGNMENT_NUMBER '10052RT-WKR-G1').
-- Every migrated SourceSystemId starts with the run prefix, so BASE-tier
-- matching is by the run prefix (P_PREFIX). HDL per-record failures are captured
-- separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so this
-- report returns BASE/SUCCESS rows only. Keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    -- WorkRelationship base tier: positive proof in PER_PERIODS_OF_SERVICE.
    SELECT 'WorkRelationship'            AS object_type,
           k.source_system_id            AS record_key,
           'BASE'                        AS source_type,
           'SUCCESS'                     AS fusion_status,
           MAX(pos.person_id)            AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))  AS error_message,
           :P_LOAD_REQUEST_ID            AS load_request_id
    FROM   hrc_integration_key_map k,
           per_periods_of_service   pos
    WHERE  k.object_name        = 'PeriodOfService'
    AND    k.source_system_owner = 'HRC_SQLLOADER'
    AND    k.surrogate_id       = pos.period_of_service_id
    AND    k.source_system_id LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR k.source_system_id > :P_AFTER_KEY)
    GROUP BY k.source_system_id
    UNION ALL
    -- Assignment base tier: positive proof in PER_ALL_ASSIGNMENTS_M. Covers both
    -- the '_ASG' assignment record and its '_TRM' work-terms sibling (both are
    -- per_all_assignments_m rows keyed by the source assignment number).
    SELECT 'Assignment'                  AS object_type,
           k.source_system_id            AS record_key,
           'BASE'                        AS source_type,
           'SUCCESS'                     AS fusion_status,
           MAX(a.assignment_id)          AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))  AS error_message,
           :P_LOAD_REQUEST_ID            AS load_request_id
    FROM   hrc_integration_key_map k,
           per_all_assignments_m   a
    WHERE  k.object_name        = 'Assignment'
    AND    k.source_system_owner = 'HRC_SQLLOADER'
    AND    k.surrogate_id       = a.assignment_id
    AND    k.source_system_id LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR k.source_system_id > :P_AFTER_KEY)
    GROUP BY k.source_system_id
    ORDER BY record_key
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
