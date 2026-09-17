prompt --application/shared_components/logic/application_items/p0_prefix_filter
begin
--   Manifest
--     APPLICATION ITEM: P0_PREFIX_FILTER
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
 p_id=>wwv_flow_imp.id(1041441188118272769)
,p_name=>'P0_PREFIX_FILTER'
,p_protection_level=>'N'
,p_version_scn=>'46966143884164'
);
wwv_flow_imp.component_end;
end;
/
