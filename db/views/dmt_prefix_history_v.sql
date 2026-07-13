-- DMT_PREFIX_HISTORY_V
-- One row per object (CEMLI) per run, exposing the single per-run prefix.
-- Decided 2026-07-03 as part of the prefix consolidation: with one prefix per
-- run stored on DMT_PIPELINE_RUN_TBL, this view is the canonical "which prefix
-- did object X use in run Y" lookup. It backs (a) the dependent-prefix picker's
-- cross-run/scenario case -- the most recent SUCCESSFUL run of an upstream CEMLI
-- in a given scenario -- and (b) the Run-History UI's per-object prefix display.
-- Objects that participated in a run are the distinct CEMLI_CODEs on that run's
-- work queue; the prefix, scenario and status come from the run header.
CREATE OR REPLACE EDITIONABLE VIEW "DMT_PREFIX_HISTORY_V" ("RUN_ID", "CEMLI_CODE", "PREFIX", "SCENARIO_ID", "SCENARIO_NAME", "PIPELINE_CODES", "RUN_MODE", "RUN_STATUS", "SUBMITTED_DATE", "COMPLETED_DATE") AS
  SELECT q.RUN_ID,
         q.CEMLI_CODE,
         r.PREFIX,
         r.SCENARIO_ID,
         r.SCENARIO_NAME,
         r.PIPELINE_CODES,
         r.RUN_MODE,
         r.RUN_STATUS,
         r.SUBMITTED_DATE,
         r.COMPLETED_DATE
  FROM   (SELECT DISTINCT RUN_ID, CEMLI_CODE FROM DMT_OWNER.DMT_WORK_QUEUE_TBL) q
  JOIN   DMT_OWNER.DMT_PIPELINE_RUN_TBL r
      ON r.RUN_ID = q.RUN_ID;
/
