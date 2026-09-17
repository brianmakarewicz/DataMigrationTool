-- PACKAGE BODY DMT_BEN_DEPEND_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_DEPEND_HDL_GEN_PKG"
AS
-- ============================================================
-- DMT_BEN_DEPEND_HDL_GEN_PKG body
-- DependentEnrollment HDL DAT generation.
--
-- CORRECTED OBJECT (2026-09-17):
--   Dependent benefit enrollment loads through HCM Data Loader as the
--   DependentEnrollment business object, written to DependentEnrollment.dat.
--   It is a TWO-component object:
--     * DependentEnrollment  (parent) — the participant's benefit relationship /
--       life-event context, one row per migrated participant.
--     * DesignateDependent   (child)  — one row per dependent designated into a
--       Plan / Program / Option under that participant's enrollment.
--   This is NOT PersonBenefitBalance. The prior version emitted
--   'PersonBenefitBalance.dat' — the wrong object AND the same file name used by
--   BenBeneficiary and BenParticipant (a three-way file-name collision). Fixed
--   here: distinct object, distinct discriminators, distinct file name
--   (DependentEnrollment.dat).
--
--   Verified against Oracle docs (24c/24d fahbo "Example of Loading Dependent
--   Enrollments"; 20b faihm "Loading Benefits Objects") and live on the pod
--   (fin_impl): HRC_INTEGRATION_KEY_MAP carries ContactRelationship (dependents
--   are contact-relationship-based); PersonBenefitBalance is a distinct object.
--
-- Both components are keyed by SourceSystemOwner/SourceSystemId so no worker or
-- participant record is repeated inline. The child references its parent by the
-- parent's SourceSystemId (DependentEnrollmentId(SourceSystemId)), and references
-- the dependent contact by DependentPersonNumber.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BEN_DEPEND_HDL_GEN_PKG';

    -- HDL business object + its two file discriminators.
    C_BUSINESS_OBJECT CONSTANT VARCHAR2(30) := 'DependentEnrollment';
    C_DAT_FILENAME    CONSTANT VARCHAR2(40) := 'DependentEnrollment.dat';

    C_PARENT_DISCRIMINATOR CONSTANT VARCHAR2(30) := 'DependentEnrollment';
    C_CHILD_DISCRIMINATOR  CONSTANT VARCHAR2(30) := 'DesignateDependent';

    -- Parent component: one enrollment context per participant, source-keyed.
    C_PARENT_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|PersonNumber|BenefitRelationship|EffectiveDate|LegalEmployer';

    -- Child component: the dependent designation, source-keyed, pointing back at
    -- its parent DependentEnrollment by SourceSystemId.
    C_CHILD_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|DependentEnrollmentId(SourceSystemId)|'
        || 'PersonNumber|Plan|Program|Option|DependentPersonNumber|LineNumber';

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

    FUNCTION has_rows(p_iid NUMBER) RETURN BOOLEAN IS
        l_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   l_cnt
        FROM   DMT_BEN_DEPEND_TFM_TBL
        WHERE  RUN_ID = p_iid
        AND    TFM_STATUS = 'STAGED'
        AND    ROWNUM = 1;
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
        l_line_no     NUMBER;
        l_parent_ssid VARCHAR2(240);
        l_vals        VARCHAR2(32767);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL start.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

        x_filename := 'DependentEnrollment_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);

        IF has_rows(p_run_id) THEN
            -- ====================================================
            -- Component 1: DependentEnrollment (parent context).
            -- One row per distinct participant (PERSON_NUMBER); the
            -- participant is referenced by SourceSystemId, never repeated
            -- as a worker record.
            -- ====================================================
            DBMS_LOB.WRITEAPPEND(
                l_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_PARENT_DISCRIMINATOR, C_PARENT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_PARENT_DISCRIMINATOR, C_PARENT_COLS));

            FOR p IN (
                SELECT PERSON_NUMBER,
                       MIN(BENEFIT_RELATIONSHIP_NAME) AS BENEFIT_RELATIONSHIP_NAME,
                       MIN(DESIGNATION_DATE)          AS EFFECTIVE_DATE,
                       MIN(LEGAL_EMPLOYER_NAME)       AS LEGAL_EMPLOYER_NAME
                FROM   DMT_BEN_DEPEND_TFM_TBL
                WHERE  RUN_ID = p_run_id
                AND    TFM_STATUS = 'STAGED'
                GROUP BY PERSON_NUMBER
                ORDER BY PERSON_NUMBER
            ) LOOP
                l_parent_ssid := pv(p.PERSON_NUMBER) || '_BENDEP';
                l_vals := C_SOURCE_SYSTEM             || '|' ||
                          l_parent_ssid               || '|' ||
                          pv(p.PERSON_NUMBER)         || '|' ||
                          pv(p.BENEFIT_RELATIONSHIP_NAME) || '|' ||
                          pv(p.EFFECTIVE_DATE)        || '|' ||
                          pv(p.LEGAL_EMPLOYER_NAME);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(
                    l_dat, l_vals, p_discriminator => C_PARENT_DISCRIMINATOR);
            END LOOP;

            -- ====================================================
            -- Component 2: DesignateDependent (child).
            -- One row per dependent designation, pointing back at its parent
            -- DependentEnrollment by SourceSystemId. LineNumber is sequential
            -- within each participant.
            -- ====================================================
            DBMS_LOB.WRITEAPPEND(
                l_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_CHILD_DISCRIMINATOR, C_CHILD_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_CHILD_DISCRIMINATOR, C_CHILD_COLS));

            FOR r IN (
                SELECT t.*,
                       ROW_NUMBER() OVER (
                           PARTITION BY t.PERSON_NUMBER
                           ORDER BY t.TFM_SEQUENCE_ID) AS LINE_NO
                FROM   DMT_BEN_DEPEND_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.PERSON_NUMBER, t.TFM_SEQUENCE_ID
            ) LOOP
                l_parent_ssid := pv(r.PERSON_NUMBER) || '_BENDEP';
                l_line_no     := r.LINE_NO;
                l_vals := C_SOURCE_SYSTEM                     || '|' ||
                          -- child SourceSystemId = participant + dependent + line
                          pv(r.PERSON_NUMBER) || '_' ||
                              pv(r.DEPENDENT_PERSON_NUMBER) || '_' ||
                              TO_CHAR(l_line_no) || '_BENDEP' || '|' ||
                          l_parent_ssid                       || '|' ||
                          pv(r.PERSON_NUMBER)                 || '|' ||
                          pv(r.PLAN_NAME)                     || '|' ||
                          pv(r.PROGRAM_NAME)                  || '|' ||
                          pv(r.OPTION_NAME)                   || '|' ||
                          pv(r.DEPENDENT_PERSON_NUMBER)       || '|' ||
                          TO_CHAR(l_line_no);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(
                    l_dat, l_vals, p_discriminator => C_CHILD_DISCRIMINATOR);
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- ZIP the DAT CLOB
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_dat) > 0 THEN
            UTL_ZIP.add1file(l_zip, C_DAT_FILENAME,
                clob_to_blob(l_dat));
        END IF;
        UTL_ZIP.finish_zip(l_zip);

        -- ============================================================
        -- Store in DMT_FBDI_CSV_TBL + DMT_FBDI_ZIP_TBL
        -- ============================================================
        SELECT DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;

        INSERT INTO DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'DependentEnrollments',
            C_DAT_FILENAME, l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'DependentEnrollments', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_BEN_DEPEND_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';


        DBMS_LOB.FREETEMPORARY(l_dat);

        x_hdl_zip := l_zip;
        x_csv_id  := l_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL complete. DesignateDependent data lines: ' || l_row_count ||
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
