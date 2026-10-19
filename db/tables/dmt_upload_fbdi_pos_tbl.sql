-- DMT_UPLOAD_FBDI_POS_TBL (backlog #792, 2026-10-19)
--
-- FBDI upload positions, keyed per FBDI file (not per staging table): for each
-- (file, staging object) pair in DMT_UPLOAD_FBDI_FILE_TBL, the 1-based CSV slot the
-- pipeline's FBDI generator writes each staging column's value to. The FBDI loader
-- loads only the columns listed here, each from its slot. Seeded by
-- db/seed/dmt_upload_fbdi_metadata.sql (generated from
-- test/upload_samples/fbdi_column_maps.py). Idempotent: safe to re-run.

begin
  execute immediate 'CREATE TABLE "DMT_UPLOAD_FBDI_POS_TBL"
   (	"FBDI_POS_ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER NOCYCLE NOKEEP NOSCALE NOT NULL ENABLE,
	"FBDI_FILE_ID" NUMBER NOT NULL ENABLE,
	"COLUMN_NAME" VARCHAR2(128) NOT NULL ENABLE,
	"FBDI_POSITION" NUMBER NOT NULL ENABLE,
	 CONSTRAINT "DMT_UPLOAD_FBDI_POS_PK" PRIMARY KEY ("FBDI_POS_ID") USING INDEX ENABLE,
	 CONSTRAINT "DMT_UPLOAD_FBDI_POS_UK1" UNIQUE ("FBDI_FILE_ID", "COLUMN_NAME") USING INDEX ENABLE,
	 CONSTRAINT "DMT_UPLOAD_FBDI_POS_CK1" CHECK (FBDI_POSITION >= 1) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'ALTER TABLE "DMT_UPLOAD_FBDI_POS_TBL" ADD CONSTRAINT "DMT_UPLOAD_FBDI_POS_FK1"
    FOREIGN KEY ("FBDI_FILE_ID") REFERENCES "DMT_UPLOAD_FBDI_FILE_TBL" ("FBDI_FILE_ID") ON DELETE CASCADE ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_UPLOAD_FBDI_POS_TBL" IS 'FBDI upload positions per FBDI file: the 1-based CSV slot of each staging column for one DMT_UPLOAD_FBDI_FILE_TBL (file, object) pair.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_POS_TBL"."FBDI_FILE_ID" IS 'The (file, staging object) pair, FK to DMT_UPLOAD_FBDI_FILE_TBL.FBDI_FILE_ID.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_POS_TBL"."COLUMN_NAME" IS 'Staging column (a non-admin DMT_UPLOAD_DICT_TBL column of the object) loaded from this slot.';
COMMENT ON COLUMN "DMT_UPLOAD_FBDI_POS_TBL"."FBDI_POSITION" IS '1-based CSV slot the FBDI generator writes this column to.';
