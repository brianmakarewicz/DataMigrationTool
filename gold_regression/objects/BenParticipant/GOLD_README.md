# BenParticipant — gold regression fixture (HDL, PersonBenefitBalance)

A standalone, reloadable **HDL** fixture (2 good person benefit balances + 1 bad)
that loads directly into Oracle Fusion HCM through the HCM Data Loader REST
service (upload -> createFileDataSet -> poll), verified read-only via BIP against
the base table `BEN_PER_BNFTS_BAL_F`. No DMT tool code and no DMT database are in
the load path.

The migration object **BenParticipant** (Benefit Participant Enrollment) is
delivered through the HDL business object **PersonBenefitBalance** — the file
discriminator is `PersonBenefitBalance` and the DAT file is
`PersonBenefitBalance.dat` (this matches the DMT generator
`DMT_BEN_PARTIC_HDL_GEN_PKG`, which builds a `PersonBenefitBalance` DAT).

## Why this fixture is portable (no upstream dependency)

A person benefit balance attaches an amount to an **existing person** under an
**existing benefit balance type** (the LOV of `BenefitBalanceName`) scoped to that
person's **legal employer**. This fixture does **not** load a worker first and does
**not** reference the prefixed workers we created earlier.

At load time it runs one read-only BIP query against the target pod and discovers:

- an **existing benefit balance type** that is defined for the US1 legal entity
  (`401k Employee Balance`, legal-entity id `300000046974965`), and
- **three existing persons who already hold that balance** (proven-valid
  person + balance-type combinations — persons whose `BEN_PER_BNFTS_BAL_F` row for
  `401k Employee Balance` is currently effective).

Those discovered `PersonNumber` values and the balance name are stamped into
`PersonBenefitBalance.dat`. The balance rows we load carry a **fresh effective
date `2026/07/19`** and a **prefix-derived value** (`${PREFIX}1`, `${PREFIX}2`), so
each run writes a new date-effective segment whose value is unambiguously ours and
the fixture reloads cleanly on any future run.

### The key portability decision — reference the person by PersonNumber, not by SourceSystemId

The DMT pipeline generator (`DMT_BEN_PARTIC_HDL_GEN_PKG`) references the person
with the source-key hint `PersonId(SourceSystemId)` set to
`PERSON_NUMBER || '_BENENRL'`. That only resolves if the person was loaded in the
**same** HDL batch under `HRC_SQLLOADER` source keys — i.e. it depends on our own
upstream Workers load. Seeded demo employees have **no** HDL source key, so that
hint cannot resolve for them.

HCM Data Loader also lets you reference an existing person by the **user key**
`PersonNumber` directly. This fixture uses `PersonNumber`, which is what makes it
self-sufficient against a fresh pod. (Same portability decision proven on the
Salaries fixture, which references the assignment by `AssignmentNumber`.)

**This clears the old Benefits blocker.** The canonical `objects/Benefits/README.md`
recorded (2026-04-04, DB-20) that PersonBenefitBalance was blocked because
"the loaded test workers are not enrolled in any benefit plans," so no valid
person + balance-type combination existed. That was a consequence of referencing
**our own** loaded workers, which were never enrolled. By discovering **seeded
demo persons who are already enrolled and already hold the balance**, a valid
combination exists and the good rows load. The blocker was an upstream-dependency
artifact, not an instance-config gap.

## The DAT (`PersonBenefitBalance.dat`, pipe-delimited HDL)

One `PersonBenefitBalance.dat` inside `BenParticipant_gold.zip`. One
`PersonBenefitBalance` section, three MERGE lines:

```
METADATA|PersonBenefitBalance|SourceSystemOwner|SourceSystemId|PersonNumber|BenefitBalanceName|BenefitRelationName|EffectiveStartDate|Val
MERGE|PersonBenefitBalance|HRC_SQLLOADER|${PREFIX}DMTBEN001|${PNUM1}|${BAL_NAME}|DFLT|2026/07/19|${PREFIX}1
MERGE|PersonBenefitBalance|HRC_SQLLOADER|${PREFIX}DMTBEN002|${PNUM2}|${BAL_NAME}|DFLT|2026/07/19|${PREFIX}2
MERGE|PersonBenefitBalance|HRC_SQLLOADER|${PREFIX}DMTBEN-BAD|${PNUM3}|DMT NONEXISTENT BENEFIT BALANCE|DFLT|2026/07/19|99999
```

| Row | SourceSystemId | PersonNumber | BenefitBalanceName | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTBEN001` | `${PNUM1}` (discovered) | `${BAL_NAME}` (discovered) | valid -> `BEN_PER_BNFTS_BAL_F` |
| GOOD-2 | `${PREFIX}DMTBEN002` | `${PNUM2}` (discovered) | `${BAL_NAME}` (discovered) | valid -> `BEN_PER_BNFTS_BAL_F` |
| BAD-1  | `${PREFIX}DMTBEN-BAD` | `${PNUM3}` (discovered) | `DMT NONEXISTENT BENEFIT BALANCE` | HDL error, no balance |

**Tokens stamped**

- `${PREFIX}` on each `SourceSystemId` and on the good `Val` — keeps the records
  unique and reloadable, and makes the good value unambiguously this run's.
- `${PNUM1}`, `${PNUM2}`, `${PNUM3}` — discovered `PersonNumber`s of existing
  persons who hold `401k Employee Balance`.
- `${BAL_NAME}` — discovered benefit balance name (`401k Employee Balance`).

**`BenefitRelationName` is `DFLT`.** The default benefit relation. Required by the
V2 business object.

**`UOM` must NOT be supplied.** The Oracle V1 example includes a `UOM|USD` column,
but the **V2** PersonBenefitBalance business object rejects it:
*"The METADATA line can't be processed because the UOM attribute is unknown for V2
version of the PersonBenefitBalance business object."* A first attempt (prefix
90311, req 9764044) carried `UOM` and the whole file's METADATA was rejected as a
critical error — import succeeded (3 ok) but nothing loaded. Removing `UOM` fixed
it.

**Bad-row design.** The bad row uses a `BenefitBalanceName` that does not exist
(`DMT NONEXISTENT BENEFIT BALANCE`). HDL rejects it (invalid balance id) and
creates no balance. Its person (`${PNUM3}`) is itself a valid enrolled person, so
the failure is deterministically on the balance name, not the person.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` -> `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` -> `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

- **REST resource is `dataLoadDataSets`** (not `hcmDataLoader`, which 404s).
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
- **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on
  purpose. The two good rows still load (partial success).
- Immediately after `createFileDataSet` the data set is not yet queryable, so the
  first GET may 404; the poller treats that as not-ready and retries.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns a single row with the balance name and three person numbers.
The persons are chosen from the **US1 legal entity** (id `300000046974965`) and
must **not already hold** `401k Employee Balance` (id `300000074351541`), so the
MERGE creates a fresh record instead of colliding with an existing balance's
source key.

```sql
SELECT bb.name AS BAL_NAME,
       TO_CHAR(bb.bnfts_bal_id) AS BAL_ID,
       MAX(CASE WHEN c.rn=1 THEN c.person_number END) AS PNUM1,
       MAX(CASE WHEN c.rn=2 THEN c.person_number END) AS PNUM2,
       MAX(CASE WHEN c.rn=3 THEN c.person_number END) AS PNUM3
FROM ben_bnfts_bal_f bb
JOIN (
  SELECT p.person_number,
         ROW_NUMBER() OVER (ORDER BY p.person_number) rn
  FROM per_all_assignments_m a
  JOIN per_all_people_f p
    ON p.person_id = a.person_id
   AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
  WHERE a.legal_entity_id = 300000046974965           -- US1 legal entity
    AND a.effective_latest_change = 'Y'
    AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
    AND a.assignment_type = 'E' AND a.primary_flag = 'Y'
    AND REGEXP_LIKE(p.person_number, '^[0-9]+$')       -- seeded demo persons only
    AND NOT EXISTS (                                    -- not already enrolled in this balance
      SELECT 1 FROM ben_per_bnfts_bal_f pb
      JOIN ben_bnfts_bal_f b2 ON b2.bnfts_bal_id = pb.bnfts_bal_id
      WHERE pb.person_id = p.person_id
        AND b2.name = '401k Employee Balance'
        AND SYSDATE BETWEEN pb.effective_start_date AND pb.effective_end_date)
) c ON c.rn <= 3
WHERE bb.name = '401k Employee Balance'
  AND SYSDATE BETWEEN bb.effective_start_date AND bb.effective_end_date
  AND bb.legal_entity_id = 300000046974965            -- US1 legal entity
GROUP BY bb.name, bb.bnfts_bal_id
```

The `NOT EXISTS` clause also makes the fixture **reloadable**: a re-run
automatically picks the next set of persons who don't yet hold the balance, so it
never collides with balances written on a prior run.

Notes on the HCM/BEN tables (reached through the `ApplicationDB_FSCM` BIP relay
with `hcm_impl` credentials — no separate HCM data source needed):

- **`ben_bnfts_bal_f`** is the benefit balance TYPE table (85 rows on this pod).
  Columns used: `name`, `bnfts_bal_id`, `legal_entity_id`, `effective_start_date`.
  This is the LOV that `BenefitBalanceName` validates against. The older name
  `ben_benefit_balances` does NOT exist on this pod (ORA-00942).
- **`ben_per_bnfts_bal_f`** is the person-benefit-balance BASE table (the pass
  bar; ~3109 rows on this pod). PK `per_bnfts_bal_id`; columns `person_id`,
  `bnfts_bal_id`, `val`, `effective_start_date`, `legal_entity_id`,
  `assignment_id`. The older name `ben_per_bnft_balances` does NOT exist (ORA-00942).

## Verification (read-only, direct single-table read)

- **Good -> base.** Direct read of `BEN_PER_BNFTS_BAL_F` joined to
  `PER_ALL_PEOPLE_F`, scoped to the discovered balance id, the fresh effective
  date `2026/07/19`, and the discovered person numbers. A `PER_BNFTS_BAL_ID`
  present for each good `PersonNumber` at that date = pass.

```sql
SELECT p.person_number AS PNUM,
       TO_CHAR(MAX(pb.per_bnfts_bal_id)) AS PBID,
       TO_CHAR(MAX(pb.val)) AS VAL
FROM ben_per_bnfts_bal_f pb
JOIN per_all_people_f p
  ON p.person_id = pb.person_id
 AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
WHERE pb.bnfts_bal_id = <discovered ${BAL_ID}>
  AND pb.effective_start_date = DATE '2026-07-19'
  AND p.person_number IN ('<PNUM1>','<PNUM2>','<PNUM3>')
GROUP BY p.person_number
```

- **Bad -> HDL error, absent from base.** The bad evidence is the load-time HDL
  message list keyed by `SourceSystemId` (`GET .../{RequestId}/child/messages`).
  The base read above returns no `2026/07/19` row for the bad `SourceSystemId`
  (which is not a person number), confirming absence.

## How to run it

```bash
cd gold_regression/harness
python run_object.py BenParticipant --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90313` |
| HDL data set RequestId | `9764141` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Discovered balance type | `401k Employee Balance` (id `300000074351541`, US1 legal entity `300000046974965`) |
| Discovered persons | GOOD `10`, `1006`; BAD `1007` (US1-LE persons without this balance) |

**Good rows → base table `BEN_PER_BNFTS_BAL_F` (2/2):**

| PersonNumber | PER_BNFTS_BAL_ID | Val | EffectiveStartDate |
|---|---|---|---|
| `10`   | `300000331543542` | 903131 | 2026-07-19 |
| `1006` | `300000331552545` | 903132 | 2026-07-19 |

**Bad row → HDL error, no balance created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `90313DMTBEN-BAD` | `You need to enter a valid value for the BnftsBalId attribute. The current values are DMT NONEXISTENT BENEFIT BALANCE.` |

The two good balances reached `BEN_PER_BNFTS_BAL_F` with real ids on existing
demo persons; the bad balance errored in the loader (file line 4) and created
nothing. Gold zip `BenParticipant_gold.zip` (last built at prefix 90313) kept here.

### Two earlier attempts (both fixed)

1. **`UOM` rejected by V2.** Prefix `90311`, req `9764044` carried a `UOM|USD`
   column (from the Oracle V1 example). V2 rejected it: *"the UOM attribute is
   unknown for V2 version of the PersonBenefitBalance business object,"* which
   failed the whole file's METADATA (import 3 ok, load 0). Removed `UOM`.
2. **MERGE collided with an existing balance's source key.** Prefix `90312`, req
   `9764086` targeted persons who **already held** `401k Employee Balance`. HDL
   treated the MERGE as an update to their existing balance, whose source key is
   not ours, and rejected both good rows: *"You can't update this record because
   the SourceSystemId … and SourceSystemOwner HRC_SQLLOADER are invalid"*
   (Oracle: "a user key/surrogate id used by an existing record with a different
   source key"). The bad row still errored correctly on the balance name. Fix:
   discover US1-legal-entity persons who do **not** yet hold the balance, so the
   MERGE creates a genuinely new record. This also confirmed the balance loads
   for a US1-LE person not previously enrolled — clearing the old Benefits blocker.
