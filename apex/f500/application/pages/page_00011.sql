prompt --application/pages/page_00011
begin
--   Manifest
--     PAGE: 00011
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
 p_id=>11
,p_name=>'HCM Payroll'
,p_alias=>'HCM-PAYROLL'
,p_step_title=>'HCM Payroll'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1583040764157576254)
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
 p_id=>wwv_flow_imp.id(1574405135599473360)
,p_plug_name=>'Bulk Upload'
,p_static_id=>'bulk-upload'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>999
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1453490890194939084)
,p_plug_name=>'Tax Calculation Cards'
,p_static_id=>'tax-calculation-cards'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>40
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_V_TAX_CARD_DETAIL WHERE (:P0_SCENARIO_ID IS NULL OR SCENARIO_ID = :P0_SCENARIO_ID)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
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
,p_ai_enabled=>false
,p_plug_comment=>'Tax Calculation Cards'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1415843297662506818)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>39797818802256335
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844229682506827)
,p_db_column_name=>'COMPONENT_GROUP_NAME'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Component Group Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844055887506825)
,p_db_column_name=>'DIRECTIVE_CARD_NAME'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Directive Card Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415843782121506823)
,p_db_column_name=>'EFFECTIVE_END_DATE'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Effective End Date'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415843747505506822)
,p_db_column_name=>'EFFECTIVE_START_DATE'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Effective Start Date'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415843494736506820)
,p_db_column_name=>'ERROR_TEXT'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Error Text'
,p_allow_sorting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_column_type=>'CLOB'
,p_heading_alignment=>'LEFT'
,p_rpt_show_filter_lov=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844958912506684)
,p_db_column_name=>'LAST_UPDATED_DATE'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Last Updated Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415843879804506824)
,p_db_column_name=>'LEGISLATIVE_DATA_GROUP_NAME'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Legislative Data Group Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415843619192506821)
,p_db_column_name=>'PERSON_NUMBER'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Person Number'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844630761506831)
,p_db_column_name=>'PREFIX'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Prefix'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844531910506830)
,p_db_column_name=>'RUN_ID'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Run Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415843458410506819)
,p_db_column_name=>'RUN_STATUS'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Run Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844710457506832)
,p_db_column_name=>'SCENARIO_ID'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Scenario Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844331766506828)
,p_db_column_name=>'SOURCE_ID'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Source Id'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844784826506833)
,p_db_column_name=>'STAGE_DATE'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Stage Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844433768506829)
,p_db_column_name=>'STG_SEQUENCE_ID'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Stg Sequence Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415844147808506826)
,p_db_column_name=>'TAX_REPORTING_UNIT'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Tax Reporting Unit'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1193224658028637898)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'497663'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'RUN_STATUS:ERROR_TEXT:PERSON_NUMBER:EFFECTIVE_START_DATE:EFFECTIVE_END_DATE:LEGISLATIVE_DATA_GROUP_NAME:DIRECTIVE_CARD_NAME:TAX_REPORTING_UNIT:COMPONENT_GROUP_NAME:SOURCE_ID:STG_SEQUENCE_ID:RUN_ID:PREFIX:SCENARIO_ID:STAGE_DATE:LAST_UPDATED_DATE'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1453491073034939085)
,p_plug_name=>'Tax Card Components'
,p_static_id=>'tax-card-components'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>50
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_V_TAX_CARD_COMP_DETAIL WHERE (:P0_SCENARIO_ID IS NULL OR SCENARIO_ID = :P0_SCENARIO_ID)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
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
,p_ai_enabled=>false
,p_plug_comment=>'Tax Card Components'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1415845026351506685)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>39799547491256202
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845382460506689)
,p_db_column_name=>'COMPONENT_NAME'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Component Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845501994506690)
,p_db_column_name=>'COMPONENT_VALUE'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Component Value'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845942652506694)
,p_db_column_name=>'DIRECTIVE_CARD_NAME'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Directive Card Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845749258506692)
,p_db_column_name=>'EFFECTIVE_END_DATE'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Effective End Date'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845584875506691)
,p_db_column_name=>'EFFECTIVE_START_DATE'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Effective Start Date'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845269714506687)
,p_db_column_name=>'ERROR_TEXT'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Error Text'
,p_allow_sorting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_column_type=>'CLOB'
,p_heading_alignment=>'LEFT'
,p_rpt_show_filter_lov=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846750729506702)
,p_db_column_name=>'LAST_UPDATED_DATE'
,p_display_order=>170
,p_column_identifier=>'Q'
,p_column_label=>'Last Updated Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845832904506693)
,p_db_column_name=>'LEGISLATIVE_DATA_GROUP_NAME'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Legislative Data Group Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845309272506688)
,p_db_column_name=>'PERSON_NUMBER'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Person Number'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846432374506699)
,p_db_column_name=>'PREFIX'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Prefix'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846332756506698)
,p_db_column_name=>'RUN_ID'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Run Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415845099514506686)
,p_db_column_name=>'RUN_STATUS'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Run Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846497938506700)
,p_db_column_name=>'SCENARIO_ID'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Scenario Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846170123506696)
,p_db_column_name=>'SOURCE_ID'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Source Id'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846657328506701)
,p_db_column_name=>'STAGE_DATE'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Stage Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846238714506697)
,p_db_column_name=>'STG_SEQUENCE_ID'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Stg Sequence Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415846040187506695)
,p_db_column_name=>'TAX_REPORTING_UNIT'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Tax Reporting Unit'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1193225226220637907)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'497669'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'RUN_STATUS:ERROR_TEXT:PERSON_NUMBER:COMPONENT_NAME:COMPONENT_VALUE:EFFECTIVE_START_DATE:EFFECTIVE_END_DATE:LEGISLATIVE_DATA_GROUP_NAME:DIRECTIVE_CARD_NAME:TAX_REPORTING_UNIT:SOURCE_ID:STG_SEQUENCE_ID:RUN_ID:PREFIX:SCENARIO_ID:STAGE_DATE:LAST_UPDATED_'
||'DATE'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1453490743022939082)
,p_plug_name=>'W-2 Balance Details'
,p_static_id=>'w-2-balance-details'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_V_W2_BAL_DTL_DETAIL WHERE (:P0_SCENARIO_ID IS NULL OR SCENARIO_ID = :P0_SCENARIO_ID)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
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
,p_ai_enabled=>false
,p_plug_comment=>'W-2 Balance Details'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1415809056009515930)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>39763577149265447
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415839900568506784)
,p_db_column_name=>'BALANCE_NAME'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Balance Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840094027506786)
,p_db_column_name=>'CONTEXT_NAME'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Context Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840222915506787)
,p_db_column_name=>'CONTEXT_VALUE'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Context Value'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840475607506789)
,p_db_column_name=>'CURRENCY_CODE'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Currency Code'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415839985023506785)
,p_db_column_name=>'DIMENSION_NAME'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Dimension Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415809194686515932)
,p_db_column_name=>'ERROR_TEXT'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Error Text'
,p_allow_sorting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_column_type=>'CLOB'
,p_heading_alignment=>'LEFT'
,p_rpt_show_filter_lov=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415841467186506799)
,p_db_column_name=>'LAST_UPDATED_DATE'
,p_display_order=>190
,p_column_identifier=>'S'
,p_column_label=>'Last Updated Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840580499506791)
,p_db_column_name=>'LEGAL_EMPLOYER_NAME'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Legal Employer Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840566258506790)
,p_db_column_name=>'LEGISLATIVE_DATA_GROUP_NAME'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Legislative Data Group Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840735849506792)
,p_db_column_name=>'PAYROLL_RELATIONSHIP_NUMBER'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Payroll Relationship Number'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415809346605515933)
,p_db_column_name=>'PERSON_NUMBER'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Person Number'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415841171700506796)
,p_db_column_name=>'PREFIX'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Prefix'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415841048111506795)
,p_db_column_name=>'RUN_ID'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Run Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415809079813515931)
,p_db_column_name=>'RUN_STATUS'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Run Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415841191935506797)
,p_db_column_name=>'SCENARIO_ID'
,p_display_order=>170
,p_column_identifier=>'Q'
,p_column_label=>'Scenario Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840877692506793)
,p_db_column_name=>'SOURCE_ID'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Source Id'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415841376744506798)
,p_db_column_name=>'STAGE_DATE'
,p_display_order=>180
,p_column_identifier=>'R'
,p_column_label=>'Stage Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840887167506794)
,p_db_column_name=>'STG_SEQUENCE_ID'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Stg Sequence Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415840352931506788)
,p_db_column_name=>'VALUE'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Value'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1193223553147637859)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'497652'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'RUN_STATUS:ERROR_TEXT:PERSON_NUMBER:BALANCE_NAME:DIMENSION_NAME:CONTEXT_NAME:CONTEXT_VALUE:VALUE:CURRENCY_CODE:LEGISLATIVE_DATA_GROUP_NAME:LEGAL_EMPLOYER_NAME:PAYROLL_RELATIONSHIP_NUMBER:SOURCE_ID:STG_SEQUENCE_ID:RUN_ID:PREFIX:SCENARIO_ID:STAGE_DATE:'
||'LAST_UPDATED_DATE'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1453490645791939081)
,p_plug_name=>'W-2 Balances'
,p_static_id=>'w-2-balances'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT * FROM DMT_V_W2_BAL_DETAIL WHERE (:P0_SCENARIO_ID IS NULL OR SCENARIO_ID = :P0_SCENARIO_ID)'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
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
,p_ai_enabled=>false
,p_plug_comment=>'W-2 Balances'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1415807374758515913)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>39761895898265430
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808042371515920)
,p_db_column_name=>'CONSOLIDATION_GROUP_NAME'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Consolidation Group Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808101197515921)
,p_db_column_name=>'EFFECTIVE_DATE'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Effective Date'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415807531431515915)
,p_db_column_name=>'ERROR_TEXT'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Error Text'
,p_allow_sorting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_column_type=>'CLOB'
,p_heading_alignment=>'LEFT'
,p_rpt_show_filter_lov=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808898964515929)
,p_db_column_name=>'LAST_UPDATED_DATE'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Last Updated Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415807726442515917)
,p_db_column_name=>'LEGAL_EMPLOYER_NAME'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Legal Employer Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808213165515922)
,p_db_column_name=>'LEGISLATIVE_DATA_GROUP_NAME'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Legislative Data Group Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415807919805515919)
,p_db_column_name=>'PAYROLL_NAME'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Payroll Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415807834887515918)
,p_db_column_name=>'PAYROLL_RELATIONSHIP_NUMBER'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Payroll Relationship Number'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415807636946515916)
,p_db_column_name=>'PERSON_NUMBER'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Person Number'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808649102515926)
,p_db_column_name=>'PREFIX'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Prefix'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808532739515925)
,p_db_column_name=>'RUN_ID'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Run Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415807385269515914)
,p_db_column_name=>'RUN_STATUS'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Run Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808772599515927)
,p_db_column_name=>'SCENARIO_ID'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Scenario Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808347513515923)
,p_db_column_name=>'SOURCE_ID'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Source Id'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808830286515928)
,p_db_column_name=>'STAGE_DATE'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Stage Date'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1415808417564515924)
,p_db_column_name=>'STG_SEQUENCE_ID'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Stg Sequence Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1193223067115637809)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'497647'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'RUN_STATUS:ERROR_TEXT:PERSON_NUMBER:LEGAL_EMPLOYER_NAME:PAYROLL_RELATIONSHIP_NUMBER:PAYROLL_NAME:CONSOLIDATION_GROUP_NAME:EFFECTIVE_DATE:LEGISLATIVE_DATA_GROUP_NAME:SOURCE_ID:STG_SEQUENCE_ID:RUN_ID:PREFIX:SCENARIO_ID:STAGE_DATE:LAST_UPDATED_DATE'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1574405390349473363)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(1574405135599473360)
,p_button_name=>'UPLOAD_CSV'
,p_static_id=>'upload-csv'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Upload CSV'
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(989176812264730614)
,p_name=>'P11_SCENARIO'
,p_item_sequence=>15
,p_item_plug_id=>wwv_flow_imp.id(1574405135599473360)
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
 p_id=>wwv_flow_imp.id(1574405280128473362)
,p_name=>'P11_UPLOAD_FILE'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(1574405135599473360)
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
 p_id=>wwv_flow_imp.id(1574405162042473361)
,p_name=>'P11_UPLOAD_OBJECT'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1574405135599473360)
,p_prompt=>'Target Object'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT DISPLAY_NAME d, OBJECT_CODE r',
'FROM DMT_UPLOAD_OBJECT_TBL',
'WHERE PAGE_NUMBER = 11 AND IS_ACTIVE = ''Y''',
'ORDER BY DISPLAY_ORDER'))
,p_lov_display_null=>'YES'
,p_cHeight=>1
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1583202216791305337)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Upload CSV'
,p_static_id=>'upload-csv'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    l_rows_loaded  NUMBER;',
'    l_rows_errored NUMBER;',
'    l_batch_id     NUMBER;',
'    l_error_msg    VARCHAR2(4000);',
'BEGIN',
'    DMT_CSV_UPLOAD_PKG.UPLOAD_CSV(',
'        p_file_name    => :P11_UPLOAD_FILE,',
'        p_object_code  => :P11_UPLOAD_OBJECT,',
'        p_rows_loaded  => l_rows_loaded,',
'        p_rows_errored => l_rows_errored,',
'        p_batch_id_out => l_batch_id,',
'        p_error_msg     => l_error_msg,',
'        p_scenario_name => :P11_SCENARIO',
'    );',
'    IF l_error_msg IS NOT NULL THEN',
'        APEX_ERROR.ADD_ERROR(p_message => l_error_msg, p_display_location => ''INLINE_IN_NOTIFICATION'');',
'    ELSE',
'        APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE :=',
'            l_rows_loaded || '' rows loaded, '' || l_rows_errored || '' errors. Batch ID: '' || l_batch_id;',
'    END IF;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1574405390349473363)
,p_internal_uid=>22378974261102612
);
wwv_flow_imp.component_end;
end;
/
