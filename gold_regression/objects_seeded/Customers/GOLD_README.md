# Customers — v2 seeded gold fixture (FBDI, async HZ import batch)

Converted from the frozen v1 fixture (`../../objects/Customers/`). Same two good + one bad
customer, loaded as ONE FBDI zip carrying the SEVEN HZ interface CSVs (parties, locations,
party sites, party site uses, accounts, account sites, account site uses) via
`loadAndImportData`, which chains **Import Bulk Customer Data** (`CDMAutoBulkImportJob`).
Verification is read-only via the BIP relay. The difference from v1: the Trading Community
**source system** and the **business unit** are **hard-coded to standard seeded values**,
not discovered at load time.

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | Token in v1 | Literal in v2 | Confirmed seeded |
|---|---|---|---|
| TCA source system (orig_system) | `${ORIG_SYSTEM}` | `LEG1` | `HZ_ORIG_SYSTEMS_B`: SPOKE, STATUS `A`, `ENABLE_FOR_TCA_FLAG='Y'`, created 2013-10-29 by SCM_IMPL — a seed process, we never loaded it |
| Business unit name | `${BU_NAME}` | `US1 Business Unit` | `FUN_ALL_BUSINESS_UNITS_V`: bu_id `300000046987012`, has a primary ledger |

Both were confirmed live via read-only BIP before conversion. `LEG1` is a registered,
TCA-enabled SPOKE source system that ships in every demo pod (this is why column 2 of every
CSV must be a registered orig_system — the old byte-template's unregistered `DMT` rejected
every party with `HZ_INVALID_ORIG_SYSTEM`). `US1 Business Unit` is the standard seeded demo
BU used for the account site / account site use rows.

Both literals also appear in the import ParameterList (position 2 batch name `Batch ID
${PREFIX} LEG1`, position 4 source system `LEG1`). `${BU_ID}` was never referenced by any CSV
in v1, so it is not carried here.

`${PREFIX}` stays exactly as in v1 on every new-record key: the party refs
(`${PREFIX}RT-CUST-{G1,G2,BAD1}`), locations, party sites, account refs, account site refs,
and the account numbers (`${PREFIX}{G001,G002,BAD01}`) — plus batch id (`${PREFIX}`) in the
ParameterList and column 1 of every CSV. The discovery block is deleted from `recipe.json`.

## The three records

| Row | Party ref | Account number | Party type | Expected |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-CUST-G1` | `${PREFIX}G001` | `ORGANIZATION` | reaches `HZ_CUST_ACCOUNTS` |
| GOOD-2 | `${PREFIX}RT-CUST-G2` | `${PREFIX}G002` | `ORGANIZATION` | reaches `HZ_CUST_ACCOUNTS` |
| BAD-1  | `${PREFIX}RT-CUST-BAD1` | `${PREFIX}BAD01` | `INVALID_TYPE` | rejected in `HZ_IMP_PARTIES_T`, never reaches base |

## The async HZ import batch (important operational note)

`loadAndImportData` returns SUCCEEDED once the interface load and the import submission
complete, but **Import Bulk Customer Data then processes the batch asynchronously.** The
batch appears in `HZ_IMP_BATCH_SUMMARY` (`BATCH_NAME = 'Batch ID <prefix> LEG1'`) and works
from `PROCESSING` to a terminal `COMPLETED` / `COMPL_ERRORS`. The base rows and the
`HZ_IMP_ERRORS` rejections appear only once the batch leaves `PROCESSING`.

Consequence for the harness: a single `run_object.py` invocation polls only the load request
and returns while the HZ batch is still `PROCESSING`, so its inline verify shows
`good_in_base_count 0` and `pass:false`. This is expected for this object (the same limitation
is documented in v1's GOLD_README). Wait for the batch to leave `PROCESSING`, then re-verify:

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Customers   # loads; inline verify may show pass:false (batch still PROCESSING)
# poll HZ_IMP_BATCH_SUMMARY.BATCH_STATUS for the run's prefix until it is no longer PROCESSING/QUEUED
GOLD_OBJECTS_SUBDIR=objects_seeded python verify.py Customers <LOAD_REQUEST_ID> <PREFIX>   # -> pass:true
```

On the proven run below the batch took ~2–3 minutes to reach `COMPL_ERRORS`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database / code in the load path); verification via the
read-only BIP relay only.

| Field | Value |
|---|---|
| Prefix | `50347` |
| Hard-coded source system / BU | `LEG1` / `US1 Business Unit` (`300000046987012`) |
| Load ESS request id (`loadAndImportData` result) | `9766178` |
| Load terminal status (`getESSJobStatus`) | `SUCCEEDED` |
| HZ import batch | `HZ_IMP_BATCH_SUMMARY` batch id `50347`, name `Batch ID 50347 LEG1` |
| Batch terminal status | `COMPL_ERRORS` (good imported, bad errored — expected mixed outcome) |
| Credential role | `fin_impl` |

**Good rows → base table `HZ_CUST_ACCOUNTS` (2/2):**

| ACCOUNT_NUMBER | CUST_ACCOUNT_ID |
|---|---|
| `50347G001` | `100002547479716` |
| `50347G002` | `100002547479717` |

**Bad row → interface rejection, absent from base (1/1):**

| Account | Rejection (`HZ_IMP_ERRORS`, `HZ_IMP_PARTIES_T`) |
|---|---|
| `50347BAD01` (party `50347RT-CUST-BAD1`, type `INVALID_TYPE`) | `HZ_IMP_PARTY_TYPE_ERROR`; `HZ_PRTY_PUA_INVALID_TYPE`; `HZ_IMP_PARTY_NAME_ERROR` |

The bad account is absent from `HZ_CUST_ACCOUNTS`.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Customers
# then wait for the HZ batch and re-verify as shown in the async-batch note above
```
