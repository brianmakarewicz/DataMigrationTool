prompt --application/shared_components/logic/application_processes/download_ess_file
begin
--   Manifest
--     APPLICATION PROCESS: DOWNLOAD_ESS_FILE
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>32599344892582845
,p_default_application_id=>500
,p_default_id_offset=>32805213799451421
,p_default_owner=>'DMT2_OWNER'
);
wwv_flow_imp_shared.create_flow_process(
 p_id=>wwv_flow_imp.id(930656992615500834)
,p_process_sequence=>10
,p_process_point=>'ON_DEMAND'
,p_process_name=>'DOWNLOAD_ESS_FILE'
,p_static_id=>'download-ess-file'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  l_req_id    NUMBER := TO_NUMBER(APEX_APPLICATION.G_X01);',
'  l_file_name VARCHAR2(200) := APEX_APPLICATION.G_X02;',
'  l_action    VARCHAR2(50) := APEX_APPLICATION.G_X03;',
'  l_username  VARCHAR2(200);',
'  l_password  VARCHAR2(200);',
'BEGIN',
'  IF l_action = ''ENUMERATE'' THEN',
'    DMT_ESS_UTIL_PKG.ENUMERATE_ESS_FILES(',
'      p_ess_job_id => NULL,',
'      p_request_id => l_req_id',
'    );',
'    APEX_JSON.OPEN_OBJECT;',
'    APEX_JSON.WRITE(''status'', ''OK'');',
'    APEX_JSON.CLOSE_OBJECT;',
'    RETURN;',
'  END IF;',
'  DMT_UTIL_PKG.GET_CREDENTIALS_FOR_REQUEST(',
'    p_request_id => l_req_id,',
'    x_username   => l_username,',
'    x_password   => l_password',
'  );',
'  DMT_ESS_UTIL_PKG.DOWNLOAD_ESS_FILE_TO_BROWSER(',
'    p_request_id => l_req_id,',
'    p_file_name  => l_file_name,',
'    p_username   => l_username,',
'    p_password   => l_password',
'  );',
'EXCEPTION',
'  WHEN OTHERS THEN',
'    IF SQLCODE = -20876 THEN RAISE; END IF;',
'    APEX_JSON.OPEN_OBJECT;',
'    APEX_JSON.WRITE(''error'', SQLERRM);',
'    APEX_JSON.CLOSE_OBJECT;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_version_scn=>'46966384756261'
);
wwv_flow_imp.component_end;
end;
/
