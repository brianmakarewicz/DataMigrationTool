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
END DMT_BLANKET_PO_FBDI_GEN_PKG;
/
