-- PACKAGE BODY DMT_CSV_LOADER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CSV_LOADER_PKG" AS
-- =============================================================================
-- DMT_CSV_LOADER_PKG — body
-- =============================================================================

    c_pkg CONSTANT VARCHAR2(30) := 'DMT_CSV_LOADER_PKG';

    -- Columns that have DB defaults and should never be loaded from CSV
    TYPE skip_set_t IS TABLE OF VARCHAR2(1) INDEX BY VARCHAR2(128);
    g_skip_cols skip_set_t;

    -- Column name array
    TYPE col_arr_t IS TABLE OF VARCHAR2(128) INDEX BY PLS_INTEGER;

    -- Field value array (32767 to handle any EBS column width)
    TYPE val_arr_t IS TABLE OF VARCHAR2(32767) INDEX BY PLS_INTEGER;

    -- Column position map: csv_position(i) → index into header array
    TYPE pos_arr_t IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

    -- -------------------------------------------------------------------------
    -- init_skip_cols (called once per session)
    -- -------------------------------------------------------------------------
    PROCEDURE init_skip_cols IS
    BEGIN
        IF g_skip_cols.COUNT = 0 THEN
            g_skip_cols('STG_SEQUENCE_ID')   := 'Y';
            g_skip_cols('STAGE_DATE')        := 'Y';
            g_skip_cols('STATUS')            := 'Y';
            g_skip_cols('ERROR_TEXT')         := 'Y';
            g_skip_cols('LAST_UPDATED_DATE') := 'Y';
        END IF;
    END init_skip_cols;

    -- -------------------------------------------------------------------------
    -- parse_header_row
    -- Extracts the first line from the CLOB and splits on commas.
    -- Returns the array of column names and sets p_offset to the start
    -- of the second line (first data row).
    -- -------------------------------------------------------------------------
    PROCEDURE parse_header_row (
        p_csv     IN  CLOB,
        p_headers OUT col_arr_t,
        p_offset  OUT NUMBER
    ) IS
        v_lf_pos  NUMBER;
        v_line    VARCHAR2(32767);
        v_start   NUMBER := 1;
        v_comma   NUMBER;
        v_idx     PLS_INTEGER := 0;
    BEGIN
        -- Find end of first line
        v_lf_pos := DBMS_LOB.INSTR(p_csv, CHR(10), 1);
        IF v_lf_pos = 0 THEN
            -- Single-line CLOB (header only, no data)
            v_line := DBMS_LOB.SUBSTR(p_csv, DBMS_LOB.GETLENGTH(p_csv), 1);
            p_offset := DBMS_LOB.GETLENGTH(p_csv) + 1;
        ELSE
            v_line := DBMS_LOB.SUBSTR(p_csv, v_lf_pos - 1, 1);
            p_offset := v_lf_pos + 1;
        END IF;

        -- Strip trailing CR if present
        IF SUBSTR(v_line, LENGTH(v_line), 1) = CHR(13) THEN
            v_line := SUBSTR(v_line, 1, LENGTH(v_line) - 1);
        END IF;

        -- Split on commas (header names never contain commas/quotes)
        v_start := 1;
        LOOP
            v_comma := INSTR(v_line, ',', v_start);
            v_idx := v_idx + 1;
            IF v_comma = 0 THEN
                p_headers(v_idx) := UPPER(TRIM(SUBSTR(v_line, v_start)));
                EXIT;
            ELSE
                p_headers(v_idx) := UPPER(TRIM(SUBSTR(v_line, v_start, v_comma - v_start)));
                v_start := v_comma + 1;
            END IF;
        END LOOP;
    END parse_header_row;

    -- -------------------------------------------------------------------------
    -- intersect_columns
    -- Matches CSV header columns to target table columns.
    -- Returns parallel arrays: target column names and their CSV positions.
    -- Skips infrastructure columns that have DB defaults.
    -- -------------------------------------------------------------------------
    PROCEDURE intersect_columns (
        p_headers       IN  col_arr_t,
        p_table_name    IN  VARCHAR2,
        p_target_cols   OUT col_arr_t,
        p_csv_positions OUT pos_arr_t,
        p_has_scenario  OUT BOOLEAN
    ) IS
        TYPE col_set_t IS TABLE OF VARCHAR2(1) INDEX BY VARCHAR2(128);
        v_tgt_cols col_set_t;
        v_col_name VARCHAR2(128);
        v_idx      PLS_INTEGER := 0;
    BEGIN
        init_skip_cols;
        p_has_scenario := FALSE;

        -- Load target table columns into a set
        FOR rec IN (SELECT column_name
                      FROM user_tab_columns
                     WHERE table_name = UPPER(p_table_name)) LOOP
            v_tgt_cols(rec.column_name) := 'Y';
            IF rec.column_name = 'SCENARIO_ID' THEN
                p_has_scenario := TRUE;
            END IF;
        END LOOP;

        -- Match CSV headers to target columns
        FOR i IN 1..p_headers.COUNT LOOP
            v_col_name := p_headers(i);
            IF v_tgt_cols.EXISTS(v_col_name)
               AND NOT g_skip_cols.EXISTS(v_col_name)
               AND v_col_name != 'SCENARIO_ID'  -- handled separately
            THEN
                v_idx := v_idx + 1;
                p_target_cols(v_idx) := v_col_name;
                p_csv_positions(v_idx) := i;
            END IF;
        END LOOP;
    END intersect_columns;

    -- -------------------------------------------------------------------------
    -- parse_csv_line
    -- Parses one data row from the CLOB starting at p_offset.
    -- Returns field values in p_fields and advances p_offset past the row.
    -- Returns FALSE if EOF reached (no more data).
    --
    -- Handles: unquoted fields, quoted fields with escaped "" and
    -- embedded commas/newlines, Windows CR+LF line endings.
    -- -------------------------------------------------------------------------
    FUNCTION parse_csv_line (
        p_csv       IN     CLOB,
        p_offset    IN OUT NUMBER,
        p_col_count IN     PLS_INTEGER,
        p_fields    OUT    val_arr_t
    ) RETURN BOOLEAN
    IS
        v_len       NUMBER;
        v_ch        VARCHAR2(1);
        v_field     VARCHAR2(4000);
        v_col_idx   PLS_INTEGER := 0;
        v_in_quotes BOOLEAN := FALSE;
        v_pos       NUMBER;
        v_field_len NUMBER := 0;
    BEGIN
        v_len := DBMS_LOB.GETLENGTH(p_csv);

        -- Skip any leading CR/LF (blank lines between rows)
        WHILE p_offset <= v_len LOOP
            v_ch := DBMS_LOB.SUBSTR(p_csv, 1, p_offset);
            EXIT WHEN v_ch NOT IN (CHR(10), CHR(13));
            p_offset := p_offset + 1;
        END LOOP;

        IF p_offset > v_len THEN
            RETURN FALSE;  -- EOF
        END IF;

        v_col_idx := 1;
        v_field := NULL;
        v_in_quotes := FALSE;
        v_pos := p_offset;

        WHILE v_pos <= v_len LOOP
            v_ch := DBMS_LOB.SUBSTR(p_csv, 1, v_pos);

            IF v_in_quotes THEN
                IF v_ch = '"' THEN
                    -- Check next char for escaped quote
                    IF v_pos + 1 <= v_len
                       AND DBMS_LOB.SUBSTR(p_csv, 1, v_pos + 1) = '"' THEN
                        -- Escaped "" → single "
                        v_field := v_field || '"';
                        v_pos := v_pos + 2;
                    ELSE
                        -- Closing quote
                        v_in_quotes := FALSE;
                        v_pos := v_pos + 1;
                    END IF;
                ELSE
                    v_field := v_field || v_ch;
                    v_pos := v_pos + 1;
                END IF;

            ELSE  -- not in quotes
                IF v_ch = '"' AND v_field IS NULL THEN
                    -- Opening quote at field start
                    v_in_quotes := TRUE;
                    v_pos := v_pos + 1;

                ELSIF v_ch = ',' THEN
                    -- Field separator
                    p_fields(v_col_idx) := v_field;
                    v_col_idx := v_col_idx + 1;
                    v_field := NULL;
                    v_pos := v_pos + 1;

                ELSIF v_ch = CHR(13) THEN
                    -- CR — skip, LF follows
                    v_pos := v_pos + 1;

                ELSIF v_ch = CHR(10) THEN
                    -- End of row
                    p_fields(v_col_idx) := v_field;
                    v_pos := v_pos + 1;
                    p_offset := v_pos;
                    -- Pad remaining columns with NULL if row is short
                    FOR j IN (v_col_idx + 1)..p_col_count LOOP
                        p_fields(j) := NULL;
                    END LOOP;
                    RETURN TRUE;

                ELSE
                    v_field := v_field || v_ch;
                    v_pos := v_pos + 1;
                END IF;
            END IF;
        END LOOP;

        -- EOF mid-row — store last field
        IF v_col_idx >= 1 THEN
            p_fields(v_col_idx) := v_field;
            FOR j IN (v_col_idx + 1)..p_col_count LOOP
                p_fields(j) := NULL;
            END LOOP;
            p_offset := v_pos;
            RETURN TRUE;
        END IF;

        RETURN FALSE;
    END parse_csv_line;

    -- -------------------------------------------------------------------------
    -- LOAD_CSV
    -- Core procedure: parses one CSV landing row into its target STG table.
    -- -------------------------------------------------------------------------
    PROCEDURE LOAD_CSV (
        p_csv_landing_id  IN NUMBER
    ) IS
        c_proc CONSTANT VARCHAR2(30) := 'LOAD_CSV';

        v_csv_data      CLOB;
        v_atp_table     VARCHAR2(100);
        v_scenario_name VARCHAR2(100);
        v_src_row_count NUMBER;
        v_view_name     VARCHAR2(100);

        v_headers       col_arr_t;
        v_target_cols   col_arr_t;
        v_csv_positions pos_arr_t;
        v_has_scenario  BOOLEAN;
        v_scenario_id   NUMBER := NULL;

        v_fields        val_arr_t;
        v_offset        NUMBER;

        v_insert_sql    VARCHAR2(32000);
        v_cur_id        INTEGER;
        v_dummy         INTEGER;
        v_rows_loaded   NUMBER := 0;
        v_row_num       NUMBER := 0;
        v_err_msg       VARCHAR2(4000);
        v_fail_detail   VARCHAR2(4000);
        v_fail_line     VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_message   => 'Starting CSV load for landing_id=' || p_csv_landing_id,
            p_package   => c_pkg,
            p_procedure => c_proc
        );

        -- Match the NLS format used by EBS generate_csv so implicit
        -- date/timestamp conversion works for CSV VARCHAR2 → DATE columns
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_DATE_FORMAT = ''YYYY/MM/DD HH24:MI:SS''';
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_TIMESTAMP_FORMAT = ''YYYY/MM/DD HH24:MI:SS.FF''';

        -- 1. Lock and read the landing row
        SELECT csv_data, atp_table_name, scenario_name, row_count, view_name
          INTO v_csv_data, v_atp_table, v_scenario_name, v_src_row_count, v_view_name
          FROM dmt_csv_landing_tbl
         WHERE csv_landing_id = p_csv_landing_id
           FOR UPDATE;

        IF v_csv_data IS NULL OR DBMS_LOB.GETLENGTH(v_csv_data) = 0 THEN
            UPDATE dmt_csv_landing_tbl
               SET status = 'FAILED', error_text = 'CSV_DATA is empty',
                   processed_date = SYSDATE
             WHERE csv_landing_id = p_csv_landing_id;
            COMMIT;
            DMT_UTIL_PKG.LOG(
                p_message   => 'FAILED: CSV_DATA is empty for landing_id=' || p_csv_landing_id,
                p_log_type  => 'WARN',
                p_package   => c_pkg,
                p_procedure => c_proc
            );
            RETURN;
        END IF;

        -- Scenario is mandatory on every ingestion path (decided 2026-07-07):
        -- untagged staging rows are disallowed. Fail the landing row with a
        -- reportable error instead of silently loading untagged rows.
        IF v_scenario_name IS NULL THEN
            UPDATE dmt_csv_landing_tbl
               SET status = 'FAILED',
                   error_text = 'SCENARIO_NAME is required: scenario is mandatory on ' ||
                                'every ingestion path — untagged staging rows are disallowed',
                   rows_loaded = 0,
                   processed_date = SYSDATE
             WHERE csv_landing_id = p_csv_landing_id;
            COMMIT;
            DMT_UTIL_PKG.LOG(
                p_message   => 'FAILED: SCENARIO_NAME is required for landing_id=' || p_csv_landing_id ||
                               ' (' || v_view_name || ' → ' || v_atp_table || ')',
                p_log_type  => 'WARN',
                p_package   => c_pkg,
                p_procedure => c_proc
            );
            RETURN;
        END IF;

        -- Mark as processing
        UPDATE dmt_csv_landing_tbl
           SET status = 'PROCESSING', error_text = NULL
         WHERE csv_landing_id = p_csv_landing_id;
        COMMIT;

        -- 2. Resolve the mandatory scenario
        IF v_scenario_name IS NOT NULL THEN
            v_scenario_id := DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO(v_scenario_name);
            DMT_UTIL_PKG.LOG(
                p_message   => 'Scenario ''' || v_scenario_name || ''' resolved to ID ' || v_scenario_id,
                p_package   => c_pkg,
                p_procedure => c_proc
            );
        END IF;

        -- 3. Parse header row
        parse_header_row(v_csv_data, v_headers, v_offset);

        -- 4. Column intersection
        intersect_columns(v_headers, v_atp_table, v_target_cols, v_csv_positions, v_has_scenario);

        IF v_target_cols.COUNT = 0 THEN
            UPDATE dmt_csv_landing_tbl
               SET status = 'FAILED',
                   error_text = 'No column intersection between CSV headers and ' || v_atp_table,
                   processed_date = SYSDATE
             WHERE csv_landing_id = p_csv_landing_id;
            COMMIT;
            DMT_UTIL_PKG.LOG(
                p_message   => 'FAILED: No column intersection for ' || v_view_name || ' → ' || v_atp_table,
                p_log_type  => 'WARN',
                p_package   => c_pkg,
                p_procedure => c_proc
            );
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_message   => v_view_name || ' → ' || v_atp_table ||
                           ': ' || v_target_cols.COUNT || ' columns matched, ' ||
                           (v_headers.COUNT - v_target_cols.COUNT) || ' skipped',
            p_package   => c_pkg,
            p_procedure => c_proc
        );

        -- 5. Build INSERT statement
        v_insert_sql := 'INSERT INTO ' || v_atp_table || ' (';
        FOR i IN 1..v_target_cols.COUNT LOOP
            IF i > 1 THEN v_insert_sql := v_insert_sql || ', '; END IF;
            v_insert_sql := v_insert_sql || v_target_cols(i);
        END LOOP;
        IF v_has_scenario AND v_scenario_id IS NOT NULL THEN
            v_insert_sql := v_insert_sql || ', SCENARIO_ID';
        END IF;
        v_insert_sql := v_insert_sql || ') VALUES (';
        FOR i IN 1..v_target_cols.COUNT LOOP
            IF i > 1 THEN v_insert_sql := v_insert_sql || ', '; END IF;
            v_insert_sql := v_insert_sql || ':b' || i;
        END LOOP;
        IF v_has_scenario AND v_scenario_id IS NOT NULL THEN
            v_insert_sql := v_insert_sql || ', :bscenario';
        END IF;
        v_insert_sql := v_insert_sql || ')';

        -- 6. Open DBMS_SQL cursor
        v_cur_id := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(v_cur_id, v_insert_sql, DBMS_SQL.NATIVE);

        -- 7. All-or-nothing: SAVEPOINT before inserting any rows.
        --    On first error, ROLLBACK and fail the entire CSV.
        --    Failures here are systemic (NLS, column width, constraints)
        --    so partial loads would just create incomplete staging data.
        SAVEPOINT csv_load_start;

        WHILE parse_csv_line(v_csv_data, v_offset, v_headers.COUNT, v_fields) LOOP
            v_row_num := v_row_num + 1;

            -- Bind intersected columns
            FOR i IN 1..v_target_cols.COUNT LOOP
                DBMS_SQL.BIND_VARIABLE(v_cur_id, ':b' || i,
                    CASE WHEN v_fields(v_csv_positions(i)) IS NOT NULL
                              AND LENGTH(v_fields(v_csv_positions(i))) > 0
                         THEN v_fields(v_csv_positions(i))
                         ELSE TO_CHAR(NULL) END,
                    4000);
            END LOOP;

            -- Bind scenario ID if applicable
            IF v_has_scenario AND v_scenario_id IS NOT NULL THEN
                DBMS_SQL.BIND_VARIABLE(v_cur_id, ':bscenario', v_scenario_id);
            END IF;

            -- Execute — fail fast on first error
            BEGIN
                v_dummy := DBMS_SQL.EXECUTE(v_cur_id);
                v_rows_loaded := v_rows_loaded + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_err_msg := SQLERRM;

                    -- Build a diagnostic string showing which column had what value
                    v_fail_detail := NULL;
                    FOR i IN 1..v_target_cols.COUNT LOOP
                        IF v_fields(v_csv_positions(i)) IS NOT NULL
                           AND LENGTH(v_fields(v_csv_positions(i))) > 0 THEN
                            v_fail_detail := v_fail_detail ||
                                v_target_cols(i) || '=' ||
                                SUBSTR(v_fields(v_csv_positions(i)), 1, 80);
                            IF i < v_target_cols.COUNT THEN
                                v_fail_detail := v_fail_detail || ' | ';
                            END IF;
                        END IF;
                        -- Keep it under 4000 chars
                        EXIT WHEN LENGTH(v_fail_detail) > 3500;
                    END LOOP;

                    -- Rollback all inserted rows
                    ROLLBACK TO csv_load_start;

                    DBMS_SQL.CLOSE_CURSOR(v_cur_id);

                    -- Build error message for landing row
                    v_fail_line := 'Row ' || v_row_num || ' of ' ||
                                   NVL(TO_CHAR(v_src_row_count), '?') || ': ' || v_err_msg;

                    UPDATE dmt_csv_landing_tbl
                       SET status = 'FAILED',
                           error_text = v_fail_line || CHR(10) || CHR(10) ||
                                        'Row data: ' || v_fail_detail,
                           rows_loaded = 0,
                           rows_skipped = 0,
                           processed_date = SYSDATE
                     WHERE csv_landing_id = p_csv_landing_id;
                    COMMIT;

                    DMT_UTIL_PKG.LOG_ERROR(
                        p_message => v_view_name || ' → ' || v_atp_table ||
                                     ': ' || v_fail_line,
                        p_sqlerrm => v_err_msg,
                        p_package => c_pkg,
                        p_procedure => c_proc
                    );
                    DMT_UTIL_PKG.LOG(
                        p_message   => 'Row data: ' || SUBSTR(v_fail_detail, 1, 3500),
                        p_log_type  => 'ERROR',
                        p_package   => c_pkg,
                        p_procedure => c_proc
                    );

                    RAISE;
            END;
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(v_cur_id);
        COMMIT;

        -- 8. All rows loaded successfully
        UPDATE dmt_csv_landing_tbl
           SET status = 'LOADED',
               rows_loaded = v_rows_loaded,
               rows_skipped = 0,
               processed_date = SYSDATE
         WHERE csv_landing_id = p_csv_landing_id;
        COMMIT;

        DMT_UTIL_PKG.LOG(
            p_message   => v_view_name || ' → ' || v_atp_table ||
                           ': ' || v_rows_loaded || ' rows loaded' ||
                           CASE WHEN v_src_row_count IS NOT NULL
                                THEN ' (source reported ' || v_src_row_count || ')'
                           END,
            p_package   => c_pkg,
            p_procedure => c_proc
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_err_msg := SQLERRM;
            IF DBMS_SQL.IS_OPEN(v_cur_id) THEN
                DBMS_SQL.CLOSE_CURSOR(v_cur_id);
            END IF;
            -- Mark landing row as failed (if not already marked by the row-level handler)
            UPDATE dmt_csv_landing_tbl
               SET status = 'FAILED',
                   error_text = NVL(error_text, v_err_msg),
                   rows_loaded = 0,
                   processed_date = SYSDATE
             WHERE csv_landing_id = p_csv_landing_id
               AND status != 'FAILED';
            COMMIT;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'LOAD_CSV failed for landing_id=' || p_csv_landing_id ||
                             ' (' || v_view_name || ' → ' || v_atp_table || ')',
                p_sqlerrm => v_err_msg,
                p_package => c_pkg,
                p_procedure => c_proc
            );
            RAISE;
    END LOAD_CSV;

    -- -------------------------------------------------------------------------
    -- LOAD_BATCH
    -- Processes all PENDING rows for a given batch.
    -- -------------------------------------------------------------------------
    PROCEDURE LOAD_BATCH (
        p_batch_id IN VARCHAR2
    ) IS
        c_proc CONSTANT VARCHAR2(30) := 'LOAD_BATCH';
        v_ok   NUMBER := 0;
        v_err  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_message   => 'Starting batch load: ' || p_batch_id,
            p_package   => c_pkg,
            p_procedure => c_proc
        );

        FOR rec IN (SELECT csv_landing_id, view_name, atp_table_name
                      FROM dmt_csv_landing_tbl
                     WHERE batch_id = p_batch_id
                       AND status = 'PENDING'
                     ORDER BY csv_landing_id) LOOP
            BEGIN
                LOAD_CSV(rec.csv_landing_id);
                v_ok := v_ok + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_err := v_err + 1;
                    -- Already logged inside LOAD_CSV; continue to next
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_message   => 'Batch ' || p_batch_id || ' complete: ' ||
                           v_ok || ' loaded, ' || v_err || ' failed',
            p_package   => c_pkg,
            p_procedure => c_proc
        );
    END LOAD_BATCH;

    -- -------------------------------------------------------------------------
    -- LOAD_ALL_PENDING
    -- Processes all PENDING rows across all batches.
    -- -------------------------------------------------------------------------
    PROCEDURE LOAD_ALL_PENDING IS
        c_proc CONSTANT VARCHAR2(30) := 'LOAD_ALL_PENDING';
        v_ok   NUMBER := 0;
        v_err  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_message   => 'Starting load of all pending CSVs',
            p_package   => c_pkg,
            p_procedure => c_proc
        );

        FOR rec IN (SELECT csv_landing_id
                      FROM dmt_csv_landing_tbl
                     WHERE status = 'PENDING'
                     ORDER BY csv_landing_id) LOOP
            BEGIN
                LOAD_CSV(rec.csv_landing_id);
                v_ok := v_ok + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_err := v_err + 1;
            END;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_message   => 'All pending complete: ' || v_ok || ' loaded, ' || v_err || ' failed',
            p_package   => c_pkg,
            p_procedure => c_proc
        );
    END LOAD_ALL_PENDING;

END DMT_CSV_LOADER_PKG;
/
