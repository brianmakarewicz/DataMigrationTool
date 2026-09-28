-- DMT_CMP_ROW_OBJ / DMT_CMP_ROW_TAB — the uniform post-run comparison-row
-- carrier type. Every object's GET_COMPARISON function returns a
-- DMT_CMP_ROW_TAB of these rows, read positionally by the framework and the
-- APEX comparison region. Attribute order is a hard interface contract —
-- do not reorder without updating every consumer.
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
