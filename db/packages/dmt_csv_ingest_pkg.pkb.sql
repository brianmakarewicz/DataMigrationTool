-- PACKAGE BODY DMT_CSV_INGEST_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CSV_INGEST_PKG" AS
-- =============================================================================
-- DMT_CSV_INGEST_PKG — body
--
-- COMMIT policy (deliberate, per issue #469):
--   Both START_FILE and APPEND_CHUNK COMMIT before returning. Each is a SEPARATE
--   remote call from the EBS adaptor across ATP_LINK. A distributed transaction
--   left open across many round-trips ties up link resources and is fragile if
--   the link drops mid-stream; committing at each call keeps every remote call
--   self-contained and makes the partially-built CSV durable between chunks. The
--   row is not loaded until DMT_CSV_LOADER_PKG runs, so committing per chunk does
--   not expose an incomplete file to the loader. This mirrors DMT_CSV_LOADER_PKG,
--   which commits at each boundary rather than holding one long transaction.
-- =============================================================================

    c_pkg CONSTANT VARCHAR2(30) := 'DMT_CSV_INGEST_PKG';

    -- -------------------------------------------------------------------------
    -- START_FILE
    -- -------------------------------------------------------------------------
    PROCEDURE START_FILE (
        p_batch_id       IN VARCHAR2,
        p_view_name      IN VARCHAR2,
        p_atp_table_name IN VARCHAR2,
        p_file_name      IN VARCHAR2,
        p_row_count      IN NUMBER,
        p_scenario_name  IN VARCHAR2,
        p_first_chunk    IN VARCHAR2
    ) IS
        c_proc CONSTANT VARCHAR2(30) := 'START_FILE';
    BEGIN
        -- Discard any prior (possibly half-built) landing row for this file so
        -- a restart starts clean.
        DELETE FROM dmt_csv_landing_tbl
         WHERE batch_id  = p_batch_id
           AND view_name = p_view_name;

        -- Fresh landing row. CSV_DATA seeded with the first chunk; APPEND_CHUNK
        -- adds the rest. TO_CLOB makes the VARCHAR2 -> CLOB conversion explicit.
        INSERT INTO dmt_csv_landing_tbl (
            batch_id,
            view_name,
            atp_table_name,
            file_name,
            csv_data,
            row_count,
            scenario_name,
            status
        ) VALUES (
            p_batch_id,
            p_view_name,
            p_atp_table_name,
            p_file_name,
            TO_CLOB(p_first_chunk),
            p_row_count,
            p_scenario_name,
            'PENDING'
        );

        COMMIT;

        DMT_UTIL_PKG.LOG(
            p_message   => 'START_FILE: landing row created for batch=' || p_batch_id ||
                           ', view=' || p_view_name || ' (' || p_atp_table_name ||
                           '), rows=' || p_row_count ||
                           ', scenario=' || p_scenario_name,
            p_package   => c_pkg,
            p_procedure => c_proc
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'START_FILE failed for batch=' || p_batch_id ||
                               ', view=' || p_view_name,
                p_sqlerrm   => SQLERRM,
                p_package   => c_pkg,
                p_procedure => c_proc
            );
            RAISE;
    END START_FILE;

    -- -------------------------------------------------------------------------
    -- APPEND_CHUNK
    -- Local LOB append (no ORA-22992 because the LOB is now local to ATP).
    -- -------------------------------------------------------------------------
    PROCEDURE APPEND_CHUNK (
        p_batch_id  IN VARCHAR2,
        p_view_name IN VARCHAR2,
        p_chunk     IN VARCHAR2
    ) IS
        c_proc CONSTANT VARCHAR2(30) := 'APPEND_CHUNK';
    BEGIN
        UPDATE dmt_csv_landing_tbl
           SET csv_data = csv_data || p_chunk
         WHERE batch_id  = p_batch_id
           AND view_name = p_view_name;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20469,
                'APPEND_CHUNK: no landing row for ' || p_batch_id || '/' ||
                p_view_name || ' — call START_FILE first');
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'APPEND_CHUNK failed for batch=' || p_batch_id ||
                               ', view=' || p_view_name,
                p_sqlerrm   => SQLERRM,
                p_package   => c_pkg,
                p_procedure => c_proc
            );
            RAISE;
    END APPEND_CHUNK;

END DMT_CSV_INGEST_PKG;
/
