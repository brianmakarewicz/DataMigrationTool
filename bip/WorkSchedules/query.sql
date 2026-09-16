-- DMT_WORKSCHEDULES_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_WORKSCHEDULES_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the WorkSchedules HDL load: one row per migrated work
-- pattern positively confirmed in the Fusion HCM Availability base view
-- HTS_WORK_PATTERNS_VL, with the real Fusion WORK_PATTERN_ID as FUSION_ID. HDL
-- per-record failures are captured separately (RECONCILE_HDL tags [FUSION_ERROR]
-- before this report runs), so this report returns BASE/SUCCESS rows only; the
-- shared parser marks a WorkSchedule LOADED only from a BASE / SUCCESS /
-- FUSION_ID-not-null row.
--
-- WorkSchedules loads through the HCM Data Loader as the WorkPattern object
-- (WorkPattern.dat), so the Fusion home of a loaded work schedule is the work
-- pattern definition. HTS_WORK_PATTERNS_VL is the translated view over the base
-- table HTS_WORK_PATTERNS_B + _TL (the base table itself has no name column; the
-- name lives on _TL, joined by the _VL view). WORK_PATTERN_ID is the base id.
--
-- RECORD_KEY = the prefixed work schedule name = HTS_WORK_PATTERNS_VL.WORK_PATTERN_NAME
--            = the WorkSchedule TFM row's RECON_KEY (the run prefix applied to the
--              source WORK_SCHEDULE_NAME at transform, design section 5).
-- Verified live 2026-09-16 (--cred fin_impl):
--   SELECT work_pattern_id, work_pattern_name FROM hts_work_patterns_vl
--   WHERE  work_pattern_name LIKE '41657%'
--     -> 300000331578562  '41657 DMT Work Schedule 1'
--        300000331578548  '41657 DMT Work Schedule 2'
--   confirming migrated work patterns carry the run prefix in WORK_PATTERN_NAME and
--   that WORK_PATTERN_ID is the base-tier Fusion id. Base-tier matching is by run
--   prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
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
    ORDER BY v.work_pattern_name
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
