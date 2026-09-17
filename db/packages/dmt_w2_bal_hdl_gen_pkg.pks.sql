-- PACKAGE DMT_W2_BAL_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_W2_BAL_HDL_GEN_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_W2_BAL_HDL_GEN_PKG
-- Generates the payroll Balance Initialization HDL files from TFM staging
-- records.
--
-- CORRECTED MODEL (2026-09-17): Oracle's current HCM Data Loader business
-- object for initializing payroll balances is "Balance Initialization",
-- loaded as TWO business objects in ONE zip:
--   - InitializeBalanceBatchHeader  -> InitializeBalanceBatchHeader.dat
--   - InitializeBalanceBatchLine    -> InitializeBalanceBatchLine.dat
-- A "Load Initial Balances" (Transfer Batch) payroll flow is then run inside
-- Fusion to move the staged batch into balances -- that is a post-load
-- functional step, not part of the HDL file.
--
-- The header carries the BATCH (BatchName|UploadDate|LegislativeDataGroupName);
-- every line references the header by BatchName. Lines carry the person /
-- payroll / balance detail -- worker records are NOT repeated.
--
-- One run = ONE batch. BatchName = <prefix>_W2BAL, and that BatchName is the
-- reconciliation key: the loaded batch appears in PAY_BAL_BATCH_HEADERS with
-- BATCH_NAME = the BatchName and BATCH_ID as the Fusion id.
--
-- This REPLACES the outdated 'PayrollBalanceInitialization.dat' /
-- BalanceInitialization + BalInitializationDetails objects, which Fusion
-- rejects (16+ filename variants all failed -- see objects/W2Balances/v2_audit.md).
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
