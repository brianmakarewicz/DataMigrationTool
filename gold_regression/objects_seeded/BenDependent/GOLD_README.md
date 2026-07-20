# BenDependent — v2 seeded gold fixture (HDL, Contact / ContactRelationship)

Converted from the frozen v1 fixture (`../../objects/BenDependent/`). Same shape — two good
dependent contacts plus one bad — loaded through HCM Data Loader (upload → createFileDataSet →
poll) and verified read-only against the base table `PER_CONTACT_RELSHIPS_F`. The only
difference from v1: the three existing employees each new dependent attaches to are
**hard-coded to their standard seeded `person_id` surrogates** instead of being discovered at
load time. No DMT tool code and no DMT database are in the load path.

## What it loads

BenDependent creates a **new dependent person** (a child) and a
`PER_CONTACT_RELSHIPS_F` relationship (`DEPENDENT_FLAG = 'Y'`, `CONTACT_TYPE = 'C'`) linking
that new person to an existing employee. The top-level HDL business object is `Contact`; its
children `ContactName` and `ContactLegislativeData` complete the new person, and its child
`ContactRelationship` links the new person to the existing employee via the unqualified
`RelatedPersonId` = that employee's `person_id` surrogate. Our new records use owner
`HRC_SQLLOADER`; the reference to the existing person resolves through that person's seeded
`FUSION` source key in `HRC_INTEGRATION_KEY_MAP` (where `source_system_id = person_id`).

## The hard-coded seeds (what v1 discovered → now literals)

v1's discovery query returned the first three US1-legal-entity (`300000046974965`) demo
employees with plain-numeric person numbers. Those three are hard-coded here as literal
`RelatedPersonId` surrogates in `Contact.dat`:

| Reference | `RelatedPersonId` (literal) | PersonNumber | Confirmed seeded (read-only BIP) |
|---|---|---|---|
| Existing employee 1 (parent of GOOD-1) | `300000047626100` | `10` | yes — FUSION source key = person_id; we never loaded it |
| Existing employee 2 (parent of GOOD-2) | `300000047887398` | `100` | yes — FUSION source key = person_id; we never loaded it |
| Existing employee 3 (parent of BAD)    | `300000066861968` | `1006` | yes — FUSION source key = person_id; we never loaded it |

All three have plain numeric person numbers (`10`, `100`, `1006`) — standard seeded demo
employees, never records we loaded (which would carry a prefix). Each was confirmed on the
target pod through the read-only BIP relay before being written as a literal: each exists in
`PER_ALL_PEOPLE_F` and has a `HRC_INTEGRATION_KEY_MAP` row under `SourceSystemOwner = 'FUSION'`
with `source_system_id = person_id`. These are the exact same three surrogates v1 discovered
(recorded in v1's live evidence at prefix 90419). The `discovery` block is deleted from
`recipe.json`.

## Re-run safety — natural, no state to own

Unlike BenParticipant (which reuses one balance record per person and therefore needs a fixed
non-prefixed source key), BenDependent **creates a brand-new dependent person on every run**.
Every field that could collide carries `${PREFIX}`:

- each new Contact / ContactName / ContactLegislativeData / ContactRelationship
  `SourceSystemId` is `${PREFIX}DMTDEP...` — unique per run;
- each dependent last name is `Dep${PREFIX}One` / `Dep${PREFIX}Two` / `Dep${PREFIX}Bad` — unique
  per run and the key the verify base read scopes on.

Because the dependent's own source keys and names vary by prefix, a later run creates a fresh,
non-colliding dependent person and a fresh relationship. The hard-coded `RelatedPersonId`
surrogates are references to seeded employees (shared, never prefixed) — the same three
employees simply gain another dependent each run, which is allowed. There is no per-person
single-record state to own, so no fixed source key is needed here.

## The DAT (`Contact.dat`, pipe-delimited HDL)

```
METADATA|Contact|SourceSystemOwner|SourceSystemId|EffectiveStartDate|EffectiveEndDate|StartDate|DateOfBirth
MERGE|Contact|HRC_SQLLOADER|${PREFIX}DMTDEP001|2020/01/01|4712/12/31|2020/01/01|2010/03/15
MERGE|Contact|HRC_SQLLOADER|${PREFIX}DMTDEP002|2020/01/01|4712/12/31|2020/01/01|2012/08/22
MERGE|Contact|HRC_SQLLOADER|${PREFIX}DMTDEP-BAD|2020/01/01|4712/12/31|2020/01/01|2011/05/10
METADATA|ContactName|...|FirstName|LastName
MERGE|ContactName|HRC_SQLLOADER|${PREFIX}DMTDEP001_NME|${PREFIX}DMTDEP001|...|US|GLOBAL|Child|Dep${PREFIX}One
MERGE|ContactName|HRC_SQLLOADER|${PREFIX}DMTDEP002_NME|${PREFIX}DMTDEP002|...|US|GLOBAL|Child|Dep${PREFIX}Two
MERGE|ContactName|HRC_SQLLOADER|${PREFIX}DMTDEP-BAD_NME|${PREFIX}DMTDEP-BAD|...|US|GLOBAL|Child|Dep${PREFIX}Bad
METADATA|ContactLegislativeData|...|Sex|MaritalStatus
MERGE|ContactLegislativeData|HRC_SQLLOADER|${PREFIX}DMTDEP001_LEG|${PREFIX}DMTDEP001|...|US|M|S
MERGE|ContactLegislativeData|HRC_SQLLOADER|${PREFIX}DMTDEP002_LEG|${PREFIX}DMTDEP002|...|US|F|S
MERGE|ContactLegislativeData|HRC_SQLLOADER|${PREFIX}DMTDEP-BAD_LEG|${PREFIX}DMTDEP-BAD|...|US|M|S
METADATA|ContactRelationship|...|PersonId(SourceSystemId)|RelatedPersonId|...|ContactType|DependentFlag|PersonalFlag
MERGE|ContactRelationship|HRC_SQLLOADER|${PREFIX}DMTDEP001_REL|${PREFIX}DMTDEP001|300000047626100|...|C|Y|Y
MERGE|ContactRelationship|HRC_SQLLOADER|${PREFIX}DMTDEP002_REL|${PREFIX}DMTDEP002|300000047887398|...|C|Y|Y
MERGE|ContactRelationship|HRC_SQLLOADER|${PREFIX}DMTDEP-BAD_REL|${PREFIX}DMTDEP-BAD|300000066861968|...|ZZINVALID|Y|Y
```

| Row | Contact (new dependent) | Attached to employee (literal `RelatedPersonId`) | ContactType | Purpose |
|---|---|---|---|---|
| GOOD-1 | `Dep${PREFIX}One` (Child) | `300000047626100` (PersonNumber 10)   | `C` | valid → `PER_CONTACT_RELSHIPS_F` |
| GOOD-2 | `Dep${PREFIX}Two` (Child) | `300000047887398` (PersonNumber 100)  | `C` | valid → `PER_CONTACT_RELSHIPS_F` |
| BAD-1  | `Dep${PREFIX}Bad` (Child) | `300000066861968` (PersonNumber 1006) | `ZZINVALID` | HDL error, no relationship |

**Date rule.** `DateOfBirth` must be before `StartDate` — children born 2010–2012, person
start / effective 2020/01/01.

**Bad-row design.** `ContactType = ZZINVALID` is not in the `CONTACT` lookup. HDL loads the bad
row's *person* fine but rejects its `ContactRelationship`, so no `DEPENDENT_FLAG='Y'` row is
created for it. The verify keys on dependent relationships, so the bad dependent is correctly
absent from the base.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

Upload → `.../dataLoadDataSets/action/uploadFile` → ContentId; submit →
`.../dataLoadDataSets/action/createFileDataSet` (`fileAction: IMPORT_AND_LOAD`) → RequestId;
poll `.../dataLoadDataSets/{RequestId}` every 30s; errors from
`.../dataLoadDataSets/{RequestId}/child/messages`. `ORA_IN_ERROR` is the EXPECTED terminal
(the one bad row errors on purpose; the two good dependents still load — partial success,
load 2 ok / 1 err).

## Verification (read-only, single-table read)

Direct read of `PER_CONTACT_RELSHIPS_F` joined to `PER_PERSON_NAMES_F` on the contact person,
scoped to `dependent_flag='Y'` and this run's prefixed dependent last names
(`Dep${PREFIX}One/Two/Bad`). A `CONTACT_RELATIONSHIP_ID` present for each good last name = pass.
The bad dependent yields no `dependent_flag='Y'` row; its evidence is the load-time HDL message.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

Standalone HDL load path only; verification via the read-only BIP relay only.

### Run 1

| Field | Value |
|---|---|
| Prefix | `67254` |
| HDL data set RequestId | `9766646` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: import 12 ok/0 err, load 2 ok/1 err) |

Good → base `PER_CONTACT_RELSHIPS_F` (2/2):
`Dep67254One` → `CONTACT_RELATIONSHIP_ID` `300000331573982` (type `C`, dependent_flag `Y`);
`Dep67254Two` → `300000331573932` (type `C`, dependent_flag `Y`).
Bad → HDL error, no relationship: `67254DMTDEP-BAD_REL` (file line 16) →
`The ZZINVALID value for the ContactType attribute is invalid and doesn't exist in the CONTACT
list of values.` — absent from base.

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `61478` |
| HDL data set RequestId | `9766744` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |

Good → base `PER_CONTACT_RELSHIPS_F` (2/2):
`Dep61478One` → **new** `CONTACT_RELATIONSHIP_ID` `300000331574241`;
`Dep61478Two` → **new** `300000331574267`. Distinct dependent persons and distinct relationship
ids from run 1 — the fresh prefix created new dependents with no collision. Bad row errored the
same way and created nothing.

Both runs reached the base table on seeded demo employees; the bad relationship errored in the
loader and created nothing. **Re-runs work naturally** — every dependent key carries the prefix,
so each run creates a fresh dependent person; the shared seeded employees simply gain another
dependent each run.

## Additive harness change

None. This object needs no derived token: `${PREFIX}` alone makes every run non-colliding, and
the three employee surrogates are plain literals in the template. The harness was not modified.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py BenDependent
# run it again immediately — a fresh prefix creates new dependents, so it passes again
```
