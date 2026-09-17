-- DMT_WORKSCHEDULES_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_WORKSCHEDULES_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six parameters).
--
-- Re-modelled 2026-09-17 (HCM re-model: WorkSchedules -> WorkPattern +
-- ScheduleAssignment). WorkSchedules is ONE DMT object carrying TWO Fusion HDL
-- business objects, each with its own base home:
--   (1) WorkPattern (pattern DEFINITION) -> HTS_WORK_PATTERNS_VL.WORK_PATTERN_ID
--   (2) ScheduleAssignment (assign schedule to WORKER) ->
--       PER_SCHEDULE_ASSIGNMENTS.SCHEDULE_ASSIGNMENT_ID
--
-- The report returns the BASE tier as a UNION of both proofs, each keyed by the
-- SAME prefixed work pattern/schedule name (= the TFM RECON_KEY). A WorkSchedule
-- TFM row is promoted to LOADED only from a BASE / SUCCESS / FUSION_ID-not-null
-- row. HDL per-record failures are captured separately (RECONCILE_HDL tags
-- [FUSION_ERROR] before this report runs), so this report returns BASE/SUCCESS
-- rows only.
--
-- Verified live 2026-09-17 (--cred fin_impl):
--   * HDL objects WorkPattern / WorkPatternShift / WorkPatternBreak /
--     ScheduleAssignment all present in HRC_INTEGRATION_KEY_MAP.
--   * Branch (1): hts_work_patterns_vl WHERE work_pattern_name LIKE '86348%'
--     -> '86348 DMT Work Schedule 1', WORK_PATTERN_ID 300000331553350.
--   * Branch (2) base table PER_SCHEDULE_ASSIGNMENTS carries RESOURCE_TYPE='ASSIGN',
--     RESOURCE_ID = worker assignment id, PRIMARY_FLAG='Y'. It links to a pattern
--     only through ZMM_SR_SCHEDULE_PATTERNS -> HTS_WORK_PATTERNS. HDL cannot
--     create the Work Schedule wrapper (ZMM_SR_SCHEDULES; a UI task), so branch
--     (2) returns zero until that config exists — the assignment side is
--     honestly config-blocked, while branch (1) continues to prove patterns.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT object_type, record_key, source_type, fusion_status,
           fusion_id, error_message, load_request_id
    FROM (
        -- Branch (1) WorkPattern definition
        SELECT 'WorkSchedules'                 AS object_type,
               v.work_pattern_name             AS record_key,
               'BASE'                          AS source_type,
               'SUCCESS'                       AS fusion_status,
               MAX(v.work_pattern_id)          AS fusion_id,
               CAST(NULL AS VARCHAR2(4000))    AS error_message,
               :P_LOAD_REQUEST_ID              AS load_request_id
        FROM   hts_work_patterns_vl v
        WHERE  v.work_pattern_name LIKE :P_PREFIX || '%'
        AND    (:P_AFTER_KEY IS NULL OR v.work_pattern_name > :P_AFTER_KEY)
        GROUP BY v.work_pattern_name

        UNION ALL

        -- Branch (2) ScheduleAssignment (config-blocked until a Work Schedule exists)
        SELECT 'WorkSchedules'                 AS object_type,
               v.work_pattern_name             AS record_key,
               'BASE'                          AS source_type,
               'SUCCESS'                       AS fusion_status,
               MAX(sa.schedule_assignment_id)  AS fusion_id,
               CAST(NULL AS VARCHAR2(4000))    AS error_message,
               :P_LOAD_REQUEST_ID              AS load_request_id
        FROM   per_schedule_assignments   sa
        JOIN   zmm_sr_schedule_patterns   sp ON sp.schedule_id = sa.schedule_id
        JOIN   hts_work_patterns_vl       v  ON v.work_pattern_id = sp.pattern_id
        WHERE  sa.resource_type = 'ASSIGN'
        AND    v.work_pattern_name LIKE :P_PREFIX || '%'
        AND    (:P_AFTER_KEY IS NULL OR v.work_pattern_name > :P_AFTER_KEY)
        GROUP BY v.work_pattern_name
    )
    ORDER BY record_key
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
