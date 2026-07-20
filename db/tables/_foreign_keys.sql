-- All foreign keys, applied after every table exists
-- DMT_ABSENCE_STG_TBL.SYS_C00128154
begin
  execute immediate 'ALTER TABLE "DMT_ABSENCE_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ABSENCE_TFM_TBL.DMT_ABSENCE_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_ABSENCE_TFM_TBL" ADD CONSTRAINT "DMT_ABSENCE_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ABSENCE_TFM_TBL.DMT_ABSENCE_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_ABSENCE_TFM_TBL" ADD CONSTRAINT "DMT_ABSENCE_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_ABSENCE_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICES_INT_STG_TBL.SYS_C00127324
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICES_INT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICES_INT_TFM_TBL.DMT_AP_INV_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INV_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICES_INT_TFM_TBL.DMT_AP_INV_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INV_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_AP_INVOICES_INT_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICE_LINES_INT_STG_TBL.SYS_C00127325
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICE_LINES_INT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICE_LINES_INT_TFM_TBL.DMT_AP_INV_LN_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICE_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INV_LN_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICE_LINES_INT_TFM_TBL.DMT_AP_INV_LN_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICE_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INV_LN_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_AP_INVOICE_LINES_INT_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ASSIGNMENT_STG_TBL.SYS_C00128151
begin
  execute immediate 'ALTER TABLE "DMT_ASSIGNMENT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ASSIGNMENT_TFM_TBL.DMT_ASSIGNMENT_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_ASSIGNMENT_TFM_TBL" ADD CONSTRAINT "DMT_ASSIGNMENT_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ASSIGNMENT_TFM_TBL.DMT_ASSIGNMENT_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_ASSIGNMENT_TFM_TBL" ADD CONSTRAINT "DMT_ASSIGNMENT_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_ASSIGNMENT_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_BENFY_STG_TBL.SYS_C00128162
begin
  execute immediate 'ALTER TABLE "DMT_BEN_BENFY_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_BENFY_TFM_TBL.DMT_BEN_BENFY_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_BENFY_TFM_TBL" ADD CONSTRAINT "DMT_BEN_BENFY_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_BENFY_TFM_TBL.DMT_BEN_BENFY_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_BENFY_TFM_TBL" ADD CONSTRAINT "DMT_BEN_BENFY_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_BEN_BENFY_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_DEPEND_STG_TBL.SYS_C00128161
begin
  execute immediate 'ALTER TABLE "DMT_BEN_DEPEND_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_DEPEND_TFM_TBL.DMT_BEN_DEPEND_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_DEPEND_TFM_TBL" ADD CONSTRAINT "DMT_BEN_DEPEND_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_DEPEND_TFM_TBL.DMT_BEN_DEPEND_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_DEPEND_TFM_TBL" ADD CONSTRAINT "DMT_BEN_DEPEND_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_BEN_DEPEND_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_PARTIC_STG_TBL.SYS_C00128160
begin
  execute immediate 'ALTER TABLE "DMT_BEN_PARTIC_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_PARTIC_TFM_TBL.DMT_BEN_PARTIC_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_PARTIC_TFM_TBL" ADD CONSTRAINT "DMT_BEN_PARTIC_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_PARTIC_TFM_TBL.DMT_BEN_PARTIC_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_PARTIC_TFM_TBL" ADD CONSTRAINT "DMT_BEN_PARTIC_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_BEN_PARTIC_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_CONVERSION_MASTER_ARCHIVE.DMT_CONV_MASTER_SCENARIO_FK
begin
  execute immediate 'ALTER TABLE "DMT_CONVERSION_MASTER_ARCHIVE" ADD CONSTRAINT "DMT_CONV_MASTER_SCENARIO_FK" FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ESS_JOB_FILE_TBL.DMT_ESS_JOB_FILE_FK
begin
  execute immediate 'ALTER TABLE "DMT_ESS_JOB_FILE_TBL" ADD CONSTRAINT "DMT_ESS_JOB_FILE_FK" FOREIGN KEY ("ESS_JOB_ID")
	  REFERENCES "DMT_ESS_JOB_TBL" ("ESS_JOB_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_ASSIGN_STG_TBL.SYS_C00127379
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_BOOK_STG_TBL.SYS_C00127380
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_HDR_STG_TBL.SYS_C00127378
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_HDR_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- (removed) DMT_FBDI_ZIP_TBL.DMT_FBDI_ZIP_CSV_FK — the FBDI_CSV_ID bridge column was
-- dropped in the FBDI CSV<->ZIP remodel (the CSV row now points UP to its zip via
-- DMT_FBDI_CSV_TBL.FBDI_ZIP_ID). This ADD CONSTRAINT on the now-missing column would
-- raise ORA-00904 on a fresh install (not in the caught sqlcode list), breaking install.sql.

-- DMT_GL_BUDGET_INT_STG_TBL.SYS_C00127376
begin
  execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GL_INTERFACE_STG_TBL.SYS_C00127375
begin
  execute immediate 'ALTER TABLE "DMT_GL_INTERFACE_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_BDGT_PRDS_STG_TBL.SYS_C00127339
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_BDGT_PRDS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_CERTS_STG_TBL.SYS_C00127340
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_CERTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_CFDAS_STG_TBL.SYS_C00127341
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_CFDAS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUNDING_STG_TBL.SYS_C00127333
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUNDING_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUND_ALLOC_STG_TBL.SYS_C00127342
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_ALLOC_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUND_SRC_STG_TBL.SYS_C00127336
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_SRC_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_HEADERS_STG_TBL.SYS_C00127332
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_HEADERS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_KEYWORDS_STG_TBL.SYS_C00127338
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_KEYWORDS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_ORG_CREDITS_STG_TBL.SYS_C00127343
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_ORG_CREDITS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PERSONNEL_STG_TBL.SYS_C00127335
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL.SYS_C00127337
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL.SYS_C00127344
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PROJECTS_STG_TBL.SYS_C00127334
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PROJECTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_REFERENCES_STG_TBL.SYS_C00127345
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_REFERENCES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_TERMS_STG_TBL.SYS_C00127346
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_TERMS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCOUNTS_STG_TBL.SYS_C00127319
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCOUNTS_TFM_TBL.DMT_HZ_ACCTS_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCTS_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCOUNTS_TFM_TBL.DMT_HZ_ACCTS_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCTS_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_HZ_ACCOUNTS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITES_STG_TBL.SYS_C00127320
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITES_TFM_TBL.DMT_HZ_ASITES_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ASITES_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITES_TFM_TBL.DMT_HZ_ASITES_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ASITES_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_HZ_ACCT_SITES_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITE_USES_STG_TBL.SYS_C00127321
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITE_USES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITE_USES_TFM_TBL.DMT_HZ_ASUSE_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ASUSE_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITE_USES_TFM_TBL.DMT_HZ_ASUSE_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ASUSE_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_HZ_ACCT_SITE_USES_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_LOCATIONS_STG_TBL.SYS_C00127316
begin
  execute immediate 'ALTER TABLE "DMT_HZ_LOCATIONS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_LOCATIONS_TFM_TBL.DMT_HZ_LOCS_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_LOCATIONS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_LOCS_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_LOCATIONS_TFM_TBL.DMT_HZ_LOCS_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_LOCATIONS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_LOCS_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_HZ_LOCATIONS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTIES_STG_TBL.SYS_C00127315
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTIES_TFM_TBL.DMT_HZ_PARTIES_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTIES_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTIES_TFM_TBL.DMT_HZ_PARTIES_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTIES_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_HZ_PARTIES_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITES_STG_TBL.SYS_C00127317
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITES_TFM_TBL.DMT_HZ_PSITES_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PSITES_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITES_TFM_TBL.DMT_HZ_PSITES_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PSITES_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_HZ_PARTY_SITES_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITE_USES_STG_TBL.SYS_C00127318
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITE_USES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITE_USES_TFM_TBL.DMT_HZ_PSUSE_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PSUSE_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITE_USES_TFM_TBL.DMT_HZ_PSUSE_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PSUSE_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_HZ_PARTY_SITE_USES_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PAY_REL_STG_TBL.SYS_C00128157
begin
  execute immediate 'ALTER TABLE "DMT_PAY_REL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PAY_REL_TFM_TBL.DMT_PAY_REL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PAY_REL_TFM_TBL" ADD CONSTRAINT "DMT_PAY_REL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PAY_REL_TFM_TBL.DMT_PAY_REL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PAY_REL_TFM_TBL" ADD CONSTRAINT "DMT_PAY_REL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PAY_REL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_RATING_STG_TBL.SYS_C00128166
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_RATING_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_RATING_TFM_TBL.DMT_PERF_EVAL_RATING_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_RATING_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_RATING_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_RATING_TFM_TBL.DMT_PERF_EVAL_RATING_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_RATING_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_RATING_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERF_EVAL_RATING_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_STG_TBL.SYS_C00128165
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_TFM_TBL.DMT_PERF_EVAL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_TFM_TBL.DMT_PERF_EVAL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERF_EVAL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_ADDR_STG_TBL.SYS_C00128147
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_ADDR_TFM_TBL.DMT_PADDR_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_PADDR_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_ADDR_TFM_TBL.DMT_PADDR_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_PADDR_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERSON_ADDR_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_EMAIL_STG_TBL.SYS_C00128145
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_EMAIL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_EMAIL_TFM_TBL.DMT_PEMAIL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_EMAIL_TFM_TBL" ADD CONSTRAINT "DMT_PEMAIL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_EMAIL_TFM_TBL.DMT_PEMAIL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_EMAIL_TFM_TBL" ADD CONSTRAINT "DMT_PEMAIL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERSON_EMAIL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_LEGISL_STG_TBL.SYS_C00128149
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_LEGISL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_LEGISL_TFM_TBL.DMT_PLEGISL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_LEGISL_TFM_TBL" ADD CONSTRAINT "DMT_PLEGISL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_LEGISL_TFM_TBL.DMT_PLEGISL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_LEGISL_TFM_TBL" ADD CONSTRAINT "DMT_PLEGISL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERSON_LEGISL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NAME_STG_TBL.SYS_C00128144
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NAME_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NAME_TFM_TBL.DMT_PNAME_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NAME_TFM_TBL" ADD CONSTRAINT "DMT_PNAME_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NAME_TFM_TBL.DMT_PNAME_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NAME_TFM_TBL" ADD CONSTRAINT "DMT_PNAME_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERSON_NAME_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NID_STG_TBL.SYS_C00128148
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NID_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NID_TFM_TBL.DMT_PNID_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NID_TFM_TBL" ADD CONSTRAINT "DMT_PNID_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NID_TFM_TBL.DMT_PNID_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NID_TFM_TBL" ADD CONSTRAINT "DMT_PNID_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERSON_NID_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_PHONE_STG_TBL.SYS_C00128146
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_PHONE_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_PHONE_TFM_TBL.DMT_PPHONE_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_PHONE_TFM_TBL" ADD CONSTRAINT "DMT_PPHONE_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_PHONE_TFM_TBL.DMT_PPHONE_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_PHONE_TFM_TBL" ADD CONSTRAINT "DMT_PPHONE_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PERSON_PHONE_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJB_BILL_EVENTS_STG_TBL.SYS_C00127330
begin
  execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJB_BILL_EVENTS_TFM_TBL.DMT_PJB_BE_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD CONSTRAINT "DMT_PJB_BE_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJB_BILL_EVENTS_TFM_TBL.DMT_PJB_BE_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD CONSTRAINT "DMT_PJB_BE_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PJB_BILL_EVENTS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_EXPENDITURES_STG_TBL.SYS_C00127331
begin
  execute immediate 'ALTER TABLE "DMT_PJC_EXPENDITURES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_EXPENDITURES_TFM_TBL.DMT_PJC_EXP_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJC_EXPENDITURES_TFM_TBL" ADD CONSTRAINT "DMT_PJC_EXP_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_EXPENDITURES_TFM_TBL.DMT_PJC_EXP_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJC_EXPENDITURES_TFM_TBL" ADD CONSTRAINT "DMT_PJC_EXP_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PJC_EXPENDITURES_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_TXN_CONTROLS_STG_TBL.SYS_C00127329
begin
  execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_TXN_CONTROLS_TFM_TBL.DMT_PJC_TC_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_TFM_TBL" ADD CONSTRAINT "DMT_PJC_TC_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_TXN_CONTROLS_TFM_TBL.DMT_PJC_TC_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_TFM_TBL" ADD CONSTRAINT "DMT_PJC_TC_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PJC_TXN_CONTROLS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_PROJECTS_STG_TBL.SYS_C00127326
begin
  execute immediate 'ALTER TABLE "DMT_PJF_PROJECTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_PROJECTS_TFM_TBL.DMT_PJF_PRJ_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_PROJECTS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_PRJ_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_PROJECTS_TFM_TBL.DMT_PJF_PRJ_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_PROJECTS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_PRJ_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PJF_PROJECTS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TASKS_STG_TBL.SYS_C00127327
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TASKS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TASKS_TFM_TBL.DMT_PJF_TSK_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TASKS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TSK_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TASKS_TFM_TBL.DMT_PJF_TSK_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TASKS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TSK_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PJF_TASKS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TEAM_MEMBERS_STG_TBL.SYS_C00127328
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TEAM_MEMBERS_TFM_TBL.DMT_PJF_TM_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TM_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TEAM_MEMBERS_TFM_TBL.DMT_PJF_TM_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TM_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PJF_TEAM_MEMBERS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PLAN_BUDGET_STG_TBL.SYS_C00127377
begin
  execute immediate 'ALTER TABLE "DMT_PLAN_BUDGET_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_DISTS_STG_TBL.SYS_C00127383
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_DISTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_HEADERS_STG_TBL.SYS_C00127381
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_LINES_STG_TBL.SYS_C00127382
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_LINES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUPPLIERS_STG_TBL.SYS_C00127306
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUPPLIERS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUPPLIERS_TFM_TBL.DMT_POZ_SUP_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUPPLIERS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUPPLIERS_TFM_TBL.DMT_POZ_SUP_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUPPLIERS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_POZ_SUPPLIERS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_ADDR_STG_TBL.SYS_C00127309
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_ADDR_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_ADDR_TFM_TBL.DMT_POZ_SUP_ADDR_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_ADDR_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_ADDR_TFM_TBL.DMT_POZ_SUP_ADDR_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_ADDR_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_POZ_SUP_ADDR_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_CONTACTS_STG_TBL.SYS_C00127308
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_CONTACTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_CONTACTS_TFM_TBL.DMT_POZ_SUP_CONT_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_CONTACTS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_CONT_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_CONTACTS_TFM_TBL.DMT_POZ_SUP_CONT_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_CONTACTS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_CONT_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_POZ_SUP_CONTACTS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_ASSN_STG_TBL.SYS_C00127310
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_ASSN_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_ASSN_TFM_TBL.DMT_POZ_SUP_SITE_ASSN_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_ASSN_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_ASSN_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_ASSN_TFM_TBL.DMT_POZ_SUP_SITE_ASSN_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_ASSN_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_ASSN_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_POZ_SUP_SITE_ASSN_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_STG_TBL.SYS_C00127307
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_TFM_TBL.DMT_POZ_SUP_SITE_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_TFM_TBL.DMT_POZ_SUP_SITE_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_POZ_SUP_SITE_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_DISTS_INT_STG_TBL.SYS_C00127314
begin
  execute immediate 'ALTER TABLE "DMT_PO_DISTS_INT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_DISTS_INT_TFM_TBL.DMT_PO_DIST_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_DISTS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_DIST_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_DISTS_INT_TFM_TBL.DMT_PO_DIST_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_DISTS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_DIST_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PO_DISTS_INT_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_HEADERS_INT_STG_TBL.SYS_C00127311
begin
  execute immediate 'ALTER TABLE "DMT_PO_HEADERS_INT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_HEADERS_INT_TFM_TBL.DMT_PO_HDR_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_HEADERS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_HDR_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_HEADERS_INT_TFM_TBL.DMT_PO_HDR_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_HEADERS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_HDR_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PO_HEADERS_INT_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINES_INT_STG_TBL.SYS_C00127312
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINES_INT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINES_INT_TFM_TBL.DMT_PO_LINE_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LINE_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINES_INT_TFM_TBL.DMT_PO_LINE_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LINE_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PO_LINES_INT_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINE_LOCS_INT_STG_TBL.SYS_C00127313
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINE_LOCS_INT_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINE_LOCS_INT_TFM_TBL.DMT_PO_LOC_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINE_LOCS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LOC_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINE_LOCS_INT_TFM_TBL.DMT_PO_LOC_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINE_LOCS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LOC_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_PO_LINE_LOCS_INT_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_DISTS_STG_TBL.SYS_C00127323
begin
  execute immediate 'ALTER TABLE "DMT_RA_DISTS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_DISTS_TFM_TBL.DMT_RA_DISTS_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" ADD CONSTRAINT "DMT_RA_DISTS_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_DISTS_TFM_TBL.DMT_RA_DISTS_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" ADD CONSTRAINT "DMT_RA_DISTS_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_RA_DISTS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_LINES_STG_TBL.SYS_C00127322
begin
  execute immediate 'ALTER TABLE "DMT_RA_LINES_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_LINES_TFM_TBL.DMT_RA_LINES_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_RA_LINES_TFM_TBL" ADD CONSTRAINT "DMT_RA_LINES_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_LINES_TFM_TBL.DMT_RA_LINES_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_RA_LINES_TFM_TBL" ADD CONSTRAINT "DMT_RA_LINES_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_RA_LINES_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_HEADERS_STG_TBL.SYS_C00127347
begin
  execute immediate 'ALTER TABLE "DMT_RCV_HEADERS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_HEADERS_TFM_TBL.DMT_RCV_HDR_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_RCV_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_HDR_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_HEADERS_TFM_TBL.DMT_RCV_HDR_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_RCV_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_HDR_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_RCV_HEADERS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_TRANSACTIONS_STG_TBL.SYS_C00127348
begin
  execute immediate 'ALTER TABLE "DMT_RCV_TRANSACTIONS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_TRANSACTIONS_TFM_TBL.DMT_RCV_TXN_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_RCV_TRANSACTIONS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_TXN_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_TRANSACTIONS_TFM_TBL.DMT_RCV_TXN_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_RCV_TRANSACTIONS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_TXN_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_RCV_TRANSACTIONS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SALARY_STG_TBL.SYS_C00128152
begin
  execute immediate 'ALTER TABLE "DMT_SALARY_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SALARY_TFM_TBL.DMT_SALARY_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_SALARY_TFM_TBL" ADD CONSTRAINT "DMT_SALARY_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SALARY_TFM_TBL.DMT_SALARY_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_SALARY_TFM_TBL" ADD CONSTRAINT "DMT_SALARY_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_SALARY_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SAL_BASIS_STG_TBL.SYS_C00128153
begin
  execute immediate 'ALTER TABLE "DMT_SAL_BASIS_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SAL_BASIS_TFM_TBL.DMT_SAL_BASIS_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_SAL_BASIS_TFM_TBL" ADD CONSTRAINT "DMT_SAL_BASIS_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SAL_BASIS_TFM_TBL.DMT_SAL_BASIS_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_SAL_BASIS_TFM_TBL" ADD CONSTRAINT "DMT_SAL_BASIS_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_SAL_BASIS_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_ITEM_STG_TBL.SYS_C00128164
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_ITEM_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_ITEM_TFM_TBL.DMT_TALENT_PROF_ITEM_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_ITEM_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_ITEM_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_ITEM_TFM_TBL.DMT_TALENT_PROF_ITEM_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_ITEM_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_ITEM_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_TALENT_PROF_ITEM_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_STG_TBL.SYS_C00128163
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_TFM_TBL.DMT_TALENT_PROF_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_TFM_TBL.DMT_TALENT_PROF_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_TALENT_PROF_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_COMP_STG_TBL.SYS_C00128159
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_COMP_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_COMP_TFM_TBL.DMT_TAX_CARD_COMP_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_COMP_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_COMP_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_COMP_TFM_TBL.DMT_TAX_CARD_COMP_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_COMP_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_COMP_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_TAX_CARD_COMP_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_STG_TBL.SYS_C00128158
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_TFM_TBL.DMT_TAX_CARD_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_TFM_TBL.DMT_TAX_CARD_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_TAX_CARD_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_UPLOAD_DICT_TBL.DMT_UPLOAD_DICT_OBJ_FK
begin
  execute immediate 'ALTER TABLE "DMT_UPLOAD_DICT_TBL" ADD CONSTRAINT "DMT_UPLOAD_DICT_OBJ_FK" FOREIGN KEY ("OBJECT_CODE")
	  REFERENCES "DMT_UPLOAD_OBJECT_TBL" ("OBJECT_CODE") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_UPLOAD_ERROR_TBL.DMT_UPLOAD_ERR_LOG_FK
begin
  execute immediate 'ALTER TABLE "DMT_UPLOAD_ERROR_TBL" ADD CONSTRAINT "DMT_UPLOAD_ERR_LOG_FK" FOREIGN KEY ("LOG_ID")
	  REFERENCES "DMT_UPLOAD_LOG_TBL" ("LOG_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_DTL_STG_TBL.SYS_C00128156
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_DTL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_DTL_TFM_TBL.DMT_W2_BAL_DTL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_DTL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_DTL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_DTL_TFM_TBL.DMT_W2_BAL_DTL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_DTL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_DTL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_W2_BAL_DTL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_STG_TBL.SYS_C00128155
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_TFM_TBL.DMT_W2_BAL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_TFM_TBL.DMT_W2_BAL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_W2_BAL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORKER_STG_TBL.SYS_C00128143
begin
  execute immediate 'ALTER TABLE "DMT_WORKER_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORKER_TFM_TBL.DMT_WORKER_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORKER_TFM_TBL" ADD CONSTRAINT "DMT_WORKER_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORKER_TFM_TBL.DMT_WORKER_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORKER_TFM_TBL" ADD CONSTRAINT "DMT_WORKER_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_WORKER_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_QUEUE_TBL.DMT_WQ_RUN_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_QUEUE_TBL" ADD CONSTRAINT "DMT_WQ_RUN_FK" FOREIGN KEY ("RUN_ID")
	  REFERENCES "DMT_PIPELINE_RUN_TBL" ("RUN_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_REL_STG_TBL.SYS_C00128150
begin
  execute immediate 'ALTER TABLE "DMT_WORK_REL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_REL_TFM_TBL.DMT_WORK_REL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_REL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_REL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_REL_TFM_TBL.DMT_WORK_REL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_REL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_REL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_WORK_REL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_DTL_STG_TBL.SYS_C00128168
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_DTL_TFM_TBL.DMT_WORK_SCHED_DTL_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_DTL_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_DTL_TFM_TBL.DMT_WORK_SCHED_DTL_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_DTL_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_WORK_SCHED_DTL_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_STG_TBL.SYS_C00128167
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_STG_TBL" ADD FOREIGN KEY ("SCENARIO_ID")
	  REFERENCES "DMT_SCENARIO_TBL" ("SCENARIO_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_TFM_TBL.DMT_WORK_SCHED_TFM_CSV_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_TFM_CSV_FK" FOREIGN KEY ("FBDI_CSV_ID")
	  REFERENCES "DMT_FBDI_CSV_TBL" ("FBDI_CSV_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_TFM_TBL.DMT_WORK_SCHED_TFM_STG_FK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_TFM_STG_FK" FOREIGN KEY ("STG_SEQUENCE_ID")
	  REFERENCES "DMT_WORK_SCHED_STG_TBL" ("STG_SEQUENCE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- ---------------------------------------------------------------------------
-- WORK_QUEUE_ID foreign keys (work-queue-ID granularity foundation, 2026-07-20;
-- DMT_DESIGN section 7 accepted 2026-07-20, docs/FIX_PLAN.md item 1). Every TFM
-- table and the FBDI CSV/ZIP holding tables reference the work item they belong
-- to. Nullable for now (NOT NULL is a later phase once code stamps it).
-- ---------------------------------------------------------------------------
-- DMT_ABSENCE_TFM_TBL.DMT_ABSENCE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_ABSENCE_TFM_TBL" ADD CONSTRAINT "DMT_ABSENCE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICE_LINES_INT_TFM_TBL.DMT_AP_INV_LINES_INT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICE_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INV_LINES_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICES_INT_TFM_TBL.DMT_AP_INVOICES_INT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INVOICES_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_PAY_TERM_HDR_TFM_TBL.DMT_AP_PAY_TERM_HDR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_HDR_TFM_TBL" ADD CONSTRAINT "DMT_AP_PAY_TERM_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_PAY_TERM_LINE_TFM_TBL.DMT_AP_PAY_TERM_LINE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_LINE_TFM_TBL" ADD CONSTRAINT "DMT_AP_PAY_TERM_LINE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ASSIGNMENT_TFM_TBL.DMT_ASSIGNMENT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_ASSIGNMENT_TFM_TBL" ADD CONSTRAINT "DMT_ASSIGNMENT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_BENFY_TFM_TBL.DMT_BEN_BENFY_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_BENFY_TFM_TBL" ADD CONSTRAINT "DMT_BEN_BENFY_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_DEPEND_TFM_TBL.DMT_BEN_DEPEND_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_DEPEND_TFM_TBL" ADD CONSTRAINT "DMT_BEN_DEPEND_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_PARTIC_TFM_TBL.DMT_BEN_PARTIC_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_BEN_PARTIC_TFM_TBL" ADD CONSTRAINT "DMT_BEN_PARTIC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_CE_BANK_ACCT_TFM_TBL.DMT_CE_BANK_ACCT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_CE_BANK_ACCT_TFM_TBL" ADD CONSTRAINT "DMT_CE_BANK_ACCT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_CE_BANK_TFM_TBL.DMT_CE_BANK_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_CE_BANK_TFM_TBL" ADD CONSTRAINT "DMT_CE_BANK_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_CE_BRANCH_TFM_TBL.DMT_CE_BRANCH_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_CE_BRANCH_TFM_TBL" ADD CONSTRAINT "DMT_CE_BRANCH_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_EGP_ITEM_CAT_TFM_TBL.DMT_EGP_ITEM_CAT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_EGP_ITEM_CAT_TFM_TBL" ADD CONSTRAINT "DMT_EGP_ITEM_CAT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_EGP_ITEM_TFM_TBL.DMT_EGP_ITEM_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_EGP_ITEM_TFM_TBL" ADD CONSTRAINT "DMT_EGP_ITEM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_ASSIGN_TFM_TBL.DMT_FA_ASSET_ASSIGN_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_TFM_TBL" ADD CONSTRAINT "DMT_FA_ASSET_ASSIGN_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_BOOK_TFM_TBL.DMT_FA_ASSET_BOOK_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" ADD CONSTRAINT "DMT_FA_ASSET_BOOK_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_HDR_TFM_TBL.DMT_FA_ASSET_HDR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_HDR_TFM_TBL" ADD CONSTRAINT "DMT_FA_ASSET_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_LOOKUP_TYPE_TFM_TBL.DMT_FND_LKP_TYPE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FND_LOOKUP_TYPE_TFM_TBL" ADD CONSTRAINT "DMT_FND_LKP_TYPE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_LOOKUP_VALUE_TFM_TBL.DMT_FND_LKP_VAL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FND_LOOKUP_VALUE_TFM_TBL" ADD CONSTRAINT "DMT_FND_LKP_VAL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_VS_SET_TFM_TBL.DMT_FND_VS_SET_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FND_VS_SET_TFM_TBL" ADD CONSTRAINT "DMT_FND_VS_SET_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_VS_VALUE_TFM_TBL.DMT_FND_VS_VALUE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FND_VS_VALUE_TFM_TBL" ADD CONSTRAINT "DMT_FND_VS_VALUE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GL_BUDGET_INT_TFM_TBL.DMT_GL_BUDGET_INT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_TFM_TBL" ADD CONSTRAINT "DMT_GL_BUDGET_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GL_CALENDAR_TFM_TBL.DMT_GL_CALENDAR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GL_CALENDAR_TFM_TBL" ADD CONSTRAINT "DMT_GL_CALENDAR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GL_INTERFACE_TFM_TBL.DMT_GL_INTERFACE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GL_INTERFACE_TFM_TBL" ADD CONSTRAINT "DMT_GL_INTERFACE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_BDGT_PRDS_TFM_TBL.DMT_GMS_AWD_BDGT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_BDGT_PRDS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_BDGT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_CERTS_TFM_TBL.DMT_GMS_AWD_CERT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_CERTS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_CERT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_CFDAS_TFM_TBL.DMT_GMS_AWD_CFDA_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_CFDAS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_CFDA_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUND_ALLOC_TFM_TBL.DMT_GMS_AWD_FALLOC_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_ALLOC_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_FALLOC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUND_SRC_TFM_TBL.DMT_GMS_AWD_FSRC_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_SRC_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_FSRC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUNDING_TFM_TBL.DMT_GMS_AWD_FUND_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUNDING_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_FUND_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_HEADERS_TFM_TBL.DMT_GMS_AWD_HDR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_KEYWORDS_TFM_TBL.DMT_GMS_AWD_KW_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_KEYWORDS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_KW_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_ORG_CREDITS_TFM_TBL.DMT_GMS_AWD_ORGCR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_ORGCR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PERSONNEL_TFM_TBL.DMT_GMS_AWD_PERS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL.DMT_GMS_AWD_PFSRC_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PFSRC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL.DMT_GMS_AWD_PTBRD_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PTBRD_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PROJECTS_TFM_TBL.DMT_GMS_AWD_PROJ_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PROJECTS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PROJ_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_REFERENCES_TFM_TBL.DMT_GMS_AWD_REF_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_REFERENCES_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_REF_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_TERMS_TFM_TBL.DMT_GMS_AWD_TERM_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_TERMS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_TERM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCOUNTS_TFM_TBL.DMT_HZ_ACCOUNTS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCOUNTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITE_USES_TFM_TBL.DMT_HZ_ACCT_SITE_USES_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCT_SITE_USES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITES_TFM_TBL.DMT_HZ_ACCT_SITES_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCT_SITES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_LOCATIONS_TFM_TBL.DMT_HZ_LOCATIONS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_LOCATIONS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_LOCATIONS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTIES_TFM_TBL.DMT_HZ_PARTIES_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTIES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITE_USES_TFM_TBL.DMT_HZ_PARTY_SITE_US_WQFK_D7BA
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTY_SITE_US_WQFK_D7BA" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITES_TFM_TBL.DMT_HZ_PARTY_SITES_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTY_SITES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_TRX_LOTS_TFM_TBL.DMT_INV_TRX_LOTS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_INV_TRX_LOTS_TFM_TBL" ADD CONSTRAINT "DMT_INV_TRX_LOTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_TRX_SERIALS_TFM_TBL.DMT_INV_TRX_SERIALS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_INV_TRX_SERIALS_TFM_TBL" ADD CONSTRAINT "DMT_INV_TRX_SERIALS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_TRX_TFM_TBL.DMT_INV_TRX_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_INV_TRX_TFM_TBL" ADD CONSTRAINT "DMT_INV_TRX_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_UOM_TFM_TBL.DMT_INV_UOM_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_INV_UOM_TFM_TBL" ADD CONSTRAINT "DMT_INV_UOM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PAY_REL_TFM_TBL.DMT_PAY_REL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PAY_REL_TFM_TBL" ADD CONSTRAINT "DMT_PAY_REL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_RATING_TFM_TBL.DMT_PERF_EVAL_RATING_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_RATING_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_RATING_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_TFM_TBL.DMT_PERF_EVAL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_ADDR_TFM_TBL.DMT_PERSON_ADDR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_ADDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_EMAIL_TFM_TBL.DMT_PERSON_EMAIL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_EMAIL_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_EMAIL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_LEGISL_TFM_TBL.DMT_PERSON_LEGISL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_LEGISL_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_LEGISL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NAME_TFM_TBL.DMT_PERSON_NAME_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NAME_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_NAME_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NID_TFM_TBL.DMT_PERSON_NID_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NID_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_NID_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_PHONE_TFM_TBL.DMT_PERSON_PHONE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_PHONE_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_PHONE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJB_BILL_EVENTS_TFM_TBL.DMT_PJB_BILL_EVENTS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD CONSTRAINT "DMT_PJB_BILL_EVENTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_EXPENDITURES_TFM_TBL.DMT_PJC_EXPENDITURES_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PJC_EXPENDITURES_TFM_TBL" ADD CONSTRAINT "DMT_PJC_EXPENDITURES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_TXN_CONTROLS_TFM_TBL.DMT_PJC_TXN_CONTROLS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_TFM_TBL" ADD CONSTRAINT "DMT_PJC_TXN_CONTROLS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_PROJECTS_TFM_TBL.DMT_PJF_PROJECTS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_PROJECTS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_PROJECTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TASKS_TFM_TBL.DMT_PJF_TASKS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TASKS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TASKS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TEAM_MEMBERS_TFM_TBL.DMT_PJF_TEAM_MEMBERS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TEAM_MEMBERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PLAN_BUDGET_TFM_TBL.DMT_PLAN_BUDGET_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PLAN_BUDGET_TFM_TBL" ADD CONSTRAINT "DMT_PLAN_BUDGET_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_DISTS_INT_TFM_TBL.DMT_PO_DISTS_INT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PO_DISTS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_DISTS_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_HEADERS_INT_TFM_TBL.DMT_PO_HEADERS_INT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PO_HEADERS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_HEADERS_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINE_LOCS_INT_TFM_TBL.DMT_PO_LINE_LOCS_INT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINE_LOCS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LINE_LOCS_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINES_INT_TFM_TBL.DMT_PO_LINES_INT_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LINES_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_DISTS_TFM_TBL.DMT_POR_REQ_DIST_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_DISTS_TFM_TBL" ADD CONSTRAINT "DMT_POR_REQ_DIST_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_HEADERS_TFM_TBL.DMT_POR_REQ_HDR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_POR_REQ_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_LINES_TFM_TBL.DMT_POR_REQ_LN_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_LINES_TFM_TBL" ADD CONSTRAINT "DMT_POR_REQ_LN_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_ADDR_TFM_TBL.DMT_POZ_SUP_ADDR_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_ADDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_CONTACTS_TFM_TBL.DMT_POZ_SUP_CONTACTS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_CONTACTS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_CONTACTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_ASSN_TFM_TBL.DMT_POZ_SUP_SITE_ASSN_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_ASSN_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_ASSN_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_TFM_TBL.DMT_POZ_SUP_SITE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUPPLIERS_TFM_TBL.DMT_POZ_SUPPLIERS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUPPLIERS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUPPLIERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PRJ_BUDGET_TFM_TBL.DMT_PRJ_BUDGET_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" ADD CONSTRAINT "DMT_PRJ_BUDGET_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_DISTS_TFM_TBL.DMT_RA_DISTS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" ADD CONSTRAINT "DMT_RA_DISTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_LINES_TFM_TBL.DMT_RA_LINES_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_RA_LINES_TFM_TBL" ADD CONSTRAINT "DMT_RA_LINES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_HEADERS_TFM_TBL.DMT_RCV_HEADERS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_RCV_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_HEADERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_TRANSACTIONS_TFM_TBL.DMT_RCV_TRANSACTIONS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_RCV_TRANSACTIONS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_TRANSACTIONS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SAL_BASIS_TFM_TBL.DMT_SAL_BASIS_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_SAL_BASIS_TFM_TBL" ADD CONSTRAINT "DMT_SAL_BASIS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SALARY_TFM_TBL.DMT_SALARY_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_SALARY_TFM_TBL" ADD CONSTRAINT "DMT_SALARY_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_ITEM_TFM_TBL.DMT_TALENT_PROF_ITEM_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_ITEM_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_ITEM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_TFM_TBL.DMT_TALENT_PROF_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_COMP_TFM_TBL.DMT_TAX_CARD_COMP_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_COMP_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_COMP_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_TFM_TBL.DMT_TAX_CARD_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_DTL_TFM_TBL.DMT_W2_BAL_DTL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_DTL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_DTL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_TFM_TBL.DMT_W2_BAL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_REL_TFM_TBL.DMT_WORK_REL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_REL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_REL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_DTL_TFM_TBL.DMT_WORK_SCHED_DTL_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_DTL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_TFM_TBL.DMT_WORK_SCHED_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORKER_TFM_TBL.DMT_WORKER_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_WORKER_TFM_TBL" ADD CONSTRAINT "DMT_WORKER_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ZX_RATE_TFM_TBL.DMT_ZX_RATE_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_ZX_RATE_TFM_TBL" ADD CONSTRAINT "DMT_ZX_RATE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ZX_REGIME_TFM_TBL.DMT_ZX_REGIME_TFM_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_ZX_REGIME_TFM_TBL" ADD CONSTRAINT "DMT_ZX_REGIME_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FBDI_CSV_TBL.DMT_FBDI_CSV_TBL_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FBDI_CSV_TBL" ADD CONSTRAINT "DMT_FBDI_CSV_TBL_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FBDI_ZIP_TBL.DMT_FBDI_ZIP_TBL_WQFK
begin
  execute immediate 'ALTER TABLE "DMT_FBDI_ZIP_TBL" ADD CONSTRAINT "DMT_FBDI_ZIP_TBL_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
	  REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

