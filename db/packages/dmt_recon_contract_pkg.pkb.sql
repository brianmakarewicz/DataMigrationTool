-- PACKAGE BODY DMT_RECON_CONTRACT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_RECON_CONTRACT_PKG" AS
-- ============================================================
-- DMT_RECON_CONTRACT_PKG body — the one shared Contract v1 fetch.
-- See the package spec for the contract and the FETCH/APPLY split (Option A).
-- This package contains NO dynamic SQL and names NO TFM table.
--
-- HEADER PAGING (owner direction 2026-10-09, backlog #224). A report may
-- return an optional tenth column PAGE_KEY: the key of the header (document)
-- each row belongs to. When the rows of a page carry PAGE_KEY, the page is a
-- set of whole documents, never a slice of one:
--   * P_CHUNK_SIZE counts HEADERS, not rows: the report returns the next
--     P_CHUNK_SIZE header keys after P_AFTER_KEY plus EVERY line and
--     distribution row of those headers, however many there are.
--   * P_AFTER_KEY is the last PAGE_KEY received (header keyset), not the
--     last RECORD_KEY.
--   * A page is short (the last page) when it holds fewer than P_CHUNK_SIZE
--     distinct headers.
-- A report that does not emit PAGE_KEY (every report except ARInvoices V5
-- today) yields NULL for it and keeps the original row keyset unchanged, so
-- this is opt-in per report and needs no change in any other caller.
-- Rows of a header-paged page are returned ordered by PAGE_KEY (BINARY), then
-- RECORD_KEY, so the page's last row carries its greatest header key.
--
-- REVISIONS:
--   2026-10-09  BM  Optional PAGE_KEY header paging (backlog #224); body only,
--                   the spec and the record type are unchanged.
-- ============================================================

    -- --------------------------------------------------------
    -- FETCH_ROWS — run the object's Contract v1 report and return its parsed rows.
    -- Procedure per the procedures-only rule: outcome via x_error_code; exceptions
    -- never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_ROWS (
        p_cemli_code    IN  VARCHAR2,
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER   DEFAULT NULL,
        p_import_ess_id IN  NUMBER   DEFAULT NULL,
        p_row_cap       IN  NUMBER   DEFAULT NULL,
        x_rows          OUT T_RECON_TBL,
        x_error_code    OUT NUMBER,
        p_work_queue_id IN  NUMBER   DEFAULT NULL,
        p_fusion_batch_id IN NUMBER  DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'FETCH_ROWS';
        C_SEP  CONSTANT VARCHAR2(1)  := DMT_UTIL_PKG.C_BIP_PARAM_SEP;   -- #414
        l_contract_ver  NUMBER;
        l_prefix        VARCHAR2(30);
        l_chunk_size    NUMBER;
        l_after_key     VARCHAR2(1000) := NULL;
        l_xml           XMLTYPE;
        l_err           NUMBER;
        l_page          PLS_INTEGER := 0;
        l_page_rows     PLS_INTEGER;
        l_last_key      VARCHAR2(1000);
        -- Header paging (backlog #224): distinct PAGE_KEYs on this page and the
        -- last one seen. Both stay 0 / NULL for a report without PAGE_KEY.
        l_page_headers  PLS_INTEGER;
        l_last_page_key VARCHAR2(1000);
        l_max_pages     PLS_INTEGER;
        l_n             PLS_INTEGER := 0;
        l_batch_param   VARCHAR2(100);
    BEGIN
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        -- Registry: the object must be Contract v1. Only the CONTRACT_VERSION is
        -- read here (plus PREFIX from the run); the report catalog path is
        -- resolved inside RUN_BIP_REPORT from DMT_BIP_REPORT_TBL. This package
        -- never reads TFM_TABLE / FUSION_ID_COLUMN and never builds SQL from them.
        BEGIN
            SELECT CONTRACT_VERSION
            INTO   l_contract_ver
            FROM   DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = p_cemli_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id    => p_run_id,
                    p_message   => C_PROC || ': no DMT_BIP_REPORT_TBL row for CEMLI '
                                   || p_cemli_code,
                    p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                    p_package   => C_PKG,
                    p_procedure => C_PROC);
                RETURN;
        END;

        IF NVL(l_contract_ver, 0) <> 1 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': CEMLI ' || p_cemli_code ||
                               ' is not registered as CONTRACT_VERSION = 1 (found ' ||
                               NVL(TO_CHAR(l_contract_ver), 'NULL') || ').',
                p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        -- Run prefix (Contract v1 P_PREFIX) and page size.
        SELECT PREFIX INTO l_prefix FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
        l_chunk_size := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));

        -- Page-count cap derived from the expected row count: a misbehaving report
        -- cannot loop forever. +2 pages of slack, floor of 2.
        l_max_pages := GREATEST(2, CEIL(NVL(p_row_cap, 0) / GREATEST(l_chunk_size, 1)) + 2);

        -- Optional Fusion import batch id (Customers): sent only when given, so the
        -- report call of every object that does not pass it stays byte-identical.
        IF p_fusion_batch_id IS NOT NULL THEN
            l_batch_param := C_SEP || 'P_FUSION_BATCH_ID|' || TO_CHAR(p_fusion_batch_id, 'TM9');
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' start. CEMLI: ' || p_cemli_code ||
                           ' | ChunkSize: ' || l_chunk_size || ' | MaxPages: ' || l_max_pages ||
                           ' | LoadReqId: ' || NVL(TO_CHAR(p_load_ess_id), '(null)') ||
                           CASE WHEN p_fusion_batch_id IS NOT NULL
                                THEN ' | FusionBatchId: ' || TO_CHAR(p_fusion_batch_id, 'TM9') END,
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- Keyset pagination loop (design section 5): first call empty cursor;
        -- each next call passes the last RECORD_KEY received; stop on a short page.
        LOOP
            l_page := l_page + 1;

            DMT_UTIL_PKG.RUN_BIP_REPORT(
                p_run_id     => p_run_id,
                p_cemli_code => p_cemli_code,
                -- Pairs are joined by DMT_UTIL_PKG.C_BIP_PARAM_SEP, not '~':
                -- from page 2 P_AFTER_KEY is the last RECORD_KEY received, and
                -- several reports build RECORD_KEY with '~' (Customers
                -- 'Customers.Parties~<ref>'). Under the '~' split that key was
                -- cut short and page 2 restarted near the first key (#414).
                p_params     => 'P_RUN_ID|'                    || TO_CHAR(p_run_id) ||
                                C_SEP || 'P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                                C_SEP || 'P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                                C_SEP || 'P_PREFIX|'          || l_prefix ||
                                l_batch_param ||
                                C_SEP || 'P_CHUNK_SIZE|'      || TO_CHAR(l_chunk_size) ||
                                C_SEP || 'P_AFTER_KEY|'       || l_after_key ||
                                -- P_WQ_ID only when given (the Projects report,
                                -- owner-approved exception 2026-10-07); no other
                                -- report receives a parameter it does not declare.
                                CASE WHEN p_work_queue_id IS NOT NULL
                                     THEN C_SEP || 'P_WQ_ID|' || TO_CHAR(p_work_queue_id) END,
                x_report_xml => l_xml,
                x_error_code => l_err);

            -- A transport failure / SOAP fault surfaces via x_error_code (design
            -- section 5: never a silent retry, never a zero-row "success"). We stop
            -- and return C_ERROR with an empty set; the caller raises loudly.
            IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id    => p_run_id,
                    p_message   => C_PROC || ': Contract v1 report failed for CEMLI '
                                   || p_cemli_code || ' on page ' || l_page ||
                                   ' (detail logged by RUN_BIP_REPORT).',
                    p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                    p_package   => C_PKG,
                    p_procedure => C_PROC);
                x_error_code := DMT_UTIL_PKG.C_ERROR;
                RETURN;
            END IF;

            -- A NULL page = zero rows. On the first page this is the "zero report
            -- rows is never success" case: warn and return whatever we have (empty
            -- on page 1). The caller's no-rows policy decides the outcome.
            IF l_xml IS NULL THEN
                IF l_page = 1 THEN
                    DMT_UTIL_PKG.LOG(
                        p_run_id    => p_run_id,
                        p_message   => C_PROC || ': Contract v1 report returned ZERO rows '
                                       || 'for CEMLI ' || p_cemli_code || '. Returning empty '
                                       || 'set (caller applies the never-a-silent-success rule).',
                        p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                        p_package   => C_PKG,
                        p_procedure => C_PROC);
                END IF;
                EXIT;
            END IF;

            -- Parse this page's seven contract columns into the collection.
            l_page_rows     := 0;
            l_last_key      := NULL;
            l_page_headers  := 0;
            l_last_page_key := NULL;
            -- Backlog #65: also parse the report's DMT_REFERENCE (Slot C DFF, tier 2)
            -- and SOURCE_REF (business key, tier 3) columns. A DM that does not emit
            -- these nodes yields NULL for them (XMLTABLE PATH returns NULL for an
            -- absent element), so this is tolerant of any un-widened DM and preserves
            -- tier-1-only behaviour.
            FOR r IN (
                SELECT x.object_type,
                       x.record_key,
                       UPPER(x.source_type)   AS source_type,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.fusion_id,
                       x.error_message,
                       x.load_request_id,
                       x.dmt_reference,
                       x.source_ref,
                       x.page_key
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                    COLUMNS
                        object_type     VARCHAR2(100)  PATH 'OBJECT_TYPE',
                        record_key      VARCHAR2(1000) PATH 'RECORD_KEY',
                        source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                        fusion_status   VARCHAR2(20)   PATH 'FUSION_STATUS',
                        fusion_id       VARCHAR2(200)  PATH 'FUSION_ID',
                        error_message   VARCHAR2(4000) PATH 'ERROR_MESSAGE',
                        load_request_id VARCHAR2(100)  PATH 'LOAD_REQUEST_ID',
                        dmt_reference   VARCHAR2(1000) PATH 'DMT_REFERENCE',
                        source_ref      VARCHAR2(1000) PATH 'SOURCE_REF',
                        -- Optional header key (backlog #224); NULL when absent.
                        page_key        VARCHAR2(1000) PATH 'PAGE_KEY'
                ) x
                -- Header-paged rows group by their header first, in the BINARY
                -- order the report pages by; for a report without PAGE_KEY every
                -- value is NULL and the order is RECORD_KEY, exactly as before.
                ORDER BY NLSSORT(x.page_key, 'NLS_SORT=BINARY') NULLS FIRST, x.record_key
            ) LOOP
                l_n := l_n + 1;
                x_rows(l_n).object_type     := r.object_type;
                x_rows(l_n).record_key      := r.record_key;
                x_rows(l_n).source_type     := r.source_type;
                x_rows(l_n).fusion_status   := r.fusion_status;
                x_rows(l_n).fusion_id       := r.fusion_id;
                x_rows(l_n).error_message   := r.error_message;
                x_rows(l_n).load_request_id := r.load_request_id;
                x_rows(l_n).dff_key         := r.dmt_reference;  -- tier 2
                x_rows(l_n).business_key     := r.source_ref;    -- tier 3
                l_page_rows := l_page_rows + 1;
                l_last_key  := r.record_key;
                -- Rows arrive grouped by PAGE_KEY, so a change of value is a new header.
                IF r.page_key IS NOT NULL
                   AND (l_last_page_key IS NULL OR r.page_key <> l_last_page_key) THEN
                    l_page_headers  := l_page_headers + 1;
                    l_last_page_key := r.page_key;
                END IF;
            END LOOP;

            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' page ' || l_page || ': rows ' || l_page_rows ||
                               CASE WHEN l_page_headers > 0
                                    THEN ' | headers ' || l_page_headers ||
                                         ' | lastPageKey ' || l_last_page_key
                                    ELSE ' | lastKey ' || NVL(l_last_key, '(none)') END,
                p_package   => C_PKG,
                p_procedure => C_PROC);

            -- Short page => last page (keyset is exact, no overlap). A header-paged
            -- page is short when it holds fewer headers than the chunk size; the
            -- number of line and distribution rows under those headers never
            -- decides it (backlog #224).
            IF l_page_headers > 0 THEN
                EXIT WHEN l_page_headers < l_chunk_size;
            ELSE
                EXIT WHEN l_page_rows < l_chunk_size;
            END IF;

            -- Safety cap: a report that keeps returning full pages beyond the
            -- expected row count is misbehaving; stop and surface it.
            IF l_page >= l_max_pages THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id    => p_run_id,
                    p_message   => C_PROC || ': page cap (' || l_max_pages || ') reached for '
                                   || 'CEMLI ' || p_cemli_code || ' — stopping keyset loop. '
                                   || 'Report may be looping.',
                    p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package   => C_PKG,
                    p_procedure => C_PROC);
                EXIT;
            END IF;

            -- Next page starts after the last header received (header paging) or
            -- after the last row key (row keyset, every other report).
            l_after_key := CASE WHEN l_page_headers > 0 THEN l_last_page_key
                                ELSE l_last_key END;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. CEMLI: ' || p_cemli_code ||
                           ' | pages ' || l_page || ' | rows ' || l_n,
            p_package   => C_PKG,
            p_procedure => C_PROC);

        x_error_code := DMT_UTIL_PKG.C_SUCCESS;

    EXCEPTION
        WHEN OTHERS THEN
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed for CEMLI ' || p_cemli_code || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END FETCH_ROWS;

END DMT_RECON_CONTRACT_PKG;
/
