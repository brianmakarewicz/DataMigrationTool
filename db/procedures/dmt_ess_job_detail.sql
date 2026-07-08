-- PROCEDURE DMT_ESS_JOB_DETAIL

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_ESS_JOB_DETAIL" (p_ess_job_id IN VARCHAR2, p_run_id IN NUMBER, p_cemli_code IN VARCHAR2) IS
    l_app VARCHAR2(10) := V('APP_ID');
    l_ses VARCHAR2(30) := V('APP_SESSION');
    v_cnt PLS_INTEGER := 0;
BEGIN
    HTP.P('<h3 style="margin:0 0 12px">ESS Job Tree</h3>');
    HTP.P('<table class="t-Report-report" style="width:100%"><thead><tr>');
    HTP.P('<th>Request ID</th><th>Parent</th><th>Job</th><th>State</th><th>Submit</th><th>Start</th><th>End</th></tr></thead><tbody>');

    FOR rec IN (
        SELECT REQUEST_ID, PARENT_REQUEST_ID, JOB_SHORT_NAME, STATE,
               TO_CHAR(SUBMIT_TIME, 'HH24:MI:SS') AS SUB_T,
               TO_CHAR(START_TIME, 'HH24:MI:SS') AS START_T,
               TO_CHAR(END_TIME, 'HH24:MI:SS') AS END_T
        FROM DMT_ESS_JOB_TBL
        WHERE RUN_ID = p_run_id
        AND (REQUEST_ID = TO_NUMBER(p_ess_job_id) OR PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id)
             OR PARENT_REQUEST_ID IN (SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL WHERE PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id) AND RUN_ID = p_run_id))
        ORDER BY REQUEST_ID
    ) LOOP
        v_cnt := v_cnt + 1;
        HTP.P('<tr>');
        HTP.P('<td>' || rec.REQUEST_ID || '</td>');
        HTP.P('<td>' || NVL(TO_CHAR(rec.PARENT_REQUEST_ID), '-') || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(rec.JOB_SHORT_NAME) || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(rec.STATE) || '</td>');
        HTP.P('<td>' || rec.SUB_T || '</td>');
        HTP.P('<td>' || rec.START_T || '</td>');
        HTP.P('<td>' || rec.END_T || '</td>');
        HTP.P('</tr>');
    END LOOP;

    IF v_cnt = 0 THEN
        HTP.P('<tr><td colspan="7" style="text-align:center;padding:16px;color:#888">No ESS job records found.</td></tr>');
    END IF;
    HTP.P('</tbody></table>');

    -- ESS Job Files
    HTP.P('<h3 style="margin:20px 0 12px">ESS Job Files</h3>');
    v_cnt := 0;
    HTP.P('<table class="t-Report-report" style="width:100%"><thead><tr>');
    HTP.P('<th>Request ID</th><th>File Name</th><th>Type</th><th>Download</th></tr></thead><tbody>');

    FOR frec IN (
        SELECT f.ESS_FILE_ID, f.REQUEST_ID, f.FILE_NAME, f.CONTENT_TYPE
        FROM DMT_ESS_JOB_FILE_TBL f
        WHERE f.REQUEST_ID IN (
            SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL
            WHERE RUN_ID = p_run_id
            AND (REQUEST_ID = TO_NUMBER(p_ess_job_id) OR PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id)
                 OR PARENT_REQUEST_ID IN (SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL WHERE PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id) AND RUN_ID = p_run_id))
        )
        ORDER BY f.REQUEST_ID, f.FILE_NAME
    ) LOOP
        v_cnt := v_cnt + 1;
        HTP.P('<tr>');
        HTP.P('<td>' || frec.REQUEST_ID || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(frec.FILE_NAME) || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(frec.CONTENT_TYPE) || '</td>');
        HTP.P('<td><a href="f?p=' || l_app || ':58:' || l_ses || '::NO::P58_REQUEST_ID:' || frec.REQUEST_ID || '">View</a></td>');
        HTP.P('</tr>');
    END LOOP;

    IF v_cnt = 0 THEN
        HTP.P('<tr><td colspan="4" style="text-align:center;padding:16px;color:#888">No files captured.</td></tr>');
    END IF;
    HTP.P('</tbody></table>');
END;
/
