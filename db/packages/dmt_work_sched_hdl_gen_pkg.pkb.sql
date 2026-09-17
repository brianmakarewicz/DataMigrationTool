-- PACKAGE BODY DMT_WORK_SCHED_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORK_SCHED_HDL_GEN_PKG"
AS
-- ============================================================
-- DMT_WORK_SCHED_HDL_GEN_PKG body
-- WorkSchedules HDL DAT generation.
--
-- 2026-09-17 HCM re-model (PR "HCM re-model: WorkSchedules ->
-- WorkPattern + ScheduleAssignment"):
--
-- The old generator emitted a single WorkPattern.dat and jammed
-- AssignmentNumber INTO the WorkPattern METADATA. That conflated two
-- distinct Fusion HDL objects:
--   (a) the work pattern DEFINITION  -> HDL object WorkPattern (+ child
--       WorkPatternShift), base view HTS_WORK_PATTERNS_VL.
--   (b) assigning a schedule to a WORKER -> HDL object ScheduleAssignment,
--       base table PER_SCHEDULE_ASSIGNMENTS.
--
-- Both object names verified live on this pod (--cred fin_impl):
--   SELECT DISTINCT object_name FROM hrc_integration_key_map
--   WHERE object_name IN
--     ('WorkPattern','WorkPatternShift','WorkPatternBreak','ScheduleAssignment')
--   -> all four exist.
-- WorkPattern METADATA (Oracle doc fahbo/example-of-deleting-work-patterns):
--   WorkPatternTypeName|RepeatNumber|RepeatCycle|DateFrom|DateTo|
--   AssignmentNumber|WorkPatternAltCode
--   child WorkPatternShift: DayOfWorkPattern|ShiftStartTime|ShiftEndTime|
--   DurationMinutes|UnpaidBreakDurationMinutes|WorkPatternShiftCode|
--   WorkPatternAltCode
-- ScheduleAssignment METADATA (Oracle field references + doc):
--   ScheduleName|StartDate|EndDate|ResourceType|PrimaryFlag|
--   AssignmentNumber|SourceSystemOwner|SourceSystemId
--   ResourceType = 'ASSIGN' when assigning to a worker's assignment
--   (verified live: PER_SCHEDULE_ASSIGNMENTS rows carry RESOURCE_TYPE='ASSIGN',
--    RESOURCE_ID = the assignment id, PRIMARY_FLAG='Y').
--
-- This generator now emits TWO .dat files in the ONE object zip:
--   WorkPattern.dat        -- the pattern definition + its shifts
--   ScheduleAssignment.dat -- assign the schedule to the worker
-- One DMT object = one zip; the zip carries the two HDL business objects that
-- together deliver a worker's work schedule. The pattern definition no longer
-- carries AssignmentNumber; the worker linkage lives solely on
-- ScheduleAssignment, which references the worker by AssignmentNumber and the
-- schedule by ScheduleName.
--
-- OBJECT_TYPE = 'WorkSchedules'.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_WORK_SCHED_HDL_GEN_PKG';

    -- WorkPattern definition METADATA (no AssignmentNumber — that was the
    -- conflation bug; a pattern is not a worker assignment). RepeatNumber /
    -- RepeatCycle define the pattern's repeat span (1 day cycle by default).
    -- WorkPatternAltCode is the pattern's own stable reference code, reused as
    -- the shift's parent key.
    C_WORKPATTERN_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|WorkPatternTypeName|RepeatNumber|RepeatCycle|DateFrom|WorkPatternAltCode';

    -- WorkPatternShift child METADATA. DayOfWorkPattern is the day index within
    -- the pattern; ShiftStartTime/ShiftEndTime + DurationMinutes describe the
    -- shift; WorkPatternAltCode ties the shift back to its parent pattern.
    C_WORKPATTERNSHIFT_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|WorkPatternAltCode|DayOfWorkPattern|ShiftStartTime|ShiftEndTime|DurationMinutes';

    -- ScheduleAssignment METADATA — assign the schedule to the worker. The
    -- schedule is referenced by name (ScheduleName); the worker by
    -- AssignmentNumber; ResourceType='ASSIGN' means the resource is a worker's
    -- assignment.
    C_SCHEDASSIGN_COLS CONSTANT VARCHAR2(4000) :=
        'SourceSystemOwner|SourceSystemId|ScheduleName|AssignmentNumber|ResourceType|PrimaryFlag|StartDate|EndDate';

    C_SOURCE_SYSTEM CONSTANT VARCHAR2(30) := 'HRC_SQLLOADER';

    -- Default repeat span for a migrated pattern: one weekly (7-day) cycle.
    C_REPEAT_NUMBER CONSTANT VARCHAR2(10) := '1';
    C_REPEAT_CYCLE  CONSTANT VARCHAR2(10) := '7';


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
        l_pattern     CLOB;   -- WorkPattern.dat        (definition + shifts)
        l_assign      CLOB;   -- ScheduleAssignment.dat (worker assignment)
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

        DBMS_LOB.CREATETEMPORARY(l_pattern, TRUE);
        DBMS_LOB.CREATETEMPORARY(l_assign, TRUE);


        -- ============================================================
        -- 1. WorkPattern (pattern DEFINITION) + WorkPatternShift child
        --    -> WorkPattern.dat
        --    No AssignmentNumber here: a pattern definition is not a worker
        --    assignment. WORK_SCHEDULE_NAME is the pattern's own name (and its
        --    WorkPatternAltCode); the shift child references the parent by that
        --    same alt code.
        -- ============================================================
        IF has_rows('DMT_WORK_SCHED_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_pattern,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPattern', C_WORKPATTERN_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPattern', C_WORKPATTERN_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_WORK_SCHED_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                                   || '|' ||
                          pv(r.WORK_SCHEDULE_NAME) || '_WPAT'              || '|' ||  -- SourceSystemId
                          NVL(pv(r.WORK_SCHEDULE_TYPE), '9A - 5P General Shift') || '|' ||  -- WorkPatternTypeName
                          C_REPEAT_NUMBER                                  || '|' ||  -- RepeatNumber
                          C_REPEAT_CYCLE                                   || '|' ||  -- RepeatCycle
                          pv(r.SCHEDULE_START_DATE)                        || '|' ||  -- DateFrom
                          pv(r.WORK_SCHEDULE_NAME);                                   -- WorkPatternAltCode
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_pattern, l_vals, p_discriminator => 'WorkPattern');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;

        -- WorkPatternShift child rows (same file, WorkPattern.dat)
        IF has_rows('DMT_WORK_SCHED_DTL_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_pattern,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPatternShift', C_WORKPATTERNSHIFT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('WorkPatternShift', C_WORKPATTERNSHIFT_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_WORK_SCHED_DTL_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                                   || '|' ||
                          pv(r.WORK_SCHEDULE_NAME) || '_WSHIFT_' || TO_CHAR(r.TFM_SEQUENCE_ID) || '|' || -- SourceSystemId (unique)
                          pv(r.WORK_SCHEDULE_NAME)                         || '|' ||  -- WorkPatternAltCode (FK to parent)
                          pv(r.SHIFT_DATE)                                 || '|' ||  -- DayOfWorkPattern (1..7)
                          pv(r.START_TIME)                                 || '|' ||  -- ShiftStartTime
                          pv(r.END_TIME)                                   || '|' ||  -- ShiftEndTime
                          pv(r.DURATION);                                             -- DurationMinutes
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_pattern, l_vals, p_discriminator => 'WorkPatternShift');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- 2. ScheduleAssignment (assign schedule to WORKER)
        --    -> ScheduleAssignment.dat
        --    One assignment row per WorkSchedule TFM row that names a worker
        --    (PERSON_NUMBER present). ScheduleName references the work schedule;
        --    AssignmentNumber references the worker's assignment; the worker is
        --    traceable through SourceSystemId (PERSON_NUMBER-derived).
        -- ============================================================
        IF has_rows('DMT_WORK_SCHED_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_assign,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('ScheduleAssignment', C_SCHEDASSIGN_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER('ScheduleAssignment', C_SCHEDASSIGN_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_WORK_SCHED_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                AND    t.PERSON_NUMBER IS NOT NULL
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_vals := C_SOURCE_SYSTEM                                   || '|' ||
                          pv(r.PERSON_NUMBER) || '_WSASG'                  || '|' ||  -- SourceSystemId (worker-traceable)
                          pv(r.WORK_SCHEDULE_NAME)                         || '|' ||  -- ScheduleName (the work schedule)
                          pv(r.PERSON_NUMBER)                              || '|' ||  -- AssignmentNumber (= prefixed person number)
                          'ASSIGN'                                         || '|' ||  -- ResourceType (worker assignment)
                          'Y'                                              || '|' ||  -- PrimaryFlag
                          pv(r.SCHEDULE_START_DATE)                        || '|' ||  -- StartDate
                          pv(r.SCHEDULE_END_DATE);                                    -- EndDate
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_assign, l_vals, p_discriminator => 'ScheduleAssignment');
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- ZIP the two DAT CLOBs (one object zip, two HDL business objects)
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_pattern) > 0 THEN
            UTL_ZIP.add1file(l_zip, 'WorkPattern.dat', clob_to_blob(l_pattern));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_assign) > 0 THEN
            UTL_ZIP.add1file(l_zip, 'ScheduleAssignment.dat', clob_to_blob(l_assign));
        END IF;
        UTL_ZIP.finish_zip(l_zip);

        -- ============================================================
        -- Store in DMT_FBDI_CSV_TBL + DMT_FBDI_ZIP_TBL. The stored CSV
        -- content keeps the WorkPattern.dat body for inspection/audit; the
        -- ScheduleAssignment.dat travels in the zip alongside it.
        -- ============================================================
        SELECT DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;

        INSERT INTO DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'WorkSchedules',
            'WorkPattern.dat', l_row_count, l_pattern, l_now
        );

        INSERT INTO DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'WorkSchedules', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_WORK_SCHED_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_WORK_SCHED_DTL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';


        DBMS_LOB.FREETEMPORARY(l_pattern);
        DBMS_LOB.FREETEMPORARY(l_assign);

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
