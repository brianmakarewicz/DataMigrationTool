prompt --application/shared_components/navigation/lists/page_navigation
begin
--   Manifest
--     LIST: Page Navigation
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>32599344892582845
,p_default_application_id=>500
,p_default_id_offset=>32805213799451421
,p_default_owner=>'DMT2_OWNER'
);
wwv_flow_imp_shared.create_list(
 p_id=>wwv_flow_imp.id(1580235294432795283)
,p_name=>'Page Navigation'
,p_static_id=>'page-navigation'
,p_version_scn=>'46458790967599'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1580238141407795277)
,p_list_item_display_sequence=>80
,p_list_item_link_text=>'Administration'
,p_static_id=>'administration'
,p_list_item_link_target=>'f?p=&APP_ID.:8:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-file-o'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1580236128979795281)
,p_list_item_display_sequence=>30
,p_list_item_link_text=>'ERP Financials'
,p_static_id=>'erp-financials'
,p_list_item_link_target=>'f?p=&APP_ID.:3:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-file-o'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1580236857916795279)
,p_list_item_display_sequence=>50
,p_list_item_link_text=>'ERP Projects'
,p_static_id=>'erp-projects'
,p_list_item_link_target=>'f?p=&APP_ID.:5:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-file-o'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1580237656626795278)
,p_list_item_display_sequence=>70
,p_list_item_link_text=>'HCM Time and Labor'
,p_static_id=>'hcm-time-and-labor'
,p_list_item_link_target=>'f?p=&APP_ID.:7:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-file-o'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1580237296643795278)
,p_list_item_display_sequence=>60
,p_list_item_link_text=>'HCM Workers'
,p_static_id=>'hcm-workers'
,p_list_item_link_target=>'f?p=&APP_ID.:6:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-file-o'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1580236464621795280)
,p_list_item_display_sequence=>40
,p_list_item_link_text=>'Order to Cash'
,p_static_id=>'order-to-cash'
,p_list_item_link_target=>'f?p=&APP_ID.:4:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-file-o'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1580235659208795282)
,p_list_item_display_sequence=>20
,p_list_item_link_text=>'Procure to Pay'
,p_static_id=>'procure-to-pay'
,p_list_item_link_target=>'f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-file-o'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp.component_end;
end;
/
