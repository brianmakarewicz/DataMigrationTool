# Lookups (v2 seeded) — artifact manifest

The load artifact is `Lookups_gold.zip`, built at run time by
`run_lookups_fsm.py`. It contains **three files at the root of the zip** (a flat-CSV
FSM object — not nested in a batch subzip). The build stamps `${PREFIX}` into the
two CSV members; the manifest XML is copied verbatim.

| Member (zip root) | Templated? | Role |
|---|---|---|
| `FND_APP_STANDARD_LOOKUP.csv` | `${PREFIX}` | Lookup **types** → `FND_LOOKUP_TYPES_B/_TL` (view `FND_LOOKUP_TYPES_VL`). One good type `RT_GOLD_${PREFIX}`. |
| `ORA_FND_APP_STANDARD_LOOKUP_CODE.csv` | `${PREFIX}` | Lookup **codes** → `FND_LOOKUP_VALUES_B/_TL` (view `FND_LOOKUP_VALUES_VL`). Good codes `G1`, `G2` under `RT_GOLD_${PREFIX}`; bad code `BAD1` under `RT_NO_SUCH_TYPE_${PREFIX}` (parent not in the type CSV → skipped). First column is parent-qualified `FND_APP_STANDARD_LOOKUP.LookupType`. |
| `ASM_SETUP_CSV_METADATA.xml` | no | Real exported manifest, `ProcessType` flipped `EXPORT`→`IMPORT`. Declares the two business objects, node paths, and the `LookupWS` service. |

**CSV format:** comma-delimited, every field double-quoted, CRLF line ends, header row
present, dates `YYYY/MM/DD HH24:MI:SS.FF`.

## Seeded references (hard-coded, not discovered)

There is exactly one non-key literal, already hard-coded in v1 and unchanged here:

| Value | Where | What it is |
|---|---|---|
| `40B3FA7250D19380E040449823C67A1A` | `FND_APP_STANDARD_LOOKUP.csv` → `ModuleId` | The seeded FND application module id present on every demo pod. Read once from a live export; not discovered. |

No `${TOKEN}` discovery reference exists (a Standard Lookup type is standalone reference
data). The only templated token is `${PREFIX}` on the lookup type code.

## Run

```bash
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/Lookups/run_lookups_fsm.py
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/Lookups/run_lookups_fsm.py --prefix 60416
```
