# Planning Budgets

## Status
DORMANT (EPBCS table not accessible on demo instance)

## Pipeline
- Module: Financials
- FBDI Template: TBD
- Interface Table: EPBCS planning table (not accessible)
- UCM Account: TBD
- ESS Job: TBD
- ParameterList: UNKNOWN
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Code References
- STG Table DDL: `schema/tables/152_dmt_plan_budget_stg_tbl.sql`
- TFM Table DDL: `schema/tables/153_dmt_plan_budget_tfm_tbl.sql`
- Validator: `packages/validators/dmt_plan_budget_validator_pkg.*`
- Transformer: `packages/transformers/dmt_plan_budget_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/planning/dmt_plan_budget_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_plan_budget_results_pkg.*`
- BIP Data Model/Report: `bip/PlanningBudgets/`

## Reference Files
None in this folder.

## Known Issues
- Intentionally dormant. EPBCS table not accessible on demo instance.

## History
- Marked DORMANT intentionally. Will revisit if EPBCS access becomes available.

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

**Scope note first:** Planning Budgets is **out of scope as a pipeline member**
(decided 2026-07-07) and is **DORMANT** -- the target EPBCS planning table is not
accessible on the demo instance, so it has never run end-to-end. It is NOT seeded
in `db/seed/dmt_cemli_catalog_tbl.sql` (no console tiles). It IS, however, fully
coded: a STG table, a TFM table, a generator (`DMT_PLAN_BUDGET_FBDI_GEN_PKG`), a
results package and a direct `RUN_PLAN_BUDGETS` entry path all exist. The audit
below records the table-vs-tab alignment of that dormant model so the rollout is
complete.

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab it
loads. Planning Budgets is modeled as ONE zip with a single CSV.

**The mapping (from the generator `DMT_PLAN_BUDGET_FBDI_GEN_PKG` `REGISTER_CSV`
call and the `FROM` table):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| EpbcsDataImport.csv | EPBCS planning table (NOT accessible on demo -- unconfirmed) | DMT_PLAN_BUDGET_STG_TBL | DMT_PLAN_BUDGET_TFM_TBL | NAME-SHORTENED / UNVERIFIED (dormant) |

**Why the verdict is qualified:** EPBCS (Enterprise Planning and Budgeting Cloud)
is a separate pod, not a Fusion FBDI interface table, so there is no Fusion
interface table to align against and the exact target could not be confirmed on the
demo instance. The DMT table name `PLAN_BUDGET` is a sensible shortening of
"Planning Budget". The single CSV is `EpbcsDataImport.csv`. Because the object has
never run, this row is recorded as UNVERIFIED rather than a firm ALIGNED/MISALIGNED
verdict -- an honest "not proven" status consistent with the object's DORMANT state.

**Findings:**
1. **NO spec-header fix needed.** The generator spec-header names the real CSV
   `EpbcsDataImport.csv`, matching the `REGISTER_CSV` call. Accurate.
2. **DOCUMENTED GAP / DORMANT:** the interface target cannot be verified until EPBCS
   access is available on an instance. No rename and no further modeling should be
   done under backlog #90 while the object is dormant. Revisit the verdict when the
   object is first run live.
3. **No STG/TFM fan-out.** One CSV, one STG, one TFM -- structurally consistent with
   the other single-tab Project-family objects.
