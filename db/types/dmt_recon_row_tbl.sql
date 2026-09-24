-- DMT_RECON_ROW_OBJ / DMT_RECON_ROW_TBL — the BIP reconciliation report
-- contract v1 carrier type for a single reconciliation report row.
--
-- Every conforming reconciler pages its Contract v1 report keyset-style
-- into a collection of this type (BULK COLLECT from XMLTABLE over the NINE
-- standard columns), then applies the whole run in set-based statements per
-- outcome by joining TABLE(:l_rows) to the object's TFM table on the recon
-- key. No per-row PL/SQL loop marks LOADED/FAILED — the collection is the
-- join input. This is the shared join carrier for every conforming
-- reconciler.
--
-- The NINE standard columns, in the contract order (see docs/DMT_DESIGN.html,
-- "BIP reconciliation report contract — v1"):
--   OBJECT_TYPE     — sub-object discriminator (record type within the FBDI);
--                     single-record-type objects return the object code
--   RECORD_KEY      — the business key, matched to the TFM row's RECON_KEY
--   SOURCE_TYPE     — 'BASE' or 'INTERFACE' — which tier the row came from
--   FUSION_STATUS   — normalized in the DM to exactly 'SUCCESS' or 'ERROR'
--   FUSION_ID       — the Fusion base-table id (non-null on BASE/SUCCESS);
--                     VARCHAR2 so an object whose proof-of-load is at a finer
--                     grain than the header can carry a '~'-joined composite
--                     (e.g. GLBalances stores JE_HEADER_ID~JE_LINE_NUM);
--                     objects with a plain numeric id store it as digits and
--                     it converts implicitly when assigned to a NUMBER column
--   ERROR_MESSAGE   — real Fusion error text (non-null on ERROR rows)
--   LOAD_REQUEST_ID — the request id the row matched on (audit)
--   SOURCE_REF      — Slot A native source-ref read back from Fusion (audit)
--   DMT_REFERENCE   — Slot C full DMT:run:queue:tfm reference (round-trip)
--
-- Re-runnable: the collection type depends on the object type, so a
-- CREATE OR REPLACE of the object type alone silently fails (ORA-02303)
-- once the collection exists — and any column-list change to the object
-- type needs both dropped and recreated. Drop the collection then the
-- object type first (FORCE, ignoring "does not exist" on a fresh DB),
-- then recreate both cleanly. This makes a re-install pick up column-list
-- changes to the nine standard columns without manual intervention.
DECLARE
    PROCEDURE drop_type(p_name IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'DROP TYPE ' || p_name || ' FORCE';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -4043 THEN RAISE; END IF;  -- -4043 = does not exist
    END;
BEGIN
    drop_type('DMT_RECON_ROW_TBL');
    drop_type('DMT_RECON_ROW_OBJ');
END;
/

CREATE OR REPLACE TYPE "DMT_RECON_ROW_OBJ" AS OBJECT (
    OBJECT_TYPE     VARCHAR2(60),
    RECORD_KEY      VARCHAR2(1000),
    SOURCE_TYPE     VARCHAR2(20),
    FUSION_STATUS   VARCHAR2(20),
    FUSION_ID       VARCHAR2(200),
    ERROR_MESSAGE   VARCHAR2(4000),
    LOAD_REQUEST_ID NUMBER,
    SOURCE_REF      VARCHAR2(240),
    DMT_REFERENCE   VARCHAR2(240)
);
/

CREATE OR REPLACE TYPE "DMT_RECON_ROW_TBL" AS TABLE OF "DMT_RECON_ROW_OBJ";
/
