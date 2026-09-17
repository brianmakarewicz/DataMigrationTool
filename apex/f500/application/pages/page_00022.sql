prompt --application/pages/page_00022
begin
--   Manifest
--     PAGE: 00022
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
 p_id=>22
,p_name=>'Config - Procurement'
,p_alias=>'CONFIG-PROCUREMENT'
,p_step_title=>'Configuration Data - Procurement & Tax'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118046720)
,p_plug_name=>'Bulk Upload'
,p_static_id=>'bulk-upload'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>50
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'<p>Upload CSV for procurement config objects.</p>'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118043720)
,p_plug_name=>'Payment Term Lines'
,p_static_id=>'payment-term-lines'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_PAY_TERM_LINES_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
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
 p_id=>wwv_flow_imp.id(1041441188118043721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99221002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093609227712299594)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521681'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'SEQUENCE_NUM:DUE_PERCENT:DUE_DAYS:DISCOUNT_PERCENT:DISCOUNT_DAYS:OVERALL_STATUS:ERROR_TEXT:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118042720)
,p_plug_name=>'Payment Terms'
,p_static_id=>'payment-terms'
,p_region_template_options=>'#DEFAULT#:is-expanded:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_PAY_TERMS_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
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
 p_id=>wwv_flow_imp.id(1041441188118042721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99220002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093608785731299587)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521676'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'NAME:DESCRIPTION:ENABLED_FLAG:PAY_TERM_TYPE:OVERALL_STATUS:ERROR_TEXT:START_DATE_ACTIVE:CUTOFF_DAY:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118045720)
,p_plug_name=>'Tax Rates'
,p_static_id=>'tax-rates'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>40
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_TAX_RATES_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
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
 p_id=>wwv_flow_imp.id(1041441188118045721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99223002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093610456641299605)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521693'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'TAX_REGIME_CODE:TAX_RATE_CODE:TAX_RATE_NAME:PERCENTAGE_RATE:EFFECTIVE_FROM:ACTIVE_FLAG:OVERALL_STATUS:ERROR_TEXT:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118044720)
,p_plug_name=>'Tax Regimes'
,p_static_id=>'tax-regimes'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>30
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_CFG_TAX_REGIMES_V WHERE (:P0_SCENARIO_SELECT IS NULL OR SCENARIO_ID = :P0_SCENARIO_SELECT) AND (:P0_PREFIX_INPUT IS NULL OR PREFIX = :P0_PREFIX_INPUT)'
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
 p_id=>wwv_flow_imp.id(1041441188118044721)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99222002
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093609857627299599)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521687'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'TAX_REGIME_CODE:TAX_REGIME_NAME:COUNTRY_CODE:EFFECTIVE_FROM:EFFECTIVE_TO:OVERALL_STATUS:ERROR_TEXT:RUN_DATE:PREFIX:SCENARIO_ID'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1041441188118046723)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(1041441188118046720)
,p_button_name=>'UPLOAD_CSV_22'
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
 p_id=>wwv_flow_imp.id(989176812264730625)
,p_name=>'P22_SCENARIO'
,p_item_sequence=>15
,p_item_plug_id=>wwv_flow_imp.id(1041441188118046720)
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
 p_id=>wwv_flow_imp.id(1041441188118046722)
,p_name=>'P22_UPLOAD_FILE'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(1041441188118046720)
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
 p_id=>wwv_flow_imp.id(1041441188118046721)
,p_name=>'P22_UPLOAD_OBJECT'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1041441188118046720)
,p_prompt=>'Object Type'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT display_name d, object_code r FROM dmt_upload_object_tbl WHERE page_number = 22 ORDER BY display_order'
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
