prompt --application/pages/page_00084
begin
--   Manifest
--     PAGE: 00084
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
 p_id=>84
,p_name=>'Run Pipeline'
,p_alias=>'P84-RUN-PIPELINE'
,p_step_title=>'Run Pipeline'
,p_autocomplete_on_off=>'OFF'
,p_inline_css=>'.pg{margin-bottom:10px;border:1px solid #e0e0e0;border-radius:8px;padding:10px 14px;background:#fafafa} .pg-h{font-weight:bold;font-size:14px;margin-bottom:6px} .pg-c{margin-left:28px} .pg-c label{display:inline-block;margin:3px 16px 3px 0;cursor:poi'
||'nter} .pg-c.off label{color:#aaa} .pg-c.off input{pointer-events:none;opacity:.4} #plan-overlay{display:none;position:fixed;top:0;left:0;right:0;bottom:0;z-index:10000;background:rgba(0,0,0,0.4)} #plan-box{background:white;margin:60px auto;max-width:'
||'800px;border-radius:12px;padding:24px;max-height:80vh;overflow-y:auto;box-shadow:0 8px 32px rgba(0,0,0,0.2)} .plan-tbl{width:100%;border-collapse:collapse;margin:8px 0} .plan-tbl th,.plan-tbl td{border:1px solid #e0e0e0;padding:6px 10px;text-align:le'
||'ft;font-size:13px} .plan-tbl th{background:#f5f5f5;font-weight:bold} .st-ready{color:#1a9c3e;font-weight:bold} .st-pending{color:#6b48c9}'
,p_step_template=>4072355960268175073
,p_page_component_map=>'17'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(605228858524477517)
,p_plug_name=>'Modal'
,p_static_id=>'modal'
,p_plug_display_sequence=>60
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'<div id="plan-overlay"><div id="plan-box"><h2 style="margin:0 0 16px 0;font-size:18px;">Execution Plan Preview</h2><div id="plan-content"><p style="color:#888">Loading...</p></div><div style="text-align:right;margin-top:16px;border-top:1px solid #e0e'
||'0e0;padding-top:12px;"><button type="button" class="t-Button" id="btn-cancel" style="margin-right:8px;">Cancel</button><button type="button" class="t-Button t-Button--hot" id="btn-confirm">Confirm &amp; Submit</button></div></div></div>'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(605228858524477516)
,p_plug_name=>'Pipeline Controls'
,p_static_id=>'pipeline-controls'
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'<style id="dmt-pipe-restyle">.pg{background:#fff;border:1px solid #e3e6ea;border-radius:8px;margin:0 0 16px;box-shadow:0 1px 3px rgba(0,0,0,.06);overflow:hidden;}.pg-h{background:#f5f7fa;padding:12px 16px;border-bottom:1px solid #e3e6ea;font-weight:6'
||'00;font-size:14px;}.pg-h label{font-weight:600;cursor:pointer;}.pg-c{padding:14px 16px;display:flex;flex-wrap:wrap;gap:10px 28px;}.pg-c label{display:inline-flex;align-items:center;gap:6px;font-size:13px;cursor:pointer;}.pg-c.off label{color:#aaa;}.p'
||'g-c.off input{pointer-events:none;opacity:.4;}.pipe-cb,.obj-cb{margin-right:6px;width:16px;height:16px;}#btn-run-pipeline{background:#0072c6;color:#fff;border:none;border-radius:6px;font-weight:600;font-size:15px;padding:12px 28px;cursor:pointer;min-'
||'width:220px;}#btn-run-pipeline:hover{background:#005a9e;}</style><p>Select full pipelines or individual objects, then click <b>Run Pipeline</b>.</p><div class="pg"><div class="pg-h"><label><input type="checkbox" class="pipe-cb" value="P2P" style="mar'
||'gin-right:6px">Procure to Pay (full pipeline)</label></div><div class="pg-c"><label><input type="checkbox" class="obj-cb" value="STANDALONE:Items">Items</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Suppliers">Suppliers</label'
||'><label><input type="checkbox" class="obj-cb" value="STANDALONE:SupplierAddresses">SupplierAddresses</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:SupplierSites">SupplierSites</label><label><input type="checkbox" class="obj-cb'
||'" value="STANDALONE:SupplierSiteAssignments">SupplierSiteAssignments</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:SupplierContacts">SupplierContacts</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Requis'
||'itions">Requisitions</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:PurchaseOrders">PurchaseOrders</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:BlanketPOs">BlanketPOs</label><label><input type="checkbox'
||'" class="obj-cb" value="STANDALONE:Contracts">Contracts</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:APInvoices">APInvoices</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:MiscReceipts">MiscReceipts</lab'
||'el></div></div><div class="pg"><div class="pg-h"><label><input type="checkbox" class="pipe-cb" value="O2C" style="margin-right:6px">Order to Cash (full pipeline)</label></div><div class="pg-c"><label><input type="checkbox" class="obj-cb" value="STAND'
||'ALONE:Customers">Customers</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:ARInvoices">ARInvoices</label></div></div><div class="pg"><div class="pg-h"><label><input type="checkbox" class="pipe-cb" value="FINANCIALS" style="margi'
||'n-right:6px">Financials (full pipeline)</label></div><div class="pg-c"><label><input type="checkbox" class="obj-cb" value="STANDALONE:GLBalances">GLBalances</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:GLBudgets">GLBudgets</l'
||'abel><label><input type="checkbox" class="obj-cb" value="STANDALONE:Assets">Assets</label></div></div><div class="pg"><div class="pg-h"><label><input type="checkbox" class="pipe-cb" value="PROJECTS" style="margin-right:6px">Projects (full pipeline)</'
||'label></div><div class="pg-c"><label><input type="checkbox" class="obj-cb" value="STANDALONE:Projects">Projects</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:BillingEvents">BillingEvents</label><label><input type="checkbox" cl'
||'ass="obj-cb" value="STANDALONE:Expenditures">Expenditures</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Grants">Grants</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:ProjectBudgets">ProjectBudgets</label'
||'></div></div><div class="pg"><div class="pg-h"><label><input type="checkbox" class="pipe-cb" value="HCM" style="margin-right:6px">HCM (full pipeline)</label></div><div class="pg-c"><label><input type="checkbox" class="obj-cb" value="STANDALONE:Worker'
||'s">Workers</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Assignments">Assignments</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Salaries">Salaries</label><label><input type="checkbox" class="obj-cb" val'
||'ue="STANDALONE:SalaryBases">SalaryBases</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:PayrollRelationships">PayrollRelationships</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:TaxCards">TaxCards</label><'
||'label><input type="checkbox" class="obj-cb" value="STANDALONE:W2Balances">W2Balances</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:BenParticipant">BenParticipant</label><label><input type="checkbox" class="obj-cb" value="STAND'
||'ALONE:BenDependent">BenDependent</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:BenBeneficiary">BenBeneficiary</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Absences">Absences</label><label><input type="'
||'checkbox" class="obj-cb" value="STANDALONE:TalentProfiles">TalentProfiles</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:PerfEvaluations">PerfEvaluations</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Wor'
||'kSchedules">WorkSchedules</label></div></div><div class="pg"><div class="pg-h"><label><input type="checkbox" class="pipe-cb" value="CONFIGURATION" style="margin-right:6px">Configuration (full pipeline)</label></div><div class="pg-c"><label><input typ'
||'e="checkbox" class="obj-cb" value="STANDALONE:GLCalendar">GLCalendar</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:ValueSets">ValueSets</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Lookups">Lookups</la'
||'bel><label><input type="checkbox" class="obj-cb" value="STANDALONE:UnitsOfMeasure">UnitsOfMeasure</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:PaymentTerms">PaymentTerms</label><label><input type="checkbox" class="obj-cb" val'
||'ue="STANDALONE:TaxConfig">TaxConfig</label><label><input type="checkbox" class="obj-cb" value="STANDALONE:Banks">Banks</label></div></div><div style="text-align:center;margin:6px 0 18px;"><button type="button" id="btn-run-pipeline">Run Pipeline</butt'
||'on></div>'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(605228858524477525)
,p_button_sequence=>50
,p_button_plug_id=>wwv_flow_imp.id(605228858524477516)
,p_button_name=>'RUN_PIPELINE'
,p_static_id=>'run-pipeline'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#:t-Button--large:t-Button--stretch'
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Run Pipeline'
,p_button_position=>'BELOW_BOX'
,p_button_alignment=>'RIGHT'
,p_warn_on_unsaved_changes=>null
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(605228858524477536)
,p_name=>'P84_RUN_MODE'
,p_item_sequence=>40
,p_item_plug_id=>wwv_flow_imp.id(605228858524477516)
,p_prompt=>'Run Mode'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'STATIC:New + Retry;NEW,Failed Only;FAILED,All (Reset);ALL'
,p_cHeight=>1
,p_colspan=>4
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(605228858524477535)
,p_name=>'P84_SCENARIO'
,p_item_sequence=>30
,p_item_plug_id=>wwv_flow_imp.id(605228858524477516)
,p_prompt=>'Scenario'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>'SELECT scenario_name d, scenario_name r FROM dmt_scenario_tbl WHERE status = ''ACTIVE'' ORDER BY scenario_name'
,p_lov_display_null=>'YES'
,p_lov_null_text=>'-- All Records --'
,p_cHeight=>1
,p_colspan=>4
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(605228858524477565)
,p_name=>'Cancel'
,p_static_id=>'cancel'
,p_event_sequence=>30
,p_triggering_element_type=>'JQUERY_SELECTOR'
,p_triggering_element=>'#btn-cancel'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(605228858524477566)
,p_event_id=>wwv_flow_imp.id(605228858524477565)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', 'document.getElementById("plan-overlay").style.display="none"')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(605228858524477575)
,p_name=>'Confirm'
,p_static_id=>'confirm'
,p_event_sequence=>40
,p_triggering_element_type=>'JQUERY_SELECTOR'
,p_triggering_element=>'#btn-confirm'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(605228858524477576)
,p_event_id=>wwv_flow_imp.id(605228858524477575)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', 'var btn=document.getElementById("btn-confirm");btn.disabled=true;btn.textContent="Submitting...";var body=new URLSearchParams();body.append("p_flow_id",$v("pFlowId"));body.append("p_flow_step_id",$v("pFlowStepId"));body.append("p_instance",$v("pInsta'
||'nce"));body.append("p_request","APPLICATION_PROCESS=SUBMIT_AJAX");body.append("p_json",JSON.stringify({pageItems:null,salt:null}));body.append("x01",window._planCodes||"");body.append("x02",$v("P84_SCENARIO")||"");body.append("x03",$v("P84_RUN_MODE")'
||'||"NEW");body.append("x04","HALT");fetch("wwv_flow.ajax",{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded; charset=UTF-8"},body:body.toString()}).then(function(r){return r.text();}).then(function(d){btn.disabled=false;btn.tex'
||'tContent="Confirm & Submit";d=(d||"").trim();if(d.indexOf("OK:")===0){var rid=d.substring(3).trim();var url="f?p="+$v("pFlowId")+":82:"+$v("pInstance")+"::NO::P82_RUN_ID:"+rid;document.getElementById("plan-content").innerHTML="<div style=\"text-align'
||':center;padding:16px\"><p style=\"font-size:17px;color:#1a7d33;margin:0 0 12px\"><b>&#10003; Pipeline submitted as Run #"+rid+"</b></p><a href=\""+url+"\" style=\"display:inline-block;padding:11px 22px;color:#fff;text-decoration:none;border-radius:6p'
||'x;background:#0072c6;font-weight:600\">Open Run #"+rid+" &rarr; tiles view</a></div>";document.getElementById("btn-confirm").style.display="none";document.getElementById("btn-cancel").textContent="Close";apex.message.showPageSuccess("Pipeline submitt'
||'ed as Run #"+rid);}else{apex.message.alert(d||"Submit returned no response");}}).catch(function(e){btn.disabled=false;btn.textContent="Confirm & Submit";apex.message.alert("Failed: "+e);});')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(605228858524477545)
,p_name=>'Pipe Toggle'
,p_static_id=>'pipe-toggle'
,p_event_sequence=>10
,p_triggering_element_type=>'JQUERY_SELECTOR'
,p_triggering_element=>'.pipe-cb'
,p_bind_type=>'live'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'change'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(605228858524477546)
,p_event_id=>wwv_flow_imp.id(605228858524477545)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', 'var cb=this.browserEvent.target,pg=cb.closest(".pg"),objs=pg.querySelectorAll(".obj-cb");if(cb.checked){pg.querySelector(".pg-c").classList.add("off");objs.forEach(function(o){o.checked=false;o.disabled=true})}else{pg.querySelector(".pg-c").classList'
||'.remove("off");objs.forEach(function(o){o.disabled=false})}')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(605228858524477555)
,p_name=>'Show Plan'
,p_static_id=>'show-plan'
,p_event_sequence=>20
,p_triggering_element_type=>'JQUERY_SELECTOR'
,p_triggering_element=>'#btn-run-pipeline'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(605228858524477556)
,p_event_id=>wwv_flow_imp.id(605228858524477555)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-javascript-code'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'js_code', 'var s=[];document.querySelectorAll(".pipe-cb:checked").forEach(function(c){s.push(c.value)});document.querySelectorAll(".obj-cb:checked").forEach(function(c){s.push(c.value)});if(!s.length){apex.message.alert("Select at least one pipeline or object."'
||');return}window._planCodes=s.join(",");document.getElementById("plan-content").innerHTML="<p style=''color:#888''>Loading execution plan...</p>";document.getElementById("plan-overlay").style.display="block";apex.server.process("PLAN_AJAX",{x01:s.join("'
||',")},{dataType:"text",success:function(h){document.getElementById("plan-content").innerHTML=h},error:function(j){document.getElementById("plan-content").innerHTML="<p style=''color:red''>"+((j.responseText||"Error").substring(0,300))+"</p>"}});')).to_clob
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(605228858524477585)
,p_process_sequence=>10
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'PLAN_AJAX'
,p_static_id=>'plan-ajax'
,p_process_sql_clob=>'BEGIN DMT_PLAN_PREVIEW_HTML(APEX_APPLICATION.G_X01); END;'
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>840070
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(605228858524477586)
,p_process_sequence=>20
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'SUBMIT_AJAX'
,p_static_id=>'submit-ajax'
,p_process_sql_clob=>'DECLARE l_codes VARCHAR2(4000):=APEX_APPLICATION.G_X01; l_sc VARCHAR2(200):=APEX_APPLICATION.G_X02; l_md VARCHAR2(20):=APEX_APPLICATION.G_X03; l_onfail VARCHAR2(20):=NVL(APEX_APPLICATION.G_X04,''HALT''); l_run_id NUMBER; BEGIN IF l_codes IS NULL THEN H'
||'TP.P(''ERROR:No selections''); RETURN; END IF; DMT_SUBMIT_RUN_V2(p_pipeline_codes=>l_codes, p_scenario_name=>NULLIF(l_sc,''''), p_run_mode=>NVL(l_md,''NEW''), p_on_failure=>l_onfail, p_submitted_by=>V(''APP_USER''), x_run_id=>l_run_id); DMT_QUEUE_PKG.ENSURE_'
||'POLLER_RUNNING; HTP.P(''OK:''||l_run_id); END;'
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>840071
);
wwv_flow_imp.component_end;
end;
/
