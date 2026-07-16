# Assignments

## Status
NOT BUILT (HDL)

## Pipeline
- Module: HCM
- HDL File: WorkRelationship.dat, Assignment.dat
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: fin_impl

## Sub-Objects
1. WorkRelationship
2. Assignment

## Code References
- STG Table DDL (WorkRelationship): `schema/tables/110_dmt_work_rel_stg_tbl.sql`
- TFM Table DDL (WorkRelationship): `schema/tables/111_dmt_work_rel_tfm_tbl.sql`
- STG Table DDL (Assignment): `schema/tables/112_dmt_assignment_stg_tbl.sql`
- TFM Table DDL (Assignment): `schema/tables/113_dmt_assignment_tfm_tbl.sql`
- Validator: `packages/validators/dmt_assignment_validator_pkg.*`
- Transformer: `packages/transformers/dmt_assignment_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_assignment_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_assignment_results_pkg.*`

## Reference Files
None.

## Known Issues
None -- not yet built.

## Minimal test-data plan (2026-07-15)

Goal: one GOOD assignment for the good worker `RT-WKR-G1` reaches `PER_ALL_ASSIGNMENTS_M`,
and one BAD assignment reaches FAILED with a reportable Fusion error. In a regression run
all HCM objects share one numeric prefix, so `PERSON_NUMBER='RT-WKR-G1'` resolves to the
worker loaded earlier in the same run.

### Required STG tables/columns (from `dmt_assignment_hdl_gen_pkg`)
The Assignment generator emits the FULL parent chain (Worker, PersonName, WorkRelationship,
WorkTerms, Assignment). It reads the parent chain from **`DMT_WORK_REL_TFM_TBL`** (person
number, date start, legal employer, worker type, action) and the Assignment line from
**`DMT_ASSIGNMENT_TFM_TBL`**. So this object needs seed rows in TWO staging tables:

1. `DMT_WORK_REL_STG_TBL` — supplies the re-stated parent chain. Required columns:
   `PERSON_NUMBER`, `DATE_START` (YYYY/MM/DD), `LEGAL_EMPLOYER_NAME`, `ACTION_CODE`,
   `WORKER_TYPE`, `PRIMARY_FLAG`, `SOURCE_ID`, `STG_STATUS='NEW'`.
2. `DMT_ASSIGNMENT_STG_TBL` — the assignment update itself. Columns the generator actually
   emits: `PERSON_NUMBER`, `ACTION_CODE`, `EFFECTIVE_START_DATE` (YYYY/MM/DD),
   `ASSIGNMENT_NAME`, `ASSIGNMENT_NUMBER`, `ASSIGNMENT_STATUS_TYPE_CODE`, `BUSINESS_UNIT_NAME`,
   `PRIMARY_ASSIGNMENT_FLAG`, `JOB_CODE`, `GRADE_CODE`, `LOCATION_CODE`, `DEPARTMENT_NAME`,
   `POSITION_CODE`, `WORKER_CATEGORY`, `ASSIGNMENT_CATEGORY`, `FULL_PART_TIME`,
   `PERMANENT_TEMPORARY`, `NORMAL_HOURS`, `FREQUENCY`, `SOURCE_ID`, `STG_STATUS='NEW'`.
   (`PersonTypeCode` is hard-coded to `Employee` in the generator; the assignment SSID is
   built as `PERSON_NUMBER || '_ASG'`, linking WorkTerms → Assignment automatically.)

### Real reference values (queried live via BIP, hcm_impl)
A real active worker (person 10, Mandy Steward, assignment E10) on the demo instance:

| Field | Real value | Query source |
|-------|-----------|--------------|
| Assignment status type code | `ACTIVE_PROCESS` (HDL enum for an active assignment) | standard HDL code; assignment E10 status = `ACTIVE` |
| Assignment type | `E` (employee) | `PER_ALL_ASSIGNMENTS_M.assignment_type` |
| Business unit name | `US1 Business Unit` | `HR_ORGANIZATION_UNITS_F_TL` where org = person 10's BU (300000046987012) |
| Job code | `JOB071` (Data Steward Manager) | `PER_JOBS_F_VL` where job_id = 300000047624120 |
| Department name | `Sales` | `HR_ORGANIZATION_UNITS_F_TL` where org = 300000047013855 |
| Normal hours / frequency | `40` / `W` | `PER_ALL_ASSIGNMENTS_M` (E10) |
| Employment category | `FR` (full-time regular) | `PER_ALL_ASSIGNMENTS_M.employment_category` |

Grade, position, full/part-time, permanent/temporary are NULL on person 10 — they are
OPTIONAL for a minimal load and are left blank in the GOOD row below.

### Proposed GOOD seed rows (reference RT-WKR-G1)
`DMT_WORK_REL_STG_TBL` (one row — parent chain for the good worker):

| Column | Value |
|--------|-------|
| PERSON_NUMBER | `RT-WKR-G1` |
| DATE_START | `2026/01/01` |
| LEGAL_EMPLOYER_NAME | `US1 Legal Entity` |
| ACTION_CODE | `HIRE` |
| WORKER_TYPE | `E` |
| PRIMARY_FLAG | `Y` |
| SOURCE_ID | `RT-WKR-G1` |
| STG_STATUS | `NEW` |

`DMT_ASSIGNMENT_STG_TBL` (one GOOD row):

| Column | Value |
|--------|-------|
| PERSON_NUMBER | `RT-WKR-G1` |
| ACTION_CODE | `HIRE` |
| EFFECTIVE_START_DATE | `2026/01/01` |
| ASSIGNMENT_NAME | `ET-RT-WKR-G1` |
| ASSIGNMENT_NUMBER | `ET-RT-WKR-G1` |
| ASSIGNMENT_STATUS_TYPE_CODE | `ACTIVE_PROCESS` |
| BUSINESS_UNIT_NAME | `US1 Business Unit` |
| PRIMARY_ASSIGNMENT_FLAG | `Y` |
| JOB_CODE | `JOB071` |
| DEPARTMENT_NAME | `Sales` |
| NORMAL_HOURS | `40` |
| FREQUENCY | `W` |
| ASSIGNMENT_CATEGORY | `FR` |
| SOURCE_ID | `RT-WKR-G1-ASG` |
| STG_STATUS | `NEW` |
| GRADE_CODE / LOCATION_CODE / POSITION_CODE / WORKER_CATEGORY / FULL_PART_TIME / PERMANENT_TEMPORARY | (blank — optional) |

Note: the AssignmentNumber/Name must match the WorkTerms name the generator builds, which is
`ET-` || PERSON_NUMBER. Using `ET-RT-WKR-G1` keeps the assignment aligned to its work terms.

### Proposed BAD seed row (validation failure at Fusion)
Assignment validator is a stub (no local rules), so the BAD row must be rejected by Fusion.
Cleanest failure: a business unit that does not exist.

`DMT_ASSIGNMENT_STG_TBL` (one BAD row) — same as GOOD but:
- PERSON_NUMBER `RT-WKR-G1`, ASSIGNMENT_NUMBER `ET-RT-WKR-G1-BAD`,
  SOURCE_ID `RT-WKR-G1-ASG-BAD`, **BUSINESS_UNIT_NAME = `NONEXISTENT BU`**.
- Expected: HDL rejects with an invalid-business-unit error; row lands FAILED with reportable
  ERROR_TEXT. (A parent WorkRel row for RT-WKR-G1 already exists, so the chain still builds.)

### Prerequisite reference data (all confirmed present on the demo instance)
- Legal employer `US1 Legal Entity` — confirmed (used by the proven Worker load).
- Business unit `US1 Business Unit` — CONFIRMED live.
- Job `JOB071` (Data Steward Manager) — CONFIRMED live.
- Department `Sales` — CONFIRMED live.
- No blocker. The GOOD row should reach `PER_ALL_ASSIGNMENTS_M`.
