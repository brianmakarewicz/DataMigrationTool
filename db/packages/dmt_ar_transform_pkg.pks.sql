-- PACKAGE DMT_AR_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AR_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_AR_TRANSFORM_PKG
-- Transforms staged AR Invoice records into TFM tables.
-- Applies run prefix to TRX_NUMBER.
-- Applies dependent prefix to customer references
-- (BILL_CUSTOMER_ACCOUNT_NUMBER, SHIP_CUSTOMER_ACCOUNT_NUMBER).
--
-- AR AutoInvoice is a single zip with 2 CSVs.
-- Lines and distributions linked via INTERFACE_LINE_ATTRIBUTE1-6.
-- ============================================================

    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_DISTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_AR_TRANSFORM_PKG;
/
