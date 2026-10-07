# BIP reconciliation reports: how each one selects its rows (review, 2026-10-07)

## The rule being checked

Owner rule (2026-10-07): a reconciliation BIP report must find its rows by Fusion job ids wherever possible. Base-table rows are found by the import job's REQUEST_ID, or the equivalent job or batch id column. Interface and error rows are found by the load request id. Prefix and key values may only be used to match a returned row back to its TFM row. They must never be used to select rows.

Classification used below:

- **Conforming (job id):** the branch selects rows by REQUEST_ID, LOAD_REQUEST_ID, or a batch id derived from the job.
- **Non-conforming: run id (P3):** the branch selects rows by the run id, as text or as a stamped value (for example `LIKE :P_RUN_ID || '_HDR_%'`, `GROUP_ID = :P_RUN_ID`, `ATTRIBUTE1 = :P_RUN_ID`). This includes branches where the run-id match is an extra `AND` next to a load-request-id predicate, because it still takes part in selecting rows.
- **Non-conforming: prefix (P1):** the branch selects rows by `LIKE :P_PREFIX || '%'` on a business number or key. This includes branches where the prefix is an `OR` arm next to a job-id predicate, because the prefix arm can select rows on its own.
- **Other:** anything else, with the priority and the reason given in the backlog item.

## What was reviewed

Every data model that `db/seed/dmt_bip_report_tbl.sql` currently points at for reconciliation, after all the converging MERGE blocks in that file are applied (so the newest version, not superseded ones), plus `bip/TaxCards`, which has a report in the repo but no registry row. The `.xdm` the registry names is the authority; line numbers are lines in that `.xdm` file. The `query.sql` copies are not cited because several no longer mirror their `.xdm` (backlog #215).

Not in scope: the post-run comparison reports (`*_CMP_*`, aggregate control totals, not row reconciliation), the `COMMON_LOOKUPS` business-unit lookup report, and the per-tier auditor-only registry rows (for example `PurchaseOrders.Line`), which never run a report of their own.

Job-id routes were checked read-only against the live demo pod with `scripts/fusion_bip_query.py`: first that the column exists (ALL_TAB_COLUMNS), then that recent DMT rows carry a value and that the value is the right ESS job (joined to `FUSION.ESS_REQUEST_HISTORY.DEFINITION`). No report, package or DB object was changed.

## Summary

44 reports reviewed. 7 fully conform (the five supplier objects, ItemCategories, and the dormant PlanningBudgets placeholder, which selects nothing). 37 have at least one non-conforming branch and each has one backlog item, with the item's priority set to its worst branch: Requisitions keeps its existing in-progress item #219, and #229 to #264 were added for the other 36. The review placeholder #220 is closed as RESOLVED and points here.

| Priority | Count | Objects |
|---|---|---|
| P1 (prefix) | 25 | APInvoices, ARInvoices, Assets, BillingEvents, Customers, Expenditures, Grants, Items, ProjectBudgets, Projects, Requisitions (in progress by another agent), and 14 HDL objects: Absences, Assignments, BenBeneficiary, BenDependent, BenParticipant, PayrollRelationships, PerfEvaluations, Salaries, SalaryBases, TalentProfiles, TaxCards, W2Balances, WorkSchedules, Workers |
| P3 (run id) | 6 | BlanketPOs, Contracts, PurchaseOrders, MiscReceipts, GLBalances, PaymentTerms |
| Other, P2 (exact natural-key list) | 5 | CashBanks, TaxConfig, Lookups, UnitsOfMeasure, ValueSets |
| Other, P3 (time window anchored on the job) | 1 | GLBudgets |

## Is the job-id route possible? (per item)

| Backlog | Object | Priority | Job-id route |
|---|---|---|---|
| #229 | APInvoices | P1 | Verified. `AP_INVOICES_ALL.REQUEST_ID` = Import Payables Invoices job (10291RT = 10011200). Lines must go through the header, because system-generated lines have NULL `REQUEST_ID`. |
| #230 | ARInvoices | P1 | Column exists on `RA_CUSTOMER_TRX_ALL` and lines; not verified, because AutoInvoice has never created a DMT transaction on the pod. |
| #231, #233 to #236, #242, #243, #246 to #252 | HDL objects (14) | P1 | Partly verified. `HRC_DL_LOGICAL_LINES.REQUEST_ID` carries the HDL RequestId with the record's `SOURCE_SYSTEM_ID` (request 10070653). Not yet verified: `KEY_SURROGATE_ID` on a loaded line, and whether data-set lines survive until reconcile. |
| #232 | Assets | P1 | Verified through `FA_MASS_ADDITIONS`: POSTED rows keep `LOAD_REQUEST_ID` and `ASSET_ID`. The FA base tables themselves have no request id. |
| #237 | BillingEvents | P1 | Verified. `PJB_BILLING_EVENTS.REQUEST_ID` = Import Billing Events job. |
| #238 | Customers | P1 | Verified through the interface: `HZ_IMP_*_T` rows survive with a per-run `LOAD_REQUEST_ID` and the created `PARTY_ID`. The base `REQUEST_ID` and the interface `BATCH_ID` are both 5001 for every run, so they are not job ids. |
| #239 | Expenditures | P1 | Verified. `PJC_EXP_ITEMS_ALL.REQUEST_ID` = Import Costs job. Rejected rows keep a request id too (stage `LOAD_REQUEST_ID`, `PJC_TXN_XFACE_ALL.REQUEST_ID`), which contradicts the report's own header comment. |
| #240 | Grants | P1 | Not possible on this pod. `OKC_K_HEADERS_ALL_B.REQUEST_ID` and `GMS_AWARD_HEADERS_B.DC_REQUEST_ID` are NULL on every FBDI award; the interface keeps no rows. |
| #241 | Items | P1 | Verified. `EGP_SYSTEM_ITEMS_B.REQUEST_ID` = Item Import job; the category tiers already have request-id arms, so only the prefix arm goes. |
| #244 | ProjectBudgets | P1 | Verified for BASE (`PJO_PLAN_VERSIONS_B.REQUEST_ID` = Import Budgets job). INTERFACE column exists but no surviving rows to confirm. |
| #245 | Projects | P1 | Not possible on this pod. `PJF_PROJECTS_ALL_B.REQUEST_ID` is NULL; task, team-member and transaction-control base tables have no request-id column; the interface is purged after success. |
| #219 | Requisitions | P1 | In progress by another agent under its existing item; not re-verified. All three base tables have `REQUEST_ID`. |
| #253 to #257 | CashBanks, Lookups, TaxConfig, UnitsOfMeasure, ValueSets | P2 | Not possible. The first four are REST-loaded (no ESS job); ValueSets loads by FBDI but no `FND_VS_*` table has a request or batch column. Proposed: select by the Fusion ids each REST response returns, where the object has one. Value Sets does not load at all today (#227). |
| #258, #259, #264 | BlanketPOs, Contracts, PurchaseOrders | P3 | Already in place: the interface branches select by `LOAD_REQUEST_ID`; the run-id `AND` just needs removing. |
| #260 | GLBalances | P3 | Not possible as a column. `GL_JE_BATCHES.REQUEST_ID` is NULL; the Journal Import request id only appears inside the batch name text. |
| #261 | GLBudgets | P3 | Not possible. `GL_BUDGET_BALANCES` has no job column; the current window is already anchored on the import job's start time. |
| #262 | MiscReceipts | P3 | Verified. `INV_MATERIAL_TXNS` and `INV_TRANSACTIONS_INTERFACE` carry `LOAD_REQUEST_ID` (load job) and `REQUEST_ID` (transaction manager). |
| #263 | PaymentTerms | P3 | Not possible: REST-loaded. Proposed: select by the `TERM_ID`s the REST responses return. |

## Other things found along the way

- The registry names three HDL data models that do not exist under those names in the repo (BenBeneficiary, Salaries, TalentProfiles). This was already logged as backlog #216; the review read the file that does exist in each folder.
- TaxCards has a reconciliation report in `bip/TaxCards` but no `DMT_BIP_REPORT_TBL` row, so reconciliation does not call it today.
- The Expenditures report header says rejected interface rows keep no request id. Live data shows they do (see #239), so that comment should be corrected when the report is reworked.
- Customers' base `REQUEST_ID` = 5001 on every run is worth knowing for any future HZ work: it is the bulk-import batch, not the ESS job.

## Every branch

| Object | Report (.xdm the registry points at) | Tier / branch | Line(s) | Current row-selection predicate | Classification | Backlog |
|---|---|---|---|---|---|---|
| Absences | `bip/Absences/DMT_ABSENCES_RECON_DM.xdm` | BASE absence entry (key map + ANC_PER_ABS_ENTRIES) | 76 | `m.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #231 |
| APInvoices | `bip/APInvoices/DMT_AP_RECON_DM.xdm` | BASE header (AP_INVOICES_ALL) | 131 | `h.invoice_num LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #229 |
| APInvoices | `bip/APInvoices/DMT_AP_RECON_DM.xdm` | BASE line (AP_INVOICE_LINES_ALL) | 154 | `h.invoice_num LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #229 |
| APInvoices | `bip/APInvoices/DMT_AP_RECON_DM.xdm` | INTERFACE header rejections | 185-186 | `h.load_request_id = :P_LOAD_REQUEST_ID OR h.invoice_num LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #229 |
| APInvoices | `bip/APInvoices/DMT_AP_RECON_DM.xdm` | INTERFACE line rejections | 223-224 | `l.load_request_id = :P_LOAD_REQUEST_ID OR h.invoice_num LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #229 |
| APInvoices | `bip/APInvoices/DMT_AP_RECON_DM.xdm` | INTERFACE lines inherited from rejected header | 278-279 | `l.load_request_id = :P_LOAD_REQUEST_ID OR h.invoice_num LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #229 |
| ARInvoices | `bip/ARInvoices/DMT_AR_RECON_V3_DM.xdm` | BASE transaction line (RA_CUSTOMER_TRX_LINES_ALL) | 135 | `bl.interface_line_attribute1 LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #230 |
| ARInvoices | `bip/ARInvoices/DMT_AR_RECON_V3_DM.xdm` | BASE distribution | 190 | `bl.interface_line_attribute1 LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #230 |
| ARInvoices | `bip/ARInvoices/DMT_AR_RECON_V3_DM.xdm` | INTERFACE line | 229 | `l.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #230 (same report) |
| ARInvoices | `bip/ARInvoices/DMT_AR_RECON_V3_DM.xdm` | INTERFACE distribution | 292 | `d.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #230 (same report) |
| Assets | `bip/Assets/DMT_FA_ASSET_RECON_DM.xdm` | BASE asset (FA_ADDITIONS_B) | 114-115 | `a.asset_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #232 |
| Assets | `bip/Assets/DMT_FA_ASSET_RECON_DM.xdm` | INTERFACE mass additions | 136 | `fma.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #232 (same report) |
| Assets | `bip/Assets/DMT_FA_ASSET_RECON_DM.xdm` | BASE distribution (FA_DISTRIBUTION_HISTORY) | 171-172 | `a.asset_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #232 |
| Assignments | `bip/Assignments/DMT_ASSIGNMENTS_RECON_DM.xdm` | BASE work relationship | 64 | `k.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #233 |
| Assignments | `bip/Assignments/DMT_ASSIGNMENTS_RECON_DM.xdm` | BASE assignment | 83 | `k.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #233 |
| BenBeneficiary | `bip/BenBeneficiary/DMT_BEN_BENFY_RECON_DM.xdm` | BASE beneficiary enrollment | 103-104 | `m.source_system_id LIKE :P_PREFIX \|\| '%' AND LIKE '%\_BENENRL'` | Non-conforming: prefix (P1) | #234 |
| BenDependent | `bip/BenDependent/DMT_BENDEPENDENT_RECON_DM.xdm` | BASE dependent | 80-81 | `m.source_system_id LIKE :P_PREFIX \|\| '%' AND LIKE '%\_BENDEP'` | Non-conforming: prefix (P1) | #235 |
| BenParticipant | `bip/BenParticipant/DMT_BENPARTICIPANT_RECON_DM.xdm` | BASE enrollment result (BEN_PRTT_ENRT_RSLT + PER_ALL_PEOPLE_F) | 77 | `p.person_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #236 |
| BillingEvents | `bip/BillingEvents/BILLING_EVENT_DM.xdm` | BASE event (PJB_BILLING_EVENTS) | 105-106 | `be.sourceref LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #237 |
| BillingEvents | `bip/BillingEvents/BILLING_EVENT_DM.xdm` | INTERFACE | 130 | `b.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #237 (same report) |
| BlanketPOs | `bip/BlanketPOs/DMT_BLANKET_PO_RECON_DM.xdm` | BASE header | 76-77 | `h.request_id = :P_IMPORT_ESS_ID` | Conforming (job id) | #258 (same report) |
| BlanketPOs | `bip/BlanketPOs/DMT_BLANKET_PO_RECON_DM.xdm` | BASE line | 96-97 | `l.request_id = :P_IMPORT_ESS_ID` | Conforming (job id) | #258 (same report) |
| BlanketPOs | `bip/BlanketPOs/DMT_BLANKET_PO_RECON_DM.xdm` | INTERFACE header | 131-132 | `h.load_request_id = :P_LOAD_REQUEST_ID AND h.interface_header_key LIKE :P_RUN_ID \|\| '\_HDR\_%'` | Non-conforming: run id (P3) | #258 |
| BlanketPOs | `bip/BlanketPOs/DMT_BLANKET_PO_RECON_DM.xdm` | INTERFACE line | 166-167 | `l.load_request_id = :P_LOAD_REQUEST_ID AND l.interface_line_key LIKE :P_RUN_ID \|\| '\_LN\_%'` | Non-conforming: run id (P3) | #258 |
| CashBanks | `bip/CashBanks/DMT_CEBANK_RECON_DM.xdm` | BASE bank (CE_BANKS_V) | 20 | `bank_name IN list :P_BANK_NAMES (INSTR)` | Other: natural-key list (P2) | #253 |
| CashBanks | `bip/CashBanks/DMT_CEBANK_RECON_DM.xdm` | BASE branch | 33 | `bank_branch_name IN list :P_BRANCH_NAMES` | Other: natural-key list (P2) | #253 |
| CashBanks | `bip/CashBanks/DMT_CEBANK_RECON_DM.xdm` | BASE account | 45 | `bank_account_name IN list :P_ACCT_NAMES` | Other: natural-key list (P2) | #253 |
| Contracts | `bip/Contracts/DMT_CONTRACT_RECON_DM.xdm` | BASE header | 73-74 | `h.request_id = :P_IMPORT_ESS_ID` | Conforming (job id) | #259 (same report) |
| Contracts | `bip/Contracts/DMT_CONTRACT_RECON_DM.xdm` | INTERFACE header | 108-109 | `h.load_request_id = :P_LOAD_REQUEST_ID AND h.interface_header_key LIKE :P_RUN_ID \|\| '\_HDR\_%'` | Non-conforming: run id (P3) | #259 |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | INTERFACE, seven HZ_IMP_*_T tiers (ld CTE) | 90, 98, 107, 116, 124, 133, 141 | `t.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #238 (same report) |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | BASE Parties (HZ_ORIG_SYS_REFERENCES) | 203 | `r.orig_system_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #238 |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | BASE Locations | 219 | `r.orig_system_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #238 |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | BASE PartySites | 235 | `r.orig_system_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #238 |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | BASE PartySiteUses | 255 | `pr.orig_system_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #238 |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | BASE Accounts | 271 | `r.orig_system_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #238 |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | BASE AccountSites | 287 | `r.orig_system_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #238 |
| Customers | `bip/Customers/DMT_CUST_RECON_V5_DM.xdm` | BASE AccountSiteUses | 303 | `r.orig_system_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #238 |
| Expenditures | `bip/Expenditures/DMT_EXP_RECON_DM.xdm` | BASE expenditure item (PJC_EXP_ITEMS_ALL) | 110 | `ei.orig_transaction_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #239 |
| Expenditures | `bip/Expenditures/DMT_EXP_RECON_DM.xdm` | INTERFACE rejections (PJC_TXN_XFACE_STAGE_ALL) | 141 | `st.orig_transaction_reference LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #239 |
| GLBalances | `bip/GLBalances/DMT_GL_BAL_RECON_DM.xdm` | BASE journal (GL_JE_BATCHES / HEADERS / LINES) | 93 | `jb.group_id = :P_RUN_ID` | Non-conforming: run id (P3) | #260 |
| GLBalances | `bip/GLBalances/DMT_GL_BAL_RECON_DM.xdm` | INTERFACE (GL_INTERFACE) | 113 | `gi.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #260 (same report) |
| GLBudgets | `bip/GLBudgets/GL_BUDGET_DM.xdm` | BASE budget cell (GL_BUDGET_BALANCES) | 199-203 | `bb.last_update_date >= PROCESSSTART of ESS request :P_IMPORT_ESS_ID` | Other: job-anchored time window (P3) | #261 |
| GLBudgets | `bip/GLBudgets/GL_BUDGET_DM.xdm` | INTERFACE (GL_BUDGET_INTERFACE) | 247 | `gi.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #261 (same report) |
| Grants | `bip/Grants/DMT_GRANT_RECON_V2_DM.xdm` | BASE award (GMS_AWARD_HEADERS_B + OKC_K_HEADERS_ALL_B) | 79-80 | `k.contract_number LIKE :P_PREFIX \|\| '%' AND b.award_source = 'FBDI'` | Non-conforming: prefix (P1) | #240 |
| Grants | `bip/Grants/DMT_GRANT_RECON_V2_DM.xdm` | INTERFACE (GMS_AWARD_HEADERS_INT) | 111 | `h.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #240 (same report) |
| ItemCategories | `bip/ItemCategories/ITEM_CAT_DM.xdm` | INTERFACE only | 28 | `ic.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | none |
| Items | `bip/Items/DMT_ITEM_RECON_V2_DM.xdm` | INTERFACE item (EGP_SYSTEM_ITEMS_INTERFACE) | 151-152 | `i.item_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #241 |
| Items | `bip/Items/DMT_ITEM_RECON_V2_DM.xdm` | BASE item (EGP_SYSTEM_ITEMS_B via interface) | 180-181 | `i.item_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #241 |
| Items | `bip/Items/DMT_ITEM_RECON_V2_DM.xdm` | INTERFACE item category | 260-262 | `ic.load_request_id = :P_LOAD_REQUEST_ID OR ic.request_id = :P_IMPORT_ESS_ID OR ic.item_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #241 |
| Items | `bip/Items/DMT_ITEM_RECON_V2_DM.xdm` | BASE item category | 288-290 | `same three-way OR including the prefix arm` | Non-conforming: prefix (P1) | #241 |
| Lookups | `bip/Lookups/DMT_LOOKUP_RECON_DM.xdm` | BASE lookup type (FND_LOOKUP_TYPES) | 93 | `lookup_type IN list :P_TYPE_CODES` | Other: natural-key list (P2) | #254 |
| Lookups | `bip/Lookups/DMT_LOOKUP_RECON_DM.xdm` | BASE lookup value (FND_LOOKUP_VALUES_B) | 112 | `lookup_type^lookup_code IN list :P_VALUE_KEYS` | Other: natural-key list (P2) | #254 |
| MiscReceipts | `bip/MiscReceipts/DMT_INV_TRX_RECON_DM.xdm` | BASE transaction (INV_MATERIAL_TXNS) | 104-105 | `t.transaction_reference = 'DMT-' \|\| :P_RUN_ID OR LIKE 'DMT-' \|\| :P_RUN_ID \|\| '-%'` | Non-conforming: run id (P3) | #262 |
| MiscReceipts | `bip/MiscReceipts/DMT_INV_TRX_RECON_DM.xdm` | INTERFACE (INV_TRANSACTIONS_INTERFACE) | 126-127 | `same run-id match plus process_flag = 3` | Non-conforming: run id (P3) | #262 |
| MiscReceipts | `bip/MiscReceipts/DMT_INV_TRX_RECON_DM.xdm` | BASE serial (INV_SERIAL_NUMBERS) | 158-159 | `EXISTS a run-id-matched INV_MATERIAL_TXNS row` | Non-conforming: run id (P3) | #262 |
| PaymentTerms | `bip/APPaymentTerms/DMT_APTERMS_RECON_DM.xdm` | BASE term header (AP_TERMS_B) | 99 | `b.attribute1 = TO_CHAR(:P_RUN_ID)` | Non-conforming: run id (P3) | #263 |
| PaymentTerms | `bip/APPaymentTerms/DMT_APTERMS_RECON_DM.xdm` | BASE term line (AP_TERMS_LINES) | 119 | `b.attribute1 = TO_CHAR(:P_RUN_ID)` | Non-conforming: run id (P3) | #263 |
| PayrollRelationships | `bip/PayrollRelationships/DMT_PAYROLLRELATIONSHIPS_RECON_DM.xdm` | BASE payroll relationship | 66-67 | `m.source_system_id LIKE :P_PREFIX \|\| '%' AND LIKE '%\_PAYREL'` | Non-conforming: prefix (P1) | #242 |
| PerfEvaluations | `bip/PerfEvaluations/DMT_PERFEVALUATIONS_RECON_DM.xdm` | BASE evaluation (HRA_EVALUATIONS) | 79 | `v.name LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #243 |
| PlanningBudgets | `bip/PlanningBudgets/PLAN_BUDGET_DM.xdm` | BASE placeholder (dormant) | 80 | `WHERE 1 = 0 (selects nothing; no reachable table)` | Not applicable (selects nothing; dormant) | none |
| ProjectBudgets | `bip/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V2_DM.xdm` | BASE plan version (PJO_PLAN_VERSIONS_B) | 151-156 | `v.pm_budget_reference LIKE :P_PREFIX \|\| '%' OR p.segment1 LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #244 |
| ProjectBudgets | `bip/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V2_DM.xdm` | INTERFACE (PJO_PLAN_VERSIONS_XFACE) | 188-190 | `x.src_budget_line_reference LIKE :P_PREFIX \|\| '%' OR x.project_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #244 |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | BASE project (PJF_PROJECTS_ALL_B) | 90-91 | `p.segment1 LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #245 |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | INTERFACE project | 112 | `x.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #245 (same report) |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | BASE task (PJF_PROJ_ELEMENTS_B) | 130-131 | `p.segment1 LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #245 |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | INTERFACE task | 153 | `t.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #245 (same report) |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | BASE team member (PJT_PROJECT_RESOURCE) | 187-188 | `pv.segment1 LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #245 |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | INTERFACE team member | 211 | `tm.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #245 (same report) |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | BASE transaction control (PJC_TRANSACTION_CONTROLS) | 239-240 | `p.segment1 LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #245 |
| Projects | `bip/Projects/DMT_PROJECT_RECON_DM.xdm` | INTERFACE transaction control | 265 | `tc.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | #245 (same report) |
| PurchaseOrders | `bip/PurchaseOrders/DMT_PO_RECON_DM.xdm` | BASE header / line / schedule / distribution | 114, 134, 155, 182 | `request_id = :P_IMPORT_ESS_ID` | Conforming (job id) | #264 (same report) |
| PurchaseOrders | `bip/PurchaseOrders/DMT_PO_RECON_DM.xdm` | INTERFACE header | 223-224 | `h.load_request_id = :P_LOAD_REQUEST_ID AND h.interface_header_key LIKE :P_RUN_ID \|\| '\_HDR\_%'` | Non-conforming: run id (P3) | #264 |
| PurchaseOrders | `bip/PurchaseOrders/DMT_PO_RECON_DM.xdm` | INTERFACE line | 263-264 | `l.load_request_id = :P_LOAD_REQUEST_ID AND l.interface_line_key LIKE :P_RUN_ID \|\| '\_LN\_%'` | Non-conforming: run id (P3) | #264 |
| PurchaseOrders | `bip/PurchaseOrders/DMT_PO_RECON_DM.xdm` | INTERFACE schedule | 303-304 | `ll.load_request_id = :P_LOAD_REQUEST_ID AND ll.interface_line_location_key LIKE :P_RUN_ID \|\| '\_LOC\_%'` | Non-conforming: run id (P3) | #264 |
| PurchaseOrders | `bip/PurchaseOrders/DMT_PO_RECON_DM.xdm` | INTERFACE distribution | 344-345 | `d.load_request_id = :P_LOAD_REQUEST_ID AND d.interface_distribution_key LIKE :P_RUN_ID \|\| '\_DIST\_%'` | Non-conforming: run id (P3) | #264 |
| Requisitions | `bip/Requisitions/DMT_REQ_RECON_DM.xdm` | BASE header (POR_REQUISITION_HEADERS_ALL) | 108 | `rh.requisition_number LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #219 (in progress) |
| Requisitions | `bip/Requisitions/DMT_REQ_RECON_DM.xdm` | BASE line | 127 | `rl.interface_line_key LIKE :P_RUN_ID \|\| '\_RQLN\_%'` | Non-conforming: run id (P3) | #219 (in progress) |
| Requisitions | `bip/Requisitions/DMT_REQ_RECON_DM.xdm` | BASE distribution | 153 | `rl.interface_line_key LIKE :P_RUN_ID \|\| '\_RQLN\_%'` | Non-conforming: run id (P3) | #219 (in progress) |
| Requisitions | `bip/Requisitions/DMT_REQ_RECON_DM.xdm` | INTERFACE header | 193 | `h.interface_header_key LIKE :P_RUN_ID \|\| '\_RQHDR\_%'` | Non-conforming: run id (P3) | #219 (in progress) |
| Requisitions | `bip/Requisitions/DMT_REQ_RECON_DM.xdm` | INTERFACE line | 223 | `l.interface_line_key LIKE :P_RUN_ID \|\| '\_RQLN\_%'` | Non-conforming: run id (P3) | #219 (in progress) |
| Requisitions | `bip/Requisitions/DMT_REQ_RECON_DM.xdm` | INTERFACE distribution | 257 | `d.interface_distribution_key LIKE :P_RUN_ID \|\| '\_RQDIST\_%'` | Non-conforming: run id (P3) | #219 (in progress) |
| Salaries | `bip/Salaries/DMT_SALARY_RECON_DM.xdm` | BASE salary | 65-66 | `m.source_system_id LIKE :P_PREFIX \|\| '%' AND LIKE '%\_SAL'` | Non-conforming: prefix (P1) | #246 |
| SalaryBases | `bip/SalaryBases/DMT_SALARYBASES_RECON_DM.xdm` | BASE salary basis | 80 | `m.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #247 |
| SupplierAddresses | `bip/SupplierAddresses/SUP_ADDR_DM.xdm` | INTERFACE + base join | 38 | `i.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | none |
| SupplierContacts | `bip/SupplierContacts/SUP_CONT_DM.xdm` | INTERFACE + base join | 40 | `i.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | none |
| Suppliers | `bip/Suppliers/SUP_DM.xdm` | INTERFACE + base join | 41 | `i.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | none |
| SupplierSiteAssignments | `bip/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm` | INTERFACE + base join | 56 | `i.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | none |
| SupplierSites | `bip/SupplierSites/SUP_SITE_DM.xdm` | INTERFACE + base join | 41 | `i.load_request_id = :P_LOAD_REQUEST_ID` | Conforming (job id) | none |
| TalentProfiles | `bip/TalentProfiles/DMT_TALENT_PROF_RECON_DM.xdm` | BASE profile item | 99 | `m.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #248 |
| TalentProfiles | `bip/TalentProfiles/DMT_TALENT_PROF_RECON_DM.xdm` | BASE talent profile | 118 | `m.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #248 |
| TaxCards | `bip/TaxCards/DMT_TAX_CARD_RECON_DM.xdm` | BASE tax card | 75 | `m.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #249 |
| TaxConfig | `bip/Taxes/DMT_ZX_RECON_DM.xdm` | BASE regime (ZX_REGIMES_B) | 20 | `tax_regime_code IN list :P_REGIME_CODES` | Other: natural-key list (P2) | #255 |
| TaxConfig | `bip/Taxes/DMT_ZX_RECON_DM.xdm` | BASE rate (ZX_RATES_B) | 32 | `tax_rate_code IN list :P_RATE_CODES` | Other: natural-key list (P2) | #255 |
| UnitsOfMeasure | `bip/UnitsOfMeasure/DMT_UOM_RECON_DM.xdm` | BASE UOM (INV_UNITS_OF_MEASURE_B) | 86 | `uom_code IN list :P_UOM_CODES` | Other: natural-key list (P2) | #256 |
| ValueSets | `bip/ValueSets/DMT_VS_RECON_DM.xdm` | BASE value set (FND_VS_VALUE_SETS) | 20 | `value_set_code IN list :P_SET_CODES` | Other: natural-key list (P2) | #257 |
| ValueSets | `bip/ValueSets/DMT_VS_RECON_DM.xdm` | BASE value (FND_VS_VALUES_B) | 30 | `value_set_code^value IN list :P_VALUE_KEYS` | Other: natural-key list (P2) | #257 |
| W2Balances | `bip/W2Balances/DMT_W2_BAL_RECON_DM.xdm` | BASE balance batch (PAY_BAL_BATCH_HEADERS) | 106 | `h.batch_name LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #250 |
| Workers | `bip/Workers/DMT_WORKERS_RECON_DM.xdm` | BASE person and component tiers (key map, one branch) | 89-90 | `m.source_system_id LIKE :P_PREFIX \|\| '%'` | Non-conforming: prefix (P1) | #252 |
| WorkSchedules | `bip/WorkSchedules/DMT_WORKSCHEDULES_RECON_DM.xdm` | BASE work pattern | 109-110 | `m.source_system_id LIKE :P_PREFIX \|\| '%' AND LIKE '%\_WPAT'` | Non-conforming: prefix (P1) | #251 |
| WorkSchedules | `bip/WorkSchedules/DMT_WORKSCHEDULES_RECON_DM.xdm` | BASE schedule assignment | 135-136 | `m.source_system_id LIKE :P_PREFIX \|\| '%' AND LIKE '%\_WSASG'` | Non-conforming: prefix (P1) | #251 |
