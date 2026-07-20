# W2Balances — v2 seeded gold fixture (HDL, balance initialization)

Converted from the frozen v1 fixture (`../../objects/W2Balances/`). Same shape — two good
balance-initialization batch lines plus one bad line — loaded through HCM Data Loader (upload →
createFileDataSet → poll) as two independent HDL business objects, and verified read-only
against the base table `PAY_BAL_BATCH_LINES`. The difference from v1: the legislative data
group name, the payroll relationship numbers, and the payroll names are **hard-coded to
standard seeded values** rather than discovered at load time. No DMT tool code and no DMT
database are in the load path.

## The two HDL business objects (unchanged from v1)

A W2 / initial payroll balance is not loaded as a bare balance. In Oracle Fusion HCM you seed
it through a **balance initialization batch**: a header, one line per (person, balance,
dimension, value), then the downstream **Load Initial Balances** ESS process converts the
accepted lines into actual balances. The two loadable objects are each their **own** top-level
`.dat` file inside the zip (they are not a header-with-child-discriminator in one file):

- **`InitializeBalanceBatchHeader.dat`** — one batch, keyed by `BatchName`.
- **`InitializeBalanceBatchLine.dat`** — the per-person values, attached to the header by
  `BatchName` (a user key, so no SourceSystemId round-trip).

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | Literal value | Confirmed seeded (read-only BIP) |
|---|---|---|
| Legislative data group name | `US Legislative Data Group` (LDG id `300000046974970`) | yes — `pay_legislative_data_groups`, no prefix |
| Good line 1 payroll relationship | `2` (payroll `Biweekly`) | yes — seeded demo employee with an assigned payroll, we never loaded it |
| Good line 2 payroll relationship | `2852` (payroll `Retail Biweekly`) | yes — seeded demo employee we never loaded |
| Bad line payroll relationship | `2854` (payroll `Retail Biweekly`) | yes — seeded demo employee we never loaded |
| Balance name | `Regular Salary` | yes — standard seeded defined balance in the US LDG |
| Balance dimension | `Core Relationship Year to Date` | yes — validated pairing with `Regular Salary` (v1 `pay_defined_balances`) |

Confirmation was run live before writing the literals: the LDG id `300000046974970` resolves to
`US Legislative Data Group`, and relationships `2` / `2852` / `2854` each return an assigned
payroll (`Biweekly`, `Retail Biweekly`, `Retail Biweekly`) through the read-only BIP relay.
These payroll relationships are seeded demo employees — this fixture never loads payroll
relationships, so none of them can be our own data. The discovery block is removed from
`recipe.json`.

## Why re-run safety is automatic here (no state trick needed)

Unlike the BenParticipant seeded fixture, this object needs no fixed-source-key or
monotonic-date device. The `${PREFIX}` sits on the **batch name** (`DMTW2${PREFIX}`), so each
run creates a **brand-new balance batch** with its own header and its own lines. There is
nothing to collide with: a later run is simply a different batch. Re-run safety is a natural
consequence of prefixing the batch name, and it is proven below by two consecutive passing
runs, each writing fresh `BATCH_LINE_ID`s under its own batch.

## The DAT files (pipe-delimited HDL, seeded literals)

**`InitializeBalanceBatchHeader.dat`**

```
METADATA|InitializeBalanceBatchHeader|LegislativeDataGroupName|BatchName|UploadDate
MERGE|InitializeBalanceBatchHeader|US Legislative Data Group|DMTW2${PREFIX}|${GL_DATE_SLASH}
```

**`InitializeBalanceBatchLine.dat`**

```
METADATA|InitializeBalanceBatchLine|LegislativeDataGroupName|BatchName|LineSequence|UploadDate|PayrollRelationshipNumber|PayrollName|BalanceName|DimensionName|Value
MERGE|InitializeBalanceBatchLine|US Legislative Data Group|DMTW2${PREFIX}|1|${GL_DATE_SLASH}|2|Biweekly|Regular Salary|Core Relationship Year to Date|1000
MERGE|InitializeBalanceBatchLine|US Legislative Data Group|DMTW2${PREFIX}|2|${GL_DATE_SLASH}|2852|Retail Biweekly|Regular Salary|Core Relationship Year to Date|2000
MERGE|InitializeBalanceBatchLine|US Legislative Data Group|DMTW2${PREFIX}NOSUCH|3|${GL_DATE_SLASH}|2854|Retail Biweekly|Regular Salary|Core Relationship Year to Date|3000
```

| Row | BatchName | PayrollRelationshipNumber | Purpose |
|---|---|---|---|
| GOOD-1 | `DMTW2${PREFIX}` (real header) | `2` (Biweekly) | valid → `PAY_BAL_BATCH_LINES` |
| GOOD-2 | `DMTW2${PREFIX}` (real header) | `2852` (Retail Biweekly) | valid → `PAY_BAL_BATCH_LINES` |
| BAD-1  | `DMTW2${PREFIX}NOSUCH` (no such header) | `2854` (Retail Biweekly) | HDL error, no line created |

**Bad-row design (the deterministic HDL error).** HDL stores each line's
`PayrollRelationshipNumber` and `BalanceName` as text and defers person/balance validation to
the downstream Load Initial Balances process — so a nonexistent person or balance name is
**not** rejected at load. The one thing HDL *does* resolve at load time is the line's parent
batch reference (`BatchName` → `BatchId`). Pointing the bad line at a batch name that does not
exist (`DMTW2${PREFIX}NOSUCH`) makes HDL fail to resolve the parent, so the line is rejected at
load and never written:

```
You need to enter a valid value for the BatchId attribute.
The current values are 300000046974970,DMTW2<prefix>NOSUCH.
```

Terminal `DataSetStatusCode` is `ORA_IN_ERROR` with load **3 ok / 1 err** (the header plus the
two good lines load; the bad line errors on purpose and creates nothing).

**Tokens still stamped** — `${PREFIX}` (the run tag, into the batch name `DMTW2<prefix>`) and
`${GL_DATE_SLASH}` (today's date `YYYY/MM/DD`, the header/line `UploadDate`). Everything else
that v1 discovered is now a literal.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

Upload → `.../dataLoadDataSets/action/uploadFile` → ContentId; submit →
`.../dataLoadDataSets/action/createFileDataSet` (`fileAction: IMPORT_AND_LOAD`) → RequestId;
poll `.../dataLoadDataSets/{RequestId}` every 30s; errors from
`.../dataLoadDataSets/{RequestId}/child/messages`. `ORA_IN_ERROR` is the EXPECTED terminal here
(the one bad line errors on purpose; the two good lines still load — partial success). A full
import+load pass takes ~3.5 minutes.

### Downstream step (documented, not in the standalone HDL load path)

The HDL load only fills the **batch** (`PAY_BAL_BATCH_HEADERS` / `PAY_BAL_BATCH_LINES`, lines at
status `U` = unprocessed). To turn the accepted lines into actual balances (`PAY_RUN_BALANCES`)
you then submit the ESS process **Load Initial Balances** (parameter: the batch name
`DMTW2<prefix>`). That is not part of this standalone fixture — the pass bar here is the
batch-line base table, the direct product of the HDL load.

## Verification (read-only, single-table read)

**Use the `PAY_BAL_BATCH_*` tables — NOT `PAY_BALANCE_BATCH_*`.** The similarly-named
`PAY_BALANCE_BATCH_*` replica is stale by months in this BIP relay (its `MAX(creation_date)` was
frozen at 2026-04-14). The live current tables are `PAY_BAL_BATCH_HEADERS` /
`PAY_BAL_BATCH_LINES`. Direct read of `PAY_BAL_BATCH_LINES` joined to its header on this run's
batch name `DMTW2<prefix>`; a `BATCH_LINE_ID` present for each good `PayrollRelationshipNumber`
= pass. The bad evidence is the load-time HDL message carrying the *"valid value for the
BatchId attribute"* rejection for file line 4, plus the bad line's absence from the base read.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (naturally re-run safe).**

Standalone HDL load path only; verification via the read-only BIP relay only.

### Run 1

| Field | Value |
|---|---|
| Prefix | `60133` (batch name `DMTW260133`) |
| HDL UCM ContentId | `UCMFA07639929` |
| HDL data set RequestId | `9766639` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |
| Import / Load counts | import 4 ok / 0 err; load **3 ok / 1 err** |

Good → base `PAY_BAL_BATCH_LINES` (2/2): PRN `2` → `BATCH_LINE_ID` `300000331573921`
(Regular Salary, Val 1000, status U); PRN `2852` → `300000331573924` (Regular Salary, Val 2000,
status U).
Bad → HDL error, no line: file line 4 (`DMTW260133NOSUCH`, PRN `2854`) →
`You need to enter a valid value for the BatchId attribute. The current values are
300000046974970,DMTW260133NOSUCH.` — absent from base.

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `41088` (batch name `DMTW241088`) |
| HDL data set RequestId | `9766736` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |

Good → base `PAY_BAL_BATCH_LINES` (2/2): PRN `2` → **new** `BATCH_LINE_ID` `300000331574288`
(Val 1000); PRN `2852` → **new** `300000331574285` (Val 2000). Fresh batch, fresh line ids —
the prefix on the batch name makes each run an independent batch. Bad row errored the same way
(`DMTW241088NOSUCH`).

Both runs reached the base table on seeded demo employees; the bad line (nonexistent parent
batch) errored in the loader and created nothing. **Re-runs work naturally** — a new prefix is a
new batch, so nothing collides; no fixed-key or date device is needed for this object.

## Harness note

No harness code change was needed. The recipe uses the existing generic HDL path
(`run_object.py` → build → `load_hdl` → `verify`), the existing `members` (multi-`.dat` zip)
and `bad_error_contains` (SourceSystemId-less HDL error match) mechanisms. The only
object-specific pieces are `recipe.json` (verify SQL against `PAY_BAL_BATCH_LINES`,
`bad_error_contains`, no discovery block) and the two seeded `.dat` templates.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py W2Balances
# run it again immediately — the prefixed batch name makes the second run a brand-new
# batch, so it passes again with fresh batch-line ids
```
