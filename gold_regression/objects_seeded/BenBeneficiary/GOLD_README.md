# BenBeneficiary — v2 seeded gold fixture (HDL, PersonBenefitBalance) — the stateful case

Converted from the frozen v1 fixture (`../../objects/BenBeneficiary/`). Same shape — two good
person benefit balances plus one bad — loaded through HCM Data Loader (upload →
createFileDataSet → poll) and verified read-only against the base table `BEN_PER_BNFTS_BAL_F`.
The difference from v1: the person numbers and the benefit balance type are **hard-coded to
standard seeded values**, not discovered at load time. No DMT tool code and no DMT database
are in the load path.

BenBeneficiary and BenParticipant deliver through the **same** HDL business object
(`PersonBenefitBalance`), discriminator, and DAT filename. They are distinguished only by the
SourceSystemId suffix (`_BENBNFY` vs `_BENENRL`) and by the balance type each targets. This
fixture uses the beneficiary suffix `_BENBNFY` and the **vested-employer** balance type, so it
never collides with the participant fixture even on the same pod.

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | Literal value | Confirmed seeded (read-only BIP) |
|---|---|---|
| Benefit balance type name | `401k Vested Employer Balance` (in the .dat) | yes — `ben_bnfts_bal_f`, no prefix |
| Benefit balance type id | `300000074351542` (verify base read) | yes, US1 legal entity `300000046974965` |
| Good person 1 | PersonNumber `6` | yes — seeded US1-LE demo employee we never loaded |
| Good person 2 | PersonNumber `8` | yes — seeded US1-LE demo employee we never loaded |
| Bad person | PersonNumber `9` | yes — seeded US1-LE demo employee we never loaded |

The discovery block is removed from `recipe.json`. Persons `6`, `8`, `9` are seeded US1
legal-entity demo employees (plain numeric person numbers) that we did not load; the balance
type `401k Vested Employer Balance` (the vested employer contribution a beneficiary would
inherit) is standard seeded benefit-balance setup. All were confirmed on the target pod through
the read-only BIP relay before being written as literals.

Note on person choice: v1's live run created ...542 balances on persons `2` and `3` under
*prefixed foreign* source keys. Re-using those persons here would be rejected as a foreign
source-key update (see finding #2 below), so this fixture picks persons `6` and `8`, confirmed
via BIP to NOT already hold the ...542 balance. The first run creates their balance under our
own fixed source key, so every later run owns and updates its own record.

## Why this is a stateful case, and how re-run safety is actually achieved

Same two live findings that drove the BenParticipant design apply, because this is the same
base object (`BEN_PER_BNFTS_BAL_F`):

1. **A prefix-derived date is not safe here.** PersonBenefitBalance rejects a new
   date-effective segment whose start date falls *before* the person's existing balance
   record. A random prefix on a later run can produce an *earlier* date, which HDL refuses.
   (This is why the prefix-derived `${SAL_DATE}` approach is wrong for this object.)

2. **A prefixed SourceSystemId is not safe here.** A person holds only **one** balance record
   per balance type, keyed by its source key. Once a person holds the balance under source key
   `A`, a later run presenting a *different* source key `B` (e.g. a `${PREFIX}`-stamped id) is
   treated as an attempt to update the existing record with a foreign source key and is
   rejected: *"You can't update this record because the SourceSystemId … and SourceSystemOwner
   HRC_SQLLOADER are invalid."*

**The re-run-safe design that works: a FIXED (non-prefixed) SourceSystemId per good row.**

Each good row carries a stable source key — `DMTBNFY-SEED-6_BENBNFY`, `DMTBNFY-SEED-8_BENBNFY`
(keeping v1's `_BENBNFY` beneficiary suffix). The first run *creates* the person's balance
record under that key. Every later run presents the **same** source key, so HDL MERGE *updates
our own record* — no foreign-source-key collision, ever. Re-run safety comes from owning the
record's source key, not from a moving date.

- The `Val` still carries `${PREFIX}` (`${PREFIX}1`, `${PREFIX}2`), so each run writes a fresh,
  unambiguously-this-run value into the base table. That prefix-stamped value is what the
  verify scopes on to prove *this run* wrote the record.
- The effective start date uses the **wall-clock-monotonic** derived token `${BEN_DATE}`
  (`build_artifact.derived_tokens`: base 2300-01-01 + days since 2020-01-01), shared with
  BenParticipant. It advances with the real calendar, so a later day's run is strictly later
  than any prior segment (never earlier, so finding #1 is never tripped). On the same calendar
  day the date is identical, which is fine: the fixed source key means the same-day re-run
  simply updates our own record at that date with a new `Val`.
- The bad row keeps a `${PREFIX}`-stamped SourceSystemId. It is rejected on the balance name
  and never lands, so it has no state to collide with.

The verify base read therefore scopes on the run's prefix-stamped `Val`
(`pb.val IN (${PREFIX}1, ${PREFIX}2)`) and the seeded persons, not on the date — because a
same-day update keeps the original start date while changing `Val`, the value is the reliable
"this run wrote it" key.

## The DAT (`PersonBenefitBalance.dat`, pipe-delimited HDL)

```
METADATA|PersonBenefitBalance|SourceSystemOwner|SourceSystemId|PersonNumber|BenefitBalanceName|BenefitRelationName|EffectiveStartDate|Val
MERGE|PersonBenefitBalance|HRC_SQLLOADER|DMTBNFY-SEED-6_BENBNFY|6|401k Vested Employer Balance|DFLT|${BEN_DATE}|${PREFIX}1
MERGE|PersonBenefitBalance|HRC_SQLLOADER|DMTBNFY-SEED-8_BENBNFY|8|401k Vested Employer Balance|DFLT|${BEN_DATE}|${PREFIX}2
MERGE|PersonBenefitBalance|HRC_SQLLOADER|${PREFIX}DMTBNFY-BAD_BENBNFY|9|DMT NONEXISTENT BENEFICIARY BALANCE|DFLT|${BEN_DATE}|99999
```

| Row | SourceSystemId | PersonNumber | BenefitBalanceName | Purpose |
|---|---|---|---|---|
| GOOD-1 | `DMTBNFY-SEED-6_BENBNFY` (fixed) | `6` | `401k Vested Employer Balance` | valid → `BEN_PER_BNFTS_BAL_F` |
| GOOD-2 | `DMTBNFY-SEED-8_BENBNFY` (fixed) | `8` | `401k Vested Employer Balance` | valid → `BEN_PER_BNFTS_BAL_F` |
| BAD-1  | `${PREFIX}DMTBNFY-BAD_BENBNFY` | `9` | `DMT NONEXISTENT BENEFICIARY BALANCE` | HDL error, no balance |

- `BenefitRelationName` is `DFLT` (the default benefit relation; required by the V2 object).
- `UOM` must NOT be supplied — the V2 PersonBenefitBalance object rejects it (carried over from
  v1). The template has no `UOM` column.
- The `_BENBNFY` suffix on every SourceSystemId is the beneficiary source-key convention
  (v1's `DMT_BEN_BENFY_HDL_GEN_PKG` emits `PERSON_NUMBER || '_BENBNFY'`).

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

Upload → `.../dataLoadDataSets/action/uploadFile` → ContentId; submit →
`.../dataLoadDataSets/action/createFileDataSet` (`fileAction: IMPORT_AND_LOAD`) → RequestId;
poll `.../dataLoadDataSets/{RequestId}` every 30s; errors from
`.../dataLoadDataSets/{RequestId}/child/messages`. `ORA_IN_ERROR` is the EXPECTED terminal here
(the one bad row errors on purpose; the two good rows still load — partial success).

## Verification (read-only, single-table read)

Direct read of `BEN_PER_BNFTS_BAL_F` joined to `PER_ALL_PEOPLE_F`, scoped to the seeded balance
id `300000074351542`, this run's prefix-stamped `Val`, and person numbers `6`/`8`/`9`. A
`PER_BNFTS_BAL_ID` present for each good person with this run's `Val` = pass. The bad
`SourceSystemId` (not a person number) never appears; the bad evidence is the load-time HDL
message list.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

Standalone HDL load path only; verification via the read-only BIP relay only.

### Run 1

| Field | Value |
|---|---|
| Prefix | `40521` |
| HDL data set RequestId | `9766635` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 loaded, 1 errored) |

Good → base `BEN_PER_BNFTS_BAL_F` (2/2): person `6` → `PER_BNFTS_BAL_ID` `300000331573746`
(Val `405211`); person `8` → `300000331573749` (Val `405212`).
Bad → HDL error, no balance: `40521DMTBNFY-BAD_BENBNFY` (person `9`) →
`You need to enter a valid value for the BnftsBalId attribute. The current values are
DMT NONEXISTENT BENEFICIARY BALANCE.` — absent from base.

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `72360` |
| HDL data set RequestId | `9766700` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |

Good → base `BEN_PER_BNFTS_BAL_F` (2/2): person `6` → **same** `PER_BNFTS_BAL_ID`
`300000331573746`, now Val `723601`; person `8` → **same** `300000331573749`, now Val
`723602`. The MERGE updated *our own* records via the fixed source keys — same balance ids,
this run's new prefix-stamped values, no collision. Bad row errored the same way.

Both runs reached the base table on seeded demo persons; the bad balance errored in the loader
and created nothing. **Re-runs work** — because each good row owns a stable SourceSystemId, a
second run updates its own record instead of colliding on a foreign source key.

## Harness change

None. This fixture reuses the `${BEN_DATE}` / `${BEN_DATE_DASH}` derived token already added to
`harness/build_artifact.py` for BenParticipant (base 2300-01-01 + days since 2020-01-01,
wall-clock-monotonic). No harness edit was needed for BenBeneficiary.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py BenBeneficiary
# run it again immediately — the fixed source keys make the second run update our own
# records, so it passes again
```
