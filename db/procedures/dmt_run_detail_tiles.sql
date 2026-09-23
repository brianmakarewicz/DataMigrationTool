-- PROCEDURE DMT_RUN_DETAIL_TILES

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_RUN_DETAIL_TILES" (p_run_id IN NUMBER) IS
    l_pp   VARCHAR2(30) := '***';
    l_bg   VARCHAR2(30);
    l_app  VARCHAR2(10) := V('APP_ID');
    l_ses  VARCHAR2(30) := V('APP_SESSION');
    l_has_queue NUMBER;
    l_phase   VARCHAR2(10);
    l_failerr NUMBER;
    l_part_keys VARCHAR2(4000);   -- partition column name(s) for a parent coordinator tile
    l_run_status VARCHAR2(30);
    l_run_active BOOLEAN := FALSE;   -- TRUE while the parent run has not reached a terminal status

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
      -- In-flight: while the run is still active, an object that FINISHED NORMALLY
      -- (phase DONE) with NO real failures but is not yet fully loaded is still
      -- working -- its records are generated / awaiting load / awaiting reconciliation
      -- (loaded, failed and unaccounted can all still be 0). That is in progress, not a
      -- failure. Colour it Blue until the run reaches a terminal status; only then do
      -- not-loaded rows count as failure. Scoped to DONE so an item whose own work
      -- status already resolved to FAILED (phase ERRORED) is NOT masked as in-progress
      -- -- it keeps falling through to the outcome logic and reds out.
      IF p_phase = 'DONE' AND l_run_active AND NVL(p_failed_err,0) = 0 AND NVL(p_loaded,0) < NVL(p_total,0) THEN RETURN '#e8f0fe'; END IF;
      IF NVL(p_unacc,0)  >= p_total THEN RETURN '#f5b8b1'; END IF;  -- Red: all unaccounted
      IF NVL(p_loaded,0) >= p_total THEN RETURN '#5fbf4f'; END IF;  -- Pure green: 100% loaded
      IF NVL(p_unacc,0) > 0 OR NVL(p_loaded,0) = 0 THEN RETURN '#fce8e6'; END IF; -- Light red
      RETURN '#c2e58f';                                       -- Light green (Option B): some failed but all accounted (distinct from the pure full-loaded green above)
    END tile_bg;

    -- Status line HTML, consistent with the colour the palette chose.
    FUNCTION tile_status(p_phase VARCHAR2, p_total NUMBER, p_loaded NUMBER,
                         p_failed_err NUMBER, p_unacc NUMBER) RETURN VARCHAR2 IS
    BEGIN
      IF p_phase = 'PENDING' THEN RETURN '<span style="color:#888">Queued</span>'; END IF;
      IF p_phase = 'RUNNING' THEN RETURN '<span style="color:#0b5cc0">In progress</span>'; END IF;
      IF p_phase = 'ERRORED' AND NVL(p_total,0) = 0 THEN RETURN '<span style="color:#b3261e">&#10007; Failed</span>'; END IF;
      IF NVL(p_total,0) = 0 OR p_phase = 'SKIPPED' THEN RETURN '<span style="color:#888">No rows</span>'; END IF;
      -- In-flight: during an active run, an object that finished normally (phase DONE)
      -- with no real failures but is not yet fully loaded is still working (generating /
      -- loading / reconciling), not a failure. Show a clock with the in-progress count,
      -- not a red X. Scoped to DONE so an ERRORED item is not masked as in-progress.
      IF p_phase = 'DONE' AND l_run_active AND NVL(p_failed_err,0) = 0 AND NVL(p_loaded,0) < NVL(p_total,0) THEN
        RETURN '<span style="color:#0b5cc0">&#128337; ' ||
               CASE WHEN NVL(p_loaded,0) > 0 THEN p_loaded || ' loaded &middot; ' END ||
               (NVL(p_total,0) - NVL(p_loaded,0) - NVL(p_failed_err,0)) || ' in progress</span>';
      END IF;
      IF NVL(p_unacc,0) >= p_total THEN
        RETURN '<span style="color:#b3261e">' || p_unacc || ' unaccounted</span>';
      END IF;
      IF NVL(p_loaded,0) >= p_total THEN
        RETURN '<span style="color:#000">&#10003; ' || p_loaded || ' loaded</span>';  -- black: reads on the deeper full-loaded green
      END IF;
      -- only a genuine failure (rows FAILED with a reportable error) shows a red X;
      -- never render "0 failed" as a failure (e.g. a terminal run with rows stuck
      -- un-loaded but not failed falls through to the neutral mixed line below).
      IF NVL(p_loaded,0) = 0 AND NVL(p_unacc,0) = 0 AND NVL(p_failed_err,0) > 0 THEN
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

    -- For a partition PARENT: the distinct partition-key COLUMN name(s) its
    -- children were split on, e.g. 'BATCH_ID' or 'DOCUMENT_NAME, USER_TRANSACTION_SOURCE'.
    -- Each child's PARTITION_KEY is a flat JSON object ({"COL":"val"} per the
    -- DMT_WORK_QUEUE_TBL.PARTITION_KEY column comment). We enumerate the key NAMES
    -- with the structured JSON parser JSON_OBJECT_T.get_keys() -- never regex offset
    -- arithmetic over the payload (DMT_DESIGN.html section 7: structured parsing over
    -- string arithmetic, JSON with JSON_VALUE / JSON_OBJECT_T). Returns the distinct
    -- names comma-joined, or NULL when the parent has no JSON-keyed children.
    FUNCTION part_key_names(p_parent_queue_id NUMBER) RETURN VARCHAR2 IS
      l_seen  VARCHAR2(4000) := '';   -- '|COL|' membership set, keeps first-seen order
      l_out   VARCHAR2(4000) := '';
      l_obj   JSON_OBJECT_T;
      l_keys  JSON_KEY_LIST;
    BEGIN
      FOR c IN (SELECT PARTITION_KEY FROM DMT_WORK_QUEUE_TBL
                 WHERE PARENT_QUEUE_ID = p_parent_queue_id
                   AND PARTITION_KEY IS NOT NULL
                   AND PARTITION_KEY <> 'ALL') LOOP
        BEGIN
          l_obj  := JSON_OBJECT_T.parse(c.PARTITION_KEY);
          l_keys := l_obj.get_keys();
          FOR i IN 1 .. l_keys.COUNT LOOP
            IF INSTR(l_seen, '|' || l_keys(i) || '|') = 0 THEN
              l_seen := l_seen || '|' || l_keys(i) || '|';
              l_out  := l_out || CASE WHEN l_out IS NOT NULL AND LENGTH(l_out) > 0 THEN ', ' END || l_keys(i);
            END IF;
          END LOOP;
        EXCEPTION WHEN OTHERS THEN NULL;  -- a non-JSON key (defensive) contributes no column name
        END;
      END LOOP;
      RETURN CASE WHEN LENGTH(l_out) > 0 THEN l_out END;
    END part_key_names;
BEGIN
    -- Parent run status: the tiles branch on whether the run is still active,
    -- so an object with unaccounted-but-not-failed records shows in progress
    -- mid-run and only turns to a failure once the run is terminal.
    BEGIN
        SELECT RUN_STATUS INTO l_run_status FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
    EXCEPTION WHEN NO_DATA_FOUND THEN l_run_status := NULL;
    END;
    l_run_active := NVL(l_run_status,'IN_PROGRESS')
                    NOT IN ('COMPLETED','COMPLETED_ERRORS','FAILED','NO_ROWS_PROCESSED');

    -- Check if work queue has rows for this run
    SELECT COUNT(*) INTO l_has_queue
    FROM DMT_WORK_QUEUE_TBL WHERE RUN_ID = p_run_id AND ROWNUM = 1;

    IF l_has_queue > 0 THEN
        -- Async path: render one tile per work item.
        --
        -- Partitioned objects (backlog #70): an object that partitions spawns a
        -- PARENT placeholder work item (the partition coordinator) plus one CHILD
        -- work item per partition key (e.g. Items/Customers by BATCH_ID, GL by
        -- Ledger). The parent does NOT submit an ESS load/import -- those belong to
        -- the children -- so the parent tile must show NO load/import request id and
        -- must be visibly marked as a coordinator, showing WHAT it partitioned on.
        -- Each child ran its OWN ESS load + import job, so each child tile must show
        -- its own DISTINCT request ids and WHICH partition it ran.
        --
        -- Load/import ids come ONLY from the work item's own LOAD_ESS_JOB_ID /
        -- IMPORT_ESS_JOB_ID columns (stamped per work item by the loader). The old
        -- COALESCE fallback to MAX(REQUEST_ID) keyed on RUN_ID+CEMLI_CODE was the
        -- root of the defect: DMT_ESS_JOB_TBL carries no partition discriminator, so
        -- that fallback fabricated the SAME id onto the parent and every child. It is
        -- removed. A parent (IS_PARENT) is forced to null ids; a child with no stamped
        -- id honestly shows no id rather than a shared fabricated one.
        --
        -- NOTE (still open, separate item): DMT_V_CEMLI_STATUS aggregates counts per
        -- object, so a partition child shows object-level counts. Per-partition counts
        -- need a partition-aware status view (tracked separately).
        FOR rec IN (
            SELECT QUEUE_ID, PIPELINE, CEMLI_CODE, WORK_STATUS, PARTITION_LABEL, PARTITION_KEY,
                   q.QUEUE_ID AS OWN_QUEUE_ID,
                   q.PARENT_QUEUE_ID,
                   -- A work item is a partition PARENT (coordinator) if it has children.
                   CASE WHEN EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                                     WHERE c.PARENT_QUEUE_ID = q.QUEUE_ID) THEN 1 ELSE 0 END AS IS_PARENT,
                   -- A work item is a partition CHILD if it was spawned from a parent.
                   CASE WHEN q.PARENT_QUEUE_ID IS NOT NULL THEN 1 ELSE 0 END AS IS_CHILD,
                   -- Own load/import ids only; a parent coordinator never exposes an id.
                   -- The old COALESCE fallback to MAX(REQUEST_ID) keyed on RUN_ID+CEMLI_CODE
                   -- is removed: DMT_ESS_JOB_TBL has no partition discriminator, so it
                   -- fabricated the SAME id onto the parent and every child. Per-child ids
                   -- are now stamped on the work item by the loader (#413), so the honest
                   -- source is the row's own column.
                   CASE WHEN EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                                     WHERE c.PARENT_QUEUE_ID = q.QUEUE_ID)
                        THEN NULL ELSE q.LOAD_ESS_JOB_ID END AS LOAD_ESS_JOB_ID,
                   CASE WHEN EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                                     WHERE c.PARENT_QUEUE_ID = q.QUEUE_ID)
                        THEN NULL ELSE q.IMPORT_ESS_JOB_ID END AS IMPORT_ESS_JOB_ID,
                   ERROR_MESSAGE, RUN_ID,
                   -- Rolled-up outcome counts for the palette (loaded / failed / unaccounted).
                   (SELECT NVL(SUM(cs.ROW_COUNT),0) FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS TOT_ROWS,
                   (SELECT NVL(SUM(CASE WHEN cs.TFM_STATUS = 'LOADED' THEN cs.ROW_COUNT END),0)
                      FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS LOADED_ROWS,
                   (SELECT NVL(SUM(CASE WHEN cs.TFM_STATUS = 'FAILED' THEN cs.ROW_COUNT END),0)
                      FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS FAILED_ROWS,
                   (SELECT NVL(SUM(cs.UNRECONCILED_COUNT),0) FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS UNACC_ROWS,
                   TO_CHAR(STARTED_AT, 'HH24:MI:SS') STARTED,
                   TO_CHAR(COMPLETED_AT, 'HH24:MI:SS') COMPLETED
            FROM DMT_WORK_QUEUE_TBL q WHERE RUN_ID = p_run_id
            -- Group each partition parent with its children: order by the
            -- coordinating item's slot (a child borrows its parent's SORT_ORDER
            -- via the self-join), render the parent first, then its children by id.
            ORDER BY PIPELINE,
                     NVL((SELECT p.SORT_ORDER FROM DMT_WORK_QUEUE_TBL p
                           WHERE p.QUEUE_ID = q.PARENT_QUEUE_ID), q.SORT_ORDER),
                     NVL(q.PARENT_QUEUE_ID, q.QUEUE_ID),
                     CASE WHEN q.PARENT_QUEUE_ID IS NULL THEN 0 ELSE 1 END,
                     q.QUEUE_ID
        ) LOOP
            IF rec.PIPELINE != l_pp THEN
                IF l_pp != '***' THEN HTP.P('</div>'); END IF;
                HTP.P('<h3 style="margin:20px 0 8px;font-size:14px;color:#555;text-transform:uppercase;letter-spacing:1px">'
                    || rec.PIPELINE || '</h3><div style="display:flex;flex-wrap:wrap;gap:12px">');
                l_pp := rec.PIPELINE;
            END IF;

            l_phase   := phase_from_work(rec.WORK_STATUS);
            l_failerr := GREATEST(NVL(rec.FAILED_ROWS,0) - NVL(rec.UNACC_ROWS,0), 0);
            -- A parent coordinator processed no records of its own; do not colour it by
            -- the object's rolled-up counts (that would double-report the children).
            -- It is a neutral placeholder. Children and normal items keep the palette.
            IF rec.IS_PARENT = 1 THEN
                l_bg := '#eef2f7';   -- neutral slate: a coordinator, not a load
            ELSE
                l_bg := tile_bg(l_phase, rec.TOT_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNACC_ROWS);
            END IF;
              HTP.P('<div style="background:' || l_bg
                  || CASE WHEN rec.IS_PARENT = 1 THEN ';border:1px dashed #9aa7b8' ELSE ';border:1px solid #ddd' END
                  || CASE WHEN rec.IS_CHILD = 1 THEN ';border-left:4px solid #9aa7b8' END
                  || ';border-radius:8px;padding:14px;min-width:200px;max-width:280px;flex:1">');
              HTP.P('<div style="font-weight:bold;font-size:14px;margin-bottom:4px">');
              -- Title. A child tile is annotated with its partition value so it is not
              -- confused with the parent or with a sibling partition.
              IF rec.IS_PARENT = 1 THEN
                  -- Parent placeholder: name + a coordinator badge; NOT a drill link
                  -- (it holds no records of its own).
                  HTP.P('<span style="color:#33475b">' || rec.CEMLI_CODE || '</span>'
                      || ' <span style="font-weight:normal;font-size:10px;background:#9aa7b8;color:#fff;'
                      || 'border-radius:3px;padding:1px 5px;vertical-align:middle">PARTITION PARENT</span>');
              ELSIF NVL(rec.TOT_ROWS,0) = 0 THEN
                  HTP.P('<span style="color:#999">' || rec.CEMLI_CODE || '</span>');
                  IF rec.IS_CHILD = 1 AND rec.PARTITION_LABEL IS NOT NULL THEN
                      HTP.P(' <span style="font-weight:normal;font-size:11px;color:#555">&#9656; '
                          || rec.PARTITION_LABEL || '</span>');
                  END IF;
              ELSE
                  HTP.P('<a href="f?p=' || l_app || ':52:' || l_ses || '::NO::P52_RUN_ID,P52_CEMLI_CODE:'
                      || rec.RUN_ID || ',' || rec.CEMLI_CODE
                      || '" style="color:inherit;text-decoration:none;border-bottom:1px dashed #999">'
                      || rec.CEMLI_CODE || '</a>');
                  IF rec.IS_CHILD = 1 AND rec.PARTITION_LABEL IS NOT NULL THEN
                      HTP.P(' <span style="font-weight:normal;font-size:11px;color:#555">&#9656; '
                          || rec.PARTITION_LABEL || '</span>');
                  END IF;
              END IF;
              HTP.P('</div><div style="font-size:12px;color:#555">');
            IF rec.IS_PARENT = 1 THEN
                -- Parent placeholder line (backlog #70): state what it split on. No
                -- counts, no load/import ids (those live on the children). The partition
                -- COLUMN name(s) come from the structured JSON parser (part_key_names);
                -- the friendly "(split into N partition(s))" text sits in PARTITION_LABEL.
                l_part_keys := part_key_names(rec.OWN_QUEUE_ID);
                HTP.P('<span style="color:#33475b">Coordinator &mdash; '
                    || NVL(rec.PARTITION_LABEL, 'partitioned') || '</span>');
                IF l_part_keys IS NOT NULL THEN
                    HTP.P('<br>Partitioned on: <b>' || l_part_keys || '</b>');
                END IF;
            ELSE
                HTP.P(tile_status(l_phase, rec.TOT_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNACC_ROWS));
                -- Item #74: surface the partition value as a first-class labelled field.
                -- A genuine spawn-per-partition child carries a real partition value --
                -- its PARTITION_KEY is a JSON object, e.g. {"BATCH_ID":"8102"} or
                -- {"BOOK_TYPE_CODE":"US CORP"} (per DMT_WORK_QUEUE_TBL.PARTITION_KEY comment);
                -- the scalar already lives in PARTITION_LABEL. Show it as "Partition: <value>".
                -- The in-zip FBDI split sentinel (PARTITION_KEY 'ALL', label 'All Groups')
                -- and any un-partitioned item keep the lighter inline suffix instead.
                IF rec.PARTITION_KEY IS NOT NULL AND rec.PARTITION_KEY <> 'ALL'
                   AND rec.PARTITION_LABEL IS NOT NULL THEN
                    HTP.P('<br><span style="color:#555">Partition: </span>'
                        || '<strong>' || rec.PARTITION_LABEL || '</strong>');
                ELSIF rec.PARTITION_LABEL IS NOT NULL THEN
                    HTP.P(' &middot; <span style="color:#888">' || rec.PARTITION_LABEL || '</span>');
                END IF;
            END IF;
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
