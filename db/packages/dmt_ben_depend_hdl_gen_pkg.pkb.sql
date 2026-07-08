-- PACKAGE BODY DMT_BEN_DEPEND_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_DEPEND_HDL_GEN_PKG" 
AS
-- ============================================================
-- DMT_BEN_DEPEND_HDL_GEN_PKG body
-- DependentEnrollment HDL DAT generation.
--
-- V2 fixes applied:
--   - Removed dfmt() — TFM columns are VARCHAR2, use pv()
--   - Added has_rows() guard around METADATA/data loop
--   - Removed PersonNumber from METADATA; added PersonId(SourceSystemId) FK hint
--   - SourceSystemId uses PERSON_NUMBER || '_BENDEP' convention
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BEN_DEPEND_HDL_GEN_PKG';

    -- METADATA for PersonBenefitBalance (same discriminator for all three benefit objects)
    -- DependentBenefitBalance is NOT a valid discriminator — use PersonBenefitBalance
    C_DEPENDENTENROLLMENT_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|EffectiveStartDate|BenefitBalanceName';

    C_SOURCE_SYSTEM CONSTANT VARCHAR2(30) := 'HRC_SQLLOADER';


    FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB IS
        l_blob         BLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(
            dest_lob     => l_blob,
            src_clob     => p_clob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_offset,
            src_offset   => l_src_offset,
            blob_csid    => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_context,
            warning      => l_warning);
        RETURN l_blob;
    END clob_to_blob;

    FUNCTION pv(p_val IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(p_val, '');
    END pv;

    FUNCTION has_rows(p_tbl VARCHAR2, p_iid NUMBER) RETURN BOOLEAN IS
        l_cnt NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM DMT_OWNER.' || p_tbl ||
            ' WHERE RUN_ID = :1 AND STATUS = ''STAGED'' AND ROWNUM = 1'
            INTO l_cnt USING p_iid;
        RETURN l_cnt > 0;
    END has_rows;


    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    )
    IS
        l_dat         CLOB;
        l_zip         BLOB;
        l_csv_id      NUMBER;
        l_now         DATE := SYSDATE;
        l_row_count   NUMBER := 0;
        l_vals        VARCHAR2(32767);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL start.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

        x_filename := 'DependentEnrollments_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);


        -- ============================================================
        -- 1. DependentEnrollment
        -- ============================================================
        IF has_rows('DMT_BEN_DEPEND_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonBenefitBalance', C_DEPENDENTENROLLMENT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonBenefitBalance', C_DEPENDENTENROLLMENT_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_BEN_DEPEND_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                      || '|' ||
                          pv(r.PERSON_NUMBER) || '_BENDEP'     || '|' ||
                          pv(r.PERSON_NUMBER)                  || '|' ||
                          pv(r.DESIGNATION_DATE)               || '|' ||
                          pv(r.PLAN_NAME);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonBenefitBalance');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- ZIP the DAT CLOB
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_dat) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'PersonBenefitBalance.dat',
                clob_to_blob(l_dat));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- ============================================================
        -- Store in DMT_FBDI_CSV_TBL + DMT_FBDI_ZIP_TBL
        -- ============================================================
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'DependentEnrollments',
            'PersonBenefitBalance.dat', l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_csv_id, p_run_id,
            'DependentEnrollments', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_OWNER.DMT_BEN_DEPEND_TFM_TBL
        SET    STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND STATUS = 'STAGED';


        DBMS_LOB.FREETEMPORARY(l_dat);

        x_hdl_zip := l_zip;
        x_csv_id  := l_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL complete. Total data lines: ' || l_row_count ||
                                ' | Zip size: ' || DBMS_LOB.GETLENGTH(l_zip) || ' bytes.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'GENERATE_HDL failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'GENERATE_HDL');
            RAISE;
    END GENERATE_HDL;

END DMT_BEN_DEPEND_HDL_GEN_PKG;
/
