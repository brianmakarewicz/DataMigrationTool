# BenBeneficiary — gold regression fixture (HDL, PersonBenefitBalance)

A standalone, reloadable **HDL** fixture (2 good person benefit balances + 1 bad)
that loads directly into Oracle Fusion HCM through the HCM Data Loader REST
service (upload -> createFileDataSet -> poll), verified read-only via BIP against
the base table `BEN_PER_BNFTS_BAL_F`. No DMT tool code and no DMT database are in
the load path.

The migration object **BenBeneficiary** (Beneficiary Designation) is delivered
through the HDL business object **PersonBenefitBalance** — the file discriminator
is `PersonBenefitBalance` and the DAT file is `PersonBenefitBalance.dat`. This
matches the DMT generator `DMT_BEN_BENFY_HDL_GEN_PKG`, which — despite the object
being "beneficiary" — emits a `PersonBenefitBalance` DAT (its own header comment
states `BeneficiaryBenefitBalance` is NOT a valid discriminator; use
`PersonBenefitBalance`).

## What distinguishes BenBeneficiary from BenParticipant

All three benefit sub-objects (Participant, Dependent, Beneficiary) share the
**same** HDL business object, discriminator, and DAT filename
(`PersonBenefitBalance`). They are not separate HDL objects. The differences are
in the DMT generator, not the loaded object:

| | BenParticipant (`DMT_BEN_PARTIC_HDL_GEN_PKG`) | BenBeneficiary (`DMT_BEN_BENFY_HDL_GEN_PKG`) |
|---|---|---|
| Discriminator / DAT | `PersonBenefitBalance` / `PersonBenefitBalance.dat` | same |
| SourceSystemId convention | `PERSON_NUMBER \|\| '_BENENRL'` | `PERSON_NUMBER \|\| '_BENBNFY'` |
| Generator zip name | (participant) | `BeneficiaryDesignations_<run>.zip` |
| STG/TFM extra columns | — | `BENEFICIARY_PERSON_NUMBER`, `BENEFICIARY_TYPE`, `PERCENTAGE`, `BENEFIT_RELATIONSHIP_NAME` |

The DMT beneficiary STG/TFM model carries a beneficiary contact
(`BENEFICIARY_PERSON_NUMBER`), a `BENEFICIARY_TYPE`, and a `PERCENTAGE`, which is
the "designate a beneficiary contact" semantics of a real beneficiary record.
**However, the actual beneficiary generator does not emit any of those fields** —
it produces a plain `PersonBenefitBalance` MERGE with the person, the effective
date, and the balance name, using the `_BENBNFY` source-key suffix. So at the
load level a BenBeneficiary fixture is a PersonBenefitBalance load; the beneficiary
flavor is carried by the `_BENBNFY` SourceSystemId suffix.

This fixture is faithful to that: it reproduces the beneficiary source-key
convention (`${PREFIX}DMTBNFY…_BENBNFY`) and, to keep it clearly a *beneficiary*
record and to avoid colliding with a same-day BenParticipant run, it targets a
**different balance type** — `401k Vested Employer Balance` (the vested employer
contribution a beneficiary would inherit), whereas BenParticipant uses
`401k Employee Balance`.

## Why this fixture is portable (no upstream dependency)

A person benefit balance attaches an amount to an **existing person** under an
**existing benefit balance type** (the LOV of `BenefitBalanceName`) scoped to that
person's **legal employer**. This fixture does **not** load a worker first and does
**not** reference any prefixed workers we created earlier. It creates NEW records
whose FK-style references are all discovered, already-present values on the target
pod (portability rules 6–8).

At load time it runs one read-only BIP query against the target pod and discovers:

- an **existing benefit balance type** defined for the US1 legal entity
  (`401k Vested Employer Balance`, bnfts_bal_id `300000074351542`, legal-entity id
  `300000046974965`), and
- **three existing US1-legal-entity persons who do NOT already hold that balance**
  (referenced by `PersonNumber`), so the MERGE creates a fresh record instead of
  colliding with an existing balance's source key.

Those discovered `PersonNumber` values and the balance name are stamped into
`PersonBenefitBalance.dat`. The balance rows carry a **fresh effective date
`2026/07/19`** and a **prefix-derived value** (`${PREFIX}1`, `${PREFIX}2`), so each
run writes a new, unambiguously-ours segment and the fixture reloads cleanly.

### Key portability decision — reference the person by PersonNumber, not SourceSystemId

The DMT generator references the person with the FK hint
`PersonId(SourceSystemId)` = `PERSON_NUMBER || '_BENBNFY'`. That only resolves if
the person was loaded in the **same** HDL batch under `HRC_SQLLOADER` source keys —
i.e. it depends on our own upstream Workers load. Seeded demo employees have no
HDL source key, so that hint cannot resolve for them. HCM Data Loader also lets
you reference an existing person by the **user key `PersonNumber`** directly. This
fixture uses `PersonNumber`, which is what makes it self-sufficient against a fresh
pod. (Same decision proven on BenParticipant and on Salaries' `AssignmentNumber`.)

## The DAT (`PersonBenefitBalance.dat`, pipe-delimited HDL)

One `PersonBenefitBalance.dat` inside `BenBeneficiary_gold.zip`. One
`PersonBenefitBalance` section, three MERGE lines:

```
METADATA|PersonBenefitBalance|SourceSystemOwner|SourceSystemId|PersonNumber|BenefitBalanceName|BenefitRelationName|EffectiveStartDate|Val
MERGE|PersonBenefitBalance|HRC_SQLLOADER|${PREFIX}DMTBNFY001_BENBNFY|${PNUM1}|${BAL_NAME}|DFLT|2026/07/19|${PREFIX}1
MERGE|PersonBenefitBalance|HRC_SQLLOADER|${PREFIX}DMTBNFY002_BENBNFY|${PNUM2}|${BAL_NAME}|DFLT|2026/07/19|${PREFIX}2
MERGE|PersonBenefitBalance|HRC_SQLLOADER|${PREFIX}DMTBNFY-BAD_BENBNFY|${PNUM3}|DMT NONEXISTENT BENEFICIARY BALANCE|DFLT|2026/07/19|99999
```

| Row | SourceSystemId | PersonNumber | BenefitBalanceName | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTBNFY001_BENBNFY` | `${PNUM1}` (discovered) | `${BAL_NAME}` (discovered) | valid -> `BEN_PER_BNFTS_BAL_F` |
| GOOD-2 | `${PREFIX}DMTBNFY002_BENBNFY` | `${PNUM2}` (discovered) | `${BAL_NAME}` (discovered) | valid -> `BEN_PER_BNFTS_BAL_F` |
| BAD-1  | `${PREFIX}DMTBNFY-BAD_BENBNFY` | `${PNUM3}` (discovered) | `DMT NONEXISTENT BENEFICIARY BALANCE` | HDL error, no balance |

**Tokens stamped**

- `${PREFIX}` on each `SourceSystemId` and on the good `Val` — keeps records unique
  and reloadable and makes the good value unambiguously this run's.
- `${PNUM1}`, `${PNUM2}`, `${PNUM3}` — discovered `PersonNumber`s of existing US1
  persons who do not yet hold `401k Vested Employer Balance`.
- `${BAL_NAME}` — discovered benefit balance name (`401k Vested Employer Balance`).

**`BenefitRelationName` is `DFLT`.** The default benefit relation, required by V2.

**`UOM` must NOT be supplied.** The V2 PersonBenefitBalance object rejects a `UOM`
column ("the UOM attribute is unknown for V2 version of the PersonBenefitBalance
business object"). Omitted here — carried over from the BenParticipant lesson.

**Bad-row design.** The bad row uses a `BenefitBalanceName` that does not exist
(`DMT NONEXISTENT BENEFICIARY BALANCE`). HDL rejects it (invalid BnftsBalId) and
creates no balance. Its person (`${PNUM3}`) is a valid US1 person, so the failure
is deterministically on the balance name, not the person.

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

One query returns a single row with the balance name/id and three person numbers.
The persons are US1-legal-entity employees (`300000046974965`) who do **not**
already hold `401k Vested Employer Balance` (id `300000074351542`), so the MERGE
creates a fresh record. This also makes the fixture reloadable — a re-run picks
the next set of persons without the balance.

```sql
SELECT bb.name AS BAL_NAME,
       TO_CHAR(bb.bnfts_bal_id) AS BAL_ID,
       MAX(CASE WHEN c.rn=1 THEN c.person_number END) AS PNUM1,
       MAX(CASE WHEN c.rn=2 THEN c.person_number END) AS PNUM2,
       MAX(CASE WHEN c.rn=3 THEN c.person_number END) AS PNUM3
FROM ben_bnfts_bal_f bb
JOIN (
  SELECT person_number, rn FROM (
    SELECT p.person_number,
           ROW_NUMBER() OVER (ORDER BY TO_NUMBER(p.person_number)) rn
    FROM per_all_assignments_m a
    JOIN per_all_people_f p
      ON p.person_id = a.person_id
     AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
    WHERE a.legal_entity_id = 300000046974965          -- US1 legal entity
      AND a.effective_latest_change = 'Y'
      AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
      AND a.assignment_type = 'E' AND a.primary_flag = 'Y'
      AND REGEXP_LIKE(p.person_number, '^[0-9]+$')      -- seeded demo persons only
      AND NOT EXISTS (                                  -- not already holding this balance
        SELECT 1 FROM ben_per_bnfts_bal_f pb
        WHERE pb.person_id = p.person_id
          AND pb.bnfts_bal_id = 300000074351542
          AND SYSDATE BETWEEN pb.effective_start_date AND pb.effective_end_date))
  WHERE rn <= 3) c ON 1=1
WHERE bb.name = '401k Vested Employer Balance'
  AND SYSDATE BETWEEN bb.effective_start_date AND bb.effective_end_date
  AND bb.legal_entity_id = 300000046974965             -- US1 legal entity
GROUP BY bb.name, bb.bnfts_bal_id
```

Tables (reached through the `ApplicationDB_FSCM` BIP relay with `hcm_impl`
credentials — no separate HCM data source needed):

- **`ben_bnfts_bal_f`** — the benefit balance TYPE table (the `BenefitBalanceName`
  LOV). Cols `name, bnfts_bal_id, legal_entity_id, effective_start_date`. US1 has
  three types: `401k Employee Balance` (…541), `401k Vested Employer Balance`
  (…542), `Current Year Stock Grant` (…543). The name `ben_benefit_balances` does
  NOT exist on this pod (ORA-00942).
- **`ben_per_bnfts_bal_f`** — the person-benefit-balance BASE table (the pass bar).
  PK `per_bnfts_bal_id`; cols `person_id, bnfts_bal_id, val, effective_start_date,
  legal_entity_id, assignment_id`. The name `ben_per_bnft_balances` does NOT exist
  (ORA-00942).

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
  message keyed by `SourceSystemId` (`GET .../{RequestId}/child/messages`). The
  base read above returns no `2026/07/19` row for the bad person, confirming
  absence.

## How to run it

```bash
cd gold_regression/harness
python run_object.py BenBeneficiary --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `67936` |
| HDL data set RequestId | `9764242` |
| UCM ContentId | `UCMFA07637088` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Discovered balance type | `401k Vested Employer Balance` (id `300000074351542`, US1 legal entity `300000046974965`) |
| Discovered persons | GOOD `2`, `3`; BAD `4` (US1-LE persons without this balance) |

**Good rows → base table `BEN_PER_BNFTS_BAL_F` (2/2):**

| PersonNumber | PER_BNFTS_BAL_ID | Val | EffectiveStartDate |
|---|---|---|---|
| `2` | `300000331552758` | 679361 | 2026-07-19 |
| `3` | `300000331552756` | 679362 | 2026-07-19 |

**Bad row → HDL error, no balance created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `67936DMTBNFY-BAD_BENBNFY` | `You need to enter a valid value for the BnftsBalId attribute. The current values are DMT NONEXISTENT BENEFICIARY BALANCE.` |

The two good balances reached `BEN_PER_BNFTS_BAL_F` with real ids on existing
demo persons; the bad balance errored in the loader (file line 4) and created
nothing. Gold zip `BenBeneficiary_gold.zip` (last built at prefix 67936) kept
here. Cleared on the first live attempt — the BenParticipant lessons (PersonNumber
user key, no UOM, target persons not already holding the balance) carried directly
over to the beneficiary variant.
