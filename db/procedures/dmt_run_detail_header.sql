-- PROCEDURE DMT_RUN_DETAIL_HEADER

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_RUN_DETAIL_HEADER" (p_run_id IN NUMBER) IS
    l_rec DMT_PIPELINE_RUN_TBL%ROWTYPE;
    l_d NUMBER; l_t NUMBER; l_f NUMBER; l_sc VARCHAR2(100);
BEGIN
    SELECT * INTO l_rec FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
    SELECT COUNT(*), SUM(CASE WHEN WORK_STATUS='DONE' THEN 1 ELSE 0 END),
           SUM(CASE WHEN WORK_STATUS='FAILED' THEN 1 ELSE 0 END)
    INTO l_t, l_d, l_f FROM DMT_WORK_QUEUE_TBL WHERE RUN_ID = p_run_id;
    l_sc := CASE l_rec.RUN_STATUS
        WHEN 'COMPLETED' THEN 'color:#1a9c3e' WHEN 'COMPLETED_ERRORS' THEN 'color:#e07600'
        WHEN 'FAILED' THEN 'color:#c42b1c' WHEN 'IN_PROGRESS' THEN 'color:#0070d2'
        WHEN 'QUEUED' THEN 'color:#6b48c9' ELSE 'color:#333' END;
    HTP.P('<div style="display:flex;gap:24px;flex-wrap:wrap;align-items:center;padding:8px 0">');
    HTP.P('<span style="font-size:20px;font-weight:bold">Run #' || l_rec.RUN_ID || '</span>');
    HTP.P('<span style="' || l_sc || ';font-weight:bold;font-size:16px">' || l_rec.RUN_STATUS || '</span>');
    HTP.P('<span>' || l_rec.PIPELINE_CODES || '</span> <span>Prefix: ' || l_rec.PREFIX || '</span>');
    HTP.P('<span>' || NVL(l_rec.SCENARIO_NAME, 'All rows') || '</span> <span>' || l_rec.RUN_MODE || '</span>');
    HTP.P('<span>' || l_d || '/' || l_t || CASE WHEN l_f > 0 THEN ' (' || l_f || ' failed)' END || '</span>');
    HTP.P('<a href="' || APEX_PAGE.GET_URL(p_page=>54, p_items=>'P54_INTEGRATION_ID', p_values=>TO_CHAR(p_run_id))
        || '" style="color:#0070d2;text-decoration:none;font-weight:600">View Activity Log &rarr;</a></div>');
EXCEPTION WHEN NO_DATA_FOUND THEN HTP.P('<p>Run not found.</p>');
END;
/
