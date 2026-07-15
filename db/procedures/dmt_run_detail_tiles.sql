-- PROCEDURE DMT_RUN_DETAIL_TILES

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_RUN_DETAIL_TILES" (p_run_id IN NUMBER) IS
    l_pp   VARCHAR2(30) := '***';
    l_bg   VARCHAR2(30);
    l_app  VARCHAR2(10) := V('APP_ID');
    l_ses  VARCHAR2(30) := V('APP_SESSION');
    l_has_queue NUMBER;
    l_phase   VARCHAR2(10);
    l_failerr NUMBER;

    -- ------------------------------------------------------------------
    -- Outcome-based tile palette (DMT_DESIGN.html section 9, decided
    -- 2026-07-06). ONE decision, called by both render paths below, so
    -- the queue path and the sync path can never diverge again.
    --
    -- p_phase is the object's lifecycle state, normalised by each caller:
    --   PENDING  queued, not started         -> White
    --   RUNNING  in progress                 -> Blue
    --   SKIPPED  no rows / dependency-skipped -> Grey
    --   ERRORED  did NOT finish (uncaught exception, API error, dead
    --            loader, BIP failure, DB error - any unexpected failure)
    --                                         -> Red
    --   DONE     finished normally -> colour by rolled-up record counts.
    --
    -- Counts are the rolled-up per-object outcome numbers:
    --   p_loaded     records confirmed in Fusion base tables (LOADED)
    --   p_failed_err records FAILED with a reportable error
    --   p_unacc      records unaccounted (FAILED, no Fusion id, no error)
    --   p_total      = loaded + failed_err + unacc
    -- Among finished objects the counts decide the colour; every-row-
    -- unaccounted is treated as Red (the doc's systemic-failure signature).
    -- ------------------------------------------------------------------
    FUNCTION tile_bg(p_phase VARCHAR2, p_total NUMBER, p_loaded NUMBER,
                     p_failed_err NUMBER, p_unacc NUMBER) RETURN VARCHAR2 IS
    BEGIN
      IF p_phase = 'PENDING' THEN RETURN '#ffffff'; END IF;   -- White: queued
      IF p_phase = 'RUNNING' THEN RETURN '#e8f0fe'; END IF;   -- Blue: in progress
      IF p_phase = 'ERRORED' AND NVL(p_total,0) = 0 THEN RETURN '#f5b8b1'; END IF;   -- Red: true infra break, no rows processed (finished-with-counts ERRORED falls through to the outcome logic below)
      IF NVL(p_total,0) = 0 OR p_phase = 'SKIPPED' THEN RETURN '#f0f0f0'; END IF; -- Grey
      IF NVL(p_unacc,0)  >= p_total THEN RETURN '#f5b8b1'; END IF;  -- Red: all unaccounted
      IF NVL(p_loaded,0) >= p_total THEN RETURN '#b7e1c0'; END IF;  -- Green: 100% loaded
      IF NVL(p_unacc,0) > 0 OR NVL(p_loaded,0) = 0 THEN RETURN '#fce8e6'; END IF; -- Light red
      RETURN '#e6f4ea';                                       -- Light green: some failed, all accounted
    END tile_bg;

    -- Status line HTML, consistent with the colour the palette chose.
    FUNCTION tile_status(p_phase VARCHAR2, p_total NUMBER, p_loaded NUMBER,
                         p_failed_err NUMBER, p_unacc NUMBER) RETURN VARCHAR2 IS
    BEGIN
      IF p_phase = 'PENDING' THEN RETURN '<span style="color:#888">Queued</span>'; END IF;
      IF p_phase = 'RUNNING' THEN RETURN '<span style="color:#0b5cc0">In progress</span>'; END IF;
      IF p_phase = 'ERRORED' AND NVL(p_total,0) = 0 THEN RETURN '<span style="color:#b3261e">&#10007; Failed</span>'; END IF;
      IF NVL(p_total,0) = 0 OR p_phase = 'SKIPPED' THEN RETURN '<span style="color:#888">No rows</span>'; END IF;
      IF NVL(p_unacc,0) >= p_total THEN
        RETURN '<span style="color:#b3261e">' || p_unacc || ' unaccounted</span>';
      END IF;
      IF NVL(p_loaded,0) >= p_total THEN
        RETURN '<span style="color:#1a7d33">&#10003; ' || p_loaded || ' loaded</span>';
      END IF;
      IF NVL(p_loaded,0) = 0 AND NVL(p_unacc,0) = 0 THEN
        RETURN '<span style="color:#b3261e">&#10007; ' || p_failed_err || ' failed</span>';
      END IF;
      -- mixed: show every non-zero bucket
      RETURN '<span style="color:#1a7d33">' || p_loaded || ' loaded</span>'
          || CASE WHEN NVL(p_failed_err,0) > 0 THEN ' &middot; <span style="color:#b3261e">' || p_failed_err || ' failed</span>' END
          || CASE WHEN NVL(p_unacc,0) > 0 THEN ' &middot; <span style="color:#c47a00">' || p_unacc || ' unaccounted</span>' END;
    END tile_status;

    -- Normalise the async work-queue status into a palette phase.
    FUNCTION phase_from_work(p_work_status VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      RETURN CASE p_work_status
               WHEN 'DONE'    THEN 'DONE'      -- finished + fully accounted -> counts decide
               WHEN 'FAILED'  THEN 'ERRORED'   -- work item broke -> Red
               WHEN 'SKIPPED' THEN 'SKIPPED'
               WHEN 'PENDING' THEN 'PENDING'
               ELSE 'RUNNING'
             END;
    END phase_from_work;

    -- Normalise the sync summary object status into a palette phase.
    FUNCTION phase_from_object(p_object_status VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      RETURN CASE p_object_status
               WHEN 'FAILED'      THEN 'ERRORED'
               WHEN 'SKIPPED'     THEN 'SKIPPED'
               WHEN 'IN_PROGRESS' THEN 'RUNNING'
               ELSE 'DONE'   -- COMPLETED / COMPLETED_ERRORS / UNRECONCILED -> counts decide
             END;
    END phase_from_object;
BEGIN
    -- Check if work queue has rows for this run
    SELECT COUNT(*) INTO l_has_queue
    FROM DMT_WORK_QUEUE_TBL WHERE RUN_ID = p_run_id AND ROWNUM = 1;

    IF l_has_queue > 0 THEN
        -- Async path: render from work queue.
        -- NOTE (partition limitation): the queue renders one tile per work
        -- item (per partition), but DMT_V_CEMLI_STATUS aggregates counts per
        -- object, so a partitioned object shows object-level counts on each
        -- partition tile. Per-partition counts are a separate backlog item
        -- (DMT_DESIGN section 9 partition tiles) needing a partition-aware view.
        FOR rec IN (
            SELECT QUEUE_ID, PIPELINE, CEMLI_CODE, WORK_STATUS, PARTITION_LABEL,
                   COALESCE(q.LOAD_ESS_JOB_ID,
                       TO_CHAR((SELECT MAX(ej.REQUEST_ID) FROM DMT_OWNER.DMT_ESS_JOB_TBL ej
                                WHERE ej.RUN_ID = q.RUN_ID AND ej.CEMLI_CODE = q.CEMLI_CODE
                                  AND ej.DEPTH_LEVEL = 0
                                  AND ej.JOB_SHORT_NAME = 'InterfaceLoaderController'))) AS LOAD_ESS_JOB_ID,
                   COALESCE(q.IMPORT_ESS_JOB_ID,
                       TO_CHAR((SELECT MAX(ej.REQUEST_ID) FROM DMT_OWNER.DMT_ESS_JOB_TBL ej
                                WHERE ej.RUN_ID = q.RUN_ID AND ej.CEMLI_CODE = q.CEMLI_CODE
                                  AND ej.DEPTH_LEVEL = 0
                                  AND ej.JOB_SHORT_NAME <> 'InterfaceLoaderController'))) AS IMPORT_ESS_JOB_ID,
                   ERROR_MESSAGE, RUN_ID,
                   -- Rolled-up outcome counts for the palette (loaded / failed / unaccounted).
                   (SELECT NVL(SUM(cs.ROW_COUNT),0) FROM DMT_OWNER.DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS TOT_ROWS,
                   (SELECT NVL(SUM(CASE WHEN cs.TFM_STATUS = 'LOADED' THEN cs.ROW_COUNT END),0)
                      FROM DMT_OWNER.DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS LOADED_ROWS,
                   (SELECT NVL(SUM(CASE WHEN cs.TFM_STATUS = 'FAILED' THEN cs.ROW_COUNT END),0)
                      FROM DMT_OWNER.DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS FAILED_ROWS,
                   (SELECT NVL(SUM(cs.UNRECONCILED_COUNT),0) FROM DMT_OWNER.DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS UNACC_ROWS,
                   TO_CHAR(STARTED_AT, 'HH24:MI:SS') STARTED,
                   TO_CHAR(COMPLETED_AT, 'HH24:MI:SS') COMPLETED
            FROM DMT_WORK_QUEUE_TBL q WHERE RUN_ID = p_run_id
            ORDER BY PIPELINE, SORT_ORDER, QUEUE_ID
        ) LOOP
            IF rec.PIPELINE != l_pp THEN
                IF l_pp != '***' THEN HTP.P('</div>'); END IF;
                HTP.P('<h3 style="margin:20px 0 8px;font-size:14px;color:#555;text-transform:uppercase;letter-spacing:1px">'
                    || rec.PIPELINE || '</h3><div style="display:flex;flex-wrap:wrap;gap:12px">');
                l_pp := rec.PIPELINE;
            END IF;

            l_phase   := phase_from_work(rec.WORK_STATUS);
            l_failerr := GREATEST(NVL(rec.FAILED_ROWS,0) - NVL(rec.UNACC_ROWS,0), 0);
            l_bg := tile_bg(l_phase, rec.TOT_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNACC_ROWS);
              HTP.P('<div style="background:' || l_bg || ';border:1px solid #ddd;border-radius:8px;padding:14px;min-width:200px;max-width:280px;flex:1">');
              HTP.P('<div style="font-weight:bold;font-size:14px;margin-bottom:4px">');
              IF NVL(rec.TOT_ROWS,0) = 0 THEN
                  HTP.P('<span style="color:#999">' || rec.CEMLI_CODE || '</span>');
              ELSE
                  HTP.P('<a href="f?p=' || l_app || ':52:' || l_ses || '::NO::P52_RUN_ID,P52_CEMLI_CODE:'
                      || rec.RUN_ID || ',' || rec.CEMLI_CODE
                      || '" style="color:inherit;text-decoration:none;border-bottom:1px dashed #999">'
                      || rec.CEMLI_CODE || '</a>');
              END IF;
              HTP.P('</div><div style="font-size:12px;color:#555">');
            HTP.P(tile_status(l_phase, rec.TOT_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNACC_ROWS));
            IF rec.PARTITION_LABEL IS NOT NULL THEN HTP.P(' &middot; ' || rec.PARTITION_LABEL); END IF;
            IF rec.STARTED IS NOT NULL THEN
                HTP.P('<br>' || rec.STARTED || CASE WHEN rec.COMPLETED IS NOT NULL THEN ' &rarr; ' || rec.COMPLETED END);
            END IF;
            IF rec.LOAD_ESS_JOB_ID IS NOT NULL THEN
                HTP.P('<br>Load: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.LOAD_ESS_JOB_ID || ',' || rec.RUN_ID || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.LOAD_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.IMPORT_ESS_JOB_ID IS NOT NULL THEN
                HTP.P(' &middot; Import: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.IMPORT_ESS_JOB_ID || ',' || rec.RUN_ID || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.IMPORT_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.ERROR_MESSAGE IS NOT NULL THEN
                HTP.P('<br><span style="color:#c42b1c;font-size:11px">' || SUBSTR(rec.ERROR_MESSAGE, 1, 120) || '</span>');
            END IF;
            HTP.P('</div></div>');
        END LOOP;
        IF l_pp != '***' THEN HTP.P('</div>'); END IF;
    ELSE
        -- Sync path: derive tiles from CEMLI_SEQUENCE via DMT_PIPELINE_SUMMARY_V
        FOR rec IN (
            SELECT v.OBJECT_TYPE AS CEMLI_CODE,
                   v.PIPELINE,
                   v.OBJECT_STATUS,
                   v.TOTAL_ROWS,
                   v.LOADED_ROWS,
                   v.FAILED_ROWS,
                   v.UNRECONCILED_ROWS,
                   v.LOAD_ESS_JOB_ID,
                   v.IMPORT_ESS_JOB_ID,
                   v.SORT_ORDER
            FROM DMT_PIPELINE_SUMMARY_V v
            WHERE v.RUN_ID = p_run_id
            AND   v.OBJECT_TYPE != '__PIPELINE__'
            ORDER BY
                CASE v.PIPELINE
                    WHEN 'Configuration' THEN 0 WHEN 'MasterData' THEN 1
                    WHEN 'P2P' THEN 2 WHEN 'O2C' THEN 3
                    WHEN 'Financials' THEN 4 WHEN 'Projects' THEN 5
                    WHEN 'Standalone' THEN 6 WHEN 'HCM' THEN 7 ELSE 9
                END,
                v.SORT_ORDER
        ) LOOP
            IF rec.PIPELINE != l_pp THEN
                IF l_pp != '***' THEN HTP.P('</div>'); END IF;
                HTP.P('<h3 style="margin:20px 0 8px;font-size:14px;color:#555;text-transform:uppercase;letter-spacing:1px">'
                    || rec.PIPELINE || '</h3><div style="display:flex;flex-wrap:wrap;gap:12px">');
                l_pp := rec.PIPELINE;
            END IF;

            l_phase   := phase_from_object(rec.OBJECT_STATUS);
            l_failerr := GREATEST(NVL(rec.FAILED_ROWS,0) - NVL(rec.UNRECONCILED_ROWS,0), 0);
            l_bg := tile_bg(l_phase, rec.TOTAL_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNRECONCILED_ROWS);
              HTP.P('<div style="background:' || l_bg || ';border:1px solid #ddd;border-radius:8px;padding:14px;min-width:200px;max-width:280px;flex:1">');
              HTP.P('<div style="font-weight:bold;font-size:14px;margin-bottom:4px">');
              IF NVL(rec.TOTAL_ROWS, 0) = 0 THEN
                  HTP.P('<span style="color:#999">' || rec.CEMLI_CODE || '</span>');
              ELSE
                  HTP.P('<a href="f?p=' || l_app || ':52:' || l_ses || '::NO::P52_RUN_ID,P52_CEMLI_CODE:'
                      || p_run_id || ',' || rec.CEMLI_CODE
                      || '" style="color:inherit;text-decoration:none;border-bottom:1px dashed #999">'
                      || rec.CEMLI_CODE || '</a>');
              END IF;
              HTP.P('</div><div style="font-size:12px;color:#555">');
            HTP.P(tile_status(l_phase, rec.TOTAL_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNRECONCILED_ROWS));

            IF rec.LOAD_ESS_JOB_ID IS NOT NULL THEN
                HTP.P('<br>Load: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.LOAD_ESS_JOB_ID || ',' || p_run_id || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.LOAD_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.IMPORT_ESS_JOB_ID IS NOT NULL THEN
                HTP.P(' &middot; Import: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.IMPORT_ESS_JOB_ID || ',' || p_run_id || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.IMPORT_ESS_JOB_ID || '</a>');
            END IF;

            HTP.P('</div></div>');
        END LOOP;
        IF l_pp != '***' THEN HTP.P('</div>'); END IF;
    END IF;
END;
/
