-- PACKAGE BODY DMT_PERF_EVAL_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PERF_EVAL_HDL_GEN_PKG" 
AS
-- ============================================================
-- DMT_PERF_EVAL_HDL_GEN_PKG body
-- PerformanceDocument HDL DAT generation.
--
-- V2 fixes applied:
--   - Removed dfmt() — TFM columns are VARCHAR2, use pv()
--   - Added has_rows() guard around METADATA/data loops
--   - Removed PersonNumber + ManagerPersonNumber from parent METADATA
--   - Added PersonId(SourceSystemId) FK hint to parent
--   - Added ManagerPersonId(SourceSystemId) FK hint to parent
--   - Removed PersonNumber from child METADATA
--   - Added PerformanceDocumentId(SourceSystemId) FK hint to child
--   - Parent SourceSystemId: PERSON_NUMBER || '_PERF'
--   - Child SourceSystemId: PERSON_NUMBER || '_PERFRTG'
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_PERF_EVAL_HDL_GEN_PKG';

    -- METADATA column list for PerformanceDocument
    -- V2: PersonNumber+ManagerPersonNumber removed, PersonId+ManagerPersonId FK hints added
    -- GoalPlan V1 — completely different from PerformanceDocument.
    -- Minimal set to discover valid attributes iteratively.
    -- GoalPlanType V1 invalid — correct name is GoalPlanTypeCode
    -- ReqSubmittedByPersonId required for GoalPlan load.
    -- Uses (SourceSystemId) FK hint to resolve PersonId dynamically.
    C_PERFORMANCEDOCUMENT_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|GoalPlanName|GoalPlanTypeCode|StartDate|EndDate|ReqSubmittedByPersonId(SourceSystemId)';

    -- METADATA column list for PerformanceRating
    -- V2: PersonNumber removed, PerformanceDocumentId(SourceSystemId) FK hint added
    C_PERFORMANCERATING_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|PerformanceDocumentId(SourceSystemId)|SectionName|RatingLevelCode|Comments|ReviewPeriodName|DocumentName';

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
        -- 1. PerformanceDocument
        -- ============================================================
        IF has_rows('DMT_PERF_EVAL_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('GoalPlan', C_PERFORMANCEDOCUMENT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('GoalPlan', C_PERFORMANCEDOCUMENT_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_PERF_EVAL_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                -- GoalPlan attributes — map from perf eval staging columns
                -- ReqSubmittedByPersonId(SourceSystemId): FK hint resolves to Fusion PersonId
                l_vals := C_SOURCE_SYSTEM                      || '|' ||
                          pv(r.PERSON_NUMBER) || '_GOAL'       || '|' ||  -- SourceSystemId
                          pv(r.DOCUMENT_NAME)                  || '|' ||  -- GoalPlanName
                          NVL(pv(r.DOCUMENT_TYPE), 'ORA_HRG_WORKER') || '|' || -- GoalPlanTypeCode
                          pv(r.START_DATE)                     || '|' ||
                          pv(r.END_DATE)                       || '|' ||
                          pv(r.PERSON_NUMBER);  -- ReqSubmittedByPersonId(SourceSystemId) = Worker's SSID
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'GoalPlan');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- 2. PerformanceRating
        -- ============================================================
        IF has_rows('DMT_PERF_EVAL_RATING_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('GoalPlanGoal', C_PERFORMANCERATING_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('GoalPlanGoal', C_PERFORMANCERATING_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_PERF_EVAL_RATING_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                      || '|' ||
                          pv(r.PERSON_NUMBER) || '_PERFRTG'    || '|' ||  -- SourceSystemId
                          pv(r.PERSON_NUMBER) || '_PERF'       || '|' ||  -- PerformanceDocumentId(SourceSystemId)
                          pv(r.SECTION_NAME)                   || '|' ||
                          pv(r.RATING_LEVEL_CODE)              || '|' ||
                          pv(r.COMMENTS)                       || '|' ||
                          pv(r.REVIEW_PERIOD_NAME)             || '|' ||
                          pv(r.DOCUMENT_NAME);
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'GoalPlanGoal');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- ZIP the DAT CLOB
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_dat) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'GoalPlan.dat',
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
            l_csv_id, p_run_id, 'PerformanceDocuments',
            'GoalPlan.dat', l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_csv_id, p_run_id,
            'PerformanceDocuments', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_OWNER.DMT_PERF_EVAL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_PERF_EVAL_RATING_TFM_TBL
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
