-- DMT_PIPELINE_DEF_TBL (DMT_DESIGN.html section 6 -- decided 2026-07-06;
-- complete seed content decided 2026-07-07, see db/seed/dmt_pipeline_def_tbl.sql)
-- Pipeline definitions: which objects each pipeline code runs, in what order,
-- with what dependencies. Replaces the hardcoded sequences in DMT_SCHEDULER_PKG
-- and feeds catalog-driven queue dispatch (section 12 backlog).
-- Every in-scope object has exactly one pipeline home (decided 2026-07-07),
-- hence the unique constraint on CEMLI_CODE alone.
-- DEPENDS_ON is a comma-separated list of canonical CEMLI codes (same format
-- DMT_WORK_QUEUE_TBL.DEPENDS_ON already uses; the queue engine strips spaces).
-- POSTRUN_JOB is the per-object post-run ESS job -- today only Assets has one;
-- every other object is explicitly none (NULL).
--
-- Dispatch registry columns (Stage C task 3 -- the section-12 "catalog-driven
-- queue dispatch" backlog item: "a one-row-per-object registry table (run
-- procedure, post-run job, ...)". This table is that one-row-per-object
-- registry -- it already carries POSTRUN_JOB):
--   EXEC_PROC   PKG.PROC the queue worker's EXECUTE_ONE invokes for the
--               object's data phase (validate/transform/generate/submit).
--               All registered procedures share the DMT_LOADER_PKG.RUN_*
--               signature (p_run_id, p_scenario_name,
--               p_run_mode, p_skip_bu_refresh). NULL = the object cannot be
--               dispatched yet (config objects pending the section-12
--               "fold config objects into the queue" item; ARReceipts).
--   EXEC_MODE   ASYNC = loader returns after SUBMIT_LOAD, work item goes to
--                       AWAITING_LOAD (the FBDI/HDL default);
--               SYNC  = loader runs its full inline cycle including its own
--                       reconcile, work item goes straight to DONE
--                       (MiscReceipts);
--               LOCAL = no Fusion load stage at all -- after EXEC_PROC the
--                       work item goes to RECONCILING when RECON_PROC is set,
--                       else DONE (the Mock engine-test objects).
--   RECON_PROC  PKG.PROC RECONCILE_ONE invokes (the object's RECONCILE_BATCH).
--               NULL = no BIP reconcile stage dispatched by the queue (HDL
--               objects reconcile inside their EXEC_PROC cycle).
--   RECON_HAS_CEMLI_ARG Y = the reconciler takes p_cemli_code as its second
--               parameter (the shared supplier-family reconciler and the mock);
--               N = the standard (p_run_id, p_load_ess_id, p_import_ess_id)
--               signature.
-- The TEST pipeline code exists only for the Mock engine-test objects, so the
-- engine walk can be proven with no Fusion and without polluting the six real
-- pipelines.

begin
  execute immediate 'CREATE TABLE "DMT_PIPELINE_DEF_TBL"
   (	"PIPELINE_DEF_ID" NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL ENABLE,
	"PIPELINE_CODE" VARCHAR2(30) NOT NULL ENABLE,
	"CEMLI_CODE" VARCHAR2(60) NOT NULL ENABLE,
	"SORT_ORDER" NUMBER NOT NULL ENABLE,
	"DEPENDS_ON" VARCHAR2(4000),
	"POSTRUN_JOB" VARCHAR2(500),
	"EXEC_PROC" VARCHAR2(200),
	"EXEC_MODE" VARCHAR2(10) DEFAULT ''ASYNC'' NOT NULL ENABLE,
	"RECON_PROC" VARCHAR2(200),
	"RECON_HAS_CEMLI_ARG" VARCHAR2(1) DEFAULT ''N'' NOT NULL ENABLE,
	 CONSTRAINT "DMT_PIPELINE_DEF_PK" PRIMARY KEY ("PIPELINE_DEF_ID")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_PIPELINE_DEF_UK1" UNIQUE ("CEMLI_CODE")
  USING INDEX  ENABLE,
	 CONSTRAINT "DMT_PIPELINE_DEF_CK1" CHECK (
        PIPELINE_CODE IN (''P2P'',''O2C'',''PROJECTS'',''FINANCIALS'',''HCM'',''CONFIGURATION'',''TEST'')) ENABLE,
	 CONSTRAINT "DMT_PIPELINE_DEF_CK2" CHECK (
        EXEC_MODE IN (''ASYNC'',''SYNC'',''LOCAL'')) ENABLE,
	 CONSTRAINT "DMT_PIPELINE_DEF_CK3" CHECK (
        RECON_HAS_CEMLI_ARG IN (''Y'',''N'')) ENABLE
   ) ';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

-- Guarded idempotent migration blocks: converge a pre-dispatch database
-- (table created without the dispatch columns) to the definition above.
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD ("EXEC_PROC" VARCHAR2(200))';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD ("EXEC_MODE" VARCHAR2(10) DEFAULT ''ASYNC'' NOT NULL)';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD ("RECON_PROC" VARCHAR2(200))';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD ("RECON_HAS_CEMLI_ARG" VARCHAR2(1) DEFAULT ''N'' NOT NULL)';
exception when others then
  if sqlcode not in (-1430) then raise; end if;
end;
/

-- Converge CK1 to include the TEST pipeline (drop + re-add; -2443 = constraint
-- does not exist, -2264 = name already in use -- both mean already converged).
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" DROP CONSTRAINT "DMT_PIPELINE_DEF_CK1"';
exception when others then
  if sqlcode not in (-2443) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD CONSTRAINT "DMT_PIPELINE_DEF_CK1" CHECK (
        PIPELINE_CODE IN (''P2P'',''O2C'',''PROJECTS'',''FINANCIALS'',''HCM'',''CONFIGURATION'',''TEST''))';
exception when others then
  if sqlcode not in (-2264) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD CONSTRAINT "DMT_PIPELINE_DEF_CK2" CHECK (
        EXEC_MODE IN (''ASYNC'',''SYNC'',''LOCAL''))';
exception when others then
  if sqlcode not in (-2264) then raise; end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PIPELINE_DEF_TBL" ADD CONSTRAINT "DMT_PIPELINE_DEF_CK3" CHECK (
        RECON_HAS_CEMLI_ARG IN (''Y'',''N''))';
exception when others then
  if sqlcode not in (-2264) then raise; end if;
end;
/

-- Contract index: the scheduler reads one pipeline's members in run order.
begin
  execute immediate 'CREATE INDEX "DMT_PIPELINE_DEF_N1" ON "DMT_PIPELINE_DEF_TBL" ("PIPELINE_CODE","SORT_ORDER")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
