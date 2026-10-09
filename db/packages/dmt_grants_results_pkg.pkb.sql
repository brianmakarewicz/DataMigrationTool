-- PACKAGE BODY DMT_GRANTS_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GRANTS_RESULTS_PKG"
AS
-- ============================================================
-- DMT_GRANTS_RESULTS_PKG body  --  Grants reconciliation, Contract v1.
--
-- Award headers are reconciled through the ONE shared Contract v1 fetch
-- (DMT_RECON_CONTRACT_PKG.FETCH_ROWS), the same multi-tier template proven on
-- Requisitions (PR #364) and Workers. A single FETCH_ROWS call runs the
-- nine-column Grants recon report (DMT_GRANT_RECON_DM.xdm) over BIP and returns
-- the parsed rows; the APPLY is STATIC SQL against the compile-time-known award
-- header TFM table (Option A, owner decision on PR #248 -- no dynamic SQL here).
--
-- The Grants recon report reconciles the AWARD HEADER tier ONLY:
--   OBJECT_TYPE literal : 'Grants'
--   header TFM table    : DMT_GMS_AWD_HEADERS_TFM_TBL
--   FUSION_ID column    : FUSION_AWARD_ID  (GMS_AWARD_HEADERS_B.ID)
--   RECON_KEY join      : RECON_KEY = report RECORD_KEY
--                         (= the prefixed AWARD_NUMBER. The V2 data model
--                          DMT_GRANT_RECON_V2_DM keys its BASE tier on
--                          OKC_K_HEADERS_ALL_B.CONTRACT_NUMBER, which is the
--                          award number; the transform stamps RECON_KEY =
--                          AWARD_NUMBER, see DMT_GRANTS_TRANSFORM_PKG).
-- Per the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_AWARD_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message
--     appended as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left GENERATED for the honest unaccounted sweep.
-- The Grants report emits real Fusion PROCESSED_MESSAGE text (no '#IMPORT_REPORT#'
-- marker), so the ERROR rows carry real messages.
--
-- CHILD ACCOUNTING (backlog #568): each of the 14 award children (funding,
-- projects, personnel, terms, ...) is accounted on its OWN Fusion evidence from
-- the Award Batch Import Report of THIS import job, keyed by AWARD_NUMBER plus
-- the child's business keys. A child is never LOADED by inheritance:
--   * award LOADED (base table) and the report lists the child row as imported
--     (its success line under G_3) -> LOADED (APPLY_CHILD_REPORT_SUCCESSES).
--   * the report lists the child row as rejected -> FAILED with its own error,
--     also under a LOADED award; the award and its siblings are then NOT quoted
--     (Fusion created the award, so the document was not rejected).
--   * neither -> left GENERATED for the honest unaccounted sweep.
--   * award rejected -> Fusion's Award Batch Import Report names the row it
--     blamed: the award itself (G_4) or a child (the failure groups nested in
--     G_4). That row keeps its own [FUSION_ERROR] (APPLY_CHILD_REPORT_FAILURES /
--     apply_award_import_report), and PROPAGATE_DOCUMENT_ERRORS (backlog #171)
--     quotes it onto every other row of the award (header, siblings, other
--     children): '[FUSION_ERROR] Rejected with document: award <AWARD_NUMBER>
--     (<grain> <key>): <real msg>' (design section 5, "Whole-document rejection
--     carries the real error to every grain").
-- Never fabricate a child base id (children carry no FUSION_*_ID yet).
--
-- AWARD BATCH IMPORT REPORT fallback (RETAINED): Fusion purges
-- GMS_AWARD_HEADERS_INT immediately after every AwardMassImportJob, so the
-- interface tier is structurally zero-rows and real per-award rejections
-- survive only in Fusion's own Award Batch Import Report -- a SEPARATE child ESS
-- request (ImportAwardReportJob / AwardBatchImportReportDm). apply_award_import_report
-- reads that child and marks each rejected award FAILED with its real message,
-- keyed on AWARD_NUMBER. Dropping it would re-introduce the already-fixed
-- "interface purged -> UNACCOUNTED" bug.
--
-- Fusion outcomes are NOT written back to the STG tables (2026-10-07): STG
-- carries only our own NEW / TRANSFORMED / FAILED lifecycle; the outcome lives
-- on the run-stamped TFM row (section 5, "Showing final outcomes next to staging
-- data").
--
-- REVISIONS:
--   2026-10-08  BM  Backlog #171: the child that Fusion blamed for an award
--                   rejection gets its own [FUSION_ERROR] from the report's
--                   nested child failure groups (APPLY_CHILD_REPORT_FAILURES);
--                   PROPAGATE_DOCUMENT_ERRORS quotes it (or the award's own
--                   error) onto every other row of the award, naming the award
--                   and the blamed row. The old header-to-children FAILED
--                   cascade is retired.
--   2026-10-09  BM  Backlog #568: cascade_children retired; a child is LOADED
--                   only on its own success line in the job's award report,
--                   under a base-confirmed award. Document quotes skip awards
--                   Fusion created. New APPLY_AWARD_REPORT_XML test seam.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_GRANTS_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Grants';

    -- One child-grain rejection read from the Award Batch Import Report (backlog
    -- #171). Fusion nests a rejected award's child failures inside its G_4 row,
    -- one group per child record type (G_33 personnel, G_2 funding, ...), each
    -- row carrying the child's own PROCESSED_MESSAGE and the business keys
    -- Fusion received in the CSV. K1..K4 are those keys, per GRAIN:
    --   personnel  : PERSON_NUMBER, PERSON_EMAIL, PERSON_NAME, PROJECT_NUMBER
    --   funding    : BUDGET_PERIOD_NAME, ISSUE_NUMBER, FUNDING_SOURCE_NAME
    --   fund alloc : ISSUE_NUMBER, PROJECT_NUMBER
    --   budget period : BUDGET_PERIOD
    --   org credit : PROJECT_NUMBER, ORGANIZATION_NAME
    --   project    : PROJECT_NUMBER
    --   cfda       : CFDA_NAME
    --   term       : TERM_NAME, TERM_CATEGORY_NAME
    --   certification : CERTIFICATION_NAME, PROJECT_NUMBER
    --   reference  : REFERENCE_TYPE, PROJECT_NUMBER
    --   task burden: PROJECT_NUMBER, BURDEN_SCHEDULE
    --   project funding source : PROJECT_NUMBER, FUNDING_SOURCE_NAME
    --   funding source : FUNDING_SOURCE_NAME
    --   keyword    : KEYWORD_NAME, PROJECT_NUMBER
    -- A NULL key is not compared (Fusion echoes only what the CSV carried).
    TYPE T_CHILD_FAIL IS RECORD (
        GRAIN        VARCHAR2(30),
        AWARD_NUMBER VARCHAR2(300),
        K1           VARCHAR2(500),
        K2           VARCHAR2(500),
        K3           VARCHAR2(500),
        K4           VARCHAR2(500),
        MSG          VARCHAR2(4000)
    );
    TYPE T_CHILD_FAIL_TBL IS TABLE OF T_CHILD_FAIL;

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS, backlog #171).
    -- Working set: "award AWARD_NUMBER was rejected and one of its rows carries
    -- its own real Fusion error, so every other row of that award still waiting
    -- for a verdict must carry QUOTED_ERROR".
    TYPE T_DOC_PAIR IS RECORD (
        AWARD_NUMBER VARCHAR2(300),
        QUOTED_ERROR VARCHAR2(4000)      -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

    -- --------------------------------------------------------
    -- find_report_ess_id
    -- Resolve the child Award Batch Import Report ESS request
    -- (ImportAwardReportJob) that Fusion spawns alongside the
    -- AwardMassImportJob. The report holds the per-award rejection
    -- messages that survive the interface-table purge.
    --
    -- Mirrors DMT_BILLING_EVENT_RESULTS_PKG.find_report_ess_id:
    -- first look for a child already captured in DMT_ESS_JOB_TBL
    -- (PARENT_REQUEST_ID = the import ESS id, a REPORT job), then
    -- fall back to capturing it now via CAPTURE_REPORT_ESS_JOB (which
    -- needs REPORT_JOB_DEF seeded for 'Grants'). Non-blocking: any
    -- failure logs a WARN and returns NULL.
    -- --------------------------------------------------------
    FUNCTION find_report_ess_id (
        p_run_id        IN NUMBER,
        p_import_ess_id IN NUMBER
    ) RETURN NUMBER IS
        C_PROC   CONSTANT VARCHAR2(30) := 'find_report_ess_id';
        l_result NUMBER;
    BEGIN
        -- Already captured in the ESS hierarchy?
        BEGIN
            SELECT REQUEST_ID INTO l_result
            FROM   DMT_ESS_JOB_TBL
            WHERE  PARENT_REQUEST_ID = p_import_ess_id
            AND    UPPER(JOB_DEFINITION) LIKE '%REPORT%'
            FETCH FIRST 1 ROW ONLY;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_result := NULL;
        END;

        IF l_result IS NOT NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Found report ESS ' || l_result ||
                ' in hierarchy (child of import ' || p_import_ess_id || ').',
                'INFO',
                C_PKG, C_PROC);
            RETURN l_result;
        END IF;

        -- Not captured yet — capture it now (needs REPORT_JOB_DEF seeded).
        l_result := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
            p_run_id        => p_run_id,
            p_import_ess_id => p_import_ess_id,
            p_cemli_code    => C_CEMLI);

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': Report ESS id = ' || NVL(TO_CHAR(l_result), 'NULL') ||
            ' (captured from import ESS ' || p_import_ess_id || ').',
            'INFO',
            C_PKG, C_PROC);

        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Failed to find Report child ESS: ' || SQLERRM,
                'INFO',
                C_PKG, C_PROC);
            RETURN NULL;
    END find_report_ess_id;

    -- --------------------------------------------------------
    -- APPLY_CHILD_REPORT_FAILURES (private, backlog #171)
    -- Give each award child that Fusion itself rejected its OWN real error.
    -- The Award Batch Import Report nests a rejected award's child failures
    -- inside its G_4 row: one group per child record type, each row carrying
    -- the child's own PROCESSED_MESSAGE and the keys Fusion read from the CSV
    -- (Fusion's data model AwardBatchImportReportDm, groups G_2 .. G_41).
    -- Each one is matched to its child TFM row of this run by AWARD_NUMBER plus
    -- the child's business keys (a key the report leaves NULL is not compared)
    -- and that row is set FAILED with '[FUSION_ERROR] <message>'. Only rows
    -- still awaiting a verdict are touched (never LOADED, never already
    -- FAILED), so a second pass changes nothing. Returns the parsed failures
    -- in x_fails so the caller can tell a child-caused award rejection from a
    -- header one. Static SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CHILD_REPORT_FAILURES (
        p_run_id IN  NUMBER,
        p_xml    IN  XMLTYPE,
        x_fails  OUT T_CHILD_FAIL_TBL,
        x_rows   OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'APPLY_CHILD_REPORT_FAILURES';
        l_step VARCHAR2(200);
    BEGIN
        x_rows := 0;
        l_step := 'reading child failure groups from the award report';
        SELECT grain, award_number, k1, k2, k3, k4, msg
        BULK COLLECT INTO x_fails
        FROM (
            SELECT 'personnel' grain, x.award_number, x.k1, x.k2, x.k3, x.k4, x.msg
            FROM   XMLTABLE('//G_33' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PERSON_NUMBER',
                       k2 VARCHAR2(500) PATH 'PERSON_EMAIL',
                       k3 VARCHAR2(500) PATH 'PERSON_NAME',
                       k4 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'funding', x.award_number, x.k1, x.k2, x.k3, NULL, x.msg
            FROM   XMLTABLE('//G_2' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'BUDGET_PERIOD_NAME',
                       k2 VARCHAR2(500) PATH 'ISSUE_NUMBER',
                       k3 VARCHAR2(500) PATH 'FUNDING_SOURCE_NAME',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'fund allocation', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_41' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'ISSUE_NUMBER',
                       k2 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'budget period', x.award_number, x.k1, NULL, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_30' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'BUDGET_PERIOD',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'org credit', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_28' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       k2 VARCHAR2(500) PATH 'ORGANIZATION_NAME',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'project', x.award_number, x.k1, NULL, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_24' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'cfda', x.award_number, x.k1, NULL, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_21' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'CFDA_NAME',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'term', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_18' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'TERM_NAME',
                       k2 VARCHAR2(500) PATH 'TERM_CATEGORY_NAME',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'certification', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_7' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'CERTIFICATION_NAME',
                       k2 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'reference', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_13' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'REFERENCE_TYPE',
                       k2 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'task burden schedule', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_14' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       k2 VARCHAR2(500) PATH 'BURDEN_SCHEDULE',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'project funding source', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_19' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       k2 VARCHAR2(500) PATH 'FUNDING_SOURCE_NAME',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'funding source', x.award_number, x.k1, NULL, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_25' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'FUNDING_SOURCE_NAME',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
            UNION ALL
            SELECT 'keyword', x.award_number, x.k1, x.k2, NULL, NULL, x.msg
            FROM   XMLTABLE('//G_8' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300)  PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'KEYWORD_NAME',
                       k2 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       msg VARCHAR2(4000) PATH 'PROCESSED_MESSAGE') x
        )
        WHERE award_number IS NOT NULL
        AND   msg IS NOT NULL;

        -- One static bulk UPDATE per child table. Each FORALL walks every parsed
        -- failure; the GRAIN predicate picks the ones for that table.
        l_step := 'marking rejected personnel rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_PERSONNEL_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'personnel'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.PERSON_NUMBER = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR UPPER(t.PERSON_EMAIL) = UPPER(x_fails(i).K2))
            AND    (x_fails(i).K3 IS NULL OR t.PERSON_NAME = x_fails(i).K3)
            AND    (x_fails(i).K4 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K4)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected funding rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_FUNDING_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'funding'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.BUDGET_PERIOD_NAME = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.ISSUE_NUMBER = x_fails(i).K2)
            AND    (x_fails(i).K3 IS NULL OR t.FUNDING_SOURCE_NAME = x_fails(i).K3)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected funding allocation rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'fund allocation'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.ISSUE_NUMBER = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected budget period rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'budget period'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.BUDGET_PERIOD = x_fails(i).K1)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected org credit rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'org credit'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.ORGANIZATION = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected project rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_PROJECTS_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'project'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K1)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected cfda rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_CFDAS_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'cfda'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.CFDA = x_fails(i).K1)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected term rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_TERMS_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'term'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.TERM_NAME = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.TERM_CATEGORY_NAME = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected certification rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_CERTS_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'certification'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.CERTIFICATION_NAME = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected reference rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_REFERENCES_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'reference'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.REFERENCE_TYPE = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected task burden schedule rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'task burden schedule'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.BURDEN_SCHEDULE = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected project funding source rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'project funding source'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.FUNDING_SOURCE_NAME = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected funding source rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_FUND_SRC_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'funding source'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.FUNDING_SOURCE_NAME = x_fails(i).K1)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking rejected keyword rows';
        FORALL i IN 1 .. x_fails.COUNT
            UPDATE DMT_GMS_AWD_KEYWORDS_TFM_TBL t
            SET    t.TFM_STATUS = 'FAILED',
                   t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, '[FUSION_ERROR] ' || x_fails(i).MSG),
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    x_fails(i).GRAIN = 'keyword'
            AND    t.AWARD_NUMBER = x_fails(i).AWARD_NUMBER
            AND    (x_fails(i).K1 IS NULL OR t.KEYWORD_NAME = x_fails(i).K1)
            AND    (x_fails(i).K2 IS NULL OR t.PROJECT_NUMBER = x_fails(i).K2)
            AND    t.TFM_STATUS NOT IN ('LOADED', 'FAILED');
        x_rows := x_rows + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ': ' || x_fails.COUNT || ' child failure(s) in the award report; '
                           || x_rows || ' child row(s) marked FAILED with their own Fusion error.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CHILD_REPORT_FAILURES;

    -- --------------------------------------------------------
    -- APPLY_CHILD_REPORT_SUCCESSES (private, backlog #568)
    -- A child row is LOADED only on its OWN Fusion evidence, never by
    -- inheritance from its award. Fusion's Award Batch Import Report for THIS
    -- import job (the report is a child request of the run's import ESS id, so
    -- the evidence is scoped by ESS job id, never by prefix text) lists, under
    -- each successful award (G_3), one success line per child row it imported:
    -- G_35 personnel, G_36 funding, G_40 funding allocation, G_32 budget period,
    -- G_27 org credit, G_26 project, G_23 funding source, G_16 project funding
    -- source. Each line is matched to ONE child TFM row of this run (award number
    -- plus the child's business keys; a key the report leaves empty is not
    -- compared; the lowest TFM_SEQUENCE_ID still awaiting a verdict wins, so two
    -- identical rows need two success lines) and that row is set LOADED, but only
    -- when its award header is already LOADED from the base table
    -- (GMS_AWARD_HEADERS_B). A child with no success line of its own stays
    -- GENERATED for the honest unaccounted sweep, and a child that Fusion
    -- rejected keeps its own [FUSION_ERROR] (APPLY_CHILD_REPORT_FAILURES runs
    -- first and FAILED rows are never touched). The other six child record types
    -- (terms, keywords, certifications, CFDAs, references, task burden schedules)
    -- have no success group in Fusion's report, so they are never LOADED here
    -- (backlog #671). Static SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CHILD_REPORT_SUCCESSES (
        p_run_id IN  NUMBER,
        p_xml    IN  XMLTYPE,
        x_rows   OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'APPLY_CHILD_REPORT_SUCCESSES';
        l_step VARCHAR2(200);
        l_oks  T_CHILD_FAIL_TBL;
    BEGIN
        x_rows := 0;
        l_step := 'reading child success groups of successful awards';
        SELECT grain, award_number, k1, k2, k3, k4, msg
        BULK COLLECT INTO l_oks
        FROM (
            SELECT 'personnel' grain, x.award_number, x.k1, x.k2, x.k3, x.k4, NULL msg
            FROM   XMLTABLE('//G_3//G_35' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PERSON_NUMBER',
                       k2 VARCHAR2(500) PATH 'PERSON_EMAIL',
                       k3 VARCHAR2(500) PATH 'PERSON_NAME',
                       k4 VARCHAR2(500) PATH 'PROJECT_NUMBER') x
            UNION ALL
            SELECT 'funding' grain, x.award_number, x.k1, x.k2, x.k3, NULL, NULL msg
            FROM   XMLTABLE('//G_3//G_36' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'BUDGET_PERIOD_NAME',
                       k2 VARCHAR2(500) PATH 'ISSUE_NUMBER',
                       k3 VARCHAR2(500) PATH 'FUNDING_SOURCE_NAME') x
            UNION ALL
            SELECT 'fund allocation' grain, x.award_number, x.k1, x.k2, NULL, NULL, NULL msg
            FROM   XMLTABLE('//G_3//G_40' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'ISSUE_NUMBER',
                       k2 VARCHAR2(500) PATH 'PROJECT_NUMBER') x
            UNION ALL
            SELECT 'budget period' grain, x.award_number, x.k1, NULL, NULL, NULL, NULL msg
            FROM   XMLTABLE('//G_3//G_32' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'BUDGET_PERIOD') x
            UNION ALL
            SELECT 'org credit' grain, x.award_number, x.k1, x.k2, NULL, NULL, NULL msg
            FROM   XMLTABLE('//G_3//G_27' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       k2 VARCHAR2(500) PATH 'ORGANIZATION_NAME') x
            UNION ALL
            SELECT 'project' grain, x.award_number, x.k1, NULL, NULL, NULL, NULL msg
            FROM   XMLTABLE('//G_3//G_26' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PROJECT_NUMBER') x
            UNION ALL
            SELECT 'funding source' grain, x.award_number, x.k1, NULL, NULL, NULL, NULL msg
            FROM   XMLTABLE('//G_3//G_23' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'FUNDING_SOURCE_NAME') x
            UNION ALL
            SELECT 'project funding source' grain, x.award_number, x.k1, x.k2, NULL, NULL, NULL msg
            FROM   XMLTABLE('//G_3//G_16' PASSING p_xml COLUMNS
                       award_number VARCHAR2(300) PATH 'AWARD_NUMBER',
                       k1 VARCHAR2(500) PATH 'PROJECT_NUMBER',
                       k2 VARCHAR2(500) PATH 'FUNDING_SOURCE_NAME') x
        )
        WHERE award_number IS NOT NULL;

        l_step := 'marking personnel rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_PERSONNEL_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'personnel'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_PERSONNEL_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.PERSON_NUMBER = l_oks(i).K1)
                       AND    (l_oks(i).K2 IS NULL OR UPPER(c.PERSON_EMAIL) = UPPER(l_oks(i).K2))
                       AND    (l_oks(i).K3 IS NULL OR c.PERSON_NAME = l_oks(i).K3)
                       AND    (l_oks(i).K4 IS NULL OR c.PROJECT_NUMBER = l_oks(i).K4)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking funding rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_FUNDING_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'funding'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_FUNDING_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.BUDGET_PERIOD_NAME = l_oks(i).K1)
                       AND    (l_oks(i).K2 IS NULL OR c.ISSUE_NUMBER = l_oks(i).K2)
                       AND    (l_oks(i).K3 IS NULL OR c.FUNDING_SOURCE_NAME = l_oks(i).K3)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking fund allocation rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'fund allocation'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_FUND_ALLOC_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.ISSUE_NUMBER = l_oks(i).K1)
                       AND    (l_oks(i).K2 IS NULL OR c.PROJECT_NUMBER = l_oks(i).K2)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking budget period rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'budget period'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_BDGT_PRDS_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.BUDGET_PERIOD = l_oks(i).K1)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking org credit rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'org credit'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_ORG_CREDITS_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.PROJECT_NUMBER = l_oks(i).K1)
                       AND    (l_oks(i).K2 IS NULL OR c.ORGANIZATION = l_oks(i).K2)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking project rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_PROJECTS_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'project'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_PROJECTS_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.PROJECT_NUMBER = l_oks(i).K1)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking funding source rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_FUND_SRC_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'funding source'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_FUND_SRC_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.FUNDING_SOURCE_NAME = l_oks(i).K1)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        l_step := 'marking project funding source rows Fusion reported imported';
        FORALL i IN 1 .. l_oks.COUNT
            UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
            SET    t.TFM_STATUS = 'LOADED',
                   t.RESULTS_UPDATED_DATE = SYSDATE, t.LAST_UPDATED_DATE = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    l_oks(i).GRAIN = 'project funding source'
            AND    t.TFM_SEQUENCE_ID = (
                       SELECT MIN(c.TFM_SEQUENCE_ID)
                       FROM   DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL c
                       WHERE  c.RUN_ID = p_run_id
                       AND    c.AWARD_NUMBER = l_oks(i).AWARD_NUMBER
                       AND    (l_oks(i).K1 IS NULL OR c.PROJECT_NUMBER = l_oks(i).K1)
                       AND    (l_oks(i).K2 IS NULL OR c.FUNDING_SOURCE_NAME = l_oks(i).K2)
                       AND    c.FBDI_CSV_ID IS NOT NULL
                       AND    c.TFM_STATUS NOT IN ('LOADED', 'FAILED', 'STAGED')
                       AND    EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                                      WHERE  h.RUN_ID = p_run_id
                                      AND    h.AWARD_NUMBER = c.AWARD_NUMBER
                                      AND    h.TFM_STATUS = 'LOADED'));
        x_rows := x_rows + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ': ' || l_oks.COUNT || ' child success line(s) in the award report; '
                           || x_rows || ' child row(s) of LOADED awards marked LOADED on their own line.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CHILD_REPORT_SUCCESSES;

    -- --------------------------------------------------------
    -- apply_report_xml_core (private)
    -- Everything the reconciler takes from the Award Batch Import Report once
    -- its XML is in hand (transport and parse are separable, design section 7):
    --   1. each child Fusion rejected gets its own [FUSION_ERROR]
    --      (APPLY_CHILD_REPORT_FAILURES);
    --   2. each rejected award (G_4) gets its own [FUSION_ERROR] unless a child
    --      caused the rejection (then G_4 is only Fusion's pointer to it);
    --   3. each child of a LOADED award that the report lists as imported is
    --      LOADED on its own success line (APPLY_CHILD_REPORT_SUCCESSES, #568).
    -- x_failed = rows set FAILED, x_loaded = child rows set LOADED. NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE apply_report_xml_core (
        p_run_id  IN  NUMBER,
        p_xml     IN  XMLTYPE,
        x_failed  OUT NUMBER,
        x_loaded  OUT NUMBER
    ) IS
        l_xml          XMLTYPE := p_xml;
        l_matched      NUMBER := 0;
        l_child_fails  T_CHILD_FAIL_TBL := T_CHILD_FAIL_TBL();
        l_child_rows   NUMBER := 0;
        l_child_caused BOOLEAN;
    BEGIN
        -- Backlog #171: first give every child that Fusion rejected its OWN real
        -- error (the failure groups nested in each G_4 row).
        APPLY_CHILD_REPORT_FAILURES(p_run_id, l_xml, l_child_fails, l_child_rows);

        -- Attribute each rejected award to its TFM row with the real message.
        -- When the report also lists a failed CHILD of the award, the child
        -- caused the rejection and the award's G_4 text is only Fusion's pointer
        -- to it (live run 320: "The award isn't imported because errors exist
        -- in the personnel data."). The header is then left for
        -- PROPAGATE_DOCUMENT_ERRORS, which quotes the child's real error onto it
        -- ("the row whose own error it is keeps it", design section 5).
        FOR r IN (
            SELECT x.award_number,
                   x.processed_message
            FROM   XMLTABLE('//G_4' PASSING l_xml
                COLUMNS
                    award_number      VARCHAR2(300)  PATH 'PARENT_AWARD_NUMBER',
                    processed_message VARCHAR2(4000) PATH 'PROCESSED_MESSAGE'
            ) x
            WHERE  x.award_number IS NOT NULL
            AND    x.processed_message IS NOT NULL
        ) LOOP
            l_child_caused := FALSE;
            FOR j IN 1 .. l_child_fails.COUNT LOOP
                IF l_child_fails(j).AWARD_NUMBER = r.award_number THEN
                    l_child_caused := TRUE;
                END IF;
            END LOOP;
            IF NOT l_child_caused THEN
                UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[FUSION_ERROR] ' || r.processed_message),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND AWARD_NUMBER = r.award_number
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_matched := l_matched + SQL%ROWCOUNT;
            END IF;
        END LOOP;
        l_matched := l_matched + l_child_rows;

        APPLY_CHILD_REPORT_SUCCESSES(p_run_id, l_xml, x_loaded);
        x_failed := l_matched;
    END apply_report_xml_core;

    -- --------------------------------------------------------
    -- apply_award_import_report
    -- Read the Award Batch Import Report XML and mark each rejected
    -- award FAILED with its REAL Fusion message.
    --
    -- The report's per-award failure rows live in LIST_G_4/G_4:
    --   PARENT_AWARD_NUMBER -> the award number (TFM key)
    --   PROCESSED_MESSAGE   -> the real Fusion rejection message
    -- G_4 is the FAILURE list: every G_4 row is a real rejection. (Since
    -- 2026-10-07 the import runs with "report success details" = true, so the
    -- report ALSO lists successful awards in LIST_G_3. An AWARD is LOADED only
    -- by the base table; G_3 is read only for each child's own success line
    -- under an award the base table already confirmed -- backlog #568.)
    -- We only ever transition GENERATED -> FAILED here, and only when
    -- PROCESSED_MESSAGE is non-empty (never fabricate an error). Awards
    -- absent from the list are left untouched (base tier may have set
    -- them LOADED; otherwise they stay GENERATED for the honest sweep).
    --
    -- Returns the count of TFM rows marked FAILED.
    -- --------------------------------------------------------
    FUNCTION apply_award_import_report (
        p_run_id        IN NUMBER,
        p_import_ess_id IN NUMBER
    ) RETURN NUMBER IS
        C_PROC          CONSTANT VARCHAR2(30) := 'apply_award_import_report';
        l_report_ess_id NUMBER;
        l_xml_clob      CLOB;
        l_xml           XMLTYPE;
        l_matched       NUMBER := 0;
        l_ess_user      VARCHAR2(100);
        l_ess_pass      VARCHAR2(100);
        l_loaded_children NUMBER := 0;
    BEGIN
        IF p_import_ess_id IS NULL THEN
            RETURN 0;
        END IF;

        l_report_ess_id := find_report_ess_id(p_run_id, p_import_ess_id);
        IF l_report_ess_id IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': No Award Batch Import Report child found for import ESS ' ||
                p_import_ess_id || '. Nothing to attribute from the report.',
                'INFO',
                C_PKG, C_PROC);
            RETURN 0;
        END IF;

        -- Download the report as the Grants per-object user (PPM_IMPL): Fusion
        -- spawns the report child as the user that submitted the import, and
        -- refuses another user's ESS output with HTTP 500 (FND_CMN_SYS_ERR).
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(p_cemli_code => C_CEMLI, x_username => l_ess_user, x_password => l_ess_pass);
        BEGIN
            l_xml_clob := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(
                              p_request_id => l_report_ess_id,
                              p_username   => l_ess_user,
                              p_password   => l_ess_pass);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': Failed to download report XML from ESS ' ||
                    l_report_ess_id || ': ' || SQLERRM,
                    'INFO',
                    C_PKG, C_PROC);
                RETURN 0;
        END;

        IF l_xml_clob IS NULL OR DBMS_LOB.GETLENGTH(l_xml_clob) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Report ESS ' || l_report_ess_id || ' returned empty output.',
                'INFO',
                C_PKG, C_PROC);
            RETURN 0;
        END IF;

        BEGIN
            l_xml := XMLTYPE(l_xml_clob);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': Report output for ESS ' || l_report_ess_id ||
                    ' is not valid XML: ' || SQLERRM,
                    'INFO',
                    C_PKG, C_PROC);
                IF DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_xml_clob);
                END IF;
                RETURN 0;
        END;

        apply_report_xml_core(p_run_id, l_xml, l_matched, l_loaded_children);

        IF DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml_clob);
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': Award Batch Import Report (ESS ' || l_report_ess_id ||
            ') parsed; ' || l_matched || ' row(s) marked FAILED with a real Fusion message; '
            || l_loaded_children || ' child row(s) of LOADED awards marked LOADED on their own success line.',
            'INFO',
            C_PKG, C_PROC);

        RETURN l_matched;
    EXCEPTION
        WHEN OTHERS THEN
            -- Never abort reconciliation on a report-read problem: log and
            -- return what we matched. Unmatched rows stay GENERATED (honest).
            BEGIN
                IF l_xml_clob IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_xml_clob);
                END IF;
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report parse/apply failed (' || SQLERRM ||
                '); ' || l_matched || ' rows matched before the error.',
                'INFO',
                C_PKG, C_PROC);
            RETURN l_matched;
    END apply_award_import_report;

    -- --------------------------------------------------------
    -- PROPAGATE_DOCUMENT_ERRORS (private, backlog #171)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07). The Fusion document is the award: Import
    -- Awards rejects the whole award when the award itself or any one of its
    -- child rows fails, and writes the error only against the row it blamed (the
    -- award in G_4, or the child in the failure group nested under it).
    --
    -- Sources: every row of this run, header or child, with TFM_STATUS = 'FAILED'
    --   carrying its OWN real Fusion error -- ERROR_TEXT contains '[FUSION_ERROR]'
    --   and does NOT contain C_DOC_ERROR_MARKER (a quote is never re-quoted).
    -- Quote: '[FUSION_ERROR] Rejected with document: award <AWARD_NUMBER>: <msg>'
    --   for a header source, and
    --   '[FUSION_ERROR] Rejected with document: award <AWARD_NUMBER> (<grain> <key>): <msg>'
    --   for a child source, so the reader sees the award and the row Fusion blamed.
    -- Targets: every row of the same award (header and all 14 child tables) that
    --   Fusion received (FBDI_CSV_ID stamped at generation), is not LOADED and not
    --   STAGED, and has no real error of its own: either still awaiting a verdict,
    --   or FAILED carrying only quotes. The row Fusion blamed keeps its own error
    --   and is never given a quote. The quote is appended (APPEND_ERROR, never
    --   overwrite) and the row set FAILED.
    -- Idempotent: a row already carrying the exact quote is skipped, so a second
    --   reconcile pass adds nothing. LOADED rows are never touched.
    -- One static SELECT builds the (award, quote) pairs, then ONE static bulk
    -- UPDATE (FORALL) per table. Scoped by RUN_ID: the Grants transform does not
    -- stamp WORK_QUEUE_ID (README known issue) and Grants runs as one work item.
    -- NO dynamic SQL; NO COMMIT (caller owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG      CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        C_TAG_RX   CONSTANT VARCHAR2(40) := '\[FUSION_ERROR\]';
        C_QUOTE_RX CONSTANT VARCHAR2(80) := '\[FUSION_ERROR\] ' || DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_marker   VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs    T_DOC_PAIR_TBL;
        l_rows     NUMBER := 0;
        l_step     VARCHAR2(200);
    BEGIN
        l_step := 'collecting (award, quoted error) pairs for run ' || p_run_id;
        SELECT AWARD_NUMBER, QUOTED_ERROR
        BULK COLLECT INTO l_pairs
        FROM (
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER,
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_HEADERS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (funding ' || t.ISSUE_NUMBER || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_FUNDING_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (project ' || t.PROJECT_NUMBER || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_PROJECTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (personnel ' || COALESCE(t.PERSON_NUMBER, t.PERSON_EMAIL, t.PERSON_NAME) || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_PERSONNEL_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (funding source ' || t.FUNDING_SOURCE_NAME || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_FUND_SRC_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (project funding source ' || t.PROJECT_NUMBER || '/' || t.FUNDING_SOURCE_NAME || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (keyword ' || t.KEYWORD_NAME || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_KEYWORDS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (budget period ' || t.BUDGET_PERIOD || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (certification ' || t.CERTIFICATION_NAME || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_CERTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (cfda ' || t.CFDA || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_CFDAS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (fund allocation ' || t.ISSUE_NUMBER || '/' || t.PROJECT_NUMBER || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (org credit ' || t.ORGANIZATION || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (task burden schedule ' || t.PROJECT_NUMBER || '/' || t.TASK_NUMBER || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (reference ' || t.REFERENCE_TYPE || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_REFERENCES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
            UNION ALL
            SELECT t.AWARD_NUMBER,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR('award', t.AWARD_NUMBER || ' (term ' || t.TERM_NAME || ')',
                       DBMS_LOB.SUBSTR(t.ERROR_TEXT, 3800, DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG))) QUOTED_ERROR
            FROM   DMT_GMS_AWD_TERMS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED' AND t.AWARD_NUMBER IS NOT NULL
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, C_TAG) > 0
            AND    DBMS_LOB.INSTR(t.ERROR_TEXT, l_marker) = 0
        )
        -- Backlog #568: Fusion created this award (header LOADED from the base
        -- table), so a rejected child did not take the document down with it.
        -- That child keeps its own error; its award and siblings are not quoted.
        WHERE AWARD_NUMBER NOT IN (
                  SELECT h.AWARD_NUMBER FROM DMT_GMS_AWD_HEADERS_TFM_TBL h
                  WHERE  h.RUN_ID = p_run_id AND h.TFM_STATUS = 'LOADED'
                  AND    h.AWARD_NUMBER IS NOT NULL);

        l_step := 'quoting award errors onto award headers';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto funding';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_FUNDING_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto projects';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_PROJECTS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto personnel';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_PERSONNEL_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto funding sources';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_FUND_SRC_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto project funding sources';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto keywords';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_KEYWORDS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto budget periods';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto certifications';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_CERTS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto cfdas';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_CFDAS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto funding allocations';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto org credits';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto task burden schedules';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto references';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_REFERENCES_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        l_step := 'quoting award errors onto terms';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_GMS_AWD_TERMS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID = p_run_id
            AND    t.AWARD_NUMBER = l_pairs(i).AWARD_NUMBER
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    (t.TFM_STATUS <> 'FAILED'
                    OR REGEXP_COUNT(t.ERROR_TEXT, C_TAG_RX) = REGEXP_COUNT(t.ERROR_TEXT, C_QUOTE_RX))
            AND    l_pairs(i).QUOTED_ERROR IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_rows := l_rows + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rejected-row sources: ' || l_pairs.COUNT
                           || ' | award rows given a quoted error: ' || l_rows || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END PROPAGATE_DOCUMENT_ERRORS;

    -- --------------------------------------------------------
    -- APPLY_AWARD_REPORT_XML (public, backlog #568) -- see spec.
    -- The report half of the reconcile, on an XML payload the caller supplies:
    -- apply_report_xml_core then PROPAGATE_DOCUMENT_ERRORS, exactly the order
    -- APPLY_CONTRACT_V1_GRANTS runs them after the base-table pass. NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE APPLY_AWARD_REPORT_XML (
        p_run_id      IN  NUMBER,
        p_report_xml  IN  CLOB,
        x_rows_failed OUT NUMBER,
        x_rows_loaded OUT NUMBER,
        x_error_code  OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'APPLY_AWARD_REPORT_XML';
        l_step VARCHAR2(200);
    BEGIN
        x_error_code  := DMT_UTIL_PKG.C_SUCCESS;
        x_rows_failed := 0;
        x_rows_loaded := 0;
        l_step := 'applying the award report XML';
        apply_report_xml_core(p_run_id, XMLTYPE(p_report_xml), x_rows_failed, x_rows_loaded);
        l_step := 'propagating document errors';
        PROPAGATE_DOCUMENT_ERRORS(p_run_id);
    EXCEPTION
        WHEN OTHERS THEN
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END APPLY_AWARD_REPORT_XML;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_GRANTS (private)
    -- The Contract v1 apply for the Grants award-header tier, Option A shape
    -- (owner decision on PR #248). The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS
    -- runs the nine-column Grants recon report over BIP and returns the parsed
    -- rows (no dynamic SQL, no TFM reference there); the APPLY here is STATIC SQL
    -- against the compile-time-known award header TFM table, joined on
    -- RECON_KEY = report RECORD_KEY. This is the header verdict; each of the 14
    -- children is then settled on its own report line (backlog #568). The
    -- Award Batch Import Report fallback fills in real per-award rejection
    -- messages that the purged interface table cannot.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_GRANTS (
        p_run_id        IN NUMBER,
        p_request_id    IN VARCHAR2,
        p_import_ess_id IN NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_GRANTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rpt_failed NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count on the award header tier drives the shared fetch's
        -- keyset page-count cap. Done statically here (not in the shared pkg).
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_GMS_AWD_HEADERS_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => TO_NUMBER(p_request_id),
            p_import_ess_id => p_import_ess_id,
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                C_PROC || ': Contract v1 fetch failed for Grants '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): the base +
            -- interface tiers found nothing. This is the EXPECTED shape after an
            -- AwardMassImportJob (Fusion purges the interface table). Do NOT treat
            -- it as LOADED; instead read the Award Batch Import Report for the real
            -- per-award rejection messages, then leave any still-unresolved award
            -- GENERATED for the honest unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Grants recon report returned zero rows '
                               || '(interface purged / no base match). Reading the '
                               || 'Award Batch Import Report for per-award errors.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                -- The Grants report emits a single tier: OBJECT_TYPE = 'Grants'
                -- (the award header). Guard on it so no other tier could ever be
                -- misapplied to the header table.
                IF l_rows(i).OBJECT_TYPE = 'Grants' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Positive proof: award found in GMS_AWARD_HEADERS_B with a
                        -- real id. The ONLY path to LOADED.
                        --
                        -- Backlog #65 three-tier match (owner order on PR #481). Tier 1
                        -- is the stamped recon key (RECON_KEY = RECORD_KEY, exactly as
                        -- before). Tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID = the
                        -- trailing numeric segment of DFF_KEY) is kept uniform with the
                        -- shared template; Grants' DMT_REFERENCE is the award ATTRIBUTE1
                        -- reference string, not a numeric carrier, so tier 2 is normally a
                        -- no-op. There is NO tier 3 for Grants: on the BASE (LOADED) path
                        -- this pre-#65 recon DM returns SOURCE_REF = AWARD_SOURCE (the
                        -- constant 'FBDI'), not a source-side award business key, so a
                        -- business-key fall-through has nothing meaningful to match (the
                        -- award's own reference travels as RECORD_KEY = the prefixed award
                        -- number / contract number, already handled by tier 1). Every tier-1 hit short-circuits, so
                        -- loaded outcomes are identical to before. Static UPDATEs.
                        UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_AWARD_ID      = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_AWARD_ID      = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED award via TIER2 '
                                || 'fallback (tier 1 stamped key did not resolve). '
                                || 'AWARD_ID ' || l_rows(i).FUSION_ID || '.',
                                'INFO', C_PKG, C_PROC);
                        END IF;

                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        -- A real, specific Fusion error -> FAILED on the exact
                        -- message (never composed). Static UPDATE on RECON_KEY.
                        UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;

                    ELSE
                        -- INTERFACE/SUCCESS (corroborating, never sufficient) or a
                        -- non-terminal status with no real error: leave the row for
                        -- the honest sweep. Never fabricate an outcome.
                        NULL;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        -- Award Batch Import Report pass (RETAINED): the real per-award rejection
        -- messages survive only in Fusion's own Award Batch Import Report, because
        -- Fusion purges GMS_AWARD_HEADERS_INT right after import. Any award neither
        -- base-confirmed LOADED nor already FAILED gets its REAL message here
        -- (keyed on AWARD_NUMBER; only GENERATED -> FAILED, never fabricated).
        -- Backlog #568: the same pass sets a child LOADED only on its own success
        -- line under a base-confirmed award (the retired cascade_children set
        -- every child of a LOADED award LOADED by inheritance).
        l_rpt_failed := apply_award_import_report(p_run_id, p_import_ess_id);
        l_failed := l_failed + l_rpt_failed;

        -- Backlog #171: quote the real error of the row Fusion blamed (award or
        -- child) onto every other row of that award. Runs after the per-row
        -- apply and before the shared SWEEP_UNACCOUNTED.
        PROPAGATE_DOCUMENT_ERRORS(p_run_id);

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | award headers LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || ' (of which ' || l_rpt_failed || ' from the Award Batch Import Report)'
                           || ' | children LOADED only on their own report success line; rejected awards propagated.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_GRANTS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — entry point (signature unchanged). Calls the shared
    -- Contract v1 apply. The Grants load ESS id is the Contract v1
    -- P_LOAD_REQUEST_ID; the import ESS id (P_IMPORT_ESS_ID) scopes the BASE
    -- tier and identifies the Award Batch Import Report child.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
            ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            'INFO',
            C_PKG, C_PROC);

        APPLY_CONTRACT_V1_GRANTS(p_run_id, TO_CHAR(p_load_ess_id), p_import_ess_id);

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE_BATCH;


    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known Grants TFM table(s). Flips this run's UNACCOUNTED rows
    -- back to GENERATED and strips the trailing [UNACCOUNTED] tag from ERROR_TEXT
    -- (CLOB-safe REGEXP_REPLACE -- plain REPLACE raises ORA-22849), preserving any
    -- prior real error. Scoped by run, and by work-queue item when given. NO
    -- dynamic SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_PROJECTS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_FUNDING_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_KEYWORDS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_FUND_SRC_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_BDGT_PRDS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_CERTS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_CFDAS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_FUND_ALLOC_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_ORG_CREDITS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_PERSONNEL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_REFERENCES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_GMS_AWD_TERMS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED Grants row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_GRANTS_RESULTS_PKG;
/
