-- PACKAGE DMT_WORK_SCHED_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_WORK_SCHED_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_WORK_SCHED_HDL_GEN_PKG
-- Generates the WorkSchedule.dat HDL file from TFM staging records.
--
-- WorkSchedule HDL is ONE zip containing ONE DAT file with 2 business object(s):
--   WorkSchedule, WorkScheduleShift.
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
