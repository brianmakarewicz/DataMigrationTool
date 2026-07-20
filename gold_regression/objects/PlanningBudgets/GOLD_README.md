# PlanningBudgets — gold regression fixture

## Verdict: TABLED — EPM-only, no Fusion ERP FBDI load path on this pod

PlanningBudgets is **not** a Fusion ERP FBDI object. It is an **Oracle EPM Cloud
(Enterprise Planning and Budgeting, EPBCS/Planning) integration**. It loads a
planning cube in a separate EPM Cloud pod through **EPM Data Management /
Data Integration**, not through the Fusion ERP Integration SOAP service. On this
Fusion ERP demo instance there is no EPM subscription, no import ESS job, no UCM
document account, and no relational base table to prove to. It therefore cannot
be live-proven under the gold-regression harness, which loads FBDI zips via
`ErpIntegrationService.loadAndImportData` and verifies against Fusion ERP base
tables.

This is a genuine "mechanism not available," documented with evidence below —
not a build failure.

## Step 0 — mechanism identification (what PlanningBudgets actually is)

The generator names the mechanism directly. `DMT_PLAN_BUDGET_FBDI_GEN_PKG`
(`db/packages/dmt_plan_budget_fbdi_gen_pkg.pkb.sql`) builds a single-member zip
whose CSV is **`EpbcsDataImport.csv`** with these columns:

```
SCENARIO, VERSION, ENTITY, ACCOUNT, PERIOD, AMOUNT, CURRENCY,
DATA_LOAD_DEFINITION_NAME, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5
```

Those are **EPM Planning dimension members** (Scenario, Version, Entity, Account,
Period) plus a **Data Load Definition name** — the shape of an Oracle EPM Cloud
Data Management / Data Integration load file. A Fusion ERP FBDI interface CSV
never looks like this (no dimension members, no data-load-definition column; it
carries interface-table columns keyed to a `*_INTERFACE` table). "EPBCS" =
Enterprise Planning and Budgeting Cloud Service, an EPM Cloud product distinct
from Fusion ERP General Ledger.

**Correct load channel (for a pod that has EPM):** an EPM **Data Load Definition**
run inside Data Integration (Import → Validate → Load into the planning cube), or
the EPM Cloud REST **Import Data** job. Auth and endpoint are the **EPM pod**, not
the Fusion ERP `fscmService/ErpIntegrationService`.

### Not to be confused with the ERP budget objects

| Object | Fusion product | UCM account | ESS import job | Base/interface | Gold status |
|---|---|---|---|---|---|
| **GLBudgets** | ERP General Ledger | `fin/budgetBalance/import` | `...ledgerDefinitions,ValidateAndLoadBudgets` | `GL_BUDGET_BALANCES` / `GL_BUDGET_INTERFACE` | ✅ proven |
| **ProjectBudgets** | ERP Project Control | `prj/projectControl/import` | `...budgetsAndForecasts,ImportBudgetsInterfaceData` | `PjoPlanVersionsXface.csv` interface | ⬜ needs bad row |
| **PlanningBudgets** | **EPM Cloud (EPBCS/Planning)** | none (EPM Data Management) | none on ERP pod | planning cube (EPM pod) | ⛔ **TABLED (EPM-only)** |

GLBudgets and ProjectBudgets are real Fusion ERP FBDI objects with their own
interface-options rows. PlanningBudgets is the EPM one and has no ERP row.

## Evidence (all read-only)

1. **No interface-options row.** `db/seed/dmt_erp_interface_options_tbl.sql` has
   no row for PlanningBudgets / EPBCS (grep for `PlanningBudget|EpbcsData|epbcs`
   returns nothing). The budget rows that do exist are all ERP GL/Project/BC
   (ids 17, 39, 51, 78, 79, 153).
2. **No FBDI metadata row.** `db/seed/dmt_upload_fbdi_metadata.sql` maps no
   `object_code` to `EpbcsDataImport.csv`.
3. **Explicitly out of scope in the catalog.** `db/seed/dmt_cemli_catalog_tbl.sql`
   line 7: *"PlanningBudgets is out of scope (2026-07-07) and is not seeded."*
4. **Object README already says DORMANT.** `objects/PlanningBudgets/README.md`:
   *"DORMANT (EPBCS table not accessible on demo instance)."*
5. **Read-only BIP probe of this pod (2026-07-19).**
   - `ESS_REQUEST_HISTORY`: **0** rows whose `name`/`definition` mentions `EPBCS`
     or `PLANNING BUDGET`. (The 124 budget-named runs are all GL/Project ERP-FBDI
     budget jobs.) No EPM/Planning import job has ever run here.
   - `GL_BUDGET_INTERFACE` is reachable — this is a Fusion **ERP** pod, with no
     EPM/EPBCS registration.
6. **Web confirmation.** Oracle EPM budget/planning loads go through EPM Data
   Management / Data Integration (the FDMEE successor) in the EPM Cloud pod; ERP
   FBDI is for ERP/SCM objects only. Sources:
   - https://www.ateam-oracle.com/data-import-options-and-guidelines-for-fusion-applications-suite
   - https://docs.oracle.com/en/cloud/saas/enterprise-performance-management-common/erpia/fusion_process_enhanced_102x4d7a440a.html
   - https://oraclebarbie.com/2023/05/17/oracle-epm-cloud-data-integration-replacing-data-management-what-you-need-to-know/

## What a load WOULD require (for a future EPM-enabled pod)

- An Oracle EPM Cloud (Planning/EPBCS) subscription reachable with credentials.
- A **Data Load Definition** in EPM Data Integration matching the
  `DATA_LOAD_DEFINITION_NAME` column, mapping the CSV dimension members to the
  target planning cube.
- Load via the EPM **Import Data** job (REST) or a Data Integration run inside
  the EPM pod — a completely different endpoint, auth, and orchestration from the
  ERP harness. The harness would need an EPM loader (not `load_fbdi.py`).
- Verification would read the **planning cube** (via an EPM data export /
  Smart View / EPM REST export), since there is no Fusion ERP relational base
  table for planning-cube cells.

None of that exists on this pod, so there is nothing to build or prove here now.

## Revisit trigger

Promote out of TABLED only when a target pod subscribes to Oracle EPM Cloud
(Planning/EPBCS) and exposes a Data Load Definition plus a readable planning
cube. At that point build an EPM loader + cube-export verify; until then this is
correctly ⛔ (EPM-only, not an ERP FBDI object).

## Deliverables in this folder

- `recipe.json` — `type: "TABLED"` with the full mechanism finding + evidence
  (machine-readable companion to this file).
- No `PlanningBudgets_gold.zip` / no `artifact/` CSV: deliberately not built,
  because the `EpbcsDataImport.csv` format has no valid load target on this pod
  and building a zip that cannot be loaded would be offline-only work, which the
  gold rules forbid presenting as progress.

## Live evidence

**2026-07-19 — TABLED (no live load attempted; no valid ERP mechanism exists).**
Prefix: n/a. Request ids: n/a. The read-only pod probe (item 5 above) is the
live evidence that no EPBCS/Planning import path exists on this Fusion ERP demo
instance.
