# UnitsOfMeasure (v2 seeded) — artifact manifest

The load artifact is `UnitsOfMeasure_gold.zip`, built at run time by `run_uom_fsm.py`. It
contains **three files at the root of the zip** (a flat-CSV FSM object — not nested in a batch
subzip). The build stamps `${PREFIX}` and the three derived 3-char codes (`${C1}`/`${C2}`/`${C3}`)
into the two CSV members; the manifest XML is copied verbatim.

| Member (zip root) | Templated? | Role |
|---|---|---|
| `ASM_SETUP_CSV_METADATA.xml` | no | Real live-exported manifest (from esew-dev28), `ProcessType` flipped `EXPORT`→`IMPORT`. Declares the business objects and the `UnitOfMeasureService`. Carries no prefix. |
| `INV_UNIT_OF_MEASURE.csv` | `${PREFIX}`, `${C1}` `${C2}` `${C3}` | The UOMs → `INV_UNITS_OF_MEASURE_B`. Two good rows (codes `${C1}`,`${C2}`, class `5`) named `GldRegUOM ${PREFIX} A`/`B`; one bad row (code `${C3}`, `UomClassCode = ZZ_NO_SUCH_CLASS`) named `GldRegUOM ${PREFIX} BAD`. |
| `INV_UNIT_OF_MEASURE_TRANSLATION.csv` | `${PREFIX}` | US names → `INV_UNITS_OF_MEASURE_TL`. First column is the parent-qualified `INV_UNIT_OF_MEASURE.UnitOfMeasure` (foreign key to the UOM by name). |

**CSV format:** comma-delimited, every value double-quoted, CRLF line ends, header row of column
names present. Minimal UOM columns: `UnitOfMeasure, UomCode, BaseUomFlag, Description,
UomClassCode, HasGeneratedCode`. Translation columns: `INV_UNIT_OF_MEASURE.UnitOfMeasure,
UnitOfMeasure, Description, Language, SourceLang`.

## Seeded references (hard-coded, not discovered)

| Value | Where | What it is |
|---|---|---|
| `5` | `INV_UNIT_OF_MEASURE.csv` → `UomClassCode` (good rows) | The UOM class **Quantity** — the largest seeded UOM class on every demo pod (confirmed via read-only BIP 2026-07-20: 17 seeded UOMs, none ours). Was v1 discovery `UOM_CLASS_REF`; now a hard-coded literal. |

## Derived (not discovered, not a seed) — the 3-char codes

`UOM_CODE` is capped at 3 characters, so the 5-digit `${PREFIX}` cannot live in the code. The
runner derives three distinct codes from the prefix with **no query**: a 2-char base-36 stem
`= int(prefix) % 1296`, then suffix `A`/`B`/`C`. Example: prefix `19742` → stem `8E` →
`8EA`/`8EB`/`8EC`. The `${PREFIX}` itself rides in the UOM name/description, and verification is
by name.

## Run

```bash
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/UnitsOfMeasure/run_uom_fsm.py
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/UnitsOfMeasure/run_uom_fsm.py --prefix 19742
```
