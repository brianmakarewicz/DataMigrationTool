-- PACKAGE BODY DMT_GL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_RESULTS_PKG" AS
-- ============================================================
-- DMT_GL_RESULTS_PKG body — BIP reconciliation report contract v1,
-- reference implementation. This is the copy-template for every
-- other conforming reconciler, so the shape below is deliberate:
--
--   1. FETCH (keyset): page the nine-column recon report by passing
--      an empty P_AFTER_KEY first, then the last RECORD_KEY received
--      on each next call, at most P_CHUNK_SIZE rows per page, until a
--      page returns fewer than P_CHUNK_SIZE rows. Accumulate every
--      page's rows into ONE collection (DMT_RECON_ROW_TBL). Memory is
--      bounded to one page during the fetch; the collection holds the
--      fixed, finished reconciliation population. A page-count cap
--      derived from the run's generated-row count stops a misbehaving
--      report from looping forever.
--   2. APPLY (set-based): a SINGLE MERGE marks LOADED (capturing
--      FUSION_ID) for BASE/SUCCESS matches, and a SINGLE MERGE marks
--      FAILED (capturing the real Fusion error) for ERROR rows. No
--      per-row PL/SQL loop does the marking — each statement joins
--      TABLE(l_rows) to the TFM table on the recon key.
--   3. ROUND-TRIP PROOF: one set-based diagnostic pass logs a single
--      WARN summary if any just-LOADED base row's DMT_REFERENCE does
--      not equal BUILD_REF for its TFM row. It never changes a verdict.
--
-- GL two-tier semantics preserved (FUSION_STATUS is normalized in the
-- DM to SUCCESS/ERROR, so the reconciler is object-agnostic here):
--   BASE  + SUCCESS (balanced/postable)          => LOADED
--   BASE  + ERROR   (unbalanced, will not post)  => FAILED
--   INTERFACE + ERROR (Journal-Import rejection) => FAILED
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

    -- Absolute safety cap on the page loop, above any real conversion
    -- volume. The live cap is derived per-run from the generated-row
    -- count (see FETCH_ALL_PAGES); this constant is the last-resort
    -- ceiling for a run whose generated count could not be read.
    C_MAX_PAGES CONSTANT PLS_INTEGER := 100000;

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
            FROM   DMT_GL_INTERFACE_TFM_TBL
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
                            fusion_id       VARCHAR2(200)  PATH 'FUSION_ID',
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
        -- FUSION_ID is now the per-line composite JE_HEADER_ID~JE_LINE_NUM,
        -- so two lines of one journal carry DIFFERENT ids (positive proof at
        -- line grain). RECON_KEY is unique per TFM line, so GROUP BY collapses
        -- to one row per key and MAX(fusion_id) simply returns that line's
        -- composite value.
        MERGE INTO DMT_GL_INTERFACE_TFM_TBL t
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
            SET t.TFM_STATUS           = 'LOADED',
                t.FUSION_JE_HEADER_ID  = s.fusion_id,
                t.RESULTS_UPDATED_DATE = SYSDATE,
                t.LAST_UPDATED_DATE    = SYSDATE
            WHERE t.TFM_STATUS NOT IN ('LOADED','FAILED');
        l_loaded := SQL%ROWCOUNT;

        -- (2) SET-BASED FAILED: any row (BASE unbalanced, or INTERFACE
        -- rejection) whose FUSION_STATUS is ERROR, carrying a real Fusion
        -- error message. Append the error, tagged [FUSION_ERROR]; never
        -- overwrite. A row that both errored and loaded cannot exist (an
        -- ERROR row has a non-null message and a non-SUCCESS status; a
        -- SUCCESS row does not), and the LOADED statement already ran, so
        -- FAILED cannot clobber a LOADED row.
        MERGE INTO DMT_GL_INTERFACE_TFM_TBL t
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
                    fusion_id       VARCHAR2(200)  PATH 'FUSION_ID',
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

    -- --------------------------------------------------------
    -- APPLY_GL — GLBalances' thin STATIC apply for the generic recon engine.
    -- The engine (DMT_RECON_ENGINE_PKG) has already staged the parsed
    -- nine-column report into DMT_RECON_STAGE_GTT for this RUN_ID. This proc
    -- reads that GTT and marks the TFM table set-based with STATIC SQL against
    -- the literally-named DMT_GL_INTERFACE_TFM_TBL. It is the SAME two MERGEs
    -- as APPLY_RESULTS above, sourced from the GTT (a static table) instead of
    -- a TABLE(:collection) — proving the engine is a drop-in for the reference
    -- reconciler with the object owning only its static apply.
    -- --------------------------------------------------------
    PROCEDURE APPLY_GL (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'APPLY_GL';
        l_loaded   NUMBER := 0;
        l_failed   NUMBER := 0;
        l_checked  NUMBER := 0;
        l_ok       NUMBER := 0;
        l_mismatch NUMBER := 0;
    BEGIN
        -- (1) SET-BASED LOADED: a TFM row is LOADED only from a BASE/SUCCESS
        -- staged row with a real FUSION_ID; FUSION_JE_HEADER_ID captured in the
        -- same statement (contract: no LOADED without its Fusion id).
        -- FUSION_ID is the per-line composite JE_HEADER_ID~JE_LINE_NUM, so two
        -- lines of one journal carry DIFFERENT ids (line-grain proof of load).
        -- RECON_KEY is unique per TFM line, so GROUP BY yields one row per key
        -- and MAX(fusion_id) just returns that line's composite. Scoped to
        -- RUN_ID, plus WORK_QUEUE_ID when a spawn-per-partition child owns it.
        MERGE INTO DMT_GL_INTERFACE_TFM_TBL t
        USING (
            SELECT g.record_key,
                   MAX(g.fusion_id) AS fusion_id
            FROM   DMT_RECON_STAGE_GTT g
            WHERE  g.run_id        = p_run_id
            AND    g.source_type   = 'BASE'
            AND    g.fusion_status = 'SUCCESS'
            AND    g.fusion_id     IS NOT NULL
            GROUP BY g.record_key
        ) s
        ON (    t.RUN_ID    = p_run_id
            AND t.RECON_KEY = s.record_key
            AND (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID = p_work_queue_id))
        WHEN MATCHED THEN UPDATE
            SET t.TFM_STATUS           = 'LOADED',
                t.FUSION_JE_HEADER_ID  = s.fusion_id,
                t.RESULTS_UPDATED_DATE = SYSDATE,
                t.LAST_UPDATED_DATE    = SYSDATE
            WHERE t.TFM_STATUS NOT IN ('LOADED','FAILED');
        l_loaded := SQL%ROWCOUNT;

        -- (2) SET-BASED FAILED: any staged ERROR row carrying a real Fusion
        -- error message. Append the error, tagged [FUSION_ERROR]; never
        -- overwrite. The LOADED statement already ran and both guard TFM_STATUS
        -- NOT IN (LOADED,FAILED), so FAILED cannot clobber a LOADED row.
        MERGE INTO DMT_GL_INTERFACE_TFM_TBL t
        USING (
            SELECT g.record_key,
                   MIN(g.error_message) AS error_message
            FROM   DMT_RECON_STAGE_GTT g
            WHERE  g.run_id        = p_run_id
            AND    g.fusion_status = 'ERROR'
            AND    g.error_message IS NOT NULL
            GROUP BY g.record_key
        ) s
        ON (    t.RUN_ID    = p_run_id
            AND t.RECON_KEY = s.record_key
            AND (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID = p_work_queue_id))
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
            C_PROC || ' complete (set-based, from GTT). LOADED: ' || l_loaded ||
            ', FAILED: ' || l_failed ||
            '. Unmatched/no-error rows left GENERATED (unaccounted).',
            'INFO', C_PKG, C_PROC);

        -- (3) ROUND-TRIP PROOF (strong, TFM-joined): every just-LOADED base
        -- row's returned DMT_REFERENCE must equal BUILD_REF for its TFM row.
        -- Static SQL joining the GTT to the literally-named TFM table.
        -- Diagnostic only — WARNs on mismatch, NEVER alters a verdict.
        BEGIN
            SELECT
                COUNT(*),
                COUNT(CASE WHEN g.dmt_reference =
                           DMT_REF_ID_PKG.BUILD_REF(t.RUN_ID, t.WORK_QUEUE_ID, t.TFM_SEQUENCE_ID)
                           THEN 1 END),
                COUNT(CASE WHEN g.dmt_reference IS NULL
                            OR g.dmt_reference <>
                           DMT_REF_ID_PKG.BUILD_REF(t.RUN_ID, t.WORK_QUEUE_ID, t.TFM_SEQUENCE_ID)
                           THEN 1 END)
              INTO l_checked, l_ok, l_mismatch
              FROM DMT_RECON_STAGE_GTT g
              JOIN DMT_GL_INTERFACE_TFM_TBL t
                ON t.RUN_ID    = p_run_id
               AND t.RECON_KEY = g.record_key
             WHERE g.run_id        = p_run_id
               AND g.source_type   = 'BASE'
               AND g.fusion_status = 'SUCCESS';

            IF l_mismatch = 0 THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'REF round-trip OK (APPLY_GL): ' || l_ok || ' of ' || l_checked ||
                    ' LOADED base rows carry the expected DMT_REFERENCE.',
                    'INFO', C_PKG, C_PROC);
            ELSE
                DMT_UTIL_PKG.LOG(p_run_id,
                    'REF round-trip MISMATCH (APPLY_GL): ' || l_mismatch || ' of ' ||
                    l_checked || ' LOADED base rows do NOT carry the expected ' ||
                    'DMT_REFERENCE. LOADED verdict UNCHANGED (diagnostic only).',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    'REF round-trip proof skipped (non-fatal): ' || SQLERRM,
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed.', SQLERRM, C_PKG, C_PROC);
            RAISE;
    END APPLY_GL;

END DMT_GL_RESULTS_PKG;
/
