-- PACKAGE BODY DMT_GL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_RESULTS_PKG" AS
-- ============================================================
-- DMT_GL_RESULTS_PKG body — BIP Reconciliation Standard, reference
-- implementation (P1). This is the copy-template for every other
-- reconciler, so the shape below is deliberate:
--
--   1. FETCH: page the six-column recon report with P_OFFSET/P_LIMIT
--      until a short page returns, accumulating each page's rows into
--      ONE collection (DMT_RECON_ROW_TBL). Memory is bounded to one
--      page during the fetch; the collection holds the fixed, finished
--      reconciliation population.
--   2. APPLY (set-based): a SINGLE UPDATE marks LOADED (capturing
--      FUSION_ID) for BASE matches with no error, and a SINGLE UPDATE
--      marks FAILED (capturing the real Fusion error) for rows that
--      carry an ERROR_MESSAGE. No per-row PL/SQL loop does the marking
--      — each statement joins TABLE(l_rows) to the TFM table on the
--      recon key.
--   3. ROUND-TRIP PROOF: one set-based diagnostic pass logs a single
--      WARN summary if any just-LOADED base row's DMT_REFERENCE does
--      not equal BUILD_REF for its TFM row. It never changes a verdict.
--
-- GL two-tier semantics preserved (no IMPORT_STATUS column needed):
--   BASE  + ERROR_MESSAGE IS NULL  => balanced/postable => LOADED
--   BASE  + ERROR_MESSAGE NOT NULL => unbalanced, will not post => FAILED
--   INTERFACE + ERROR_MESSAGE NOT NULL => Fusion rejection => FAILED
--   INTERFACE with no error is corroborating only, never LOADED on its
--   own (LOADED requires a BASE/FUSION_ID row).
-- Rows with no match and no error STAY GENERATED (unaccounted) — the
-- shared unaccounted sweep, never this reconciler, marks them.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
-- UTL_HTTP copy). Outcomes are written to the TFM table only; nothing
-- is written back to staging.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_GL_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'GLBalances';

    -- Safety cap on the page loop so a misbehaving report can never
    -- loop forever. GL runs are tiny; 10,000 pages at the default
    -- chunk size is far past any real conversion volume.
    C_MAX_PAGES CONSTANT PLS_INTEGER := 10000;

    -- --------------------------------------------------------
    -- FETCH_ALL_PAGES (private)
    -- Pages the deployed six-column recon report with P_OFFSET/P_LIMIT
    -- until a page returns fewer rows than the page size, accumulating
    -- every row into x_rows (DMT_RECON_ROW_TBL). Each page is decoded
    -- with XMLTABLE over the six standard columns. HTTP/SOAP failures
    -- are surfaced through x_error_code (detail logged by RUN_BIP_REPORT).
    -- --------------------------------------------------------
    PROCEDURE FETCH_ALL_PAGES (
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER,
        p_import_ess_id IN  NUMBER,
        x_rows          OUT DMT_RECON_ROW_TBL,
        x_error_code    OUT NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'FETCH_ALL_PAGES';
        l_prefix   VARCHAR2(20);
        l_limit    PLS_INTEGER;
        l_offset   PLS_INTEGER := 0;
        l_page     PLS_INTEGER := 0;
        l_page_cnt PLS_INTEGER;
        l_xml      XMLTYPE;
        l_err      NUMBER;
        l_page_rows DMT_RECON_ROW_TBL;
    BEGIN
        x_rows       := DMT_RECON_ROW_TBL();
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        l_limit := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));
        IF l_limit IS NULL OR l_limit <= 0 THEN
            l_limit := 5000;
        END IF;

        SELECT PREFIX INTO l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI ||
            ' | P_RUN_ID: ' || p_run_id ||
            ' | P_LOAD_REQUEST_ID: ' || p_load_ess_id ||
            ' | page size: ' || l_limit,
            'INFO', C_PKG, C_PROC);

        LOOP
            l_page := l_page + 1;
            EXIT WHEN l_page > C_MAX_PAGES;

            DMT_UTIL_PKG.RUN_BIP_REPORT(
                p_run_id     => p_run_id,
                p_cemli_code => C_CEMLI,
                p_params     => 'P_RUN_ID|'           || TO_CHAR(p_run_id) ||
                                '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                                '~P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                                '~P_PREFIX|'          || l_prefix ||
                                '~P_OFFSET|'          || TO_CHAR(l_offset) ||
                                '~P_LIMIT|'           || TO_CHAR(l_limit),
                x_report_xml => l_xml,
                x_error_code => l_err);

            IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ' failed on page ' || l_page ||
                    ' (offset ' || l_offset || '); detail logged by RUN_BIP_REPORT.',
                    DMT_UTIL_PKG.C_LOG_ERROR, C_PKG, C_PROC);
                RETURN;   -- x_error_code stays C_ERROR
            END IF;

            -- A short/empty page ends the loop. RUN_BIP_REPORT returns
            -- either NULL (no reportBytes) or a DATA_DS with zero G_1
            -- rows on an empty page; both decode to zero rows here.
            IF l_xml IS NULL THEN
                l_page_rows := DMT_RECON_ROW_TBL();
            ELSE
                SELECT DMT_RECON_ROW_OBJ(
                           x.record_key, x.fusion_id, x.source_ref,
                           x.dmt_reference, UPPER(x.source_type), x.error_message)
                  BULK COLLECT INTO l_page_rows
                  FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                        COLUMNS
                            record_key    VARCHAR2(1000) PATH 'RECORD_KEY',
                            fusion_id     NUMBER         PATH 'FUSION_ID',
                            source_ref    VARCHAR2(240)  PATH 'SOURCE_REF',
                            dmt_reference VARCHAR2(240)  PATH 'DMT_REFERENCE',
                            source_type   VARCHAR2(20)   PATH 'SOURCE_TYPE',
                            error_message VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                       ) x;
            END IF;

            l_page_cnt := l_page_rows.COUNT;

            -- Accumulate this page into the run-wide collection.
            FOR i IN 1 .. l_page_cnt LOOP
                x_rows.EXTEND;
                x_rows(x_rows.COUNT) := l_page_rows(i);
            END LOOP;

            EXIT WHEN l_page_cnt < l_limit;   -- short page = last page
            l_offset := l_offset + l_limit;
        END LOOP;

        x_error_code := DMT_UTIL_PKG.C_SUCCESS;
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Pages fetched: ' || l_page ||
            ' | total report rows: ' || x_rows.COUNT || '.',
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            x_rows       := DMT_RECON_ROW_TBL();
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed. CEMLI: ' || C_CEMLI,
                SQLERRM, C_PKG, C_PROC);
    END FETCH_ALL_PAGES;

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS (public, retained for independent testing)
    -- Single-page XML fetch (offset 0, one chunk) via the shared
    -- transport. Kept so a caller can pull the raw report XML without
    -- the set-based apply. The live reconcile path uses FETCH_ALL_PAGES.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER,
        x_report_xml    OUT XMLTYPE,
        x_error_code    OUT NUMBER,
        p_import_ess_id IN  NUMBER DEFAULT NULL
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_prefix VARCHAR2(20);
        l_limit  PLS_INTEGER;
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;

        l_limit := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));

        SELECT PREFIX INTO l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_RUN_ID|'           || TO_CHAR(p_run_id) ||
                            '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                            '~P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                            '~P_PREFIX|'          || l_prefix ||
                            '~P_OFFSET|0' ||
                            '~P_LIMIT|'           || TO_CHAR(l_limit),
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed. CEMLI: ' || C_CEMLI,
                SQLERRM, C_PKG, C_PROC);
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- CONFIRM_ROUNDTRIP_SET (private)
    -- Set-based #12 round-trip proof: one query counts BASE/LOADED rows
    -- whose returned DMT_REFERENCE does NOT equal BUILD_REF for the
    -- matched TFM row, and logs a single summary. Diagnostic only — it
    -- WARNs on any mismatch and NEVER alters the LOADED verdict (honest:
    -- the load already succeeded; a reference mismatch is a data-quality
    -- signal, not a load failure).
    -- --------------------------------------------------------
    PROCEDURE CONFIRM_ROUNDTRIP_SET (
        p_run_id IN NUMBER,
        p_rows   IN DMT_RECON_ROW_TBL
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'CONFIRM_ROUNDTRIP_SET';
        l_checked    NUMBER := 0;
        l_ok         NUMBER := 0;
        l_mismatch   NUMBER := 0;
    BEGIN
        SELECT
            COUNT(*),
            COUNT(CASE WHEN r.dmt_reference =
                       DMT_REF_ID_PKG.BUILD_REF(t.RUN_ID, t.WORK_QUEUE_ID, t.TFM_SEQUENCE_ID)
                       THEN 1 END),
            COUNT(CASE WHEN r.dmt_reference IS NULL
                        OR r.dmt_reference <>
                       DMT_REF_ID_PKG.BUILD_REF(t.RUN_ID, t.WORK_QUEUE_ID, t.TFM_SEQUENCE_ID)
                       THEN 1 END)
          INTO l_checked, l_ok, l_mismatch
          FROM TABLE(p_rows) r
          JOIN DMT_GL_INTERFACE_TFM_TBL t
            ON t.RUN_ID = p_run_id
           AND t.RECON_KEY = r.record_key
         WHERE r.source_type = 'BASE'
           AND r.error_message IS NULL;

        IF l_mismatch = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip OK (set-based): ' || l_ok || ' of ' ||
                l_checked || ' LOADED base rows carry the expected DMT_REFERENCE.',
                'INFO', C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip MISMATCH (set-based): ' || l_mismatch ||
                ' of ' || l_checked || ' LOADED base rows do NOT carry the ' ||
                'expected DMT_REFERENCE. LOADED verdict UNCHANGED (diagnostic only).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Round-trip proof must never break the reconcile.
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip proof skipped (non-fatal): ' || SQLERRM,
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
    END CONFIRM_ROUNDTRIP_SET;

    -- --------------------------------------------------------
    -- APPLY_RESULTS (private) — the set-based core.
    -- Two single statements do all the marking; no per-row loop.
    -- --------------------------------------------------------
    PROCEDURE APPLY_RESULTS (
        p_run_id IN NUMBER,
        p_rows   IN DMT_RECON_ROW_TBL
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'APPLY_RESULTS';
        l_loaded NUMBER := 0;
        l_failed NUMBER := 0;
    BEGIN
        -- (1) SET-BASED LOADED: a TFM row is LOADED only from a
        -- BASE row with a real FUSION_ID and no error (balanced,
        -- postable). Capture FUSION_ID in the same statement (design
        -- section 7: no LOADED without its Fusion id). If two base
        -- lines map to the same TFM recon key, MAX(fusion_id) is a
        -- stable pick (all lines of one journal share JE_HEADER_ID).
        MERGE INTO DMT_GL_INTERFACE_TFM_TBL t
        USING (
            SELECT r.record_key,
                   MAX(r.fusion_id) AS fusion_id
            FROM   TABLE(p_rows) r
            WHERE  r.source_type   = 'BASE'
            AND    r.error_message IS NULL
            AND    r.fusion_id     IS NOT NULL
            GROUP BY r.record_key
        ) s
        ON (t.RUN_ID = p_run_id AND t.RECON_KEY = s.record_key)
        WHEN MATCHED THEN UPDATE
            SET t.TFM_STATUS           = 'LOADED',
                t.FUSION_JE_HEADER_ID  = s.fusion_id,
                t.RESULTS_UPDATED_DATE = SYSDATE,
                t.LAST_UPDATED_DATE    = SYSDATE
            WHERE t.TFM_STATUS NOT IN ('LOADED','FAILED');
        l_loaded := SQL%ROWCOUNT;

        -- (2) SET-BASED FAILED: any row (BASE unbalanced, or INTERFACE
        -- rejection) that carries a real Fusion error message. Append
        -- the error, tagged [FUSION_ERROR]; never overwrite. A row that
        -- both errored and loaded cannot exist (an error row has a
        -- non-null message; a loaded row does not), and the LOADED
        -- statement already ran, so FAILED cannot clobber a LOADED row.
        MERGE INTO DMT_GL_INTERFACE_TFM_TBL t
        USING (
            SELECT r.record_key,
                   MIN(r.error_message) AS error_message
            FROM   TABLE(p_rows) r
            WHERE  r.error_message IS NOT NULL
            GROUP BY r.record_key
        ) s
        ON (t.RUN_ID = p_run_id AND t.RECON_KEY = s.record_key)
        WHEN MATCHED THEN UPDATE
            SET t.TFM_STATUS           = 'FAILED',
                t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                             t.ERROR_TEXT,
                                             '[FUSION_ERROR] ' || s.error_message),
                t.RESULTS_UPDATED_DATE = SYSDATE,
                t.LAST_UPDATED_DATE    = SYSDATE
            WHERE t.TFM_STATUS NOT IN ('LOADED','FAILED');
        l_failed := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete (set-based). LOADED: ' || l_loaded ||
            ', FAILED: ' || l_failed ||
            '. Unmatched/no-error rows left GENERATED (unaccounted).',
            'INFO', C_PKG, C_PROC);
    END APPLY_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE (public, retained signature) —
    -- decodes an XML report page and delegates to the set-based apply.
    -- The live path uses the collection overload below; this XML
    -- overload is kept for independent reprocessing/testing.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id     IN NUMBER,
        p_report_xml IN XMLTYPE
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_rows DMT_RECON_ROW_TBL;
    BEGIN
        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report XML is NULL (zero rows). GENERATED rows ' ||
                'left unaccounted (not marked FAILED).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        SELECT DMT_RECON_ROW_OBJ(
                   x.record_key, x.fusion_id, x.source_ref,
                   x.dmt_reference, UPPER(x.source_type), x.error_message)
          BULK COLLECT INTO l_rows
          FROM XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_key    VARCHAR2(1000) PATH 'RECORD_KEY',
                    fusion_id     NUMBER         PATH 'FUSION_ID',
                    source_ref    VARCHAR2(240)  PATH 'SOURCE_REF',
                    dmt_reference VARCHAR2(240)  PATH 'DMT_REFERENCE',
                    source_type   VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    error_message VARCHAR2(4000) PATH 'ERROR_MESSAGE'
               ) x;

        APPLY_RESULTS(p_run_id, l_rows);
        CONFIRM_ROUNDTRIP_SET(p_run_id, l_rows);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — orchestrates the standard flow:
    -- page the six-column report into one collection, apply it
    -- set-based, then log the set-based round-trip proof.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_rows DMT_RECON_ROW_TBL;
        l_err  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
            ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            'INFO', C_PKG, C_PROC);

        FETCH_ALL_PAGES(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            x_rows          => l_rows,
            x_error_code    => l_err);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20038,
                'RECONCILE_BATCH: report fetch failed for CEMLI ' ||
                C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows IS NULL OR l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5). The
            -- GENERATED rows stay unaccounted; the accounting gate reports
            -- the object not-DONE.
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero rows. GENERATED rows left ' ||
                'unaccounted (not marked FAILED).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        APPLY_RESULTS(p_run_id, l_rows);
        CONFIRM_ROUNDTRIP_SET(p_run_id, l_rows);

        -- NO COMMIT — the orchestrator controls transaction boundaries.
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_GL_RESULTS_PKG;
/
