-- Seed FBDI upload metadata (GENERATED -- do not edit by hand).
--   Source: test/upload_samples/fbdi_column_maps.py
--   Regenerate: python test/upload_samples/gen_fbdi_metadata_seed.py
--   Checked by: scripts/check_fbdi_upload_mappings.py (fails when this file is stale)
--
-- WHAT THIS DOES
--   The FBDI upload format routes each headerless, positional CSV in an Oracle FBDI
--   zip by its file name to the staging object(s) registered for it in
--   DMT_UPLOAD_FBDI_FILE_TBL, and loads it column-by-position using that file's own
--   positions in DMT_UPLOAD_FBDI_POS_TBL (backlog #792: positions are keyed per FBDI
--   file, so BlanketPOs / Contracts load the shared PO staging tables with their own
--   layouts, and Assets FaMassAdditions.csv feeds both the asset header and the asset
--   book). This seed is the INVERSE of FBDI generation: for every file the pipeline's
--   FBDI generators write, the exact 1-based slot each staging column is written to.
--
--   Source of truth: the FBDI generator packages (db/packages/*_fbdi_gen_pkg), read
--   slot by slot into test/upload_samples/fbdi_column_maps.py.
--
--   Section 1 keeps the legacy per-object copy -- DMT_UPLOAD_OBJECT_TBL.FBDI_CSV_FILENAME
--   and DMT_UPLOAD_DICT_TBL.FBDI_POSITION of the object's first file -- for the
--   per-object test tooling; the upload router and loader do not read it.
--
--   MUST run AFTER DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY (db/seed/dmt_upload_object_tbl.sql):
--   positions are filtered against the dictionary's non-admin columns. Idempotent and
--   convergent: MERGE on the business keys, then delete rows the maps no longer hold.

-- 1) Legacy per-object copy (first file of each object) for the per-object test tooling.
merge into "DMT_UPLOAD_OBJECT_TBL" t
using (
    select 'AP_INVOICES_INT' object_code, 'ApInvoicesInterface.csv' fbdi_csv_filename from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ApInvoiceLinesInterface.csv' fbdi_csv_filename from dual
    union all select 'EGP_ITEM' object_code, 'EgpSystemItemsInterface.csv' fbdi_csv_filename from dual
    union all select 'EGP_ITEM_CAT' object_code, 'EgpItemCategoriesInterface.csv' fbdi_csv_filename from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'FaMassaddDistributions.csv' fbdi_csv_filename from dual
    union all select 'FA_ASSET_BOOK' object_code, 'FaMassAdditions.csv' fbdi_csv_filename from dual
    union all select 'FA_ASSET_HDR' object_code, 'FaMassAdditions.csv' fbdi_csv_filename from dual
    union all select 'GL_BUDGET_INT' object_code, 'GlBudgetInterface.csv' fbdi_csv_filename from dual
    union all select 'GL_INTERFACE' object_code, 'GlInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_BDGT_PRDS' object_code, 'GmsAwardBdgtPeriodsInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_CERTS' object_code, 'GmsAwardCertsInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_CFDAS' object_code, 'GmsAwardCfdasInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'GmsAwardFundingInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_FUND_ALLOC' object_code, 'GmsAwardFundAllocInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'GmsAwardFundSrcInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'GmsAwardHeadersInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_KEYWORDS' object_code, 'GmsAwardKeywordsInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_ORG_CREDITS' object_code, 'GmsAwardOrgCreditsInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'GmsAwardPersonnelInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_PRJ_FUND_SRC' object_code, 'GmsAwardPrjFundSrcInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_PRJ_TSK_BRD' object_code, 'GmsAwardPrjTaskBrdInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'GmsAwardProjectsInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_REFERENCES' object_code, 'GmsAwardReferencesInterface.csv' fbdi_csv_filename from dual
    union all select 'GMS_AWD_TERMS' object_code, 'GmsAwardTermsInterface.csv' fbdi_csv_filename from dual
    union all select 'HZ_ACCOUNTS' object_code, 'HzImpAccountsT.csv' fbdi_csv_filename from dual
    union all select 'HZ_ACCT_SITES' object_code, 'HzImpAcctSitesT.csv' fbdi_csv_filename from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'HzImpAcctSiteUsesT.csv' fbdi_csv_filename from dual
    union all select 'HZ_LOCATIONS' object_code, 'HzImpLocationsT.csv' fbdi_csv_filename from dual
    union all select 'HZ_PARTIES' object_code, 'HzImpPartiesT.csv' fbdi_csv_filename from dual
    union all select 'HZ_PARTY_SITES' object_code, 'HzImpPartySitesT.csv' fbdi_csv_filename from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'HzImpPartySiteUsesT.csv' fbdi_csv_filename from dual
    union all select 'INV_TRX' object_code, 'InvTransactionsInterface.csv' fbdi_csv_filename from dual
    union all select 'INV_TRX_LOTS' object_code, 'InvTransactionLotsInterface.csv' fbdi_csv_filename from dual
    union all select 'INV_TRX_SERIALS' object_code, 'InvSerialNumbersInterface.csv' fbdi_csv_filename from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'PjbBillingEventsXface.csv' fbdi_csv_filename from dual
    union all select 'PJC_EXPENDITURES' object_code, 'PjcTxnXfaceStageAll.csv' fbdi_csv_filename from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'PjcTxnControlsStage.csv' fbdi_csv_filename from dual
    union all select 'PJF_PROJECTS' object_code, 'PjfProjectsAllXface.csv' fbdi_csv_filename from dual
    union all select 'PJF_TASKS' object_code, 'PjfProjElementsXface.csv' fbdi_csv_filename from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'PjfProjectPartiesInt.csv' fbdi_csv_filename from dual
    union all select 'POR_REQ_DISTS' object_code, 'PorReqDistsInterfaceAll.csv' fbdi_csv_filename from dual
    union all select 'POR_REQ_HEADERS' object_code, 'PorReqHeadersInterfaceAll.csv' fbdi_csv_filename from dual
    union all select 'POR_REQ_LINES' object_code, 'PorReqLinesInterfaceAll.csv' fbdi_csv_filename from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PoSupplierImport.csv' fbdi_csv_filename from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PozSupAddressesInt.csv' fbdi_csv_filename from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'PozSupContactsInt.csv' fbdi_csv_filename from dual
    union all select 'POZ_SUP_SITE' object_code, 'PozSupplierSitesInt.csv' fbdi_csv_filename from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'PozSiteAssignmentsInt.csv' fbdi_csv_filename from dual
    union all select 'PO_DISTS_INT' object_code, 'PoDistributionsInterfaceOrder.csv' fbdi_csv_filename from dual
    union all select 'PO_HEADERS_INT' object_code, 'PoHeadersInterfaceOrder.csv' fbdi_csv_filename from dual
    union all select 'PO_LINES_INT' object_code, 'PoLinesInterfaceOrder.csv' fbdi_csv_filename from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'PoLineLocationsInterfaceOrder.csv' fbdi_csv_filename from dual
    union all select 'PRJ_BUDGET' object_code, 'PjoPlanVersionsXface.csv' fbdi_csv_filename from dual
    union all select 'RA_DISTS' object_code, 'RaInterfaceDistributionsAll.csv' fbdi_csv_filename from dual
    union all select 'RA_LINES' object_code, 'RaInterfaceLinesAll.csv' fbdi_csv_filename from dual
) s
on (t."OBJECT_CODE" = s.object_code)
when matched then update set t."FBDI_CSV_FILENAME" = s.fbdi_csv_filename;

update "DMT_UPLOAD_DICT_TBL"
set    "FBDI_POSITION" = null
where  "OBJECT_CODE" in ('AP_INVOICES_INT', 'AP_INVOICE_LINES_INT', 'EGP_ITEM', 'EGP_ITEM_CAT', 'FA_ASSET_ASSIGN', 'FA_ASSET_BOOK', 'FA_ASSET_HDR', 'GL_BUDGET_INT', 'GL_INTERFACE', 'GMS_AWD_BDGT_PRDS', 'GMS_AWD_CERTS', 'GMS_AWD_CFDAS', 'GMS_AWD_FUNDING', 'GMS_AWD_FUND_ALLOC', 'GMS_AWD_FUND_SRC', 'GMS_AWD_HEADERS', 'GMS_AWD_KEYWORDS', 'GMS_AWD_ORG_CREDITS', 'GMS_AWD_PERSONNEL', 'GMS_AWD_PRJ_FUND_SRC', 'GMS_AWD_PRJ_TSK_BRD', 'GMS_AWD_PROJECTS', 'GMS_AWD_REFERENCES', 'GMS_AWD_TERMS', 'HZ_ACCOUNTS', 'HZ_ACCT_SITES', 'HZ_ACCT_SITE_USES', 'HZ_LOCATIONS', 'HZ_PARTIES', 'HZ_PARTY_SITES', 'HZ_PARTY_SITE_USES', 'INV_TRX', 'INV_TRX_LOTS', 'INV_TRX_SERIALS', 'PJB_BILL_EVENTS', 'PJC_EXPENDITURES', 'PJC_TXN_CONTROLS', 'PJF_PROJECTS', 'PJF_TASKS', 'PJF_TEAM_MEMBERS', 'POR_REQ_DISTS', 'POR_REQ_HEADERS', 'POR_REQ_LINES', 'POZ_SUPPLIERS', 'POZ_SUP_ADDR', 'POZ_SUP_CONTACTS', 'POZ_SUP_SITE', 'POZ_SUP_SITE_ASSN', 'PO_DISTS_INT', 'PO_HEADERS_INT', 'PO_LINES_INT', 'PO_LINE_LOCS_INT', 'PRJ_BUDGET', 'RA_DISTS', 'RA_LINES');

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'AP_INVOICES_INT' object_code, 'INVOICE_ID' column_name, 1 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'OPERATING_UNIT' column_name, 2 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'SOURCE' column_name, 3 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INVOICE_NUM' column_name, 4 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INVOICE_AMOUNT' column_name, 5 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INVOICE_DATE' column_name, 6 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'VENDOR_NAME' column_name, 7 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'VENDOR_NUM' column_name, 8 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'VENDOR_SITE_CODE' column_name, 9 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INVOICE_CURRENCY_CODE' column_name, 10 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PAYMENT_CURRENCY_CODE' column_name, 11 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'DESCRIPTION' column_name, 12 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GROUP_ID' column_name, 13 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INVOICE_TYPE_LOOKUP_CODE' column_name, 14 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'LEGAL_ENTITY_NAME' column_name, 15 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'CUST_REGISTRATION_NUMBER' column_name, 16 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'CUST_REGISTRATION_CODE' column_name, 17 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'FIRST_PARTY_REGISTRATION_NUM' column_name, 18 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'THIRD_PARTY_REGISTRATION_NUM' column_name, 19 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'TERMS_NAME' column_name, 20 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'TERMS_DATE' column_name, 21 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GOODS_RECEIVED_DATE' column_name, 22 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INVOICE_RECEIVED_DATE' column_name, 23 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GL_DATE' column_name, 24 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PAYMENT_METHOD_CODE' column_name, 25 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PAY_GROUP_LOOKUP_CODE' column_name, 26 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'EXCLUSIVE_PAYMENT_FLAG' column_name, 27 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'AMOUNT_APPLICABLE_TO_DISCOUNT' column_name, 28 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PREPAY_NUM' column_name, 29 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PREPAY_LINE_NUM' column_name, 30 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PREPAY_APPLY_AMOUNT' column_name, 31 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PREPAY_GL_DATE' column_name, 32 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INVOICE_INCLUDES_PREPAY_FLAG' column_name, 33 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'EXCHANGE_RATE_TYPE' column_name, 34 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'EXCHANGE_DATE' column_name, 35 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'EXCHANGE_RATE' column_name, 36 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ACCTS_PAY_CODE_CONCATENATED' column_name, 37 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'DOC_CATEGORY_CODE' column_name, 38 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'VOUCHER_NUM' column_name, 39 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REQUESTER_FIRST_NAME' column_name, 40 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REQUESTER_LAST_NAME' column_name, 41 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REQUESTER_EMPLOYEE_NUM' column_name, 42 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'DELIVERY_CHANNEL_CODE' column_name, 43 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'BANK_CHARGE_BEARER' column_name, 44 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REMIT_TO_SUPPLIER_NAME' column_name, 45 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REMIT_TO_SUPPLIER_NUM' column_name, 46 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REMIT_TO_ADDRESS_NAME' column_name, 47 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PAYMENT_PRIORITY' column_name, 48 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'SETTLEMENT_PRIORITY' column_name, 49 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'UNIQUE_REMITTANCE_IDENTIFIER' column_name, 50 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'URI_CHECK_DIGIT' column_name, 51 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PAYMENT_REASON_CODE' column_name, 52 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PAYMENT_REASON_COMMENTS' column_name, 53 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REMITTANCE_MESSAGE1' column_name, 54 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REMITTANCE_MESSAGE2' column_name, 55 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REMITTANCE_MESSAGE3' column_name, 56 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'AWT_GROUP_NAME' column_name, 57 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'SHIP_TO_LOCATION' column_name, 58 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'TAXATION_COUNTRY' column_name, 59 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'DOCUMENT_SUB_TYPE' column_name, 60 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'TAX_INVOICE_INTERNAL_SEQ' column_name, 61 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'SUPPLIER_TAX_INVOICE_NUMBER' column_name, 62 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'TAX_INVOICE_RECORDING_DATE' column_name, 63 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'SUPPLIER_TAX_INVOICE_DATE' column_name, 64 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'SUPPLIER_TAX_EXCHANGE_RATE' column_name, 65 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'PORT_OF_ENTRY_CODE' column_name, 66 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'CORRECTION_YEAR' column_name, 67 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'CORRECTION_PERIOD' column_name, 68 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'IMPORT_DOCUMENT_NUMBER' column_name, 69 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'IMPORT_DOCUMENT_DATE' column_name, 70 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'CONTROL_AMOUNT' column_name, 71 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'CALC_TAX_DURING_IMPORT_FLAG' column_name, 72 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ADD_TAX_TO_INV_AMT_FLAG' column_name, 73 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_CATEGORY' column_name, 74 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE1' column_name, 75 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE2' column_name, 76 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE3' column_name, 77 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE4' column_name, 78 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE5' column_name, 79 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE6' column_name, 80 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE7' column_name, 81 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE8' column_name, 82 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE9' column_name, 83 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE10' column_name, 84 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE11' column_name, 85 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE12' column_name, 86 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE13' column_name, 87 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE14' column_name, 88 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE15' column_name, 89 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_NUMBER1' column_name, 90 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_NUMBER2' column_name, 91 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_NUMBER3' column_name, 92 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_NUMBER4' column_name, 93 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_NUMBER5' column_name, 94 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_DATE1' column_name, 95 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_DATE2' column_name, 96 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_DATE3' column_name, 97 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_DATE4' column_name, 98 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'ATTRIBUTE_DATE5' column_name, 99 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 100 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE1' column_name, 101 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE2' column_name, 102 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE3' column_name, 103 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE4' column_name, 104 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE5' column_name, 105 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE6' column_name, 106 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE7' column_name, 107 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE8' column_name, 108 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE9' column_name, 109 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE10' column_name, 110 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE11' column_name, 111 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE12' column_name, 112 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE13' column_name, 113 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE14' column_name, 114 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE15' column_name, 115 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE16' column_name, 116 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE17' column_name, 117 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE18' column_name, 118 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE19' column_name, 119 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE20' column_name, 120 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 121 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 122 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 123 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 124 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 125 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE1' column_name, 126 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE2' column_name, 127 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE3' column_name, 128 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE4' column_name, 129 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE5' column_name, 130 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'IMAGE_DOCUMENT_URI' column_name, 131 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'EXTERNAL_BANK_ACCOUNT_NUMBER' column_name, 132 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'EXT_BANK_ACCOUNT_IBAN_NUMBER' column_name, 133 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'REQUESTER_EMAIL_ADDRESS' column_name, 134 fbdi_position from dual
    union all select 'AP_INVOICES_INT' object_code, 'INTERCOMPANY_CROSSCHARGE_FLAG' column_name, 135 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'AP_INVOICE_LINES_INT' object_code, 'INVOICE_ID' column_name, 1 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'LINE_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'LINE_TYPE_LOOKUP_CODE' column_name, 3 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'AMOUNT' column_name, 4 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'QUANTITY_INVOICED' column_name, 5 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'UNIT_PRICE' column_name, 6 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'UNIT_OF_MEAS_LOOKUP_CODE' column_name, 7 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'DESCRIPTION' column_name, 8 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PO_NUMBER' column_name, 9 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PO_LINE_NUMBER' column_name, 10 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PO_SHIPMENT_NUM' column_name, 11 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PO_DISTRIBUTION_NUM' column_name, 12 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ITEM_DESCRIPTION' column_name, 13 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'RELEASE_NUM' column_name, 14 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PURCHASING_CATEGORY' column_name, 15 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'RECEIPT_NUMBER' column_name, 16 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'RECEIPT_LINE_NUMBER' column_name, 17 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'CONSUMPTION_ADVICE_NUMBER' column_name, 18 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'CONSUMPTION_ADVICE_LINE_NUMBER' column_name, 19 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PACKING_SLIP' column_name, 20 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'FINAL_MATCH_FLAG' column_name, 21 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'DIST_CODE_CONCATENATED' column_name, 22 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'DISTRIBUTION_SET_NAME' column_name, 23 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ACCOUNTING_DATE' column_name, 24 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ACCOUNT_SEGMENT' column_name, 25 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'BALANCING_SEGMENT' column_name, 26 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'COST_CENTER_SEGMENT' column_name, 27 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TAX_CLASSIFICATION_CODE' column_name, 28 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'SHIP_TO_LOCATION_CODE' column_name, 29 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'SHIP_FROM_LOCATION_CODE' column_name, 30 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'FINAL_DISCHARGE_LOCATION_CODE' column_name, 31 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TRX_BUSINESS_CATEGORY' column_name, 32 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRODUCT_FISC_CLASSIFICATION' column_name, 33 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRIMARY_INTENDED_USE' column_name, 34 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'USER_DEFINED_FISC_CLASS' column_name, 35 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRODUCT_TYPE' column_name, 36 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ASSESSABLE_VALUE' column_name, 37 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRODUCT_CATEGORY' column_name, 38 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'CONTROL_AMOUNT' column_name, 39 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TAX_REGIME_CODE' column_name, 40 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TAX' column_name, 41 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TAX_STATUS_CODE' column_name, 42 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TAX_JURISDICTION_CODE' column_name, 43 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TAX_RATE_CODE' column_name, 44 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TAX_RATE' column_name, 45 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'AWT_GROUP_NAME' column_name, 46 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'TYPE_1099' column_name, 47 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'INCOME_TAX_REGION' column_name, 48 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRORATE_ACROSS_FLAG' column_name, 49 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'LINE_GROUP_NUMBER' column_name, 50 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'COST_FACTOR_NAME' column_name, 51 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'STAT_AMOUNT' column_name, 52 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ASSETS_TRACKING_FLAG' column_name, 53 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ASSET_BOOK_TYPE_CODE' column_name, 54 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ASSET_CATEGORY_ID' column_name, 55 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'SERIAL_NUMBER' column_name, 56 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'MANUFACTURER' column_name, 57 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'MODEL_NUMBER' column_name, 58 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'WARRANTY_NUMBER' column_name, 59 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRICE_CORRECTION_FLAG' column_name, 60 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRICE_CORRECT_INV_NUM' column_name, 61 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PRICE_CORRECT_INV_LINE_NUM' column_name, 62 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'REQUESTER_FIRST_NAME' column_name, 63 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'REQUESTER_LAST_NAME' column_name, 64 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'REQUESTER_EMPLOYEE_NUM' column_name, 65 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_CATEGORY' column_name, 66 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE1' column_name, 67 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE2' column_name, 68 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE3' column_name, 69 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE4' column_name, 70 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE5' column_name, 71 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE6' column_name, 72 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE7' column_name, 73 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE8' column_name, 74 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE9' column_name, 75 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE10' column_name, 76 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE11' column_name, 77 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE12' column_name, 78 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE13' column_name, 79 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE14' column_name, 80 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE15' column_name, 81 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_NUMBER1' column_name, 82 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_NUMBER2' column_name, 83 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_NUMBER3' column_name, 84 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_NUMBER4' column_name, 85 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_NUMBER5' column_name, 86 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_DATE1' column_name, 87 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_DATE2' column_name, 88 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_DATE3' column_name, 89 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_DATE4' column_name, 90 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'ATTRIBUTE_DATE5' column_name, 91 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 92 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE1' column_name, 93 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE2' column_name, 94 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE3' column_name, 95 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE4' column_name, 96 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE5' column_name, 97 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE6' column_name, 98 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE7' column_name, 99 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE8' column_name, 100 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE9' column_name, 101 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE10' column_name, 102 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE11' column_name, 103 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE12' column_name, 104 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE13' column_name, 105 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE14' column_name, 106 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE15' column_name, 107 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE16' column_name, 108 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE17' column_name, 109 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE18' column_name, 110 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE19' column_name, 111 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE20' column_name, 112 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 113 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 114 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 115 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 116 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 117 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE1' column_name, 118 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE2' column_name, 119 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE3' column_name, 120 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE4' column_name, 121 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'GLOBAL_ATTRIBUTE_DATE5' column_name, 122 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_PROJECT_ID' column_name, 123 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_TASK_ID' column_name, 124 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_EXPENDITURE_TYPE_ID' column_name, 125 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_EXPENDITURE_ITEM_DATE' column_name, 126 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_ORGANIZATION_ID' column_name, 127 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_PROJECT_NUMBER' column_name, 128 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_TASK_NUMBER' column_name, 129 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_EXPENDITURE_TYPE_NAME' column_name, 130 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_ORGANIZATION_NAME' column_name, 131 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE1' column_name, 132 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE2' column_name, 133 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE3' column_name, 134 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE4' column_name, 135 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE5' column_name, 136 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE6' column_name, 137 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE7' column_name, 138 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE8' column_name, 139 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE9' column_name, 140 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_RESERVED_ATTRIBUTE10' column_name, 141 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE1' column_name, 142 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE2' column_name, 143 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE3' column_name, 144 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE4' column_name, 145 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE5' column_name, 146 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE6' column_name, 147 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE7' column_name, 148 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE8' column_name, 149 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE9' column_name, 150 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE10' column_name, 151 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'FISCAL_CHARGE_TYPE' column_name, 152 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'DEF_ACCTG_START_DATE' column_name, 153 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'DEF_ACCTG_END_DATE' column_name, 154 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'DEF_ACCRUAL_CODE_CONCATENATED' column_name, 155 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_PROJECT_NAME' column_name, 156 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_TASK_NAME' column_name, 157 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_WORK_TYPE' column_name, 158 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_CONTRACT_NAME' column_name, 159 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_CONTRACT_NUMBER' column_name, 160 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_FUNDING_SOURCE_NAME' column_name, 161 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'PJC_FUNDING_SOURCE_NUMBER' column_name, 162 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'REQUESTER_EMAIL_ADDRESS' column_name, 163 fbdi_position from dual
    union all select 'AP_INVOICE_LINES_INT' object_code, 'RCV_TRANSACTION_ID' column_name, 164 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'EGP_ITEM' object_code, 'TRANSACTION_TYPE' column_name, 1 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'BATCH_ID' column_name, 2 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'BATCH_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ITEM_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ORGANIZATION_CODE' column_name, 6 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'DESCRIPTION' column_name, 7 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'TEMPLATE_NAME' column_name, 8 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SOURCE_SYSTEM_CODE' column_name, 9 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SOURCE_SYSTEM_REFERENCE' column_name, 10 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PRIMARY_UOM_CODE' column_name, 13 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CURRENT_PHASE_CODE' column_name, 14 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVENTORY_ITEM_STATUS_CODE' column_name, 15 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ITEM_CLASS_NAME' column_name, 16 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'COSTING_ENABLED_FLAG' column_name, 27 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVENTORY_ASSET_FLAG' column_name, 29 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'FIXED_DAYS_SUPPLY' column_name, 38 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'FIXED_LOT_MULTIPLIER' column_name, 39 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'FIXED_ORDER_QUANTITY' column_name, 40 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVENTORY_PLANNING_CODE' column_name, 42 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MIN_MINMAX_QUANTITY' column_name, 46 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MAX_MINMAX_QUANTITY' column_name, 47 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MINIMUM_ORDER_QUANTITY' column_name, 48 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MAXIMUM_ORDER_QUANTITY' column_name, 49 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PLANNER_CODE' column_name, 50 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PLANNING_MAKE_BUY_CODE' column_name, 51 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'RESTRICT_SUBINVENTORIES_CODE' column_name, 60 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'RESTRICT_LOCATORS_CODE' column_name, 61 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CHILD_LOT_FLAG' column_name, 62 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'STOCK_ENABLED_FLAG' column_name, 69 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SHELF_LIFE_CODE' column_name, 71 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SHELF_LIFE_DAYS' column_name, 72 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SERIAL_NUMBER_CONTROL_CODE' column_name, 73 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'REVISION_QTY_CONTROL_CODE' column_name, 75 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CHECK_SHORTAGES_FLAG' column_name, 80 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CYCLE_COUNT_ENABLED_FLAG' column_name, 81 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GRADE_CONTROL_FLAG' column_name, 83 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'LOT_DIVISIBLE_FLAG' column_name, 85 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVENTORY_ITEM_FLAG' column_name, 91 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'LOCATION_CONTROL_CODE' column_name, 92 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'LOT_CONTROL_CODE' column_name, 93 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MTL_TRANSACTIONS_ENABLED_FLAG' column_name, 97 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'RESERVABLE_TYPE' column_name, 101 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVOICING_RULE_NAME' column_name, 103 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'TAX_CODE' column_name, 104 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SALES_ACCOUNT' column_name, 105 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PAYMENT_TERMS_NAME' column_name, 106 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVOICE_ENABLED_FLAG' column_name, 107 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVOICEABLE_ITEM_FLAG' column_name, 108 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ACCOUNTING_RULE_NAME' column_name, 109 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CUM_MANUFACTURING_LEAD_TIME' column_name, 119 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PREPROCESSING_LEAD_TIME' column_name, 120 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CUMULATIVE_TOTAL_LEAD_TIME' column_name, 121 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'FIXED_LEAD_TIME' column_name, 122 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'VARIABLE_LEAD_TIME' column_name, 123 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'FULL_LEAD_TIME' column_name, 124 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'LEAD_TIME_LOT_SIZE' column_name, 125 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'POSTPROCESSING_LEAD_TIME' column_name, 126 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MRP_PLANNING_CODE' column_name, 141 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SHRINKAGE_RATE' column_name, 152 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'DUAL_UOM_DEVIATION_HIGH' column_name, 157 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'DUAL_UOM_DEVIATION_LOW' column_name, 158 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ITEM_TYPE' column_name, 159 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'LONG_DESCRIPTION' column_name, 160 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SECONDARY_UOM_CODE' column_name, 164 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATP_FLAG' column_name, 168 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'OVER_SHIPMENT_TOLERANCE' column_name, 169 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UNDER_SHIPMENT_TOLERANCE' column_name, 170 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'OVER_RETURN_TOLERANCE' column_name, 171 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UNDER_RETURN_TOLERANCE' column_name, 172 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INDIVISIBLE_FLAG' column_name, 175 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INTERNAL_ORDER_ENABLED_FLAG' column_name, 176 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CUSTOMER_ORDER_ENABLED_FLAG' column_name, 179 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'DEFAULT_SHIPPING_ORG' column_name, 180 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INTERNAL_ORDER_FLAG' column_name, 184 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PICKING_RULE_NAME' column_name, 185 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'RETURNABLE_FLAG' column_name, 186 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SHIPPABLE_ITEM_FLAG' column_name, 190 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CUSTOMER_ORDER_FLAG' column_name, 193 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UNIT_WEIGHT' column_name, 194 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'WEIGHT_UOM_CODE' column_name, 195 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UNIT_VOLUME' column_name, 196 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'VOLUME_UOM_CODE' column_name, 197 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'DIMENSION_UOM_CODE' column_name, 198 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UNIT_LENGTH' column_name, 199 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UNIT_WIDTH' column_name, 200 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UNIT_HEIGHT' column_name, 201 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'EXPENSE_ACCOUNT' column_name, 221 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'UN_NUMBER_CODE' column_name, 222 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'RECEIVE_CLOSE_TOLERANCE' column_name, 225 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PURCHASING_TAX_CODE' column_name, 226 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PURCHASING_ITEM_FLAG' column_name, 227 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PRICE_TOLERANCE_PERCENT' column_name, 228 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MUST_USE_APPROVED_VENDOR_FLAG' column_name, 232 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MATCH_APPROVAL_LEVEL' column_name, 233 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVOICE_MATCH_OPTION' column_name, 234 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'LIST_PRICE_PER_UNIT' column_name, 235 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'INVOICE_CLOSE_TOLERANCE' column_name, 236 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'HAZARD_CLASS_CODE' column_name, 237 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'BUYER_NAME' column_name, 238 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'PURCHASING_ENABLED_FLAG' column_name, 240 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'OUTSIDE_OPERATION_FLAG' column_name, 241 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'MARKET_PRICE' column_name, 242 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ASSET_CATEGORY_ID' column_name, 243 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ALLOW_ITEM_DESC_UPDATE_FLAG' column_name, 244 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' column_name, 246 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ALLOW_UNORDERED_RECEIPTS_FLAG' column_name, 247 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'DAYS_EARLY_RECEIPT_ALLOWED' column_name, 248 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'DAYS_LATE_RECEIPT_ALLOWED' column_name, 249 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'RECEIVING_ROUTING_ID' column_name, 250 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ENFORCE_SHIP_TO_LOCATION_CODE' column_name, 251 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'QTY_RCV_EXCEPTION_CODE' column_name, 252 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'QTY_RCV_TOLERANCE' column_name, 253 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'RECEIPT_DAYS_EXCEPTION_CODE' column_name, 254 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'CONTRACT_ITEM_TYPE_CODE' column_name, 259 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SERVICEABLE_PRODUCT_FLAG' column_name, 265 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SERVICE_DURATION' column_name, 267 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'SERVICE_DURATION_PERIOD_CODE' column_name, 268 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'BACK_ORDERABLE_FLAG' column_name, 279 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'BUILD_IN_WIP_FLAG' column_name, 282 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'WIP_SUPPLY_TYPE' column_name, 285 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'WIP_SUPPLY_SUBINVENTORY' column_name, 286 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'STYLE_ITEM_FLAG' column_name, 292 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 299 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE1' column_name, 300 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE2' column_name, 301 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE3' column_name, 302 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE4' column_name, 303 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE5' column_name, 304 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE6' column_name, 305 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE7' column_name, 306 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE8' column_name, 307 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE9' column_name, 308 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE10' column_name, 309 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_CATEGORY' column_name, 310 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE1' column_name, 311 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE2' column_name, 312 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE3' column_name, 313 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE4' column_name, 314 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE5' column_name, 315 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE6' column_name, 316 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE7' column_name, 317 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE8' column_name, 318 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE9' column_name, 319 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE10' column_name, 320 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE11' column_name, 321 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE12' column_name, 322 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE13' column_name, 323 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE14' column_name, 324 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE15' column_name, 325 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_NUMBER1' column_name, 341 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_NUMBER2' column_name, 342 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_NUMBER3' column_name, 343 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_NUMBER4' column_name, 344 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_NUMBER5' column_name, 345 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_DATE1' column_name, 351 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_DATE2' column_name, 352 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_DATE3' column_name, 353 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_DATE4' column_name, 354 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'ATTRIBUTE_DATE5' column_name, 355 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE11' column_name, 361 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE12' column_name, 362 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE13' column_name, 363 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE14' column_name, 364 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE15' column_name, 365 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE16' column_name, 366 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE17' column_name, 367 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE18' column_name, 368 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE19' column_name, 369 fbdi_position from dual
    union all select 'EGP_ITEM' object_code, 'GLOBAL_ATTRIBUTE20' column_name, 370 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'EGP_ITEM_CAT' object_code, 'TRANSACTION_TYPE' column_name, 1 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'BATCH_ID' column_name, 2 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'BATCH_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'ITEM_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'ORGANIZATION_CODE' column_name, 5 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'CATEGORY_SET_NAME' column_name, 6 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'CATEGORY_NAME' column_name, 7 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'CATEGORY_CODE' column_name, 8 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'OLD_CATEGORY_NAME' column_name, 9 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'OLD_CATEGORY_CODE' column_name, 10 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'SOURCE_SYSTEM_CODE' column_name, 11 fbdi_position from dual
    union all select 'EGP_ITEM_CAT' object_code, 'SOURCE_SYSTEM_REFERENCE' column_name, 12 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'FA_ASSET_ASSIGN' object_code, 'UNITS_ASSIGNED' column_name, 2 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'LOCATION_SEGMENT1' column_name, 4 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'LOCATION_SEGMENT2' column_name, 5 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'LOCATION_SEGMENT3' column_name, 6 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'LOCATION_SEGMENT4' column_name, 7 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'LOCATION_SEGMENT5' column_name, 8 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'LOCATION_SEGMENT6' column_name, 9 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'LOCATION_SEGMENT7' column_name, 10 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT1' column_name, 11 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT2' column_name, 12 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT3' column_name, 13 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT4' column_name, 14 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT5' column_name, 15 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT6' column_name, 16 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT7' column_name, 17 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT8' column_name, 18 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT9' column_name, 19 fbdi_position from dual
    union all select 'FA_ASSET_ASSIGN' object_code, 'EXPENSE_ACCOUNT_SEGMENT10' column_name, 20 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'FA_ASSET_BOOK' object_code, 'BOOK_TYPE_CODE' column_name, 2 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'DESCRIPTION' column_name, 5 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'TAG_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'MANUFACTURER_NAME' column_name, 7 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'SERIAL_NUMBER' column_name, 8 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'MODEL_NUMBER' column_name, 9 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_TYPE' column_name, 10 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'COST' column_name, 11 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'DATE_PLACED_IN_SERVICE' column_name, 12 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'PRORATE_CONVENTION_CODE' column_name, 13 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'CURRENT_UNITS' column_name, 14 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_CATEGORY_SEGMENT1' column_name, 15 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_CATEGORY_SEGMENT2' column_name, 16 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_CATEGORY_SEGMENT3' column_name, 17 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_CATEGORY_SEGMENT4' column_name, 18 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_CATEGORY_SEGMENT5' column_name, 19 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_CATEGORY_SEGMENT6' column_name, 20 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ASSET_CATEGORY_SEGMENT7' column_name, 21 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'PARENT_ASSET_NUMBER' column_name, 25 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'PROPERTY_TYPE_CODE' column_name, 38 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'PROPERTY_1245_1250_CODE' column_name, 39 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'IN_USE_FLAG' column_name, 40 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'OWNED_LEASED' column_name, 41 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'NEW_USED' column_name, 42 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'SALVAGE_VALUE' column_name, 50 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'YTD_DEPRN' column_name, 52 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'DEPRN_RESERVE' column_name, 53 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'BONUS_YTD_DEPRN' column_name, 54 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'BONUS_DEPRN_RESERVE' column_name, 55 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'DEPRECIATION_METHOD' column_name, 58 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'LIFE_IN_MONTHS' column_name, 59 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE1' column_name, 101 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE2' column_name, 102 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE3' column_name, 103 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE4' column_name, 104 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE5' column_name, 105 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE6' column_name, 106 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE7' column_name, 107 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE8' column_name, 108 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE9' column_name, 109 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE10' column_name, 110 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE11' column_name, 111 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE12' column_name, 112 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE13' column_name, 113 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE14' column_name, 114 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE15' column_name, 115 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'ATTRIBUTE_CATEGORY' column_name, 141 fbdi_position from dual
    union all select 'FA_ASSET_BOOK' object_code, 'DEPRN_START_DATE' column_name, 245 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'FA_ASSET_HDR' object_code, 'BOOK_TYPE_CODE' column_name, 2 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'DESCRIPTION' column_name, 5 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'TAG_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'MANUFACTURER_NAME' column_name, 7 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'SERIAL_NUMBER' column_name, 8 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'MODEL_NUMBER' column_name, 9 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_TYPE' column_name, 10 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'COST' column_name, 11 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'DATE_PLACED_IN_SERVICE' column_name, 12 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'PRORATE_CONVENTION_CODE' column_name, 13 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'CURRENT_UNITS' column_name, 14 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_CATEGORY_SEGMENT1' column_name, 15 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_CATEGORY_SEGMENT2' column_name, 16 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_CATEGORY_SEGMENT3' column_name, 17 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_CATEGORY_SEGMENT4' column_name, 18 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_CATEGORY_SEGMENT5' column_name, 19 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_CATEGORY_SEGMENT6' column_name, 20 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ASSET_CATEGORY_SEGMENT7' column_name, 21 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'PARENT_ASSET_NUMBER' column_name, 25 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'PROPERTY_TYPE_CODE' column_name, 38 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'PROPERTY_1245_1250_CODE' column_name, 39 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'IN_USE_FLAG' column_name, 40 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'OWNED_LEASED' column_name, 41 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'NEW_USED' column_name, 42 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'SALVAGE_VALUE' column_name, 50 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'YTD_DEPRN' column_name, 52 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'DEPRN_RESERVE' column_name, 53 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'BONUS_YTD_DEPRN' column_name, 54 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'BONUS_DEPRN_RESERVE' column_name, 55 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'DEPRECIATION_METHOD' column_name, 58 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'LIFE_IN_MONTHS' column_name, 59 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE1' column_name, 101 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE2' column_name, 102 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE3' column_name, 103 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE4' column_name, 104 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE5' column_name, 105 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE6' column_name, 106 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE7' column_name, 107 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE8' column_name, 108 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE9' column_name, 109 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE10' column_name, 110 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE11' column_name, 111 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE12' column_name, 112 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE13' column_name, 113 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE14' column_name, 114 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE15' column_name, 115 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'ATTRIBUTE_CATEGORY' column_name, 141 fbdi_position from dual
    union all select 'FA_ASSET_HDR' object_code, 'DEPRN_START_DATE' column_name, 245 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GL_BUDGET_INT' object_code, 'RUN_NAME' column_name, 1 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'STATUS_FBDI' column_name, 2 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'LEDGER_ID' column_name, 3 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'BUDGET_NAME' column_name, 4 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'PERIOD_NAME' column_name, 5 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'CURRENCY_CODE' column_name, 6 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT1' column_name, 7 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT2' column_name, 8 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT3' column_name, 9 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT4' column_name, 10 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT5' column_name, 11 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT6' column_name, 12 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT7' column_name, 13 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT8' column_name, 14 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT9' column_name, 15 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT10' column_name, 16 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT11' column_name, 17 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT12' column_name, 18 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT13' column_name, 19 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT14' column_name, 20 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT15' column_name, 21 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT16' column_name, 22 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT17' column_name, 23 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT18' column_name, 24 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT19' column_name, 25 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT20' column_name, 26 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT21' column_name, 27 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT22' column_name, 28 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT23' column_name, 29 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT24' column_name, 30 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT25' column_name, 31 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT26' column_name, 32 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT27' column_name, 33 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT28' column_name, 34 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT29' column_name, 35 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'SEGMENT30' column_name, 36 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'BUDGET_AMOUNT' column_name, 37 fbdi_position from dual
    union all select 'GL_BUDGET_INT' object_code, 'LEDGER_NAME' column_name, 38 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GL_INTERFACE' object_code, 'JOURNAL_STATUS' column_name, 1 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ACCOUNTING_DATE' column_name, 3 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'USER_JE_SOURCE_NAME' column_name, 4 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'USER_JE_CATEGORY_NAME' column_name, 5 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'CURRENCY_CODE' column_name, 6 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'DATE_CREATED' column_name, 7 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ACTUAL_FLAG' column_name, 8 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT1' column_name, 9 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT2' column_name, 10 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT3' column_name, 11 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT4' column_name, 12 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT5' column_name, 13 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT6' column_name, 14 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT7' column_name, 15 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT8' column_name, 16 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT9' column_name, 17 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT10' column_name, 18 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT11' column_name, 19 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT12' column_name, 20 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT13' column_name, 21 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT14' column_name, 22 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT15' column_name, 23 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT16' column_name, 24 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT17' column_name, 25 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT18' column_name, 26 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT19' column_name, 27 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT20' column_name, 28 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT21' column_name, 29 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT22' column_name, 30 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT23' column_name, 31 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT24' column_name, 32 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT25' column_name, 33 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT26' column_name, 34 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT27' column_name, 35 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT28' column_name, 36 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT29' column_name, 37 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'SEGMENT30' column_name, 38 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ENTERED_DR' column_name, 39 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ENTERED_CR' column_name, 40 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ACCOUNTED_DR' column_name, 41 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ACCOUNTED_CR' column_name, 42 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE1' column_name, 43 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE2' column_name, 44 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE4' column_name, 46 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE5' column_name, 47 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE6' column_name, 48 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE7' column_name, 49 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE8' column_name, 50 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'REFERENCE10' column_name, 52 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'RECON_KEY' column_name, 53 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'STAT_AMOUNT' column_name, 63 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'USER_CURRENCY_CONVERSION_TYPE' column_name, 64 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'CURRENCY_CONVERSION_DATE' column_name, 65 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'CURRENCY_CONVERSION_RATE' column_name, 66 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'GROUP_ID' column_name, 67 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE_CATEGORY' column_name, 68 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE1' column_name, 69 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE2' column_name, 70 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE3' column_name, 71 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE4' column_name, 72 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE5' column_name, 73 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE6' column_name, 74 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE7' column_name, 75 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE8' column_name, 76 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE9' column_name, 77 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE10' column_name, 78 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE11' column_name, 79 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE12' column_name, 80 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE13' column_name, 81 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE14' column_name, 82 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE15' column_name, 83 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE16' column_name, 84 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE17' column_name, 85 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE18' column_name, 86 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE19' column_name, 87 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'ATTRIBUTE20' column_name, 88 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'LEDGER_NAME' column_name, 92 fbdi_position from dual
    union all select 'GL_INTERFACE' object_code, 'PERIOD_NAME' column_name, 95 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_BDGT_PRDS' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_BDGT_PRDS' object_code, 'BUDGET_PERIOD' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_BDGT_PRDS' object_code, 'START_DATE' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_BDGT_PRDS' object_code, 'END_DATE' column_name, 4 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_CERTS' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'CERTIFICATION_NAME' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'CERTIFICATION_DATE' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'CERTIFIED_BY' column_name, 5 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'CERT_STATUS' column_name, 6 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'APPROVAL_DATE' column_name, 7 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'EXPIRATION_DATE' column_name, 8 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'EXPEDITED_REVIEW' column_name, 9 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'FULL_REVIEW' column_name, 10 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'ASSURANCE_NUMBER' column_name, 11 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'EXEMPTION_NUMBER' column_name, 12 fbdi_position from dual
    union all select 'GMS_AWD_CERTS' object_code, 'COMMENTS' column_name, 13 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_CFDAS' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_CFDAS' object_code, 'CFDA' column_name, 2 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_FUNDING' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'BUDGET_PERIOD_NAME' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'FUNDING_SOURCE_NAME' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'ISSUE_TYPE' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'ISSUE_NUMBER' column_name, 5 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'ISSUE_DATE' column_name, 6 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'ISSUE_DESCRIPTION' column_name, 7 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'DIRECT_FUNDING_AMOUNT' column_name, 8 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'INDIRECT_FUNDING_AMOUNT' column_name, 9 fbdi_position from dual
    union all select 'GMS_AWD_FUNDING' object_code, 'FUNDING_SOURCE_NUMBER' column_name, 10 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_FUND_ALLOC' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_FUND_ALLOC' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_FUND_ALLOC' object_code, 'ISSUE_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_FUND_ALLOC' object_code, 'FUNDING_AMOUNT' column_name, 4 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_FUND_SRC' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'FUNDING_SOURCE_NAME' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'FUNDING_SOURCE_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'COST_SHARE_REQ_BY_SPONSOR' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'COST_SHARE_APPROVED_BY_EMAIL' column_name, 5 fbdi_position from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'COST_SHARE_APPROVED_BY_NAME' column_name, 6 fbdi_position from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'COST_SHARE_APPROVED_BY_NUMBER' column_name, 7 fbdi_position from dual
    union all select 'GMS_AWD_FUND_SRC' object_code, 'COST_SHARE_APPROVAL_DATE' column_name, 8 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_HEADERS' object_code, 'AWARD_NAME' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'AWARD_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'SOURCE_TEMPLATE_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BUSINESS_UNIT' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'LEGAL_ENTITY' column_name, 5 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'CONTRACT_TYPE' column_name, 6 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PRIMARY_SPONSOR' column_name, 7 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PRINCIPAL_INVESTIGATOR_EMAIL' column_name, 8 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PI_NAME' column_name, 9 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PI_NUMBER' column_name, 10 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'AWARD_START_DATE' column_name, 11 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'AWARD_END_DATE' column_name, 12 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'AWARD_DESCRIPTION' column_name, 13 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ORGANIZATION' column_name, 14 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'INSTITUTION' column_name, 15 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'SPONSOR_AWARD_NUMBER' column_name, 16 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'AWARD_PURPOSE' column_name, 17 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'AWARD_TYPE' column_name, 18 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'EXPANDED_AUTHORITY_FLAG' column_name, 19 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'COST_SHARE' column_name, 20 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'DEFAULT_BURDEN_SCHEDULE' column_name, 21 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FIXED_DATE' column_name, 22 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PRE_AWARD_DATE' column_name, 23 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PRE_AWARD_SPENDING_ALLOWED' column_name, 24 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PRE_AWARD_GSF' column_name, 25 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'CLOSE_DATE' column_name, 26 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'COI_INST_POLICY_COMPLIANT' column_name, 27 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'COI_REVIEW_COMPLETED' column_name, 28 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'COI_APPROVAL_DATE' column_name, 29 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FT_PRIMARY_SPONSOR' column_name, 30 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FT_REF_AWARD_NAME' column_name, 31 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FT_FROM_DATE' column_name, 32 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FT_TO_DATE' column_name, 33 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FT_AMOUNT' column_name, 34 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FT_IS_FEDERAL' column_name, 35 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'IS_INTELL_PROP_REPORTED' column_name, 36 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'INTELL_PROP_DESC' column_name, 37 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PREV_AWARD_BU' column_name, 38 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PREV_AWARD_NAME' column_name, 39 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PREV_AWARD_RENEWAL_INPRG' column_name, 40 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PREV_AWARD_ABR' column_name, 41 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'COST_SHARE_REQ_BY_SPONSOR' column_name, 42 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'COST_SHARE_APPROVED_BY' column_name, 43 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'COST_SHARE_APPROVAL_DATE' column_name, 44 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 45 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE1' column_name, 46 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE2' column_name, 47 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE3' column_name, 48 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE4' column_name, 49 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE5' column_name, 50 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE6' column_name, 51 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE7' column_name, 52 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE8' column_name, 53 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE9' column_name, 54 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE10' column_name, 55 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE11' column_name, 56 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE12' column_name, 57 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE13' column_name, 58 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE14' column_name, 59 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE15' column_name, 60 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE16' column_name, 61 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE17' column_name, 62 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE18' column_name, 63 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE19' column_name, 64 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE20' column_name, 65 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER1' column_name, 66 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER2' column_name, 67 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER3' column_name, 68 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER4' column_name, 69 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER5' column_name, 70 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER6' column_name, 71 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER7' column_name, 72 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER8' column_name, 73 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER9' column_name, 74 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_NUMBER10' column_name, 75 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE1' column_name, 76 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE2' column_name, 77 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE3' column_name, 78 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE4' column_name, 79 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE5' column_name, 80 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE6' column_name, 81 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE7' column_name, 82 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE8' column_name, 83 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE9' column_name, 84 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_DATE10' column_name, 85 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 86 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 87 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 88 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 89 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 90 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 91 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 92 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 93 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 94 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 95 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'CONTRACT_STATUS' column_name, 96 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'CONTRACT_LINE_NAME' column_name, 97 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'LOC_FLAG' column_name, 98 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'DOC_NUMBER' column_name, 99 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FED_INVOICE_FORMAT' column_name, 100 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BILL_PLAN_NAME' column_name, 101 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'REVENUE_PLAN_NAME' column_name, 102 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'INVOICE_METHOD' column_name, 103 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'REVENUE_METHOD' column_name, 104 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BILLING_CYCLE' column_name, 105 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PAYMENT_TERM' column_name, 106 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'LABOR_FORMAT' column_name, 107 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'NON_LABOR_FORMAT' column_name, 108 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'EVENT_FORMAT' column_name, 109 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'CURRENCY_CODE' column_name, 110 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PRIMARY_SPONSOR_NUMBER' column_name, 111 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'FT_PRIMARY_SPONSOR_NUMBER' column_name, 112 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'NET_INVOICE_FLAG' column_name, 113 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'INV_HDR_GROUPING_OPTIONS' column_name, 114 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BILL_TO_SITE_LOCATION' column_name, 115 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BILL_TO_CONTACT_NAME' column_name, 116 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BILL_TO_CONTACT_EMAIL' column_name, 117 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'SHIP_TO_SITE_LOCATION' column_name, 118 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BILL_SET_NUMBER' column_name, 119 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'GENERATED_INVOICE_STATUS' column_name, 120 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'INV_TRX_TYPE_NAME' column_name, 121 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'BILL_TO_ACCT_NUMBER' column_name, 122 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'SHIP_TO_ACCT_NUMBER' column_name, 123 fbdi_position from dual
    union all select 'GMS_AWD_HEADERS' object_code, 'PREPAY_TRX_TYPE_NAME' column_name, 124 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_KEYWORDS' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_KEYWORDS' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_KEYWORDS' object_code, 'KEYWORD_NAME' column_name, 3 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_ORG_CREDITS' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_ORG_CREDITS' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_ORG_CREDITS' object_code, 'ORGANIZATION' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_ORG_CREDITS' object_code, 'CREDIT_PERCENTAGE' column_name, 4 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_PERSONNEL' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'INTERNAL' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'PERSON_EMAIL' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'PERSON_NAME' column_name, 5 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'PERSON_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ROLE' column_name, 7 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'START_DATE' column_name, 8 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'END_DATE' column_name, 9 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'CREDIT_PERCENTAGE' column_name, 10 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_CATEGORY' column_name, 11 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE1' column_name, 12 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE2' column_name, 13 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE3' column_name, 14 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE4' column_name, 15 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE5' column_name, 16 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE6' column_name, 17 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE7' column_name, 18 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE8' column_name, 19 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE9' column_name, 20 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE10' column_name, 21 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE11' column_name, 22 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE12' column_name, 23 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE13' column_name, 24 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE14' column_name, 25 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE15' column_name, 26 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE16' column_name, 27 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE17' column_name, 28 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE18' column_name, 29 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE19' column_name, 30 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE20' column_name, 31 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER1' column_name, 32 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER2' column_name, 33 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER3' column_name, 34 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER4' column_name, 35 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER5' column_name, 36 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER6' column_name, 37 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER7' column_name, 38 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER8' column_name, 39 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER9' column_name, 40 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_NUMBER10' column_name, 41 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE1' column_name, 42 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE2' column_name, 43 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE3' column_name, 44 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE4' column_name, 45 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE5' column_name, 46 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE6' column_name, 47 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE7' column_name, 48 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE8' column_name, 49 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE9' column_name, 50 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_DATE10' column_name, 51 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 52 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 53 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 54 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 55 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 56 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 57 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 58 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 59 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 60 fbdi_position from dual
    union all select 'GMS_AWD_PERSONNEL' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 61 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_PRJ_FUND_SRC' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_FUND_SRC' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_FUND_SRC' object_code, 'FUNDING_SOURCE_NAME' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_FUND_SRC' object_code, 'FUNDING_SOURCE_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_FUND_SRC' object_code, 'ENABLE_BURDENING_FLAG' column_name, 5 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_PRJ_TSK_BRD' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_TSK_BRD' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_TSK_BRD' object_code, 'TASK_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_TSK_BRD' object_code, 'BURDEN_SCHEDULE' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_PRJ_TSK_BRD' object_code, 'FIXED_DATE' column_name, 5 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_PROJECTS' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'FUNDING_SOURCE_NAME' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'PROJECT_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'AWARD_PRJ_BRD_SCHEDULE' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'FIXED_DATE' column_name, 5 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 6 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE1' column_name, 7 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE2' column_name, 8 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE3' column_name, 9 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE4' column_name, 10 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE5' column_name, 11 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE6' column_name, 12 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE7' column_name, 13 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE8' column_name, 14 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE9' column_name, 15 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE10' column_name, 16 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE11' column_name, 17 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE12' column_name, 18 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE13' column_name, 19 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE14' column_name, 20 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE15' column_name, 21 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE16' column_name, 22 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE17' column_name, 23 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE18' column_name, 24 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE19' column_name, 25 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE20' column_name, 26 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER1' column_name, 27 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER2' column_name, 28 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER3' column_name, 29 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER4' column_name, 30 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER5' column_name, 31 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER6' column_name, 32 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER7' column_name, 33 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER8' column_name, 34 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER9' column_name, 35 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_NUMBER10' column_name, 36 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE1' column_name, 37 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE2' column_name, 38 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE3' column_name, 39 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE4' column_name, 40 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE5' column_name, 41 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE6' column_name, 42 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE7' column_name, 43 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE8' column_name, 44 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE9' column_name, 45 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_DATE10' column_name, 46 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 47 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 48 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 49 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 50 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 51 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 52 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 53 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 54 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 55 fbdi_position from dual
    union all select 'GMS_AWD_PROJECTS' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 56 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_REFERENCES' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_REFERENCES' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_REFERENCES' object_code, 'REFERENCE_TYPE' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_REFERENCES' object_code, 'VALUE' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_REFERENCES' object_code, 'COMMENTS' column_name, 5 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'GMS_AWD_TERMS' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'GMS_AWD_TERMS' object_code, 'TERM_CATEGORY_NAME' column_name, 2 fbdi_position from dual
    union all select 'GMS_AWD_TERMS' object_code, 'TERM_NAME' column_name, 3 fbdi_position from dual
    union all select 'GMS_AWD_TERMS' object_code, 'TERM_DESCRIPTION' column_name, 4 fbdi_position from dual
    union all select 'GMS_AWD_TERMS' object_code, 'TERM_OPERAND' column_name, 5 fbdi_position from dual
    union all select 'GMS_AWD_TERMS' object_code, 'TERM_VALUE' column_name, 6 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'HZ_ACCOUNTS' object_code, 'BATCH_ID' column_name, 1 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'CUST_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'CUST_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'PARTY_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 5 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ACCOUNT_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'INSERT_UPDATE_FLAG' column_name, 7 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'CUSTOMER_TYPE' column_name, 8 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'CUSTOMER_CLASS_CODE' column_name, 9 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ACCOUNT_NAME' column_name, 10 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ACCOUNT_ESTABLISHED_DATE' column_name, 11 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 12 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE1' column_name, 13 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE2' column_name, 14 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE3' column_name, 15 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE4' column_name, 16 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE5' column_name, 17 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE6' column_name, 18 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE7' column_name, 19 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE8' column_name, 20 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE9' column_name, 21 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE10' column_name, 22 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE11' column_name, 23 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE12' column_name, 24 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE13' column_name, 25 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE14' column_name, 26 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE15' column_name, 27 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE16' column_name, 28 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE17' column_name, 29 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE18' column_name, 30 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE19' column_name, 31 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ATTRIBUTE20' column_name, 32 fbdi_position from dual
    union all select 'HZ_ACCOUNTS' object_code, 'ACCOUNT_TERMINATION_DATE' column_name, 33 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'HZ_ACCT_SITES' object_code, 'BATCH_ID' column_name, 1 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'CUST_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'CUST_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'CUST_SITE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'CUST_SITE_ORIG_SYS_REF' column_name, 5 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'SITE_ORIG_SYSTEM' column_name, 6 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'SITE_ORIG_SYSTEM_REFERENCE' column_name, 7 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ACCT_SITE_LANGUAGE' column_name, 8 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'INSERT_UPDATE_FLAG' column_name, 9 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'CUSTOMER_CATEGORY_CODE' column_name, 10 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'TRANSLATED_CUSTOMER_NAME' column_name, 11 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'SET_CODE' column_name, 12 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'START_DATE' column_name, 13 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'END_DATE' column_name, 14 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'KEY_ACCOUNT_FLAG' column_name, 15 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ACCOUNT_NUMBER' column_name, 16 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'PARTY_SITE_NUMBER' column_name, 17 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 18 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE1' column_name, 19 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE2' column_name, 20 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE3' column_name, 21 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE4' column_name, 22 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE5' column_name, 23 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE6' column_name, 24 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE7' column_name, 25 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE8' column_name, 26 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE9' column_name, 27 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE10' column_name, 28 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE11' column_name, 29 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE12' column_name, 30 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE13' column_name, 31 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE14' column_name, 32 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE15' column_name, 33 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE16' column_name, 34 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE17' column_name, 35 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE18' column_name, 36 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE19' column_name, 37 fbdi_position from dual
    union all select 'HZ_ACCT_SITES' object_code, 'ATTRIBUTE20' column_name, 38 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'HZ_ACCT_SITE_USES' object_code, 'BATCH_ID' column_name, 1 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'CUST_SITE_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'CUST_SITE_ORIG_SYS_REF' column_name, 3 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'CUST_SITEUSE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'CUST_SITEUSE_ORIG_SYS_REF' column_name, 5 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'SITE_USE_CODE' column_name, 6 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'PRIMARY_FLAG' column_name, 7 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'INSERT_UPDATE_FLAG' column_name, 8 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'LOCATION' column_name, 9 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'SET_CODE' column_name, 10 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'START_DATE' column_name, 11 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'END_DATE' column_name, 12 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ACCOUNT_NUMBER' column_name, 13 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'PARTY_SITE_NUMBER' column_name, 14 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 15 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE1' column_name, 16 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE2' column_name, 17 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE3' column_name, 18 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE4' column_name, 19 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE5' column_name, 20 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE6' column_name, 21 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE7' column_name, 22 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE8' column_name, 23 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE9' column_name, 24 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE10' column_name, 25 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE11' column_name, 26 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE12' column_name, 27 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE13' column_name, 28 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE14' column_name, 29 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE15' column_name, 30 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE16' column_name, 31 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE17' column_name, 32 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE18' column_name, 33 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE19' column_name, 34 fbdi_position from dual
    union all select 'HZ_ACCT_SITE_USES' object_code, 'ATTRIBUTE20' column_name, 35 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'HZ_LOCATIONS' object_code, 'BATCH_ID' column_name, 1 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'LOCATION_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'LOCATION_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'INSERT_UPDATE_FLAG' column_name, 4 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'COUNTRY' column_name, 5 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDRESS1' column_name, 6 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDRESS2' column_name, 7 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDRESS3' column_name, 8 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDRESS4' column_name, 9 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'CITY' column_name, 10 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'STATE' column_name, 11 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'PROVINCE' column_name, 12 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'COUNTY' column_name, 13 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'POSTAL_CODE' column_name, 14 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'POSTAL_PLUS4_CODE' column_name, 15 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'LOCATION_LANGUAGE' column_name, 16 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'DESCRIPTION' column_name, 17 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'SHORT_DESCRIPTION' column_name, 18 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'SALES_TAX_GEOCODE' column_name, 19 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'SALES_TAX_INSIDE_CITY_LIMITS' column_name, 20 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'TIMEZONE_CODE' column_name, 21 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDRESS1_STD' column_name, 22 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADAPTER_CONTENT_SOURCE' column_name, 23 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDR_VALID_STATUS_CODE' column_name, 24 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'DATE_VALIDATED' column_name, 25 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDRESS_EFFECTIVE_DATE' column_name, 26 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ADDRESS_EXPIRATION_DATE' column_name, 27 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'VALIDATED_FLAG' column_name, 28 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'DO_NOT_VALIDATE_FLAG' column_name, 29 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 30 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE1' column_name, 31 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE2' column_name, 32 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE3' column_name, 33 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE4' column_name, 34 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE5' column_name, 35 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE6' column_name, 36 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE7' column_name, 37 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE8' column_name, 38 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE9' column_name, 39 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE10' column_name, 40 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE11' column_name, 41 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE12' column_name, 42 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE13' column_name, 43 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE14' column_name, 44 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE15' column_name, 45 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE16' column_name, 46 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE17' column_name, 47 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE18' column_name, 48 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE19' column_name, 49 fbdi_position from dual
    union all select 'HZ_LOCATIONS' object_code, 'ATTRIBUTE20' column_name, 50 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'HZ_PARTIES' object_code, 'BATCH_ID' column_name, 1 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PARTY_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'INSERT_UPDATE_FLAG' column_name, 4 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PARTY_TYPE' column_name, 5 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PARTY_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'SALUTATION' column_name, 7 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PARTY_USAGE_CODE' column_name, 8 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'JGZZ_FISCAL_CODE' column_name, 9 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ORGANIZATION_NAME' column_name, 10 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'DUNS_NUMBER_C' column_name, 11 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PERSON_FIRST_NAME' column_name, 12 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PERSON_LAST_NAME' column_name, 13 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PERSON_LAST_NAME_PREFIX' column_name, 14 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PERSON_SECOND_LAST_NAME' column_name, 15 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PERSON_MIDDLE_NAME' column_name, 16 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PERSON_NAME_SUFFIX' column_name, 17 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'PERSON_TITLE' column_name, 18 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 19 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE1' column_name, 20 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE2' column_name, 21 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE3' column_name, 22 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE4' column_name, 23 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE5' column_name, 24 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE6' column_name, 25 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE7' column_name, 26 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE8' column_name, 27 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE9' column_name, 28 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE10' column_name, 29 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE11' column_name, 30 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE12' column_name, 31 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE13' column_name, 32 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE14' column_name, 33 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE15' column_name, 34 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE16' column_name, 35 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE17' column_name, 36 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE18' column_name, 37 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE19' column_name, 38 fbdi_position from dual
    union all select 'HZ_PARTIES' object_code, 'ATTRIBUTE20' column_name, 39 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'HZ_PARTY_SITES' object_code, 'BATCH_ID' column_name, 1 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'PARTY_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'SITE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'SITE_ORIG_SYSTEM_REFERENCE' column_name, 5 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'LOCATION_ORIG_SYSTEM' column_name, 6 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'LOCATION_ORIG_SYSTEM_REFERENCE' column_name, 7 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'INSERT_UPDATE_FLAG' column_name, 8 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'PARTY_SITE_NAME' column_name, 9 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'PARTY_SITE_NUMBER' column_name, 10 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'START_DATE_ACTIVE' column_name, 11 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'END_DATE_ACTIVE' column_name, 12 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'MAILSTOP' column_name, 13 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'IDENTIFYING_ADDRESS_FLAG' column_name, 14 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'PARTY_SITE_LANGUAGE' column_name, 15 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'REL_ORIG_SYSTEM' column_name, 16 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'REL_ORIG_SYSTEM_REFERENCE' column_name, 17 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 18 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE1' column_name, 19 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE2' column_name, 20 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE3' column_name, 21 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE4' column_name, 22 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE5' column_name, 23 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE6' column_name, 24 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE7' column_name, 25 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE8' column_name, 26 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE9' column_name, 27 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE10' column_name, 28 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE11' column_name, 29 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE12' column_name, 30 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE13' column_name, 31 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE14' column_name, 32 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE15' column_name, 33 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE16' column_name, 34 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE17' column_name, 35 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE18' column_name, 36 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE19' column_name, 37 fbdi_position from dual
    union all select 'HZ_PARTY_SITES' object_code, 'ATTRIBUTE20' column_name, 38 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'HZ_PARTY_SITE_USES' object_code, 'BATCH_ID' column_name, 1 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'PARTY_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'SITE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'SITE_ORIG_SYSTEM_REFERENCE' column_name, 5 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'SITE_USE_TYPE' column_name, 6 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'PRIMARY_FLAG' column_name, 7 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'INSERT_UPDATE_FLAG' column_name, 8 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'START_DATE' column_name, 9 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'END_DATE' column_name, 10 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'SITEUSE_ORIG_SYSTEM' column_name, 11 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'SITEUSE_ORIG_SYSTEM_REF' column_name, 12 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 13 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE1' column_name, 14 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE2' column_name, 15 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE3' column_name, 16 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE4' column_name, 17 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE5' column_name, 18 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE6' column_name, 19 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE7' column_name, 20 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE8' column_name, 21 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE9' column_name, 22 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE10' column_name, 23 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE11' column_name, 24 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE12' column_name, 25 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE13' column_name, 26 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE14' column_name, 27 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE15' column_name, 28 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE16' column_name, 29 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE17' column_name, 30 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE18' column_name, 31 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE19' column_name, 32 fbdi_position from dual
    union all select 'HZ_PARTY_SITE_USES' object_code, 'ATTRIBUTE20' column_name, 33 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'INV_TRX' object_code, 'ORGANIZATION_NAME' column_name, 1 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_GROUP_ID' column_name, 2 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_GROUP_SEQ' column_name, 3 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_BATCH_ID' column_name, 4 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_BATCH_SEQ' column_name, 5 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PROCESS_FLAG' column_name, 6 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'INVENTORY_ITEM' column_name, 7 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ITEM_NUMBER' column_name, 8 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'REVISION' column_name, 9 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'INV_LOTSERIAL_INTERFACE_NUM' column_name, 10 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SUBINVENTORY_CODE' column_name, 11 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOCATOR_NAME' column_name, 12 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT1' column_name, 13 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT2' column_name, 14 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT3' column_name, 15 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT4' column_name, 16 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT5' column_name, 17 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT6' column_name, 18 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT7' column_name, 19 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT8' column_name, 20 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT9' column_name, 21 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT10' column_name, 22 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT11' column_name, 23 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT12' column_name, 24 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT13' column_name, 25 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT14' column_name, 26 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT15' column_name, 27 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT16' column_name, 28 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT17' column_name, 29 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT18' column_name, 30 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT19' column_name, 31 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOC_SEGMENT20' column_name, 32 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_QUANTITY' column_name, 33 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_UOM' column_name, 34 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_UNIT_OF_MEASURE' column_name, 35 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'RESERVATION_QUANTITY' column_name, 36 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_DATE' column_name, 37 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_SOURCE_TYPE_NAME' column_name, 38 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_TYPE_NAME' column_name, 39 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_ORGANIZATION_TYPE' column_name, 40 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_ORGANIZATION_NAME' column_name, 41 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_SUBINVENTORY' column_name, 42 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT1' column_name, 43 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT2' column_name, 44 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT3' column_name, 45 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT4' column_name, 46 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT5' column_name, 47 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT6' column_name, 48 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT7' column_name, 49 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT8' column_name, 50 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT9' column_name, 51 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT10' column_name, 52 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT11' column_name, 53 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT12' column_name, 54 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT13' column_name, 55 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT14' column_name, 56 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT15' column_name, 57 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT16' column_name, 58 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT17' column_name, 59 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT18' column_name, 60 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT19' column_name, 61 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFER_LOC_SEGMENT20' column_name, 62 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PRIMARY_QUANTITY' column_name, 63 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SECONDARY_TRANSACTION_QUANTITY' column_name, 64 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SECONDARY_UOM_CODE' column_name, 65 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SECONDARY_UNIT_OF_MEASURE' column_name, 66 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SOURCE_CODE' column_name, 67 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SOURCE_HEADER_ID' column_name, 68 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SOURCE_LINE_ID' column_name, 69 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_SOURCE_NAME' column_name, 70 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT1' column_name, 71 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT2' column_name, 72 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT3' column_name, 73 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT4' column_name, 74 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT5' column_name, 75 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT6' column_name, 76 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT7' column_name, 77 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT8' column_name, 78 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT9' column_name, 79 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT10' column_name, 80 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT11' column_name, 81 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT12' column_name, 82 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT13' column_name, 83 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT14' column_name, 84 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT15' column_name, 85 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT16' column_name, 86 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT17' column_name, 87 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT18' column_name, 88 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT19' column_name, 89 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT20' column_name, 90 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT21' column_name, 91 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT22' column_name, 92 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT23' column_name, 93 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT24' column_name, 94 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT25' column_name, 95 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT26' column_name, 96 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT27' column_name, 97 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT28' column_name, 98 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT29' column_name, 99 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DSP_SEGMENT30' column_name, 100 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_ACTION_NAME' column_name, 101 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_MODE' column_name, 102 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOCK_FLAG' column_name, 103 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_REFERENCE' column_name, 104 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'REASON_NAME' column_name, 105 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CURRENCY_NAME' column_name, 106 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CURRENCY_CODE' column_name, 107 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CURRENCY_CONVERSION_TYPE' column_name, 108 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CURRENCY_CONVERSION_RATE' column_name, 109 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CURRENCY_CONVERSION_DATE' column_name, 110 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_COST' column_name, 111 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_COST' column_name, 112 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'NEW_AVERAGE_COST' column_name, 113 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'VALUE_CHANGE' column_name, 114 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PERCENTAGE_CHANGE' column_name, 115 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT1' column_name, 116 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT2' column_name, 117 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT3' column_name, 118 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT4' column_name, 119 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT5' column_name, 120 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT6' column_name, 121 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT7' column_name, 122 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT8' column_name, 123 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT9' column_name, 124 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT10' column_name, 125 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT11' column_name, 126 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT12' column_name, 127 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT13' column_name, 128 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT14' column_name, 129 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT15' column_name, 130 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT16' column_name, 131 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT17' column_name, 132 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT18' column_name, 133 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT19' column_name, 134 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT20' column_name, 135 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT21' column_name, 136 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT22' column_name, 137 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT23' column_name, 138 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT24' column_name, 139 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT25' column_name, 140 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT26' column_name, 141 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT27' column_name, 142 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT28' column_name, 143 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT29' column_name, 144 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DST_SEGMENT30' column_name, 145 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LOCATION_TYPE' column_name, 146 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'EMPLOYEE_CODE' column_name, 147 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'RECEIVING_DOCUMENT' column_name, 148 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'LINE_ITEM_NUM' column_name, 149 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SHIPMENT_NUMBER' column_name, 150 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSPORTATION_COST' column_name, 151 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CONTAINERS' column_name, 152 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'WAYBILL_AIRBILL' column_name, 153 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'EXPECTED_ARRIVAL_DATE' column_name, 154 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'REQUIRED_FLAG' column_name, 155 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SHIPPABLE_FLAG' column_name, 156 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SHIPPED_QUANTITY' column_name, 157 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'VALIDATION_REQUIRED' column_name, 158 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'NEGATIVE_REQ_FLAG' column_name, 159 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'OWNING_TP_TYPE' column_name, 160 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_OWNING_TP_TYPE' column_name, 161 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'OWNING_ORGANIZATION_NAME' column_name, 162 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFR_OWNING_ORGANIZATION_NAME' column_name, 163 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_PERCENTAGE' column_name, 164 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PLANNING_TP_TYPE' column_name, 165 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_PLANNING_TP_TYPE' column_name, 166 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ROUTING_REVISION' column_name, 167 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ROUTING_REVISION_DATE' column_name, 168 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ALTERNATE_BOM_DESIGNATOR' column_name, 169 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ALTERNATE_ROUTING_DESIGNATOR' column_name, 170 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ORGANIZATION_TYPE' column_name, 171 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'USSGL_TRANSACTION_CODE' column_name, 172 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'WIP_ENTITY_TYPE' column_name, 173 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SCHEDULE_UPDATE_CODE' column_name, 174 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'SETUP_TEARDOWN_CODE' column_name, 175 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PRIMARY_SWITCH' column_name, 176 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'MRP_CODE' column_name, 177 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'OPERATION_SEQ_NUM' column_name, 178 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'WIP_SUPPLY_TYPE' column_name, 179 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'RELIEVE_RESERVATIONS_FLAG' column_name, 180 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'RELIEVE_HIGH_LEVEL_RSV_FLAG' column_name, 181 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_PRICE' column_name, 182 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'BUILD_BREAK_TO_UOM' column_name, 183 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'BUILD_BREAK_TO_UNIT_OF_MEASURE' column_name, 184 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_CATEGORY' column_name, 185 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE1' column_name, 186 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE2' column_name, 187 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE3' column_name, 188 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE4' column_name, 189 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE5' column_name, 190 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE6' column_name, 191 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE7' column_name, 192 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE8' column_name, 193 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE9' column_name, 194 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE10' column_name, 195 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE11' column_name, 196 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE12' column_name, 197 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE13' column_name, 198 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE14' column_name, 199 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE15' column_name, 200 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE16' column_name, 201 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE17' column_name, 202 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE18' column_name, 203 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE19' column_name, 204 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE20' column_name, 205 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER1' column_name, 206 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER2' column_name, 207 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER3' column_name, 208 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER4' column_name, 209 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER5' column_name, 210 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER6' column_name, 211 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER7' column_name, 212 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER8' column_name, 213 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER9' column_name, 214 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_NUMBER10' column_name, 215 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_DATE1' column_name, 216 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_DATE2' column_name, 217 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_DATE3' column_name, 218 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_DATE4' column_name, 219 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_DATE5' column_name, 220 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 221 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 222 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 223 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 224 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 225 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSACTION_COST_IDENTIFIER' column_name, 226 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DEFAULT_TAXATION_COUNTRY' column_name, 227 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'DOCUMENT_SUB_TYPE' column_name, 228 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRX_BUSINESS_CATEGORY' column_name, 229 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'USER_DEFINED_FISC_CLASS' column_name, 230 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TAX_INVOICE_NUMBER' column_name, 231 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TAX_INVOICE_DATE' column_name, 232 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PRODUCT_CATEGORY' column_name, 233 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PRODUCT_TYPE' column_name, 234 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'ASSESSABLE_VALUE' column_name, 235 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TAX_CLASSIFICATION_CODE' column_name, 236 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'EXEMPT_CERTIFICATE_NUMBER' column_name, 237 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'EXEMPT_REASON_CODE' column_name, 238 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'INTENDED_USE' column_name, 239 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'FIRST_PTY_NUMBER' column_name, 240 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'THIRD_PTY_NUMBER' column_name, 241 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'FINAL_DISCHARGE_LOC_CODE' column_name, 242 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CATEGORY_NAME' column_name, 243 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'OWNING_ORGANIZATION_ID' column_name, 244 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'XFR_OWNING_ORGANIZATION_ID' column_name, 245 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'PRC_BU_NAME' column_name, 246 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'VENDOR_NAME' column_name, 247 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'VENDOR_NUMBER' column_name, 248 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'CONSIGNMENT_AGREEMENT_NUM' column_name, 249 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'USE_CURRENT_COST' column_name, 250 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'EXTERNAL_SYSTEM_PACKING_UNIT' column_name, 251 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_LOCATOR_NAME' column_name, 252 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'INV_PROJECT' column_name, 253 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'INV_TASK' column_name, 254 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'COUNTRY_OF_ORIGIN_NAME' column_name, 255 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_INV_PROJECT' column_name, 256 fbdi_position from dual
    union all select 'INV_TRX' object_code, 'TRANSFER_INV_TASK' column_name, 257 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'INV_TRX_LOTS' object_code, 'INVENTORY_LOT_INTERFACE_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'INVENTORY_SERIAL_INTERFACE_NUM' column_name, 2 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'SOURCE_CODE' column_name, 3 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'SOURCE_LINE_ID' column_name, 4 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'LOT_NUMBER' column_name, 5 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'DESCRIPTION' column_name, 6 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'LOT_EXPIRATION_DATE' column_name, 7 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'TRANSACTION_QUANTITY' column_name, 8 fbdi_position from dual
    union all select 'INV_TRX_LOTS' object_code, 'PRIMARY_QUANTITY' column_name, 9 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'INV_TRX_SERIALS' object_code, 'FM_SERIAL_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'INV_TRX_SERIALS' object_code, 'TO_SERIAL_NUMBER' column_name, 5 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PJB_BILL_EVENTS' object_code, 'SOURCENAME' column_name, 1 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'SOURCEREF' column_name, 2 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ORGANIZATION_NAME' column_name, 3 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'CONTRACT_TYPE_NAME' column_name, 4 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'CONTRACT_NUMBER' column_name, 5 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'CONTRACT_LINE_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'EVENT_TYPE_NAME' column_name, 7 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'EVENT_DESC' column_name, 8 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'COMPLETION_DATE' column_name, 9 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'BILL_TRNS_CURRENCY_CODE' column_name, 10 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'BILL_TRNS_AMOUNT' column_name, 11 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'PROJECT_NUMBER' column_name, 12 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'TASK_NUMBER' column_name, 13 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'BILL_HOLD_FLAG' column_name, 14 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'REVENUE_HOLD_FLAG' column_name, 15 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 16 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE1' column_name, 17 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE2' column_name, 18 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE3' column_name, 19 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE4' column_name, 20 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE5' column_name, 21 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE6' column_name, 22 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE7' column_name, 23 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE8' column_name, 24 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE9' column_name, 25 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE10' column_name, 26 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR11' column_name, 27 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR12' column_name, 28 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR13' column_name, 29 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR14' column_name, 30 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR15' column_name, 31 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR16' column_name, 32 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR17' column_name, 33 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR18' column_name, 34 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR19' column_name, 35 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR20' column_name, 36 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR21' column_name, 37 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR22' column_name, 38 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR23' column_name, 39 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR24' column_name, 40 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR25' column_name, 41 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR26' column_name, 42 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR27' column_name, 43 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR28' column_name, 44 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR29' column_name, 45 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_CHAR30' column_name, 46 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER1' column_name, 47 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER2' column_name, 48 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER3' column_name, 49 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER4' column_name, 50 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER5' column_name, 51 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER6' column_name, 52 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER7' column_name, 53 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER8' column_name, 54 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER9' column_name, 55 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_NUMBER10' column_name, 56 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE1' column_name, 57 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE2' column_name, 58 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE3' column_name, 59 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE4' column_name, 60 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE5' column_name, 61 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE6' column_name, 62 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE7' column_name, 63 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE8' column_name, 64 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE9' column_name, 65 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_DATE10' column_name, 66 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 67 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 68 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 69 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 70 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 71 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'REVERSE_ACCRUAL_FLAG' column_name, 72 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ITEM_EVENT_FLAG' column_name, 73 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'QUANTITY' column_name, 74 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'ITEM_NUMBER' column_name, 75 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'UNIT_OF_MEASURE' column_name, 76 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'UNIT_PRICE' column_name, 77 fbdi_position from dual
    union all select 'PJB_BILL_EVENTS' object_code, 'PREPAYMENT_REQ_EVENT_NUM' column_name, 78 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PJC_EXPENDITURES' object_code, 'TRANSACTION_TYPE' column_name, 1 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BUSINESS_UNIT' column_name, 2 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ORG_ID' column_name, 3 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_TRANSACTION_SOURCE' column_name, 4 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'TRANSACTION_SOURCE_ID' column_name, 5 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DOCUMENT_NAME' column_name, 6 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DOCUMENT_ID' column_name, 7 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DOC_ENTRY_NAME' column_name, 8 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DOC_ENTRY_ID' column_name, 9 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BATCH_NAME' column_name, 10 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BATCH_ENDING_DATE' column_name, 11 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BATCH_DESCRIPTION' column_name, 12 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'EXPENDITURE_ITEM_DATE' column_name, 13 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'PERSON_NUMBER' column_name, 14 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'PERSON_NAME' column_name, 15 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'PERSON_ID' column_name, 16 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'HCM_ASSIGNMENT_NAME' column_name, 17 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'HCM_ASSIGNMENT_ID' column_name, 18 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'PROJECT_NUMBER' column_name, 19 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'PROJECT_NAME' column_name, 20 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'PROJECT_ID' column_name, 21 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'TASK_NUMBER' column_name, 22 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'TASK_NAME' column_name, 23 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'TASK_ID' column_name, 24 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'EXPENDITURE_TYPE' column_name, 25 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'EXPENDITURE_TYPE_ID' column_name, 26 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ORGANIZATION_NAME' column_name, 27 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ORGANIZATION_ID' column_name, 28 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'QUANTITY' column_name, 29 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'UNIT_OF_MEASURE_NAME' column_name, 30 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'UNIT_OF_MEASURE' column_name, 31 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'WORK_TYPE' column_name, 32 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'WORK_TYPE_ID' column_name, 33 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BILLABLE_FLAG' column_name, 34 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'CAPITALIZABLE_FLAG' column_name, 35 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ORIG_TRANSACTION_REFERENCE' column_name, 36 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'UNMATCHED_NEGATIVE_TXN_FLAG' column_name, 37 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'REVERSED_ORIG_TXN_REFERENCE' column_name, 38 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'EXPENDITURE_COMMENT' column_name, 39 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'GL_DATE' column_name, 40 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DENOM_CURRENCY_CODE' column_name, 41 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DENOM_CURRENCY' column_name, 42 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DENOM_RAW_COST' column_name, 43 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'DENOM_BURDENED_COST' column_name, 44 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RAW_COST_CR_CCID' column_name, 45 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RAW_COST_CR_ACCOUNT' column_name, 46 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RAW_COST_DR_CCID' column_name, 47 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RAW_COST_DR_ACCOUNT' column_name, 48 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDENED_COST_CR_CCID' column_name, 49 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDENED_COST_CR_ACCOUNT' column_name, 50 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDENED_COST_DR_CCID' column_name, 51 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDENED_COST_DR_ACCOUNT' column_name, 52 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDEN_COST_CR_CCID' column_name, 53 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDEN_COST_CR_ACCOUNT' column_name, 54 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDEN_COST_DR_CCID' column_name, 55 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'BURDEN_COST_DR_ACCOUNT' column_name, 56 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_CURRENCY_CODE' column_name, 57 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_CURRENCY' column_name, 58 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_RAW_COST' column_name, 59 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_BURDENED_COST' column_name, 60 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_RATE_TYPE' column_name, 61 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_RATE_DATE' column_name, 62 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_RATE_DATE_TYPE' column_name, 63 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_EXCHANGE_RATE' column_name, 64 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ACCT_EXCHANGE_ROUNDING_LIMIT' column_name, 65 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'CONVERTED_FLAG' column_name, 66 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'CONTEXT_CATEGORY' column_name, 67 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE1' column_name, 68 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE2' column_name, 69 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE3' column_name, 70 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE4' column_name, 71 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE5' column_name, 72 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE6' column_name, 73 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE7' column_name, 74 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE8' column_name, 75 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE9' column_name, 76 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'USER_DEF_ATTRIBUTE10' column_name, 77 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE1' column_name, 78 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE2' column_name, 79 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE3' column_name, 80 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE4' column_name, 81 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE5' column_name, 82 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE6' column_name, 83 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE7' column_name, 84 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE8' column_name, 85 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE9' column_name, 86 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'RESERVED_ATTRIBUTE10' column_name, 87 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 88 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE1' column_name, 89 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE2' column_name, 90 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE3' column_name, 91 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE4' column_name, 92 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE5' column_name, 93 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE6' column_name, 94 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE7' column_name, 95 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE8' column_name, 96 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE9' column_name, 97 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'ATTRIBUTE10' column_name, 98 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'CONTRACT_NUMBER' column_name, 99 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'CONTRACT_NAME' column_name, 100 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'CONTRACT_ID' column_name, 101 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'FUNDING_SOURCE_NUMBER' column_name, 102 fbdi_position from dual
    union all select 'PJC_EXPENDITURES' object_code, 'FUNDING_SOURCE_NAME' column_name, 103 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PJC_TXN_CONTROLS' object_code, 'TXN_CTRL_REFERENCE' column_name, 1 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'PROJECT_NAME' column_name, 2 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'PROJECT_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'TASK_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'TASK_NAME' column_name, 5 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'EXPENDITURE_CATEGORY_NAME' column_name, 6 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'EXPENDITURE_TYPE' column_name, 7 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'NON_LABOR_RESOURCE' column_name, 8 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'PERSON_NUMBER' column_name, 9 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'PERSON_NAME' column_name, 10 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'PERSON_EMAILID' column_name, 11 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'PERSON_TYPE' column_name, 12 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'JOB_NAME' column_name, 13 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'ORGANIZATION_NAME' column_name, 14 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'CHARGEABLE_FLAG' column_name, 15 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'BILLABLE_FLAG' column_name, 16 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'CAPITALIZABLE_FLAG' column_name, 17 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'START_DATE_ACTIVE' column_name, 18 fbdi_position from dual
    union all select 'PJC_TXN_CONTROLS' object_code, 'END_DATE_ACTIVE' column_name, 19 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PJF_PROJECTS' object_code, 'PROJECT_NAME' column_name, 1 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'SOURCE_TEMPLATE_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'SOURCE_APPLICATION_CODE' column_name, 4 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'SOURCE_PROJECT_REFERENCE' column_name, 5 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ORGANIZATION_NAME' column_name, 6 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'LEGAL_ENTITY_NAME' column_name, 7 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'DESCRIPTION' column_name, 8 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_MANAGER_NUMBER' column_name, 9 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_MANAGER_NAME' column_name, 10 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_MANAGER_EMAIL' column_name, 11 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_START_DATE' column_name, 12 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_FINISH_DATE' column_name, 13 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CLOSED_DATE' column_name, 14 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_STATUS_NAME' column_name, 15 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_PRIORITY_CODE' column_name, 16 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OUTLINE_DISPLAY_LEVEL' column_name, 17 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PLANNING_PROJECT_FLAG' column_name, 18 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'SERVICE_TYPE_CODE' column_name, 19 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'WORK_TYPE_NAME' column_name, 20 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'LIMIT_TO_TXN_CONTROLS_CODE' column_name, 21 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_CURRENCY_CODE' column_name, 22 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CURRENCY_CONV_RATE_TYPE' column_name, 23 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CURRENCY_CONV_DATE_TYPE_CODE' column_name, 24 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CURRENCY_CONV_DATE' column_name, 25 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CINT_ELIGIBLE_FLAG' column_name, 26 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CINT_RATE_SCH_NAME' column_name, 27 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CINT_STOP_DATE' column_name, 28 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ASSET_ALLOCATION_METHOD_CODE' column_name, 29 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CAPITAL_EVENT_PROCESSING_CODE' column_name, 30 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ALLOW_CROSS_CHARGE_FLAG' column_name, 31 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CC_PROCESS_LABOR_FLAG' column_name, 32 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'LABOR_TP_SCHEDULE_NAME' column_name, 33 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'LABOR_TP_FIXED_DATE' column_name, 34 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CC_PROCESS_NL_FLAG' column_name, 35 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'NL_TP_SCHEDULE_NAME' column_name, 36 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'NL_TP_FIXED_DATE' column_name, 37 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'BURDEN_SCHEDULE_NAME' column_name, 38 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'BURDEN_SCH_FIXED_DATED' column_name, 39 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'KPI_NOTIFICATION_ENABLED' column_name, 40 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'KPI_NOTIFICATION_RECIPIENTS' column_name, 41 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'KPI_NOTIFICATION_INCLUDE_NOTES' column_name, 42 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_TEAM_MEMBERS_FLAG' column_name, 43 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_PROJECT_CLASSES_FLAG' column_name, 44 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_ATTACHMENTS_FLAG' column_name, 45 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_DFF_FLAG' column_name, 46 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_GROUP_SPACE_FLAG' column_name, 47 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_TASKS_FLAG' column_name, 48 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_TASK_ATTACHMENTS_FLAG' column_name, 49 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_TASK_DFF_FLAG' column_name, 50 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_TASK_ASSIGNMENTS_FLAG' column_name, 51 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_TRANSACTION_CONTROLS_FLAG' column_name, 52 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_ASSETS_FLAG' column_name, 53 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_ASSET_ASSIGNMENTS_FLAG' column_name, 54 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'COPY_COST_OVERRIDES_FLAG' column_name, 55 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 56 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE1' column_name, 57 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE2' column_name, 58 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE3' column_name, 59 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE4' column_name, 60 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE5' column_name, 61 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE6' column_name, 62 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE7' column_name, 63 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE8' column_name, 64 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE9' column_name, 65 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE10' column_name, 66 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE11' column_name, 67 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE12' column_name, 68 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE13' column_name, 69 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE14' column_name, 70 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE15' column_name, 71 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE16' column_name, 72 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE17' column_name, 73 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE18' column_name, 74 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE19' column_name, 75 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE20' column_name, 76 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE21' column_name, 77 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE22' column_name, 78 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE23' column_name, 79 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE24' column_name, 80 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE25' column_name, 81 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE26' column_name, 82 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE27' column_name, 83 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE28' column_name, 84 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE29' column_name, 85 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE30' column_name, 86 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE31' column_name, 87 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE32' column_name, 88 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE33' column_name, 89 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE34' column_name, 90 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE35' column_name, 91 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE36' column_name, 92 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE37' column_name, 93 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE38' column_name, 94 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE39' column_name, 95 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE40' column_name, 96 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE41' column_name, 97 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE42' column_name, 98 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE43' column_name, 99 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE44' column_name, 100 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE45' column_name, 101 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE46' column_name, 102 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE47' column_name, 103 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE48' column_name, 104 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE49' column_name, 105 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE50' column_name, 106 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE1_NUMBER' column_name, 107 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE2_NUMBER' column_name, 108 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE3_NUMBER' column_name, 109 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE4_NUMBER' column_name, 110 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE5_NUMBER' column_name, 111 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE6_NUMBER' column_name, 112 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE7_NUMBER' column_name, 113 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE8_NUMBER' column_name, 114 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE9_NUMBER' column_name, 115 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE10_NUMBER' column_name, 116 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE11_NUMBER' column_name, 117 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE12_NUMBER' column_name, 118 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE13_NUMBER' column_name, 119 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE14_NUMBER' column_name, 120 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE15_NUMBER' column_name, 121 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE1_DATE' column_name, 122 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE2_DATE' column_name, 123 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE3_DATE' column_name, 124 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE4_DATE' column_name, 125 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE5_DATE' column_name, 126 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE6_DATE' column_name, 127 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE7_DATE' column_name, 128 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE8_DATE' column_name, 129 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE9_DATE' column_name, 130 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE10_DATE' column_name, 131 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE11_DATE' column_name, 132 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE12_DATE' column_name, 133 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE13_DATE' column_name, 134 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE14_DATE' column_name, 135 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'ATTRIBUTE15_DATE' column_name, 136 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'SCHEDULE_NAME' column_name, 137 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'EPS_NAME' column_name, 138 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PROJECT_PLAN_VIEW_ACCESS' column_name, 139 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'SCHEDULE_TYPE' column_name, 140 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_ID' column_name, 141 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_NUMBER' column_name, 142 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_CUSTOMER_NUMBER' column_name, 143 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_CUSTOMER_ID' column_name, 144 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_AMT' column_name, 145 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_CURRCODE' column_name, 146 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_WIN_CONF_PERCENT' column_name, 147 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_NAME' column_name, 148 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_DESC' column_name, 149 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_CUSTOMER_NAME' column_name, 150 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'OPPORTUNITY_STATUS' column_name, 151 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PRJ_PLAN_BASELINE_NAME' column_name, 152 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PRJ_PLAN_BASELINE_DESC' column_name, 153 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'PRJ_PLAN_BASELINE_DATE' column_name, 154 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'BUDGETARY_CONTROL_FLAG' column_name, 155 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'SOURCE_TEMPLATE_NAME' column_name, 156 fbdi_position from dual
    union all select 'PJF_PROJECTS' object_code, 'CASCADE_OPTION' column_name, 157 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PJF_TASKS' object_code, 'PROJECT_NAME' column_name, 1 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'TASK_NAME' column_name, 3 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'TASK_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'TASK_DESCRIPTION' column_name, 5 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'PARENT_TASK_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'PLANNING_START_DATE' column_name, 7 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'PLANNING_END_DATE' column_name, 8 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'MILESTONE_FLAG' column_name, 9 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'CRITICAL_FLAG' column_name, 10 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'CHARGEABLE_FLAG' column_name, 11 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BILLABLE_FLAG' column_name, 12 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'CAPITALIZABLE_FLAG' column_name, 13 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'LIMIT_TO_TXN_CONTROLS_FLAG' column_name, 14 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'SOURCE_TASK_REFERENCE' column_name, 15 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'SOURCE_APPLICATION_CODE' column_name, 16 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'SERVICE_TYPE_CODE' column_name, 17 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'WORK_TYPE_ID' column_name, 18 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'MANAGER_PERSON_ID' column_name, 19 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ALLOW_CROSS_CHARGE_FLAG' column_name, 20 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'CC_PROCESS_LABOR_FLAG' column_name, 21 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'CC_PROCESS_NL_FLAG' column_name, 22 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'RECEIVE_PROJECT_INVOICE_FLAG' column_name, 23 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 24 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE1' column_name, 25 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE2' column_name, 26 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE3' column_name, 27 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE4' column_name, 28 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE5' column_name, 29 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE6' column_name, 30 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE7' column_name, 31 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE8' column_name, 32 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE9' column_name, 33 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE10' column_name, 34 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE11' column_name, 35 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE12' column_name, 36 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE13' column_name, 37 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE14' column_name, 38 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE15' column_name, 39 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE16' column_name, 40 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE17' column_name, 41 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE18' column_name, 42 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE19' column_name, 43 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE20' column_name, 44 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE21' column_name, 45 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE22' column_name, 46 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE23' column_name, 47 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE24' column_name, 48 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE25' column_name, 49 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE26' column_name, 50 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE27' column_name, 51 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE28' column_name, 52 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE29' column_name, 53 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE30' column_name, 54 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE31' column_name, 55 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE32' column_name, 56 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE33' column_name, 57 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE34' column_name, 58 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE35' column_name, 59 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE36' column_name, 60 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE37' column_name, 61 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE38' column_name, 62 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE39' column_name, 63 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE40' column_name, 64 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE41' column_name, 65 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE42' column_name, 66 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE43' column_name, 67 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE44' column_name, 68 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE45' column_name, 69 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE46' column_name, 70 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE47' column_name, 71 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE48' column_name, 72 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE49' column_name, 73 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE50' column_name, 74 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE1_NUMBER' column_name, 75 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE2_NUMBER' column_name, 76 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE3_NUMBER' column_name, 77 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE4_NUMBER' column_name, 78 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE5_NUMBER' column_name, 79 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE6_NUMBER' column_name, 80 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE7_NUMBER' column_name, 81 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE8_NUMBER' column_name, 82 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE9_NUMBER' column_name, 83 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE10_NUMBER' column_name, 84 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE11_NUMBER' column_name, 85 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE12_NUMBER' column_name, 86 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE13_NUMBER' column_name, 87 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE14_NUMBER' column_name, 88 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE15_NUMBER' column_name, 89 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE1_DATE' column_name, 90 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE2_DATE' column_name, 91 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE3_DATE' column_name, 92 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE4_DATE' column_name, 93 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE5_DATE' column_name, 94 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE6_DATE' column_name, 95 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE7_DATE' column_name, 96 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE8_DATE' column_name, 97 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE9_DATE' column_name, 98 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE10_DATE' column_name, 99 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE11_DATE' column_name, 100 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE12_DATE' column_name, 101 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE13_DATE' column_name, 102 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE14_DATE' column_name, 103 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ATTRIBUTE15_DATE' column_name, 104 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'ORGANIZATION_NAME' column_name, 105 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'FINANCIAL_TASK' column_name, 106 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'PLANNED_EFFORT' column_name, 107 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'PLANNED_DURATION' column_name, 108 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'REQMNT_CODE' column_name, 109 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'SPRINT' column_name, 110 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'PRIORITY' column_name, 111 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'SCHEDULE_MODE' column_name, 112 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_START_DATE' column_name, 113 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_FINISH_DATE' column_name, 114 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_EFFORT' column_name, 115 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_DURATION' column_name, 116 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_ALLOCATION' column_name, 117 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'CONSTRAINT_TYPE' column_name, 118 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'CONSTRAINT_DATE' column_name, 119 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_LABOR_COST_AMOUNT' column_name, 120 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_LABOR_BILLED_AMOUNT' column_name, 121 fbdi_position from dual
    union all select 'PJF_TASKS' object_code, 'BASELINE_EXPENSE_COST_AMOUNT' column_name, 122 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PJF_TEAM_MEMBERS' object_code, 'PROJECT_NAME' column_name, 1 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'TEAM_MEMBER_NUMBER' column_name, 2 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'TEAM_MEMBER_NAME' column_name, 3 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'TEAM_MEMBER_EMAIL' column_name, 4 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'PROJECT_ROLE_NAME' column_name, 5 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'START_DATE_ACTIVE' column_name, 6 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'END_DATE_ACTIVE' column_name, 7 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'TRACK_TIME_FLAG' column_name, 8 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'ALLOCATION' column_name, 9 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'EFFORT' column_name, 10 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'COST_RATE' column_name, 11 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'BILL_RATE' column_name, 12 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'ASSIGNMENT_TYPE' column_name, 13 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'BILLABLE_PERCENT' column_name, 14 fbdi_position from dual
    union all select 'PJF_TEAM_MEMBERS' object_code, 'BILLABLE_PERCENT_REASON_CODE' column_name, 15 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POR_REQ_DISTS' object_code, 'INTERFACE_DISTRIBUTION_KEY' column_name, 1 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'INTERFACE_LINE_KEY' column_name, 2 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PERCENT' column_name, 3 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'DISTRIBUTION_NUMBER' column_name, 4 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'DISTRIBUTION_QUANTITY' column_name, 5 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'DISTRIBUTION_CURRENCY_AMOUNT' column_name, 6 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_PROJECT_NAME' column_name, 7 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_TASK_NAME' column_name, 8 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_EXPENDITURE_TYPE_NAME' column_name, 9 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_EXPENDITURE_ITEM_DATE' column_name, 10 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_ORGANIZATION_NAME' column_name, 11 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_BILLABLE_FLAG' column_name, 12 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_CAPITALIZABLE_FLAG' column_name, 13 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE1' column_name, 14 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE2' column_name, 15 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE3' column_name, 16 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE4' column_name, 17 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE5' column_name, 18 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE6' column_name, 19 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE7' column_name, 20 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE8' column_name, 21 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE9' column_name, 22 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_RESERVED_ATTRIBUTE10' column_name, 23 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE1' column_name, 24 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE2' column_name, 25 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE3' column_name, 26 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE4' column_name, 27 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE5' column_name, 28 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE6' column_name, 29 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE7' column_name, 30 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE8' column_name, 31 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE9' column_name, 32 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_USER_DEF_ATTRIBUTE10' column_name, 33 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE1' column_name, 34 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE2' column_name, 35 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE3' column_name, 36 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE4' column_name, 37 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE5' column_name, 38 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE6' column_name, 39 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE7' column_name, 40 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE8' column_name, 41 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE9' column_name, 42 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE10' column_name, 43 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE11' column_name, 44 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE12' column_name, 45 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE13' column_name, 46 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE14' column_name, 47 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE15' column_name, 48 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE16' column_name, 49 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE17' column_name, 50 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE18' column_name, 51 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE19' column_name, 52 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE20' column_name, 53 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE1' column_name, 54 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE2' column_name, 55 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE3' column_name, 56 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE4' column_name, 57 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE5' column_name, 58 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE6' column_name, 59 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE7' column_name, 60 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE8' column_name, 61 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE9' column_name, 62 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_DATE10' column_name, 63 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 64 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 65 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 66 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 67 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 68 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 69 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 70 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 71 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 72 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 73 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER1' column_name, 74 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER2' column_name, 75 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER3' column_name, 76 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER4' column_name, 77 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER5' column_name, 78 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER6' column_name, 79 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER7' column_name, 80 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER8' column_name, 81 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER9' column_name, 82 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_NUMBER10' column_name, 83 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 84 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT1' column_name, 85 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT2' column_name, 86 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT3' column_name, 87 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT4' column_name, 88 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT5' column_name, 89 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT6' column_name, 90 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT7' column_name, 91 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT8' column_name, 92 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT9' column_name, 93 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT10' column_name, 94 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT11' column_name, 95 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT12' column_name, 96 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT13' column_name, 97 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT14' column_name, 98 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT15' column_name, 99 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT16' column_name, 100 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT17' column_name, 101 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT18' column_name, 102 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT19' column_name, 103 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT20' column_name, 104 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT21' column_name, 105 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT22' column_name, 106 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT23' column_name, 107 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT24' column_name, 108 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT25' column_name, 109 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT26' column_name, 110 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT27' column_name, 111 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT28' column_name, 112 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT29' column_name, 113 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'CHARGE_ACCOUNT_SEGMENT30' column_name, 114 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'PJC_WORK_TYPE' column_name, 115 fbdi_position from dual
    union all select 'POR_REQ_DISTS' object_code, 'BUDGET_DATE' column_name, 116 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POR_REQ_HEADERS' object_code, 'INTERFACE_HEADER_KEY' column_name, 1 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'INTERFACE_SOURCE_CODE' column_name, 2 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'REQ_BU_NAME' column_name, 3 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'BATCH_ID' column_name, 4 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'INTERFACE_SOURCE_LINE_ID' column_name, 5 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'DOCUMENT_STATUS' column_name, 6 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'APPROVER_EMAIL_ADDR' column_name, 7 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'PREPARER_EMAIL_ADDR' column_name, 8 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'PRC_BU_NAME' column_name, 9 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'REQUISITION_NUMBER' column_name, 10 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'DESCRIPTION' column_name, 11 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'EMERGENCY_PO_NUMBER' column_name, 12 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'DEFAULT_TAXATION_COUNTRY' column_name, 13 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'DEFAULT_TAXATION_TERRITORY' column_name, 14 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'DOCUMENT_SUB_TYPE' column_name, 15 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'DOCUMENT_SUB_TYPE_NAME' column_name, 16 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'JUSTIFICATION' column_name, 17 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE1' column_name, 18 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE2' column_name, 19 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE3' column_name, 20 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE4' column_name, 21 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE5' column_name, 22 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE6' column_name, 23 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE7' column_name, 24 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE8' column_name, 25 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE9' column_name, 26 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE10' column_name, 27 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE11' column_name, 28 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE12' column_name, 29 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE13' column_name, 30 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE14' column_name, 31 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE15' column_name, 32 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE16' column_name, 33 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE17' column_name, 34 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE18' column_name, 35 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE19' column_name, 36 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE20' column_name, 37 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE1' column_name, 38 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE2' column_name, 39 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE3' column_name, 40 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE4' column_name, 41 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE5' column_name, 42 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE6' column_name, 43 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE7' column_name, 44 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE8' column_name, 45 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE9' column_name, 46 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_DATE10' column_name, 47 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 48 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 49 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 50 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 51 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 52 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 53 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 54 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 55 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 56 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 57 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER1' column_name, 58 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER2' column_name, 59 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER3' column_name, 60 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER4' column_name, 61 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER5' column_name, 62 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER6' column_name, 63 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER7' column_name, 64 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER8' column_name, 65 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER9' column_name, 66 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_NUMBER10' column_name, 67 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 68 fbdi_position from dual
    union all select 'POR_REQ_HEADERS' object_code, 'SOLDTO_LE_NAME' column_name, 69 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POR_REQ_LINES' object_code, 'INTERFACE_LINE_KEY' column_name, 1 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'INTERFACE_HEADER_KEY' column_name, 2 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'GROUP_CODE' column_name, 3 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'DESTINATION_TYPE_CODE' column_name, 4 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'DELIVER_TO_LOCATION_CODE' column_name, 5 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'DESTINATION_ORGANIZATION_CODE' column_name, 6 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'DESTINATION_SUBINVENTORY' column_name, 7 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'REQUESTER_EMAIL_ADDR' column_name, 8 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ITEM_DESCRIPTION' column_name, 9 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'CATEGORY_NAME' column_name, 10 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'NEED_BY_DATE' column_name, 11 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ITEM_NUMBER' column_name, 12 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ITEM_REVISION' column_name, 13 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'UOM_CODE' column_name, 14 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'LINE_TYPE' column_name, 15 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'QUANTITY' column_name, 16 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'CURRENCY_CODE' column_name, 17 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'CURRENCY_UNIT_PRICE' column_name, 18 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'RATE' column_name, 19 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'RATE_DATE' column_name, 20 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'RATE_TYPE' column_name, 21 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SECONDARY_UOM_CODE' column_name, 22 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SECONDARY_QUANTITY' column_name, 23 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'CURRENCY_AMOUNT' column_name, 24 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'UN_NUMBER' column_name, 25 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'HAZARD_CLASS' column_name, 26 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'PRC_BU_NAME' column_name, 27 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SOURCE_DOC_HEADER_NUMBER' column_name, 28 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SOURCE_DOC_LINE_NUMBER' column_name, 29 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_VENDOR_NAME' column_name, 30 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_VENDOR_SITE' column_name, 31 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_VENDOR_CONTACT' column_name, 32 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_VENDOR_CONTACT_PHONE' column_name, 33 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_VENDOR_CONTACT_FAX' column_name, 34 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_VENDOR_CONTACT_EMAIL' column_name, 35 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_SUPPLIER_ITEM_NUM' column_name, 36 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SUGGESTED_BUYER_EMAIL_ADDR' column_name, 37 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'AUTOSOURCE_FLAG' column_name, 38 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'NEGOTIATED_BY_PREPARER_FLAG' column_name, 39 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'NEGOTIATION_REQUIRED_FLAG' column_name, 40 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'URGENT_FLAG' column_name, 41 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'NEW_SUPPLIER_FLAG' column_name, 42 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'NOTE_TO_BUYER' column_name, 43 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'NOTE_TO_RECEIVER' column_name, 44 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'TRX_BUSINESS_CATEGORY' column_name, 45 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'TRX_BUSINESS_CATEGORY_NAME' column_name, 46 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'PRODUCT_TYPE' column_name, 47 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'PRODUCT_TYPE_NAME' column_name, 48 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'PRODUCT_FISC_CLASSIFICATION' column_name, 49 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'PRODUCT_FISC_CLASS_NAME' column_name, 50 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'PRODUCT_CATEGORY' column_name, 51 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'PRODUCT_CATEGORY_NAME' column_name, 52 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'LINE_INTENDED_USE' column_name, 53 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'LINE_INTENDED_USE_NAME' column_name, 54 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'USER_DEFINED_FISC_CLASS' column_name, 55 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'USER_DEFINED_FISC_CLASS_NAME' column_name, 56 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'TAX_CLASSIFICATION_CODE' column_name, 57 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'TAX_CLASSIFICATION_NAME' column_name, 58 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ASSESSABLE_VALUE' column_name, 59 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE1' column_name, 60 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE2' column_name, 61 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE3' column_name, 62 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE4' column_name, 63 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE5' column_name, 64 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE6' column_name, 65 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE7' column_name, 66 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE8' column_name, 67 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE9' column_name, 68 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE10' column_name, 69 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE11' column_name, 70 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE12' column_name, 71 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE13' column_name, 72 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE14' column_name, 73 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE15' column_name, 74 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE16' column_name, 75 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE17' column_name, 76 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE18' column_name, 77 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE19' column_name, 78 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE20' column_name, 79 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE1' column_name, 80 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE2' column_name, 81 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE3' column_name, 82 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE4' column_name, 83 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE5' column_name, 84 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE6' column_name, 85 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE7' column_name, 86 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE8' column_name, 87 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE9' column_name, 88 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_DATE10' column_name, 89 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 90 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 91 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 92 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 93 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 94 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 95 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 96 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 97 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 98 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 99 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER1' column_name, 100 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER2' column_name, 101 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER3' column_name, 102 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER4' column_name, 103 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER5' column_name, 104 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER6' column_name, 105 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER7' column_name, 106 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER8' column_name, 107 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER9' column_name, 108 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_NUMBER10' column_name, 109 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 110 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'VENDOR_NUMBER' column_name, 111 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'FIRST_PTY_REG_NUMBER' column_name, 112 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'THIRD_PTY_REG_NUMBER' column_name, 113 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'FINAL_DISCHARGE_LOC_CODE' column_name, 114 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'UNIT_OF_MEASURE' column_name, 115 fbdi_position from dual
    union all select 'POR_REQ_LINES' object_code, 'SECONDARY_UNIT_OF_MEASURE' column_name, 116 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POZ_SUPPLIERS' object_code, 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'VENDOR_NAME' column_name, 2 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'VENDOR_NAME_NEW' column_name, 3 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'SEGMENT1' column_name, 4 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'VENDOR_NAME_ALT' column_name, 5 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ORGANIZATION_TYPE_LOOKUP_CODE' column_name, 6 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'VENDOR_TYPE_LOOKUP_CODE' column_name, 7 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'END_DATE_ACTIVE' column_name, 8 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'BUSINESS_RELATIONSHIP' column_name, 9 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PARENT_SUPPLIER_NAME' column_name, 10 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ALIAS' column_name, 11 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'DUNS_NUMBER' column_name, 12 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ONE_TIME_FLAG' column_name, 13 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'CUSTOMER_NUM' column_name, 14 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'STANDARD_INDUSTRY_CLASS' column_name, 15 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'NI_NUMBER' column_name, 16 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'CORPORATE_WEBSITE' column_name, 17 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'CHIEF_EXECUTIVE_TITLE' column_name, 18 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'CHIEF_EXECUTIVE_NAME' column_name, 19 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'BC_NOT_APPLICABLE_FLAG' column_name, 20 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'TAX_COUNTRY_CODE' column_name, 21 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'NUM_1099' column_name, 22 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'FEDERAL_REPORTABLE_FLAG' column_name, 23 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'TYPE_1099' column_name, 24 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'STATE_REPORTABLE_FLAG' column_name, 25 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'TAX_REPORTING_NAME' column_name, 26 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'NAME_CONTROL' column_name, 27 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'TAX_VERIFICATION_DATE' column_name, 28 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ALLOW_AWT_FLAG' column_name, 29 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'AWT_GROUP_NAME' column_name, 30 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'VAT_CODE' column_name, 31 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'VAT_REGISTRATION_NUM' column_name, 32 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'AUTO_TAX_CALC_OVERRIDE' column_name, 33 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PAYMENT_METHOD_LOOKUP_CODE' column_name, 34 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'DELIVERY_CHANNEL_CODE' column_name, 35 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'BANK_INSTRUCTION1_CODE' column_name, 36 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'BANK_INSTRUCTION2_CODE' column_name, 37 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'BANK_INSTRUCTION_DETAILS' column_name, 38 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'SETTLEMENT_PRIORITY' column_name, 39 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PAYMENT_TEXT_MESSAGE1' column_name, 40 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PAYMENT_TEXT_MESSAGE2' column_name, 41 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PAYMENT_TEXT_MESSAGE3' column_name, 42 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'IBY_BANK_CHARGE_BEARER' column_name, 43 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PAYMENT_REASON_CODE' column_name, 44 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PAYMENT_REASON_COMMENTS' column_name, 45 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PAYMENT_FORMAT_CODE' column_name, 46 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 47 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE1' column_name, 48 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE2' column_name, 49 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE3' column_name, 50 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE4' column_name, 51 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE5' column_name, 52 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE6' column_name, 53 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE7' column_name, 54 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE8' column_name, 55 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE9' column_name, 56 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE10' column_name, 57 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE11' column_name, 58 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE12' column_name, 59 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE13' column_name, 60 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE14' column_name, 61 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE15' column_name, 62 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE16' column_name, 63 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE17' column_name, 64 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE18' column_name, 65 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE19' column_name, 66 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE20' column_name, 67 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE1' column_name, 68 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE2' column_name, 69 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE3' column_name, 70 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE4' column_name, 71 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE5' column_name, 72 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE6' column_name, 73 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE7' column_name, 74 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE8' column_name, 75 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE9' column_name, 76 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_DATE10' column_name, 77 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 78 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 79 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 80 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 81 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 82 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 83 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 84 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 85 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 86 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 87 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER1' column_name, 88 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER2' column_name, 89 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER3' column_name, 90 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER4' column_name, 91 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER5' column_name, 92 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER6' column_name, 93 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER7' column_name, 94 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER8' column_name, 95 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER9' column_name, 96 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'ATTRIBUTE_NUMBER10' column_name, 97 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 98 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE1' column_name, 99 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE2' column_name, 100 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE3' column_name, 101 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE4' column_name, 102 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE5' column_name, 103 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE6' column_name, 104 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE7' column_name, 105 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE8' column_name, 106 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE9' column_name, 107 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE10' column_name, 108 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE11' column_name, 109 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE12' column_name, 110 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE13' column_name, 111 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE14' column_name, 112 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE15' column_name, 113 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE16' column_name, 114 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE17' column_name, 115 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE18' column_name, 116 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE19' column_name, 117 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE20' column_name, 118 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE1' column_name, 119 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE2' column_name, 120 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE3' column_name, 121 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE4' column_name, 122 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE5' column_name, 123 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE6' column_name, 124 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE7' column_name, 125 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE8' column_name, 126 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE9' column_name, 127 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_DATE10' column_name, 128 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP1' column_name, 129 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP2' column_name, 130 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP3' column_name, 131 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP4' column_name, 132 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP5' column_name, 133 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP6' column_name, 134 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP7' column_name, 135 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP8' column_name, 136 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP9' column_name, 137 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP10' column_name, 138 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 139 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 140 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 141 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 142 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 143 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER6' column_name, 144 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER7' column_name, 145 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER8' column_name, 146 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER9' column_name, 147 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'GLOBAL_ATTRIBUTE_NUMBER10' column_name, 148 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'PARTY_NUMBER' column_name, 149 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'SERVICE_LEVEL_CODE' column_name, 150 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'EXCLUSIVE_PAYMENT_FLAG' column_name, 151 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'REMIT_ADVICE_DELIVERY_METHOD' column_name, 152 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'REMIT_ADVICE_EMAIL' column_name, 153 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'REMIT_ADVICE_FAX' column_name, 154 fbdi_position from dual
    union all select 'POZ_SUPPLIERS' object_code, 'DATAFOX_COMPANY_ID' column_name, 155 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POZ_SUP_ADDR' object_code, 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'VENDOR_NAME' column_name, 2 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PARTY_SITE_NAME' column_name, 3 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PARTY_SITE_NAME_NEW' column_name, 4 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'COUNTRY' column_name, 5 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDRESS_LINE1' column_name, 6 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDRESS_LINE2' column_name, 7 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDRESS_LINE3' column_name, 8 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDRESS_LINE4' column_name, 9 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDRESS_LINES_PHONETIC' column_name, 10 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDR_ELEMENT_ATTRIBUTE1' column_name, 11 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDR_ELEMENT_ATTRIBUTE2' column_name, 12 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDR_ELEMENT_ATTRIBUTE3' column_name, 13 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDR_ELEMENT_ATTRIBUTE4' column_name, 14 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDR_ELEMENT_ATTRIBUTE5' column_name, 15 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'BUILDING' column_name, 16 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'FLOOR_NUMBER' column_name, 17 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'CITY' column_name, 18 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'STATE' column_name, 19 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PROVINCE' column_name, 20 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'COUNTY' column_name, 21 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'POSTAL_CODE' column_name, 22 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'POSTAL_PLUS4_CODE' column_name, 23 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ADDRESSEE' column_name, 24 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'GLOBAL_LOCATION_NUMBER' column_name, 25 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PARTY_SITE_LANGUAGE' column_name, 26 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'INACTIVE_DATE' column_name, 27 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PHONE_COUNTRY_CODE' column_name, 28 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PHONE_AREA_CODE' column_name, 29 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PHONE' column_name, 30 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PHONE_EXTENSION' column_name, 31 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'FAX_COUNTRY_CODE' column_name, 32 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'FAX_AREA_CODE' column_name, 33 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'FAX' column_name, 34 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'RFQ_OR_BIDDING_PURPOSE_FLAG' column_name, 35 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ORDERING_PURPOSE_FLAG' column_name, 36 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'REMIT_TO_PURPOSE_FLAG' column_name, 37 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_CATEGORY' column_name, 38 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE1' column_name, 39 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE2' column_name, 40 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE3' column_name, 41 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE4' column_name, 42 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE5' column_name, 43 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE6' column_name, 44 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE7' column_name, 45 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE8' column_name, 46 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE9' column_name, 47 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE10' column_name, 48 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE11' column_name, 49 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE12' column_name, 50 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE13' column_name, 51 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE14' column_name, 52 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE15' column_name, 53 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE16' column_name, 54 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE17' column_name, 55 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE18' column_name, 56 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE19' column_name, 57 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE20' column_name, 58 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE21' column_name, 59 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE22' column_name, 60 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE23' column_name, 61 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE24' column_name, 62 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE25' column_name, 63 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE26' column_name, 64 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE27' column_name, 65 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE28' column_name, 66 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE29' column_name, 67 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE30' column_name, 68 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER1' column_name, 69 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER2' column_name, 70 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER3' column_name, 71 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER4' column_name, 72 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER5' column_name, 73 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER6' column_name, 74 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER7' column_name, 75 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER8' column_name, 76 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER9' column_name, 77 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER10' column_name, 78 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER11' column_name, 79 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_NUMBER12' column_name, 80 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE1' column_name, 81 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE2' column_name, 82 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE3' column_name, 83 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE4' column_name, 84 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE5' column_name, 85 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE6' column_name, 86 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE7' column_name, 87 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE8' column_name, 88 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE9' column_name, 89 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE10' column_name, 90 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE11' column_name, 91 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'ATTRIBUTE_DATE12' column_name, 92 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'EMAIL_ADDRESS' column_name, 93 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'DELIVERY_CHANNEL_CODE' column_name, 94 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'BANK_INSTRUCTION1_CODE' column_name, 95 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'BANK_INSTRUCTION2_CODE' column_name, 96 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'BANK_INSTRUCTION_DETAILS' column_name, 97 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'SETTLEMENT_PRIORITY' column_name, 98 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PAYMENT_TEXT_MESSAGE1' column_name, 99 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PAYMENT_TEXT_MESSAGE2' column_name, 100 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PAYMENT_TEXT_MESSAGE3' column_name, 101 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'SERVICE_LEVEL_CODE' column_name, 102 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'EXCLUSIVE_PAYMENT_FLAG' column_name, 103 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'IBY_BANK_CHARGE_BEARER' column_name, 104 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PAYMENT_REASON_CODE' column_name, 105 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'PAYMENT_REASON_COMMENTS' column_name, 106 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'REMIT_ADVICE_DELIVERY_METHOD' column_name, 107 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'REMIT_ADVICE_EMAIL' column_name, 108 fbdi_position from dual
    union all select 'POZ_SUP_ADDR' object_code, 'REMIT_ADVICE_FAX' column_name, 109 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POZ_SUP_CONTACTS' object_code, 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'VENDOR_NAME' column_name, 2 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'PREFIX' column_name, 3 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'FIRST_NAME' column_name, 4 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'FIRST_NAME_NEW' column_name, 5 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'MIDDLE_NAME' column_name, 6 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'LAST_NAME' column_name, 7 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'LAST_NAME_NEW' column_name, 8 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'TITLE' column_name, 9 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'PRIMARY_ADMIN_CONTACT' column_name, 10 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'EMAIL_ADDRESS' column_name, 11 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'EMAIL_ADDRESS_NEW' column_name, 12 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'PHONE_COUNTRY_CODE' column_name, 13 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'AREA_CODE' column_name, 14 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'PHONE' column_name, 15 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'PHONE_EXTENSION' column_name, 16 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'FAX_COUNTRY_CODE' column_name, 17 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'FAX_AREA_CODE' column_name, 18 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'FAX' column_name, 19 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'MOBILE_COUNTRY_CODE' column_name, 20 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'MOBILE_AREA_CODE' column_name, 21 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'MOBILE' column_name, 22 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'INACTIVE_DATE' column_name, 23 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 24 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE1' column_name, 25 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE2' column_name, 26 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE3' column_name, 27 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE4' column_name, 28 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE5' column_name, 29 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE6' column_name, 30 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE7' column_name, 31 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE8' column_name, 32 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE9' column_name, 33 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE10' column_name, 34 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE11' column_name, 35 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE12' column_name, 36 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE13' column_name, 37 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE14' column_name, 38 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE15' column_name, 39 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE16' column_name, 40 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE17' column_name, 41 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE18' column_name, 42 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE19' column_name, 43 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE20' column_name, 44 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE21' column_name, 45 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE22' column_name, 46 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE23' column_name, 47 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE24' column_name, 48 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE25' column_name, 49 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE26' column_name, 50 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE27' column_name, 51 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE28' column_name, 52 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE29' column_name, 53 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE30' column_name, 54 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER1' column_name, 55 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER2' column_name, 56 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER3' column_name, 57 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER4' column_name, 58 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER5' column_name, 59 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER6' column_name, 60 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER7' column_name, 61 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER8' column_name, 62 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER9' column_name, 63 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER10' column_name, 64 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER11' column_name, 65 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_NUMBER12' column_name, 66 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE1' column_name, 67 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE2' column_name, 68 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE3' column_name, 69 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE4' column_name, 70 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE5' column_name, 71 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE6' column_name, 72 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE7' column_name, 73 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE8' column_name, 74 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE9' column_name, 75 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE10' column_name, 76 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE11' column_name, 77 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ATTRIBUTE_DATE12' column_name, 78 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'USER_ACCOUNT_ACTION' column_name, 79 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE1' column_name, 80 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE2' column_name, 81 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE3' column_name, 82 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE4' column_name, 83 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE5' column_name, 84 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE6' column_name, 85 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE7' column_name, 86 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE8' column_name, 87 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE9' column_name, 88 fbdi_position from dual
    union all select 'POZ_SUP_CONTACTS' object_code, 'ROLE10' column_name, 89 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POZ_SUP_SITE' object_code, 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'VENDOR_NAME' column_name, 2 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PROCUREMENT_BUSINESS_UNIT_NAME' column_name, 3 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PARTY_SITE_NAME' column_name, 4 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'VENDOR_SITE_CODE' column_name, 5 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'VENDOR_SITE_CODE_NEW' column_name, 6 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'INACTIVE_DATE' column_name, 7 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'RFQ_ONLY_SITE_FLAG' column_name, 8 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PURCHASING_SITE_FLAG' column_name, 9 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PCARD_SITE_FLAG' column_name, 10 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAY_SITE_FLAG' column_name, 11 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PRIMARY_PAY_SITE_FLAG' column_name, 12 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'TAX_REPORTING_SITE_FLAG' column_name, 13 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'VENDOR_SITE_CODE_ALT' column_name, 14 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'CUSTOMER_NUM' column_name, 15 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'B2B_COMM_METHOD_CODE' column_name, 16 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'B2B_SITE_CODE' column_name, 17 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'SUPPLIER_NOTIF_METHOD' column_name, 18 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'EMAIL_ADDRESS' column_name, 19 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'FAX_COUNTRY_CODE' column_name, 20 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'FAX_AREA_CODE' column_name, 21 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'FAX' column_name, 22 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'HOLD_FLAG' column_name, 23 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PURCHASING_HOLD_REASON' column_name, 24 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'CARRIER' column_name, 25 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'MODE_OF_TRANSPORT_CODE' column_name, 26 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'SERVICE_LEVEL_CODE' column_name, 27 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'FREIGHT_TERMS_LOOKUP_CODE' column_name, 28 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAY_ON_CODE' column_name, 29 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'FOB_LOOKUP_CODE' column_name, 30 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'COUNTRY_OF_ORIGIN_CODE' column_name, 31 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'BUYER_MANAGED_TRANSPORT_FLAG' column_name, 32 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAY_ON_USE_FLAG' column_name, 33 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'AGING_ONSET_POINT' column_name, 34 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'AGING_PERIOD_DAYS' column_name, 35 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'CONSUMPTION_ADVICE_FREQUENCY' column_name, 36 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'CONSUMPTION_ADVICE_SUMMARY' column_name, 37 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'DEFAULT_PAY_SITE_CODE' column_name, 38 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAY_ON_RECEIPT_SUMMARY_CODE' column_name, 39 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GAPLESS_INV_NUM_FLAG' column_name, 40 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'SELLING_COMPANY_IDENTIFIER' column_name, 41 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'CREATE_DEBIT_MEMO_FLAG' column_name, 42 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ENFORCE_SHIP_TO_LOCATION_CODE' column_name, 43 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'RECEIVING_ROUTING_ID' column_name, 44 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'QTY_RCV_TOLERANCE' column_name, 45 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'QTY_RCV_EXCEPTION_CODE' column_name, 46 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'DAYS_EARLY_RECEIPT_ALLOWED' column_name, 47 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'DAYS_LATE_RECEIPT_ALLOWED' column_name, 48 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' column_name, 49 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ALLOW_UNORDERED_RECEIPTS_FLAG' column_name, 50 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'RECEIPT_DAYS_EXCEPTION_CODE' column_name, 51 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'INVOICE_CURRENCY_CODE' column_name, 52 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'INVOICE_AMOUNT_LIMIT' column_name, 53 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'MATCH_OPTION' column_name, 54 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'MATCH_APPROVAL_LEVEL' column_name, 55 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_CURRENCY_CODE' column_name, 56 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_PRIORITY' column_name, 57 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAY_GROUP_LOOKUP_CODE' column_name, 58 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'TOLERANCE_NAME' column_name, 59 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'SERVICES_TOLERANCE' column_name, 60 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'HOLD_ALL_PAYMENTS_FLAG' column_name, 61 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'HOLD_UNMATCHED_INVOICES_FLAG' column_name, 62 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'HOLD_FUTURE_PAYMENTS_FLAG' column_name, 63 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'HOLD_BY' column_name, 64 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_HOLD_DATE' column_name, 65 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'HOLD_REASON' column_name, 66 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'TERMS_NAME' column_name, 67 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'TERMS_DATE_BASIS' column_name, 68 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAY_DATE_BASIS_LOOKUP_CODE' column_name, 69 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'BANK_CHARGE_DEDUCTION_TYPE' column_name, 70 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ALWAYS_TAKE_DISC_FLAG' column_name, 71 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'EXCLUDE_FREIGHT_FROM_DISCOUNT' column_name, 72 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'EXCLUDE_TAX_FROM_DISCOUNT' column_name, 73 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'AUTO_CALCULATE_INTEREST_FLAG' column_name, 74 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'VAT_CODE' column_name, 75 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'VAT_REGISTRATION_NUM' column_name, 76 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_METHOD_LOOKUP_CODE' column_name, 77 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'DELIVERY_CHANNEL_CODE' column_name, 78 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'BANK_INSTRUCTION1_CODE' column_name, 79 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'BANK_INSTRUCTION2_CODE' column_name, 80 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'BANK_INSTRUCTION_DETAILS' column_name, 81 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'SETTLEMENT_PRIORITY' column_name, 82 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_TEXT_MESSAGE1' column_name, 83 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_TEXT_MESSAGE2' column_name, 84 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_TEXT_MESSAGE3' column_name, 85 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'IBY_BANK_CHARGE_BEARER' column_name, 86 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_REASON_CODE' column_name, 87 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYMENT_REASON_COMMENTS' column_name, 88 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'REMIT_ADVICE_DELIVERY_METHOD' column_name, 89 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'REMITTANCE_EMAIL' column_name, 90 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'REMITTANCE_FAX' column_name, 91 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_CATEGORY' column_name, 92 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE1' column_name, 93 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE2' column_name, 94 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE3' column_name, 95 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE4' column_name, 96 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE5' column_name, 97 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE6' column_name, 98 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE7' column_name, 99 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE8' column_name, 100 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE9' column_name, 101 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE10' column_name, 102 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE11' column_name, 103 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE12' column_name, 104 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE13' column_name, 105 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE14' column_name, 106 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE15' column_name, 107 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE16' column_name, 108 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE17' column_name, 109 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE18' column_name, 110 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE19' column_name, 111 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE20' column_name, 112 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE1' column_name, 113 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE2' column_name, 114 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE3' column_name, 115 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE4' column_name, 116 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE5' column_name, 117 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE6' column_name, 118 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE7' column_name, 119 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE8' column_name, 120 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE9' column_name, 121 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_DATE10' column_name, 122 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 123 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 124 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 125 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 126 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 127 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 128 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 129 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 130 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 131 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 132 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER1' column_name, 133 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER2' column_name, 134 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER3' column_name, 135 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER4' column_name, 136 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER5' column_name, 137 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER6' column_name, 138 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER7' column_name, 139 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER8' column_name, 140 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER9' column_name, 141 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'ATTRIBUTE_NUMBER10' column_name, 142 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 143 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE1' column_name, 144 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE2' column_name, 145 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE3' column_name, 146 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE4' column_name, 147 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE5' column_name, 148 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE6' column_name, 149 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE7' column_name, 150 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE8' column_name, 151 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE9' column_name, 152 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE10' column_name, 153 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE11' column_name, 154 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE12' column_name, 155 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE13' column_name, 156 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE14' column_name, 157 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE15' column_name, 158 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE16' column_name, 159 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE17' column_name, 160 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE18' column_name, 161 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE19' column_name, 162 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE20' column_name, 163 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE1' column_name, 164 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE2' column_name, 165 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE3' column_name, 166 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE4' column_name, 167 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE5' column_name, 168 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE6' column_name, 169 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE7' column_name, 170 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE8' column_name, 171 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE9' column_name, 172 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_DATE10' column_name, 173 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP1' column_name, 174 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP2' column_name, 175 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP3' column_name, 176 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP4' column_name, 177 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP5' column_name, 178 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP6' column_name, 179 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP7' column_name, 180 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP8' column_name, 181 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP9' column_name, 182 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_TIMESTAMP10' column_name, 183 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 184 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 185 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 186 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 187 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 188 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER6' column_name, 189 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER7' column_name, 190 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER8' column_name, 191 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER9' column_name, 192 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'GLOBAL_ATTRIBUTE_NUMBER10' column_name, 193 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PO_ACK_REQD_CODE' column_name, 194 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PO_ACK_REQD_DAYS' column_name, 195 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'INVOICE_CHANNEL' column_name, 196 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'PAYEE_SERVICE_LEVEL_CODE' column_name, 197 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'EXCLUSIVE_PAYMENT_FLAG' column_name, 198 fbdi_position from dual
    union all select 'POZ_SUP_SITE' object_code, 'OVERRIDE_B2B_COMM_CODE' column_name, 199 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'POZ_SUP_SITE_ASSN' object_code, 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'VENDOR_NAME' column_name, 2 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'VENDOR_SITE_CODE' column_name, 3 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'PROCUREMENT_BUSINESS_UNIT_NAME' column_name, 4 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'BUSINESS_UNIT_NAME' column_name, 5 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'BILL_TO_BU_NAME' column_name, 6 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'SHIP_TO_LOCATION_CODE' column_name, 7 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'BILL_TO_LOCATION_CODE' column_name, 8 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'ALLOW_AWT_FLAG' column_name, 9 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'AWT_GROUP_NAME' column_name, 10 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'ACCTS_PAY_CONCAT_SEGMENTS' column_name, 11 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'PREPAY_CONCAT_SEGMENTS' column_name, 12 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'FUTURE_DATED_CONCAT_SEGMENTS' column_name, 13 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'DISTRIBUTION_SET_NAME' column_name, 14 fbdi_position from dual
    union all select 'POZ_SUP_SITE_ASSN' object_code, 'INACTIVE_DATE' column_name, 15 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PO_DISTS_INT' object_code, 'INTERFACE_DISTRIBUTION_KEY' column_name, 1 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'INTERFACE_LINE_LOCATION_KEY' column_name, 2 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'DISTRIBUTION_NUM' column_name, 3 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'DELIVER_TO_LOCATION' column_name, 4 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'DELIVER_TO_PERSON_FULL_NAME' column_name, 5 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'DESTINATION_SUBINVENTORY' column_name, 6 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'AMOUNT_ORDERED' column_name, 7 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'QUANTITY_ORDERED' column_name, 8 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT1' column_name, 9 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT2' column_name, 10 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT3' column_name, 11 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT4' column_name, 12 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT5' column_name, 13 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT6' column_name, 14 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT7' column_name, 15 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT8' column_name, 16 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT9' column_name, 17 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT10' column_name, 18 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT11' column_name, 19 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT12' column_name, 20 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT13' column_name, 21 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT14' column_name, 22 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT15' column_name, 23 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT16' column_name, 24 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT17' column_name, 25 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT18' column_name, 26 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT19' column_name, 27 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT20' column_name, 28 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT21' column_name, 29 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT22' column_name, 30 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT23' column_name, 31 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT24' column_name, 32 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT25' column_name, 33 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT26' column_name, 34 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT27' column_name, 35 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT28' column_name, 36 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT29' column_name, 37 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'CHARGE_ACCOUNT_SEGMENT30' column_name, 38 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'DESTINATION_CONTEXT' column_name, 39 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PROJECT' column_name, 40 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'TASK' column_name, 41 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_EXPENDITURE_ITEM_DATE' column_name, 42 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'EXPENDITURE' column_name, 43 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'EXPENDITURE_ORGANIZATION' column_name, 44 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_BILLABLE_FLAG' column_name, 45 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_CAPITALIZABLE_FLAG' column_name, 46 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_WORK_TYPE' column_name, 47 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE1' column_name, 48 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE2' column_name, 49 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE3' column_name, 50 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE4' column_name, 51 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE5' column_name, 52 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE6' column_name, 53 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE7' column_name, 54 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE8' column_name, 55 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE9' column_name, 56 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_RESERVED_ATTRIBUTE10' column_name, 57 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE1' column_name, 58 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE2' column_name, 59 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE3' column_name, 60 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE4' column_name, 61 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE5' column_name, 62 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE6' column_name, 63 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE7' column_name, 64 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE8' column_name, 65 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE9' column_name, 66 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_USER_DEF_ATTRIBUTE10' column_name, 67 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'RATE' column_name, 68 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'RATE_DATE' column_name, 69 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_CATEGORY' column_name, 70 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE1' column_name, 71 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE2' column_name, 72 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE3' column_name, 73 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE4' column_name, 74 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE5' column_name, 75 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE6' column_name, 76 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE7' column_name, 77 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE8' column_name, 78 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE9' column_name, 79 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE10' column_name, 80 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE11' column_name, 81 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE12' column_name, 82 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE13' column_name, 83 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE14' column_name, 84 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE15' column_name, 85 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE16' column_name, 86 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE17' column_name, 87 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE18' column_name, 88 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE19' column_name, 89 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE20' column_name, 90 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE1' column_name, 91 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE2' column_name, 92 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE3' column_name, 93 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE4' column_name, 94 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE5' column_name, 95 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE6' column_name, 96 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE7' column_name, 97 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE8' column_name, 98 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE9' column_name, 99 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_DATE10' column_name, 100 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER1' column_name, 101 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER2' column_name, 102 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER3' column_name, 103 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER4' column_name, 104 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER5' column_name, 105 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER6' column_name, 106 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER7' column_name, 107 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER8' column_name, 108 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER9' column_name, 109 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_NUMBER10' column_name, 110 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 111 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 112 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 113 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 114 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 115 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 116 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 117 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 118 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 119 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 120 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'DELIVER_TO_PERSON_EMAIL_ADDR' column_name, 121 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'BUDGET_DATE' column_name, 122 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_CONTRACT_NUMBER' column_name, 123 fbdi_position from dual
    union all select 'PO_DISTS_INT' object_code, 'PJC_FUNDING_SOURCE' column_name, 124 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PO_HEADERS_INT' object_code, 'INTERFACE_HEADER_KEY' column_name, 1 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ACTION' column_name, 2 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'BATCH_ID' column_name, 3 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'INTERFACE_SOURCE_CODE' column_name, 4 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'APPROVAL_ACTION' column_name, 5 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'DOCUMENT_NUM' column_name, 6 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'DOCUMENT_TYPE_CODE' column_name, 7 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'STYLE_DISPLAY_NAME' column_name, 8 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'PRC_BU_NAME' column_name, 9 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'REQ_BU_NAME' column_name, 10 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'SOLDTO_LE_NAME' column_name, 11 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'BILLTO_BU_NAME' column_name, 12 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'AGENT_NAME' column_name, 13 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'CURRENCY_CODE' column_name, 14 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'RATE' column_name, 15 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'RATE_TYPE' column_name, 16 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'RATE_DATE' column_name, 17 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'COMMENTS' column_name, 18 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'BILL_TO_LOCATION' column_name, 19 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'SHIP_TO_LOCATION' column_name, 20 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'VENDOR_NAME' column_name, 21 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'VENDOR_NUM' column_name, 22 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'VENDOR_SITE_CODE' column_name, 23 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'VENDOR_CONTACT' column_name, 24 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'VENDOR_DOC_NUM' column_name, 25 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'FOB' column_name, 26 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'FREIGHT_CARRIER' column_name, 27 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'FREIGHT_TERMS' column_name, 28 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'PAY_ON_CODE' column_name, 29 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'PAYMENT_TERMS' column_name, 30 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ORIGINATOR_ROLE' column_name, 31 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'CHANGE_ORDER_DESC' column_name, 32 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ACCEPTANCE_REQUIRED_FLAG' column_name, 33 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ACCEPTANCE_WITHIN_DAYS' column_name, 34 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'SUPPLIER_NOTIF_METHOD' column_name, 35 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'FAX' column_name, 36 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'EMAIL_ADDRESS' column_name, 37 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'CONFIRMING_ORDER_FLAG' column_name, 38 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'NOTE_TO_VENDOR' column_name, 39 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'NOTE_TO_RECEIVER' column_name, 40 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'DEFAULT_TAXATION_COUNTRY' column_name, 41 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'TAX_DOCUMENT_SUBTYPE' column_name, 42 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_CATEGORY' column_name, 43 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE1' column_name, 44 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE2' column_name, 45 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE3' column_name, 46 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE4' column_name, 47 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE5' column_name, 48 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE6' column_name, 49 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE7' column_name, 50 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE8' column_name, 51 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE9' column_name, 52 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE10' column_name, 53 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE11' column_name, 54 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE12' column_name, 55 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE13' column_name, 56 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE14' column_name, 57 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE15' column_name, 58 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE16' column_name, 59 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE17' column_name, 60 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE18' column_name, 61 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE19' column_name, 62 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE20' column_name, 63 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE1' column_name, 64 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE2' column_name, 65 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE3' column_name, 66 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE4' column_name, 67 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE5' column_name, 68 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE6' column_name, 69 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE7' column_name, 70 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE8' column_name, 71 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE9' column_name, 72 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_DATE10' column_name, 73 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER1' column_name, 74 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER2' column_name, 75 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER3' column_name, 76 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER4' column_name, 77 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER5' column_name, 78 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER6' column_name, 79 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER7' column_name, 80 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER8' column_name, 81 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER9' column_name, 82 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_NUMBER10' column_name, 83 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 84 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 85 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 86 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 87 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 88 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 89 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 90 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 91 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 92 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 93 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'AGENT_EMAIL_ADDRESS' column_name, 94 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'MODE_OF_TRANSPORT' column_name, 95 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'SERVICE_LEVEL' column_name, 96 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'FIRST_PTY_REG_NUM' column_name, 97 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'THIRD_PTY_REG_NUM' column_name, 98 fbdi_position from dual
    union all select 'PO_HEADERS_INT' object_code, 'BUYER_MANAGED_TRANSPORT_FLAG' column_name, 99 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PO_LINES_INT' object_code, 'INTERFACE_LINE_KEY' column_name, 1 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'INTERFACE_HEADER_KEY' column_name, 2 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ACTION' column_name, 3 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_NUM' column_name, 4 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_TYPE' column_name, 5 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM' column_name, 6 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_DESCRIPTION' column_name, 7 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_REVISION' column_name, 8 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'CATEGORY' column_name, 9 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'AMOUNT' column_name, 10 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'QUANTITY' column_name, 11 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'UNIT_OF_MEASURE' column_name, 12 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'UNIT_PRICE' column_name, 13 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'SECONDARY_QUANTITY' column_name, 14 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'SECONDARY_UNIT_OF_MEASURE' column_name, 15 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'VENDOR_PRODUCT_NUM' column_name, 16 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'NEGOTIATED_BY_PREPARER_FLAG' column_name, 17 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'HAZARD_CLASS' column_name, 18 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'UN_NUMBER' column_name, 19 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'NOTE_TO_VENDOR' column_name, 20 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'NOTE_TO_RECEIVER' column_name, 21 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE_CATEGORY_LINES' column_name, 22 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE1' column_name, 23 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE2' column_name, 24 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE3' column_name, 25 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE4' column_name, 26 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE5' column_name, 27 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE6' column_name, 28 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE7' column_name, 29 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE8' column_name, 30 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE9' column_name, 31 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE10' column_name, 32 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE11' column_name, 33 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE12' column_name, 34 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE13' column_name, 35 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE14' column_name, 36 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'LINE_ATTRIBUTE15' column_name, 37 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE16' column_name, 38 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE17' column_name, 39 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE18' column_name, 40 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE19' column_name, 41 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE20' column_name, 42 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE1' column_name, 43 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE2' column_name, 44 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE3' column_name, 45 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE4' column_name, 46 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE5' column_name, 47 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE6' column_name, 48 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE7' column_name, 49 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE8' column_name, 50 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE9' column_name, 51 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_DATE10' column_name, 52 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER1' column_name, 53 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER2' column_name, 54 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER3' column_name, 55 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER4' column_name, 56 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER5' column_name, 57 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER6' column_name, 58 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER7' column_name, 59 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER8' column_name, 60 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER9' column_name, 61 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_NUMBER10' column_name, 62 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 63 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 64 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 65 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 66 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 67 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 68 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 69 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 70 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 71 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 72 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'UNIT_WEIGHT' column_name, 73 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'WEIGHT_UOM_CODE' column_name, 74 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'WEIGHT_UNIT_OF_MEASURE' column_name, 75 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'UNIT_VOLUME' column_name, 76 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'VOLUME_UOM_CODE' column_name, 77 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'VOLUME_UNIT_OF_MEASURE' column_name, 78 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'TEMPLATE_NAME' column_name, 79 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE_CATEGORY' column_name, 80 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE1' column_name, 81 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE2' column_name, 82 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE3' column_name, 83 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE4' column_name, 84 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE5' column_name, 85 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE6' column_name, 86 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE7' column_name, 87 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE8' column_name, 88 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE9' column_name, 89 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE10' column_name, 90 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE11' column_name, 91 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE12' column_name, 92 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE13' column_name, 93 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE14' column_name, 94 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'ITEM_ATTRIBUTE15' column_name, 95 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'SOURCE_AGREEMENT_PRC_BU_NAME' column_name, 96 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'SOURCE_AGREEMENT' column_name, 97 fbdi_position from dual
    union all select 'PO_LINES_INT' object_code, 'SOURCE_AGREEMENT_LINE' column_name, 98 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PO_LINE_LOCS_INT' object_code, 'INTERFACE_LINE_LOCATION_KEY' column_name, 1 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'INTERFACE_LINE_KEY' column_name, 2 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'SHIPMENT_NUM' column_name, 3 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'SHIP_TO_LOCATION' column_name, 4 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'SHIP_TO_ORGANIZATION_CODE' column_name, 5 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'AMOUNT' column_name, 6 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'QUANTITY' column_name, 7 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'NEED_BY_DATE' column_name, 8 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'PROMISED_DATE' column_name, 9 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'SECONDARY_QUANTITY' column_name, 10 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'SECONDARY_UNIT_OF_MEASURE' column_name, 11 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'DESTINATION_TYPE_CODE' column_name, 12 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ACCRUE_ON_RECEIPT_FLAG' column_name, 13 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' column_name, 14 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ASSESSABLE_VALUE' column_name, 15 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'DAYS_EARLY_RECEIPT_ALLOWED' column_name, 16 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'DAYS_LATE_RECEIPT_ALLOWED' column_name, 17 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ENFORCE_SHIP_TO_LOCATION_CODE' column_name, 18 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'INSPECTION_REQUIRED_FLAG' column_name, 19 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'RECEIPT_REQUIRED_FLAG' column_name, 20 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'INVOICE_CLOSE_TOLERANCE' column_name, 21 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'RECEIVE_CLOSE_TOLERANCE' column_name, 22 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'QTY_RCV_TOLERANCE' column_name, 23 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'QTY_RCV_EXCEPTION_CODE' column_name, 24 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'RECEIPT_DAYS_EXCEPTION_CODE' column_name, 25 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'RECEIVING_ROUTING' column_name, 26 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'NOTE_TO_RECEIVER' column_name, 27 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'INPUT_TAX_CLASSIFICATION_CODE' column_name, 28 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'LINE_INTENDED_USE' column_name, 29 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'PRODUCT_CATEGORY' column_name, 30 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'PRODUCT_FISC_CLASSIFICATION' column_name, 31 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'PRODUCT_TYPE' column_name, 32 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'TRX_BUSINESS_CATEGORY' column_name, 33 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'USER_DEFINED_FISC_CLASS' column_name, 34 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_CATEGORY' column_name, 35 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE1' column_name, 36 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE2' column_name, 37 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE3' column_name, 38 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE4' column_name, 39 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE5' column_name, 40 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE6' column_name, 41 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE7' column_name, 42 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE8' column_name, 43 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE9' column_name, 44 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE10' column_name, 45 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE11' column_name, 46 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE12' column_name, 47 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE13' column_name, 48 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE14' column_name, 49 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE15' column_name, 50 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE16' column_name, 51 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE17' column_name, 52 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE18' column_name, 53 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE19' column_name, 54 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE20' column_name, 55 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE1' column_name, 56 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE2' column_name, 57 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE3' column_name, 58 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE4' column_name, 59 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE5' column_name, 60 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE6' column_name, 61 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE7' column_name, 62 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE8' column_name, 63 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE9' column_name, 64 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_DATE10' column_name, 65 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER1' column_name, 66 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER2' column_name, 67 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER3' column_name, 68 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER4' column_name, 69 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER5' column_name, 70 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER6' column_name, 71 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER7' column_name, 72 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER8' column_name, 73 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER9' column_name, 74 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_NUMBER10' column_name, 75 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP1' column_name, 76 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP2' column_name, 77 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP3' column_name, 78 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP4' column_name, 79 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP5' column_name, 80 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP6' column_name, 81 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP7' column_name, 82 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP8' column_name, 83 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP9' column_name, 84 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'ATTRIBUTE_TIMESTAMP10' column_name, 85 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'FREIGHT_CARRIER' column_name, 86 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'MODE_OF_TRANSPORT' column_name, 87 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'SERVICE_LEVEL' column_name, 88 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'FINAL_DISCHARGE_LOCATION_CODE' column_name, 89 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'REQUESTED_SHIP_DATE' column_name, 90 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'PROMISED_SHIP_DATE' column_name, 91 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'REQUESTED_DELIVERY_DATE' column_name, 92 fbdi_position from dual
    union all select 'PO_LINE_LOCS_INT' object_code, 'PROMISED_DELIVERY_DATE' column_name, 93 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'PRJ_BUDGET' object_code, 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'FINANCIAL_PLAN_TYPE' column_name, 2 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PROJECT_NUMBER' column_name, 3 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PROJECT_NAME' column_name, 4 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'TASK_NAME' column_name, 5 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'TASK_NUMBER' column_name, 6 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PLAN_VERSION_NAME' column_name, 7 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PLAN_VERSION_DESCRIPTION' column_name, 8 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PLAN_VERSION_STATUS' column_name, 9 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'RESOURCE_NAME' column_name, 10 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PERIOD_NAME' column_name, 11 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PLANNING_CURRENCY' column_name, 12 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'TOTAL_QUANTITY' column_name, 13 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'TOTAL_TC_RAW_COST' column_name, 14 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'TOTAL_TC_REVENUE' column_name, 15 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'SRC_BUDGET_LINE_REFERENCE' column_name, 16 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'FUNDING_SOURCE_NUMBER' column_name, 17 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'FUNDING_SOURCE_NAME' column_name, 18 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PC_RAW_COST' column_name, 19 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PC_REVENUE' column_name, 20 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PFC_RAW_COST' column_name, 21 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PFC_REVENUE' column_name, 22 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'TOTAL_TC_BRDND_COST' column_name, 23 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PC_BRDND_COST' column_name, 24 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PFC_BRDND_COST' column_name, 25 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'LINE_TYPE' column_name, 26 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PLANNING_START_DATE' column_name, 27 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PLANNING_END_DATE' column_name, 28 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE_CATEGORY' column_name, 30 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE1' column_name, 31 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE2' column_name, 32 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE3' column_name, 33 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE4' column_name, 34 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE5' column_name, 35 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE6' column_name, 36 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE7' column_name, 37 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE8' column_name, 38 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE9' column_name, 39 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE10' column_name, 40 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE11' column_name, 41 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE12' column_name, 42 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE13' column_name, 43 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE14' column_name, 44 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE15' column_name, 45 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE16' column_name, 46 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE17' column_name, 47 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE18' column_name, 48 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE19' column_name, 49 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE20' column_name, 50 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE21' column_name, 51 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE22' column_name, 52 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE23' column_name, 53 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE24' column_name, 54 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE25' column_name, 55 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE26' column_name, 56 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE27' column_name, 57 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE28' column_name, 58 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE29' column_name, 59 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'ATTRIBUTE30' column_name, 60 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PLAN_VERSION_NUMBER' column_name, 61 fbdi_position from dual
    union all select 'PRJ_BUDGET' object_code, 'PROCESSING_MODE' column_name, 62 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'RA_DISTS' object_code, 'ORG_ID' column_name, 1 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ACCOUNT_CLASS' column_name, 2 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'AMOUNT' column_name, 3 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'PERCENT' column_name, 4 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ACCTD_AMOUNT' column_name, 5 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_CONTEXT' column_name, 6 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE1' column_name, 7 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE2' column_name, 8 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE3' column_name, 9 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE4' column_name, 10 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE5' column_name, 11 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE6' column_name, 12 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE7' column_name, 13 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE8' column_name, 14 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE9' column_name, 15 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE10' column_name, 16 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE11' column_name, 17 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE12' column_name, 18 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE13' column_name, 19 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE14' column_name, 20 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'INTERFACE_LINE_ATTRIBUTE15' column_name, 21 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT1' column_name, 22 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT2' column_name, 23 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT3' column_name, 24 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT4' column_name, 25 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT5' column_name, 26 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT6' column_name, 27 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT7' column_name, 28 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT8' column_name, 29 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT9' column_name, 30 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT10' column_name, 31 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT11' column_name, 32 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT12' column_name, 33 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT13' column_name, 34 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT14' column_name, 35 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT15' column_name, 36 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT16' column_name, 37 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT17' column_name, 38 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT18' column_name, 39 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT19' column_name, 40 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT20' column_name, 41 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT21' column_name, 42 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT22' column_name, 43 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT23' column_name, 44 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT24' column_name, 45 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT25' column_name, 46 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT26' column_name, 47 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT27' column_name, 48 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT28' column_name, 49 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT29' column_name, 50 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'SEGMENT30' column_name, 51 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'COMMENTS' column_name, 52 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE_CATEGORY' column_name, 83 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE1' column_name, 84 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE2' column_name, 85 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE3' column_name, 86 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE4' column_name, 87 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE5' column_name, 88 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE6' column_name, 89 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE7' column_name, 90 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE8' column_name, 91 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE9' column_name, 92 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE10' column_name, 93 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE11' column_name, 94 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE12' column_name, 95 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE13' column_name, 96 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE14' column_name, 97 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'ATTRIBUTE15' column_name, 98 fbdi_position from dual
    union all select 'RA_DISTS' object_code, 'BU_NAME' column_name, 99 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

merge into "DMT_UPLOAD_DICT_TBL" t
using (
    select 'RA_LINES' object_code, 'ORG_ID' column_name, 1 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'BATCH_SOURCE_NAME' column_name, 2 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CUST_TRX_TYPE_NAME' column_name, 3 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TERM_NAME' column_name, 4 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TRX_DATE' column_name, 5 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'GL_DATE' column_name, 6 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TRX_NUMBER' column_name, 7 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_BILL_CUSTOMER_REF' column_name, 8 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_BILL_ADDRESS_REF' column_name, 9 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_BILL_CONTACT_REF' column_name, 10 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYS_SHIP_PARTY_REF' column_name, 11 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYS_SHIP_PARTY_SITE_REF' column_name, 12 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYS_SHIP_PTY_CONTACT_REF' column_name, 13 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_SHIP_CUSTOMER_REF' column_name, 14 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_SHIP_ADDRESS_REF' column_name, 15 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_SHIP_CONTACT_REF' column_name, 16 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYS_SOLD_PARTY_REF' column_name, 17 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_SOLD_CUSTOMER_REF' column_name, 18 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'BILL_CUSTOMER_ACCOUNT_NUMBER' column_name, 19 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'BILL_CUSTOMER_SITE_NUMBER' column_name, 20 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'BILL_CONTACT_PARTY_NUMBER' column_name, 21 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SHIP_CUSTOMER_ACCOUNT_NUMBER' column_name, 22 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SHIP_CUSTOMER_SITE_NUMBER' column_name, 23 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SHIP_CONTACT_PARTY_NUMBER' column_name, 24 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SOLD_CUSTOMER_ACCOUNT_NUMBER' column_name, 25 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINE_TYPE' column_name, 26 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'DESCRIPTION' column_name, 27 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CURRENCY_CODE' column_name, 28 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CONVERSION_TYPE' column_name, 29 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CONVERSION_DATE' column_name, 30 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CONVERSION_RATE' column_name, 31 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'AMOUNT' column_name, 32 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'QUANTITY' column_name, 33 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'QUANTITY_ORDERED' column_name, 34 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'UNIT_SELLING_PRICE' column_name, 35 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'UNIT_STANDARD_PRICE' column_name, 36 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_CONTEXT' column_name, 37 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE1' column_name, 38 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE2' column_name, 39 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE3' column_name, 40 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE4' column_name, 41 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE5' column_name, 42 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE6' column_name, 43 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE7' column_name, 44 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE8' column_name, 45 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE9' column_name, 46 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE10' column_name, 47 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE11' column_name, 48 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE12' column_name, 49 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE13' column_name, 50 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE14' column_name, 51 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERFACE_LINE_ATTRIBUTE15' column_name, 52 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PRIMARY_SALESREP_NUMBER' column_name, 53 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_CODE' column_name, 54 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LEGAL_ENTITY_IDENTIFIER' column_name, 55 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ACCTD_AMOUNT' column_name, 56 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SALES_ORDER' column_name, 57 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SALES_ORDER_DATE' column_name, 58 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SHIP_DATE_ACTUAL' column_name, 59 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'WAREHOUSE_CODE' column_name, 60 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'UOM_CODE' column_name, 61 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'UOM_NAME' column_name, 62 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INVOICING_RULE_NAME' column_name, 63 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ACCOUNTING_RULE_NAME' column_name, 64 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ACCOUNTING_RULE_DURATION' column_name, 65 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'RULE_START_DATE' column_name, 66 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'RULE_END_DATE' column_name, 67 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'REASON_CODE_MEANING' column_name, 68 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LAST_PERIOD_TO_CREDIT' column_name, 69 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TRX_BUSINESS_CATEGORY' column_name, 70 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PRODUCT_FISC_CLASSIFICATION' column_name, 71 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PRODUCT_CATEGORY' column_name, 72 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PRODUCT_TYPE' column_name, 73 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINE_INTENDED_USE' column_name, 74 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ASSESSABLE_VALUE' column_name, 75 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'DOCUMENT_SUB_TYPE' column_name, 76 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'DEFAULT_TAXATION_COUNTRY' column_name, 77 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'USER_DEFINED_FISC_CLASS' column_name, 78 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_INVOICE_NUMBER' column_name, 79 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_INVOICE_DATE' column_name, 80 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_REGIME_CODE' column_name, 81 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX' column_name, 82 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_STATUS_CODE' column_name, 83 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_RATE_CODE' column_name, 84 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_JURISDICTION_CODE' column_name, 85 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'FIRST_PTY_REG_NUM' column_name, 86 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'THIRD_PTY_REG_NUM' column_name, 87 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'FINAL_DISCHARGE_LOCATION_CODE' column_name, 88 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAXABLE_AMOUNT' column_name, 89 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAXABLE_FLAG' column_name, 90 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_EXEMPT_FLAG' column_name, 91 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_EXEMPT_REASON_CODE' column_name, 92 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_EXEMPT_REASON_CODE_MEANING' column_name, 93 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_EXEMPT_NUMBER' column_name, 94 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'AMOUNT_INCLUDES_TAX_FLAG' column_name, 95 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_PRECEDENCE' column_name, 96 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CREDIT_METHOD_FOR_ACCT_RULE' column_name, 97 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CREDIT_METHOD_FOR_INSTALLMENTS' column_name, 98 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'REASON_CODE' column_name, 99 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TAX_RATE' column_name, 100 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'FOB_POINT' column_name, 101 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SHIP_VIA' column_name, 102 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'WAYBILL_NUMBER' column_name, 103 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SALES_ORDER_LINE' column_name, 104 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SALES_ORDER_SOURCE' column_name, 105 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'SALES_ORDER_REVISION' column_name, 106 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PURCHASE_ORDER' column_name, 107 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PURCHASE_ORDER_REVISION' column_name, 108 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PURCHASE_ORDER_DATE' column_name, 109 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'AGREEMENT_NAME' column_name, 110 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'MEMO_LINE_NAME' column_name, 111 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'DOCUMENT_NUMBER' column_name, 112 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIG_SYSTEM_BATCH_NAME' column_name, 113 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINK_TO_LINE_CONTEXT' column_name, 114 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINK_TO_LINE_ATTRIBUTE1' column_name, 115 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINK_TO_LINE_ATTRIBUTE2' column_name, 116 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINK_TO_LINE_ATTRIBUTE3' column_name, 117 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINK_TO_LINE_ATTRIBUTE4' column_name, 118 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINK_TO_LINE_ATTRIBUTE5' column_name, 119 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'LINK_TO_LINE_ATTRIBUTE6' column_name, 120 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'RECEIPT_METHOD_NAME' column_name, 162 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PRINTING_OPTION' column_name, 163 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'RELATED_BATCH_SOURCE_NAME' column_name, 164 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'RELATED_TRX_NUMBER' column_name, 165 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'TRANSLATED_DESCRIPTION' column_name, 192 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'CONS_BILLING_NUMBER' column_name, 193 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PROMISED_COMMITMENT_AMOUNT' column_name, 194 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'PAYMENT_SET_ID' column_name, 195 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ORIGINAL_GL_DATE' column_name, 196 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INVOICED_LINE_ACCTG_LEVEL' column_name, 197 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'OVERRIDE_AUTO_ACCOUNTING_FLAG' column_name, 198 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HISTORICAL_FLAG' column_name, 199 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'DEFERRAL_EXCLUSION_FLAG' column_name, 200 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'BILLING_DATE' column_name, 202 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE_CATEGORY' column_name, 203 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE1' column_name, 204 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE2' column_name, 205 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE3' column_name, 206 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE4' column_name, 207 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE5' column_name, 208 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE6' column_name, 209 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE7' column_name, 210 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE8' column_name, 211 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE9' column_name, 212 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE10' column_name, 213 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE11' column_name, 214 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE12' column_name, 215 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE13' column_name, 216 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE14' column_name, 217 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'ATTRIBUTE15' column_name, 218 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE_CATEGORY' column_name, 219 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE1' column_name, 220 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE2' column_name, 221 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE3' column_name, 222 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE4' column_name, 223 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE5' column_name, 224 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE6' column_name, 225 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE7' column_name, 226 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE8' column_name, 227 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE9' column_name, 228 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE10' column_name, 229 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE11' column_name, 230 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE12' column_name, 231 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE13' column_name, 232 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE14' column_name, 233 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'HEADER_ATTRIBUTE15' column_name, 234 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'BU_NAME' column_name, 287 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'COMMENTS' column_name, 288 fbdi_position from dual
    union all select 'RA_LINES' object_code, 'INTERNAL_NOTES' column_name, 289 fbdi_position from dual
) s
on (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position;

-- 2) FBDI file routing registry: one row per (file, staging object). FBDI_COLUMN_COUNT is
--    the field count of every row of the file's Oracle template; the loader rejects a
--    file whose first row has a different count (backlog #790).
merge into "DMT_UPLOAD_FBDI_FILE_TBL" t
using (
    select 'GlInterface.csv' fbdi_csv_filename, 'GL_INTERFACE' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 149 fbdi_column_count from dual
    union all select 'GlBudgetInterface.csv' fbdi_csv_filename, 'GL_BUDGET_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 38 fbdi_column_count from dual
    union all select 'PoSupplierImport.csv' fbdi_csv_filename, 'POZ_SUPPLIERS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 155 fbdi_column_count from dual
    union all select 'PozSupAddressesInt.csv' fbdi_csv_filename, 'POZ_SUP_ADDR' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 109 fbdi_column_count from dual
    union all select 'PozSupplierSitesInt.csv' fbdi_csv_filename, 'POZ_SUP_SITE' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 199 fbdi_column_count from dual
    union all select 'PozSiteAssignmentsInt.csv' fbdi_csv_filename, 'POZ_SUP_SITE_ASSN' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 15 fbdi_column_count from dual
    union all select 'PozSupContactsInt.csv' fbdi_csv_filename, 'POZ_SUP_CONTACTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 89 fbdi_column_count from dual
    union all select 'PoHeadersInterfaceOrder.csv' fbdi_csv_filename, 'PO_HEADERS_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 99 fbdi_column_count from dual
    union all select 'PoLinesInterfaceOrder.csv' fbdi_csv_filename, 'PO_LINES_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 98 fbdi_column_count from dual
    union all select 'PoLineLocationsInterfaceOrder.csv' fbdi_csv_filename, 'PO_LINE_LOCS_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 93 fbdi_column_count from dual
    union all select 'PoDistributionsInterfaceOrder.csv' fbdi_csv_filename, 'PO_DISTS_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 124 fbdi_column_count from dual
    union all select 'HzImpPartiesT.csv' fbdi_csv_filename, 'HZ_PARTIES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 39 fbdi_column_count from dual
    union all select 'HzImpLocationsT.csv' fbdi_csv_filename, 'HZ_LOCATIONS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 50 fbdi_column_count from dual
    union all select 'HzImpPartySitesT.csv' fbdi_csv_filename, 'HZ_PARTY_SITES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 38 fbdi_column_count from dual
    union all select 'HzImpPartySiteUsesT.csv' fbdi_csv_filename, 'HZ_PARTY_SITE_USES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 33 fbdi_column_count from dual
    union all select 'HzImpAccountsT.csv' fbdi_csv_filename, 'HZ_ACCOUNTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 33 fbdi_column_count from dual
    union all select 'HzImpAcctSitesT.csv' fbdi_csv_filename, 'HZ_ACCT_SITES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 38 fbdi_column_count from dual
    union all select 'HzImpAcctSiteUsesT.csv' fbdi_csv_filename, 'HZ_ACCT_SITE_USES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 35 fbdi_column_count from dual
    union all select 'PorReqHeadersInterfaceAll.csv' fbdi_csv_filename, 'POR_REQ_HEADERS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 70 fbdi_column_count from dual
    union all select 'PorReqLinesInterfaceAll.csv' fbdi_csv_filename, 'POR_REQ_LINES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 116 fbdi_column_count from dual
    union all select 'PorReqDistsInterfaceAll.csv' fbdi_csv_filename, 'POR_REQ_DISTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 116 fbdi_column_count from dual
    union all select 'PjfProjectsAllXface.csv' fbdi_csv_filename, 'PJF_PROJECTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 157 fbdi_column_count from dual
    union all select 'PjfProjElementsXface.csv' fbdi_csv_filename, 'PJF_TASKS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 122 fbdi_column_count from dual
    union all select 'PjfProjectPartiesInt.csv' fbdi_csv_filename, 'PJF_TEAM_MEMBERS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 15 fbdi_column_count from dual
    union all select 'PjcTxnControlsStage.csv' fbdi_csv_filename, 'PJC_TXN_CONTROLS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 19 fbdi_column_count from dual
    union all select 'PjoPlanVersionsXface.csv' fbdi_csv_filename, 'PRJ_BUDGET' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 62 fbdi_column_count from dual
    union all select 'EgpSystemItemsInterface.csv' fbdi_csv_filename, 'EGP_ITEM' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 399 fbdi_column_count from dual
    union all select 'EgpItemCategoriesInterface.csv' fbdi_csv_filename, 'EGP_ITEM_CAT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 14 fbdi_column_count from dual
    union all select 'GmsAwardHeadersInterface.csv' fbdi_csv_filename, 'GMS_AWD_HEADERS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 124 fbdi_column_count from dual
    union all select 'GmsAwardPersonnelInterface.csv' fbdi_csv_filename, 'GMS_AWD_PERSONNEL' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 61 fbdi_column_count from dual
    union all select 'ApInvoicesInterface.csv' fbdi_csv_filename, 'AP_INVOICES_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 135 fbdi_column_count from dual
    union all select 'ApInvoiceLinesInterface.csv' fbdi_csv_filename, 'AP_INVOICE_LINES_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 164 fbdi_column_count from dual
    union all select 'RaInterfaceLinesAll.csv' fbdi_csv_filename, 'RA_LINES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 373 fbdi_column_count from dual
    union all select 'PjbBillingEventsXface.csv' fbdi_csv_filename, 'PJB_BILL_EVENTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 78 fbdi_column_count from dual
    union all select 'PjcTxnXfaceStageAll.csv' fbdi_csv_filename, 'PJC_EXPENDITURES' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 105 fbdi_column_count from dual
    union all select 'RaInterfaceDistributionsAll.csv' fbdi_csv_filename, 'RA_DISTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 140 fbdi_column_count from dual
    union all select 'InvTransactionsInterface.csv' fbdi_csv_filename, 'INV_TRX' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 273 fbdi_column_count from dual
    union all select 'InvTransactionLotsInterface.csv' fbdi_csv_filename, 'INV_TRX_LOTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, 10 link_position, 1 link_key_position, null parent_fbdi_filename, null parent_key_position, null parent_value_position, 'INV_TRX' parent_object_code, 'INV_LOTSERIAL_INTERFACE_NUM' parent_key_column, 9 fbdi_column_count from dual
    union all select 'InvSerialNumbersInterface.csv' fbdi_csv_filename, 'INV_TRX_SERIALS' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, 6 link_position, 1 link_key_position, null parent_fbdi_filename, null parent_key_position, null parent_value_position, 'INV_TRX' parent_object_code, 'INV_LOTSERIAL_INTERFACE_NUM' parent_key_column, 5 fbdi_column_count from dual
    union all select 'GmsAwardFundingInterface.csv' fbdi_csv_filename, 'GMS_AWD_FUNDING' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 10 fbdi_column_count from dual
    union all select 'GmsAwardProjectsInterface.csv' fbdi_csv_filename, 'GMS_AWD_PROJECTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 56 fbdi_column_count from dual
    union all select 'GmsAwardFundSrcInterface.csv' fbdi_csv_filename, 'GMS_AWD_FUND_SRC' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 8 fbdi_column_count from dual
    union all select 'GmsAwardPrjFundSrcInterface.csv' fbdi_csv_filename, 'GMS_AWD_PRJ_FUND_SRC' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 5 fbdi_column_count from dual
    union all select 'GmsAwardKeywordsInterface.csv' fbdi_csv_filename, 'GMS_AWD_KEYWORDS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 3 fbdi_column_count from dual
    union all select 'GmsAwardBdgtPeriodsInterface.csv' fbdi_csv_filename, 'GMS_AWD_BDGT_PRDS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 4 fbdi_column_count from dual
    union all select 'GmsAwardCertsInterface.csv' fbdi_csv_filename, 'GMS_AWD_CERTS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 13 fbdi_column_count from dual
    union all select 'GmsAwardCfdasInterface.csv' fbdi_csv_filename, 'GMS_AWD_CFDAS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 2 fbdi_column_count from dual
    union all select 'GmsAwardFundAllocInterface.csv' fbdi_csv_filename, 'GMS_AWD_FUND_ALLOC' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 4 fbdi_column_count from dual
    union all select 'GmsAwardOrgCreditsInterface.csv' fbdi_csv_filename, 'GMS_AWD_ORG_CREDITS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 4 fbdi_column_count from dual
    union all select 'GmsAwardPrjTaskBrdInterface.csv' fbdi_csv_filename, 'GMS_AWD_PRJ_TSK_BRD' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 5 fbdi_column_count from dual
    union all select 'GmsAwardReferencesInterface.csv' fbdi_csv_filename, 'GMS_AWD_REFERENCES' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 5 fbdi_column_count from dual
    union all select 'GmsAwardTermsInterface.csv' fbdi_csv_filename, 'GMS_AWD_TERMS' object_code, 1 load_order, 'N' distinct_rows_flag, 'MM/DD/YYYY HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 6 fbdi_column_count from dual
    union all select 'FaMassAdditions.csv' fbdi_csv_filename, 'FA_ASSET_HDR' object_code, 1 load_order, 'Y' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 425 fbdi_column_count from dual
    union all select 'FaMassAdditions.csv' fbdi_csv_filename, 'FA_ASSET_BOOK' object_code, 2 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 425 fbdi_column_count from dual
    union all select 'FaMassaddDistributions.csv' fbdi_csv_filename, 'FA_ASSET_ASSIGN' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, 67 link_position, 1 link_key_position, 'FaMassAdditions.csv' parent_fbdi_filename, 1 parent_key_position, 4 parent_value_position, null parent_object_code, null parent_key_column, 66 fbdi_column_count from dual
    union all select 'PoHeadersInterfaceBlanket.csv' fbdi_csv_filename, 'PO_HEADERS_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 122 fbdi_column_count from dual
    union all select 'PoLinesInterfaceBlanket.csv' fbdi_csv_filename, 'PO_LINES_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 108 fbdi_column_count from dual
    union all select 'PoHeadersInterfaceContract.csv' fbdi_csv_filename, 'PO_HEADERS_INT' object_code, 1 load_order, 'N' distinct_rows_flag, 'YYYY/MM/DD HH24:MI:SS' date_mask, cast(null as number) link_position, cast(null as number) link_key_position, cast(null as varchar2(100)) parent_fbdi_filename, cast(null as number) parent_key_position, cast(null as number) parent_value_position, cast(null as varchar2(50)) parent_object_code, cast(null as varchar2(128)) parent_key_column, 106 fbdi_column_count from dual
) s
on (t."FBDI_CSV_FILENAME" = s.fbdi_csv_filename and t."OBJECT_CODE" = s.object_code)
when matched then update set t."LOAD_ORDER" = s.load_order,
                             t."DISTINCT_ROWS_FLAG" = s.distinct_rows_flag,
                             t."DATE_MASK" = s.date_mask,
                             t."LINK_POSITION" = s.link_position,
                             t."LINK_KEY_POSITION" = s.link_key_position,
                             t."PARENT_FBDI_FILENAME" = s.parent_fbdi_filename,
                             t."PARENT_KEY_POSITION" = s.parent_key_position,
                             t."PARENT_VALUE_POSITION" = s.parent_value_position,
                             t."PARENT_OBJECT_CODE" = s.parent_object_code,
                             t."PARENT_KEY_COLUMN" = s.parent_key_column,
                             t."FBDI_COLUMN_COUNT" = s.fbdi_column_count
when not matched then insert ("FBDI_CSV_FILENAME", "OBJECT_CODE", "LOAD_ORDER", "DISTINCT_ROWS_FLAG", "DATE_MASK", "LINK_POSITION", "LINK_KEY_POSITION", "PARENT_FBDI_FILENAME", "PARENT_KEY_POSITION", "PARENT_VALUE_POSITION", "PARENT_OBJECT_CODE", "PARENT_KEY_COLUMN", "FBDI_COLUMN_COUNT")
     values (s.fbdi_csv_filename, s.object_code, s.load_order, s.distinct_rows_flag, s.date_mask, s.link_position, s.link_key_position, s.parent_fbdi_filename, s.parent_key_position, s.parent_value_position, s.parent_object_code, s.parent_key_column, s.fbdi_column_count);

-- Registry rows the maps no longer hold (their positions go with them, ON DELETE CASCADE).
delete from "DMT_UPLOAD_FBDI_FILE_TBL" t
where not exists (
  select 1 from (
    select 'GlInterface.csv' fbdi_csv_filename, 'GL_INTERFACE' object_code from dual
    union all select 'GlBudgetInterface.csv' fbdi_csv_filename, 'GL_BUDGET_INT' object_code from dual
    union all select 'PoSupplierImport.csv' fbdi_csv_filename, 'POZ_SUPPLIERS' object_code from dual
    union all select 'PozSupAddressesInt.csv' fbdi_csv_filename, 'POZ_SUP_ADDR' object_code from dual
    union all select 'PozSupplierSitesInt.csv' fbdi_csv_filename, 'POZ_SUP_SITE' object_code from dual
    union all select 'PozSiteAssignmentsInt.csv' fbdi_csv_filename, 'POZ_SUP_SITE_ASSN' object_code from dual
    union all select 'PozSupContactsInt.csv' fbdi_csv_filename, 'POZ_SUP_CONTACTS' object_code from dual
    union all select 'PoHeadersInterfaceOrder.csv' fbdi_csv_filename, 'PO_HEADERS_INT' object_code from dual
    union all select 'PoLinesInterfaceOrder.csv' fbdi_csv_filename, 'PO_LINES_INT' object_code from dual
    union all select 'PoLineLocationsInterfaceOrder.csv' fbdi_csv_filename, 'PO_LINE_LOCS_INT' object_code from dual
    union all select 'PoDistributionsInterfaceOrder.csv' fbdi_csv_filename, 'PO_DISTS_INT' object_code from dual
    union all select 'HzImpPartiesT.csv' fbdi_csv_filename, 'HZ_PARTIES' object_code from dual
    union all select 'HzImpLocationsT.csv' fbdi_csv_filename, 'HZ_LOCATIONS' object_code from dual
    union all select 'HzImpPartySitesT.csv' fbdi_csv_filename, 'HZ_PARTY_SITES' object_code from dual
    union all select 'HzImpPartySiteUsesT.csv' fbdi_csv_filename, 'HZ_PARTY_SITE_USES' object_code from dual
    union all select 'HzImpAccountsT.csv' fbdi_csv_filename, 'HZ_ACCOUNTS' object_code from dual
    union all select 'HzImpAcctSitesT.csv' fbdi_csv_filename, 'HZ_ACCT_SITES' object_code from dual
    union all select 'HzImpAcctSiteUsesT.csv' fbdi_csv_filename, 'HZ_ACCT_SITE_USES' object_code from dual
    union all select 'PorReqHeadersInterfaceAll.csv' fbdi_csv_filename, 'POR_REQ_HEADERS' object_code from dual
    union all select 'PorReqLinesInterfaceAll.csv' fbdi_csv_filename, 'POR_REQ_LINES' object_code from dual
    union all select 'PorReqDistsInterfaceAll.csv' fbdi_csv_filename, 'POR_REQ_DISTS' object_code from dual
    union all select 'PjfProjectsAllXface.csv' fbdi_csv_filename, 'PJF_PROJECTS' object_code from dual
    union all select 'PjfProjElementsXface.csv' fbdi_csv_filename, 'PJF_TASKS' object_code from dual
    union all select 'PjfProjectPartiesInt.csv' fbdi_csv_filename, 'PJF_TEAM_MEMBERS' object_code from dual
    union all select 'PjcTxnControlsStage.csv' fbdi_csv_filename, 'PJC_TXN_CONTROLS' object_code from dual
    union all select 'PjoPlanVersionsXface.csv' fbdi_csv_filename, 'PRJ_BUDGET' object_code from dual
    union all select 'EgpSystemItemsInterface.csv' fbdi_csv_filename, 'EGP_ITEM' object_code from dual
    union all select 'EgpItemCategoriesInterface.csv' fbdi_csv_filename, 'EGP_ITEM_CAT' object_code from dual
    union all select 'GmsAwardHeadersInterface.csv' fbdi_csv_filename, 'GMS_AWD_HEADERS' object_code from dual
    union all select 'GmsAwardPersonnelInterface.csv' fbdi_csv_filename, 'GMS_AWD_PERSONNEL' object_code from dual
    union all select 'ApInvoicesInterface.csv' fbdi_csv_filename, 'AP_INVOICES_INT' object_code from dual
    union all select 'ApInvoiceLinesInterface.csv' fbdi_csv_filename, 'AP_INVOICE_LINES_INT' object_code from dual
    union all select 'RaInterfaceLinesAll.csv' fbdi_csv_filename, 'RA_LINES' object_code from dual
    union all select 'PjbBillingEventsXface.csv' fbdi_csv_filename, 'PJB_BILL_EVENTS' object_code from dual
    union all select 'PjcTxnXfaceStageAll.csv' fbdi_csv_filename, 'PJC_EXPENDITURES' object_code from dual
    union all select 'RaInterfaceDistributionsAll.csv' fbdi_csv_filename, 'RA_DISTS' object_code from dual
    union all select 'InvTransactionsInterface.csv' fbdi_csv_filename, 'INV_TRX' object_code from dual
    union all select 'InvTransactionLotsInterface.csv' fbdi_csv_filename, 'INV_TRX_LOTS' object_code from dual
    union all select 'InvSerialNumbersInterface.csv' fbdi_csv_filename, 'INV_TRX_SERIALS' object_code from dual
    union all select 'GmsAwardFundingInterface.csv' fbdi_csv_filename, 'GMS_AWD_FUNDING' object_code from dual
    union all select 'GmsAwardProjectsInterface.csv' fbdi_csv_filename, 'GMS_AWD_PROJECTS' object_code from dual
    union all select 'GmsAwardFundSrcInterface.csv' fbdi_csv_filename, 'GMS_AWD_FUND_SRC' object_code from dual
    union all select 'GmsAwardPrjFundSrcInterface.csv' fbdi_csv_filename, 'GMS_AWD_PRJ_FUND_SRC' object_code from dual
    union all select 'GmsAwardKeywordsInterface.csv' fbdi_csv_filename, 'GMS_AWD_KEYWORDS' object_code from dual
    union all select 'GmsAwardBdgtPeriodsInterface.csv' fbdi_csv_filename, 'GMS_AWD_BDGT_PRDS' object_code from dual
    union all select 'GmsAwardCertsInterface.csv' fbdi_csv_filename, 'GMS_AWD_CERTS' object_code from dual
    union all select 'GmsAwardCfdasInterface.csv' fbdi_csv_filename, 'GMS_AWD_CFDAS' object_code from dual
    union all select 'GmsAwardFundAllocInterface.csv' fbdi_csv_filename, 'GMS_AWD_FUND_ALLOC' object_code from dual
    union all select 'GmsAwardOrgCreditsInterface.csv' fbdi_csv_filename, 'GMS_AWD_ORG_CREDITS' object_code from dual
    union all select 'GmsAwardPrjTaskBrdInterface.csv' fbdi_csv_filename, 'GMS_AWD_PRJ_TSK_BRD' object_code from dual
    union all select 'GmsAwardReferencesInterface.csv' fbdi_csv_filename, 'GMS_AWD_REFERENCES' object_code from dual
    union all select 'GmsAwardTermsInterface.csv' fbdi_csv_filename, 'GMS_AWD_TERMS' object_code from dual
    union all select 'FaMassAdditions.csv' fbdi_csv_filename, 'FA_ASSET_HDR' object_code from dual
    union all select 'FaMassAdditions.csv' fbdi_csv_filename, 'FA_ASSET_BOOK' object_code from dual
    union all select 'FaMassaddDistributions.csv' fbdi_csv_filename, 'FA_ASSET_ASSIGN' object_code from dual
    union all select 'PoHeadersInterfaceBlanket.csv' fbdi_csv_filename, 'PO_HEADERS_INT' object_code from dual
    union all select 'PoLinesInterfaceBlanket.csv' fbdi_csv_filename, 'PO_LINES_INT' object_code from dual
    union all select 'PoHeadersInterfaceContract.csv' fbdi_csv_filename, 'PO_HEADERS_INT' object_code from dual
  ) s
  where s.fbdi_csv_filename = t."FBDI_CSV_FILENAME" and s.object_code = t."OBJECT_CODE");

-- 3) Positions per (file, staging object), filtered to the object's non-admin dictionary columns.
-- GlInterface.csv -> GL_INTERFACE
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'JOURNAL_STATUS' column_name, 1 fbdi_position from dual
      union all select 'ACCOUNTING_DATE' column_name, 3 fbdi_position from dual
      union all select 'USER_JE_SOURCE_NAME' column_name, 4 fbdi_position from dual
      union all select 'USER_JE_CATEGORY_NAME' column_name, 5 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 6 fbdi_position from dual
      union all select 'DATE_CREATED' column_name, 7 fbdi_position from dual
      union all select 'ACTUAL_FLAG' column_name, 8 fbdi_position from dual
      union all select 'SEGMENT1' column_name, 9 fbdi_position from dual
      union all select 'SEGMENT2' column_name, 10 fbdi_position from dual
      union all select 'SEGMENT3' column_name, 11 fbdi_position from dual
      union all select 'SEGMENT4' column_name, 12 fbdi_position from dual
      union all select 'SEGMENT5' column_name, 13 fbdi_position from dual
      union all select 'SEGMENT6' column_name, 14 fbdi_position from dual
      union all select 'SEGMENT7' column_name, 15 fbdi_position from dual
      union all select 'SEGMENT8' column_name, 16 fbdi_position from dual
      union all select 'SEGMENT9' column_name, 17 fbdi_position from dual
      union all select 'SEGMENT10' column_name, 18 fbdi_position from dual
      union all select 'SEGMENT11' column_name, 19 fbdi_position from dual
      union all select 'SEGMENT12' column_name, 20 fbdi_position from dual
      union all select 'SEGMENT13' column_name, 21 fbdi_position from dual
      union all select 'SEGMENT14' column_name, 22 fbdi_position from dual
      union all select 'SEGMENT15' column_name, 23 fbdi_position from dual
      union all select 'SEGMENT16' column_name, 24 fbdi_position from dual
      union all select 'SEGMENT17' column_name, 25 fbdi_position from dual
      union all select 'SEGMENT18' column_name, 26 fbdi_position from dual
      union all select 'SEGMENT19' column_name, 27 fbdi_position from dual
      union all select 'SEGMENT20' column_name, 28 fbdi_position from dual
      union all select 'SEGMENT21' column_name, 29 fbdi_position from dual
      union all select 'SEGMENT22' column_name, 30 fbdi_position from dual
      union all select 'SEGMENT23' column_name, 31 fbdi_position from dual
      union all select 'SEGMENT24' column_name, 32 fbdi_position from dual
      union all select 'SEGMENT25' column_name, 33 fbdi_position from dual
      union all select 'SEGMENT26' column_name, 34 fbdi_position from dual
      union all select 'SEGMENT27' column_name, 35 fbdi_position from dual
      union all select 'SEGMENT28' column_name, 36 fbdi_position from dual
      union all select 'SEGMENT29' column_name, 37 fbdi_position from dual
      union all select 'SEGMENT30' column_name, 38 fbdi_position from dual
      union all select 'ENTERED_DR' column_name, 39 fbdi_position from dual
      union all select 'ENTERED_CR' column_name, 40 fbdi_position from dual
      union all select 'ACCOUNTED_DR' column_name, 41 fbdi_position from dual
      union all select 'ACCOUNTED_CR' column_name, 42 fbdi_position from dual
      union all select 'REFERENCE1' column_name, 43 fbdi_position from dual
      union all select 'REFERENCE2' column_name, 44 fbdi_position from dual
      union all select 'REFERENCE4' column_name, 46 fbdi_position from dual
      union all select 'REFERENCE5' column_name, 47 fbdi_position from dual
      union all select 'REFERENCE6' column_name, 48 fbdi_position from dual
      union all select 'REFERENCE7' column_name, 49 fbdi_position from dual
      union all select 'REFERENCE8' column_name, 50 fbdi_position from dual
      union all select 'REFERENCE10' column_name, 52 fbdi_position from dual
      union all select 'RECON_KEY' column_name, 53 fbdi_position from dual
      union all select 'STAT_AMOUNT' column_name, 63 fbdi_position from dual
      union all select 'USER_CURRENCY_CONVERSION_TYPE' column_name, 64 fbdi_position from dual
      union all select 'CURRENCY_CONVERSION_DATE' column_name, 65 fbdi_position from dual
      union all select 'CURRENCY_CONVERSION_RATE' column_name, 66 fbdi_position from dual
      union all select 'GROUP_ID' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 88 fbdi_position from dual
      union all select 'LEDGER_NAME' column_name, 92 fbdi_position from dual
      union all select 'PERIOD_NAME' column_name, 95 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GlInterface.csv' and f."OBJECT_CODE" = 'GL_INTERFACE'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GlInterface.csv' and f."OBJECT_CODE" = 'GL_INTERFACE')
and   t."COLUMN_NAME" not in ('JOURNAL_STATUS', 'ACCOUNTING_DATE', 'USER_JE_SOURCE_NAME', 'USER_JE_CATEGORY_NAME', 'CURRENCY_CODE', 'DATE_CREATED', 'ACTUAL_FLAG', 'SEGMENT1', 'SEGMENT2', 'SEGMENT3', 'SEGMENT4', 'SEGMENT5', 'SEGMENT6', 'SEGMENT7', 'SEGMENT8', 'SEGMENT9', 'SEGMENT10', 'SEGMENT11', 'SEGMENT12', 'SEGMENT13', 'SEGMENT14', 'SEGMENT15', 'SEGMENT16', 'SEGMENT17', 'SEGMENT18', 'SEGMENT19', 'SEGMENT20', 'SEGMENT21', 'SEGMENT22', 'SEGMENT23', 'SEGMENT24', 'SEGMENT25', 'SEGMENT26', 'SEGMENT27', 'SEGMENT28', 'SEGMENT29', 'SEGMENT30', 'ENTERED_DR', 'ENTERED_CR', 'ACCOUNTED_DR', 'ACCOUNTED_CR', 'REFERENCE1', 'REFERENCE2', 'REFERENCE4', 'REFERENCE5', 'REFERENCE6', 'REFERENCE7', 'REFERENCE8', 'REFERENCE10', 'RECON_KEY', 'STAT_AMOUNT', 'USER_CURRENCY_CONVERSION_TYPE', 'CURRENCY_CONVERSION_DATE', 'CURRENCY_CONVERSION_RATE', 'GROUP_ID', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'LEDGER_NAME', 'PERIOD_NAME');

-- GlBudgetInterface.csv -> GL_BUDGET_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'RUN_NAME' column_name, 1 fbdi_position from dual
      union all select 'STATUS_FBDI' column_name, 2 fbdi_position from dual
      union all select 'LEDGER_ID' column_name, 3 fbdi_position from dual
      union all select 'BUDGET_NAME' column_name, 4 fbdi_position from dual
      union all select 'PERIOD_NAME' column_name, 5 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 6 fbdi_position from dual
      union all select 'SEGMENT1' column_name, 7 fbdi_position from dual
      union all select 'SEGMENT2' column_name, 8 fbdi_position from dual
      union all select 'SEGMENT3' column_name, 9 fbdi_position from dual
      union all select 'SEGMENT4' column_name, 10 fbdi_position from dual
      union all select 'SEGMENT5' column_name, 11 fbdi_position from dual
      union all select 'SEGMENT6' column_name, 12 fbdi_position from dual
      union all select 'SEGMENT7' column_name, 13 fbdi_position from dual
      union all select 'SEGMENT8' column_name, 14 fbdi_position from dual
      union all select 'SEGMENT9' column_name, 15 fbdi_position from dual
      union all select 'SEGMENT10' column_name, 16 fbdi_position from dual
      union all select 'SEGMENT11' column_name, 17 fbdi_position from dual
      union all select 'SEGMENT12' column_name, 18 fbdi_position from dual
      union all select 'SEGMENT13' column_name, 19 fbdi_position from dual
      union all select 'SEGMENT14' column_name, 20 fbdi_position from dual
      union all select 'SEGMENT15' column_name, 21 fbdi_position from dual
      union all select 'SEGMENT16' column_name, 22 fbdi_position from dual
      union all select 'SEGMENT17' column_name, 23 fbdi_position from dual
      union all select 'SEGMENT18' column_name, 24 fbdi_position from dual
      union all select 'SEGMENT19' column_name, 25 fbdi_position from dual
      union all select 'SEGMENT20' column_name, 26 fbdi_position from dual
      union all select 'SEGMENT21' column_name, 27 fbdi_position from dual
      union all select 'SEGMENT22' column_name, 28 fbdi_position from dual
      union all select 'SEGMENT23' column_name, 29 fbdi_position from dual
      union all select 'SEGMENT24' column_name, 30 fbdi_position from dual
      union all select 'SEGMENT25' column_name, 31 fbdi_position from dual
      union all select 'SEGMENT26' column_name, 32 fbdi_position from dual
      union all select 'SEGMENT27' column_name, 33 fbdi_position from dual
      union all select 'SEGMENT28' column_name, 34 fbdi_position from dual
      union all select 'SEGMENT29' column_name, 35 fbdi_position from dual
      union all select 'SEGMENT30' column_name, 36 fbdi_position from dual
      union all select 'BUDGET_AMOUNT' column_name, 37 fbdi_position from dual
      union all select 'LEDGER_NAME' column_name, 38 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GlBudgetInterface.csv' and f."OBJECT_CODE" = 'GL_BUDGET_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GlBudgetInterface.csv' and f."OBJECT_CODE" = 'GL_BUDGET_INT')
and   t."COLUMN_NAME" not in ('RUN_NAME', 'STATUS_FBDI', 'LEDGER_ID', 'BUDGET_NAME', 'PERIOD_NAME', 'CURRENCY_CODE', 'SEGMENT1', 'SEGMENT2', 'SEGMENT3', 'SEGMENT4', 'SEGMENT5', 'SEGMENT6', 'SEGMENT7', 'SEGMENT8', 'SEGMENT9', 'SEGMENT10', 'SEGMENT11', 'SEGMENT12', 'SEGMENT13', 'SEGMENT14', 'SEGMENT15', 'SEGMENT16', 'SEGMENT17', 'SEGMENT18', 'SEGMENT19', 'SEGMENT20', 'SEGMENT21', 'SEGMENT22', 'SEGMENT23', 'SEGMENT24', 'SEGMENT25', 'SEGMENT26', 'SEGMENT27', 'SEGMENT28', 'SEGMENT29', 'SEGMENT30', 'BUDGET_AMOUNT', 'LEDGER_NAME');

-- PoSupplierImport.csv -> POZ_SUPPLIERS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 2 fbdi_position from dual
      union all select 'VENDOR_NAME_NEW' column_name, 3 fbdi_position from dual
      union all select 'SEGMENT1' column_name, 4 fbdi_position from dual
      union all select 'VENDOR_NAME_ALT' column_name, 5 fbdi_position from dual
      union all select 'ORGANIZATION_TYPE_LOOKUP_CODE' column_name, 6 fbdi_position from dual
      union all select 'VENDOR_TYPE_LOOKUP_CODE' column_name, 7 fbdi_position from dual
      union all select 'END_DATE_ACTIVE' column_name, 8 fbdi_position from dual
      union all select 'BUSINESS_RELATIONSHIP' column_name, 9 fbdi_position from dual
      union all select 'PARENT_SUPPLIER_NAME' column_name, 10 fbdi_position from dual
      union all select 'ALIAS' column_name, 11 fbdi_position from dual
      union all select 'DUNS_NUMBER' column_name, 12 fbdi_position from dual
      union all select 'ONE_TIME_FLAG' column_name, 13 fbdi_position from dual
      union all select 'CUSTOMER_NUM' column_name, 14 fbdi_position from dual
      union all select 'STANDARD_INDUSTRY_CLASS' column_name, 15 fbdi_position from dual
      union all select 'NI_NUMBER' column_name, 16 fbdi_position from dual
      union all select 'CORPORATE_WEBSITE' column_name, 17 fbdi_position from dual
      union all select 'CHIEF_EXECUTIVE_TITLE' column_name, 18 fbdi_position from dual
      union all select 'CHIEF_EXECUTIVE_NAME' column_name, 19 fbdi_position from dual
      union all select 'BC_NOT_APPLICABLE_FLAG' column_name, 20 fbdi_position from dual
      union all select 'TAX_COUNTRY_CODE' column_name, 21 fbdi_position from dual
      union all select 'NUM_1099' column_name, 22 fbdi_position from dual
      union all select 'FEDERAL_REPORTABLE_FLAG' column_name, 23 fbdi_position from dual
      union all select 'TYPE_1099' column_name, 24 fbdi_position from dual
      union all select 'STATE_REPORTABLE_FLAG' column_name, 25 fbdi_position from dual
      union all select 'TAX_REPORTING_NAME' column_name, 26 fbdi_position from dual
      union all select 'NAME_CONTROL' column_name, 27 fbdi_position from dual
      union all select 'TAX_VERIFICATION_DATE' column_name, 28 fbdi_position from dual
      union all select 'ALLOW_AWT_FLAG' column_name, 29 fbdi_position from dual
      union all select 'AWT_GROUP_NAME' column_name, 30 fbdi_position from dual
      union all select 'VAT_CODE' column_name, 31 fbdi_position from dual
      union all select 'VAT_REGISTRATION_NUM' column_name, 32 fbdi_position from dual
      union all select 'AUTO_TAX_CALC_OVERRIDE' column_name, 33 fbdi_position from dual
      union all select 'PAYMENT_METHOD_LOOKUP_CODE' column_name, 34 fbdi_position from dual
      union all select 'DELIVERY_CHANNEL_CODE' column_name, 35 fbdi_position from dual
      union all select 'BANK_INSTRUCTION1_CODE' column_name, 36 fbdi_position from dual
      union all select 'BANK_INSTRUCTION2_CODE' column_name, 37 fbdi_position from dual
      union all select 'BANK_INSTRUCTION_DETAILS' column_name, 38 fbdi_position from dual
      union all select 'SETTLEMENT_PRIORITY' column_name, 39 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE1' column_name, 40 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE2' column_name, 41 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE3' column_name, 42 fbdi_position from dual
      union all select 'IBY_BANK_CHARGE_BEARER' column_name, 43 fbdi_position from dual
      union all select 'PAYMENT_REASON_CODE' column_name, 44 fbdi_position from dual
      union all select 'PAYMENT_REASON_COMMENTS' column_name, 45 fbdi_position from dual
      union all select 'PAYMENT_FORMAT_CODE' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 97 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 98 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE1' column_name, 99 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE2' column_name, 100 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE3' column_name, 101 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE4' column_name, 102 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE5' column_name, 103 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE6' column_name, 104 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE7' column_name, 105 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE8' column_name, 106 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE9' column_name, 107 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE10' column_name, 108 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE11' column_name, 109 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE12' column_name, 110 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE13' column_name, 111 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE14' column_name, 112 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE15' column_name, 113 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE16' column_name, 114 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE17' column_name, 115 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE18' column_name, 116 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE19' column_name, 117 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE20' column_name, 118 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE1' column_name, 119 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE2' column_name, 120 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE3' column_name, 121 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE4' column_name, 122 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE5' column_name, 123 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE6' column_name, 124 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE7' column_name, 125 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE8' column_name, 126 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE9' column_name, 127 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE10' column_name, 128 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP1' column_name, 129 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP2' column_name, 130 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP3' column_name, 131 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP4' column_name, 132 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP5' column_name, 133 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP6' column_name, 134 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP7' column_name, 135 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP8' column_name, 136 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP9' column_name, 137 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP10' column_name, 138 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 139 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 140 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 141 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 142 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 143 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER6' column_name, 144 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER7' column_name, 145 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER8' column_name, 146 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER9' column_name, 147 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER10' column_name, 148 fbdi_position from dual
      union all select 'PARTY_NUMBER' column_name, 149 fbdi_position from dual
      union all select 'SERVICE_LEVEL_CODE' column_name, 150 fbdi_position from dual
      union all select 'EXCLUSIVE_PAYMENT_FLAG' column_name, 151 fbdi_position from dual
      union all select 'REMIT_ADVICE_DELIVERY_METHOD' column_name, 152 fbdi_position from dual
      union all select 'REMIT_ADVICE_EMAIL' column_name, 153 fbdi_position from dual
      union all select 'REMIT_ADVICE_FAX' column_name, 154 fbdi_position from dual
      union all select 'DATAFOX_COMPANY_ID' column_name, 155 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoSupplierImport.csv' and f."OBJECT_CODE" = 'POZ_SUPPLIERS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoSupplierImport.csv' and f."OBJECT_CODE" = 'POZ_SUPPLIERS')
and   t."COLUMN_NAME" not in ('IMPORT_ACTION', 'VENDOR_NAME', 'VENDOR_NAME_NEW', 'SEGMENT1', 'VENDOR_NAME_ALT', 'ORGANIZATION_TYPE_LOOKUP_CODE', 'VENDOR_TYPE_LOOKUP_CODE', 'END_DATE_ACTIVE', 'BUSINESS_RELATIONSHIP', 'PARENT_SUPPLIER_NAME', 'ALIAS', 'DUNS_NUMBER', 'ONE_TIME_FLAG', 'CUSTOMER_NUM', 'STANDARD_INDUSTRY_CLASS', 'NI_NUMBER', 'CORPORATE_WEBSITE', 'CHIEF_EXECUTIVE_TITLE', 'CHIEF_EXECUTIVE_NAME', 'BC_NOT_APPLICABLE_FLAG', 'TAX_COUNTRY_CODE', 'NUM_1099', 'FEDERAL_REPORTABLE_FLAG', 'TYPE_1099', 'STATE_REPORTABLE_FLAG', 'TAX_REPORTING_NAME', 'NAME_CONTROL', 'TAX_VERIFICATION_DATE', 'ALLOW_AWT_FLAG', 'AWT_GROUP_NAME', 'VAT_CODE', 'VAT_REGISTRATION_NUM', 'AUTO_TAX_CALC_OVERRIDE', 'PAYMENT_METHOD_LOOKUP_CODE', 'DELIVERY_CHANNEL_CODE', 'BANK_INSTRUCTION1_CODE', 'BANK_INSTRUCTION2_CODE', 'BANK_INSTRUCTION_DETAILS', 'SETTLEMENT_PRIORITY', 'PAYMENT_TEXT_MESSAGE1', 'PAYMENT_TEXT_MESSAGE2', 'PAYMENT_TEXT_MESSAGE3', 'IBY_BANK_CHARGE_BEARER', 'PAYMENT_REASON_CODE', 'PAYMENT_REASON_COMMENTS', 'PAYMENT_FORMAT_CODE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'GLOBAL_ATTRIBUTE_CATEGORY', 'GLOBAL_ATTRIBUTE1', 'GLOBAL_ATTRIBUTE2', 'GLOBAL_ATTRIBUTE3', 'GLOBAL_ATTRIBUTE4', 'GLOBAL_ATTRIBUTE5', 'GLOBAL_ATTRIBUTE6', 'GLOBAL_ATTRIBUTE7', 'GLOBAL_ATTRIBUTE8', 'GLOBAL_ATTRIBUTE9', 'GLOBAL_ATTRIBUTE10', 'GLOBAL_ATTRIBUTE11', 'GLOBAL_ATTRIBUTE12', 'GLOBAL_ATTRIBUTE13', 'GLOBAL_ATTRIBUTE14', 'GLOBAL_ATTRIBUTE15', 'GLOBAL_ATTRIBUTE16', 'GLOBAL_ATTRIBUTE17', 'GLOBAL_ATTRIBUTE18', 'GLOBAL_ATTRIBUTE19', 'GLOBAL_ATTRIBUTE20', 'GLOBAL_ATTRIBUTE_DATE1', 'GLOBAL_ATTRIBUTE_DATE2', 'GLOBAL_ATTRIBUTE_DATE3', 'GLOBAL_ATTRIBUTE_DATE4', 'GLOBAL_ATTRIBUTE_DATE5', 'GLOBAL_ATTRIBUTE_DATE6', 'GLOBAL_ATTRIBUTE_DATE7', 'GLOBAL_ATTRIBUTE_DATE8', 'GLOBAL_ATTRIBUTE_DATE9', 'GLOBAL_ATTRIBUTE_DATE10', 'GLOBAL_ATTRIBUTE_TIMESTAMP1', 'GLOBAL_ATTRIBUTE_TIMESTAMP2', 'GLOBAL_ATTRIBUTE_TIMESTAMP3', 'GLOBAL_ATTRIBUTE_TIMESTAMP4', 'GLOBAL_ATTRIBUTE_TIMESTAMP5', 'GLOBAL_ATTRIBUTE_TIMESTAMP6', 'GLOBAL_ATTRIBUTE_TIMESTAMP7', 'GLOBAL_ATTRIBUTE_TIMESTAMP8', 'GLOBAL_ATTRIBUTE_TIMESTAMP9', 'GLOBAL_ATTRIBUTE_TIMESTAMP10', 'GLOBAL_ATTRIBUTE_NUMBER1', 'GLOBAL_ATTRIBUTE_NUMBER2', 'GLOBAL_ATTRIBUTE_NUMBER3', 'GLOBAL_ATTRIBUTE_NUMBER4', 'GLOBAL_ATTRIBUTE_NUMBER5', 'GLOBAL_ATTRIBUTE_NUMBER6', 'GLOBAL_ATTRIBUTE_NUMBER7', 'GLOBAL_ATTRIBUTE_NUMBER8', 'GLOBAL_ATTRIBUTE_NUMBER9', 'GLOBAL_ATTRIBUTE_NUMBER10', 'PARTY_NUMBER', 'SERVICE_LEVEL_CODE', 'EXCLUSIVE_PAYMENT_FLAG', 'REMIT_ADVICE_DELIVERY_METHOD', 'REMIT_ADVICE_EMAIL', 'REMIT_ADVICE_FAX', 'DATAFOX_COMPANY_ID');

-- PozSupAddressesInt.csv -> POZ_SUP_ADDR
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 2 fbdi_position from dual
      union all select 'PARTY_SITE_NAME' column_name, 3 fbdi_position from dual
      union all select 'PARTY_SITE_NAME_NEW' column_name, 4 fbdi_position from dual
      union all select 'COUNTRY' column_name, 5 fbdi_position from dual
      union all select 'ADDRESS_LINE1' column_name, 6 fbdi_position from dual
      union all select 'ADDRESS_LINE2' column_name, 7 fbdi_position from dual
      union all select 'ADDRESS_LINE3' column_name, 8 fbdi_position from dual
      union all select 'ADDRESS_LINE4' column_name, 9 fbdi_position from dual
      union all select 'ADDRESS_LINES_PHONETIC' column_name, 10 fbdi_position from dual
      union all select 'ADDR_ELEMENT_ATTRIBUTE1' column_name, 11 fbdi_position from dual
      union all select 'ADDR_ELEMENT_ATTRIBUTE2' column_name, 12 fbdi_position from dual
      union all select 'ADDR_ELEMENT_ATTRIBUTE3' column_name, 13 fbdi_position from dual
      union all select 'ADDR_ELEMENT_ATTRIBUTE4' column_name, 14 fbdi_position from dual
      union all select 'ADDR_ELEMENT_ATTRIBUTE5' column_name, 15 fbdi_position from dual
      union all select 'BUILDING' column_name, 16 fbdi_position from dual
      union all select 'FLOOR_NUMBER' column_name, 17 fbdi_position from dual
      union all select 'CITY' column_name, 18 fbdi_position from dual
      union all select 'STATE' column_name, 19 fbdi_position from dual
      union all select 'PROVINCE' column_name, 20 fbdi_position from dual
      union all select 'COUNTY' column_name, 21 fbdi_position from dual
      union all select 'POSTAL_CODE' column_name, 22 fbdi_position from dual
      union all select 'POSTAL_PLUS4_CODE' column_name, 23 fbdi_position from dual
      union all select 'ADDRESSEE' column_name, 24 fbdi_position from dual
      union all select 'GLOBAL_LOCATION_NUMBER' column_name, 25 fbdi_position from dual
      union all select 'PARTY_SITE_LANGUAGE' column_name, 26 fbdi_position from dual
      union all select 'INACTIVE_DATE' column_name, 27 fbdi_position from dual
      union all select 'PHONE_COUNTRY_CODE' column_name, 28 fbdi_position from dual
      union all select 'PHONE_AREA_CODE' column_name, 29 fbdi_position from dual
      union all select 'PHONE' column_name, 30 fbdi_position from dual
      union all select 'PHONE_EXTENSION' column_name, 31 fbdi_position from dual
      union all select 'FAX_COUNTRY_CODE' column_name, 32 fbdi_position from dual
      union all select 'FAX_AREA_CODE' column_name, 33 fbdi_position from dual
      union all select 'FAX' column_name, 34 fbdi_position from dual
      union all select 'RFQ_OR_BIDDING_PURPOSE_FLAG' column_name, 35 fbdi_position from dual
      union all select 'ORDERING_PURPOSE_FLAG' column_name, 36 fbdi_position from dual
      union all select 'REMIT_TO_PURPOSE_FLAG' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE21' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE22' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE23' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE24' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE25' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE26' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE27' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE28' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE29' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE30' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER11' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER12' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE11' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE12' column_name, 92 fbdi_position from dual
      union all select 'EMAIL_ADDRESS' column_name, 93 fbdi_position from dual
      union all select 'DELIVERY_CHANNEL_CODE' column_name, 94 fbdi_position from dual
      union all select 'BANK_INSTRUCTION1_CODE' column_name, 95 fbdi_position from dual
      union all select 'BANK_INSTRUCTION2_CODE' column_name, 96 fbdi_position from dual
      union all select 'BANK_INSTRUCTION_DETAILS' column_name, 97 fbdi_position from dual
      union all select 'SETTLEMENT_PRIORITY' column_name, 98 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE1' column_name, 99 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE2' column_name, 100 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE3' column_name, 101 fbdi_position from dual
      union all select 'SERVICE_LEVEL_CODE' column_name, 102 fbdi_position from dual
      union all select 'EXCLUSIVE_PAYMENT_FLAG' column_name, 103 fbdi_position from dual
      union all select 'IBY_BANK_CHARGE_BEARER' column_name, 104 fbdi_position from dual
      union all select 'PAYMENT_REASON_CODE' column_name, 105 fbdi_position from dual
      union all select 'PAYMENT_REASON_COMMENTS' column_name, 106 fbdi_position from dual
      union all select 'REMIT_ADVICE_DELIVERY_METHOD' column_name, 107 fbdi_position from dual
      union all select 'REMIT_ADVICE_EMAIL' column_name, 108 fbdi_position from dual
      union all select 'REMIT_ADVICE_FAX' column_name, 109 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PozSupAddressesInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_ADDR'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PozSupAddressesInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_ADDR')
and   t."COLUMN_NAME" not in ('IMPORT_ACTION', 'VENDOR_NAME', 'PARTY_SITE_NAME', 'PARTY_SITE_NAME_NEW', 'COUNTRY', 'ADDRESS_LINE1', 'ADDRESS_LINE2', 'ADDRESS_LINE3', 'ADDRESS_LINE4', 'ADDRESS_LINES_PHONETIC', 'ADDR_ELEMENT_ATTRIBUTE1', 'ADDR_ELEMENT_ATTRIBUTE2', 'ADDR_ELEMENT_ATTRIBUTE3', 'ADDR_ELEMENT_ATTRIBUTE4', 'ADDR_ELEMENT_ATTRIBUTE5', 'BUILDING', 'FLOOR_NUMBER', 'CITY', 'STATE', 'PROVINCE', 'COUNTY', 'POSTAL_CODE', 'POSTAL_PLUS4_CODE', 'ADDRESSEE', 'GLOBAL_LOCATION_NUMBER', 'PARTY_SITE_LANGUAGE', 'INACTIVE_DATE', 'PHONE_COUNTRY_CODE', 'PHONE_AREA_CODE', 'PHONE', 'PHONE_EXTENSION', 'FAX_COUNTRY_CODE', 'FAX_AREA_CODE', 'FAX', 'RFQ_OR_BIDDING_PURPOSE_FLAG', 'ORDERING_PURPOSE_FLAG', 'REMIT_TO_PURPOSE_FLAG', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE21', 'ATTRIBUTE22', 'ATTRIBUTE23', 'ATTRIBUTE24', 'ATTRIBUTE25', 'ATTRIBUTE26', 'ATTRIBUTE27', 'ATTRIBUTE28', 'ATTRIBUTE29', 'ATTRIBUTE30', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_NUMBER11', 'ATTRIBUTE_NUMBER12', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_DATE11', 'ATTRIBUTE_DATE12', 'EMAIL_ADDRESS', 'DELIVERY_CHANNEL_CODE', 'BANK_INSTRUCTION1_CODE', 'BANK_INSTRUCTION2_CODE', 'BANK_INSTRUCTION_DETAILS', 'SETTLEMENT_PRIORITY', 'PAYMENT_TEXT_MESSAGE1', 'PAYMENT_TEXT_MESSAGE2', 'PAYMENT_TEXT_MESSAGE3', 'SERVICE_LEVEL_CODE', 'EXCLUSIVE_PAYMENT_FLAG', 'IBY_BANK_CHARGE_BEARER', 'PAYMENT_REASON_CODE', 'PAYMENT_REASON_COMMENTS', 'REMIT_ADVICE_DELIVERY_METHOD', 'REMIT_ADVICE_EMAIL', 'REMIT_ADVICE_FAX');

-- PozSupplierSitesInt.csv -> POZ_SUP_SITE
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 2 fbdi_position from dual
      union all select 'PROCUREMENT_BUSINESS_UNIT_NAME' column_name, 3 fbdi_position from dual
      union all select 'PARTY_SITE_NAME' column_name, 4 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE' column_name, 5 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE_NEW' column_name, 6 fbdi_position from dual
      union all select 'INACTIVE_DATE' column_name, 7 fbdi_position from dual
      union all select 'RFQ_ONLY_SITE_FLAG' column_name, 8 fbdi_position from dual
      union all select 'PURCHASING_SITE_FLAG' column_name, 9 fbdi_position from dual
      union all select 'PCARD_SITE_FLAG' column_name, 10 fbdi_position from dual
      union all select 'PAY_SITE_FLAG' column_name, 11 fbdi_position from dual
      union all select 'PRIMARY_PAY_SITE_FLAG' column_name, 12 fbdi_position from dual
      union all select 'TAX_REPORTING_SITE_FLAG' column_name, 13 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE_ALT' column_name, 14 fbdi_position from dual
      union all select 'CUSTOMER_NUM' column_name, 15 fbdi_position from dual
      union all select 'B2B_COMM_METHOD_CODE' column_name, 16 fbdi_position from dual
      union all select 'B2B_SITE_CODE' column_name, 17 fbdi_position from dual
      union all select 'SUPPLIER_NOTIF_METHOD' column_name, 18 fbdi_position from dual
      union all select 'EMAIL_ADDRESS' column_name, 19 fbdi_position from dual
      union all select 'FAX_COUNTRY_CODE' column_name, 20 fbdi_position from dual
      union all select 'FAX_AREA_CODE' column_name, 21 fbdi_position from dual
      union all select 'FAX' column_name, 22 fbdi_position from dual
      union all select 'HOLD_FLAG' column_name, 23 fbdi_position from dual
      union all select 'PURCHASING_HOLD_REASON' column_name, 24 fbdi_position from dual
      union all select 'CARRIER' column_name, 25 fbdi_position from dual
      union all select 'MODE_OF_TRANSPORT_CODE' column_name, 26 fbdi_position from dual
      union all select 'SERVICE_LEVEL_CODE' column_name, 27 fbdi_position from dual
      union all select 'FREIGHT_TERMS_LOOKUP_CODE' column_name, 28 fbdi_position from dual
      union all select 'PAY_ON_CODE' column_name, 29 fbdi_position from dual
      union all select 'FOB_LOOKUP_CODE' column_name, 30 fbdi_position from dual
      union all select 'COUNTRY_OF_ORIGIN_CODE' column_name, 31 fbdi_position from dual
      union all select 'BUYER_MANAGED_TRANSPORT_FLAG' column_name, 32 fbdi_position from dual
      union all select 'PAY_ON_USE_FLAG' column_name, 33 fbdi_position from dual
      union all select 'AGING_ONSET_POINT' column_name, 34 fbdi_position from dual
      union all select 'AGING_PERIOD_DAYS' column_name, 35 fbdi_position from dual
      union all select 'CONSUMPTION_ADVICE_FREQUENCY' column_name, 36 fbdi_position from dual
      union all select 'CONSUMPTION_ADVICE_SUMMARY' column_name, 37 fbdi_position from dual
      union all select 'DEFAULT_PAY_SITE_CODE' column_name, 38 fbdi_position from dual
      union all select 'PAY_ON_RECEIPT_SUMMARY_CODE' column_name, 39 fbdi_position from dual
      union all select 'GAPLESS_INV_NUM_FLAG' column_name, 40 fbdi_position from dual
      union all select 'SELLING_COMPANY_IDENTIFIER' column_name, 41 fbdi_position from dual
      union all select 'CREATE_DEBIT_MEMO_FLAG' column_name, 42 fbdi_position from dual
      union all select 'ENFORCE_SHIP_TO_LOCATION_CODE' column_name, 43 fbdi_position from dual
      union all select 'RECEIVING_ROUTING_ID' column_name, 44 fbdi_position from dual
      union all select 'QTY_RCV_TOLERANCE' column_name, 45 fbdi_position from dual
      union all select 'QTY_RCV_EXCEPTION_CODE' column_name, 46 fbdi_position from dual
      union all select 'DAYS_EARLY_RECEIPT_ALLOWED' column_name, 47 fbdi_position from dual
      union all select 'DAYS_LATE_RECEIPT_ALLOWED' column_name, 48 fbdi_position from dual
      union all select 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' column_name, 49 fbdi_position from dual
      union all select 'ALLOW_UNORDERED_RECEIPTS_FLAG' column_name, 50 fbdi_position from dual
      union all select 'RECEIPT_DAYS_EXCEPTION_CODE' column_name, 51 fbdi_position from dual
      union all select 'INVOICE_CURRENCY_CODE' column_name, 52 fbdi_position from dual
      union all select 'INVOICE_AMOUNT_LIMIT' column_name, 53 fbdi_position from dual
      union all select 'MATCH_OPTION' column_name, 54 fbdi_position from dual
      union all select 'MATCH_APPROVAL_LEVEL' column_name, 55 fbdi_position from dual
      union all select 'PAYMENT_CURRENCY_CODE' column_name, 56 fbdi_position from dual
      union all select 'PAYMENT_PRIORITY' column_name, 57 fbdi_position from dual
      union all select 'PAY_GROUP_LOOKUP_CODE' column_name, 58 fbdi_position from dual
      union all select 'TOLERANCE_NAME' column_name, 59 fbdi_position from dual
      union all select 'SERVICES_TOLERANCE' column_name, 60 fbdi_position from dual
      union all select 'HOLD_ALL_PAYMENTS_FLAG' column_name, 61 fbdi_position from dual
      union all select 'HOLD_UNMATCHED_INVOICES_FLAG' column_name, 62 fbdi_position from dual
      union all select 'HOLD_FUTURE_PAYMENTS_FLAG' column_name, 63 fbdi_position from dual
      union all select 'HOLD_BY' column_name, 64 fbdi_position from dual
      union all select 'PAYMENT_HOLD_DATE' column_name, 65 fbdi_position from dual
      union all select 'HOLD_REASON' column_name, 66 fbdi_position from dual
      union all select 'TERMS_NAME' column_name, 67 fbdi_position from dual
      union all select 'TERMS_DATE_BASIS' column_name, 68 fbdi_position from dual
      union all select 'PAY_DATE_BASIS_LOOKUP_CODE' column_name, 69 fbdi_position from dual
      union all select 'BANK_CHARGE_DEDUCTION_TYPE' column_name, 70 fbdi_position from dual
      union all select 'ALWAYS_TAKE_DISC_FLAG' column_name, 71 fbdi_position from dual
      union all select 'EXCLUDE_FREIGHT_FROM_DISCOUNT' column_name, 72 fbdi_position from dual
      union all select 'EXCLUDE_TAX_FROM_DISCOUNT' column_name, 73 fbdi_position from dual
      union all select 'AUTO_CALCULATE_INTEREST_FLAG' column_name, 74 fbdi_position from dual
      union all select 'VAT_CODE' column_name, 75 fbdi_position from dual
      union all select 'VAT_REGISTRATION_NUM' column_name, 76 fbdi_position from dual
      union all select 'PAYMENT_METHOD_LOOKUP_CODE' column_name, 77 fbdi_position from dual
      union all select 'DELIVERY_CHANNEL_CODE' column_name, 78 fbdi_position from dual
      union all select 'BANK_INSTRUCTION1_CODE' column_name, 79 fbdi_position from dual
      union all select 'BANK_INSTRUCTION2_CODE' column_name, 80 fbdi_position from dual
      union all select 'BANK_INSTRUCTION_DETAILS' column_name, 81 fbdi_position from dual
      union all select 'SETTLEMENT_PRIORITY' column_name, 82 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE1' column_name, 83 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE2' column_name, 84 fbdi_position from dual
      union all select 'PAYMENT_TEXT_MESSAGE3' column_name, 85 fbdi_position from dual
      union all select 'IBY_BANK_CHARGE_BEARER' column_name, 86 fbdi_position from dual
      union all select 'PAYMENT_REASON_CODE' column_name, 87 fbdi_position from dual
      union all select 'PAYMENT_REASON_COMMENTS' column_name, 88 fbdi_position from dual
      union all select 'REMIT_ADVICE_DELIVERY_METHOD' column_name, 89 fbdi_position from dual
      union all select 'REMITTANCE_EMAIL' column_name, 90 fbdi_position from dual
      union all select 'REMITTANCE_FAX' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 98 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 99 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 100 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 101 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 102 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 103 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 104 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 105 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 106 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 107 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 108 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 109 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 110 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 111 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 112 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 113 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 114 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 115 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 116 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 117 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 118 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 119 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 120 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 121 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 122 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 123 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 124 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 125 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 126 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 127 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 128 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 129 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 130 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 131 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 132 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 133 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 134 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 135 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 136 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 137 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 138 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 139 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 140 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 141 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 142 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 143 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE1' column_name, 144 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE2' column_name, 145 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE3' column_name, 146 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE4' column_name, 147 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE5' column_name, 148 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE6' column_name, 149 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE7' column_name, 150 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE8' column_name, 151 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE9' column_name, 152 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE10' column_name, 153 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE11' column_name, 154 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE12' column_name, 155 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE13' column_name, 156 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE14' column_name, 157 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE15' column_name, 158 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE16' column_name, 159 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE17' column_name, 160 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE18' column_name, 161 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE19' column_name, 162 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE20' column_name, 163 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE1' column_name, 164 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE2' column_name, 165 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE3' column_name, 166 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE4' column_name, 167 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE5' column_name, 168 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE6' column_name, 169 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE7' column_name, 170 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE8' column_name, 171 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE9' column_name, 172 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE10' column_name, 173 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP1' column_name, 174 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP2' column_name, 175 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP3' column_name, 176 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP4' column_name, 177 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP5' column_name, 178 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP6' column_name, 179 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP7' column_name, 180 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP8' column_name, 181 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP9' column_name, 182 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_TIMESTAMP10' column_name, 183 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 184 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 185 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 186 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 187 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 188 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER6' column_name, 189 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER7' column_name, 190 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER8' column_name, 191 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER9' column_name, 192 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER10' column_name, 193 fbdi_position from dual
      union all select 'PO_ACK_REQD_CODE' column_name, 194 fbdi_position from dual
      union all select 'PO_ACK_REQD_DAYS' column_name, 195 fbdi_position from dual
      union all select 'INVOICE_CHANNEL' column_name, 196 fbdi_position from dual
      union all select 'PAYEE_SERVICE_LEVEL_CODE' column_name, 197 fbdi_position from dual
      union all select 'EXCLUSIVE_PAYMENT_FLAG' column_name, 198 fbdi_position from dual
      union all select 'OVERRIDE_B2B_COMM_CODE' column_name, 199 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PozSupplierSitesInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_SITE'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PozSupplierSitesInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_SITE')
and   t."COLUMN_NAME" not in ('IMPORT_ACTION', 'VENDOR_NAME', 'PROCUREMENT_BUSINESS_UNIT_NAME', 'PARTY_SITE_NAME', 'VENDOR_SITE_CODE', 'VENDOR_SITE_CODE_NEW', 'INACTIVE_DATE', 'RFQ_ONLY_SITE_FLAG', 'PURCHASING_SITE_FLAG', 'PCARD_SITE_FLAG', 'PAY_SITE_FLAG', 'PRIMARY_PAY_SITE_FLAG', 'TAX_REPORTING_SITE_FLAG', 'VENDOR_SITE_CODE_ALT', 'CUSTOMER_NUM', 'B2B_COMM_METHOD_CODE', 'B2B_SITE_CODE', 'SUPPLIER_NOTIF_METHOD', 'EMAIL_ADDRESS', 'FAX_COUNTRY_CODE', 'FAX_AREA_CODE', 'FAX', 'HOLD_FLAG', 'PURCHASING_HOLD_REASON', 'CARRIER', 'MODE_OF_TRANSPORT_CODE', 'SERVICE_LEVEL_CODE', 'FREIGHT_TERMS_LOOKUP_CODE', 'PAY_ON_CODE', 'FOB_LOOKUP_CODE', 'COUNTRY_OF_ORIGIN_CODE', 'BUYER_MANAGED_TRANSPORT_FLAG', 'PAY_ON_USE_FLAG', 'AGING_ONSET_POINT', 'AGING_PERIOD_DAYS', 'CONSUMPTION_ADVICE_FREQUENCY', 'CONSUMPTION_ADVICE_SUMMARY', 'DEFAULT_PAY_SITE_CODE', 'PAY_ON_RECEIPT_SUMMARY_CODE', 'GAPLESS_INV_NUM_FLAG', 'SELLING_COMPANY_IDENTIFIER', 'CREATE_DEBIT_MEMO_FLAG', 'ENFORCE_SHIP_TO_LOCATION_CODE', 'RECEIVING_ROUTING_ID', 'QTY_RCV_TOLERANCE', 'QTY_RCV_EXCEPTION_CODE', 'DAYS_EARLY_RECEIPT_ALLOWED', 'DAYS_LATE_RECEIPT_ALLOWED', 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG', 'ALLOW_UNORDERED_RECEIPTS_FLAG', 'RECEIPT_DAYS_EXCEPTION_CODE', 'INVOICE_CURRENCY_CODE', 'INVOICE_AMOUNT_LIMIT', 'MATCH_OPTION', 'MATCH_APPROVAL_LEVEL', 'PAYMENT_CURRENCY_CODE', 'PAYMENT_PRIORITY', 'PAY_GROUP_LOOKUP_CODE', 'TOLERANCE_NAME', 'SERVICES_TOLERANCE', 'HOLD_ALL_PAYMENTS_FLAG', 'HOLD_UNMATCHED_INVOICES_FLAG', 'HOLD_FUTURE_PAYMENTS_FLAG', 'HOLD_BY', 'PAYMENT_HOLD_DATE', 'HOLD_REASON', 'TERMS_NAME', 'TERMS_DATE_BASIS', 'PAY_DATE_BASIS_LOOKUP_CODE', 'BANK_CHARGE_DEDUCTION_TYPE', 'ALWAYS_TAKE_DISC_FLAG', 'EXCLUDE_FREIGHT_FROM_DISCOUNT', 'EXCLUDE_TAX_FROM_DISCOUNT', 'AUTO_CALCULATE_INTEREST_FLAG', 'VAT_CODE', 'VAT_REGISTRATION_NUM', 'PAYMENT_METHOD_LOOKUP_CODE', 'DELIVERY_CHANNEL_CODE', 'BANK_INSTRUCTION1_CODE', 'BANK_INSTRUCTION2_CODE', 'BANK_INSTRUCTION_DETAILS', 'SETTLEMENT_PRIORITY', 'PAYMENT_TEXT_MESSAGE1', 'PAYMENT_TEXT_MESSAGE2', 'PAYMENT_TEXT_MESSAGE3', 'IBY_BANK_CHARGE_BEARER', 'PAYMENT_REASON_CODE', 'PAYMENT_REASON_COMMENTS', 'REMIT_ADVICE_DELIVERY_METHOD', 'REMITTANCE_EMAIL', 'REMITTANCE_FAX', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'GLOBAL_ATTRIBUTE_CATEGORY', 'GLOBAL_ATTRIBUTE1', 'GLOBAL_ATTRIBUTE2', 'GLOBAL_ATTRIBUTE3', 'GLOBAL_ATTRIBUTE4', 'GLOBAL_ATTRIBUTE5', 'GLOBAL_ATTRIBUTE6', 'GLOBAL_ATTRIBUTE7', 'GLOBAL_ATTRIBUTE8', 'GLOBAL_ATTRIBUTE9', 'GLOBAL_ATTRIBUTE10', 'GLOBAL_ATTRIBUTE11', 'GLOBAL_ATTRIBUTE12', 'GLOBAL_ATTRIBUTE13', 'GLOBAL_ATTRIBUTE14', 'GLOBAL_ATTRIBUTE15', 'GLOBAL_ATTRIBUTE16', 'GLOBAL_ATTRIBUTE17', 'GLOBAL_ATTRIBUTE18', 'GLOBAL_ATTRIBUTE19', 'GLOBAL_ATTRIBUTE20', 'GLOBAL_ATTRIBUTE_DATE1', 'GLOBAL_ATTRIBUTE_DATE2', 'GLOBAL_ATTRIBUTE_DATE3', 'GLOBAL_ATTRIBUTE_DATE4', 'GLOBAL_ATTRIBUTE_DATE5', 'GLOBAL_ATTRIBUTE_DATE6', 'GLOBAL_ATTRIBUTE_DATE7', 'GLOBAL_ATTRIBUTE_DATE8', 'GLOBAL_ATTRIBUTE_DATE9', 'GLOBAL_ATTRIBUTE_DATE10', 'GLOBAL_ATTRIBUTE_TIMESTAMP1', 'GLOBAL_ATTRIBUTE_TIMESTAMP2', 'GLOBAL_ATTRIBUTE_TIMESTAMP3', 'GLOBAL_ATTRIBUTE_TIMESTAMP4', 'GLOBAL_ATTRIBUTE_TIMESTAMP5', 'GLOBAL_ATTRIBUTE_TIMESTAMP6', 'GLOBAL_ATTRIBUTE_TIMESTAMP7', 'GLOBAL_ATTRIBUTE_TIMESTAMP8', 'GLOBAL_ATTRIBUTE_TIMESTAMP9', 'GLOBAL_ATTRIBUTE_TIMESTAMP10', 'GLOBAL_ATTRIBUTE_NUMBER1', 'GLOBAL_ATTRIBUTE_NUMBER2', 'GLOBAL_ATTRIBUTE_NUMBER3', 'GLOBAL_ATTRIBUTE_NUMBER4', 'GLOBAL_ATTRIBUTE_NUMBER5', 'GLOBAL_ATTRIBUTE_NUMBER6', 'GLOBAL_ATTRIBUTE_NUMBER7', 'GLOBAL_ATTRIBUTE_NUMBER8', 'GLOBAL_ATTRIBUTE_NUMBER9', 'GLOBAL_ATTRIBUTE_NUMBER10', 'PO_ACK_REQD_CODE', 'PO_ACK_REQD_DAYS', 'INVOICE_CHANNEL', 'PAYEE_SERVICE_LEVEL_CODE', 'EXCLUSIVE_PAYMENT_FLAG', 'OVERRIDE_B2B_COMM_CODE');

-- PozSiteAssignmentsInt.csv -> POZ_SUP_SITE_ASSN
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 2 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE' column_name, 3 fbdi_position from dual
      union all select 'PROCUREMENT_BUSINESS_UNIT_NAME' column_name, 4 fbdi_position from dual
      union all select 'BUSINESS_UNIT_NAME' column_name, 5 fbdi_position from dual
      union all select 'BILL_TO_BU_NAME' column_name, 6 fbdi_position from dual
      union all select 'SHIP_TO_LOCATION_CODE' column_name, 7 fbdi_position from dual
      union all select 'BILL_TO_LOCATION_CODE' column_name, 8 fbdi_position from dual
      union all select 'ALLOW_AWT_FLAG' column_name, 9 fbdi_position from dual
      union all select 'AWT_GROUP_NAME' column_name, 10 fbdi_position from dual
      union all select 'ACCTS_PAY_CONCAT_SEGMENTS' column_name, 11 fbdi_position from dual
      union all select 'PREPAY_CONCAT_SEGMENTS' column_name, 12 fbdi_position from dual
      union all select 'FUTURE_DATED_CONCAT_SEGMENTS' column_name, 13 fbdi_position from dual
      union all select 'DISTRIBUTION_SET_NAME' column_name, 14 fbdi_position from dual
      union all select 'INACTIVE_DATE' column_name, 15 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PozSiteAssignmentsInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_SITE_ASSN'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PozSiteAssignmentsInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_SITE_ASSN')
and   t."COLUMN_NAME" not in ('IMPORT_ACTION', 'VENDOR_NAME', 'VENDOR_SITE_CODE', 'PROCUREMENT_BUSINESS_UNIT_NAME', 'BUSINESS_UNIT_NAME', 'BILL_TO_BU_NAME', 'SHIP_TO_LOCATION_CODE', 'BILL_TO_LOCATION_CODE', 'ALLOW_AWT_FLAG', 'AWT_GROUP_NAME', 'ACCTS_PAY_CONCAT_SEGMENTS', 'PREPAY_CONCAT_SEGMENTS', 'FUTURE_DATED_CONCAT_SEGMENTS', 'DISTRIBUTION_SET_NAME', 'INACTIVE_DATE');

-- PozSupContactsInt.csv -> POZ_SUP_CONTACTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'IMPORT_ACTION' column_name, 1 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 2 fbdi_position from dual
      union all select 'PREFIX' column_name, 3 fbdi_position from dual
      union all select 'FIRST_NAME' column_name, 4 fbdi_position from dual
      union all select 'FIRST_NAME_NEW' column_name, 5 fbdi_position from dual
      union all select 'MIDDLE_NAME' column_name, 6 fbdi_position from dual
      union all select 'LAST_NAME' column_name, 7 fbdi_position from dual
      union all select 'LAST_NAME_NEW' column_name, 8 fbdi_position from dual
      union all select 'TITLE' column_name, 9 fbdi_position from dual
      union all select 'PRIMARY_ADMIN_CONTACT' column_name, 10 fbdi_position from dual
      union all select 'EMAIL_ADDRESS' column_name, 11 fbdi_position from dual
      union all select 'EMAIL_ADDRESS_NEW' column_name, 12 fbdi_position from dual
      union all select 'PHONE_COUNTRY_CODE' column_name, 13 fbdi_position from dual
      union all select 'AREA_CODE' column_name, 14 fbdi_position from dual
      union all select 'PHONE' column_name, 15 fbdi_position from dual
      union all select 'PHONE_EXTENSION' column_name, 16 fbdi_position from dual
      union all select 'FAX_COUNTRY_CODE' column_name, 17 fbdi_position from dual
      union all select 'FAX_AREA_CODE' column_name, 18 fbdi_position from dual
      union all select 'FAX' column_name, 19 fbdi_position from dual
      union all select 'MOBILE_COUNTRY_CODE' column_name, 20 fbdi_position from dual
      union all select 'MOBILE_AREA_CODE' column_name, 21 fbdi_position from dual
      union all select 'MOBILE' column_name, 22 fbdi_position from dual
      union all select 'INACTIVE_DATE' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE21' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE22' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE23' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE24' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE25' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE26' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE27' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE28' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE29' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE30' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER11' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER12' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE11' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE12' column_name, 78 fbdi_position from dual
      union all select 'USER_ACCOUNT_ACTION' column_name, 79 fbdi_position from dual
      union all select 'ROLE1' column_name, 80 fbdi_position from dual
      union all select 'ROLE2' column_name, 81 fbdi_position from dual
      union all select 'ROLE3' column_name, 82 fbdi_position from dual
      union all select 'ROLE4' column_name, 83 fbdi_position from dual
      union all select 'ROLE5' column_name, 84 fbdi_position from dual
      union all select 'ROLE6' column_name, 85 fbdi_position from dual
      union all select 'ROLE7' column_name, 86 fbdi_position from dual
      union all select 'ROLE8' column_name, 87 fbdi_position from dual
      union all select 'ROLE9' column_name, 88 fbdi_position from dual
      union all select 'ROLE10' column_name, 89 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PozSupContactsInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_CONTACTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PozSupContactsInt.csv' and f."OBJECT_CODE" = 'POZ_SUP_CONTACTS')
and   t."COLUMN_NAME" not in ('IMPORT_ACTION', 'VENDOR_NAME', 'PREFIX', 'FIRST_NAME', 'FIRST_NAME_NEW', 'MIDDLE_NAME', 'LAST_NAME', 'LAST_NAME_NEW', 'TITLE', 'PRIMARY_ADMIN_CONTACT', 'EMAIL_ADDRESS', 'EMAIL_ADDRESS_NEW', 'PHONE_COUNTRY_CODE', 'AREA_CODE', 'PHONE', 'PHONE_EXTENSION', 'FAX_COUNTRY_CODE', 'FAX_AREA_CODE', 'FAX', 'MOBILE_COUNTRY_CODE', 'MOBILE_AREA_CODE', 'MOBILE', 'INACTIVE_DATE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE21', 'ATTRIBUTE22', 'ATTRIBUTE23', 'ATTRIBUTE24', 'ATTRIBUTE25', 'ATTRIBUTE26', 'ATTRIBUTE27', 'ATTRIBUTE28', 'ATTRIBUTE29', 'ATTRIBUTE30', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_NUMBER11', 'ATTRIBUTE_NUMBER12', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_DATE11', 'ATTRIBUTE_DATE12', 'USER_ACCOUNT_ACTION', 'ROLE1', 'ROLE2', 'ROLE3', 'ROLE4', 'ROLE5', 'ROLE6', 'ROLE7', 'ROLE8', 'ROLE9', 'ROLE10');

-- PoHeadersInterfaceOrder.csv -> PO_HEADERS_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_HEADER_KEY' column_name, 1 fbdi_position from dual
      union all select 'ACTION' column_name, 2 fbdi_position from dual
      union all select 'BATCH_ID' column_name, 3 fbdi_position from dual
      union all select 'INTERFACE_SOURCE_CODE' column_name, 4 fbdi_position from dual
      union all select 'APPROVAL_ACTION' column_name, 5 fbdi_position from dual
      union all select 'DOCUMENT_NUM' column_name, 6 fbdi_position from dual
      union all select 'DOCUMENT_TYPE_CODE' column_name, 7 fbdi_position from dual
      union all select 'STYLE_DISPLAY_NAME' column_name, 8 fbdi_position from dual
      union all select 'PRC_BU_NAME' column_name, 9 fbdi_position from dual
      union all select 'REQ_BU_NAME' column_name, 10 fbdi_position from dual
      union all select 'SOLDTO_LE_NAME' column_name, 11 fbdi_position from dual
      union all select 'BILLTO_BU_NAME' column_name, 12 fbdi_position from dual
      union all select 'AGENT_NAME' column_name, 13 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 14 fbdi_position from dual
      union all select 'RATE' column_name, 15 fbdi_position from dual
      union all select 'RATE_TYPE' column_name, 16 fbdi_position from dual
      union all select 'RATE_DATE' column_name, 17 fbdi_position from dual
      union all select 'COMMENTS' column_name, 18 fbdi_position from dual
      union all select 'BILL_TO_LOCATION' column_name, 19 fbdi_position from dual
      union all select 'SHIP_TO_LOCATION' column_name, 20 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 21 fbdi_position from dual
      union all select 'VENDOR_NUM' column_name, 22 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE' column_name, 23 fbdi_position from dual
      union all select 'VENDOR_CONTACT' column_name, 24 fbdi_position from dual
      union all select 'VENDOR_DOC_NUM' column_name, 25 fbdi_position from dual
      union all select 'FOB' column_name, 26 fbdi_position from dual
      union all select 'FREIGHT_CARRIER' column_name, 27 fbdi_position from dual
      union all select 'FREIGHT_TERMS' column_name, 28 fbdi_position from dual
      union all select 'PAY_ON_CODE' column_name, 29 fbdi_position from dual
      union all select 'PAYMENT_TERMS' column_name, 30 fbdi_position from dual
      union all select 'ORIGINATOR_ROLE' column_name, 31 fbdi_position from dual
      union all select 'CHANGE_ORDER_DESC' column_name, 32 fbdi_position from dual
      union all select 'ACCEPTANCE_REQUIRED_FLAG' column_name, 33 fbdi_position from dual
      union all select 'ACCEPTANCE_WITHIN_DAYS' column_name, 34 fbdi_position from dual
      union all select 'SUPPLIER_NOTIF_METHOD' column_name, 35 fbdi_position from dual
      union all select 'FAX' column_name, 36 fbdi_position from dual
      union all select 'EMAIL_ADDRESS' column_name, 37 fbdi_position from dual
      union all select 'CONFIRMING_ORDER_FLAG' column_name, 38 fbdi_position from dual
      union all select 'NOTE_TO_VENDOR' column_name, 39 fbdi_position from dual
      union all select 'NOTE_TO_RECEIVER' column_name, 40 fbdi_position from dual
      union all select 'DEFAULT_TAXATION_COUNTRY' column_name, 41 fbdi_position from dual
      union all select 'TAX_DOCUMENT_SUBTYPE' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 93 fbdi_position from dual
      union all select 'AGENT_EMAIL_ADDRESS' column_name, 94 fbdi_position from dual
      union all select 'MODE_OF_TRANSPORT' column_name, 95 fbdi_position from dual
      union all select 'SERVICE_LEVEL' column_name, 96 fbdi_position from dual
      union all select 'FIRST_PTY_REG_NUM' column_name, 97 fbdi_position from dual
      union all select 'THIRD_PTY_REG_NUM' column_name, 98 fbdi_position from dual
      union all select 'BUYER_MANAGED_TRANSPORT_FLAG' column_name, 99 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoHeadersInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_HEADERS_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoHeadersInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_HEADERS_INT')
and   t."COLUMN_NAME" not in ('INTERFACE_HEADER_KEY', 'ACTION', 'BATCH_ID', 'INTERFACE_SOURCE_CODE', 'APPROVAL_ACTION', 'DOCUMENT_NUM', 'DOCUMENT_TYPE_CODE', 'STYLE_DISPLAY_NAME', 'PRC_BU_NAME', 'REQ_BU_NAME', 'SOLDTO_LE_NAME', 'BILLTO_BU_NAME', 'AGENT_NAME', 'CURRENCY_CODE', 'RATE', 'RATE_TYPE', 'RATE_DATE', 'COMMENTS', 'BILL_TO_LOCATION', 'SHIP_TO_LOCATION', 'VENDOR_NAME', 'VENDOR_NUM', 'VENDOR_SITE_CODE', 'VENDOR_CONTACT', 'VENDOR_DOC_NUM', 'FOB', 'FREIGHT_CARRIER', 'FREIGHT_TERMS', 'PAY_ON_CODE', 'PAYMENT_TERMS', 'ORIGINATOR_ROLE', 'CHANGE_ORDER_DESC', 'ACCEPTANCE_REQUIRED_FLAG', 'ACCEPTANCE_WITHIN_DAYS', 'SUPPLIER_NOTIF_METHOD', 'FAX', 'EMAIL_ADDRESS', 'CONFIRMING_ORDER_FLAG', 'NOTE_TO_VENDOR', 'NOTE_TO_RECEIVER', 'DEFAULT_TAXATION_COUNTRY', 'TAX_DOCUMENT_SUBTYPE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'AGENT_EMAIL_ADDRESS', 'MODE_OF_TRANSPORT', 'SERVICE_LEVEL', 'FIRST_PTY_REG_NUM', 'THIRD_PTY_REG_NUM', 'BUYER_MANAGED_TRANSPORT_FLAG');

-- PoLinesInterfaceOrder.csv -> PO_LINES_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_LINE_KEY' column_name, 1 fbdi_position from dual
      union all select 'INTERFACE_HEADER_KEY' column_name, 2 fbdi_position from dual
      union all select 'ACTION' column_name, 3 fbdi_position from dual
      union all select 'LINE_NUM' column_name, 4 fbdi_position from dual
      union all select 'LINE_TYPE' column_name, 5 fbdi_position from dual
      union all select 'ITEM' column_name, 6 fbdi_position from dual
      union all select 'ITEM_DESCRIPTION' column_name, 7 fbdi_position from dual
      union all select 'ITEM_REVISION' column_name, 8 fbdi_position from dual
      union all select 'CATEGORY' column_name, 9 fbdi_position from dual
      union all select 'AMOUNT' column_name, 10 fbdi_position from dual
      union all select 'QUANTITY' column_name, 11 fbdi_position from dual
      union all select 'UNIT_OF_MEASURE' column_name, 12 fbdi_position from dual
      union all select 'UNIT_PRICE' column_name, 13 fbdi_position from dual
      union all select 'SECONDARY_QUANTITY' column_name, 14 fbdi_position from dual
      union all select 'SECONDARY_UNIT_OF_MEASURE' column_name, 15 fbdi_position from dual
      union all select 'VENDOR_PRODUCT_NUM' column_name, 16 fbdi_position from dual
      union all select 'NEGOTIATED_BY_PREPARER_FLAG' column_name, 17 fbdi_position from dual
      union all select 'HAZARD_CLASS' column_name, 18 fbdi_position from dual
      union all select 'UN_NUMBER' column_name, 19 fbdi_position from dual
      union all select 'NOTE_TO_VENDOR' column_name, 20 fbdi_position from dual
      union all select 'NOTE_TO_RECEIVER' column_name, 21 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE_CATEGORY_LINES' column_name, 22 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE1' column_name, 23 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE2' column_name, 24 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE3' column_name, 25 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE4' column_name, 26 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE5' column_name, 27 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE6' column_name, 28 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE7' column_name, 29 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE8' column_name, 30 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE9' column_name, 31 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE10' column_name, 32 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE11' column_name, 33 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE12' column_name, 34 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE13' column_name, 35 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE14' column_name, 36 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE15' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 72 fbdi_position from dual
      union all select 'UNIT_WEIGHT' column_name, 73 fbdi_position from dual
      union all select 'WEIGHT_UOM_CODE' column_name, 74 fbdi_position from dual
      union all select 'WEIGHT_UNIT_OF_MEASURE' column_name, 75 fbdi_position from dual
      union all select 'UNIT_VOLUME' column_name, 76 fbdi_position from dual
      union all select 'VOLUME_UOM_CODE' column_name, 77 fbdi_position from dual
      union all select 'VOLUME_UNIT_OF_MEASURE' column_name, 78 fbdi_position from dual
      union all select 'TEMPLATE_NAME' column_name, 79 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE_CATEGORY' column_name, 80 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE1' column_name, 81 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE2' column_name, 82 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE3' column_name, 83 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE4' column_name, 84 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE5' column_name, 85 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE6' column_name, 86 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE7' column_name, 87 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE8' column_name, 88 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE9' column_name, 89 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE10' column_name, 90 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE11' column_name, 91 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE12' column_name, 92 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE13' column_name, 93 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE14' column_name, 94 fbdi_position from dual
      union all select 'ITEM_ATTRIBUTE15' column_name, 95 fbdi_position from dual
      union all select 'SOURCE_AGREEMENT_PRC_BU_NAME' column_name, 96 fbdi_position from dual
      union all select 'SOURCE_AGREEMENT' column_name, 97 fbdi_position from dual
      union all select 'SOURCE_AGREEMENT_LINE' column_name, 98 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoLinesInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_LINES_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoLinesInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_LINES_INT')
and   t."COLUMN_NAME" not in ('INTERFACE_LINE_KEY', 'INTERFACE_HEADER_KEY', 'ACTION', 'LINE_NUM', 'LINE_TYPE', 'ITEM', 'ITEM_DESCRIPTION', 'ITEM_REVISION', 'CATEGORY', 'AMOUNT', 'QUANTITY', 'UNIT_OF_MEASURE', 'UNIT_PRICE', 'SECONDARY_QUANTITY', 'SECONDARY_UNIT_OF_MEASURE', 'VENDOR_PRODUCT_NUM', 'NEGOTIATED_BY_PREPARER_FLAG', 'HAZARD_CLASS', 'UN_NUMBER', 'NOTE_TO_VENDOR', 'NOTE_TO_RECEIVER', 'LINE_ATTRIBUTE_CATEGORY_LINES', 'LINE_ATTRIBUTE1', 'LINE_ATTRIBUTE2', 'LINE_ATTRIBUTE3', 'LINE_ATTRIBUTE4', 'LINE_ATTRIBUTE5', 'LINE_ATTRIBUTE6', 'LINE_ATTRIBUTE7', 'LINE_ATTRIBUTE8', 'LINE_ATTRIBUTE9', 'LINE_ATTRIBUTE10', 'LINE_ATTRIBUTE11', 'LINE_ATTRIBUTE12', 'LINE_ATTRIBUTE13', 'LINE_ATTRIBUTE14', 'LINE_ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'UNIT_WEIGHT', 'WEIGHT_UOM_CODE', 'WEIGHT_UNIT_OF_MEASURE', 'UNIT_VOLUME', 'VOLUME_UOM_CODE', 'VOLUME_UNIT_OF_MEASURE', 'TEMPLATE_NAME', 'ITEM_ATTRIBUTE_CATEGORY', 'ITEM_ATTRIBUTE1', 'ITEM_ATTRIBUTE2', 'ITEM_ATTRIBUTE3', 'ITEM_ATTRIBUTE4', 'ITEM_ATTRIBUTE5', 'ITEM_ATTRIBUTE6', 'ITEM_ATTRIBUTE7', 'ITEM_ATTRIBUTE8', 'ITEM_ATTRIBUTE9', 'ITEM_ATTRIBUTE10', 'ITEM_ATTRIBUTE11', 'ITEM_ATTRIBUTE12', 'ITEM_ATTRIBUTE13', 'ITEM_ATTRIBUTE14', 'ITEM_ATTRIBUTE15', 'SOURCE_AGREEMENT_PRC_BU_NAME', 'SOURCE_AGREEMENT', 'SOURCE_AGREEMENT_LINE');

-- PoLineLocationsInterfaceOrder.csv -> PO_LINE_LOCS_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_LINE_LOCATION_KEY' column_name, 1 fbdi_position from dual
      union all select 'INTERFACE_LINE_KEY' column_name, 2 fbdi_position from dual
      union all select 'SHIPMENT_NUM' column_name, 3 fbdi_position from dual
      union all select 'SHIP_TO_LOCATION' column_name, 4 fbdi_position from dual
      union all select 'SHIP_TO_ORGANIZATION_CODE' column_name, 5 fbdi_position from dual
      union all select 'AMOUNT' column_name, 6 fbdi_position from dual
      union all select 'QUANTITY' column_name, 7 fbdi_position from dual
      union all select 'NEED_BY_DATE' column_name, 8 fbdi_position from dual
      union all select 'PROMISED_DATE' column_name, 9 fbdi_position from dual
      union all select 'SECONDARY_QUANTITY' column_name, 10 fbdi_position from dual
      union all select 'SECONDARY_UNIT_OF_MEASURE' column_name, 11 fbdi_position from dual
      union all select 'DESTINATION_TYPE_CODE' column_name, 12 fbdi_position from dual
      union all select 'ACCRUE_ON_RECEIPT_FLAG' column_name, 13 fbdi_position from dual
      union all select 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' column_name, 14 fbdi_position from dual
      union all select 'ASSESSABLE_VALUE' column_name, 15 fbdi_position from dual
      union all select 'DAYS_EARLY_RECEIPT_ALLOWED' column_name, 16 fbdi_position from dual
      union all select 'DAYS_LATE_RECEIPT_ALLOWED' column_name, 17 fbdi_position from dual
      union all select 'ENFORCE_SHIP_TO_LOCATION_CODE' column_name, 18 fbdi_position from dual
      union all select 'INSPECTION_REQUIRED_FLAG' column_name, 19 fbdi_position from dual
      union all select 'RECEIPT_REQUIRED_FLAG' column_name, 20 fbdi_position from dual
      union all select 'INVOICE_CLOSE_TOLERANCE' column_name, 21 fbdi_position from dual
      union all select 'RECEIVE_CLOSE_TOLERANCE' column_name, 22 fbdi_position from dual
      union all select 'QTY_RCV_TOLERANCE' column_name, 23 fbdi_position from dual
      union all select 'QTY_RCV_EXCEPTION_CODE' column_name, 24 fbdi_position from dual
      union all select 'RECEIPT_DAYS_EXCEPTION_CODE' column_name, 25 fbdi_position from dual
      union all select 'RECEIVING_ROUTING' column_name, 26 fbdi_position from dual
      union all select 'NOTE_TO_RECEIVER' column_name, 27 fbdi_position from dual
      union all select 'INPUT_TAX_CLASSIFICATION_CODE' column_name, 28 fbdi_position from dual
      union all select 'LINE_INTENDED_USE' column_name, 29 fbdi_position from dual
      union all select 'PRODUCT_CATEGORY' column_name, 30 fbdi_position from dual
      union all select 'PRODUCT_FISC_CLASSIFICATION' column_name, 31 fbdi_position from dual
      union all select 'PRODUCT_TYPE' column_name, 32 fbdi_position from dual
      union all select 'TRX_BUSINESS_CATEGORY' column_name, 33 fbdi_position from dual
      union all select 'USER_DEFINED_FISC_CLASS' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 85 fbdi_position from dual
      union all select 'FREIGHT_CARRIER' column_name, 86 fbdi_position from dual
      union all select 'MODE_OF_TRANSPORT' column_name, 87 fbdi_position from dual
      union all select 'SERVICE_LEVEL' column_name, 88 fbdi_position from dual
      union all select 'FINAL_DISCHARGE_LOCATION_CODE' column_name, 89 fbdi_position from dual
      union all select 'REQUESTED_SHIP_DATE' column_name, 90 fbdi_position from dual
      union all select 'PROMISED_SHIP_DATE' column_name, 91 fbdi_position from dual
      union all select 'REQUESTED_DELIVERY_DATE' column_name, 92 fbdi_position from dual
      union all select 'PROMISED_DELIVERY_DATE' column_name, 93 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoLineLocationsInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_LINE_LOCS_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoLineLocationsInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_LINE_LOCS_INT')
and   t."COLUMN_NAME" not in ('INTERFACE_LINE_LOCATION_KEY', 'INTERFACE_LINE_KEY', 'SHIPMENT_NUM', 'SHIP_TO_LOCATION', 'SHIP_TO_ORGANIZATION_CODE', 'AMOUNT', 'QUANTITY', 'NEED_BY_DATE', 'PROMISED_DATE', 'SECONDARY_QUANTITY', 'SECONDARY_UNIT_OF_MEASURE', 'DESTINATION_TYPE_CODE', 'ACCRUE_ON_RECEIPT_FLAG', 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG', 'ASSESSABLE_VALUE', 'DAYS_EARLY_RECEIPT_ALLOWED', 'DAYS_LATE_RECEIPT_ALLOWED', 'ENFORCE_SHIP_TO_LOCATION_CODE', 'INSPECTION_REQUIRED_FLAG', 'RECEIPT_REQUIRED_FLAG', 'INVOICE_CLOSE_TOLERANCE', 'RECEIVE_CLOSE_TOLERANCE', 'QTY_RCV_TOLERANCE', 'QTY_RCV_EXCEPTION_CODE', 'RECEIPT_DAYS_EXCEPTION_CODE', 'RECEIVING_ROUTING', 'NOTE_TO_RECEIVER', 'INPUT_TAX_CLASSIFICATION_CODE', 'LINE_INTENDED_USE', 'PRODUCT_CATEGORY', 'PRODUCT_FISC_CLASSIFICATION', 'PRODUCT_TYPE', 'TRX_BUSINESS_CATEGORY', 'USER_DEFINED_FISC_CLASS', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'FREIGHT_CARRIER', 'MODE_OF_TRANSPORT', 'SERVICE_LEVEL', 'FINAL_DISCHARGE_LOCATION_CODE', 'REQUESTED_SHIP_DATE', 'PROMISED_SHIP_DATE', 'REQUESTED_DELIVERY_DATE', 'PROMISED_DELIVERY_DATE');

-- PoDistributionsInterfaceOrder.csv -> PO_DISTS_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_DISTRIBUTION_KEY' column_name, 1 fbdi_position from dual
      union all select 'INTERFACE_LINE_LOCATION_KEY' column_name, 2 fbdi_position from dual
      union all select 'DISTRIBUTION_NUM' column_name, 3 fbdi_position from dual
      union all select 'DELIVER_TO_LOCATION' column_name, 4 fbdi_position from dual
      union all select 'DELIVER_TO_PERSON_FULL_NAME' column_name, 5 fbdi_position from dual
      union all select 'DESTINATION_SUBINVENTORY' column_name, 6 fbdi_position from dual
      union all select 'AMOUNT_ORDERED' column_name, 7 fbdi_position from dual
      union all select 'QUANTITY_ORDERED' column_name, 8 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT1' column_name, 9 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT2' column_name, 10 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT3' column_name, 11 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT4' column_name, 12 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT5' column_name, 13 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT6' column_name, 14 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT7' column_name, 15 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT8' column_name, 16 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT9' column_name, 17 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT10' column_name, 18 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT11' column_name, 19 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT12' column_name, 20 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT13' column_name, 21 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT14' column_name, 22 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT15' column_name, 23 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT16' column_name, 24 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT17' column_name, 25 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT18' column_name, 26 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT19' column_name, 27 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT20' column_name, 28 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT21' column_name, 29 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT22' column_name, 30 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT23' column_name, 31 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT24' column_name, 32 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT25' column_name, 33 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT26' column_name, 34 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT27' column_name, 35 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT28' column_name, 36 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT29' column_name, 37 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT30' column_name, 38 fbdi_position from dual
      union all select 'DESTINATION_CONTEXT' column_name, 39 fbdi_position from dual
      union all select 'PROJECT' column_name, 40 fbdi_position from dual
      union all select 'TASK' column_name, 41 fbdi_position from dual
      union all select 'PJC_EXPENDITURE_ITEM_DATE' column_name, 42 fbdi_position from dual
      union all select 'EXPENDITURE' column_name, 43 fbdi_position from dual
      union all select 'EXPENDITURE_ORGANIZATION' column_name, 44 fbdi_position from dual
      union all select 'PJC_BILLABLE_FLAG' column_name, 45 fbdi_position from dual
      union all select 'PJC_CAPITALIZABLE_FLAG' column_name, 46 fbdi_position from dual
      union all select 'PJC_WORK_TYPE' column_name, 47 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE1' column_name, 48 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE2' column_name, 49 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE3' column_name, 50 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE4' column_name, 51 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE5' column_name, 52 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE6' column_name, 53 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE7' column_name, 54 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE8' column_name, 55 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE9' column_name, 56 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE10' column_name, 57 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE1' column_name, 58 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE2' column_name, 59 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE3' column_name, 60 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE4' column_name, 61 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE5' column_name, 62 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE6' column_name, 63 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE7' column_name, 64 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE8' column_name, 65 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE9' column_name, 66 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE10' column_name, 67 fbdi_position from dual
      union all select 'RATE' column_name, 68 fbdi_position from dual
      union all select 'RATE_DATE' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 98 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 99 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 100 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 101 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 102 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 103 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 104 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 105 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 106 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 107 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 108 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 109 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 110 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 111 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 112 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 113 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 114 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 115 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 116 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 117 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 118 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 119 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 120 fbdi_position from dual
      union all select 'DELIVER_TO_PERSON_EMAIL_ADDR' column_name, 121 fbdi_position from dual
      union all select 'BUDGET_DATE' column_name, 122 fbdi_position from dual
      union all select 'PJC_CONTRACT_NUMBER' column_name, 123 fbdi_position from dual
      union all select 'PJC_FUNDING_SOURCE' column_name, 124 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoDistributionsInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_DISTS_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoDistributionsInterfaceOrder.csv' and f."OBJECT_CODE" = 'PO_DISTS_INT')
and   t."COLUMN_NAME" not in ('INTERFACE_DISTRIBUTION_KEY', 'INTERFACE_LINE_LOCATION_KEY', 'DISTRIBUTION_NUM', 'DELIVER_TO_LOCATION', 'DELIVER_TO_PERSON_FULL_NAME', 'DESTINATION_SUBINVENTORY', 'AMOUNT_ORDERED', 'QUANTITY_ORDERED', 'CHARGE_ACCOUNT_SEGMENT1', 'CHARGE_ACCOUNT_SEGMENT2', 'CHARGE_ACCOUNT_SEGMENT3', 'CHARGE_ACCOUNT_SEGMENT4', 'CHARGE_ACCOUNT_SEGMENT5', 'CHARGE_ACCOUNT_SEGMENT6', 'CHARGE_ACCOUNT_SEGMENT7', 'CHARGE_ACCOUNT_SEGMENT8', 'CHARGE_ACCOUNT_SEGMENT9', 'CHARGE_ACCOUNT_SEGMENT10', 'CHARGE_ACCOUNT_SEGMENT11', 'CHARGE_ACCOUNT_SEGMENT12', 'CHARGE_ACCOUNT_SEGMENT13', 'CHARGE_ACCOUNT_SEGMENT14', 'CHARGE_ACCOUNT_SEGMENT15', 'CHARGE_ACCOUNT_SEGMENT16', 'CHARGE_ACCOUNT_SEGMENT17', 'CHARGE_ACCOUNT_SEGMENT18', 'CHARGE_ACCOUNT_SEGMENT19', 'CHARGE_ACCOUNT_SEGMENT20', 'CHARGE_ACCOUNT_SEGMENT21', 'CHARGE_ACCOUNT_SEGMENT22', 'CHARGE_ACCOUNT_SEGMENT23', 'CHARGE_ACCOUNT_SEGMENT24', 'CHARGE_ACCOUNT_SEGMENT25', 'CHARGE_ACCOUNT_SEGMENT26', 'CHARGE_ACCOUNT_SEGMENT27', 'CHARGE_ACCOUNT_SEGMENT28', 'CHARGE_ACCOUNT_SEGMENT29', 'CHARGE_ACCOUNT_SEGMENT30', 'DESTINATION_CONTEXT', 'PROJECT', 'TASK', 'PJC_EXPENDITURE_ITEM_DATE', 'EXPENDITURE', 'EXPENDITURE_ORGANIZATION', 'PJC_BILLABLE_FLAG', 'PJC_CAPITALIZABLE_FLAG', 'PJC_WORK_TYPE', 'PJC_RESERVED_ATTRIBUTE1', 'PJC_RESERVED_ATTRIBUTE2', 'PJC_RESERVED_ATTRIBUTE3', 'PJC_RESERVED_ATTRIBUTE4', 'PJC_RESERVED_ATTRIBUTE5', 'PJC_RESERVED_ATTRIBUTE6', 'PJC_RESERVED_ATTRIBUTE7', 'PJC_RESERVED_ATTRIBUTE8', 'PJC_RESERVED_ATTRIBUTE9', 'PJC_RESERVED_ATTRIBUTE10', 'PJC_USER_DEF_ATTRIBUTE1', 'PJC_USER_DEF_ATTRIBUTE2', 'PJC_USER_DEF_ATTRIBUTE3', 'PJC_USER_DEF_ATTRIBUTE4', 'PJC_USER_DEF_ATTRIBUTE5', 'PJC_USER_DEF_ATTRIBUTE6', 'PJC_USER_DEF_ATTRIBUTE7', 'PJC_USER_DEF_ATTRIBUTE8', 'PJC_USER_DEF_ATTRIBUTE9', 'PJC_USER_DEF_ATTRIBUTE10', 'RATE', 'RATE_DATE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'DELIVER_TO_PERSON_EMAIL_ADDR', 'BUDGET_DATE', 'PJC_CONTRACT_NUMBER', 'PJC_FUNDING_SOURCE');

-- HzImpPartiesT.csv -> HZ_PARTIES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BATCH_ID' column_name, 1 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
      union all select 'INSERT_UPDATE_FLAG' column_name, 4 fbdi_position from dual
      union all select 'PARTY_TYPE' column_name, 5 fbdi_position from dual
      union all select 'PARTY_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'SALUTATION' column_name, 7 fbdi_position from dual
      union all select 'PARTY_USAGE_CODE' column_name, 8 fbdi_position from dual
      union all select 'JGZZ_FISCAL_CODE' column_name, 9 fbdi_position from dual
      union all select 'ORGANIZATION_NAME' column_name, 10 fbdi_position from dual
      union all select 'DUNS_NUMBER_C' column_name, 11 fbdi_position from dual
      union all select 'PERSON_FIRST_NAME' column_name, 12 fbdi_position from dual
      union all select 'PERSON_LAST_NAME' column_name, 13 fbdi_position from dual
      union all select 'PERSON_LAST_NAME_PREFIX' column_name, 14 fbdi_position from dual
      union all select 'PERSON_SECOND_LAST_NAME' column_name, 15 fbdi_position from dual
      union all select 'PERSON_MIDDLE_NAME' column_name, 16 fbdi_position from dual
      union all select 'PERSON_NAME_SUFFIX' column_name, 17 fbdi_position from dual
      union all select 'PERSON_TITLE' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 39 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'HzImpPartiesT.csv' and f."OBJECT_CODE" = 'HZ_PARTIES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'HzImpPartiesT.csv' and f."OBJECT_CODE" = 'HZ_PARTIES')
and   t."COLUMN_NAME" not in ('BATCH_ID', 'PARTY_ORIG_SYSTEM', 'PARTY_ORIG_SYSTEM_REFERENCE', 'INSERT_UPDATE_FLAG', 'PARTY_TYPE', 'PARTY_NUMBER', 'SALUTATION', 'PARTY_USAGE_CODE', 'JGZZ_FISCAL_CODE', 'ORGANIZATION_NAME', 'DUNS_NUMBER_C', 'PERSON_FIRST_NAME', 'PERSON_LAST_NAME', 'PERSON_LAST_NAME_PREFIX', 'PERSON_SECOND_LAST_NAME', 'PERSON_MIDDLE_NAME', 'PERSON_NAME_SUFFIX', 'PERSON_TITLE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20');

-- HzImpLocationsT.csv -> HZ_LOCATIONS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BATCH_ID' column_name, 1 fbdi_position from dual
      union all select 'LOCATION_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
      union all select 'LOCATION_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
      union all select 'INSERT_UPDATE_FLAG' column_name, 4 fbdi_position from dual
      union all select 'COUNTRY' column_name, 5 fbdi_position from dual
      union all select 'ADDRESS1' column_name, 6 fbdi_position from dual
      union all select 'ADDRESS2' column_name, 7 fbdi_position from dual
      union all select 'ADDRESS3' column_name, 8 fbdi_position from dual
      union all select 'ADDRESS4' column_name, 9 fbdi_position from dual
      union all select 'CITY' column_name, 10 fbdi_position from dual
      union all select 'STATE' column_name, 11 fbdi_position from dual
      union all select 'PROVINCE' column_name, 12 fbdi_position from dual
      union all select 'COUNTY' column_name, 13 fbdi_position from dual
      union all select 'POSTAL_CODE' column_name, 14 fbdi_position from dual
      union all select 'POSTAL_PLUS4_CODE' column_name, 15 fbdi_position from dual
      union all select 'LOCATION_LANGUAGE' column_name, 16 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 17 fbdi_position from dual
      union all select 'SHORT_DESCRIPTION' column_name, 18 fbdi_position from dual
      union all select 'SALES_TAX_GEOCODE' column_name, 19 fbdi_position from dual
      union all select 'SALES_TAX_INSIDE_CITY_LIMITS' column_name, 20 fbdi_position from dual
      union all select 'TIMEZONE_CODE' column_name, 21 fbdi_position from dual
      union all select 'ADDRESS1_STD' column_name, 22 fbdi_position from dual
      union all select 'ADAPTER_CONTENT_SOURCE' column_name, 23 fbdi_position from dual
      union all select 'ADDR_VALID_STATUS_CODE' column_name, 24 fbdi_position from dual
      union all select 'DATE_VALIDATED' column_name, 25 fbdi_position from dual
      union all select 'ADDRESS_EFFECTIVE_DATE' column_name, 26 fbdi_position from dual
      union all select 'ADDRESS_EXPIRATION_DATE' column_name, 27 fbdi_position from dual
      union all select 'VALIDATED_FLAG' column_name, 28 fbdi_position from dual
      union all select 'DO_NOT_VALIDATE_FLAG' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 50 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'HzImpLocationsT.csv' and f."OBJECT_CODE" = 'HZ_LOCATIONS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'HzImpLocationsT.csv' and f."OBJECT_CODE" = 'HZ_LOCATIONS')
and   t."COLUMN_NAME" not in ('BATCH_ID', 'LOCATION_ORIG_SYSTEM', 'LOCATION_ORIG_SYSTEM_REFERENCE', 'INSERT_UPDATE_FLAG', 'COUNTRY', 'ADDRESS1', 'ADDRESS2', 'ADDRESS3', 'ADDRESS4', 'CITY', 'STATE', 'PROVINCE', 'COUNTY', 'POSTAL_CODE', 'POSTAL_PLUS4_CODE', 'LOCATION_LANGUAGE', 'DESCRIPTION', 'SHORT_DESCRIPTION', 'SALES_TAX_GEOCODE', 'SALES_TAX_INSIDE_CITY_LIMITS', 'TIMEZONE_CODE', 'ADDRESS1_STD', 'ADAPTER_CONTENT_SOURCE', 'ADDR_VALID_STATUS_CODE', 'DATE_VALIDATED', 'ADDRESS_EFFECTIVE_DATE', 'ADDRESS_EXPIRATION_DATE', 'VALIDATED_FLAG', 'DO_NOT_VALIDATE_FLAG', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20');

-- HzImpPartySitesT.csv -> HZ_PARTY_SITES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BATCH_ID' column_name, 1 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
      union all select 'SITE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
      union all select 'SITE_ORIG_SYSTEM_REFERENCE' column_name, 5 fbdi_position from dual
      union all select 'LOCATION_ORIG_SYSTEM' column_name, 6 fbdi_position from dual
      union all select 'LOCATION_ORIG_SYSTEM_REFERENCE' column_name, 7 fbdi_position from dual
      union all select 'INSERT_UPDATE_FLAG' column_name, 8 fbdi_position from dual
      union all select 'PARTY_SITE_NAME' column_name, 9 fbdi_position from dual
      union all select 'PARTY_SITE_NUMBER' column_name, 10 fbdi_position from dual
      union all select 'START_DATE_ACTIVE' column_name, 11 fbdi_position from dual
      union all select 'END_DATE_ACTIVE' column_name, 12 fbdi_position from dual
      union all select 'MAILSTOP' column_name, 13 fbdi_position from dual
      union all select 'IDENTIFYING_ADDRESS_FLAG' column_name, 14 fbdi_position from dual
      union all select 'PARTY_SITE_LANGUAGE' column_name, 15 fbdi_position from dual
      union all select 'REL_ORIG_SYSTEM' column_name, 16 fbdi_position from dual
      union all select 'REL_ORIG_SYSTEM_REFERENCE' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 38 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'HzImpPartySitesT.csv' and f."OBJECT_CODE" = 'HZ_PARTY_SITES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'HzImpPartySitesT.csv' and f."OBJECT_CODE" = 'HZ_PARTY_SITES')
and   t."COLUMN_NAME" not in ('BATCH_ID', 'PARTY_ORIG_SYSTEM', 'PARTY_ORIG_SYSTEM_REFERENCE', 'SITE_ORIG_SYSTEM', 'SITE_ORIG_SYSTEM_REFERENCE', 'LOCATION_ORIG_SYSTEM', 'LOCATION_ORIG_SYSTEM_REFERENCE', 'INSERT_UPDATE_FLAG', 'PARTY_SITE_NAME', 'PARTY_SITE_NUMBER', 'START_DATE_ACTIVE', 'END_DATE_ACTIVE', 'MAILSTOP', 'IDENTIFYING_ADDRESS_FLAG', 'PARTY_SITE_LANGUAGE', 'REL_ORIG_SYSTEM', 'REL_ORIG_SYSTEM_REFERENCE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20');

-- HzImpPartySiteUsesT.csv -> HZ_PARTY_SITE_USES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BATCH_ID' column_name, 1 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
      union all select 'SITE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
      union all select 'SITE_ORIG_SYSTEM_REFERENCE' column_name, 5 fbdi_position from dual
      union all select 'SITE_USE_TYPE' column_name, 6 fbdi_position from dual
      union all select 'PRIMARY_FLAG' column_name, 7 fbdi_position from dual
      union all select 'INSERT_UPDATE_FLAG' column_name, 8 fbdi_position from dual
      union all select 'START_DATE' column_name, 9 fbdi_position from dual
      union all select 'END_DATE' column_name, 10 fbdi_position from dual
      union all select 'SITEUSE_ORIG_SYSTEM' column_name, 11 fbdi_position from dual
      union all select 'SITEUSE_ORIG_SYSTEM_REF' column_name, 12 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 13 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 14 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 15 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 16 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 33 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'HzImpPartySiteUsesT.csv' and f."OBJECT_CODE" = 'HZ_PARTY_SITE_USES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'HzImpPartySiteUsesT.csv' and f."OBJECT_CODE" = 'HZ_PARTY_SITE_USES')
and   t."COLUMN_NAME" not in ('BATCH_ID', 'PARTY_ORIG_SYSTEM', 'PARTY_ORIG_SYSTEM_REFERENCE', 'SITE_ORIG_SYSTEM', 'SITE_ORIG_SYSTEM_REFERENCE', 'SITE_USE_TYPE', 'PRIMARY_FLAG', 'INSERT_UPDATE_FLAG', 'START_DATE', 'END_DATE', 'SITEUSE_ORIG_SYSTEM', 'SITEUSE_ORIG_SYSTEM_REF', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20');

-- HzImpAccountsT.csv -> HZ_ACCOUNTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BATCH_ID' column_name, 1 fbdi_position from dual
      union all select 'CUST_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
      union all select 'CUST_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
      union all select 'PARTY_ORIG_SYSTEM_REFERENCE' column_name, 5 fbdi_position from dual
      union all select 'ACCOUNT_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'INSERT_UPDATE_FLAG' column_name, 7 fbdi_position from dual
      union all select 'CUSTOMER_TYPE' column_name, 8 fbdi_position from dual
      union all select 'CUSTOMER_CLASS_CODE' column_name, 9 fbdi_position from dual
      union all select 'ACCOUNT_NAME' column_name, 10 fbdi_position from dual
      union all select 'ACCOUNT_ESTABLISHED_DATE' column_name, 11 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 12 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 13 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 14 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 15 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 16 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 32 fbdi_position from dual
      union all select 'ACCOUNT_TERMINATION_DATE' column_name, 33 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'HzImpAccountsT.csv' and f."OBJECT_CODE" = 'HZ_ACCOUNTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'HzImpAccountsT.csv' and f."OBJECT_CODE" = 'HZ_ACCOUNTS')
and   t."COLUMN_NAME" not in ('BATCH_ID', 'CUST_ORIG_SYSTEM', 'CUST_ORIG_SYSTEM_REFERENCE', 'PARTY_ORIG_SYSTEM', 'PARTY_ORIG_SYSTEM_REFERENCE', 'ACCOUNT_NUMBER', 'INSERT_UPDATE_FLAG', 'CUSTOMER_TYPE', 'CUSTOMER_CLASS_CODE', 'ACCOUNT_NAME', 'ACCOUNT_ESTABLISHED_DATE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ACCOUNT_TERMINATION_DATE');

-- HzImpAcctSitesT.csv -> HZ_ACCT_SITES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BATCH_ID' column_name, 1 fbdi_position from dual
      union all select 'CUST_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
      union all select 'CUST_ORIG_SYSTEM_REFERENCE' column_name, 3 fbdi_position from dual
      union all select 'CUST_SITE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
      union all select 'CUST_SITE_ORIG_SYS_REF' column_name, 5 fbdi_position from dual
      union all select 'SITE_ORIG_SYSTEM' column_name, 6 fbdi_position from dual
      union all select 'SITE_ORIG_SYSTEM_REFERENCE' column_name, 7 fbdi_position from dual
      union all select 'ACCT_SITE_LANGUAGE' column_name, 8 fbdi_position from dual
      union all select 'INSERT_UPDATE_FLAG' column_name, 9 fbdi_position from dual
      union all select 'CUSTOMER_CATEGORY_CODE' column_name, 10 fbdi_position from dual
      union all select 'TRANSLATED_CUSTOMER_NAME' column_name, 11 fbdi_position from dual
      union all select 'SET_CODE' column_name, 12 fbdi_position from dual
      union all select 'START_DATE' column_name, 13 fbdi_position from dual
      union all select 'END_DATE' column_name, 14 fbdi_position from dual
      union all select 'KEY_ACCOUNT_FLAG' column_name, 15 fbdi_position from dual
      union all select 'ACCOUNT_NUMBER' column_name, 16 fbdi_position from dual
      union all select 'PARTY_SITE_NUMBER' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 38 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'HzImpAcctSitesT.csv' and f."OBJECT_CODE" = 'HZ_ACCT_SITES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'HzImpAcctSitesT.csv' and f."OBJECT_CODE" = 'HZ_ACCT_SITES')
and   t."COLUMN_NAME" not in ('BATCH_ID', 'CUST_ORIG_SYSTEM', 'CUST_ORIG_SYSTEM_REFERENCE', 'CUST_SITE_ORIG_SYSTEM', 'CUST_SITE_ORIG_SYS_REF', 'SITE_ORIG_SYSTEM', 'SITE_ORIG_SYSTEM_REFERENCE', 'ACCT_SITE_LANGUAGE', 'INSERT_UPDATE_FLAG', 'CUSTOMER_CATEGORY_CODE', 'TRANSLATED_CUSTOMER_NAME', 'SET_CODE', 'START_DATE', 'END_DATE', 'KEY_ACCOUNT_FLAG', 'ACCOUNT_NUMBER', 'PARTY_SITE_NUMBER', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20');

-- HzImpAcctSiteUsesT.csv -> HZ_ACCT_SITE_USES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BATCH_ID' column_name, 1 fbdi_position from dual
      union all select 'CUST_SITE_ORIG_SYSTEM' column_name, 2 fbdi_position from dual
      union all select 'CUST_SITE_ORIG_SYS_REF' column_name, 3 fbdi_position from dual
      union all select 'CUST_SITEUSE_ORIG_SYSTEM' column_name, 4 fbdi_position from dual
      union all select 'CUST_SITEUSE_ORIG_SYS_REF' column_name, 5 fbdi_position from dual
      union all select 'SITE_USE_CODE' column_name, 6 fbdi_position from dual
      union all select 'PRIMARY_FLAG' column_name, 7 fbdi_position from dual
      union all select 'INSERT_UPDATE_FLAG' column_name, 8 fbdi_position from dual
      union all select 'LOCATION' column_name, 9 fbdi_position from dual
      union all select 'SET_CODE' column_name, 10 fbdi_position from dual
      union all select 'START_DATE' column_name, 11 fbdi_position from dual
      union all select 'END_DATE' column_name, 12 fbdi_position from dual
      union all select 'ACCOUNT_NUMBER' column_name, 13 fbdi_position from dual
      union all select 'PARTY_SITE_NUMBER' column_name, 14 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 15 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 16 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 35 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'HzImpAcctSiteUsesT.csv' and f."OBJECT_CODE" = 'HZ_ACCT_SITE_USES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'HzImpAcctSiteUsesT.csv' and f."OBJECT_CODE" = 'HZ_ACCT_SITE_USES')
and   t."COLUMN_NAME" not in ('BATCH_ID', 'CUST_SITE_ORIG_SYSTEM', 'CUST_SITE_ORIG_SYS_REF', 'CUST_SITEUSE_ORIG_SYSTEM', 'CUST_SITEUSE_ORIG_SYS_REF', 'SITE_USE_CODE', 'PRIMARY_FLAG', 'INSERT_UPDATE_FLAG', 'LOCATION', 'SET_CODE', 'START_DATE', 'END_DATE', 'ACCOUNT_NUMBER', 'PARTY_SITE_NUMBER', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20');

-- PorReqHeadersInterfaceAll.csv -> POR_REQ_HEADERS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_HEADER_KEY' column_name, 1 fbdi_position from dual
      union all select 'INTERFACE_SOURCE_CODE' column_name, 2 fbdi_position from dual
      union all select 'REQ_BU_NAME' column_name, 3 fbdi_position from dual
      union all select 'BATCH_ID' column_name, 4 fbdi_position from dual
      union all select 'INTERFACE_SOURCE_LINE_ID' column_name, 5 fbdi_position from dual
      union all select 'DOCUMENT_STATUS' column_name, 6 fbdi_position from dual
      union all select 'APPROVER_EMAIL_ADDR' column_name, 7 fbdi_position from dual
      union all select 'PREPARER_EMAIL_ADDR' column_name, 8 fbdi_position from dual
      union all select 'PRC_BU_NAME' column_name, 9 fbdi_position from dual
      union all select 'REQUISITION_NUMBER' column_name, 10 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 11 fbdi_position from dual
      union all select 'EMERGENCY_PO_NUMBER' column_name, 12 fbdi_position from dual
      union all select 'DEFAULT_TAXATION_COUNTRY' column_name, 13 fbdi_position from dual
      union all select 'DEFAULT_TAXATION_TERRITORY' column_name, 14 fbdi_position from dual
      union all select 'DOCUMENT_SUB_TYPE' column_name, 15 fbdi_position from dual
      union all select 'DOCUMENT_SUB_TYPE_NAME' column_name, 16 fbdi_position from dual
      union all select 'JUSTIFICATION' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 68 fbdi_position from dual
      union all select 'SOLDTO_LE_NAME' column_name, 69 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PorReqHeadersInterfaceAll.csv' and f."OBJECT_CODE" = 'POR_REQ_HEADERS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PorReqHeadersInterfaceAll.csv' and f."OBJECT_CODE" = 'POR_REQ_HEADERS')
and   t."COLUMN_NAME" not in ('INTERFACE_HEADER_KEY', 'INTERFACE_SOURCE_CODE', 'REQ_BU_NAME', 'BATCH_ID', 'INTERFACE_SOURCE_LINE_ID', 'DOCUMENT_STATUS', 'APPROVER_EMAIL_ADDR', 'PREPARER_EMAIL_ADDR', 'PRC_BU_NAME', 'REQUISITION_NUMBER', 'DESCRIPTION', 'EMERGENCY_PO_NUMBER', 'DEFAULT_TAXATION_COUNTRY', 'DEFAULT_TAXATION_TERRITORY', 'DOCUMENT_SUB_TYPE', 'DOCUMENT_SUB_TYPE_NAME', 'JUSTIFICATION', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_CATEGORY', 'SOLDTO_LE_NAME');

-- PorReqLinesInterfaceAll.csv -> POR_REQ_LINES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_LINE_KEY' column_name, 1 fbdi_position from dual
      union all select 'INTERFACE_HEADER_KEY' column_name, 2 fbdi_position from dual
      union all select 'GROUP_CODE' column_name, 3 fbdi_position from dual
      union all select 'DESTINATION_TYPE_CODE' column_name, 4 fbdi_position from dual
      union all select 'DELIVER_TO_LOCATION_CODE' column_name, 5 fbdi_position from dual
      union all select 'DESTINATION_ORGANIZATION_CODE' column_name, 6 fbdi_position from dual
      union all select 'DESTINATION_SUBINVENTORY' column_name, 7 fbdi_position from dual
      union all select 'REQUESTER_EMAIL_ADDR' column_name, 8 fbdi_position from dual
      union all select 'ITEM_DESCRIPTION' column_name, 9 fbdi_position from dual
      union all select 'CATEGORY_NAME' column_name, 10 fbdi_position from dual
      union all select 'NEED_BY_DATE' column_name, 11 fbdi_position from dual
      union all select 'ITEM_NUMBER' column_name, 12 fbdi_position from dual
      union all select 'ITEM_REVISION' column_name, 13 fbdi_position from dual
      union all select 'UOM_CODE' column_name, 14 fbdi_position from dual
      union all select 'LINE_TYPE' column_name, 15 fbdi_position from dual
      union all select 'QUANTITY' column_name, 16 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 17 fbdi_position from dual
      union all select 'CURRENCY_UNIT_PRICE' column_name, 18 fbdi_position from dual
      union all select 'RATE' column_name, 19 fbdi_position from dual
      union all select 'RATE_DATE' column_name, 20 fbdi_position from dual
      union all select 'RATE_TYPE' column_name, 21 fbdi_position from dual
      union all select 'SECONDARY_UOM_CODE' column_name, 22 fbdi_position from dual
      union all select 'SECONDARY_QUANTITY' column_name, 23 fbdi_position from dual
      union all select 'CURRENCY_AMOUNT' column_name, 24 fbdi_position from dual
      union all select 'UN_NUMBER' column_name, 25 fbdi_position from dual
      union all select 'HAZARD_CLASS' column_name, 26 fbdi_position from dual
      union all select 'PRC_BU_NAME' column_name, 27 fbdi_position from dual
      union all select 'SOURCE_DOC_HEADER_NUMBER' column_name, 28 fbdi_position from dual
      union all select 'SOURCE_DOC_LINE_NUMBER' column_name, 29 fbdi_position from dual
      union all select 'SUGGESTED_VENDOR_NAME' column_name, 30 fbdi_position from dual
      union all select 'SUGGESTED_VENDOR_SITE' column_name, 31 fbdi_position from dual
      union all select 'SUGGESTED_VENDOR_CONTACT' column_name, 32 fbdi_position from dual
      union all select 'SUGGESTED_VENDOR_CONTACT_PHONE' column_name, 33 fbdi_position from dual
      union all select 'SUGGESTED_VENDOR_CONTACT_FAX' column_name, 34 fbdi_position from dual
      union all select 'SUGGESTED_VENDOR_CONTACT_EMAIL' column_name, 35 fbdi_position from dual
      union all select 'SUGGESTED_SUPPLIER_ITEM_NUM' column_name, 36 fbdi_position from dual
      union all select 'SUGGESTED_BUYER_EMAIL_ADDR' column_name, 37 fbdi_position from dual
      union all select 'AUTOSOURCE_FLAG' column_name, 38 fbdi_position from dual
      union all select 'NEGOTIATED_BY_PREPARER_FLAG' column_name, 39 fbdi_position from dual
      union all select 'NEGOTIATION_REQUIRED_FLAG' column_name, 40 fbdi_position from dual
      union all select 'URGENT_FLAG' column_name, 41 fbdi_position from dual
      union all select 'NEW_SUPPLIER_FLAG' column_name, 42 fbdi_position from dual
      union all select 'NOTE_TO_BUYER' column_name, 43 fbdi_position from dual
      union all select 'NOTE_TO_RECEIVER' column_name, 44 fbdi_position from dual
      union all select 'TRX_BUSINESS_CATEGORY' column_name, 45 fbdi_position from dual
      union all select 'TRX_BUSINESS_CATEGORY_NAME' column_name, 46 fbdi_position from dual
      union all select 'PRODUCT_TYPE' column_name, 47 fbdi_position from dual
      union all select 'PRODUCT_TYPE_NAME' column_name, 48 fbdi_position from dual
      union all select 'PRODUCT_FISC_CLASSIFICATION' column_name, 49 fbdi_position from dual
      union all select 'PRODUCT_FISC_CLASS_NAME' column_name, 50 fbdi_position from dual
      union all select 'PRODUCT_CATEGORY' column_name, 51 fbdi_position from dual
      union all select 'PRODUCT_CATEGORY_NAME' column_name, 52 fbdi_position from dual
      union all select 'LINE_INTENDED_USE' column_name, 53 fbdi_position from dual
      union all select 'LINE_INTENDED_USE_NAME' column_name, 54 fbdi_position from dual
      union all select 'USER_DEFINED_FISC_CLASS' column_name, 55 fbdi_position from dual
      union all select 'USER_DEFINED_FISC_CLASS_NAME' column_name, 56 fbdi_position from dual
      union all select 'TAX_CLASSIFICATION_CODE' column_name, 57 fbdi_position from dual
      union all select 'TAX_CLASSIFICATION_NAME' column_name, 58 fbdi_position from dual
      union all select 'ASSESSABLE_VALUE' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 98 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 99 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 100 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 101 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 102 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 103 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 104 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 105 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 106 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 107 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 108 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 109 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 110 fbdi_position from dual
      union all select 'VENDOR_NUMBER' column_name, 111 fbdi_position from dual
      union all select 'FIRST_PTY_REG_NUMBER' column_name, 112 fbdi_position from dual
      union all select 'THIRD_PTY_REG_NUMBER' column_name, 113 fbdi_position from dual
      union all select 'FINAL_DISCHARGE_LOC_CODE' column_name, 114 fbdi_position from dual
      union all select 'UNIT_OF_MEASURE' column_name, 115 fbdi_position from dual
      union all select 'SECONDARY_UNIT_OF_MEASURE' column_name, 116 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PorReqLinesInterfaceAll.csv' and f."OBJECT_CODE" = 'POR_REQ_LINES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PorReqLinesInterfaceAll.csv' and f."OBJECT_CODE" = 'POR_REQ_LINES')
and   t."COLUMN_NAME" not in ('INTERFACE_LINE_KEY', 'INTERFACE_HEADER_KEY', 'GROUP_CODE', 'DESTINATION_TYPE_CODE', 'DELIVER_TO_LOCATION_CODE', 'DESTINATION_ORGANIZATION_CODE', 'DESTINATION_SUBINVENTORY', 'REQUESTER_EMAIL_ADDR', 'ITEM_DESCRIPTION', 'CATEGORY_NAME', 'NEED_BY_DATE', 'ITEM_NUMBER', 'ITEM_REVISION', 'UOM_CODE', 'LINE_TYPE', 'QUANTITY', 'CURRENCY_CODE', 'CURRENCY_UNIT_PRICE', 'RATE', 'RATE_DATE', 'RATE_TYPE', 'SECONDARY_UOM_CODE', 'SECONDARY_QUANTITY', 'CURRENCY_AMOUNT', 'UN_NUMBER', 'HAZARD_CLASS', 'PRC_BU_NAME', 'SOURCE_DOC_HEADER_NUMBER', 'SOURCE_DOC_LINE_NUMBER', 'SUGGESTED_VENDOR_NAME', 'SUGGESTED_VENDOR_SITE', 'SUGGESTED_VENDOR_CONTACT', 'SUGGESTED_VENDOR_CONTACT_PHONE', 'SUGGESTED_VENDOR_CONTACT_FAX', 'SUGGESTED_VENDOR_CONTACT_EMAIL', 'SUGGESTED_SUPPLIER_ITEM_NUM', 'SUGGESTED_BUYER_EMAIL_ADDR', 'AUTOSOURCE_FLAG', 'NEGOTIATED_BY_PREPARER_FLAG', 'NEGOTIATION_REQUIRED_FLAG', 'URGENT_FLAG', 'NEW_SUPPLIER_FLAG', 'NOTE_TO_BUYER', 'NOTE_TO_RECEIVER', 'TRX_BUSINESS_CATEGORY', 'TRX_BUSINESS_CATEGORY_NAME', 'PRODUCT_TYPE', 'PRODUCT_TYPE_NAME', 'PRODUCT_FISC_CLASSIFICATION', 'PRODUCT_FISC_CLASS_NAME', 'PRODUCT_CATEGORY', 'PRODUCT_CATEGORY_NAME', 'LINE_INTENDED_USE', 'LINE_INTENDED_USE_NAME', 'USER_DEFINED_FISC_CLASS', 'USER_DEFINED_FISC_CLASS_NAME', 'TAX_CLASSIFICATION_CODE', 'TAX_CLASSIFICATION_NAME', 'ASSESSABLE_VALUE', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_CATEGORY', 'VENDOR_NUMBER', 'FIRST_PTY_REG_NUMBER', 'THIRD_PTY_REG_NUMBER', 'FINAL_DISCHARGE_LOC_CODE', 'UNIT_OF_MEASURE', 'SECONDARY_UNIT_OF_MEASURE');

-- PorReqDistsInterfaceAll.csv -> POR_REQ_DISTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_DISTRIBUTION_KEY' column_name, 1 fbdi_position from dual
      union all select 'INTERFACE_LINE_KEY' column_name, 2 fbdi_position from dual
      union all select 'PERCENT' column_name, 3 fbdi_position from dual
      union all select 'DISTRIBUTION_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'DISTRIBUTION_QUANTITY' column_name, 5 fbdi_position from dual
      union all select 'DISTRIBUTION_CURRENCY_AMOUNT' column_name, 6 fbdi_position from dual
      union all select 'PJC_PROJECT_NAME' column_name, 7 fbdi_position from dual
      union all select 'PJC_TASK_NAME' column_name, 8 fbdi_position from dual
      union all select 'PJC_EXPENDITURE_TYPE_NAME' column_name, 9 fbdi_position from dual
      union all select 'PJC_EXPENDITURE_ITEM_DATE' column_name, 10 fbdi_position from dual
      union all select 'PJC_ORGANIZATION_NAME' column_name, 11 fbdi_position from dual
      union all select 'PJC_BILLABLE_FLAG' column_name, 12 fbdi_position from dual
      union all select 'PJC_CAPITALIZABLE_FLAG' column_name, 13 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE1' column_name, 14 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE2' column_name, 15 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE3' column_name, 16 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE4' column_name, 17 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE5' column_name, 18 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE6' column_name, 19 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE7' column_name, 20 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE8' column_name, 21 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE9' column_name, 22 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE10' column_name, 23 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE1' column_name, 24 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE2' column_name, 25 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE3' column_name, 26 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE4' column_name, 27 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE5' column_name, 28 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE6' column_name, 29 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE7' column_name, 30 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE8' column_name, 31 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE9' column_name, 32 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE10' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 84 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT1' column_name, 85 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT2' column_name, 86 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT3' column_name, 87 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT4' column_name, 88 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT5' column_name, 89 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT6' column_name, 90 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT7' column_name, 91 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT8' column_name, 92 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT9' column_name, 93 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT10' column_name, 94 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT11' column_name, 95 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT12' column_name, 96 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT13' column_name, 97 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT14' column_name, 98 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT15' column_name, 99 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT16' column_name, 100 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT17' column_name, 101 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT18' column_name, 102 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT19' column_name, 103 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT20' column_name, 104 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT21' column_name, 105 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT22' column_name, 106 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT23' column_name, 107 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT24' column_name, 108 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT25' column_name, 109 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT26' column_name, 110 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT27' column_name, 111 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT28' column_name, 112 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT29' column_name, 113 fbdi_position from dual
      union all select 'CHARGE_ACCOUNT_SEGMENT30' column_name, 114 fbdi_position from dual
      union all select 'PJC_WORK_TYPE' column_name, 115 fbdi_position from dual
      union all select 'BUDGET_DATE' column_name, 116 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PorReqDistsInterfaceAll.csv' and f."OBJECT_CODE" = 'POR_REQ_DISTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PorReqDistsInterfaceAll.csv' and f."OBJECT_CODE" = 'POR_REQ_DISTS')
and   t."COLUMN_NAME" not in ('INTERFACE_DISTRIBUTION_KEY', 'INTERFACE_LINE_KEY', 'PERCENT', 'DISTRIBUTION_NUMBER', 'DISTRIBUTION_QUANTITY', 'DISTRIBUTION_CURRENCY_AMOUNT', 'PJC_PROJECT_NAME', 'PJC_TASK_NAME', 'PJC_EXPENDITURE_TYPE_NAME', 'PJC_EXPENDITURE_ITEM_DATE', 'PJC_ORGANIZATION_NAME', 'PJC_BILLABLE_FLAG', 'PJC_CAPITALIZABLE_FLAG', 'PJC_RESERVED_ATTRIBUTE1', 'PJC_RESERVED_ATTRIBUTE2', 'PJC_RESERVED_ATTRIBUTE3', 'PJC_RESERVED_ATTRIBUTE4', 'PJC_RESERVED_ATTRIBUTE5', 'PJC_RESERVED_ATTRIBUTE6', 'PJC_RESERVED_ATTRIBUTE7', 'PJC_RESERVED_ATTRIBUTE8', 'PJC_RESERVED_ATTRIBUTE9', 'PJC_RESERVED_ATTRIBUTE10', 'PJC_USER_DEF_ATTRIBUTE1', 'PJC_USER_DEF_ATTRIBUTE2', 'PJC_USER_DEF_ATTRIBUTE3', 'PJC_USER_DEF_ATTRIBUTE4', 'PJC_USER_DEF_ATTRIBUTE5', 'PJC_USER_DEF_ATTRIBUTE6', 'PJC_USER_DEF_ATTRIBUTE7', 'PJC_USER_DEF_ATTRIBUTE8', 'PJC_USER_DEF_ATTRIBUTE9', 'PJC_USER_DEF_ATTRIBUTE10', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_CATEGORY', 'CHARGE_ACCOUNT_SEGMENT1', 'CHARGE_ACCOUNT_SEGMENT2', 'CHARGE_ACCOUNT_SEGMENT3', 'CHARGE_ACCOUNT_SEGMENT4', 'CHARGE_ACCOUNT_SEGMENT5', 'CHARGE_ACCOUNT_SEGMENT6', 'CHARGE_ACCOUNT_SEGMENT7', 'CHARGE_ACCOUNT_SEGMENT8', 'CHARGE_ACCOUNT_SEGMENT9', 'CHARGE_ACCOUNT_SEGMENT10', 'CHARGE_ACCOUNT_SEGMENT11', 'CHARGE_ACCOUNT_SEGMENT12', 'CHARGE_ACCOUNT_SEGMENT13', 'CHARGE_ACCOUNT_SEGMENT14', 'CHARGE_ACCOUNT_SEGMENT15', 'CHARGE_ACCOUNT_SEGMENT16', 'CHARGE_ACCOUNT_SEGMENT17', 'CHARGE_ACCOUNT_SEGMENT18', 'CHARGE_ACCOUNT_SEGMENT19', 'CHARGE_ACCOUNT_SEGMENT20', 'CHARGE_ACCOUNT_SEGMENT21', 'CHARGE_ACCOUNT_SEGMENT22', 'CHARGE_ACCOUNT_SEGMENT23', 'CHARGE_ACCOUNT_SEGMENT24', 'CHARGE_ACCOUNT_SEGMENT25', 'CHARGE_ACCOUNT_SEGMENT26', 'CHARGE_ACCOUNT_SEGMENT27', 'CHARGE_ACCOUNT_SEGMENT28', 'CHARGE_ACCOUNT_SEGMENT29', 'CHARGE_ACCOUNT_SEGMENT30', 'PJC_WORK_TYPE', 'BUDGET_DATE');

-- PjfProjectsAllXface.csv -> PJF_PROJECTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'PROJECT_NAME' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'SOURCE_TEMPLATE_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'SOURCE_APPLICATION_CODE' column_name, 4 fbdi_position from dual
      union all select 'SOURCE_PROJECT_REFERENCE' column_name, 5 fbdi_position from dual
      union all select 'ORGANIZATION_NAME' column_name, 6 fbdi_position from dual
      union all select 'LEGAL_ENTITY_NAME' column_name, 7 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 8 fbdi_position from dual
      union all select 'PROJECT_MANAGER_NUMBER' column_name, 9 fbdi_position from dual
      union all select 'PROJECT_MANAGER_NAME' column_name, 10 fbdi_position from dual
      union all select 'PROJECT_MANAGER_EMAIL' column_name, 11 fbdi_position from dual
      union all select 'PROJECT_START_DATE' column_name, 12 fbdi_position from dual
      union all select 'PROJECT_FINISH_DATE' column_name, 13 fbdi_position from dual
      union all select 'CLOSED_DATE' column_name, 14 fbdi_position from dual
      union all select 'PROJECT_STATUS_NAME' column_name, 15 fbdi_position from dual
      union all select 'PROJECT_PRIORITY_CODE' column_name, 16 fbdi_position from dual
      union all select 'OUTLINE_DISPLAY_LEVEL' column_name, 17 fbdi_position from dual
      union all select 'PLANNING_PROJECT_FLAG' column_name, 18 fbdi_position from dual
      union all select 'SERVICE_TYPE_CODE' column_name, 19 fbdi_position from dual
      union all select 'WORK_TYPE_NAME' column_name, 20 fbdi_position from dual
      union all select 'LIMIT_TO_TXN_CONTROLS_CODE' column_name, 21 fbdi_position from dual
      union all select 'PROJECT_CURRENCY_CODE' column_name, 22 fbdi_position from dual
      union all select 'CURRENCY_CONV_RATE_TYPE' column_name, 23 fbdi_position from dual
      union all select 'CURRENCY_CONV_DATE_TYPE_CODE' column_name, 24 fbdi_position from dual
      union all select 'CURRENCY_CONV_DATE' column_name, 25 fbdi_position from dual
      union all select 'CINT_ELIGIBLE_FLAG' column_name, 26 fbdi_position from dual
      union all select 'CINT_RATE_SCH_NAME' column_name, 27 fbdi_position from dual
      union all select 'CINT_STOP_DATE' column_name, 28 fbdi_position from dual
      union all select 'ASSET_ALLOCATION_METHOD_CODE' column_name, 29 fbdi_position from dual
      union all select 'CAPITAL_EVENT_PROCESSING_CODE' column_name, 30 fbdi_position from dual
      union all select 'ALLOW_CROSS_CHARGE_FLAG' column_name, 31 fbdi_position from dual
      union all select 'CC_PROCESS_LABOR_FLAG' column_name, 32 fbdi_position from dual
      union all select 'LABOR_TP_SCHEDULE_NAME' column_name, 33 fbdi_position from dual
      union all select 'LABOR_TP_FIXED_DATE' column_name, 34 fbdi_position from dual
      union all select 'CC_PROCESS_NL_FLAG' column_name, 35 fbdi_position from dual
      union all select 'NL_TP_SCHEDULE_NAME' column_name, 36 fbdi_position from dual
      union all select 'NL_TP_FIXED_DATE' column_name, 37 fbdi_position from dual
      union all select 'BURDEN_SCHEDULE_NAME' column_name, 38 fbdi_position from dual
      union all select 'BURDEN_SCH_FIXED_DATED' column_name, 39 fbdi_position from dual
      union all select 'KPI_NOTIFICATION_ENABLED' column_name, 40 fbdi_position from dual
      union all select 'KPI_NOTIFICATION_RECIPIENTS' column_name, 41 fbdi_position from dual
      union all select 'KPI_NOTIFICATION_INCLUDE_NOTES' column_name, 42 fbdi_position from dual
      union all select 'COPY_TEAM_MEMBERS_FLAG' column_name, 43 fbdi_position from dual
      union all select 'COPY_PROJECT_CLASSES_FLAG' column_name, 44 fbdi_position from dual
      union all select 'COPY_ATTACHMENTS_FLAG' column_name, 45 fbdi_position from dual
      union all select 'COPY_DFF_FLAG' column_name, 46 fbdi_position from dual
      union all select 'COPY_GROUP_SPACE_FLAG' column_name, 47 fbdi_position from dual
      union all select 'COPY_TASKS_FLAG' column_name, 48 fbdi_position from dual
      union all select 'COPY_TASK_ATTACHMENTS_FLAG' column_name, 49 fbdi_position from dual
      union all select 'COPY_TASK_DFF_FLAG' column_name, 50 fbdi_position from dual
      union all select 'COPY_TASK_ASSIGNMENTS_FLAG' column_name, 51 fbdi_position from dual
      union all select 'COPY_TRANSACTION_CONTROLS_FLAG' column_name, 52 fbdi_position from dual
      union all select 'COPY_ASSETS_FLAG' column_name, 53 fbdi_position from dual
      union all select 'COPY_ASSET_ASSIGNMENTS_FLAG' column_name, 54 fbdi_position from dual
      union all select 'COPY_COST_OVERRIDES_FLAG' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE21' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE22' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE23' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE24' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE25' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE26' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE27' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE28' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE29' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE30' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE31' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE32' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE33' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE34' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE35' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE36' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE37' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE38' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE39' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE40' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE41' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE42' column_name, 98 fbdi_position from dual
      union all select 'ATTRIBUTE43' column_name, 99 fbdi_position from dual
      union all select 'ATTRIBUTE44' column_name, 100 fbdi_position from dual
      union all select 'ATTRIBUTE45' column_name, 101 fbdi_position from dual
      union all select 'ATTRIBUTE46' column_name, 102 fbdi_position from dual
      union all select 'ATTRIBUTE47' column_name, 103 fbdi_position from dual
      union all select 'ATTRIBUTE48' column_name, 104 fbdi_position from dual
      union all select 'ATTRIBUTE49' column_name, 105 fbdi_position from dual
      union all select 'ATTRIBUTE50' column_name, 106 fbdi_position from dual
      union all select 'ATTRIBUTE1_NUMBER' column_name, 107 fbdi_position from dual
      union all select 'ATTRIBUTE2_NUMBER' column_name, 108 fbdi_position from dual
      union all select 'ATTRIBUTE3_NUMBER' column_name, 109 fbdi_position from dual
      union all select 'ATTRIBUTE4_NUMBER' column_name, 110 fbdi_position from dual
      union all select 'ATTRIBUTE5_NUMBER' column_name, 111 fbdi_position from dual
      union all select 'ATTRIBUTE6_NUMBER' column_name, 112 fbdi_position from dual
      union all select 'ATTRIBUTE7_NUMBER' column_name, 113 fbdi_position from dual
      union all select 'ATTRIBUTE8_NUMBER' column_name, 114 fbdi_position from dual
      union all select 'ATTRIBUTE9_NUMBER' column_name, 115 fbdi_position from dual
      union all select 'ATTRIBUTE10_NUMBER' column_name, 116 fbdi_position from dual
      union all select 'ATTRIBUTE11_NUMBER' column_name, 117 fbdi_position from dual
      union all select 'ATTRIBUTE12_NUMBER' column_name, 118 fbdi_position from dual
      union all select 'ATTRIBUTE13_NUMBER' column_name, 119 fbdi_position from dual
      union all select 'ATTRIBUTE14_NUMBER' column_name, 120 fbdi_position from dual
      union all select 'ATTRIBUTE15_NUMBER' column_name, 121 fbdi_position from dual
      union all select 'ATTRIBUTE1_DATE' column_name, 122 fbdi_position from dual
      union all select 'ATTRIBUTE2_DATE' column_name, 123 fbdi_position from dual
      union all select 'ATTRIBUTE3_DATE' column_name, 124 fbdi_position from dual
      union all select 'ATTRIBUTE4_DATE' column_name, 125 fbdi_position from dual
      union all select 'ATTRIBUTE5_DATE' column_name, 126 fbdi_position from dual
      union all select 'ATTRIBUTE6_DATE' column_name, 127 fbdi_position from dual
      union all select 'ATTRIBUTE7_DATE' column_name, 128 fbdi_position from dual
      union all select 'ATTRIBUTE8_DATE' column_name, 129 fbdi_position from dual
      union all select 'ATTRIBUTE9_DATE' column_name, 130 fbdi_position from dual
      union all select 'ATTRIBUTE10_DATE' column_name, 131 fbdi_position from dual
      union all select 'ATTRIBUTE11_DATE' column_name, 132 fbdi_position from dual
      union all select 'ATTRIBUTE12_DATE' column_name, 133 fbdi_position from dual
      union all select 'ATTRIBUTE13_DATE' column_name, 134 fbdi_position from dual
      union all select 'ATTRIBUTE14_DATE' column_name, 135 fbdi_position from dual
      union all select 'ATTRIBUTE15_DATE' column_name, 136 fbdi_position from dual
      union all select 'SCHEDULE_NAME' column_name, 137 fbdi_position from dual
      union all select 'EPS_NAME' column_name, 138 fbdi_position from dual
      union all select 'PROJECT_PLAN_VIEW_ACCESS' column_name, 139 fbdi_position from dual
      union all select 'SCHEDULE_TYPE' column_name, 140 fbdi_position from dual
      union all select 'OPPORTUNITY_ID' column_name, 141 fbdi_position from dual
      union all select 'OPPORTUNITY_NUMBER' column_name, 142 fbdi_position from dual
      union all select 'OPPORTUNITY_CUSTOMER_NUMBER' column_name, 143 fbdi_position from dual
      union all select 'OPPORTUNITY_CUSTOMER_ID' column_name, 144 fbdi_position from dual
      union all select 'OPPORTUNITY_AMT' column_name, 145 fbdi_position from dual
      union all select 'OPPORTUNITY_CURRCODE' column_name, 146 fbdi_position from dual
      union all select 'OPPORTUNITY_WIN_CONF_PERCENT' column_name, 147 fbdi_position from dual
      union all select 'OPPORTUNITY_NAME' column_name, 148 fbdi_position from dual
      union all select 'OPPORTUNITY_DESC' column_name, 149 fbdi_position from dual
      union all select 'OPPORTUNITY_CUSTOMER_NAME' column_name, 150 fbdi_position from dual
      union all select 'OPPORTUNITY_STATUS' column_name, 151 fbdi_position from dual
      union all select 'PRJ_PLAN_BASELINE_NAME' column_name, 152 fbdi_position from dual
      union all select 'PRJ_PLAN_BASELINE_DESC' column_name, 153 fbdi_position from dual
      union all select 'PRJ_PLAN_BASELINE_DATE' column_name, 154 fbdi_position from dual
      union all select 'BUDGETARY_CONTROL_FLAG' column_name, 155 fbdi_position from dual
      union all select 'SOURCE_TEMPLATE_NAME' column_name, 156 fbdi_position from dual
      union all select 'CASCADE_OPTION' column_name, 157 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PjfProjectsAllXface.csv' and f."OBJECT_CODE" = 'PJF_PROJECTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PjfProjectsAllXface.csv' and f."OBJECT_CODE" = 'PJF_PROJECTS')
and   t."COLUMN_NAME" not in ('PROJECT_NAME', 'PROJECT_NUMBER', 'SOURCE_TEMPLATE_NUMBER', 'SOURCE_APPLICATION_CODE', 'SOURCE_PROJECT_REFERENCE', 'ORGANIZATION_NAME', 'LEGAL_ENTITY_NAME', 'DESCRIPTION', 'PROJECT_MANAGER_NUMBER', 'PROJECT_MANAGER_NAME', 'PROJECT_MANAGER_EMAIL', 'PROJECT_START_DATE', 'PROJECT_FINISH_DATE', 'CLOSED_DATE', 'PROJECT_STATUS_NAME', 'PROJECT_PRIORITY_CODE', 'OUTLINE_DISPLAY_LEVEL', 'PLANNING_PROJECT_FLAG', 'SERVICE_TYPE_CODE', 'WORK_TYPE_NAME', 'LIMIT_TO_TXN_CONTROLS_CODE', 'PROJECT_CURRENCY_CODE', 'CURRENCY_CONV_RATE_TYPE', 'CURRENCY_CONV_DATE_TYPE_CODE', 'CURRENCY_CONV_DATE', 'CINT_ELIGIBLE_FLAG', 'CINT_RATE_SCH_NAME', 'CINT_STOP_DATE', 'ASSET_ALLOCATION_METHOD_CODE', 'CAPITAL_EVENT_PROCESSING_CODE', 'ALLOW_CROSS_CHARGE_FLAG', 'CC_PROCESS_LABOR_FLAG', 'LABOR_TP_SCHEDULE_NAME', 'LABOR_TP_FIXED_DATE', 'CC_PROCESS_NL_FLAG', 'NL_TP_SCHEDULE_NAME', 'NL_TP_FIXED_DATE', 'BURDEN_SCHEDULE_NAME', 'BURDEN_SCH_FIXED_DATED', 'KPI_NOTIFICATION_ENABLED', 'KPI_NOTIFICATION_RECIPIENTS', 'KPI_NOTIFICATION_INCLUDE_NOTES', 'COPY_TEAM_MEMBERS_FLAG', 'COPY_PROJECT_CLASSES_FLAG', 'COPY_ATTACHMENTS_FLAG', 'COPY_DFF_FLAG', 'COPY_GROUP_SPACE_FLAG', 'COPY_TASKS_FLAG', 'COPY_TASK_ATTACHMENTS_FLAG', 'COPY_TASK_DFF_FLAG', 'COPY_TASK_ASSIGNMENTS_FLAG', 'COPY_TRANSACTION_CONTROLS_FLAG', 'COPY_ASSETS_FLAG', 'COPY_ASSET_ASSIGNMENTS_FLAG', 'COPY_COST_OVERRIDES_FLAG', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE21', 'ATTRIBUTE22', 'ATTRIBUTE23', 'ATTRIBUTE24', 'ATTRIBUTE25', 'ATTRIBUTE26', 'ATTRIBUTE27', 'ATTRIBUTE28', 'ATTRIBUTE29', 'ATTRIBUTE30', 'ATTRIBUTE31', 'ATTRIBUTE32', 'ATTRIBUTE33', 'ATTRIBUTE34', 'ATTRIBUTE35', 'ATTRIBUTE36', 'ATTRIBUTE37', 'ATTRIBUTE38', 'ATTRIBUTE39', 'ATTRIBUTE40', 'ATTRIBUTE41', 'ATTRIBUTE42', 'ATTRIBUTE43', 'ATTRIBUTE44', 'ATTRIBUTE45', 'ATTRIBUTE46', 'ATTRIBUTE47', 'ATTRIBUTE48', 'ATTRIBUTE49', 'ATTRIBUTE50', 'ATTRIBUTE1_NUMBER', 'ATTRIBUTE2_NUMBER', 'ATTRIBUTE3_NUMBER', 'ATTRIBUTE4_NUMBER', 'ATTRIBUTE5_NUMBER', 'ATTRIBUTE6_NUMBER', 'ATTRIBUTE7_NUMBER', 'ATTRIBUTE8_NUMBER', 'ATTRIBUTE9_NUMBER', 'ATTRIBUTE10_NUMBER', 'ATTRIBUTE11_NUMBER', 'ATTRIBUTE12_NUMBER', 'ATTRIBUTE13_NUMBER', 'ATTRIBUTE14_NUMBER', 'ATTRIBUTE15_NUMBER', 'ATTRIBUTE1_DATE', 'ATTRIBUTE2_DATE', 'ATTRIBUTE3_DATE', 'ATTRIBUTE4_DATE', 'ATTRIBUTE5_DATE', 'ATTRIBUTE6_DATE', 'ATTRIBUTE7_DATE', 'ATTRIBUTE8_DATE', 'ATTRIBUTE9_DATE', 'ATTRIBUTE10_DATE', 'ATTRIBUTE11_DATE', 'ATTRIBUTE12_DATE', 'ATTRIBUTE13_DATE', 'ATTRIBUTE14_DATE', 'ATTRIBUTE15_DATE', 'SCHEDULE_NAME', 'EPS_NAME', 'PROJECT_PLAN_VIEW_ACCESS', 'SCHEDULE_TYPE', 'OPPORTUNITY_ID', 'OPPORTUNITY_NUMBER', 'OPPORTUNITY_CUSTOMER_NUMBER', 'OPPORTUNITY_CUSTOMER_ID', 'OPPORTUNITY_AMT', 'OPPORTUNITY_CURRCODE', 'OPPORTUNITY_WIN_CONF_PERCENT', 'OPPORTUNITY_NAME', 'OPPORTUNITY_DESC', 'OPPORTUNITY_CUSTOMER_NAME', 'OPPORTUNITY_STATUS', 'PRJ_PLAN_BASELINE_NAME', 'PRJ_PLAN_BASELINE_DESC', 'PRJ_PLAN_BASELINE_DATE', 'BUDGETARY_CONTROL_FLAG', 'SOURCE_TEMPLATE_NAME', 'CASCADE_OPTION');

-- PjfProjElementsXface.csv -> PJF_TASKS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'PROJECT_NAME' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'TASK_NAME' column_name, 3 fbdi_position from dual
      union all select 'TASK_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'TASK_DESCRIPTION' column_name, 5 fbdi_position from dual
      union all select 'PARENT_TASK_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'PLANNING_START_DATE' column_name, 7 fbdi_position from dual
      union all select 'PLANNING_END_DATE' column_name, 8 fbdi_position from dual
      union all select 'MILESTONE_FLAG' column_name, 9 fbdi_position from dual
      union all select 'CRITICAL_FLAG' column_name, 10 fbdi_position from dual
      union all select 'CHARGEABLE_FLAG' column_name, 11 fbdi_position from dual
      union all select 'BILLABLE_FLAG' column_name, 12 fbdi_position from dual
      union all select 'CAPITALIZABLE_FLAG' column_name, 13 fbdi_position from dual
      union all select 'LIMIT_TO_TXN_CONTROLS_FLAG' column_name, 14 fbdi_position from dual
      union all select 'SOURCE_TASK_REFERENCE' column_name, 15 fbdi_position from dual
      union all select 'SOURCE_APPLICATION_CODE' column_name, 16 fbdi_position from dual
      union all select 'SERVICE_TYPE_CODE' column_name, 17 fbdi_position from dual
      union all select 'WORK_TYPE_ID' column_name, 18 fbdi_position from dual
      union all select 'MANAGER_PERSON_ID' column_name, 19 fbdi_position from dual
      union all select 'ALLOW_CROSS_CHARGE_FLAG' column_name, 20 fbdi_position from dual
      union all select 'CC_PROCESS_LABOR_FLAG' column_name, 21 fbdi_position from dual
      union all select 'CC_PROCESS_NL_FLAG' column_name, 22 fbdi_position from dual
      union all select 'RECEIVE_PROJECT_INVOICE_FLAG' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE21' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE22' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE23' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE24' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE25' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE26' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE27' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE28' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE29' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE30' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE31' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE32' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE33' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE34' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE35' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE36' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE37' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE38' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE39' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE40' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE41' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE42' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE43' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE44' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE45' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE46' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE47' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE48' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE49' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE50' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE1_NUMBER' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE2_NUMBER' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE3_NUMBER' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE4_NUMBER' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE5_NUMBER' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE6_NUMBER' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE7_NUMBER' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE8_NUMBER' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE9_NUMBER' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE10_NUMBER' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE11_NUMBER' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE12_NUMBER' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE13_NUMBER' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE14_NUMBER' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE15_NUMBER' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE1_DATE' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE2_DATE' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE3_DATE' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE4_DATE' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE5_DATE' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE6_DATE' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE7_DATE' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE8_DATE' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE9_DATE' column_name, 98 fbdi_position from dual
      union all select 'ATTRIBUTE10_DATE' column_name, 99 fbdi_position from dual
      union all select 'ATTRIBUTE11_DATE' column_name, 100 fbdi_position from dual
      union all select 'ATTRIBUTE12_DATE' column_name, 101 fbdi_position from dual
      union all select 'ATTRIBUTE13_DATE' column_name, 102 fbdi_position from dual
      union all select 'ATTRIBUTE14_DATE' column_name, 103 fbdi_position from dual
      union all select 'ATTRIBUTE15_DATE' column_name, 104 fbdi_position from dual
      union all select 'ORGANIZATION_NAME' column_name, 105 fbdi_position from dual
      union all select 'FINANCIAL_TASK' column_name, 106 fbdi_position from dual
      union all select 'PLANNED_EFFORT' column_name, 107 fbdi_position from dual
      union all select 'PLANNED_DURATION' column_name, 108 fbdi_position from dual
      union all select 'REQMNT_CODE' column_name, 109 fbdi_position from dual
      union all select 'SPRINT' column_name, 110 fbdi_position from dual
      union all select 'PRIORITY' column_name, 111 fbdi_position from dual
      union all select 'SCHEDULE_MODE' column_name, 112 fbdi_position from dual
      union all select 'BASELINE_START_DATE' column_name, 113 fbdi_position from dual
      union all select 'BASELINE_FINISH_DATE' column_name, 114 fbdi_position from dual
      union all select 'BASELINE_EFFORT' column_name, 115 fbdi_position from dual
      union all select 'BASELINE_DURATION' column_name, 116 fbdi_position from dual
      union all select 'BASELINE_ALLOCATION' column_name, 117 fbdi_position from dual
      union all select 'CONSTRAINT_TYPE' column_name, 118 fbdi_position from dual
      union all select 'CONSTRAINT_DATE' column_name, 119 fbdi_position from dual
      union all select 'BASELINE_LABOR_COST_AMOUNT' column_name, 120 fbdi_position from dual
      union all select 'BASELINE_LABOR_BILLED_AMOUNT' column_name, 121 fbdi_position from dual
      union all select 'BASELINE_EXPENSE_COST_AMOUNT' column_name, 122 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PjfProjElementsXface.csv' and f."OBJECT_CODE" = 'PJF_TASKS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PjfProjElementsXface.csv' and f."OBJECT_CODE" = 'PJF_TASKS')
and   t."COLUMN_NAME" not in ('PROJECT_NAME', 'PROJECT_NUMBER', 'TASK_NAME', 'TASK_NUMBER', 'TASK_DESCRIPTION', 'PARENT_TASK_NUMBER', 'PLANNING_START_DATE', 'PLANNING_END_DATE', 'MILESTONE_FLAG', 'CRITICAL_FLAG', 'CHARGEABLE_FLAG', 'BILLABLE_FLAG', 'CAPITALIZABLE_FLAG', 'LIMIT_TO_TXN_CONTROLS_FLAG', 'SOURCE_TASK_REFERENCE', 'SOURCE_APPLICATION_CODE', 'SERVICE_TYPE_CODE', 'WORK_TYPE_ID', 'MANAGER_PERSON_ID', 'ALLOW_CROSS_CHARGE_FLAG', 'CC_PROCESS_LABOR_FLAG', 'CC_PROCESS_NL_FLAG', 'RECEIVE_PROJECT_INVOICE_FLAG', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE21', 'ATTRIBUTE22', 'ATTRIBUTE23', 'ATTRIBUTE24', 'ATTRIBUTE25', 'ATTRIBUTE26', 'ATTRIBUTE27', 'ATTRIBUTE28', 'ATTRIBUTE29', 'ATTRIBUTE30', 'ATTRIBUTE31', 'ATTRIBUTE32', 'ATTRIBUTE33', 'ATTRIBUTE34', 'ATTRIBUTE35', 'ATTRIBUTE36', 'ATTRIBUTE37', 'ATTRIBUTE38', 'ATTRIBUTE39', 'ATTRIBUTE40', 'ATTRIBUTE41', 'ATTRIBUTE42', 'ATTRIBUTE43', 'ATTRIBUTE44', 'ATTRIBUTE45', 'ATTRIBUTE46', 'ATTRIBUTE47', 'ATTRIBUTE48', 'ATTRIBUTE49', 'ATTRIBUTE50', 'ATTRIBUTE1_NUMBER', 'ATTRIBUTE2_NUMBER', 'ATTRIBUTE3_NUMBER', 'ATTRIBUTE4_NUMBER', 'ATTRIBUTE5_NUMBER', 'ATTRIBUTE6_NUMBER', 'ATTRIBUTE7_NUMBER', 'ATTRIBUTE8_NUMBER', 'ATTRIBUTE9_NUMBER', 'ATTRIBUTE10_NUMBER', 'ATTRIBUTE11_NUMBER', 'ATTRIBUTE12_NUMBER', 'ATTRIBUTE13_NUMBER', 'ATTRIBUTE14_NUMBER', 'ATTRIBUTE15_NUMBER', 'ATTRIBUTE1_DATE', 'ATTRIBUTE2_DATE', 'ATTRIBUTE3_DATE', 'ATTRIBUTE4_DATE', 'ATTRIBUTE5_DATE', 'ATTRIBUTE6_DATE', 'ATTRIBUTE7_DATE', 'ATTRIBUTE8_DATE', 'ATTRIBUTE9_DATE', 'ATTRIBUTE10_DATE', 'ATTRIBUTE11_DATE', 'ATTRIBUTE12_DATE', 'ATTRIBUTE13_DATE', 'ATTRIBUTE14_DATE', 'ATTRIBUTE15_DATE', 'ORGANIZATION_NAME', 'FINANCIAL_TASK', 'PLANNED_EFFORT', 'PLANNED_DURATION', 'REQMNT_CODE', 'SPRINT', 'PRIORITY', 'SCHEDULE_MODE', 'BASELINE_START_DATE', 'BASELINE_FINISH_DATE', 'BASELINE_EFFORT', 'BASELINE_DURATION', 'BASELINE_ALLOCATION', 'CONSTRAINT_TYPE', 'CONSTRAINT_DATE', 'BASELINE_LABOR_COST_AMOUNT', 'BASELINE_LABOR_BILLED_AMOUNT', 'BASELINE_EXPENSE_COST_AMOUNT');

-- PjfProjectPartiesInt.csv -> PJF_TEAM_MEMBERS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'PROJECT_NAME' column_name, 1 fbdi_position from dual
      union all select 'TEAM_MEMBER_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'TEAM_MEMBER_NAME' column_name, 3 fbdi_position from dual
      union all select 'TEAM_MEMBER_EMAIL' column_name, 4 fbdi_position from dual
      union all select 'PROJECT_ROLE_NAME' column_name, 5 fbdi_position from dual
      union all select 'START_DATE_ACTIVE' column_name, 6 fbdi_position from dual
      union all select 'END_DATE_ACTIVE' column_name, 7 fbdi_position from dual
      union all select 'TRACK_TIME_FLAG' column_name, 8 fbdi_position from dual
      union all select 'ALLOCATION' column_name, 9 fbdi_position from dual
      union all select 'EFFORT' column_name, 10 fbdi_position from dual
      union all select 'COST_RATE' column_name, 11 fbdi_position from dual
      union all select 'BILL_RATE' column_name, 12 fbdi_position from dual
      union all select 'ASSIGNMENT_TYPE' column_name, 13 fbdi_position from dual
      union all select 'BILLABLE_PERCENT' column_name, 14 fbdi_position from dual
      union all select 'BILLABLE_PERCENT_REASON_CODE' column_name, 15 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PjfProjectPartiesInt.csv' and f."OBJECT_CODE" = 'PJF_TEAM_MEMBERS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PjfProjectPartiesInt.csv' and f."OBJECT_CODE" = 'PJF_TEAM_MEMBERS')
and   t."COLUMN_NAME" not in ('PROJECT_NAME', 'TEAM_MEMBER_NUMBER', 'TEAM_MEMBER_NAME', 'TEAM_MEMBER_EMAIL', 'PROJECT_ROLE_NAME', 'START_DATE_ACTIVE', 'END_DATE_ACTIVE', 'TRACK_TIME_FLAG', 'ALLOCATION', 'EFFORT', 'COST_RATE', 'BILL_RATE', 'ASSIGNMENT_TYPE', 'BILLABLE_PERCENT', 'BILLABLE_PERCENT_REASON_CODE');

-- PjcTxnControlsStage.csv -> PJC_TXN_CONTROLS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'TXN_CTRL_REFERENCE' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NAME' column_name, 2 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'TASK_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'TASK_NAME' column_name, 5 fbdi_position from dual
      union all select 'EXPENDITURE_CATEGORY_NAME' column_name, 6 fbdi_position from dual
      union all select 'EXPENDITURE_TYPE' column_name, 7 fbdi_position from dual
      union all select 'NON_LABOR_RESOURCE' column_name, 8 fbdi_position from dual
      union all select 'PERSON_NUMBER' column_name, 9 fbdi_position from dual
      union all select 'PERSON_NAME' column_name, 10 fbdi_position from dual
      union all select 'PERSON_EMAILID' column_name, 11 fbdi_position from dual
      union all select 'PERSON_TYPE' column_name, 12 fbdi_position from dual
      union all select 'JOB_NAME' column_name, 13 fbdi_position from dual
      union all select 'ORGANIZATION_NAME' column_name, 14 fbdi_position from dual
      union all select 'CHARGEABLE_FLAG' column_name, 15 fbdi_position from dual
      union all select 'BILLABLE_FLAG' column_name, 16 fbdi_position from dual
      union all select 'CAPITALIZABLE_FLAG' column_name, 17 fbdi_position from dual
      union all select 'START_DATE_ACTIVE' column_name, 18 fbdi_position from dual
      union all select 'END_DATE_ACTIVE' column_name, 19 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PjcTxnControlsStage.csv' and f."OBJECT_CODE" = 'PJC_TXN_CONTROLS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PjcTxnControlsStage.csv' and f."OBJECT_CODE" = 'PJC_TXN_CONTROLS')
and   t."COLUMN_NAME" not in ('TXN_CTRL_REFERENCE', 'PROJECT_NAME', 'PROJECT_NUMBER', 'TASK_NUMBER', 'TASK_NAME', 'EXPENDITURE_CATEGORY_NAME', 'EXPENDITURE_TYPE', 'NON_LABOR_RESOURCE', 'PERSON_NUMBER', 'PERSON_NAME', 'PERSON_EMAILID', 'PERSON_TYPE', 'JOB_NAME', 'ORGANIZATION_NAME', 'CHARGEABLE_FLAG', 'BILLABLE_FLAG', 'CAPITALIZABLE_FLAG', 'START_DATE_ACTIVE', 'END_DATE_ACTIVE');

-- PjoPlanVersionsXface.csv -> PRJ_BUDGET
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'FINANCIAL_PLAN_TYPE' column_name, 2 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'PROJECT_NAME' column_name, 4 fbdi_position from dual
      union all select 'TASK_NAME' column_name, 5 fbdi_position from dual
      union all select 'TASK_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'PLAN_VERSION_NAME' column_name, 7 fbdi_position from dual
      union all select 'PLAN_VERSION_DESCRIPTION' column_name, 8 fbdi_position from dual
      union all select 'PLAN_VERSION_STATUS' column_name, 9 fbdi_position from dual
      union all select 'RESOURCE_NAME' column_name, 10 fbdi_position from dual
      union all select 'PERIOD_NAME' column_name, 11 fbdi_position from dual
      union all select 'PLANNING_CURRENCY' column_name, 12 fbdi_position from dual
      union all select 'TOTAL_QUANTITY' column_name, 13 fbdi_position from dual
      union all select 'TOTAL_TC_RAW_COST' column_name, 14 fbdi_position from dual
      union all select 'TOTAL_TC_REVENUE' column_name, 15 fbdi_position from dual
      union all select 'SRC_BUDGET_LINE_REFERENCE' column_name, 16 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NUMBER' column_name, 17 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NAME' column_name, 18 fbdi_position from dual
      union all select 'PC_RAW_COST' column_name, 19 fbdi_position from dual
      union all select 'PC_REVENUE' column_name, 20 fbdi_position from dual
      union all select 'PFC_RAW_COST' column_name, 21 fbdi_position from dual
      union all select 'PFC_REVENUE' column_name, 22 fbdi_position from dual
      union all select 'TOTAL_TC_BRDND_COST' column_name, 23 fbdi_position from dual
      union all select 'PC_BRDND_COST' column_name, 24 fbdi_position from dual
      union all select 'PFC_BRDND_COST' column_name, 25 fbdi_position from dual
      union all select 'LINE_TYPE' column_name, 26 fbdi_position from dual
      union all select 'PLANNING_START_DATE' column_name, 27 fbdi_position from dual
      union all select 'PLANNING_END_DATE' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE21' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE22' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE23' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE24' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE25' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE26' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE27' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE28' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE29' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE30' column_name, 60 fbdi_position from dual
      union all select 'PLAN_VERSION_NUMBER' column_name, 61 fbdi_position from dual
      union all select 'PROCESSING_MODE' column_name, 62 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PjoPlanVersionsXface.csv' and f."OBJECT_CODE" = 'PRJ_BUDGET'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PjoPlanVersionsXface.csv' and f."OBJECT_CODE" = 'PRJ_BUDGET')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'FINANCIAL_PLAN_TYPE', 'PROJECT_NUMBER', 'PROJECT_NAME', 'TASK_NAME', 'TASK_NUMBER', 'PLAN_VERSION_NAME', 'PLAN_VERSION_DESCRIPTION', 'PLAN_VERSION_STATUS', 'RESOURCE_NAME', 'PERIOD_NAME', 'PLANNING_CURRENCY', 'TOTAL_QUANTITY', 'TOTAL_TC_RAW_COST', 'TOTAL_TC_REVENUE', 'SRC_BUDGET_LINE_REFERENCE', 'FUNDING_SOURCE_NUMBER', 'FUNDING_SOURCE_NAME', 'PC_RAW_COST', 'PC_REVENUE', 'PFC_RAW_COST', 'PFC_REVENUE', 'TOTAL_TC_BRDND_COST', 'PC_BRDND_COST', 'PFC_BRDND_COST', 'LINE_TYPE', 'PLANNING_START_DATE', 'PLANNING_END_DATE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE21', 'ATTRIBUTE22', 'ATTRIBUTE23', 'ATTRIBUTE24', 'ATTRIBUTE25', 'ATTRIBUTE26', 'ATTRIBUTE27', 'ATTRIBUTE28', 'ATTRIBUTE29', 'ATTRIBUTE30', 'PLAN_VERSION_NUMBER', 'PROCESSING_MODE');

-- EgpSystemItemsInterface.csv -> EGP_ITEM
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'TRANSACTION_TYPE' column_name, 1 fbdi_position from dual
      union all select 'BATCH_ID' column_name, 2 fbdi_position from dual
      union all select 'BATCH_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'ITEM_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'ORGANIZATION_CODE' column_name, 6 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 7 fbdi_position from dual
      union all select 'TEMPLATE_NAME' column_name, 8 fbdi_position from dual
      union all select 'SOURCE_SYSTEM_CODE' column_name, 9 fbdi_position from dual
      union all select 'SOURCE_SYSTEM_REFERENCE' column_name, 10 fbdi_position from dual
      union all select 'PRIMARY_UOM_CODE' column_name, 13 fbdi_position from dual
      union all select 'CURRENT_PHASE_CODE' column_name, 14 fbdi_position from dual
      union all select 'INVENTORY_ITEM_STATUS_CODE' column_name, 15 fbdi_position from dual
      union all select 'ITEM_CLASS_NAME' column_name, 16 fbdi_position from dual
      union all select 'COSTING_ENABLED_FLAG' column_name, 27 fbdi_position from dual
      union all select 'INVENTORY_ASSET_FLAG' column_name, 29 fbdi_position from dual
      union all select 'FIXED_DAYS_SUPPLY' column_name, 38 fbdi_position from dual
      union all select 'FIXED_LOT_MULTIPLIER' column_name, 39 fbdi_position from dual
      union all select 'FIXED_ORDER_QUANTITY' column_name, 40 fbdi_position from dual
      union all select 'INVENTORY_PLANNING_CODE' column_name, 42 fbdi_position from dual
      union all select 'MIN_MINMAX_QUANTITY' column_name, 46 fbdi_position from dual
      union all select 'MAX_MINMAX_QUANTITY' column_name, 47 fbdi_position from dual
      union all select 'MINIMUM_ORDER_QUANTITY' column_name, 48 fbdi_position from dual
      union all select 'MAXIMUM_ORDER_QUANTITY' column_name, 49 fbdi_position from dual
      union all select 'PLANNER_CODE' column_name, 50 fbdi_position from dual
      union all select 'PLANNING_MAKE_BUY_CODE' column_name, 51 fbdi_position from dual
      union all select 'RESTRICT_SUBINVENTORIES_CODE' column_name, 60 fbdi_position from dual
      union all select 'RESTRICT_LOCATORS_CODE' column_name, 61 fbdi_position from dual
      union all select 'CHILD_LOT_FLAG' column_name, 62 fbdi_position from dual
      union all select 'STOCK_ENABLED_FLAG' column_name, 69 fbdi_position from dual
      union all select 'SHELF_LIFE_CODE' column_name, 71 fbdi_position from dual
      union all select 'SHELF_LIFE_DAYS' column_name, 72 fbdi_position from dual
      union all select 'SERIAL_NUMBER_CONTROL_CODE' column_name, 73 fbdi_position from dual
      union all select 'REVISION_QTY_CONTROL_CODE' column_name, 75 fbdi_position from dual
      union all select 'CHECK_SHORTAGES_FLAG' column_name, 80 fbdi_position from dual
      union all select 'CYCLE_COUNT_ENABLED_FLAG' column_name, 81 fbdi_position from dual
      union all select 'GRADE_CONTROL_FLAG' column_name, 83 fbdi_position from dual
      union all select 'LOT_DIVISIBLE_FLAG' column_name, 85 fbdi_position from dual
      union all select 'INVENTORY_ITEM_FLAG' column_name, 91 fbdi_position from dual
      union all select 'LOCATION_CONTROL_CODE' column_name, 92 fbdi_position from dual
      union all select 'LOT_CONTROL_CODE' column_name, 93 fbdi_position from dual
      union all select 'MTL_TRANSACTIONS_ENABLED_FLAG' column_name, 97 fbdi_position from dual
      union all select 'RESERVABLE_TYPE' column_name, 101 fbdi_position from dual
      union all select 'INVOICING_RULE_NAME' column_name, 103 fbdi_position from dual
      union all select 'TAX_CODE' column_name, 104 fbdi_position from dual
      union all select 'SALES_ACCOUNT' column_name, 105 fbdi_position from dual
      union all select 'PAYMENT_TERMS_NAME' column_name, 106 fbdi_position from dual
      union all select 'INVOICE_ENABLED_FLAG' column_name, 107 fbdi_position from dual
      union all select 'INVOICEABLE_ITEM_FLAG' column_name, 108 fbdi_position from dual
      union all select 'ACCOUNTING_RULE_NAME' column_name, 109 fbdi_position from dual
      union all select 'CUM_MANUFACTURING_LEAD_TIME' column_name, 119 fbdi_position from dual
      union all select 'PREPROCESSING_LEAD_TIME' column_name, 120 fbdi_position from dual
      union all select 'CUMULATIVE_TOTAL_LEAD_TIME' column_name, 121 fbdi_position from dual
      union all select 'FIXED_LEAD_TIME' column_name, 122 fbdi_position from dual
      union all select 'VARIABLE_LEAD_TIME' column_name, 123 fbdi_position from dual
      union all select 'FULL_LEAD_TIME' column_name, 124 fbdi_position from dual
      union all select 'LEAD_TIME_LOT_SIZE' column_name, 125 fbdi_position from dual
      union all select 'POSTPROCESSING_LEAD_TIME' column_name, 126 fbdi_position from dual
      union all select 'MRP_PLANNING_CODE' column_name, 141 fbdi_position from dual
      union all select 'SHRINKAGE_RATE' column_name, 152 fbdi_position from dual
      union all select 'DUAL_UOM_DEVIATION_HIGH' column_name, 157 fbdi_position from dual
      union all select 'DUAL_UOM_DEVIATION_LOW' column_name, 158 fbdi_position from dual
      union all select 'ITEM_TYPE' column_name, 159 fbdi_position from dual
      union all select 'LONG_DESCRIPTION' column_name, 160 fbdi_position from dual
      union all select 'SECONDARY_UOM_CODE' column_name, 164 fbdi_position from dual
      union all select 'ATP_FLAG' column_name, 168 fbdi_position from dual
      union all select 'OVER_SHIPMENT_TOLERANCE' column_name, 169 fbdi_position from dual
      union all select 'UNDER_SHIPMENT_TOLERANCE' column_name, 170 fbdi_position from dual
      union all select 'OVER_RETURN_TOLERANCE' column_name, 171 fbdi_position from dual
      union all select 'UNDER_RETURN_TOLERANCE' column_name, 172 fbdi_position from dual
      union all select 'INDIVISIBLE_FLAG' column_name, 175 fbdi_position from dual
      union all select 'INTERNAL_ORDER_ENABLED_FLAG' column_name, 176 fbdi_position from dual
      union all select 'CUSTOMER_ORDER_ENABLED_FLAG' column_name, 179 fbdi_position from dual
      union all select 'DEFAULT_SHIPPING_ORG' column_name, 180 fbdi_position from dual
      union all select 'INTERNAL_ORDER_FLAG' column_name, 184 fbdi_position from dual
      union all select 'PICKING_RULE_NAME' column_name, 185 fbdi_position from dual
      union all select 'RETURNABLE_FLAG' column_name, 186 fbdi_position from dual
      union all select 'SHIPPABLE_ITEM_FLAG' column_name, 190 fbdi_position from dual
      union all select 'CUSTOMER_ORDER_FLAG' column_name, 193 fbdi_position from dual
      union all select 'UNIT_WEIGHT' column_name, 194 fbdi_position from dual
      union all select 'WEIGHT_UOM_CODE' column_name, 195 fbdi_position from dual
      union all select 'UNIT_VOLUME' column_name, 196 fbdi_position from dual
      union all select 'VOLUME_UOM_CODE' column_name, 197 fbdi_position from dual
      union all select 'DIMENSION_UOM_CODE' column_name, 198 fbdi_position from dual
      union all select 'UNIT_LENGTH' column_name, 199 fbdi_position from dual
      union all select 'UNIT_WIDTH' column_name, 200 fbdi_position from dual
      union all select 'UNIT_HEIGHT' column_name, 201 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT' column_name, 221 fbdi_position from dual
      union all select 'UN_NUMBER_CODE' column_name, 222 fbdi_position from dual
      union all select 'RECEIVE_CLOSE_TOLERANCE' column_name, 225 fbdi_position from dual
      union all select 'PURCHASING_TAX_CODE' column_name, 226 fbdi_position from dual
      union all select 'PURCHASING_ITEM_FLAG' column_name, 227 fbdi_position from dual
      union all select 'PRICE_TOLERANCE_PERCENT' column_name, 228 fbdi_position from dual
      union all select 'MUST_USE_APPROVED_VENDOR_FLAG' column_name, 232 fbdi_position from dual
      union all select 'MATCH_APPROVAL_LEVEL' column_name, 233 fbdi_position from dual
      union all select 'INVOICE_MATCH_OPTION' column_name, 234 fbdi_position from dual
      union all select 'LIST_PRICE_PER_UNIT' column_name, 235 fbdi_position from dual
      union all select 'INVOICE_CLOSE_TOLERANCE' column_name, 236 fbdi_position from dual
      union all select 'HAZARD_CLASS_CODE' column_name, 237 fbdi_position from dual
      union all select 'BUYER_NAME' column_name, 238 fbdi_position from dual
      union all select 'PURCHASING_ENABLED_FLAG' column_name, 240 fbdi_position from dual
      union all select 'OUTSIDE_OPERATION_FLAG' column_name, 241 fbdi_position from dual
      union all select 'MARKET_PRICE' column_name, 242 fbdi_position from dual
      union all select 'ASSET_CATEGORY_ID' column_name, 243 fbdi_position from dual
      union all select 'ALLOW_ITEM_DESC_UPDATE_FLAG' column_name, 244 fbdi_position from dual
      union all select 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' column_name, 246 fbdi_position from dual
      union all select 'ALLOW_UNORDERED_RECEIPTS_FLAG' column_name, 247 fbdi_position from dual
      union all select 'DAYS_EARLY_RECEIPT_ALLOWED' column_name, 248 fbdi_position from dual
      union all select 'DAYS_LATE_RECEIPT_ALLOWED' column_name, 249 fbdi_position from dual
      union all select 'RECEIVING_ROUTING_ID' column_name, 250 fbdi_position from dual
      union all select 'ENFORCE_SHIP_TO_LOCATION_CODE' column_name, 251 fbdi_position from dual
      union all select 'QTY_RCV_EXCEPTION_CODE' column_name, 252 fbdi_position from dual
      union all select 'QTY_RCV_TOLERANCE' column_name, 253 fbdi_position from dual
      union all select 'RECEIPT_DAYS_EXCEPTION_CODE' column_name, 254 fbdi_position from dual
      union all select 'CONTRACT_ITEM_TYPE_CODE' column_name, 259 fbdi_position from dual
      union all select 'SERVICEABLE_PRODUCT_FLAG' column_name, 265 fbdi_position from dual
      union all select 'SERVICE_DURATION' column_name, 267 fbdi_position from dual
      union all select 'SERVICE_DURATION_PERIOD_CODE' column_name, 268 fbdi_position from dual
      union all select 'BACK_ORDERABLE_FLAG' column_name, 279 fbdi_position from dual
      union all select 'BUILD_IN_WIP_FLAG' column_name, 282 fbdi_position from dual
      union all select 'WIP_SUPPLY_TYPE' column_name, 285 fbdi_position from dual
      union all select 'WIP_SUPPLY_SUBINVENTORY' column_name, 286 fbdi_position from dual
      union all select 'STYLE_ITEM_FLAG' column_name, 292 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 299 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE1' column_name, 300 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE2' column_name, 301 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE3' column_name, 302 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE4' column_name, 303 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE5' column_name, 304 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE6' column_name, 305 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE7' column_name, 306 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE8' column_name, 307 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE9' column_name, 308 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE10' column_name, 309 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 310 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 311 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 312 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 313 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 314 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 315 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 316 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 317 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 318 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 319 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 320 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 321 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 322 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 323 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 324 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 325 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 341 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 342 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 343 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 344 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 345 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 351 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 352 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 353 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 354 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 355 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE11' column_name, 361 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE12' column_name, 362 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE13' column_name, 363 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE14' column_name, 364 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE15' column_name, 365 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE16' column_name, 366 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE17' column_name, 367 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE18' column_name, 368 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE19' column_name, 369 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE20' column_name, 370 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'EgpSystemItemsInterface.csv' and f."OBJECT_CODE" = 'EGP_ITEM'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'EgpSystemItemsInterface.csv' and f."OBJECT_CODE" = 'EGP_ITEM')
and   t."COLUMN_NAME" not in ('TRANSACTION_TYPE', 'BATCH_ID', 'BATCH_NUMBER', 'ITEM_NUMBER', 'ORGANIZATION_CODE', 'DESCRIPTION', 'TEMPLATE_NAME', 'SOURCE_SYSTEM_CODE', 'SOURCE_SYSTEM_REFERENCE', 'PRIMARY_UOM_CODE', 'CURRENT_PHASE_CODE', 'INVENTORY_ITEM_STATUS_CODE', 'ITEM_CLASS_NAME', 'COSTING_ENABLED_FLAG', 'INVENTORY_ASSET_FLAG', 'FIXED_DAYS_SUPPLY', 'FIXED_LOT_MULTIPLIER', 'FIXED_ORDER_QUANTITY', 'INVENTORY_PLANNING_CODE', 'MIN_MINMAX_QUANTITY', 'MAX_MINMAX_QUANTITY', 'MINIMUM_ORDER_QUANTITY', 'MAXIMUM_ORDER_QUANTITY', 'PLANNER_CODE', 'PLANNING_MAKE_BUY_CODE', 'RESTRICT_SUBINVENTORIES_CODE', 'RESTRICT_LOCATORS_CODE', 'CHILD_LOT_FLAG', 'STOCK_ENABLED_FLAG', 'SHELF_LIFE_CODE', 'SHELF_LIFE_DAYS', 'SERIAL_NUMBER_CONTROL_CODE', 'REVISION_QTY_CONTROL_CODE', 'CHECK_SHORTAGES_FLAG', 'CYCLE_COUNT_ENABLED_FLAG', 'GRADE_CONTROL_FLAG', 'LOT_DIVISIBLE_FLAG', 'INVENTORY_ITEM_FLAG', 'LOCATION_CONTROL_CODE', 'LOT_CONTROL_CODE', 'MTL_TRANSACTIONS_ENABLED_FLAG', 'RESERVABLE_TYPE', 'INVOICING_RULE_NAME', 'TAX_CODE', 'SALES_ACCOUNT', 'PAYMENT_TERMS_NAME', 'INVOICE_ENABLED_FLAG', 'INVOICEABLE_ITEM_FLAG', 'ACCOUNTING_RULE_NAME', 'CUM_MANUFACTURING_LEAD_TIME', 'PREPROCESSING_LEAD_TIME', 'CUMULATIVE_TOTAL_LEAD_TIME', 'FIXED_LEAD_TIME', 'VARIABLE_LEAD_TIME', 'FULL_LEAD_TIME', 'LEAD_TIME_LOT_SIZE', 'POSTPROCESSING_LEAD_TIME', 'MRP_PLANNING_CODE', 'SHRINKAGE_RATE', 'DUAL_UOM_DEVIATION_HIGH', 'DUAL_UOM_DEVIATION_LOW', 'ITEM_TYPE', 'LONG_DESCRIPTION', 'SECONDARY_UOM_CODE', 'ATP_FLAG', 'OVER_SHIPMENT_TOLERANCE', 'UNDER_SHIPMENT_TOLERANCE', 'OVER_RETURN_TOLERANCE', 'UNDER_RETURN_TOLERANCE', 'INDIVISIBLE_FLAG', 'INTERNAL_ORDER_ENABLED_FLAG', 'CUSTOMER_ORDER_ENABLED_FLAG', 'DEFAULT_SHIPPING_ORG', 'INTERNAL_ORDER_FLAG', 'PICKING_RULE_NAME', 'RETURNABLE_FLAG', 'SHIPPABLE_ITEM_FLAG', 'CUSTOMER_ORDER_FLAG', 'UNIT_WEIGHT', 'WEIGHT_UOM_CODE', 'UNIT_VOLUME', 'VOLUME_UOM_CODE', 'DIMENSION_UOM_CODE', 'UNIT_LENGTH', 'UNIT_WIDTH', 'UNIT_HEIGHT', 'EXPENSE_ACCOUNT', 'UN_NUMBER_CODE', 'RECEIVE_CLOSE_TOLERANCE', 'PURCHASING_TAX_CODE', 'PURCHASING_ITEM_FLAG', 'PRICE_TOLERANCE_PERCENT', 'MUST_USE_APPROVED_VENDOR_FLAG', 'MATCH_APPROVAL_LEVEL', 'INVOICE_MATCH_OPTION', 'LIST_PRICE_PER_UNIT', 'INVOICE_CLOSE_TOLERANCE', 'HAZARD_CLASS_CODE', 'BUYER_NAME', 'PURCHASING_ENABLED_FLAG', 'OUTSIDE_OPERATION_FLAG', 'MARKET_PRICE', 'ASSET_CATEGORY_ID', 'ALLOW_ITEM_DESC_UPDATE_FLAG', 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG', 'ALLOW_UNORDERED_RECEIPTS_FLAG', 'DAYS_EARLY_RECEIPT_ALLOWED', 'DAYS_LATE_RECEIPT_ALLOWED', 'RECEIVING_ROUTING_ID', 'ENFORCE_SHIP_TO_LOCATION_CODE', 'QTY_RCV_EXCEPTION_CODE', 'QTY_RCV_TOLERANCE', 'RECEIPT_DAYS_EXCEPTION_CODE', 'CONTRACT_ITEM_TYPE_CODE', 'SERVICEABLE_PRODUCT_FLAG', 'SERVICE_DURATION', 'SERVICE_DURATION_PERIOD_CODE', 'BACK_ORDERABLE_FLAG', 'BUILD_IN_WIP_FLAG', 'WIP_SUPPLY_TYPE', 'WIP_SUPPLY_SUBINVENTORY', 'STYLE_ITEM_FLAG', 'GLOBAL_ATTRIBUTE_CATEGORY', 'GLOBAL_ATTRIBUTE1', 'GLOBAL_ATTRIBUTE2', 'GLOBAL_ATTRIBUTE3', 'GLOBAL_ATTRIBUTE4', 'GLOBAL_ATTRIBUTE5', 'GLOBAL_ATTRIBUTE6', 'GLOBAL_ATTRIBUTE7', 'GLOBAL_ATTRIBUTE8', 'GLOBAL_ATTRIBUTE9', 'GLOBAL_ATTRIBUTE10', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'GLOBAL_ATTRIBUTE11', 'GLOBAL_ATTRIBUTE12', 'GLOBAL_ATTRIBUTE13', 'GLOBAL_ATTRIBUTE14', 'GLOBAL_ATTRIBUTE15', 'GLOBAL_ATTRIBUTE16', 'GLOBAL_ATTRIBUTE17', 'GLOBAL_ATTRIBUTE18', 'GLOBAL_ATTRIBUTE19', 'GLOBAL_ATTRIBUTE20');

-- EgpItemCategoriesInterface.csv -> EGP_ITEM_CAT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'TRANSACTION_TYPE' column_name, 1 fbdi_position from dual
      union all select 'BATCH_ID' column_name, 2 fbdi_position from dual
      union all select 'BATCH_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'ITEM_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'ORGANIZATION_CODE' column_name, 5 fbdi_position from dual
      union all select 'CATEGORY_SET_NAME' column_name, 6 fbdi_position from dual
      union all select 'CATEGORY_NAME' column_name, 7 fbdi_position from dual
      union all select 'CATEGORY_CODE' column_name, 8 fbdi_position from dual
      union all select 'OLD_CATEGORY_NAME' column_name, 9 fbdi_position from dual
      union all select 'OLD_CATEGORY_CODE' column_name, 10 fbdi_position from dual
      union all select 'SOURCE_SYSTEM_CODE' column_name, 11 fbdi_position from dual
      union all select 'SOURCE_SYSTEM_REFERENCE' column_name, 12 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'EgpItemCategoriesInterface.csv' and f."OBJECT_CODE" = 'EGP_ITEM_CAT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'EgpItemCategoriesInterface.csv' and f."OBJECT_CODE" = 'EGP_ITEM_CAT')
and   t."COLUMN_NAME" not in ('TRANSACTION_TYPE', 'BATCH_ID', 'BATCH_NUMBER', 'ITEM_NUMBER', 'ORGANIZATION_CODE', 'CATEGORY_SET_NAME', 'CATEGORY_NAME', 'CATEGORY_CODE', 'OLD_CATEGORY_NAME', 'OLD_CATEGORY_CODE', 'SOURCE_SYSTEM_CODE', 'SOURCE_SYSTEM_REFERENCE');

-- GmsAwardHeadersInterface.csv -> GMS_AWD_HEADERS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NAME' column_name, 1 fbdi_position from dual
      union all select 'AWARD_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'SOURCE_TEMPLATE_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'BUSINESS_UNIT' column_name, 4 fbdi_position from dual
      union all select 'LEGAL_ENTITY' column_name, 5 fbdi_position from dual
      union all select 'CONTRACT_TYPE' column_name, 6 fbdi_position from dual
      union all select 'PRIMARY_SPONSOR' column_name, 7 fbdi_position from dual
      union all select 'PRINCIPAL_INVESTIGATOR_EMAIL' column_name, 8 fbdi_position from dual
      union all select 'PI_NAME' column_name, 9 fbdi_position from dual
      union all select 'PI_NUMBER' column_name, 10 fbdi_position from dual
      union all select 'AWARD_START_DATE' column_name, 11 fbdi_position from dual
      union all select 'AWARD_END_DATE' column_name, 12 fbdi_position from dual
      union all select 'AWARD_DESCRIPTION' column_name, 13 fbdi_position from dual
      union all select 'ORGANIZATION' column_name, 14 fbdi_position from dual
      union all select 'INSTITUTION' column_name, 15 fbdi_position from dual
      union all select 'SPONSOR_AWARD_NUMBER' column_name, 16 fbdi_position from dual
      union all select 'AWARD_PURPOSE' column_name, 17 fbdi_position from dual
      union all select 'AWARD_TYPE' column_name, 18 fbdi_position from dual
      union all select 'EXPANDED_AUTHORITY_FLAG' column_name, 19 fbdi_position from dual
      union all select 'COST_SHARE' column_name, 20 fbdi_position from dual
      union all select 'DEFAULT_BURDEN_SCHEDULE' column_name, 21 fbdi_position from dual
      union all select 'FIXED_DATE' column_name, 22 fbdi_position from dual
      union all select 'PRE_AWARD_DATE' column_name, 23 fbdi_position from dual
      union all select 'PRE_AWARD_SPENDING_ALLOWED' column_name, 24 fbdi_position from dual
      union all select 'PRE_AWARD_GSF' column_name, 25 fbdi_position from dual
      union all select 'CLOSE_DATE' column_name, 26 fbdi_position from dual
      union all select 'COI_INST_POLICY_COMPLIANT' column_name, 27 fbdi_position from dual
      union all select 'COI_REVIEW_COMPLETED' column_name, 28 fbdi_position from dual
      union all select 'COI_APPROVAL_DATE' column_name, 29 fbdi_position from dual
      union all select 'FT_PRIMARY_SPONSOR' column_name, 30 fbdi_position from dual
      union all select 'FT_REF_AWARD_NAME' column_name, 31 fbdi_position from dual
      union all select 'FT_FROM_DATE' column_name, 32 fbdi_position from dual
      union all select 'FT_TO_DATE' column_name, 33 fbdi_position from dual
      union all select 'FT_AMOUNT' column_name, 34 fbdi_position from dual
      union all select 'FT_IS_FEDERAL' column_name, 35 fbdi_position from dual
      union all select 'IS_INTELL_PROP_REPORTED' column_name, 36 fbdi_position from dual
      union all select 'INTELL_PROP_DESC' column_name, 37 fbdi_position from dual
      union all select 'PREV_AWARD_BU' column_name, 38 fbdi_position from dual
      union all select 'PREV_AWARD_NAME' column_name, 39 fbdi_position from dual
      union all select 'PREV_AWARD_RENEWAL_INPRG' column_name, 40 fbdi_position from dual
      union all select 'PREV_AWARD_ABR' column_name, 41 fbdi_position from dual
      union all select 'COST_SHARE_REQ_BY_SPONSOR' column_name, 42 fbdi_position from dual
      union all select 'COST_SHARE_APPROVED_BY' column_name, 43 fbdi_position from dual
      union all select 'COST_SHARE_APPROVAL_DATE' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 95 fbdi_position from dual
      union all select 'CONTRACT_STATUS' column_name, 96 fbdi_position from dual
      union all select 'CONTRACT_LINE_NAME' column_name, 97 fbdi_position from dual
      union all select 'LOC_FLAG' column_name, 98 fbdi_position from dual
      union all select 'DOC_NUMBER' column_name, 99 fbdi_position from dual
      union all select 'FED_INVOICE_FORMAT' column_name, 100 fbdi_position from dual
      union all select 'BILL_PLAN_NAME' column_name, 101 fbdi_position from dual
      union all select 'REVENUE_PLAN_NAME' column_name, 102 fbdi_position from dual
      union all select 'INVOICE_METHOD' column_name, 103 fbdi_position from dual
      union all select 'REVENUE_METHOD' column_name, 104 fbdi_position from dual
      union all select 'BILLING_CYCLE' column_name, 105 fbdi_position from dual
      union all select 'PAYMENT_TERM' column_name, 106 fbdi_position from dual
      union all select 'LABOR_FORMAT' column_name, 107 fbdi_position from dual
      union all select 'NON_LABOR_FORMAT' column_name, 108 fbdi_position from dual
      union all select 'EVENT_FORMAT' column_name, 109 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 110 fbdi_position from dual
      union all select 'PRIMARY_SPONSOR_NUMBER' column_name, 111 fbdi_position from dual
      union all select 'FT_PRIMARY_SPONSOR_NUMBER' column_name, 112 fbdi_position from dual
      union all select 'NET_INVOICE_FLAG' column_name, 113 fbdi_position from dual
      union all select 'INV_HDR_GROUPING_OPTIONS' column_name, 114 fbdi_position from dual
      union all select 'BILL_TO_SITE_LOCATION' column_name, 115 fbdi_position from dual
      union all select 'BILL_TO_CONTACT_NAME' column_name, 116 fbdi_position from dual
      union all select 'BILL_TO_CONTACT_EMAIL' column_name, 117 fbdi_position from dual
      union all select 'SHIP_TO_SITE_LOCATION' column_name, 118 fbdi_position from dual
      union all select 'BILL_SET_NUMBER' column_name, 119 fbdi_position from dual
      union all select 'GENERATED_INVOICE_STATUS' column_name, 120 fbdi_position from dual
      union all select 'INV_TRX_TYPE_NAME' column_name, 121 fbdi_position from dual
      union all select 'BILL_TO_ACCT_NUMBER' column_name, 122 fbdi_position from dual
      union all select 'SHIP_TO_ACCT_NUMBER' column_name, 123 fbdi_position from dual
      union all select 'PREPAY_TRX_TYPE_NAME' column_name, 124 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardHeadersInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_HEADERS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardHeadersInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_HEADERS')
and   t."COLUMN_NAME" not in ('AWARD_NAME', 'AWARD_NUMBER', 'SOURCE_TEMPLATE_NUMBER', 'BUSINESS_UNIT', 'LEGAL_ENTITY', 'CONTRACT_TYPE', 'PRIMARY_SPONSOR', 'PRINCIPAL_INVESTIGATOR_EMAIL', 'PI_NAME', 'PI_NUMBER', 'AWARD_START_DATE', 'AWARD_END_DATE', 'AWARD_DESCRIPTION', 'ORGANIZATION', 'INSTITUTION', 'SPONSOR_AWARD_NUMBER', 'AWARD_PURPOSE', 'AWARD_TYPE', 'EXPANDED_AUTHORITY_FLAG', 'COST_SHARE', 'DEFAULT_BURDEN_SCHEDULE', 'FIXED_DATE', 'PRE_AWARD_DATE', 'PRE_AWARD_SPENDING_ALLOWED', 'PRE_AWARD_GSF', 'CLOSE_DATE', 'COI_INST_POLICY_COMPLIANT', 'COI_REVIEW_COMPLETED', 'COI_APPROVAL_DATE', 'FT_PRIMARY_SPONSOR', 'FT_REF_AWARD_NAME', 'FT_FROM_DATE', 'FT_TO_DATE', 'FT_AMOUNT', 'FT_IS_FEDERAL', 'IS_INTELL_PROP_REPORTED', 'INTELL_PROP_DESC', 'PREV_AWARD_BU', 'PREV_AWARD_NAME', 'PREV_AWARD_RENEWAL_INPRG', 'PREV_AWARD_ABR', 'COST_SHARE_REQ_BY_SPONSOR', 'COST_SHARE_APPROVED_BY', 'COST_SHARE_APPROVAL_DATE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'CONTRACT_STATUS', 'CONTRACT_LINE_NAME', 'LOC_FLAG', 'DOC_NUMBER', 'FED_INVOICE_FORMAT', 'BILL_PLAN_NAME', 'REVENUE_PLAN_NAME', 'INVOICE_METHOD', 'REVENUE_METHOD', 'BILLING_CYCLE', 'PAYMENT_TERM', 'LABOR_FORMAT', 'NON_LABOR_FORMAT', 'EVENT_FORMAT', 'CURRENCY_CODE', 'PRIMARY_SPONSOR_NUMBER', 'FT_PRIMARY_SPONSOR_NUMBER', 'NET_INVOICE_FLAG', 'INV_HDR_GROUPING_OPTIONS', 'BILL_TO_SITE_LOCATION', 'BILL_TO_CONTACT_NAME', 'BILL_TO_CONTACT_EMAIL', 'SHIP_TO_SITE_LOCATION', 'BILL_SET_NUMBER', 'GENERATED_INVOICE_STATUS', 'INV_TRX_TYPE_NAME', 'BILL_TO_ACCT_NUMBER', 'SHIP_TO_ACCT_NUMBER', 'PREPAY_TRX_TYPE_NAME');

-- GmsAwardPersonnelInterface.csv -> GMS_AWD_PERSONNEL
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'INTERNAL' column_name, 3 fbdi_position from dual
      union all select 'PERSON_EMAIL' column_name, 4 fbdi_position from dual
      union all select 'PERSON_NAME' column_name, 5 fbdi_position from dual
      union all select 'PERSON_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'ROLE' column_name, 7 fbdi_position from dual
      union all select 'START_DATE' column_name, 8 fbdi_position from dual
      union all select 'END_DATE' column_name, 9 fbdi_position from dual
      union all select 'CREDIT_PERCENTAGE' column_name, 10 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 11 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 12 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 13 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 14 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 15 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 16 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 61 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardPersonnelInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PERSONNEL'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardPersonnelInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PERSONNEL')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'INTERNAL', 'PERSON_EMAIL', 'PERSON_NAME', 'PERSON_NUMBER', 'ROLE', 'START_DATE', 'END_DATE', 'CREDIT_PERCENTAGE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10');

-- ApInvoicesInterface.csv -> AP_INVOICES_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INVOICE_ID' column_name, 1 fbdi_position from dual
      union all select 'OPERATING_UNIT' column_name, 2 fbdi_position from dual
      union all select 'SOURCE' column_name, 3 fbdi_position from dual
      union all select 'INVOICE_NUM' column_name, 4 fbdi_position from dual
      union all select 'INVOICE_AMOUNT' column_name, 5 fbdi_position from dual
      union all select 'INVOICE_DATE' column_name, 6 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 7 fbdi_position from dual
      union all select 'VENDOR_NUM' column_name, 8 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE' column_name, 9 fbdi_position from dual
      union all select 'INVOICE_CURRENCY_CODE' column_name, 10 fbdi_position from dual
      union all select 'PAYMENT_CURRENCY_CODE' column_name, 11 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 12 fbdi_position from dual
      union all select 'GROUP_ID' column_name, 13 fbdi_position from dual
      union all select 'INVOICE_TYPE_LOOKUP_CODE' column_name, 14 fbdi_position from dual
      union all select 'LEGAL_ENTITY_NAME' column_name, 15 fbdi_position from dual
      union all select 'CUST_REGISTRATION_NUMBER' column_name, 16 fbdi_position from dual
      union all select 'CUST_REGISTRATION_CODE' column_name, 17 fbdi_position from dual
      union all select 'FIRST_PARTY_REGISTRATION_NUM' column_name, 18 fbdi_position from dual
      union all select 'THIRD_PARTY_REGISTRATION_NUM' column_name, 19 fbdi_position from dual
      union all select 'TERMS_NAME' column_name, 20 fbdi_position from dual
      union all select 'TERMS_DATE' column_name, 21 fbdi_position from dual
      union all select 'GOODS_RECEIVED_DATE' column_name, 22 fbdi_position from dual
      union all select 'INVOICE_RECEIVED_DATE' column_name, 23 fbdi_position from dual
      union all select 'GL_DATE' column_name, 24 fbdi_position from dual
      union all select 'PAYMENT_METHOD_CODE' column_name, 25 fbdi_position from dual
      union all select 'PAY_GROUP_LOOKUP_CODE' column_name, 26 fbdi_position from dual
      union all select 'EXCLUSIVE_PAYMENT_FLAG' column_name, 27 fbdi_position from dual
      union all select 'AMOUNT_APPLICABLE_TO_DISCOUNT' column_name, 28 fbdi_position from dual
      union all select 'PREPAY_NUM' column_name, 29 fbdi_position from dual
      union all select 'PREPAY_LINE_NUM' column_name, 30 fbdi_position from dual
      union all select 'PREPAY_APPLY_AMOUNT' column_name, 31 fbdi_position from dual
      union all select 'PREPAY_GL_DATE' column_name, 32 fbdi_position from dual
      union all select 'INVOICE_INCLUDES_PREPAY_FLAG' column_name, 33 fbdi_position from dual
      union all select 'EXCHANGE_RATE_TYPE' column_name, 34 fbdi_position from dual
      union all select 'EXCHANGE_DATE' column_name, 35 fbdi_position from dual
      union all select 'EXCHANGE_RATE' column_name, 36 fbdi_position from dual
      union all select 'ACCTS_PAY_CODE_CONCATENATED' column_name, 37 fbdi_position from dual
      union all select 'DOC_CATEGORY_CODE' column_name, 38 fbdi_position from dual
      union all select 'VOUCHER_NUM' column_name, 39 fbdi_position from dual
      union all select 'REQUESTER_FIRST_NAME' column_name, 40 fbdi_position from dual
      union all select 'REQUESTER_LAST_NAME' column_name, 41 fbdi_position from dual
      union all select 'REQUESTER_EMPLOYEE_NUM' column_name, 42 fbdi_position from dual
      union all select 'DELIVERY_CHANNEL_CODE' column_name, 43 fbdi_position from dual
      union all select 'BANK_CHARGE_BEARER' column_name, 44 fbdi_position from dual
      union all select 'REMIT_TO_SUPPLIER_NAME' column_name, 45 fbdi_position from dual
      union all select 'REMIT_TO_SUPPLIER_NUM' column_name, 46 fbdi_position from dual
      union all select 'REMIT_TO_ADDRESS_NAME' column_name, 47 fbdi_position from dual
      union all select 'PAYMENT_PRIORITY' column_name, 48 fbdi_position from dual
      union all select 'SETTLEMENT_PRIORITY' column_name, 49 fbdi_position from dual
      union all select 'UNIQUE_REMITTANCE_IDENTIFIER' column_name, 50 fbdi_position from dual
      union all select 'URI_CHECK_DIGIT' column_name, 51 fbdi_position from dual
      union all select 'PAYMENT_REASON_CODE' column_name, 52 fbdi_position from dual
      union all select 'PAYMENT_REASON_COMMENTS' column_name, 53 fbdi_position from dual
      union all select 'REMITTANCE_MESSAGE1' column_name, 54 fbdi_position from dual
      union all select 'REMITTANCE_MESSAGE2' column_name, 55 fbdi_position from dual
      union all select 'REMITTANCE_MESSAGE3' column_name, 56 fbdi_position from dual
      union all select 'AWT_GROUP_NAME' column_name, 57 fbdi_position from dual
      union all select 'SHIP_TO_LOCATION' column_name, 58 fbdi_position from dual
      union all select 'TAXATION_COUNTRY' column_name, 59 fbdi_position from dual
      union all select 'DOCUMENT_SUB_TYPE' column_name, 60 fbdi_position from dual
      union all select 'TAX_INVOICE_INTERNAL_SEQ' column_name, 61 fbdi_position from dual
      union all select 'SUPPLIER_TAX_INVOICE_NUMBER' column_name, 62 fbdi_position from dual
      union all select 'TAX_INVOICE_RECORDING_DATE' column_name, 63 fbdi_position from dual
      union all select 'SUPPLIER_TAX_INVOICE_DATE' column_name, 64 fbdi_position from dual
      union all select 'SUPPLIER_TAX_EXCHANGE_RATE' column_name, 65 fbdi_position from dual
      union all select 'PORT_OF_ENTRY_CODE' column_name, 66 fbdi_position from dual
      union all select 'CORRECTION_YEAR' column_name, 67 fbdi_position from dual
      union all select 'CORRECTION_PERIOD' column_name, 68 fbdi_position from dual
      union all select 'IMPORT_DOCUMENT_NUMBER' column_name, 69 fbdi_position from dual
      union all select 'IMPORT_DOCUMENT_DATE' column_name, 70 fbdi_position from dual
      union all select 'CONTROL_AMOUNT' column_name, 71 fbdi_position from dual
      union all select 'CALC_TAX_DURING_IMPORT_FLAG' column_name, 72 fbdi_position from dual
      union all select 'ADD_TAX_TO_INV_AMT_FLAG' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 98 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 99 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 100 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE1' column_name, 101 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE2' column_name, 102 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE3' column_name, 103 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE4' column_name, 104 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE5' column_name, 105 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE6' column_name, 106 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE7' column_name, 107 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE8' column_name, 108 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE9' column_name, 109 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE10' column_name, 110 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE11' column_name, 111 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE12' column_name, 112 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE13' column_name, 113 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE14' column_name, 114 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE15' column_name, 115 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE16' column_name, 116 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE17' column_name, 117 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE18' column_name, 118 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE19' column_name, 119 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE20' column_name, 120 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 121 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 122 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 123 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 124 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 125 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE1' column_name, 126 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE2' column_name, 127 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE3' column_name, 128 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE4' column_name, 129 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE5' column_name, 130 fbdi_position from dual
      union all select 'IMAGE_DOCUMENT_URI' column_name, 131 fbdi_position from dual
      union all select 'EXTERNAL_BANK_ACCOUNT_NUMBER' column_name, 132 fbdi_position from dual
      union all select 'EXT_BANK_ACCOUNT_IBAN_NUMBER' column_name, 133 fbdi_position from dual
      union all select 'REQUESTER_EMAIL_ADDRESS' column_name, 134 fbdi_position from dual
      union all select 'INTERCOMPANY_CROSSCHARGE_FLAG' column_name, 135 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'ApInvoicesInterface.csv' and f."OBJECT_CODE" = 'AP_INVOICES_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'ApInvoicesInterface.csv' and f."OBJECT_CODE" = 'AP_INVOICES_INT')
and   t."COLUMN_NAME" not in ('INVOICE_ID', 'OPERATING_UNIT', 'SOURCE', 'INVOICE_NUM', 'INVOICE_AMOUNT', 'INVOICE_DATE', 'VENDOR_NAME', 'VENDOR_NUM', 'VENDOR_SITE_CODE', 'INVOICE_CURRENCY_CODE', 'PAYMENT_CURRENCY_CODE', 'DESCRIPTION', 'GROUP_ID', 'INVOICE_TYPE_LOOKUP_CODE', 'LEGAL_ENTITY_NAME', 'CUST_REGISTRATION_NUMBER', 'CUST_REGISTRATION_CODE', 'FIRST_PARTY_REGISTRATION_NUM', 'THIRD_PARTY_REGISTRATION_NUM', 'TERMS_NAME', 'TERMS_DATE', 'GOODS_RECEIVED_DATE', 'INVOICE_RECEIVED_DATE', 'GL_DATE', 'PAYMENT_METHOD_CODE', 'PAY_GROUP_LOOKUP_CODE', 'EXCLUSIVE_PAYMENT_FLAG', 'AMOUNT_APPLICABLE_TO_DISCOUNT', 'PREPAY_NUM', 'PREPAY_LINE_NUM', 'PREPAY_APPLY_AMOUNT', 'PREPAY_GL_DATE', 'INVOICE_INCLUDES_PREPAY_FLAG', 'EXCHANGE_RATE_TYPE', 'EXCHANGE_DATE', 'EXCHANGE_RATE', 'ACCTS_PAY_CODE_CONCATENATED', 'DOC_CATEGORY_CODE', 'VOUCHER_NUM', 'REQUESTER_FIRST_NAME', 'REQUESTER_LAST_NAME', 'REQUESTER_EMPLOYEE_NUM', 'DELIVERY_CHANNEL_CODE', 'BANK_CHARGE_BEARER', 'REMIT_TO_SUPPLIER_NAME', 'REMIT_TO_SUPPLIER_NUM', 'REMIT_TO_ADDRESS_NAME', 'PAYMENT_PRIORITY', 'SETTLEMENT_PRIORITY', 'UNIQUE_REMITTANCE_IDENTIFIER', 'URI_CHECK_DIGIT', 'PAYMENT_REASON_CODE', 'PAYMENT_REASON_COMMENTS', 'REMITTANCE_MESSAGE1', 'REMITTANCE_MESSAGE2', 'REMITTANCE_MESSAGE3', 'AWT_GROUP_NAME', 'SHIP_TO_LOCATION', 'TAXATION_COUNTRY', 'DOCUMENT_SUB_TYPE', 'TAX_INVOICE_INTERNAL_SEQ', 'SUPPLIER_TAX_INVOICE_NUMBER', 'TAX_INVOICE_RECORDING_DATE', 'SUPPLIER_TAX_INVOICE_DATE', 'SUPPLIER_TAX_EXCHANGE_RATE', 'PORT_OF_ENTRY_CODE', 'CORRECTION_YEAR', 'CORRECTION_PERIOD', 'IMPORT_DOCUMENT_NUMBER', 'IMPORT_DOCUMENT_DATE', 'CONTROL_AMOUNT', 'CALC_TAX_DURING_IMPORT_FLAG', 'ADD_TAX_TO_INV_AMT_FLAG', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'GLOBAL_ATTRIBUTE_CATEGORY', 'GLOBAL_ATTRIBUTE1', 'GLOBAL_ATTRIBUTE2', 'GLOBAL_ATTRIBUTE3', 'GLOBAL_ATTRIBUTE4', 'GLOBAL_ATTRIBUTE5', 'GLOBAL_ATTRIBUTE6', 'GLOBAL_ATTRIBUTE7', 'GLOBAL_ATTRIBUTE8', 'GLOBAL_ATTRIBUTE9', 'GLOBAL_ATTRIBUTE10', 'GLOBAL_ATTRIBUTE11', 'GLOBAL_ATTRIBUTE12', 'GLOBAL_ATTRIBUTE13', 'GLOBAL_ATTRIBUTE14', 'GLOBAL_ATTRIBUTE15', 'GLOBAL_ATTRIBUTE16', 'GLOBAL_ATTRIBUTE17', 'GLOBAL_ATTRIBUTE18', 'GLOBAL_ATTRIBUTE19', 'GLOBAL_ATTRIBUTE20', 'GLOBAL_ATTRIBUTE_NUMBER1', 'GLOBAL_ATTRIBUTE_NUMBER2', 'GLOBAL_ATTRIBUTE_NUMBER3', 'GLOBAL_ATTRIBUTE_NUMBER4', 'GLOBAL_ATTRIBUTE_NUMBER5', 'GLOBAL_ATTRIBUTE_DATE1', 'GLOBAL_ATTRIBUTE_DATE2', 'GLOBAL_ATTRIBUTE_DATE3', 'GLOBAL_ATTRIBUTE_DATE4', 'GLOBAL_ATTRIBUTE_DATE5', 'IMAGE_DOCUMENT_URI', 'EXTERNAL_BANK_ACCOUNT_NUMBER', 'EXT_BANK_ACCOUNT_IBAN_NUMBER', 'REQUESTER_EMAIL_ADDRESS', 'INTERCOMPANY_CROSSCHARGE_FLAG');

-- ApInvoiceLinesInterface.csv -> AP_INVOICE_LINES_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INVOICE_ID' column_name, 1 fbdi_position from dual
      union all select 'LINE_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'LINE_TYPE_LOOKUP_CODE' column_name, 3 fbdi_position from dual
      union all select 'AMOUNT' column_name, 4 fbdi_position from dual
      union all select 'QUANTITY_INVOICED' column_name, 5 fbdi_position from dual
      union all select 'UNIT_PRICE' column_name, 6 fbdi_position from dual
      union all select 'UNIT_OF_MEAS_LOOKUP_CODE' column_name, 7 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 8 fbdi_position from dual
      union all select 'PO_NUMBER' column_name, 9 fbdi_position from dual
      union all select 'PO_LINE_NUMBER' column_name, 10 fbdi_position from dual
      union all select 'PO_SHIPMENT_NUM' column_name, 11 fbdi_position from dual
      union all select 'PO_DISTRIBUTION_NUM' column_name, 12 fbdi_position from dual
      union all select 'ITEM_DESCRIPTION' column_name, 13 fbdi_position from dual
      union all select 'RELEASE_NUM' column_name, 14 fbdi_position from dual
      union all select 'PURCHASING_CATEGORY' column_name, 15 fbdi_position from dual
      union all select 'RECEIPT_NUMBER' column_name, 16 fbdi_position from dual
      union all select 'RECEIPT_LINE_NUMBER' column_name, 17 fbdi_position from dual
      union all select 'CONSUMPTION_ADVICE_NUMBER' column_name, 18 fbdi_position from dual
      union all select 'CONSUMPTION_ADVICE_LINE_NUMBER' column_name, 19 fbdi_position from dual
      union all select 'PACKING_SLIP' column_name, 20 fbdi_position from dual
      union all select 'FINAL_MATCH_FLAG' column_name, 21 fbdi_position from dual
      union all select 'DIST_CODE_CONCATENATED' column_name, 22 fbdi_position from dual
      union all select 'DISTRIBUTION_SET_NAME' column_name, 23 fbdi_position from dual
      union all select 'ACCOUNTING_DATE' column_name, 24 fbdi_position from dual
      union all select 'ACCOUNT_SEGMENT' column_name, 25 fbdi_position from dual
      union all select 'BALANCING_SEGMENT' column_name, 26 fbdi_position from dual
      union all select 'COST_CENTER_SEGMENT' column_name, 27 fbdi_position from dual
      union all select 'TAX_CLASSIFICATION_CODE' column_name, 28 fbdi_position from dual
      union all select 'SHIP_TO_LOCATION_CODE' column_name, 29 fbdi_position from dual
      union all select 'SHIP_FROM_LOCATION_CODE' column_name, 30 fbdi_position from dual
      union all select 'FINAL_DISCHARGE_LOCATION_CODE' column_name, 31 fbdi_position from dual
      union all select 'TRX_BUSINESS_CATEGORY' column_name, 32 fbdi_position from dual
      union all select 'PRODUCT_FISC_CLASSIFICATION' column_name, 33 fbdi_position from dual
      union all select 'PRIMARY_INTENDED_USE' column_name, 34 fbdi_position from dual
      union all select 'USER_DEFINED_FISC_CLASS' column_name, 35 fbdi_position from dual
      union all select 'PRODUCT_TYPE' column_name, 36 fbdi_position from dual
      union all select 'ASSESSABLE_VALUE' column_name, 37 fbdi_position from dual
      union all select 'PRODUCT_CATEGORY' column_name, 38 fbdi_position from dual
      union all select 'CONTROL_AMOUNT' column_name, 39 fbdi_position from dual
      union all select 'TAX_REGIME_CODE' column_name, 40 fbdi_position from dual
      union all select 'TAX' column_name, 41 fbdi_position from dual
      union all select 'TAX_STATUS_CODE' column_name, 42 fbdi_position from dual
      union all select 'TAX_JURISDICTION_CODE' column_name, 43 fbdi_position from dual
      union all select 'TAX_RATE_CODE' column_name, 44 fbdi_position from dual
      union all select 'TAX_RATE' column_name, 45 fbdi_position from dual
      union all select 'AWT_GROUP_NAME' column_name, 46 fbdi_position from dual
      union all select 'TYPE_1099' column_name, 47 fbdi_position from dual
      union all select 'INCOME_TAX_REGION' column_name, 48 fbdi_position from dual
      union all select 'PRORATE_ACROSS_FLAG' column_name, 49 fbdi_position from dual
      union all select 'LINE_GROUP_NUMBER' column_name, 50 fbdi_position from dual
      union all select 'COST_FACTOR_NAME' column_name, 51 fbdi_position from dual
      union all select 'STAT_AMOUNT' column_name, 52 fbdi_position from dual
      union all select 'ASSETS_TRACKING_FLAG' column_name, 53 fbdi_position from dual
      union all select 'ASSET_BOOK_TYPE_CODE' column_name, 54 fbdi_position from dual
      union all select 'ASSET_CATEGORY_ID' column_name, 55 fbdi_position from dual
      union all select 'SERIAL_NUMBER' column_name, 56 fbdi_position from dual
      union all select 'MANUFACTURER' column_name, 57 fbdi_position from dual
      union all select 'MODEL_NUMBER' column_name, 58 fbdi_position from dual
      union all select 'WARRANTY_NUMBER' column_name, 59 fbdi_position from dual
      union all select 'PRICE_CORRECTION_FLAG' column_name, 60 fbdi_position from dual
      union all select 'PRICE_CORRECT_INV_NUM' column_name, 61 fbdi_position from dual
      union all select 'PRICE_CORRECT_INV_LINE_NUM' column_name, 62 fbdi_position from dual
      union all select 'REQUESTER_FIRST_NAME' column_name, 63 fbdi_position from dual
      union all select 'REQUESTER_LAST_NAME' column_name, 64 fbdi_position from dual
      union all select 'REQUESTER_EMPLOYEE_NUM' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 91 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_CATEGORY' column_name, 92 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE1' column_name, 93 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE2' column_name, 94 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE3' column_name, 95 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE4' column_name, 96 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE5' column_name, 97 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE6' column_name, 98 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE7' column_name, 99 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE8' column_name, 100 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE9' column_name, 101 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE10' column_name, 102 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE11' column_name, 103 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE12' column_name, 104 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE13' column_name, 105 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE14' column_name, 106 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE15' column_name, 107 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE16' column_name, 108 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE17' column_name, 109 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE18' column_name, 110 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE19' column_name, 111 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE20' column_name, 112 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER1' column_name, 113 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER2' column_name, 114 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER3' column_name, 115 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER4' column_name, 116 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_NUMBER5' column_name, 117 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE1' column_name, 118 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE2' column_name, 119 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE3' column_name, 120 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE4' column_name, 121 fbdi_position from dual
      union all select 'GLOBAL_ATTRIBUTE_DATE5' column_name, 122 fbdi_position from dual
      union all select 'PJC_PROJECT_ID' column_name, 123 fbdi_position from dual
      union all select 'PJC_TASK_ID' column_name, 124 fbdi_position from dual
      union all select 'PJC_EXPENDITURE_TYPE_ID' column_name, 125 fbdi_position from dual
      union all select 'PJC_EXPENDITURE_ITEM_DATE' column_name, 126 fbdi_position from dual
      union all select 'PJC_ORGANIZATION_ID' column_name, 127 fbdi_position from dual
      union all select 'PJC_PROJECT_NUMBER' column_name, 128 fbdi_position from dual
      union all select 'PJC_TASK_NUMBER' column_name, 129 fbdi_position from dual
      union all select 'PJC_EXPENDITURE_TYPE_NAME' column_name, 130 fbdi_position from dual
      union all select 'PJC_ORGANIZATION_NAME' column_name, 131 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE1' column_name, 132 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE2' column_name, 133 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE3' column_name, 134 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE4' column_name, 135 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE5' column_name, 136 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE6' column_name, 137 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE7' column_name, 138 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE8' column_name, 139 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE9' column_name, 140 fbdi_position from dual
      union all select 'PJC_RESERVED_ATTRIBUTE10' column_name, 141 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE1' column_name, 142 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE2' column_name, 143 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE3' column_name, 144 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE4' column_name, 145 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE5' column_name, 146 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE6' column_name, 147 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE7' column_name, 148 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE8' column_name, 149 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE9' column_name, 150 fbdi_position from dual
      union all select 'PJC_USER_DEF_ATTRIBUTE10' column_name, 151 fbdi_position from dual
      union all select 'FISCAL_CHARGE_TYPE' column_name, 152 fbdi_position from dual
      union all select 'DEF_ACCTG_START_DATE' column_name, 153 fbdi_position from dual
      union all select 'DEF_ACCTG_END_DATE' column_name, 154 fbdi_position from dual
      union all select 'DEF_ACCRUAL_CODE_CONCATENATED' column_name, 155 fbdi_position from dual
      union all select 'PJC_PROJECT_NAME' column_name, 156 fbdi_position from dual
      union all select 'PJC_TASK_NAME' column_name, 157 fbdi_position from dual
      union all select 'PJC_WORK_TYPE' column_name, 158 fbdi_position from dual
      union all select 'PJC_CONTRACT_NAME' column_name, 159 fbdi_position from dual
      union all select 'PJC_CONTRACT_NUMBER' column_name, 160 fbdi_position from dual
      union all select 'PJC_FUNDING_SOURCE_NAME' column_name, 161 fbdi_position from dual
      union all select 'PJC_FUNDING_SOURCE_NUMBER' column_name, 162 fbdi_position from dual
      union all select 'REQUESTER_EMAIL_ADDRESS' column_name, 163 fbdi_position from dual
      union all select 'RCV_TRANSACTION_ID' column_name, 164 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'ApInvoiceLinesInterface.csv' and f."OBJECT_CODE" = 'AP_INVOICE_LINES_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'ApInvoiceLinesInterface.csv' and f."OBJECT_CODE" = 'AP_INVOICE_LINES_INT')
and   t."COLUMN_NAME" not in ('INVOICE_ID', 'LINE_NUMBER', 'LINE_TYPE_LOOKUP_CODE', 'AMOUNT', 'QUANTITY_INVOICED', 'UNIT_PRICE', 'UNIT_OF_MEAS_LOOKUP_CODE', 'DESCRIPTION', 'PO_NUMBER', 'PO_LINE_NUMBER', 'PO_SHIPMENT_NUM', 'PO_DISTRIBUTION_NUM', 'ITEM_DESCRIPTION', 'RELEASE_NUM', 'PURCHASING_CATEGORY', 'RECEIPT_NUMBER', 'RECEIPT_LINE_NUMBER', 'CONSUMPTION_ADVICE_NUMBER', 'CONSUMPTION_ADVICE_LINE_NUMBER', 'PACKING_SLIP', 'FINAL_MATCH_FLAG', 'DIST_CODE_CONCATENATED', 'DISTRIBUTION_SET_NAME', 'ACCOUNTING_DATE', 'ACCOUNT_SEGMENT', 'BALANCING_SEGMENT', 'COST_CENTER_SEGMENT', 'TAX_CLASSIFICATION_CODE', 'SHIP_TO_LOCATION_CODE', 'SHIP_FROM_LOCATION_CODE', 'FINAL_DISCHARGE_LOCATION_CODE', 'TRX_BUSINESS_CATEGORY', 'PRODUCT_FISC_CLASSIFICATION', 'PRIMARY_INTENDED_USE', 'USER_DEFINED_FISC_CLASS', 'PRODUCT_TYPE', 'ASSESSABLE_VALUE', 'PRODUCT_CATEGORY', 'CONTROL_AMOUNT', 'TAX_REGIME_CODE', 'TAX', 'TAX_STATUS_CODE', 'TAX_JURISDICTION_CODE', 'TAX_RATE_CODE', 'TAX_RATE', 'AWT_GROUP_NAME', 'TYPE_1099', 'INCOME_TAX_REGION', 'PRORATE_ACROSS_FLAG', 'LINE_GROUP_NUMBER', 'COST_FACTOR_NAME', 'STAT_AMOUNT', 'ASSETS_TRACKING_FLAG', 'ASSET_BOOK_TYPE_CODE', 'ASSET_CATEGORY_ID', 'SERIAL_NUMBER', 'MANUFACTURER', 'MODEL_NUMBER', 'WARRANTY_NUMBER', 'PRICE_CORRECTION_FLAG', 'PRICE_CORRECT_INV_NUM', 'PRICE_CORRECT_INV_LINE_NUM', 'REQUESTER_FIRST_NAME', 'REQUESTER_LAST_NAME', 'REQUESTER_EMPLOYEE_NUM', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'GLOBAL_ATTRIBUTE_CATEGORY', 'GLOBAL_ATTRIBUTE1', 'GLOBAL_ATTRIBUTE2', 'GLOBAL_ATTRIBUTE3', 'GLOBAL_ATTRIBUTE4', 'GLOBAL_ATTRIBUTE5', 'GLOBAL_ATTRIBUTE6', 'GLOBAL_ATTRIBUTE7', 'GLOBAL_ATTRIBUTE8', 'GLOBAL_ATTRIBUTE9', 'GLOBAL_ATTRIBUTE10', 'GLOBAL_ATTRIBUTE11', 'GLOBAL_ATTRIBUTE12', 'GLOBAL_ATTRIBUTE13', 'GLOBAL_ATTRIBUTE14', 'GLOBAL_ATTRIBUTE15', 'GLOBAL_ATTRIBUTE16', 'GLOBAL_ATTRIBUTE17', 'GLOBAL_ATTRIBUTE18', 'GLOBAL_ATTRIBUTE19', 'GLOBAL_ATTRIBUTE20', 'GLOBAL_ATTRIBUTE_NUMBER1', 'GLOBAL_ATTRIBUTE_NUMBER2', 'GLOBAL_ATTRIBUTE_NUMBER3', 'GLOBAL_ATTRIBUTE_NUMBER4', 'GLOBAL_ATTRIBUTE_NUMBER5', 'GLOBAL_ATTRIBUTE_DATE1', 'GLOBAL_ATTRIBUTE_DATE2', 'GLOBAL_ATTRIBUTE_DATE3', 'GLOBAL_ATTRIBUTE_DATE4', 'GLOBAL_ATTRIBUTE_DATE5', 'PJC_PROJECT_ID', 'PJC_TASK_ID', 'PJC_EXPENDITURE_TYPE_ID', 'PJC_EXPENDITURE_ITEM_DATE', 'PJC_ORGANIZATION_ID', 'PJC_PROJECT_NUMBER', 'PJC_TASK_NUMBER', 'PJC_EXPENDITURE_TYPE_NAME', 'PJC_ORGANIZATION_NAME', 'PJC_RESERVED_ATTRIBUTE1', 'PJC_RESERVED_ATTRIBUTE2', 'PJC_RESERVED_ATTRIBUTE3', 'PJC_RESERVED_ATTRIBUTE4', 'PJC_RESERVED_ATTRIBUTE5', 'PJC_RESERVED_ATTRIBUTE6', 'PJC_RESERVED_ATTRIBUTE7', 'PJC_RESERVED_ATTRIBUTE8', 'PJC_RESERVED_ATTRIBUTE9', 'PJC_RESERVED_ATTRIBUTE10', 'PJC_USER_DEF_ATTRIBUTE1', 'PJC_USER_DEF_ATTRIBUTE2', 'PJC_USER_DEF_ATTRIBUTE3', 'PJC_USER_DEF_ATTRIBUTE4', 'PJC_USER_DEF_ATTRIBUTE5', 'PJC_USER_DEF_ATTRIBUTE6', 'PJC_USER_DEF_ATTRIBUTE7', 'PJC_USER_DEF_ATTRIBUTE8', 'PJC_USER_DEF_ATTRIBUTE9', 'PJC_USER_DEF_ATTRIBUTE10', 'FISCAL_CHARGE_TYPE', 'DEF_ACCTG_START_DATE', 'DEF_ACCTG_END_DATE', 'DEF_ACCRUAL_CODE_CONCATENATED', 'PJC_PROJECT_NAME', 'PJC_TASK_NAME', 'PJC_WORK_TYPE', 'PJC_CONTRACT_NAME', 'PJC_CONTRACT_NUMBER', 'PJC_FUNDING_SOURCE_NAME', 'PJC_FUNDING_SOURCE_NUMBER', 'REQUESTER_EMAIL_ADDRESS', 'RCV_TRANSACTION_ID');

-- RaInterfaceLinesAll.csv -> RA_LINES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'ORG_ID' column_name, 1 fbdi_position from dual
      union all select 'BATCH_SOURCE_NAME' column_name, 2 fbdi_position from dual
      union all select 'CUST_TRX_TYPE_NAME' column_name, 3 fbdi_position from dual
      union all select 'TERM_NAME' column_name, 4 fbdi_position from dual
      union all select 'TRX_DATE' column_name, 5 fbdi_position from dual
      union all select 'GL_DATE' column_name, 6 fbdi_position from dual
      union all select 'TRX_NUMBER' column_name, 7 fbdi_position from dual
      union all select 'ORIG_SYSTEM_BILL_CUSTOMER_REF' column_name, 8 fbdi_position from dual
      union all select 'ORIG_SYSTEM_BILL_ADDRESS_REF' column_name, 9 fbdi_position from dual
      union all select 'ORIG_SYSTEM_BILL_CONTACT_REF' column_name, 10 fbdi_position from dual
      union all select 'ORIG_SYS_SHIP_PARTY_REF' column_name, 11 fbdi_position from dual
      union all select 'ORIG_SYS_SHIP_PARTY_SITE_REF' column_name, 12 fbdi_position from dual
      union all select 'ORIG_SYS_SHIP_PTY_CONTACT_REF' column_name, 13 fbdi_position from dual
      union all select 'ORIG_SYSTEM_SHIP_CUSTOMER_REF' column_name, 14 fbdi_position from dual
      union all select 'ORIG_SYSTEM_SHIP_ADDRESS_REF' column_name, 15 fbdi_position from dual
      union all select 'ORIG_SYSTEM_SHIP_CONTACT_REF' column_name, 16 fbdi_position from dual
      union all select 'ORIG_SYS_SOLD_PARTY_REF' column_name, 17 fbdi_position from dual
      union all select 'ORIG_SYSTEM_SOLD_CUSTOMER_REF' column_name, 18 fbdi_position from dual
      union all select 'BILL_CUSTOMER_ACCOUNT_NUMBER' column_name, 19 fbdi_position from dual
      union all select 'BILL_CUSTOMER_SITE_NUMBER' column_name, 20 fbdi_position from dual
      union all select 'BILL_CONTACT_PARTY_NUMBER' column_name, 21 fbdi_position from dual
      union all select 'SHIP_CUSTOMER_ACCOUNT_NUMBER' column_name, 22 fbdi_position from dual
      union all select 'SHIP_CUSTOMER_SITE_NUMBER' column_name, 23 fbdi_position from dual
      union all select 'SHIP_CONTACT_PARTY_NUMBER' column_name, 24 fbdi_position from dual
      union all select 'SOLD_CUSTOMER_ACCOUNT_NUMBER' column_name, 25 fbdi_position from dual
      union all select 'LINE_TYPE' column_name, 26 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 27 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 28 fbdi_position from dual
      union all select 'CONVERSION_TYPE' column_name, 29 fbdi_position from dual
      union all select 'CONVERSION_DATE' column_name, 30 fbdi_position from dual
      union all select 'CONVERSION_RATE' column_name, 31 fbdi_position from dual
      union all select 'AMOUNT' column_name, 32 fbdi_position from dual
      union all select 'QUANTITY' column_name, 33 fbdi_position from dual
      union all select 'QUANTITY_ORDERED' column_name, 34 fbdi_position from dual
      union all select 'UNIT_SELLING_PRICE' column_name, 35 fbdi_position from dual
      union all select 'UNIT_STANDARD_PRICE' column_name, 36 fbdi_position from dual
      union all select 'INTERFACE_LINE_CONTEXT' column_name, 37 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE1' column_name, 38 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE2' column_name, 39 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE3' column_name, 40 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE4' column_name, 41 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE5' column_name, 42 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE6' column_name, 43 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE7' column_name, 44 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE8' column_name, 45 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE9' column_name, 46 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE10' column_name, 47 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE11' column_name, 48 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE12' column_name, 49 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE13' column_name, 50 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE14' column_name, 51 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE15' column_name, 52 fbdi_position from dual
      union all select 'PRIMARY_SALESREP_NUMBER' column_name, 53 fbdi_position from dual
      union all select 'TAX_CODE' column_name, 54 fbdi_position from dual
      union all select 'LEGAL_ENTITY_IDENTIFIER' column_name, 55 fbdi_position from dual
      union all select 'ACCTD_AMOUNT' column_name, 56 fbdi_position from dual
      union all select 'SALES_ORDER' column_name, 57 fbdi_position from dual
      union all select 'SALES_ORDER_DATE' column_name, 58 fbdi_position from dual
      union all select 'SHIP_DATE_ACTUAL' column_name, 59 fbdi_position from dual
      union all select 'WAREHOUSE_CODE' column_name, 60 fbdi_position from dual
      union all select 'UOM_CODE' column_name, 61 fbdi_position from dual
      union all select 'UOM_NAME' column_name, 62 fbdi_position from dual
      union all select 'INVOICING_RULE_NAME' column_name, 63 fbdi_position from dual
      union all select 'ACCOUNTING_RULE_NAME' column_name, 64 fbdi_position from dual
      union all select 'ACCOUNTING_RULE_DURATION' column_name, 65 fbdi_position from dual
      union all select 'RULE_START_DATE' column_name, 66 fbdi_position from dual
      union all select 'RULE_END_DATE' column_name, 67 fbdi_position from dual
      union all select 'REASON_CODE_MEANING' column_name, 68 fbdi_position from dual
      union all select 'LAST_PERIOD_TO_CREDIT' column_name, 69 fbdi_position from dual
      union all select 'TRX_BUSINESS_CATEGORY' column_name, 70 fbdi_position from dual
      union all select 'PRODUCT_FISC_CLASSIFICATION' column_name, 71 fbdi_position from dual
      union all select 'PRODUCT_CATEGORY' column_name, 72 fbdi_position from dual
      union all select 'PRODUCT_TYPE' column_name, 73 fbdi_position from dual
      union all select 'LINE_INTENDED_USE' column_name, 74 fbdi_position from dual
      union all select 'ASSESSABLE_VALUE' column_name, 75 fbdi_position from dual
      union all select 'DOCUMENT_SUB_TYPE' column_name, 76 fbdi_position from dual
      union all select 'DEFAULT_TAXATION_COUNTRY' column_name, 77 fbdi_position from dual
      union all select 'USER_DEFINED_FISC_CLASS' column_name, 78 fbdi_position from dual
      union all select 'TAX_INVOICE_NUMBER' column_name, 79 fbdi_position from dual
      union all select 'TAX_INVOICE_DATE' column_name, 80 fbdi_position from dual
      union all select 'TAX_REGIME_CODE' column_name, 81 fbdi_position from dual
      union all select 'TAX' column_name, 82 fbdi_position from dual
      union all select 'TAX_STATUS_CODE' column_name, 83 fbdi_position from dual
      union all select 'TAX_RATE_CODE' column_name, 84 fbdi_position from dual
      union all select 'TAX_JURISDICTION_CODE' column_name, 85 fbdi_position from dual
      union all select 'FIRST_PTY_REG_NUM' column_name, 86 fbdi_position from dual
      union all select 'THIRD_PTY_REG_NUM' column_name, 87 fbdi_position from dual
      union all select 'FINAL_DISCHARGE_LOCATION_CODE' column_name, 88 fbdi_position from dual
      union all select 'TAXABLE_AMOUNT' column_name, 89 fbdi_position from dual
      union all select 'TAXABLE_FLAG' column_name, 90 fbdi_position from dual
      union all select 'TAX_EXEMPT_FLAG' column_name, 91 fbdi_position from dual
      union all select 'TAX_EXEMPT_REASON_CODE' column_name, 92 fbdi_position from dual
      union all select 'TAX_EXEMPT_REASON_CODE_MEANING' column_name, 93 fbdi_position from dual
      union all select 'TAX_EXEMPT_NUMBER' column_name, 94 fbdi_position from dual
      union all select 'AMOUNT_INCLUDES_TAX_FLAG' column_name, 95 fbdi_position from dual
      union all select 'TAX_PRECEDENCE' column_name, 96 fbdi_position from dual
      union all select 'CREDIT_METHOD_FOR_ACCT_RULE' column_name, 97 fbdi_position from dual
      union all select 'CREDIT_METHOD_FOR_INSTALLMENTS' column_name, 98 fbdi_position from dual
      union all select 'REASON_CODE' column_name, 99 fbdi_position from dual
      union all select 'TAX_RATE' column_name, 100 fbdi_position from dual
      union all select 'FOB_POINT' column_name, 101 fbdi_position from dual
      union all select 'SHIP_VIA' column_name, 102 fbdi_position from dual
      union all select 'WAYBILL_NUMBER' column_name, 103 fbdi_position from dual
      union all select 'SALES_ORDER_LINE' column_name, 104 fbdi_position from dual
      union all select 'SALES_ORDER_SOURCE' column_name, 105 fbdi_position from dual
      union all select 'SALES_ORDER_REVISION' column_name, 106 fbdi_position from dual
      union all select 'PURCHASE_ORDER' column_name, 107 fbdi_position from dual
      union all select 'PURCHASE_ORDER_REVISION' column_name, 108 fbdi_position from dual
      union all select 'PURCHASE_ORDER_DATE' column_name, 109 fbdi_position from dual
      union all select 'AGREEMENT_NAME' column_name, 110 fbdi_position from dual
      union all select 'MEMO_LINE_NAME' column_name, 111 fbdi_position from dual
      union all select 'DOCUMENT_NUMBER' column_name, 112 fbdi_position from dual
      union all select 'ORIG_SYSTEM_BATCH_NAME' column_name, 113 fbdi_position from dual
      union all select 'LINK_TO_LINE_CONTEXT' column_name, 114 fbdi_position from dual
      union all select 'LINK_TO_LINE_ATTRIBUTE1' column_name, 115 fbdi_position from dual
      union all select 'LINK_TO_LINE_ATTRIBUTE2' column_name, 116 fbdi_position from dual
      union all select 'LINK_TO_LINE_ATTRIBUTE3' column_name, 117 fbdi_position from dual
      union all select 'LINK_TO_LINE_ATTRIBUTE4' column_name, 118 fbdi_position from dual
      union all select 'LINK_TO_LINE_ATTRIBUTE5' column_name, 119 fbdi_position from dual
      union all select 'LINK_TO_LINE_ATTRIBUTE6' column_name, 120 fbdi_position from dual
      union all select 'RECEIPT_METHOD_NAME' column_name, 162 fbdi_position from dual
      union all select 'PRINTING_OPTION' column_name, 163 fbdi_position from dual
      union all select 'RELATED_BATCH_SOURCE_NAME' column_name, 164 fbdi_position from dual
      union all select 'RELATED_TRX_NUMBER' column_name, 165 fbdi_position from dual
      union all select 'TRANSLATED_DESCRIPTION' column_name, 192 fbdi_position from dual
      union all select 'CONS_BILLING_NUMBER' column_name, 193 fbdi_position from dual
      union all select 'PROMISED_COMMITMENT_AMOUNT' column_name, 194 fbdi_position from dual
      union all select 'PAYMENT_SET_ID' column_name, 195 fbdi_position from dual
      union all select 'ORIGINAL_GL_DATE' column_name, 196 fbdi_position from dual
      union all select 'INVOICED_LINE_ACCTG_LEVEL' column_name, 197 fbdi_position from dual
      union all select 'OVERRIDE_AUTO_ACCOUNTING_FLAG' column_name, 198 fbdi_position from dual
      union all select 'HISTORICAL_FLAG' column_name, 199 fbdi_position from dual
      union all select 'DEFERRAL_EXCLUSION_FLAG' column_name, 200 fbdi_position from dual
      union all select 'BILLING_DATE' column_name, 202 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 203 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 204 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 205 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 206 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 207 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 208 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 209 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 210 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 211 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 212 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 213 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 214 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 215 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 216 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 217 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 218 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE_CATEGORY' column_name, 219 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE1' column_name, 220 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE2' column_name, 221 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE3' column_name, 222 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE4' column_name, 223 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE5' column_name, 224 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE6' column_name, 225 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE7' column_name, 226 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE8' column_name, 227 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE9' column_name, 228 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE10' column_name, 229 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE11' column_name, 230 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE12' column_name, 231 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE13' column_name, 232 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE14' column_name, 233 fbdi_position from dual
      union all select 'HEADER_ATTRIBUTE15' column_name, 234 fbdi_position from dual
      union all select 'BU_NAME' column_name, 287 fbdi_position from dual
      union all select 'COMMENTS' column_name, 288 fbdi_position from dual
      union all select 'INTERNAL_NOTES' column_name, 289 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'RaInterfaceLinesAll.csv' and f."OBJECT_CODE" = 'RA_LINES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'RaInterfaceLinesAll.csv' and f."OBJECT_CODE" = 'RA_LINES')
and   t."COLUMN_NAME" not in ('ORG_ID', 'BATCH_SOURCE_NAME', 'CUST_TRX_TYPE_NAME', 'TERM_NAME', 'TRX_DATE', 'GL_DATE', 'TRX_NUMBER', 'ORIG_SYSTEM_BILL_CUSTOMER_REF', 'ORIG_SYSTEM_BILL_ADDRESS_REF', 'ORIG_SYSTEM_BILL_CONTACT_REF', 'ORIG_SYS_SHIP_PARTY_REF', 'ORIG_SYS_SHIP_PARTY_SITE_REF', 'ORIG_SYS_SHIP_PTY_CONTACT_REF', 'ORIG_SYSTEM_SHIP_CUSTOMER_REF', 'ORIG_SYSTEM_SHIP_ADDRESS_REF', 'ORIG_SYSTEM_SHIP_CONTACT_REF', 'ORIG_SYS_SOLD_PARTY_REF', 'ORIG_SYSTEM_SOLD_CUSTOMER_REF', 'BILL_CUSTOMER_ACCOUNT_NUMBER', 'BILL_CUSTOMER_SITE_NUMBER', 'BILL_CONTACT_PARTY_NUMBER', 'SHIP_CUSTOMER_ACCOUNT_NUMBER', 'SHIP_CUSTOMER_SITE_NUMBER', 'SHIP_CONTACT_PARTY_NUMBER', 'SOLD_CUSTOMER_ACCOUNT_NUMBER', 'LINE_TYPE', 'DESCRIPTION', 'CURRENCY_CODE', 'CONVERSION_TYPE', 'CONVERSION_DATE', 'CONVERSION_RATE', 'AMOUNT', 'QUANTITY', 'QUANTITY_ORDERED', 'UNIT_SELLING_PRICE', 'UNIT_STANDARD_PRICE', 'INTERFACE_LINE_CONTEXT', 'INTERFACE_LINE_ATTRIBUTE1', 'INTERFACE_LINE_ATTRIBUTE2', 'INTERFACE_LINE_ATTRIBUTE3', 'INTERFACE_LINE_ATTRIBUTE4', 'INTERFACE_LINE_ATTRIBUTE5', 'INTERFACE_LINE_ATTRIBUTE6', 'INTERFACE_LINE_ATTRIBUTE7', 'INTERFACE_LINE_ATTRIBUTE8', 'INTERFACE_LINE_ATTRIBUTE9', 'INTERFACE_LINE_ATTRIBUTE10', 'INTERFACE_LINE_ATTRIBUTE11', 'INTERFACE_LINE_ATTRIBUTE12', 'INTERFACE_LINE_ATTRIBUTE13', 'INTERFACE_LINE_ATTRIBUTE14', 'INTERFACE_LINE_ATTRIBUTE15', 'PRIMARY_SALESREP_NUMBER', 'TAX_CODE', 'LEGAL_ENTITY_IDENTIFIER', 'ACCTD_AMOUNT', 'SALES_ORDER', 'SALES_ORDER_DATE', 'SHIP_DATE_ACTUAL', 'WAREHOUSE_CODE', 'UOM_CODE', 'UOM_NAME', 'INVOICING_RULE_NAME', 'ACCOUNTING_RULE_NAME', 'ACCOUNTING_RULE_DURATION', 'RULE_START_DATE', 'RULE_END_DATE', 'REASON_CODE_MEANING', 'LAST_PERIOD_TO_CREDIT', 'TRX_BUSINESS_CATEGORY', 'PRODUCT_FISC_CLASSIFICATION', 'PRODUCT_CATEGORY', 'PRODUCT_TYPE', 'LINE_INTENDED_USE', 'ASSESSABLE_VALUE', 'DOCUMENT_SUB_TYPE', 'DEFAULT_TAXATION_COUNTRY', 'USER_DEFINED_FISC_CLASS', 'TAX_INVOICE_NUMBER', 'TAX_INVOICE_DATE', 'TAX_REGIME_CODE', 'TAX', 'TAX_STATUS_CODE', 'TAX_RATE_CODE', 'TAX_JURISDICTION_CODE', 'FIRST_PTY_REG_NUM', 'THIRD_PTY_REG_NUM', 'FINAL_DISCHARGE_LOCATION_CODE', 'TAXABLE_AMOUNT', 'TAXABLE_FLAG', 'TAX_EXEMPT_FLAG', 'TAX_EXEMPT_REASON_CODE', 'TAX_EXEMPT_REASON_CODE_MEANING', 'TAX_EXEMPT_NUMBER', 'AMOUNT_INCLUDES_TAX_FLAG', 'TAX_PRECEDENCE', 'CREDIT_METHOD_FOR_ACCT_RULE', 'CREDIT_METHOD_FOR_INSTALLMENTS', 'REASON_CODE', 'TAX_RATE', 'FOB_POINT', 'SHIP_VIA', 'WAYBILL_NUMBER', 'SALES_ORDER_LINE', 'SALES_ORDER_SOURCE', 'SALES_ORDER_REVISION', 'PURCHASE_ORDER', 'PURCHASE_ORDER_REVISION', 'PURCHASE_ORDER_DATE', 'AGREEMENT_NAME', 'MEMO_LINE_NAME', 'DOCUMENT_NUMBER', 'ORIG_SYSTEM_BATCH_NAME', 'LINK_TO_LINE_CONTEXT', 'LINK_TO_LINE_ATTRIBUTE1', 'LINK_TO_LINE_ATTRIBUTE2', 'LINK_TO_LINE_ATTRIBUTE3', 'LINK_TO_LINE_ATTRIBUTE4', 'LINK_TO_LINE_ATTRIBUTE5', 'LINK_TO_LINE_ATTRIBUTE6', 'RECEIPT_METHOD_NAME', 'PRINTING_OPTION', 'RELATED_BATCH_SOURCE_NAME', 'RELATED_TRX_NUMBER', 'TRANSLATED_DESCRIPTION', 'CONS_BILLING_NUMBER', 'PROMISED_COMMITMENT_AMOUNT', 'PAYMENT_SET_ID', 'ORIGINAL_GL_DATE', 'INVOICED_LINE_ACCTG_LEVEL', 'OVERRIDE_AUTO_ACCOUNTING_FLAG', 'HISTORICAL_FLAG', 'DEFERRAL_EXCLUSION_FLAG', 'BILLING_DATE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'HEADER_ATTRIBUTE_CATEGORY', 'HEADER_ATTRIBUTE1', 'HEADER_ATTRIBUTE2', 'HEADER_ATTRIBUTE3', 'HEADER_ATTRIBUTE4', 'HEADER_ATTRIBUTE5', 'HEADER_ATTRIBUTE6', 'HEADER_ATTRIBUTE7', 'HEADER_ATTRIBUTE8', 'HEADER_ATTRIBUTE9', 'HEADER_ATTRIBUTE10', 'HEADER_ATTRIBUTE11', 'HEADER_ATTRIBUTE12', 'HEADER_ATTRIBUTE13', 'HEADER_ATTRIBUTE14', 'HEADER_ATTRIBUTE15', 'BU_NAME', 'COMMENTS', 'INTERNAL_NOTES');

-- PjbBillingEventsXface.csv -> PJB_BILL_EVENTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'SOURCENAME' column_name, 1 fbdi_position from dual
      union all select 'SOURCEREF' column_name, 2 fbdi_position from dual
      union all select 'ORGANIZATION_NAME' column_name, 3 fbdi_position from dual
      union all select 'CONTRACT_TYPE_NAME' column_name, 4 fbdi_position from dual
      union all select 'CONTRACT_NUMBER' column_name, 5 fbdi_position from dual
      union all select 'CONTRACT_LINE_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'EVENT_TYPE_NAME' column_name, 7 fbdi_position from dual
      union all select 'EVENT_DESC' column_name, 8 fbdi_position from dual
      union all select 'COMPLETION_DATE' column_name, 9 fbdi_position from dual
      union all select 'BILL_TRNS_CURRENCY_CODE' column_name, 10 fbdi_position from dual
      union all select 'BILL_TRNS_AMOUNT' column_name, 11 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 12 fbdi_position from dual
      union all select 'TASK_NUMBER' column_name, 13 fbdi_position from dual
      union all select 'BILL_HOLD_FLAG' column_name, 14 fbdi_position from dual
      union all select 'REVENUE_HOLD_FLAG' column_name, 15 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 16 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR11' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR12' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR13' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR14' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR15' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR16' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR17' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR18' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR19' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR20' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR21' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR22' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR23' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR24' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR25' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR26' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR27' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR28' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR29' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE_CHAR30' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 71 fbdi_position from dual
      union all select 'REVERSE_ACCRUAL_FLAG' column_name, 72 fbdi_position from dual
      union all select 'ITEM_EVENT_FLAG' column_name, 73 fbdi_position from dual
      union all select 'QUANTITY' column_name, 74 fbdi_position from dual
      union all select 'ITEM_NUMBER' column_name, 75 fbdi_position from dual
      union all select 'UNIT_OF_MEASURE' column_name, 76 fbdi_position from dual
      union all select 'UNIT_PRICE' column_name, 77 fbdi_position from dual
      union all select 'PREPAYMENT_REQ_EVENT_NUM' column_name, 78 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PjbBillingEventsXface.csv' and f."OBJECT_CODE" = 'PJB_BILL_EVENTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PjbBillingEventsXface.csv' and f."OBJECT_CODE" = 'PJB_BILL_EVENTS')
and   t."COLUMN_NAME" not in ('SOURCENAME', 'SOURCEREF', 'ORGANIZATION_NAME', 'CONTRACT_TYPE_NAME', 'CONTRACT_NUMBER', 'CONTRACT_LINE_NUMBER', 'EVENT_TYPE_NAME', 'EVENT_DESC', 'COMPLETION_DATE', 'BILL_TRNS_CURRENCY_CODE', 'BILL_TRNS_AMOUNT', 'PROJECT_NUMBER', 'TASK_NUMBER', 'BILL_HOLD_FLAG', 'REVENUE_HOLD_FLAG', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE_CHAR11', 'ATTRIBUTE_CHAR12', 'ATTRIBUTE_CHAR13', 'ATTRIBUTE_CHAR14', 'ATTRIBUTE_CHAR15', 'ATTRIBUTE_CHAR16', 'ATTRIBUTE_CHAR17', 'ATTRIBUTE_CHAR18', 'ATTRIBUTE_CHAR19', 'ATTRIBUTE_CHAR20', 'ATTRIBUTE_CHAR21', 'ATTRIBUTE_CHAR22', 'ATTRIBUTE_CHAR23', 'ATTRIBUTE_CHAR24', 'ATTRIBUTE_CHAR25', 'ATTRIBUTE_CHAR26', 'ATTRIBUTE_CHAR27', 'ATTRIBUTE_CHAR28', 'ATTRIBUTE_CHAR29', 'ATTRIBUTE_CHAR30', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'REVERSE_ACCRUAL_FLAG', 'ITEM_EVENT_FLAG', 'QUANTITY', 'ITEM_NUMBER', 'UNIT_OF_MEASURE', 'UNIT_PRICE', 'PREPAYMENT_REQ_EVENT_NUM');

-- PjcTxnXfaceStageAll.csv -> PJC_EXPENDITURES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'TRANSACTION_TYPE' column_name, 1 fbdi_position from dual
      union all select 'BUSINESS_UNIT' column_name, 2 fbdi_position from dual
      union all select 'ORG_ID' column_name, 3 fbdi_position from dual
      union all select 'USER_TRANSACTION_SOURCE' column_name, 4 fbdi_position from dual
      union all select 'TRANSACTION_SOURCE_ID' column_name, 5 fbdi_position from dual
      union all select 'DOCUMENT_NAME' column_name, 6 fbdi_position from dual
      union all select 'DOCUMENT_ID' column_name, 7 fbdi_position from dual
      union all select 'DOC_ENTRY_NAME' column_name, 8 fbdi_position from dual
      union all select 'DOC_ENTRY_ID' column_name, 9 fbdi_position from dual
      union all select 'BATCH_NAME' column_name, 10 fbdi_position from dual
      union all select 'BATCH_ENDING_DATE' column_name, 11 fbdi_position from dual
      union all select 'BATCH_DESCRIPTION' column_name, 12 fbdi_position from dual
      union all select 'EXPENDITURE_ITEM_DATE' column_name, 13 fbdi_position from dual
      union all select 'PERSON_NUMBER' column_name, 14 fbdi_position from dual
      union all select 'PERSON_NAME' column_name, 15 fbdi_position from dual
      union all select 'PERSON_ID' column_name, 16 fbdi_position from dual
      union all select 'HCM_ASSIGNMENT_NAME' column_name, 17 fbdi_position from dual
      union all select 'HCM_ASSIGNMENT_ID' column_name, 18 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 19 fbdi_position from dual
      union all select 'PROJECT_NAME' column_name, 20 fbdi_position from dual
      union all select 'PROJECT_ID' column_name, 21 fbdi_position from dual
      union all select 'TASK_NUMBER' column_name, 22 fbdi_position from dual
      union all select 'TASK_NAME' column_name, 23 fbdi_position from dual
      union all select 'TASK_ID' column_name, 24 fbdi_position from dual
      union all select 'EXPENDITURE_TYPE' column_name, 25 fbdi_position from dual
      union all select 'EXPENDITURE_TYPE_ID' column_name, 26 fbdi_position from dual
      union all select 'ORGANIZATION_NAME' column_name, 27 fbdi_position from dual
      union all select 'ORGANIZATION_ID' column_name, 28 fbdi_position from dual
      union all select 'QUANTITY' column_name, 29 fbdi_position from dual
      union all select 'UNIT_OF_MEASURE_NAME' column_name, 30 fbdi_position from dual
      union all select 'UNIT_OF_MEASURE' column_name, 31 fbdi_position from dual
      union all select 'WORK_TYPE' column_name, 32 fbdi_position from dual
      union all select 'WORK_TYPE_ID' column_name, 33 fbdi_position from dual
      union all select 'BILLABLE_FLAG' column_name, 34 fbdi_position from dual
      union all select 'CAPITALIZABLE_FLAG' column_name, 35 fbdi_position from dual
      union all select 'ORIG_TRANSACTION_REFERENCE' column_name, 36 fbdi_position from dual
      union all select 'UNMATCHED_NEGATIVE_TXN_FLAG' column_name, 37 fbdi_position from dual
      union all select 'REVERSED_ORIG_TXN_REFERENCE' column_name, 38 fbdi_position from dual
      union all select 'EXPENDITURE_COMMENT' column_name, 39 fbdi_position from dual
      union all select 'GL_DATE' column_name, 40 fbdi_position from dual
      union all select 'DENOM_CURRENCY_CODE' column_name, 41 fbdi_position from dual
      union all select 'DENOM_CURRENCY' column_name, 42 fbdi_position from dual
      union all select 'DENOM_RAW_COST' column_name, 43 fbdi_position from dual
      union all select 'DENOM_BURDENED_COST' column_name, 44 fbdi_position from dual
      union all select 'RAW_COST_CR_CCID' column_name, 45 fbdi_position from dual
      union all select 'RAW_COST_CR_ACCOUNT' column_name, 46 fbdi_position from dual
      union all select 'RAW_COST_DR_CCID' column_name, 47 fbdi_position from dual
      union all select 'RAW_COST_DR_ACCOUNT' column_name, 48 fbdi_position from dual
      union all select 'BURDENED_COST_CR_CCID' column_name, 49 fbdi_position from dual
      union all select 'BURDENED_COST_CR_ACCOUNT' column_name, 50 fbdi_position from dual
      union all select 'BURDENED_COST_DR_CCID' column_name, 51 fbdi_position from dual
      union all select 'BURDENED_COST_DR_ACCOUNT' column_name, 52 fbdi_position from dual
      union all select 'BURDEN_COST_CR_CCID' column_name, 53 fbdi_position from dual
      union all select 'BURDEN_COST_CR_ACCOUNT' column_name, 54 fbdi_position from dual
      union all select 'BURDEN_COST_DR_CCID' column_name, 55 fbdi_position from dual
      union all select 'BURDEN_COST_DR_ACCOUNT' column_name, 56 fbdi_position from dual
      union all select 'ACCT_CURRENCY_CODE' column_name, 57 fbdi_position from dual
      union all select 'ACCT_CURRENCY' column_name, 58 fbdi_position from dual
      union all select 'ACCT_RAW_COST' column_name, 59 fbdi_position from dual
      union all select 'ACCT_BURDENED_COST' column_name, 60 fbdi_position from dual
      union all select 'ACCT_RATE_TYPE' column_name, 61 fbdi_position from dual
      union all select 'ACCT_RATE_DATE' column_name, 62 fbdi_position from dual
      union all select 'ACCT_RATE_DATE_TYPE' column_name, 63 fbdi_position from dual
      union all select 'ACCT_EXCHANGE_RATE' column_name, 64 fbdi_position from dual
      union all select 'ACCT_EXCHANGE_ROUNDING_LIMIT' column_name, 65 fbdi_position from dual
      union all select 'CONVERTED_FLAG' column_name, 66 fbdi_position from dual
      union all select 'CONTEXT_CATEGORY' column_name, 67 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE1' column_name, 68 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE2' column_name, 69 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE3' column_name, 70 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE4' column_name, 71 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE5' column_name, 72 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE6' column_name, 73 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE7' column_name, 74 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE8' column_name, 75 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE9' column_name, 76 fbdi_position from dual
      union all select 'USER_DEF_ATTRIBUTE10' column_name, 77 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE1' column_name, 78 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE2' column_name, 79 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE3' column_name, 80 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE4' column_name, 81 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE5' column_name, 82 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE6' column_name, 83 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE7' column_name, 84 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE8' column_name, 85 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE9' column_name, 86 fbdi_position from dual
      union all select 'RESERVED_ATTRIBUTE10' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 98 fbdi_position from dual
      union all select 'CONTRACT_NUMBER' column_name, 99 fbdi_position from dual
      union all select 'CONTRACT_NAME' column_name, 100 fbdi_position from dual
      union all select 'CONTRACT_ID' column_name, 101 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NUMBER' column_name, 102 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NAME' column_name, 103 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PjcTxnXfaceStageAll.csv' and f."OBJECT_CODE" = 'PJC_EXPENDITURES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PjcTxnXfaceStageAll.csv' and f."OBJECT_CODE" = 'PJC_EXPENDITURES')
and   t."COLUMN_NAME" not in ('TRANSACTION_TYPE', 'BUSINESS_UNIT', 'ORG_ID', 'USER_TRANSACTION_SOURCE', 'TRANSACTION_SOURCE_ID', 'DOCUMENT_NAME', 'DOCUMENT_ID', 'DOC_ENTRY_NAME', 'DOC_ENTRY_ID', 'BATCH_NAME', 'BATCH_ENDING_DATE', 'BATCH_DESCRIPTION', 'EXPENDITURE_ITEM_DATE', 'PERSON_NUMBER', 'PERSON_NAME', 'PERSON_ID', 'HCM_ASSIGNMENT_NAME', 'HCM_ASSIGNMENT_ID', 'PROJECT_NUMBER', 'PROJECT_NAME', 'PROJECT_ID', 'TASK_NUMBER', 'TASK_NAME', 'TASK_ID', 'EXPENDITURE_TYPE', 'EXPENDITURE_TYPE_ID', 'ORGANIZATION_NAME', 'ORGANIZATION_ID', 'QUANTITY', 'UNIT_OF_MEASURE_NAME', 'UNIT_OF_MEASURE', 'WORK_TYPE', 'WORK_TYPE_ID', 'BILLABLE_FLAG', 'CAPITALIZABLE_FLAG', 'ORIG_TRANSACTION_REFERENCE', 'UNMATCHED_NEGATIVE_TXN_FLAG', 'REVERSED_ORIG_TXN_REFERENCE', 'EXPENDITURE_COMMENT', 'GL_DATE', 'DENOM_CURRENCY_CODE', 'DENOM_CURRENCY', 'DENOM_RAW_COST', 'DENOM_BURDENED_COST', 'RAW_COST_CR_CCID', 'RAW_COST_CR_ACCOUNT', 'RAW_COST_DR_CCID', 'RAW_COST_DR_ACCOUNT', 'BURDENED_COST_CR_CCID', 'BURDENED_COST_CR_ACCOUNT', 'BURDENED_COST_DR_CCID', 'BURDENED_COST_DR_ACCOUNT', 'BURDEN_COST_CR_CCID', 'BURDEN_COST_CR_ACCOUNT', 'BURDEN_COST_DR_CCID', 'BURDEN_COST_DR_ACCOUNT', 'ACCT_CURRENCY_CODE', 'ACCT_CURRENCY', 'ACCT_RAW_COST', 'ACCT_BURDENED_COST', 'ACCT_RATE_TYPE', 'ACCT_RATE_DATE', 'ACCT_RATE_DATE_TYPE', 'ACCT_EXCHANGE_RATE', 'ACCT_EXCHANGE_ROUNDING_LIMIT', 'CONVERTED_FLAG', 'CONTEXT_CATEGORY', 'USER_DEF_ATTRIBUTE1', 'USER_DEF_ATTRIBUTE2', 'USER_DEF_ATTRIBUTE3', 'USER_DEF_ATTRIBUTE4', 'USER_DEF_ATTRIBUTE5', 'USER_DEF_ATTRIBUTE6', 'USER_DEF_ATTRIBUTE7', 'USER_DEF_ATTRIBUTE8', 'USER_DEF_ATTRIBUTE9', 'USER_DEF_ATTRIBUTE10', 'RESERVED_ATTRIBUTE1', 'RESERVED_ATTRIBUTE2', 'RESERVED_ATTRIBUTE3', 'RESERVED_ATTRIBUTE4', 'RESERVED_ATTRIBUTE5', 'RESERVED_ATTRIBUTE6', 'RESERVED_ATTRIBUTE7', 'RESERVED_ATTRIBUTE8', 'RESERVED_ATTRIBUTE9', 'RESERVED_ATTRIBUTE10', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'CONTRACT_NUMBER', 'CONTRACT_NAME', 'CONTRACT_ID', 'FUNDING_SOURCE_NUMBER', 'FUNDING_SOURCE_NAME');

-- RaInterfaceDistributionsAll.csv -> RA_DISTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'ORG_ID' column_name, 1 fbdi_position from dual
      union all select 'ACCOUNT_CLASS' column_name, 2 fbdi_position from dual
      union all select 'AMOUNT' column_name, 3 fbdi_position from dual
      union all select 'PERCENT' column_name, 4 fbdi_position from dual
      union all select 'ACCTD_AMOUNT' column_name, 5 fbdi_position from dual
      union all select 'INTERFACE_LINE_CONTEXT' column_name, 6 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE1' column_name, 7 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE2' column_name, 8 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE3' column_name, 9 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE4' column_name, 10 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE5' column_name, 11 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE6' column_name, 12 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE7' column_name, 13 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE8' column_name, 14 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE9' column_name, 15 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE10' column_name, 16 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE11' column_name, 17 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE12' column_name, 18 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE13' column_name, 19 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE14' column_name, 20 fbdi_position from dual
      union all select 'INTERFACE_LINE_ATTRIBUTE15' column_name, 21 fbdi_position from dual
      union all select 'SEGMENT1' column_name, 22 fbdi_position from dual
      union all select 'SEGMENT2' column_name, 23 fbdi_position from dual
      union all select 'SEGMENT3' column_name, 24 fbdi_position from dual
      union all select 'SEGMENT4' column_name, 25 fbdi_position from dual
      union all select 'SEGMENT5' column_name, 26 fbdi_position from dual
      union all select 'SEGMENT6' column_name, 27 fbdi_position from dual
      union all select 'SEGMENT7' column_name, 28 fbdi_position from dual
      union all select 'SEGMENT8' column_name, 29 fbdi_position from dual
      union all select 'SEGMENT9' column_name, 30 fbdi_position from dual
      union all select 'SEGMENT10' column_name, 31 fbdi_position from dual
      union all select 'SEGMENT11' column_name, 32 fbdi_position from dual
      union all select 'SEGMENT12' column_name, 33 fbdi_position from dual
      union all select 'SEGMENT13' column_name, 34 fbdi_position from dual
      union all select 'SEGMENT14' column_name, 35 fbdi_position from dual
      union all select 'SEGMENT15' column_name, 36 fbdi_position from dual
      union all select 'SEGMENT16' column_name, 37 fbdi_position from dual
      union all select 'SEGMENT17' column_name, 38 fbdi_position from dual
      union all select 'SEGMENT18' column_name, 39 fbdi_position from dual
      union all select 'SEGMENT19' column_name, 40 fbdi_position from dual
      union all select 'SEGMENT20' column_name, 41 fbdi_position from dual
      union all select 'SEGMENT21' column_name, 42 fbdi_position from dual
      union all select 'SEGMENT22' column_name, 43 fbdi_position from dual
      union all select 'SEGMENT23' column_name, 44 fbdi_position from dual
      union all select 'SEGMENT24' column_name, 45 fbdi_position from dual
      union all select 'SEGMENT25' column_name, 46 fbdi_position from dual
      union all select 'SEGMENT26' column_name, 47 fbdi_position from dual
      union all select 'SEGMENT27' column_name, 48 fbdi_position from dual
      union all select 'SEGMENT28' column_name, 49 fbdi_position from dual
      union all select 'SEGMENT29' column_name, 50 fbdi_position from dual
      union all select 'SEGMENT30' column_name, 51 fbdi_position from dual
      union all select 'COMMENTS' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 97 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 98 fbdi_position from dual
      union all select 'BU_NAME' column_name, 99 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'RaInterfaceDistributionsAll.csv' and f."OBJECT_CODE" = 'RA_DISTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'RaInterfaceDistributionsAll.csv' and f."OBJECT_CODE" = 'RA_DISTS')
and   t."COLUMN_NAME" not in ('ORG_ID', 'ACCOUNT_CLASS', 'AMOUNT', 'PERCENT', 'ACCTD_AMOUNT', 'INTERFACE_LINE_CONTEXT', 'INTERFACE_LINE_ATTRIBUTE1', 'INTERFACE_LINE_ATTRIBUTE2', 'INTERFACE_LINE_ATTRIBUTE3', 'INTERFACE_LINE_ATTRIBUTE4', 'INTERFACE_LINE_ATTRIBUTE5', 'INTERFACE_LINE_ATTRIBUTE6', 'INTERFACE_LINE_ATTRIBUTE7', 'INTERFACE_LINE_ATTRIBUTE8', 'INTERFACE_LINE_ATTRIBUTE9', 'INTERFACE_LINE_ATTRIBUTE10', 'INTERFACE_LINE_ATTRIBUTE11', 'INTERFACE_LINE_ATTRIBUTE12', 'INTERFACE_LINE_ATTRIBUTE13', 'INTERFACE_LINE_ATTRIBUTE14', 'INTERFACE_LINE_ATTRIBUTE15', 'SEGMENT1', 'SEGMENT2', 'SEGMENT3', 'SEGMENT4', 'SEGMENT5', 'SEGMENT6', 'SEGMENT7', 'SEGMENT8', 'SEGMENT9', 'SEGMENT10', 'SEGMENT11', 'SEGMENT12', 'SEGMENT13', 'SEGMENT14', 'SEGMENT15', 'SEGMENT16', 'SEGMENT17', 'SEGMENT18', 'SEGMENT19', 'SEGMENT20', 'SEGMENT21', 'SEGMENT22', 'SEGMENT23', 'SEGMENT24', 'SEGMENT25', 'SEGMENT26', 'SEGMENT27', 'SEGMENT28', 'SEGMENT29', 'SEGMENT30', 'COMMENTS', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'BU_NAME');

-- InvTransactionsInterface.csv -> INV_TRX
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'ORGANIZATION_NAME' column_name, 1 fbdi_position from dual
      union all select 'TRANSACTION_GROUP_ID' column_name, 2 fbdi_position from dual
      union all select 'TRANSACTION_GROUP_SEQ' column_name, 3 fbdi_position from dual
      union all select 'TRANSACTION_BATCH_ID' column_name, 4 fbdi_position from dual
      union all select 'TRANSACTION_BATCH_SEQ' column_name, 5 fbdi_position from dual
      union all select 'PROCESS_FLAG' column_name, 6 fbdi_position from dual
      union all select 'INVENTORY_ITEM' column_name, 7 fbdi_position from dual
      union all select 'ITEM_NUMBER' column_name, 8 fbdi_position from dual
      union all select 'REVISION' column_name, 9 fbdi_position from dual
      union all select 'INV_LOTSERIAL_INTERFACE_NUM' column_name, 10 fbdi_position from dual
      union all select 'SUBINVENTORY_CODE' column_name, 11 fbdi_position from dual
      union all select 'LOCATOR_NAME' column_name, 12 fbdi_position from dual
      union all select 'LOC_SEGMENT1' column_name, 13 fbdi_position from dual
      union all select 'LOC_SEGMENT2' column_name, 14 fbdi_position from dual
      union all select 'LOC_SEGMENT3' column_name, 15 fbdi_position from dual
      union all select 'LOC_SEGMENT4' column_name, 16 fbdi_position from dual
      union all select 'LOC_SEGMENT5' column_name, 17 fbdi_position from dual
      union all select 'LOC_SEGMENT6' column_name, 18 fbdi_position from dual
      union all select 'LOC_SEGMENT7' column_name, 19 fbdi_position from dual
      union all select 'LOC_SEGMENT8' column_name, 20 fbdi_position from dual
      union all select 'LOC_SEGMENT9' column_name, 21 fbdi_position from dual
      union all select 'LOC_SEGMENT10' column_name, 22 fbdi_position from dual
      union all select 'LOC_SEGMENT11' column_name, 23 fbdi_position from dual
      union all select 'LOC_SEGMENT12' column_name, 24 fbdi_position from dual
      union all select 'LOC_SEGMENT13' column_name, 25 fbdi_position from dual
      union all select 'LOC_SEGMENT14' column_name, 26 fbdi_position from dual
      union all select 'LOC_SEGMENT15' column_name, 27 fbdi_position from dual
      union all select 'LOC_SEGMENT16' column_name, 28 fbdi_position from dual
      union all select 'LOC_SEGMENT17' column_name, 29 fbdi_position from dual
      union all select 'LOC_SEGMENT18' column_name, 30 fbdi_position from dual
      union all select 'LOC_SEGMENT19' column_name, 31 fbdi_position from dual
      union all select 'LOC_SEGMENT20' column_name, 32 fbdi_position from dual
      union all select 'TRANSACTION_QUANTITY' column_name, 33 fbdi_position from dual
      union all select 'TRANSACTION_UOM' column_name, 34 fbdi_position from dual
      union all select 'TRANSACTION_UNIT_OF_MEASURE' column_name, 35 fbdi_position from dual
      union all select 'RESERVATION_QUANTITY' column_name, 36 fbdi_position from dual
      union all select 'TRANSACTION_DATE' column_name, 37 fbdi_position from dual
      union all select 'TRANSACTION_SOURCE_TYPE_NAME' column_name, 38 fbdi_position from dual
      union all select 'TRANSACTION_TYPE_NAME' column_name, 39 fbdi_position from dual
      union all select 'TRANSFER_ORGANIZATION_TYPE' column_name, 40 fbdi_position from dual
      union all select 'TRANSFER_ORGANIZATION_NAME' column_name, 41 fbdi_position from dual
      union all select 'TRANSFER_SUBINVENTORY' column_name, 42 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT1' column_name, 43 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT2' column_name, 44 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT3' column_name, 45 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT4' column_name, 46 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT5' column_name, 47 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT6' column_name, 48 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT7' column_name, 49 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT8' column_name, 50 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT9' column_name, 51 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT10' column_name, 52 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT11' column_name, 53 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT12' column_name, 54 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT13' column_name, 55 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT14' column_name, 56 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT15' column_name, 57 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT16' column_name, 58 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT17' column_name, 59 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT18' column_name, 60 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT19' column_name, 61 fbdi_position from dual
      union all select 'XFER_LOC_SEGMENT20' column_name, 62 fbdi_position from dual
      union all select 'PRIMARY_QUANTITY' column_name, 63 fbdi_position from dual
      union all select 'SECONDARY_TRANSACTION_QUANTITY' column_name, 64 fbdi_position from dual
      union all select 'SECONDARY_UOM_CODE' column_name, 65 fbdi_position from dual
      union all select 'SECONDARY_UNIT_OF_MEASURE' column_name, 66 fbdi_position from dual
      union all select 'SOURCE_CODE' column_name, 67 fbdi_position from dual
      union all select 'SOURCE_HEADER_ID' column_name, 68 fbdi_position from dual
      union all select 'SOURCE_LINE_ID' column_name, 69 fbdi_position from dual
      union all select 'TRANSACTION_SOURCE_NAME' column_name, 70 fbdi_position from dual
      union all select 'DSP_SEGMENT1' column_name, 71 fbdi_position from dual
      union all select 'DSP_SEGMENT2' column_name, 72 fbdi_position from dual
      union all select 'DSP_SEGMENT3' column_name, 73 fbdi_position from dual
      union all select 'DSP_SEGMENT4' column_name, 74 fbdi_position from dual
      union all select 'DSP_SEGMENT5' column_name, 75 fbdi_position from dual
      union all select 'DSP_SEGMENT6' column_name, 76 fbdi_position from dual
      union all select 'DSP_SEGMENT7' column_name, 77 fbdi_position from dual
      union all select 'DSP_SEGMENT8' column_name, 78 fbdi_position from dual
      union all select 'DSP_SEGMENT9' column_name, 79 fbdi_position from dual
      union all select 'DSP_SEGMENT10' column_name, 80 fbdi_position from dual
      union all select 'DSP_SEGMENT11' column_name, 81 fbdi_position from dual
      union all select 'DSP_SEGMENT12' column_name, 82 fbdi_position from dual
      union all select 'DSP_SEGMENT13' column_name, 83 fbdi_position from dual
      union all select 'DSP_SEGMENT14' column_name, 84 fbdi_position from dual
      union all select 'DSP_SEGMENT15' column_name, 85 fbdi_position from dual
      union all select 'DSP_SEGMENT16' column_name, 86 fbdi_position from dual
      union all select 'DSP_SEGMENT17' column_name, 87 fbdi_position from dual
      union all select 'DSP_SEGMENT18' column_name, 88 fbdi_position from dual
      union all select 'DSP_SEGMENT19' column_name, 89 fbdi_position from dual
      union all select 'DSP_SEGMENT20' column_name, 90 fbdi_position from dual
      union all select 'DSP_SEGMENT21' column_name, 91 fbdi_position from dual
      union all select 'DSP_SEGMENT22' column_name, 92 fbdi_position from dual
      union all select 'DSP_SEGMENT23' column_name, 93 fbdi_position from dual
      union all select 'DSP_SEGMENT24' column_name, 94 fbdi_position from dual
      union all select 'DSP_SEGMENT25' column_name, 95 fbdi_position from dual
      union all select 'DSP_SEGMENT26' column_name, 96 fbdi_position from dual
      union all select 'DSP_SEGMENT27' column_name, 97 fbdi_position from dual
      union all select 'DSP_SEGMENT28' column_name, 98 fbdi_position from dual
      union all select 'DSP_SEGMENT29' column_name, 99 fbdi_position from dual
      union all select 'DSP_SEGMENT30' column_name, 100 fbdi_position from dual
      union all select 'TRANSACTION_ACTION_NAME' column_name, 101 fbdi_position from dual
      union all select 'TRANSACTION_MODE' column_name, 102 fbdi_position from dual
      union all select 'LOCK_FLAG' column_name, 103 fbdi_position from dual
      union all select 'TRANSACTION_REFERENCE' column_name, 104 fbdi_position from dual
      union all select 'REASON_NAME' column_name, 105 fbdi_position from dual
      union all select 'CURRENCY_NAME' column_name, 106 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 107 fbdi_position from dual
      union all select 'CURRENCY_CONVERSION_TYPE' column_name, 108 fbdi_position from dual
      union all select 'CURRENCY_CONVERSION_RATE' column_name, 109 fbdi_position from dual
      union all select 'CURRENCY_CONVERSION_DATE' column_name, 110 fbdi_position from dual
      union all select 'TRANSACTION_COST' column_name, 111 fbdi_position from dual
      union all select 'TRANSFER_COST' column_name, 112 fbdi_position from dual
      union all select 'NEW_AVERAGE_COST' column_name, 113 fbdi_position from dual
      union all select 'VALUE_CHANGE' column_name, 114 fbdi_position from dual
      union all select 'PERCENTAGE_CHANGE' column_name, 115 fbdi_position from dual
      union all select 'DST_SEGMENT1' column_name, 116 fbdi_position from dual
      union all select 'DST_SEGMENT2' column_name, 117 fbdi_position from dual
      union all select 'DST_SEGMENT3' column_name, 118 fbdi_position from dual
      union all select 'DST_SEGMENT4' column_name, 119 fbdi_position from dual
      union all select 'DST_SEGMENT5' column_name, 120 fbdi_position from dual
      union all select 'DST_SEGMENT6' column_name, 121 fbdi_position from dual
      union all select 'DST_SEGMENT7' column_name, 122 fbdi_position from dual
      union all select 'DST_SEGMENT8' column_name, 123 fbdi_position from dual
      union all select 'DST_SEGMENT9' column_name, 124 fbdi_position from dual
      union all select 'DST_SEGMENT10' column_name, 125 fbdi_position from dual
      union all select 'DST_SEGMENT11' column_name, 126 fbdi_position from dual
      union all select 'DST_SEGMENT12' column_name, 127 fbdi_position from dual
      union all select 'DST_SEGMENT13' column_name, 128 fbdi_position from dual
      union all select 'DST_SEGMENT14' column_name, 129 fbdi_position from dual
      union all select 'DST_SEGMENT15' column_name, 130 fbdi_position from dual
      union all select 'DST_SEGMENT16' column_name, 131 fbdi_position from dual
      union all select 'DST_SEGMENT17' column_name, 132 fbdi_position from dual
      union all select 'DST_SEGMENT18' column_name, 133 fbdi_position from dual
      union all select 'DST_SEGMENT19' column_name, 134 fbdi_position from dual
      union all select 'DST_SEGMENT20' column_name, 135 fbdi_position from dual
      union all select 'DST_SEGMENT21' column_name, 136 fbdi_position from dual
      union all select 'DST_SEGMENT22' column_name, 137 fbdi_position from dual
      union all select 'DST_SEGMENT23' column_name, 138 fbdi_position from dual
      union all select 'DST_SEGMENT24' column_name, 139 fbdi_position from dual
      union all select 'DST_SEGMENT25' column_name, 140 fbdi_position from dual
      union all select 'DST_SEGMENT26' column_name, 141 fbdi_position from dual
      union all select 'DST_SEGMENT27' column_name, 142 fbdi_position from dual
      union all select 'DST_SEGMENT28' column_name, 143 fbdi_position from dual
      union all select 'DST_SEGMENT29' column_name, 144 fbdi_position from dual
      union all select 'DST_SEGMENT30' column_name, 145 fbdi_position from dual
      union all select 'LOCATION_TYPE' column_name, 146 fbdi_position from dual
      union all select 'EMPLOYEE_CODE' column_name, 147 fbdi_position from dual
      union all select 'RECEIVING_DOCUMENT' column_name, 148 fbdi_position from dual
      union all select 'LINE_ITEM_NUM' column_name, 149 fbdi_position from dual
      union all select 'SHIPMENT_NUMBER' column_name, 150 fbdi_position from dual
      union all select 'TRANSPORTATION_COST' column_name, 151 fbdi_position from dual
      union all select 'CONTAINERS' column_name, 152 fbdi_position from dual
      union all select 'WAYBILL_AIRBILL' column_name, 153 fbdi_position from dual
      union all select 'EXPECTED_ARRIVAL_DATE' column_name, 154 fbdi_position from dual
      union all select 'REQUIRED_FLAG' column_name, 155 fbdi_position from dual
      union all select 'SHIPPABLE_FLAG' column_name, 156 fbdi_position from dual
      union all select 'SHIPPED_QUANTITY' column_name, 157 fbdi_position from dual
      union all select 'VALIDATION_REQUIRED' column_name, 158 fbdi_position from dual
      union all select 'NEGATIVE_REQ_FLAG' column_name, 159 fbdi_position from dual
      union all select 'OWNING_TP_TYPE' column_name, 160 fbdi_position from dual
      union all select 'TRANSFER_OWNING_TP_TYPE' column_name, 161 fbdi_position from dual
      union all select 'OWNING_ORGANIZATION_NAME' column_name, 162 fbdi_position from dual
      union all select 'XFR_OWNING_ORGANIZATION_NAME' column_name, 163 fbdi_position from dual
      union all select 'TRANSFER_PERCENTAGE' column_name, 164 fbdi_position from dual
      union all select 'PLANNING_TP_TYPE' column_name, 165 fbdi_position from dual
      union all select 'TRANSFER_PLANNING_TP_TYPE' column_name, 166 fbdi_position from dual
      union all select 'ROUTING_REVISION' column_name, 167 fbdi_position from dual
      union all select 'ROUTING_REVISION_DATE' column_name, 168 fbdi_position from dual
      union all select 'ALTERNATE_BOM_DESIGNATOR' column_name, 169 fbdi_position from dual
      union all select 'ALTERNATE_ROUTING_DESIGNATOR' column_name, 170 fbdi_position from dual
      union all select 'ORGANIZATION_TYPE' column_name, 171 fbdi_position from dual
      union all select 'USSGL_TRANSACTION_CODE' column_name, 172 fbdi_position from dual
      union all select 'WIP_ENTITY_TYPE' column_name, 173 fbdi_position from dual
      union all select 'SCHEDULE_UPDATE_CODE' column_name, 174 fbdi_position from dual
      union all select 'SETUP_TEARDOWN_CODE' column_name, 175 fbdi_position from dual
      union all select 'PRIMARY_SWITCH' column_name, 176 fbdi_position from dual
      union all select 'MRP_CODE' column_name, 177 fbdi_position from dual
      union all select 'OPERATION_SEQ_NUM' column_name, 178 fbdi_position from dual
      union all select 'WIP_SUPPLY_TYPE' column_name, 179 fbdi_position from dual
      union all select 'RELIEVE_RESERVATIONS_FLAG' column_name, 180 fbdi_position from dual
      union all select 'RELIEVE_HIGH_LEVEL_RSV_FLAG' column_name, 181 fbdi_position from dual
      union all select 'TRANSFER_PRICE' column_name, 182 fbdi_position from dual
      union all select 'BUILD_BREAK_TO_UOM' column_name, 183 fbdi_position from dual
      union all select 'BUILD_BREAK_TO_UNIT_OF_MEASURE' column_name, 184 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 185 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 186 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 187 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 188 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 189 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 190 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 191 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 192 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 193 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 194 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 195 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 196 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 197 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 198 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 199 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 200 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 201 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 202 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 203 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 204 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 205 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 206 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 207 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 208 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 209 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 210 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 211 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 212 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 213 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 214 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 215 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 216 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 217 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 218 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 219 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 220 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 221 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 222 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 223 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 224 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 225 fbdi_position from dual
      union all select 'TRANSACTION_COST_IDENTIFIER' column_name, 226 fbdi_position from dual
      union all select 'DEFAULT_TAXATION_COUNTRY' column_name, 227 fbdi_position from dual
      union all select 'DOCUMENT_SUB_TYPE' column_name, 228 fbdi_position from dual
      union all select 'TRX_BUSINESS_CATEGORY' column_name, 229 fbdi_position from dual
      union all select 'USER_DEFINED_FISC_CLASS' column_name, 230 fbdi_position from dual
      union all select 'TAX_INVOICE_NUMBER' column_name, 231 fbdi_position from dual
      union all select 'TAX_INVOICE_DATE' column_name, 232 fbdi_position from dual
      union all select 'PRODUCT_CATEGORY' column_name, 233 fbdi_position from dual
      union all select 'PRODUCT_TYPE' column_name, 234 fbdi_position from dual
      union all select 'ASSESSABLE_VALUE' column_name, 235 fbdi_position from dual
      union all select 'TAX_CLASSIFICATION_CODE' column_name, 236 fbdi_position from dual
      union all select 'EXEMPT_CERTIFICATE_NUMBER' column_name, 237 fbdi_position from dual
      union all select 'EXEMPT_REASON_CODE' column_name, 238 fbdi_position from dual
      union all select 'INTENDED_USE' column_name, 239 fbdi_position from dual
      union all select 'FIRST_PTY_NUMBER' column_name, 240 fbdi_position from dual
      union all select 'THIRD_PTY_NUMBER' column_name, 241 fbdi_position from dual
      union all select 'FINAL_DISCHARGE_LOC_CODE' column_name, 242 fbdi_position from dual
      union all select 'CATEGORY_NAME' column_name, 243 fbdi_position from dual
      union all select 'OWNING_ORGANIZATION_ID' column_name, 244 fbdi_position from dual
      union all select 'XFR_OWNING_ORGANIZATION_ID' column_name, 245 fbdi_position from dual
      union all select 'PRC_BU_NAME' column_name, 246 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 247 fbdi_position from dual
      union all select 'VENDOR_NUMBER' column_name, 248 fbdi_position from dual
      union all select 'CONSIGNMENT_AGREEMENT_NUM' column_name, 249 fbdi_position from dual
      union all select 'USE_CURRENT_COST' column_name, 250 fbdi_position from dual
      union all select 'EXTERNAL_SYSTEM_PACKING_UNIT' column_name, 251 fbdi_position from dual
      union all select 'TRANSFER_LOCATOR_NAME' column_name, 252 fbdi_position from dual
      union all select 'INV_PROJECT' column_name, 253 fbdi_position from dual
      union all select 'INV_TASK' column_name, 254 fbdi_position from dual
      union all select 'COUNTRY_OF_ORIGIN_NAME' column_name, 255 fbdi_position from dual
      union all select 'TRANSFER_INV_PROJECT' column_name, 256 fbdi_position from dual
      union all select 'TRANSFER_INV_TASK' column_name, 257 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'InvTransactionsInterface.csv' and f."OBJECT_CODE" = 'INV_TRX'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'InvTransactionsInterface.csv' and f."OBJECT_CODE" = 'INV_TRX')
and   t."COLUMN_NAME" not in ('ORGANIZATION_NAME', 'TRANSACTION_GROUP_ID', 'TRANSACTION_GROUP_SEQ', 'TRANSACTION_BATCH_ID', 'TRANSACTION_BATCH_SEQ', 'PROCESS_FLAG', 'INVENTORY_ITEM', 'ITEM_NUMBER', 'REVISION', 'INV_LOTSERIAL_INTERFACE_NUM', 'SUBINVENTORY_CODE', 'LOCATOR_NAME', 'LOC_SEGMENT1', 'LOC_SEGMENT2', 'LOC_SEGMENT3', 'LOC_SEGMENT4', 'LOC_SEGMENT5', 'LOC_SEGMENT6', 'LOC_SEGMENT7', 'LOC_SEGMENT8', 'LOC_SEGMENT9', 'LOC_SEGMENT10', 'LOC_SEGMENT11', 'LOC_SEGMENT12', 'LOC_SEGMENT13', 'LOC_SEGMENT14', 'LOC_SEGMENT15', 'LOC_SEGMENT16', 'LOC_SEGMENT17', 'LOC_SEGMENT18', 'LOC_SEGMENT19', 'LOC_SEGMENT20', 'TRANSACTION_QUANTITY', 'TRANSACTION_UOM', 'TRANSACTION_UNIT_OF_MEASURE', 'RESERVATION_QUANTITY', 'TRANSACTION_DATE', 'TRANSACTION_SOURCE_TYPE_NAME', 'TRANSACTION_TYPE_NAME', 'TRANSFER_ORGANIZATION_TYPE', 'TRANSFER_ORGANIZATION_NAME', 'TRANSFER_SUBINVENTORY', 'XFER_LOC_SEGMENT1', 'XFER_LOC_SEGMENT2', 'XFER_LOC_SEGMENT3', 'XFER_LOC_SEGMENT4', 'XFER_LOC_SEGMENT5', 'XFER_LOC_SEGMENT6', 'XFER_LOC_SEGMENT7', 'XFER_LOC_SEGMENT8', 'XFER_LOC_SEGMENT9', 'XFER_LOC_SEGMENT10', 'XFER_LOC_SEGMENT11', 'XFER_LOC_SEGMENT12', 'XFER_LOC_SEGMENT13', 'XFER_LOC_SEGMENT14', 'XFER_LOC_SEGMENT15', 'XFER_LOC_SEGMENT16', 'XFER_LOC_SEGMENT17', 'XFER_LOC_SEGMENT18', 'XFER_LOC_SEGMENT19', 'XFER_LOC_SEGMENT20', 'PRIMARY_QUANTITY', 'SECONDARY_TRANSACTION_QUANTITY', 'SECONDARY_UOM_CODE', 'SECONDARY_UNIT_OF_MEASURE', 'SOURCE_CODE', 'SOURCE_HEADER_ID', 'SOURCE_LINE_ID', 'TRANSACTION_SOURCE_NAME', 'DSP_SEGMENT1', 'DSP_SEGMENT2', 'DSP_SEGMENT3', 'DSP_SEGMENT4', 'DSP_SEGMENT5', 'DSP_SEGMENT6', 'DSP_SEGMENT7', 'DSP_SEGMENT8', 'DSP_SEGMENT9', 'DSP_SEGMENT10', 'DSP_SEGMENT11', 'DSP_SEGMENT12', 'DSP_SEGMENT13', 'DSP_SEGMENT14', 'DSP_SEGMENT15', 'DSP_SEGMENT16', 'DSP_SEGMENT17', 'DSP_SEGMENT18', 'DSP_SEGMENT19', 'DSP_SEGMENT20', 'DSP_SEGMENT21', 'DSP_SEGMENT22', 'DSP_SEGMENT23', 'DSP_SEGMENT24', 'DSP_SEGMENT25', 'DSP_SEGMENT26', 'DSP_SEGMENT27', 'DSP_SEGMENT28', 'DSP_SEGMENT29', 'DSP_SEGMENT30', 'TRANSACTION_ACTION_NAME', 'TRANSACTION_MODE', 'LOCK_FLAG', 'TRANSACTION_REFERENCE', 'REASON_NAME', 'CURRENCY_NAME', 'CURRENCY_CODE', 'CURRENCY_CONVERSION_TYPE', 'CURRENCY_CONVERSION_RATE', 'CURRENCY_CONVERSION_DATE', 'TRANSACTION_COST', 'TRANSFER_COST', 'NEW_AVERAGE_COST', 'VALUE_CHANGE', 'PERCENTAGE_CHANGE', 'DST_SEGMENT1', 'DST_SEGMENT2', 'DST_SEGMENT3', 'DST_SEGMENT4', 'DST_SEGMENT5', 'DST_SEGMENT6', 'DST_SEGMENT7', 'DST_SEGMENT8', 'DST_SEGMENT9', 'DST_SEGMENT10', 'DST_SEGMENT11', 'DST_SEGMENT12', 'DST_SEGMENT13', 'DST_SEGMENT14', 'DST_SEGMENT15', 'DST_SEGMENT16', 'DST_SEGMENT17', 'DST_SEGMENT18', 'DST_SEGMENT19', 'DST_SEGMENT20', 'DST_SEGMENT21', 'DST_SEGMENT22', 'DST_SEGMENT23', 'DST_SEGMENT24', 'DST_SEGMENT25', 'DST_SEGMENT26', 'DST_SEGMENT27', 'DST_SEGMENT28', 'DST_SEGMENT29', 'DST_SEGMENT30', 'LOCATION_TYPE', 'EMPLOYEE_CODE', 'RECEIVING_DOCUMENT', 'LINE_ITEM_NUM', 'SHIPMENT_NUMBER', 'TRANSPORTATION_COST', 'CONTAINERS', 'WAYBILL_AIRBILL', 'EXPECTED_ARRIVAL_DATE', 'REQUIRED_FLAG', 'SHIPPABLE_FLAG', 'SHIPPED_QUANTITY', 'VALIDATION_REQUIRED', 'NEGATIVE_REQ_FLAG', 'OWNING_TP_TYPE', 'TRANSFER_OWNING_TP_TYPE', 'OWNING_ORGANIZATION_NAME', 'XFR_OWNING_ORGANIZATION_NAME', 'TRANSFER_PERCENTAGE', 'PLANNING_TP_TYPE', 'TRANSFER_PLANNING_TP_TYPE', 'ROUTING_REVISION', 'ROUTING_REVISION_DATE', 'ALTERNATE_BOM_DESIGNATOR', 'ALTERNATE_ROUTING_DESIGNATOR', 'ORGANIZATION_TYPE', 'USSGL_TRANSACTION_CODE', 'WIP_ENTITY_TYPE', 'SCHEDULE_UPDATE_CODE', 'SETUP_TEARDOWN_CODE', 'PRIMARY_SWITCH', 'MRP_CODE', 'OPERATION_SEQ_NUM', 'WIP_SUPPLY_TYPE', 'RELIEVE_RESERVATIONS_FLAG', 'RELIEVE_HIGH_LEVEL_RSV_FLAG', 'TRANSFER_PRICE', 'BUILD_BREAK_TO_UOM', 'BUILD_BREAK_TO_UNIT_OF_MEASURE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'TRANSACTION_COST_IDENTIFIER', 'DEFAULT_TAXATION_COUNTRY', 'DOCUMENT_SUB_TYPE', 'TRX_BUSINESS_CATEGORY', 'USER_DEFINED_FISC_CLASS', 'TAX_INVOICE_NUMBER', 'TAX_INVOICE_DATE', 'PRODUCT_CATEGORY', 'PRODUCT_TYPE', 'ASSESSABLE_VALUE', 'TAX_CLASSIFICATION_CODE', 'EXEMPT_CERTIFICATE_NUMBER', 'EXEMPT_REASON_CODE', 'INTENDED_USE', 'FIRST_PTY_NUMBER', 'THIRD_PTY_NUMBER', 'FINAL_DISCHARGE_LOC_CODE', 'CATEGORY_NAME', 'OWNING_ORGANIZATION_ID', 'XFR_OWNING_ORGANIZATION_ID', 'PRC_BU_NAME', 'VENDOR_NAME', 'VENDOR_NUMBER', 'CONSIGNMENT_AGREEMENT_NUM', 'USE_CURRENT_COST', 'EXTERNAL_SYSTEM_PACKING_UNIT', 'TRANSFER_LOCATOR_NAME', 'INV_PROJECT', 'INV_TASK', 'COUNTRY_OF_ORIGIN_NAME', 'TRANSFER_INV_PROJECT', 'TRANSFER_INV_TASK');

-- InvTransactionLotsInterface.csv -> INV_TRX_LOTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INVENTORY_LOT_INTERFACE_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'INVENTORY_SERIAL_INTERFACE_NUM' column_name, 2 fbdi_position from dual
      union all select 'SOURCE_CODE' column_name, 3 fbdi_position from dual
      union all select 'SOURCE_LINE_ID' column_name, 4 fbdi_position from dual
      union all select 'LOT_NUMBER' column_name, 5 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 6 fbdi_position from dual
      union all select 'LOT_EXPIRATION_DATE' column_name, 7 fbdi_position from dual
      union all select 'TRANSACTION_QUANTITY' column_name, 8 fbdi_position from dual
      union all select 'PRIMARY_QUANTITY' column_name, 9 fbdi_position from dual
      union all select 'SOURCE_ID' column_name, 10 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'InvTransactionLotsInterface.csv' and f."OBJECT_CODE" = 'INV_TRX_LOTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and (d."IS_ADMIN_COLUMN" = 'N' or d."COLUMN_NAME" = 'SOURCE_ID')
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'InvTransactionLotsInterface.csv' and f."OBJECT_CODE" = 'INV_TRX_LOTS')
and   t."COLUMN_NAME" not in ('INVENTORY_LOT_INTERFACE_NUMBER', 'INVENTORY_SERIAL_INTERFACE_NUM', 'SOURCE_CODE', 'SOURCE_LINE_ID', 'LOT_NUMBER', 'DESCRIPTION', 'LOT_EXPIRATION_DATE', 'TRANSACTION_QUANTITY', 'PRIMARY_QUANTITY', 'SOURCE_ID');

-- InvSerialNumbersInterface.csv -> INV_TRX_SERIALS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'FM_SERIAL_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'TO_SERIAL_NUMBER' column_name, 5 fbdi_position from dual
      union all select 'SOURCE_ID' column_name, 6 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'InvSerialNumbersInterface.csv' and f."OBJECT_CODE" = 'INV_TRX_SERIALS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and (d."IS_ADMIN_COLUMN" = 'N' or d."COLUMN_NAME" = 'SOURCE_ID')
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'InvSerialNumbersInterface.csv' and f."OBJECT_CODE" = 'INV_TRX_SERIALS')
and   t."COLUMN_NAME" not in ('FM_SERIAL_NUMBER', 'TO_SERIAL_NUMBER', 'SOURCE_ID');

-- GmsAwardFundingInterface.csv -> GMS_AWD_FUNDING
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'BUDGET_PERIOD_NAME' column_name, 2 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NAME' column_name, 3 fbdi_position from dual
      union all select 'ISSUE_TYPE' column_name, 4 fbdi_position from dual
      union all select 'ISSUE_NUMBER' column_name, 5 fbdi_position from dual
      union all select 'ISSUE_DATE' column_name, 6 fbdi_position from dual
      union all select 'ISSUE_DESCRIPTION' column_name, 7 fbdi_position from dual
      union all select 'DIRECT_FUNDING_AMOUNT' column_name, 8 fbdi_position from dual
      union all select 'INDIRECT_FUNDING_AMOUNT' column_name, 9 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NUMBER' column_name, 10 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardFundingInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_FUNDING'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardFundingInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_FUNDING')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'BUDGET_PERIOD_NAME', 'FUNDING_SOURCE_NAME', 'ISSUE_TYPE', 'ISSUE_NUMBER', 'ISSUE_DATE', 'ISSUE_DESCRIPTION', 'DIRECT_FUNDING_AMOUNT', 'INDIRECT_FUNDING_AMOUNT', 'FUNDING_SOURCE_NUMBER');

-- GmsAwardProjectsInterface.csv -> GMS_AWD_PROJECTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NAME' column_name, 2 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'AWARD_PRJ_BRD_SCHEDULE' column_name, 4 fbdi_position from dual
      union all select 'FIXED_DATE' column_name, 5 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 6 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 7 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 8 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 9 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 10 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 11 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 12 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 13 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 14 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 15 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 16 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 17 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 18 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 19 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 20 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 21 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 22 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 23 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 24 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 25 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 26 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 27 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 28 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 29 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 30 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 31 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 32 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 33 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 34 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 35 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 36 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 56 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardProjectsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PROJECTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardProjectsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PROJECTS')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'FUNDING_SOURCE_NAME', 'PROJECT_NUMBER', 'AWARD_PRJ_BRD_SCHEDULE', 'FIXED_DATE', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10');

-- GmsAwardFundSrcInterface.csv -> GMS_AWD_FUND_SRC
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NAME' column_name, 2 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'COST_SHARE_REQ_BY_SPONSOR' column_name, 4 fbdi_position from dual
      union all select 'COST_SHARE_APPROVED_BY_EMAIL' column_name, 5 fbdi_position from dual
      union all select 'COST_SHARE_APPROVED_BY_NAME' column_name, 6 fbdi_position from dual
      union all select 'COST_SHARE_APPROVED_BY_NUMBER' column_name, 7 fbdi_position from dual
      union all select 'COST_SHARE_APPROVAL_DATE' column_name, 8 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardFundSrcInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_FUND_SRC'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardFundSrcInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_FUND_SRC')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'FUNDING_SOURCE_NAME', 'FUNDING_SOURCE_NUMBER', 'COST_SHARE_REQ_BY_SPONSOR', 'COST_SHARE_APPROVED_BY_EMAIL', 'COST_SHARE_APPROVED_BY_NAME', 'COST_SHARE_APPROVED_BY_NUMBER', 'COST_SHARE_APPROVAL_DATE');

-- GmsAwardPrjFundSrcInterface.csv -> GMS_AWD_PRJ_FUND_SRC
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NAME' column_name, 3 fbdi_position from dual
      union all select 'FUNDING_SOURCE_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'ENABLE_BURDENING_FLAG' column_name, 5 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardPrjFundSrcInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PRJ_FUND_SRC'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardPrjFundSrcInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PRJ_FUND_SRC')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'FUNDING_SOURCE_NAME', 'FUNDING_SOURCE_NUMBER', 'ENABLE_BURDENING_FLAG');

-- GmsAwardKeywordsInterface.csv -> GMS_AWD_KEYWORDS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'KEYWORD_NAME' column_name, 3 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardKeywordsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_KEYWORDS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardKeywordsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_KEYWORDS')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'KEYWORD_NAME');

-- GmsAwardBdgtPeriodsInterface.csv -> GMS_AWD_BDGT_PRDS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'BUDGET_PERIOD' column_name, 2 fbdi_position from dual
      union all select 'START_DATE' column_name, 3 fbdi_position from dual
      union all select 'END_DATE' column_name, 4 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardBdgtPeriodsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_BDGT_PRDS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardBdgtPeriodsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_BDGT_PRDS')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'BUDGET_PERIOD', 'START_DATE', 'END_DATE');

-- GmsAwardCertsInterface.csv -> GMS_AWD_CERTS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'CERTIFICATION_NAME' column_name, 3 fbdi_position from dual
      union all select 'CERTIFICATION_DATE' column_name, 4 fbdi_position from dual
      union all select 'CERTIFIED_BY' column_name, 5 fbdi_position from dual
      union all select 'CERT_STATUS' column_name, 6 fbdi_position from dual
      union all select 'APPROVAL_DATE' column_name, 7 fbdi_position from dual
      union all select 'EXPIRATION_DATE' column_name, 8 fbdi_position from dual
      union all select 'EXPEDITED_REVIEW' column_name, 9 fbdi_position from dual
      union all select 'FULL_REVIEW' column_name, 10 fbdi_position from dual
      union all select 'ASSURANCE_NUMBER' column_name, 11 fbdi_position from dual
      union all select 'EXEMPTION_NUMBER' column_name, 12 fbdi_position from dual
      union all select 'COMMENTS' column_name, 13 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardCertsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_CERTS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardCertsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_CERTS')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'CERTIFICATION_NAME', 'CERTIFICATION_DATE', 'CERTIFIED_BY', 'CERT_STATUS', 'APPROVAL_DATE', 'EXPIRATION_DATE', 'EXPEDITED_REVIEW', 'FULL_REVIEW', 'ASSURANCE_NUMBER', 'EXEMPTION_NUMBER', 'COMMENTS');

-- GmsAwardCfdasInterface.csv -> GMS_AWD_CFDAS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'CFDA' column_name, 2 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardCfdasInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_CFDAS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardCfdasInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_CFDAS')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'CFDA');

-- GmsAwardFundAllocInterface.csv -> GMS_AWD_FUND_ALLOC
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'ISSUE_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'FUNDING_AMOUNT' column_name, 4 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardFundAllocInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_FUND_ALLOC'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardFundAllocInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_FUND_ALLOC')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'ISSUE_NUMBER', 'FUNDING_AMOUNT');

-- GmsAwardOrgCreditsInterface.csv -> GMS_AWD_ORG_CREDITS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'ORGANIZATION' column_name, 3 fbdi_position from dual
      union all select 'CREDIT_PERCENTAGE' column_name, 4 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardOrgCreditsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_ORG_CREDITS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardOrgCreditsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_ORG_CREDITS')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'ORGANIZATION', 'CREDIT_PERCENTAGE');

-- GmsAwardPrjTaskBrdInterface.csv -> GMS_AWD_PRJ_TSK_BRD
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'TASK_NUMBER' column_name, 3 fbdi_position from dual
      union all select 'BURDEN_SCHEDULE' column_name, 4 fbdi_position from dual
      union all select 'FIXED_DATE' column_name, 5 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardPrjTaskBrdInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PRJ_TSK_BRD'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardPrjTaskBrdInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_PRJ_TSK_BRD')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'TASK_NUMBER', 'BURDEN_SCHEDULE', 'FIXED_DATE');

-- GmsAwardReferencesInterface.csv -> GMS_AWD_REFERENCES
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'PROJECT_NUMBER' column_name, 2 fbdi_position from dual
      union all select 'REFERENCE_TYPE' column_name, 3 fbdi_position from dual
      union all select 'VALUE' column_name, 4 fbdi_position from dual
      union all select 'COMMENTS' column_name, 5 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardReferencesInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_REFERENCES'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardReferencesInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_REFERENCES')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'PROJECT_NUMBER', 'REFERENCE_TYPE', 'VALUE', 'COMMENTS');

-- GmsAwardTermsInterface.csv -> GMS_AWD_TERMS
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'AWARD_NUMBER' column_name, 1 fbdi_position from dual
      union all select 'TERM_CATEGORY_NAME' column_name, 2 fbdi_position from dual
      union all select 'TERM_NAME' column_name, 3 fbdi_position from dual
      union all select 'TERM_DESCRIPTION' column_name, 4 fbdi_position from dual
      union all select 'TERM_OPERAND' column_name, 5 fbdi_position from dual
      union all select 'TERM_VALUE' column_name, 6 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'GmsAwardTermsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_TERMS'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'GmsAwardTermsInterface.csv' and f."OBJECT_CODE" = 'GMS_AWD_TERMS')
and   t."COLUMN_NAME" not in ('AWARD_NUMBER', 'TERM_CATEGORY_NAME', 'TERM_NAME', 'TERM_DESCRIPTION', 'TERM_OPERAND', 'TERM_VALUE');

-- FaMassAdditions.csv -> FA_ASSET_HDR
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BOOK_TYPE_CODE' column_name, 2 fbdi_position from dual
      union all select 'ASSET_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 5 fbdi_position from dual
      union all select 'TAG_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'MANUFACTURER_NAME' column_name, 7 fbdi_position from dual
      union all select 'SERIAL_NUMBER' column_name, 8 fbdi_position from dual
      union all select 'MODEL_NUMBER' column_name, 9 fbdi_position from dual
      union all select 'ASSET_TYPE' column_name, 10 fbdi_position from dual
      union all select 'COST' column_name, 11 fbdi_position from dual
      union all select 'DATE_PLACED_IN_SERVICE' column_name, 12 fbdi_position from dual
      union all select 'PRORATE_CONVENTION_CODE' column_name, 13 fbdi_position from dual
      union all select 'CURRENT_UNITS' column_name, 14 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT1' column_name, 15 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT2' column_name, 16 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT3' column_name, 17 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT4' column_name, 18 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT5' column_name, 19 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT6' column_name, 20 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT7' column_name, 21 fbdi_position from dual
      union all select 'PARENT_ASSET_NUMBER' column_name, 25 fbdi_position from dual
      union all select 'PROPERTY_TYPE_CODE' column_name, 38 fbdi_position from dual
      union all select 'PROPERTY_1245_1250_CODE' column_name, 39 fbdi_position from dual
      union all select 'IN_USE_FLAG' column_name, 40 fbdi_position from dual
      union all select 'OWNED_LEASED' column_name, 41 fbdi_position from dual
      union all select 'NEW_USED' column_name, 42 fbdi_position from dual
      union all select 'SALVAGE_VALUE' column_name, 50 fbdi_position from dual
      union all select 'YTD_DEPRN' column_name, 52 fbdi_position from dual
      union all select 'DEPRN_RESERVE' column_name, 53 fbdi_position from dual
      union all select 'BONUS_YTD_DEPRN' column_name, 54 fbdi_position from dual
      union all select 'BONUS_DEPRN_RESERVE' column_name, 55 fbdi_position from dual
      union all select 'DEPRECIATION_METHOD' column_name, 58 fbdi_position from dual
      union all select 'LIFE_IN_MONTHS' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 101 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 102 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 103 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 104 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 105 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 106 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 107 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 108 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 109 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 110 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 111 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 112 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 113 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 114 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 115 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 141 fbdi_position from dual
      union all select 'DEPRN_START_DATE' column_name, 245 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'FaMassAdditions.csv' and f."OBJECT_CODE" = 'FA_ASSET_HDR'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'FaMassAdditions.csv' and f."OBJECT_CODE" = 'FA_ASSET_HDR')
and   t."COLUMN_NAME" not in ('BOOK_TYPE_CODE', 'ASSET_NUMBER', 'DESCRIPTION', 'TAG_NUMBER', 'MANUFACTURER_NAME', 'SERIAL_NUMBER', 'MODEL_NUMBER', 'ASSET_TYPE', 'COST', 'DATE_PLACED_IN_SERVICE', 'PRORATE_CONVENTION_CODE', 'CURRENT_UNITS', 'ASSET_CATEGORY_SEGMENT1', 'ASSET_CATEGORY_SEGMENT2', 'ASSET_CATEGORY_SEGMENT3', 'ASSET_CATEGORY_SEGMENT4', 'ASSET_CATEGORY_SEGMENT5', 'ASSET_CATEGORY_SEGMENT6', 'ASSET_CATEGORY_SEGMENT7', 'PARENT_ASSET_NUMBER', 'PROPERTY_TYPE_CODE', 'PROPERTY_1245_1250_CODE', 'IN_USE_FLAG', 'OWNED_LEASED', 'NEW_USED', 'SALVAGE_VALUE', 'YTD_DEPRN', 'DEPRN_RESERVE', 'BONUS_YTD_DEPRN', 'BONUS_DEPRN_RESERVE', 'DEPRECIATION_METHOD', 'LIFE_IN_MONTHS', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE_CATEGORY', 'DEPRN_START_DATE');

-- FaMassAdditions.csv -> FA_ASSET_BOOK
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'BOOK_TYPE_CODE' column_name, 2 fbdi_position from dual
      union all select 'ASSET_NUMBER' column_name, 4 fbdi_position from dual
      union all select 'DESCRIPTION' column_name, 5 fbdi_position from dual
      union all select 'TAG_NUMBER' column_name, 6 fbdi_position from dual
      union all select 'MANUFACTURER_NAME' column_name, 7 fbdi_position from dual
      union all select 'SERIAL_NUMBER' column_name, 8 fbdi_position from dual
      union all select 'MODEL_NUMBER' column_name, 9 fbdi_position from dual
      union all select 'ASSET_TYPE' column_name, 10 fbdi_position from dual
      union all select 'COST' column_name, 11 fbdi_position from dual
      union all select 'DATE_PLACED_IN_SERVICE' column_name, 12 fbdi_position from dual
      union all select 'PRORATE_CONVENTION_CODE' column_name, 13 fbdi_position from dual
      union all select 'CURRENT_UNITS' column_name, 14 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT1' column_name, 15 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT2' column_name, 16 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT3' column_name, 17 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT4' column_name, 18 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT5' column_name, 19 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT6' column_name, 20 fbdi_position from dual
      union all select 'ASSET_CATEGORY_SEGMENT7' column_name, 21 fbdi_position from dual
      union all select 'PARENT_ASSET_NUMBER' column_name, 25 fbdi_position from dual
      union all select 'PROPERTY_TYPE_CODE' column_name, 38 fbdi_position from dual
      union all select 'PROPERTY_1245_1250_CODE' column_name, 39 fbdi_position from dual
      union all select 'IN_USE_FLAG' column_name, 40 fbdi_position from dual
      union all select 'OWNED_LEASED' column_name, 41 fbdi_position from dual
      union all select 'NEW_USED' column_name, 42 fbdi_position from dual
      union all select 'SALVAGE_VALUE' column_name, 50 fbdi_position from dual
      union all select 'YTD_DEPRN' column_name, 52 fbdi_position from dual
      union all select 'DEPRN_RESERVE' column_name, 53 fbdi_position from dual
      union all select 'BONUS_YTD_DEPRN' column_name, 54 fbdi_position from dual
      union all select 'BONUS_DEPRN_RESERVE' column_name, 55 fbdi_position from dual
      union all select 'DEPRECIATION_METHOD' column_name, 58 fbdi_position from dual
      union all select 'LIFE_IN_MONTHS' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 101 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 102 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 103 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 104 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 105 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 106 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 107 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 108 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 109 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 110 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 111 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 112 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 113 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 114 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 115 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 141 fbdi_position from dual
      union all select 'DEPRN_START_DATE' column_name, 245 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'FaMassAdditions.csv' and f."OBJECT_CODE" = 'FA_ASSET_BOOK'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'FaMassAdditions.csv' and f."OBJECT_CODE" = 'FA_ASSET_BOOK')
and   t."COLUMN_NAME" not in ('BOOK_TYPE_CODE', 'ASSET_NUMBER', 'DESCRIPTION', 'TAG_NUMBER', 'MANUFACTURER_NAME', 'SERIAL_NUMBER', 'MODEL_NUMBER', 'ASSET_TYPE', 'COST', 'DATE_PLACED_IN_SERVICE', 'PRORATE_CONVENTION_CODE', 'CURRENT_UNITS', 'ASSET_CATEGORY_SEGMENT1', 'ASSET_CATEGORY_SEGMENT2', 'ASSET_CATEGORY_SEGMENT3', 'ASSET_CATEGORY_SEGMENT4', 'ASSET_CATEGORY_SEGMENT5', 'ASSET_CATEGORY_SEGMENT6', 'ASSET_CATEGORY_SEGMENT7', 'PARENT_ASSET_NUMBER', 'PROPERTY_TYPE_CODE', 'PROPERTY_1245_1250_CODE', 'IN_USE_FLAG', 'OWNED_LEASED', 'NEW_USED', 'SALVAGE_VALUE', 'YTD_DEPRN', 'DEPRN_RESERVE', 'BONUS_YTD_DEPRN', 'BONUS_DEPRN_RESERVE', 'DEPRECIATION_METHOD', 'LIFE_IN_MONTHS', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE_CATEGORY', 'DEPRN_START_DATE');

-- FaMassaddDistributions.csv -> FA_ASSET_ASSIGN
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'UNITS_ASSIGNED' column_name, 2 fbdi_position from dual
      union all select 'LOCATION_SEGMENT1' column_name, 4 fbdi_position from dual
      union all select 'LOCATION_SEGMENT2' column_name, 5 fbdi_position from dual
      union all select 'LOCATION_SEGMENT3' column_name, 6 fbdi_position from dual
      union all select 'LOCATION_SEGMENT4' column_name, 7 fbdi_position from dual
      union all select 'LOCATION_SEGMENT5' column_name, 8 fbdi_position from dual
      union all select 'LOCATION_SEGMENT6' column_name, 9 fbdi_position from dual
      union all select 'LOCATION_SEGMENT7' column_name, 10 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT1' column_name, 11 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT2' column_name, 12 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT3' column_name, 13 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT4' column_name, 14 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT5' column_name, 15 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT6' column_name, 16 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT7' column_name, 17 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT8' column_name, 18 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT9' column_name, 19 fbdi_position from dual
      union all select 'EXPENSE_ACCOUNT_SEGMENT10' column_name, 20 fbdi_position from dual
      union all select 'ASSET_NUMBER' column_name, 67 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'FaMassaddDistributions.csv' and f."OBJECT_CODE" = 'FA_ASSET_ASSIGN'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and (d."IS_ADMIN_COLUMN" = 'N' or d."COLUMN_NAME" = 'ASSET_NUMBER')
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'FaMassaddDistributions.csv' and f."OBJECT_CODE" = 'FA_ASSET_ASSIGN')
and   t."COLUMN_NAME" not in ('UNITS_ASSIGNED', 'LOCATION_SEGMENT1', 'LOCATION_SEGMENT2', 'LOCATION_SEGMENT3', 'LOCATION_SEGMENT4', 'LOCATION_SEGMENT5', 'LOCATION_SEGMENT6', 'LOCATION_SEGMENT7', 'EXPENSE_ACCOUNT_SEGMENT1', 'EXPENSE_ACCOUNT_SEGMENT2', 'EXPENSE_ACCOUNT_SEGMENT3', 'EXPENSE_ACCOUNT_SEGMENT4', 'EXPENSE_ACCOUNT_SEGMENT5', 'EXPENSE_ACCOUNT_SEGMENT6', 'EXPENSE_ACCOUNT_SEGMENT7', 'EXPENSE_ACCOUNT_SEGMENT8', 'EXPENSE_ACCOUNT_SEGMENT9', 'EXPENSE_ACCOUNT_SEGMENT10', 'ASSET_NUMBER');

-- PoHeadersInterfaceBlanket.csv -> PO_HEADERS_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_HEADER_KEY' column_name, 1 fbdi_position from dual
      union all select 'ACTION' column_name, 2 fbdi_position from dual
      union all select 'BATCH_ID' column_name, 3 fbdi_position from dual
      union all select 'INTERFACE_SOURCE_CODE' column_name, 4 fbdi_position from dual
      union all select 'APPROVAL_ACTION' column_name, 5 fbdi_position from dual
      union all select 'DOCUMENT_NUM' column_name, 6 fbdi_position from dual
      union all select 'DOCUMENT_TYPE_CODE' column_name, 7 fbdi_position from dual
      union all select 'STYLE_DISPLAY_NAME' column_name, 8 fbdi_position from dual
      union all select 'PRC_BU_NAME' column_name, 9 fbdi_position from dual
      union all select 'AGENT_NAME' column_name, 10 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 11 fbdi_position from dual
      union all select 'COMMENTS' column_name, 12 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 13 fbdi_position from dual
      union all select 'VENDOR_NUM' column_name, 14 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE' column_name, 15 fbdi_position from dual
      union all select 'VENDOR_CONTACT' column_name, 16 fbdi_position from dual
      union all select 'VENDOR_DOC_NUM' column_name, 17 fbdi_position from dual
      union all select 'FOB' column_name, 18 fbdi_position from dual
      union all select 'FREIGHT_CARRIER' column_name, 19 fbdi_position from dual
      union all select 'FREIGHT_TERMS' column_name, 20 fbdi_position from dual
      union all select 'PAY_ON_CODE' column_name, 21 fbdi_position from dual
      union all select 'PAYMENT_TERMS' column_name, 22 fbdi_position from dual
      union all select 'ORIGINATOR_ROLE' column_name, 23 fbdi_position from dual
      union all select 'CHANGE_ORDER_DESC' column_name, 24 fbdi_position from dual
      union all select 'ACCEPTANCE_REQUIRED_FLAG' column_name, 25 fbdi_position from dual
      union all select 'ACCEPTANCE_WITHIN_DAYS' column_name, 26 fbdi_position from dual
      union all select 'SUPPLIER_NOTIF_METHOD' column_name, 27 fbdi_position from dual
      union all select 'FAX' column_name, 28 fbdi_position from dual
      union all select 'EMAIL_ADDRESS' column_name, 29 fbdi_position from dual
      union all select 'CONFIRMING_ORDER_FLAG' column_name, 30 fbdi_position from dual
      union all select 'NOTE_TO_VENDOR' column_name, 36 fbdi_position from dual
      union all select 'NOTE_TO_RECEIVER' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 94 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 95 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 96 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 97 fbdi_position from dual
      union all select 'AGENT_EMAIL_ADDRESS' column_name, 98 fbdi_position from dual
      union all select 'MODE_OF_TRANSPORT' column_name, 99 fbdi_position from dual
      union all select 'SERVICE_LEVEL' column_name, 100 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoHeadersInterfaceBlanket.csv' and f."OBJECT_CODE" = 'PO_HEADERS_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoHeadersInterfaceBlanket.csv' and f."OBJECT_CODE" = 'PO_HEADERS_INT')
and   t."COLUMN_NAME" not in ('INTERFACE_HEADER_KEY', 'ACTION', 'BATCH_ID', 'INTERFACE_SOURCE_CODE', 'APPROVAL_ACTION', 'DOCUMENT_NUM', 'DOCUMENT_TYPE_CODE', 'STYLE_DISPLAY_NAME', 'PRC_BU_NAME', 'AGENT_NAME', 'CURRENCY_CODE', 'COMMENTS', 'VENDOR_NAME', 'VENDOR_NUM', 'VENDOR_SITE_CODE', 'VENDOR_CONTACT', 'VENDOR_DOC_NUM', 'FOB', 'FREIGHT_CARRIER', 'FREIGHT_TERMS', 'PAY_ON_CODE', 'PAYMENT_TERMS', 'ORIGINATOR_ROLE', 'CHANGE_ORDER_DESC', 'ACCEPTANCE_REQUIRED_FLAG', 'ACCEPTANCE_WITHIN_DAYS', 'SUPPLIER_NOTIF_METHOD', 'FAX', 'EMAIL_ADDRESS', 'CONFIRMING_ORDER_FLAG', 'NOTE_TO_VENDOR', 'NOTE_TO_RECEIVER', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'AGENT_EMAIL_ADDRESS', 'MODE_OF_TRANSPORT', 'SERVICE_LEVEL');

-- PoLinesInterfaceBlanket.csv -> PO_LINES_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_LINE_KEY' column_name, 1 fbdi_position from dual
      union all select 'INTERFACE_HEADER_KEY' column_name, 2 fbdi_position from dual
      union all select 'ACTION' column_name, 3 fbdi_position from dual
      union all select 'LINE_NUM' column_name, 4 fbdi_position from dual
      union all select 'LINE_TYPE' column_name, 5 fbdi_position from dual
      union all select 'ITEM' column_name, 6 fbdi_position from dual
      union all select 'ITEM_DESCRIPTION' column_name, 7 fbdi_position from dual
      union all select 'ITEM_REVISION' column_name, 8 fbdi_position from dual
      union all select 'CATEGORY' column_name, 9 fbdi_position from dual
      union all select 'UNIT_OF_MEASURE' column_name, 11 fbdi_position from dual
      union all select 'UNIT_PRICE' column_name, 12 fbdi_position from dual
      union all select 'NEGOTIATED_BY_PREPARER_FLAG' column_name, 16 fbdi_position from dual
      union all select 'NOTE_TO_VENDOR' column_name, 17 fbdi_position from dual
      union all select 'NOTE_TO_RECEIVER' column_name, 18 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE_CATEGORY_LINES' column_name, 23 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE1' column_name, 24 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE2' column_name, 25 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE3' column_name, 26 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE4' column_name, 27 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE5' column_name, 28 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE6' column_name, 29 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE7' column_name, 30 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE8' column_name, 31 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE9' column_name, 32 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE10' column_name, 33 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE11' column_name, 34 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE12' column_name, 35 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE13' column_name, 36 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE14' column_name, 37 fbdi_position from dual
      union all select 'LINE_ATTRIBUTE15' column_name, 38 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 39 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 40 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 41 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 42 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 43 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 73 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoLinesInterfaceBlanket.csv' and f."OBJECT_CODE" = 'PO_LINES_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoLinesInterfaceBlanket.csv' and f."OBJECT_CODE" = 'PO_LINES_INT')
and   t."COLUMN_NAME" not in ('INTERFACE_LINE_KEY', 'INTERFACE_HEADER_KEY', 'ACTION', 'LINE_NUM', 'LINE_TYPE', 'ITEM', 'ITEM_DESCRIPTION', 'ITEM_REVISION', 'CATEGORY', 'UNIT_OF_MEASURE', 'UNIT_PRICE', 'NEGOTIATED_BY_PREPARER_FLAG', 'NOTE_TO_VENDOR', 'NOTE_TO_RECEIVER', 'LINE_ATTRIBUTE_CATEGORY_LINES', 'LINE_ATTRIBUTE1', 'LINE_ATTRIBUTE2', 'LINE_ATTRIBUTE3', 'LINE_ATTRIBUTE4', 'LINE_ATTRIBUTE5', 'LINE_ATTRIBUTE6', 'LINE_ATTRIBUTE7', 'LINE_ATTRIBUTE8', 'LINE_ATTRIBUTE9', 'LINE_ATTRIBUTE10', 'LINE_ATTRIBUTE11', 'LINE_ATTRIBUTE12', 'LINE_ATTRIBUTE13', 'LINE_ATTRIBUTE14', 'LINE_ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10');

-- PoHeadersInterfaceContract.csv -> PO_HEADERS_INT
merge into "DMT_UPLOAD_FBDI_POS_TBL" t
using (
  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position
  from (
      select 'INTERFACE_HEADER_KEY' column_name, 1 fbdi_position from dual
      union all select 'ACTION' column_name, 2 fbdi_position from dual
      union all select 'BATCH_ID' column_name, 3 fbdi_position from dual
      union all select 'INTERFACE_SOURCE_CODE' column_name, 4 fbdi_position from dual
      union all select 'APPROVAL_ACTION' column_name, 5 fbdi_position from dual
      union all select 'DOCUMENT_NUM' column_name, 6 fbdi_position from dual
      union all select 'DOCUMENT_TYPE_CODE' column_name, 7 fbdi_position from dual
      union all select 'STYLE_DISPLAY_NAME' column_name, 8 fbdi_position from dual
      union all select 'PRC_BU_NAME' column_name, 9 fbdi_position from dual
      union all select 'AGENT_NAME' column_name, 10 fbdi_position from dual
      union all select 'CURRENCY_CODE' column_name, 11 fbdi_position from dual
      union all select 'COMMENTS' column_name, 12 fbdi_position from dual
      union all select 'VENDOR_NAME' column_name, 13 fbdi_position from dual
      union all select 'VENDOR_NUM' column_name, 14 fbdi_position from dual
      union all select 'VENDOR_SITE_CODE' column_name, 15 fbdi_position from dual
      union all select 'VENDOR_CONTACT' column_name, 16 fbdi_position from dual
      union all select 'VENDOR_DOC_NUM' column_name, 17 fbdi_position from dual
      union all select 'FOB' column_name, 18 fbdi_position from dual
      union all select 'FREIGHT_CARRIER' column_name, 19 fbdi_position from dual
      union all select 'FREIGHT_TERMS' column_name, 20 fbdi_position from dual
      union all select 'PAY_ON_CODE' column_name, 21 fbdi_position from dual
      union all select 'PAYMENT_TERMS' column_name, 22 fbdi_position from dual
      union all select 'ORIGINATOR_ROLE' column_name, 23 fbdi_position from dual
      union all select 'CHANGE_ORDER_DESC' column_name, 24 fbdi_position from dual
      union all select 'ACCEPTANCE_REQUIRED_FLAG' column_name, 25 fbdi_position from dual
      union all select 'ACCEPTANCE_WITHIN_DAYS' column_name, 26 fbdi_position from dual
      union all select 'SUPPLIER_NOTIF_METHOD' column_name, 27 fbdi_position from dual
      union all select 'FAX' column_name, 28 fbdi_position from dual
      union all select 'EMAIL_ADDRESS' column_name, 29 fbdi_position from dual
      union all select 'CONFIRMING_ORDER_FLAG' column_name, 30 fbdi_position from dual
      union all select 'NOTE_TO_VENDOR' column_name, 36 fbdi_position from dual
      union all select 'NOTE_TO_RECEIVER' column_name, 37 fbdi_position from dual
      union all select 'ATTRIBUTE_CATEGORY' column_name, 44 fbdi_position from dual
      union all select 'ATTRIBUTE1' column_name, 45 fbdi_position from dual
      union all select 'ATTRIBUTE2' column_name, 46 fbdi_position from dual
      union all select 'ATTRIBUTE3' column_name, 47 fbdi_position from dual
      union all select 'ATTRIBUTE4' column_name, 48 fbdi_position from dual
      union all select 'ATTRIBUTE5' column_name, 49 fbdi_position from dual
      union all select 'ATTRIBUTE6' column_name, 50 fbdi_position from dual
      union all select 'ATTRIBUTE7' column_name, 51 fbdi_position from dual
      union all select 'ATTRIBUTE8' column_name, 52 fbdi_position from dual
      union all select 'ATTRIBUTE9' column_name, 53 fbdi_position from dual
      union all select 'ATTRIBUTE10' column_name, 54 fbdi_position from dual
      union all select 'ATTRIBUTE11' column_name, 55 fbdi_position from dual
      union all select 'ATTRIBUTE12' column_name, 56 fbdi_position from dual
      union all select 'ATTRIBUTE13' column_name, 57 fbdi_position from dual
      union all select 'ATTRIBUTE14' column_name, 58 fbdi_position from dual
      union all select 'ATTRIBUTE15' column_name, 59 fbdi_position from dual
      union all select 'ATTRIBUTE16' column_name, 60 fbdi_position from dual
      union all select 'ATTRIBUTE17' column_name, 61 fbdi_position from dual
      union all select 'ATTRIBUTE18' column_name, 62 fbdi_position from dual
      union all select 'ATTRIBUTE19' column_name, 63 fbdi_position from dual
      union all select 'ATTRIBUTE20' column_name, 64 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE1' column_name, 65 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE2' column_name, 66 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE3' column_name, 67 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE4' column_name, 68 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE5' column_name, 69 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE6' column_name, 70 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE7' column_name, 71 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE8' column_name, 72 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE9' column_name, 73 fbdi_position from dual
      union all select 'ATTRIBUTE_DATE10' column_name, 74 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER1' column_name, 75 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER2' column_name, 76 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER3' column_name, 77 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER4' column_name, 78 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER5' column_name, 79 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER6' column_name, 80 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER7' column_name, 81 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER8' column_name, 82 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER9' column_name, 83 fbdi_position from dual
      union all select 'ATTRIBUTE_NUMBER10' column_name, 84 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP1' column_name, 85 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP2' column_name, 86 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP3' column_name, 87 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP4' column_name, 88 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP5' column_name, 89 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP6' column_name, 90 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP7' column_name, 91 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP8' column_name, 92 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP9' column_name, 93 fbdi_position from dual
      union all select 'ATTRIBUTE_TIMESTAMP10' column_name, 94 fbdi_position from dual
      union all select 'AGENT_EMAIL_ADDRESS' column_name, 95 fbdi_position from dual
      union all select 'MODE_OF_TRANSPORT' column_name, 96 fbdi_position from dual
      union all select 'SERVICE_LEVEL' column_name, 97 fbdi_position from dual
      union all select 'BUYER_MANAGED_TRANSPORT_FLAG' column_name, 99 fbdi_position from dual
  ) s
  join "DMT_UPLOAD_FBDI_FILE_TBL" f
    on f."FBDI_CSV_FILENAME" = 'PoHeadersInterfaceContract.csv' and f."OBJECT_CODE" = 'PO_HEADERS_INT'
  join "DMT_UPLOAD_DICT_TBL" d
    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name
   and d."IS_ADMIN_COLUMN" = 'N'
) s
on (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)
when matched then update set t."FBDI_POSITION" = s.fbdi_position
when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")
     values (s.fbdi_file_id, s.column_name, s.fbdi_position);

delete from "DMT_UPLOAD_FBDI_POS_TBL" t
where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f
                         where f."FBDI_CSV_FILENAME" = 'PoHeadersInterfaceContract.csv' and f."OBJECT_CODE" = 'PO_HEADERS_INT')
and   t."COLUMN_NAME" not in ('INTERFACE_HEADER_KEY', 'ACTION', 'BATCH_ID', 'INTERFACE_SOURCE_CODE', 'APPROVAL_ACTION', 'DOCUMENT_NUM', 'DOCUMENT_TYPE_CODE', 'STYLE_DISPLAY_NAME', 'PRC_BU_NAME', 'AGENT_NAME', 'CURRENCY_CODE', 'COMMENTS', 'VENDOR_NAME', 'VENDOR_NUM', 'VENDOR_SITE_CODE', 'VENDOR_CONTACT', 'VENDOR_DOC_NUM', 'FOB', 'FREIGHT_CARRIER', 'FREIGHT_TERMS', 'PAY_ON_CODE', 'PAYMENT_TERMS', 'ORIGINATOR_ROLE', 'CHANGE_ORDER_DESC', 'ACCEPTANCE_REQUIRED_FLAG', 'ACCEPTANCE_WITHIN_DAYS', 'SUPPLIER_NOTIF_METHOD', 'FAX', 'EMAIL_ADDRESS', 'CONFIRMING_ORDER_FLAG', 'NOTE_TO_VENDOR', 'NOTE_TO_RECEIVER', 'ATTRIBUTE_CATEGORY', 'ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4', 'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8', 'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12', 'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'ATTRIBUTE16', 'ATTRIBUTE17', 'ATTRIBUTE18', 'ATTRIBUTE19', 'ATTRIBUTE20', 'ATTRIBUTE_DATE1', 'ATTRIBUTE_DATE2', 'ATTRIBUTE_DATE3', 'ATTRIBUTE_DATE4', 'ATTRIBUTE_DATE5', 'ATTRIBUTE_DATE6', 'ATTRIBUTE_DATE7', 'ATTRIBUTE_DATE8', 'ATTRIBUTE_DATE9', 'ATTRIBUTE_DATE10', 'ATTRIBUTE_NUMBER1', 'ATTRIBUTE_NUMBER2', 'ATTRIBUTE_NUMBER3', 'ATTRIBUTE_NUMBER4', 'ATTRIBUTE_NUMBER5', 'ATTRIBUTE_NUMBER6', 'ATTRIBUTE_NUMBER7', 'ATTRIBUTE_NUMBER8', 'ATTRIBUTE_NUMBER9', 'ATTRIBUTE_NUMBER10', 'ATTRIBUTE_TIMESTAMP1', 'ATTRIBUTE_TIMESTAMP2', 'ATTRIBUTE_TIMESTAMP3', 'ATTRIBUTE_TIMESTAMP4', 'ATTRIBUTE_TIMESTAMP5', 'ATTRIBUTE_TIMESTAMP6', 'ATTRIBUTE_TIMESTAMP7', 'ATTRIBUTE_TIMESTAMP8', 'ATTRIBUTE_TIMESTAMP9', 'ATTRIBUTE_TIMESTAMP10', 'AGENT_EMAIL_ADDRESS', 'MODE_OF_TRANSPORT', 'SERVICE_LEVEL', 'BUYER_MANAGED_TRANSPORT_FLAG');

commit;
