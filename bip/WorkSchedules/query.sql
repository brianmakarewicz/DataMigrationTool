-- DMT_WORK_SCHED_RECON_DM query (Contract v1: nine columns, six parameters,
-- keyset pagination). Mirror of the CDATA SQL in DMT_WORK_SCHED_RECON_DM.xdm,
-- kept here for review and for running the query standalone against live Fusion
-- (bind the six parameters).
--
-- Returns the BASE tier for the WorkSchedules HDL load. WorkSchedules is ONE DMT
-- object that carries TWO Fusion HDL business objects, so the report is a UNION of
-- two OBJECT_TYPE branches, each keyed by the SourceSystemId Fusion recorded in
-- HRC_INTEGRATION_KEY_MAP (SOURCE_SYSTEM_OWNER='HRC_SQLLOADER', which excludes
-- Fusion-seeded rows). A WorkSchedules TFM row is promoted to LOADED only from a
-- BASE / SUCCESS / FUSION_ID-not-null row; HDL per-record failures are captured
-- separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs).
--
--   Branch (1) WorkPattern (pattern DEFINITION):
--     OBJECT_NAME='WorkPattern', suffix '_WPAT' (= the TFM RECON_KEY),
--     FUSION_ID = SURROGATE_ID (the Fusion-assigned base pattern id).
--   Branch (2) ScheduleAssignment (assign schedule to a WORKER):
--     OBJECT_NAME='ScheduleAssignment', suffix '_WSASG',
--     FUSION_ID = PER_SCHEDULE_ASSIGNMENTS.SCHEDULE_ASSIGNMENT_ID.
--     Config-blocked (the Work Schedule wrapper is a UI task HDL cannot create),
--     so this branch returns zero until that config exists on the pod.
--
-- Verified live 2026-09-20 (--cred fin_impl / ApplicationDB_FSCM):
--   * WorkPattern has 11 HRC_SQLLOADER rows (suffix _WPAT), each SURROGATE_ID a
--     real Fusion base pattern id. Round-trip: every key-map row corresponds to a
--     real pattern visible in HTS_WORK_PATTERNS_VL by WORK_PATTERN_NAME.
--   * ScheduleAssignment has 0 HRC_SQLLOADER rows (config-blocked); 556
--     FUSION-seeded rows exist and are excluded by the owner filter.
--   * Standalone page/advance/empty keyset behaviour confirmed (see PR body).

SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Branch (1) WorkPattern definition
    SELECT 'WorkSchedules'                AS object_type,
           m.source_system_id             AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(m.surrogate_id)            AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           m.source_system_id             AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   hrc_integration_key_map m
    WHERE  m.object_name         = 'WorkPattern'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_WPAT' ESCAPE '\'
    GROUP BY m.source_system_id

    UNION ALL

    -- Branch (2) ScheduleAssignment (config-blocked until a Work Schedule exists)
    SELECT 'WorkSchedules'                AS object_type,
           m.source_system_id             AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(sa.schedule_assignment_id) AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           m.source_system_id             AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   hrc_integration_key_map m
    JOIN   per_schedule_assignments sa
           ON sa.schedule_assignment_id = m.surrogate_id
    WHERE  m.object_name         = 'ScheduleAssignment'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_WSASG' ESCAPE '\'
    GROUP BY m.source_system_id
)
-- Keyset pagination by RECORD_KEY. First page: P_AFTER_KEY is NULL -> from start.
-- Later pages: P_AFTER_KEY = previous page's last RECORD_KEY -> only greater keys.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
