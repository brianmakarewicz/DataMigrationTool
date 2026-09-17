prompt --application/pages/page_00018
begin
--   Manifest
--     PAGE: 00018
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
 p_id=>18
,p_name=>'EBS Values'
,p_alias=>'EBS-VALUES'
,p_step_title=>'EBS Values'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1291287366029576060)
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
 p_id=>wwv_flow_imp.id(1291288021738576063)
,p_plug_name=>'EBS Values'
,p_static_id=>'ebs-values'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT e.ebs_value_id, e.lookup_type, e.ebs_value, e.ebs_description, e.ebs_id, e.active_flag, e.last_refresh_date, m.fusion_value AS mapped_to FROM DMT_LOOKUP.DMT_LKP_EBS_VALUES e LEFT JOIN DMT_LOOKUP.DMT_LKP_MAPPING m ON m.lookup_type = e.lookup_ty'
||'pe AND m.ebs_value = e.ebs_value AND m.active_flag = ''Y'' WHERE e.active_flag = ''Y'' AND (NVL(:P18_LOOKUP_TYPE, ''%'') = ''%'' OR e.lookup_type = :P18_LOOKUP_TYPE) AND (NVL(:P18_UNMATCHED_ONLY,''N'') = ''N'' OR NOT EXISTS (SELECT 1 FROM DMT_LOOKUP.DMT_LKP_FUSI'
||'ON_VALUES f WHERE f.lookup_type = e.lookup_type AND UPPER(f.fusion_value) = UPPER(e.ebs_value) AND f.active_flag = ''Y''))'
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P18_UNMATCHED_ONLY,P18_LOOKUP_TYPE'
,p_prn_page_header=>'EBS Values'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1291288077915576063)
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
,p_internal_uid=>49026709924854374
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291290795843576072)
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
 p_id=>wwv_flow_imp.id(1291289983939576070)
,p_db_column_name=>'EBS_DESCRIPTION'
,p_display_order=>4
,p_column_identifier=>'D'
,p_column_label=>'Ebs Description'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291290467249576071)
,p_db_column_name=>'EBS_ID'
,p_display_order=>5
,p_column_identifier=>'E'
,p_column_label=>'Ebs Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291289618563576069)
,p_db_column_name=>'EBS_VALUE'
,p_display_order=>3
,p_column_identifier=>'C'
,p_column_label=>'Ebs Value'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291288834075576066)
,p_db_column_name=>'EBS_VALUE_ID'
,p_display_order=>1
,p_column_identifier=>'A'
,p_column_label=>'Ebs Value Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291291224597576074)
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
 p_id=>wwv_flow_imp.id(1291289212954576068)
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
 p_id=>wwv_flow_imp.id(1291291579615576075)
,p_db_column_name=>'MAPPED_TO'
,p_display_order=>8
,p_column_identifier=>'H'
,p_column_label=>'Mapped To'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1291308303664669851)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'490470'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'EBS_VALUE_ID:LOOKUP_TYPE:EBS_VALUE:EBS_DESCRIPTION:EBS_ID:ACTIVE_FLAG:LAST_REFRESH_DATE:MAPPED_TO'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1192511140745222508)
,p_name=>'P18_LOOKUP_TYPE'
,p_item_sequence=>1
,p_item_plug_id=>wwv_flow_imp.id(1291288021738576063)
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
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1242109353913244501)
,p_name=>'P18_UNMATCHED_ONLY'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1291288021738576063)
,p_item_default=>'N'
,p_prompt=>'Show only values with no Fusion equivalent'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_YES_NO'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1242109484978244502)
,p_name=>'New'
,p_static_id=>'new'
,p_event_sequence=>10
,p_triggering_element_type=>'ITEM'
,p_triggering_element=>'P18_UNMATCHED_ONLY'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'change'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1242109607080244503)
,p_event_id=>wwv_flow_imp.id(1242109484978244502)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-refresh'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(1291288021738576063)
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'maintain_pagination', 'N')).to_clob
);
wwv_flow_imp.component_end;
end;
/
