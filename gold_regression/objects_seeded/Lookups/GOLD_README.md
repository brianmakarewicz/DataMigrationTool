# Lookups — GOLD fixture (v2 seeded) — LIVE-PROVEN

**Object:** Application Standard / Common Lookups (a lookup *type* plus its lookup *codes*).
**Load path:** FSM "Setup Data Import from CSV file" REST (`setupTaskCSVImports`),
task code `FND_MANAGE_STANDARD_LOOKUPS`, credential role `fin_impl`. No DMT database,
no DMT pipeline code in the load path.
**Base tables:** `FND_LOOKUP_TYPES_B/_TL` (type), `FND_LOOKUP_VALUES_B/_TL` (codes);
verified through the granted translated views `FND_LOOKUP_TYPES_VL` / `FND_LOOKUP_VALUES_VL`.
**Status:** LIVE-PROVEN 2026-07-20 (v2 seeded), prefix `60416`.

## What "v2 seeded" changed here: nothing

This is the point of the object. A Standard Lookup type is **standalone reference data** —
it borrows nothing from upstream data, so there is no reference to discover. The v1 fixture
in `../../objects/Lookups/` already had `"discovery": []` and carried **no `${TOKEN}`** at
all. The one run-time-derived value — the `ModuleId` for the FND application
(`40B3FA7250D19380E040449823C67A1A`, the seeded FND module present on every demo pod) —
was already written as a hard-coded literal in the v1 template, not discovered.

So the v2 conversion is a **byte-identical copy** of the v1 artifact and recipe. The only
templated token, `${PREFIX}` on the lookup type code (`RT_GOLD_${PREFIX}` /
`RT_NO_SUCH_TYPE_${PREFIX}`), is unchanged. There was no discovery block to delete and no
`${TOKEN}` to hard-code — it was already in the "seeded" shape.

## How it runs

`run_object.py` only routes FBDI and HDL objects, so this FSM CSV object is driven by the
self-contained runner `run_lookups_fsm.py`, which honors `GOLD_OBJECTS_SUBDIR` exactly like
the rest of the harness:

```bash
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/Lookups/run_lookups_fsm.py --prefix 60416
```

It reads the artifact from the active object tree, stamps `${PREFIX}` into the two CSVs,
zips the three root files, submits through the shared `harness/load_fsm_csv.py` driver
(`fin_impl`), polls `ProcessCompletedFlag`, then verifies read-only through the shared BIP
relay (`harness/bip.py`) using the recipe's verify SQL.

## Good / bad design (unchanged from v1)

- **Good:** lookup type `RT_GOLD_${PREFIX}` with two enabled codes `G1`, `G2`.
- **Bad (deterministic rejection):** code `BAD1` whose parent `LookupType` =
  `RT_NO_SUCH_TYPE_${PREFIX}` is **not** in the type CSV. The importer skips it —
  *"Parent row is missing in file FND_APP_STANDARD_LOOKUP.csv for row 3 in file
  ORA_FND_APP_STANDARD_LOOKUP_CODE.csv. Row will be skipped"* — so it never reaches
  `FND_LOOKUP_VALUES`. Pod-independent; needs no bad reference data.

## Verify SQL (read-only BIP, `_VL` views)

```sql
-- good type reached base
SELECT lookup_type FROM fnd_lookup_types_vl WHERE lookup_type = 'RT_GOLD_60416';
-- good codes reached base
SELECT lookup_type, lookup_code FROM fnd_lookup_values_vl
 WHERE lookup_type = 'RT_GOLD_60416' AND lookup_code IN ('G1','G2');
-- bad code absent from base (rejection proof)
SELECT lookup_type, lookup_code FROM fnd_lookup_values_vl
 WHERE lookup_type = 'RT_NO_SUCH_TYPE_60416';   -- expect zero rows
```

## Live evidence (v2 seeded, 2026-07-20)

| Item | Value |
|---|---|
| Version | v2 seeded (`GOLD_OBJECTS_SUBDIR=objects_seeded`) |
| Prefix | `60416` |
| Import ProcessId | `100007867616132` |
| ESS request id | `9766463` |
| Auth / role | `fin_impl` |
| Import status | Completed with warnings — 3 code rows processed, bad row skipped |
| Good type in base | `RT_GOLD_60416` present in `FND_LOOKUP_TYPES_VL` |
| Good codes in base | `G1`, `G2` present in `FND_LOOKUP_VALUES_VL` |
| Bad row | `BAD1` under `RT_NO_SUCH_TYPE_60416` — importer *"Parent row is missing … Row will be skipped"*; absent from base (0 rows) |
| Result | **PASS** (good_type + good_codes + bad_absent all true) |

v1 baseline for comparison: prefix `90777`, ProcessId `100007866630904` / ESS `9765415`.
