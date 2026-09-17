prompt --application/pages/page_00036
begin
--   Manifest
--     PAGE: 00036
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
 p_id=>36
,p_name=>'Target Combinations'
,p_alias=>'TARGET-COMBINATIONS'
,p_step_title=>'Target Combinations'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1143535186809323156)
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
 p_id=>wwv_flow_imp.id(1143535909693323159)
,p_plug_name=>'Target Combinations'
,p_static_id=>'target-combinations'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT concat_segments,',
'       segment1, segment2, segment3, segment4,',
'       segment5, segment6, segment7, segment8,',
'       enabled_flag,',
'       last_refresh_date',
'FROM DMT_COA_TARGET_COMBOS',
'WHERE coa_set_id = :P36_COA_SET_ID',
'ORDER BY concat_segments'))
,p_plug_source_type=>'NATIVE_IR'
,p_prn_page_header=>'Target Combinations'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1143535995183323159)
,p_max_row_count_message=>'The maximum row count for this report is #MAX_ROW_COUNT# rows.  Please apply a filter to reduce the number of records in your query.'
,p_no_data_found_message=>'No data found.'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>50087259566976582
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143536701731323163)
,p_db_column_name=>'CONCAT_SEGMENTS'
,p_display_order=>1
,p_column_identifier=>'A'
,p_column_label=>'Concat Segments'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143540295376323175)
,p_db_column_name=>'ENABLED_FLAG'
,p_display_order=>10
,p_column_identifier=>'J'
,p_column_label=>'Enabled Flag'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143540702962323177)
,p_db_column_name=>'LAST_REFRESH_DATE'
,p_display_order=>11
,p_column_identifier=>'K'
,p_column_label=>'Last Refresh Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143537092216323164)
,p_db_column_name=>'SEGMENT1'
,p_display_order=>2
,p_column_identifier=>'B'
,p_column_label=>'Segment1'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143537487415323166)
,p_db_column_name=>'SEGMENT2'
,p_display_order=>3
,p_column_identifier=>'C'
,p_column_label=>'Segment2'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143537918273323167)
,p_db_column_name=>'SEGMENT3'
,p_display_order=>4
,p_column_identifier=>'D'
,p_column_label=>'Segment3'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143538260577323168)
,p_db_column_name=>'SEGMENT4'
,p_display_order=>5
,p_column_identifier=>'E'
,p_column_label=>'Segment4'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143538694982323170)
,p_db_column_name=>'SEGMENT5'
,p_display_order=>6
,p_column_identifier=>'F'
,p_column_label=>'Segment5'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143539069917323171)
,p_db_column_name=>'SEGMENT6'
,p_display_order=>7
,p_column_identifier=>'G'
,p_column_label=>'Segment6'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143539524944323172)
,p_db_column_name=>'SEGMENT7'
,p_display_order=>8
,p_column_identifier=>'H'
,p_column_label=>'Segment7'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143539918330323174)
,p_db_column_name=>'SEGMENT8'
,p_display_order=>9
,p_column_identifier=>'I'
,p_column_label=>'Segment8'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1143072217914835813)
,p_name=>'P36_COA_SET_ID'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(1143535909693323159)
,p_prompt=>'Target COA Set'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>unistr('SELECT set_code || '' \2014 '' || ledger_name AS d, coa_set_id AS r FROM DMT_COA_SET WHERE set_type=''TARGET'' AND active_flag=''Y'' ORDER BY set_code')
,p_lov_display_null=>'YES'
,p_cHeight=>1
,p_begin_on_new_line=>'N'
,p_begin_on_new_field=>'N'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'execute_validations', 'Y',
  'page_action_on_selection', 'SUBMIT')).to_clob
);
wwv_flow_imp.component_end;
end;
/
