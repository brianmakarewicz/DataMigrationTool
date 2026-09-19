-- DMT_PERFEVALUATIONS_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_PERFEVALUATIONS_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the PerfEvaluations HDL load: one row per migrated
-- performance document positively confirmed in the Fusion Performance Management base
-- table HRA_EVALUATIONS, with the real Fusion EVALUATION_ID as FUSION_ID. HDL per-record
-- failures are captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this report
-- runs), so this report returns BASE/SUCCESS rows only; the shared parser marks a
-- PerfEvaluations row LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- OBJECT: PerfEvaluations loads through the HCM Data Loader as the PerformanceDocument
-- business object (PerfDocComplete.dat — see db/packages/dmt_perf_eval_hdl_gen_pkg.pkb.sql,
-- BUILD_DAT_HEADER('PerfDocComplete',...) + BUILD_DAT_HEADER('RatingsAndComments',...)),
-- so the Fusion home of a loaded performance evaluation is the performance document.
-- HRA_EVALUATIONS is the performance document base table. EVALUATION_ID is the base id;
-- NAME is the document name (CustomaryName) and the business key.
--
-- RECORD_KEY = the prefixed document name = HRA_EVALUATIONS.NAME
--            = the PerfEvaluations TFM row's RECON_KEY (the run prefix applied to
--              the source DOCUMENT_NAME at transform, design section 5).
--
-- Verified live 2026-09-17 (--cred fin_impl):
--   1) HRA_EVALUATIONS exists with 6773 rows (the performance document base table).
--   2) HRA_EVALUATIONS columns include EVALUATION_ID, NAME, WORKER_ID, ASSIGNMENT_ID,
--      MANAGER_ID, REVIEW_PERIOD_ID, TEMPLATE_DEFN_ID, START_DATE, END_DATE.
--   3) Config prerequisites present: 39 distinct TEMPLATE_DEFN_ID and 5 distinct
--      REVIEW_PERIOD_ID in use across the 6773 existing documents, so performance
--      templates + review periods are configured on this pod.
--   4) No DMT-prefixed documents exist yet in HRA_EVALUATIONS, so base-tier matching by
--      run prefix (P_PREFIX) against NAME is clean; keyset pagination by RECORD_KEY.
--   5) HRC_INTEGRATION_KEY_MAP has NO PerformanceDocument/PerfDocComplete rows (only the
--      legacy GoalPlan rows from the prior wrong-object load), and PerfDocComplete is a
--      natural-key object (no SourceSystem keys), so base-tier matching is by NAME prefix,
--      not by SourceSystemId.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'PerfEvaluations'               AS object_type,
           v.name                          AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(v.evaluation_id)            AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hra_evaluations v
    WHERE  v.name LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR v.name > :P_AFTER_KEY)
    GROUP BY v.name
    ORDER BY v.name
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
