-- DMT_REF_CARRIER_CFG_TBL (backlog #12 -- decided 2026-09-19, owner sign-off)
-- The per-object carrier map for the run-scoped per-record reference. One row per
-- TFM table (i.e. per object tier). It tells the generator WHERE to stamp each of
-- three identifier slots, and tells the reconciler WHERE to read them back:
--
--   Slot A -- a NATIVE source-system-reference field that receives the per-record
--            id (the TFM row's TFM_SEQUENCE_ID). Present only where Fusion offers a
--            source-ref field (e.g. TCA ORIG_SYSTEM_REFERENCE, HDL SourceSystemId,
--            Expenditures ORIG_TRANSACTION_REFERENCE). SLOT_A_FIELD is the
--            interface/HDL attribute written; SLOT_A_BASE_COLUMN is the base-table
--            column read back at reconcile. NULL where the object has none.
--   Slot B -- a NATIVE batch/group/request field that receives the run id
--            (the run = the batch). e.g. BATCH_ID (AP/AR), GROUP_ID (GL/Inv),
--            REQUEST_ID. NULL where the object has none.
--   Slot C -- a high-numbered TEXT descriptive-flexfield attribute that ALWAYS
--            receives the full reference  DMT:<run_id>:<work_queue_id>:<tfm_seq_id>.
--            Never a low attribute (clients use ATTRIBUTE1..5); SLOT_C_ATTRIBUTE is
--            the highest available on the base table (varies 8..50 per object).
--            SLOT_C_MAXLEN is its char length; REF_FORMAT is FULL when the length
--            holds the full form, COMPACT (DMT:<tfm_seq_id>) when the field is short.
--            NULL where the base table has no attribute column.
--
-- Matching is on the TFM id (Slot A where present, else parsed from Slot C); the
-- run id and work-queue id are provenance. GLBudgets carries all slots NULL --
-- it has no base-table surface, so it reconciles on its business key (owner
-- decision 2026-09-19) and is present here only to record that fact.
-- CONFIDENCE mirrors the research pass: CONFIRMED (base column verified live),
-- LIKELY (strong evidence, not re-queried), NONE (no such column). ACTIVE_FLAG
-- lets a row be disabled without deletion. The carrier is config, not code:
-- changing an object's slot is a seed edit + redeploy, no PL/SQL change.

begin
  execute immediate 'CREATE TABLE "DMT_REF_CARRIER_CFG_TBL"
   (	"CARRIER_CFG_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE,
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE,
	"SUB_OBJECT" VARCHAR2(200),
	"TFM_TABLE" VARCHAR2(128) NOT NULL ENABLE,
	"SLOT_A_FIELD" VARCHAR2(128),
	"SLOT_A_BASE_COLUMN" VARCHAR2(128),
	"SLOT_B_FIELD" VARCHAR2(128),
	"SLOT_C_ATTRIBUTE" VARCHAR2(60),
	"SLOT_C_MAXLEN" NUMBER,
	"REF_FORMAT" VARCHAR2(12) DEFAULT ''FULL'' NOT NULL ENABLE,
	"CONFIDENCE" VARCHAR2(12),
	"ACTIVE_FLAG" VARCHAR2(1) DEFAULT ''Y'' NOT NULL ENABLE,
	"NOTES" VARCHAR2(1000),
	"CREATED_DATE" DATE DEFAULT SYSDATE,
	"LAST_UPDATED_DATE" DATE DEFAULT SYSDATE,
	 CONSTRAINT "DMT_REF_CARRIER_CFG_PK" PRIMARY KEY ("CARRIER_CFG_ID")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_REF_CARRIER_CFG_UK1" UNIQUE ("TFM_TABLE")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_REF_CARRIER_CFG_CK1" CHECK (REF_FORMAT IN (''FULL'',''COMPACT'')) ENABLE,
	 CONSTRAINT "DMT_REF_CARRIER_CFG_CK2" CHECK (ACTIVE_FLAG IN (''Y'',''N'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- The generator and reconciler read all tiers for one object by CEMLI_CODE.
begin
  execute immediate 'CREATE INDEX "DMT_REF_CARRIER_CFG_N1" ON "DMT_REF_CARRIER_CFG_TBL" ("CEMLI_CODE")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
