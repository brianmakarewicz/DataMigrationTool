prompt --application/pages/page_00052
begin
--   Manifest
--     PAGE: 00052
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
 p_id=>52
,p_name=>'Object Detail'
,p_alias=>'OBJECT-DETAIL'
,p_step_title=>'Object Detail'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'10'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1538429647821884569)
,p_plug_name=>'Breadcrumb'
,p_static_id=>'breadcrumb'
,p_region_name=>'breadcrumb_52'
,p_plug_display_sequence=>1
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'BEGIN DMT_OBJECT_DETAIL_BREADCRUMB(:P52_RUN_ID, :P52_CEMLI_CODE); END;'
,p_plug_source_type=>'NATIVE_PLSQL'
,p_plug_query_options=>'DERIVED_REPORT_COLUMNS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1538429647821884568)
,p_plug_name=>'Failed Records'
,p_static_id=>'failed-records'
,p_region_name=>'failed_records'
,p_plug_display_sequence=>40
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  v_sql       VARCHAR2(4000);',
'  v_cnt       NUMBER;',
'  v_int_id    NUMBER := NVL(:P52_RUN_ID, 0);',
'  v_cemli     VARCHAR2(100) := :P52_CEMLI_CODE;',
'  v_has_fails BOOLEAN := FALSE;',
'  TYPE rc_type IS REF CURSOR;',
'  v_cur       rc_type;',
'  v_seq_id    NUMBER;',
'  v_stg_id    NUMBER;',
'  v_error     VARCHAR2(4000);',
'  v_upd_date  VARCHAR2(100);',
'  CURSOR c_tables IS',
'    SELECT TFM_TABLE, DISPLAY_NAME, STATUS_COLUMN, ROW_FILTER',
'    FROM DMT_V_CEMLI_TFM_TABLES',
'    WHERE CEMLI_CODE = v_cemli',
'    ORDER BY SORT_ORDER;',
'BEGIN',
'  IF v_cemli IS NULL THEN',
'    htp.p(''<p>No CEMLI code specified.</p>'');',
'    RETURN;',
'  END IF;',
'  FOR rec IN c_tables LOOP',
'    -- Count failed rows first',
'    v_sql := ''SELECT COUNT(*) FROM '' || rec.TFM_TABLE ||',
'      '' WHERE RUN_ID = :1 AND '' || rec.STATUS_COLUMN || '' = ''''FAILED'''''';',
'    IF rec.ROW_FILTER IS NOT NULL THEN',
'      v_sql := v_sql || '' AND '' || rec.ROW_FILTER;',
'    END IF;',
'    BEGIN',
'      EXECUTE IMMEDIATE v_sql INTO v_cnt USING v_int_id;',
'    EXCEPTION WHEN OTHERS THEN',
'      v_cnt := 0;',
'    END;',
'    IF v_cnt > 0 THEN',
'      IF NOT v_has_fails THEN',
'        htp.p(''<h3 style="color:#CC0000;margin:16px 0 8px">Failed Records</h3>'');',
'        v_has_fails := TRUE;',
'      END IF;',
'      htp.p(''<h4 style="margin:12px 0 4px">'' || htf.escape_sc(rec.DISPLAY_NAME) || '' ('' || v_cnt || '' failed)</h4>'');',
'      htp.p(''<table class="t-Report-report" style="width:100%">'');',
'      htp.p(''<thead><tr>'');',
'      htp.p(''<th style="padding:6px 8px">TFM Seq</th>'');',
'      htp.p(''<th style="padding:6px 8px">STG Seq</th>'');',
'      htp.p(''<th style="padding:6px 8px">Error Text</th>'');',
'      htp.p(''<th style="padding:6px 8px">Updated</th>'');',
'      htp.p(''</tr></thead><tbody>'');',
'      v_sql := ''SELECT TFM_SEQUENCE_ID, STG_SEQUENCE_ID, '' ||',
'        ''SUBSTR(ERROR_TEXT,1,500), '' ||',
'        ''TO_CHAR(LAST_UPDATED_DATE,''''YYYY-MM-DD HH24:MI'''') '' ||',
'        ''FROM '' || rec.TFM_TABLE ||',
'        '' WHERE RUN_ID = :1 AND '' || rec.STATUS_COLUMN || '' = ''''FAILED'''''';',
'      IF rec.ROW_FILTER IS NOT NULL THEN',
'        v_sql := v_sql || '' AND '' || rec.ROW_FILTER;',
'      END IF;',
'      v_sql := v_sql || '' ORDER BY TFM_SEQUENCE_ID FETCH FIRST 100 ROWS ONLY'';',
'      BEGIN',
'        OPEN v_cur FOR v_sql USING v_int_id;',
'        LOOP',
'          FETCH v_cur INTO v_seq_id, v_stg_id, v_error, v_upd_date;',
'          EXIT WHEN v_cur%NOTFOUND;',
'          htp.p(''<tr>'');',
'          htp.p(''<td style="padding:4px 8px">'' || v_seq_id || ''</td>'');',
'          htp.p(''<td style="padding:4px 8px">'' || v_stg_id || ''</td>'');',
'          htp.p(''<td style="padding:4px 8px;word-break:break-all;max-width:500px">'' || htf.escape_sc(v_error) || ''</td>'');',
'          htp.p(''<td style="padding:4px 8px;white-space:nowrap">'' || v_upd_date || ''</td>'');',
'          htp.p(''</tr>'');',
'        END LOOP;',
'        CLOSE v_cur;',
'      EXCEPTION WHEN OTHERS THEN',
'        IF v_cur%ISOPEN THEN CLOSE v_cur; END IF;',
'        htp.p(''<tr><td colspan="4" style="color:red">Error querying table: '' || htf.escape_sc(SQLERRM) || ''</td></tr>'');',
'      END;',
'      htp.p(''</tbody></table>'');',
'      IF v_cnt > 100 THEN',
'        htp.p(''<p style="color:#666;font-style:italic">Showing first 100 of '' || v_cnt || '' failed records.</p>'');',
'      END IF;',
'    END IF;',
'  END LOOP;',
'  IF NOT v_has_fails THEN',
'    htp.p(''<p style="color:#00AA00;padding:12px">No failed records found for this run.</p>'');',
'  END IF;',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
,p_plug_display_condition_type=>'NEVER'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1538429647821884566)
,p_plug_name=>'FBDI File Chain'
,p_static_id=>'fbdi-file-chain'
,p_plug_display_sequence=>5
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  l_run  NUMBER := :P52_RUN_ID;',
'  l_cem  VARCHAR2(100) := :P52_CEMLI_CODE;',
'  l_csv  VARCHAR2(200);',
'  l_zip  VARCHAR2(200);',
'  l_load VARCHAR2(100);',
'  l_imp  VARCHAR2(100);',
'  l_url  VARCHAR2(4000);',
'BEGIN',
'  BEGIN',
'    EXECUTE IMMEDIATE ''SELECT FILENAME FROM DMT_FBDI_CSV_TBL WHERE INTEGRATION_ID=:1 AND OBJECT_TYPE=:2 AND ROWNUM=1'' INTO l_csv USING l_run, l_cem;',
'  EXCEPTION WHEN OTHERS THEN l_csv := NULL; END;',
'  BEGIN',
'    EXECUTE IMMEDIATE ''SELECT FILENAME FROM DMT_FBDI_ZIP_TBL WHERE INTEGRATION_ID=:1 AND OBJECT_TYPE=:2 AND ROWNUM=1'' INTO l_zip USING l_run, l_cem;',
'  EXCEPTION WHEN OTHERS THEN l_zip := NULL; END;',
'  BEGIN',
'    EXECUTE IMMEDIATE ''SELECT LOAD_ESS_JOB_ID, IMPORT_ESS_JOB_ID FROM DMT_OBJECT_DETAIL_V WHERE INTEGRATION_ID=:1 AND CEMLI_CODE=:2 AND ROWNUM=1'' INTO l_load, l_imp USING l_run, l_cem;',
'  EXCEPTION WHEN OTHERS THEN l_load := NULL; l_imp := NULL; END;',
'',
'  HTP.P(''<div style="background:#fff;border:1px solid #e3e6ea;border-radius:10px;box-shadow:0 1px 4px rgba(0,0,0,.06);padding:20px 24px;margin:0 0 24px;">'');',
'  HTP.P(''<h2 style="margin:0 0 16px;font-size:20px;font-weight:700;color:#16191f;">''||APEX_ESCAPE.HTML(NVL(l_cem,''Object''))||''</h2>'');',
'  HTP.P(''<div style="display:flex;flex-wrap:wrap;gap:18px 48px;font-size:13px;">'');',
'  HTP.P(''<div><div style="color:#888;text-transform:uppercase;font-size:11px;letter-spacing:.04em;">CSV File</div>''||''<div style="font-weight:600;color:#16191f;margin-top:2px;">''||APEX_ESCAPE.HTML(NVL(l_csv,''-''))||''</div></div>'');',
'  HTP.P(''<div><div style="color:#888;text-transform:uppercase;font-size:11px;letter-spacing:.04em;">ZIP File</div>''||''<div style="font-weight:600;color:#16191f;margin-top:2px;">''||APEX_ESCAPE.HTML(NVL(l_zip,''-''))||''</div></div>'');',
'  HTP.P(''<div><div style="color:#888;text-transform:uppercase;font-size:11px;letter-spacing:.04em;">Load ESS Job</div><div style="font-weight:600;margin-top:2px;">'');',
'  IF l_load IS NOT NULL THEN',
'    l_url := APEX_PAGE.GET_URL(p_page=>53, p_items=>''P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE'', p_values=>l_load||'',''||l_run||'',''||l_cem);',
'    HTP.P(''<a href="''||l_url||''" style="color:#0072c6;text-decoration:none;">''||APEX_ESCAPE.HTML(l_load)||''</a>'');',
'  ELSE HTP.P(''-''); END IF;',
'  HTP.P(''</div></div>'');',
'  HTP.P(''<div><div style="color:#888;text-transform:uppercase;font-size:11px;letter-spacing:.04em;">Import ESS Job</div><div style="font-weight:600;margin-top:2px;">'');',
'  IF l_imp IS NOT NULL THEN',
'    l_url := APEX_PAGE.GET_URL(p_page=>53, p_items=>''P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE'', p_values=>l_imp||'',''||l_run||'',''||l_cem);',
'    HTP.P(''<a href="''||l_url||''" style="color:#0072c6;text-decoration:none;">''||APEX_ESCAPE.HTML(l_imp)||''</a>'');',
'  ELSE HTP.P(''-''); END IF;',
'  HTP.P(''</div></div>'');',
'  HTP.P(''</div></div>'');',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1538429647821884567)
,p_plug_name=>'Record Breakdown'
,p_static_id=>'record-breakdown'
,p_region_name=>'record_breakdown'
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'  v_run    NUMBER := NVL(:P52_RUN_ID, 0);',
'  v_cemli  VARCHAR2(100) := :P52_CEMLI_CODE;',
'  v_rows   PLS_INTEGER := 0;',
'  -- Clickable count pill -> Record List (page 57) filtered to run + sub-object + status.',
'  FUNCTION pill(p_n NUMBER, p_status VARCHAR2, p_sub VARCHAR2, p_bg VARCHAR2, p_bold VARCHAR2 DEFAULT ''600'') RETURN VARCHAR2 IS',
'  BEGIN',
'    IF NVL(p_n,0) = 0 THEN RETURN ''<span style="color:#9aa5b1">0</span>''; END IF;',
'    RETURN ''<a href="''',
'        || APEX_PAGE.GET_URL(p_page=>57, p_items=>''P57_RUN_ID,P57_SUB_OBJECT,P57_STATUS'', p_values=>v_run||'',''||p_sub||'',''||p_status)',
'        || ''" style="text-decoration:none"><span style="background:''||p_bg',
'        || '';color:#fff;border-radius:10px;padding:1px 9px;font-weight:''||p_bold||'';cursor:pointer">''||p_n||''</span></a>'';',
'  END;',
'  -- Small red drop-out count between funnel stages ("-N x"); dash when zero.',
'  FUNCTION drop_cell(p_n NUMBER) RETURN VARCHAR2 IS',
'  BEGIN',
'    IF NVL(p_n,0) = 0 THEN RETURN ''<span style="color:#c8ced6">&ndash;</span>''; END IF;',
'    RETURN ''<span style="color:#a8271a;font-weight:600">&minus;''||p_n||'' &#10007;</span>'';',
'  END;',
'BEGIN',
'  IF v_cemli IS NULL THEN htp.p(''<p style="color:#888">No object selected.</p>''); RETURN; END IF;',
'',
'  FOR m IN (SELECT scenario_name, prefix, run_status FROM DMT_OBJECT_FUNNEL_V',
'             WHERE run_id=v_run AND cemli_code=v_cemli AND ROWNUM=1) LOOP',
'    htp.p(''<div style="color:#5f6b7a;font-size:12px;margin-bottom:8px">Run ''||v_run||'' &middot; ''',
'      ||APEX_ESCAPE.HTML(NVL(m.scenario_name,''(no scenario)''))||'' &middot; prefix ''',
'      ||APEX_ESCAPE.HTML(m.prefix)||'' &middot; ''||APEX_ESCAPE.HTML(m.run_status)||''</div>'');',
'  END LOOP;',
'',
'  htp.p(''<div style="margin-bottom:10px"><a href="''',
'    ||APEX_PAGE.GET_URL(p_page=>54,p_items=>''P54_RUN_ID,P54_CEMLI_CODE'',p_values=>v_run||'',''||v_cemli)',
'    ||''" style="color:#0070d2;text-decoration:none;font-weight:600">View activity log for this object &rarr;</a></div>'');',
'',
'  htp.p(''<div style="overflow-x:auto"><table style="border-collapse:collapse;width:100%;font-size:12.5px">'');',
'  htp.p(''<thead><tr style="background:#f3f6fa;color:#39485c">''',
'     ||''<th style="text-align:left;padding:6px 10px">Record type</th>''',
'     ||''<th style="padding:6px 8px">Staged</th><th style="padding:6px 4px;color:#a8271a;font-weight:500" title="pre-validation rejects">val &#10007;</th>''',
'     ||''<th style="padding:6px 8px">Transformed</th><th style="padding:6px 4px;color:#a8271a;font-weight:500" title="transform failures">xform &#10007;</th>''',
'     ||''<th style="padding:6px 8px">Generated</th>''',
'     ||''<th style="padding:6px 8px">Loaded</th><th style="padding:6px 8px;color:#a8271a">Load&nbsp;&#10007;</th>''',
'     ||''<th style="padding:6px 8px" title="still in flight">In&nbsp;flight</th>''',
'     ||''<th style="padding:6px 8px;color:#a8271a" title="failed with no error text - accounting defect, should be 0">Unacct.</th>''',
'     ||''</tr></thead><tbody>'');',
'',
'  FOR rec IN (SELECT sub_object, staged, prevalidation_failed, transformed, transform_failed,',
'                     generated, loaded, load_failed, in_progress, unreconciled',
'                FROM DMT_OBJECT_FUNNEL_V',
'               WHERE run_id=v_run AND cemli_code=v_cemli',
'               ORDER BY sub_order, sub_object) LOOP',
'    v_rows := v_rows + 1;',
'    htp.p(''<tr style="border-top:1px solid #e4e9f0;text-align:center">'');',
'    htp.p(''<td style="text-align:left;padding:6px 10px;font-weight:600">''||APEX_ESCAPE.HTML(rec.sub_object)||''</td>'');',
'    htp.p(''<td style="padding:6px 8px">''||pill(rec.staged, '''', rec.sub_object, ''#0b5cc0'')||''</td>'');',
'    htp.p(''<td style="padding:6px 4px">''||drop_cell(rec.prevalidation_failed)||''</td>'');',
'    htp.p(''<td style="padding:6px 8px">''||pill(rec.transformed, '''', rec.sub_object, ''#0b5cc0'')||''</td>'');',
'    htp.p(''<td style="padding:6px 4px">''||drop_cell(rec.transform_failed)||''</td>'');',
'    htp.p(''<td style="padding:6px 8px">''||pill(rec.generated, ''GENERATED'', rec.sub_object, ''#0b5cc0'')||''</td>'');',
'    htp.p(''<td style="padding:6px 8px">''||pill(rec.loaded, ''LOADED'', rec.sub_object, ''#1a7a33'')||''</td>'');',
'    htp.p(''<td style="padding:6px 8px">''||pill(rec.load_failed, ''FAILED'', rec.sub_object, ''#a8271a'')||''</td>'');',
'    htp.p(''<td style="padding:6px 8px">''||CASE WHEN NVL(rec.in_progress,0)>0',
'          THEN ''<span style="background:#e8f0fe;color:#0b5cc0;border-radius:10px;padding:1px 9px;font-weight:600">''||rec.in_progress||''</span>''',
'          ELSE ''<span style="color:#9aa5b1">0</span>'' END||''</td>'');',
'    htp.p(''<td style="padding:6px 8px">''||pill(rec.unreconciled, ''FAILED'', rec.sub_object, ''#a8271a'', ''700'')||''</td>'');',
'    htp.p(''</tr>'');',
'  END LOOP;',
'  htp.p(''</tbody></table></div>'');',
'  IF v_rows = 0 THEN htp.p(''<div style="padding:16px;color:#888">No funnel data for this object in this run.</div>''); END IF;',
'END;'))
,p_plug_source_type=>'NATIVE_PLSQL'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1565962746016488285)
,p_name=>'P52_CEMLI_CODE'
,p_item_sequence=>30
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1565962621776488284)
,p_name=>'P52_RUN_ID'
,p_item_sequence=>20
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp.component_end;
end;
/
