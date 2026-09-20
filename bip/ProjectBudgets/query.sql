-- ============================================================
-- Project Budgets BIP reconciliation query -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination). Data source:
-- ApplicationDB_FSCM. This mirrors the SQL embedded in
-- PRJ_BUDGET_DM.xdm for review; the .xdm is authoritative.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- ONE object, two tiers. ProjectBudgets is a single FBDI zip
-- (PjoPlanVersionsXface.csv) loaded by "Import Budgets Interface
-- Data": interface table PJO_PLAN_VERSIONS_XFACE, base table
-- PJO_PLAN_VERSIONS_B. One budget FBDI resolves to one plan version
-- (PLAN_VERSION_ID); budget lines land in PJO_PLAN_LINE_DETAILS, which
-- carries no native source reference, so the reconcilable grain is the
-- plan version. FUSION_ID = PLAN_VERSION_ID.
--
-- RECON KEY = the native source budget line reference. On the base row
-- it is PM_BUDGET_REFERENCE (verified live: values like ENDOW001-01
-- survive verbatim on PJO_PLAN_VERSIONS_B); on the interface row it is
-- SRC_BUDGET_LINE_REFERENCE. The transform prefixes PROJECT_NUMBER /
-- PROJECT_NAME only (NOT the budget reference), so the run-scoped
-- selector is the prefixed PROJECT_NUMBER, which lands on
-- PJF_PROJECTS_ALL_B.SEGMENT1 (LIKE :P_PREFIX || '%'). Load/import ESS
-- ids are not durably captured per row on this pod, so
-- :P_LOAD_REQUEST_ID / :P_IMPORT_ESS_ID cannot select the run alone;
-- they are declared for contract symmetry and stamped for traceability.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE (present in PJO_PLAN_VERSIONS_B) => SUCCESS
--   INTERFACE (unprocessed: PROCESS_CODE/LOAD_STATUS not success) => ERROR
-- FUSION_ID non-null on every BASE row (PLAN_VERSION_ID).
--
-- ERROR_MESSAGE limitation (verified live): PJO_PLAN_VERSIONS_XFACE has
-- NO error-text column and there is no queryable PJO*ERR* table on this
-- pod, so a rejected row cannot be joined to its real Fusion message
-- from a queryable table. The per-row rejection text lives in the
-- Import Budgets report XML, which the pipeline harvests into DMT
-- TFM.ERROR_TEXT. This query reports the interface status codes (the
-- only signal the interface carries).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- BASE tier -- SUCCESS. RECORD_KEY = PM_BUDGET_REFERENCE (source
    -- budget line reference, persisted verbatim on the base row); when
    -- null, a stable synthetic key from prefixed project number + plan
    -- version name + plan version id. DMT_REFERENCE = PM_BUDGET_REFERENCE.
    SELECT
        'ProjectBudgets'                                        AS object_type,
        NVL(v.pm_budget_reference,
            p.segment1 || '::' || vtl.version_name
                       || '::' || v.plan_version_id)            AS record_key,
        'BASE'                                                  AS source_type,
        'SUCCESS'                                               AS fusion_status,
        v.plan_version_id                                       AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))                            AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)                             AS load_request_id,
        v.pm_budget_reference                                   AS source_ref,
        v.pm_budget_reference                                   AS dmt_reference
    FROM   pjo_plan_versions_b   v,
           pjo_plan_versions_tl  vtl,
           pjf_projects_all_b    p
    WHERE  vtl.plan_version_id = v.plan_version_id
    AND    vtl.language        = 'US'
    AND    p.project_id        = v.project_id
    AND    p.segment1 LIKE :P_PREFIX || '%'

    UNION ALL

    -- INTERFACE tier -- rejections only (PROCESS_CODE / LOAD_STATUS not
    -- success). SUCCESS rows are covered by the BASE tier, so nothing is
    -- counted twice. Scoped to the run by the prefixed PROJECT_NUMBER.
    -- ERROR_MESSAGE reports the interface status codes; the real per-row
    -- Fusion text is retained by the reconciler from the report XML.
    SELECT
        'ProjectBudgets'                                        AS object_type,
        NVL(x.src_budget_line_reference,
            x.project_number || '::' || x.plan_version_name)    AS record_key,
        'INTERFACE'                                             AS source_type,
        'ERROR'                                                 AS fusion_status,
        CAST(NULL AS NUMBER)                                    AS fusion_id,
        '[INTERFACE] Rejected by Import Budgets Interface Data '
             || '(PROCESS_CODE=' || NVL(x.process_code,'NULL')
             || ', LOAD_STATUS=' || NVL(x.load_status,'NULL')
             || '; not posted to PJO_PLAN_VERSIONS_B). The budget interface '
             || 'has no error-text column; the per-row Fusion rejection '
             || 'message is in the Import Budgets report XML, harvested to '
             || 'DMT TFM.ERROR_TEXT.'                           AS error_message,
        x.load_request_id                                       AS load_request_id,
        x.src_budget_line_reference                             AS source_ref,
        x.src_budget_line_reference                             AS dmt_reference
    FROM   pjo_plan_versions_xface x
    WHERE  x.project_number LIKE :P_PREFIX || '%'
    AND    NVL(UPPER(x.process_code),'X')
               NOT IN ('COMPLETED','PROCESSED','SUCCESS','P')
    AND    NVL(UPPER(x.load_status),'X')
               NOT IN ('COMPLETED','PROCESSED','SUCCESS','P')
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
