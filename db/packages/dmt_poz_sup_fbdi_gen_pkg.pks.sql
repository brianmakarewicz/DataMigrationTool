-- PACKAGE DMT_POZ_SUP_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_FBDI_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_POZ_SUP_FBDI_GEN_PKG
-- Generates the Supplier header FBDI zip from VALIDATED staging records.
-- Interface table: POZ_SUPPLIERS_INT
-- FBDI file: PoSupplierImport.csv
-- Uses DMT_OWNER.UTL_ZIP (Anton Scheffer) for zip construction.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2
    );

END DMT_POZ_SUP_FBDI_GEN_PKG;
/
