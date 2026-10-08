-- Seed data for DMT_CONFIG_TBL (37 rows, snapshot 2026-07-03; +2 no-hardcoded-IDs keys 2026-07-12;
-- +2 BIP transport-retry keys 2026-10-03, Backlog #148; -2 retired HCM_USERNAME/HCM_PASSWORD 2026-10-08,
-- Backlog #430: every Fusion user comes from DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS)
-- Idempotent: duplicate-key inserts are skipped.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AP_IMPORT_JOB_NAME','/oracle/apps/ess/financials/payables/invoices/payablesImport,PayablesImportEss',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- No-hardcoded-IDs standard (design section 7): the Expenditures business unit
-- is named here; its instance-specific id is resolved from the BU lookup at run time.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('EXPENDITURE_BU_NAME','US1 Business Unit','Business unit name for the Expenditures import; id resolved via BU_NAME_TO_BU_ID lookup.',to_date('2026-07-12 00:00:00','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('WORKER_DEFAULT_BU_NAME','US1 Business Unit','Business unit short code written to the Assignment HDL line for new-hire workers; named config, not a code literal (design section 7).',to_date('2026-07-15 00:00:00','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- No-hardcoded-IDs standard (design section 7): the asset book code is named
-- config so other book types load without a code change.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('ASSET_BOOK_TYPE','US CORP','Asset book type code for the Assets PostMassAdditions ESS job.',to_date('2026-07-12 00:00:00','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AP_INTERFACE_DETAILS_ID','1',NULL,to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AP_UCM_ACCOUNT','fin/payables/import',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AR_IMPORT_JOB_NAME','/oracle/apps/ess/financials/receivables/transactions/autoInvoices,AutoInvoiceImportEss',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AR_INTERFACE_DETAILS_ID','2',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('AR_UCM_ACCOUNT','fin/receivables/import',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('CUST_IMPORT_JOB_NAME','/oracle/apps/ess/cdm/foundation/bulkImport,CDMAutoBulkImportJob',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('CUST_INTERFACE_DETAILS_ID','4',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('CUST_UCM_ACCOUNT','fin/receivables/import',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('FUSION_PASSWORD','***MASKED-SET-ME***',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('FUSION_URL','https://fa-esew-dev28-saasfademo1.ds-fa.oraclepdemos.com/','Active Fusion instance base URL',to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('FUSION_USERNAME','fin_impl',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_BUYER_ID','300000047340498',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_BUYER_NAME','Roth, Calvin',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_PRC_BU_ID','300000046987012',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_REQ_BU_ID','300000046987012',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PO_DEFAULT_REQ_BU_NAME','US1 Business Unit',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_ADDR_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierAddresses',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_ADDR_INTERFACE_DETAILS_ID','56',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_CONT_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierContacts',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_CONT_INTERFACE_DETAILS_ID','26',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSuppliers',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_INTERFACE_DETAILS_ID','24',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_RESULTS_BIP_PATH','/Custom/DMT/SUP_RESULTS_RPT.xdo',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_ASSN_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSiteAssignments',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_ASSN_INTERFACE_DETAILS_ID','27',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_IMPORT_JOB_NAME','/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSites',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('SUP_SITE_INTERFACE_DETAILS_ID','25',NULL,to_date('2026-04-02 18:25:34','YYYY-MM-DD HH24:MI:SS'),'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('USE_PREFIX','Y',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('WALLET_DIR','***MASKED-SET-ME***',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('WALLET_PASSWORD','***MASKED-SET-ME***',NULL,NULL,NULL);
exception when dup_val_on_index then null;
end;
/
commit;

-- Decided admin config keys (DMT_DESIGN.html sections 2, 5, 6) - added 2026-07-07
-- after the blind infrastructure-tranche review found them missing from the seed.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('ESS_POLL_TIMEOUT_MINUTES','30','Max minutes to poll an ESS job before marking GENERATED rows FAILED [LOAD_ERROR]; reconciliation still runs after (design section 2)',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('BIP_CHUNK_SIZE','5000','Rows per BIP reconciliation fetch chunk (Contract v1, design section 5)',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('RETENTION_DAYS','90','Days to retain CSV CLOBs / ZIP BLOBs / activity-log entries before the purge job clears them (design section 6)',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('VALIDATE_UPSTREAM_DEPS','N','FALLBACK ONLY, superseded by the per-run flag (Backlog #142). Cross-object upstream PRE-validation (parent-must-be-LOADED checks in the validators) is now controlled PER RUN by DMT_PIPELINE_RUN_TBL.VALIDATE_UPSTREAM (page-84 toggle), read via DMT_UTIL_PKG.SHOULD_VALIDATE_UPSTREAM; this global key is consulted only for a run row with no explicit value. N (default)=skip (references resolve via DMT_XREF_PKG; a missing parent still fails at Fusion). Y=enforce.',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- Projects orphan-task pre-validation: allow a task whose parent project already
-- exists in Fusion (loaded by an earlier DMT run) to pass instead of being rejected.
-- N (default) = strict, batch-only: a task is an orphan unless its parent project
-- header is in the SAME source/scenario. Y = also let a task through when its parent
-- PROJECT_NUMBER has a prior LOADED Projects row (the DMT-side evidence that the
-- project is already present in Fusion, resolved the same way DMT_XREF_PKG resolves
-- cross-object references). A true orphan (parent neither in the batch nor previously
-- loaded) is still rejected under either setting.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('PROJECT_ALLOW_EXTERNAL_PARENT','N','Projects orphan-task pre-validation. N (default) = reject any task whose parent PROJECT_NUMBER is absent from the same source/scenario (strict, self-contained batch). Y = also allow a task through when its parent project was already loaded to Fusion by an earlier DMT run (a prior LOADED Projects TFM row for that PROJECT_NUMBER); only a true orphan (parent neither in the batch nor previously loaded) is then rejected.',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- Shared reconcile settle + re-read (Backlog #147). Applies to EVERY object's
-- reconcile (the shared RECONCILE_ONE path), not just Items. A load/import ESS
-- job can report terminal (SUCCEEDED/WARNING) a beat before a just-created row
-- is query-visible in the Fusion base table the reconcile reads -- a
-- commit/visibility lag, NOT a missing wait (the pipeline already polls the job
-- to terminal and reconciles every request). Without a settle, a GOOD row can be
-- falsely concluded UNACCOUNTED. Before the shared unaccounted sweep finalizes a
-- row, these two keys let the reconcile wait and re-read the base table for the
-- rows still awaiting base-table confirmation -- but ONLY after the object's
-- import reached SUCCEEDED/WARNING (a job-level crash is honestly UNACCOUNTED,
-- nothing to wait for) and ONLY for rows with no real per-row rejection. Read via
-- DMT_UTIL_PKG.GET_CONFIG, exactly like PROJECT_ALLOW_EXTERNAL_PARENT above.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('RECONCILE_SETTLE_SECONDS','30','Backlog #147 (all objects). Seconds the shared reconcile waits (DBMS_SESSION.SLEEP) before each re-read of the Fusion base table for GOOD rows not yet found there -- absorbing the commit/visibility lag after the object''s import ESS reports terminal. Default 30. 0 disables the wait (single pass, no settle). Applies to every object via DMT_QUEUE_WORKER_PKG.RECONCILE_ONE.',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('RECONCILE_MAX_RETRIES','2','Backlog #147 (all objects). Max settle-and-re-read passes the shared reconcile makes PER OBJECT for rows awaiting base-table confirmation before the sweep finalizes them. Each pass sleeps RECONCILE_SETTLE_SECONDS then re-reads all that object''s awaiting rows at once (per object, not per row); stops early when none remain. Default 2 (~60s max per object at 30s). 0 disables. Fires only after a SUCCEEDED/WARNING import; real rejections never retried; never fabricates LOADED.',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- BIP transport retry (Backlog #148). Bound how hard DMT_UTIL_PKG.RUN_BIP_REPORT
-- retries the runReport POST when it hits a TRANSIENT TRANSPORT fault -- a
-- network/connection blip (UTL_HTTP/ORA-29273 ''HTTP request failed'',
-- connection reset, ORA-12xxx) or a transport-level HTTP 5xx with no valid SOAP
-- body. runReport is READ-ONLY so a re-POST is side-effect free. These keys do
-- NOT apply to a BIP SOAP FAULT (a well-formed SOAP response carrying
-- soapenv:Fault / soap:Fault, e.g. a wrong report name or report error): a SOAP
-- fault means a real problem, raises immediately, and is NEVER retried (standing
-- rule bip_soap_fault_handling). A non-5xx non-2xx HTTP status (e.g. a 4xx
-- client error) is likewise not transient and raises on the first occurrence.
-- Read via DMT_UTIL_PKG.GET_CONFIG, exactly like the RECONCILE_* keys above.
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('BIP_TRANSPORT_MAX_RETRIES','2','Backlog #148. Max number of RETRIES DMT_UTIL_PKG.RUN_BIP_REPORT makes on the runReport POST after a TRANSIENT TRANSPORT fault (total attempts = 1 + this value). Default 2 (up to 3 attempts). 0 = no retry (single attempt). Applies ONLY to transport faults (ORA-29273/connection errors, or HTTP 5xx with no SOAP body); a BIP SOAP FAULT raises immediately and is NEVER retried per bip_soap_fault_handling. runReport is read-only so re-POST is safe.',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CONFIG_TBL" ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY") values ('BIP_TRANSPORT_BACKOFF_SECONDS','3','Backlog #148. Seconds DMT_UTIL_PKG.RUN_BIP_REPORT waits (DBMS_SESSION.SLEEP) before each retry of the runReport POST following a transient transport fault. Default 3. 0 = retry immediately with no backoff. Only used when BIP_TRANSPORT_MAX_RETRIES > 0 and the failure was classified transport (never for a SOAP fault).',sysdate,'DMT_OWNER');
exception when dup_val_on_index then null;
end;
/
-- ARInvoices grouping stamp (owner decision 2026-10-07). AutoInvoice groups lines
-- into invoices by its grouping rule, which on this pod ignores
-- INTERFACE_LINE_ATTRIBUTE1, so two DMT source invoices with the same customer and
-- dates merge into one Fusion invoice, and a leftover rejected interface line from
-- an earlier run silently holds back a new run's lines. Y stamps 'DMT <run-prefixed
-- invoice key>' into INTERNAL_NOTES (a mandatory grouping attribute), so each DMT
-- invoice is its own Fusion invoice. Read once per batch by
-- DMT_AR_TRANSFORM_PKG.TRANSFORM_LINES via DMT_UTIL_PKG.GET_CONFIG. MERGE inserts
-- only when missing, so an administrator's later choice is never overwritten;
-- re-running is a no-op.
merge into "DMT_CONFIG_TBL" t
using (select 'AR_GROUP_BY_DMT_INVOICE' config_key, 'Y' config_value,
              'ARInvoices Y/N, default Y. Y = each AR line gets ''DMT <run-prefixed invoice key>'' in INTERNAL_NOTES (after any source note; the note is truncated, never the key). INTERNAL_NOTES is an AutoInvoice grouping attribute, so each DMT invoice is one Fusion invoice and old rejected interface rows cannot hold back new runs. N = source note unchanged; DMT invoices with equal grouping values may merge (one rejection fails all) and old rejected rows can hold back new runs until purged.' description
       from dual) s
on (t."CONFIG_KEY" = s.config_key)
when not matched then insert ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
     values (s.config_key, s.config_value, s.description, sysdate, 'DMT_OWNER');
commit;
-- HDL SourceSystemOwner per DMT instance (backlog #287, owner decision 2026-10-07).
-- Every HCM HDL generator writes this value as SourceSystemOwner on every .dat line
-- (read at run time through DMT_HDL_UTIL_PKG.GET_SOURCE_SYSTEM_OWNER). SourceSystemIds
-- are permanent in Fusion's HRC_INTEGRATION_KEY_MAP and TFM ids repeat across a
-- --fresh rebuild and between Docker and ATP, so each DMT instance writes under its
-- own owner: DMT_ATP on an Autonomous Database (SYS_CONTEXT CLOUD_SERVICE is set
-- there) and DMT_LOCAL everywhere else (the Docker instance). Both codes exist and
-- are enabled in the pod's HRC_SOURCE_SYSTEM_OWNER lookup (verified 2026-10-07).
-- MERGE inserts only when missing, so an administrator's later value is never
-- overwritten; re-running is a no-op.
merge into "DMT_CONFIG_TBL" t
using (select 'HDL_SOURCE_SYSTEM_OWNER' config_key,
              case when sys_context('USERENV', 'CLOUD_SERVICE') is not null
                   then 'DMT_ATP' else 'DMT_LOCAL' end config_value,
              'HCM HDL SourceSystemOwner written on every .dat line by every HDL generator (backlog #287). One owner per DMT instance so SourceSystemIds from different DMT databases never collide in Fusion HRC_INTEGRATION_KEY_MAP. Must be an enabled HRC_SOURCE_SYSTEM_OWNER lookup code. Seeded DMT_ATP on ATP, DMT_LOCAL on Docker.' description
       from dual) s
on (t."CONFIG_KEY" = s.config_key)
when not matched then insert ("CONFIG_KEY","CONFIG_VALUE","DESCRIPTION","LAST_UPDATED_DATE","LAST_UPDATED_BY")
     values (s.config_key, s.config_value, s.description, sysdate, 'DMT_OWNER');
commit;
