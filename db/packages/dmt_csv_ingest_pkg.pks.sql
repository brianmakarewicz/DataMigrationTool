-- PACKAGE DMT_CSV_INGEST_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CSV_INGEST_PKG" AS
-- =============================================================================
-- DMT_CSV_INGEST_PKG
-- Chunked, remote-safe ingest of large CSV CLOBs into DMT_CSV_LANDING_TBL.
--
-- Why this package exists (issue #469):
--   The EBS-side push builds a CSV as a CLOB on the EBS database and must land
--   it in DMT_CSV_LANDING_TBL@ATP_LINK. A CLOB cannot be transferred whole over
--   a database link:
--     - a direct distributed INSERT ... SELECT csv_data silently TRUNCATES the
--       CLOB at ~8000 chars, and
--     - a chunked remote UPDATE ... SET csv_data = csv_data || :chunk fails with
--       ORA-22992 (cannot use LOB locators selected from remote tables).
--   The fix is to append the LOB HERE, on the ATP side, running as DMT2_OWNER,
--   so the LOB append is LOCAL (no ORA-22992). The EBS push calls these two
--   procedures remotely with VARCHAR2 arguments, which the link fully supports.
--
-- Usage (from the EBS adaptor, over ATP_LINK):
--   1. DMT_CSV_INGEST_PKG.START_FILE(batch, view, atp_table, file, rows,
--                                    scenario, first_chunk)  -- resets + first chunk
--   2. DMT_CSV_INGEST_PKG.APPEND_CHUNK(batch, view, next_chunk)  -- repeat N times
--   The landing row is then picked up by DMT_CSV_LOADER_PKG in the normal way.
--
-- All string parameters are VARCHAR2 (chunks up to 32767 chars per call).
-- Both procedures COMMIT (see body header for rationale).
-- =============================================================================

    -- Begin (or restart) ingest of one file. Deletes any prior landing row for
    -- (p_batch_id, p_view_name), then inserts a fresh row whose CSV_DATA is
    -- p_first_chunk and whose STATUS is 'PENDING'. Idempotent per file: calling
    -- it again for the same batch/view discards a half-built row and starts over.
    PROCEDURE START_FILE (
        p_batch_id       IN VARCHAR2,
        p_view_name      IN VARCHAR2,
        p_atp_table_name IN VARCHAR2,
        p_file_name      IN VARCHAR2,
        p_row_count      IN NUMBER,
        p_scenario_name  IN VARCHAR2,
        p_first_chunk    IN VARCHAR2
    );

    -- Append one more chunk to the CSV_DATA of the landing row identified by
    -- (p_batch_id, p_view_name). This is a LOCAL LOB append (no ORA-22992).
    -- Raises ORA-20469 if no matching landing row exists (START_FILE not called).
    PROCEDURE APPEND_CHUNK (
        p_batch_id  IN VARCHAR2,
        p_view_name IN VARCHAR2,
        p_chunk     IN VARCHAR2
    );

END DMT_CSV_INGEST_PKG;
/
