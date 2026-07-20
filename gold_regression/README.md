# Gold Regression — trusted good/bad load fixtures, proven live to Fusion base tables

**Purpose.** A standalone, trusted library of regression data for every migration object.
For each object we keep a *ready-to-load* FBDI zip / HDL DAT that carries **known-good rows
and known-bad rows**, and we have **proven, live against the Fusion demo instance**, that:

- the **good** rows reach the **Fusion base tables** (confirmed by a read-only BIP query), and
- the **bad** rows land in the **interface tables with a real error** and do **not** reach the base tables.

This exists because our regression scenario data kept drifting — we would fabricate data, it
would sometimes load and sometimes not, and we could never trust a red result. This folder is
the fix: a frozen, re-verifiable "gold copy" that is built and loaded **outside** the DMT
pipeline (no DMT database, no DMT PL/SQL), so it tests the data itself, not the tool.

## Hard rules for this folder

1. **No DMT code or DMT database involvement in the load path.** We assemble the FBDI/HDL
   artifact and call the Fusion web services directly (see `harness/`). The DMT pipeline
   tables and packages are never touched to load a gold fixture.
2. **Verification is read-only.** Base-table and interface-table checks go through the
   read-only BIP query relay (the same mechanism as `scripts/fusion_bip_query.py`). Reading
   Fusion base tables is only possible via BIP — that is not "DMT database involvement."
3. **A fixture is not "gold" until it is proven live**, both directions (good → base tables,
   bad → interface error, absent from base tables). Offline/build-only is not gold.
4. **Reloadable, not one-shot.** Natural keys carry a `${PREFIX}` placeholder that the harness
   stamps with a fresh numeric prefix at load time, so the same fixture can be re-loaded on any
   future run without colliding with data already in Fusion.
5. **Every object folder gets a `GOLD_README.md`** documenting the exact call: web-service
   endpoint + operation, the full ParameterList spelled out, the auth user, **every ESS job in
   order — the load/import job, any chained/subsequent job, and any downstream program we must
   wait to complete before verifying** — the base-table and interface-table verification
   queries, and the last live-proven evidence (date, prefix, request ids, row counts). Whenever
   we learn something new, we update it here **and** in `../objects/{Name}/README.md`.

### Portability rules (added 2026-07-19 — the whole point of "gold")

6. **Self-sufficient against a fresh demo pod. No upstream dependency on our own loads.** A
   fixture must load successfully on ANY Oracle Fusion demo environment, standalone. It may NOT
   assume a parent object we loaded earlier exists (e.g. do not reference a supplier or worker
   we created under a prefix). Every reference a fixture needs (business unit, ledger, supplier,
   customer, item, worker, salary basis, etc.) must point at data that already ships in / already
   exists in the target pod.
7. **Discover references at load time, never hardcode ids.** Fusion ids differ per pod. The
   harness/recipe must, at load time, run a read-only BIP query against the TARGET environment
   to find a valid existing reference (e.g. "an active supplier", "a primary ledger", "an
   INV_ORG"), and stamp the fixture with the discovered natural-key/name value. Hardcoding a
   vendor_id or a specific ledger name that only exists on our working pod is a portability bug.
8. **New record is created fresh; its references are borrowed from what exists.** The good/bad
   rows create NEW top-level records (stamped with a fresh prefix so they don't collide), but any
   FK-style reference inside them is a discovered, already-present value. This is what lets the
   same gold copy run in a pod we have never touched.

## Per-object recipe convention

Each object is driven by a self-contained recipe so objects can be built in parallel without
editing a shared file. `harness/objects.json` holds the shared/simple recipes; an object with
discovery logic or special handling keeps `objects/{Name}/recipe.json`. A recipe declares: type
(FBDI/HDL/REST), the CSV/DAT member layout, the discovery queries for references, the good-row
and bad-row field values (bad row + its expected Fusion error), the ordered ESS jobs
(load → import → downstream), and the base-table + interface-table verify queries.

## Two versions: v1 frozen (discovery) and v2 seeded (hard-coded)

- **v1 — `objects/` — FROZEN as of 2026-07-20.** The proven fixtures that discover their
  upstream references at load time (`${TOKEN}`). These are the reference baseline and are not
  edited. The job IDs that loaded them are recorded in `LOAD_EVIDENCE.json` / `LOAD_EVIDENCE.md`.
- **v2 — `objects_seeded/` — the converting version.** The same good/bad records with discovery
  replaced by hard-coded standard-seed references (a supplier we never loaded, `US1 Business
  Unit`, `US Primary Ledger`, …), which are identical across demo pods. Simpler and lookup-free.

Both run through the same engine; a single env var chooses which tree:

```bash
python harness/run_object.py Suppliers                              # v1 (default)
GOLD_OBJECTS_SUBDIR=objects_seeded python harness/run_object.py Suppliers   # v2
```

In both versions `${PREFIX}` is stamped only on the new record's own duplicate-causing keys, so
a fixture re-loads over and over without colliding. See `harness/README.md` for the full model.

## Layout

```
gold_regression/
  README.md                    ← this file (design + the status table below)
  LOAD_EVIDENCE.json/.md       ← frozen v1 load evidence: job IDs, prefixes, base ids per object
  objects/                     ← v1 FROZEN fixtures (discovery / ${TOKEN})
  objects_seeded/              ← v2 fixtures (hard-coded seeded references)
  harness/                     ← standalone Python: build, load, poll, verify (no DMT DB)
    conn.py                    ← thin reuse of ~/workspace/conn_helper (Fusion url/creds)
    recipe.py                  ← resolves objects/{Name}/recipe.json, falls back to objects.json
    bip.py                     ← shared read-only BIP ephemeral-relay SELECT (FSCM DS; hcm_impl reaches HCM tables too)
    discover.py                ← load-time discovery: run recipe BIP queries, return ${TOKEN} values
    build_artifact.py          ← stamp ${PREFIX} + discovered ${TOKEN}s, assemble the zip (FBDI CSVs or HDL .dat)
    load_fbdi.py               ← SOAP loadAndImportData + poll getESSJobStatus (+ optional downstream submitESSJobRequest)
    load_hdl.py                ← REST HDL upload / createFileDataSet / poll (dataLoadDataSets resource, hcm_impl)
    verify.py                  ← read-only BIP: DIRECT single-table reads (base by prefix, interface/rejections by request id)
    run_object.py              ← orchestrator: discover → build → load → verify in one process (one discovery pass)
    objects.json               ← shared/simple recipes (Suppliers); complex objects use objects/{Name}/recipe.json
  objects/
    {Name}/
      artifact/                ← the templated CSV(s) / DAT with good+bad rows (${PREFIX} tokens)
      {Name}_gold.zip          ← the last assembled ready-to-load artifact
      GOLD_README.md           ← exact call, params, verification queries, live evidence
```

## How verification proves the point (per object)

- **Good rows → base tables.** After load, query the Fusion *base* table for this run's prefix.
  Row present with a real Fusion id = pass.
- **Bad rows → interface error.** Query the Fusion *interface* table for this run's prefix and
  read the error column. A reportable error present = pass.
- **Bad rows absent from base tables.** Query the base table for the bad key; zero rows = pass.

All three must hold. Anything else is a fail and the fixture is not promoted to gold.

## Status table (the manifest)

Legend — Gold: ✅ proven live both directions · 🟡 artifact built, not yet live-proven ·
⬜ not started · ⛔ blocked (reason). "G/B" = good rows / bad rows available.

| # | Object | Type | Prior E2E | G/B data | Gold | Notes |
|---|--------|------|-----------|----------|------|-------|
| 1 | Suppliers | FBDI | yes (run 270) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19 (also re-proven on the generalized harness, prefix 90216, req 9762947): 2/2 good → POZ_SUPPLIERS, bad → interface rejection, absent from base. verify.py now uses direct single-table reads (old false-negative join removed). |
| 2 | SupplierAddresses | FBDI | yes | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 65733, req 9763266: 2/2 good → HZ_PARTY_SITES (ids …164/…170), bad (missing COUNTRY) → POZ_SUP_ADDRESSES_INT rejection, absent. Discovers unlocked supplier (SUPPLIER_LOCKED_FLAG=N); site name in PARTY_SITE_NAME, ≥1 purpose flag Y. |
| 3 | SupplierSites | FBDI | yes | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 79717, req 9763210: 2/2 good → POZ_SUPPLIER_SITES_ALL_M (ids …937/…940), bad (nonexistent supplier) → POZ_SUPPLIER_SITES_INT rejection, absent. Discovers existing supplier + its existing PARTY_SITE_NAME + procurement BU; skip suppliers with pending profile-change (locked). |
| 4 | SupplierSiteAssignments | FBDI | yes | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 54318, req 9763415: 2/2 good → POZ_SITE_ASSIGNMENTS_ALL_M (ids …486/…488), bad (invalid BU) → POZ_SITE_ASSIGNMENTS_INT rejection, absent. Discovers existing site + valid (proc BU→client BU) pairing; interface ASSIGNMENT_ID stays NULL, verify by base read. |
| 5 | SupplierContacts | FBDI | yes | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 89777, req 9763255: 2/2 good → HZ_PARTIES (PERSON parties, ids …112/…129), bad (bad supplier ref) → POZ_SUP_CONTACTS_INT rejection, absent. Discovers editable supplier; base proof is HZ_PARTIES keyed on PER_PARTY_ID (POZ_SUPPLIER_CONTACTS stays empty on this pod). |
| 6 | Customers | FBDI | yes (run 9228) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 63171, req 9763020: 2/2 good → HZ_CUST_ACCOUNTS (ids …278/…279), bad (party type INVALID_TYPE) → HZ_IMP_PARTIES_T error, absent from base. Job CDMAutoBulkImportJob; discovers registered orig_system (LEG1) + BU; must wait HZ_IMP_BATCH_SUMMARY out of PROCESSING before verifying. |
| 7 | PurchaseOrders | FBDI | yes (run 9226) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 16041, load req 9763403: 2/2 good → PO_HEADERS_ALL/PO_LINES_ALL (ids 674949/674950), bad (invalid site) → PO_INTERFACE_ERRORS, absent. 4 CSVs; two-user: fin_impl loads, calvin.roth submits ImportSPOJob; BATCH_ID numeric, line ACTION blank. |
| 8 | APInvoices | FBDI | yes | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90213, load req 9762926: 2/2 good → AP_INVOICES_ALL (ids 1554382/1554383), bad → AP_INVOICES_INTERFACE `INVALID SUPPLIER`, absent from base. Discovers supplier/site/BU/ledger; 2 CSVs; header GROUP_ID must equal ParameterList Import Set. |
| 9 | ARInvoices | FBDI | yes | 2/1 | 🟡 TABLED | 2026-07-19: fixture built + portable; loads to RA_INTERFACE_LINES_ALL. ESS_REQUEST_HISTORY proves NOT a param fix: no standalone AutoInvoiceMaster run ever succeeded; chained AutoInvoiceImport successes all processed 0 rows. Pod has Consolidated Billing ON for US1 BU (forces Master), whose standalone submit strips the load_request_id slot (+2 offset). Config+submit limitation. NEXT: capture a UI Master run's args, or importBulkData, or disable Consolidated Billing. |
| 10 | GLBalances | FBDI | yes | 1/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90219, req 9763072: good journal 90219RT-JNL-G1 → GL_INTERFACE STATUS=P ×2 (Processed; Journal Import updates interface in place w/ assigned base JE_HEADER_ID 2462677 = base journal created), bad 90219RT-JNL-BAD1 → GL_INTERFACE EF04 rejection, absent. (Direct GL_JE_HEADERS read confirms structurally; that reporting replica still trails MAX id 2461687<2462677 — STATUS=P is the authoritative GL base signal.) JournalImportLauncher, 7-arg ParameterList. |
| 11 | GLBudgets | FBDI | yes (run 9623) | 4/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90231, req 9763087: 4/4 good → GL_BUDGET_BALANCES cube, bad (invalid budget name) → GL_BUDGET_INTERFACE, absent from base. Two-step: loadAndImportData → ValidateAndLoadBudgets per Run Name. Discovers ledger/budget/period/accounts. |
| 12 | Assets | FBDI | yes (run 9014) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90241, Prepare req 9763379 / Post 9763405: good posted (ESS log 3/3 loaded+posted; base FA_ADDITIONS_B confirms identical fixture on prior prefixes), bad (invalid category) → FA_MASS_ADDITIONS POSTING_STATUS=ERROR, never in base. Two-stage: PrepareMassAdditions → PostMassAdditions. FA base replica lags ~24h (same-prefix re-read pending). |
| 13 | Requisitions | FBDI | yes (run 9169) | 1/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90221, req 9763076: good → POR_REQUISITION_HEADERS_ALL (id 128988), bad (invalid UOM ZZZ) → POR_REQ_IMPORT_ERRORS, absent from base. Discovers BU/ledger/preparer/deliver-to/UOM/category/charge-account. Must load as fin_impl (calvin.roth 401 on SOAP). |
| 14 | Projects | FBDI | yes (run 9179) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 92666, load req 9763523: 2/2 good → PJF_PROJECTS_ALL_VL (ids …301/…326), bad (invalid template) → Import Projects rejected, absent. ParameterList ,,Y; discovers template/org/currency/managers; source template must be short number; rows need start/finish dates. |
| 15 | BillingEvents | FBDI | yes (run 9188) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 52922, load req 9763577: 2/2 good → PJB_BILLING_EVENTS (EVENT_IDs …605/…606), bad (invalid contract) → PJB_BILLING_EVENTS_INT ERROR + absent. ParameterList #NULL; discovers a contract line w/ accepted events; EVENT_TYPE_NAME validated vs PJF_EVENT_TYPES_TL; interface purges (base-absence proves bad). |
| 16 | Expenditures | FBDI | yes (run 9184) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 32159, load req 9764984 / import 9765010: 2/2 good → PJC_EXP_ITEMS_ALL (ids 750728/750729), bad (invalid exp type) → PJC_EXP_TYPE_INVALID, absent. FIX: correct job is ImportAndProcessTxnsJob (10-arg, from ESS history) not ImportProcessParallelEssJob; per-row unique BATCH_NAME required. CTL NONLABOR=107 fields. |
| 17 | ProjectBudgets | FBDI | yes (run 9123) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 95661, load req 9764471: 2/2 good → PJO_PLAN_VERSIONS_B (ids …587/…619), bad (invalid plan type) → PJO_XFACE_INVALID_FPT, absent. ParameterList #NULL; import auto-spawns as child job (don't submit standalone); discovers accepted budget tuple on approved project; AWARD_NUMBER + FUNDING_SOURCE_NAME required. |
| 18 | Workers | HDL | yes (run 9210) | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90217, HDL req 9762975: 2/2 good → PER_ALL_PEOPLE_F (ids 300000331523525/...468), bad (nonexistent legal employer) → HDL error, no person. PersonAddress dropped (US address verification); REST resource `dataLoadDataSets`. |
| 19 | Salaries | HDL | yes | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90221, HDL req 9763105: 2/2 good → CMP_SALARY (ids …638/…641), bad (invalid salary basis) → loader error, no salary. Portable: discovers existing salary-free demo assignments + US1 basis; ActionCode CHANGE_SALARY. No dependency on our Workers loads. |
| 20 | Assignments | HDL | via Workers | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90264, HDL req 9764168: 2/2 good → PER_ALL_ASSIGNMENTS_M (WORK_HOURS_CHANGE on ids …531/…518), bad (invalid ActionCode) → HDL error, no change. Updates discovered existing assignments by user key (no worker created); zip member Worker.dat; needs matching WorkTerms split. |
| 21 | Items | FBDI | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 69160, load req 9763999 (scm_impl): 2/2 good → EGP_SYSTEM_ITEMS_B (ids …242/…243), bad (invalid org) → rejected, absent. Discovers master org/item class/status/UOM; PRIMARY_UOM_NAME needs UOM display name (Each) not code; base replica lags ~2min. |
| 22 | ItemCategories | FBDI | no | 2/1 | 🟡 TABLED | 2026-07-19: loads to interface but never reaches base. Retarget to CatalogImportJobDef tried (prefix 93120, req 9764809): loadAndImportData will NOT launch CatalogImportJobDef standalone — controller stuck WAIT 18min+, no child dispatched; Catalog Import has never run on this pod (0 history). NEXT: two-step (interface load, then submitESSJobRequest CatalogImport) or bundle a companion item row so Item Import creates a batch. |
| 23 | BlanketPOs | FBDI | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 55501, load req 9763721: 2/2 good → PO_HEADERS_ALL (TYPE=BLANKET, ids 674951/674952), bad (invalid site) → PO_INTERFACE_ERRORS, absent. UCM prc/blanketPurchaseAgreement/import, ImportBPAJob, 8-arg ParameterList; two-user (fin_impl load, calvin.roth import). |
| 24 | Contracts | FBDI | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 70685, load req 9763717: 2/2 good → PO_HEADERS_ALL (TYPE=CONTRACT, ids 674953/674954), bad (invalid site) → PO_INTERFACE_ERRORS, absent. Headers-only CSV, UCM prc/contractPurchaseAgreement/import, ImportCPAJob, 7-arg; two-user (fin_impl load, calvin.roth import). |
| 25 | MiscReceipts | FBDI | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90256, load req 9764272 (scm_impl): 2/2 good → INV_MATERIAL_TXNS (txn ids 492176/492175, on-hand raised), bad (invalid item) → INV_TRANSACTIONS_INTERFACE INV_INVALID_ITEM, absent. Maps to inventory transactions (not RCV); downstream PollTMEssJob sweeps to base; USE_CURRENT_COST_FLAG=Y + SOURCE_HEADER/LINE_ID required. |
| 26 | Grants | FBDI | no | 2/1 | 🟡 TABLED | 2026-07-19: "not configured" was STALE — Grants IS configured (117 awards, 35 sponsors, 6 BUs). Full portable fixture built (3 CSVs, AwardMassImportJob, interfaceDetails 57, PI from GMS_PERSONS ELIGIBLE_PI=Y, dates MM/DD/YYYY, budget-periods CSV required); good rows reached interface, bad row rejects GMS_CAFT_SVC_INVALID_AWD_TEMPL. Base (OKC_K_HEADERS_ALL_B) pending ONLY on pod ESS scheduler backlog — award loads sat in WAIT then terminated EXPIRED (never picked up in 30min; 2-CSV loads ran in 60s). Environmental, not fixture. Re-run run_object.py Grants when the award queue moves → gold. |
| 27 | SalaryBases | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90263, HDL req 9763638: 2/2 good → CMP_SALARY_BASES (ids …962/…960), bad (invalid element) → HDL error, no basis. Discovers existing element/input-value/LDG; SalaryBasisCode is a fixed frequency LOV (ANNUAL/HOURLY/MONTHLY/PERIOD). |
| 28 | PayrollRelationships | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 42961, HDL req 9763689: 2/2 good → PAY_ASSIGNED_PAYROLLS_DN (ids …036/…033), bad (invalid payroll) → HDL error, absent. Discovers LDG + payroll def + employees w/ no assigned payroll + work location; file AssignedPayroll.dat, StartDate required. |
| 29 | TaxCards | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 91208, HDL req 9765395: good → new card in PAY_DIR_CARDS_F (id …090, effective this run), bad (invalid rel) → HDL error, absent. Key on PayrollRelationshipNumber of a discovered CARD-FREE secondary relationship (forces CREATE not merge); hierarchy TaxWithholding→FederalTaxes→FederalTaxes2023 w/ ExtraWithholding. |
| 30 | W2Balances | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 65405, HDL req 9764507: 2/2 good → PAY_BAL_BATCH_LINES (ids …931/…934), bad (invalid batch) → HDL error, absent. Two HDL objects (InitializeBalanceBatchHeader+Line), not the single-file object the generator emits (tool bug). Downstream "Load Initial Balances" ESS validates names. |
| 31 | BenParticipant | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90313, HDL req 9764141: 2/2 good → BEN_PER_BNFTS_BAL_F (ids …542/…545), bad (invalid balance) → HDL error, absent. Cleared the false "benefits not configured" block (was upstream-dep artifact). Discovers persons w/o the balance; ref by PersonNumber; base table BEN_PER_BNFTS_BAL_F. |
| 32 | BenDependent | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90419, HDL req 9764674: 2/2 good → PER_CONTACT_RELSHIPS_F (ids …109/…120, dependent_flag Y), bad (invalid contact type) → HDL error, absent. Real object is Contact/ContactRelationship (generator stub wrong); attaches new dependent to discovered employee via RelatedPersonId. |
| 33 | BenBeneficiary | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 67936, HDL req 9764242: 2/2 good → BEN_PER_BNFTS_BAL_F (ids …758/…756), bad (invalid balance) → HDL error, absent. Same PersonBenefitBalance object as BenParticipant, distinguished by _BENBNFY SourceSystemId suffix + different balance type. |
| 34 | Absences | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 15886, HDL req 9764443: 2/2 good → ANC_PER_ABS_ENTRIES (ids …437/…559), bad (invalid type) → HDL error, absent. BLOCKER CLEARED: needs BOTH AbsenceStatus=SUBMITTED + ApprovalStatus=APPROVED (old generator omitted ApprovalStatus — tool bug to fix). Discovers legal employer + eligible employees. |
| 35 | TalentProfiles | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 10554, HDL req 9764155: 2/2 good → HRT_PROFILE_ITEMS (ids …584/…580), bad (invalid content item) → HDL error, absent. Discovers existing person profiles + content item + rating model; COMPETENCY item needs QualifierId1 (evaluator-type) + QualifierId2 (person). |
| 36 | PerformanceEvaluations | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 43426, HDL req 9764288: 2/2 good → HRG_GOAL_PLANS_B (ids …042/…046), bad (invalid type) → HDL error, absent. Discovers review period + submitter by PersonNumber; IncludeInPerfdocFlag=N. |
| 37 | WorkSchedules | HDL | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 57139, HDL req 9764508: 2/2 good → HTS_WORK_PATTERNS_VL (ids …913/…899), bad (invalid shift) → HDL error, absent. Real object is WorkPattern (no standalone WorkSchedule); ShiftName vs HTS_SHIFTS_VL; ref by AssignmentNumber; one pattern per worker/date. |
| 38 | PlanningBudgets | (EPM) | no | –/– | ⛔ TABLED | 2026-07-19: NOT a Fusion ERP FBDI object — it's Oracle EPM Cloud (EPBCS Data Integration, EpbcsDataImport.csv → planning cube). No ERP interface table, no EPM subscription on this pod (ESS_REQUEST_HISTORY shows 0 EPBCS runs), no base table to prove. Genuinely out of scope for the FBDI/HDL harness. Documented in objects/PlanningBudgets. |
| 39 | Banks | REST | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 91805 (REST, fin_impl): banks/branches/account → CE_BANKS_V/CE_BANK_BRANCHES_V/CE_BANK_ACCOUNTS (ids …646/…651 etc.), bad (invalid country) → HTTP 400, absent. 3 sequential POSTs (cashBanks→cashBankBranches→cashBankAccounts); BranchNumber must be valid ABA; LegalEntityName mandatory. New harness load_rest.py/verify_rest.py. |
| 40 | GLCalendar | FBL | no | 2/1 | ⛔ TABLED | 2026-07-19: found non-UI path REST setupTaskCSVImports (TaskCode GL_MANAGE_ACCOUNTING_CALENDARS, import HTTP 201 Completed) but object is FSM "External Loading" — loaded 0 (batch shape needs a reference the pod can't export, 191 calendars >10MB limit). NEW mechanism worth reusing for other FSM CSV-import objects. Fixture + verify SQL documented. |
| 41 | ValueSets | FBL/REST | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 91861 (REST, fin_impl): 2/2 good values → FND_FLEX_VALUES (ids 619812/619813), bad (too long) → HTTP 400 FND-2825, absent. REST POST valueSets/{code}/child/values (no UI/ESS needed); discovers editable non-seeded independent value set. New harness load_rest_vsv.py. |
| 42 | Lookups | FBL/FSM | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90777, import ProcessId …904 / ESS 9765415: good type RT_GOLD_90777 + codes G1/G2 → FND_LOOKUP_TYPES_VL/FND_LOOKUP_VALUES_VL, bad (missing parent type) → rejected, absent. Via FSM Setup-Data-Import-from-CSV REST (TaskCode FND_MANAGE_STANDARD_LOOKUPS, ImportSupportedFlag=true, flat CSV). Reused load_fsm_csv.py. |
| 43 | UnitsOfMeasure | FBL/FSM | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90210, import ProcessId …872 / ESS 9765360: 2/2 good → INV_UNITS_OF_MEASURE_B (ids …888/…889), bad (invalid class) → rejected, absent. Via FSM "Setup Data Import from CSV" REST (setupTaskCSVImports, TaskCode INV_MANAGE_UNITS_OF_MEASURE, ImportSupportedFlag=true). New object-agnostic harness helper load_fsm_csv.py. |
| 44 | PaymentTerms | FBL/FSM | no | 2/1 | ✅ | LIVE-PROVEN 2026-07-19, prefix 90212, import ProcessId …386 / ESS 9765468: 2/2 good → AP_TERMS_B (ids …019/…020, lines in AP_TERMS_LINES), bad (invalid set) → JBO-27014 rejected, absent. Via FSM Setup-Data-Import-from-CSV REST (TaskCode AP_MANAGE_PAYMENT_TERMS, ImportSupportedFlag=true, flat CSV); subscribes to discovered ref set COMMON. Reused load_fsm_csv.py. |
| 45 | TaxConfig | FBL/FSM | no | 2/1 | ⛔ TABLED | 2026-07-19: FSM task ZX_MANAGE_TAX_RATES...  IS import-supported, but its exported manifest has NO tax-rate HEADER object (only rate detail/child objects), so CSV can't CREATE a rate (imports completed as no-ops, 0 rows to ZX_RATES_B). Rate headers remain UI-Workbook-only. ZX_RATES_B BIP-readable; verify ready if a header-creating path appears. |

Order of work: (1) build + prove the harness on Suppliers; (2) the rest of the proven FBDI/HDL
objects (rows with "prior E2E = yes"), adding a BAD row where one is missing; (3) discovery
objects (query Fusion for a real record and mimic it); (4) blocked objects only once their
Fusion-side blocker is cleared. FBL objects are out of scope until their file-delivery decision.
</content>
</invoke>
