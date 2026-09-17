-- PACKAGE DMT_WORK_SCHED_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_WORK_SCHED_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_WORK_SCHED_HDL_GEN_PKG
-- Generates the WorkSchedules HDL zip from TFM staging records.
--
-- WorkSchedules is ONE DMT object = ONE zip. The zip carries TWO DAT files,
-- one per distinct Fusion HDL business object (re-modelled 2026-09-17):
--   WorkPattern.dat        - the work pattern DEFINITION (+ WorkPatternShift
--                            child). Base view HTS_WORK_PATTERNS_VL.
--   ScheduleAssignment.dat - assigns the schedule to the WORKER, by
--                            AssignmentNumber + ScheduleName, ResourceType
--                            'ASSIGN'. Base table PER_SCHEDULE_ASSIGNMENTS.
-- The pattern definition no longer carries AssignmentNumber; the worker
-- linkage lives solely on ScheduleAssignment.
--
-- OBJECT_TYPE = 'WorkSchedules'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_WORK_SCHED_HDL_GEN_PKG;
/
