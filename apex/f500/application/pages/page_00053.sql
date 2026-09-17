prompt --application/pages/page_00053
begin
--   Manifest
--     PAGE: 00053
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
 p_id=>53
,p_name=>'ESS Job Detail'
,p_alias=>'P53-ESS-JOB-DETAIL'
,p_step_title=>'ESS Job Detail'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'10'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(488878712092960431)
,p_plug_name=>'Breadcrumb'
,p_static_id=>'breadcrumb'
,p_plug_display_sequence=>1
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'BEGIN DMT_OBJECT_DETAIL_BREADCRUMB(:P53_RUN_ID, :P53_CEMLI_CODE); END;'
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(488878712092960432)
,p_plug_name=>'ESS Job Detail'
,p_static_id=>'ess-job-detail'
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  l_root NUMBER := TO_NUMBER(:P53_ESS_JOB_ID);',
'  l_url  VARCHAR2(600);',
'  l_cnt  NUMBER := 0;',
'BEGIN',
'  HTP.P(''<style>.dmt-ess-tbl{width:100%;border-collapse:collapse;font-size:13px;margin-top:8px;}''',
'    ||''.dmt-ess-tbl th{text-align:left;padding:10px;border-bottom:2px solid #0072c6;color:#333;font-weight:600;}''',
'    ||''.dmt-ess-tbl td{padding:9px 10px;border-bottom:1px solid #e6e6e6;}''',
'    ||''.dmt-ess-req a{color:#0072c6;font-weight:600;text-decoration:none;}''',
'    ||''.dmt-ess-req a:hover{text-decoration:underline;}''',
'    ||''.dmt-att-btn{display:inline-block;padding:4px 12px;border-radius:4px;background:#0072c6;color:#fff;text-decoration:none;font-size:12px;}''',
'    ||''.dmt-att-btn:hover{background:#005a9e;}</style>'');',
'  HTP.P(''<h3 style="margin:4px 0 6px;font-size:16px;">ESS Job Tree</h3>'');',
'  HTP.P(''<table class="dmt-ess-tbl"><thead><tr>''',
'    ||''<th>Request ID</th><th>Job</th><th>State</th><th>Start</th><th>End</th><th>Attachments</th>''',
'    ||''</tr></thead><tbody>'');',
'  FOR r IN (',
'    SELECT REQUEST_ID, PARENT_REQUEST_ID, JOB_SHORT_NAME, STATE_TEXT, START_TIME, END_TIME, NVL(DEPTH_LEVEL,0) DEPTH_LEVEL',
'    FROM DMT_ESS_JOB_TBL',
'    WHERE REQUEST_ID = l_root',
'       OR PARENT_REQUEST_ID = l_root',
'       OR PARENT_REQUEST_ID IN (SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL WHERE PARENT_REQUEST_ID = l_root)',
'    ORDER BY DEPTH_LEVEL, REQUEST_ID',
'  ) LOOP',
'    l_cnt := l_cnt + 1;',
'    l_url := APEX_PAGE.GET_URL(p_page => 58, p_items => ''P58_REQUEST_ID'', p_values => TO_CHAR(r.REQUEST_ID));',
'    HTP.P(''<tr><td class="dmt-ess-req" style="padding-left:''||TO_CHAR(10 + r.DEPTH_LEVEL*22)||''px;"><a href="''||l_url||''">''||r.REQUEST_ID||''</a></td>''',
'      ||''<td>''||APEX_ESCAPE.HTML(r.JOB_SHORT_NAME)||''</td>''',
'      ||''<td>''||APEX_ESCAPE.HTML(r.STATE_TEXT)||''</td>''',
'      ||''<td>''||TO_CHAR(r.START_TIME,''HH24:MI:SS'')||''</td>''',
'      ||''<td>''||TO_CHAR(r.END_TIME,''HH24:MI:SS'')||''</td>''',
'      ||''<td><a class="dmt-att-btn" href="''||l_url||''">View attachments</a></td></tr>'');',
'  END LOOP;',
'  IF l_cnt = 0 THEN',
'    HTP.P(''<tr><td colspan="6" style="padding:16px;color:#888;">No ESS jobs found for this request.</td></tr>'');',
'  END IF;',
'  HTP.P(''</tbody></table>'');',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(488878712092960440)
,p_button_sequence=>5
,p_button_plug_id=>wwv_flow_imp.id(488878712092960431)
,p_button_name=>'BACK'
,p_static_id=>'back'
,p_button_action=>'REDIRECT_PAGE'
,p_button_template_options=>'#DEFAULT#'
,p_button_image_alt=>'Back'
,p_button_position=>'PREVIOUS'
,p_button_redirect_url=>'f?p=&APP_ID.:52:&SESSION.::&DEBUG.::P52_RUN_ID,P52_CEMLI_CODE:&P53_RUN_ID.,&P53_CEMLI_CODE.'
,p_icon_css_classes=>'fa-chevron-left'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(488878712092960452)
,p_name=>'P53_CEMLI_CODE'
,p_item_sequence=>30
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(488878712092960450)
,p_name=>'P53_ESS_JOB_ID'
,p_item_sequence=>10
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(488878712092960451)
,p_name=>'P53_RUN_ID'
,p_item_sequence=>20
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp.component_end;
end;
/
