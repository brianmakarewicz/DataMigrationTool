-- RUN AS DMT_LOOKUP (the schema owner), not DMT_OWNER.
-- Drop DMT_LOOKUP.DMT_LKP_REFRESH_PKG (backlog #286, fixed under #309,
-- 2026-10-07). It read FUSION_USERNAME / FUSION_PASSWORD straight out of
-- DMT_OWNER.DMT_CONFIG_TBL, bypassing the central Fusion user utility
-- (DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS), and nothing calls it: the run-start
-- lookup refresh is DMT_UTIL_PKG.REFRESH_LOOKUPS through DMT_BIP_DEPLOY_PKG.
-- Its files, @@ lines and grant are removed from db/install_dmt_lookup.sql in
-- the same change. Plain DROP (no dynamic SQL); a re-run reports ORA-04043 and
-- changes nothing. DMT_MIGRATION_LOG is DMT_OWNER's table, so this
-- DMT_LOOKUP-side script is not logged there.
whenever sqlerror continue

prompt == Drop DMT_LOOKUP.DMT_LKP_REFRESH_PKG ==
drop package DMT_LKP_REFRESH_PKG;
