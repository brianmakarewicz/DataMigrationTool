-- DMT_RUN_SWEEP_OBJ / DMT_RUN_SWEEP_TBL — carrier type for the end-of-run
-- Fusion-side load-summary sweep (backlog #93, DMT_RUN_SUMMARY_PKG.GET_RUN_FUSION_SWEEP).
--
-- One instance per object the run touched. The sweep procedure accumulates the
-- per-object counts in PL/SQL (looping the objects, calling the shared Contract
-- v1 BIP fetch per object), appends one of these objects per object, then opens
-- the OUT cursor over TABLE(the collection) so the result is a single static
-- SELECT — no dynamic SQL, no temp table. This mirrors the DMT_RECON_ROW_TBL
-- "collection as the SQL carrier" pattern used across the reconcilers.
--
-- Columns:
--   CEMLI_CODE        the object's registry key (DMT_BIP_REPORT_TBL.CEMLI_CODE)
--   OBJECT_TYPE       human-readable object label
--   CONTRACT_VERSION  the object's DMT_BIP_REPORT_TBL.CONTRACT_VERSION (NULL = legacy)
--   TFM_TOTAL_ROWS    our own total record count for the run/object (DMT_RUN_RECORDS_V)
--   TFM_LOADED_ROWS   our own LOADED count for the run/object (the TFM-side truth)
--   FUSION_BASE_ROWS  base rows Fusion returned for the run (BASE + SUCCESS + id)
--   FUSION_ID_COUNT   distinct non-null FUSION_IDs among those base rows
--   FUSION_ERROR_ROWS rows Fusion returned as FUSION_STATUS='ERROR'
--   SWEEP_STATUS      'SWEPT' | 'SKIPPED' | 'FETCH_FAILED'
--   FETCH_NOTE        short human note (skip/failed reason, or NULL on SWEPT)
--
-- Re-runnable: the collection type depends on the object type, so drop the
-- collection then the object type first (FORCE, ignoring "does not exist"),
-- then recreate both — so a re-install picks up any column-list change.
DECLARE
    PROCEDURE drop_type(p_name IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'DROP TYPE ' || p_name || ' FORCE';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -4043 THEN RAISE; END IF;  -- -4043 = does not exist
    END;
BEGIN
    drop_type('DMT_RUN_SWEEP_TBL');
    drop_type('DMT_RUN_SWEEP_OBJ');
END;
/

CREATE OR REPLACE TYPE "DMT_RUN_SWEEP_OBJ" AS OBJECT (
    CEMLI_CODE        VARCHAR2(60),
    OBJECT_TYPE       VARCHAR2(100),
    CONTRACT_VERSION  NUMBER,
    TFM_TOTAL_ROWS    NUMBER,
    TFM_LOADED_ROWS   NUMBER,
    FUSION_BASE_ROWS  NUMBER,
    FUSION_ID_COUNT   NUMBER,
    FUSION_ERROR_ROWS NUMBER,
    SWEEP_STATUS      VARCHAR2(20),
    FETCH_NOTE        VARCHAR2(400)
);
/

CREATE OR REPLACE TYPE "DMT_RUN_SWEEP_TBL" AS TABLE OF "DMT_RUN_SWEEP_OBJ";
/
