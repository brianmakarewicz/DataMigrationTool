# DMT2 Fix Plan — owner-decided, 2026-07-20

Single source of truth for the eight work items decided this session. Each is a short-lived
branch + PR through the automated reviewer. Coding-standard changes are **accepted** (owner-directed),
not RED/proposed.

Dependency order: 8, 5, 2 are independent and land first. 1 (foundation) next. 3, 4, 6 depend on
1's `WORK_QUEUE_ID`. 7 (cleanup) any time.

---

## 1. Work-queue-ID granularity (foundation)

**Coding standards (accepted):**
- The work queue item is the unit of processing. Data is transformed, generated, zipped, loaded,
  reconciled, and swept **per work queue item**.
- Every TFM table, every FBDI/CSV staging table, and every zip-level record carries a
  `WORK_QUEUE_ID` column, FK → `DMT_WORK_QUEUE_TBL`, **NOT NULL**, required on every record.
- Prefix is never a standalone/control/search value. It may only be a component of a business key
  (via `PREFIXED`). Batch/control identifiers are `NVL(source_value, WORK_QUEUE_ID)`, never prefix.

**Schema:**
- Add `WORK_QUEUE_ID` to every TFM + FBDI/CSV table (FK, NOT NULL).
- Add a parent-reference column (self-FK → `QUEUE_ID`) to `DMT_WORK_QUEUE_TBL` for spawned-child
  traceability.

**Code:**
- Generalize the existing Assets per-book split (currently `IF CEMLI_CODE='Assets'` in
  `dmt_queue_worker_pkg`) into a config-driven "spawn one child queue item **per partition key**"
  mechanism; partition column per object comes from `DMT_CEMLI_SPLIT_CFG`. Move Assets, Items, and
  Requisitions onto it.
- Stamp `WORK_QUEUE_ID` on every record when a child claims its partition at generation (parent
  transforms first; the stamp is set/updated at generation when the child id exists).
- Scope reconcile and `SWEEP_UNACCOUNTED` by `WORK_QUEUE_ID` — makes the multi-batch premature-sweep
  bug (Items batch 8102, Requisitions batch 7002) impossible by construction.
- Fix the Customer transform prefix-as-control: `NVL(TO_NUMBER(l_prefix), s.BATCH_ID)` →
  `NVL(s.BATCH_ID, WORK_QUEUE_ID)` (all tiers). Same for Items/Requisitions batch fallback
  (`p_run_id` → `WORK_QUEUE_ID`). Do NOT touch `PREFIXED(l_prefix, business_ref)` uses.

**Verify:** re-run **ALL mode** on the existing scenario; Items lot/serial + Requisitions batch 7002
reach base tables; no single-batch object regresses; `WORK_QUEUE_ID` NOT NULL holds across a full run.

**Backlog (separate task):** catalog any other standalone prefix-as-control/search usages.

---

## 2. Reconcile HTTP-failure retry (independent)

In `RECONCILE_ONE` (`dmt_queue_worker_pkg`), replace the blanket `WHEN OTHERS → FAILED` with a
code-based split:
- Transient transport failures (`ORA-29273` HTTP request failed, timeouts, connection resets):
  route the work item back to reconcile-pending; poller retries next tick, up to **3 attempts**.
- After 3 exhausted attempts, mark FAILED with an honest "could not verify after 3 attempts" — not
  "the data failed."
- Genuine BIP/SOAP application faults (bad report, bad SQL) still fail immediately.

Fixes MiscReceipts + Expenditures being failed by a single blip while their data actually loaded.
Pairs with #1: once each partition is its own queue item, the retry re-runs only that item.

---

## 3. Customer site-use reference synthesis (depends on #1)

When a source `ORIG_SYSTEM_REFERENCE` on an FBDI child record is null, synthesize a deterministic
one and persist it to the reference column at generation time, read by both generator and reconciler:

```sql
DMT_UTIL_PKG.PREFIXED(l_prefix,
    NVL(s.SITEUSE_ORIG_SYSTEM_REF, TO_CHAR(TFM_SEQUENCE_ID) || '-' || TO_CHAR(WORK_QUEUE_ID)))
```

- **FBDI only.** HDL `SourceSystemId` is out of scope (business-keyed, never null; inventing one
  breaks HDL updates).
- Generalize to any FBDI child tier with a null source reference. Audit other customer tiers +
  account-site-uses when implementing.
- Account-**site** failure (all 4) still needs its own live root-cause — follow-up.

---

## 4. HCM assignment number from source, no fabrication (depends on #1)

Root cause: worker STG has **no** assignment-number column, so the Worker generator fabricates the
number from `PERSON_NUMBER` (`pv(r.PERSON_NUMBER)`), while the Assignments object reads the real
source `ASSIGNMENT_NUMBER` — they collide on the shared `..._ASG` SourceSystemId, and person-number
keying caps a worker at one assignment.

**Fix:** the assignment number is a business key, provided by source, prefixed, referenced
consistently — like a supplier/PO number. Never generated.
- Key assignment identity by the source assignment number:
  `SourceSystemId = pv(ASSIGNMENT_NUMBER)||'_ASG'`, `AssignmentNumber = pv(ASSIGNMENT_NUMBER)`.
- Worker load builds its required new-hire assignment section from the assignment source rows
  (joined by person) using the real number — stops fabricating.
- Assignments object references the same key and MERGEs detail; does not restate a conflicting number.
- Downstream (Salary, PayrollRelationship, TalentProfile) resolve by the same prefixed key or fail
  honestly.
- Missing assignment number = validation failure ("assignment number required"), not fabrication.
- Supports multiple assignments per person by construction (each source row has its own number).

**Data-model change:** the worker/assignment source is one hierarchy; the Worker load needs the
assignment rows (with numbers). `ASSIGNMENT_NUMBER` becomes required, validated source data. Verify
the feed can carry it; flag seed/DDL changes.

---

## 5. AR AutoInvoice — submit the second job (independent, RESOLVED)

Root cause: AR is a **two-job** flow. Our load runs `AutoInvoiceImportEss` (stages
`RA_INTERFACE_LINES_ALL` only; parent reports SUCCEEDED even though nothing imports). We never submit
`AutoInvoiceMasterEss` ("Import Receivables Transactions Using AutoInvoice") that creates the
transactions — so good rows sit at `INTERFACE_STATUS = NULL`. Not a config or batch-source problem
("External Source" exists).

**Fix (proven contract from MCCS `RICE_005-XXCNV_AR_INVOICE_STG_PKG.sql`):** after the import job
SUCCEEDS, submit `AutoInvoiceMasterEss`:
- Job: `/oracle/apps/ess/financials/receivables/transactions/autoInvoices`, `AutoInvoiceMasterEss`
- ParameterList is **tilde-separated** with **`#NULL`** for empty slots (empty strings make Fusion
  collapse slots and misplace the trailing flag — the documented run-179 blocker):
  ```
  <distinct BU count> ~ #NULL ~ <trx_source_id> ~ <open-period date YYYY-MM-DD>
    ~ #NULL (×20) ~ N ~ Y ~
  ```
  - BU count = `COUNT(DISTINCT bu_name)` for the run's AR rows
  - `trx_source_id` = the batch source resolved to its numeric id (from the batch source name)
  - date must be in an open period (stamp current date; stale 2025/06/15 lands in a closed period)
- Then reconcile as today (lines move to processed / transactions appear in `RA_CUSTOMER_TRX_ALL`).

---

## 6. Expenditures NON_LABOR_RESOURCE columns (independent-ish)

The CTL is **fixed, not dynamic**. `NON_LABOR_RESOURCE` / `NON_LABOR_RESOURCE_ORGANIZATION` are
required for usage/non-labor items and not for labor (Oracle docs). PR #189's "remove the 4 columns"
is wrong — it re-triggers PR #173's real ORA-01400. The ORA-06502 at import is from emitting an
**empty string into the numeric** `NON_LABOR_RESOURCE_ID` / `NON_LABOR_RESOURCE_ORG_ID` columns for
no-resource NONLABOR rows.

**Fix:** keep the columns; emit a proper null (not `''`) for the numeric resource ids when a NONLABOR
row has no non-labor resource. Confirm exact column positions against `PJC_TXN_XFACE_ALL` and verify
with a live ALL-mode run (SQL*Loader accepts, no ORA-06502, rows post to base). Close PR #189.

**Fixture:** the good/bad rows are both NONLABOR-no-resource, but the proven reference is LABOR.
Align the fixture and add LABOR-path coverage.

---

## 7. Working-tree cleanup

Inventory the uncommitted local state; keep real work (gold_regression/, findings docs, README
updates, scripts/SQLQueries), discard junk (regression_*.json, docs archives, malformed
`objects/Customers/FBDI ` path). Commit the valuable, deliberately.

---

## 8. BIP paths to DMT2

Repoint `DMT_BIP_REPORT_TBL` (~10 objects) and any code literals from `/Custom/DMT/` to
`/Custom/DMT2/`. Deploy the BIP catalog objects into `/Custom/DMT2/`, dual-deploying in both folders
where anything still requires `/Custom/DMT/`.
