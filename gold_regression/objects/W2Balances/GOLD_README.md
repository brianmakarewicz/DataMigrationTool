# W2Balances — gold regression fixture (HDL, balance initialization)

A standalone, reloadable **HDL** fixture (2 good rows + 1 bad row) that loads
payroll **balance-initialization** batch lines for existing employees through the
HCM Data Loader REST service (upload → createFileDataSet → poll), verified
read-only via BIP against the base table `PAY_BAL_BATCH_LINES`. No DMT tool code
and no DMT database are in the load path.

## What "W2 balance" / balance initialization means for a portable gold fixture

A W2 balance (an accumulated payroll balance such as taxable earnings withheld
year-to-date) is not loaded as a bare balance. In Oracle Fusion HCM you seed
initial balance values through a **balance initialization batch**: you create a
batch header, add one line per (person, balance, dimension, value), and then run
the **Load Initial Balances** process, which converts the accepted batch lines
into actual balances.

The loadable, data-carrying pieces are therefore two HDL business objects:

- **`InitializeBalanceBatchHeader`** — one batch, keyed by `BatchName`.
- **`InitializeBalanceBatchLine`** — the per-person balance values, each line
  attached to the header by `BatchName`.

Each line references:

- an **existing employee payroll relationship** (by `PayrollRelationshipNumber`),
- the person's **existing payroll** (by `PayrollName`),
- an **existing balance name** (`Regular Salary`) and a **balance dimension**
  (`Core Relationship Year to Date`) that the balance is defined for, and
- the **legislative data group** (`US Legislative Data Group`).

Nothing is created upstream. There is **no dependency on our earlier Workers,
Salaries, or PayrollRelationships loads** — the persons, their payroll
relationships, the payroll definitions, and the balance/dimension definitions all
already ship on the pod.

## Two separate .dat files, not a parent+child in one file (the key correction)

The prior audit (`v2_audit.md`) tried 16+ single-file names
(`PayrollBalanceInitialization.dat`, `BalanceAdjustment.dat`, …) and every one was
rejected. The reason: **`InitializeBalanceBatchHeader` and
`InitializeBalanceBatchLine` are two independent top-level HDL business objects,
each delivered as its OWN .dat file inside the zip.** They are not a
header-with-child-discriminator in a single file.

- Putting the `InitializeBalanceBatchLine` METADATA line inside
  `InitializeBalanceBatchHeader.dat` is rejected with *"The
  InitializeBalanceBatchLine component discriminator isn't valid. The line with the
  METADATA instruction needs to include a discriminator that's supported by the
  InitializeBalanceBatchHeader object."*
- The DMT generator `DMT_W2_BAL_HDL_GEN_PKG` emits a different, wrong pair of
  objects (`BalanceInitialization` + `BalInitializationDetails`) in a single
  `PayrollBalanceInitialization.dat`. That is the source of the old blocker. The
  correct objects for a US demo pod are the `InitializeBalanceBatch*` pair. (The
  generator is reference-only here; this fixture does not use or modify it.)

So `W2Balances_gold.zip` contains **two** members:

```
InitializeBalanceBatchHeader.dat
InitializeBalanceBatchLine.dat
```

The line file references the header purely by `BatchName` (a user key), so no
SourceSystemId round-trip is needed and the fixture is fully portable.

## The DAT files (pipe-delimited HDL)

**`InitializeBalanceBatchHeader.dat`** — one batch, name stamped with the prefix:

```
METADATA|InitializeBalanceBatchHeader|LegislativeDataGroupName|BatchName|UploadDate
MERGE|InitializeBalanceBatchHeader|${LDG_NAME}|DMTW2${PREFIX}|${GL_DATE_SLASH}
```

**`InitializeBalanceBatchLine.dat`** — two good lines + one bad line:

```
METADATA|InitializeBalanceBatchLine|LegislativeDataGroupName|BatchName|LineSequence|UploadDate|PayrollRelationshipNumber|PayrollName|BalanceName|DimensionName|Value
MERGE|InitializeBalanceBatchLine|${LDG_NAME}|DMTW2${PREFIX}|1|${GL_DATE_SLASH}|${PRN1}|${PAY1}|Regular Salary|Core Relationship Year to Date|1000
MERGE|InitializeBalanceBatchLine|${LDG_NAME}|DMTW2${PREFIX}|2|${GL_DATE_SLASH}|${PRN2}|${PAY2}|Regular Salary|Core Relationship Year to Date|2000
MERGE|InitializeBalanceBatchLine|${LDG_NAME}|DMTW2${PREFIX}NOSUCH|3|${GL_DATE_SLASH}|${PRN3}|${PAY3}|Regular Salary|Core Relationship Year to Date|3000
```

| Row | BatchName | PayrollRelationshipNumber | Purpose |
|---|---|---|---|
| GOOD-1 | `DMTW2${PREFIX}` (real header) | `${PRN1}` (discovered) | valid → `PAY_BAL_BATCH_LINES` |
| GOOD-2 | `DMTW2${PREFIX}` (real header) | `${PRN2}` (discovered) | valid → `PAY_BAL_BATCH_LINES` |
| BAD-1  | `DMTW2${PREFIX}NOSUCH` (no such header) | `${PRN3}` (discovered) | HDL error, no line created |

**Bad-row design (the deterministic HDL error).** HDL for this batch loader stores
each line's `PayrollRelationshipNumber` and `BalanceName` *as text* and defers
person/balance validation to the downstream Load Initial Balances process — so a
nonexistent balance name or a nonexistent person number is **not** rejected at load
(it lands in the batch line with status `U`). The one thing HDL *does* resolve at
load time is the line's parent batch reference (`BatchName` → `BatchId`).
Pointing the bad line at a batch name that does not exist (`DMTW2${PREFIX}NOSUCH`)
makes HDL fail to resolve the parent, so the line is rejected at load and never
written:

```
You need to enter a valid value for the BatchId attribute.
The current values are 300000046974970,DMTW2<prefix>NOSUCH.
```

Terminal `DataSetStatusCode` is `ORA_IN_ERROR` with **load 2 ok / 1 err** — the two
good lines still load; the bad line errors on purpose and creates nothing.

**Tokens stamped**

- `${PRN1}`, `${PRN2}`, `${PRN3}` — discovered `PayrollRelationshipNumber`s of
  existing US employees that already have an assigned payroll.
- `${PAY1}`, `${PAY2}`, `${PAY3}` — each person's own discovered payroll name.
- `${LDG_NAME}` — discovered legislative data group name (`US Legislative Data Group`).
- `${PREFIX}` — the run tag, stamped into the batch name (`DMTW2<prefix>`) so the
  fixture reloads without colliding.
- `${GL_DATE_SLASH}` — today's date in `YYYY/MM/DD` (the batch/line `UploadDate`).

`Regular Salary` + `Core Relationship Year to Date` is a validated defined-balance
pairing in the US LDG (confirmed live via `pay_defined_balances`). It is stable
seeded metadata, so it is held constant rather than discovered per run.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `DatFileName` + `FileLine` + `MessageText` |

- **REST resource is `dataLoadDataSets`**.
- Terminal statuses: `ORA_SUCCESS` / `ORA_COMPLETED` / `ORA_IN_ERROR` / `ORA_STOPPED`.
  In-flight statuses seen: `ORA_IN_PROGRESS`, `ORA_UNPROCESSED`.
- **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on
  purpose. The two good rows still load (load 2 ok / 1 err).
- Immediately after `createFileDataSet` the data set is not yet queryable, so the
  first GET may 404; the poller treats that as not-ready and retries.
- A full import+load pass takes ~3 minutes.

### Downstream step (documented, not in the standalone REST load path)

The HDL load only fills the **batch** (`PAY_BAL_BATCH_HEADERS` /
`PAY_BAL_BATCH_LINES`, lines at status `U` = unprocessed). To turn the accepted
batch lines into actual balances (`PAY_RUN_BALANCES` etc.) you then submit the ESS
process **Load Initial Balances** (parameter: the batch name `DMTW2<prefix>`). That
process is the balance-creation step and is where a bad balance name / bad person
would be reported. It is not part of this standalone REST fixture — the pass bar
here is the batch-line base table, which is the direct product of the HDL load.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns a single row: the LDG name and three existing payroll
relationship numbers (each with its own payroll name) for US employees that
already have an assigned payroll. The US LDG id is `300000046974970`.

```sql
SELECT ldg.name AS LDG_NAME,
       MAX(CASE WHEN c.rn=1 THEN c.prn END)     AS PRN1,
       MAX(CASE WHEN c.rn=1 THEN c.payname END) AS PAY1,
       MAX(CASE WHEN c.rn=2 THEN c.prn END)     AS PRN2,
       MAX(CASE WHEN c.rn=2 THEN c.payname END) AS PAY2,
       MAX(CASE WHEN c.rn=3 THEN c.prn END)     AS PRN3,
       MAX(CASE WHEN c.rn=3 THEN c.payname END) AS PAY3
FROM pay_legislative_data_groups ldg
CROSS JOIN (
  SELECT prn, payname, ROW_NUMBER() OVER (ORDER BY prn) rn FROM (
    SELECT DISTINCT pr.payroll_relationship_number prn, pl.payroll_name payname,
           ROW_NUMBER() OVER (PARTITION BY pr.payroll_relationship_number
                              ORDER BY pl.payroll_name) r2
    FROM pay_assigned_payrolls_dn ap
    JOIN pay_pay_relationships_dn pr
      ON ap.payroll_term_id BETWEEN pr.payroll_relationship_id
                                AND pr.payroll_relationship_id + 6
     AND pr.legislative_data_group_id = 300000046974970
    JOIN per_all_people_f p
      ON p.person_id = pr.person_id
     AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
    JOIN pay_all_payrolls_f pl
      ON pl.payroll_id = ap.payroll_id
     AND SYSDATE BETWEEN pl.effective_start_date AND pl.effective_end_date
    WHERE ap.legislative_data_group_id = 300000046974970
      AND REGEXP_LIKE(pr.payroll_relationship_number, '^[0-9]+$'))
  WHERE r2 = 1) c
WHERE ldg.legislative_data_group_id = 300000046974970 AND c.rn <= 3
GROUP BY ldg.name
```

→ e.g. `${LDG_NAME}='US Legislative Data Group'`, `${PRN1}='2'`/`${PAY1}='Biweekly'`,
`${PRN2}='2852'`/`${PAY2}='Retail Biweekly'`, `${PRN3}='2854'`/`${PAY3}='Retail Biweekly'`.

Notes on the HCM tables (reached through the `ApplicationDB_FSCM` BIP relay with
`hcm_impl` credentials — no separate HCM data source needed):

- The assigned-payroll → relationship link uses
  `pay_assigned_payrolls_dn.payroll_term_id BETWEEN payroll_relationship_id AND +6`
  (the term id sits just above the relationship id), the same robust pattern the
  PayrollRelationships fixture uses to avoid the lagging `pay_rel_groups_dn`.
- `Regular Salary` (US LDG) is defined for `Core Relationship Year to Date`
  (verified via `pay_defined_balances` joined to `pay_balance_types_vl` +
  `pay_balance_dimensions`).

## Verification (read-only, direct single-table read)

**Use the `PAY_BAL_BATCH_*` tables — NOT `PAY_BALANCE_BATCH_*`.** There are two
similarly-named table families visible through this BIP relay. The
`PAY_BALANCE_BATCH_HEADERS` / `PAY_BALANCE_BATCH_LINES` replica is **stale by
months** (its `MAX(creation_date)` was frozen at 2026-04-14 while the load ran on
2026-07-19). The live, current tables are `PAY_BAL_BATCH_HEADERS` /
`PAY_BAL_BATCH_LINES` — the just-loaded batch appears there within a minute. This
is the single most important gotcha for verifying this object.

- **Good → base.** Direct read of `PAY_BAL_BATCH_LINES` joined to its header on
  this run's batch name `DMTW2<prefix>`. A `BATCH_LINE_ID` present for each good
  `PayrollRelationshipNumber` = pass.

```sql
SELECT l.payroll_relationship_number AS PRN,
       MAX(l.batch_line_id)      AS BATCH_LINE_ID,
       MAX(l.batch_line_status)  AS BATCH_LINE_STATUS,
       MAX(l.balance_name)       AS BALANCE_NAME,
       MAX(l.value)              AS VAL
FROM pay_bal_batch_lines l
JOIN pay_bal_batch_headers h ON h.batch_id = l.batch_id
WHERE h.batch_name = 'DMTW2<prefix>'
  AND h.legislative_data_group_id = 300000046974970
GROUP BY l.payroll_relationship_number
```

- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL
  message (`GET .../{RequestId}/child/messages`) carrying the *"valid value for the
  BatchId attribute"* rejection for file line 4. The base read above returns no row
  under the valid batch for the rejected line, confirming absence. (The recipe
  declares `bad_error_contains: "valid value for the batchid"` so the harness
  matches the SourceSystemId-less HDL error message.)

## How to run it

```bash
cd gold_regression/harness
python run_object.py W2Balances   # discover -> build -> upload/submit/poll -> verify
```

`run_object.py` passes the discovered tokens into the HDL verify call, so the base
read is scoped to exactly the batch it just loaded.

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `65405` (stamped into batch name `DMTW265405`) |
| HDL UCM ContentId | `UCMFA07637...` (per run) |
| HDL data set RequestId | `9764507` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 4 ok / 0 err; load **2 ok / 1 err** |
| Discovered LDG | `US Legislative Data Group` (id `300000046974970`) |
| Discovered relationships | GOOD `2` (Biweekly), `2852` (Retail Biweekly); BAD line PRN `2854` |

**Good rows → base table `PAY_BAL_BATCH_LINES` (2/2):**

| PayrollRelationshipNumber | BATCH_LINE_ID | BalanceName | Value | Status |
|---|---|---|---|---|
| `2`    | `300000331555931` | Regular Salary | 1000 | U (unprocessed) |
| `2852` | `300000331555934` | Regular Salary | 2000 | U (unprocessed) |

**Bad row → HDL error, no line created (1/1):**

| File line | HDL error |
|---|---|
| 4 | `You need to enter a valid value for the BatchId attribute. The current values are 300000046974970,DMTW265405NOSUCH.` |

The two good lines reached `PAY_BAL_BATCH_LINES` with real batch-line ids under the
run's batch `DMTW265405`; the bad line (nonexistent parent batch) errored at load
and created nothing (absent from the base read). Gold zip `W2Balances_gold.zip`
(last built at prefix 65405) kept here.

**Earlier-attempt notes (all fixed, same session):**

1. Single-file `InitializeBalanceBatchHeader.dat` carrying both METADATA blocks →
   *"InitializeBalanceBatchLine component discriminator isn't valid."* Fixed by
   splitting into two separate .dat members (two top-level business objects).
2. Bad row = nonexistent `BalanceName` → NOT rejected by HDL (loaded at status `U`;
   validation is deferred to Load Initial Balances). Same for a nonexistent
   `PayrollRelationshipNumber`. Fixed by making the bad row reference a nonexistent
   parent batch name, which HDL *does* resolve and reject at load.
3. Verified against `PAY_BALANCE_BATCH_LINES` → 0 rows (stale replica, frozen at
   2026-04-14). Fixed by reading the live `PAY_BAL_BATCH_LINES` tables instead.

## Harness note

No harness code change was needed. The recipe uses the existing generic HDL path
(`run_object.py` → `discover` → `build_artifact` → `load_hdl` → `verify`) and the
existing `members` (multi-.dat zip) and `bad_error_contains` (SourceSystemId-less
HDL error match) mechanisms. The only object-specific pieces are `recipe.json`
(discovery + verify SQL against `PAY_BAL_BATCH_LINES`, `bad_error_contains`) and the
two `.dat` templates.
