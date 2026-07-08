-- PACKAGE DMT_CSV_LOADER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CSV_LOADER_PKG" AS
-- =============================================================================
-- DMT_CSV_LOADER_PKG
-- Parses CSV CLOBs from DMT_CSV_LANDING_TBL and loads into target STG tables.
--
-- CSV format expected:
--   Row 1: column headers (comma-separated, no quoting needed)
--   Row 2+: data rows (comma-separated, quoted if value contains , " or newline)
--
-- Column intersection: only CSV columns that match the target STG table are
-- loaded. Infrastructure columns (STG_SEQUENCE_ID, STAGE_DATE, STATUS, etc.)
-- are left to their DB defaults.
--
-- Scenario support: if SCENARIO_NAME is set on the landing row, it is resolved
-- to SCENARIO_ID via DMT_UTIL_PKG.GET_OR_CREATE_SCENARIO and stamped on each
-- inserted row (if the target table has a SCENARIO_ID column).
-- =============================================================================

    -- Load one specific landing row by ID.
    -- All-or-nothing: either every row loads or none do.
    -- On failure, the landing row captures the exact row number,
    -- error, and row data for diagnostics.
    PROCEDURE LOAD_CSV (
        p_csv_landing_id  IN NUMBER
    );

    -- Load all PENDING rows for a specific batch
    PROCEDURE LOAD_BATCH (
        p_batch_id IN VARCHAR2
    );

    -- Load all PENDING rows across all batches
    PROCEDURE LOAD_ALL_PENDING;

END DMT_CSV_LOADER_PKG;
/
