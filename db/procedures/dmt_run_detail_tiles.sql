-- PROCEDURE DMT_RUN_DETAIL_TILES

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_RUN_DETAIL_TILES" (p_run_id IN NUMBER) IS
    l_pp   VARCHAR2(30) := '***';
    l_bg   VARCHAR2(30);
    l_app  VARCHAR2(10) := V('APP_ID');
    l_ses  VARCHAR2(30) := V('APP_SESSION');
    l_has_queue NUMBER;
BEGIN
    -- Check if work queue has rows for this run
    SELECT COUNT(*) INTO l_has_queue
    FROM DMT_WORK_QUEUE_TBL WHERE RUN_ID = p_run_id AND ROWNUM = 1;

    IF l_has_queue > 0 THEN
        -- Async path: render from work queue (original logic)
        FOR rec IN (
            SELECT QUEUE_ID, PIPELINE, CEMLI_CODE, WORK_STATUS, PARTITION_LABEL,
                   -- Grouped/sync CEMLIs (GL, GL Budgets, MiscReceipts, HDL) never write ESS
                   -- ids back to the queue row; fall back to DMT_ESS_JOB_TBL where they are
                   -- captured (Load = depth-0 InterfaceLoaderController, Import = depth-0 launcher).
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
                   -- C6: record count for this object; 0 => grey card, no drill link.
                   -- Keyed on DMT_RECORD_DETAIL_V (what the drill actually shows), so a
                   -- greyed card means "drilling would be empty" by construction.
                   (SELECT COUNT(*) FROM DMT_OWNER.DMT_RECORD_DETAIL_V r
                     WHERE r.RUN_ID = q.RUN_ID AND r.CEMLI_CODE = q.CEMLI_CODE) AS REC_COUNT,
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
            l_bg := CASE rec.WORK_STATUS
                WHEN 'DONE' THEN '#e6f4ea' WHEN 'FAILED' THEN '#fce8e6'
                WHEN 'SKIPPED' THEN '#f0f0f0' WHEN 'PENDING' THEN '#fff' ELSE '#e8f0fe' END;
            IF rec.REC_COUNT = 0 THEN l_bg := '#f0f0f0'; END IF;  -- C6: grey empty (0-record) objects
            HTP.P('<div style="background:' || l_bg || ';border:1px solid #ddd;border-radius:8px;padding:14px;min-width:200px;max-width:280px;flex:1">');
            HTP.P('<div style="font-weight:bold;font-size:14px;margin-bottom:4px">');
            IF rec.REC_COUNT = 0 THEN
                -- C6: no records -> muted label, no drill link (drill would be empty)
                HTP.P('<span style="color:#999">' || rec.CEMLI_CODE || '</span>');
            ELSE
                HTP.P('<a href="f?p=' || l_app || ':52:' || l_ses || '::NO::P52_INTEGRATION_ID,P52_CEMLI_CODE:'
                    || rec.RUN_ID || ',' || rec.CEMLI_CODE
                    || '" style="color:inherit;text-decoration:none;border-bottom:1px dashed #999">'
                    || rec.CEMLI_CODE || '</a>');
            END IF;
            HTP.P('</div><div style="font-size:12px;color:#555">');
            CASE rec.WORK_STATUS
                WHEN 'DONE' THEN HTP.P('<span style="color:#1a9c3e">&#10003; Done</span>');
                WHEN 'FAILED' THEN HTP.P('<span style="color:#c42b1c">&#10007; Failed</span>');
                WHEN 'SKIPPED' THEN HTP.P('<span style="color:#888">Skipped</span>');
                WHEN 'PENDING' THEN HTP.P('<span style="color:#888">Pending</span>');
                ELSE HTP.P('<span style="color:#0070d2">' || rec.WORK_STATUS || '</span>');
            END CASE;
            IF rec.PARTITION_LABEL IS NOT NULL THEN HTP.P(' &middot; ' || rec.PARTITION_LABEL); END IF;
            IF rec.STARTED IS NOT NULL THEN
                HTP.P('<br>' || rec.STARTED || CASE WHEN rec.COMPLETED IS NOT NULL THEN ' &rarr; ' || rec.COMPLETED END);
            END IF;
            IF rec.LOAD_ESS_JOB_ID IS NOT NULL THEN
                HTP.P('<br>Load: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_INTEGRATION_ID,P53_CEMLI_CODE:'
                    || rec.LOAD_ESS_JOB_ID || ',' || rec.RUN_ID || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.LOAD_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.IMPORT_ESS_JOB_ID IS NOT NULL THEN
                HTP.P(' &middot; Import: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_INTEGRATION_ID,P53_CEMLI_CODE:'
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
                   v.CARD_SUMMARY,
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

            l_bg := CASE rec.OBJECT_STATUS
                WHEN 'COMPLETED'        THEN '#e6f4ea'
                WHEN 'COMPLETED_ERRORS' THEN '#fff3e0'
                WHEN 'FAILED'           THEN '#fce8e6'
                WHEN 'SKIPPED'          THEN '#f0f0f0'
                WHEN 'IN_PROGRESS'      THEN '#e8f0fe'
                ELSE '#f0f0f0'
            END;
            IF NVL(rec.TOTAL_ROWS, 0) = 0 THEN l_bg := '#f0f0f0'; END IF;  -- C6: grey empty objects

            HTP.P('<div style="background:' || l_bg || ';border:1px solid #ddd;border-radius:8px;padding:14px;min-width:200px;max-width:280px;flex:1">');
            HTP.P('<div style="font-weight:bold;font-size:14px;margin-bottom:4px">');
            IF NVL(rec.TOTAL_ROWS, 0) = 0 THEN
                -- C6: no records -> muted label, no drill link
                HTP.P('<span style="color:#999">' || rec.CEMLI_CODE || '</span>');
            ELSE
                HTP.P('<a href="f?p=' || l_app || ':52:' || l_ses || '::NO::P52_INTEGRATION_ID,P52_CEMLI_CODE:'
                    || p_run_id || ',' || rec.CEMLI_CODE
                    || '" style="color:inherit;text-decoration:none;border-bottom:1px dashed #999">'
                    || rec.CEMLI_CODE || '</a>');
            END IF;
            HTP.P('</div><div style="font-size:12px;color:#555">');

            CASE rec.OBJECT_STATUS
                WHEN 'COMPLETED'        THEN HTP.P('<span style="color:#1a9c3e">&#10003; ' || rec.LOADED_ROWS || ' loaded</span>');
                WHEN 'COMPLETED_ERRORS' THEN HTP.P('<span style="color:#e65100">' || rec.LOADED_ROWS || ' loaded, ' || rec.FAILED_ROWS || ' failed</span>');
                WHEN 'FAILED'           THEN HTP.P('<span style="color:#c42b1c">&#10007; ' || rec.FAILED_ROWS || ' failed</span>');
                WHEN 'SKIPPED'          THEN HTP.P('<span style="color:#888">No rows</span>');
                WHEN 'IN_PROGRESS'      THEN HTP.P('<span style="color:#0070d2">In progress</span>');
                ELSE HTP.P('<span style="color:#888">' || rec.CARD_SUMMARY || '</span>');
            END CASE;

            IF rec.LOAD_ESS_JOB_ID IS NOT NULL THEN
                HTP.P('<br>Load: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_INTEGRATION_ID,P53_CEMLI_CODE:'
                    || rec.LOAD_ESS_JOB_ID || ',' || p_run_id || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.LOAD_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.IMPORT_ESS_JOB_ID IS NOT NULL THEN
                HTP.P(' &middot; Import: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_INTEGRATION_ID,P53_CEMLI_CODE:'
                    || rec.IMPORT_ESS_JOB_ID || ',' || p_run_id || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.IMPORT_ESS_JOB_ID || '</a>');
            END IF;

            HTP.P('</div></div>');
        END LOOP;
        IF l_pp != '***' THEN HTP.P('</div>'); END IF;
    END IF;
END;
/
