-- PACKAGE DMT_BILLING_EVENT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BILLING_EVENT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_BILLING_EVENT_TRANSFORM_PKG spec
-- Billing Events transformation: STG -> TFM with prefix application.
-- Single object type: billing events.
-- ============================================================
    PROCEDURE TRANSFORM_EVENTS (p_run_id IN NUMBER, p_reprocess_errors IN BOOLEAN DEFAULT FALSE, p_scenario_id IN NUMBER DEFAULT NULL, p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW');
END DMT_BILLING_EVENT_TRANSFORM_PKG;
/
