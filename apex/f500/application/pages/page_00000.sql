prompt --application/pages/page_00000
begin
--   Manifest
--     PAGE: 00000
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
 p_id=>0
,p_name=>'Global Page'
,p_reload_on_submit=>null
,p_warn_on_unsaved_changes=>null
,p_autocomplete_on_off=>'OFF'
,p_inline_css=>wwv_flow_string.join(wwv_flow_t_varchar2(
'',
'/* Filter bar box */',
'.dmt-filter-box {',
'  background: #f4f6f8;',
'  border: 1px solid #d2d6dc;',
'  border-radius: 8px;',
'  padding: 12px 16px 8px 16px;',
'  margin: 0 0 16px 0;',
'  max-width: 480px;',
'}',
'.dmt-filter-box .t-Form-fieldContainer {',
'  margin-bottom: 4px !important;',
'  padding-bottom: 0 !important;',
'}',
'.dmt-filter-box .t-Form-inputContainer {',
'  padding-bottom: 0 !important;',
'}',
'.dmt-filter-box select,',
'.dmt-filter-box input[type="text"] {',
'  height: 32px;',
'  font-size: 13px;',
'}',
'.dmt-filter-box label.t-Form-label {',
'  font-size: 11px;',
'  font-weight: 600;',
'  color: #555;',
'  text-transform: uppercase;',
'  letter-spacing: 0.5px;',
'}',
'.dmt-filter-buttons {',
'  display: flex;',
'  gap: 8px;',
'  margin-top: 8px;',
'  padding-top: 8px;',
'  border-top: 1px solid #e0e3e8;',
'}',
'.dmt-filter-buttons .t-Button {',
'  height: 30px;',
'  line-height: 28px;',
'  padding: 0 16px;',
'  font-size: 12px;',
'}',
''))
,p_protection_level=>'D'
,p_page_component_map=>'14'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118272720)
,p_plug_name=>'Filter Bar'
,p_static_id=>'filter-bar'
,p_region_css_classes=>'dmt-filter-box'
,p_region_template_options=>'#DEFAULT#'
,p_plug_display_sequence=>1
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_display_condition_type=>'CURRENT_PAGE_IN_CONDITION'
,p_plug_display_when_condition=>'1,2,3,4,5,6,7,10,11,12,21,22,23,24,50,51,52,53,54,55,56,57,58'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118272721)
,p_plug_name=>'Filter Buttons'
,p_static_id=>'filter-buttons'
,p_parent_plug_id=>wwv_flow_imp.id(1041441188118272720)
,p_region_css_classes=>'dmt-filter-buttons'
,p_region_template_options=>'#DEFAULT#'
,p_plug_display_sequence=>30
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1041441188118272739)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(1041441188118272721)
,p_button_name=>'APPLY_FILTER'
,p_static_id=>'apply-filter'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#:t-Button--small'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Apply'
,p_button_position=>'TEMPLATE_DEFAULT'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1041441188118272740)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(1041441188118272721)
,p_button_name=>'CLEAR_FILTER'
,p_static_id=>'clear-filter'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#:t-Button--small'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Clear'
,p_button_position=>'TEMPLATE_DEFAULT'
,p_warn_on_unsaved_changes=>null
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118272730)
,p_name=>'P0_PREFIX_INPUT'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(1041441188118272720)
,p_prompt=>'Prefix'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>8
,p_begin_on_new_line=>'N'
,p_colspan=>4
,p_grid_label_column_span=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'Y',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118272729)
,p_name=>'P0_SCENARIO_SELECT'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1041441188118272720)
,p_prompt=>'Scenario'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT scenario_name AS d, scenario_id AS r FROM dmt_scenario_tbl WHERE status = ''ACTIVE'' ORDER BY scenario_name'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'-- All Scenarios --'
,p_cHeight=>1
,p_colspan=>6
,p_grid_label_column_span=>2
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_computation(
 p_id=>wwv_flow_imp.id(1041441188118272760)
,p_computation_sequence=>20
,p_computation_item=>'P0_PREFIX_FILTER'
,p_static_id=>'p0-prefix-filter'
,p_computation_type=>'ITEM_VALUE'
,p_computation=>'P0_PREFIX_INPUT'
);
wwv_flow_imp_page.create_page_computation(
 p_id=>wwv_flow_imp.id(1041441188118272759)
,p_computation_sequence=>10
,p_computation_item=>'P0_SCENARIO_ID'
,p_static_id=>'p0-scenario-id'
,p_computation_type=>'ITEM_VALUE'
,p_computation=>'P0_SCENARIO_SELECT'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1041441188118272749)
,p_name=>'Clear Filter'
,p_static_id=>'clear-filter'
,p_event_sequence=>20
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(1041441188118272740)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1041441188118272750)
,p_event_id=>wwv_flow_imp.id(1041441188118272749)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', 'apex.item("P0_SCENARIO_SELECT").setValue("");apex.item("P0_PREFIX_INPUT").setValue("");apex.page.submit("CLEAR_FILTER");')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1331144005049695910)
,p_name=>'Decorate Status Badges'
,p_static_id=>'decorate-status-badges'
,p_event_sequence=>10
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'ready'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1331144095921695911)
,p_event_id=>wwv_flow_imp.id(1331144005049695910)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', wwv_flow_string.join(wwv_flow_t_varchar2(
    '(function(){var C={CONFIRMED:"u-Badge u-Badge--success",UNRECONCILED:"u-Badge u-Badge--danger",IN_PROGRESS:"u-Badge u-Badge--warning"};function d(s){(s||document).querySelectorAll(".a-IRR-table").forEach(function(t){var h=t.querySelectorAll("thead th'
||'"),si=-1,ri=-1;h.forEach(function(th,i){var l=(th.id||th.getAttribute("data-id")||(th.textContent||"").trim()).toUpperCase();if(ri<0&&l.indexOf("RECONCILIATION_STATUS")>=0)ri=i;else if(si<0&&l.indexOf("STATUS")>=0&&l.indexOf("RECONCILIATION")<0)si=i;'
||'});if(si<0||ri<0)return;t.querySelectorAll("tbody tr").forEach(function(r){if(r.dataset.ba==="1")return;var c=r.children;if(c.length<=Math.max(si,ri))return;var v=(c[ri].textContent||"").trim().toUpperCase(),cls=C[v];if(!cls)return;c[si].innerHTML=''<'
||'span class="''+cls+''">''+(c[si].textContent||"").trim()+''</span>'';r.dataset.ba="1";});});}',
    'if(!document.getElementById("dmt-badge-css")){var s=document.createElement("style");s.id="dmt-badge-css";s.textContent=".u-Badge{display:inline-block;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:600;line-height:1.5}.u-Badge--success{'
||'background:#4CAF50;color:#fff}.u-Badge--danger{background:#F44336;color:#fff}.u-Badge--warning{background:#FFC107;color:#222}";document.head.appendChild(s);}d();if(window.apex&&apex.jQuery)apex.jQuery(document).on("apexafterrefresh",function(e){d(e.t'
||'arget);});})();')))).to_clob
);
wwv_flow_imp.component_end;
end;
/
