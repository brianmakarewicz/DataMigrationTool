# Run 234 Expenditures FBDI vs Gold — ORA-01008 root cause

**Date:** 2026-07-21
**Scope:** READ-ONLY investigation. No code changed, no pipeline run.
**Symptom:** Run 234 Expenditures import job `ImportAndProcessTxnsJob` (ESS request 9773867)
errored with `ORA-01008: not all variables bound` inside Fusion's PJC onestop costing proc at
the `update_xface_id` step. The 6 staged rows sit in `PJC_TXN_XFACE_STAGE_ALL` at status `P`
(load request 9773838). The job path and ParameterList match gold.

## What was compared

- **Gold known-good CSV:** `gold_regression/objects/Expenditures/artifact/PjcTxnXfaceStageAll.csv`
  and the seeded variant `gold_regression/objects_seeded/Expenditures/artifact/PjcTxnXfaceStageAll.csv`
  (the seeded one resolves real reference values, so it is the shape to match). Gold loaded and
  costed cleanly on this pod at prefix 32159 (`PJC_EXP_ITEMS_ALL` EXPENDITURE_ITEM_ID 750728/750729).
- **Our actual generated CSV for run 234:** recovered live from the Docker DB
  (`dmt2-local`, port 1523) — `DMT_OWNER.DMT_FBDI_CSV_TBL`, `FBDI_CSV_ID = 100002687`,
  `FILENAME = PjcTxnXfaceStageAll.csv`, 6 rows, 3108 bytes. This is the exact CSV DMT built this
  run, not a reconstruction.
- **Generator column order:** `db/packages/dmt_expenditure_fbdi_gen_pkg.pkb.sql` (the NONLABOR
  branch, lines 79–210).
- **Transform (source of the field values):** `db/packages/dmt_expenditure_transform_pkg.pkb.sql`.

## Headline result — it is NOT a column-count / layout mismatch

Our generated CSV has **107 fields per row for every row**, which is an EXACT positional match to
the gold NONLABOR layout (107 fields, four `NON_LABOR_RESOURCE*` columns after ORGANIZATION_ID at
positions 29–32). All rows are `NONLABOR`, so the SQL*Loader discriminator routes them into the
same 107-column branch gold used. The load step even SUCCEEDED (rows reached staging at status `P`).
The column layout is therefore ruled out as the ORA-01008 cause.

The `ORA-01008` fires later, during the separate `ImportAndProcessTxnsJob` costing step, inside
Fusion's own dynamic UPDATE that stamps resolved internal ids back onto the staging rows
(`update_xface_id`). That step binds one variable per reference it resolved; when a **mandatory
reference cannot be resolved to an internal id, its bind is never populated**, and the dynamic
statement raises `ORA-01008: not all variables bound`. So the cause is a DATA value that Fusion
cannot resolve — not the CSV structure.

## Full positional diff (our GOOD row vs seeded-gold GOOD row)

Placeholders normalized: `${PREFIX}` → `10115` (run 234's prefix), `${GL_DATE_SLASH}` → `2026/11/02`.

| Pos | Column | GOLD (known-good) | OUR run 234 | Verdict |
|----:|--------|-------------------|-------------|---------|
| 19 | PROJECT_NUMBER | `PCS10037` | `10115PCS10037` | **PRIME SUSPECT — unresolvable project** |
| 44 | GL_DATE | `2026/11/02` (populated) | *(empty)* | Secondary suspect — mandatory bind left empty |
| 34 | UNIT_OF_MEASURE_NAME | *(empty)* | `DOLLARS` | Minor — extra value gold leaves blank |
| 10 | BATCH_NAME | `10115RT-EXP-G1` | `10115RT-EXP-RTPRJ001` | Cosmetic — unique per row, fine |
| 40 | ORIG_TRANSACTION_REFERENCE | `10115RT-EXP-G1` | `10115RT-EXP-RTPRJ001` | Cosmetic — unique per row, fine |
| 33 | QUANTITY | `125` | `1500` | Cosmetic — different amount, QTY==RAW_COST holds |
| 47 | DENOM_RAW_COST | `125` | `1500` | Cosmetic — different amount |

Everything else (positions 1, 2, 4, 6, 8, 13, 22, 25, 27, 35, 38, 45 and all empty tail fields)
is byte-identical to gold: `NONLABOR`, `US1 Business Unit`, `External Miscellaneous`,
`Miscellaneous`/`Miscellaneous`, expenditure item date, task `5.2`, expenditure type `Airfare`
(and `ZZ-BAD-EXPTYPE-99` on the bad rows), org `Consulting North US`, UOM code `DOLLARS`,
billable `N`, currency `USD`.

## Ranked causes

### 1. (PRIME) PROJECT_NUMBER carries the run prefix — `10115PCS10037` instead of `PCS10037`

- **Our value:** `10115PCS10037`  ·  **Gold value:** `PCS10037`  ·  **Template expectation:** the
  real, existing project number, unprefixed.
- `PCS10037` is a real project discovered live on the pod (per gold GOLD_README.md). `10115PCS10037`
  does not exist. When the costing proc tries to resolve the project reference to a `PROJECT_ID` to
  bind into the `update_xface_id` UPDATE, resolution returns nothing, the id bind is never set, and
  the dynamic statement raises `ORA-01008`. This is exactly the "a required column the proc binds is
  missing/empty" mode the facts describe, and it is the single value that is structurally present
  but semantically unresolvable.
- **Why it happens:** the transform unconditionally stamps the run prefix onto PROJECT_NUMBER.
  `db/packages/dmt_expenditure_transform_pkg.pkb.sql:185`
  `DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.PROJECT_NUMBER, 25)`.
  For Expenditures the project is a **pre-existing pod reference we charge against**, not an object
  we created earlier in this run, so it must NOT be prefixed. (Gold discovers the real project and
  writes it verbatim; the transform mangles it.)
- **Proposed fix:** stop prefixing PROJECT_NUMBER in the Expenditures transform. Change
  `dmt_expenditure_transform_pkg.pkb.sql:185` from
  `DMT_UTIL_PKG.PREFIXED(l_dep_prefix, s.PROJECT_NUMBER, 25)` to plain `s.PROJECT_NUMBER`.
  (Keep the prefix on ORIG_TRANSACTION_REFERENCE at line 220 and on the synthesised BATCH_NAME at
  line 176 — those are our own keys and SHOULD stay unique per run.)

### 2. (SECONDARY) GL_DATE is empty — gold populates position 44

- **Our value:** *(empty)*  ·  **Gold value:** `2026/11/02` (same as expenditure item date)  ·
  **Template expectation:** a populated GL date.
- Gold's seeded fixture fills position 44 (`${GL_DATE_SLASH}`). Our row leaves it blank because the
  regression seed never sets `GL_DATE` on the STG row, and the transform passes it straight through
  (`dmt_expenditure_transform_pkg.pkb.sql:224` `s.GL_DATE`), so TFM/CSV GL_DATE is NULL. If Fusion's
  `update_xface_id` also binds a GL-date-derived value, an empty GL_DATE is a second way to leave a
  bind unpopulated. Fix #1 alone may clear the error; if it does not, fill GL_DATE too.
- **Proposed fix (defensive):** default GL_DATE to the expenditure item date when the source leaves
  it null — in the transform, change `dmt_expenditure_transform_pkg.pkb.sql:224` from `s.GL_DATE` to
  `NVL(s.GL_DATE, s.EXPENDITURE_ITEM_DATE)`; or set GL_DATE in the seed
  (`scripts/insert_regression_test_data.py`, section 27, both GOOD and BAD Expenditure inserts).

### 3. (MINOR) UNIT_OF_MEASURE_NAME populated where gold leaves it blank

- **Our value (pos 34):** `DOLLARS`  ·  **Gold value:** *(empty)*  ·  Both populate pos 35 (the UOM
  code) with `DOLLARS`.
- Gold supplies only the UOM **code** (pos 35) and leaves the UOM **name** (pos 34) blank. Ours puts
  `DOLLARS` in both. This is very unlikely to cause ORA-01008 (it is a text column, not an id bind),
  but it is a real drift from the proven-good shape and could trip a name-vs-code validation. Match
  gold: leave UNIT_OF_MEASURE_NAME blank and populate only UNIT_OF_MEASURE. Source of the value is
  the STG `UNIT_OF_MEASURE_NAME` column; the generator emits it verbatim at
  `dmt_expenditure_fbdi_gen_pkg.pkb.sql:131`. Cleanest fix is to not seed UNIT_OF_MEASURE_NAME
  (leave the STG/TFM column null); the generator already handles null as empty.

## Recommendation

Apply fix #1 first (stop prefixing PROJECT_NUMBER) — it is the concrete, gold-backed explanation for
`ORA-01008 at update_xface_id`, because `10115PCS10037` is the one field that is present in the CSV
but cannot be resolved to a real Fusion id. Re-run Expenditures for a fresh prefix. If the costing
job still errors, apply fix #2 (populate GL_DATE), then #3 (drop UOM name). Do not touch the column
layout — it is already a byte-exact 107-field NONLABOR match to gold.

## Evidence / limitation notes

- Our generated CSV was recovered directly from the DB (not reconstructed): `DMT_FBDI_CSV_TBL`
  FBDI_CSV_ID 100002687. Saved locally at the scratchpad `run234_exp.csv` for the diff.
- Run 234 TFM rows confirm the same values live in `DMT_PJC_EXPENDITURES_TFM_TBL` (6 rows,
  TFM_STATUS `UNACCOUNTED`, PROJECT_NUMBER `10115PCS10037`, GL_DATE null).
- The `ORA-01008 at update_xface_id` attribution itself comes from the Fusion ESS log (per the task
  facts); that log lives in Fusion, not the local DMT DB, so it was not re-pulled here. The prime
  cause (unresolvable prefixed project) is the value-level difference most consistent with an
  unbound id variable in Fusion's dynamic reference-resolution UPDATE.
