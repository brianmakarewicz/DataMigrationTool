# PayrollRelationship

## Status
NOT BUILT (HDL)

## FOLLOW-UP (generator forward-fix, tracked from run 234, 2026-07-21)
The HDL generator emits the business object / file name `PayrollRelationship`, which is
NOT a loadable top-level HDL object. Fusion rejects the whole file before any row is read:
"The PayrollRelationship file name isn't valid. You need to use the name of a top-level
supported business object as the file name." The loadable object is **`AssignedPayroll`**
(the `.dat` must be named `AssignedPayroll.dat`; HDL derives the object from the file name).
Fix the generator to emit `AssignedPayroll`. This is a SEPARATE forward-fix that makes the
data LOAD; it is out of scope for the reconciler honesty fix (PR that added file-level error
attribution). Until then, run-234 rows are now honestly FAILED with the real Fusion file
message rather than left stuck at GENERATED.

## Pipeline
- Module: HCM
- HDL File: PayrollRelationship.dat
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: fin_impl

## Code References
- STG Table DDL: `schema/tables/130_dmt_pay_rel_stg_tbl.sql`
- TFM Table DDL: `schema/tables/131_dmt_pay_rel_tfm_tbl.sql`
- Validator: `packages/validators/dmt_pay_rel_validator_pkg.*`
- Transformer: `packages/transformers/dmt_pay_rel_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_pay_rel_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_pay_rel_results_pkg.*`

## Reference Files
None.

## Known Issues
None -- not yet built.

## Minimal test-data plan (2026-07-15)

Goal: one GOOD payroll relationship for the good worker `RT-WKR-G1` reaches
`PAY_PAY_RELATIONSHIPS_F`, and one BAD reaches FAILED with a reportable Fusion error. All
HCM objects in a regression run share one numeric prefix, so the
`PeriodOfServiceId(SourceSystemId)` FK (`RT-WKR-G1_POS`) resolves to the work relationship
loaded earlier in the same run.

### Required STG table/columns (from `dmt_pay_rel_hdl_gen_pkg`)
Single table: **`DMT_PAY_REL_STG_TBL`**. Standalone HDL file, but the FK
(`PERSON_NUMBER || '_POS'`) references the work relationship from the Worker/Assignment load,
so Workers must load first in the same prefixed run. Columns the generator actually emits:
`PERSON_NUMBER`, `LEGAL_EMPLOYER_NAME`, `PAYROLL_NAME`, `PAYROLL_RELATIONSHIP_NUMBER`,
`PAYROLL_STATUS_CODE`, `LEGISLATIVE_DATA_GROUP_NAME`, plus infra `SOURCE_ID`,
`STG_STATUS='NEW'`. (SSID is `PERSON_NUMBER || '_PAYREL'`.)

### Real reference values (queried live via BIP, hcm_impl)
`PAY_PAY_RELATIONSHIPS_F` is reachable and holds real records (e.g. relationship id
300000047606127, effective 2009/03/09). Type/status/number are not stored as plain columns
on the `_F` table on this instance; they are HDL enums:

| Field | Value to use | Source |
|-------|--------------|--------|
| Legislative data group name | `US Legislative Data Group` | `PAY_LEGISLATIVE_DATA_GROUPS` (legislation US) — CONFIRMED live |
| Payroll name | `Biweekly` (a real US payroll) | `PAY_ALL_PAYROLLS_F` joined to the US LDG — CONFIRMED live |
| Legal employer name | `US1 Legal Entity` | matches the proven Worker load |
| Payroll status code | `A` (active) | standard HDL payroll-status enum |

### Proposed GOOD seed row (references RT-WKR-G1)
`DMT_PAY_REL_STG_TBL` (one GOOD row):

| Column | Value |
|--------|-------|
| PERSON_NUMBER | `RT-WKR-G1` |
| LEGAL_EMPLOYER_NAME | `US1 Legal Entity` |
| PAYROLL_NAME | `Biweekly` |
| PAYROLL_RELATIONSHIP_NUMBER | `RT-WKR-G1` (let Fusion default if rejected) |
| PAYROLL_STATUS_CODE | `A` |
| LEGISLATIVE_DATA_GROUP_NAME | `US Legislative Data Group` |
| SOURCE_ID | `RT-WKR-G1-PAYREL` |
| STG_STATUS | `NEW` |

### Proposed BAD seed row (validation failure at Fusion)
Pay-rel validator is a stub, so failure comes from Fusion. Cleanest failure: a legislative
data group that does not exist.

`DMT_PAY_REL_STG_TBL` (one BAD row) — same as GOOD but:
- PERSON_NUMBER `RT-WKR-G1`, SOURCE_ID `RT-WKR-G1-PAYREL-BAD`,
  **LEGISLATIVE_DATA_GROUP_NAME = `NONEXISTENT LDG`**.
- Expected: Fusion rejects the unknown LDG; row lands FAILED with reportable ERROR_TEXT.

### Prerequisite reference data (confirmed present)
- Legislative data group `US Legislative Data Group` — CONFIRMED live.
- Payroll `Biweekly` (US LDG) — CONFIRMED live.
- Legal employer `US1 Legal Entity` — CONFIRMED (Worker load).
- The work relationship (`RT-WKR-G1_POS`) must load first in the same prefixed run.
- Possible risk to verify at load time: whether the demo payroll definitions cover the
  2026/01/01 hire date and whether `Biweekly` is assignable to a newly hired US worker.
  If the load rejects the payroll, try another US payroll from the confirmed list
  (`Semimonthly`, `Monthly`, `Weekly`). No hard blocker identified.
