-- PACKAGE DMT_CONTRACT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CONTRACT_FBDI_GEN_PKG" AUTHID DEFINER AS
-- Contracts FBDI zip generation. 1 CSV: PoHeadersInterfaceOrder.csv only.
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        p_prc_bu_name     IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );
END DMT_CONTRACT_FBDI_GEN_PKG;
/
