-- PACKAGE DMT_AP_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_AP_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_AP_TRANSFORM_PKG
-- Transforms staged AP Invoice records into the transformed tables.
-- Applies run prefix to INVOICE_NUM, dependent prefix to VENDOR_NUM,
-- and derives INVOICE_ID when not supplied.
--
-- Two object types: invoice headers and invoice lines.
-- Called by DMT_LOADER_PKG before FBDI generation.
--
-- Staging STATUS lifecycle managed here:
--   NEW / RETRY  -> TRANSFORMED (success) or FAILED (exception)
--
-- TFM STATUS set on insert:
--   STAGED (ready for FBDI generation)
-- ============================================================

    -- Transform eligible AP invoice header staging rows for this run.
    -- Applies run prefix to INVOICE_NUM, dep_prefix to VENDOR_NUM.
    -- Derives INVOICE_ID = run_id * 10000 + stg_seq_id when NULL.
    -- When p_inv_type_filter is non-NULL, only processes staging rows with
    -- matching INVOICE_TYPE_LOOKUP_CODE (uses LIKE, e.g. '%1099%').
    -- This allows 1099Invoices and APInvoices to share the same tables
    -- but transform independently.
    PROCEDURE TRANSFORM_HEADERS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_inv_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    -- Transform eligible AP invoice line staging rows for this run.
    -- Copies INVOICE_ID from staging (links to header).
    -- When p_inv_type_filter is non-NULL, only processes lines whose
    -- parent header matches the INVOICE_TYPE_LOOKUP_CODE filter.
    PROCEDURE TRANSFORM_LINES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_inv_type_filter  IN VARCHAR2 DEFAULT NULL,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_AP_TRANSFORM_PKG;
/
