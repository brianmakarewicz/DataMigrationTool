-- DMT_PERFEVALUATIONS_RECON_DM query (Contract v1, nine-column, design section 5).
-- Mirror of the CDATA SQL in DMT_PERFEVALUATIONS_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- RE-POINTED 2026-09-22 to the CORRECT Fusion object. PerfEvaluations loads through the
-- HCM Data Loader as the PerformanceDocument business object (PerfDocComplete.dat plus
-- the RatingsAndComments component -- see db/packages/dmt_perf_eval_hdl_gen_pkg.pkb.sql,
-- BUILD_DAT_HEADER('PerfDocComplete',...)). A loaded performance evaluation therefore
-- lives in Fusion as a performance document, NOT as a goal plan.
--
-- ORACLE DOC AUTHORITY:
--   * HCM Data Loader - Performance Document business object:
--     https://docs.oracle.com/en/cloud/saas/talent-management/faapd/hcm-data-loader-and-performance-document-business-objects.html
--   * Base table HRA_EVALUATIONS (Tables and Views for HCM, oedmh): EVALUATION_ID is the
--     primary key; NAME is the document name.
--     https://docs.oracle.com/en/cloud/saas/human-resources/oedmh/hraevaluations-5145.html
--
-- Returns the BASE tier for the PerfEvaluations HDL load: one row per migrated
-- performance document positively confirmed in HRA_EVALUATIONS, with the real Fusion
-- EVALUATION_ID as FUSION_ID. HDL per-record failures are captured separately
-- (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so this report returns
-- BASE/SUCCESS rows only; the shared parser marks a PerfEvaluations row LOADED only from
-- a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed document name = HRA_EVALUATIONS.NAME = the PerfEvaluations
-- TFM row's RECON_KEY (run prefix applied to DOCUMENT_NAME at transform, section 5).
-- PerformanceDocument is a natural-key object (no SourceSystem keys, no
-- HRC_INTEGRATION_KEY_MAP row), so base-tier matching is by run prefix (P_PREFIX)
-- against NAME; keyset pagination by RECORD_KEY.
--
-- SOURCE_REF (col 8) = the prefixed NAME read back (= RECORD_KEY).
-- DMT_REFERENCE (col 9) = DFF stamp; not deployed for this HDL load, so NULL.
--
-- LIVE PROBE (original PR, cred fin_impl, 2026-09-17): HRA_EVALUATIONS exists with ~6773
-- rows; columns include EVALUATION_ID, NAME, WORKER_ID, ASSIGNMENT_ID, MANAGER_ID.
-- Re-probe at re-cut was environment-blocked (BIP credential 401).

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'PerfEvaluations'               AS object_type,
           v.name                          AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(v.evaluation_id)            AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id,
           v.name                          AS source_ref,
           CAST(NULL AS VARCHAR2(4000))    AS dmt_reference
    FROM   hra_evaluations v
    WHERE  v.name LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR v.name > :P_AFTER_KEY)
    GROUP BY v.name
    ORDER BY v.name
)
WHERE ROWNUM <= :P_CHUNK_SIZE
