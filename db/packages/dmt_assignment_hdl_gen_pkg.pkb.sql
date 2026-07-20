-- PACKAGE BODY DMT_ASSIGNMENT_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ASSIGNMENT_HDL_GEN_PKG" 
AS
-- ============================================================
-- DMT_ASSIGNMENT_HDL_GEN_PKG body
-- Worker Assignment HDL DAT generation.
--
-- HDL requires the full parent chain in the file even for updates:
--   Worker → WorkRelationship → WorkTerms → Assignment
-- Parent records are re-stated as MERGEs using the SourceSystemId
-- pattern shared with the Worker load. WorkRelationship/PeriodOfService keys
-- off the person (<PersonNumber>_POS); WorkTerms and Assignment key off the
-- SOURCE assignment number (<AssignmentNumber>_TRM / <AssignmentNumber>_ASG),
-- so both loads derive the same keys from the same field and never collide on
-- the shared assignment id. Multiple assignments per person are supported.
--
-- METADATA validated against Fusion 25B V2 (proven in Worker pipeline).
-- V2 invalid: EffectiveStartDate/EndDate on WR, ManagerPersonNumber,
--             ManagerAssignmentNumber on Assignment.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_ASSIGNMENT_HDL_GEN_PKG';

    -- METADATA column lists — all proven from Worker V2 validation.
    C_WORKER_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|EffectiveStartDate|PersonNumber|StartDate|DateOfBirth|ActionCode';

    C_PERSON_NAME_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|EffectiveStartDate|PersonId(SourceSystemId)|NameType|LegislationCode|LastName|FirstName';

    C_WORK_REL_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|LegalEmployerName|DateStart|WorkerType|PrimaryFlag';

    C_WORK_TERMS_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|PeriodOfServiceId(SourceSystemId)|ActionCode|EffectiveStartDate|EffectiveSequence|EffectiveLatestChange|AssignmentName|AssignmentNumber|PrimaryWorkTermsFlag';

    -- ManagerPersonNumber/ManagerAssignmentNumber INVALID for V2 — removed.
    C_ASSIGNMENT_COLS CONSTANT VARCHAR2(1000) :=
        'SourceSystemOwner|SourceSystemId|ActionCode|EffectiveStartDate|EffectiveSequence|EffectiveLatestChange|WorkTermsAssignmentId(SourceSystemId)|AssignmentName|AssignmentNumber|AssignmentStatusTypeCode|PersonTypeCode|BusinessUnitShortCode|PrimaryAssignmentFlag|JobCode|GradeCode|LocationCode|DepartmentName|PositionCode|WorkerCategory|AssignmentCategory|FullPartTime|PermanentTemporary|NormalHours|Frequency';

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
            ' WHERE RUN_ID = :1 AND TFM_STATUS = ''STAGED'' AND ROWNUM = 1'
            INTO l_cnt USING p_iid;
        RETURN l_cnt > 0;
    END has_rows;


    -- ============================================================
    -- GENERATE_HDL
    -- ============================================================
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

        x_filename := 'Worker_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);

        -- HDL requires the full parent chain for Assignment updates.
        -- For each distinct person in the assignment batch, emit parent
        -- records using the SourceSystemId convention from Worker load.
        -- The parent data (Worker/WR/WorkTerms) comes from WorkRel staging
        -- which carries PERSON_NUMBER, LEGAL_EMPLOYER_NAME, DATE_START, etc.

        IF has_rows('DMT_ASSIGNMENT_TFM_TBL', p_run_id) THEN

            -- ============================================================
            -- 1. Worker (parent chain — re-state existing by SSID match)
            -- ============================================================
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Worker', C_WORKER_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Worker', C_WORKER_COLS));

            FOR r IN (
                SELECT DISTINCT wr.PERSON_NUMBER,
                       wr.DATE_START, wr.LEGAL_EMPLOYER_NAME, wr.ACTION_CODE
                FROM   DMT_OWNER.DMT_WORK_REL_TFM_TBL wr
                WHERE  wr.RUN_ID = p_run_id
                AND    wr.TFM_STATUS = 'STAGED'
            ) LOOP
                l_vals := C_SOURCE_SYSTEM              || '|' ||
                          pv(r.PERSON_NUMBER)          || '|' ||  -- SourceSystemId
                          pv(r.DATE_START)             || '|' ||  -- EffectiveStartDate
                          pv(r.PERSON_NUMBER)          || '|' ||  -- PersonNumber
                          pv(r.DATE_START)             || '|' ||  -- StartDate
                          ''                           || '|' ||  -- DateOfBirth (not required for MERGE)
                          NVL(r.ACTION_CODE, 'HIRE');
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'Worker');
                l_row_count := l_row_count + 1;
            END LOOP;

            -- ============================================================
            -- 2. PersonName (required by Worker MERGE — Fusion requires LastName)
            -- ============================================================
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonName', C_PERSON_NAME_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonName', C_PERSON_NAME_COLS));

            FOR r IN (
                SELECT DISTINCT wr.PERSON_NUMBER, wr.DATE_START
                FROM   DMT_OWNER.DMT_WORK_REL_TFM_TBL wr
                WHERE  wr.RUN_ID = p_run_id
                AND    wr.TFM_STATUS = 'STAGED'
            ) LOOP
                -- Re-state PersonName with existing SSID pattern.
                -- MERGE will match existing record and preserve values.
                l_vals := C_SOURCE_SYSTEM                || '|' ||
                          pv(r.PERSON_NUMBER) || '_NME'  || '|' ||  -- SourceSystemId
                          pv(r.DATE_START)               || '|' ||  -- EffectiveStartDate
                          pv(r.PERSON_NUMBER)            || '|' ||  -- PersonId(SourceSystemId)
                          'GLOBAL'                       || '|' ||  -- NameType
                          'US'                           || '|' ||  -- LegislationCode
                          pv(r.PERSON_NUMBER)            || '|' ||  -- LastName (placeholder — MERGE keeps existing)
                          'Worker';                                  -- FirstName (placeholder)
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonName');
                l_row_count := l_row_count + 1;
            END LOOP;

            -- ============================================================
            -- 3. WorkRelationship (parent chain)
            -- ============================================================
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkRelationship', C_WORK_REL_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkRelationship', C_WORK_REL_COLS));

            FOR r IN (
                SELECT DISTINCT wr.PERSON_NUMBER,
                       wr.DATE_START, wr.LEGAL_EMPLOYER_NAME, wr.WORKER_TYPE
                FROM   DMT_OWNER.DMT_WORK_REL_TFM_TBL wr
                WHERE  wr.RUN_ID = p_run_id
                AND    wr.TFM_STATUS = 'STAGED'
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                || '|' ||
                          pv(r.PERSON_NUMBER) || '_POS'  || '|' ||  -- SourceSystemId
                          pv(r.PERSON_NUMBER)            || '|' ||  -- PersonId(SourceSystemId)
                          pv(r.LEGAL_EMPLOYER_NAME)      || '|' ||
                          pv(r.DATE_START)               || '|' ||
                          NVL(r.WORKER_TYPE, 'E')        || '|' ||
                          'Y';
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'WorkRelationship');
                l_row_count := l_row_count + 1;
            END LOOP;

            -- ============================================================
            -- 4. WorkTerms (parent chain — one per assignment)
            --    Keyed by the source ASSIGNMENT_NUMBER (a business key), NOT
            --    the person. The SourceSystemId (<AssignmentNumber>_TRM) and
            --    AssignmentNumber therefore match exactly what the Worker load
            --    emits for the same assignment, so the two loads never collide
            --    on the shared assignment id. The work relationship
            --    (<PersonNumber>_POS) stays person-keyed — one period of
            --    service per person.
            -- ============================================================
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkTerms', C_WORK_TERMS_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkTerms', C_WORK_TERMS_COLS));

            FOR r IN (
                SELECT a.PERSON_NUMBER, a.ASSIGNMENT_NUMBER, a.ASSIGNMENT_NAME,
                       a.EFFECTIVE_START_DATE, a.ACTION_CODE,
                       a.PRIMARY_ASSIGNMENT_FLAG
                FROM   DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL a
                WHERE  a.RUN_ID = p_run_id
                AND    a.TFM_STATUS = 'STAGED'
                ORDER BY a.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                        || '|' ||
                          pv(r.ASSIGNMENT_NUMBER) || '_TRM'      || '|' ||  -- SourceSystemId (per assignment)
                          pv(r.PERSON_NUMBER) || '_POS'          || '|' ||  -- PeriodOfServiceId(SourceSystemId)
                          NVL(r.ACTION_CODE, 'HIRE')             || '|' ||
                          pv(r.EFFECTIVE_START_DATE)             || '|' ||  -- EffectiveStartDate
                          '1'                                    || '|' ||  -- EffectiveSequence
                          'Y'                                    || '|' ||  -- EffectiveLatestChange
                          pv(NVL(r.ASSIGNMENT_NAME, r.ASSIGNMENT_NUMBER)) || '|' ||  -- AssignmentName
                          pv(r.ASSIGNMENT_NUMBER)                || '|' ||  -- AssignmentNumber (source business key)
                          pv(NVL(r.PRIMARY_ASSIGNMENT_FLAG, 'Y'));    -- PrimaryWorkTermsFlag (source primary flag; one 'Y' per _POS)
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'WorkTerms');
                l_row_count := l_row_count + 1;
            END LOOP;

            -- ============================================================
            -- 5. Assignment (the actual update)
            -- ============================================================
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Assignment', C_ASSIGNMENT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Assignment', C_ASSIGNMENT_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                    || '|' ||
                          pv(r.ASSIGNMENT_NUMBER) || '_ASG'  || '|' ||  -- SourceSystemId (per assignment)
                          pv(r.ACTION_CODE)                  || '|' ||
                          pv(r.EFFECTIVE_START_DATE)          || '|' ||
                          '1'                                || '|' ||  -- EffectiveSequence
                          'Y'                                || '|' ||  -- EffectiveLatestChange
                          pv(r.ASSIGNMENT_NUMBER) || '_TRM'  || '|' ||  -- WorkTermsAssignmentId(SourceSystemId)
                          pv(r.ASSIGNMENT_NAME)              || '|' ||
                          pv(r.ASSIGNMENT_NUMBER)            || '|' ||
                          pv(r.ASSIGNMENT_STATUS_TYPE_CODE)  || '|' ||
                          'Employee'                         || '|' ||  -- PersonTypeCode
                          pv(r.BUSINESS_UNIT_NAME)           || '|' ||  -- BusinessUnitShortCode
                          pv(r.PRIMARY_ASSIGNMENT_FLAG)      || '|' ||
                          pv(r.JOB_CODE)                     || '|' ||
                          pv(r.GRADE_CODE)                   || '|' ||
                          pv(r.LOCATION_CODE)                || '|' ||
                          pv(r.DEPARTMENT_NAME)              || '|' ||
                          pv(r.POSITION_CODE)                || '|' ||
                          pv(r.WORKER_CATEGORY)              || '|' ||
                          pv(r.ASSIGNMENT_CATEGORY)          || '|' ||
                          pv(r.FULL_PART_TIME)               || '|' ||
                          pv(r.PERMANENT_TEMPORARY)          || '|' ||
                          pv(r.NORMAL_HOURS)                 || '|' ||
                          pv(r.FREQUENCY);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'Assignment');
                l_row_count := l_row_count + 1;
            END LOOP;

        END IF;

        -- ============================================================
        -- ZIP the DAT CLOB
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_dat) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'Worker.dat',
                clob_to_blob(l_dat));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'WorkerAssignments',
            'Worker.dat', l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'WorkerAssignments', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        UPDATE DMT_OWNER.DMT_WORK_REL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL
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

END DMT_ASSIGNMENT_HDL_GEN_PKG;
/
