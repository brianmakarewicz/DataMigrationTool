-- DMT_CEMLI_SPLIT_CFG (generated from ATP 2026-07-03)

begin
  execute immediate 'CREATE TABLE "DMT_CEMLI_SPLIT_CFG" 
   (	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE, 
	"TFM_TABLE" VARCHAR2(128) NOT NULL ENABLE, 
	"PARTITION_COLUMNS" VARCHAR2(500) NOT NULL ENABLE, 
	"LABEL_EXPRESSION" VARCHAR2(500) NOT NULL ENABLE, 
	"WHERE_TEMPLATE" VARCHAR2(4000) NOT NULL ENABLE, 
	"STATUS_COLUMN" VARCHAR2(30) DEFAULT ''TFM_STATUS'',
	"CHILD_PARTITION_COLUMN" VARCHAR2(30),
	 CONSTRAINT "DMT_CEMLI_SPLIT_CFG_PK" PRIMARY KEY ("CEMLI_CODE")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-09 conformance review F1: STATUS_COLUMN default was the retired
-- name 'STATUS'; the infra-column dictionary (design section 7, accepted
-- 2026-07-08) makes TFM_STATUS the only legal TFM row-status column, and the
-- engine reads this value to build its split SQL. Converges a pre-existing
-- database; fresh installs get the correct default from the CREATE above.
-- ---------------------------------------------------------------------------
declare
  l_def varchar2(4000);
begin
  select data_default into l_def
    from user_tab_columns
   where table_name = 'DMT_CEMLI_SPLIT_CFG' and column_name = 'STATUS_COLUMN';
  if l_def is null or upper(trim(l_def)) not like '''TFM_STATUS''%' then
    execute immediate
      'ALTER TABLE "DMT_CEMLI_SPLIT_CFG" MODIFY ("STATUS_COLUMN" DEFAULT ''TFM_STATUS'')';
  end if;
end;
/

-- ---------------------------------------------------------------------------
-- 2026-07-20 work-queue-ID core: CHILD_PARTITION_COLUMN names the single TFM
-- column an object is split on when it spawns one child work-queue item per
-- distinct partition value (generalized Assets-per-book path; Items/Requisitions
-- per BATCH_ID). Distinct from PARTITION_COLUMNS (in-zip FBDI split). Additive
-- + nullable; converges a pre-existing database. See migrations/.
-- ---------------------------------------------------------------------------
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_CEMLI_SPLIT_CFG' and column_name = 'CHILD_PARTITION_COLUMN';
  if l_n = 0 then
    execute immediate
      'ALTER TABLE "DMT_CEMLI_SPLIT_CFG" ADD ("CHILD_PARTITION_COLUMN" VARCHAR2(30))';
  end if;
end;
/
