prompt --application/pages/page_00030
begin
--   Manifest
--     PAGE: 00030
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
 p_id=>30
,p_name=>'COA Dashboard'
,p_alias=>'COA-DASHBOARD'
,p_step_title=>'COA Dashboard'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1143463909254236796)
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
 p_id=>wwv_flow_imp.id(1143464557405236805)
,p_plug_name=>'COA Dashboard'
,p_static_id=>'coa-dashboard'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT mc.config_code,',
'       mc.description,',
'       src.set_code     AS source_coa,',
'       src.ledger_name  AS source_ledger,',
'       tgt.set_code     AS target_coa,',
'       tgt.ledger_name  AS target_ledger,',
'       NVL(sc.src_count, 0)  AS source_combos,',
'       NVL(mm.map_count, 0)  AS mapped,',
'       NVL(sc.src_count, 0) - NVL(mm.map_count, 0) AS unmapped,',
'       CASE',
'           WHEN NVL(sc.src_count, 0) = 0 THEN ''No Source Data''',
'           WHEN NVL(mm.map_count, 0) >= NVL(sc.src_count, 0) THEN ''Complete''',
'           WHEN NVL(mm.map_count, 0) > 0 THEN ''In Progress''',
'           ELSE ''Not Started''',
'       END AS status,',
'       ROUND(NVL(mm.map_count, 0) / NULLIF(NVL(sc.src_count, 0), 0) * 100) AS pct_complete,',
'       mc.active_flag',
'FROM DMT_COA_MAP_CONFIG mc',
'JOIN DMT_COA_SET src ON src.coa_set_id = mc.source_coa_set_id',
'JOIN DMT_COA_SET tgt ON tgt.coa_set_id = mc.target_coa_set_id',
'LEFT JOIN (',
'    SELECT coa_set_id, COUNT(*) AS src_count',
'    FROM DMT_COA_SOURCE_COMBOS WHERE enabled_flag = ''Y''',
'    GROUP BY coa_set_id',
') sc ON sc.coa_set_id = mc.source_coa_set_id',
'LEFT JOIN (',
'    SELECT map_config_id, COUNT(*) AS map_count',
'    FROM DMT_COA_MAPPING WHERE active_flag = ''Y''',
'    GROUP BY map_config_id',
') mm ON mm.map_config_id = mc.map_config_id',
'ORDER BY mc.config_code'))
,p_plug_source_type=>'NATIVE_IR'
,p_prn_page_header=>'COA Dashboard'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1143464678696236805)
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
,p_internal_uid=>50015943079890228
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143469788755236824)
,p_db_column_name=>'ACTIVE_FLAG'
,p_display_order=>12
,p_column_identifier=>'L'
,p_column_label=>'Active Flag'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143465360942236811)
,p_db_column_name=>'CONFIG_CODE'
,p_display_order=>1
,p_column_identifier=>'A'
,p_column_label=>'Config Code'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143465784679236813)
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
 p_id=>wwv_flow_imp.id(1143468198548236820)
,p_db_column_name=>'MAPPED'
,p_display_order=>8
,p_column_identifier=>'H'
,p_column_label=>'Mapped'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143469412217236823)
,p_db_column_name=>'PCT_COMPLETE'
,p_display_order=>11
,p_column_identifier=>'K'
,p_column_label=>'Pct Complete'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143466136912236814)
,p_db_column_name=>'SOURCE_COA'
,p_display_order=>3
,p_column_identifier=>'C'
,p_column_label=>'Source Coa'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143467800210236819)
,p_db_column_name=>'SOURCE_COMBOS'
,p_display_order=>7
,p_column_identifier=>'G'
,p_column_label=>'Source Combos'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143466618267236816)
,p_db_column_name=>'SOURCE_LEDGER'
,p_display_order=>4
,p_column_identifier=>'D'
,p_column_label=>'Source Ledger'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143469022070236822)
,p_db_column_name=>'STATUS'
,p_display_order=>10
,p_column_identifier=>'J'
,p_column_label=>'Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143466950966236817)
,p_db_column_name=>'TARGET_COA'
,p_display_order=>5
,p_column_identifier=>'E'
,p_column_label=>'Target Coa'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143467421543236818)
,p_db_column_name=>'TARGET_LEDGER'
,p_display_order=>6
,p_column_identifier=>'F'
,p_column_label=>'Target Ledger'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1143468627712236821)
,p_db_column_name=>'UNMAPPED'
,p_display_order=>9
,p_column_identifier=>'I'
,p_column_label=>'Unmapped'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1143542485096372080)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'500938'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'CONFIG_CODE:DESCRIPTION:SOURCE_COA:SOURCE_LEDGER:TARGET_COA:TARGET_LEDGER:SOURCE_COMBOS:MAPPED:UNMAPPED:STATUS:PCT_COMPLETE:ACTIVE_FLAG'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1143852846683440996)
,p_plug_name=>'Summary Cards'
,p_static_id=>'summary-cards'
,p_parent_plug_id=>wwv_flow_imp.id(1143464557405236805)
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>4072358936313175081
,p_plug_display_sequence=>5
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  v_total NUMBER;',
'  v_mapped NUMBER;',
'  v_unmapped NUMBER;',
'  v_configs NUMBER;',
'BEGIN',
'  SELECT COUNT(*) INTO v_total FROM DMT_LOOKUP.DMT_COA_SOURCE_COMBOS WHERE enabled_flag = ''Y'';',
'  SELECT COUNT(*) INTO v_mapped FROM DMT_LOOKUP.DMT_COA_MAPPING WHERE active_flag = ''Y'';',
'  v_unmapped := v_total - v_mapped;',
'  SELECT COUNT(*) INTO v_configs FROM DMT_LOOKUP.DMT_COA_MAP_CONFIG WHERE active_flag = ''Y'';',
'  HTP.P(''<div style="display:flex;gap:12px;margin:12px 0;flex-wrap:wrap;">'');',
'  HTP.P(''<div style="flex:1;min-width:140px;padding:16px;background:#f0f4ff;border-radius:8px;border:1px solid #c0d2ff;"><div style="color:#5a6f8c;font-size:12px;">SOURCE COMBOS</div><div style="font-size:28px;font-weight:600;color:#1a3661;">''||v_tot'
||'al||''</div></div>'');',
'  HTP.P(''<div style="flex:1;min-width:140px;padding:16px;background:#e8f6e9;border-radius:8px;border:1px solid #bfe2c3;"><div style="color:#3a6b40;font-size:12px;">MAPPED</div><div style="font-size:28px;font-weight:600;color:#1f5226;">''||v_mapped||''<'
||'/div></div>'');',
'  HTP.P(''<div style="flex:1;min-width:140px;padding:16px;background:#fff4e6;border-radius:8px;border:1px solid #ffd9a8;"><div style="color:#8c5a1a;font-size:12px;">UNMAPPED</div><div style="font-size:28px;font-weight:600;color:#6b4111;">''||v_unmapped'
||'||''</div></div>'');',
'  HTP.P(''<div style="flex:1;min-width:140px;padding:16px;background:#e6f5fb;border-radius:8px;border:1px solid #b0d9eb;"><div style="color:#1f6082;font-size:12px;">ACTIVE CONFIGS</div><div style="font-size:28px;font-weight:600;color:#0e3a52;">''||v_co'
||'nfigs||''</div></div>'');',
'  HTP.P(''</div>'');',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143073282710835824)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(1143464557405236805)
,p_button_name=>'GENERATE_ALL'
,p_static_id=>'generate-all'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Generate All Mappings'
,p_grid_new_row=>'N'
,p_grid_new_column=>'N'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1143073403140835825)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(1143464557405236805)
,p_button_name=>'VALIDATE_ALL'
,p_static_id=>'validate-all'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Validate All'
,p_grid_new_row=>'N'
,p_grid_new_column=>'N'
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143851106179440978)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Generate All Mappings'
,p_static_id=>'generate-all-mappings'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_total NUMBER := 0;',
'    v_cnt NUMBER;',
'BEGIN',
'    FOR rec IN (SELECT config_code FROM DMT_COA_MAP_CONFIG WHERE active_flag = ''Y'' ORDER BY config_code) LOOP',
'        v_cnt := DMT_COA_MAP_PKG.GENERATE_MAPPINGS(rec.config_code);',
'        v_total := v_total + v_cnt;',
'    END LOOP;',
'    APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE := v_total || '' total mappings generated across all active configs.'';',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143073282710835824)
,p_internal_uid=>50402370563094401
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1143851149106440979)
,p_process_sequence=>20
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Validate All Mappings'
,p_static_id=>'validate-all-mappings'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_total NUMBER := 0;',
'    v_cnt NUMBER;',
'BEGIN',
'    FOR rec IN (SELECT config_code FROM DMT_COA_MAP_CONFIG WHERE active_flag = ''Y'' ORDER BY config_code) LOOP',
'        v_cnt := DMT_COA_MAP_PKG.VALIDATE_MAPPINGS(rec.config_code);',
'        v_total := v_total + v_cnt;',
'    END LOOP;',
'    APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE := v_total || '' total invalid mappings flagged across all active configs.'';',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1143073403140835825)
,p_internal_uid=>50402413490094402
);
wwv_flow_imp.component_end;
end;
/
