-- Seed data for DMT_CEMLI_SPLIT_CFG (7 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
begin
  insert into "DMT_CEMLI_SPLIT_CFG" ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN") values ('1099Invoices','DMT_AP_INVOICES_INT_TFM_TBL','ORG_ID','ORG_ID','ORG_ID = :partition_key','STATUS');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CEMLI_SPLIT_CFG" ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN") values ('APInvoices','DMT_AP_INVOICES_INT_TFM_TBL','ORG_ID','ORG_ID','ORG_ID = :partition_key','STATUS');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CEMLI_SPLIT_CFG" ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN") values ('ARInvoices','DMT_RA_LINES_TFM_TBL','BU_NAME','BU_NAME','BU_NAME = :partition_key','STATUS');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CEMLI_SPLIT_CFG" ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN") values ('BlanketPOs','DMT_PO_HEADERS_INT_TFM_TBL','PROCUREMENT_BU','PROCUREMENT_BU','PROCUREMENT_BU = :partition_key','STATUS');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CEMLI_SPLIT_CFG" ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN") values ('Contracts','DMT_PO_HEADERS_INT_TFM_TBL','PROCUREMENT_BU','PROCUREMENT_BU','PROCUREMENT_BU = :partition_key','STATUS');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CEMLI_SPLIT_CFG" ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN") values ('GLBalances','DMT_GL_INTERFACE_TFM_TBL','LEDGER_NAME','LEDGER_NAME','LEDGER_NAME = :partition_key','TFM_STATUS');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_CEMLI_SPLIT_CFG" ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN") values ('PurchaseOrders','DMT_PO_HEADERS_INT_TFM_TBL','PROCUREMENT_BU','PROCUREMENT_BU','PROCUREMENT_BU = :partition_key','STATUS');
exception when dup_val_on_index then null;
end;
/
commit;
