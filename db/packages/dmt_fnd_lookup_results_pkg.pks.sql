-- PACKAGE DMT_FND_LOOKUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_FND_LOOKUP_RESULTS_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_FND_LOOKUP_RESULTS_PKG
-- FND Lookup Types + Values: REST load + BIP base-table reconciliation.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation MUST be a BIP report over the Fusion BASE tables. A REST
-- load-call HTTP 200 is NOT reconciliation. Lookups is a two-tier load (a
-- lookup type, then its child lookup codes), so LOAD and RECONCILE are two
-- separate phases, each covering both tiers.
--
-- SPECIAL CASE -- no numeric surrogate id. FND lookups have only string keys:
-- FND_LOOKUP_TYPES is keyed by LOOKUP_TYPE, FND_LOOKUP_VALUES_B by
-- LOOKUP_TYPE + LOOKUP_CODE. There is NO LOOKUP_TYPE_ID / LOOKUP_ID numeric
-- column. Reconciliation therefore confirms EXISTENCE by the string key (the
-- honest base-table proof), marks the matching TFM row LOADED, and LEAVES
-- FUSION_LOOKUP_TYPE_ID / FUSION_LOOKUP_ID NULL -- there is no id to capture.
-- The report returns RECORD_KEY + SOURCE_TYPE only (no FUSION_ID column).
--
--   LOAD  (LOAD_TYPES / LOAD_VALUES): POST each GENERATED type to the
--         standardLookups REST resource, then POST each GENERATED value to the
--         type's child lookupCodes collection. A non-2xx / exception is a real
--         Fusion rejection: its message is STASHED into ERROR_TEXT (accumulate,
--         never overwrite). Rows are NOT marked terminal here -- left GENERATED,
--         pending base-table proof. A 2xx is NOT treated as LOADED.
--
--   RECONCILE (FETCH_BIP_RESULTS + PARSE_AND_UPDATE): run DMT_LOOKUP_RECON_RPT
--         over this run's type codes and value keys. A type found in
--         FND_LOOKUP_TYPES -> LOADED (FUSION_LOOKUP_TYPE_ID left NULL). A value
--         found in FND_LOOKUP_VALUES_B -> LOADED (FUSION_LOOKUP_ID left NULL).
--         Rows not returned stay as the load step set them: FAILED if the REST
--         load stashed a real error, else left GENERATED (unaccounted) -- never
--         a fabricated verdict or id.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT. Base tables:
-- FND_LOOKUP_TYPES (key LOOKUP_TYPE) and FND_LOOKUP_VALUES_B (key
-- LOOKUP_TYPE + LOOKUP_CODE). Backlog #11 / new recon standard.
-- ============================================================

    -- Load all GENERATED TFM rows to Fusion via REST, then reconcile against the
    -- Fusion base tables via the BIP report (the new standard).
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER
    );

END DMT_FND_LOOKUP_RESULTS_PKG;
/
