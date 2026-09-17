prompt --application/pages/page_00032
begin
--   Manifest
--     PAGE: 00032
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
 p_id=>32
,p_name=>'Segment Rules'
,p_alias=>'SEGMENT-RULES'
,p_step_title=>'Segment Rules'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'21'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1143482471648268105)
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
 p_id=>wwv_flow_imp.id(1143853016428440997)
,p_plug_name=>'Config Summary'
,p_static_id=>'config-summary'
,p_parent_plug_id=>wwv_flow_imp.id(1143483181066268108)
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>4072358936313175081
,p_plug_display_sequence=>15
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'BEGIN',
'  FOR r IN (',
'    SELECT mc.config_code,',
'           ss.set_code AS src_code, ss.description AS src_desc,',
'           ts.set_code AS tgt_code, ts.description AS tgt_desc,',
'           (SELECT COUNT(*) FROM DMT_LOOKUP.DMT_COA_SEGMENT_DEF WHERE coa_set_id = mc.source_coa_set_id) src_segs,',
'           (SELECT COUNT(*) FROM DMT_LOOKUP.DMT_COA_SEGMENT_DEF WHERE coa_set_id = mc.target_coa_set_id) tgt_segs',
'    FROM DMT_LOOKUP.DMT_COA_MAP_CONFIG mc',
'    JOIN DMT_LOOKUP.DMT_COA_SET ss ON ss.coa_set_id = mc.source_coa_set_id',
'    JOIN DMT_LOOKUP.DMT_COA_SET ts ON ts.coa_set_id = mc.target_coa_set_id',
'    WHERE mc.config_code = :P32_CONFIG_CODE',
'  ) LOOP',
'    HTP.P(''<div style="padding:12px;background:#f7f9fc;border:1px solid #d8e0ec;border-radius:6px;margin-bottom:12px;">'');',
'    HTP.P(''<div style="font-weight:600;color:#1a3661;margin-bottom:6px;">Config: ''||r.config_code||'' &mdash; ''||r.src_desc||'' &rarr; ''||r.tgt_desc||''</div>'');',
'    HTP.P(''<div style="display:flex;gap:24px;font-size:13px;color:#3a5078;">'');',
'    HTP.P(''<div><b>Source:</b> ''||r.src_code||'' (''||r.src_segs||'' segments)</div>'');',
'    HTP.P(''<div><b>Target:</b> ''||r.tgt_code||'' (''||r.tgt_segs||'' segments)</div>'');',
'    HTP.P(''</div></div>'');',
'  END LOOP;',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1143483181066268108)
,p_plug_name=>'Segment Rules'
,p_static_id=>'segment-rules'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT sm.segment_map_id,',
'       sm.map_config_id,',
'       sm.source_segment_num,',
'       ssd.segment_name AS source_segment_name,',
'       sm.target_segment_num,',
'       tsd.segment_name AS target_segment_name,',
'       sm.mapping_rule,',
'       sm.default_value,',
'       sm.pad_length,',
'       sm.pad_char,',
'       sm.active_flag,',
'       sm.notes,',
'       NVL(sv.val_count, 0) AS value_map_count,',
'       NVL(sv.unmapped, 0)  AS unmapped_count',
'FROM DMT_COA_SEGMENT_MAP sm',
'JOIN DMT_COA_MAP_CONFIG mc ON mc.map_config_id = sm.map_config_id',
'LEFT JOIN DMT_COA_SEGMENT_DEF ssd',
'  ON ssd.coa_set_id = mc.source_coa_set_id AND ssd.segment_num = sm.source_segment_num',
'JOIN DMT_COA_SEGMENT_DEF tsd',
'  ON tsd.coa_set_id = mc.target_coa_set_id AND tsd.segment_num = sm.target_segment_num',
'LEFT JOIN (',
'    SELECT segment_map_id,',
'           COUNT(*) AS val_count,',
'           0 AS unmapped',
'    FROM DMT_COA_SEGMENT_VALUES',
'    WHERE active_flag = ''Y'' AND suggested_flag = ''N''',
'    GROUP BY segment_map_id',
') sv ON sv.segment_map_id = sm.segment_map_id',
'WHERE mc.config_code = :P32_CONFIG_CODE',
'  AND sm.active_flag = ''Y''',
'ORDER BY sm.target_segment_num, sm.source_segment_num NULLS LAST'))
,p_plug_source_type=>'NATIVE_IG'
,p_prn_page_header=>'Segment Rules'
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(1143494514805268141)
,p_name=>'ACTIVE_FLAG'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ACTIVE_FLAG'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Active Flag'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>110
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
 p_id=>wwv_flow_imp.id(1143491479584268132)
,p_name=>'DEFAULT_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DEFAULT_VALUE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Default Value'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>80
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
 p_id=>wwv_flow_imp.id(1143490506218268129)
,p_name=>'MAPPING_RULE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'MAPPING_RULE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Mapping Rule'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>70
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>true
,p_max_length=>30
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
 p_id=>wwv_flow_imp.id(1143485470167268115)
,p_name=>'MAP_CONFIG_ID'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'MAP_CONFIG_ID'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Map Config Id'
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
 p_id=>wwv_flow_imp.id(1143495462733268144)
,p_name=>'NOTES'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'NOTES'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Notes'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>120
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
 p_id=>wwv_flow_imp.id(1143493452473268139)
,p_name=>'PAD_CHAR'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'PAD_CHAR'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Pad Char'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>100
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
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
 p_id=>wwv_flow_imp.id(1143492469617268136)
,p_name=>'PAD_LENGTH'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'PAD_LENGTH'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Pad Length'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>90
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
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
 p_id=>wwv_flow_imp.id(1143484459182268112)
,p_name=>'SEGMENT_MAP_ID'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'SEGMENT_MAP_ID'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Segment Map Id'
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
 p_id=>wwv_flow_imp.id(1143487452120268121)
,p_name=>'SOURCE_SEGMENT_NAME'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'SOURCE_SEGMENT_NAME'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Source Segment Name'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>40
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
 p_id=>wwv_flow_imp.id(1143486445822268118)
,p_name=>'SOURCE_SEGMENT_NUM'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'SOURCE_SEGMENT_NUM'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Source Segment Num'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>30
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
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
 p_id=>wwv_flow_imp.id(1143489463511268126)
,p_name=>'TARGET_SEGMENT_NAME'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TARGET_SEGMENT_NAME'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Target Segment Name'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>60
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
 p_id=>wwv_flow_imp.id(1143488469192268124)
,p_name=>'TARGET_SEGMENT_NUM'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TARGET_SEGMENT_NUM'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Target Segment Num'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>50
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
 p_id=>wwv_flow_imp.id(1143497454112268150)
,p_name=>'UNMAPPED_COUNT'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'UNMAPPED_COUNT'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Unmapped Count'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>140
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
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
 p_id=>wwv_flow_imp.id(1143496478797268147)
,p_name=>'VALUE_MAP_COUNT'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'VALUE_MAP_COUNT'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_LINK'
,p_heading=>'Value Map Count'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>130
,p_value_alignment=>'RIGHT'
,p_link_target=>'f?p=&APP_ID.:33:&SESSION.::&DEBUG.:Y,33:P33_SEGMENT_MAP_ID:&SEGMENT_MAP_ID.'
,p_link_text=>'&VALUE_MAP_COUNT.'
,p_enable_filter=>true
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
,p_escape_on_http_output=>true
);
wwv_flow_imp_page.create_interactive_grid(
 p_id=>wwv_flow_imp.id(1143483679115268110)
,p_internal_uid=>50034943498921533
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
 p_id=>wwv_flow_imp.id(1143484044956268111)
,p_interactive_grid_id=>wwv_flow_imp.id(1143483679115268110)
,p_static_id=>'500354'
,p_type=>'PRIMARY'
,p_default_view=>'GRID'
,p_show_row_number=>false
,p_settings_area_expanded=>true
);
wwv_flow_imp_page.create_ig_report_view(
 p_id=>wwv_flow_imp.id(1143484307437268111)
,p_report_id=>wwv_flow_imp.id(1143484044956268111)
,p_view_type=>'GRID'
,p_stretch_columns=>true
,p_srv_exclude_null_values=>false
,p_srv_only_display_columns=>true
,p_edit_mode=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143484851307268113)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>1
,p_column_id=>wwv_flow_imp.id(1143484459182268112)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143485909389268116)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>2
,p_column_id=>wwv_flow_imp.id(1143485470167268115)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143486855819268119)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>3
,p_column_id=>wwv_flow_imp.id(1143486445822268118)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143487921382268122)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>4
,p_column_id=>wwv_flow_imp.id(1143487452120268121)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143488857924268125)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>5
,p_column_id=>wwv_flow_imp.id(1143488469192268124)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143489864828268127)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>6
,p_column_id=>wwv_flow_imp.id(1143489463511268126)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143490847920268130)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>7
,p_column_id=>wwv_flow_imp.id(1143490506218268129)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143491875137268133)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>8
,p_column_id=>wwv_flow_imp.id(1143491479584268132)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143492926857268137)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>9
,p_column_id=>wwv_flow_imp.id(1143492469617268136)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143493836241268140)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>10
,p_column_id=>wwv_flow_imp.id(1143493452473268139)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143494918888268142)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>11
,p_column_id=>wwv_flow_imp.id(1143494514805268141)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143495851828268145)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>12
,p_column_id=>wwv_flow_imp.id(1143495462733268144)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143496889549268148)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>13
,p_column_id=>wwv_flow_imp.id(1143496478797268147)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(1143497836841268151)
,p_view_id=>wwv_flow_imp.id(1143484307437268111)
,p_display_seq=>14
,p_column_id=>wwv_flow_imp.id(1143497454112268150)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143070647604835798)
,p_button_sequence=>40
,p_button_plug_id=>wwv_flow_imp.id(1143483181066268108)
,p_button_name=>'CLEAR_GENERATED'
,p_static_id=>'clear-generated'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Clear Generated'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143070499139835796)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(1143483181066268108)
,p_button_name=>'GENERATE_MAPPINGS'
,p_static_id=>'generate-mappings'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Generate Mappings'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143070603288835797)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(1143483181066268108)
,p_button_name=>'VALIDATE_MAPPINGS'
,p_static_id=>'validate-mappings'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Validate Mappings'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1143070399650835795)
,p_name=>'P32_CONFIG_CODE'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1143483181066268108)
,p_prompt=>'Mapping Config'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>unistr('SELECT config_code || '' \2014 '' || description AS d, config_code AS r FROM DMT_COA_MAP_CONFIG WHERE active_flag = ''Y'' ORDER BY config_code')
,p_lov_display_null=>'YES'
,p_cHeight=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'execute_validations', 'Y',
  'page_action_on_selection', 'SUBMIT')).to_clob
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143070960082835801)
,p_process_sequence=>30
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Clear Generated'
,p_static_id=>'clear-generated'
,p_process_sql_clob=>'BEGIN DMT_COA_MAP_PKG.CLEAR_GENERATED(:P32_CONFIG_CODE); APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE := ''Generated mappings cleared for '' || :P32_CONFIG_CODE; END;'
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143070647604835798)
,p_internal_uid=>49622224466489224
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143070823482835799)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Generate Mappings'
,p_static_id=>'generate-mappings'
,p_process_sql_clob=>'DECLARE v_cnt NUMBER; BEGIN v_cnt := DMT_COA_MAP_PKG.GENERATE_MAPPINGS(:P32_CONFIG_CODE); APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE := v_cnt || '' mappings generated for '' || :P32_CONFIG_CODE; END;'
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143070499139835796)
,p_internal_uid=>49622087866489222
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143070883487835800)
,p_process_sequence=>20
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Validate Mappings'
,p_static_id=>'validate-mappings'
,p_process_sql_clob=>'DECLARE v_cnt NUMBER; BEGIN v_cnt := DMT_COA_MAP_PKG.VALIDATE_MAPPINGS(:P32_CONFIG_CODE); APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE := v_cnt || '' invalid mappings flagged for '' || :P32_CONFIG_CODE; END;'
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143070603288835797)
,p_internal_uid=>49622147871489223
);
wwv_flow_imp.component_end;
end;
/
