-- PACKAGE DMT_BILLING_EVENT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BILLING_EVENT_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_BILLING_EVENT_RESULTS_PKG spec
-- Billing Events reconciliation. CEMLI_CODE: 'BillingEvents'
--
-- Three-tier reconciliation:
--   Tier 1: BIP query on PJB_BILLING_EVENTS_INT (interface table — always purged, rarely returns rows)
--   Tier 2: BIP query on PJB_BILLING_EVENTS (base table, positive confirmation of LOADED)
--   Tier 3: Import Report XML from ImportBillingEventReportJob ESS output
--           (G_6 rows = full interface snapshot with IMPORT_STATUS; G_7 = per-row error messages)
--
-- PJB_BILLING_EVENTS_INT is ALWAYS purged after ImportBillingEventJob completes (MOS 2534525.1).
-- Tier 3 is the primary source for error details. Tier 2 catches successes.
-- Single table, no cascade.
-- ============================================================
    PROCEDURE RECONCILE_BATCH (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL);
    FUNCTION FETCH_BIP_RESULTS (p_run_id IN NUMBER, p_load_ess_id IN NUMBER, p_import_ess_id IN NUMBER DEFAULT NULL) RETURN CLOB;
    PROCEDURE PARSE_AND_UPDATE (p_run_id IN NUMBER, p_xml_data IN CLOB, p_import_ess_id IN NUMBER DEFAULT NULL);
END DMT_BILLING_EVENT_RESULTS_PKG;
/
