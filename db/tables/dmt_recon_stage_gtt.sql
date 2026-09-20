-- DMT_RECON_STAGE_GTT — session-private staging table for the generic
-- Contract v1 reconcile engine (DMT_RECON_ENGINE_PKG).
--
-- The engine is object-agnostic: every Contract v1 recon report returns the
-- SAME nine standard columns (see docs/DMT_DESIGN.html, "BIP reconciliation
-- report contract — v1" and the carrier type DMT_RECON_ROW_OBJ). The engine
-- keyset-pages that fixed nine-column report, parses each page with XMLTABLE,
-- and STATICALLY inserts the parsed rows into this GTT keyed by RUN_ID. It
-- then hands off to the object's OWN thin static APPLY_<OBJ> procedure, which
-- reads THIS GTT and MERGEs into its literally-named TFM table with STATIC SQL.
--
-- Why a GTT and not a PL/SQL collection handed across the dispatch boundary:
-- the sanctioned dynamic-invocation site (DMT_QUEUE_WORKER_PKG.invoke_registered)
-- binds only scalars (RUN_ID and the ESS/queue ids). A collection cannot ride
-- that dispatch. Staging the parsed rows in this session-private GTT lets the
-- engine pass ONLY p_run_id to the object's APPLY proc through the existing
-- dispatch — the rows are already here — so NO new dynamic-SQL site is added.
--
-- ON COMMIT PRESERVE ROWS: the queue engine controls the transaction boundary
-- and does not commit between the engine's stage step and the APPLY proc's
-- MERGE (both run inside RECONCILE_ONE). PRESERVE keeps the staged rows alive
-- across any intermediate commit the report transport might do, until the
-- session ends. Each RECONCILE call first deletes its own RUN_ID rows so a
-- re-run or a second object in the same session starts clean.
--
-- Columns: the nine standard Contract v1 report columns (identical names and
-- types to DMT_RECON_ROW_OBJ), plus RUN_ID to scope a page set to its run.

begin
  execute immediate 'CREATE GLOBAL TEMPORARY TABLE "DMT_RECON_STAGE_GTT"
   (	"RUN_ID"          NUMBER NOT NULL,
	"OBJECT_TYPE"     VARCHAR2(60),
	"RECORD_KEY"      VARCHAR2(1000),
	"SOURCE_TYPE"     VARCHAR2(20),
	"FUSION_STATUS"   VARCHAR2(20),
	"FUSION_ID"       NUMBER,
	"ERROR_MESSAGE"   VARCHAR2(4000),
	"LOAD_REQUEST_ID" NUMBER,
	"SOURCE_REF"      VARCHAR2(240),
	"DMT_REFERENCE"   VARCHAR2(240)
   )  ON COMMIT PRESERVE ROWS';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

COMMENT ON TABLE "DMT_RECON_STAGE_GTT" IS 'Session GTT the generic recon engine stages parsed Contract v1 report pages into; per-object static APPLY_<OBJ> procs read it and MERGE into their own TFM table. Scoped by RUN_ID.';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."RUN_ID" IS 'Pipeline run id — scopes a staged page set to its run; APPLY procs filter on it.';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."OBJECT_TYPE" IS 'Contract v1: sub-object discriminator (record type); object code for single-record-type objects.';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."RECORD_KEY" IS 'Contract v1: business key matched to the TFM row RECON_KEY.';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."SOURCE_TYPE" IS 'Contract v1: BASE or INTERFACE — which Fusion tier the row came from.';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."FUSION_STATUS" IS 'Contract v1: normalized SUCCESS or ERROR (the DM normalizes object-specific states).';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."FUSION_ID" IS 'Contract v1: Fusion base-table id (non-null on BASE/SUCCESS).';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."ERROR_MESSAGE" IS 'Contract v1: real Fusion error text (non-null on ERROR rows).';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."LOAD_REQUEST_ID" IS 'Contract v1: the request id the row matched on (audit).';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."SOURCE_REF" IS 'Contract v1: Slot A native source-ref read back from Fusion (audit).';
COMMENT ON COLUMN "DMT_RECON_STAGE_GTT"."DMT_REFERENCE" IS 'Contract v1: Slot C full DMT:run:queue:tfm reference (round-trip proof).';
