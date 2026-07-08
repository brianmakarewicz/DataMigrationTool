-- PACKAGE DMT_BILLING_EVENT_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BILLING_EVENT_FBDI_GEN_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_BILLING_EVENT_FBDI_GEN_PKG spec
-- Billing Events FBDI zip generation.
-- Single CSV: PjbBillingEventsXface.csv
-- Single submission (not grouped).
-- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER
    );
END DMT_BILLING_EVENT_FBDI_GEN_PKG;
/
