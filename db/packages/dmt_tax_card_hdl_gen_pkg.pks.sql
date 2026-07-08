-- PACKAGE DMT_TAX_CARD_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_TAX_CARD_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_TAX_CARD_HDL_GEN_PKG
-- Generates the CalculationCard.dat HDL file from TFM staging records.
--
-- CalculationCard HDL is ONE zip containing ONE DAT file with 2 business object(s):
--   CalculationCard, CardComponent.
--
-- OBJECT_TYPE = 'TaxCards'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_TAX_CARD_HDL_GEN_PKG;
/
