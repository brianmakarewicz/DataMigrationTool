-- PACKAGE BODY DMT_RECON_CONTRACT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_RECON_CONTRACT_PKG" AS
-- ============================================================
-- DMT_RECON_CONTRACT_PKG body — the one shared Contract v1 parser.
-- See the package spec for the contract and outcome rules.
-- ============================================================

    -- --------------------------------------------------------
    -- APPLY_PAGE — apply one page of parsed report rows to the TFM table.
    -- Dynamic against p_tfm_table / p_fusion_id_col (from the registry) so the
    -- same code serves every Contract v1 object. Returns the LOADED/FAILED
    -- counts for this page and the last RECORD_KEY seen (the keyset cursor).
    -- --------------------------------------------------------
    PROCEDURE apply_page (
        p_run_id        IN  NUMBER,
        p_tfm_table     IN  VARCHAR2,
        p_fusion_id_col IN  VARCHAR2,
        p_report_xml    IN  XMLTYPE,
        x_last_key      OUT VARCHAR2,
        x_row_count     OUT NUMBER,
        x_loaded        OUT NUMBER,
        x_failed        OUT NUMBER
    ) IS
        l_loaded  NUMBER := 0;
        l_failed  NUMBER := 0;
        l_rows    NUMBER := 0;
        l_last    VARCHAR2(1000);
        -- One LOADED update and one FAILED update, both dynamic on the registry-
        -- named table + Fusion-id column. RECORD_KEY is matched to RECON_KEY.
        l_load_sql VARCHAR2(2000) :=
            'UPDATE ' || p_tfm_table ||
            ' SET TFM_STATUS = ''LOADED'', ' || p_fusion_id_col || ' = :fid, ' ||
            '     RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE ' ||
            ' WHERE RUN_ID = :iid AND RECON_KEY = :rk ' ||
            '   AND TFM_STATUS NOT IN (''LOADED'',''FAILED'')';
        l_fail_sql VARCHAR2(2000) :=
            'UPDATE ' || p_tfm_table ||
            ' SET TFM_STATUS = ''FAILED'', ' ||
            '     ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, ''[FUSION_ERROR] '' || :msg), ' ||
            '     RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE ' ||
            ' WHERE RUN_ID = :iid AND RECON_KEY = :rk ' ||
            '   AND TFM_STATUS NOT IN (''LOADED'',''FAILED'')';
        l_n NUMBER;
    BEGIN
        FOR r IN (
            SELECT x.object_type,
                   x.record_key,
                   UPPER(x.source_type)   AS source_type,
                   UPPER(x.fusion_status) AS fusion_status,
                   x.fusion_id,
                   x.error_message
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    object_type     VARCHAR2(100)  PATH 'OBJECT_TYPE',
                    record_key      VARCHAR2(1000) PATH 'RECORD_KEY',
                    source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_status   VARCHAR2(20)   PATH 'FUSION_STATUS',
                    fusion_id       NUMBER         PATH 'FUSION_ID',
                    error_message   VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
            ORDER BY x.record_key
        ) LOOP
            l_rows := l_rows + 1;
            l_last := r.record_key;

            IF r.source_type = 'BASE'
               AND r.fusion_status = 'SUCCESS'
               AND r.fusion_id IS NOT NULL THEN
                -- Positive proof: the object's business key was found in its Fusion
                -- base table with a real id. This is the ONLY path to LOADED.
                EXECUTE IMMEDIATE l_load_sql
                    USING r.fusion_id, p_run_id, r.record_key;
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.fusion_status = 'ERROR' AND r.error_message IS NOT NULL THEN
                -- A real, specific Fusion error for this record -> FAILED with the
                -- exact message (no composed sentence).
                EXECUTE IMMEDIATE l_fail_sql
                    USING r.error_message, p_run_id, r.record_key;
                l_failed := l_failed + SQL%ROWCOUNT;

            ELSE
                -- INTERFACE/SUCCESS (corroborating, never sufficient), or a
                -- non-terminal status with no real error: leave the row for the
                -- shared [UNACCOUNTED] sweep. Never fabricate an outcome.
                NULL;
            END IF;
        END LOOP;

        x_row_count := l_rows;
        x_last_key  := l_last;
        x_loaded    := l_loaded;
        x_failed    := l_failed;
    END apply_page;

    -- --------------------------------------------------------
    -- RECONCILE (full) — see spec.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE (
        p_cemli_code    IN  VARCHAR2,
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER   DEFAULT NULL,
        p_import_ess_id IN  NUMBER   DEFAULT NULL,
        x_loaded        OUT NUMBER,
        x_failed        OUT NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE';
        l_contract_ver  NUMBER;
        l_tfm_table     VARCHAR2(100);
        l_fusion_id_col VARCHAR2(100);
        l_prefix        VARCHAR2(30);
        l_chunk_size    NUMBER;
        l_after_key     VARCHAR2(1000) := NULL;
        l_xml           XMLTYPE;
        l_err           NUMBER;
        l_page          PLS_INTEGER := 0;
        l_page_rows     NUMBER;
        l_last_key      VARCHAR2(1000);
        l_pg_loaded     NUMBER;
        l_pg_failed     NUMBER;
        l_gen_count     NUMBER;
        l_max_pages     PLS_INTEGER;
        l_total_rows    NUMBER := 0;
    BEGIN
        x_loaded := 0;
        x_failed := 0;

        -- Registry: the object must be Contract v1 with a TFM table + id column.
        BEGIN
            SELECT CONTRACT_VERSION, TFM_TABLE, FUSION_ID_COLUMN
            INTO   l_contract_ver, l_tfm_table, l_fusion_id_col
            FROM   DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = p_cemli_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20090,
                    'DMT_RECON_CONTRACT_PKG.RECONCILE: no DMT_BIP_REPORT_TBL row for CEMLI '
                    || p_cemli_code);
        END;

        IF NVL(l_contract_ver, 0) <> 1 THEN
            RAISE_APPLICATION_ERROR(-20091,
                'DMT_RECON_CONTRACT_PKG.RECONCILE: CEMLI ' || p_cemli_code ||
                ' is not registered as CONTRACT_VERSION = 1 (found ' ||
                NVL(TO_CHAR(l_contract_ver), 'NULL') || ').');
        END IF;

        IF l_tfm_table IS NULL OR l_fusion_id_col IS NULL THEN
            RAISE_APPLICATION_ERROR(-20092,
                'DMT_RECON_CONTRACT_PKG.RECONCILE: CEMLI ' || p_cemli_code ||
                ' is Contract v1 but TFM_TABLE / FUSION_ID_COLUMN is not registered.');
        END IF;

        -- Run prefix (Contract v1 P_PREFIX) and page size.
        SELECT PREFIX INTO l_prefix FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
        l_chunk_size := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));

        -- Page-count cap derived from the run's generated-row count: a misbehaving
        -- report cannot loop forever. +2 pages of slack, floor of 2.
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || l_tfm_table || ' WHERE RUN_ID = :iid'
            INTO l_gen_count USING p_run_id;
        l_max_pages := GREATEST(2, CEIL(NVL(l_gen_count, 0) / GREATEST(l_chunk_size, 1)) + 2);

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' start. CEMLI: ' || p_cemli_code ||
            ' | TFM: ' || l_tfm_table || ' | FusionIdCol: ' || l_fusion_id_col ||
            ' | ChunkSize: ' || l_chunk_size || ' | MaxPages: ' || l_max_pages ||
            ' | LoadReqId: ' || NVL(TO_CHAR(p_load_ess_id), '(null)'),
            'INFO', C_PKG, C_PROC);

        -- Keyset pagination loop (design section 5): first call empty cursor;
        -- each next call passes the last RECORD_KEY received; stop on a short page.
        LOOP
            l_page := l_page + 1;

            DMT_UTIL_PKG.RUN_BIP_REPORT(
                p_run_id     => p_run_id,
                p_cemli_code => p_cemli_code,
                p_params     => 'P_RUN_ID|'           || TO_CHAR(p_run_id) ||
                                '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                                '~P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                                '~P_PREFIX|'          || l_prefix ||
                                '~P_CHUNK_SIZE|'      || TO_CHAR(l_chunk_size) ||
                                '~P_AFTER_KEY|'       || l_after_key,
                x_report_xml => l_xml,
                x_error_code => l_err);

            -- A transport failure / SOAP fault raises immediately (design section 5:
            -- never a silent retry, never a zero-row "success").
            IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
                RAISE_APPLICATION_ERROR(-20093,
                    'DMT_RECON_CONTRACT_PKG.RECONCILE: Contract v1 report failed for CEMLI '
                    || p_cemli_code || ' on page ' || l_page || ' (detail in DMT_LOG_TBL).');
            END IF;

            -- A NULL page = zero rows. On the first page this is the "zero report
            -- rows is never success" case: warn, leave rows unaccounted, stop.
            IF l_xml IS NULL THEN
                IF l_page = 1 THEN
                    DMT_UTIL_PKG.LOG(p_run_id,
                        C_PROC || ': Contract v1 report returned ZERO rows for CEMLI '
                        || p_cemli_code || '. Rows left unaccounted (never a silent success).',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
                END IF;
                EXIT;
            END IF;

            apply_page(
                p_run_id        => p_run_id,
                p_tfm_table     => l_tfm_table,
                p_fusion_id_col => l_fusion_id_col,
                p_report_xml    => l_xml,
                x_last_key      => l_last_key,
                x_row_count     => l_page_rows,
                x_loaded        => l_pg_loaded,
                x_failed        => l_pg_failed);

            x_loaded     := x_loaded + l_pg_loaded;
            x_failed     := x_failed + l_pg_failed;
            l_total_rows := l_total_rows + l_page_rows;

            DMT_UTIL_PKG.LOG(p_run_id,
                C_PROC || ' page ' || l_page || ': rows ' || l_page_rows ||
                ' | LOADED ' || l_pg_loaded || ' | FAILED ' || l_pg_failed ||
                ' | lastKey ' || NVL(l_last_key, '(none)'),
                'INFO', C_PKG, C_PROC);

            -- Short page => last page (keyset is exact, no overlap).
            EXIT WHEN l_page_rows < l_chunk_size;

            -- Safety cap: a report that keeps returning full pages beyond the
            -- run's own row count is misbehaving; stop and surface it.
            IF l_page >= l_max_pages THEN
                DMT_UTIL_PKG.LOG(p_run_id,
                    C_PROC || ': page cap (' || l_max_pages || ') reached for CEMLI '
                    || p_cemli_code || ' — stopping keyset loop. Report may be looping.',
                    DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
                EXIT;
            END IF;

            l_after_key := l_last_key;
        END LOOP;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ' complete. CEMLI: ' || p_cemli_code ||
            ' | pages ' || l_page || ' | rows ' || l_total_rows ||
            ' | LOADED ' || x_loaded || ' | FAILED ' || x_failed,
            'INFO', C_PKG, C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                C_PROC || ' failed for CEMLI ' || p_cemli_code || '.',
                SQLERRM, C_PKG, C_PROC);
            RAISE;
    END RECONCILE;

    -- --------------------------------------------------------
    -- RECONCILE (convenience, no OUT counts).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE (
        p_cemli_code    IN  VARCHAR2,
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER   DEFAULT NULL,
        p_import_ess_id IN  NUMBER   DEFAULT NULL
    ) IS
        l_loaded NUMBER;
        l_failed NUMBER;
    BEGIN
        RECONCILE(p_cemli_code, p_run_id, p_load_ess_id, p_import_ess_id, l_loaded, l_failed);
    END RECONCILE;

END DMT_RECON_CONTRACT_PKG;
/
