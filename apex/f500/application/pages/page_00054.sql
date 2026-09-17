prompt --application/pages/page_00054
begin
--   Manifest
--     PAGE: 00054
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
 p_id=>54
,p_name=>'Activity Log'
,p_alias=>'ACTIVITY-LOG'
,p_step_title=>'Activity Log'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1538429647822084567)
,p_plug_name=>'Breadcrumb'
,p_static_id=>'breadcrumb'
,p_region_name=>'breadcrumb_54'
,p_plug_display_sequence=>1
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  v_int_id NUMBER := NVL(:P54_RUN_ID, 0);',
'  v_log_id NUMBER := NVL(:P54_LOG_ID, 0);',
'  v_cemli  VARCHAR2(200);',
'BEGIN',
'  BEGIN',
'    SELECT ORCHESTRATION_CODE INTO v_cemli',
'      FROM DMT_CONVERSION_MASTER_TBL',
'     WHERE INTEGRATION_ID = v_int_id',
'       AND ROWNUM = 1;',
'  EXCEPTION WHEN OTHERS THEN v_cemli := ''Unknown'';',
'  END;',
'  htp.p(''<nav style="font-size:13px;padding:4px 0 12px 0;color:#888;">'');',
'  htp.p(''<a href="'' || APEX_PAGE.GET_URL(p_page => 50) || ''" class="dmt-link">Pipeline Summary</a>'');',
'  htp.p('' &rsaquo; '');',
'  htp.p(''<a href="'' || APEX_PAGE.GET_URL(p_page => 51, p_items => ''P51_CEMLI_CODE'', p_values => v_cemli) || ''" class="dmt-link">'' || HTF.ESCAPE_SC(v_cemli) || ''</a>'');',
'  htp.p('' &rsaquo; '');',
'  htp.p(''<a href="'' || APEX_PAGE.GET_URL(p_page => 52, p_items => ''P52_RUN_ID'', p_values => TO_CHAR(v_int_id)) || ''" class="dmt-link">Run #'' || v_int_id || ''</a>'');',
'  htp.p('' &rsaquo; '');',
'  htp.p(''<span style="color:#ccc;">Log #'' || v_log_id || ''</span>'');',
'  htp.p(''</nav>'');',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
,p_plug_query_options=>'DERIVED_REPORT_COLUMNS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1574026493436703610)
,p_plug_name=>'Breadcrumb'
,p_static_id=>'breadcrumb-2'
,p_region_template_options=>'#DEFAULT#:t-BreadcrumbRegion--useBreadcrumbTitle'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>2531463326621247859
,p_plug_display_sequence=>10
,p_plug_display_point=>'REGION_POSITION_01'
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_menu_id=>wwv_flow_imp.id(1580210497427795502)
,p_plug_source_type=>'NATIVE_BREADCRUMB'
,p_menu_template_id=>4072363345357175094
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1538429647822084565)
,p_plug_name=>'Log Entry Detail'
,p_static_id=>'log-entry-detail'
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'DECLARE v_log_id NUMBER; v_log_date DATE; v_log_type VARCHAR2(50); v_pkg VARCHAR2(200); v_proc VARCHAR2(200); v_msg CLOB; v_err VARCHAR2(4000); v_int_id NUMBER; BEGIN v_log_id := :P54_LOG_ID; IF v_log_id IS NULL THEN htp.p(''<p>No log entry selected.<'
||'/p>''); RETURN; END IF; SELECT LOG_DATE, LOG_TYPE, PACKAGE_NAME, PROCEDURE_NAME, MESSAGE, SQLERRM_TEXT, INTEGRATION_ID INTO v_log_date, v_log_type, v_pkg, v_proc, v_msg, v_err, v_int_id FROM DMT_LOG_TBL WHERE LOG_ID = v_log_id; htp.p(''<div style="marg'
||'in:10px 0">''); htp.p(''<table class="t-Report-report" style="width:auto"><tbody>''); htp.p(''<tr><td style="font-weight:bold;padding:4px 12px">Log ID</td><td style="padding:4px 12px">'' || v_log_id || ''</td></tr>''); htp.p(''<tr><td style="font-weight:bold'
||';padding:4px 12px">Integration ID</td><td style="padding:4px 12px">'' || v_int_id || ''</td></tr>''); htp.p(''<tr><td style="font-weight:bold;padding:4px 12px">Date</td><td style="padding:4px 12px">'' || TO_CHAR(v_log_date,''YYYY-MM-DD HH24:MI:SS'') || ''</t'
||'d></tr>''); htp.p(''<tr><td style="font-weight:bold;padding:4px 12px">Type</td><td style="padding:4px 12px">'' || v_log_type || ''</td></tr>''); htp.p(''<tr><td style="font-weight:bold;padding:4px 12px">Package</td><td style="padding:4px 12px">'' || v_pkg |'
||'| ''</td></tr>''); htp.p(''<tr><td style="font-weight:bold;padding:4px 12px">Procedure</td><td style="padding:4px 12px">'' || v_proc || ''</td></tr>''); IF v_err IS NOT NULL THEN htp.p(''<tr><td style="font-weight:bold;padding:4px 12px;color:red">SQLERRM</t'
||'d><td style="padding:4px 12px;color:red">'' || HTF.ESCAPE_SC(v_err) || ''</td></tr>''); END IF; htp.p(''</tbody></table></div>''); htp.p(''<h3 style="margin:16px 0 8px">Full Message</h3>''); htp.p(''<pre style="background:#1e1e1e;color:#d4d4d4;padding:12px;b'
||'order-radius:6px;overflow-x:auto;white-space:pre-wrap;word-wrap:break-word;max-height:600px;overflow-y:auto">'' || HTF.ESCAPE_SC(v_msg) || ''</pre>''); EXCEPTION WHEN NO_DATA_FOUND THEN htp.p(''<p>Log entry '' || v_log_id || '' not found.</p>''); END;'
,p_plug_source_type=>'NATIVE_PLSQL'
,p_plug_query_options=>'DERIVED_REPORT_COLUMNS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1538429647822084566)
,p_plug_name=>'Log Navigation'
,p_static_id=>'log-navigation'
,p_region_name=>'log_navigation'
,p_plug_display_sequence=>5
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  v_log_id  NUMBER := NVL(:P54_LOG_ID, 0);',
'  v_int_id  NUMBER := NVL(:P54_RUN_ID, 0);',
'  v_prev_id NUMBER;',
'  v_next_id NUMBER;',
'  v_app_id  VARCHAR2(20) := V(''APP_ID'');',
'  v_session VARCHAR2(40) := V(''APP_SESSION'');',
'BEGIN',
'  -- Find previous log entry (lower LOG_ID, same integration)',
'  BEGIN',
'    SELECT MAX(LOG_ID) INTO v_prev_id',
'      FROM DMT_LOG_TBL',
'     WHERE INTEGRATION_ID = v_int_id',
'       AND LOG_ID < v_log_id;',
'  EXCEPTION WHEN OTHERS THEN v_prev_id := NULL;',
'  END;',
'',
'  -- Find next log entry (higher LOG_ID, same integration)',
'  BEGIN',
'    SELECT MIN(LOG_ID) INTO v_next_id',
'      FROM DMT_LOG_TBL',
'     WHERE INTEGRATION_ID = v_int_id',
'       AND LOG_ID > v_log_id;',
'  EXCEPTION WHEN OTHERS THEN v_next_id := NULL;',
'  END;',
'',
'  htp.p(''<div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;margin-bottom:12px;">'');',
'',
'  -- Prev button',
'  IF v_prev_id IS NOT NULL THEN',
'    htp.p(''<a href="'' || APEX_PAGE.GET_URL(p_page => 54, p_items => ''P54_LOG_ID,P54_RUN_ID'', p_values => v_prev_id || '','' || v_int_id) || ''" class="dmt-link" style="padding:8px 16px;border:1px solid #555;border-radius:4px;text-decoration:none;">&larr'
||'; Previous Entry (#'' || v_prev_id || '')</a>'');',
'  ELSE',
'    htp.p(''<span style="padding:8px 16px;border:1px solid #333;border-radius:4px;color:#666;">&larr; No Previous</span>'');',
'  END IF;',
'',
'  -- Current indicator',
'  htp.p(''<span style="color:#aaa;">Log Entry #'' || v_log_id || ''</span>'');',
'',
'  -- Next button',
'  IF v_next_id IS NOT NULL THEN',
'    htp.p(''<a href="'' || APEX_PAGE.GET_URL(p_page => 54, p_items => ''P54_LOG_ID,P54_RUN_ID'', p_values => v_next_id || '','' || v_int_id) || ''" class="dmt-link" style="padding:8px 16px;border:1px solid #555;border-radius:4px;text-decoration:none;">Next '
||'Entry (#'' || v_next_id || '') &rarr;</a>'');',
'  ELSE',
'    htp.p(''<span style="padding:8px 16px;border:1px solid #333;border-radius:4px;color:#666;">No Next &rarr;</span>'');',
'  END IF;',
'',
'  htp.p(''</div>'');',
'',
'  -- Back to Run Detail link',
'  htp.p(''<div style="margin-bottom:12px;">'');',
'  htp.p(''<a href="'' || APEX_PAGE.GET_URL(p_page => 53, p_items => ''P53_RUN_ID'', p_values => TO_CHAR(v_int_id)) || ''" class="dmt-link" style="font-size:13px;">&laquo; Back to Run Detail</a>'');',
'  htp.p(''</div>'');',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
,p_plug_query_options=>'DERIVED_REPORT_COLUMNS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1565963090722488343)
,p_plug_name=>'Run Log Entries'
,p_static_id=>'run-log-entries'
,p_region_template_options=>'#DEFAULT#:is-expanded:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>25
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT l.LOG_ID,',
'       TO_CHAR(l.LOG_DATE, ''MM/DD HH24:MI:SS'') AS LOG_TIME,',
'       l.LOG_TYPE,',
'       l.PACKAGE_NAME,',
'       l.PROCEDURE_NAME,',
'       SUBSTR(l.MESSAGE, 1, 300) AS MESSAGE,',
'       l.SQLERRM_TEXT AS ERROR',
'FROM DMT_LOG_TBL l',
'WHERE (:P54_RUN_ID IS NULL OR l.INTEGRATION_ID = :P54_RUN_ID)',
'  AND (:P54_CEMLI_CODE IS NULL OR l.QUEUE_ID IN (',
'         SELECT q.QUEUE_ID FROM DMT_WORK_QUEUE_TBL q',
'         WHERE q.RUN_ID = :P54_RUN_ID AND q.CEMLI_CODE = :P54_CEMLI_CODE))',
'ORDER BY l.LOG_DATE DESC'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P54_RUN_ID,P54_CEMLI_CODE'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1565963090722488344)
,p_max_row_count=>'500'
,p_no_data_found_message=>'No log entries for this run.'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99540511
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1565963090722488359)
,p_db_column_name=>'ERROR'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Error'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1565963090722488353)
,p_db_column_name=>'LOG_ID'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Log ID'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1565963090722488354)
,p_db_column_name=>'LOG_TIME'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Time'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1565963090722488355)
,p_db_column_name=>'LOG_TYPE'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Type'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1565963090722488358)
,p_db_column_name=>'MESSAGE'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Message'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1565963090722488356)
,p_db_column_name=>'PACKAGE_NAME'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Package'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1565963090722488357)
,p_db_column_name=>'PROCEDURE_NAME'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Procedure'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1565963090722488363)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'RUNLOG123'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'LOG_ID:LOG_TIME:LOG_TYPE:PACKAGE_NAME:PROCEDURE_NAME:MESSAGE:ERROR'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1565963090722489198)
,p_name=>'P54_CEMLI_CODE'
,p_item_sequence=>30
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1565963090722488289)
,p_name=>'P54_LOG_ID'
,p_item_sequence=>20
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1565963090722488333)
,p_name=>'P54_RUN_ID'
,p_item_sequence=>25
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp.component_end;
end;
/
