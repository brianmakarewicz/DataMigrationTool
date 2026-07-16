-- PACKAGE BODY DMT_CSV_UPLOAD_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CSV_UPLOAD_PKG" 
AS
-- ============================================================
-- DMT_CSV_UPLOAD_PKG body
--
-- Two loading modes:
--   FAST (default): APEX_DATA_PARSER.PARSE returns a pipelined
--     table (COL001..COL300). We read the header row to build a
--     CSV-position → DB-column map, then execute a single
--     INSERT INTO staging SELECT COLnnn FROM TABLE(PARSE(...)).
--     No PL/SQL loop, no DBMS_SQL. Handles 500K+ rows.
--
--   LEGACY: PL/SQL character-by-character CLOB scan with
--     DBMS_SQL row-by-row INSERT. Per-row error handling.
--     Use for debugging or when APEX_DATA_PARSER is unavailable.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_CSV_UPLOAD_PKG';

    -- --------------------------------------------------------
    -- Type for column mapping: CSV header index -> DB column
    -- --------------------------------------------------------
    TYPE t_col_map_rec IS RECORD (
        csv_index    PLS_INTEGER,
        column_name  VARCHAR2(128)
    );
    TYPE t_col_map_tab IS TABLE OF t_col_map_rec INDEX BY PLS_INTEGER;

    -- ============================================================
    -- SHARED HELPERS
    -- ============================================================

    -- --------------------------------------------------------
    -- Log a per-row error to DMT_UPLOAD_ERROR_TBL
    -- Uses autonomous transaction
    -- --------------------------------------------------------
    PROCEDURE log_row_error (
        p_log_id        IN NUMBER,
        p_row_number    IN NUMBER,
        p_column_name   IN VARCHAR2,
        p_error_type    IN VARCHAR2,
        p_error_message IN VARCHAR2,
        p_raw_value     IN VARCHAR2 DEFAULT NULL,
        p_batch_tag     IN VARCHAR2 DEFAULT NULL
    )
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO DMT_UPLOAD_ERROR_TBL (
            LOG_ID, ROW_NUMBER, COLUMN_NAME, ERROR_TYPE, ERROR_MESSAGE, RAW_VALUE, BATCH_TAG
        ) VALUES (
            p_log_id, p_row_number, p_column_name, p_error_type, p_error_message, p_raw_value, p_batch_tag
        );
        COMMIT;
    END log_row_error;

    -- Forward declaration (parse_fields defined in LEGACY section below)
    PROCEDURE parse_fields (
        p_line   IN  VARCHAR2,
        p_fields OUT DBMS_SQL.VARCHAR2_TABLE,
        p_count  OUT PLS_INTEGER
    );

    -- --------------------------------------------------------
    -- Read header row from BLOB to get CSV column names.
    -- Uses lightweight CLOB conversion of just the first line
    -- (not the whole file), then the legacy parse_fields on
    -- that one line. Fast for any file size.
    -- --------------------------------------------------------
    PROCEDURE read_csv_headers (
        p_blob         IN  BLOB,
        p_headers      OUT DBMS_SQL.VARCHAR2_TABLE,
        p_header_count OUT PLS_INTEGER,
        p_error_msg    OUT VARCHAR2
    )
    IS
        l_raw       RAW(32767);
        l_line      VARCHAR2(32767);
        l_blob_len  NUMBER;
        l_read_len  NUMBER;
        l_nl_pos    PLS_INTEGER;
    BEGIN
        p_header_count := 0;
        l_blob_len := DBMS_LOB.GETLENGTH(p_blob);
        IF l_blob_len = 0 THEN
            p_error_msg := 'File is empty.';
            RETURN;
        END IF;

        -- Read first 32K of the BLOB (more than enough for a header row)
        l_read_len := LEAST(l_blob_len, 32767);
        l_raw := DBMS_LOB.SUBSTR(p_blob, l_read_len, 1);

        -- Skip UTF-8 BOM if present
        IF l_read_len >= 3 AND DBMS_LOB.SUBSTR(p_blob, 3, 1) = HEXTORAW('EFBBBF') THEN
            l_raw := DBMS_LOB.SUBSTR(p_blob, l_read_len - 3, 4);
        END IF;

        l_line := UTL_RAW.CAST_TO_VARCHAR2(l_raw);

        -- Trim to first line (LF or CRLF)
        l_nl_pos := INSTR(l_line, CHR(10));
        IF l_nl_pos > 0 THEN
            l_line := SUBSTR(l_line, 1, l_nl_pos - 1);
        END IF;
        -- Strip trailing CR
        IF SUBSTR(l_line, -1) = CHR(13) THEN
            l_line := SUBSTR(l_line, 1, LENGTH(l_line) - 1);
        END IF;

        -- Parse the header line using the existing field parser
        parse_fields(l_line, p_headers, p_header_count);

        -- Uppercase all headers
        FOR i IN 1 .. p_header_count LOOP
            p_headers(i) := UPPER(TRIM(p_headers(i)));
        END LOOP;

        IF p_header_count = 0 THEN
            p_error_msg := 'Could not read CSV headers.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            p_error_msg := 'Header parse failed: ' || SQLERRM;
    END read_csv_headers;

    -- ============================================================
    -- DML ERROR LOG HELPER
    -- Lazily creates ERR$_<staging_table> via DBMS_ERRLOG if it
    -- does not already exist. Called once per object on first upload.
    -- ============================================================
    PROCEDURE ensure_err_log_table (
        p_staging_table IN VARCHAR2
    )
    IS
        l_err_table VARCHAR2(128) := 'ERR$_' || p_staging_table;
        l_cnt       PLS_INTEGER;
        l_ddl       VARCHAR2(32767);
        l_col_list  VARCHAR2(32767);
    BEGIN
        SELECT COUNT(*) INTO l_cnt
        FROM   user_tables
        WHERE  table_name = l_err_table;

        IF l_cnt = 0 THEN
            -- Build column list: standard ORA_ERR columns + all non-LOB source columns as VARCHAR2
            l_col_list := 'ORA_ERR_NUMBER$ NUMBER, '
                       || 'ORA_ERR_MESG$ VARCHAR2(2000), '
                       || 'ORA_ERR_ROWID$ UROWID, '
                       || 'ORA_ERR_OPTYP$ VARCHAR2(2), '
                       || 'ORA_ERR_TAG$ VARCHAR2(2000)';

            FOR c IN (
                SELECT column_name
                FROM   user_tab_columns
                WHERE  table_name = p_staging_table
                AND    data_type NOT IN ('CLOB', 'BLOB', 'NCLOB', 'LONG', 'LONG RAW')
                ORDER  BY column_id
            ) LOOP
                l_col_list := l_col_list || ', '
                           || DBMS_ASSERT.SIMPLE_SQL_NAME(c.column_name) || ' VARCHAR2(4000)';
            END LOOP;

            l_ddl := 'CREATE TABLE ' || l_err_table || ' (' || l_col_list || ')';
            EXECUTE IMMEDIATE l_ddl;
        END IF;
    END ensure_err_log_table;

    -- ============================================================
    -- FAST LOADER: APEX_DATA_PARSER path
    -- Single INSERT...SELECT with LOG ERRORS INTO for per-row
    -- error capture. Good rows commit; bad rows land in
    -- ERR$_<staging_table> and get copied to DMT_UPLOAD_ERROR_TBL.
    -- ============================================================
    PROCEDURE fast_load_from_blob (
        p_blob          IN  BLOB,
        p_file_label    IN  VARCHAR2,
        p_object_code   IN  VARCHAR2,
        p_staging_table IN  VARCHAR2,
        p_batch_id      IN  NUMBER,
        p_log_id        IN  NUMBER,
        p_rows_loaded   OUT NUMBER,
        p_rows_errored  OUT NUMBER,
        p_error_msg     OUT VARCHAR2,
        p_batch_tag     IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_headers      DBMS_SQL.VARCHAR2_TABLE;
        l_header_count PLS_INTEGER;
        l_hdr_error    VARCHAR2(4000);

        -- Valid (non-admin, non-LOB) columns for this object
        TYPE t_valid_cols IS TABLE OF VARCHAR2(128) INDEX BY VARCHAR2(128);
        l_valid_cols   t_valid_cols;

        l_col_list     VARCHAR2(32767);
        l_select_list  VARCHAR2(32767);
        l_map_count    PLS_INTEGER := 0;
        l_warnings     VARCHAR2(4000);
        l_sql          VARCHAR2(32767);
        l_col_key      VARCHAR2(128);
        l_err_table    VARCHAR2(128);
        l_err_count    PLS_INTEGER := 0;
    BEGIN
        p_rows_loaded  := 0;
        p_rows_errored := 0;

        -- Load valid columns: non-admin AND non-LOB (LOG ERRORS INTO can't handle CLOBs).
        -- SOURCE_ID is marked admin in the dictionary (it defaults to NULL and is
        -- otherwise pipeline-managed) but it is a real source natural key, so it
        -- is honoured when a CSV supplies it (mirrors the regression seed, which
        -- populates SOURCE_ID on every staging row).
        FOR c IN (
            SELECT UPPER(d.COLUMN_NAME) AS COLUMN_NAME
            FROM   DMT_UPLOAD_DICT_TBL d
            JOIN   user_tab_columns tc
                   ON tc.table_name  = p_staging_table
                   AND tc.column_name = UPPER(d.COLUMN_NAME)
            WHERE  d.OBJECT_CODE    = p_object_code
            AND    (d.IS_ADMIN_COLUMN = 'N' OR UPPER(d.COLUMN_NAME) = 'SOURCE_ID')
            AND    tc.data_type NOT IN ('CLOB', 'BLOB', 'NCLOB', 'LONG')
        ) LOOP
            l_valid_cols(c.COLUMN_NAME) := c.COLUMN_NAME;
        END LOOP;

        -- Read headers from first row of CSV
        read_csv_headers(p_blob, l_headers, l_header_count, l_hdr_error);
        IF l_hdr_error IS NOT NULL THEN
            p_error_msg := l_hdr_error;
            RETURN;
        END IF;

        -- Build column mapping: CSV position (COLnnn) -> staging column name
        FOR i IN 1 .. l_header_count LOOP
            l_col_key := l_headers(i);

            IF l_col_key IS NOT NULL AND l_valid_cols.EXISTS(l_col_key) THEN
                l_map_count := l_map_count + 1;

                IF l_col_list IS NOT NULL THEN
                    l_col_list    := l_col_list    || ', ';
                    l_select_list := l_select_list || ', ';
                END IF;
                l_col_list    := l_col_list    || DBMS_ASSERT.SIMPLE_SQL_NAME(l_col_key);
                l_select_list := l_select_list || 'COL' || LPAD(i, 3, '0');
            ELSIF l_col_key IS NOT NULL THEN
                l_warnings := l_warnings || 'Column "' || l_col_key || '" skipped. ';
            END IF;
        END LOOP;

        IF l_map_count = 0 THEN
            p_error_msg := 'No CSV headers matched uploadable columns for ' || p_object_code || '. ' || l_warnings;
            RETURN;
        END IF;

        -- Ensure DML error log table exists for this staging table
        l_err_table := 'ERR$_' || p_staging_table;
        ensure_err_log_table(p_staging_table);

        -- Build INSERT...SELECT with LOG ERRORS INTO.
        -- Good rows insert normally; bad rows (type conversion, constraint
        -- violations) are captured in ERR$_<table> instead of failing the batch.
        l_sql := 'INSERT INTO ' || p_staging_table ||
                 ' (' || l_col_list || ')' ||
                 ' SELECT ' || l_select_list ||
                 ' FROM TABLE(APEX_DATA_PARSER.PARSE(' ||
                 '   p_content   => :blob,' ||
                 '   p_file_name => ''upload.csv'',' ||
                 '   p_skip_rows => 1))' ||
                 ' LOG ERRORS INTO ' || l_err_table ||
                 ' (''' || p_log_id || ''') REJECT LIMIT UNLIMITED';

        DMT_UTIL_PKG.LOG(
            p_message   => 'Fast loader: executing INSERT...SELECT for ' || p_object_code
                           || ' (' || l_map_count || ' columns mapped)',
            p_package   => C_PKG,
            p_procedure => 'fast_load_from_blob'
        );

        EXECUTE IMMEDIATE l_sql USING p_blob;
        p_rows_loaded := SQL%ROWCOUNT;
        COMMIT;

        -- Check for rejected rows in the DML error log
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || l_err_table ||
            ' WHERE ORA_ERR_TAG$ = :tag'
            INTO l_err_count
            USING TO_CHAR(p_log_id);

        IF l_err_count > 0 THEN
            p_rows_errored := l_err_count;

            -- Copy per-row errors into DMT_UPLOAD_ERROR_TBL for the UI
            EXECUTE IMMEDIATE
                'INSERT INTO DMT_UPLOAD_ERROR_TBL '
             || '  (LOG_ID, ROW_NUMBER, COLUMN_NAME, ERROR_TYPE, ERROR_MESSAGE, RAW_VALUE, BATCH_TAG) '
             || 'SELECT :log_id, ROWNUM, NULL, '
             || '  ''FAST_LOADER (ORA-'' || ORA_ERR_NUMBER$ || '')'', '
             || '  SUBSTR(ORA_ERR_MESG$, 1, 4000), '
             || '  ORA_ERR_TAG$, '
             || '  :batch_tag '
             || 'FROM ' || l_err_table
             || ' WHERE ORA_ERR_TAG$ = :tag'
                USING p_log_id, p_batch_tag, TO_CHAR(p_log_id);
            COMMIT;

            -- Clean up the DML error log for this batch
            EXECUTE IMMEDIATE
                'DELETE FROM ' || l_err_table || ' WHERE ORA_ERR_TAG$ = :tag'
                USING TO_CHAR(p_log_id);
            COMMIT;

            p_error_msg := p_rows_loaded || ' loaded, ' || l_err_count
                        || ' rejected. Filter Upload Errors by Load ID: ' || p_batch_tag;
        END IF;

        -- Any warnings about skipped columns
        IF l_warnings IS NOT NULL THEN
            p_error_msg := NVL(p_error_msg, '') || ' ' || l_warnings;
            UPDATE DMT_UPLOAD_LOG_TBL
            SET    ERROR_MSG = l_warnings
            WHERE  LOG_ID = p_log_id;
            COMMIT;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_message   => 'Fast loader complete: ' || p_rows_loaded || ' rows inserted, '
                           || l_err_count || ' rejected for ' || p_object_code,
            p_package   => C_PKG,
            p_procedure => 'fast_load_from_blob'
        );

    EXCEPTION
        WHEN OTHERS THEN
            -- Structural errors (bad SQL, missing table, etc.) still caught here.
            -- Log to error table so it's visible in the UI too.
            log_row_error(
                p_log_id        => p_log_id,
                p_row_number    => -1,
                p_column_name   => NULL,
                p_error_type    => 'FAST_LOADER',
                p_error_message => SUBSTR('Fast loader failed for ' || p_object_code || ': ' || SQLERRM, 1, 4000),
                p_raw_value     => SUBSTR(l_sql, 1, 4000),
                p_batch_tag     => p_batch_tag
            );
            p_error_msg := 'Fast loader failed: ' || SQLERRM
                        || ' (Load ID: ' || p_batch_tag || ')';
            p_rows_errored := 1;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'Fast loader failed for ' || p_object_code || '. SQL: ' || SUBSTR(l_sql, 1, 500),
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => 'fast_load_from_blob'
            );
    END fast_load_from_blob;

    -- ============================================================
    -- LEGACY HELPERS (row-by-row path)
    -- ============================================================

    FUNCTION blob_to_clob (p_blob IN BLOB) RETURN CLOB
    IS
        l_clob    CLOB;
        l_dest_offset  PLS_INTEGER := 1;
        l_src_offset   PLS_INTEGER := 1;
        l_lang_ctx     PLS_INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      PLS_INTEGER;
        l_blob_len     PLS_INTEGER;
        l_bom          RAW(3);
    BEGIN
        IF p_blob IS NULL OR DBMS_LOB.GETLENGTH(p_blob) = 0 THEN
            RETURN NULL;
        END IF;
        l_blob_len := DBMS_LOB.GETLENGTH(p_blob);
        IF l_blob_len >= 3 THEN
            l_bom := DBMS_LOB.SUBSTR(p_blob, 3, 1);
            IF l_bom = HEXTORAW('EFBBBF') THEN
                l_src_offset := 4;
            END IF;
        END IF;
        DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
        DBMS_LOB.CONVERTTOCLOB(
            dest_lob => l_clob, src_blob => p_blob,
            amount => DBMS_LOB.LOBMAXSIZE, dest_offset => l_dest_offset,
            src_offset => l_src_offset, blob_csid => NLS_CHARSET_ID('AL32UTF8'),
            lang_context => l_lang_ctx, warning => l_warning);
        RETURN l_clob;
    END blob_to_clob;

    PROCEDURE parse_fields (
        p_line   IN  VARCHAR2,
        p_fields OUT DBMS_SQL.VARCHAR2_TABLE,
        p_count  OUT PLS_INTEGER
    ) IS
        l_pos PLS_INTEGER := 1; l_len PLS_INTEGER; l_char VARCHAR2(1);
        l_field VARCHAR2(32767); l_in_quotes BOOLEAN := FALSE; l_idx PLS_INTEGER := 0;
    BEGIN
        l_len := NVL(LENGTH(p_line), 0); l_field := NULL;
        WHILE l_pos <= l_len LOOP
            l_char := SUBSTR(p_line, l_pos, 1);
            IF l_in_quotes THEN
                IF l_char = '"' THEN
                    IF l_pos < l_len AND SUBSTR(p_line, l_pos+1, 1) = '"' THEN
                        l_field := l_field || '"'; l_pos := l_pos + 1;
                    ELSE l_in_quotes := FALSE; END IF;
                ELSE l_field := l_field || l_char; END IF;
            ELSE
                IF l_char = '"' THEN l_in_quotes := TRUE;
                ELSIF l_char = ',' THEN
                    l_idx := l_idx + 1; p_fields(l_idx) := TRIM(l_field); l_field := NULL;
                ELSE l_field := l_field || l_char; END IF;
            END IF;
            l_pos := l_pos + 1;
        END LOOP;
        l_idx := l_idx + 1; p_fields(l_idx) := TRIM(l_field); p_count := l_idx;
    END parse_fields;

    FUNCTION next_line (p_clob IN CLOB, p_offset IN OUT NUMBER) RETURN VARCHAR2 IS
        l_len NUMBER; l_start NUMBER; l_pos NUMBER;
        l_char VARCHAR2(1); l_in_quotes BOOLEAN := FALSE;
    BEGIN
        l_len := DBMS_LOB.GETLENGTH(p_clob);
        IF p_offset > l_len THEN RETURN NULL; END IF;
        l_start := p_offset; l_pos := p_offset;
        WHILE l_pos <= l_len LOOP
            l_char := DBMS_LOB.SUBSTR(p_clob, 1, l_pos);
            IF l_char = '"' THEN l_in_quotes := NOT l_in_quotes; END IF;
            IF NOT l_in_quotes THEN
                IF l_char = CHR(13) THEN
                    IF l_pos < l_len AND DBMS_LOB.SUBSTR(p_clob, 1, l_pos+1) = CHR(10) THEN
                        p_offset := l_pos + 2;
                    ELSE p_offset := l_pos + 1; END IF;
                    RETURN DBMS_LOB.SUBSTR(p_clob, l_pos - l_start, l_start);
                ELSIF l_char = CHR(10) THEN
                    p_offset := l_pos + 1;
                    RETURN DBMS_LOB.SUBSTR(p_clob, l_pos - l_start, l_start);
                END IF;
            END IF;
            l_pos := l_pos + 1;
        END LOOP;
        p_offset := l_len + 1;
        RETURN DBMS_LOB.SUBSTR(p_clob, l_len - l_start + 1, l_start);
    END next_line;

    -- --------------------------------------------------------
    -- LEGACY LOADER: PL/SQL row-by-row path
    -- --------------------------------------------------------
    PROCEDURE legacy_load_from_blob (
        p_blob          IN  BLOB,
        p_file_label    IN  VARCHAR2,
        p_object_code   IN  VARCHAR2,
        p_staging_table IN  VARCHAR2,
        p_batch_id      IN  NUMBER,
        p_log_id        IN  NUMBER,
        p_rows_loaded   OUT NUMBER,
        p_rows_errored  OUT NUMBER,
        p_error_msg     OUT VARCHAR2
    )
    IS
        l_clob          CLOB;
        l_offset        NUMBER := 1;
        l_line          VARCHAR2(32767);
        l_row_num       PLS_INTEGER := 0;
        l_headers       DBMS_SQL.VARCHAR2_TABLE;
        l_header_count  PLS_INTEGER;
        l_fields        DBMS_SQL.VARCHAR2_TABLE;
        l_field_count   PLS_INTEGER;
        l_col_map       t_col_map_tab;
        l_map_count     PLS_INTEGER := 0;
        TYPE t_valid_cols IS TABLE OF VARCHAR2(128) INDEX BY VARCHAR2(128);
        l_valid_cols    t_valid_cols;
        l_col_key       VARCHAR2(128);
        l_sql           VARCHAR2(32767);
        l_col_list      VARCHAR2(32767);
        l_bind_list     VARCHAR2(32767);
        l_cursor        INTEGER := 0;
        l_result        INTEGER;
        l_warnings      VARCHAR2(4000);
    BEGIN
        p_rows_loaded  := 0;
        p_rows_errored := 0;

        l_clob := blob_to_clob(p_blob);
        IF l_clob IS NULL OR DBMS_LOB.GETLENGTH(l_clob) = 0 THEN
            p_error_msg := 'File is empty.';
            RETURN;
        END IF;

        -- SOURCE_ID is admin in the dictionary but is a real source key: honour
        -- it when the CSV supplies it (same rule as the fast loader above).
        FOR c IN (
            SELECT UPPER(COLUMN_NAME) AS COLUMN_NAME
            FROM   DMT_UPLOAD_DICT_TBL
            WHERE  OBJECT_CODE = p_object_code
            AND    (IS_ADMIN_COLUMN = 'N' OR UPPER(COLUMN_NAME) = 'SOURCE_ID')
        ) LOOP
            l_valid_cols(c.COLUMN_NAME) := c.COLUMN_NAME;
        END LOOP;

        l_line := next_line(l_clob, l_offset);
        IF l_line IS NULL THEN
            p_error_msg := 'File contains no data.';
            DBMS_LOB.FREETEMPORARY(l_clob);
            RETURN;
        END IF;

        parse_fields(l_line, l_headers, l_header_count);

        FOR i IN 1 .. l_header_count LOOP
            l_col_key := UPPER(TRIM(l_headers(i)));
            IF l_col_key IS NOT NULL AND l_valid_cols.EXISTS(l_col_key) THEN
                l_map_count := l_map_count + 1;
                l_col_map(l_map_count).csv_index   := i;
                l_col_map(l_map_count).column_name := DBMS_ASSERT.SIMPLE_SQL_NAME(l_col_key);
                IF l_col_list IS NOT NULL THEN
                    l_col_list  := l_col_list  || ', ';
                    l_bind_list := l_bind_list || ', ';
                END IF;
                l_col_list  := l_col_list  || l_col_map(l_map_count).column_name;
                l_bind_list := l_bind_list || ':b' || l_map_count;
            ELSIF l_col_key IS NOT NULL THEN
                l_warnings := l_warnings || 'Column "' || l_headers(i) || '" skipped. ';
            END IF;
        END LOOP;

        IF l_map_count = 0 THEN
            p_error_msg := 'No CSV headers matched uploadable columns for ' || p_object_code || '. ' || l_warnings;
            DBMS_LOB.FREETEMPORARY(l_clob);
            RETURN;
        END IF;

        l_sql := 'INSERT INTO ' || p_staging_table
                 || ' (' || l_col_list || ') VALUES (' || l_bind_list || ')';

        l_cursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor, l_sql, DBMS_SQL.NATIVE);

        LOOP
            l_line := next_line(l_clob, l_offset);
            EXIT WHEN l_line IS NULL;
            IF TRIM(l_line) IS NULL THEN CONTINUE; END IF;
            l_row_num := l_row_num + 1;
            BEGIN
                parse_fields(l_line, l_fields, l_field_count);
                FOR m IN 1 .. l_map_count LOOP
                    IF l_col_map(m).csv_index <= l_field_count THEN
                        DBMS_SQL.BIND_VARIABLE(l_cursor, ':b' || m,
                            l_fields(l_col_map(m).csv_index));
                    ELSE
                        DBMS_SQL.BIND_VARIABLE(l_cursor, ':b' || m, CAST(NULL AS VARCHAR2));
                    END IF;
                END LOOP;
                l_result := DBMS_SQL.EXECUTE(l_cursor);
                p_rows_loaded := p_rows_loaded + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    p_rows_errored := p_rows_errored + 1;
                    log_row_error(p_log_id, l_row_num, NULL, 'INSERT_FAILED',
                        SQLERRM, SUBSTR(l_line, 1, 4000));
            END;
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(l_cursor);
        l_cursor := 0;
        COMMIT;

        IF l_warnings IS NOT NULL THEN
            UPDATE DMT_UPLOAD_LOG_TBL SET ERROR_MSG = l_warnings WHERE LOG_ID = p_log_id;
            COMMIT;
        END IF;

        DBMS_LOB.FREETEMPORARY(l_clob);

        IF p_rows_errored > 0 THEN
            p_error_msg := p_rows_errored || ' of ' || l_row_num || ' rows had errors.';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF l_cursor IS NOT NULL AND l_cursor != 0 THEN
                BEGIN IF DBMS_SQL.IS_OPEN(l_cursor) THEN DBMS_SQL.CLOSE_CURSOR(l_cursor); END IF;
                EXCEPTION WHEN OTHERS THEN NULL; END;
            END IF;
            IF l_clob IS NOT NULL THEN
                BEGIN DBMS_LOB.FREETEMPORARY(l_clob); EXCEPTION WHEN OTHERS THEN NULL; END;
            END IF;
            p_error_msg := 'Legacy loader failed: ' || SQLERRM;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'Legacy loader failed for ' || p_object_code,
                p_sqlerrm => SQLERRM, p_package => C_PKG,
                p_procedure => 'legacy_load_from_blob');
    END legacy_load_from_blob;

    -- ============================================================
    -- UPLOAD_CSV_FROM_BLOB — core entry point
    -- Delegates to fast_load or legacy_load based on flag.
    -- ============================================================
    PROCEDURE UPLOAD_CSV_FROM_BLOB (
        p_blob            IN  BLOB,
        p_file_label      IN  VARCHAR2,
        p_object_code     IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_rows_loaded     OUT NUMBER,
        p_rows_errored    OUT NUMBER,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_staging_table  VARCHAR2(128);
        l_batch_id       NUMBER;
        l_log_id         NUMBER;
        l_scenario_id    NUMBER;
        l_scn_err        NUMBER;
        l_max_seq_before NUMBER;
        l_batch_tag      VARCHAR2(200);
    BEGIN
        p_rows_loaded  := 0;
        p_rows_errored := 0;
        p_error_msg    := NULL;

        -- Build human-readable batch tag: scenario~YYMMDDHH24MISS~filename
        l_batch_tag := NVL(p_scenario_name, 'none') || '~'
                    || TO_CHAR(SYSTIMESTAMP, 'YYMMDDHH24MISS') || '~'
                    || SUBSTR(p_file_label, GREATEST(INSTR(p_file_label, '/', -1), INSTR(p_file_label, '\', -1)) + 1);

        -- Get batch ID
        IF p_batch_id IS NOT NULL THEN
            l_batch_id := p_batch_id;
        ELSE
            SELECT DMT_UPLOAD_BATCH_SEQ.NEXTVAL INTO l_batch_id FROM DUAL;
        END IF;
        p_batch_id_out := l_batch_id;

        -- Validate BLOB
        IF p_blob IS NULL OR DBMS_LOB.GETLENGTH(p_blob) = 0 THEN
            p_error_msg := 'File is empty.';
            RETURN;
        END IF;

        -- Look up staging table
        BEGIN
            SELECT STAGING_TABLE INTO l_staging_table
            FROM   DMT_UPLOAD_OBJECT_TBL
            WHERE  OBJECT_CODE = p_object_code
            AND    IS_ACTIVE = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_error_msg := 'Unknown or inactive object code: ' || p_object_code;
                RETURN;
        END;
        l_staging_table := DBMS_ASSERT.SIMPLE_SQL_NAME(l_staging_table);

        -- Create upload log entry
        INSERT INTO DMT_UPLOAD_LOG_TBL (BATCH_ID, OBJECT_CODE, FILE_NAME, STATUS)
        VALUES (l_batch_id, p_object_code, p_file_label, 'PROCESSING')
        RETURNING LOG_ID INTO l_log_id;
        COMMIT;

        -- Resolve scenario (if provided)
        IF p_scenario_name IS NOT NULL THEN
            DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
                p_scenario_name => p_scenario_name,
                x_scenario_id   => l_scenario_id,
                x_error_code    => l_scn_err);
            IF l_scn_err != DMT_UTIL_PKG.C_SUCCESS THEN
                RAISE_APPLICATION_ERROR(-20115,
                    'GET_OR_CREATE_SCENARIO failed for scenario "' ||
                    p_scenario_name || '" (detail in DMT_LOG_TBL).');
            END IF;
        END IF;

        -- Capture max STG_SEQUENCE_ID before insert so we can tag new rows with scenario
        IF l_scenario_id IS NOT NULL THEN
            EXECUTE IMMEDIATE
                'SELECT NVL(MAX(STG_SEQUENCE_ID), 0) FROM ' || l_staging_table
                INTO l_max_seq_before;
        END IF;

        -- Delegate to fast or legacy loader
        IF p_use_fast_loader THEN
            fast_load_from_blob(
                p_blob          => p_blob,
                p_file_label    => p_file_label,
                p_object_code   => p_object_code,
                p_staging_table => l_staging_table,
                p_batch_id      => l_batch_id,
                p_log_id        => l_log_id,
                p_rows_loaded   => p_rows_loaded,
                p_rows_errored  => p_rows_errored,
                p_error_msg     => p_error_msg,
                p_batch_tag     => l_batch_tag
            );
        ELSE
            legacy_load_from_blob(
                p_blob          => p_blob,
                p_file_label    => p_file_label,
                p_object_code   => p_object_code,
                p_staging_table => l_staging_table,
                p_batch_id      => l_batch_id,
                p_log_id        => l_log_id,
                p_rows_loaded   => p_rows_loaded,
                p_rows_errored  => p_rows_errored,
                p_error_msg     => p_error_msg
            );
        END IF;

        -- Tag newly inserted rows with scenario ID
        IF l_scenario_id IS NOT NULL AND p_rows_loaded > 0 THEN
            EXECUTE IMMEDIATE
                'UPDATE ' || l_staging_table ||
                ' SET SCENARIO_ID = :sid WHERE STG_SEQUENCE_ID > :max_seq'
                USING l_scenario_id, l_max_seq_before;
            COMMIT;
        END IF;

        -- Update log entry
        UPDATE DMT_UPLOAD_LOG_TBL
        SET    ROWS_IN_FILE  = p_rows_loaded + p_rows_errored,
               ROWS_LOADED   = p_rows_loaded,
               ROWS_ERRORED  = p_rows_errored,
               STATUS        = CASE
                                   WHEN p_error_msg IS NOT NULL AND p_rows_loaded = 0 THEN 'FAILED'
                                   WHEN p_rows_errored > 0 THEN 'COMPLETED_WITH_ERRORS'
                                   ELSE 'COMPLETED'
                               END,
               ERROR_MSG     = NVL(ERROR_MSG, '') ||
                               CASE WHEN p_error_msg IS NOT NULL THEN p_error_msg ELSE '' END
        WHERE  LOG_ID = l_log_id;
        COMMIT;

        DMT_UTIL_PKG.LOG(
            p_message   => 'CSV upload complete for ' || p_object_code
                           || ' — mode: ' || CASE WHEN p_use_fast_loader THEN 'FAST' ELSE 'LEGACY' END
                           || ', loaded: ' || p_rows_loaded
                           || ', errored: ' || p_rows_errored
                           || ', batch: ' || l_batch_id,
            p_package   => C_PKG,
            p_procedure => 'UPLOAD_CSV_FROM_BLOB'
        );

    EXCEPTION
        WHEN OTHERS THEN
            p_error_msg := 'Upload failed: ' || SQLERRM;
            IF l_log_id IS NOT NULL THEN
                BEGIN
                    UPDATE DMT_UPLOAD_LOG_TBL
                    SET STATUS = 'FAILED', ERROR_MSG = SUBSTR(p_error_msg, 1, 4000)
                    WHERE LOG_ID = l_log_id;
                    COMMIT;
                EXCEPTION WHEN OTHERS THEN NULL;
                END;
            END IF;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'CSV upload failed for ' || p_object_code,
                p_sqlerrm => SQLERRM, p_package => C_PKG,
                p_procedure => 'UPLOAD_CSV_FROM_BLOB');
    END UPLOAD_CSV_FROM_BLOB;

    -- --------------------------------------------------------
    -- UPLOAD_CSV — reads from APEX_APPLICATION_TEMP_FILES
    -- --------------------------------------------------------
    PROCEDURE UPLOAD_CSV (
        p_file_name       IN  VARCHAR2,
        p_object_code     IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_rows_loaded     OUT NUMBER,
        p_rows_errored    OUT NUMBER,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_blob BLOB;
    BEGIN
        BEGIN
            SELECT BLOB_CONTENT INTO l_blob
            FROM   APEX_APPLICATION_TEMP_FILES
            WHERE  NAME = p_file_name;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_rows_loaded := 0; p_rows_errored := 0;
                p_batch_id_out := NULL;
                p_error_msg := 'File not found: ' || p_file_name;
                RETURN;
        END;

        UPLOAD_CSV_FROM_BLOB(
            p_blob            => l_blob,
            p_file_label      => p_file_name,
            p_object_code     => p_object_code,
            p_batch_id        => p_batch_id,
            p_rows_loaded     => p_rows_loaded,
            p_rows_errored    => p_rows_errored,
            p_batch_id_out    => p_batch_id_out,
            p_error_msg       => p_error_msg,
            p_use_fast_loader => p_use_fast_loader,
            p_scenario_name   => p_scenario_name
        );
    END UPLOAD_CSV;

    -- --------------------------------------------------------
    -- UPLOAD_FROM_REMOTE
    -- --------------------------------------------------------
    -- Called by EBS over DB link. Converts CLOB to BLOB,
    -- delegates to UPLOAD_CSV_FROM_BLOB. No OUT params (DB link
    -- compatible). Results written to DMT_UPLOAD_LOG_TBL.
    -- --------------------------------------------------------
    PROCEDURE UPLOAD_FROM_REMOTE (
        p_csv_clob      IN  CLOB,
        p_object_code   IN  VARCHAR2,
        p_file_label    IN  VARCHAR2 DEFAULT 'EBS_REMOTE',
        p_scenario_name IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_blob         BLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      INTEGER;
        l_sqlerrm      VARCHAR2(4000);
        l_rows_loaded  NUMBER;
        l_rows_errored NUMBER;
        l_batch_id_out NUMBER;
        l_error_msg    VARCHAR2(4000);
    BEGIN
        IF p_csv_clob IS NULL OR DBMS_LOB.GETLENGTH(p_csv_clob) = 0 THEN
            INSERT INTO DMT_UPLOAD_LOG_TBL (BATCH_ID, OBJECT_CODE, FILE_NAME, STATUS, ERROR_MSG)
            VALUES (DMT_UPLOAD_BATCH_SEQ.NEXTVAL, p_object_code, p_file_label, 'FAILED', 'Empty CLOB received');
            COMMIT;
            RETURN;
        END IF;

        -- Convert CLOB to BLOB
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(
            dest_lob    => l_blob,
            src_clob    => p_csv_clob,
            amount      => DBMS_LOB.LOBMAXSIZE,
            dest_offset => l_dest_offset,
            src_offset  => l_src_offset,
            blob_csid   => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_context,
            warning     => l_warning
        );

        UPLOAD_CSV_FROM_BLOB(
            p_blob            => l_blob,
            p_file_label      => p_file_label,
            p_object_code     => p_object_code,
            p_batch_id        => NULL,
            p_rows_loaded     => l_rows_loaded,
            p_rows_errored    => l_rows_errored,
            p_batch_id_out    => l_batch_id_out,
            p_error_msg       => l_error_msg,
            p_use_fast_loader => TRUE,
            p_scenario_name   => p_scenario_name
        );

        DBMS_LOB.FREETEMPORARY(l_blob);

    EXCEPTION
        WHEN OTHERS THEN
            IF l_blob IS NOT NULL THEN
                BEGIN DBMS_LOB.FREETEMPORARY(l_blob); EXCEPTION WHEN OTHERS THEN NULL; END;
            END IF;
            l_sqlerrm := SQLERRM;
            INSERT INTO DMT_UPLOAD_LOG_TBL (BATCH_ID, OBJECT_CODE, FILE_NAME, STATUS, ERROR_MSG)
            VALUES (DMT_UPLOAD_BATCH_SEQ.NEXTVAL, p_object_code, p_file_label, 'FAILED', 'Remote upload failed: ' || l_sqlerrm);
            COMMIT;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'Remote upload failed', p_sqlerrm => l_sqlerrm,
                p_package => C_PKG, p_procedure => 'UPLOAD_FROM_REMOTE');
    END UPLOAD_FROM_REMOTE;

    -- --------------------------------------------------------
    -- UPLOAD_ZIP_BUNDLE
    -- --------------------------------------------------------
    PROCEDURE UPLOAD_ZIP_BUNDLE (
        p_file_name       IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_zip_blob      BLOB;
        l_batch_id      NUMBER;
        l_files         APEX_ZIP.T_FILES;
        l_file_blob     BLOB;
        l_file_name     VARCHAR2(500);
        l_object_code   VARCHAR2(50);
        l_rows_loaded   NUMBER;
        l_rows_errored  NUMBER;
        l_batch_out     NUMBER;
        l_file_error    VARCHAR2(4000);
        l_summary       CLOB;
        l_matched       BOOLEAN;
        l_total_loaded  NUMBER := 0;
        l_total_errored NUMBER := 0;
        l_total_files   NUMBER := 0;
        l_batch_tag     VARCHAR2(200);

        -- Parent-before-child routing plan. Each matched CSV in the zip is
        -- resolved to its object and its registry DISPLAY_ORDER, then the whole
        -- bundle is loaded in DISPLAY_ORDER so a parent staging table (e.g.
        -- DMT_PO_HEADERS_INT_STG_TBL, DMT_HZ_PARTIES_STG_TBL) is always loaded
        -- before its child tables — regardless of the file order inside the zip.
        TYPE t_plan_rec IS RECORD (
            display_order NUMBER,
            zip_index     PLS_INTEGER,
            file_label    VARCHAR2(500),
            object_code   VARCHAR2(50)
        );
        TYPE t_plan_tab IS TABLE OF t_plan_rec INDEX BY PLS_INTEGER;
        l_plan       t_plan_tab;
        l_plan_count PLS_INTEGER := 0;
        l_disp_order NUMBER;
        -- simple insertion sort keys (small N: one zip of at most ~96 CSVs)
        l_tmp        t_plan_rec;
    BEGIN
        p_error_msg := NULL;

        IF p_batch_id IS NOT NULL THEN
            l_batch_id := p_batch_id;
        ELSE
            SELECT DMT_UPLOAD_BATCH_SEQ.NEXTVAL INTO l_batch_id FROM DUAL;
        END IF;
        p_batch_id_out := l_batch_id;

        BEGIN
            SELECT BLOB_CONTENT INTO l_zip_blob
            FROM   APEX_APPLICATION_TEMP_FILES
            WHERE  NAME = p_file_name;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_error_msg := 'ZIP file not found: ' || p_file_name;
                RETURN;
        END;

        l_files := APEX_ZIP.GET_FILES(p_zipped_blob => l_zip_blob);
        DBMS_LOB.CREATETEMPORARY(l_summary, TRUE);

        -- Build the batch tag once for the whole ZIP
        l_batch_tag := NVL(p_scenario_name, 'none') || '~'
                    || TO_CHAR(SYSTIMESTAMP, 'YYMMDDHH24MISS') || '~'
                    || SUBSTR(p_file_name, GREATEST(INSTR(p_file_name, '/', -1), INSTR(p_file_name, '\', -1)) + 1);

        -- Pass 1: resolve each zip file to its object + DISPLAY_ORDER.
        FOR i IN 1 .. l_files.COUNT LOOP
            l_file_name := l_files(i);
            IF l_file_name LIKE '%/' OR l_file_name LIKE '.%' THEN CONTINUE; END IF;
            IF INSTR(l_file_name, '/') > 0 THEN
                l_file_name := SUBSTR(l_file_name, INSTR(l_file_name, '/', -1) + 1);
            END IF;

            l_matched := FALSE;
            BEGIN
                SELECT OBJECT_CODE, NVL(DISPLAY_ORDER, 0)
                INTO   l_object_code, l_disp_order
                FROM   DMT_UPLOAD_OBJECT_TBL
                WHERE  UPPER(CSV_FILENAME) = UPPER(l_file_name)
                AND    IS_ACTIVE = 'Y';
                l_matched := TRUE;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
                WHEN TOO_MANY_ROWS THEN NULL;
            END;

            IF l_matched THEN
                l_plan_count := l_plan_count + 1;
                l_plan(l_plan_count).display_order := l_disp_order;
                l_plan(l_plan_count).zip_index     := i;
                l_plan(l_plan_count).file_label     := l_file_name;
                l_plan(l_plan_count).object_code    := l_object_code;
            END IF;
        END LOOP;

        -- Sort the plan by DISPLAY_ORDER (ascending). Insertion sort — the plan
        -- is small (one zip), and this keeps a stable parent-before-child order.
        FOR i IN 2 .. l_plan_count LOOP
            l_tmp := l_plan(i);
            DECLARE j PLS_INTEGER := i - 1;
            BEGIN
                WHILE j >= 1 AND l_plan(j).display_order > l_tmp.display_order LOOP
                    l_plan(j + 1) := l_plan(j);
                    j := j - 1;
                END LOOP;
                l_plan(j + 1) := l_tmp;
            END;
        END LOOP;

        -- Pass 2: load in DISPLAY_ORDER (parents before children).
        FOR i IN 1 .. l_plan_count LOOP
            l_file_name   := l_plan(i).file_label;
            l_object_code := l_plan(i).object_code;

            l_file_blob := APEX_ZIP.GET_FILE_CONTENT(
                p_zipped_blob => l_zip_blob, p_file_name => l_files(l_plan(i).zip_index));

            UPLOAD_CSV_FROM_BLOB(
                p_blob            => l_file_blob,
                p_file_label      => l_file_name,
                p_object_code     => l_object_code,
                p_batch_id        => l_batch_id,
                p_rows_loaded     => l_rows_loaded,
                p_rows_errored    => l_rows_errored,
                p_batch_id_out    => l_batch_out,
                p_error_msg       => l_file_error,
                p_use_fast_loader => p_use_fast_loader,
                p_scenario_name   => p_scenario_name
            );

            l_total_loaded  := l_total_loaded  + NVL(l_rows_loaded, 0);
            l_total_errored := l_total_errored + NVL(l_rows_errored, 0);
            l_total_files   := l_total_files + 1;
        END LOOP;

        -- Build compact summary for APEX notification
        DECLARE
            l_msg VARCHAR2(1000) := l_total_files || ' objects, '
                || l_total_loaded || ' rows loaded, '
                || l_total_errored || ' errors.';
        BEGIN
            IF l_total_errored > 0 THEN
                l_msg := l_msg || ' Load ID: ' || l_batch_tag;
            END IF;
            DBMS_LOB.WRITEAPPEND(l_summary, LENGTH(l_msg), l_msg);
        END;

        p_summary := l_summary;

        DMT_UTIL_PKG.LOG(
            p_message   => 'ZIP bundle complete — batch: ' || l_batch_id || ', files: ' || l_files.COUNT,
            p_package   => C_PKG,
            p_procedure => 'UPLOAD_ZIP_BUNDLE');

    EXCEPTION
        WHEN OTHERS THEN
            IF l_summary IS NOT NULL THEN
                BEGIN DBMS_LOB.FREETEMPORARY(l_summary); EXCEPTION WHEN OTHERS THEN NULL; END;
            END IF;
            p_error_msg := 'ZIP upload failed: ' || SQLERRM;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'ZIP bundle failed', p_sqlerrm => SQLERRM,
                p_package => C_PKG, p_procedure => 'UPLOAD_ZIP_BUNDLE');
    END UPLOAD_ZIP_BUNDLE;

    -- ============================================================
    -- FBDI POSITIONAL LOADER (private)
    -- ============================================================
    -- Loads a headerless, position-based FBDI CSV into a staging
    -- table. Column mapping is purely positional: column 1 in the
    -- CSV maps to the first non-admin column in DMT_UPLOAD_DICT_TBL
    -- (ordered by COLUMN_ORDER), column 2 to the second, etc.
    -- ============================================================
    PROCEDURE fbdi_load_from_blob (
        p_blob          IN  BLOB,
        p_file_label    IN  VARCHAR2,
        p_object_code   IN  VARCHAR2,
        p_staging_table IN  VARCHAR2,
        p_batch_id      IN  NUMBER,
        p_log_id        IN  NUMBER,
        p_rows_loaded   OUT NUMBER,
        p_rows_errored  OUT NUMBER,
        p_error_msg     OUT VARCHAR2
    )
    IS
        l_col_list     VARCHAR2(32767);
        l_select_list  VARCHAR2(32767);
        l_col_count    PLS_INTEGER := 0;
        l_sql          VARCHAR2(32767);
    BEGIN
        p_rows_loaded  := 0;
        p_rows_errored := 0;

        -- Build positional column mapping from dictionary.
        --
        -- An FBDI CSV is headerless and positional. The pipeline's FBDI
        -- generators write a value at a fixed slot only for SOME of a staging
        -- table's columns (the rest of the slots are empty or constants). We
        -- therefore load ONLY the staging columns that carry an explicit
        -- FBDI_POSITION, and pull each from that exact CSV slot (COLnnn). A
        -- column with no FBDI_POSITION is a slot the generator never fills, so
        -- it is left out of the INSERT entirely.
        --
        -- The presence of at least one seeded FBDI_POSITION for the object is
        -- what makes it loadable in FBDI format. If NONE of the object's
        -- columns has a position (HDL objects, or unseeded objects), we fall
        -- back to strict sequential mapping so a same-order CSV still loads,
        -- rather than silently mapping nothing.
        DECLARE
            l_has_positions PLS_INTEGER;
        BEGIN
            SELECT COUNT(*)
            INTO   l_has_positions
            FROM   DMT_UPLOAD_DICT_TBL
            WHERE  OBJECT_CODE     = p_object_code
            AND    IS_ADMIN_COLUMN = 'N'
            AND    FBDI_POSITION IS NOT NULL;

            IF l_has_positions > 0 THEN
                -- Position-driven: only the columns the generator writes.
                FOR c IN (
                    SELECT DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(COLUMN_NAME)) AS COLUMN_NAME,
                           FBDI_POSITION
                    FROM   DMT_UPLOAD_DICT_TBL
                    WHERE  OBJECT_CODE     = p_object_code
                    AND    IS_ADMIN_COLUMN = 'N'
                    AND    FBDI_POSITION IS NOT NULL
                    ORDER BY FBDI_POSITION
                ) LOOP
                    l_col_count := l_col_count + 1;
                    IF l_col_list IS NOT NULL THEN
                        l_col_list    := l_col_list    || ', ';
                        l_select_list := l_select_list || ', ';
                    END IF;
                    l_col_list    := l_col_list    || c.COLUMN_NAME;
                    l_select_list := l_select_list || 'COL' || LPAD(c.FBDI_POSITION, 3, '0');
                END LOOP;
            ELSE
                -- Sequential fallback (no positions seeded for this object).
                FOR c IN (
                    SELECT DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(COLUMN_NAME)) AS COLUMN_NAME
                    FROM   DMT_UPLOAD_DICT_TBL
                    WHERE  OBJECT_CODE     = p_object_code
                    AND    IS_ADMIN_COLUMN = 'N'
                    ORDER BY COLUMN_ORDER
                ) LOOP
                    l_col_count := l_col_count + 1;
                    IF l_col_list IS NOT NULL THEN
                        l_col_list    := l_col_list    || ', ';
                        l_select_list := l_select_list || ', ';
                    END IF;
                    l_col_list    := l_col_list    || c.COLUMN_NAME;
                    l_select_list := l_select_list || 'COL' || LPAD(l_col_count, 3, '0');
                END LOOP;
            END IF;
        END;

        IF l_col_count = 0 THEN
            p_error_msg := 'No uploadable columns found in dictionary for ' || p_object_code;
            RETURN;
        END IF;

        -- Set NLS formats to match FBDI CSV conventions (YYYY/MM/DD HH24:MI:SS)
        -- so DATE/TIMESTAMP columns convert correctly via implicit cast
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_DATE_FORMAT = ''YYYY/MM/DD HH24:MI:SS''';
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_TIMESTAMP_FORMAT = ''YYYY/MM/DD HH24:MI:SS.FF''';

        -- Build and execute: INSERT INTO staging (cols) SELECT COLnnn FROM APEX_DATA_PARSER
        -- p_skip_rows => 0 because FBDI CSVs have no header row
        l_sql := 'INSERT INTO ' || p_staging_table ||
                 ' (' || l_col_list || ')' ||
                 ' SELECT ' || l_select_list ||
                 ' FROM TABLE(APEX_DATA_PARSER.PARSE(' ||
                 '   p_content   => :blob,' ||
                 '   p_file_name => ''upload.csv'',' ||
                 '   p_skip_rows => 0))';

        DMT_UTIL_PKG.LOG(
            p_message   => 'FBDI loader: executing INSERT...SELECT for ' || p_object_code
                           || ' (' || l_col_count || ' columns mapped positionally)',
            p_package   => C_PKG,
            p_procedure => 'fbdi_load_from_blob'
        );

        EXECUTE IMMEDIATE l_sql USING p_blob;
        p_rows_loaded := SQL%ROWCOUNT;
        COMMIT;

        DMT_UTIL_PKG.LOG(
            p_message   => 'FBDI loader complete: ' || p_rows_loaded || ' rows inserted for ' || p_object_code,
            p_package   => C_PKG,
            p_procedure => 'fbdi_load_from_blob'
        );

    EXCEPTION
        WHEN OTHERS THEN
            p_error_msg := 'FBDI loader failed: ' || SQLERRM;
            p_rows_errored := 1;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'FBDI loader failed for ' || p_object_code || '. SQL: ' || SUBSTR(l_sql, 1, 500),
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => 'fbdi_load_from_blob'
            );
    END fbdi_load_from_blob;

    -- ============================================================
    -- UPLOAD_FBDI_ZIP_FROM_BLOB
    -- ============================================================
    PROCEDURE UPLOAD_FBDI_ZIP_FROM_BLOB (
        p_zip_blob        IN  BLOB,
        p_file_label      IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_batch_id       NUMBER;
        l_files          APEX_ZIP.T_FILES;
        l_file_blob      BLOB;
        l_file_name      VARCHAR2(500);
        l_object_code    VARCHAR2(50);
        l_staging_table  VARCHAR2(128);
        l_rows_loaded    NUMBER;
        l_rows_errored   NUMBER;
        l_file_error     VARCHAR2(4000);
        l_summary        CLOB;
        l_matched        BOOLEAN;
        l_log_id         NUMBER;
        l_scenario_id    NUMBER;
        l_scn_err        NUMBER;
        l_max_seq_before NUMBER;
    BEGIN
        p_error_msg := NULL;

        IF p_batch_id IS NOT NULL THEN
            l_batch_id := p_batch_id;
        ELSE
            SELECT DMT_UPLOAD_BATCH_SEQ.NEXTVAL INTO l_batch_id FROM DUAL;
        END IF;
        p_batch_id_out := l_batch_id;

        -- Resolve scenario once for the entire zip
        IF p_scenario_name IS NOT NULL THEN
            DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
                p_scenario_name => p_scenario_name,
                x_scenario_id   => l_scenario_id,
                x_error_code    => l_scn_err);
            IF l_scn_err != DMT_UTIL_PKG.C_SUCCESS THEN
                RAISE_APPLICATION_ERROR(-20115,
                    'GET_OR_CREATE_SCENARIO failed for scenario "' ||
                    p_scenario_name || '" (detail in DMT_LOG_TBL).');
            END IF;
        END IF;

        l_files := APEX_ZIP.GET_FILES(p_zipped_blob => p_zip_blob);
        DBMS_LOB.CREATETEMPORARY(l_summary, TRUE);

        FOR i IN 1 .. l_files.COUNT LOOP
            l_file_name := l_files(i);
            -- Skip directories and hidden files
            IF l_file_name LIKE '%/' OR l_file_name LIKE '.%' THEN CONTINUE; END IF;
            -- Strip path prefix (zip may contain folder structure)
            IF INSTR(l_file_name, '/') > 0 THEN
                l_file_name := SUBSTR(l_file_name, INSTR(l_file_name, '/', -1) + 1);
            END IF;

            -- Route by FBDI_CSV_FILENAME (not CSV_FILENAME)
            l_matched := FALSE;
            BEGIN
                SELECT OBJECT_CODE, STAGING_TABLE
                INTO   l_object_code, l_staging_table
                FROM   DMT_UPLOAD_OBJECT_TBL
                WHERE  UPPER(FBDI_CSV_FILENAME) = UPPER(l_file_name)
                AND    IS_ACTIVE = 'Y';
                l_matched := TRUE;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DECLARE l_msg VARCHAR2(500) := 'SKIPPED: ' || l_file_name || ' (no FBDI filename match)' || CHR(10);
                    BEGIN DBMS_LOB.WRITEAPPEND(l_summary, LENGTH(l_msg), l_msg); END;
                WHEN TOO_MANY_ROWS THEN
                    DECLARE l_msg VARCHAR2(500) := 'SKIPPED (multi-match): ' || l_file_name || CHR(10);
                    BEGIN DBMS_LOB.WRITEAPPEND(l_summary, LENGTH(l_msg), l_msg); END;
            END;

            IF l_matched THEN
                l_staging_table := DBMS_ASSERT.SIMPLE_SQL_NAME(l_staging_table);
                l_file_blob := APEX_ZIP.GET_FILE_CONTENT(
                    p_zipped_blob => p_zip_blob, p_file_name => l_files(i));

                -- Create upload log entry for this file
                INSERT INTO DMT_UPLOAD_LOG_TBL (BATCH_ID, OBJECT_CODE, FILE_NAME, STATUS)
                VALUES (l_batch_id, l_object_code, l_file_name, 'PROCESSING')
                RETURNING LOG_ID INTO l_log_id;
                COMMIT;

                -- Capture max STG_SEQUENCE_ID before insert for scenario tagging
                IF l_scenario_id IS NOT NULL THEN
                    EXECUTE IMMEDIATE
                        'SELECT NVL(MAX(STG_SEQUENCE_ID), 0) FROM ' || l_staging_table
                        INTO l_max_seq_before;
                END IF;

                -- Load using positional FBDI loader
                fbdi_load_from_blob(
                    p_blob          => l_file_blob,
                    p_file_label    => l_file_name,
                    p_object_code   => l_object_code,
                    p_staging_table => l_staging_table,
                    p_batch_id      => l_batch_id,
                    p_log_id        => l_log_id,
                    p_rows_loaded   => l_rows_loaded,
                    p_rows_errored  => l_rows_errored,
                    p_error_msg     => l_file_error
                );

                -- Tag newly inserted rows with scenario ID
                IF l_scenario_id IS NOT NULL AND l_rows_loaded > 0 THEN
                    EXECUTE IMMEDIATE
                        'UPDATE ' || l_staging_table ||
                        ' SET SCENARIO_ID = :sid WHERE STG_SEQUENCE_ID > :max_seq'
                        USING l_scenario_id, l_max_seq_before;
                    COMMIT;
                END IF;

                -- Update log entry
                UPDATE DMT_UPLOAD_LOG_TBL
                SET    ROWS_IN_FILE  = l_rows_loaded + l_rows_errored,
                       ROWS_LOADED   = l_rows_loaded,
                       ROWS_ERRORED  = l_rows_errored,
                       STATUS        = CASE
                                           WHEN l_file_error IS NOT NULL AND l_rows_loaded = 0 THEN 'FAILED'
                                           WHEN l_rows_errored > 0 THEN 'COMPLETED_WITH_ERRORS'
                                           ELSE 'COMPLETED'
                                       END,
                       ERROR_MSG     = l_file_error
                WHERE  LOG_ID = l_log_id;
                COMMIT;

                -- Append to summary
                DECLARE
                    l_msg VARCHAR2(4000) := l_object_code || ': '
                        || l_rows_loaded || ' loaded, ' || l_rows_errored || ' errors';
                BEGIN
                    IF l_file_error IS NOT NULL THEN l_msg := l_msg || ' — ' || l_file_error; END IF;
                    l_msg := l_msg || CHR(10);
                    DBMS_LOB.WRITEAPPEND(l_summary, LENGTH(l_msg), l_msg);
                END;
            END IF;
        END LOOP;

        p_summary := l_summary;

        DMT_UTIL_PKG.LOG(
            p_message   => 'FBDI ZIP upload complete — batch: ' || l_batch_id || ', files: ' || l_files.COUNT,
            p_package   => C_PKG,
            p_procedure => 'UPLOAD_FBDI_ZIP_FROM_BLOB');

    EXCEPTION
        WHEN OTHERS THEN
            IF l_summary IS NOT NULL THEN
                BEGIN DBMS_LOB.FREETEMPORARY(l_summary); EXCEPTION WHEN OTHERS THEN NULL; END;
            END IF;
            p_error_msg := 'FBDI ZIP upload failed: ' || SQLERRM;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'FBDI ZIP upload failed', p_sqlerrm => SQLERRM,
                p_package => C_PKG, p_procedure => 'UPLOAD_FBDI_ZIP_FROM_BLOB');
    END UPLOAD_FBDI_ZIP_FROM_BLOB;

    -- ============================================================
    -- UPLOAD_FBDI_ZIP
    -- ============================================================
    -- APEX entry point: reads ZIP from APEX_APPLICATION_TEMP_FILES,
    -- delegates to UPLOAD_FBDI_ZIP_FROM_BLOB.
    -- ============================================================
    PROCEDURE UPLOAD_FBDI_ZIP (
        p_file_name       IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_zip_blob BLOB;
    BEGIN
        p_error_msg := NULL;

        BEGIN
            SELECT BLOB_CONTENT INTO l_zip_blob
            FROM   APEX_APPLICATION_TEMP_FILES
            WHERE  NAME = p_file_name;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_error_msg := 'FBDI ZIP file not found: ' || p_file_name;
                RETURN;
        END;

        UPLOAD_FBDI_ZIP_FROM_BLOB(
            p_zip_blob      => l_zip_blob,
            p_file_label    => p_file_name,
            p_batch_id      => p_batch_id,
            p_summary       => p_summary,
            p_batch_id_out  => p_batch_id_out,
            p_error_msg     => p_error_msg,
            p_scenario_name => p_scenario_name
        );

    EXCEPTION
        WHEN OTHERS THEN
            p_error_msg := 'FBDI ZIP upload failed: ' || SQLERRM;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'FBDI ZIP upload failed', p_sqlerrm => SQLERRM,
                p_package => C_PKG, p_procedure => 'UPLOAD_FBDI_ZIP');
    END UPLOAD_FBDI_ZIP;

    -- ============================================================
    -- UPLOAD_ZIP_AUTO_FROM_BLOB — auto-detect dispatcher
    -- ============================================================
    -- One ZIP, mixed formats. Each member CSV is routed by filename:
    --   * matches CSV_FILENAME      -> proprietary CSV (header-driven) loader
    --   * matches FBDI_CSV_FILENAME -> FBDI (headerless, positional) loader
    --   * neither                   -> skipped with a warning line
    -- The whole bundle is loaded in DISPLAY_ORDER (parents before
    -- children) regardless of member order in the zip, and regardless
    -- of which format each file is in. Both loaders already own their
    -- per-row error handling, logging, and scenario tagging; this
    -- procedure only routes and orders.
    -- ============================================================
    PROCEDURE UPLOAD_ZIP_AUTO_FROM_BLOB (
        p_zip_blob        IN  BLOB,
        p_file_label      IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_batch_id       NUMBER;
        l_files          APEX_ZIP.T_FILES;
        l_file_blob      BLOB;
        l_file_name      VARCHAR2(500);
        l_object_code    VARCHAR2(50);
        l_staging_table  VARCHAR2(128);
        l_disp_order     NUMBER;
        l_format         VARCHAR2(12);
        l_rows_loaded    NUMBER;
        l_rows_errored   NUMBER;
        l_batch_out      NUMBER;
        l_file_error     VARCHAR2(4000);
        l_summary        CLOB;
        l_total_loaded   NUMBER := 0;
        l_total_errored  NUMBER := 0;
        l_total_files    NUMBER := 0;
        l_skipped        NUMBER := 0;

        -- Per-file routing plan: format tells the second pass which loader
        -- to call; DISPLAY_ORDER sorts the whole mixed bundle parent-first.
        TYPE t_plan_rec IS RECORD (
            display_order NUMBER,
            zip_index     PLS_INTEGER,
            file_label    VARCHAR2(500),
            object_code   VARCHAR2(50),
            staging_table VARCHAR2(128),
            format        VARCHAR2(12)   -- 'PROPRIETARY' or 'FBDI'
        );
        TYPE t_plan_tab IS TABLE OF t_plan_rec INDEX BY PLS_INTEGER;
        l_plan       t_plan_tab;
        l_plan_count PLS_INTEGER := 0;
        l_tmp        t_plan_rec;

        -- Log-entry + scenario-tagging locals for the FBDI branch (the
        -- proprietary branch does its own via UPLOAD_CSV_FROM_BLOB).
        l_log_id         NUMBER;
        l_scenario_id    NUMBER;
        l_scn_err        NUMBER;
        l_max_seq_before NUMBER;

        PROCEDURE append_summary (p_text IN VARCHAR2) IS
        BEGIN
            DBMS_LOB.WRITEAPPEND(l_summary, LENGTH(p_text), p_text);
        END append_summary;
    BEGIN
        p_error_msg := NULL;

        IF p_batch_id IS NOT NULL THEN
            l_batch_id := p_batch_id;
        ELSE
            SELECT DMT_UPLOAD_BATCH_SEQ.NEXTVAL INTO l_batch_id FROM DUAL;
        END IF;
        p_batch_id_out := l_batch_id;

        -- Resolve scenario once for the whole bundle (used by the FBDI branch;
        -- the proprietary branch passes p_scenario_name straight through).
        IF p_scenario_name IS NOT NULL THEN
            DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(
                p_scenario_name => p_scenario_name,
                x_scenario_id   => l_scenario_id,
                x_error_code    => l_scn_err);
            IF l_scn_err != DMT_UTIL_PKG.C_SUCCESS THEN
                RAISE_APPLICATION_ERROR(-20115,
                    'GET_OR_CREATE_SCENARIO failed for scenario "' ||
                    p_scenario_name || '" (detail in DMT_LOG_TBL).');
            END IF;
        END IF;

        l_files := APEX_ZIP.GET_FILES(p_zipped_blob => p_zip_blob);
        DBMS_LOB.CREATETEMPORARY(l_summary, TRUE);

        -- Pass 1: classify + resolve each member to object, staging table,
        -- DISPLAY_ORDER and format.
        FOR i IN 1 .. l_files.COUNT LOOP
            l_file_name := l_files(i);
            IF l_file_name LIKE '%/' OR l_file_name LIKE '.%' THEN CONTINUE; END IF;
            IF INSTR(l_file_name, '/') > 0 THEN
                l_file_name := SUBSTR(l_file_name, INSTR(l_file_name, '/', -1) + 1);
            END IF;

            l_format := NULL;

            -- Try proprietary filename first.
            BEGIN
                SELECT OBJECT_CODE, STAGING_TABLE, NVL(DISPLAY_ORDER, 0)
                INTO   l_object_code, l_staging_table, l_disp_order
                FROM   DMT_UPLOAD_OBJECT_TBL
                WHERE  UPPER(CSV_FILENAME) = UPPER(l_file_name)
                AND    IS_ACTIVE = 'Y';
                l_format := 'PROPRIETARY';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
                WHEN TOO_MANY_ROWS THEN NULL;
            END;

            -- Else try FBDI filename.
            IF l_format IS NULL THEN
                BEGIN
                    SELECT OBJECT_CODE, STAGING_TABLE, NVL(DISPLAY_ORDER, 0)
                    INTO   l_object_code, l_staging_table, l_disp_order
                    FROM   DMT_UPLOAD_OBJECT_TBL
                    WHERE  UPPER(FBDI_CSV_FILENAME) = UPPER(l_file_name)
                    AND    IS_ACTIVE = 'Y';
                    l_format := 'FBDI';
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;
                    WHEN TOO_MANY_ROWS THEN NULL;
                END;
            END IF;

            IF l_format IS NULL THEN
                l_skipped := l_skipped + 1;
                append_summary('SKIPPED: ' || l_file_name
                    || ' (unrecognized file — no proprietary or FBDI filename match)' || CHR(10));
            ELSE
                l_plan_count := l_plan_count + 1;
                l_plan(l_plan_count).display_order := l_disp_order;
                l_plan(l_plan_count).zip_index     := i;
                l_plan(l_plan_count).file_label    := l_file_name;
                l_plan(l_plan_count).object_code   := l_object_code;
                l_plan(l_plan_count).staging_table := l_staging_table;
                l_plan(l_plan_count).format        := l_format;
            END IF;
        END LOOP;

        -- Sort the plan by DISPLAY_ORDER (ascending) — insertion sort, small N.
        FOR i IN 2 .. l_plan_count LOOP
            l_tmp := l_plan(i);
            DECLARE j PLS_INTEGER := i - 1;
            BEGIN
                WHILE j >= 1 AND l_plan(j).display_order > l_tmp.display_order LOOP
                    l_plan(j + 1) := l_plan(j);
                    j := j - 1;
                END LOOP;
                l_plan(j + 1) := l_tmp;
            END;
        END LOOP;

        -- Pass 2: load in DISPLAY_ORDER, each file via its format's loader.
        FOR i IN 1 .. l_plan_count LOOP
            l_file_name   := l_plan(i).file_label;
            l_object_code := l_plan(i).object_code;
            l_file_blob   := APEX_ZIP.GET_FILE_CONTENT(
                p_zipped_blob => p_zip_blob, p_file_name => l_files(l_plan(i).zip_index));
            l_file_error  := NULL;
            l_rows_loaded := 0;
            l_rows_errored := 0;

            IF l_plan(i).format = 'PROPRIETARY' THEN
                -- Reuse the header-driven loader end-to-end (it logs, tags
                -- scenario and per-row errors itself).
                UPLOAD_CSV_FROM_BLOB(
                    p_blob            => l_file_blob,
                    p_file_label      => l_file_name,
                    p_object_code     => l_object_code,
                    p_batch_id        => l_batch_id,
                    p_rows_loaded     => l_rows_loaded,
                    p_rows_errored    => l_rows_errored,
                    p_batch_id_out    => l_batch_out,
                    p_error_msg       => l_file_error,
                    p_use_fast_loader => p_use_fast_loader,
                    p_scenario_name   => p_scenario_name
                );
            ELSE
                -- FBDI positional load. Mirror UPLOAD_FBDI_ZIP_FROM_BLOB's
                -- per-file bookkeeping (log entry, scenario tag) around the
                -- shared positional loader so behaviour matches the FBDI-only
                -- entry point exactly.
                l_staging_table := DBMS_ASSERT.SIMPLE_SQL_NAME(l_plan(i).staging_table);

                INSERT INTO DMT_UPLOAD_LOG_TBL (BATCH_ID, OBJECT_CODE, FILE_NAME, STATUS)
                VALUES (l_batch_id, l_object_code, l_file_name, 'PROCESSING')
                RETURNING LOG_ID INTO l_log_id;
                COMMIT;

                IF l_scenario_id IS NOT NULL THEN
                    EXECUTE IMMEDIATE
                        'SELECT NVL(MAX(STG_SEQUENCE_ID), 0) FROM ' || l_staging_table
                        INTO l_max_seq_before;
                END IF;

                fbdi_load_from_blob(
                    p_blob          => l_file_blob,
                    p_file_label    => l_file_name,
                    p_object_code   => l_object_code,
                    p_staging_table => l_staging_table,
                    p_batch_id      => l_batch_id,
                    p_log_id        => l_log_id,
                    p_rows_loaded   => l_rows_loaded,
                    p_rows_errored  => l_rows_errored,
                    p_error_msg     => l_file_error
                );

                IF l_scenario_id IS NOT NULL AND l_rows_loaded > 0 THEN
                    EXECUTE IMMEDIATE
                        'UPDATE ' || l_staging_table ||
                        ' SET SCENARIO_ID = :sid WHERE STG_SEQUENCE_ID > :max_seq'
                        USING l_scenario_id, l_max_seq_before;
                    COMMIT;
                END IF;

                UPDATE DMT_UPLOAD_LOG_TBL
                SET    ROWS_IN_FILE  = l_rows_loaded + l_rows_errored,
                       ROWS_LOADED   = l_rows_loaded,
                       ROWS_ERRORED  = l_rows_errored,
                       STATUS        = CASE
                                           WHEN l_file_error IS NOT NULL AND l_rows_loaded = 0 THEN 'FAILED'
                                           WHEN l_rows_errored > 0 THEN 'COMPLETED_WITH_ERRORS'
                                           ELSE 'COMPLETED'
                                       END,
                       ERROR_MSG     = l_file_error
                WHERE  LOG_ID = l_log_id;
                COMMIT;
            END IF;

            l_total_loaded  := l_total_loaded  + NVL(l_rows_loaded, 0);
            l_total_errored := l_total_errored + NVL(l_rows_errored, 0);
            l_total_files   := l_total_files + 1;

            DECLARE
                l_msg VARCHAR2(4000) := l_plan(i).format || '  ' || l_object_code || ': '
                    || NVL(l_rows_loaded, 0) || ' loaded, ' || NVL(l_rows_errored, 0) || ' errors';
            BEGIN
                IF l_file_error IS NOT NULL THEN l_msg := l_msg || ' — ' || l_file_error; END IF;
                append_summary(l_msg || CHR(10));
            END;
        END LOOP;

        DECLARE
            l_hdr VARCHAR2(400) := l_total_files || ' file(s) loaded, '
                || l_total_loaded || ' rows loaded, '
                || l_total_errored || ' errors, '
                || l_skipped || ' skipped.' || CHR(10);
        BEGIN
            append_summary(l_hdr);
        END;

        p_summary := l_summary;

        DMT_UTIL_PKG.LOG(
            p_message   => 'Auto-detect ZIP complete — batch: ' || l_batch_id
                           || ', matched: ' || l_total_files
                           || ', skipped: ' || l_skipped
                           || ', rows: ' || l_total_loaded,
            p_package   => C_PKG,
            p_procedure => 'UPLOAD_ZIP_AUTO_FROM_BLOB');

    EXCEPTION
        WHEN OTHERS THEN
            IF l_summary IS NOT NULL THEN
                BEGIN DBMS_LOB.FREETEMPORARY(l_summary); EXCEPTION WHEN OTHERS THEN NULL; END;
            END IF;
            p_error_msg := 'Auto-detect ZIP upload failed: ' || SQLERRM;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'Auto-detect ZIP upload failed', p_sqlerrm => SQLERRM,
                p_package => C_PKG, p_procedure => 'UPLOAD_ZIP_AUTO_FROM_BLOB');
    END UPLOAD_ZIP_AUTO_FROM_BLOB;

    -- ============================================================
    -- UPLOAD_ZIP_AUTO — APEX entry point (reads temp file, delegates)
    -- ============================================================
    PROCEDURE UPLOAD_ZIP_AUTO (
        p_file_name       IN  VARCHAR2,
        p_batch_id        IN  NUMBER   DEFAULT NULL,
        p_summary         OUT CLOB,
        p_batch_id_out    OUT NUMBER,
        p_error_msg       OUT VARCHAR2,
        p_use_fast_loader IN  BOOLEAN  DEFAULT TRUE,
        p_scenario_name   IN  VARCHAR2 DEFAULT NULL
    )
    IS
        l_zip_blob BLOB;
    BEGIN
        p_error_msg := NULL;

        BEGIN
            SELECT BLOB_CONTENT INTO l_zip_blob
            FROM   APEX_APPLICATION_TEMP_FILES
            WHERE  NAME = p_file_name;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_error_msg := 'ZIP file not found: ' || p_file_name;
                RETURN;
        END;

        UPLOAD_ZIP_AUTO_FROM_BLOB(
            p_zip_blob        => l_zip_blob,
            p_file_label      => p_file_name,
            p_batch_id        => p_batch_id,
            p_summary         => p_summary,
            p_batch_id_out    => p_batch_id_out,
            p_error_msg       => p_error_msg,
            p_use_fast_loader => p_use_fast_loader,
            p_scenario_name   => p_scenario_name
        );

    EXCEPTION
        WHEN OTHERS THEN
            p_error_msg := 'Auto-detect ZIP upload failed: ' || SQLERRM;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'Auto-detect ZIP upload failed', p_sqlerrm => SQLERRM,
                p_package => C_PKG, p_procedure => 'UPLOAD_ZIP_AUTO');
    END UPLOAD_ZIP_AUTO;

END DMT_CSV_UPLOAD_PKG;
/
