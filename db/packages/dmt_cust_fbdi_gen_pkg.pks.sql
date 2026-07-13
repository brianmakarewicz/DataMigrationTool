-- PACKAGE DMT_CUST_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CUST_FBDI_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_CUST_FBDI_GEN_PKG
-- Generates the Customer FBDI zip from TFM staging records.
--
-- Customer FBDI is ONE zip containing SEVEN CSVs (all share
-- a single BulkImportJob ESS job submission).
--
-- CSV files (Oracle FBDI filenames):
--   HzImpPartiesT.csv          -> HZ_IMP_PARTIES_T
--   HzImpLocationsT.csv        -> HZ_IMP_LOCATIONS_T
--   HzImpPartySitesT.csv       -> HZ_IMP_PARTYSITES_T
--   HzImpPartySiteUsesT.csv    -> HZ_IMP_PARTYSITEUSES_T
--   HzImpAccountsT.csv         -> HZ_IMP_ACCOUNTS_T
--   HzImpAcctSitesT.csv        -> HZ_IMP_ACCTSITES_T
--   HzImpAcctSiteUsesT.csv     -> HZ_IMP_ACCTSITEUSES_T
--
-- Column order in each CSV must match the Fusion FBDI CTL file.
-- No header row — Oracle FBDI CSVs are data-only, position-based.
-- ============================================================

    PROCEDURE GENERATE_FBDI (
        p_run_id IN  NUMBER,
        x_fbdi_zip       OUT BLOB,
        x_filename       OUT VARCHAR2,
        x_fbdi_csv_id    OUT NUMBER,
        -- Partition filter: NULL = whole run (backward compatible); a value emits
        -- and flips to GENERATED only that batch's rows (Customers-by-BATCH_ID).
        p_batch_id       IN  NUMBER DEFAULT NULL
    );

END DMT_CUST_FBDI_GEN_PKG;
/
