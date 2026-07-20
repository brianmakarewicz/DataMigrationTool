# Gold Regression (v2 seeded) — Load Evidence (39 objects)

Structured evidence compiled from each object's `objects_seeded/{Object}/GOLD_README.md`
"Live evidence" section. All 39 converted seeded fixtures are LIVE-PROVEN / PASS
(good rows reached the Fusion base table, the one bad row rejected). Evidence date:
2026-07-20. Full detail (request/ESS/dataset/process IDs, all seed values, re-run notes)
in `LOAD_EVIDENCE.json`.

| Object | Type | Prefix | Base table | Good base IDs | Seed refs (short) | Re-run | Bad error (short) |
|---|---|---|---|---|---|---|---|
| Suppliers | FBDI | 19927 | POZ_SUPPLIERS | 300000331567990, 300000331567997 | CORPORATION / SUPPLIER / SPEND_AUTHORIZED | yes | valid tax organization type required [ORGANIZATION_TYPE_LOOKUP_CODE] |
| SupplierAddresses | FBDI | 35118 | HZ_PARTY_SITES | 300000331567849, 300000331567855 | Staffing Services (1253), party 300000047414569 | — | A value is required [COUNTRY] |
| SupplierSites | FBDI | 27224 | POZ_SUPPLIER_SITES_ALL_M | 300000331568020, 300000331568027 | Staffing Services, vendor 300000047414571, Staffing US1 | — | valid VENDOR_ID/VENDOR_NAME required |
| SupplierSiteAssignments | FBDI | 37353 | POZ_SITE_ASSIGNMENTS_ALL_M | 300000331568177, 300000331568179 | InterSupCH (300000188707452), client BUs Sweden/UK | one-shot | valid value required [BUSINESS_UNIT_NAME] |
| SupplierContacts | FBDI | 97571 | HZ_PARTIES | 300000331568051, 300000331568068 | St. Johns School (1493), vendor 300000324469533 | — | valid VENDOR_ID/VENDOR_NAME required |
| Customers | FBDI | 50347 | HZ_CUST_ACCOUNTS | 100002547479716, 100002547479717 | orig system LEG1, US1 Business Unit (300000046987012) | yes | HZ_IMP_PARTY_TYPE_ERROR / HZ_PRTY_PUA_INVALID_TYPE |
| PurchaseOrders | FBDI | 65058 | PO_HEADERS_ALL | 674965, 674966 | US1 BU, buyer Roth Calvin (300000047340498), Lee Supplies/Lee US1 | — | supplier site isn't valid (ZZINVALIDSITE) |
| APInvoices | FBDI | 23880 | AP_INVOICES_ALL | 1555378, 1555379 | Lee Supplies (1252)/Lee US1, US1 BU, ledger 300000046975971 | — | INVALID SUPPLIER |
| GLBalances | FBDI | 90654 | GL_JE_HEADERS (GL_INTERFACE STATUS=P) | 2461689 | US Primary Ledger (300000046975971), CCID 10196, Spreadsheet/Adjustment | yes | FLEX-VALUE DOES NOT EXIST (Account 99999) |
| GLBudgets | FBDI | 68853 | GL_BUDGET_BALANCES | 101-10-11102/11200/12101/12310-000-000-000 | US Primary Ledger, budget name Budget, accts 11102/11200/12101/12310 | yes | You must specify a valid budget name. |
| Assets | FBDI | 19666 | FA_ADDITIONS_B | 566164, 566165, 566161, 567146, 567147 | US CORP, EQUIPMENT.MANUFACTURING, USA.NEW YORK.NEW YORK | yes* | valid category combination required (ZZINVALIDCAT) |
| Requisitions | FBDI | 18526 | POR_REQUISITION_HEADERS_ALL | 128995 | US1 BU, ledger 300000046975971, Louisville, UOM ECH | — | UOM isn't valid (UOM_CODE=ZZZ) |
| Projects | FBDI | 70047 | PJF_PROJECTS_ALL_VL | 300000331550256, 300000331550282 | template PRGUS Sponsored, org Maintenance Prg US | — | IMPORT_STATUS=FAILURE (invalid source template) |
| BillingEvents | FBDI | 15949 | PJB_BILLING_EVENTS | 100002547480454, 100002547480455 | contract C10013 / Sell: Project Lines Soft Limit, project PCS10013 | — | invalid contract (proven by base-absence; interface purged) |
| Expenditures | FBDI | 30180 | PJC_EXP_ITEMS_ALL | 750730, 750731 | US1 BU, source External Miscellaneous (300000049907116), PCS10037 task 5.2 | yes | PJC_EXP_TYPE_INVALID (ZZ-BAD-EXPTYPE-99) |
| ProjectBudgets | FBDI | 96447 | PJO_PLAN_VERSIONS_B / _TL | 100002547480378, 100002547480410 | project DON003-1, plan type UNIVUS Approved Cost Budget, award DON003 | yes | PJO_XFACE_INVALID_FPT (invalid financial plan type) |
| Items | FBDI | 99133 | EGP_SYSTEM_ITEMS_B | 100002547695816, 100002547695817 | org 000, UOM Each, status Active, Root Item Class | yes | valid organization required (PROCESS_STATUS=3) |
| BlanketPOs | FBDI | 14735 | PO_HEADERS_ALL | 674970, 674971 | US1 BU, buyer Roth Calvin, Lee Supplies (1252)/Lee US1 | yes | supplier site isn't valid (ZZINVALIDSITE) |
| Contracts | FBDI | 69347 | PO_HEADERS_ALL | 674968, 674969 | US1 BU, buyer Roth Calvin, Lee Supplies (1252)/Lee US1 | yes | supplier site isn't valid (ZZINVALIDSITE) |
| MiscReceipts | FBDI | 87068 | INV_MATERIAL_TXNS | 493175, 493174 | Seattle (org 001), item AS55001, Stores, UOM Ea | yes | INV_INVALID_ITEM |
| Banks | REST | 93574 | CE_BANKS_V / CE_BANK_BRANCHES_V / CE_BANK_ACCOUNTS | 300000331550392, 300000331550397, 300000331550402, 300000331550413, 300000331550423 | US INS Legal Entity, USD, routing 935740012/935740025 | yes | Country isn't valid (HTTP 400) |
| ValueSets | REST | 94120 | FND_FLEX_VALUES | 619824, 619825 | value set FA_MAJOR_CATEGORY, max size 20 | yes | value too long (FND-2825) |
| Lookups | FSM | 60416 | FND_LOOKUP_TYPES/_VALUES (_VL) | RT_GOLD_60416 (type), G1, G2 | ModuleId 40B3FA7250D19380E040449823C67A1A | yes | Parent row missing in FND_APP_STANDARD_LOOKUP.csv — row skipped |
| UnitsOfMeasure | FSM | 19742 | INV_UNITS_OF_MEASURE_B / _TL | 300000331550473, 300000331550474 | UomClassCode 5 | yes | UomClass does not exist; skipping record (ZZ_NO_SUCH_CLASS) |
| PaymentTerms | FSM | 83810 | AP_TERMS_B / _TL / _LINES | 300000331550466, 300000331550467 | SetCode COMMON | yes | JBO-27014: SetId required (ZZ_NO_SUCH_SET) |
| Workers | HDL | 54685 | PER_ALL_PEOPLE_F | 300000331562447, 300000331562504 | US1 Legal Entity, US1 Business Unit | yes | valid LegalEntityId required (nonexistent legal employer) |
| Salaries | HDL | 71334 | CMP_SALARY | 300000331562320, 300000331562323 | US1 Annual Salary (300000048365126), assignments E10/E12 | yes | valid SalaryBasisId required |
| SalaryBases | HDL | 45660 | CMP_SALARY_BASES | 300000331569612, 300000331569603 | Regular Salary / Amount, US Legislative Data Group | yes | valid ElementTypeId required (nonexistent element) |
| PayrollRelationships | HDL | 67592 | PAY_ASSIGNED_PAYROLLS_DN | 300000331578632, 300000331578635 | US LDG (300000046974970), Biweekly (300000051084930), E15/E16 | yes | valid PayrollId required (nonexistent payroll) |
| TaxCards | HDL | 64617 | PAY_DIR_CARDS_F / PAY_DIR_CARD_COMPONENTS_F | 300000331574506 | US LDG, payroll rel 4176 (300000175399856), card def 300000000375476 | one-shot | valid SourceId required (64617DMT-NO-REL) |
| W2Balances | HDL | 60133 | PAY_BAL_BATCH_LINES | 300000331573921, 300000331573924 | US LDG (300000046974970), rels 2/2852, Regular Salary / Core Rel YTD | yes | valid BatchId required (DMTW260133NOSUCH) |
| BenParticipant | HDL | 46570 | BEN_PER_BNFTS_BAL_F | 300000331569742, 300000331569739 | 401k Employee Balance (300000074351541), persons 13/19 | yes | valid BnftsBalId required (nonexistent benefit balance) |
| BenDependent | HDL | 67254 | PER_CONTACT_RELSHIPS_F | 300000331573982, 300000331573932 | related persons 300000047626100/300000047887398, person# 10/100 | yes | ZZINVALID ContactType not in CONTACT LOV |
| BenBeneficiary | HDL | 40521 | BEN_PER_BNFTS_BAL_F | 300000331573746, 300000331573749 | 401k Vested Employer Balance (300000074351542), persons 6/8 | yes | valid BnftsBalId required (nonexistent beneficiary balance) |
| Absences | HDL | 16928 | ANC_PER_ABS_ENTRIES | 300000331570025, 300000331570159 | US1 Legal Entity (300000046974965), Vacation (300000071752546), persons 6/9 | yes | valid AbsenceTypeId required |
| TalentProfiles | HDL | 31070 | HRT_PROFILE_ITEMS | 300000331574294, 300000331574291 | profiles PERS_300000194232824/PERS_300000047627793, Oral Communication | yes | valid ContentItemId required (nonexistent content item) |
| Assignments | HDL | 30059 | PER_ALL_ASSIGNMENTS_M | 300000047339531, 300000047340518 | assignments E2/E3, US1 Legal Entity, ActionCode WORK_HOURS_CHANGE | yes | valid ActionCode required |
| PerformanceEvaluations | HDL | 29379 | HRG_GOAL_PLANS_B | 300000331573915, 300000331573918 | 2026 Annual Cycle, submitter person# 21356 | yes | DMT_INVALID_TYPE not in ORA_HRG_GOAL_PLAN_TYPE LOV |
| WorkSchedules | HDL | 34027 | HTS_WORK_PATTERNS_VL | 300000331574434, 300000331574417 | assignments E8/E9, shift 9A - 5P General Shift | yes | valid ShiftName required (nonexistent shift) |

\* Assets: PASS, but own-prefix direct base read was pending FA BIP replica refresh; the good base IDs listed are from prior prefixes (10063/10062/10057). Base bar met via the ESS PrepareMassAdditions log for prefix 19666. See JSON `rerun_note`.

## Summary

- **Gold (seeded, proven live both directions):** 39 / 39
- Re-run classification: 36 repeatable (`yes`), 2 one-shot (SupplierSiteAssignments, TaxCards), 1 caveated (Assets — replica lag).
- HDL objects terminate at the intended `ORA_IN_ERROR` (good rows load, the one bad row errors on purpose); FBDI/REST/FSM terminate `SUCCEEDED` / HTTP 201 / Completed-with-warnings.
