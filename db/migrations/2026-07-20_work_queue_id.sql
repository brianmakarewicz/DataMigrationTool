-- =========================================================================
-- Migration: WORK_QUEUE_ID granularity foundation  (2026-07-20)
-- docs/FIX_PLAN.md item 1; DMT_DESIGN section 7 accepted 2026-07-20.
--
-- Adds a nullable WORK_QUEUE_ID NUMBER column + FK to
-- DMT_WORK_QUEUE_TBL(QUEUE_ID) to every object TFM table and to the FBDI
-- CSV/ZIP holding tables, and a self-referencing PARENT_QUEUE_ID to
-- DMT_WORK_QUEUE_TBL for spawned-child traceability.
--
-- ADDITIVE + NULLABLE only. NOT NULL is deferred to a later phase (after the
-- pipeline code stamps the column). No package bodies are touched here.
--
-- Idempotent: column adds are guarded by a USER_TAB_COLUMNS check; FK adds
-- tolerate ORA-00955 (name in use) / -02275 (FK already exists) / -02264.
-- Safe to re-run. Deploy as DMT_OWNER (never ADMIN).
-- =========================================================================
set define off
set serveroutput on

prompt == PARENT_QUEUE_ID on DMT_WORK_QUEUE_TBL (self-reference) ==
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_WORK_QUEUE_TBL' and column_name = 'PARENT_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_WORK_QUEUE_TBL" ADD ("PARENT_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_WORK_QUEUE_TBL" ADD CONSTRAINT "DMT_WORK_QUEUE_PARENT_FK"
    FOREIGN KEY ("PARENT_QUEUE_ID") REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/
begin
  execute immediate 'CREATE INDEX "DMT_WORK_QUEUE_N2" ON "DMT_WORK_QUEUE_TBL" ("PARENT_QUEUE_ID")';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/

prompt == WORK_QUEUE_ID column + FK on 99 TFM / FBDI tables ==

-- DMT_ABSENCE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_ABSENCE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_ABSENCE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_ABSENCE_TFM_TBL" ADD CONSTRAINT "DMT_ABSENCE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICE_LINES_INT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_AP_INVOICE_LINES_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_AP_INVOICE_LINES_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICE_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INV_LINES_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_INVOICES_INT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_AP_INVOICES_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_AP_INVOICES_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_AP_INVOICES_INT_TFM_TBL" ADD CONSTRAINT "DMT_AP_INVOICES_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_PAY_TERM_HDR_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_AP_PAY_TERM_HDR_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_HDR_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_HDR_TFM_TBL" ADD CONSTRAINT "DMT_AP_PAY_TERM_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_AP_PAY_TERM_LINE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_AP_PAY_TERM_LINE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_LINE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_AP_PAY_TERM_LINE_TFM_TBL" ADD CONSTRAINT "DMT_AP_PAY_TERM_LINE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ASSIGNMENT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_ASSIGNMENT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_ASSIGNMENT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_ASSIGNMENT_TFM_TBL" ADD CONSTRAINT "DMT_ASSIGNMENT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_BENFY_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_BEN_BENFY_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_BEN_BENFY_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_BEN_BENFY_TFM_TBL" ADD CONSTRAINT "DMT_BEN_BENFY_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_DEPEND_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_BEN_DEPEND_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_BEN_DEPEND_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_BEN_DEPEND_TFM_TBL" ADD CONSTRAINT "DMT_BEN_DEPEND_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_BEN_PARTIC_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_BEN_PARTIC_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_BEN_PARTIC_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_BEN_PARTIC_TFM_TBL" ADD CONSTRAINT "DMT_BEN_PARTIC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_CE_BANK_ACCT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_CE_BANK_ACCT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_CE_BANK_ACCT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_CE_BANK_ACCT_TFM_TBL" ADD CONSTRAINT "DMT_CE_BANK_ACCT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_CE_BANK_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_CE_BANK_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_CE_BANK_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_CE_BANK_TFM_TBL" ADD CONSTRAINT "DMT_CE_BANK_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_CE_BRANCH_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_CE_BRANCH_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_CE_BRANCH_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_CE_BRANCH_TFM_TBL" ADD CONSTRAINT "DMT_CE_BRANCH_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_EGP_ITEM_CAT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_EGP_ITEM_CAT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_EGP_ITEM_CAT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_EGP_ITEM_CAT_TFM_TBL" ADD CONSTRAINT "DMT_EGP_ITEM_CAT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_EGP_ITEM_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_EGP_ITEM_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_EGP_ITEM_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_EGP_ITEM_TFM_TBL" ADD CONSTRAINT "DMT_EGP_ITEM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_ASSIGN_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FA_ASSET_ASSIGN_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_ASSIGN_TFM_TBL" ADD CONSTRAINT "DMT_FA_ASSET_ASSIGN_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_BOOK_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FA_ASSET_BOOK_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_BOOK_TFM_TBL" ADD CONSTRAINT "DMT_FA_ASSET_BOOK_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FA_ASSET_HDR_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FA_ASSET_HDR_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FA_ASSET_HDR_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FA_ASSET_HDR_TFM_TBL" ADD CONSTRAINT "DMT_FA_ASSET_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_LOOKUP_TYPE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FND_LOOKUP_TYPE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FND_LOOKUP_TYPE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FND_LOOKUP_TYPE_TFM_TBL" ADD CONSTRAINT "DMT_FND_LKP_TYPE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_LOOKUP_VALUE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FND_LOOKUP_VALUE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FND_LOOKUP_VALUE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FND_LOOKUP_VALUE_TFM_TBL" ADD CONSTRAINT "DMT_FND_LKP_VAL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_VS_SET_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FND_VS_SET_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FND_VS_SET_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FND_VS_SET_TFM_TBL" ADD CONSTRAINT "DMT_FND_VS_SET_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FND_VS_VALUE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FND_VS_VALUE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FND_VS_VALUE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FND_VS_VALUE_TFM_TBL" ADD CONSTRAINT "DMT_FND_VS_VALUE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GL_BUDGET_INT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GL_BUDGET_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GL_BUDGET_INT_TFM_TBL" ADD CONSTRAINT "DMT_GL_BUDGET_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GL_CALENDAR_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GL_CALENDAR_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GL_CALENDAR_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GL_CALENDAR_TFM_TBL" ADD CONSTRAINT "DMT_GL_CALENDAR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GL_INTERFACE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GL_INTERFACE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GL_INTERFACE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GL_INTERFACE_TFM_TBL" ADD CONSTRAINT "DMT_GL_INTERFACE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_BDGT_PRDS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_BDGT_PRDS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_BDGT_PRDS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_BDGT_PRDS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_BDGT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_CERTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_CERTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_CERTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_CERTS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_CERT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_CFDAS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_CFDAS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_CFDAS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_CFDAS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_CFDA_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUND_ALLOC_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_FUND_ALLOC_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_ALLOC_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_ALLOC_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_FALLOC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUND_SRC_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_FUND_SRC_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_SRC_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUND_SRC_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_FSRC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_FUNDING_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_FUNDING_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUNDING_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_FUNDING_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_FUND_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_HEADERS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_HEADERS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_HEADERS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_KEYWORDS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_KEYWORDS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_KEYWORDS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_KEYWORDS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_KW_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_ORG_CREDITS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_ORG_CREDITS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_ORG_CREDITS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_ORGCR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PERSONNEL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PERSONNEL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PERSONNEL_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PFSRC_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PTBRD_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_PROJECTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_PROJECTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_PROJECTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_PROJECTS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_PROJ_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_REFERENCES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_REFERENCES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_REFERENCES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_REFERENCES_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_REF_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_GMS_AWD_TERMS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_GMS_AWD_TERMS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_GMS_AWD_TERMS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_GMS_AWD_TERMS_TFM_TBL" ADD CONSTRAINT "DMT_GMS_AWD_TERM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCOUNTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_ACCOUNTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCOUNTS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCOUNTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITE_USES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_ACCT_SITE_USES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITE_USES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCT_SITE_USES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_ACCT_SITES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_ACCT_SITES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_HZ_ACCT_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_ACCT_SITES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_LOCATIONS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_LOCATIONS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_LOCATIONS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_HZ_LOCATIONS_TFM_TBL" ADD CONSTRAINT "DMT_HZ_LOCATIONS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTIES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_PARTIES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTIES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTIES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITE_USES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_PARTY_SITE_USES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITE_USES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITE_USES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTY_SITE_US_WQFK_D7BA" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_HZ_PARTY_SITES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_HZ_PARTY_SITES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_HZ_PARTY_SITES_TFM_TBL" ADD CONSTRAINT "DMT_HZ_PARTY_SITES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_TRX_LOTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_INV_TRX_LOTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_INV_TRX_LOTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_INV_TRX_LOTS_TFM_TBL" ADD CONSTRAINT "DMT_INV_TRX_LOTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_TRX_SERIALS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_INV_TRX_SERIALS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_INV_TRX_SERIALS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_INV_TRX_SERIALS_TFM_TBL" ADD CONSTRAINT "DMT_INV_TRX_SERIALS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_TRX_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_INV_TRX_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_INV_TRX_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_INV_TRX_TFM_TBL" ADD CONSTRAINT "DMT_INV_TRX_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_INV_UOM_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_INV_UOM_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_INV_UOM_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_INV_UOM_TFM_TBL" ADD CONSTRAINT "DMT_INV_UOM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PAY_REL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PAY_REL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PAY_REL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PAY_REL_TFM_TBL" ADD CONSTRAINT "DMT_PAY_REL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_RATING_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERF_EVAL_RATING_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERF_EVAL_RATING_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_RATING_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_RATING_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERF_EVAL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERF_EVAL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERF_EVAL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERF_EVAL_TFM_TBL" ADD CONSTRAINT "DMT_PERF_EVAL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_ADDR_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_ADDR_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_ADDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_EMAIL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_EMAIL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERSON_EMAIL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_EMAIL_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_EMAIL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_LEGISL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_LEGISL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERSON_LEGISL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_LEGISL_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_LEGISL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NAME_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_NAME_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERSON_NAME_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NAME_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_NAME_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_NID_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_NID_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERSON_NID_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_NID_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_NID_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PERSON_PHONE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PERSON_PHONE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PERSON_PHONE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PERSON_PHONE_TFM_TBL" ADD CONSTRAINT "DMT_PERSON_PHONE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJB_BILL_EVENTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJB_BILL_EVENTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PJB_BILL_EVENTS_TFM_TBL" ADD CONSTRAINT "DMT_PJB_BILL_EVENTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_EXPENDITURES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJC_EXPENDITURES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJC_EXPENDITURES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PJC_EXPENDITURES_TFM_TBL" ADD CONSTRAINT "DMT_PJC_EXPENDITURES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJC_TXN_CONTROLS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJC_TXN_CONTROLS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PJC_TXN_CONTROLS_TFM_TBL" ADD CONSTRAINT "DMT_PJC_TXN_CONTROLS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_PROJECTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJF_PROJECTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJF_PROJECTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PJF_PROJECTS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_PROJECTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TASKS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJF_TASKS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJF_TASKS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TASKS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TASKS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PJF_TEAM_MEMBERS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PJF_TEAM_MEMBERS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PJF_TEAM_MEMBERS_TFM_TBL" ADD CONSTRAINT "DMT_PJF_TEAM_MEMBERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PLAN_BUDGET_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PLAN_BUDGET_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PLAN_BUDGET_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PLAN_BUDGET_TFM_TBL" ADD CONSTRAINT "DMT_PLAN_BUDGET_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_DISTS_INT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PO_DISTS_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PO_DISTS_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PO_DISTS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_DISTS_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_HEADERS_INT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PO_HEADERS_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PO_HEADERS_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PO_HEADERS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_HEADERS_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINE_LOCS_INT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PO_LINE_LOCS_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PO_LINE_LOCS_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINE_LOCS_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LINE_LOCS_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PO_LINES_INT_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PO_LINES_INT_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PO_LINES_INT_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PO_LINES_INT_TFM_TBL" ADD CONSTRAINT "DMT_PO_LINES_INT_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_DISTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POR_REQ_DISTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_DISTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_DISTS_TFM_TBL" ADD CONSTRAINT "DMT_POR_REQ_DIST_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_HEADERS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POR_REQ_HEADERS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_POR_REQ_HDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POR_REQ_LINES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POR_REQ_LINES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POR_REQ_LINES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POR_REQ_LINES_TFM_TBL" ADD CONSTRAINT "DMT_POR_REQ_LN_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_ADDR_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POZ_SUP_ADDR_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POZ_SUP_ADDR_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_ADDR_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_ADDR_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_CONTACTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POZ_SUP_CONTACTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POZ_SUP_CONTACTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_CONTACTS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_CONTACTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_ASSN_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POZ_SUP_SITE_ASSN_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_ASSN_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_ASSN_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_ASSN_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUP_SITE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POZ_SUP_SITE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUP_SITE_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUP_SITE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_POZ_SUPPLIERS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_POZ_SUPPLIERS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_POZ_SUPPLIERS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_POZ_SUPPLIERS_TFM_TBL" ADD CONSTRAINT "DMT_POZ_SUPPLIERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_PRJ_BUDGET_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_PRJ_BUDGET_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_PRJ_BUDGET_TFM_TBL" ADD CONSTRAINT "DMT_PRJ_BUDGET_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_DISTS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_RA_DISTS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_RA_DISTS_TFM_TBL" ADD CONSTRAINT "DMT_RA_DISTS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RA_LINES_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_RA_LINES_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_RA_LINES_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_RA_LINES_TFM_TBL" ADD CONSTRAINT "DMT_RA_LINES_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_HEADERS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_RCV_HEADERS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_RCV_HEADERS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_RCV_HEADERS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_HEADERS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_RCV_TRANSACTIONS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_RCV_TRANSACTIONS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_RCV_TRANSACTIONS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_RCV_TRANSACTIONS_TFM_TBL" ADD CONSTRAINT "DMT_RCV_TRANSACTIONS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SAL_BASIS_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_SAL_BASIS_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_SAL_BASIS_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_SAL_BASIS_TFM_TBL" ADD CONSTRAINT "DMT_SAL_BASIS_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_SALARY_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_SALARY_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_SALARY_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_SALARY_TFM_TBL" ADD CONSTRAINT "DMT_SALARY_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_ITEM_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_TALENT_PROF_ITEM_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_TALENT_PROF_ITEM_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_ITEM_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_ITEM_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TALENT_PROF_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_TALENT_PROF_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_TALENT_PROF_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_TALENT_PROF_TFM_TBL" ADD CONSTRAINT "DMT_TALENT_PROF_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_COMP_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_TAX_CARD_COMP_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_TAX_CARD_COMP_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_COMP_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_COMP_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_TAX_CARD_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_TAX_CARD_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_TAX_CARD_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_TAX_CARD_TFM_TBL" ADD CONSTRAINT "DMT_TAX_CARD_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_DTL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_W2_BAL_DTL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_W2_BAL_DTL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_DTL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_DTL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_W2_BAL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_W2_BAL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_W2_BAL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_W2_BAL_TFM_TBL" ADD CONSTRAINT "DMT_W2_BAL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_REL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_WORK_REL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_WORK_REL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_WORK_REL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_REL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_DTL_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_WORK_SCHED_DTL_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_DTL_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_DTL_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORK_SCHED_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_WORK_SCHED_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_WORK_SCHED_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_WORK_SCHED_TFM_TBL" ADD CONSTRAINT "DMT_WORK_SCHED_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_WORKER_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_WORKER_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_WORKER_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_WORKER_TFM_TBL" ADD CONSTRAINT "DMT_WORKER_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ZX_RATE_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_ZX_RATE_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_ZX_RATE_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_ZX_RATE_TFM_TBL" ADD CONSTRAINT "DMT_ZX_RATE_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_ZX_REGIME_TFM_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_ZX_REGIME_TFM_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_ZX_REGIME_TFM_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_ZX_REGIME_TFM_TBL" ADD CONSTRAINT "DMT_ZX_REGIME_TFM_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FBDI_CSV_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FBDI_CSV_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FBDI_CSV_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FBDI_CSV_TBL" ADD CONSTRAINT "DMT_FBDI_CSV_TBL_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

-- DMT_FBDI_ZIP_TBL
declare
  l_n pls_integer;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_FBDI_ZIP_TBL' and column_name = 'WORK_QUEUE_ID';
  if l_n = 0 then
    execute immediate 'ALTER TABLE "DMT_FBDI_ZIP_TBL" ADD ("WORK_QUEUE_ID" NUMBER)';
  end if;
end;
/
begin
  execute immediate 'ALTER TABLE "DMT_FBDI_ZIP_TBL" ADD CONSTRAINT "DMT_FBDI_ZIP_TBL_WQFK" FOREIGN KEY ("WORK_QUEUE_ID")
    REFERENCES "DMT_WORK_QUEUE_TBL" ("QUEUE_ID") ENABLE';
exception when others then
  if sqlcode not in (-955,-2275,-2264) then raise; end if;
end;
/

prompt == WORK_QUEUE_ID migration complete ==
