-- PACKAGE DMT_AR_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AR_FBDI_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_AR_FBDI_GEN_PKG
-- Generates the AR AutoInvoice FBDI zip from TFM records.
--
-- AR AutoInvoice is ONE zip containing TWO CSVs:
--   RaInterfaceLinesAll.csv          -> RA_INTERFACE_LINES_ALL
--   RaInterfaceDistributionsAll.csv  -> RA_INTERFACE_DISTRIBUTIONS_ALL
--
-- Single ESS job: AutoInvoiceImportEss
-- UCM account: fin/receivables/import
--
-- May require BU-scoped submission (similar to PO multi-BU).
-- p_bu_name filters lines/dists to a specific Business Unit.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id    IN  NUMBER,
        p_bu_name           IN  VARCHAR2 DEFAULT NULL,
        p_batch_source_name IN  VARCHAR2 DEFAULT NULL,
        x_fbdi_zip          OUT BLOB,
        x_filename          OUT VARCHAR2,
        x_fbdi_csv_id       OUT NUMBER
    );

END DMT_AR_FBDI_GEN_PKG;
/
