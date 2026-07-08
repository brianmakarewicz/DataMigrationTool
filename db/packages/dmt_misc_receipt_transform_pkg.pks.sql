-- PACKAGE DMT_MISC_RECEIPT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_MISC_RECEIPT_TRANSFORM_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_MISC_RECEIPT_TRANSFORM_PKG
-- Transforms inventory transaction staging data (On Hand Qty)
-- into TFM tables for FBDI generation.
-- Uses INV_TRANSACTIONS_INTERFACE per MCCS RICE_011/012.
-- Replaces the old RCV-based approach.
-- ============================================================

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_MISC_RECEIPT_TRANSFORM_PKG;
/
