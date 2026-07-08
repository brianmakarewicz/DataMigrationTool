-- PACKAGE DMT_POZ_SUP_CONT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_POZ_SUP_CONT_FBDI_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_POZ_SUP_CONT_FBDI_GEN_PKG
-- Generates the Supplier Contact FBDI zip from VALIDATED staging records.
-- Interface table: POZ_SUP_CONTACTS_INT
-- FBDI file: PoSupplierContactImport.csv
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2
    );

END DMT_POZ_SUP_CONT_FBDI_GEN_PKG;
/
