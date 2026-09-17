prompt --application/pages/page_00014
begin
--   Manifest
--     PAGE: 00014
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
 p_id=>14
,p_name=>'Scenario Management'
,p_alias=>'SCENARIO-MANAGEMENT'
,p_step_title=>'Scenario Management'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1561239619186709402)
,p_plug_name=>'Breadcrumb'
,p_static_id=>'breadcrumb'
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
 p_id=>wwv_flow_imp.id(1560810491073787095)
,p_plug_name=>'Scenario Form'
,p_static_id=>'scenario-form'
,p_region_name=>'scenario_form_dialog'
,p_region_template_options=>'#DEFAULT#:js-dialog-size600x400'
,p_plug_template=>2672673746673652531
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1560809520591787085)
,p_plug_name=>'Scenario List'
,p_static_id=>'scenario-list'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    s.SCENARIO_ID,',
'    s.SCENARIO_NAME,',
'    s.DESCRIPTION,',
'    s.STATUS,',
'    s.CREATED_BY,',
'    s.CREATED_DATE,',
'    s.LAST_UPDATED_DATE',
'FROM DMT_SCENARIO_TBL s',
'ORDER BY s.CREATED_DATE DESC'))
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1560809602562787086)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'C'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_detail_link=>'f?p=&APP_ID.:14:&SESSION.::&DEBUG.::P14_SCENARIO_ID,P14_SCENARIO_NAME,P14_DESCRIPTION,P14_STATUS:#SCENARIO_ID#,#SCENARIO_NAME#,#DESCRIPTION#,#STATUS#'
,p_detail_link_text=>'<span role="img" aria-label="Edit" class="fa fa-edit" title="Edit"></span>'
,p_internal_uid=>22379955646102622
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1560810063920787091)
,p_db_column_name=>'CREATED_BY'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Created By'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1560810174319787092)
,p_db_column_name=>'CREATED_DATE'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Created Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1560809872162787089)
,p_db_column_name=>'DESCRIPTION'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Description'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1560810310084787093)
,p_db_column_name=>'LAST_UPDATED_DATE'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Last Updated Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1560809655016787087)
,p_db_column_name=>'SCENARIO_ID'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Scenario Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1560809817918787088)
,p_db_column_name=>'SCENARIO_NAME'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Scenario Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1560809961971787090)
,p_db_column_name=>'STATUS'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1561249761125373889)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'228202'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'SCENARIO_ID:SCENARIO_NAME:DESCRIPTION:STATUS:CREATED_BY:CREATED_DATE:LAST_UPDATED_DATE'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1560810984463787100)
,p_button_sequence=>50
,p_button_plug_id=>wwv_flow_imp.id(1560810491073787095)
,p_button_name=>'CANCEL_DIALOG'
,p_static_id=>'cancel-dialog'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Cancel'
,p_button_position=>'CLOSE'
,p_warn_on_unsaved_changes=>null
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1560810442236787094)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(1560809520591787085)
,p_button_name=>'CREATE_SCENARIO'
,p_static_id=>'create-scenario'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Create Scenario'
,p_button_position=>'RIGHT_OF_IR_SEARCH_BAR'
,p_warn_on_unsaved_changes=>null
,p_icon_css_classes=>'fa-plus'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1560811100542787101)
,p_button_sequence=>50
,p_button_plug_id=>wwv_flow_imp.id(1560810491073787095)
,p_button_name=>'SAVE_SCENARIO'
,p_static_id=>'save-scenario'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Save'
,p_button_position=>'CREATE'
);
wwv_flow_imp_page.create_page_branch(
 p_id=>wwv_flow_imp.id(1560811810841787108)
,p_branch_name=>'After Save'
,p_branch_action=>'f?p=&APP_ID.:14:&SESSION.::&DEBUG.:14::&success_msg=#SUCCESS_MSG#'
,p_branch_point=>'AFTER_PROCESSING'
,p_branch_type=>'REDIRECT_URL'
,p_branch_when_button_id=>wwv_flow_imp.id(1560811100542787101)
,p_branch_sequence=>10
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1560810829374787098)
,p_name=>'P14_DESCRIPTION'
,p_item_sequence=>30
,p_item_plug_id=>wwv_flow_imp.id(1560810491073787095)
,p_prompt=>'Description'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>30
,p_cHeight=>5
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1560810567124787096)
,p_name=>'P14_SCENARIO_ID'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1560810491073787095)
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1560810742540787097)
,p_name=>'P14_SCENARIO_NAME'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(1560810491073787095)
,p_prompt=>'Scenario Name'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>30
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1560810927115787099)
,p_name=>'P14_STATUS'
,p_item_sequence=>40
,p_item_plug_id=>wwv_flow_imp.id(1560810491073787095)
,p_prompt=>'Status'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'STATIC:Active;ACTIVE,Archived;ARCHIVED'
,p_cHeight=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1561253012704998071)
,p_name=>'Auto-Open Edit Dialog'
,p_static_id=>'auto-open-edit-dialog'
,p_event_sequence=>30
,p_condition_element=>'P14_SCENARIO_ID'
,p_triggering_condition_type=>'NOT_NULL'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'ready'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1561253059978998072)
,p_event_id=>wwv_flow_imp.id(1561253012704998071)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_static_id=>'native-open-region'
,p_action=>'NATIVE_OPEN_REGION'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(1560810491073787095)
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1560811447880787105)
,p_name=>'Close Scenario Dialog'
,p_static_id=>'close-scenario-dialog'
,p_event_sequence=>20
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(1560810984463787100)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1560811581086787106)
,p_event_id=>wwv_flow_imp.id(1560811447880787105)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-close-region'
,p_action=>'NATIVE_CLOSE_REGION'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(1560810491073787095)
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1560811194448787102)
,p_name=>'Open Scenario Dialog'
,p_static_id=>'open-scenario-dialog'
,p_event_sequence=>10
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(1560810442236787094)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1560811407961787104)
,p_event_id=>wwv_flow_imp.id(1560811194448787102)
,p_event_result=>'TRUE'
,p_action_sequence=>20
,p_execute_on_page_init=>'N'
,p_static_id=>'native-clear'
,p_action=>'NATIVE_CLEAR'
,p_affected_elements_type=>'ITEM'
,p_affected_elements=>'P14_SCENARIO_ID,P14_SCENARIO_NAME,P14_DESCRIPTION,P14_STATUS'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1560811322650787103)
,p_event_id=>wwv_flow_imp.id(1560811194448787102)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-open-region'
,p_action=>'NATIVE_OPEN_REGION'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(1560810491073787095)
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1560811713813787107)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Save Scenario'
,p_static_id=>'save-scenario'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'IF :P14_SCENARIO_ID IS NULL THEN',
'    INSERT INTO DMT_SCENARIO_TBL (',
'            SCENARIO_NAME,',
'                    DESCRIPTION,',
'                            STATUS,',
'                                    CREATED_BY,',
'                                            CREATED_DATE',
'                                                ) VALUES (',
'                                                        :P14_SCENARIO_NAME,',
'                                                                :P14_DESCRIPTION,',
'                                                                        NVL(:P14_STATUS, ''ACTIVE''),',
'                                                                                :APP_USER,',
'                                                                                        SYSDATE',
'                                                                                            );',
'                                                                                            ELSE',
'                                                                                                UPDATE DMT_SCENARIO_TBL SET',
'                                                                                                        SCENARIO_NAME     = :P14_SCENARIO_NAME,',
'                                                                                                                DESCRIPTION       = :P14_DESCRIPTION,',
'                                                                                                                        STATUS            = :P14_STATUS,',
'                                                                                                                                LAST_UPDATED_DATE = SYSDATE',
'                                                                                                                                    WHERE SCENARIO_ID = :P14_SCENARIO_ID;',
'                                                                                                                                    END IF;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1560811100542787101)
,p_process_success_message=>'Scenario saved successfully.'
,p_internal_uid=>22382066897102643
);
wwv_flow_imp.component_end;
end;
/
