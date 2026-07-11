-- DMT_LOOKUP_TBL
-- The ONE common table for application-sourced name->id (key->value)
-- mappings (design section 7 "One common lookup table"). Canonical shape:
--   LOOKUP_TYPE  - names the mapping (convention SOURCE_TO_TARGET,
--                  e.g. BU_NAME_TO_BU_ID); see the canonical lookup registry.
--   LOOKUP_VALUE - the input being resolved (e.g. a business-unit name).
--   RETURN_VALUE - the resolved output (e.g. bu_id). Parts that always
--                  travel together join with a tilde ~ (the one reserved
--                  separator), e.g. ledger_id~access_set_id.
-- Instance-specific ids are NOT committed here; they are refreshed from
-- Fusion at pipeline start (DMT_UTIL_PKG.REFRESH_LOOKUPS) and read through
-- the single accessor DMT_UTIL_PKG.GET_LOOKUP.

begin
  execute immediate 'CREATE TABLE "DMT_LOOKUP_TBL"
   (	"LOOKUP_ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE,
	"LOOKUP_TYPE" VARCHAR2(100) NOT NULL ENABLE,
	"LOOKUP_VALUE" VARCHAR2(500) NOT NULL ENABLE,
	"RETURN_VALUE" VARCHAR2(500),
	"DESCRIPTION" VARCHAR2(500),
	"CREATED_DATE" DATE DEFAULT SYSDATE,
	"LAST_UPDATED_DATE" DATE DEFAULT SYSDATE,
	 CONSTRAINT "DMT_LOOKUP_PK" PRIMARY KEY ("LOOKUP_ID")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_LOOKUP_UK" UNIQUE ("LOOKUP_TYPE", "LOOKUP_VALUE", "RETURN_VALUE")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- ============================================================
-- Guarded idempotent migration (2026-07-11): converge a database created
-- with the earlier shape (LOOKUP_CODE / LOOKUP_VALUE / LOOKUP_VALUE2) to
-- the canonical shape above. The table is an instance cache repopulated by
-- REFRESH_LOOKUPS at every pipeline preflight, so the rename does not need
-- to preserve LOOKUP_VALUE2's data -- REFRESH_LOOKUPS re-derives every value
-- (and now splits the old single BU row into its two canonical types and
-- ~-joins the ledger's access set). The unique constraint follows the column
-- renames automatically.
--   1) LOOKUP_VALUE (old output) -> RETURN_VALUE
--   2) LOOKUP_CODE  (old input)  -> LOOKUP_VALUE
--   3) drop LOOKUP_VALUE2 (folded into RETURN_VALUE with ~ where it belongs)
-- ============================================================
declare l_n number; begin
  select count(*) into l_n from user_tab_columns
   where table_name='DMT_LOOKUP_TBL' and column_name='RETURN_VALUE';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_LOOKUP_TBL" RENAME COLUMN "LOOKUP_VALUE" TO "RETURN_VALUE"';
  end if;
end;
/
declare l_n number; begin
  select count(*) into l_n from user_tab_columns
   where table_name='DMT_LOOKUP_TBL' and column_name='LOOKUP_CODE';
  if l_n > 0 then
    execute immediate 'ALTER TABLE "DMT_LOOKUP_TBL" RENAME COLUMN "LOOKUP_CODE" TO "LOOKUP_VALUE"';
  end if;
end;
/
declare l_n number; begin
  select count(*) into l_n from user_tab_columns
   where table_name='DMT_LOOKUP_TBL' and column_name='LOOKUP_VALUE2';
  if l_n > 0 then
    execute immediate 'ALTER TABLE "DMT_LOOKUP_TBL" DROP COLUMN "LOOKUP_VALUE2"';
  end if;
end;
/

COMMENT ON COLUMN "DMT_LOOKUP_TBL"."LOOKUP_TYPE"  IS 'Names the mapping, convention SOURCE_TO_TARGET (e.g. BU_NAME_TO_BU_ID). See the canonical lookup registry in the design doc.';
COMMENT ON COLUMN "DMT_LOOKUP_TBL"."LOOKUP_VALUE" IS 'The input being resolved (e.g. a business-unit or ledger name).';
COMMENT ON COLUMN "DMT_LOOKUP_TBL"."RETURN_VALUE" IS 'The resolved output (e.g. bu_id). Composite returns join their parts with a tilde ~ (e.g. ledger_id~access_set_id).';
COMMENT ON TABLE  "DMT_LOOKUP_TBL"  IS 'The one common table for application-sourced name->id lookups. Refreshed from Fusion at pipeline start (REFRESH_LOOKUPS); read via GET_LOOKUP.';
