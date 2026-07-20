-- PACKAGE BODY DMT_WORKER_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORKER_HDL_GEN_PKG" 
AS
-- ============================================================
-- DMT_WORKER_HDL_GEN_PKG body
-- Worker HDL DAT generation.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_WORKER_HDL_GEN_PKG';

    -- METADATA column lists for each business object (pipe-delimited).
    -- Format follows Oracle HDL tutorial: SourceSystemOwner|SourceSystemId first,
    -- parent FK via hint notation e.g. PersonId(SourceSystemId).
    -- Validated against Fusion 25B V2 + Oracle new hire tutorial.

    C_WORKER_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|EffectiveStartDate|PersonNumber|StartDate|DateOfBirth|ActionCode';

    C_PERSON_NAME_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|EffectiveStartDate|PersonId(SourceSystemId)|NameType|LegislationCode|LastName|FirstName|MiddleNames|Title';

    C_WORK_REL_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|LegalEmployerName|DateStart|WorkerType|PrimaryFlag';

    C_WORK_TERMS_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|PeriodOfServiceId(SourceSystemId)|ActionCode|EffectiveStartDate|EffectiveSequence|EffectiveLatestChange|DateStart|AssignmentName|AssignmentNumber|PrimaryWorkTermsFlag';

    C_ASSIGNMENT_COLS CONSTANT VARCHAR2(1000) :=
        'SourceSystemOwner|SourceSystemId|ActionCode|EffectiveStartDate|EffectiveSequence|EffectiveLatestChange|WorkTermsAssignmentId(SourceSystemId)|AssignmentName|AssignmentNumber|AssignmentStatusTypeCode|PersonTypeCode|BusinessUnitShortCode|PrimaryAssignmentFlag';

    C_PERSON_EMAIL_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|DateFrom|EmailType|EmailAddress|PrimaryFlag';

    C_PERSON_PHONE_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|LegislationCode|DateFrom|PhoneType|CountryCodeNumber|AreaCode|PhoneNumber|PrimaryFlag';

    C_PERSON_ADDR_COLS CONSTANT VARCHAR2(1000) :=
        'SourceSystemOwner|SourceSystemId|EffectiveStartDate|PersonId(SourceSystemId)|AddressType|AddressLine1|AddressLine2|AddressLine3|AddressLine4|TownOrCity|Region1|Region2|PostalCode|Country|PrimaryFlag';

    C_PERSON_NID_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|LegislationCode|NationalIdentifierType|NationalIdentifierNumber|PrimaryFlag';

    C_PERSON_LEGISL_COLS CONSTANT VARCHAR2(500) :=
        'SourceSystemOwner|SourceSystemId|EffectiveStartDate|PersonId(SourceSystemId)|LegislationCode|Sex|MaritalStatus|HighestEducationLevel';

    -- Source system owner constant for HDL SourceSystemOwner/SourceSystemId
    -- SourceSystemOwner must be a registered source system in Fusion.
    -- HRC_SQLLOADER is pre-seeded in all Fusion instances.
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

    -- --------------------------------------------------------
    -- Private: build pipe-delimited values string from fields.
    -- NULLs become empty strings.
    -- --------------------------------------------------------
    FUNCTION pv(p_val IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(p_val, '');
    END pv;

    -- Conditionally write METADATA header only if rows exist
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
        -- No-hardcoded-values standard (design section 7): the assignment business
        -- unit short code comes from named config, not a literal, so a new instance
        -- is a config change rather than a code edit. Defaults to 'US1 Business Unit'
        -- if the key is absent.
        l_bu_short    VARCHAR2(240);
    BEGIN
        l_bu_short := NVL(DMT_UTIL_PKG.GET_CONFIG('WORKER_DEFAULT_BU_NAME'), 'US1 Business Unit');
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL start.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

        x_filename := 'Worker_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);

        -- Source key naming convention:
        --   Worker:           SSO=HRC_SQLLOADER, SSID=<PersonNumber>
        --   PersonName:       SSID=<PersonNumber>_NME, PersonId(SSID)=<PersonNumber>
        --   WorkRelationship: SSID=<PersonNumber>_POS, PersonId(SSID)=<PersonNumber>
        --   WorkTerms:        SSID=<AssignmentNumber>_TRM, PeriodOfServiceId(SSID)=<PersonNumber>_POS
        --   Assignment:       SSID=<AssignmentNumber>_ASG, WorkTermsAssignmentId(SSID)=<AssignmentNumber>_TRM
        -- The assignment number is a SOURCE business key (from the Assignment
        -- object's rows, joined by person) — never fabricated from the person.

        -- ============================================================
        -- 1. Worker
        -- ============================================================
        DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Worker', C_WORKER_COLS)),
            DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Worker', C_WORKER_COLS));

        FOR r IN (
            SELECT t.*
            FROM   DMT_OWNER.DMT_WORKER_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            l_vals := C_SOURCE_SYSTEM              || '|' ||
                      pv(r.PERSON_NUMBER)          || '|' ||  -- SourceSystemId
                      pv(NVL(r.EFFECTIVE_START_DATE, r.START_DATE)) || '|' ||
                      pv(r.PERSON_NUMBER)          || '|' ||  -- PersonNumber
                      pv(r.START_DATE)             || '|' ||
                      pv(r.DATE_OF_BIRTH)          || '|' ||
                      pv(r.ACTION_CODE);
            DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'Worker');
            l_row_count := l_row_count + 1;
        END LOOP;

        -- ============================================================
        -- 2. PersonName (only if rows exist)
        -- ============================================================
        IF has_rows('DMT_PERSON_NAME_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonName', C_PERSON_NAME_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonName', C_PERSON_NAME_COLS));

            FOR r IN (
                SELECT t.*,
                       (SELECT w.START_DATE FROM DMT_OWNER.DMT_WORKER_TFM_TBL w
                        WHERE w.RUN_ID = t.RUN_ID
                        AND w.PERSON_NUMBER = t.PERSON_NUMBER
                        AND ROWNUM = 1) AS WORKER_START_DATE
                FROM   DMT_OWNER.DMT_PERSON_NAME_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                || '|' ||
                          pv(r.PERSON_NUMBER) || '_NME'  || '|' ||  -- SourceSystemId
                          pv(NVL(r.EFFECTIVE_START_DATE, r.WORKER_START_DATE)) || '|' ||
                          pv(r.PERSON_NUMBER)            || '|' ||  -- PersonId(SourceSystemId)
                          pv(NVL(r.NAME_TYPE, 'GLOBAL')) || '|' ||
                          pv(r.LEGISLATION_CODE)         || '|' ||
                          pv(r.LAST_NAME)                || '|' ||
                          pv(r.FIRST_NAME)               || '|' ||
                          pv(r.MIDDLE_NAMES)             || '|' ||
                          pv(r.TITLE);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonName');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;

        -- ============================================================
        -- 3. WorkRelationship (auto-generated from Worker rows)
        -- ============================================================
        DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkRelationship', C_WORK_REL_COLS)),
            DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkRelationship', C_WORK_REL_COLS));

        FOR r IN (
            SELECT t.*
            FROM   DMT_OWNER.DMT_WORKER_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    t.TFM_STATUS = 'STAGED'
            ORDER BY t.TFM_SEQUENCE_ID
        ) LOOP
            l_vals := C_SOURCE_SYSTEM                || '|' ||
                      pv(r.PERSON_NUMBER) || '_POS'  || '|' ||  -- SourceSystemId
                      pv(r.PERSON_NUMBER)            || '|' ||  -- PersonId(SourceSystemId)
                      pv(r.LEGAL_ENTITY_NAME)        || '|' ||
                      pv(r.START_DATE)             || '|' ||
                      'E'                            || '|' ||  -- WorkerType: E=Employee
                      'Y';                                       -- PrimaryFlag
            DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'WorkRelationship');
            l_row_count := l_row_count + 1;
        END LOOP;

        -- ============================================================
        -- 4. WorkTerms (one per assignment — required for new hires)
        --    The assignment number is a business key that comes from the
        --    Assignment source (DMT_ASSIGNMENT_TFM_TBL), joined to the worker
        --    by PERSON_NUMBER. The Worker load NEVER fabricates the number:
        --    both this section and the standalone Assignment object derive the
        --    HDL keys from the SAME source field (ASSIGNMENT_NUMBER), so they
        --    always agree on SourceSystemId/AssignmentNumber and never collide
        --    on the shared assignment id. One assignment source row = one
        --    WorkTerms + one Assignment line, so multiple assignments per
        --    person get distinct keys by construction. A worker with no
        --    matching assignment row is a validation failure (the worker
        --    validator rejects it before this point).
        -- ============================================================
        DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkTerms', C_WORK_TERMS_COLS)),
            DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkTerms', C_WORK_TERMS_COLS));

        FOR r IN (
            SELECT w.PERSON_NUMBER, w.START_DATE,
                   a.ASSIGNMENT_NUMBER, a.ASSIGNMENT_NAME, a.ACTION_CODE
            FROM   DMT_OWNER.DMT_WORKER_TFM_TBL w
            JOIN   DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL a
                   ON  a.RUN_ID = w.RUN_ID
                   AND a.PERSON_NUMBER = w.PERSON_NUMBER
                   AND a.TFM_STATUS <> 'FAILED'
            WHERE  w.RUN_ID = p_run_id
            AND    w.TFM_STATUS = 'STAGED'
            ORDER BY w.TFM_SEQUENCE_ID, a.TFM_SEQUENCE_ID
        ) LOOP
            l_vals := C_SOURCE_SYSTEM                        || '|' ||
                      pv(r.ASSIGNMENT_NUMBER) || '_TRM'      || '|' ||  -- SourceSystemId (per assignment)
                      pv(r.PERSON_NUMBER) || '_POS'          || '|' ||  -- PeriodOfServiceId(SourceSystemId)
                      pv(NVL(r.ACTION_CODE, 'HIRE'))         || '|' ||
                      pv(r.START_DATE)                       || '|' ||  -- EffectiveStartDate
                      '1'                                    || '|' ||  -- EffectiveSequence
                      'Y'                                    || '|' ||  -- EffectiveLatestChange
                      pv(r.START_DATE)                       || '|' ||  -- DateStart (From Date)
                      pv(NVL(r.ASSIGNMENT_NAME, r.ASSIGNMENT_NUMBER)) || '|' ||  -- AssignmentName
                      pv(r.ASSIGNMENT_NUMBER)                || '|' ||  -- AssignmentNumber (source business key)
                      'Y';                                       -- PrimaryWorkTermsFlag
            DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'WorkTerms');
            l_row_count := l_row_count + 1;
        END LOOP;

        -- ============================================================
        -- 5. Assignment (one per assignment — required for new hires)
        --    Keyed by the source ASSIGNMENT_NUMBER, matching section 4 and the
        --    standalone Assignment object. Detail (BU/job/grade/...) comes from
        --    the assignment source row rather than fabricated constants.
        -- ============================================================
        DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Assignment', C_ASSIGNMENT_COLS)),
            DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('Assignment', C_ASSIGNMENT_COLS));

        FOR r IN (
            SELECT w.PERSON_NUMBER, w.START_DATE,
                   a.ASSIGNMENT_NUMBER, a.ASSIGNMENT_NAME, a.ACTION_CODE,
                   a.ASSIGNMENT_STATUS_TYPE_CODE, a.BUSINESS_UNIT_NAME,
                   a.PRIMARY_ASSIGNMENT_FLAG
            FROM   DMT_OWNER.DMT_WORKER_TFM_TBL w
            JOIN   DMT_OWNER.DMT_ASSIGNMENT_TFM_TBL a
                   ON  a.RUN_ID = w.RUN_ID
                   AND a.PERSON_NUMBER = w.PERSON_NUMBER
                   AND a.TFM_STATUS <> 'FAILED'
            WHERE  w.RUN_ID = p_run_id
            AND    w.TFM_STATUS = 'STAGED'
            ORDER BY w.TFM_SEQUENCE_ID, a.TFM_SEQUENCE_ID
        ) LOOP
            l_vals := C_SOURCE_SYSTEM                        || '|' ||
                      pv(r.ASSIGNMENT_NUMBER) || '_ASG'      || '|' ||  -- SourceSystemId (per assignment)
                      pv(NVL(r.ACTION_CODE, 'HIRE'))         || '|' ||
                      pv(r.START_DATE)                       || '|' ||  -- EffectiveStartDate
                      '1'                                    || '|' ||  -- EffectiveSequence
                      'Y'                                    || '|' ||  -- EffectiveLatestChange
                      pv(r.ASSIGNMENT_NUMBER) || '_TRM'      || '|' ||  -- WorkTermsAssignmentId(SourceSystemId)
                      pv(NVL(r.ASSIGNMENT_NAME, r.ASSIGNMENT_NUMBER)) || '|' ||  -- AssignmentName
                      pv(r.ASSIGNMENT_NUMBER)                || '|' ||  -- AssignmentNumber (source business key)
                      pv(NVL(r.ASSIGNMENT_STATUS_TYPE_CODE, 'ACTIVE_PROCESS')) || '|' ||  -- AssignmentStatusTypeCode
                      'Employee'                             || '|' ||  -- PersonTypeCode
                      pv(NVL(r.BUSINESS_UNIT_NAME, l_bu_short)) || '|' ||  -- BusinessUnitShortCode
                      pv(NVL(r.PRIMARY_ASSIGNMENT_FLAG, 'Y'));            -- PrimaryAssignmentFlag
            DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'Assignment');
            l_row_count := l_row_count + 1;
        END LOOP;

        -- ============================================================
        -- 6. PersonEmail (only if rows exist)
        -- ============================================================
        IF has_rows('DMT_PERSON_EMAIL_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonEmail', C_PERSON_EMAIL_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonEmail', C_PERSON_EMAIL_COLS));

            FOR r IN (
                SELECT t.*,
                       (SELECT w.START_DATE FROM DMT_OWNER.DMT_WORKER_TFM_TBL w
                        WHERE w.RUN_ID = t.RUN_ID
                        AND w.PERSON_NUMBER = t.PERSON_NUMBER
                        AND ROWNUM = 1) AS WORKER_START_DATE
                FROM   DMT_OWNER.DMT_PERSON_EMAIL_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                  || '|' ||
                          pv(r.PERSON_NUMBER) || '_EML'    || '|' ||
                          pv(r.PERSON_NUMBER)              || '|' ||  -- PersonId(SourceSystemId)
                          pv(r.WORKER_START_DATE)          || '|' ||  -- DateFrom (worker start date)
                          pv(r.EMAIL_TYPE)                 || '|' ||
                          pv(r.EMAIL_ADDRESS)              || '|' ||
                          pv(r.PRIMARY_FLAG);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonEmail');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;

        -- ============================================================
        -- 7. PersonPhone (only if rows exist)
        -- ============================================================
        IF has_rows('DMT_PERSON_PHONE_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonPhone', C_PERSON_PHONE_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonPhone', C_PERSON_PHONE_COLS));

            FOR r IN (
                SELECT t.*,
                       (SELECT n.LEGISLATION_CODE FROM DMT_OWNER.DMT_PERSON_NID_TFM_TBL n
                        WHERE n.RUN_ID = t.RUN_ID
                        AND n.PERSON_NUMBER = t.PERSON_NUMBER
                        AND ROWNUM = 1) AS PHONE_LEGIS_CODE,
                       (SELECT w.START_DATE FROM DMT_OWNER.DMT_WORKER_TFM_TBL w
                        WHERE w.RUN_ID = t.RUN_ID
                        AND w.PERSON_NUMBER = t.PERSON_NUMBER
                        AND ROWNUM = 1) AS WORKER_START_DATE
                FROM   DMT_OWNER.DMT_PERSON_PHONE_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                  || '|' ||
                          pv(r.PERSON_NUMBER) || '_PHN'    || '|' ||
                          pv(r.PERSON_NUMBER)              || '|' ||  -- PersonId(SourceSystemId)
                          NVL(pv(r.PHONE_LEGIS_CODE), 'US') || '|' || -- LegislationCode (from NID or default US)
                          pv(r.WORKER_START_DATE)          || '|' ||  -- DateFrom (worker start date)
                          pv(r.PHONE_TYPE)                 || '|' ||
                          pv(r.COUNTRY_CODE_NUMBER)        || '|' ||
                          pv(r.AREA_CODE)                  || '|' ||
                          pv(r.PHONE_NUMBER)               || '|' ||
                          pv(r.PRIMARY_FLAG);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonPhone');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;

        -- ============================================================
        -- 8. PersonAddress (only if rows exist)
        -- ============================================================
        IF has_rows('DMT_PERSON_ADDR_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonAddress', C_PERSON_ADDR_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonAddress', C_PERSON_ADDR_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_PERSON_ADDR_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                  || '|' ||
                          pv(r.PERSON_NUMBER) || '_ADR'    || '|' ||
                          pv(r.EFFECTIVE_START_DATE)      || '|' ||
                          pv(r.PERSON_NUMBER)              || '|' ||  -- PersonId(SourceSystemId)
                          pv(r.ADDRESS_TYPE)               || '|' ||
                          pv(r.ADDRESS_LINE_1)             || '|' ||
                          pv(r.ADDRESS_LINE_2)             || '|' ||
                          pv(r.ADDRESS_LINE_3)             || '|' ||
                          pv(r.ADDRESS_LINE_4)             || '|' ||
                          pv(r.TOWN_OR_CITY)               || '|' ||
                          pv(r.REGION_1)                   || '|' ||
                          pv(r.REGION_2)                   || '|' ||
                          pv(r.POSTAL_CODE)                || '|' ||
                          pv(r.COUNTRY)                    || '|' ||
                          pv(r.PRIMARY_FLAG);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonAddress');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;

        -- ============================================================
        -- 9. PersonNationalIdentifier (only if rows exist)
        -- ============================================================
        IF has_rows('DMT_PERSON_NID_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonNationalIdentifier', C_PERSON_NID_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonNationalIdentifier', C_PERSON_NID_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_PERSON_NID_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                  || '|' ||
                          pv(r.PERSON_NUMBER) || '_NID'    || '|' ||
                          pv(r.PERSON_NUMBER)              || '|' ||  -- PersonId(SourceSystemId)
                          pv(r.LEGISLATION_CODE)           || '|' ||
                          pv(r.NATIONAL_IDENTIFIER_TYPE)   || '|' ||
                          pv(r.NATIONAL_IDENTIFIER_NUMBER) || '|' ||
                          pv(r.PRIMARY_FLAG);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonNationalIdentifier');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;

        -- ============================================================
        -- 10. PersonLegislativeData (only if rows exist)
        -- ============================================================
        IF has_rows('DMT_PERSON_LEGISL_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonLegislativeData', C_PERSON_LEGISL_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PersonLegislativeData', C_PERSON_LEGISL_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_PERSON_LEGISL_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                  || '|' ||
                          pv(r.PERSON_NUMBER) || '_LEG'    || '|' ||
                          pv(r.EFFECTIVE_START_DATE)      || '|' ||
                          pv(r.PERSON_NUMBER)               || '|' ||  -- PersonId(SourceSystemId)
                          pv(r.LEGISLATION_CODE)            || '|' ||
                          pv(r.SEX)                         || '|' ||
                          pv(r.MARITAL_STATUS)              || '|' ||
                          pv(r.HIGHEST_EDUCATION_LEVEL);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PersonLegislativeData');
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

        -- ============================================================
        -- Store in DMT_FBDI_CSV_TBL + DMT_FBDI_ZIP_TBL
        -- ============================================================
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;

        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'Workers',
            'Worker.dat', l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'Workers', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update all 7 TFM tables to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_OWNER.DMT_WORKER_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PERSON_NAME_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PERSON_EMAIL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PERSON_PHONE_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PERSON_ADDR_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PERSON_NID_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PERSON_LEGISL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        -- Free temporary LOBs
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

END DMT_WORKER_HDL_GEN_PKG;
/
