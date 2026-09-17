prompt --application/pages/page_00025
begin
--   Manifest
--     PAGE: 00025
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
 p_id=>25
,p_name=>'Smart Upload'
,p_alias=>'SMART-UPLOAD'
,p_step_title=>'Upload Data Files'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4072355960268175073
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118072749)
,p_plug_name=>'Object Reference'
,p_static_id=>'object-reference'
,p_region_template_options=>'#DEFAULT#:is-collapsed:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'SELECT object_code, display_name, csv_filename AS expected_filename, fbdi_csv_filename AS fbdi_filename FROM dmt_upload_object_tbl WHERE is_active = ''Y'' ORDER BY display_name'
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1041441188118072750)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99250031
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072805)
,p_db_column_name=>'DISPLAY_NAME'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Display Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072806)
,p_db_column_name=>'EXPECTED_FILENAME'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Expected Filename'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072807)
,p_db_column_name=>'FBDI_FILENAME'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'FBDI Filename'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072804)
,p_db_column_name=>'OBJECT_CODE'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Object Code'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1093623226302743565)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'521821'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'OBJECT_CODE:DISPLAY_NAME:EXPECTED_FILENAME:FBDI_FILENAME'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118072720)
,p_plug_name=>'Upload Data Files'
,p_static_id=>'upload-data-files'
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<div style="margin-bottom:16px">',
'<p><strong>Three ways to upload:</strong></p>',
'<ul>',
'<li><strong>Manual:</strong> Select the file type from the dropdown, then upload any CSV file. The file must have a header row &mdash; column names determine the mapping. Filename does not matter.</li>',
'<li><strong>Auto-detect CSV:</strong> Upload a CSV file named to match the expected format (e.g. <code>POZ_SUPPLIERS.csv</code>). Must have a header row.</li>',
'<li><strong>ZIP bundle:</strong> Upload a ZIP file containing multiple CSVs. Each CSV is routed by its filename:',
'  <ul>',
'    <li>If the filename matches a <strong>staging CSV name</strong> (e.g. <code>POZ_SUPPLIERS.csv</code>) &rarr; parsed with headers</li>',
'    <li>If the filename matches an <strong>FBDI template name</strong> (e.g. <code>PozSuppliersInt.csv</code>) &rarr; parsed positionally (no headers, column order per CTL spec)</li>',
'    <li>Unrecognized filenames are skipped</li>',
'  </ul>',
'  The ZIP filename itself does not matter.</li>',
'</ul>',
'</div>'))
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118072774)
,p_plug_name=>'Upload Errors'
,p_static_id=>'upload-errors'
,p_region_template_options=>'#DEFAULT#:is-expanded:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>15
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT e.BATCH_TAG,',
'       e.LOG_ID AS BATCH,',
'       e.ROW_NUMBER,',
'       e.COLUMN_NAME,',
'       e.ERROR_TYPE,',
'       e.ERROR_MESSAGE,',
'       e.RAW_VALUE,',
'       TO_CHAR(e.CREATED_DATE, ''MM/DD HH24:MI'') AS LOGGED_AT',
'FROM DMT_UPLOAD_ERROR_TBL e',
'ORDER BY e.LOG_ID DESC, e.ROW_NUMBER',
'FETCH FIRST 200 ROWS ONLY'))
,p_plug_source_type=>'NATIVE_IR'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1041441188118072775)
,p_max_row_count=>'200'
,p_max_row_count_message=>'Showing first 200 errors.'
,p_no_data_found_message=>'No upload errors found.'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99250951
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072794)
,p_db_column_name=>'BATCH'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Batch'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072801)
,p_db_column_name=>'BATCH_TAG'
,p_display_order=>5
,p_column_identifier=>'H'
,p_column_label=>'Load ID'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072796)
,p_db_column_name=>'COLUMN_NAME'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Column'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072798)
,p_db_column_name=>'ERROR_MESSAGE'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Error Message'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072797)
,p_db_column_name=>'ERROR_TYPE'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Error Type'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072800)
,p_db_column_name=>'LOGGED_AT'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'When'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072799)
,p_db_column_name=>'RAW_VALUE'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Raw Value'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072795)
,p_db_column_name=>'ROW_NUMBER'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Row #'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1041441188118072784)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'UPL_ERR_DEF'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'BATCH_TAG:BATCH:ROW_NUMBER:COLUMN_NAME:ERROR_TYPE:ERROR_MESSAGE:RAW_VALUE:LOGGED_AT'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(1041441188118072824)
,p_plug_name=>'Upload Summary'
,p_static_id=>'upload-summary'
,p_region_template_options=>'#DEFAULT#:is-expanded:t-Region--scrollBody'
,p_plug_template=>2664334895415463485
,p_plug_display_sequence=>12
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT OBJECT_CODE,',
'       ROWS_LOADED,',
'       ROWS_ERRORED,',
'       STATUS,',
'       SUBSTR(ERROR_MSG, 1, 200) AS ERROR_MSG',
'FROM DMT_UPLOAD_LOG_TBL',
'WHERE BATCH_ID = :P25_LAST_BATCH_ID',
'ORDER BY OBJECT_CODE'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P25_LAST_BATCH_ID'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_ai_enabled=>false
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(1041441188118072825)
,p_max_row_count=>'100'
,p_no_data_found_message=>'Upload a file to see results here.'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>99251001
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072838)
,p_db_column_name=>'ERROR_MSG'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Error'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072834)
,p_db_column_name=>'OBJECT_CODE'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Object'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072836)
,p_db_column_name=>'ROWS_ERRORED'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Errors'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072835)
,p_db_column_name=>'ROWS_LOADED'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Loaded'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(1041441188118072837)
,p_db_column_name=>'STATUS'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Status'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(1041441188118072844)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'UPL_SUM_DEF'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'OBJECT_CODE:ROWS_LOADED:ROWS_ERRORED:STATUS:ERROR_MSG'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(1041441188118072732)
,p_button_sequence=>40
,p_button_plug_id=>wwv_flow_imp.id(1041441188118072720)
,p_button_name=>'UPLOAD_SMART'
,p_static_id=>'upload-smart'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#:t-Button--large'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Upload'
,p_button_position=>'BELOW_BOX'
,p_button_alignment=>'RIGHT'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118072814)
,p_name=>'P25_LAST_BATCH_ID'
,p_item_sequence=>90
,p_item_plug_id=>wwv_flow_imp.id(1041441188118072720)
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118072730)
,p_name=>'P25_OBJECT_TYPE'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(1041441188118072720)
,p_prompt=>'Object Type'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT display_name d, object_code r FROM dmt_upload_object_tbl WHERE is_active = ''Y'' ORDER BY display_name'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'-- Select Object Type --'
,p_cHeight=>1
,p_colspan=>6
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118072734)
,p_name=>'P25_SCENARIO'
,p_item_sequence=>25
,p_item_plug_id=>wwv_flow_imp.id(1041441188118072720)
,p_prompt=>'Scenario'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT scenario_name AS d, scenario_name AS r FROM dmt_scenario_tbl WHERE status = ''ACTIVE'' ORDER BY scenario_name'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'-- No Scenario --'
,p_cHeight=>1
,p_colspan=>6
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_help_text=>'Optional. Tag uploaded data with a scenario name so the pipeline can process subsets selectively.'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(1041441188118072731)
,p_name=>'P25_UPLOAD_FILE'
,p_item_sequence=>30
,p_item_plug_id=>wwv_flow_imp.id(1041441188118072720)
,p_prompt=>'File (CSV or ZIP)'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_FILE'
,p_cSize=>30
,p_colspan=>6
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
 p_id=>wwv_flow_imp.id(1041441188118072729)
,p_name=>'P25_UPLOAD_MODE'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(1041441188118072720)
,p_prompt=>'Upload Mode'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_RADIOGROUP'
,p_lov=>'STATIC:Manual - Pick Object Type;MANUAL,Auto-detect by Filename;AUTO'
,p_cSize=>30
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_of_columns', '1',
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(1041441188118072739)
,p_name=>'Toggle Object Type'
,p_static_id=>'toggle-object-type'
,p_event_sequence=>10
,p_triggering_element_type=>'ITEM'
,p_triggering_element=>'P25_UPLOAD_MODE'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'change'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(1041441188118072740)
,p_event_id=>wwv_flow_imp.id(1041441188118072739)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'Y'
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', 'var mode=apex.item("P25_UPLOAD_MODE").getValue();if(mode==="MANUAL"){apex.item("P25_OBJECT_TYPE").show();}else{apex.item("P25_OBJECT_TYPE").hide();apex.item("P25_OBJECT_TYPE").setValue("");}')).to_clob
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(1041441188118072759)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Smart Upload'
,p_static_id=>'smart-upload'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'',
'DECLARE',
'    l_filename     VARCHAR2(400);',
'    l_obj_code     VARCHAR2(100);',
'    l_ext          VARCHAR2(10);',
'    l_scenario     VARCHAR2(200) := :P25_SCENARIO;',
'    l_rows_loaded  NUMBER;',
'    l_rows_errored NUMBER;',
'    l_batch_id     NUMBER;',
'    l_error_msg    VARCHAR2(4000);',
'    l_summary      CLOB;',
'    l_has_stg      NUMBER := 0;',
'    l_has_fbdi     NUMBER := 0;',
'BEGIN',
'    SELECT filename INTO l_filename',
'    FROM apex_application_temp_files',
'    WHERE name = :P25_UPLOAD_FILE;',
'',
'    l_ext := UPPER(SUBSTR(l_filename, INSTR(l_filename, ''.'', -1) + 1));',
'',
'    IF :P25_UPLOAD_MODE = ''MANUAL'' THEN',
'        -- Manual: user picked the object type',
'        IF :P25_OBJECT_TYPE IS NULL THEN',
'            RAISE_APPLICATION_ERROR(-20001, ''Please select an Object Type in Manual mode.'');',
'        END IF;',
'        DMT_CSV_UPLOAD_PKG.UPLOAD_CSV(',
'            p_file_name    => :P25_UPLOAD_FILE,',
'            p_object_code  => :P25_OBJECT_TYPE,',
'            p_rows_loaded  => l_rows_loaded,',
'            p_rows_errored => l_rows_errored,',
'            p_batch_id_out => l_batch_id,',
'            p_error_msg    => l_error_msg,',
'            p_scenario_name => l_scenario',
'        );',
'        IF l_error_msg IS NOT NULL THEN',
'            APEX_ERROR.ADD_ERROR(p_message => l_error_msg, p_display_location => ''INLINE_IN_NOTIFICATION'');',
'        ELSE',
'            APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE :=',
'                l_rows_loaded || '' rows loaded, '' || l_rows_errored || '' errors.'';',
'        END IF;',
'',
'    ELSIF l_ext = ''ZIP'' THEN',
'        -- ZIP: peek inside to determine header-based vs FBDI',
'        DECLARE',
'            l_zip_blob  BLOB;',
'            l_files     APEX_ZIP.T_FILES;',
'            l_fname     VARCHAR2(500);',
'        BEGIN',
'            SELECT blob_content INTO l_zip_blob',
'            FROM apex_application_temp_files WHERE name = :P25_UPLOAD_FILE;',
'',
'            l_files := APEX_ZIP.GET_FILES(p_zipped_blob => l_zip_blob);',
'',
'            FOR i IN 1 .. l_files.COUNT LOOP',
'                l_fname := l_files(i);',
'                IF l_fname LIKE ''%/'' OR l_fname LIKE ''.%'' THEN CONTINUE; END IF;',
'                IF INSTR(l_fname, ''/'') > 0 THEN',
'                    l_fname := SUBSTR(l_fname, INSTR(l_fname, ''/'', -1) + 1);',
'                END IF;',
'',
'                SELECT COUNT(*) INTO l_has_stg FROM dmt_upload_object_tbl',
'                WHERE UPPER(csv_filename) = UPPER(l_fname) AND is_active = ''Y'' AND ROWNUM = 1;',
'                IF l_has_stg > 0 THEN EXIT; END IF;',
'',
'                SELECT COUNT(*) INTO l_has_fbdi FROM dmt_upload_object_tbl',
'                WHERE UPPER(fbdi_csv_filename) = UPPER(l_fname) AND is_active = ''Y'' AND ROWNUM = 1;',
'                IF l_has_fbdi > 0 THEN EXIT; END IF;',
'            END LOOP;',
'        END;',
'',
'        IF l_has_stg > 0 THEN',
'            DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_BUNDLE(',
'                p_file_name    => :P25_UPLOAD_FILE,',
'                p_summary      => l_summary,',
'                p_batch_id_out => l_batch_id,',
'                p_error_msg    => l_error_msg,',
'                p_scenario_name => l_scenario',
'            );',
'            IF l_error_msg IS NOT NULL THEN',
'                APEX_ERROR.ADD_ERROR(p_message => l_error_msg, p_display_location => ''INLINE_IN_NOTIFICATION'');',
'            ELSE',
'                APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE :=',
'                    SUBSTR(l_summary, 1, 2000);',
'            END IF;',
'',
'        ELSIF l_has_fbdi > 0 THEN',
'            DMT_CSV_UPLOAD_PKG.UPLOAD_FBDI_ZIP(',
'                p_file_name    => :P25_UPLOAD_FILE,',
'                p_summary      => l_summary,',
'                p_batch_id_out => l_batch_id,',
'                p_error_msg    => l_error_msg,',
'                p_scenario_name => l_scenario',
'            );',
'            IF l_error_msg IS NOT NULL THEN',
'                APEX_ERROR.ADD_ERROR(p_message => l_error_msg, p_display_location => ''INLINE_IN_NOTIFICATION'');',
'            ELSE',
'                APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE :=',
'                    SUBSTR(l_summary, 1, 2000);',
'            END IF;',
'',
'        ELSE',
'            APEX_ERROR.ADD_ERROR(',
'                p_message          => ''No files in the ZIP matched any known object filename. ''',
'                                     || ''Check the Object Reference table below for expected filenames.'',',
'                p_display_location => ''INLINE_IN_NOTIFICATION'');',
'        END IF;',
'',
'    ELSE',
'        -- Auto-detect single CSV by filename',
'        BEGIN',
'            SELECT object_code INTO l_obj_code',
'            FROM dmt_upload_object_tbl',
'            WHERE UPPER(csv_filename) = UPPER(l_filename)',
'            AND   is_active = ''Y''',
'            AND   ROWNUM = 1;',
'        EXCEPTION',
'            WHEN NO_DATA_FOUND THEN',
'                RAISE_APPLICATION_ERROR(-20002,',
'                    ''Could not auto-detect object type from filename "'' || l_filename || ''". ''',
'                    || ''Use Manual mode or rename the file to match an expected filename.'');',
'        END;',
'',
'        DMT_CSV_UPLOAD_PKG.UPLOAD_CSV(',
'            p_file_name    => :P25_UPLOAD_FILE,',
'            p_object_code  => l_obj_code,',
'            p_rows_loaded  => l_rows_loaded,',
'            p_rows_errored => l_rows_errored,',
'            p_batch_id_out => l_batch_id,',
'            p_error_msg    => l_error_msg,',
'            p_scenario_name => l_scenario',
'        );',
'        IF l_error_msg IS NOT NULL THEN',
'            APEX_ERROR.ADD_ERROR(p_message => l_error_msg, p_display_location => ''INLINE_IN_NOTIFICATION'');',
'        ELSE',
'            APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE :=',
'                l_rows_loaded || '' rows loaded, '' || l_rows_errored || '' errors. ('' || l_obj_code || '')'';',
'        END IF;',
'    END IF;',
'',
'    :P25_LAST_BATCH_ID := l_batch_id;',
'    :P25_UPLOAD_FILE := NULL;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when_button_id=>wwv_flow_imp.id(1041441188118072732)
,p_internal_uid=>99250040
);
wwv_flow_imp.component_end;
end;
/
