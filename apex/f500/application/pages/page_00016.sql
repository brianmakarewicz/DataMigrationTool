prompt --application/pages/page_00016
begin
--   Manifest
--     PAGE: 00016
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
 p_id=>16
,p_name=>'Lookup Dashboard'
,p_alias=>'LOOKUP-DASHBOARD'
,p_step_title=>'Lookup Dashboard'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1291268611921476419)
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
 p_id=>wwv_flow_imp.id(1291269280763476427)
,p_plug_name=>'Lookup Dashboard'
,p_static_id=>'lookup-dashboard'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT tc.lookup_type, tc.description, tc.module,',
'       NVL(e.ebs_count, 0) AS ebs_values,',
'       NVL(f.fusion_count, 0) AS fusion_values,',
'       NVL(m.mapped_count, 0) AS mapped,',
'       NVL(e.ebs_count, 0) - NVL(m.mapped_count, 0) AS unmapped,',
'       NVL(u.unmatched_count, 0) AS no_fusion_equivalent,',
'       NVL(s.suggested_count, 0) AS pending_suggestions,',
'       CASE WHEN NVL(e.ebs_count, 0) = 0 THEN ''No EBS Data''',
'            WHEN NVL(m.mapped_count, 0) >= NVL(e.ebs_count, 0) THEN ''Complete''',
'            WHEN NVL(m.mapped_count, 0) > 0 THEN ''In Progress''',
'            ELSE ''Not Started'' END AS status,',
'       ROUND(NVL(m.mapped_count, 0) / NULLIF(NVL(e.ebs_count, 0), 0) * 100) AS pct_complete,',
'       tc.default_fusion_value,',
'       tc.active_flag',
'FROM DMT_LOOKUP.DMT_LKP_TYPE_CONFIG tc',
'LEFT JOIN (SELECT lookup_type, COUNT(*) AS ebs_count FROM DMT_LOOKUP.DMT_LKP_EBS_VALUES WHERE active_flag = ''Y'' GROUP BY lookup_type) e ON e.lookup_type = tc.lookup_type',
'LEFT JOIN (SELECT lookup_type, COUNT(*) AS fusion_count FROM DMT_LOOKUP.DMT_LKP_FUSION_VALUES WHERE active_flag = ''Y'' GROUP BY lookup_type) f ON f.lookup_type = tc.lookup_type',
'LEFT JOIN (SELECT lookup_type, COUNT(*) AS mapped_count FROM DMT_LOOKUP.DMT_LKP_MAPPING WHERE active_flag = ''Y'' AND NVL(suggested_flag,''N'') = ''N'' GROUP BY lookup_type) m ON m.lookup_type = tc.lookup_type',
'LEFT JOIN (SELECT e2.lookup_type, COUNT(*) AS unmatched_count FROM DMT_LOOKUP.DMT_LKP_EBS_VALUES e2 WHERE e2.active_flag = ''Y'' AND NOT EXISTS (SELECT 1 FROM DMT_LOOKUP.DMT_LKP_FUSION_VALUES f2 WHERE f2.lookup_type = e2.lookup_type AND UPPER(f2.fusion'
||'_value) = UPPER(e2.ebs_value) AND f2.active_flag = ''Y'') GROUP BY e2.lookup_type) u ON u.lookup_type = tc.lookup_type',
'LEFT JOIN (SELECT lookup_type, COUNT(*) AS suggested_count FROM DMT_LOOKUP.DMT_LKP_MAPPING WHERE suggested_flag = ''Y'' AND active_flag = ''N'' GROUP BY lookup_type) s ON s.lookup_type = tc.lookup_type',
'ORDER BY tc.module, tc.lookup_type'))
,p_plug_source_type=>'NATIVE_IR'
,p_prn_page_header=>'Lookup Dashboard'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1291269387700476427)
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
,p_internal_uid=>49008019709754738
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291273728304476445)
,p_db_column_name=>'ACTIVE_FLAG'
,p_display_order=>10
,p_column_identifier=>'J'
,p_column_label=>'Active Flag'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1242109173776244499)
,p_db_column_name=>'DEFAULT_FUSION_VALUE'
,p_display_order=>40
,p_column_identifier=>'M'
,p_column_label=>'Default Fusion Value'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291270502764476436)
,p_db_column_name=>'DESCRIPTION'
,p_display_order=>2
,p_column_identifier=>'B'
,p_column_label=>'Description'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291271345040476438)
,p_db_column_name=>'EBS_VALUES'
,p_display_order=>4
,p_column_identifier=>'D'
,p_column_label=>'Ebs Values'
,p_column_link=>'f?p=&APP_ID.:18:&SESSION.::&DEBUG.:18:P18_LOOKUP_TYPE:&LOOKUP_TYPE.'
,p_column_linktext=>'#EBS_VALUES#'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291271680610476439)
,p_db_column_name=>'FUSION_VALUES'
,p_display_order=>5
,p_column_identifier=>'E'
,p_column_label=>'Fusion Values'
,p_column_link=>'f?p=&APP_ID.:19:&SESSION.::&DEBUG.:19:P19_LOOKUP_TYPE:&LOOKUP_TYPE.'
,p_column_linktext=>'#FUSION_VALUES#'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291270144423476434)
,p_db_column_name=>'LOOKUP_TYPE'
,p_display_order=>1
,p_column_identifier=>'A'
,p_column_label=>'Lookup Type'
,p_column_link=>'f?p=&APP_ID.:17:&APP_SESSION.:::17:P17_LOOKUP_TYPE:#LOOKUP_TYPE#'
,p_column_linktext=>'#LOOKUP_TYPE#'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291272158583476440)
,p_db_column_name=>'MAPPED'
,p_display_order=>6
,p_column_identifier=>'F'
,p_column_label=>'Mapped'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291270889857476437)
,p_db_column_name=>'MODULE'
,p_display_order=>3
,p_column_identifier=>'C'
,p_column_label=>'Module'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1242109025392244497)
,p_db_column_name=>'NO_FUSION_EQUIVALENT'
,p_display_order=>20
,p_column_identifier=>'K'
,p_column_label=>'No Fusion Equivalent'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291273354839476444)
,p_db_column_name=>'PCT_COMPLETE'
,p_display_order=>9
,p_column_identifier=>'I'
,p_column_label=>'Pct Complete'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1242109086186244498)
,p_db_column_name=>'PENDING_SUGGESTIONS'
,p_display_order=>30
,p_column_identifier=>'L'
,p_column_label=>'Pending Suggestions'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291272904307476443)
,p_db_column_name=>'STATUS'
,p_display_order=>8
,p_column_identifier=>'H'
,p_column_label=>'Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1291272471987476441)
,p_db_column_name=>'UNMAPPED'
,p_display_order=>7
,p_column_identifier=>'G'
,p_column_label=>'Unmapped'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1291307601099664104)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'490463'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'LOOKUP_TYPE:DESCRIPTION:MODULE:EBS_VALUES:FUSION_VALUES:MAPPED:UNMAPPED:STATUS:PCT_COMPLETE:ACTIVE_FLAG'
);
wwv_flow_imp.component_end;
end;
/
