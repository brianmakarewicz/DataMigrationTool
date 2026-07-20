# PaymentTerms (v2 seeded) — artifact manifest

The load artifact is `PaymentTerms_gold.zip`, built at run time by
`run_paymentterms_fsm.py`. It contains **five files at the root of the zip** (a flat-CSV
FSM object — not nested in a batch subzip). The build stamps `${PREFIX}` into the four
CSV members; the manifest XML is copied verbatim.

| Member (zip root) | Templated? | Role |
|---|---|---|
| `AP_TERM_HEADER.csv` | `${PREFIX}` (Name) | The term header → `AP_TERMS_B` / `AP_TERMS_TL`. Two good terms `GldRegTerm ${PREFIX} A` (STD) and `GldRegTerm ${PREFIX} B`, plus bad `GldRegTerm ${PREFIX} BAD`. |
| `AP_TERM_LINE.csv` | `${PREFIX}` (FK Name) | Installment lines → `AP_TERMS_LINES`. One line each: A = 100% / 30 days, B = 100% / 45 days. FK column `AP_TERM_HEADER.Name`. |
| `AP_TERM_HEADER_TRANSLATION.csv` | `${PREFIX}` (FK + Name) | US name/description → `AP_TERMS_TL`. FK `AP_TERM_HEADER.Name`. |
| `AP_TERM_SUBSCRIPTION.csv` | `${PREFIX}` (FK Name only) | Reference-set assignment. Good rows hard-code seeded `SetCode = COMMON`; bad row names `ZZ_NO_SUCH_SET` (no such set). FK `AP_TERM_HEADER.Name`. |
| `ASM_SETUP_CSV_METADATA.xml` | no | Real exported manifest, `ProcessType` flipped `EXPORT`→`IMPORT`. Declares the four business objects, node paths, and `PaymentTermHeaderVO`. Copied verbatim. |

**CSV format:** comma-delimited, every field double-quoted, CRLF line ends, header row
present, dates `YYYY/MM/DD`.

## Seeded references (hard-coded, not discovered)

The one upstream reference a payment term needs is the **reference data set** it subscribes
to. In v1 this was described as "discovered" but the CSV already carried a literal; v2 pins
it as a seed and deletes the discovery block:

| Value | Where | What it is |
|---|---|---|
| `COMMON` | `AP_TERM_SUBSCRIPTION.csv` → `SetCode` (good rows) | The standard seeded reference data set on every demo pod (`FND_SETID_SETS_VL` SET_CODE `COMMON`, SET_NAME "Common Set"; 22 seeded subscriptions in the live export). We did **not** load it; it carries no prefix. Confirmed seeded via read-only BIP on 2026-07-20. The FSM importer resolves `SetCode` → `SetId`. |

The bad row deliberately names `ZZ_NO_SUCH_SET` (a set that does not exist) so the importer
cannot resolve a `SetId` and rejects that term. No `${TOKEN}` discovery remains; the only
templated token is `${PREFIX}` on the term Name.

## Run

```bash
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/PaymentTerms/run_paymentterms_fsm.py
GOLD_OBJECTS_SUBDIR=objects_seeded python objects_seeded/PaymentTerms/run_paymentterms_fsm.py --prefix 90333
```
