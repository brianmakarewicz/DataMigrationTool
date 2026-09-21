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
--                         (= SPONSOR_AWARD_NUMBER, the DM's BASE-tier key with
--                          its 'AWARD_ID:'||ID null fallback; the transform
--                          stamps SPONSOR_AWARD_NUMBER, see
--                          DMT_GRANTS_TRANSFORM_PKG).
-- Per the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_AWARD_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message
--     appended as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left GENERATED for the honest unaccounted sweep.
-- The Grants report emits real Fusion PROCESSED_MESSAGE text (no '#IMPORT_REPORT#'
-- marker), so the ERROR rows carry real messages.
--
-- CHILD ACCOUNTING (unchanged behaviour): the 14 award children (funding,
-- projects, personnel, terms, ...) have NO independent Fusion base/interface
-- proof on this pod. Their ONLY honest verdict is their parent award's verdict,
-- keyed by AWARD_NUMBER:
--   * award LOADED -> children LOADED (they loaded with the award; the parent
--     was confirmed in the base table, so this is accounting, not fabrication).
--   * award FAILED -> children FAILED, carrying the real parent Fusion error in
--     the prescribed linked-record form (a child could not load without its
--     award).
-- Never fabricate a child base id. This mirrors the Worker person-component
-- cascade (DMT_WORKER_RESULTS_PKG lines 178-309).
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
-- Outcomes are echoed back to all 15 STG tables (unchanged).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_GRANTS_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Grants';

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
            C_PKG, C_PROC);

        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Failed to find Report child ESS: ' || SQLERRM,
                C_PKG, C_PROC);
            RETURN NULL;
    END find_report_ess_id;

    -- --------------------------------------------------------
    -- apply_award_import_report
    -- Read the Award Batch Import Report XML and mark each rejected
    -- award FAILED with its REAL Fusion message.
    --
    -- The report's per-award failure rows live in LIST_G_4/G_4:
    --   PARENT_AWARD_NUMBER -> the award number (TFM key)
    --   PROCESSED_MESSAGE   -> the real Fusion rejection message
    -- This is a FAILURE-ONLY list (the report runs with
    -- REPORT_SUCCESS_RECORDS=N), so every G_4 row is a real rejection.
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
    BEGIN
        IF p_import_ess_id IS NULL THEN
            RETURN 0;
        END IF;

        l_report_ess_id := find_report_ess_id(p_run_id, p_import_ess_id);
        IF l_report_ess_id IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': No Award Batch Import Report child found for import ESS ' ||
                p_import_ess_id || '. Nothing to attribute from the report.',
                C_PKG, C_PROC);
            RETURN 0;
        END IF;

        BEGIN
            l_xml_clob := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(l_report_ess_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': Failed to download report XML from ESS ' ||
                    l_report_ess_id || ': ' || SQLERRM,
                    C_PKG, C_PROC);
                RETURN 0;
        END;

        IF l_xml_clob IS NULL OR DBMS_LOB.GETLENGTH(l_xml_clob) = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': Report ESS ' || l_report_ess_id || ' returned empty output.',
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
                    C_PKG, C_PROC);
                IF DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
                    DBMS_LOB.FREETEMPORARY(l_xml_clob);
                END IF;
                RETURN 0;
        END;

        -- Attribute each rejected award to its TFM row with the real message.
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
            UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[FUSION_ERROR] ' || r.processed_message),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND AWARD_NUMBER = r.award_number
            AND    TFM_STATUS NOT IN ('LOADED','FAILED');
            l_matched := l_matched + SQL%ROWCOUNT;
        END LOOP;

        IF DBMS_LOB.ISTEMPORARY(l_xml_clob) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml_clob);
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': Award Batch Import Report (ESS ' || l_report_ess_id ||
            ') parsed; ' || l_matched || ' award(s) marked FAILED with a real Fusion message.',
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
                C_PKG, C_PROC);
            RETURN l_matched;
    END apply_award_import_report;

    -- --------------------------------------------------------
    -- cascade_children_and_echo (private)
    -- Account the 14 award children by the parent award's verdict (keyed by
    -- AWARD_NUMBER) and echo all 15 outcomes back to STG. Behaviour preserved
    -- verbatim from the prior reader:
    --   * award LOADED -> child LOADED
    --   * award FAILED -> child FAILED, carrying the real parent Fusion error.
    -- Never fabricates a child base id. Straight set-based UPDATEs; the award
    -- header TFM row's terminal status is the compile-time-known driver.
    -- --------------------------------------------------------
    PROCEDURE cascade_children_and_echo (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'cascade_children_and_echo';
    BEGIN
        -- Cascade LOADED to all 14 child TFM tables via AWARD_NUMBER
        UPDATE DMT_GMS_AWD_FUNDING_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_PROJECTS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_PERSONNEL_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_FUND_SRC_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_KEYWORDS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_BDGT_PRDS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_CERTS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_CFDAS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_FUND_ALLOC_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_ORG_CREDITS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_REFERENCES_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        UPDATE DMT_GMS_AWD_TERMS_TFM_TBL c
        SET c.TFM_STATUS='LOADED', c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE
        WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='LOADED'
        AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='LOADED');

        -- Cascade FAILED to all 14 child TFM tables. The parent award header
        -- only reaches FAILED with a real Fusion error, so each child carries
        -- that same real parent error in the prescribed linked-record form.
        UPDATE DMT_GMS_AWD_FUNDING_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_PROJECTS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_PERSONNEL_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_FUND_SRC_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_KEYWORDS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_BDGT_PRDS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_CERTS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_CFDAS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_FUND_ALLOC_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_ORG_CREDITS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_REFERENCES_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');
        UPDATE DMT_GMS_AWD_TERMS_TFM_TBL c SET c.TFM_STATUS='FAILED', c.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,'[FUSION_ERROR]The parent record has the following Fusion error: '||(SELECT h2.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL h2 WHERE h2.RUN_ID=p_run_id AND h2.AWARD_NUMBER=c.AWARD_NUMBER AND h2.TFM_STATUS='FAILED' AND ROWNUM=1)), c.RESULTS_UPDATED_DATE=SYSDATE, c.LAST_UPDATED_DATE=SYSDATE WHERE c.RUN_ID=p_run_id AND c.TFM_STATUS!='FAILED' AND EXISTS (SELECT 1 FROM DMT_GMS_AWD_HEADERS_TFM_TBL h WHERE h.RUN_ID=p_run_id AND h.AWARD_NUMBER=c.AWARD_NUMBER AND h.TFM_STATUS='FAILED');

        -- Echo outcomes back to all 15 STG tables
        -- Headers
        UPDATE DMT_GMS_AWD_HEADERS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_HEADERS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_HEADERS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_HEADERS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_HEADERS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Funding
        UPDATE DMT_GMS_AWD_FUNDING_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_FUNDING_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_FUNDING_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_FUNDING_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_FUNDING_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Projects
        UPDATE DMT_GMS_AWD_PROJECTS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PROJECTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_PROJECTS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_PROJECTS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PROJECTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Personnel
        UPDATE DMT_GMS_AWD_PERSONNEL_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PERSONNEL_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_PERSONNEL_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_PERSONNEL_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PERSONNEL_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Fund Sources
        UPDATE DMT_GMS_AWD_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_FUND_SRC_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Prj Fund Sources
        UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Keywords
        UPDATE DMT_GMS_AWD_KEYWORDS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_KEYWORDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_KEYWORDS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_KEYWORDS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_KEYWORDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Budget Periods
        UPDATE DMT_GMS_AWD_BDGT_PRDS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_BDGT_PRDS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_BDGT_PRDS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Certs
        UPDATE DMT_GMS_AWD_CERTS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_CERTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_CERTS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_CERTS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_CERTS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- CFDAs
        UPDATE DMT_GMS_AWD_CFDAS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_CFDAS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_CFDAS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_CFDAS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_CFDAS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Fund Allocations
        UPDATE DMT_GMS_AWD_FUND_ALLOC_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_FUND_ALLOC_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_FUND_ALLOC_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Org Credits
        UPDATE DMT_GMS_AWD_ORG_CREDITS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_ORG_CREDITS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_ORG_CREDITS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Prj Task Burden
        UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- References
        UPDATE DMT_GMS_AWD_REFERENCES_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_REFERENCES_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_REFERENCES_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_REFERENCES_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_REFERENCES_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- Terms
        UPDATE DMT_GMS_AWD_TERMS_STG_TBL stg SET stg.STG_STATUS='LOADED', stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_TERMS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='LOADED');
        UPDATE DMT_GMS_AWD_TERMS_STG_TBL stg SET stg.STG_STATUS='FAILED', stg.ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,(SELECT t.ERROR_TEXT FROM DMT_GMS_AWD_TERMS_TFM_TBL t WHERE t.STG_SEQUENCE_ID=stg.STG_SEQUENCE_ID AND t.RUN_ID=p_run_id)), stg.LAST_UPDATED_DATE=SYSDATE WHERE stg.STG_SEQUENCE_ID IN (SELECT t.STG_SEQUENCE_ID FROM DMT_GMS_AWD_TERMS_TFM_TBL t WHERE t.RUN_ID=p_run_id AND t.TFM_STATUS='FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. 14 children accounted by parent-award verdict; 15 STG tables echoed.',
            C_PKG, C_PROC);
    END cascade_children_and_echo;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_GRANTS (private)
    -- The Contract v1 apply for the Grants award-header tier, Option A shape
    -- (owner decision on PR #248). The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS
    -- runs the nine-column Grants recon report over BIP and returns the parsed
    -- rows (no dynamic SQL, no TFM reference there); the APPLY here is STATIC SQL
    -- against the compile-time-known award header TFM table, joined on
    -- RECON_KEY = report RECORD_KEY. This is the header verdict; the 14 children
    -- and the 15 STG tables are then settled by cascade_children_and_echo. The
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
                -- The Grants report emits a single tier: OBJECT_TYPE = 'Grants'
                -- (the award header). Guard on it so no other tier could ever be
                -- misapplied to the header table.
                IF l_rows(i).OBJECT_TYPE = 'Grants' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Positive proof: award found in GMS_AWARD_HEADERS_B with a
                        -- real id. The ONLY path to LOADED. Static UPDATE on RECON_KEY.
                        UPDATE DMT_GMS_AWD_HEADERS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_AWARD_ID      = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;

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
        l_rpt_failed := apply_award_import_report(p_run_id, p_import_ess_id);
        l_failed := l_failed + l_rpt_failed;

        -- Settle the 14 children by the parent award's verdict and echo to STG.
        cascade_children_and_echo(p_run_id);

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | award headers LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || ' (of which ' || l_rpt_failed || ' from the Award Batch Import Report)'
                           || ' | 14 children accounted by parent verdict.',
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
            C_PKG, C_PROC);

        APPLY_CONTRACT_V1_GRANTS(p_run_id, TO_CHAR(p_load_ess_id), p_import_ess_id);

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete.', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_GRANTS_RESULTS_PKG;
/
