# UnitsOfMeasure — GOLD fixture (v2 seeded) — LIVE-PROVEN

**Object:** a Unit of Measure (standalone SCM reference data — a UOM plus its US name).
**Load path:** FSM "Setup Data Import from CSV file" REST (`setupTaskCSVImports`),
task code `INV_MANAGE_UNITS_OF_MEASURE`, credential role `scm_impl`. No DMT database,
no DMT pipeline code in the load path.
**Base tables:** `INV_UNITS_OF_MEASURE_B` (the UOM) / `INV_UNITS_OF_MEASURE_TL` (US name),
joined on `UNIT_OF_MEASURE_ID`. Verified read-only through the BIP relay.
**Status:** LIVE-PROVEN 2026-07-20 (v2 seeded), first run prefix `19742`, second run `71793`.

## What "v2 seeded" changed here

v1 (`../../objects/UnitsOfMeasure/`) discovered two things at load time; both are now hard-coded
or derived, and the `discovery` block is empty:

1. **The UOM class** — v1 ran `SELECT UOM_CLASS ... GROUP BY UOM_CLASS ORDER BY COUNT(*) DESC`
   to find the largest existing class, which resolved to `5` (Quantity). v2 writes `5` as a
   **hard-coded literal** in the CSV template (`UomClassCode = "5"`). Confirmed via read-only BIP
   on 2026-07-20 that class `5` is the largest seeded UOM class on the pod (17 UOMs, none carrying
   our `GldRegUOM` prefix) — standard demo-pod data we did not load, so it resolves on any pod.
2. **The 3-char codes** — v1 queried the used `UOM_CODE` set and picked three unused ones.
   `UOM_CODE` is capped at 3 characters, so a 5-digit `${PREFIX}` cannot live in the code. v2 does
   **no query**: the runner derives three distinct codes from the prefix deterministically —
   a 2-character base-36 stem `= int(prefix) % 1296`, then suffixes `A` (good 1), `B` (good 2),
   `C` (bad). Distinct prefixes give distinct codes.

Everything else is identical to v1. The `${PREFIX}` still rides in the UOM **name/description**
(`GldRegUOM ${PREFIX} A` / `B` / `BAD`), and verification is **by name**, exactly as v1.

## How it runs

`run_object.py` only routes FBDI and HDL objects, so this FSM CSV object is driven by the
self-contained runner `run_uom_fsm.py`, which honors `GOLD_OBJECTS_SUBDIR` like the rest of the
harness (the same shape as `objects_seeded/Lookups/run_lookups_fsm.py`):

```bash
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/UnitsOfMeasure/run_uom_fsm.py
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/UnitsOfMeasure/run_uom_fsm.py --prefix 19742
```

It reads the artifact from the active object tree, stamps `${PREFIX}` and the derived codes into
the two CSVs, zips the three root files, submits through the shared `harness/load_fsm_csv.py`
driver (`scm_impl`), polls `ProcessCompletedFlag`, then verifies read-only through the shared BIP
relay (`harness/bip.py`) using the recipe's verify SQL.

## Good / bad design

- **Good:** two NEW non-base UOMs placed in the hard-coded seeded class `5` (Quantity),
  named `GldRegUOM ${PREFIX} A` and `GldRegUOM ${PREFIX} B`.
- **Bad (deterministic rejection):** a NEW UOM `GldRegUOM ${PREFIX} BAD` with
  `UomClassCode = ZZ_NO_SUCH_CLASS` — a class that does not exist. The importer rejects it —
  *"UomClass does not exist; skipping record"* — so it never reaches `INV_UNITS_OF_MEASURE_B`.
  Pod-independent; needs no bad reference data.

## Verify SQL (read-only BIP, `scm_impl`)

```sql
-- good UOMs reached base (expect 2 rows, real ids, class 5)
SELECT b.UOM_CODE, b.UNIT_OF_MEASURE_ID, b.UOM_CLASS, t.UNIT_OF_MEASURE
FROM   INV_UNITS_OF_MEASURE_B b
JOIN   INV_UNITS_OF_MEASURE_TL t ON t.UNIT_OF_MEASURE_ID = b.UNIT_OF_MEASURE_ID
WHERE  t.LANGUAGE = 'US'
  AND  t.UNIT_OF_MEASURE LIKE 'GldRegUOM 19742%'
  AND  t.UNIT_OF_MEASURE NOT LIKE '%BAD%';
-- bad UOM absent from base (rejection proof — expect zero rows)
SELECT UOM_CODE FROM INV_UNITS_OF_MEASURE_B WHERE UOM_CODE = '8EC';
```

## Live evidence (v2 seeded, 2026-07-20)

| Item | First run | Second run (consecutive) |
|---|---|---|
| Version | v2 seeded (`GOLD_OBJECTS_SUBDIR=objects_seeded`) | v2 seeded |
| Prefix | `19742` | `71793` |
| Seeded class (hard-coded) | `5` (Quantity) | `5` (Quantity) |
| Good UOM codes | `8EA`, `8EB` | `E9A`, `E9B` |
| **Good base ids** (`INV_UNITS_OF_MEASURE_B`) | `300000331550473` (8EA), `300000331550474` (8EB) | `300000331574586` (E9A), `300000331574587` (E9B) |
| Good names (`_TL`, US) | `GldRegUOM 19742 A` / `B` | `GldRegUOM 71793 A` / `B` |
| Bad UOM code | `8EC` | `E9C` |
| Bad error | *"UomClass does not exist; skipping record. (uom :GldRegUOM 19742 BAD,uomCode:8EC,uomClassCode:ZZ_NO_SUCH_CLASS) ,Skipping the row"* | *"UomClass does not exist; skipping record. (uom :GldRegUOM 71793 BAD,uomCode:E9C,uomClassCode:ZZ_NO_SUCH_CLASS) ,Skipping the row"* |
| Bad in base? | **No** — `8EC` absent (0 rows) | **No** — `E9C` absent (0 rows) |
| Import ProcessId / ESS | `100007867616163` / `9766674` | `100007867616202` / `9766712` |
| Result | **PASS** | **PASS** |

## Second-run note (re-runnability)

The two runs above were **consecutive** on the same pod with **no reset and no cleanup between
them**, and both passed. New UOMs are naturally re-runnable: each run stamps a fresh prefix, which
both changes the UOM names (`GldRegUOM 19742 …` vs `GldRegUOM 71793 …`) and derives a distinct
3-char code stem (`8E…` vs `E9…`), so the second run creates brand-new records that never collide
with the first. Verification is by name, so each run only sees its own rows. This mirrors v1's
re-runnability without any discovery query.

v1 baseline for comparison: prefix `90210`, class `5`, codes `GAA`/`GAB`/`GAC`,
ids `300000331549888` / `300000331549889`, ProcessId `100007866630872` / ESS `9765360`.
