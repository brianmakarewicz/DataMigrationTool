-- PACKAGE BODY DMT_RECON_CONTRACT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_RECON_CONTRACT_PKG" AS
-- ============================================================
-- NAME:    DMT_RECON_CONTRACT_PKG (body)
-- PURPOSE: The one shared Contract v1 reconciliation fetch. See the package
--          spec for the contract and the FETCH/APPLY split (Option A).
--          This package contains NO dynamic SQL and names NO TFM table.
--
-- HEADER PAGING (owner decision 2026-10-09, design section 5 "Reconciliation
-- fetches page on header boundaries"; backlog #224, #680). A report returns an
-- optional tenth column PAGE_KEY: the key of the header (document) each row
-- belongs to. When the rows of a page carry PAGE_KEY, the page is a set of
-- whole documents, never a slice of one:
--   * P_CHUNK_SIZE counts HEADERS, not rows: the report returns the next
--     P_CHUNK_SIZE header keys after P_AFTER_KEY plus EVERY line, distribution
--     and child row of those headers, however many there are.
--   * P_AFTER_KEY is the last PAGE_KEY received (header keyset).
--   * A page is the last page when it holds fewer than P_CHUNK_SIZE headers.
-- A report without PAGE_KEY is single-grain (each record is its own header):
-- its cursor is the last RECORD_KEY and a page is the last page when it holds
-- fewer than P_CHUNK_SIZE rows.
-- There is NO page-count cap (the cap derived from p_row_cap is retired; the
-- argument is ignored). The only loop guard is the runaway check in
-- ACCEPT_PAGE: a page whose first key is not greater than the cursor it was
-- given, or a full page that yields no next key, raises an error, so the fetch
-- fails loudly with an empty result. It never returns a partial set as success.
--
-- Transport and parse are separate (design section 7, offline-testable
-- seams): FETCH_ROWS does the BIP transport, ACCEPT_PAGE parses one page and
-- decides the next cursor, and is unit-tested offline
-- (test/unit/test_recon_fetch_paging.sql).
--
-- REVISIONS:
--   2026-10-09  BM  Optional PAGE_KEY header paging (backlog #224).
--   2026-10-09  BM  Page cap retired, no-progress guard raises for both
--                   keysets, page parse split into ACCEPT_PAGE (backlog #680).
-- ============================================================

    -- --------------------------------------------------------
    -- ACCEPT_PAGE - parse one report page into x_rows and decide the cursor.
    -- Procedure per the procedures-only rule: outcome via x_error_code; the
    -- runaway check raises inside and is reported through x_error_code.
    -- --------------------------------------------------------
    PROCEDURE ACCEPT_PAGE (
        p_page_xml    IN            XMLTYPE,
        p_chunk_size  IN            NUMBER,
        p_after_key   IN            VARCHAR2,
        x_rows        IN OUT NOCOPY T_RECON_TBL,
        x_next_key    OUT           VARCHAR2,
        x_last_page   OUT           VARCHAR2,
        x_error_code  OUT           NUMBER,
        p_run_id      IN            NUMBER   DEFAULT NULL,
        p_cemli_code  IN            VARCHAR2 DEFAULT NULL,
        p_page_no     IN            NUMBER   DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'ACCEPT_PAGE';
        l_step           VARCHAR2(500);
        l_n              PLS_INTEGER;
        l_page_rows      PLS_INTEGER := 0;
        l_page_headers   PLS_INTEGER := 0;
        l_first_key      VARCHAR2(1000);
        l_last_key       VARCHAR2(1000);
        l_first_page_key VARCHAR2(1000);
        l_last_page_key  VARCHAR2(1000);
        l_cursor_first   VARCHAR2(1000);
        l_advanced       PLS_INTEGER;
    BEGIN
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven
        x_next_key   := NULL;
        x_last_page  := 'Y';
        l_n          := x_rows.COUNT;

        -- Parse this page's contract columns into the collection. Backlog #65:
        -- DMT_REFERENCE (Slot C DFF, tier 2) and SOURCE_REF (business key, tier 3)
        -- are parsed too; a DM that does not emit a node yields NULL for it.
        -- Header-paged rows group by their header first, in the BINARY order the
        -- report pages by; for a report without PAGE_KEY every value is NULL and
        -- the order is RECORD_KEY (BINARY).
        l_step := 'parsing report page ' || NVL(TO_CHAR(p_page_no), '?');
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
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_page_xml
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
                    page_key        VARCHAR2(1000) PATH 'PAGE_KEY'
            ) x
            ORDER BY NLSSORT(x.page_key, 'NLS_SORT=BINARY') NULLS FIRST,
                     NLSSORT(x.record_key, 'NLS_SORT=BINARY')
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
            x_rows(l_n).business_key    := r.source_ref;     -- tier 3
            l_page_rows := l_page_rows + 1;
            IF l_page_rows = 1 THEN
                l_first_key := r.record_key;
            END IF;
            l_last_key := r.record_key;
            -- Rows arrive grouped by PAGE_KEY, so a change of value is a new header.
            IF r.page_key IS NOT NULL
               AND (l_last_page_key IS NULL OR r.page_key <> l_last_page_key) THEN
                l_page_headers   := l_page_headers + 1;
                l_last_page_key  := r.page_key;
                l_first_page_key := NVL(l_first_page_key, r.page_key);
            END IF;
        END LOOP;

        -- The cursor is the header key when the page carries PAGE_KEY, else the
        -- row key (a single-grain report: each record is its own header).
        IF l_page_headers > 0 THEN
            l_cursor_first := l_first_page_key;
            x_next_key     := l_last_page_key;
            x_last_page    := CASE WHEN l_page_headers < p_chunk_size THEN 'Y' ELSE 'N' END;
        ELSE
            l_cursor_first := l_first_key;
            x_next_key     := l_last_key;
            x_last_page    := CASE WHEN l_page_rows < p_chunk_size THEN 'Y' ELSE 'N' END;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' page ' || NVL(TO_CHAR(p_page_no), '?') || ': rows '
                           || l_page_rows ||
                           CASE WHEN l_page_headers > 0
                                THEN ' | headers ' || l_page_headers ||
                                     ' | lastPageKey ' || l_last_page_key
                                ELSE ' | lastKey ' || NVL(l_last_key, '(none)') END,
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- Runaway check (design section 5, decided 2026-10-09): a page must start
        -- after the cursor it was given, in the BINARY order the reports page by.
        -- If it does not, the report is not advancing; fail loudly.
        l_step := 'checking that page ' || NVL(TO_CHAR(p_page_no), '?')
                  || ' advanced past cursor ' || p_after_key;
        IF p_after_key IS NOT NULL AND l_page_rows > 0 THEN
            SELECT CASE WHEN l_cursor_first IS NOT NULL
                         AND NLSSORT(l_cursor_first, 'NLS_SORT=BINARY')
                             > NLSSORT(p_after_key, 'NLS_SORT=BINARY')
                        THEN 1 ELSE 0 END
            INTO   l_advanced
            FROM   dual;
            IF l_advanced = 0 THEN
                RAISE_APPLICATION_ERROR(-20681,
                    'Reconciliation fetch for ' || NVL(p_cemli_code, '(unknown CEMLI)')
                    || ' is not advancing: page ' || NVL(TO_CHAR(p_page_no), '?')
                    || ' starts at ' || CASE WHEN l_page_headers > 0 THEN 'header key '
                                             ELSE 'record key ' END
                    || NVL(l_cursor_first, '(null)') || ', which is not after the cursor '
                    || p_after_key || '. The report does not page; the fetch is stopped '
                    || 'and returns no rows.');
            END IF;
        END IF;

        -- A full page must hand back a key to continue from; a NULL key would
        -- restart the report from the beginning and loop forever.
        IF x_last_page = 'N' AND x_next_key IS NULL THEN
            RAISE_APPLICATION_ERROR(-20681,
                'Reconciliation fetch for ' || NVL(p_cemli_code, '(unknown CEMLI)')
                || ' is not advancing: page ' || NVL(TO_CHAR(p_page_no), '?')
                || ' is full but its last key is empty, so there is no cursor to continue '
                || 'from. The fetch is stopped and returns no rows.');
        END IF;

        x_error_code := DMT_UTIL_PKG.C_SUCCESS;

    EXCEPTION
        WHEN OTHERS THEN
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            x_next_key   := NULL;
            x_last_page  := 'Y';
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed for CEMLI ' || NVL(p_cemli_code, '(unknown)')
                               || ' while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END ACCEPT_PAGE;

    -- --------------------------------------------------------
    -- FETCH_ROWS - run the object's Contract v1 report and return its parsed rows.
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
        l_step          VARCHAR2(500);
        l_contract_ver  NUMBER;
        l_prefix        VARCHAR2(30);
        l_chunk_size    NUMBER;
        l_after_key     VARCHAR2(1000) := NULL;
        l_next_key      VARCHAR2(1000);
        l_last_page     VARCHAR2(1);
        l_xml           XMLTYPE;
        l_err           NUMBER;
        l_page          PLS_INTEGER := 0;
        l_batch_param   VARCHAR2(100);
    BEGIN
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        -- Registry: the object must be Contract v1. Only the CONTRACT_VERSION is
        -- read here (plus PREFIX from the run); the report catalog path is
        -- resolved inside RUN_BIP_REPORT from DMT_BIP_REPORT_TBL. This package
        -- never reads TFM_TABLE / FUSION_ID_COLUMN and never builds SQL from them.
        l_step := 'reading the registry row of ' || p_cemli_code;
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

        -- Run prefix (Contract v1 P_PREFIX) and page size (headers per page for a
        -- header-paged report, rows per page for a single-grain one).
        l_step := 'reading the run prefix and BIP_CHUNK_SIZE';
        SELECT PREFIX INTO l_prefix FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
        l_chunk_size := TO_NUMBER(NVL(DMT_UTIL_PKG.GET_CONFIG('BIP_CHUNK_SIZE'), '5000'));

        -- Optional Fusion import batch id (Customers): sent only when given, so the
        -- report call of every object that does not pass it stays byte-identical.
        IF p_fusion_batch_id IS NOT NULL THEN
            l_batch_param := C_SEP || 'P_FUSION_BATCH_ID|' || TO_CHAR(p_fusion_batch_id, 'TM9');
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' start. CEMLI: ' || p_cemli_code ||
                           ' | ChunkSize: ' || l_chunk_size ||
                           ' | LoadReqId: ' || NVL(TO_CHAR(p_load_ess_id), '(null)') ||
                           CASE WHEN p_fusion_batch_id IS NOT NULL
                                THEN ' | FusionBatchId: ' || TO_CHAR(p_fusion_batch_id, 'TM9') END,
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- Keyset pagination loop (design section 5): first call with an empty
        -- cursor; each next call passes the cursor ACCEPT_PAGE returned (the last
        -- header key, or the last row key for a single-grain report); stop on the
        -- last page. No page-count cap: ACCEPT_PAGE stops a report that does not
        -- advance.
        LOOP
            l_page := l_page + 1;

            l_step := 'running the report for page ' || l_page;
            DMT_UTIL_PKG.RUN_BIP_REPORT(
                p_run_id     => p_run_id,
                p_cemli_code => p_cemli_code,
                -- Pairs are joined by DMT_UTIL_PKG.C_BIP_PARAM_SEP, not '~':
                -- from page 2 P_AFTER_KEY is the last key received, and
                -- several reports build keys with '~' (Customers
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
                x_rows.DELETE;
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

            l_step := 'accepting page ' || l_page;
            ACCEPT_PAGE(
                p_page_xml   => l_xml,
                p_chunk_size => l_chunk_size,
                p_after_key  => l_after_key,
                x_rows       => x_rows,
                x_next_key   => l_next_key,
                x_last_page  => l_last_page,
                x_error_code => l_err,
                p_run_id     => p_run_id,
                p_cemli_code => p_cemli_code,
                p_page_no    => l_page);

            -- The report did not advance (ACCEPT_PAGE logged the ERROR with the
            -- keys): fail loudly with an empty result, never a partial set.
            IF l_err <> DMT_UTIL_PKG.C_SUCCESS THEN
                x_rows.DELETE;
                x_error_code := DMT_UTIL_PKG.C_ERROR;
                RETURN;
            END IF;

            EXIT WHEN l_last_page = 'Y';
            l_after_key := l_next_key;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. CEMLI: ' || p_cemli_code ||
                           ' | pages ' || l_page || ' | rows ' || x_rows.COUNT,
            p_package   => C_PKG,
            p_procedure => C_PROC);

        x_error_code := DMT_UTIL_PKG.C_SUCCESS;

    EXCEPTION
        WHEN OTHERS THEN
            x_rows.DELETE;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed for CEMLI ' || p_cemli_code
                               || ' while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END FETCH_ROWS;

END DMT_RECON_CONTRACT_PKG;
/
