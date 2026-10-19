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
