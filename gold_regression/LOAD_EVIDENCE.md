# Gold Regression — Load Evidence (all 45 objects)

Structured evidence compiled from each object's `GOLD_README.md` "Live evidence" section,
cross-checked against the top-level `README.md` status table. Evidence dates: 2026-07-19,
with a few re-proofs/retries on 2026-07-20. 39 gold, 6 tabled.

| Object | Status | Type | Prefix | Key request IDs | Base table | Good base IDs | Bad error (short) |
|---|---|---|---|---|---|---|---|
| Suppliers | gold | FBDI | 93107 | load 9762785 | POZ_SUPPLIERS | 300000331542172, 300000331542179 | valid tax organization type required [ORGANIZATION_TYPE_LOOKUP_CODE] |
| SupplierAddresses | gold | FBDI | 65733 | load 9763266 / import 9763280 | HZ_PARTY_SITES | 300000331545164, 300000331545170 | A value is required [COUNTRY] |
| SupplierSites | gold | FBDI | 79717 | load 9763210 | POZ_SUPPLIER_SITES_ALL_M | 300000331544937, 300000331544940 | valid VENDOR_ID/VENDOR_NAME required |
| SupplierSiteAssignments | gold | FBDI | 54318 | load 9763415 | POZ_SITE_ASSIGNMENTS_ALL_M | 300000331545486, 300000331545488 | valid value required [BUSINESS_UNIT_NAME] |
| SupplierContacts | gold | FBDI | 89777 | load 9763255 | HZ_PARTIES | 300000331545112, 300000331545129 | valid VENDOR_ID/VENDOR_NAME required |
| Customers | gold | FBDI | 63171 | load 9763020 (CDMAutoBulkImportJob, batch 63171) | HZ_CUST_ACCOUNTS | 100002547170278, 100002547170279 | HZ_IMP_PARTY_TYPE_ERROR / HZ_PRTY_PUA_INVALID_TYPE (party type INVALID_TYPE) |
| PurchaseOrders | gold | FBDI | 16041 | load 9763403 / import 9763413 | PO_HEADERS_ALL / PO_LINES_ALL | 674949, 674950 | supplier site isn't valid (ZZINVALIDSITE) |
| APInvoices | gold | FBDI | 90213 | load 9762926 / import 9762927 | AP_INVOICES_ALL | 1554382, 1554383 | INVALID SUPPLIER |
| ARInvoices | tabled | FBDI | 90223 | load 9763470 / master 9763477 | RA_CUSTOMER_TRX_ALL | — | not produced (AutoInvoice aborts before validation) — blocker: Consolidated Billing forces Master route; Master load_request_id slot unreachable via submitESSJobRequest |
| GLBalances | gold | FBDI | 90219 | load 9763072 | GL_JE_HEADERS (GL_INTERFACE STATUS=P) | 2462677 | EF04: FLEX-VALUE DOES NOT EXIST (Account 99999) |
| GLBudgets | gold | FBDI | 90231 | load 9763087 / good-run 9763103 / bad-run 9763165 | GL_BUDGET_BALANCES | 101-10-11102/11200/12101/12310-000-000-000 | You must specify a valid budget name. |
| Assets | gold | FBDI | 90241 | prepare 9763379 / post 9763405 | FA_ADDITIONS_B | 567146, 567147, 567143, 567144 | valid category combination required (ZZINVALIDCAT) |
| Requisitions | gold | FBDI | 90221 | load 9763076 | POR_REQUISITION_HEADERS_ALL | 128988 | UOM isn't valid (UOM_CODE=ZZZ) |
| Projects | gold | FBDI | 92666 | load 9763523 / import 9763529 / report 9763532 | PJF_PROJECTS_ALL_VL | 300000331530301, 300000331530326 | The source template number isn't valid. |
| BillingEvents | gold | FBDI | 52922 | load 9763577 / import 9763536 | PJB_BILLING_EVENTS | 100002547246605, 100002547246606 | IMPORT_STATUS=ERROR (invalid contract; proven by base-absence) |
| Expenditures | gold | FBDI | 32159 | load 9764984 / import 9765010 / report 9765015 | PJC_EXP_ITEMS_ALL | 750728, 750729 | PJC_EXP_TYPE_INVALID (ZZ-BAD-EXPTYPE-99) |
| ProjectBudgets | gold | FBDI | 95661 | load 9764471 / import 9764476 / report 9764483 | PJO_PLAN_VERSIONS_B | 100002547416587, 100002547416619 | invalid financial plan type (PJO_XFACE_INVALID_FPT) |
| Workers | gold | HDL | 90217 | dataset 9762975 | PER_ALL_PEOPLE_F | 300000331523525, 300000331523468 | valid LegalEntityId required (nonexistent legal employer) |
| Salaries | gold | HDL | 90221 | dataset 9763105 | CMP_SALARY | 300000331542638, 300000331542641 | valid SalaryBasisId required (nonexistent basis) |
| Assignments | gold | HDL | 90264 | dataset 9764168 | PER_ALL_ASSIGNMENTS_M | 300000047339531, 300000047340518 | valid ActionCode required |
| Items | gold | FBDI | 69160 | load 9763999 / import 9764006 | EGP_SYSTEM_ITEMS_B | 100002547248242, 100002547248243 | valid organization required (ZZ_NO_SUCH_ORG; base-absence) |
| ItemCategories | tabled | FBDI | 93120 | load 9764809 | EGP_ITEM_CATEGORIES | — | not produced — blocker: loadAndImportData won't launch CatalogImportJobDef standalone; category is a peripheral entity of an Item Import batch |
| BlanketPOs | gold | FBDI | 55501 | load 9763721 / import 9763741 | PO_HEADERS_ALL (BLANKET) | 674951, 674952 | supplier site isn't valid (ZZINVALIDSITE) |
| Contracts | gold | FBDI | 70685 | load 9763717 / import 9763740 | PO_HEADERS_ALL (CONTRACT) | 674953, 674954 | supplier site isn't valid (ZZINVALIDSITE) |
| MiscReceipts | gold | FBDI | 90256 | load 9764272 / PollTM 9764279 | INV_MATERIAL_TXNS | 492176, 492175 | INV_INVALID_ITEM (FAKE-ITEM-90256-BAD) |
| Grants | tabled | FBDI | 90510 | load 9765110 | OKC_K_HEADERS_ALL_B | — | GMS_CAFT_SVC_INVALID_AWD_TEMPL (bad row) — blocker: base pending on pod ESS scheduler backlog (award loads sat WAIT then EXPIRED); environmental, not fixture |
| SalaryBases | gold | HDL | 90263 | dataset 9763638 | CMP_SALARY_BASES | 300000331542962, 300000331542960 | valid ElementTypeId required (nonexistent element) |
| PayrollRelationships | gold | HDL | 42961 | dataset 9763689 | PAY_ASSIGNED_PAYROLLS_DN | 300000331543036, 300000331543033 | valid PayrollId required (nonexistent payroll) |
| TaxCards | gold | HDL | 91208 | dataset 9765395 | PAY_DIR_CARDS_F | 300000331562090 | valid SourceId required (91208DMT-NO-REL) |
| W2Balances | gold | HDL | 65405 | dataset 9764507 | PAY_BAL_BATCH_LINES | 300000331555931, 300000331555934 | valid BatchId required (DMTW265405NOSUCH) |
| BenParticipant | gold | HDL | 90313 | dataset 9764141 | BEN_PER_BNFTS_BAL_F | 300000331543542, 300000331552545 | valid BnftsBalId required (nonexistent benefit balance) |
| BenDependent | gold | HDL | 90419 | dataset 9764674 | PER_CONTACT_RELSHIPS_F | 300000331556109, 300000331556120 | ZZINVALID ContactType not in CONTACT LOV |
| BenBeneficiary | gold | HDL | 67936 | dataset 9764242 | BEN_PER_BNFTS_BAL_F | 300000331552758, 300000331552756 | valid BnftsBalId required (nonexistent beneficiary balance) |
| Absences | gold | HDL | 15886 | dataset 9764443 | ANC_PER_ABS_ENTRIES | 300000331553437, 300000331555559 | valid AbsenceTypeId required (nonexistent absence type) |
| TalentProfiles | gold | HDL | 10554 | dataset 9764155 | HRT_PROFILE_ITEMS | 300000331552584, 300000331552580 | valid ContentItemId required (nonexistent content item) |
| PerformanceEvaluations | gold | HDL | 43426 | dataset 9764288 | HRG_GOAL_PLANS_B | 300000331553042, 300000331553046 | DMT_INVALID_TYPE not in ORA_HRG_GOAL_PLAN_TYPE LOV |
| WorkSchedules | gold | HDL | 57139 | dataset 9764508 | HTS_WORK_PATTERNS_VL | 300000331555913, 300000331555899 | valid ShiftName required (nonexistent shift) |
| PlanningBudgets | tabled | FBDI | — | — | planning cube (EPM pod) | — | n/a — blocker: EPM Cloud (EPBCS) object, not a Fusion ERP FBDI object; no EPM subscription/base table on this pod |
| Banks | gold | REST | 91805 | REST POSTs (bank/branch/account) | CE_BANKS_V / CE_BANK_BRANCHES_V / CE_BANK_ACCOUNTS | 300000331549646, 300000331549651, 300000331549657, 300000331549668, 300000331549678 | Country isn't valid (HTTP 400, Nowhereland) |
| GLCalendar | tabled | FSM | — | process 100007866630785 / ESS 9764673 | GL_CALENDARS / GL_PERIOD_SETS / GL_PERIODS | — | not produced (importer skipped) — blocker: External-Loading SOA-batch object; flat CSVs skipped; reference batch export exceeds FSM 10MB limit (191 calendars) |
| ValueSets | gold | REST | 91861 | REST POSTs (per value) | FND_FLEX_VALUES | 619812, 619813 | value too long (FND-2825, HTTP 400) |
| Lookups | gold | FSM | 90777 | process 100007866630904 / ESS 9765415 | FND_LOOKUP_TYPES_VL / FND_LOOKUP_VALUES_VL | RT_GOLD_90777 (type), G1, G2 | Parent row missing in FND_APP_STANDARD_LOOKUP.csv — row skipped |
| UnitsOfMeasure | gold | FSM | 90210 | process 100007866630872 / ESS 9765360 | INV_UNITS_OF_MEASURE_B | 300000331549888, 300000331549889 | UomClass does not exist; skipping record (ZZ_NO_SUCH_CLASS) |
| PaymentTerms | gold | FSM | 90212 | process 100007867615386 / ESS 9765468 | AP_TERMS_B | 300000331550019, 300000331550020 | JBO-27014: SetId required (ZZ_NO_SUCH_SET) |
| TaxConfig | tabled | FSM | — | process 100007868615103 / ESS 9765656 | ZX_RATES_B | — | not produced — blocker: FSM CSV task has no tax-rate HEADER object (detail-only); rate headers remain UI-Workbook-only |

## Summary

- **Gold (proven live, both directions):** 39
- **Tabled:** 6 — ARInvoices, ItemCategories, Grants, PlanningBudgets, GLCalendar, TaxConfig
- **Total:** 45
