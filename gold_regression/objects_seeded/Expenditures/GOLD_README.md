# Expenditures — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/Expenditures/`). Same two good +
one bad project cost transactions (NONLABOR), loaded via a two-step FBDI flow
(`loadAndImportData` to stage, then the **Import and Process Cost Transactions** ESS job),
with read-only BIP verification. The one difference from v1: every upstream reference is
**hard-coded to standard seeded values**, not discovered at load time.

## The hard-coded seeds (what v1 discovered -> now literals)

v1 discovered a chargeable project/task, an expenditure type/org, a transaction source and
its document. On this pod they resolved to the values below. All are standard seeded demo
data we never loaded (none carry an RT prefix), confirmed live via read-only BIP on
2026-07-20:

| Reference | Literal value | Where used |
|---|---|---|
| Business Unit name | `US1 Business Unit` | CSV NONLABOR col 2 |
| Business Unit id | `300000046987012` | ParameterList arg 2 (`${BU_ID}` -> literal) |
| Transaction source | `External Miscellaneous` | CSV col 4 |
| Transaction source id | `300000049907116` | ParameterList arg 6 (`${TXN_SOURCE_ID}` -> literal) |
| Document name / entry | `Miscellaneous` | CSV cols 6 & 8 |
| Document id | `300000049907117` | ParameterList arg 7 (`${DOCUMENT_ID}` -> literal) |
| Project number | `PCS10037` | CSV col 19 |
| Task number | `5.2` | CSV col 22 |
| Expenditure type | `Airfare` | CSV col 25 (good rows) |
| Expenditure org | `Consulting North US` | CSV col 27 |
| Unit of measure | `DOLLARS` | CSV col 35 |

`${PREFIX}` stays only on the two new keys: `ORIG_TRANSACTION_REFERENCE` (CSV position 40)
and the per-row unique `BATCH_NAME` (CSV NONLABOR position 10), both set to
`${PREFIX}RT-EXP-*`. The unique batch is mandatory — with an empty batch the good rows
collide with each other and are all rejected on `PJC_UNIQUE_BATCH_NAME`. The
`EXPENDITURE_ITEM_DATE` and `GL_DATE` use the derived token `${GL_DATE_SLASH}` (today, in
`YYYY/MM/DD`) so the rows always land in an open period without discovery. The discovery
block is removed from `recipe.json`.

## ESS orchestration (unchanged from v1)

Two steps, not one call:

1. `loadAndImportData` (interfaceDetails=20, doc account `prj/projectCosting/import`,
   `fin_impl`) stages `PjcTxnXfaceStageAll.csv` into `PJC_TXN_XFACE_STAGE_ALL` at status
   `P`. It does NOT chain the costing import on this product.
2. A separate `submitESSJobRequest` for **Import and Process Cost Transactions**
   (`onestop,ImportAndProcessTxnsJob`, 10-arg positional) validates + costs: accepted rows
   move to base `PJC_EXP_ITEMS_ALL`; rejected rows are purged from staging.

Use `ImportAndProcessTxnsJob` (10-arg), NOT `ImportProcessParallelEssJob` (13-arg, which
ORA-06502s on this pod). ParameterList (all seed ids as literals):

```
IMPORT_AND_PROCESS~300000046987012~ALL~#NULL~#NULL~300000049907116~300000049907117~#NULL~#NULL~#NULL
```

## Rows

| Key (ORIG_TRANSACTION_REFERENCE) | Expenditure type | Cost | Expected |
|---|---|---|---|
| `${PREFIX}RT-EXP-G1` | `Airfare` (valid) | 125 | -> `PJC_EXP_ITEMS_ALL` |
| `${PREFIX}RT-EXP-G2` | `Airfare` (valid) | 250 | -> `PJC_EXP_ITEMS_ALL` |
| `${PREFIX}RT-EXP-BAD1` | `ZZ-BAD-EXPTYPE-99` (invalid) | 500 | rejected `PJC_EXP_TYPE_INVALID`, absent from base |

## Verification (read-only)

Good -> base: direct read of `PJC_EXP_ITEMS_ALL` by prefix; both `-G1`/`-G2` present with a
real `EXPENDITURE_ITEM_ID` = pass. Bad -> proof-by-absence: the import purges rejected rows
from staging on this pod, so the bad key is proven rejected by its ABSENCE from base while
the two good rows from the SAME import reached base. The per-row message
(`PJC_EXP_TYPE_INVALID` / `VALIDATIONS`) lives only in the Import-Costs report XML. Recipe
declares `bad_proof_is_absence: true`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

| Field | Value |
|---|---|
| Prefix | `30180` |
| Load ESS request id | `9766261` (SUCCEEDED) |
| Import ESS request id | `9766304` (`onestop,ImportAndProcessTxnsJob`, SUCCEEDED) |
| Credential role | `fin_impl` |
| Hard-coded refs | project `PCS10037` / task `5.2`, exp type `Airfare`, org `Consulting North US`, BU `US1 Business Unit` (300000046987012), source `External Miscellaneous` (300000049907116) / document `Miscellaneous` (300000049907117), UOM `DOLLARS` |

Good rows -> base `PJC_EXP_ITEMS_ALL` (2/2):

| ORIG_TRANSACTION_REFERENCE | EXPENDITURE_ITEM_ID | Cost |
|---|---|---|
| `30180RT-EXP-G1` | `750730` | 125 |
| `30180RT-EXP-G2` | `750731` | 250 |

Bad row -> rejected, absent from base (1/1): `30180RT-EXP-BAD1` does not appear in
`PJC_EXP_ITEMS_ALL` (rejected on invalid expenditure type `ZZ-BAD-EXPTYPE-99`,
`MESSAGE_NAME=PJC_EXP_TYPE_INVALID`). The harness `verify.py` returned `"pass": true`.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Expenditures
```
