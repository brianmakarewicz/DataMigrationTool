prompt --application/pages/page_00058
begin
--   Manifest
--     PAGE: 00058
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>32599344892582845
,p_default_application_id=>500
,p_default_id_offset=>32805213799451421
,p_default_owner=>'DMT2_OWNER'
);
wwv_flow_imp_page.create_page(
 p_id=>58
,p_name=>'ESS Job Output'
,p_alias=>'ESS-JOB-OUTPUT'
,p_step_title=>'ESS Job Output'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'10'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1524987452357892857)
,p_plug_name=>'ESS Output'
,p_static_id=>'ess-output'
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  l_req  NUMBER := :P58_REQUEST_ID;',
'  l_cnt  NUMBER := 0;',
'BEGIN',
'  IF l_req IS NULL THEN',
'    HTP.P(''<div style="padding:24px;color:#888;">No Request ID specified.</div>'');',
'    RETURN;',
'  END IF;',
'  FOR rec IN (SELECT JOB_SHORT_NAME, STATE_TEXT, DURATION_SECS',
'              FROM DMT_ESS_JOB_DETAIL_V',
'              WHERE REQUEST_ID = l_req AND ROWNUM = 1) LOOP',
'    HTP.P(''<h3 style="font-size:15px;font-weight:600;margin:0 0 12px;">ESS Job '' || l_req || ''</h3>'');',
'    HTP.P(''<div style="display:flex;gap:24px;padding:8px 0;border-bottom:1px solid #e0e0e0;margin-bottom:12px;">'');',
'    HTP.P(''<div><span style="color:#888;font-size:11px;text-transform:uppercase;">Job Name</span><br><strong>'' || APEX_ESCAPE.HTML(rec.JOB_SHORT_NAME) || ''</strong></div>'');',
'    HTP.P(''<div><span style="color:#888;font-size:11px;text-transform:uppercase;">State</span><br><strong>'' || APEX_ESCAPE.HTML(rec.STATE_TEXT) || ''</strong></div>'');',
'    HTP.P(''<div><span style="color:#888;font-size:11px;text-transform:uppercase;">Duration</span><br><strong>'' || NVL(TO_CHAR(rec.DURATION_SECS),''-'') || ''s</strong></div>'');',
'    HTP.P(''</div>'');',
'  END LOOP;',
'  HTP.P(''<h4 style="font-size:13px;font-weight:600;margin:16px 0 8px;">Output Files</h4>'');',
'  HTP.P(''<div id="essFileList">'');',
'  FOR f IN (SELECT REQUEST_ID, FILE_TYPE, FILE_NAME',
'            FROM DMT_ESS_JOB_FILE_TBL',
'            WHERE REQUEST_ID = l_req ORDER BY FILE_NAME) LOOP',
'    l_cnt := l_cnt + 1;',
'    HTP.P(''<div style="display:flex;align-items:center;gap:12px;padding:8px;border:1px solid #e0e0e0;border-radius:4px;margin-bottom:6px;">'');',
'    HTP.P(''<span style="flex:1;font-size:13px;">'' || APEX_ESCAPE.HTML(f.FILE_NAME) || ''</span>'');',
'    HTP.P(''<span style="color:#888;font-size:11px;">'' || NVL(APEX_ESCAPE.HTML(f.FILE_TYPE),''-'') || ''</span>'');',
'    HTP.P(q''[<button onclick="downloadEssFile(]'' || f.REQUEST_ID || q''[,'']'' || APEX_ESCAPE.HTML(f.FILE_NAME) || q''['',this)" style="background:#0072c6;color:#fff;border:none;padding:5px 14px;border-radius:3px;cursor:pointer;font-size:12px;">Download</'
||'button>]'');',
'    HTP.P(''</div>'');',
'  END LOOP;',
'  IF l_cnt = 0 THEN',
'    HTP.P(q''[<div style="padding:12px;color:#888;font-size:13px;">No files cached yet. <button onclick="enumerateFiles(]'' || l_req || q''[)" style="background:#555;color:#fff;border:none;padding:5px 14px;border-radius:3px;cursor:pointer;font-size:12px'
||';">Fetch File List from Fusion</button></div>]'');',
'  END IF;',
'  HTP.P(''</div>'');',
'  HTP.P(''<script>'');',
'  HTP.P(''function downloadEssFile(reqId, fileName, btn) {'');',
'  HTP.P(''  var orig = btn ? btn.textContent : null; if (btn){btn.disabled=true;btn.textContent="Downloading...";}'');',
'  HTP.P(''  var i = window.location.pathname.indexOf("/ords/");'');',
'  HTP.P(''  var ords = window.location.origin + (i>=0 ? window.location.pathname.substring(0,i+6) : "/ords/");'');',
'  HTP.P(''  var u = ords + "wwv_flow.show?p_request=APPLICATION_PROCESS%3DDOWNLOAD_ESS_FILE_V2"'');',
'  HTP.P(''        + "&p_flow_id=" + $v("pFlowId") + "&p_flow_step_id=0"'');',
'  HTP.P(''        + "&p_instance=" + $v("pInstance")'');',
'  HTP.P(''        + "&x01=" + encodeURIComponent(reqId) + "&x02=" + encodeURIComponent(fileName);'');',
'  HTP.P(''  window.open(u, "_blank");'');',
'  HTP.P(''  if(btn){setTimeout(function(){btn.disabled=false;btn.textContent=orig;},1500);}'');',
'  HTP.P(''}'');',
'  HTP.P(''function enumerateFiles(reqId) {'');',
'  HTP.P(''  var btn = event.target; btn.disabled = true; btn.textContent = "Fetching...";'');',
'  HTP.P(''  apex.server.process("DOWNLOAD_ESS_FILE", {x01: String(reqId), x03: "ENUMERATE"}, {'');',
'  HTP.P(''    success: function(data) { if (data && data.error) { alert("Error: " + data.error); btn.disabled=false; btn.textContent="Fetch File List from Fusion"; return; } location.reload(); },'');',
'  HTP.P(''    error: function(x,t,e) { alert("Request failed: " + t); btn.disabled=false; btn.textContent="Fetch File List from Fusion"; }'');',
'  HTP.P(''  });'');',
'  HTP.P(''}'');',
'  HTP.P(''</script>'');',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1524987452357892856)
,p_plug_name=>'Parameters'
,p_static_id=>'parameters'
,p_region_template_options=>'#DEFAULT#'
,p_plug_display_sequence=>1
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'output_as', 'TEXT',
  'show_line_breaks', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1524987452357893856)
,p_name=>'P58_REQUEST_ID'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1524987452357892856)
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1452808722224643742)
,p_process_sequence=>10
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'DOWNLOAD_ESS_FILE_V2'
,p_static_id=>'download-ess-file-v'
,p_process_sql_clob=>'DECLARE l_request_id NUMBER := TO_NUMBER(apex_application.g_x01); l_file_name VARCHAR2(500) := apex_application.g_x02; l_action VARCHAR2(20) := NVL(apex_application.g_x03, ''DOWNLOAD''); BEGIN IF l_action = ''LIST'' THEN APEX_JSON.open_object; APEX_JSON.'
||'open_array(''files''); FOR f IN ( SELECT ESS_FILE_ID, REQUEST_ID, FILE_TYPE, FILE_NAME, CONTENT_TYPE FROM DMT_ESS_JOB_FILE_TBL WHERE REQUEST_ID = l_request_id ORDER BY FILE_NAME ) LOOP APEX_JSON.open_object; APEX_JSON.write(''file_id'', f.ESS_FILE_ID); A'
||'PEX_JSON.write(''request_id'', f.REQUEST_ID); APEX_JSON.write(''file_type'', f.FILE_TYPE); APEX_JSON.write(''file_name'', f.FILE_NAME); APEX_JSON.write(''content_type'', f.CONTENT_TYPE); APEX_JSON.close_object; END LOOP; APEX_JSON.close_array; APEX_JSON.clos'
||'e_object; ELSIF l_action = ''ENUMERATE'' THEN DMT_ESS_UTIL_PKG.ENUMERATE_ESS_FILES( p_ess_job_id => NULL, p_request_id => l_request_id ); APEX_JSON.open_object; APEX_JSON.write(''status'', ''OK''); APEX_JSON.close_object; ELSE DMT_ESS_UTIL_PKG.DOWNLOAD_ESS'
||'_FILE_V2_TO_BROWSER( p_request_id => l_request_id, p_file_name => l_file_name ); END IF; EXCEPTION WHEN OTHERS THEN APEX_JSON.open_object; APEX_JSON.write(''error'', SQLERRM); APEX_JSON.close_object; END;'
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>999000058001
);
wwv_flow_imp.component_end;
end;
/
