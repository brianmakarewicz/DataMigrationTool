-- DMT_OBJECT_FUNNEL_V
-- Per run + object + sub-object funnel: how many source records made it through
-- each pipeline stage, and where the rest dropped off. One row per
-- (RUN_ID, CEMLI_CODE, SUB_OBJECT). Each source record is counted in exactly one
-- terminal position.
--
-- Built on DMT_OBJECT_DETAIL_V (the TFM-side counts — transformed / generated /
-- loaded / load-failed / in-progress / unreconciled, reused so the ~97-table
-- union is not repeated) FULL OUTER JOINed to the two pre-TFM failure lanes in
-- DMT_STG_TFM_ERROR_TBL, so an object whose rows ALL failed before reaching TFM
-- (no TFM row, hence absent from DMT_OBJECT_DETAIL_V) still appears here.
--
-- Precedence — reaching TFM wins. A record that has a TFM row this run is counted
-- as TRANSFORMED (and its downstream state), even if it also has an error row from
-- an earlier stage this run (e.g. ALL-mode reprocessing re-transforms a row that
-- pre-validation rejected). So the pre-TFM failure lanes count only records that
-- did NOT reach TFM — anti-joined against DMT_RECORD_DETAIL_V, the set of records
-- that reached TFM. This keeps STAGED = distinct source records, never a
-- double-count.
--
-- Stages (left to right): STAGED -> [PREVALIDATION_FAILED] -> TRANSFORMED
--   -> [TRANSFORM_FAILED] -> GENERATED -> LOADED / LOAD_FAILED / UNACCOUNTED;
--   IN_PROGRESS and UNRECONCILED are in-flight / accounting-defect buckets carried
--   from the detail view. UNACCOUNTED is the real terminal status set by the shared
--   unaccounted sweep (a record neither confirmed LOADED nor failed with a real
--   Fusion error) — its own lane, distinct from LOAD_FAILED, so the UI can color it
--   dark-red; the goal of the cycle is to drive it to zero. STAGED is derived per run
--   (STG has no RUN_ID): everything that entered this run for the sub-object =
--   TRANSFORMED + the two (non-transformed) failed lanes.
--
-- The two failed lanes are split by the design's ERROR_TEXT tag prefix (section 5:
-- '[PRE_VALIDATION]' vs '[TRANSFORM_ERROR]', always the leading token) — an
-- anchored prefix match on the free-text message, not a controlled-code column, and
-- counted DISTINCT per record. TRANSFORM_FAILED reads 0 until the transform-stage
-- error wiring is built (section 7 proposed rule) — the lane is structural and fills
-- with no view change.
CREATE OR REPLACE EDITIONABLE VIEW "DMT_OBJECT_FUNNEL_V"
    ("CEMLI_CODE", "SUB_OBJECT", "SUB_ORDER", "RUN_ID",
     "STAGED", "PREVALIDATION_FAILED", "TRANSFORMED", "TRANSFORM_FAILED",
     "GENERATED", "LOADED", "LOAD_FAILED", "UNACCOUNTED", "IN_PROGRESS", "UNRECONCILED",
     "ALL_UNACCOUNTED",
     "PIPELINE_CODES", "SCENARIO_NAME", "PREFIX", "SUBMITTED_DATE", "COMPLETED_DATE", "RUN_STATUS") AS
  WITH reached_tfm AS (
    -- the set of source records that reached TFM this run (one row per TFM record).
    -- DMT_RECORD_DETAIL_V now also carries a pre-transform-failure lane whose rows
    -- did NOT reach TFM (TFM_SEQUENCE_ID IS NULL); exclude them here so this CTE keeps
    -- meaning "rows that actually reached a TFM table" — otherwise the err anti-join
    -- below would treat every pre-validation failure as already-in-TFM and drop it,
    -- making 100%-pre-validation-failed objects vanish from the funnel entirely.
    SELECT DISTINCT RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID
    FROM   DMT_RECORD_DETAIL_V
    WHERE  TFM_SEQUENCE_ID IS NOT NULL
  ),
  err AS (
    -- distinct records that failed at each pre-TFM stage AND did not reach TFM
    SELECT e.RUN_ID, e.CEMLI_CODE, e.SUB_OBJECT,
           COUNT(DISTINCT CASE WHEN e.ERROR_TEXT LIKE '[PRE_VALIDATION]%'  THEN e.STG_SEQUENCE_ID END) AS PREVAL_CNT,
           COUNT(DISTINCT CASE WHEN e.ERROR_TEXT LIKE '[TRANSFORM_ERROR]%' THEN e.STG_SEQUENCE_ID END) AS TRANSFORM_CNT
    FROM   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
    WHERE  NOT EXISTS (SELECT 1 FROM reached_tfm r
                       WHERE r.RUN_ID = e.RUN_ID
                       AND   r.CEMLI_CODE = e.CEMLI_CODE
                       AND   r.SUB_OBJECT = e.SUB_OBJECT
                       AND   r.STG_SEQUENCE_ID = e.STG_SEQUENCE_ID)
    GROUP BY e.RUN_ID, e.CEMLI_CODE, e.SUB_OBJECT
  )
  SELECT
    COALESCE(d.CEMLI_CODE, e.CEMLI_CODE)                                  AS CEMLI_CODE,
    COALESCE(d.SUB_OBJECT, e.SUB_OBJECT)                                  AS SUB_OBJECT,
    NVL(d.SUB_ORDER, 0)                                                   AS SUB_ORDER,
    COALESCE(d.RUN_ID, e.RUN_ID)                                          AS RUN_ID,
    NVL(d.TOTAL_ROWS, 0) + NVL(e.PREVAL_CNT, 0) + NVL(e.TRANSFORM_CNT, 0) AS STAGED,
    NVL(e.PREVAL_CNT, 0)                                                  AS PREVALIDATION_FAILED,
    NVL(d.TOTAL_ROWS, 0)                                                  AS TRANSFORMED,
    NVL(e.TRANSFORM_CNT, 0)                                               AS TRANSFORM_FAILED,
    NVL(d.GENERATED_ROWS, 0)                                              AS GENERATED,
    NVL(d.LOADED_ROWS, 0)                                                 AS LOADED,
    NVL(d.FAILED_ROWS, 0)                                                 AS LOAD_FAILED,
    -- UNACCOUNTED lane (2026-07-21): rows the shared sweep marked with the real
    -- terminal status UNACCOUNTED. Distinct from LOAD_FAILED so the UI can render
    -- it dark-red (unaccounted) vs the lighter red of a genuine load failure.
    NVL(d.UNACCOUNTED_ROWS, 0)                                            AS UNACCOUNTED,
    NVL(d.IN_PROGRESS_ROWS, 0)                                            AS IN_PROGRESS,
    NVL(d.UNRECONCILED_ROWS, 0)                                           AS UNRECONCILED,
    -- ALL_UNACCOUNTED (2026-07-22): object-level tile severity. 'Y' when EVERY
    -- staged record for this sub-object ended UNACCOUNTED — i.e. the load/import/
    -- cost job failed at the job level and produced no per-row verdict for anyone
    -- (nothing LOADED, nothing LOAD_FAILED, no pre-TFM failure). This is the
    -- signature of a true job crash (e.g. Expenditures ORA-01008, AR AutoInvoice
    -- abort): the UI colors the whole tile DARK red. 'N' with UNACCOUNTED > 0 is a
    -- PARTIAL case (some accounted, some not) → lighter red. Derived, not stored.
    CASE
      WHEN NVL(d.UNACCOUNTED_ROWS, 0) > 0
       AND NVL(d.UNACCOUNTED_ROWS, 0) =
           NVL(d.TOTAL_ROWS, 0) + NVL(e.PREVAL_CNT, 0) + NVL(e.TRANSFORM_CNT, 0)
      THEN 'Y' ELSE 'N'
    END                                                                  AS ALL_UNACCOUNTED,
    m.PIPELINE_CODES,
    m.SCENARIO_NAME,
    m.PREFIX,
    m.SUBMITTED_DATE,
    m.COMPLETED_DATE,
    m.RUN_STATUS
  FROM       DMT_OBJECT_DETAIL_V d
  FULL OUTER JOIN err e
          ON  e.RUN_ID     = d.RUN_ID
          AND e.CEMLI_CODE  = d.CEMLI_CODE
          AND e.SUB_OBJECT  = d.SUB_OBJECT
  LEFT JOIN  DMT_OWNER.DMT_PIPELINE_RUN_TBL m
          ON  m.RUN_ID = COALESCE(d.RUN_ID, e.RUN_ID)
  ORDER BY   COALESCE(d.RUN_ID, e.RUN_ID) DESC,
             COALESCE(d.CEMLI_CODE, e.CEMLI_CODE),
             NVL(d.SUB_ORDER, 0);
