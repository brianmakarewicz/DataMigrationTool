prompt --application/pages/page_00035
begin
--   Manifest
--     PAGE: 00035
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
 p_id=>35
,p_name=>'Source Combinations'
,p_alias=>'SOURCE-COMBINATIONS'
,p_step_title=>'Source Combinations'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1143527897251314414)
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
 p_id=>wwv_flow_imp.id(1143528617232314417)
,p_plug_name=>'Source Combinations'
,p_static_id=>'source-combinations'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>20
,p_plug_new_grid_row=>false
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT sc.concat_segments,',
'       sc.segment1, sc.segment2, sc.segment3, sc.segment4,',
'       sc.segment5, sc.segment6, sc.segment7, sc.segment8,',
'       sc.enabled_flag,',
'       sc.last_refresh_date,',
'       CASE WHEN m.coa_mapping_id IS NOT NULL THEN ''Y'' ELSE ''N'' END AS is_mapped,',
'       m.target_concat AS mapped_to',
'FROM DMT_COA_SOURCE_COMBOS sc',
'LEFT JOIN DMT_COA_MAP_CONFIG mc ON mc.source_coa_set_id = sc.coa_set_id AND mc.active_flag = ''Y''',
'LEFT JOIN DMT_COA_MAPPING m ON m.map_config_id = mc.map_config_id AND m.source_concat = sc.concat_segments AND m.active_flag = ''Y''',
'WHERE sc.coa_set_id = :P35_COA_SET_ID',
'ORDER BY sc.concat_segments'))
,p_plug_source_type=>'NATIVE_IR'
,p_prn_page_header=>'Source Combinations'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1143528646793314417)
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
,p_internal_uid=>50079911176967840
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143529341409314420)
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
 p_id=>wwv_flow_imp.id(1143532997001314430)
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
 p_id=>wwv_flow_imp.id(1143533829666314432)
,p_db_column_name=>'IS_MAPPED'
,p_display_order=>12
,p_column_identifier=>'L'
,p_column_label=>'Is Mapped'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143533421572314431)
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
 p_id=>wwv_flow_imp.id(1143534182534314433)
,p_db_column_name=>'MAPPED_TO'
,p_display_order=>13
,p_column_identifier=>'M'
,p_column_label=>'Mapped To'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143529751305314421)
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
 p_id=>wwv_flow_imp.id(1143530227469314422)
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
 p_id=>wwv_flow_imp.id(1143530598982314423)
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
 p_id=>wwv_flow_imp.id(1143530992874314425)
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
 p_id=>wwv_flow_imp.id(1143531357483314426)
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
 p_id=>wwv_flow_imp.id(1143531793841314427)
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
 p_id=>wwv_flow_imp.id(1143532183002314428)
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
 p_id=>wwv_flow_imp.id(1143532551095314429)
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
 p_id=>wwv_flow_imp.id(1143072077581835812)
,p_name=>'P35_COA_SET_ID'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1143528617232314417)
,p_prompt=>'Source COA Set'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>unistr('SELECT set_code || '' \2014 '' || ledger_name AS d, coa_set_id AS r FROM DMT_COA_SET WHERE set_type=''SOURCE'' AND active_flag=''Y'' ORDER BY set_code')
,p_lov_display_null=>'YES'
,p_cHeight=>1
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
