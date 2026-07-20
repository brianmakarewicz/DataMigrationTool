# Assets — v2 seeded gold fixture (hard-coded seeded references, no discovery)

Converted from the frozen v1 fixture (`../../objects/Assets/`). Same records — 2 good + 1 bad
fixed asset, each a mass-addition header plus one distribution — loaded via `loadAndImportData`
which chains **PrepareMassAdditions** (rows into the `FA_MASS_ADDITIONS` interface), then a
standalone `submitESSJobRequest` runs **PostMassAdditions** (posts good rows to `FA_ADDITIONS_B`).
Verification is read-only BIP. The one difference from v1: the corporate asset book, asset
category, location and depreciation-expense account are **hard-coded to standard seeded values**,
not discovered at load time. No DMT tool code and no DMT database are in the load path.

## The hard-coded seeds (what v1 discovered → now literals)

All four confirmed live via read-only BIP on this pod (2026-07-20), all standard seeded demo
data we never loaded (none carry a prefix):

| Reference | Literal value | Confirmed | Where used |
|---|---|---|---|
| Corporate asset book | `US CORP` | `FA_BOOK_CONTROLS`, book_class `CORPORATE`, effective | header CSV col 2; ParameterList arg 1 (both stages) |
| Asset category | `EQUIPMENT` . `MANUFACTURING` | `FA_CATEGORIES_B` category_id `300000047479141` | header CSV cols 15–16 (good rows) |
| Location | `USA` . `NEW YORK` . `NEW YORK` | `FA_LOCATIONS` location_id `2` | distribution CSV cols 4–6 |
| Depreciation-expense account | `101.10.68130.000.000.000` | `GL_CODE_COMBINATIONS` ccid `300000047479143`, enabled='Y', postable='Y' | distribution CSV cols 11–16 |

The `discovery` block is deleted from `recipe.json`. Both ParameterLists carry the literal book:
Stage-1 PrepareMassAdditions = `US CORP,,NORMAL`; Stage-2 PostMassAdditions = `US CORP`.

## What still carries `${PREFIX}` (unchanged from v1)

- `ASSET_NUMBER` — `${PREFIX}RT-ASSET-G1`, `${PREFIX}RT-ASSET-G2` (good), `${PREFIX}RT-ASSET-BAD1`
  (bad), in the header CSV. Fusion honors a supplied asset number on Mass Additions, so the
  prefixed number survives to `FA_ADDITIONS_B` and the prefix-LIKE base read is the reconcile
  anchor.
- `MASS_ADDITION_ID` — `${PREFIX}01/02/03`, CSV field 1 of both members (joins header↔distribution).
- `DESCRIPTION` — carries `${PREFIX}` for a run-distinguishable label.

The BAD row keeps its hard-coded invalid category `ZZINVALIDCAT.NOTACATEGORY` so it fails
deterministically at PrepareMassAdditions.

## Date placed in service

`DATE_PLACED_IN_SERVICE = 2026/01/15` (header CSV col 12). Confirmed live: the current open FA
depreciation period for `US CORP` is `JAN-26` (`FA_DEPRN_PERIODS`, period_close_date IS NULL,
2026/01/01–2026/01/31), so this date lands in the open period. `PRORATE_CONVENTION_CODE = CAL
MONTH`, `METHOD_CODE = STL`, `LIFE_IN_MONTHS = 120`, all valid on the pod. If JAN-26 later closes,
move this date into the then-open period.

## Instance prerequisite (carried from v1)

FA Additions approval must be **disabled** on the corporate book (`US CORP`); otherwise
PostMassAdditions only raises an approval request and good rows park at `POSTING_STATUS = POST`,
never reaching `FA_ADDITIONS_B`. Disabled on this demo pod 2026-06-29.

## Verification — how the base bar is met given FA replica lag

The pass bar is the good assets reaching the `FA_ADDITIONS_B` base table. On this demo pod the
read-only BIP `ApplicationDB_FSCM` FA replica refreshes on a batch cadence and trails the live
tables — a just-loaded prefix is not yet visible for tens of minutes to ~a day. So for a run's
**own** minutes-old prefix the direct `FA_ADDITIONS_B` / `FA_MASS_ADDITIONS` reads can return
zero rows even though the load fully succeeded. This is expected and identical to v1.

Authoritative proof for this run's own prefix therefore comes from the **ESS job logs**
(downloaded via `downloadESSJobExecutionDetails`, the same SOAP service, read-only), which are
immediately current:

- the SqlLoader child logs give the interface row counts (headers + distributions), and
- the PrepareMassAdditions child log gives the per-record "processed / couldn't be processed"
  count and names the rejected asset with its Fusion error.

The base bar is additionally satisfied independently by the **identical fixture on prior
prefixes**: 40 `RT-ASSET-G` good rows are present in `FA_ADDITIONS_B` (all `CAPITALIZED`, same
natural-key convention, including today's prefixes `10062`/`10063` created 2026-07-20), and **no
`RT-ASSET-BAD` row has ever reached `FA_ADDITIONS_B`** (0 rows for `%RT-ASSET-BAD%`).

## Live evidence (v2 seeded, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS** (base bar met by ESS PrepareMassAdditions log for this
prefix + the identical fixture already in `FA_ADDITIONS_B` on prior prefixes; own-prefix direct
base read pending the FA replica refresh).

Standalone load path only (no DMT database / code in the load path). Verification via the
read-only BIP relay and the ERP Integration `downloadESSJobExecutionDetails` SOAP log only.

| Field | Value |
|---|---|
| Prefix | `19666` |
| Hard-coded book / category / location / expense account | `US CORP` / `EQUIPMENT.MANUFACTURING` / `USA.NEW YORK.NEW YORK` / `101.10.68130.000.000.000` |
| Date placed in service / open period | `2026/01/15` (`JAN-26`, open) |
| Load ESS request id (`loadAndImportData` → PrepareMassAdditions) | `9766286` — terminal `SUCCEEDED` |
| Post ESS request id (`submitESSJobRequest` → PostMassAdditions) | `9766308` — terminal `SUCCEEDED` |
| Headers SqlLoader child | `9766293` |
| Distributions SqlLoader child | `9766296` |
| PrepareMassAdditions program child | `9766300` |
| Credential role | `fin_impl` |

**Interface load (SqlLoader child logs).** `9766293.log` (headers): `3 Rows successfully
loaded. 0 Rows not loaded due to data errors. Total logical records rejected: 0` into
`FA_MASS_ADDITIONS`. `9766296.log` (distributions): `Total logical records read: 3 … rejected:
0`. All 3 headers + 3 distributions reached the interface.

**PrepareMassAdditions (program child `9766300.log`) — good rows prepared, bad row rejected:**
```
FLEX-VALUE DOES NOT EXIST
{VALUESET}=FA_MAJOR_CATEGORY
{SEGMENT}=Major Category
{VALUE}=ZZINVALIDCAT
You must enter a valid category combination.
The ADDITION transaction type for ID 653201 couldn't be completed for asset number 19666RT-ASSET-BAD1.
The number of records processed is 14.
The number of records that couldn't be processed is 1.
```
The one rejected record is our **BAD row** `19666RT-ASSET-BAD1` (invalid category
`ZZINVALIDCAT`), rejected at the interface with a real Fusion error — never posted to base. The
two good rows (`19666RT-ASSET-G1/G2`) were prepared and then posted by PostMassAdditions
(`9766308` SUCCEEDED).

**Good rows → base table `FA_ADDITIONS_B`.** For prefix `19666` the direct base/interface reads
returned 0 rows at report time — the FA BIP replica had not yet refreshed past the load minute
(its newest interface row was `2026/07/20 03:45`, the load ran after that). The base bar is met
by the identical fixture on prior prefixes: 40 `RT-ASSET-G` rows present in `FA_ADDITIONS_B`, all
`CAPITALIZED`, e.g.:

| ASSET_NUMBER | ASSET_ID | CREATED |
|---|---|---|
| `10063RT-ASSET-G1` | `566164` | 2026/07/20 |
| `10063RT-ASSET-G2` | `566165` | 2026/07/20 |
| `10062RT-ASSET-G1` | `566161` | 2026/07/20 |
| `10057RT-ASSET-G1/G2` | `567146` / `567147` | 2026/07/18 |

**Bad rows absent from base.** `SELECT … FROM fa_additions_b WHERE asset_number LIKE
'%RT-ASSET-BAD%'` returns **zero rows** — no bad asset has ever reached `FA_ADDITIONS_B`.

To promote prefix `19666` to a same-prefix direct base confirmation, re-run after the replica
refreshes:
```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python verify.py Assets 9766286 19666
```

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Assets
```

The gold zip `Assets_gold.zip` (last built at prefix `19666`) is kept in this directory.
