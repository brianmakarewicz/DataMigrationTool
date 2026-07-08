-- DMT_CEMLI_CATALOG_TBL (DMT_DESIGN.html section 11 -- decided 2026-07-07)
-- The object display catalog: one row per record type (sub-object) per object,
-- carrying object code, display name, transform table, status column, row
-- filter, and sort order. Replaces the hardcoded ~90-branch UNION ALL view --
-- DMT_V_CEMLI_TFM_TABLES becomes a plain SELECT over this table, and the
-- catalog-driven queue dispatch (section 12 backlog) reads the same rows.
-- Drill contract (section 11 / appendix): page 52 passes DISPLAY_NAME as the
-- page-57 SUB_OBJECT filter, so display names must be globally unique across
-- objects and byte-identical on both sides -- enforced here by UK1.
-- ROW_FILTER is a SQL predicate fragment appended as ' AND ' || ROW_FILTER to
-- a single-table count (shared-table children carry the parent discriminator).
-- TFM_TABLE is nullable only for objects whose record types are not built yet
-- (ARReceipts -- deliberately last, section 1 #46).

begin
  execute immediate 'CREATE TABLE "DMT_CEMLI_CATALOG_TBL"
   (	"CATALOG_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE,
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE,
	"DISPLAY_NAME" VARCHAR2(200) NOT NULL ENABLE,
	"TFM_TABLE" VARCHAR2(128),
	"STATUS_COLUMN" VARCHAR2(128),
	"ROW_FILTER" VARCHAR2(4000),
	"SORT_ORDER" NUMBER NOT NULL ENABLE,
	 CONSTRAINT "DMT_CEMLI_CATALOG_PK" PRIMARY KEY ("CATALOG_ID")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_CEMLI_CATALOG_UK1" UNIQUE ("DISPLAY_NAME")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_CEMLI_CATALOG_UK2" UNIQUE ("CEMLI_CODE","SORT_ORDER")
  USING INDEX  ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- Contract index: the page-52 breakdown cursor and the dispatch path read all
-- record types for one object by CEMLI_CODE.
begin
  execute immediate 'CREATE INDEX "DMT_CEMLI_CATALOG_N1" ON "DMT_CEMLI_CATALOG_TBL" ("CEMLI_CODE")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
