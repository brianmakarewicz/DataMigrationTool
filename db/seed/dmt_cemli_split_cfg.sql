-- Seed data for DMT_CEMLI_SPLIT_CFG -- per-object FBDI split configuration
-- (one row per object whose generator splits one TFM table into several
-- zips: by BU, ledger, or org).
--
-- MERGE on the business key (CEMLI_CODE -- the table's primary key; the
-- registry-converge rule in DMT_DESIGN.html section 7, accepted 2026-07-08,
-- names split config as a registry seed) so a corrected committed value
-- propagates to an existing database on re-install.
--
-- STATUS_COLUMN is uniformly TFM_STATUS per the STG/TFM infra-column
-- dictionary (section 7, accepted 2026-07-08): the engine reads the status
-- column name from this registry, so a row carrying the retired name STATUS
-- makes the split step issue SQL against a column that no longer exists
-- (fixed 2026-07-09, blind conformance-tranche review F1).
merge into "DMT_CEMLI_SPLIT_CFG" t
using (
    select 'APInvoices' cemli_code, 'DMT_AP_INVOICES_INT_TFM_TBL' tfm_table, 'ORG_ID' partition_columns, 'ORG_ID' label_expression, 'ORG_ID = :partition_key' where_template, 'TFM_STATUS' status_column from dual
    union all select 'ARInvoices', 'DMT_RA_LINES_TFM_TBL', 'BU_NAME', 'BU_NAME', 'BU_NAME = :partition_key', 'TFM_STATUS' from dual
    union all select 'BlanketPOs', 'DMT_PO_HEADERS_INT_TFM_TBL', 'PROCUREMENT_BU', 'PROCUREMENT_BU', 'PROCUREMENT_BU = :partition_key', 'TFM_STATUS' from dual
    union all select 'Contracts', 'DMT_PO_HEADERS_INT_TFM_TBL', 'PROCUREMENT_BU', 'PROCUREMENT_BU', 'PROCUREMENT_BU = :partition_key', 'TFM_STATUS' from dual
    union all select 'GLBalances', 'DMT_GL_INTERFACE_TFM_TBL', 'LEDGER_NAME', 'LEDGER_NAME', 'LEDGER_NAME = :partition_key', 'TFM_STATUS' from dual
    union all select 'PurchaseOrders', 'DMT_PO_HEADERS_INT_TFM_TBL', 'PROCUREMENT_BU', 'PROCUREMENT_BU', 'PROCUREMENT_BU = :partition_key', 'TFM_STATUS' from dual
) s
on (t."CEMLI_CODE" = s.cemli_code)
when matched then update set
    t."TFM_TABLE"         = s.tfm_table,
    t."PARTITION_COLUMNS" = s.partition_columns,
    t."LABEL_EXPRESSION"  = s.label_expression,
    t."WHERE_TEMPLATE"    = s.where_template,
    t."STATUS_COLUMN"     = s.status_column
when not matched then insert
    ("CEMLI_CODE","TFM_TABLE","PARTITION_COLUMNS","LABEL_EXPRESSION","WHERE_TEMPLATE","STATUS_COLUMN")
    values (s.cemli_code, s.tfm_table, s.partition_columns, s.label_expression, s.where_template, s.status_column);

commit;
