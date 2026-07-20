# Gold Regression Harness — how it works and how to run it

This folder is the standalone engine that builds a gold fixture, loads it into Oracle Fusion
through a web-service call, and verifies the result — with **no DMT database and no DMT
pipeline code in the load path**. Verification is a read-only query only.

If you are opening this folder cold, read this file first, then the top-level
`../README.md` (the design rules and the 45-object status table).

## The one idea

Every fixture is a small file of records with two kinds of field:

1. **The new record's own keys** — the fields that would cause a duplicate if you loaded the
   same file twice (a supplier segment/name, an invoice number, a lookup code). These carry a
   `${PREFIX}` placeholder. The harness stamps a fresh number into `${PREFIX}` on every run, so
   the same fixture loads again and again without ever colliding with data already in Fusion.

2. **References to data that already exists** — the business unit, the ledger, the parent
   supplier a site attaches to, the legal employer a worker belongs to. These are **hard-coded
   in the template** to a standard seeded value that ships in every demo pod. We do **not**
   look these up, and we do **not** stamp a prefix on them.

That is the whole model: stamp a fresh prefix on the new keys, leave the seeded references
alone, load, verify.

## Why the references are hard-coded (not discovered)

Every Oracle Fusion demo pod (`fa-esew-devN-saasfademo1`) is cloned from the same demo image,
so the standard seeded data is identical everywhere: the same demo suppliers, the same
`US1 Business Unit`, the same `US Primary Ledger`, the same demo employees. Because those
values are the same on any pod, we can hard-code one and it will resolve on any instance.

**The rule for choosing a reference value:** pick a piece of **standard seeded demo data that
we did NOT load ourselves** — never a record that carries one of our prefixes. A seeded
supplier like `Lee Supplies` (site `Lee US1`) is safe; a supplier named `93107RT Supplier
Good-1` is one we loaded and must never be used as a reference. Seeded reference data is
stable; our own loaded data is not.

Hard-coding keeps each fixture self-contained and readable: you can look at the template and
see exactly what it references, with nothing computed at run time.

## The frozen templates

Each object keeps its records under `../objects/{Object}/artifact/`. **These templates are the
frozen source of truth for that object's known-good and known-bad records.** A run *reads* a
template and *writes* a throwaway `{Object}_gold.zip`; it never modifies the template. To
change what a fixture loads, edit the template deliberately — a normal run will not touch it.

The known-bad row lives in the same template as the good rows. It is written to fail on a
specific, deterministic reason (an invalid lookup value, a missing required field, a reference
to something that does not exist) so that it reliably lands in the interface with a real error
and never reaches the base table.

## Running a fixture

```bash
# from gold_regression/harness/
python run_object.py Suppliers            # fresh random prefix, then load + verify
python run_object.py Suppliers --prefix 12345   # a prefix you choose
```

`run_object.py` does the whole thing in one process: stamp the prefix into the template, build
the loadable artifact, call the right load path, poll to completion, then read the base and
interface tables to confirm the good rows landed and the bad row was rejected. It prints a
summary and exits `0` on pass, non-zero on fail.

To run the same object repeatedly (each run gets its own fresh prefix, so nothing collides),
loop it — a fresh prefix every iteration is the point:

```bash
for i in 1 2 3; do python run_object.py Suppliers; done
```

## The five load paths

The harness knows five ways to get records into Fusion; each object's recipe says which one it
uses, and you rarely need to care which:

| Path | Module | Used for |
|---|---|---|
| FBDI (loadAndImportData + ESS import, poll, downstream jobs) | `load_fbdi.py` | most Financials/SCM/Projects objects |
| HDL (REST upload → createFileDataSet → poll) | `load_hdl.py` | HCM objects (Workers, Salaries, …) |
| REST create (POST the record) | `load_rest.py` | Banks |
| REST child-collection POST | `load_rest_vsv.py` | Value Set Values |
| FSM Setup-Data-Import from CSV (setupTaskCSVImports) | `load_fsm_csv.py` | setup/config objects (Lookups, UnitsOfMeasure, PaymentTerms) |

## Verifying

Verification (`verify.py`, `verify_rest.py`) is **read-only** and goes through the BIP query
relay — the same mechanism as `../../scripts/fusion_bip_query.py`. It proves three things, all
of which must hold for a pass:

- the good rows are present in the Fusion **base table**, filtered by this run's prefix;
- the bad row is present in the **interface** (or rejected by the loader) with a real error;
- the bad row is **absent** from the base table.

Reading base tables is only possible through BIP; that read-only relay is not "DMT database
involvement" and is the only allowed database touch.

## The other modules

- `conn.py` — reuses `~/workspace/conn_helper.py` for the Fusion URL and credentials. Never
  hardcode a password.
- `bip.py` — the shared read-only BIP query helper (FSCM data source; HCM tables via `hcm_impl`).
- `recipe.py` — loads an object's recipe (`../objects/{Object}/recipe.json`, or the shared
  `objects.json` for simple objects).
- `build_artifact.py` — stamps `${PREFIX}` into the template member(s) and zips the artifact.

## Credentials

Fixtures load as `fin_impl` (Financials/Projects/Procurement), `scm_impl` (SCM: Items,
Inventory), or `hcm_impl` (HCM). The load role is per object; `calvin.roth` is used only where a
procurement import job requires it (Purchase Orders / agreements). All of these read from
`connections.json` via `conn_helper` — no secrets live in this folder.

---

### Two versions (2026-07-20)

There are two object trees, and one env var picks which the harness reads/writes:

- **`../objects/` — v1, FROZEN.** The originally-proven fixtures that discover their references
  at load time (`${TOKEN}`). Left untouched; job IDs recorded in `../LOAD_EVIDENCE.json`.
- **`../objects_seeded/` — v2.** The same records with discovery replaced by hard-coded seeded
  references (this file's model). Iterate here.

```bash
python run_object.py Suppliers                              # v1 (default: objects/)
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Suppliers   # v2 (objects_seeded/)
```

The `${PREFIX}` behavior is identical in both. The difference is only whether a reference is
discovered (v1) or hard-coded to a seed value (v2).
</content>
