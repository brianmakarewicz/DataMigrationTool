# PerformanceEvaluations (PerfEvaluations)

## Status
Re-modelled 2026-09 to the correct Fusion HDL object **PerformanceDocument**
(discriminator `PerfDocComplete`). The prior build loaded `GoalPlan.dat`, which is
Goal Management — the wrong object for performance evaluations. Goal Management is a
separate future object, out of scope here.

Generator + reconciliation report re-pointed and deployed VALID; generate + .dat
inspection verified. Live submit-and-load is pending a test data run through the queue
(config prerequisites confirmed present — see below).

## Pipeline
- Module: HCM
- HDL File: **PerfDocComplete.dat**
- Discriminator (document): **PerfDocComplete**
- Discriminator (ratings/comments): **RatingsAndComments**
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: hcm_impl

## Business object (Oracle-documented)
`PerfDocComplete` is a natural-key object — no SourceSystem keys. It is keyed by
`AssignmentNumber` + `CustomaryName` (the document name). `RatingsAndComments` hangs
off the same document and carries section + overall ratings and comments.

Sources:
- Oracle Talent Management, "HCM Data Loader and Performance Document Business Objects".
- Oracle HCM, "Examples of Loading Performance Documents" (fahbo).

## METADATA
Performance document:
```
METADATA|PerfDocComplete|AssignmentNumber|CustomaryName|StartDate|EndDate|Operation|ManagerAssignmentNumber
```
Section + overall ratings and comments:
```
METADATA|RatingsAndComments|AssignmentNumber|CustomaryName|ParticipantPersonNumber|ParticipantRoleTypeCode|SectionName|SectionTypeCode|RatingName|Comments
```

- `AssignmentNumber` — the worker. Source stages `PERSON_NUMBER`; on this demo pod the
  primary assignment number equals the person number, so PERSON_NUMBER is used as the
  assignment number. If a client's assignment numbers differ, stage the assignment
  number into PERSON_NUMBER at load, or extend the STG/TFM schema.
- `CustomaryName` — the prefixed document name (`DOCUMENT_NAME`). Carries the run prefix
  and is the reconciliation key (matched against `HRA_EVALUATIONS.NAME`).
- `Operation` — `ORA_CREATE_PD` (Performance Administration Action lookup
  `ORA_HRA_ADMIN_ACTION`) to create the document.
- `ManagerAssignmentNumber` — from `MANAGER_PERSON_NUMBER`.
- `ParticipantRoleTypeCode` — `Manager` (the manager supplies the ratings).
- `SectionTypeCode` — `REG`.
- `RatingName` — the rating level (section or overall). Overall rating loads on the
  overall/summary section.

## Config prerequisites (verified live 2026-09-17, --cred fin_impl)
Performance evaluations require configured **performance templates** and **review
periods** on the pod, plus target workers loaded. Confirmed present:
- `HRA_EVALUATIONS` (the performance document base table) has 6,773 rows.
- 39 distinct `TEMPLATE_DEFN_ID` and 5 distinct `REVIEW_PERIOD_ID` are in use across
  those documents, so templates and review periods are configured.
- A create-document HDL load is therefore viable on this pod.

## Base table + reconciliation
- Base table: `HRA_EVALUATIONS`. Base id: `EVALUATION_ID`. Business key: `NAME`
  (the `CustomaryName`).
- Report: `bip/PerfEvaluations/DMT_PERFEVALUATIONS_RECON_DM.xdm` (+ `.xdo`, `query.sql`)
  returns the BASE tier: one row per migrated document confirmed in `HRA_EVALUATIONS`,
  matched by run prefix against `NAME`, with `EVALUATION_ID` as `FUSION_ID`.
- A PerfEvaluations TFM row reaches LOADED only from a BASE / SUCCESS / FUSION_ID-not-null
  row. Per-record HDL failures are tagged `[FUSION_ERROR]` by `RECONCILE_HDL` first.

## Code references
- STG / TFM tables: `db/tables/dmt_perf_eval_*_tbl.sql`
- Validator: `db/packages/dmt_perf_eval_validator_pkg.*`
- Transformer: `db/packages/dmt_perf_eval_transform_pkg.*`
- HDL Generator: `db/packages/dmt_perf_eval_hdl_gen_pkg.*`
- Reconciliation: `db/packages/dmt_perf_eval_results_pkg.*`

## Test data shape
| Field | Value |
|-------|-------|
| PERSON_NUMBER | must match a worker + assignment that exists / is loaded in Fusion |
| MANAGER_PERSON_NUMBER | the manager's assignment number |
| DOCUMENT_NAME | the document name (prefixed at transform) |
| REVIEW_PERIOD_NAME | a configured review period |
| START_DATE / END_DATE | evaluation period, YYYY/MM/DD |
| SECTION_NAME / RATING_LEVEL_CODE / COMMENTS | ratings child rows |

## History
- 2026-03/04: prior build loaded `GoalPlan.dat` (wrong object — Goal Management).
- 2026-09: **re-modelled to PerformanceDocument** (`PerfDocComplete` + `RatingsAndComments`);
  generator + BIP recon report re-pointed to `HRA_EVALUATIONS`; config prerequisites
  confirmed present live.

## Shared-file deltas (reported, not edited here)
- `db/seed/dmt_bip_report_tbl.sql` — the PerfEvaluations registry row's catalog paths are
  unchanged and correct; only its descriptive comment still says GoalPlan / HRG_GOAL_PLANS_VL.
- `db/seed/dmt_rest_lookup_tbl.sql` — the PerfEvaluations REST enrichment lookup still
  points at `/goalPlans`; it should point at the performance-documents REST resource. This
  is display-only enrichment, not on the LOADED path.
