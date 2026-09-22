-- PACKAGE BODY DMT_PERF_EVAL_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PERF_EVAL_HDL_GEN_PKG"
AS
-- ============================================================
-- DMT_PERF_EVAL_HDL_GEN_PKG body
-- PerformanceDocument HDL DAT generation.
--
-- Emits PerfDocComplete.dat with two components:
--   1. PerfDocComplete    - the performance document (one per worker + evaluation).
--   2. RatingsAndComments - section ratings, overall rating and comments.
--
-- Oracle-documented structure (Examples of Loading Performance Documents):
--   METADATA|PerfDocComplete|AssignmentNumber|CustomaryName|StartDate|EndDate|Operation|ManagerAssignmentNumber
--   METADATA|RatingsAndComments|AssignmentNumber|CustomaryName|ParticipantPersonNumber|ParticipantRoleTypeCode|SectionName|SectionTypeCode|RatingName|Comments
--
-- Worker reference: AssignmentNumber. The source stages PERSON_NUMBER; on this demo
-- pod (and typically) the primary assignment number equals the person number, so
-- PERSON_NUMBER is used as AssignmentNumber. If a client's assignment numbers differ,
-- stage the assignment number into PERSON_NUMBER at load or extend the STG/TFM schema.
--
-- CustomaryName = the document name (prefixed DOCUMENT_NAME). It carries the run prefix
-- and is the business key reconciliation matches against HRA_EVALUATIONS.NAME.
--
-- Operation ORA_CREATE_PD creates the document (Performance Administration Action
-- lookup ORA_HRA_ADMIN_ACTION).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PERF_EVAL_HDL_GEN_PKG';

    -- METADATA column list for PerfDocComplete (the performance document).
    -- Natural-key object: keyed by AssignmentNumber + CustomaryName; no SourceSystem keys.
    C_PERFDOC_COLS CONSTANT VARCHAR2(4000) :=
        'AssignmentNumber|CustomaryName|StartDate|EndDate|Operation|ManagerAssignmentNumber';

    -- METADATA column list for RatingsAndComments (section + overall ratings, comments).
    C_RATINGS_COLS CONSTANT VARCHAR2(4000) :=
        'AssignmentNumber|CustomaryName|ParticipantPersonNumber|ParticipantRoleTypeCode|SectionName|SectionTypeCode|RatingName|Comments';

    -- Operation that creates a performance document (ORA_HRA_ADMIN_ACTION lookup).
    C_OP_CREATE_PD CONSTANT VARCHAR2(30) := 'ORA_CREATE_PD';

    -- NOTE (manager attribution, fixed 2026-09-22): the RatingsAndComments component
    -- must NOT invent a participant. The rating STG/TFM tables carry only PERSON_NUMBER
    -- (the worker being evaluated) and no manager/participant column, so there is no
    -- honest source for ParticipantPersonNumber. Stamping the worker as
    -- ParticipantPersonNumber with ParticipantRoleTypeCode 'Manager' (the prior defect)
    -- would load the worker as their own manager -- a fabricated attribution. We instead
    -- OMIT both fields (emit empty). The manager is already correctly attributed on the
    -- PerfDocComplete line via ManagerAssignmentNumber (the real MANAGER_PERSON_NUMBER),
    -- and HDL attributes the section ratings to the document's manager. If a genuine
    -- rating-participant source is added to the STG/TFM later, populate it here.

    -- Regular section type (ORA_HRA sections default to REG).
    C_SECTION_TYPE_REG CONSTANT VARCHAR2(10) := 'REG';

    -- HDL DAT file name for the PerformanceDocument object.
    C_DAT_FILENAME CONSTANT VARCHAR2(60) := 'PerfDocComplete.dat';


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
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL start.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

        x_filename := 'PerformanceDocuments_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);


        -- ============================================================
        -- 1. PerfDocComplete - the performance document
        -- ============================================================
        IF has_rows('DMT_PERF_EVAL_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PerfDocComplete', C_PERFDOC_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('PerfDocComplete', C_PERFDOC_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_PERF_EVAL_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                -- AssignmentNumber = worker's assignment (PERSON_NUMBER on this pod).
                -- CustomaryName    = prefixed DOCUMENT_NAME (the reconciliation key).
                -- Operation        = ORA_CREATE_PD.
                -- ManagerAssignmentNumber = the manager's assignment number.
                l_vals := pv(r.PERSON_NUMBER)          || '|' ||  -- AssignmentNumber
                          pv(r.DOCUMENT_NAME)          || '|' ||  -- CustomaryName
                          pv(r.START_DATE)             || '|' ||  -- StartDate
                          pv(r.END_DATE)               || '|' ||  -- EndDate
                          C_OP_CREATE_PD               || '|' ||  -- Operation
                          pv(r.MANAGER_PERSON_NUMBER);           -- ManagerAssignmentNumber
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'PerfDocComplete');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- 2. RatingsAndComments - section + overall ratings and comments
        -- ============================================================
        IF has_rows('DMT_PERF_EVAL_RATING_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('RatingsAndComments', C_RATINGS_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('RatingsAndComments', C_RATINGS_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_PERF_EVAL_RATING_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                -- AssignmentNumber        = worker (PERSON_NUMBER on this pod).
                -- CustomaryName           = prefixed document name (ties to the doc above).
                -- ParticipantPersonNumber = omitted (no honest participant source in
                --   the rating STG/TFM; the manager is attributed on the PerfDocComplete
                --   line via ManagerAssignmentNumber). Never the worker themselves.
                -- ParticipantRoleTypeCode = omitted (not fabricated as 'Manager').
                -- SectionName             = the rated section (overall rating loads on the
                --                           overall/summary section).
                -- SectionTypeCode         = REG.
                -- RatingName              = the rating level (section or overall).
                -- Comments                = section/overall comments.
                -- ParticipantPersonNumber and ParticipantRoleTypeCode are emitted
                -- EMPTY (see note by the constants): no honest participant source exists
                -- in the rating STG/TFM, and the manager is attributed on the
                -- PerfDocComplete line. Never stamp the worker as their own manager.
                l_vals := pv(r.PERSON_NUMBER)          || '|' ||  -- AssignmentNumber
                          pv(r.DOCUMENT_NAME)          || '|' ||  -- CustomaryName
                          ''                           || '|' ||  -- ParticipantPersonNumber (omitted; no honest source)
                          ''                           || '|' ||  -- ParticipantRoleTypeCode (omitted; not fabricated)
                          pv(r.SECTION_NAME)           || '|' ||  -- SectionName
                          C_SECTION_TYPE_REG           || '|' ||  -- SectionTypeCode
                          pv(r.RATING_LEVEL_CODE)      || '|' ||  -- RatingName
                          pv(r.COMMENTS);                        -- Comments
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'RatingsAndComments');
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
            l_csv_id, p_run_id, 'PerfEvaluations',
            C_DAT_FILENAME, l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'PerfEvaluations', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_PERF_EVAL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_PERF_EVAL_RATING_TFM_TBL
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

END DMT_PERF_EVAL_HDL_GEN_PKG;
/
