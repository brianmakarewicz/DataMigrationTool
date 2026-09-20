-- PACKAGE BODY DMT_REQ_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REQ_RESULTS_PKG" AS
-- ============================================================
-- DMT_REQ_RESULTS_PKG body — BIP reconciliation report contract v1.
--
-- READER-CODE PILOT: this body is a verbatim copy of the reference
-- reconciler DMT_GL_RESULTS_PKG, changed only by the four documented
-- object-specific swaps:
--   1. C_CEMLI                 : 'Requisitions'
--   2. TFM table               : DMT_POR_REQ_HEADERS_TFM_TBL
--   3. FUSION_ID target column : FUSION_REQUISITION_HEADER_ID
--   4. generated-row count tbl : DMT_POR_REQ_HEADERS_TFM_TBL
-- Plus GET_PARTITION_KEYS is retained (Requisitions dispatches
-- spawn-per-partition through it). Everything else — the keyset fetch,
-- the two set-based MERGEs, the round-trip proof, the orchestration —
-- is the reference logic unchanged.
--
-- The two-tier semantics are object-agnostic (FUSION_STATUS is
-- normalized in the DM to SUCCESS/ERROR):
--   BASE  + SUCCESS => LOADED  (capturing the Fusion id)
--   any   + ERROR   => FAILED  (capturing the real Fusion error)
-- Rows with no match and no error STAY GENERATED (unaccounted) — the
-- shared unaccounted sweep, never this reconciler, marks them.
--
-- >>> KNOWN BLOCKER (reader-code pilot finding, 2026-09-20): the
-- header transform (DMT_REQ_TRANSFORM_PKG) does NOT stamp RECON_KEY on
-- DMT_POR_REQ_HEADERS_TFM_TBL, so the MERGE join t.RECON_KEY =
-- r.record_key matches ZERO rows and this reconciler will leave every
-- row GENERATED until the transform is fixed (or the object adopts a
-- tier-aware join). See the package .pks header and the PR body. The
-- code below is the honest verbatim template copy; it is NOT faked to
-- match a different column. <<<
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_REQ_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Requisitions';

    -- Absolute safety cap on the page loop, above any real conversion
    -- volume. The live cap is derived per-run from the generated-row
    -- count (see FETCH_ALL_PAGES); this constant is the last-resort
    -- ceiling for a run whose generated count could not be read.
    C_MAX_PAGES CONSTANT PLS_INTEGER := 100000;

    -- --------------------------------------------------------
    -- GET_PARTITION_KEYS — distinct BATCH_ID tokens for one run, STATIC SQL
    -- over the requisition-headers transform table (this object's own table).
    -- Spawn-per-partition (work-queue-ID core): one child work item per batch.
    -- Called through invoke_registered (style KEYS). Retained from the prior
    -- Requisitions reconciler; not part of the reference template.
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL IS
        l_keys DMT_PARTITION_KEY_TBL;
    BEGIN
        SELECT DISTINCT JSON_OBJECT('BATCH_ID' VALUE TO_CHAR(BATCH_ID))
        BULK COLLECT INTO l_keys
        FROM   DMT_POR_REQ_HEADERS_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'STAGED'
        AND    BATCH_ID IS NOT NULL;
        RETURN l_keys;
    END GET_PARTITION_KEYS;

    -- --------------------------------------------------------
    -- FETCH_ALL_PAGES (private)
    -- Keyset-pages the deployed nine-column recon report: empty
    -- P_AFTER_KEY on the first call, then the last RECORD_KEY received
    -- on each next call, until a page returns fewer than P_CHUNK_SIZE
    -- rows. Each page is decoded with XMLTABLE over the nine standard
    -- columns. HTTP/SOAP failures are surfaced through x_error_code
    -- (detail logged by RUN_BIP_REPORT).
    -- --------------------------------------------------------
    PROCEDURE FETCH_ALL_PAGES (
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER,
        p_import_ess_id IN  NUMBER,
        x_rows          OUT DMT_RECON_ROW_TBL,
        x_error_code    OUT NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'FETCH_ALL_PAGES';
        l_prefix    VARCHAR2(20);
        l_chunk     PLS_INTEGER;
        l_after_key VARCHAR2(1000) := NULL;   -- empty cursor on first call
        l_page      PLS_INTEGER := 0;
        l_page_cap  PLS_INTEGER;
        l_gen_cnt   PLS_INTEGER;
        l_page_cnt  PLS_INTEGER;
        l_xml       XMLTYPE;
        l_err       NUMBER;
        l_page_rows DMT_RECON_ROW_TBL;
    BEGIN
        x_rows       := DMT_RECON_ROW_TBL();
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        l_chunk := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));
        IF l_chunk IS NULL OR l_chunk <= 0 THEN
            l_chunk := 5000;
        END IF;

        SELECT PREFIX INTO l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        -- Page-count cap from the run's generated-row count: at most one
        -- page per generated row plus a small margin, capped at C_MAX_PAGES.
        BEGIN
            SELECT COUNT(*) INTO l_gen_cnt
            FROM   DMT_POR_REQ_HEADERS_TFM_TBL
            WHERE  RUN_ID = p_run_id;
        EXCEPTION WHEN OTHERS THEN l_gen_cnt := 0;
        END;
        l_page_cap := CEIL(GREATEST(l_gen_cnt, 1) / l_chunk) + 2;
        IF l_page_cap > C_MAX_PAGES THEN
            l_page_cap := C_MAX_PAGES;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || C_CEMLI ||
            ' | P_RUN_ID: ' || p_run_id ||
            ' | P_LOAD_REQUEST_ID: ' || p_load_ess_id ||
            ' | chunk size: ' || l_chunk ||
            ' | page cap: ' || l_page_cap || ' (gen rows: ' || l_gen_cnt || ')',
            'INFO', C_PKG, C_PROC);

        LOOP
            l_page := l_page + 1;
            EXIT WHEN l_page > l_page_cap;

            -- Keyset cursor: P_AFTER_KEY empty on the first page, then the
            -- last RECORD_KEY of the previous page. P_CHUNK_SIZE bounds the
            -- page. No P_OFFSET / P_LIMIT (retired by Contract v1).
            DMT_UTIL_PKG.RUN_BIP_REPORT(
                p_run_id     => p_run_id,
                p_cemli_code => C_CEMLI,
                p_params     => 'P_RUN_ID|'           || TO_CHAR(p_run_id) ||
                                '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                                '~P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                                '~P_PREFIX|'          || l_prefix ||
                                '~P_CHUNK_SIZE|'      || TO_CHAR(l_chunk) ||
                                '~P_AFTER_KEY|'       || l_after_key,
                x_report_xml => l_xml,
                x_error_code => l_err);

            IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ' failed on page ' || l_page ||
                    ' (after_key ''' || NVL(l_after_key, '<empty>') ||
                    '''); detail logged by RUN_BIP_REPORT.',
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
                           x.object_type, x.record_key, UPPER(x.source_type),
                           UPPER(x.fusion_status), x.fusion_id, x.error_message,
                           x.load_request_id, x.source_ref, x.dmt_reference)
                  BULK COLLECT INTO l_page_rows
                  FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                        COLUMNS
                            object_type     VARCHAR2(60)   PATH 'OBJECT_TYPE',
                            record_key      VARCHAR2(1000) PATH 'RECORD_KEY',
                            source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                            fusion_status   VARCHAR2(20)   PATH 'FUSION_STATUS',
                            fusion_id       NUMBER         PATH 'FUSION_ID',
                            error_message   VARCHAR2(4000) PATH 'ERROR_MESSAGE',
                            load_request_id NUMBER         PATH 'LOAD_REQUEST_ID',
                            source_ref      VARCHAR2(240)  PATH 'SOURCE_REF',
                            dmt_reference   VARCHAR2(240)  PATH 'DMT_REFERENCE'
                       ) x;
            END IF;

            l_page_cnt := l_page_rows.COUNT;

            -- Accumulate this page into the run-wide collection and
            -- advance the keyset cursor to this page's last RECORD_KEY
            -- (the report ORDERs BY RECORD_KEY, so the last row carries
            -- the greatest key).
            FOR i IN 1 .. l_page_cnt LOOP
                x_rows.EXTEND;
                x_rows(x_rows.COUNT) := l_page_rows(i);
            END LOOP;
            IF l_page_cnt > 0 THEN
                l_after_key := l_page_rows(l_page_cnt).record_key;
            END IF;

            EXIT WHEN l_page_cnt < l_chunk;   -- short page = last page
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
    -- Single-page XML fetch (empty cursor, one chunk) via the shared
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
        l_chunk  PLS_INTEGER;
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;

        l_chunk := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));

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
                            '~P_CHUNK_SIZE|'      || TO_CHAR(l_chunk) ||
                            '~P_AFTER_KEY|',       -- empty cursor: first page
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
    -- Set-based round-trip proof: one query counts BASE/SUCCESS rows
    -- whose returned DMT_REFERENCE does NOT equal BUILD_REF for the
    -- matched TFM row, and logs a single summary. Diagnostic only — it
    -- WARNs on any mismatch and NEVER alters the LOADED verdict.
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
          JOIN DMT_POR_REQ_HEADERS_TFM_TBL t
            ON t.RUN_ID = p_run_id
           AND t.RECON_KEY = r.record_key
         WHERE r.source_type   = 'BASE'
           AND r.fusion_status = 'SUCCESS';

        IF l_mismatch = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip OK (set-based): ' || l_ok || ' of ' ||
                l_checked || ' LOADED base rows carry the expected DMT_REFERENCE.',
                'INFO', C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip MISMATCH (set-based): ' || l_mismatch ||
                ' of ' || l_checked || ' LOADED base rows do NOT carry the ' ||
                'expected DMT_REFERENCE. LOADED verdict UNCHANGED (diagnostic only).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Round-trip proof must never break the reconcile.
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip proof skipped (non-fatal): ' || SQLERRM,
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
        -- BASE/SUCCESS row with a real FUSION_ID. Capture FUSION_ID in
        -- the same statement (contract: no LOADED without its Fusion id).
        MERGE INTO DMT_POR_REQ_HEADERS_TFM_TBL t
        USING (
            SELECT r.record_key,
                   MAX(r.fusion_id) AS fusion_id
            FROM   TABLE(p_rows) r
            WHERE  r.source_type   = 'BASE'
            AND    r.fusion_status = 'SUCCESS'
            AND    r.fusion_id     IS NOT NULL
            GROUP BY r.record_key
        ) s
        ON (t.RUN_ID = p_run_id AND t.RECON_KEY = s.record_key)
        WHEN MATCHED THEN UPDATE
            SET t.TFM_STATUS                   = 'LOADED',
                t.FUSION_REQUISITION_HEADER_ID = s.fusion_id,
                t.RESULTS_UPDATED_DATE         = SYSDATE,
                t.LAST_UPDATED_DATE            = SYSDATE
            WHERE t.TFM_STATUS NOT IN ('LOADED','FAILED');
        l_loaded := SQL%ROWCOUNT;

        -- (2) SET-BASED FAILED: any row whose FUSION_STATUS is ERROR,
        -- carrying a real Fusion error message. Append the error, tagged
        -- [FUSION_ERROR]; never overwrite. The LOADED statement already ran
        -- and both guard TFM_STATUS NOT IN (LOADED,FAILED), so FAILED cannot
        -- clobber a LOADED row.
        MERGE INTO DMT_POR_REQ_HEADERS_TFM_TBL t
        USING (
            SELECT r.record_key,
                   MIN(r.error_message) AS error_message
            FROM   TABLE(p_rows) r
            WHERE  r.fusion_status = 'ERROR'
            AND    r.error_message IS NOT NULL
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
    -- The live path uses FETCH_ALL_PAGES; this XML overload is kept for
    -- independent reprocessing/testing of a single decoded page.
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
                   x.object_type, x.record_key, UPPER(x.source_type),
                   UPPER(x.fusion_status), x.fusion_id, x.error_message,
                   x.load_request_id, x.source_ref, x.dmt_reference)
          BULK COLLECT INTO l_rows
          FROM XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    object_type     VARCHAR2(60)   PATH 'OBJECT_TYPE',
                    record_key      VARCHAR2(1000) PATH 'RECORD_KEY',
                    source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_status   VARCHAR2(20)   PATH 'FUSION_STATUS',
                    fusion_id       NUMBER         PATH 'FUSION_ID',
                    error_message   VARCHAR2(4000) PATH 'ERROR_MESSAGE',
                    load_request_id NUMBER         PATH 'LOAD_REQUEST_ID',
                    source_ref      VARCHAR2(240)  PATH 'SOURCE_REF',
                    dmt_reference   VARCHAR2(240)  PATH 'DMT_REFERENCE'
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
    -- keyset-page the nine-column report into one collection, apply it
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
            -- Zero report rows is never success (Contract v1). The
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

END DMT_REQ_RESULTS_PKG;
/
