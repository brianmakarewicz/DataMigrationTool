prompt --application/pages/page_00033
begin
--   Manifest
--     PAGE: 00033
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
 p_id=>33
,p_name=>'Segment Values'
,p_alias=>'SEGMENT-VALUES'
,p_step_title=>'Segment Values'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'21'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1143498975383276835)
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
 p_id=>wwv_flow_imp.id(1143499661974276838)
,p_plug_name=>'Segment Values'
,p_static_id=>'segment-values'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT segment_value_id, segment_map_id,',
'       source_value, target_value,',
'       active_flag, notes,',
'       created_by, created_date',
'FROM DMT_COA_SEGMENT_VALUES',
'WHERE segment_map_id = :P33_SEGMENT_MAP_ID',
'  AND suggested_flag = ''N''',
'ORDER BY source_value'))
,p_plug_source_type=>'NATIVE_IG'
,p_prn_page_header=>'Segment Values'
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1143505006186276853)
,p_name=>'ACTIVE_FLAG'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ACTIVE_FLAG'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Active Flag'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>50
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>true
,p_max_length=>1
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
 p_id=>wwv_flow_imp.id(1143506978381276858)
,p_name=>'CREATED_BY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'CREATED_BY'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Created By'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>70
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>100
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
 p_id=>wwv_flow_imp.id(1143507999984276860)
,p_name=>'CREATED_DATE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'CREATED_DATE'
,p_data_type=>'DATE'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_DATE_PICKER_APEX'
,p_heading=>'Created Date'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>80
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_date_ranges=>'ALL'
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
 p_id=>wwv_flow_imp.id(1143506019610276855)
,p_name=>'NOTES'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'NOTES'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Notes'
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
 p_id=>wwv_flow_imp.id(1143502015621276845)
,p_name=>'SEGMENT_MAP_ID'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'SEGMENT_MAP_ID'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Segment Map Id'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>20
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
 p_id=>wwv_flow_imp.id(1143500937114276842)
,p_name=>'SEGMENT_VALUE_ID'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'SEGMENT_VALUE_ID'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Segment Value Id'
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
 p_id=>wwv_flow_imp.id(1143502997387276847)
,p_name=>'SOURCE_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'SOURCE_VALUE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Source Value'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>30
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>true
,p_max_length=>100
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
 p_id=>wwv_flow_imp.id(1143504003390276850)
,p_name=>'TARGET_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TARGET_VALUE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Target Value'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>40
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>true
,p_max_length=>100
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
 p_id=>wwv_flow_imp.id(1143500233475276840)
,p_internal_uid=>50051497858930263
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
,p_enable_mail_download=>true
,p_fixed_header=>'PAGE'
,p_show_icon_view=>false
,p_show_detail_view=>false
);
wwv_flow_imp_page.create_ig_report(
 p_id=>wwv_flow_imp.id(1143500629857276841)
,p_interactive_grid_id=>wwv_flow_imp.id(1143500233475276840)
,p_static_id=>'500519'
,p_type=>'PRIMARY'
,p_default_view=>'GRID'
,p_show_row_number=>false
,p_settings_area_expanded=>true
);
wwv_flow_imp_page.create_ig_report_view(
 p_id=>wwv_flow_imp.id(1143500779193276841)
,p_report_id=>wwv_flow_imp.id(1143500629857276841)
,p_view_type=>'GRID'
,p_stretch_columns=>true
,p_srv_exclude_null_values=>false
,p_srv_only_display_columns=>true
,p_edit_mode=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143501421519276843)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>1
,p_column_id=>wwv_flow_imp.id(1143500937114276842)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143502431088276846)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>2
,p_column_id=>wwv_flow_imp.id(1143502015621276845)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143503420709276848)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>3
,p_column_id=>wwv_flow_imp.id(1143502997387276847)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143504374158276851)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>4
,p_column_id=>wwv_flow_imp.id(1143504003390276850)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143505356944276853)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>5
,p_column_id=>wwv_flow_imp.id(1143505006186276853)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143506412383276856)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>6
,p_column_id=>wwv_flow_imp.id(1143506019610276855)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143507398501276859)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>7
,p_column_id=>wwv_flow_imp.id(1143506978381276858)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143508352448276861)
,p_view_id=>wwv_flow_imp.id(1143500779193276841)
,p_display_seq=>8
,p_column_id=>wwv_flow_imp.id(1143507999984276860)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_report_region(
 p_id=>wwv_flow_imp.id(1143851249699440980)
,p_name=>'Suggested Mappings'
,p_static_id=>'suggested-mappings'
,p_parent_plug_id=>wwv_flow_imp.id(1143499661974276838)
,p_template=>4072358936313175081
,p_display_sequence=>60
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_component_template_options=>'#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight'
,p_source_type=>'NATIVE_SQL_REPORT'
,p_query_type=>'SQL'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT APEX_ITEM.CHECKBOX2(1, segment_value_id, ''CHECKED'') AS select_row,',
'       segment_value_id,',
'       source_value,',
'       target_value,',
'       match_score,',
'       notes',
'FROM DMT_LOOKUP.DMT_COA_SEGMENT_VALUES',
'WHERE segment_map_id = :P33_SEGMENT_MAP_ID',
'  AND suggested_flag = ''Y''',
'  AND active_flag = ''N''',
'ORDER BY match_score DESC'))
,p_ajax_enabled=>'Y'
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
 p_id=>wwv_flow_imp.id(1143851774560440985)
,p_query_column_id=>5
,p_column_alias=>'MATCH_SCORE'
,p_column_display_sequence=>50
,p_column_heading=>'Match Score'
,p_column_alignment=>'RIGHT'
,p_heading_alignment=>'RIGHT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1143851863451440986)
,p_query_column_id=>6
,p_column_alias=>'NOTES'
,p_column_display_sequence=>60
,p_column_heading=>'Notes'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1143851461274440982)
,p_query_column_id=>2
,p_column_alias=>'SEGMENT_VALUE_ID'
,p_column_display_sequence=>20
,p_column_heading=>'Segment Value Id'
,p_column_alignment=>'RIGHT'
,p_heading_alignment=>'RIGHT'
,p_display_as=>'HIDDEN'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1143851380562440981)
,p_query_column_id=>1
,p_column_alias=>'SELECT_ROW'
,p_column_display_sequence=>10
,p_heading_alignment=>'LEFT'
,p_display_as=>'WITHOUT_MODIFICATION'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1143851555298440983)
,p_query_column_id=>3
,p_column_alias=>'SOURCE_VALUE'
,p_column_display_sequence=>30
,p_column_heading=>'Source Value'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_report_columns(
 p_id=>wwv_flow_imp.id(1143851665578440984)
,p_query_column_id=>4
,p_column_alias=>'TARGET_VALUE'
,p_column_display_sequence=>40
,p_column_heading=>'Target Value'
,p_heading_alignment=>'LEFT'
,p_derived_column=>'N'
,p_include_in_export=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143071359256835805)
,p_button_sequence=>40
,p_button_plug_id=>wwv_flow_imp.id(1143499661974276838)
,p_button_name=>'ACCEPT_SELECTED'
,p_static_id=>'accept-selected'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Accept Selected'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143071152261835803)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(1143499661974276838)
,p_button_name=>'AUTO_MAP_EXACT'
,p_static_id=>'auto-map-exact'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Auto-Map Exact'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143071454045835806)
,p_button_sequence=>50
,p_button_plug_id=>wwv_flow_imp.id(1143499661974276838)
,p_button_name=>'REJECT_SELECTED'
,p_static_id=>'reject-selected'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Reject Selected'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143071274285835804)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(1143499661974276838)
,p_button_name=>'SUGGEST_FUZZY'
,p_static_id=>'suggest-fuzzy'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Suggest Fuzzy Matches'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1143851968693440987)
,p_name=>'P33_SEGMENT_INFO'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1143851249699440980)
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_DISPLAY_ONLY'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'based_on', 'VALUE',
  'format', 'PLAIN',
  'send_on_page_submit', 'Y',
  'show_line_breaks', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1143071082061835802)
,p_name=>'P33_SEGMENT_MAP_ID'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1143499661974276838)
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'N')).to_clob
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143071779624835809)
,p_process_sequence=>30
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Accept Selected'
,p_static_id=>'accept-selected'
,p_process_sql_clob=>'DECLARE l_ids VARCHAR2(4000); BEGIN FOR i IN 1..APEX_APPLICATION.G_F01.COUNT LOOP l_ids := l_ids || '':'' || APEX_APPLICATION.G_F01(i); END LOOP; l_ids := LTRIM(l_ids, '':''); IF l_ids IS NOT NULL THEN DMT_COA_SUGGEST_PKG.ACCEPT_SUGGESTIONS(l_ids); APEX_'
||'APPLICATION.G_PRINT_SUCCESS_MESSAGE := ''Suggestions accepted.''; END IF; END;'
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143071359256835805)
,p_internal_uid=>49623044008489232
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143071574894835807)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Auto-Map Exact'
,p_static_id=>'auto-map-exact'
,p_process_sql_clob=>'DECLARE v_cnt NUMBER; BEGIN v_cnt := DMT_COA_SUGGEST_PKG.AUTO_MAP_EXACT(:P33_SEGMENT_MAP_ID); APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE := v_cnt || '' exact matches auto-mapped.''; END;'
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143071152261835803)
,p_internal_uid=>49622839278489230
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143071935415835810)
,p_process_sequence=>40
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Reject Selected'
,p_static_id=>'reject-selected'
,p_process_sql_clob=>'DECLARE l_ids VARCHAR2(4000); BEGIN FOR i IN 1..APEX_APPLICATION.G_F01.COUNT LOOP l_ids := l_ids || '':'' || APEX_APPLICATION.G_F01(i); END LOOP; l_ids := LTRIM(l_ids, '':''); IF l_ids IS NOT NULL THEN DMT_COA_SUGGEST_PKG.REJECT_SUGGESTIONS(l_ids); APEX_'
||'APPLICATION.G_PRINT_SUCCESS_MESSAGE := ''Suggestions rejected.''; END IF; END;'
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143071454045835806)
,p_internal_uid=>49623199799489233
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143071651629835808)
,p_process_sequence=>20
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Suggest Fuzzy'
,p_static_id=>'suggest-fuzzy'
,p_process_sql_clob=>'DECLARE v_cnt NUMBER; BEGIN v_cnt := DMT_COA_SUGGEST_PKG.SUGGEST_SEGMENT_VALUES(:P33_SEGMENT_MAP_ID); APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE := v_cnt || '' fuzzy suggestions generated.''; END;'
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143071274285835804)
,p_internal_uid=>49622916013489231
);
wwv_flow_imp.component_end;
end;
/
