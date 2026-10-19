-- DMT_UPLOAD_FBDI_FILE_TBL (backlog #792, 2026-10-19)
--
-- FBDI upload routing registry: one row per (FBDI file name, staging object) pair.
-- The FBDI upload (DMT_CSV_UPLOAD_PKG) routes each headerless, positional CSV in an
-- uploaded zip by its file name to every staging object registered here for it, in
-- LOAD_ORDER, and loads it with that pair's own positions (DMT_UPLOAD_FBDI_POS_TBL).
--   * one file can feed several staging objects (Assets FaMassAdditions.csv carries
--     the asset header joined to the asset book);
--   * one staging object can be fed by several files with different layouts (the PO
--     header staging table takes PoHeadersInterfaceOrder/Blanket/Contract.csv).
-- Seeded by db/seed/dmt_upload_fbdi_metadata.sql (generated from
-- test/upload_samples/fbdi_column_maps.py). Idempotent: safe to re-run.

begin
  execute immediate 'CREATE TABLE "DMT_UPLOAD_FBDI_FILE_TBL"
   (	"FBDI_FILE_ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER NOCYCLE NOKEEP NOSCALE NOT NULL ENABLE,
	"FBDI_CSV_FILENAME" VARCHAR2(100) NOT NULL ENABLE,
	"OBJECT_CODE" VARCHAR2(50) NOT NULL ENABLE,
	"LOAD_ORDER" NUMBER DEFAULT 1 NOT NULL ENABLE,
	"DISTINCT_ROWS_FLAG" VARCHAR2(1) DEFAULT ''N'' NOT NULL ENABLE,
	"DATE_MASK" VARCHAR2(30) DEFAULT ''YYYY/MM/DD HH24:MI:SS'' NOT NULL ENABLE,
	"LINK_POSITION" NUMBER,
	"LINK_KEY_POSITION" NUMBER,
	"PARENT_FBDI_FILENAME" VARCHAR2(100),
	"PARENT_KEY_POSITION" NUMBER,
	"PARENT_VALUE_POSITION" NUMBER,
	"PARENT_OBJECT_CODE" VARCHAR2(50),
	"PARENT_KEY_COLUMN" VARCHAR2(128),
	"FBDI_COLUMN_COUNT" NUMBER,
	"CREATED_DATE" TIMESTAMP (6) DEFAULT SYSTIMESTAMP,
	 CONSTRAINT "DMT_UPLOAD_FBDI_FILE_PK" PRIMARY KEY ("FBDI_FILE_ID") USING INDEX ENABLE,
	 CONSTRAINT "DMT_UPLOAD_FBDI_FILE_UK1" UNIQUE ("FBDI_CSV_FILENAME", "OBJECT_CODE") USING INDEX ENABLE,
	 CONSTRAINT "DMT_UPLOAD_FBDI_FILE_CK1" CHECK (DISTINCT_ROWS_FLAG IN (''Y'',''N'')) ENABLE,
	 CONSTRAINT "DMT_UPLOAD_FBDI_FILE_CK2" CHECK (DATE_MASK IN (''YYYY/MM/DD HH24:MI:SS'',''MM/DD/YYYY HH24:MI:SS'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- Backlog #793: parent-link columns (converges a table created by #792; the
-- CREATE above already carries them for a fresh install).
declare
  procedure add_col(p_col in varchar2, p_type in varchar2) is
    l_n pls_integer;
  begin
    select count(*) into l_n from user_tab_columns
    where  table_name = 'DMT_UPLOAD_FBDI_FILE_TBL' and column_name = p_col;
    if l_n = 0 then
      execute immediate 'ALTER TABLE "DMT_UPLOAD_FBDI_FILE_TBL" ADD ("' || p_col || '" ' || p_type || ')';
    end if;
  end add_col;
begin
  add_col('LINK_POSITION', 'NUMBER');
  add_col('LINK_KEY_POSITION', 'NUMBER');
  add_col('PARENT_FBDI_FILENAME', 'VARCHAR2(100)');
  add_col('PARENT_KEY_POSITION', 'NUMBER');
  add_col('PARENT_VALUE_POSITION', 'NUMBER');
  add_col('PARENT_OBJECT_CODE', 'VARCHAR2(50)');
  add_col('PARENT_KEY_COLUMN', 'VARCHAR2(128)');
end;
/

-- A link is either to a parent FILE of the same zip or to a parent STAGING object.
begin
  execute immediate 'ALTER TABLE "DMT_UPLOAD_FBDI_FILE_TBL" ADD CONSTRAINT "DMT_UPLOAD_FBDI_FILE_CK3" CHECK (
      LINK_POSITION IS NULL
      OR (LINK_KEY_POSITION IS NOT NULL
          AND ((PARENT_FBDI_FILENAME IS NOT NULL AND PARENT_KEY_POSITION IS NOT NULL
                AND PARENT_VALUE_POSITION IS NOT NULL AND PARENT_OBJECT_CODE IS NULL)
            OR (PARENT_OBJECT_CODE IS NOT NULL AND PARENT_KEY_COLUMN IS NOT NULL
                AND PARENT_FBDI_FILENAME IS NULL)))) ENABLE';
exception when others then
  if sqlcode not in (-2264) then raise; end if;
end;
/

-- Backlog #790: fields per row of the file's Oracle template (existing databases).
begin
  execute immediate 'ALTER TABLE "DMT_UPLOAD_FBDI_FILE_TBL" ADD ("FBDI_COLUMN_COUNT" NUMBER)';
exception when others then if sqlcode not in (-1430) then raise; end if;
end;
/

begin
  execute immediate 'ALTER TABLE "DMT_UPLOAD_FBDI_FILE_TBL" ADD CONSTRAINT "DMT_UPLOAD_FBDI_FILE_FK1"
    FOREIGN KEY ("OBJECT_CODE") REFERENCES "DMT_UPLOAD_OBJECT_TBL" ("OBJECT_CODE") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX "DMT_UPLOAD_FBDI_FILE_N1" ON "DMT_UPLOAD_FBDI_FILE_TBL" ("OBJECT_CODE")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_UPLOAD_FBDI_FILE_TBL" IS 'FBDI upload routing: one row per (FBDI file name, staging object). The FBDI upload routes a CSV by file name to every object registered for it, in LOAD_ORDER, using that row''s positions in DMT_UPLOAD_FBDI_POS_TBL.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."FBDI_CSV_FILENAME" IS 'CSV file name inside the FBDI zip, exactly as the pipeline FBDI generator writes it (matched case-insensitively).';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."OBJECT_CODE" IS 'Upload object (DMT_UPLOAD_OBJECT_TBL.OBJECT_CODE) whose staging table this file loads.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."LOAD_ORDER" IS 'Order in which the staging objects fed by the same file are loaded (parent first).';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."DISTINCT_ROWS_FLAG" IS 'Y = load one staging row per distinct set of mapped values (a parent repeated on every child row of a joined file, e.g. the asset header in FaMassAdditions.csv).';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."DATE_MASK" IS 'Format the file''s generator writes dates in; every DATE column is parsed with it, TIMESTAMP columns with it plus .FF.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."LINK_POSITION" IS 'Backlog #793: slot the resolved parent link is appended at before loading (mapped in DMT_UPLOAD_FBDI_POS_TBL to the child''s link column). NULL = the file has no parent link.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."LINK_KEY_POSITION" IS 'Slot of this file holding the key Oracle links the row to its parent by (e.g. MASS_ADDITION_ID, INV_LOTSERIAL_INTERFACE_NUM).';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."PARENT_FBDI_FILENAME" IS 'Parent file in the same zip: the link value is its PARENT_VALUE_POSITION slot on the row whose PARENT_KEY_POSITION slot equals the key.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."PARENT_KEY_POSITION" IS 'Key slot in PARENT_FBDI_FILENAME.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."PARENT_VALUE_POSITION" IS 'Slot in PARENT_FBDI_FILENAME whose value becomes the link.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."PARENT_OBJECT_CODE" IS 'Parent staging object loaded from the same upload: the link value is the STG_SEQUENCE_ID of its latest row in the scenario whose PARENT_KEY_COLUMN equals the key.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."PARENT_KEY_COLUMN" IS 'Key column of the PARENT_OBJECT_CODE staging table.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_FILE_TBL"."FBDI_COLUMN_COUNT" IS 'Fields in every row of the Oracle FBDI template for this file (what the FBDI generator writes). The FBDI upload rejects a file whose first row has a different count (wrong layout, backlog #790).';
