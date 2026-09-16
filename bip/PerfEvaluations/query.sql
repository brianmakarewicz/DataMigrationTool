-- DMT_PERFEVALUATIONS_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_PERFEVALUATIONS_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the PerfEvaluations HDL load: one row per migrated goal
-- plan positively confirmed in the Fusion HCM Goals base view HRG_GOAL_PLANS_VL,
-- with the real Fusion GOAL_PLAN_ID as FUSION_ID. HDL per-record failures are
-- captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs),
-- so this report returns BASE/SUCCESS rows only; the shared parser marks a
-- PerfEvaluations row LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- PerfEvaluations loads through the HCM Data Loader as the GoalPlan object
-- (GoalPlan.dat — see db/packages/dmt_perf_eval_hdl_gen_pkg.pkb.sql,
-- BUILD_DAT_HEADER('GoalPlan',...)), so the Fusion home of a loaded performance
-- evaluation is the goal plan definition. HRG_GOAL_PLANS_VL is the translated view
-- over the base table HRG_GOAL_PLANS_B + _TL (the name lives on _TL, joined by the
-- _VL view). GOAL_PLAN_ID is the base id.
--
-- RECORD_KEY = the prefixed goal plan name = HRG_GOAL_PLANS_VL.GOAL_PLAN_NAME
--            = the PerfEvaluations TFM row's RECON_KEY (the run prefix applied to
--              the source DOCUMENT_NAME at transform, design section 5).
--
-- Verified live 2026-09-16 (--cred fin_impl):
--   1) HRC_INTEGRATION_KEY_MAP.object_name = 'GoalPlan' -> 72 rows
--      (confirms our HDL loads PerfEvaluations as GoalPlan).
--   2) HRG_GOAL_PLANS_VL columns include GOAL_PLAN_ID and GOAL_PLAN_NAME.
--   3) SELECT goal_plan_id, goal_plan_name FROM hrg_goal_plans_vl
--        WHERE goal_plan_name LIKE '%DMT%'
--      -> 300000331553042  '43426 DMT Goal Plan A'
--         300000331553046  '43426 DMT Goal Plan B'
--         300000331552755  '95480 DMT Goal Plan B'
--      confirming migrated goal plans carry the run prefix in GOAL_PLAN_NAME and
--      that GOAL_PLAN_ID is the base-tier Fusion id.
--   4) NO HRC_SQLLOADER-owned or '%_GOAL' source_system_id rows exist in
--      HRC_INTEGRATION_KEY_MAP for GoalPlan, so base-tier matching is by run prefix
--      (P_PREFIX) against GOAL_PLAN_NAME, not by SourceSystemId; keyset pagination
--      by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'PerfEvaluations'               AS object_type,
           v.goal_plan_name                AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(v.goal_plan_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrg_goal_plans_vl v
    WHERE  v.goal_plan_name LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR v.goal_plan_name > :P_AFTER_KEY)
    GROUP BY v.goal_plan_name
    ORDER BY v.goal_plan_name
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
