# WorkSchedules

## Status
CLOSE — parent METADATA validated, child WorkPatternShift V1 attributes unknown (2026-04-04 DB-20)

## Pipeline
- Module: HCM
- HDL File: **WorkPattern.dat** (NOT WorkSchedule.dat)
- Discriminator: **WorkPattern** (V1)
- Child: **WorkPatternShift** (V1) — at least 1 required
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: hcm_impl (password: m?CDa6^6)

## SourceSystemId Convention
| Component | Suffix | Example |
|-----------|--------|---------|
| WorkPattern | _WPAT | 9210DMTW101_WPAT |
| WorkPatternShift | _WSHIFT_{seq} | 9210DMTW101_WSHIFT_123 |

## METADATA — Parent (Validated, Import OK)
```
SourceSystemOwner|SourceSystemId|AssignmentNumber|DateFrom|WorkPatternTypeName
```

- `AssignmentNumber` = prefixed PERSON_NUMBER (matches Worker Assignment created during hire)
- `DateFrom` = schedule start date
- `WorkPatternTypeName` = **required**. Demo instance value: `9A - 5P General Shift`
- PERSON_NUMBER added to STG/TFM in DB-20 (maps to AssignmentNumber via prefix)

## METADATA — Child (BLOCKED — V1 attributes unknown)
Attempted attributes, ALL rejected as "unknown for V1 version of WorkPatternShift":
- `DayNumber` — INVALID
- `StartTime` — INVALID  
- `EndTime` — INVALID
- `ShiftName`, `ShiftDate`, `Duration`, `UnitOfMeasure` — not yet tested

Correct V1 attribute names need iterative discovery.

## Code References
- STG Table DDL: `schema/tables/144_dmt_work_sched_stg_tbl.sql`
- STG Table DDL (Details): `schema/tables/146_dmt_work_sched_dtl_stg_tbl.sql`
- TFM Table DDL: `schema/tables/145_dmt_work_sched_tfm_tbl.sql`
- TFM Table DDL (Details): `schema/tables/147_dmt_work_sched_dtl_tfm_tbl.sql`
- Validator: `packages/validators/dmt_work_sched_validator_pkg.*`
- Transformer: `packages/transformers/dmt_work_sched_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_work_sched_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_work_sched_results_pkg.*`

## Known Issues
1. **WorkPatternShift V1 attribute names unknown.** `DayNumber`, `StartTime`, `EndTime` all rejected. Need iterative discovery testing.
2. **At least 1 shift required.** Fusion rejects WorkPattern without any child shifts: "You need to add at least 1 shift before you can save the work pattern."
3. **STG design gap.** Original STG was modeled for schedule definitions (no person reference). PERSON_NUMBER column added in DB-20 to support the person-level WorkPattern HDL object.

## Lessons Learned
- HDL filename is **WorkPattern.dat** — NOT WorkSchedule.dat.
- Uses V1 format (not V2).
- `WorkPatternTypeName` is required (Fusion rejects without it). It's instance-specific — query `workPatterns` REST endpoint to discover valid values.
- Demo instance only has one type: `9A - 5P General Shift` (from REST query of existing work patterns).
- Child WorkPatternShift records are mandatory — not optional. A work pattern without shifts fails at load.
- Reconciliation key mismatch: error messages reference SourceSystemId but TFM uses WORK_SCHEDULE_NAME as key. Errors show as "HDL data set ended in error but no row-level error matched." Direct REST query to `/dataLoadDataSets/{id}/child/messages` is needed to see actual errors.

## History
- 2026-03-25: METADATA validated (parent only). WorkPattern.dat filename discovered. V1 confirmed.
- 2026-04-04 (DB-20): PERSON_NUMBER added to STG/TFM. Dynamic AssignmentNumber working. WorkPatternTypeName discovered. Child shift required but V1 attributes unknown.
