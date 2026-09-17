prompt --application/shared_components/logic/application_items/p0_scenario_id
begin
--   Manifest
--     APPLICATION ITEM: P0_SCENARIO_ID
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>32599344892582845
,p_default_application_id=>500
,p_default_id_offset=>32805213799451421
,p_default_owner=>'DMT2_OWNER'
);
wwv_flow_imp_shared.create_flow_item(
 p_id=>wwv_flow_imp.id(1041441188118172720)
,p_name=>'P0_SCENARIO_ID'
,p_protection_level=>'N'
,p_version_scn=>'46966068629003'
);
wwv_flow_imp.component_end;
end;
/
