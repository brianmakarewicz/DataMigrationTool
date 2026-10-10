-- Grants award CFDA rows: the row's own Fusion id column FUSION_CFDA_ID on
-- DMT_GMS_AWD_CFDAS_TFM_TBL (backlog #671). Reconciliation stores GMS_AWARD_CFDAS.ID there
-- when the Grants recon report V4 finds the row in Fusion. The create-table script
-- db/tables/dmt_gms_awd_cfdas_tfm_tbl.sql carries the column for fresh installs and
-- converges an existing database with the same guarded block. Guarded and
-- idempotent: a re-run is a no-op. Deploy as the schema owner:
--   python scripts/dmt_deploy.py table --create db/tables/dmt_gms_awd_cfdas_tfm_tbl.sql --migration <this file>
-- The block is one line so dmt_deploy.py runs it as one statement, and SQLcl runs it
-- on the slash. This header ends with a semicolon so the deploy tool splits it off;

declare l_n pls_integer; begin select count(*) into l_n from user_tab_columns where table_name = 'DMT_GMS_AWD_CFDAS_TFM_TBL' and column_name = 'FUSION_CFDA_ID'; if l_n = 0 then execute immediate 'alter table DMT_GMS_AWD_CFDAS_TFM_TBL add (FUSION_CFDA_ID number)'; end if; end; --
/
