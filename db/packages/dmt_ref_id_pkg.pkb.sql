-- PACKAGE BODY DMT_REF_ID_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REF_ID_PKG" AS
-- ============================================================
-- DMT_REF_ID_PKG body. Pure PL/SQL id-writer (backlog #12).
-- Single sanctioned config SELECT; no dynamic SQL.
-- ============================================================

    -- --------------------------------------------------------
    -- BUILD_REF
    -- --------------------------------------------------------
    FUNCTION BUILD_REF (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER,
        p_tfm_seq_id    IN NUMBER,
        p_format        IN VARCHAR2 DEFAULT 'FULL'
    ) RETURN VARCHAR2
    IS
    BEGIN
        IF UPPER(p_format) = C_FMT_COMPACT THEN
            RETURN C_PREFIX || ':' || TO_CHAR(p_tfm_seq_id);
        ELSE
            -- FULL (the default, and any unrecognised format).
            RETURN C_PREFIX || ':' || TO_CHAR(p_run_id)
                             || ':' || TO_CHAR(p_work_queue_id)
                             || ':' || TO_CHAR(p_tfm_seq_id);
        END IF;
    END BUILD_REF;

    -- --------------------------------------------------------
    -- GET_CARRIER
    -- One sanctioned SELECT against the config table.
    -- --------------------------------------------------------
    FUNCTION GET_CARRIER (
        p_tfm_table IN VARCHAR2
    ) RETURN t_carrier
    IS
        l_rec t_carrier;
    BEGIN
        l_rec.found := FALSE;

        SELECT cemli_code, sub_object, tfm_table,
               slot_a_field, slot_a_base_column, slot_b_field,
               slot_c_attribute, slot_c_maxlen,
               ref_format, confidence, active_flag
          INTO l_rec.cemli_code, l_rec.sub_object, l_rec.tfm_table,
               l_rec.slot_a_field, l_rec.slot_a_base_col, l_rec.slot_b_field,
               l_rec.slot_c_attribute, l_rec.slot_c_maxlen,
               l_rec.ref_format, l_rec.confidence, l_rec.active_flag
          FROM dmt_ref_carrier_cfg_tbl
         WHERE UPPER(tfm_table) = UPPER(p_tfm_table)
           AND active_flag = 'Y';

        l_rec.found := TRUE;            -- reached only when the SELECT found a row
        RETURN l_rec;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_rec := NULL;              -- reset every field
            l_rec.found := FALSE;
            RETURN l_rec;
    END GET_CARRIER;

    -- --------------------------------------------------------
    -- Convenience getters
    -- --------------------------------------------------------
    FUNCTION GET_SLOT_A_FIELD (p_tfm_table IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN GET_CARRIER(p_tfm_table).slot_a_field;
    END GET_SLOT_A_FIELD;

    FUNCTION GET_SLOT_A_BASE_COL (p_tfm_table IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN GET_CARRIER(p_tfm_table).slot_a_base_col;
    END GET_SLOT_A_BASE_COL;

    FUNCTION GET_SLOT_B_FIELD (p_tfm_table IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN GET_CARRIER(p_tfm_table).slot_b_field;
    END GET_SLOT_B_FIELD;

    FUNCTION GET_SLOT_C_ATTRIBUTE (p_tfm_table IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN GET_CARRIER(p_tfm_table).slot_c_attribute;
    END GET_SLOT_C_ATTRIBUTE;

    FUNCTION GET_REF_FORMAT (p_tfm_table IN VARCHAR2) RETURN VARCHAR2 IS
        l_rec t_carrier;
    BEGIN
        l_rec := GET_CARRIER(p_tfm_table);
        -- Default to FULL when the row is absent or the column is unset,
        -- so the result is always safe to pass into BUILD_REF.
        RETURN NVL(l_rec.ref_format, C_FMT_FULL);
    END GET_REF_FORMAT;

END DMT_REF_ID_PKG;
/
