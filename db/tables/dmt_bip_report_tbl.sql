-- DMT_BIP_REPORT_TBL (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_BIP_REPORT_TBL" 
   (	"BIP_REPORT_ID" NUMBER NOT NULL ENABLE, 
	"CEMLI_CODE" VARCHAR2(50) NOT NULL ENABLE, 
	"OBJECT_TYPE" VARCHAR2(100) NOT NULL ENABLE, 
	"DM_CATALOG_PATH" VARCHAR2(500), 
	"REPORT_CATALOG_PATH" VARCHAR2(500), 
	"INTERFACE_TABLE" VARCHAR2(100), 
	"CREATED_DATE" DATE DEFAULT SYSDATE, 
	"NOTES" VARCHAR2(1000), 
	"DEEP_LINK_OBJ_TYPE" VARCHAR2(100), 
	"DEEP_LINK_KEY_TEMPLATE" VARCHAR2(500), 
	 CONSTRAINT "DMT_BIP_REPORT_TBL_PK" PRIMARY KEY ("BIP_REPORT_ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "DMT_BIP_REPORT_TBL_UQ" UNIQUE ("CEMLI_CODE")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."BIP_REPORT_ID" IS 'PK - from DMT_BIP_RPT_ID_SEQ';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."CEMLI_CODE" IS 'CEMLI identifier e.g. C001-Suppliers. Unique.';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."OBJECT_TYPE" IS 'Human-readable object label e.g. Supplier Address';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."DM_CATALOG_PATH" IS 'Full Fusion catalog path to the BIP data model .xdm';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."REPORT_CATALOG_PATH" IS 'Full Fusion catalog path to the BIP report .xdo';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."INTERFACE_TABLE" IS 'Primary Fusion interface table queried by the report';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."CREATED_DATE" IS 'Date row was seeded';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."NOTES" IS 'Free text deployment notes';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."DEEP_LINK_OBJ_TYPE" IS 'Fusion deep link objType parameter (e.g. PRC_SUPPLIER, PURCHASE_ORDER). NULL if no deep link exists.';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."DEEP_LINK_KEY_TEMPLATE" IS 'Deep link objKey template with {ID} placeholder (e.g. prcBuId%3D300000046987012%3BsupplierId%3D{ID}). Replaced at runtime by GET_DEEP_LINK.';
COMMENT ON TABLE "DMT_BIP_REPORT_TBL"  IS 'BIP report registry. One row per CEMLI. Paths queried by results packages at runtime.';

-- ---------------------------------------------------------------------------
-- Contract v1 registration columns (design section 5, "BIP reconciliation
-- report contract - v1"). ADDITIVE + NULLABLE. Fresh installs get the final
-- shape from these guarded in-file ALTERs; an existing database converges via
-- db/migrations/2026-09-16_bip_report_contract_v1_columns.sql (same statements,
-- logged once in DMT_MIGRATION_LOG). These four columns describe an object's
-- Contract v1 registration. CONTRACT_VERSION gates the shared FETCH
-- (DMT_RECON_CONTRACT_PKG.FETCH); the other three are DOCUMENTATION for the
-- object's own reconciler (Option A, owner decision on PR #248 — the shared
-- package never uses TFM_TABLE / FUSION_ID_COLUMN in SQL, so there is no dynamic
-- SQL against a catalog-sourced identifier). The per-object reconciler applies
-- the parsed rows with STATIC SQL against its own compile-time-known TFM table.
--   CONTRACT_VERSION  1 = the object's recon report conforms to Contract v1, so
--                     the shared FETCH will page + parse it. NULL/0 = legacy
--                     bespoke reconciler (coexists during per-object migration).
--   TFM_TABLE         (documentation) the TFM table the object's reconciler updates.
--   FUSION_ID_COLUMN  (documentation) the TFM column the object's reconciler stamps
--                     the Fusion base-table id into on a BASE/SUCCESS row.
--   RECON_KEY_SQL     (documentation) how RECON_KEY is built for the object; the
--                     reconciler matches the report's RECORD_KEY to TFM.RECON_KEY.
--   APPLY_PROC        PKG.PROC of the object's thin STATIC apply (APPLY_<OBJ>).
--                     The generic recon engine (DMT_RECON_ENGINE_PKG) stages the
--                     parsed report into DMT_RECON_STAGE_GTT, then dispatches
--                     this proc through the sanctioned invoke_registered site.
--                     It is a PROCEDURE NAME (invoke_registered validates the
--                     PKG.PROC allow-pattern), never a table or column name — so
--                     no new dynamic-SQL site is introduced.
-- ---------------------------------------------------------------------------
declare
  procedure add_col(p_col varchar2, p_ddl varchar2) is
    l_n pls_integer;
  begin
    select count(*) into l_n from user_tab_columns
    where  table_name = 'DMT_BIP_REPORT_TBL' and column_name = p_col;
    if l_n = 0 then
      execute immediate 'ALTER TABLE "DMT_BIP_REPORT_TBL" ADD (' || p_ddl || ')';
    end if;
  end;
begin
  add_col('CONTRACT_VERSION', '"CONTRACT_VERSION" NUMBER');
  add_col('TFM_TABLE',        '"TFM_TABLE" VARCHAR2(240)');
  add_col('FUSION_ID_COLUMN', '"FUSION_ID_COLUMN" VARCHAR2(100)');
  add_col('RECON_KEY_SQL',    '"RECON_KEY_SQL" VARCHAR2(1000)');
  add_col('APPLY_PROC',       '"APPLY_PROC" VARCHAR2(200)');
end;
/
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."CONTRACT_VERSION" IS 'Contract v1 conformance: 1 = shared parser applies the seven-column response; NULL/0 = legacy bespoke reconciler.';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."TFM_TABLE" IS 'TFM table the shared Contract v1 parser updates for this object.';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."FUSION_ID_COLUMN" IS 'TFM column the shared parser stamps the Fusion base-table id into on a BASE/SUCCESS row.';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."RECON_KEY_SQL" IS 'Documents how RECON_KEY is built for this object (report RECORD_KEY is matched to TFM.RECON_KEY).';
COMMENT ON COLUMN "DMT_BIP_REPORT_TBL"."APPLY_PROC" IS 'PKG.PROC of the object thin static apply (APPLY_<OBJ>), dispatched by DMT_RECON_ENGINE_PKG through invoke_registered after staging the report to DMT_RECON_STAGE_GTT.';
