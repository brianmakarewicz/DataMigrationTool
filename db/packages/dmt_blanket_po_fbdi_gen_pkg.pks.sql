-- PACKAGE DMT_BLANKET_PO_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BLANKET_PO_FBDI_GEN_PKG" AUTHID DEFINER AS
-- BlanketPOs FBDI zip generation.
-- 2 CSVs: PoHeadersInterfaceOrder.csv + PoLinesInterfaceOrder.csv (no locs/dists).
-- Grouped by PRC_BU_NAME — same as standard POs.
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        p_prc_bu_name     IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );

    -- FAIL_GENERATED_ROWS -- the BU zip's load failed (backlog #674).
    -- Marks every GENERATED row of the run's blanket zip for p_prc_bu_name
    -- (NULL = all BUs) FAILED with p_error_text, in BOTH record types
    -- (agreement headers and agreement lines). The caller
    -- (DMT_LOADER_PKG.po_mark_bu_failed, synchronous load-failure path) passes the
    -- [LOAD_ERROR] text; this procedure never composes one. LOADED, STAGED and
    -- FAILED rows, standard-PO and contract rows are never touched.
    -- NO COMMIT (the caller commits).
    -- x_rows_failed = rows changed across the two tables.
    -- x_error_code  = DMT_UTIL_PKG.C_SUCCESS / C_ERROR (failure logged).
    PROCEDURE FAIL_GENERATED_ROWS (
        p_run_id      IN  NUMBER,
        p_prc_bu_name IN  VARCHAR2,
        p_error_text  IN  VARCHAR2,
        x_rows_failed OUT NUMBER,
        x_error_code  OUT NUMBER
    );
END DMT_BLANKET_PO_FBDI_GEN_PKG;
/
