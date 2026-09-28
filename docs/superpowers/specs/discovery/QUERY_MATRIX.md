# Post-Run Comparison — Proven Query Matrix

Date: 2026-09-27
Basis: RUN_ID **132** on local Docker `dmt2-local` (scenario RegressionTest26092311, prefix 93212).
Method: read-only. STG/TFM from the Docker DMT DB; Fusion successes queried **live** (demo password rotated first). One findings file per object in this folder holds the exact runnable SQL.

## Headline

All **23 objects** in run 132 were reconciled by hand. Every object's accounting ties out:
`Fusion successes + TFM errors = STG total` (on count, and on money where money round-trips).
Nothing was fabricated — every FAILED row was confirmed to carry a real Fusion error, and every
LOADED count was confirmed against a Fusion base table.

- **19 objects** are fully proven with a **production-valid key** and a balanced result. (This
  includes the 4 below that were resolved in the follow-up pass — see "Follow-up resolutions".)
- **4 objects** had **0 loaded rows** this run (env/functional-blocked). Their STG/TFM side ties
  out and their Fusion success query is *designed and documented*, to be confirmed on a run where
  they do load.
- **0 objects** remain on the prefix or a time-window. The 4 that were (Assets, Projects,
  Expenditures, GL Budgets) are now on production-valid keys.

## Universal patterns confirmed (these become framework rules)

1. **STG has no RUN_ID and holds duplicate seed rows.** The run's record set is always the object's
   **TFM rows for the run**; scope STG *through the TFM row's `STG_SEQUENCE_ID` pointer*, never by a
   business key or the prefix. Balancing from a raw STG business-key join double-counts (seen on
   Requisitions, Blanket POs, Expenditures).
2. **The Fusion success query is per-object** — different base table, key, grain, and amount. The
   uniform *output* shape (from the spec) still holds; only the SQL underneath differs.
3. **A "success" is object-specific, not "row present."** GL Balances = a *postable/balanced*
   journal; Assets = *posted*; Project Budgets = a real budget version *excluding* the auto-created
   "Project Plan" workplan versions. Each object's query encodes its own success test.
4. **One object can have several load/import ESS ids in one run** (Requisitions had two). The
   load-id key path must take a **list** of request ids per object per run, not one.
5. **Money does not always round-trip to Fusion.** Some objects have no money in the base table
   (Blanket POs, Contracts) or Fusion recomputes it (Expenditures). The report reconciles money
   only where Fusion carries it; elsewhere it is **count-only** on the Fusion side.

## Key paths seen (in order of production-validity)

- **Import/Load ESS request id** — filter the Fusion base/interface on the request id from
  `DMT_WORK_QUEUE_TBL` (`IMPORT_ESS_JOB_ID` or `LOAD_ESS_JOB_ID`), joined by RUN_ID + CEMLI_CODE.
  Used by PO, AP, all 5 Suppliers, Blanket POs, Contracts. **Prod-valid.**
- **Stamped reference that round-trips** — a value we write that lands on the Fusion row: GL
  `GROUP_ID = RUN_ID` on `gl_je_batches`; Billing Events `SOURCEREF`; Requisitions interface-line
  key (`132_RQLN_…`); HCM `HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID`; Customers orig-system
  reference. **Prod-valid.**
- **Captured Fusion id** — the `FUSION_*_ID` DMT already stamped on each LOADED row; re-query the
  base table for those ids. Always available for loaded rows. **Prod-valid fallback.**
- **Time window** — `LAST_UPDATE_DATE >= job start` (GL Budgets only, because a budget cell carries
  no request id). **Weak — replace with captured code-combination ids.**
- **Prefix** — `… LIKE '93212%'`. **Forbidden (not production-valid).** Currently the only working
  path for Assets, Projects, Expenditures — must be replaced.

## The matrix

Verdict legend: **OK** = proven, prod-valid key, balanced · **0-LOAD** = accounted, Fusion query
designed, not confirmable this run · **KEY-FIX** = balances today only via prefix/time-window,
needs a prod-valid key before build.

| # | Object | Fusion base (success) | Key path | Money column | Fusion money? | Balance (run 132) | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | Suppliers | POZ_SUPPLIERS (vendor_id) | Load req id 10023694 | — | n/a | 2+1=3 | OK |
| 2 | SupplierAddresses | HZ_PARTY_SITES (party_site_id) | Load req id 10023955 | — | n/a | 2+1=3 | OK |
| 3 | SupplierSites | POZ_SUPPLIER_SITES_ALL_M | Load req id 10024125 | — | n/a | 2+1=3 | OK |
| 4 | SupplierSiteAssignments | POZ_SITE_ASSIGNMENTS_ALL_M | Load req id 10024145 | — | n/a | 2+1=3 | OK |
| 5 | SupplierContacts | HZ_PARTIES (per_party_id) | Load req id 10024164 | — | n/a | 2+1=3 | OK |
| 6 | PurchaseOrders | PO_HEADERS_ALL (STANDARD) | Import req id 10024267 | qty×unit_price (lines) | yes | 2+1=3 / 2250+50=2300 | OK |
| 7 | BlanketPOs | PO_HEADERS_ALL (BLANKET) | Import req id 10024172 | line amount (DMT only) | **no** | count 1+1=2 | OK (count) |
| 8 | Contracts | PO_HEADERS_ALL (CONTRACT) | Import req id 10024188 | none | n/a | count 1+1=2 | OK |
| 9 | APInvoices | AP_INVOICES_ALL | Import req id 10024200 | INVOICE_AMOUNT | yes | 2+2=4 / 4250+5000=9250 | OK |
| 10 | Customers | HZ_CUST_ACCOUNTS | orig-sys ref / captured id | — | n/a | 2+2=4 | OK |
| 11 | ARInvoices | RA_CUSTOMER_TRX_LINES_ALL | *designed* (load req / captured) | line AMOUNT | (n/c) | 0+3=3, **0 loaded** | 0-LOAD |
| 12 | GLBalances | GL_JE_LINES (postable) | GROUP_ID=RUN_ID (gl_je_batches) | entered_dr / entered_cr | yes | 2+1=3 / dr 14999.99, cr 5000 | OK |
| 13 | GLBudgets | GL_BUDGET_BALANCES | **time window + CCID** | BUDGET_AMOUNT | yes | 2+1=3 / 2000+500=2500 | KEY-FIX |
| 14 | Projects | PJF_PROJECTS_ALL_VL | **prefix on SEGMENT1** | none | n/a | 2+1=3 | KEY-FIX |
| 15 | ProjectBudgets | PJO budget versions (excl. Project Plan) | *designed* | TOTAL_TC_RAW_COST | (n/c) | 0+3=3, **0 loaded** | 0-LOAD |
| 16 | Expenditures | PJC_EXP_ITEMS_ALL | **prefix on ORIG_TRANSACTION_REFERENCE** | recomputed → count only | **no** | count 2+6=8 | KEY-FIX |
| 17 | BillingEvents | PJB_BILLING_EVENTS | SOURCEREF (round-trips) | BILL_TRNS_AMOUNT | yes | 2+1=3 / 2+1000=1002 | OK |
| 18 | Grants | GMS award (DC_REQUEST_ID) | *designed* 10023979 | none | n/a | 0+3=3, **0 loaded** | 0-LOAD |
| 19 | Assets | FA_ADDITIONS_B / FA_BOOKS | **prefix on ASSET_NUMBER** | COST (book table) | yes | 2+1=3 / 155000+1000=156000 | KEY-FIX |
| 20 | Requisitions | POR_REQUISITION_HEADERS_ALL | captured id / interface-line key | qty×unit_price | yes | 2+3=5 / 490+700=1190 | OK |
| 21 | Workers | PER_ALL_PEOPLE_F | key map source-system id | — | n/a | 1+1=2 | OK |
| 22 | Salaries | CMP_SALARY | key map source-system id | SALARY_AMOUNT | yes | 1+1=2 / 75000+80000=155000 | OK |
| 23 | TalentProfiles | HRT_PROFILE_ITEMS | *designed* (key map) | — | n/a | 0+2=2, **0 loaded** | 0-LOAD |

## Follow-up resolutions (2026-09-27)

Decision taken: **find a batch id first**; use the captured Fusion id only where a batch id
genuinely does not exist. Result:

| Object | Was | Now (production key) | Money |
|---|---|---|---|
| Assets | prefix on ASSET_NUMBER | **batch id** — `FA_MASS_ADDITIONS.LOAD_REQUEST_ID = LOAD_ESS_JOB_ID`, POSTED, join to FA_BOOKS | COST, Fusion=155,000 ✓ |
| Expenditures | prefix on ORIG_TRANSACTION_REFERENCE | **batch id** — `PJC_EXP_ITEMS_ALL.REQUEST_ID = IMPORT_ESS_JOB_ID` | `DENOM_RAW_COST` = 3,840 (Fusion recomputes qty×rate; the 4,000→3,840 gap is a real variance to show) |
| Projects | prefix on SEGMENT1 | **captured id** — `PROJECT_ID IN (captured FUSION_PROJECT_ID)`; proven no batch id round-trips (base REQUEST_ID null, interface purged, no source ref) | none (count-only) |
| GL Budgets | time window + CCID | **captured id** — code-combination ids + budget name (+ period/ledger/currency for hardening); proven no batch id survives onto a loaded cell | BUDGET_AMOUNT, Fusion=2,000 ✓ |

Money column resolutions:

- **Expenditures** — `DENOM_RAW_COST` (Fusion's recomputed value is the reported success amount).
- **Blanket POs** — no queryable Fusion amount as loaded: the line is created **quantity-based**,
  so Fusion drops the AMOUNT we send. Money stays DMT-side (TFM line = 50,000); Fusion proves the
  load by count. *Follow-up (data/generator, not recon): to reconcile blanket money, generate the
  BPA line as amount-based so Fusion persists AMOUNT.*
- **Contracts** — genuinely no money (header-only CPA, all four PO amount columns null). Count-only.

## Final state

- **Money reconciled from Fusion (9):** PO, AP Invoices, GL Balances, GL Budgets, Billing Events,
  Requisitions, Salaries, Assets, Expenditures.
- **Count-only (10):** Suppliers ×5, Customers, Projects, Workers, Contracts, plus 0-load
  Grants/Talent Profiles.
- **DMT-side money only, by generator design (1):** Blanket POs.
- **0-loaded, query designed for a future run (4):** AR Invoices, Project Budgets, Grants,
  Talent Profiles.

Amount columns (confirmed): PO & Requisitions = qty×unit_price; AP = invoice amount; GL Balances =
entered dr/cr; GL Budgets = budget amount; Billing Events = bill amount; Salaries = salary amount;
Assets = book cost; Expenditures = denom raw cost.

All 23 objects are ready to code: 19 with a proven production-valid key, 4 with a designed query
awaiting a run where they load.
