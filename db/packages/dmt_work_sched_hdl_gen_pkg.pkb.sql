-- PACKAGE BODY DMT_WORK_SCHED_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORK_SCHED_HDL_GEN_PKG" 
AS
-- ============================================================
-- DMT_WORK_SCHED_HDL_GEN_PKG body
-- WorkSchedule HDL DAT generation.
--
-- V2 fixes applied:
--   - Removed dfmt() — TFM columns are VARCHAR2, use pv()
--   - Added has_rows() guard around METADATA/data loops
--   - Config object (not person-specific) — no PersonId FK needed
--   - SourceSystemId uses WORK_SCHEDULE_NAME || '_WSCHED' for parent
--   - SourceSystemId uses WORK_SCHEDULE_NAME || '_WSHIFT' for child
--   - Child has WorkScheduleId(SourceSystemId) FK back to parent
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_WORK_SCHED_HDL_GEN_PKG';

    -- METADATA column list for WorkSchedule (config object — no person reference)
    -- WorkPattern V1 — completely different attrs from WorkSchedule
    -- All original attrs rejected. Try WorkPattern-specific names.
    -- WorkPattern V1 — all guessed attrs rejected. Try bare minimum.
    -- AssignmentNumber required. Added after bare minimum validation.
    -- DateFrom required. Added after load error.
    -- WorkPatternTypeName IS required (Fusion rejects without it)
    C_WORKSCHEDULE_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|AssignmentNumber|DateFrom|WorkPatternTypeName';

    -- METADATA column list for WorkPatternShift child
    -- REST API confirms: DayOfWorkPattern (not DayNumber), ShiftName (not StartTime/EndTime)
    -- Shifts are pre-defined entities referenced by name, not raw times
    C_WORKSCHEDULESHIFT_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|WorkPatternAssignmentId(SourceSystemId)|DayOfWorkPattern|ShiftName';

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

        x_filename := 'WorkSchedules_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);


        -- ============================================================
        -- 1. WorkSchedule
        -- ============================================================
        IF has_rows('DMT_WORK_SCHED_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPattern', C_WORKSCHEDULE_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPattern', C_WORKSCHEDULE_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_OWNER.DMT_WORK_SCHED_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                      || '|' ||
                          pv(r.PERSON_NUMBER) || '_WPAT'       || '|' ||  -- SourceSystemId
                          pv(r.PERSON_NUMBER)                  || '|' ||  -- AssignmentNumber (= prefixed person number)
                          pv(r.SCHEDULE_START_DATE)            || '|' ||  -- DateFrom
                          NVL(pv(r.WORK_SCHEDULE_TYPE), '9A - 5P General Shift');  -- WorkPatternTypeName (instance-specific)
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'WorkPattern');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- 2. WorkScheduleShift
        -- ============================================================
        IF has_rows('DMT_WORK_SCHED_DTL_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat, LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPatternShift', C_WORKSCHEDULESHIFT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPatternShift', C_WORKSCHEDULESHIFT_COLS));

            FOR r IN (
                SELECT t.*,
                       (SELECT p.PERSON_NUMBER FROM DMT_OWNER.DMT_WORK_SCHED_TFM_TBL p
                        WHERE p.RUN_ID = t.RUN_ID
                        AND p.WORK_SCHEDULE_NAME = t.WORK_SCHEDULE_NAME
                        AND ROWNUM = 1) AS PARENT_PERSON_NUMBER
                FROM   DMT_OWNER.DMT_WORK_SCHED_DTL_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                      || '|' ||
                          pv(r.PARENT_PERSON_NUMBER) || '_WSHIFT_' || TO_CHAR(r.TFM_SEQUENCE_ID) || '|' || -- unique SourceSystemId
                          pv(r.PARENT_PERSON_NUMBER) || '_WPAT'   || '|' || -- FK to parent WorkPattern
                          pv(r.SHIFT_DATE)                     || '|' ||  -- DayOfWorkPattern (1-7)
                          pv(r.SHIFT_NAME);                               -- ShiftName (pre-defined shift, e.g. '8:30 AM - 4:30 PM')
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => 'WorkPatternShift');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- ZIP the DAT CLOB
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_dat) > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'WorkPattern.dat',
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
            l_csv_id, p_run_id, 'WorkSchedules',
            'WorkPattern.dat', l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'WorkSchedules', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_OWNER.DMT_WORK_SCHED_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_OWNER.DMT_WORK_SCHED_DTL_TFM_TBL
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

END DMT_WORK_SCHED_HDL_GEN_PKG;
/
