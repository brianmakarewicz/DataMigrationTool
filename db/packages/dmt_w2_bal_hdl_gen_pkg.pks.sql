-- PACKAGE DMT_W2_BAL_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_W2_BAL_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_W2_BAL_HDL_GEN_PKG
-- Generates the PayrollBalanceInitialization.dat HDL file from TFM staging records.
--
-- PayrollBalanceInitialization HDL is ONE zip containing ONE DAT file with 2 business object(s):
--   BalanceInitialization, BalInitializationDetails.
--
-- OBJECT_TYPE = 'W2Balances'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_W2_BAL_HDL_GEN_PKG;
/
