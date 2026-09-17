prompt --application/pages/page_00017
begin
--   Manifest
--     PAGE: 00017
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
 p_id=>17
,p_name=>'Value Mapping'
,p_alias=>'VALUE-MAPPING'
,p_step_title=>'Value Mapping'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'21'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1291274967135562992)
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
wwv_flow_imp_page.create_report_region(
 p_id=>wwv_flow_imp.id(1242109752459244505)
,p_name=>'EBS Values With No Fusion Equivalent'
,p_static_id=>'ebs-values-with-no-fusion-equivalent'
,p_template=>4072358936313175081
,p_display_sequence=>40
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_component_template_options=>'#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight'
,p_source_type=>'NATIVE_SQL_REPORT'
,p_query_type=>'SQL'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT APEX_ITEM.HIDDEN(10, e.ebs_value_id) ||',
'       APEX_ITEM.POPUP_FROM_QUERY(',
'         p_idx        => 11,',
'         p_value      => e.mapped_to,',
'         p_lov_query  => ''select fusion_value d, fusion_value r from DMT_LOOKUP.DMT_LKP_FUSION_VALUES where lookup_type = '''''' || REPLACE(NVL(:P17_LOOKUP_TYPE,''~''), '''''''', '''''''''''') || '''''' order by 1'',',
'         p_width      => 30,',
'         p_max_length => 500,',
'         p_attributes => ''style="width:240px;"''',
'       ) AS map_to,',
'       e.ebs_value,',
'       e.ebs_description,',
'       e.default_fusion_value,',
'       CASE WHEN e.mapped_to IS NOT NULL THEN ''MAPPED''',
'            WHEN e.default_fusion_value IS NOT NULL THEN ''HAS DEFAULT''',
'            ELSE ''NEEDS MAPPING''',
'       END AS resolution_status',
'  FROM DMT_LOOKUP.DMT_LKP_EBS_UNMATCHED_V e',
' WHERE e.lookup_type = :P17_LOOKUP_TYPE',
' ORDER BY resolution_status DESC, e.ebs_value'))
,p_ajax_enabled=>'Y'
,p_ajax_items_to_submit=>'P17_LOOKUP_TYPE'
,p_lazy_loading=>false
,p_query_row_template=>2538654340625403440
,p_query_num_rows=>15
,p_query_options=>'DERIVED_REPORT_COLUMNS'
,p_query_num_rows_type=>'NEXT_PREVIOUS_LINKS'
,p_pagination_display_position=>'BOTTOM_RIGHT'
,p_csv_output=>'N'
,p_prn_output=>'N'
,p_sort_null=>'L'
,p_plug_query_strip_html=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242110142804244509)
,p_query_column_id=>4
,p_column_alias=>'DEFAULT_FUSION_VALUE'
,p_column_display_sequence=>40
,p_column_heading=>'Default Fusion Value'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242109983147244507)
,p_query_column_id=>3
,p_column_alias=>'EBS_DESCRIPTION'
,p_column_display_sequence=>20
,p_column_heading=>'Ebs Description'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242109896139244506)
,p_query_column_id=>2
,p_column_alias=>'EBS_VALUE'
,p_column_display_sequence=>10
,p_column_heading=>'Ebs Value'
,p_heading_alignment=>'LEFT'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1193079035661701670)
,p_query_column_id=>1
,p_column_alias=>'MAP_TO'
,p_column_display_sequence=>60
,p_column_heading=>'Map To'
,p_heading_alignment=>'LEFT'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242110232136244510)
,p_query_column_id=>5
,p_column_alias=>'RESOLUTION_STATUS'
,p_column_display_sequence=>50
,p_column_heading=>'Resolution Status'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_region(
 p_id=>wwv_flow_imp.id(1242110382639244511)
,p_name=>'Suggested Mappings'
,p_static_id=>'suggested-mappings'
,p_template=>4072358936313175081
,p_display_sequence=>30
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_component_template_options=>'#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight'
,p_source_type=>'NATIVE_SQL_REPORT'
,p_query_type=>'SQL'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT APEX_ITEM.CHECKBOX2(1, mapping_id) AS select_row,',
'       mapping_id,',
'       ebs_value,',
'       fusion_value,',
'       match_score AS combined_score,',
'       REGEXP_SUBSTR(notes, ''JW=(\d+)'', 1, 1, NULL, 1) AS jaro_winkler,',
'       REGEXP_SUBSTR(notes, ''ED=(\d+)'', 1, 1, NULL, 1) AS edit_distance,',
'       notes',
'  FROM DMT_LOOKUP.DMT_LKP_MAPPING',
' WHERE lookup_type = :P17_LOOKUP_TYPE',
'   AND suggested_flag = ''Y''',
'   AND active_flag = ''N''',
' ORDER BY match_score DESC'))
,p_ajax_enabled=>'Y'
,p_ajax_items_to_submit=>'P17_LOOKUP_TYPE'
,p_lazy_loading=>false
,p_query_row_template=>2538654340625403440
,p_query_num_rows=>15
,p_query_options=>'DERIVED_REPORT_COLUMNS'
,p_query_num_rows_type=>'NEXT_PREVIOUS_LINKS'
,p_pagination_display_position=>'BOTTOM_RIGHT'
,p_csv_output=>'N'
,p_prn_output=>'N'
,p_sort_null=>'L'
,p_plug_query_strip_html=>'N'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1192511335882222510)
,p_query_column_id=>5
,p_column_alias=>'COMBINED_SCORE'
,p_column_display_sequence=>70
,p_column_heading=>'Combined'
,p_column_alignment=>'RIGHT'
,p_heading_alignment=>'RIGHT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242110711025244514)
,p_query_column_id=>3
,p_column_alias=>'EBS_VALUE'
,p_column_display_sequence=>30
,p_column_heading=>'Ebs Value'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1192511522999222512)
,p_query_column_id=>7
,p_column_alias=>'EDIT_DISTANCE'
,p_column_display_sequence=>90
,p_column_heading=>'Edit Distance'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242110741996244515)
,p_query_column_id=>4
,p_column_alias=>'FUSION_VALUE'
,p_column_display_sequence=>40
,p_column_heading=>'Fusion Value'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1192511395428222511)
,p_query_column_id=>6
,p_column_alias=>'JARO_WINKLER'
,p_column_display_sequence=>80
,p_column_heading=>'Jaro-Winkler'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242110538442244513)
,p_query_column_id=>2
,p_column_alias=>'MAPPING_ID'
,p_column_display_sequence=>20
,p_column_heading=>'Mapping Id'
,p_column_alignment=>'RIGHT'
,p_heading_alignment=>'RIGHT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242110930372244517)
,p_query_column_id=>8
,p_column_alias=>'NOTES'
,p_column_display_sequence=>60
,p_column_heading=>'Match Notes'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1242110446990244512)
,p_query_column_id=>1
,p_column_alias=>'SELECT_ROW'
,p_column_display_sequence=>10
,p_column_heading=>'Select Row'
,p_heading_alignment=>'LEFT'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1193079172505701671)
,p_plug_name=>'Unmatched EBS Values (IG version)'
,p_static_id=>'unmatched-ebs-values-ig-version'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>50
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT e.ebs_value_id,',
'       e.lookup_type,',
'       e.ebs_value,',
'       e.ebs_description,',
'       e.mapped_to,',
'       e.default_fusion_value,',
'       CASE WHEN e.mapped_to IS NOT NULL THEN ''MAPPED''',
'            WHEN e.default_fusion_value IS NOT NULL THEN ''HAS DEFAULT''',
'            ELSE ''NEEDS MAPPING''',
'       END AS resolution_status',
'  FROM DMT_LOOKUP.DMT_LKP_EBS_UNMATCHED_V e',
' WHERE e.lookup_type = :P17_LOOKUP_TYPE'))
,p_plug_source_type=>'NATIVE_IG'
,p_ajax_items_to_submit=>'P17_LOOKUP_TYPE'
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
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1193079856666701678)
,p_name=>'DEFAULT_FUSION_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DEFAULT_FUSION_VALUE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Default Fusion Value'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>60
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>500
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1193079624155701676)
,p_name=>'EBS_DESCRIPTION'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'EBS_DESCRIPTION'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Ebs Description'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>40
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>500
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1193079568061701675)
,p_name=>'EBS_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'EBS_VALUE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Ebs Value'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>30
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>true
,p_max_length=>500
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1193079350110701673)
,p_name=>'EBS_VALUE_ID'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'EBS_VALUE_ID'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Ebs Value Id'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>10
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>true
,p_enable_filter=>true
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1193079414094701674)
,p_name=>'LOOKUP_TYPE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'LOOKUP_TYPE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Lookup Type'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>20
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>true
,p_max_length=>150
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'DISTINCT'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1193079709278701677)
,p_name=>'MAPPED_TO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'MAPPED_TO'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Mapped To'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>50
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>500
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1193079912217701679)
,p_name=>'RESOLUTION_STATUS'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'RESOLUTION_STATUS'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Resolution Status'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>70
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>13
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'DISTINCT'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_interactive_grid(
 p_id=>wwv_flow_imp.id(1193079202686701672)
,p_internal_uid=>49620808035489210
,p_is_editable=>false
,p_lazy_loading=>false
,p_requires_filter=>false
,p_select_first_row=>true
,p_fixed_row_height=>true
,p_pagination_type=>'SCROLL'
,p_show_total_row_count=>true
,p_show_toolbar=>true
,p_enable_save_public_report=>false
,p_enable_subscriptions=>true
,p_enable_flashback=>true
,p_define_chart_view=>true
,p_enable_download=>true
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>true
,p_fixed_header=>'PAGE'
,p_show_icon_view=>false
,p_show_detail_view=>false
);
wwv_flow_imp_page.create_ig_report(
 p_id=>wwv_flow_imp.id(1193424552726572373)
,p_interactive_grid_id=>wwv_flow_imp.id(1193079202686701672)
,p_static_id=>'499662'
,p_type=>'PRIMARY'
,p_default_view=>'GRID'
,p_show_row_number=>false
,p_settings_area_expanded=>true
);
wwv_flow_imp_page.create_ig_report_view(
 p_id=>wwv_flow_imp.id(1193424724513572375)
,p_report_id=>wwv_flow_imp.id(1193424552726572373)
,p_view_type=>'GRID'
,p_stretch_columns=>true
,p_srv_exclude_null_values=>false
,p_srv_only_display_columns=>true
,p_edit_mode=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1193425259212572383)
,p_view_id=>wwv_flow_imp.id(1193424724513572375)
,p_display_seq=>1
,p_column_id=>wwv_flow_imp.id(1193079350110701673)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1193426114013572389)
,p_view_id=>wwv_flow_imp.id(1193424724513572375)
,p_display_seq=>2
,p_column_id=>wwv_flow_imp.id(1193079414094701674)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1193427023396572393)
,p_view_id=>wwv_flow_imp.id(1193424724513572375)
,p_display_seq=>3
,p_column_id=>wwv_flow_imp.id(1193079568061701675)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1193427966019572397)
,p_view_id=>wwv_flow_imp.id(1193424724513572375)
,p_display_seq=>4
,p_column_id=>wwv_flow_imp.id(1193079624155701676)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1193428824216572402)
,p_view_id=>wwv_flow_imp.id(1193424724513572375)
,p_display_seq=>5
,p_column_id=>wwv_flow_imp.id(1193079709278701677)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1193429697226572405)
,p_view_id=>wwv_flow_imp.id(1193424724513572375)
,p_display_seq=>6
,p_column_id=>wwv_flow_imp.id(1193079856666701678)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1193430611613572410)
,p_view_id=>wwv_flow_imp.id(1193424724513572375)
,p_display_seq=>7
,p_column_id=>wwv_flow_imp.id(1193079912217701679)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1291275500604562994)
,p_plug_name=>'Value Mapping'
,p_static_id=>'value-mapping'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT mapping_id, lookup_type, ebs_value, fusion_value, match_score, active_flag, notes, created_by, created_date, last_update_by, last_update_date FROM DMT_LOOKUP.DMT_LKP_MAPPING WHERE LOOKUP_TYPE = :P17_LOOKUP_TYPE AND NVL(SUGGESTED_FLAG,''N'') = ''N'
||''''
,p_plug_source_type=>'NATIVE_IG'
,p_prn_page_header=>'Value Mapping'
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291280820364563039)
,p_name=>'ACTIVE_FLAG'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ACTIVE_FLAG'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_SELECT_LIST'
,p_heading=>'Active Flag'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>70
,p_value_alignment=>'LEFT'
,p_is_required=>true
,p_lov_type=>'STATIC'
,p_lov_source=>'STATIC:Yes;Y,No;N'
,p_lov_display_extra=>true
,p_lov_display_null=>true
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'LOV'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1282141952255965338)
,p_name=>'APEX$ROW_ACTION'
,p_session_state_data_type=>'VARCHAR2'
,p_item_type=>'NATIVE_ROW_ACTION'
,p_display_sequence=>20
,p_use_as_row_header=>false
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1282142037137965339)
,p_name=>'APEX$ROW_SELECTOR'
,p_session_state_data_type=>'VARCHAR2'
,p_item_type=>'NATIVE_ROW_SELECTOR'
,p_display_sequence=>10
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'enable_multi_select', 'Y',
  'hide_control', 'N',
  'show_select_all', 'Y')).to_clob
,p_use_as_row_header=>false
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291282798825563043)
,p_name=>'CREATED_BY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'CREATED_BY'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>90
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_use_as_row_header=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291283780926563046)
,p_name=>'CREATED_DATE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'CREATED_DATE'
,p_data_type=>'DATE'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>100
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_use_as_row_header=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291278832313563033)
,p_name=>'EBS_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'EBS_VALUE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_SELECT_LIST'
,p_heading=>'Ebs Value'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>50
,p_value_alignment=>'LEFT'
,p_is_required=>true
,p_lov_type=>'SQL_QUERY'
,p_lov_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT ebs_value || NVL2(ebs_description, '' -- '' || ebs_description, '''') AS d,',
'       ebs_value AS r',
'  FROM DMT_LOOKUP.DMT_LKP_EBS_VALUES',
' WHERE lookup_type = :P17_LOOKUP_TYPE',
'   AND active_flag = ''Y''',
' ORDER BY ebs_value'))
,p_lov_display_extra=>true
,p_lov_display_null=>true
,p_lov_null_text=>'- Select EBS Value -'
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'LOV'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291279851983563036)
,p_name=>'FUSION_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'FUSION_VALUE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_SELECT_LIST'
,p_heading=>'Fusion Value'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>60
,p_value_alignment=>'LEFT'
,p_is_required=>true
,p_lov_type=>'SQL_QUERY'
,p_lov_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT fusion_value || NVL2(fusion_description, '' -- '' || fusion_description, '''') AS d,',
'       fusion_value AS r',
'  FROM DMT_LOOKUP.DMT_LKP_FUSION_VALUES',
' WHERE lookup_type = :P17_LOOKUP_TYPE',
'   AND active_flag = ''Y''',
' ORDER BY fusion_value'))
,p_lov_display_extra=>true
,p_lov_display_null=>true
,p_lov_null_text=>'- Select Fusion Value -'
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'LOV'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291284832377563048)
,p_name=>'LAST_UPDATE_BY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'LAST_UPDATE_BY'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>110
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_use_as_row_header=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291285827900563051)
,p_name=>'LAST_UPDATE_DATE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'LAST_UPDATE_DATE'
,p_data_type=>'DATE'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>120
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_use_as_row_header=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291277845090563031)
,p_name=>'LOOKUP_TYPE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'LOOKUP_TYPE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>40
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_use_as_row_header=>false
,p_is_primary_key=>false
,p_default_type=>'ITEM'
,p_default_expression=>'P17_LOOKUP_TYPE'
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291276846207563026)
,p_name=>'MAPPING_ID'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'MAPPING_ID'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>30
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_use_as_row_header=>false
,p_is_primary_key=>true
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1242108877416244496)
,p_name=>'MATCH_SCORE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'MATCH_SCORE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_DISPLAY_ONLY'
,p_heading=>'Match Score'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>130
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'based_on', 'VALUE',
  'format', 'PLAIN')).to_clob
,p_enable_filter=>true
,p_filter_text_case=>'MIXED'
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1291281832112563041)
,p_name=>'NOTES'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'NOTES'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Notes'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>80
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>500
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_text_case=>'MIXED'
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_interactive_grid(
 p_id=>wwv_flow_imp.id(1291275998873562996)
,p_internal_uid=>49014630882841307
,p_is_editable=>true
,p_edit_operations=>'i:u:d'
,p_lost_update_check_type=>'VALUES'
,p_add_row_if_empty=>true
,p_lazy_loading=>false
,p_requires_filter=>false
,p_select_first_row=>true
,p_fixed_row_height=>true
,p_pagination_type=>'SCROLL'
,p_show_total_row_count=>true
,p_show_toolbar=>true
,p_enable_save_public_report=>false
,p_enable_subscriptions=>true
,p_enable_flashback=>true
,p_define_chart_view=>true
,p_enable_download=>true
,p_enable_mail_download=>true
,p_fixed_header=>'PAGE'
,p_show_icon_view=>false
,p_show_detail_view=>false
);
wwv_flow_imp_page.create_ig_report(
 p_id=>wwv_flow_imp.id(1291276443773563016)
,p_interactive_grid_id=>wwv_flow_imp.id(1291275998873562996)
,p_static_id=>'490151'
,p_type=>'PRIMARY'
,p_default_view=>'GRID'
,p_show_row_number=>false
,p_settings_area_expanded=>true
);
wwv_flow_imp_page.create_ig_report_view(
 p_id=>wwv_flow_imp.id(1291276629338563017)
,p_report_id=>wwv_flow_imp.id(1291276443773563016)
,p_view_type=>'GRID'
,p_stretch_columns=>true
,p_srv_exclude_null_values=>false
,p_srv_only_display_columns=>true
,p_edit_mode=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1242268003535819242)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>11
,p_column_id=>wwv_flow_imp.id(1242108877416244496)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291277262651563028)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>1
,p_column_id=>wwv_flow_imp.id(1291276846207563026)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291278256662563031)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>2
,p_column_id=>wwv_flow_imp.id(1291277845090563031)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291279241649563034)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>3
,p_column_id=>wwv_flow_imp.id(1291278832313563033)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291280168981563036)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>4
,p_column_id=>wwv_flow_imp.id(1291279851983563036)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291281214415563040)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>5
,p_column_id=>wwv_flow_imp.id(1291280820364563039)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291282239913563042)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>6
,p_column_id=>wwv_flow_imp.id(1291281832112563041)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291283194596563044)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>7
,p_column_id=>wwv_flow_imp.id(1291282798825563043)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291284247606563047)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>8
,p_column_id=>wwv_flow_imp.id(1291283780926563046)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291285239143563049)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>9
,p_column_id=>wwv_flow_imp.id(1291284832377563048)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291286207682563052)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>10
,p_column_id=>wwv_flow_imp.id(1291285827900563051)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1291315876910732645)
,p_view_id=>wwv_flow_imp.id(1291276629338563017)
,p_display_seq=>0
,p_column_id=>wwv_flow_imp.id(1282141952255965338)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1242111301951244520)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(1242110382639244511)
,p_button_name=>'ACCEPT_ALL'
,p_static_id=>'accept-all'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Accept All for Type'
,p_grid_new_row=>'N'
,p_grid_new_column=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1242111105182244518)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(1242110382639244511)
,p_button_name=>'ACCEPT_SELECTED'
,p_static_id=>'accept-selected'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Accept Selected'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1242111378053244521)
,p_button_sequence=>40
,p_button_plug_id=>wwv_flow_imp.id(1242110382639244511)
,p_button_name=>'REJECT_ALL'
,p_static_id=>'reject-all'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'t-Button--danger'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Reject All for Type'
,p_grid_new_row=>'N'
,p_grid_new_column=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1242111150224244519)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(1242110382639244511)
,p_button_name=>'REJECT_SELECTED'
,p_static_id=>'reject-selected'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'t-Button--danger'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Reject Selected'
,p_grid_new_row=>'N'
,p_grid_new_column=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1192510948170222506)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(1242109752459244505)
,p_button_name=>'SAVE_UNMATCHED_MAPPINGS'
,p_static_id=>'save-unmatched-mappings'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Save Quick Mappings'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_branch(
 p_id=>wwv_flow_imp.id(1193078342870701663)
,p_branch_name=>'Refresh Page 17 After Quick Save'
,p_branch_action=>'f?p=&APP_ID.:17:&SESSION.::&DEBUG.:17:P17_LOOKUP_TYPE:&P17_LOOKUP_TYPE.&success_msg=#SUCCESS_MSG#'
,p_branch_point=>'AFTER_PROCESSING'
,p_branch_type=>'REDIRECT_URL'
,p_branch_when_button_id=>wwv_flow_imp.id(1192510948170222506)
,p_branch_sequence=>10
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1242109723500244504)
,p_name=>'P17_DEFAULT_VALUE'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1291275500604562994)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Type Default'
,p_post_element_text=>'<button type="button" class="t-Button t-Button--simple t-Button--primary" style="margin-left:8px;" onclick="apex.event.trigger(''#P17_DEFAULT_VALUE'',''change'');">Save</button>'
,p_source=>'SELECT NVL(default_fusion_value, ''(Not set)'') FROM DMT_LOOKUP.DMT_LKP_TYPE_CONFIG WHERE lookup_type = :P17_LOOKUP_TYPE'
,p_source_type=>'QUERY'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT fusion_value || NVL2(fusion_description, '' -- '' || fusion_description, '''') AS d, fusion_value AS r FROM DMT_LOOKUP.DMT_LKP_FUSION_VALUES WHERE lookup_type = :P17_LOOKUP_TYPE AND active_flag = ''Y'' ORDER BY fusion_value'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'- No Default (pass-through) -'
,p_lov_cascade_parent_items=>'P17_LOOKUP_TYPE'
,p_ajax_optimize_refresh=>'Y'
,p_cHeight=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1291309772732731692)
,p_name=>'P17_LOOKUP_TYPE'
,p_item_sequence=>1
,p_item_plug_id=>wwv_flow_imp.id(1291275500604562994)
,p_prompt=>'Lookup Type'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT lookup_type d, lookup_type r FROM DMT_LOOKUP.DMT_LKP_TYPE_CONFIG ORDER BY 1'
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
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1193078720485701667)
,p_name=>'Refresh Default Value on Type Change'
,p_static_id=>'refresh-default-value-on-type-change'
,p_event_sequence=>20
,p_triggering_element_type=>'ITEM'
,p_triggering_element=>'P17_LOOKUP_TYPE'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'change'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1193078894150701668)
,p_event_id=>wwv_flow_imp.id(1193078720485701667)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'Y'
,p_static_id=>'native-set-value'
,p_action=>'NATIVE_SET_VALUE'
,p_affected_elements_type=>'ITEM'
,p_affected_elements=>'P17_DEFAULT_VALUE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'escape_special_characters', 'Y',
  'items_to_submit', 'P17_LOOKUP_TYPE',
  'sql_query', 'SELECT default_fusion_value FROM DMT_LOOKUP.DMT_LKP_TYPE_CONFIG WHERE lookup_type = :P17_LOOKUP_TYPE',
  'suppress_change_event', 'N',
  'type', 'SQL_STATEMENT')).to_clob
,p_wait_for_result=>'Y'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1193078488280701664)
,p_name=>'Save Default Value on Change'
,p_static_id=>'save-default-value-on-change'
,p_event_sequence=>10
,p_triggering_element_type=>'ITEM'
,p_triggering_element=>'P17_DEFAULT_VALUE'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'change'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1193078586991701665)
,p_event_id=>wwv_flow_imp.id(1193078488280701664)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-execute-plsql-code'
,p_action=>'NATIVE_EXECUTE_PLSQL_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'items_to_submit', 'P17_DEFAULT_VALUE,P17_LOOKUP_TYPE',
  'language', 'PLSQL',
  'plsql_code', wwv_flow_string.join(wwv_flow_t_varchar2(
    'UPDATE DMT_LOOKUP.DMT_LKP_TYPE_CONFIG',
    '   SET default_fusion_value = NULLIF(:P17_DEFAULT_VALUE, '''')',
    ' WHERE lookup_type = :P17_LOOKUP_TYPE;',
    'COMMIT;')),
  'show_processing', 'N')).to_clob
,p_wait_for_result=>'Y'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1193078683887701666)
,p_event_id=>wwv_flow_imp.id(1193078488280701664)
,p_event_result=>'TRUE'
,p_action_sequence=>20
,p_execute_on_page_init=>'N'
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', 'apex.message.showPageSuccess(''Default value saved.'');')).to_clob
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1242111630053244524)
,p_process_sequence=>40
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Accept All Suggestions for Type'
,p_static_id=>'accept-all-suggestions-for-type'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'BEGIN',
'  DMT_LOOKUP.DMT_LKP_SUGGEST_PKG.ACCEPT_ALL_FOR_TYPE(:P17_LOOKUP_TYPE);',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1242111301951244520)
,p_internal_uid=>49051601255010035
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1242111477847244522)
,p_process_sequence=>20
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Accept Selected Suggestions'
,p_static_id=>'accept-selected-suggestions'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  l_ids VARCHAR2(32767);',
'BEGIN',
'  FOR i IN 1..APEX_APPLICATION.G_F01.COUNT LOOP',
'    l_ids := l_ids || '':'' || APEX_APPLICATION.G_F01(i);',
'  END LOOP;',
'  l_ids := LTRIM(l_ids, '':'');',
'  IF l_ids IS NOT NULL THEN',
'    DMT_LOOKUP.DMT_LKP_SUGGEST_PKG.ACCEPT_SUGGESTIONS(l_ids);',
'  END IF;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1242111105182244518)
,p_internal_uid=>49051449049010033
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1242111766822244525)
,p_process_sequence=>50
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Reject All Suggestions for Type'
,p_static_id=>'reject-all-suggestions-for-type'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'BEGIN',
'  DMT_LOOKUP.DMT_LKP_SUGGEST_PKG.REJECT_ALL_FOR_TYPE(:P17_LOOKUP_TYPE);',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1242111378053244521)
,p_internal_uid=>49051738024010036
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1242111590796244523)
,p_process_sequence=>30
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Reject Selected Suggestions'
,p_static_id=>'reject-selected-suggestions'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  l_ids VARCHAR2(32767);',
'BEGIN',
'  FOR i IN 1..APEX_APPLICATION.G_F01.COUNT LOOP',
'    l_ids := l_ids || '':'' || APEX_APPLICATION.G_F01(i);',
'  END LOOP;',
'  l_ids := LTRIM(l_ids, '':'');',
'  IF l_ids IS NOT NULL THEN',
'    DMT_LOOKUP.DMT_LKP_SUGGEST_PKG.REJECT_SUGGESTIONS(l_ids);',
'  END IF;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1242111150224244519)
,p_internal_uid=>49051561998010034
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1192511080538222507)
,p_process_sequence=>60
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Save Quick Mappings from Unmatched'
,p_static_id=>'save-quick-mappings-from-unmatched'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'   l_user VARCHAR2(100) := COALESCE(:APP_USER, USER);',
'BEGIN',
'   IF APEX_APPLICATION.G_F10.COUNT = 0 THEN',
'      RETURN;',
'   END IF;',
'',
'   FOR i IN 1 .. APEX_APPLICATION.G_F10.COUNT LOOP',
'      DECLARE',
'         l_ebs_value_id NUMBER := TO_NUMBER(APEX_APPLICATION.G_F10(i));',
'         l_mapped_to    VARCHAR2(500) := NULLIF(APEX_APPLICATION.G_F11(i), '''');',
'         l_lookup_type  VARCHAR2(150);',
'         l_ebs_value    VARCHAR2(500);',
'      BEGIN',
'         IF l_mapped_to IS NULL THEN',
'            CONTINUE;',
'         END IF;',
'',
'         SELECT lookup_type, ebs_value',
'           INTO l_lookup_type, l_ebs_value',
'           FROM DMT_LOOKUP.DMT_LKP_EBS_VALUES',
'          WHERE ebs_value_id = l_ebs_value_id;',
'',
'         MERGE INTO DMT_LOOKUP.DMT_LKP_MAPPING m',
'         USING (SELECT l_lookup_type AS lookup_type, l_ebs_value AS ebs_value FROM dual) src',
'            ON (m.lookup_type = src.lookup_type AND m.ebs_value = src.ebs_value)',
'         WHEN MATCHED THEN',
'            UPDATE SET m.fusion_value = l_mapped_to,',
'                       m.active_flag  = ''Y'',',
'                       m.notes        = ''Quick-mapped from unmatched''',
'         WHEN NOT MATCHED THEN',
'            INSERT (lookup_type, ebs_value, fusion_value, active_flag, notes)',
'            VALUES (l_lookup_type, l_ebs_value, l_mapped_to, ''Y'', ''Quick-mapped from unmatched'');',
'      END;',
'   END LOOP;',
'',
'   COMMIT;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1192510948170222506)
,p_internal_uid=>49052685887010045
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1291309661279731690)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_region_id=>wwv_flow_imp.id(1291275500604562994)
,p_process_type=>'NATIVE_IG_DML'
,p_process_name=>'Value Mapping - Save Interactive Grid Data'
,p_static_id=>'value-mapping-save-interactive-grid-data'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'lock_row', 'Y',
  'prevent_lost_updates', 'Y',
  'return_primary_keys_after_insert', 'Y',
  'target_type', 'REGION_SOURCE')).to_clob
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_internal_uid=>49048293289010001
);
wwv_flow_imp.component_end;
end;
/
