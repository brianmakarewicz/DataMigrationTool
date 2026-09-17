-- PACKAGE BODY DMT_BEN_BENFY_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_BENFY_HDL_GEN_PKG"
AS
-- ============================================================
-- DMT_BEN_BENFY_HDL_GEN_PKG body
-- BeneficiaryEnrollment HDL DAT generation (beneficiary designation).
--
-- 2026-09-17 RE-MODEL — correct HDL business object.
--   Previously this generator emitted 'PersonBenefitBalance.dat' under the
--   PersonBenefitBalance discriminator. That is the WRONG business object
--   (PersonBenefitBalance carries accumulated benefit balance amounts, not
--   beneficiary designations) and it collided on filename/discriminator with
--   the BenParticipant and BenDependent generators (all three wrote the same
--   PersonBenefitBalance.dat).
--
--   Beneficiary designation is its own HDL business object: BeneficiaryEnrollment,
--   with the child component DesignateBeneficiary. One zip, one DAT file named
--   for the business object: BeneficiaryEnrollment.dat. Verified against Oracle
--   docs "Example of Loading Beneficiary Enrollments"
--   (docs.oracle.com/en/cloud/saas/human-resources/fahbo/example-of-loading-beneficiary-enrollments.html):
--     METADATA|BeneficiaryEnrollment|PersonNumber|BenefitRelationship|EffectiveDate|LifeEvent|LifeEventOccuredDate
--     METADATA|DesignateBeneficiary|Plan|Program|Option|BeneficiaryPercentage|BeneficiaryPersonNumber|BeneficiaryType|LineNumber|PersonNumber
--   The child references the parent (and the migrated worker) by the shared
--   PersonNumber — the worker is NOT repeated, only referenced by its key.
--
--   Design notes:
--   - TFM columns are VARCHAR2, use pv().
--   - has_rows() guard around the METADATA/data loop.
--   - The enrolled worker is referenced by PERSON_NUMBER (the migrated worker's
--     key, loaded by DMT_WORKER_HDL_GEN_PKG with SourceSystemId = PersonNumber).
--     PersonNumber resolves the person natively for benefit-enrollment loads.
--   - LineNumber is a sequence within each person's designation set so multiple
--     beneficiaries for one worker each get a distinct child row.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BEN_BENFY_HDL_GEN_PKG';

    -- Parent component: BeneficiaryEnrollment (one per enrolled worker + relationship).
    -- SourceSystemOwner/SourceSystemId are carried alongside the natural PersonNumber
    -- so the load records a DETERMINISTIC HRC_INTEGRATION_KEY_MAP row we can reconcile
    -- against (OBJECT_NAME='BeneficiaryEnrollment', SOURCE_SYSTEM_ID=<PersonNumber>_BENENRL).
    C_BENEFICIARYENROLLMENT_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|PersonNumber|BenefitRelationship|EffectiveDate|LifeEvent|LifeEventOccuredDate';

    -- Child component: DesignateBeneficiary (one per designated beneficiary).
    C_DESIGNATEBENEFICIARY_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|Plan|Program|Option|BeneficiaryPercentage|BeneficiaryPersonNumber|BeneficiaryType|LineNumber|PersonNumber';

    C_SOURCE_SYSTEM CONSTANT VARCHAR2(30) := 'HRC_SQLLOADER';

    -- Distinct SourceSystemId suffixes — never the collided '_BENBNFY' of the old
    -- PersonBenefitBalance model.
    C_ENRL_SUFFIX CONSTANT VARCHAR2(10) := '_BENENRL';
    C_DSGN_SUFFIX CONSTANT VARCHAR2(10) := '_BENDSGN';

    -- Default benefit relationship when the source does not carry one. On the
    -- doc example this is 'Default'.
    C_DEFAULT_REL CONSTANT VARCHAR2(30) := 'Default';


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
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_tbl ||
            ' WHERE RUN_ID = :1 AND TFM_STATUS = ''STAGED'' AND ROWNUM = 1'
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
        l_prev_person VARCHAR2(240);
        l_line_no     NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL start.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

        x_filename := 'BeneficiaryEnrollment_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);


        -- ============================================================
        -- BeneficiaryEnrollment parent + DesignateBeneficiary child
        -- ============================================================
        IF has_rows('DMT_BEN_BENFY_TFM_TBL', p_run_id) THEN

            -- --------------------------------------------------------
            -- 1. BeneficiaryEnrollment (parent): one row per distinct
            --    enrolled worker + benefit relationship. The worker is
            --    referenced by PERSON_NUMBER (the migrated worker's key),
            --    never re-created here.
            -- --------------------------------------------------------
            DBMS_LOB.WRITEAPPEND(l_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('BeneficiaryEnrollment', C_BENEFICIARYENROLLMENT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('BeneficiaryEnrollment', C_BENEFICIARYENROLLMENT_COLS));

            FOR r IN (
                SELECT t.PERSON_NUMBER,
                       NVL(MAX(t.BENEFIT_RELATIONSHIP_NAME), C_DEFAULT_REL) AS BENEFIT_RELATIONSHIP_NAME,
                       MIN(t.DESIGNATION_DATE)                             AS EFFECTIVE_DATE
                FROM   DMT_BEN_BENFY_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                GROUP BY t.PERSON_NUMBER
                ORDER BY t.PERSON_NUMBER
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                            || '|' ||  -- SourceSystemOwner
                          pv(r.PERSON_NUMBER) || C_ENRL_SUFFIX       || '|' ||  -- SourceSystemId
                          pv(r.PERSON_NUMBER)                        || '|' ||  -- PersonNumber
                          pv(r.BENEFIT_RELATIONSHIP_NAME)            || '|' ||  -- BenefitRelationship
                          pv(r.EFFECTIVE_DATE)                       || '|' ||  -- EffectiveDate
                          ''                                         || '|' ||  -- LifeEvent (optional)
                          '';                                                   -- LifeEventOccuredDate (optional)
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'BeneficiaryEnrollment');
                l_row_count := l_row_count + 1;
            END LOOP;

            -- --------------------------------------------------------
            -- 2. DesignateBeneficiary (child): one row per designated
            --    beneficiary. References the parent enrollment and the
            --    migrated worker by the shared PersonNumber. LineNumber
            --    is sequenced within each worker's designation set.
            -- --------------------------------------------------------
            DBMS_LOB.WRITEAPPEND(l_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('DesignateBeneficiary', C_DESIGNATEBENEFICIARY_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('DesignateBeneficiary', C_DESIGNATEBENEFICIARY_COLS));

            l_prev_person := NULL;
            l_line_no     := 0;

            FOR r IN (
                SELECT t.*
                FROM   DMT_BEN_BENFY_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.PERSON_NUMBER, t.TFM_SEQUENCE_ID
            ) LOOP
                IF l_prev_person IS NULL OR r.PERSON_NUMBER <> l_prev_person THEN
                    l_line_no := 1;
                ELSE
                    l_line_no := l_line_no + 1;
                END IF;
                l_prev_person := r.PERSON_NUMBER;

                l_vals := C_SOURCE_SYSTEM                                       || '|' ||  -- SourceSystemOwner
                          pv(r.PERSON_NUMBER) || C_DSGN_SUFFIX || TO_CHAR(l_line_no) || '|' ||  -- SourceSystemId
                          pv(r.PLAN_NAME)                    || '|' ||  -- Plan
                          pv(r.PROGRAM_NAME)                 || '|' ||  -- Program
                          ''                                 || '|' ||  -- Option (optional)
                          pv(r.PERCENTAGE)                   || '|' ||  -- BeneficiaryPercentage
                          pv(r.BENEFICIARY_PERSON_NUMBER)    || '|' ||  -- BeneficiaryPersonNumber
                          pv(r.BENEFICIARY_TYPE)             || '|' ||  -- BeneficiaryType
                          TO_CHAR(l_line_no)                 || '|' ||  -- LineNumber
                          pv(r.PERSON_NUMBER);                          -- PersonNumber (parent ref)
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'DesignateBeneficiary');
                l_row_count := l_row_count + 1;
            END LOOP;

        END IF;


        -- ============================================================
        -- ZIP the DAT CLOB. File name matches the business object.
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_dat) > 0 THEN
            UTL_ZIP.add1file(l_zip, 'BeneficiaryEnrollment.dat',
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
            l_csv_id, p_run_id, 'BeneficiaryEnrollment',
            'BeneficiaryEnrollment.dat', l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'BeneficiaryEnrollment', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_BEN_BENFY_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';


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

END DMT_BEN_BENFY_HDL_GEN_PKG;
/
