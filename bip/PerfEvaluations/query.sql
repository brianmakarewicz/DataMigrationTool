-- DMT_PERFEVALUATIONS_RECON_DM query (Contract v1, nine-column, design section 5).
-- Mirror of the CDATA SQL in DMT_PERFEVALUATIONS_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the PerfEvaluations HDL load: one row per migrated goal
-- plan positively confirmed in the Fusion HCM Goals base view HRG_GOAL_PLANS_VL,
-- with the real Fusion GOAL_PLAN_ID as FUSION_ID. HDL per-record failures are
-- captured separately (RECONCILE_HDL tags [FUSION_ERROR] from the HDL response
-- before this report runs), so this report returns BASE/SUCCESS rows only; the
-- shared parser marks a PerfEvaluations row LOADED only from a
-- BASE / SUCCESS / FUSION_ID-not-null row.
--
-- PerfEvaluations loads through the HCM Data Loader as the GoalPlan object
-- (GoalPlan.dat -- see db/packages/dmt_perf_eval_hdl_gen_pkg.pkb.sql,
-- BUILD_DAT_HEADER('GoalPlan',...)), so the Fusion home of a loaded performance
-- evaluation is the goal plan definition. HRG_GOAL_PLANS_VL is the translated view
-- over the base table HRG_GOAL_PLANS_B + _TL. GOAL_PLAN_ID is the base id.
--
-- RECORD_KEY = the prefixed goal plan name = HRG_GOAL_PLANS_VL.GOAL_PLAN_NAME
--            = the PerfEvaluations TFM row's RECON_KEY (the run prefix applied to
--              the source DOCUMENT_NAME at transform, design section 5).
--
-- BASE-MATCH BY PREFIXED NAME (not by the HRC_SQLLOADER key map). Verified live
-- 2026-09-20 (cred fin_impl):
--   1) HRC_INTEGRATION_KEY_MAP has GoalPlan (72) and GoalPlanGoal (17152) rows,
--      but ALL have SOURCE_SYSTEM_OWNER='FUSION' -- ZERO HRC_SQLLOADER rows.
--   2) Those FUSION rows store SOURCE_SYSTEM_ID = the numeric GOAL_PLAN_ID itself
--      (SSID==SURROGATE_ID), not our 'PERSON_NUMBER_GOAL' business key; no row
--      matches our '%_GOAL' key or '%DMT%'. So a key-map join returns zero rows
--      for our loads, and our '_GOAL' SourceSystemId carries no run prefix anyway.
--   3) HRG_GOAL_PLANS_VL carries the prefixed GOAL_PLAN_NAME and a real
--      GOAL_PLAN_ID, e.g. 300000331552763 '95480 DMT Goal Plan A' and
--      300000331552755 '95480 DMT Goal Plan B'; GOAL_PLAN_NAME is unique.
-- Base-tier matching is therefore by run prefix (P_PREFIX) against GOAL_PLAN_NAME;
-- keyset pagination by RECORD_KEY.
--
-- Columns 8-9 (design section 5, added 2026-09-20):
--   SOURCE_REF    = the run-scoped native reference read back from the base table.
--                   HRG_GOAL_PLANS does not store our HDL SourceSystemId, so the
--                   run-scoped reference the base table carries is the prefixed
--                   GOAL_PLAN_NAME (= RECORD_KEY).
--   DMT_REFERENCE = the DMT:<run>:<queue>:<tfm> stamp read back from DFF ATTRIBUTE1.
--                   Our generator writes no DFF stamp for GoalPlan, so NULL today;
--                   read back so it populates automatically if a stamp is added.
--
-- Standalone-validated live 2026-09-20 (prefix '95480', P_CHUNK_SIZE=1):
--   page 1 (after null)                 -> '95480 DMT Goal Plan A', FUSION_ID 300000331552763
--   page 2 (after '...Goal Plan A')     -> '95480 DMT Goal Plan B', FUSION_ID 300000331552755
--   page 3 (after '...Goal Plan B')     -> empty

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'PerfEvaluations'               AS object_type,
           v.goal_plan_name                AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(v.goal_plan_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id,
           v.goal_plan_name                AS source_ref,
           MAX(v.attribute1)               AS dmt_reference
    FROM   hrg_goal_plans_vl v
    WHERE  v.goal_plan_name LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR v.goal_plan_name > :P_AFTER_KEY)
    GROUP BY v.goal_plan_name
    ORDER BY v.goal_plan_name
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
