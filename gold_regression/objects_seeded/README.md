# objects_seeded — v2 fixtures (hard-coded seeded references, no discovery)

This is the **converted** version of the gold fixtures. It is functionally identical to the
frozen v1 fixtures in `../objects/`, with one difference: instead of discovering an upstream
reference at load time, each fixture **hard-codes a standard seeded value** that ships in every
demo pod (a supplier we never loaded, `US1 Business Unit`, `US Primary Ledger`, and so on).

- **v1 — `../objects/` — FROZEN.** The proven fixtures that use `${TOKEN}` discovery. Do not
  edit them. They are the reference baseline, with their live load evidence recorded in
  `../LOAD_EVIDENCE.json`.
- **v2 — this folder — the converting version.** Same records, discovery replaced by hard-coded
  seeds. Safe to iterate on.

Both run through the same harness. Pick the version with one env var:

```bash
# v1 (default): discovery
python harness/run_object.py Suppliers

# v2: this folder, hard-coded seeds
GOLD_OBJECTS_SUBDIR=objects_seeded python harness/run_object.py Suppliers
```

Conversion rule for each object: take the value that v1's discovery resolved to (recorded in
`../objects/{Object}/GOLD_README.md`), confirm it is standard seeded data we did **not** load
(never a record carrying one of our prefixes), write it as a literal in this version's template,
and delete the discovery block from this version's `recipe.json`. `${PREFIX}` on the new
record's own keys stays exactly as in v1. Then run it live here to confirm it still reaches the
base table before marking the object converted.
</content>
