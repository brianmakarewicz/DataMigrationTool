prompt --application/pages/page_00021
begin
--   Manifest
--     PAGE: 00021
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
 p_id=>21
,p_name=>'Config - Financial'
,p_alias=>'CONFIG-FINANCIAL'
,p_step_title=>'Configuration Data - Financial & Reference'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118036720)
,p_plug_name=>'Bulk Upload'
,p_static_id=>'bulk-upload'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>50
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'<p>Upload a CSV file for configuration objects on this page.</p>'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118032720)
,p_plug_name=>'GL Calendar Periods'
,p_static_id=>'gl-calendar-periods'
,p_region_template_options=>'#DEFAULT#:is-expanded:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_GL_CALENDAR_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1041441188118032721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99210002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093605988087296607)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521649'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'PERIOD_SET_NAME:PERIOD_NAME:PERIOD_TYPE:PERIOD_YEAR:PERIOD_NUM:PERIOD_START_DATE:PERIOD_END_DATE:ADJUSTMENT_PERIOD_FLAG:OVERALL_STATUS:ERROR_TEXT:STG_STATUS:TFM_STATUS:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118035720)
,p_plug_name=>'Units of Measure'
,p_static_id=>'units-of-measure'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>40
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_UOM_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1041441188118035721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99213002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093607688076296657)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521666'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'UOM_CODE:UNIT_OF_MEASURE:UOM_CLASS:DESCRIPTION:BASE_UOM_FLAG:OVERALL_STATUS:ERROR_TEXT:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118034720)
,p_plug_name=>'Value Set Values'
,p_static_id=>'value-set-values'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>30
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_VS_VALUES_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1041441188118034721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99212002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093607091212296650)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521660'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'VALUE_SET_CODE:VALUE:DESCRIPTION:ENABLED_FLAG:OVERALL_STATUS:ERROR_TEXT:EFFECTIVE_START_DATE:EFFECTIVE_END_DATE:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118033720)
,p_plug_name=>'Value Sets'
,p_static_id=>'value-sets'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_VALUE_SETS_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1041441188118033721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99211002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093606606792296644)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521655'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'VALUE_SET_CODE:DESCRIPTION:MODULE_ID:VALIDATION_TYPE:VALUE_DATA_TYPE:OVERALL_STATUS:ERROR_TEXT:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1041441188118036723)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(1041441188118036720)
,p_button_name=>'UPLOAD_CSV_21'
,p_static_id=>'upload-csv'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Upload'
,p_button_position=>'BELOW_BOX'
,p_button_alignment=>'RIGHT'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(989176812264730624)
,p_name=>'P21_SCENARIO'
,p_item_sequence=>15
,p_item_plug_id=>wwv_flow_imp.id(1041441188118036720)
,p_prompt=>'Scenario'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT scenario_name d, scenario_name r FROM dmt_scenario_tbl WHERE status = ''ACTIVE'' ORDER BY scenario_name'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'-- No Scenario --'
,p_cHeight=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118036722)
,p_name=>'P21_UPLOAD_FILE'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(1041441188118036720)
,p_prompt=>'Upload File'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_FILE'
,p_cSize=>30
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'allow_copy_paste', 'N',
  'allow_multiple_files', 'N',
  'display_as', 'INLINE',
  'purge_file_at', 'SESSION',
  'storage_type', 'APEX_APPLICATION_TEMP_FILES')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118036721)
,p_name=>'P21_UPLOAD_OBJECT'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1041441188118036720)
,p_prompt=>'Object Type'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT display_name d, object_code r FROM dmt_upload_object_tbl WHERE page_number = 21 ORDER BY display_order'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'-- Select Object --'
,p_cHeight=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp.component_end;
end;
/
