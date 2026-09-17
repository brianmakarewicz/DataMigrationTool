prompt --application/pages/page_00019
begin
--   Manifest
--     PAGE: 00019
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
 p_id=>19
,p_name=>'Fusion Values'
,p_alias=>'FUSION-VALUES'
,p_step_title=>'Fusion Values'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1291292622847584591)
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
 p_id=>wwv_flow_imp.id(1291293236235584593)
,p_plug_name=>'Fusion Values'
,p_static_id=>'fusion-values'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT f.fusion_value_id, f.lookup_type, f.fusion_value, f.fusion_description, f.fusion_id, f.active_flag, f.last_refresh_date, (SELECT COUNT(*) FROM DMT_LOOKUP.DMT_LKP_MAPPING m WHERE m.lookup_type = f.lookup_type AND m.fusion_value = f.fusion_value'
||' AND m.active_flag = ''Y'') AS mapped_from_count FROM DMT_LOOKUP.DMT_LKP_FUSION_VALUES f WHERE f.active_flag = ''Y'' AND (NVL(:P19_LOOKUP_TYPE, ''%'') = ''%'' OR f.lookup_type = :P19_LOOKUP_TYPE)'
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P19_LOOKUP_TYPE'
,p_prn_page_header=>'Fusion Values'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1291293312896584593)
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
,p_internal_uid=>49031944905862904
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291295982554584603)
,p_db_column_name=>'ACTIVE_FLAG'
,p_display_order=>6
,p_column_identifier=>'F'
,p_column_label=>'Active Flag'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291295259278584601)
,p_db_column_name=>'FUSION_DESCRIPTION'
,p_display_order=>4
,p_column_identifier=>'D'
,p_column_label=>'Fusion Description'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291295571820584602)
,p_db_column_name=>'FUSION_ID'
,p_display_order=>5
,p_column_identifier=>'E'
,p_column_label=>'Fusion Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291294781442584599)
,p_db_column_name=>'FUSION_VALUE'
,p_display_order=>3
,p_column_identifier=>'C'
,p_column_label=>'Fusion Value'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291294005037584596)
,p_db_column_name=>'FUSION_VALUE_ID'
,p_display_order=>1
,p_column_identifier=>'A'
,p_column_label=>'Fusion Value Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291296416961584605)
,p_db_column_name=>'LAST_REFRESH_DATE'
,p_display_order=>7
,p_column_identifier=>'G'
,p_column_label=>'Last Refresh Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291294419038584598)
,p_db_column_name=>'LOOKUP_TYPE'
,p_display_order=>2
,p_column_identifier=>'B'
,p_column_label=>'Lookup Type'
,p_column_link=>'f?p=&APP_ID.:17:&SESSION.::&DEBUG.:Y,17:P17_LOOKUP_TYPE:#LOOKUP_TYPE#'
,p_column_linktext=>'#LOOKUP_TYPE#'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291296845260584606)
,p_db_column_name=>'MAPPED_FROM_COUNT'
,p_display_order=>8
,p_column_identifier=>'H'
,p_column_label=>'Mapped From Count'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1291308940329673549)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'490476'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'FUSION_VALUE_ID:LOOKUP_TYPE:FUSION_VALUE:FUSION_DESCRIPTION:FUSION_ID:ACTIVE_FLAG:LAST_REFRESH_DATE:MAPPED_FROM_COUNT'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1192511267726222509)
,p_name=>'P19_LOOKUP_TYPE'
,p_item_sequence=>1
,p_item_plug_id=>wwv_flow_imp.id(1291293236235584593)
,p_prompt=>'Lookup Type'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT lookup_type || '' -- '' || description AS d, lookup_type AS r FROM DMT_LOOKUP.DMT_LKP_TYPE_CONFIG WHERE active_flag = ''Y'' ORDER BY module, lookup_type'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'- All Lookup Types -'
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
