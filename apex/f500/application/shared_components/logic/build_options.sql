prompt --application/shared_components/logic/build_options
begin
--   Manifest
--     BUILD OPTIONS: 500
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>32599344892582845
,p_default_application_id=>500
,p_default_id_offset=>32805213799451421
,p_default_owner=>'DMT2_OWNER'
);
wwv_flow_imp_shared.create_build_option(
 p_id=>wwv_flow_imp.id(1580209920259795508)
,p_build_option_name=>'Commented Out'
,p_static_id=>'commented-out'
,p_build_option_status=>'EXCLUDE'
,p_version_scn=>'46458790962880'
);
wwv_flow_imp.component_end;
end;
/
