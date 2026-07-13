-- PROCEDURE DMT_FBDI_FILE_CHAIN

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_FBDI_FILE_CHAIN" (p_run_id IN NUMBER, p_cemli_code IN VARCHAR2) IS
    CURSOR c_files IS
        SELECT c.FBDI_CSV_ID, c.OBJECT_TYPE AS OBJ, c.FILENAME AS CSVF, c.ROW_COUNT AS RCNT,
               z.FILENAME AS ZIPF, z.ZIP_SIZE_BYTES AS ZSIZ,
               q.LOAD_ESS_JOB_ID AS LEID, q.IMPORT_ESS_JOB_ID AS IEID,
               z.CREATED_DATE AS CD
        FROM DMT_FBDI_CSV_TBL c
        -- KNOWN GAP (fix at APEX port): the multi-CSV objects that go through
        -- DMT_UTIL_PKG.REGISTER_CSV / BUILD_ZIP_FROM_CSVS stamp FBDI_ZIP_ID on the CSV row,
        -- so this join resolves. The ~21 single-CSV generators still insert their CSV row
        -- directly WITHOUT setting FBDI_ZIP_ID, so their ZIP file/size/created columns render
        -- blank here. Page 53 (the only consumer) is deferred, so this does not surface yet.
        -- Logged in the design doc open-items list (P3). Fix = stamp FBDI_ZIP_ID on those inserts.
        LEFT JOIN DMT_FBDI_ZIP_TBL z ON z.FBDI_ZIP_ID = c.FBDI_ZIP_ID
        LEFT JOIN (SELECT DISTINCT RUN_ID, CEMLI_CODE, LOAD_ESS_JOB_ID, IMPORT_ESS_JOB_ID
                   FROM DMT_WORK_QUEUE_TBL) q
            ON q.RUN_ID = c.RUN_ID AND q.CEMLI_CODE = p_cemli_code
        WHERE c.RUN_ID = p_run_id
        AND c.OBJECT_TYPE = p_cemli_code
        ORDER BY c.FBDI_CSV_ID;
    v_f BOOLEAN := FALSE;
    v_u VARCHAR2(500);
    l_app VARCHAR2(10) := V('APP_ID');
    l_ses VARCHAR2(30) := V('APP_SESSION');
BEGIN
    HTP.P('<table class="t-Report-report" style="width:100%"><thead><tr>'
        || '<th>Object Type</th><th>CSV File</th><th>Rows</th><th>ZIP File</th>'
        || '<th>Size</th><th>Load ESS</th><th>Import ESS</th><th>Created</th></tr></thead><tbody>');
    FOR rec IN c_files LOOP
        v_f := TRUE;
        HTP.P('<tr><td>' || HTF.ESCAPE_SC(rec.OBJ) || '</td><td>' || HTF.ESCAPE_SC(rec.CSVF)
            || '</td><td>' || rec.RCNT || '</td><td>' || HTF.ESCAPE_SC(rec.ZIPF)
            || '</td><td>' || rec.ZSIZ || '</td>');
        IF rec.LEID IS NOT NULL THEN
            v_u := 'f?p=' || l_app || ':53:' || l_ses || '::NO::P53_ESS_JOB_ID,P53_INTEGRATION_ID,P53_CEMLI_CODE:'
                || rec.LEID || ',' || p_run_id || ',' || p_cemli_code;
            HTP.P('<td><a href="' || v_u || '">' || rec.LEID || '</a></td>');
        ELSE
            HTP.P('<td style="color:#888">(pending)</td>');
        END IF;
        IF rec.IEID IS NOT NULL THEN
            v_u := 'f?p=' || l_app || ':53:' || l_ses || '::NO::P53_ESS_JOB_ID,P53_INTEGRATION_ID,P53_CEMLI_CODE:'
                || rec.IEID || ',' || p_run_id || ',' || p_cemli_code;
            HTP.P('<td><a href="' || v_u || '">' || rec.IEID || '</a></td>');
        ELSE
            HTP.P('<td style="color:#888">(pending)</td>');
        END IF;
        HTP.P('<td>' || TO_CHAR(rec.CD, 'YYYY-MM-DD HH24:MI') || '</td></tr>');
    END LOOP;
    IF NOT v_f THEN
        HTP.P('<tr><td colspan="8" style="text-align:center;padding:20px">No FBDI files found.</td></tr>');
    END IF;
    HTP.P('</tbody></table>');
END;
/
