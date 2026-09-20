-- DMT_RECON_ROW_OBJ / DMT_RECON_ROW_TBL — the BIP Reconciliation Standard
-- carrier type for a single reconciliation report row (reference impl, P1).
--
-- Every conforming reconciler fetches each report page into a collection of
-- this type (BULK COLLECT from XMLTABLE over the six standard columns), then
-- applies the whole run in ONE set-based statement per outcome by joining
-- TABLE(:l_rows) to the object's TFM table on the recon key. No per-row
-- PL/SQL loop marks LOADED/FAILED — the collection is the join input.
--
-- The six standard columns (see docs/DMT_DESIGN.html, BIP Reconciliation
-- Standard):
--   RECORD_KEY    — the per-record recon key, matched to TFM RECON_KEY
--   FUSION_ID     — the Fusion base-table id (non-null on BASE/LOADED rows)
--   SOURCE_REF    — the source reference stamped to Fusion (audit)
--   DMT_REFERENCE — the run-scoped reference stamped to Fusion (round-trip)
--   SOURCE_TYPE   — 'BASE' or 'INTERFACE'
--   ERROR_MESSAGE — real Fusion error text; NULL means no error for that row
--
-- Re-runnable: CREATE OR REPLACE TYPE.
CREATE OR REPLACE TYPE "DMT_RECON_ROW_OBJ" AS OBJECT (
    RECORD_KEY    VARCHAR2(1000),
    FUSION_ID     NUMBER,
    SOURCE_REF    VARCHAR2(240),
    DMT_REFERENCE VARCHAR2(240),
    SOURCE_TYPE   VARCHAR2(20),
    ERROR_MESSAGE VARCHAR2(4000)
);
/

CREATE OR REPLACE TYPE "DMT_RECON_ROW_TBL" AS TABLE OF "DMT_RECON_ROW_OBJ";
/
