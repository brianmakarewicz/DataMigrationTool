-- DMT_CMP_ROW_OBJ / DMT_CMP_ROW_TAB — the uniform post-run comparison-row
-- carrier type. Every object's GET_COMPARISON function returns a
-- DMT_CMP_ROW_TAB of these rows, read positionally by the framework and the
-- APEX comparison region. Attribute order is a hard interface contract —
-- do not reorder without updating every consumer.
--
-- Re-runnable: the collection type depends on the object type, so a
-- CREATE OR REPLACE of the object type alone silently fails (ORA-02303)
-- once the collection exists — and any column-list change to the object
-- type needs both dropped and recreated. Drop the collection then the
-- object type first (FORCE, ignoring "does not exist" on a fresh DB),
-- then recreate both cleanly. This makes a re-install pick up column-list
-- changes to the 15 standard attributes without manual intervention.
DECLARE
    PROCEDURE drop_type(p_name IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'DROP TYPE ' || p_name || ' FORCE';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -4043 THEN RAISE; END IF;  -- -4043 = does not exist
    END;
BEGIN
    drop_type('DMT_CMP_ROW_TAB');
    drop_type('DMT_CMP_ROW_OBJ');
END;
/

CREATE OR REPLACE TYPE DMT_CMP_ROW_OBJ AS OBJECT (
    OBJECT_TYPE            VARCHAR2(100),
    CEMLI_CODE             VARCHAR2(60),
    KEY_TYPE               VARCHAR2(20),   -- LOAD_ID | IMPORT_ID | STAMPED_REF | CAPTURED_ID | NONE
    STG_COUNT              NUMBER,
    STG_AMOUNT             NUMBER,
    TFM_ERROR_COUNT        NUMBER,
    TFM_ERROR_AMOUNT       NUMBER,
    FUSION_SUCCESS_COUNT   NUMBER,
    FUSION_SUCCESS_AMOUNT  NUMBER,
    AMOUNT_CURRENCY        VARCHAR2(15),
    FUSION_MONEY_AVAILABLE VARCHAR2(1),    -- Y | N
    VARIANCE_COUNT         NUMBER,
    VARIANCE_AMOUNT        NUMBER,
    IN_BALANCE             VARCHAR2(1),     -- Y | N | ? (unknown: Fusion side not available)
    NOTE                   VARCHAR2(400)
);
/
CREATE OR REPLACE TYPE DMT_CMP_ROW_TAB AS TABLE OF DMT_CMP_ROW_OBJ;
/
