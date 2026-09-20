-- PACKAGE BODY DMT_RECON_ENGINE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_RECON_ENGINE_PKG" AS
-- ============================================================
-- DMT_RECON_ENGINE_PKG body — the one generic Contract v1 reconcile.
-- See the package spec for the contract and the FETCH/APPLY/ROUND-TRIP
-- shape (extracted from the reference DMT_GL_RESULTS_PKG).
--
-- The two APPLY MERGEs are built from registry-named identifiers. Every
-- identifier (TFM table, status column, fusion-id column, recon-key column)
-- is validated by assert_ident BEFORE it is concatenated into a statement,
-- and every value is bound — the same sanctioned posture as
-- DMT_QUEUE_WORKER_PKG.ACCOUNT_ROWS / assert_catalog_identifier. No
-- non-identifier text can reach a dynamic statement.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_RECON_ENGINE_PKG';

    -- Absolute safety cap on the page loop, above any real conversion volume.
    -- The live cap is derived per-run from the generated-row count; this is the
    -- last-resort ceiling for a run whose generated count could not be read.
    C_MAX_PAGES CONSTANT PLS_INTEGER := 100000;

    -- One object's registry-driven reconcile config (all from DMT_BIP_REPORT_TBL).
    TYPE t_cfg IS RECORD (
        contract_version NUMBER,
        tfm_table        VARCHAR2(128),
        status_column    VARCHAR2(128),
        fusion_id_column VARCHAR2(128),
        recon_key_column VARCHAR2(128)
    );

    -- --------------------------------------------------------
    -- assert_ident — validate a registry-supplied table or column name
    -- before it is concatenated into a SQL text. Same posture as
    -- DMT_QUEUE_WORKER_PKG.assert_catalog_identifier: the values come only
    -- from the seeded registry DMT_BIP_REPORT_TBL, and are still
    -- pattern-checked so no non-identifier text can ever reach a dynamic
    -- statement.
    -- --------------------------------------------------------
    PROCEDURE assert_ident (p_name IN VARCHAR2, p_what IN VARCHAR2) IS
    BEGIN
        IF p_name IS NULL
           OR NOT REGEXP_LIKE(p_name, '^[A-Z][A-Z0-9_$#]*$') THEN
            RAISE_APPLICATION_ERROR(-20120,
                'Registry ' || p_what || ' "' || p_name ||
                '" is not a valid SQL identifier (DMT_BIP_REPORT_TBL seed defect)');
        END IF;
    END assert_ident;

    -- --------------------------------------------------------
    -- read_config — read the object's Contract v1 reconcile config from the
    -- registry and assert every identifier. Raises if the object is not
    -- Contract v1 or an identifier is malformed. STATUS_COLUMN / RECON_KEY_COLUMN
    -- default to TFM_STATUS / RECON_KEY when the registry leaves them NULL
    -- (the universal DMT convention), so an object need only set the two that
    -- differ from convention.
    -- --------------------------------------------------------
    PROCEDURE read_config (p_cemli_code IN VARCHAR2, x_cfg OUT t_cfg) IS
    BEGIN
        BEGIN
            SELECT CONTRACT_VERSION,
                   TFM_TABLE,
                   NVL(STATUS_COLUMN,    'TFM_STATUS'),
                   FUSION_ID_COLUMN,
                   NVL(RECON_KEY_COLUMN, 'RECON_KEY')
            INTO   x_cfg.contract_version,
                   x_cfg.tfm_table,
                   x_cfg.status_column,
                   x_cfg.fusion_id_column,
                   x_cfg.recon_key_column
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

        assert_ident(x_cfg.tfm_table,        'TFM_TABLE');
        assert_ident(x_cfg.status_column,    'STATUS_COLUMN');
        assert_ident(x_cfg.fusion_id_column, 'FUSION_ID_COLUMN');
        assert_ident(x_cfg.recon_key_column, 'RECON_KEY_COLUMN');
    END read_config;

    -- --------------------------------------------------------
    -- fetch_all_pages — keyset-page the object's deployed nine-column recon
    -- report into ONE DMT_RECON_ROW_TBL collection (the SQL type, so the APPLY
    -- MERGEs can TABLE()-join it). Empty P_AFTER_KEY on the first call, then the
    -- last RECORD_KEY received, until a page returns fewer than P_CHUNK_SIZE
    -- rows. Same shape and parameters as the reference reconciler; transport is
    -- the shared DMT_UTIL_PKG.RUN_BIP_REPORT. HTTP/SOAP failures surface through
    -- x_error_code (detail logged by RUN_BIP_REPORT).
    -- --------------------------------------------------------
    PROCEDURE fetch_all_pages (
        p_run_id        IN  NUMBER,
        p_cemli_code    IN  VARCHAR2,
        p_load_ess_id   IN  NUMBER,
        p_import_ess_id IN  NUMBER,
        p_gen_cnt       IN  NUMBER,
        x_rows          OUT DMT_RECON_ROW_TBL,
        x_error_code    OUT NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'fetch_all_pages';
        l_prefix    VARCHAR2(30);
        l_chunk     PLS_INTEGER;
        l_after_key VARCHAR2(1000) := NULL;   -- empty cursor on first call
        l_page      PLS_INTEGER := 0;
        l_page_cap  PLS_INTEGER;
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

        -- Page-count cap from the run's generated-row count: at most one page
        -- per generated row plus a small margin, capped at C_MAX_PAGES.
        l_page_cap := CEIL(GREATEST(NVL(p_gen_cnt, 0), 1) / l_chunk) + 2;
        IF l_page_cap > C_MAX_PAGES THEN
            l_page_cap := C_MAX_PAGES;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || p_cemli_code ||
            ' | P_LOAD_REQUEST_ID: ' || p_load_ess_id ||
            ' | chunk size: ' || l_chunk ||
            ' | page cap: ' || l_page_cap || ' (gen rows: ' || NVL(p_gen_cnt, 0) || ')',
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

            -- A short/empty page ends the loop.
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
                C_PROC || ' failed. CEMLI: ' || p_cemli_code,
                SQLERRM, C_PKG, C_PROC);
    END fetch_all_pages;

    -- --------------------------------------------------------
    -- apply_results — the set-based core, built generically. Two single
    -- statements do all the marking; no per-row loop. Both scope to RUN_ID
    -- (plus WORK_QUEUE_ID for a spawn-per-partition child). The identifiers
    -- are asserted by the caller (read_config); every value is bound.
    -- --------------------------------------------------------
    PROCEDURE apply_results (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_cfg           IN t_cfg,
        p_rows          IN DMT_RECON_ROW_TBL,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'apply_results';
        l_wq     CONSTANT VARCHAR2(60) :=
                     CASE WHEN p_work_queue_id IS NOT NULL
                          THEN ' AND t.WORK_QUEUE_ID = :wq' END;
        l_sql    VARCHAR2(4000);
        l_loaded NUMBER := 0;
        l_failed NUMBER := 0;
    BEGIN
        -- (1) SET-BASED LOADED: a TFM row is LOADED only from a BASE/SUCCESS
        -- row with a real FUSION_ID; FUSION_ID captured in the same statement
        -- (contract: no LOADED without its Fusion id). MAX(fusion_id) is a
        -- stable pick when several base lines map to one recon key.
        l_sql :=
            'MERGE INTO ' || p_cfg.tfm_table || ' t ' ||
            'USING (SELECT r.record_key, MAX(r.fusion_id) AS fusion_id ' ||
            '       FROM   TABLE(:p_rows) r ' ||
            '       WHERE  r.source_type = ''BASE'' ' ||
            '       AND    r.fusion_status = ''SUCCESS'' ' ||
            '       AND    r.fusion_id IS NOT NULL ' ||
            '       GROUP BY r.record_key) s ' ||
            'ON (t.RUN_ID = :run_id AND t.' || p_cfg.recon_key_column || ' = s.record_key' ||
            NVL(l_wq, '') || ') ' ||
            'WHEN MATCHED THEN UPDATE ' ||
            '   SET t.' || p_cfg.status_column    || ' = ''LOADED'', ' ||
            '       t.' || p_cfg.fusion_id_column || ' = s.fusion_id, ' ||
            '       t.RESULTS_UPDATED_DATE = SYSDATE, ' ||
            '       t.LAST_UPDATED_DATE    = SYSDATE ' ||
            '   WHERE t.' || p_cfg.status_column || ' NOT IN (''LOADED'',''FAILED'')';

        IF p_work_queue_id IS NOT NULL THEN
            EXECUTE IMMEDIATE l_sql USING p_rows, p_run_id, p_work_queue_id;
        ELSE
            EXECUTE IMMEDIATE l_sql USING p_rows, p_run_id;
        END IF;
        l_loaded := SQL%ROWCOUNT;

        -- (2) SET-BASED FAILED: any ERROR row carrying a real Fusion error
        -- message. Append the error, tagged [FUSION_ERROR]; never overwrite.
        -- The LOADED statement already ran and both guard TFM_STATUS NOT IN
        -- (LOADED,FAILED), so FAILED cannot clobber a LOADED row.
        l_sql :=
            'MERGE INTO ' || p_cfg.tfm_table || ' t ' ||
            'USING (SELECT r.record_key, MIN(r.error_message) AS error_message ' ||
            '       FROM   TABLE(:p_rows) r ' ||
            '       WHERE  r.fusion_status = ''ERROR'' ' ||
            '       AND    r.error_message IS NOT NULL ' ||
            '       GROUP BY r.record_key) s ' ||
            'ON (t.RUN_ID = :run_id AND t.' || p_cfg.recon_key_column || ' = s.record_key' ||
            NVL(l_wq, '') || ') ' ||
            'WHEN MATCHED THEN UPDATE ' ||
            '   SET t.' || p_cfg.status_column || ' = ''FAILED'', ' ||
            '       t.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, ' ||
            '                        ''[FUSION_ERROR] '' || s.error_message), ' ||
            '       t.RESULTS_UPDATED_DATE = SYSDATE, ' ||
            '       t.LAST_UPDATED_DATE    = SYSDATE ' ||
            '   WHERE t.' || p_cfg.status_column || ' NOT IN (''LOADED'',''FAILED'')';

        IF p_work_queue_id IS NOT NULL THEN
            EXECUTE IMMEDIATE l_sql USING p_rows, p_run_id, p_work_queue_id;
        ELSE
            EXECUTE IMMEDIATE l_sql USING p_rows, p_run_id;
        END IF;
        l_failed := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete (set-based). CEMLI: ' || p_cemli_code ||
            ' | LOADED: ' || l_loaded || ', FAILED: ' || l_failed ||
            '. Unmatched/no-error rows left GENERATED (unaccounted).',
            'INFO', C_PKG, C_PROC);
    END apply_results;

    -- --------------------------------------------------------
    -- confirm_roundtrip — set-based round-trip proof. One query counts
    -- BASE/SUCCESS rows whose returned DMT_REFERENCE does NOT equal BUILD_REF
    -- for the matched TFM row, and logs a single summary. Diagnostic only —
    -- WARNs on any mismatch and NEVER alters a verdict.
    --
    -- BUILD_REF needs the TFM row's identity PK and WORK_QUEUE_ID. Not every
    -- conforming TFM table carries those; when the object's TFM table does not
    -- expose the reference-carrier columns the proof is skipped with an INFO
    -- (the load verdict is unaffected). The reference GL TFM table exposes
    -- TFM_SEQUENCE_ID + WORK_QUEUE_ID, so GL keeps the exact proof it had.
    --
    -- Built dynamically (the TFM table + recon-key column are registry-named,
    -- already asserted). The identity-PK column is read from ALL_TAB_IDENTITY_COLS
    -- for the object's TFM table; if there is no single identity PK column the
    -- proof is skipped.
    -- --------------------------------------------------------
    PROCEDURE confirm_roundtrip (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_cfg           IN t_cfg,
        p_rows          IN DMT_RECON_ROW_TBL
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'confirm_roundtrip';
        l_id_col   VARCHAR2(128);
        l_has_wq   PLS_INTEGER;
        l_sql      VARCHAR2(4000);
        l_checked  NUMBER := 0;
        l_ok       NUMBER := 0;
        l_mismatch NUMBER := 0;
    BEGIN
        -- The TFM table must expose WORK_QUEUE_ID and exactly one identity column
        -- for BUILD_REF's FULL reference (DMT:run:queue:tfm). Otherwise skip.
        SELECT COUNT(*) INTO l_has_wq
        FROM   USER_TAB_COLUMNS
        WHERE  TABLE_NAME = p_cfg.tfm_table AND COLUMN_NAME = 'WORK_QUEUE_ID';

        BEGIN
            SELECT COLUMN_NAME INTO l_id_col
            FROM   USER_TAB_IDENTITY_COLS
            WHERE  TABLE_NAME = p_cfg.tfm_table;
        EXCEPTION
            WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN l_id_col := NULL;
        END;

        IF l_has_wq = 0 OR l_id_col IS NULL THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip proof skipped for ' || p_cemli_code ||
                ' (TFM table ' || p_cfg.tfm_table || ' has no single identity PK + '
                || 'WORK_QUEUE_ID to build the FULL reference). LOADED verdict UNCHANGED.',
                'INFO', C_PKG, C_PROC);
            RETURN;
        END IF;
        assert_ident(l_id_col, 'IDENTITY_COLUMN');

        l_sql :=
            'SELECT COUNT(*), ' ||
            '  COUNT(CASE WHEN r.dmt_reference = ' ||
            '        DMT_REF_ID_PKG.BUILD_REF(t.RUN_ID, t.WORK_QUEUE_ID, t.' || l_id_col || ') ' ||
            '        THEN 1 END), ' ||
            '  COUNT(CASE WHEN r.dmt_reference IS NULL OR r.dmt_reference <> ' ||
            '        DMT_REF_ID_PKG.BUILD_REF(t.RUN_ID, t.WORK_QUEUE_ID, t.' || l_id_col || ') ' ||
            '        THEN 1 END) ' ||
            'FROM TABLE(:p_rows) r ' ||
            'JOIN ' || p_cfg.tfm_table || ' t ' ||
            '  ON t.RUN_ID = :run_id AND t.' || p_cfg.recon_key_column || ' = r.record_key ' ||
            'WHERE r.source_type = ''BASE'' AND r.fusion_status = ''SUCCESS''';

        EXECUTE IMMEDIATE l_sql INTO l_checked, l_ok, l_mismatch USING p_rows, p_run_id;

        IF l_mismatch = 0 THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip OK (set-based): ' || l_ok || ' of ' || l_checked ||
                ' LOADED base rows carry the expected DMT_REFERENCE.',
                'INFO', C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip MISMATCH (set-based): ' || l_mismatch || ' of ' ||
                l_checked || ' LOADED base rows do NOT carry the expected DMT_REFERENCE. '
                || 'LOADED verdict UNCHANGED (diagnostic only).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Round-trip proof must never break the reconcile.
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF round-trip proof skipped (non-fatal): ' || SQLERRM,
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
    END confirm_roundtrip;

    -- --------------------------------------------------------
    -- count_generated — generated-row count for the object's TFM table, used
    -- only to derive the keyset page cap. Registry-named table, asserted;
    -- RUN_ID (and WORK_QUEUE_ID for a child) bound. On any error returns 0
    -- (the cap then falls back to a floor).
    -- --------------------------------------------------------
    FUNCTION count_generated (
        p_run_id        IN NUMBER,
        p_cfg           IN t_cfg,
        p_work_queue_id IN NUMBER
    ) RETURN NUMBER IS
        l_sql VARCHAR2(1000);
        l_cnt NUMBER := 0;
    BEGIN
        l_sql := 'SELECT COUNT(*) FROM ' || p_cfg.tfm_table || ' WHERE RUN_ID = :run_id' ||
                 CASE WHEN p_work_queue_id IS NOT NULL THEN ' AND WORK_QUEUE_ID = :wq' END;
        IF p_work_queue_id IS NOT NULL THEN
            EXECUTE IMMEDIATE l_sql INTO l_cnt USING p_run_id, p_work_queue_id;
        ELSE
            EXECUTE IMMEDIATE l_sql INTO l_cnt USING p_run_id;
        END IF;
        RETURN l_cnt;
    EXCEPTION
        WHEN OTHERS THEN RETURN 0;
    END count_generated;

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
        l_rows  DMT_RECON_ROW_TBL;
        l_gen   NUMBER;
        l_err   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || p_cemli_code ||
            ' | load_req_id: ' || p_load_request_id ||
            ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL') ||
            ' | work_queue_id: ' || NVL(TO_CHAR(p_work_queue_id), 'NULL'),
            'INFO', C_PKG, C_PROC);

        -- Registry-driven config + identifier assertions.
        read_config(p_cemli_code, l_cfg);

        -- Page cap driver (generated-row count on this object's TFM table).
        l_gen := count_generated(p_run_id, l_cfg, p_work_queue_id);

        -- 1. FETCH (keyset) the nine-column report into one collection.
        fetch_all_pages(
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => p_load_request_id,
            p_import_ess_id => p_import_ess_id,
            p_gen_cnt       => l_gen,
            x_rows          => l_rows,
            x_error_code    => l_err);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20123,
                'DMT_RECON_ENGINE_PKG.RECONCILE: report fetch failed for CEMLI ' ||
                p_cemli_code || ' (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows IS NULL OR l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (Contract v1). GENERATED rows stay
            -- unaccounted; the shared sweep + accounting gate report the object
            -- not-DONE. Nothing is fabricated.
            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ': report returned zero rows for ' || p_cemli_code ||
                '. GENERATED rows left unaccounted (not marked FAILED).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
            RETURN;
        END IF;

        -- 2. APPLY (set-based, generic) + 3. ROUND-TRIP proof.
        apply_results(p_run_id, p_cemli_code, l_cfg, l_rows, p_work_queue_id);
        confirm_roundtrip(p_run_id, p_cemli_code, l_cfg, l_rows);

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
    -- RECONCILE_BATCH — thin RECON_PROC-compatible wrapper (see spec). Delegates
    -- to RECONCILE, mapping the dispatch's p_load_ess_id to p_load_request_id.
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
