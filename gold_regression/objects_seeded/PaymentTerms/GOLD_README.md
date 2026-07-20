# PaymentTerms — Gold Regression Fixture (v2 seeded — PASS, live to base tables)

**Result: PASS (2026-07-20).** This is the v2 "seeded" conversion of `../objects/PaymentTerms/`
(v1, frozen). It loads Payables Payment Terms live to the Fusion base tables `AP_TERMS_B` /
`AP_TERMS_TL` / `AP_TERMS_LINES` through the Functional Setup Manager (FSM) "Setup Data Import
from CSV file" REST resource `setupTaskCSVImports`, TaskCode `AP_MANAGE_PAYMENT_TERMS`, credential
role `fin_impl`. Two consecutive runs both reached base cleanly.

## What "v2 seeded" changed from v1

The v2 rule is: replace any load-time discovery with a hard-coded standard seeded value.

For Payment Terms there was effectively nothing to discover. A payment term's only upstream
reference is the **reference data set** it subscribes to, and v1's CSV already carried the
literal `COMMON` — the "discovery" entry in v1's `recipe.json` was descriptive, not an actual
`${TOKEN}` substitution. The conversion therefore:

- **Deleted** the `discovery` block from `recipe.json` (replaced by a `seeded_references`
  entry that pins `SetCode = COMMON`).
- **Confirmed `COMMON` is seeded** (not something we loaded, and no prefix) via read-only BIP:
  `FND_SETID_SETS_VL` returns SET_CODE `COMMON`, SET_NAME "Common Set"; the bad set
  `ZZ_NO_SUCH_SET` returns nothing.
- **Kept `${PREFIX}` exactly as in v1**, on the term **Name** (`GldRegTerm ${PREFIX} A/B/BAD`).
  The runner stamps a fresh prefix each run, so new terms never collide — they are naturally
  re-runnable by distinct name.

The artifact CSVs are the v1 members with `${PREFIX}` restored into the names (v1's frozen
copies had a run prefix baked in); the manifest `ASM_SETUP_CSV_METADATA.xml` is copied verbatim.

## The package shape

Five flat files at the zip root (no nested batch zip). A payment term is four related record
types, all keyed back to the header by term Name:

```
ASM_SETUP_CSV_METADATA.xml        (manifest; ProcessType EXPORT->IMPORT; copied verbatim)
AP_TERM_HEADER.csv                (the term: Name, EnabledFlag, Type=STD, StartDateActive, Description)
AP_TERM_LINE.csv                  (installment lines: FK Name, SequenceNum, DuePercent, DueDays)
AP_TERM_HEADER_TRANSLATION.csv    (US name/description: FK Name, Name, Description, Language, SourceLang)
AP_TERM_SUBSCRIPTION.csv          (reference-set assignment: FK Name, SetCode)
```

CSV format: header row, comma-separated, every value double-quoted, CRLF, dates `YYYY/MM/DD`.

## Good / bad design (seeded, portable)

- **Good:** two NEW terms — `GldRegTerm ${PREFIX} A` (net-30, one line `DuePercent=100, DueDays=30`)
  and `GldRegTerm ${PREFIX} B` (net-45, `DuePercent=100, DueDays=45`), each subscribed to the
  seeded reference set `COMMON`. The run `${PREFIX}` lives in the term **Name** (how we verify).
- **Bad:** a NEW term `GldRegTerm ${PREFIX} BAD` whose subscription names `SetCode =
  ZZ_NO_SUCH_SET`, a reference set that does not exist. The importer cannot resolve it to a
  `SetId`, rejects the whole term deterministically, and it never reaches `AP_TERMS_B`.
  Pod-independent.

## How it is run (honors GOLD_OBJECTS_SUBDIR)

`run_object.py` only routes FBDI and HDL, so this FSM object is driven by the small runner
`run_paymentterms_fsm.py` in this folder — the same pattern as `../Lookups/run_lookups_fsm.py`.
It reads the artifact from `objects_seeded/PaymentTerms/artifact/` (via the harness's
`object_dir`, which honors `GOLD_OBJECTS_SUBDIR`), stamps `${PREFIX}` into the four CSVs, zips
the five root files, submits through the shared `harness/load_fsm_csv.py` driver (`fin_impl`),
polls to completion, then verifies read-only through the shared BIP relay.

```bash
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/PaymentTerms/run_paymentterms_fsm.py
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/PaymentTerms/run_paymentterms_fsm.py --prefix 90333
```

## Live evidence (base-table pass)

| Item | Run 1 | Run 2 (consecutive) |
|---|---|---|
| Date | 2026-07-20 | 2026-07-20 |
| Prefix | 83810 | 97334 |
| Reference set (good) | `COMMON` (seeded, hard-coded) | `COMMON` |
| Good term A (net-30) | `AP_TERMS_B` TERM_ID **300000331550466**, line 100% / 30 days | TERM_ID **300000331574575**, 100% / 30 days |
| Good term B (net-45) | `AP_TERMS_B` TERM_ID **300000331550467**, line 100% / 45 days | TERM_ID **300000331574576**, 100% / 45 days |
| Bad term | `GldRegTerm 83810 BAD` (SetCode `ZZ_NO_SUCH_SET`) | `GldRegTerm 97334 BAD` |
| **Bad error** | `JBO-27024: Failed to validate a row ... in PaymentTermSubscriptionEO / JBO-27014: Attribute SetId in PaymentTermSubscriptionEO is required` | same |
| Bad in base? | **No** — absent from `AP_TERMS_TL`/`AP_TERMS_B` | **No** |
| Import ProcessId / ESS | `100007867616149` / `9766671` | `100007867616187` / `9766708` |
| ProcessLog | "A total of 3 rows were processed. 1 rows of them failed" | same |

## Second-run note (re-runnability)

Two consecutive runs both loaded to base with no collision. Each run stamps a fresh `${PREFIX}`
into the term Name, so the new terms have distinct names every time and never conflict with
data already in Fusion. Run 1 (prefix 83810) produced TERM_IDs …550466/…550467; run 2 (prefix
97334) produced distinct TERM_IDs …574575/…574576. No reset or cleanup is needed between runs.

## Verify SQL (read-only BIP, fin_impl)

Good terms reached base (expect 2 rows with real ids):
```sql
SELECT t.NAME AS TERM_NAME, b.TERM_ID AS TERM_ID
FROM   AP_TERMS_B b
JOIN   AP_TERMS_TL t ON t.TERM_ID = b.TERM_ID
WHERE  t.LANGUAGE = 'US' AND t.NAME LIKE 'GldRegTerm ${PREFIX}%';
```
Bad term absent (rejection proof — expect zero rows):
```sql
SELECT t.NAME FROM AP_TERMS_TL t
WHERE  t.LANGUAGE = 'US' AND t.NAME = 'GldRegTerm ${PREFIX} BAD';
```

## Files

- `recipe.json` — machine-readable v2 seeded recipe: task, import body, poll paths, CSV columns,
  `seeded_references` (COMMON pinned), good/bad design, verify SQL, live evidence for both runs.
- `run_paymentterms_fsm.py` — the standalone FSM runner (honors `GOLD_OBJECTS_SUBDIR`).
- `MANIFEST.md` — the artifact member table and seeded-reference note.
- `artifact/` — the five package members (four templated CSVs + verbatim manifest).
- `PaymentTerms_gold.zip` — the last built import package (throwaway; rebuilt each run).
