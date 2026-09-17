prompt --application/pages/page_00008
begin
--   Manifest
--     PAGE: 00008
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
 p_id=>8
,p_name=>'Administration'
,p_alias=>'ADMIN'
,p_step_title=>'Administration'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_component_map=>'10'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1580423498597419548)
,p_plug_name=>'BIP Report Registry'
,p_static_id=>'bip-report-registry'
,p_plug_display_sequence=>30
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'BEGIN IF :G_SECTION IS NULL OR :G_SECTION=''BIP'' THEN dmt_render_view(''DMT_BIP_REPORTS_ADMIN_V'',''BIP Report''); END IF; END;'
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1580424289381419546)
,p_plug_name=>'Daily Run Metrics'
,p_static_id=>'daily-run-metrics'
,p_plug_display_sequence=>50
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'BEGIN IF :G_SECTION IS NULL OR :G_SECTION=''METRICS'' THEN dmt_render_view(''DMT_RUN_METRICS_V'',''Run Metric''); END IF; END;'
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1580423072634419549)
,p_plug_name=>'ESS Job Files'
,p_static_id=>'ess-job-files'
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'BEGIN IF :G_SECTION IS NULL OR :G_SECTION=''ESS'' THEN dmt_render_view(''DMT_ESS_JOB_FILES_V'',''ESS Job File''); END IF; END;'
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1580422695414419550)
,p_plug_name=>'ESS Job Monitor'
,p_static_id=>'ess-job-monitor'
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'BEGIN IF :G_SECTION IS NULL OR :G_SECTION=''ESS'' THEN dmt_render_view(''DMT_ESS_JOBS_MONITOR_V'',''ESS Job''); END IF; END;'
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1580423932212419547)
,p_plug_name=>'System Configuration'
,p_static_id=>'system-configuration'
,p_plug_display_sequence=>40
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'BEGIN IF :G_SECTION IS NULL OR :G_SECTION=''CONFIG'' THEN dmt_render_view(''DMT_CONFIG_ADMIN_V'',''Configuration''); END IF; END;'
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp.component_end;
end;
/
