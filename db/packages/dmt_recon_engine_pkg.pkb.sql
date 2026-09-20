-- PACKAGE BODY DMT_RECON_ENGINE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_RECON_ENGINE_PKG" AS
-- ============================================================
-- DMT_RECON_ENGINE_PKG body — the ONE generic Contract v1 reconcile engine.
-- See the package spec for the FETCH / PARSE / STAGE / ROUND-TRIP / APPLY split.
--
-- This body contains NO dynamic SQL. Every statement is static:
--   * the report parse is XMLTABLE over the NINE FIXED Contract v1 columns;
--   * the stage is a static INSERT into DMT_RECON_STAGE_GTT (fixed columns);
--   * the round-trip is a static SELECT over the GTT's fixed columns;
--   * the apply is DISPATCHED to the object's own static proc through the
--     existing sanctioned site DMT_QUEUE_WORKER_PKG.INVOKE_APPLY (which calls
--     the private invoke_registered — the ONE dynamic-invocation site).
-- The object's TFM table name never appears in this package, as text or data.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_RECON_ENGINE_PKG';

    -- Absolute safety cap on the page loop, above any real conversion volume.
    C_MAX_PAGES CONSTANT PLS_INTEGER := 100000;

    -- One object's Contract v1 registration (all from DMT_BIP_REPORT_TBL).
    TYPE t_cfg IS RECORD (
        contract_version NUMBER,
        apply_proc       VARCHAR2(200)
    );

    -- --------------------------------------------------------
    -- read_config — read the object's Contract v1 registration from the
    -- registry. Raises if the object is not Contract v1 or has no APPLY_PROC.
    -- No identifier is concatenated into SQL here: APPLY_PROC is a procedure
    -- name handed to invoke_registered (which validates its PKG.PROC pattern),
    -- never a table or column name.
    -- --------------------------------------------------------
    PROCEDURE read_config (p_cemli_code IN VARCHAR2, x_cfg OUT t_cfg) IS
    BEGIN
        BEGIN
            SELECT CONTRACT_VERSION, APPLY_PROC
            INTO   x_cfg.contract_version, x_cfg.apply_proc
            FROM   DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = p_cemli_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20121,
                    'DMT_RECON_ENGINE_PKG.RECONCILE: no DMT_BIP_REPORT_TBL row for CEMLI '
                    || p_cemli_code);
        END;

        IF NVL(x_cfg.contract_version, 0) <> 1 THEN
            RAISE_APPLICATION_ERROR(-20122,
                'DMT_RECON_ENGINE_PKG.RECONCILE: CEMLI ' || p_cemli_code ||
                ' is not CONTRACT_VERSION = 1 (found ' ||
                NVL(TO_CHAR(x_cfg.contract_version), 'NULL') ||
                '); the generic engine only reconciles Contract v1 objects.');
        END IF;

        IF x_cfg.apply_proc IS NULL THEN
            RAISE_APPLICATION_ERROR(-20124,
                'DMT_RECON_ENGINE_PKG.RECONCILE: CEMLI ' || p_cemli_code ||
                ' has no APPLY_PROC in DMT_BIP_REPORT_TBL. Register the object''s ' ||
                'thin static APPLY_<OBJ> before the engine can reconcile it.');
        END IF;
    END read_config;

    -- --------------------------------------------------------
    -- fetch_and_stage — keyset-page the object's deployed nine-column recon
    -- report and STATICALLY INSERT each parsed page into DMT_RECON_STAGE_GTT
    -- keyed by RUN_ID. Empty P_AFTER_KEY on the first call, then the last
    -- RECORD_KEY received, until a page returns fewer than P_CHUNK_SIZE rows.
    -- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT. HTTP/SOAP failures
    -- surface through x_error_code (detail logged by RUN_BIP_REPORT).
    -- x_total_rows returns the number of rows staged.
    -- --------------------------------------------------------
    PROCEDURE fetch_and_stage (
        p_run_id        IN  NUMBER,
        p_cemli_code    IN  VARCHAR2,
        p_load_ess_id   IN  NUMBER,
        p_import_ess_id IN  NUMBER,
        x_total_rows    OUT NUMBER,
        x_error_code    OUT NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'fetch_and_stage';
        l_prefix    VARCHAR2(30);
        l_chunk     PLS_INTEGER;
        l_after_key VARCHAR2(1000) := NULL;   -- empty cursor on first call
        l_page      PLS_INTEGER := 0;
        l_page_cap  PLS_INTEGER;
        l_page_cnt  PLS_INTEGER;
        l_total     NUMBER := 0;
        l_xml       XMLTYPE;
        l_err       NUMBER;
    BEGIN
        x_total_rows := 0;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        l_chunk := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));
        IF l_chunk IS NULL OR l_chunk <= 0 THEN
            l_chunk := 5000;
        END IF;

        SELECT PREFIX INTO l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        -- The engine is object-agnostic and does NOT read the object's TFM
        -- table for a generated-row count (that would need the table name as
        -- data). The page cap is a fixed high ceiling; the short-page test is
        -- the real terminator.
        l_page_cap := C_MAX_PAGES;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || p_cemli_code ||
            ' | P_LOAD_REQUEST_ID: ' || p_load_ess_id ||
            ' | chunk size: ' || l_chunk || ' | page cap: ' || l_page_cap,
            'INFO', C_PKG, C_PROC);

        LOOP
            l_page := l_page + 1;
            EXIT WHEN l_page > l_page_cap;

            -- Keyset cursor: P_AFTER_KEY empty on the first page, then the last
            -- RECORD_KEY of the previous page. P_CHUNK_SIZE bounds the page.
            DMT_UTIL_PKG.RUN_BIP_REPORT(
                p_run_id     => p_run_id,
                p_cemli_code => p_cemli_code,
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

            l_page_cnt := 0;

            -- A short/empty page ends the loop. When there is XML, STATICALLY
            -- insert the parsed nine columns straight into the GTT (fixed
            -- column list; no collection round-trip). The last RECORD_KEY of
            -- the page advances the keyset cursor.
            IF l_xml IS NOT NULL THEN
                INSERT INTO DMT_RECON_STAGE_GTT (
                    RUN_ID, OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
                    FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF, DMT_REFERENCE)
                SELECT p_run_id, x.object_type, x.record_key, UPPER(x.source_type),
                       UPPER(x.fusion_status), x.fusion_id, x.error_message,
                       x.load_request_id, x.source_ref, x.dmt_reference
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
                l_page_cnt := SQL%ROWCOUNT;

                -- Advance the keyset cursor to this page's greatest RECORD_KEY.
                IF l_page_cnt > 0 THEN
                    SELECT MAX(record_key) INTO l_after_key
                    FROM XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                          COLUMNS record_key VARCHAR2(1000) PATH 'RECORD_KEY');
                END IF;
            END IF;

            l_total := l_total + l_page_cnt;
            EXIT WHEN l_page_cnt < l_chunk;   -- short page = last page
        END LOOP;

        x_total_rows := l_total;
        x_error_code := DMT_UTIL_PKG.C_SUCCESS;
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. Pages fetched: ' || l_page ||
            ' | total report rows staged: ' || l_total || '.',
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            x_total_rows := 0;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed. CEMLI: ' || p_cemli_code,
                SQLERRM, C_PKG, C_PROC);
    END fetch_and_stage;

    -- --------------------------------------------------------
    -- confirm_reference_roundtrip — object-agnostic reference PRESENCE proof
    -- over the STAGED rows. The engine cannot join the object's TFM table (that
    -- would need the table name as data), so the STRONG reference-equals-BUILD_REF
    -- proof lives in the object's own static APPLY_<OBJ> (APPLY_GL does exactly
    -- that, TFM-joined). Here the engine confirms, generically, that every
    -- BASE/SUCCESS row DID come back carrying a Slot C reference of the expected
    -- DMT:run:...:... shape for THIS run — i.e. the round-trip reference actually
    -- returned and belongs to this run. Static SQL over the GTT's fixed columns.
    -- Diagnostic only — WARNs on any gap and NEVER alters a verdict.
    -- --------------------------------------------------------
    PROCEDURE confirm_reference_roundtrip (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'confirm_reference_roundtrip';
        l_expect  CONSTANT VARCHAR2(60) := 'DMT:' || TO_CHAR(p_run_id) || ':%';
        l_checked NUMBER := 0;
        l_ok      NUMBER := 0;
        l_gap     NUMBER := 0;
    BEGIN
        SELECT
            COUNT(*),
            COUNT(CASE WHEN g.dmt_reference LIKE l_expect THEN 1 END),
            COUNT(CASE WHEN g.dmt_reference IS NULL
                        OR g.dmt_reference NOT LIKE l_expect THEN 1 END)
          INTO l_checked, l_ok, l_gap
          FROM DMT_RECON_STAGE_GTT g
         WHERE g.RUN_ID        = p_run_id
           AND g.SOURCE_TYPE   = 'BASE'
           AND g.FUSION_STATUS = 'SUCCESS';

        IF l_gap = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip (engine) OK for ' || p_cemli_code || ': ' || l_ok ||
                ' of ' || l_checked || ' LOADED base rows returned a Slot C reference ' ||
                'for this run.',
                'INFO', C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip (engine) GAP for ' || p_cemli_code || ': ' || l_gap ||
                ' of ' || l_checked || ' LOADED base rows did NOT return a Slot C ' ||
                'reference for this run. The object''s APPLY proof owns the strong ' ||
                'TFM-joined check; LOADED verdict UNCHANGED (diagnostic only).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Round-trip proof must never break the reconcile.
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip (engine) skipped (non-fatal) for ' || p_cemli_code ||
                ': ' || SQLERRM,
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
    END confirm_reference_roundtrip;

    -- --------------------------------------------------------
    -- RECONCILE — the generic Contract v1 reconcile entry point.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE (
        p_run_id          IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_request_id IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id   IN NUMBER DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RECONCILE';
        l_cfg   t_cfg;
        l_total NUMBER;
        l_err   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || p_cemli_code ||
            ' | load_req_id: ' || p_load_request_id ||
            ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL') ||
            ' | work_queue_id: ' || NVL(TO_CHAR(p_work_queue_id), 'NULL'),
            'INFO', C_PKG, C_PROC);

        -- Registry-driven config (Contract v1 gate + the object's APPLY proc).
        read_config(p_cemli_code, l_cfg);

        -- Start this run's stage clean (a re-run, or a second object in the same
        -- session, must not see stale rows). Session GTT scoped by RUN_ID.
        DELETE FROM DMT_RECON_STAGE_GTT WHERE RUN_ID = p_run_id;

        -- 1-3. FETCH (keyset) + PARSE (nine fixed columns) + STAGE (static
        -- INSERT into the GTT). No dynamic SQL; no per-object knowledge.
        fetch_and_stage(
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => p_load_request_id,
            p_import_ess_id => p_import_ess_id,
            x_total_rows    => l_total,
            x_error_code    => l_err);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20123,
                'DMT_RECON_ENGINE_PKG.RECONCILE: report fetch failed for CEMLI ' ||
                p_cemli_code || ' (detail in DMT_LOG_TBL).');
        END IF;

        IF NVL(l_total, 0) = 0 THEN
            -- Zero report rows is never success (Contract v1). GENERATED rows stay
            -- unaccounted; the shared sweep + accounting gate report the object
            -- not-DONE. Nothing is fabricated.
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero rows for ' || p_cemli_code ||
                '. GENERATED rows left unaccounted (not marked FAILED).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        -- 4. ROUND-TRIP proof over the staged rows (diagnostic, object-agnostic).
        confirm_reference_roundtrip(p_run_id, p_cemli_code);

        -- 5. APPLY — hand off to the object's OWN thin static proc through the
        -- existing sanctioned invoke_registered site. It reads the GTT and MERGEs
        -- into its literally-named TFM table with STATIC SQL. The engine passes
        -- only scalars; the rows are already in the GTT.
        DMT_QUEUE_WORKER_PKG.INVOKE_APPLY(
            p_apply_proc    => l_cfg.apply_proc,
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => p_load_request_id,
            p_import_ess_id => p_import_ess_id,
            p_work_queue_id => p_work_queue_id);

        -- NO COMMIT — the orchestrator controls transaction boundaries.
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete for ' || p_cemli_code || '.', 'INFO', C_PKG, C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed for CEMLI ' || p_cemli_code || '.',
                SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — thin RECON_PROC-compatible wrapper (see spec).
    -- Delegates to RECONCILE, mapping p_load_ess_id to p_load_request_id.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        RECONCILE(
            p_run_id          => p_run_id,
            p_cemli_code      => p_cemli_code,
            p_load_request_id => p_load_ess_id,
            p_import_ess_id   => p_import_ess_id,
            p_work_queue_id   => p_work_queue_id);
    END RECONCILE_BATCH;

END DMT_RECON_ENGINE_PKG;
/
