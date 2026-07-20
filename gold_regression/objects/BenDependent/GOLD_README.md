# BenDependent — gold regression fixture (HDL, Contact / ContactRelationship)

A standalone, reloadable **HDL** fixture (2 good dependent contacts + 1 bad) that
loads directly into Oracle Fusion HCM through the HCM Data Loader REST service
(upload -> createFileDataSet -> poll), verified read-only via BIP against the base
table `PER_CONTACT_RELSHIPS_F`. No DMT tool code and no DMT database are in the
load path.

## What "BenDependent" really loads — and how it differs from BenParticipant

The migration object **BenDependent** (Dependent Enrollment) is about a **person's
dependent** — a child, spouse, or other family member attached to an existing
employee and marked as a benefits dependent. That is a **contact relationship**,
not a balance amount.

The sibling **BenParticipant** fixture stamps a benefit-balance amount
(`PersonBenefitBalance`) onto an existing person. It creates no new person and no
relationship — it only writes a dated value against a person who already exists.

BenDependent is a genuinely different shape:

- it **creates a new person** (the dependent/contact), and
- it **creates a `PER_CONTACT_RELSHIPS_F` relationship** that links that new
  dependent to an **existing employee**, with `DEPENDENT_FLAG = 'Y'` and a
  contact type of `C` (Child).

So the two fixtures load different Fusion business objects into different base
tables. BenParticipant -> `BEN_PER_BNFTS_BAL_F`. BenDependent -> `PER_CONTACT_RELSHIPS_F`.

### Why not just copy the DMT generator?

The DMT pipeline generator `DMT_BEN_DEPEND_HDL_GEN_PKG` is a shortcut: it emits a
`PersonBenefitBalance` DAT keyed on the primary person number, exactly like the
participant generator. It never actually writes the dependent person or the
contact relationship — its staging table carries `DEPENDENT_PERSON_NUMBER` and
`BENEFIT_RELATIONSHIP_NAME` columns that the generated DAT throws away. Copying it
would have produced a fixture indistinguishable from BenParticipant and would not
have proven a dependent record at all. This fixture loads the real dependent
object (`ContactRelationship`) so the gold copy actually exercises the dependent
shape.

## Why this fixture is portable (no upstream dependency)

A dependent contact attaches a **new** person to an **existing** employee. This
fixture does **not** load a worker first and does **not** reference the prefixed
workers we created earlier.

At load time it runs one read-only BIP query against the target pod and discovers
**three existing US1-legal-entity employees** (by their `PersonNumber` and their
`person_id` surrogate). Each discovered employee becomes the parent that one new
dependent is attached to. The new dependent persons are created fresh under our
own prefix, so the fixture reloads cleanly on any future run without colliding.

### The key portability decision — reference the existing employee by surrogate id, resolved through the seeded FUSION source key

The existing employee is referenced from the `ContactRelationship` line by the
**unqualified `RelatedPersonId`** attribute set to the employee's numeric
`person_id` surrogate (e.g. `300000047626100`).

This works because every seeded demo person already has a source-key row in
`HRC_INTEGRATION_KEY_MAP` under `SourceSystemOwner = 'FUSION'` where
`SourceSystemId = person_id`. HCM Data Loader resolves the unqualified
`RelatedPersonId` FK straight to that surrogate. We therefore never need the
employee to carry an `HRC_SQLLOADER` source key of our own — the fixture is
self-sufficient against a fresh pod.

**Attributes that do NOT work on this pod (proven by failed loads):**

- `PersonId(PersonNumber)` / `RelatedPersonId(PersonNumber)` — HDL rejects the
  key-resolution hint `PersonNumber` for the ContactRelationship business object
  ("The key resolution hint PersonNumber ... is invalid").
- `RelatedPersonNumber` + `ExistingPerson` — this older-release convenience pair
  is ignored by the current business-object version; the loader still demands
  `RelatedPersonId` ("You must enter a valid value for the RelatedPersonId field").
- `SourceSystemOwner = FUSION` on our own new records — rejected ("The
  SourceSystemOwner value FUSION is unknown"). Our new records must use a
  registered owner (`HRC_SQLLOADER`); only the *reference* to the existing person
  goes through the seeded FUSION key.

## The DAT (`Contact.dat`, pipe-delimited HDL)

The top-level HDL business object is **`Contact`** (which creates a new contact
person); its children `ContactName` and `ContactLegislativeData` complete the
person; and its child `ContactRelationship` links the new person to the existing
employee. All four sections live in one `Contact.dat` inside
`BenDependent_gold.zip`.

```
METADATA|Contact|SourceSystemOwner|SourceSystemId|EffectiveStartDate|EffectiveEndDate|StartDate|DateOfBirth
MERGE|Contact|HRC_SQLLOADER|${PREFIX}DMTDEP001|2020/01/01|4712/12/31|2020/01/01|2010/03/15
...
METADATA|ContactName|SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|EffectiveStartDate|EffectiveEndDate|LegislationCode|NameType|FirstName|LastName
MERGE|ContactName|HRC_SQLLOADER|${PREFIX}DMTDEP001_NME|${PREFIX}DMTDEP001|2020/01/01|4712/12/31|US|GLOBAL|Child|Dep${PREFIX}One
...
METADATA|ContactLegislativeData|SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|EffectiveStartDate|EffectiveEndDate|LegislationCode|Sex|MaritalStatus
MERGE|ContactLegislativeData|HRC_SQLLOADER|${PREFIX}DMTDEP001_LEG|${PREFIX}DMTDEP001|2020/01/01|4712/12/31|US|M|S
...
METADATA|ContactRelationship|SourceSystemOwner|SourceSystemId|PersonId(SourceSystemId)|RelatedPersonId|EffectiveStartDate|EffectiveEndDate|ContactType|DependentFlag|PersonalFlag
MERGE|ContactRelationship|HRC_SQLLOADER|${PREFIX}DMTDEP001_REL|${PREFIX}DMTDEP001|${PID1}|2020/01/01|4712/12/31|C|Y|Y
MERGE|ContactRelationship|HRC_SQLLOADER|${PREFIX}DMTDEP002_REL|${PREFIX}DMTDEP002|${PID2}|2020/01/01|4712/12/31|C|Y|Y
MERGE|ContactRelationship|HRC_SQLLOADER|${PREFIX}DMTDEP-BAD_REL|${PREFIX}DMTDEP-BAD|${PID3}|2020/01/01|4712/12/31|ZZINVALID|Y|Y
```

| Row | Contact (new dependent) | Attached to employee | ContactType | Purpose |
|---|---|---|---|---|
| GOOD-1 | `Dep${PREFIX}One` (Child) | `${PNUM1}` / `${PID1}` (discovered) | `C` | valid -> `PER_CONTACT_RELSHIPS_F` |
| GOOD-2 | `Dep${PREFIX}Two` (Child) | `${PNUM2}` / `${PID2}` (discovered) | `C` | valid -> `PER_CONTACT_RELSHIPS_F` |
| BAD-1  | `Dep${PREFIX}Bad` (Child)  | `${PID3}` (discovered) | `ZZINVALID` | HDL error, no relationship |

**Tokens stamped**

- `${PREFIX}` on every `SourceSystemId` and on the dependent last names
  (`Dep${PREFIX}One/Two/Bad`) — keeps the records unique and reloadable, and makes
  each dependent findable in the base by its prefixed last name.
- `${PID1}`, `${PID2}`, `${PID3}` — discovered `person_id` surrogates of the three
  existing US1 employees; used as the unqualified `RelatedPersonId` FK.
- `${PNUM1..3}` — the same employees' person numbers (discovery output; recorded
  in the evidence for traceability).

**Date rule.** `DateOfBirth` must be **before** the person's `StartDate`
(otherwise: "You need to enter a date of birth that's before the start date of the
person record"). The dependents are modeled as children born 2010-2012 with a
person start / effective date of 2020/01/01.

**Bad-row design.** The bad row's `ContactType` is `ZZINVALID`, which is not in the
`CONTACT` lookup. HDL loads the bad row's *person* (Contact/ContactName/
ContactLegislativeData import fine) but rejects its **ContactRelationship** with a
deterministic error and creates no relationship. Because the base verify keys on
`DEPENDENT_FLAG = 'Y'` relationships, the bad dependent is correctly absent from
the base (its person exists but has no dependent relationship).

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` -> `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` -> `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

- REST resource is `dataLoadDataSets` (not `hcmDataLoader`, which 404s).
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
- **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on
  purpose. The two good dependents still load (partial success: load 2 ok / 1 err).
- Immediately after `createFileDataSet` the data set is not yet queryable, so the
  first GET may 404; the poller treats that as not-ready and retries.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns three existing US1-legal-entity employees — each employee's
`PersonNumber` and their `person_id` surrogate.

```sql
SELECT MAX(CASE WHEN rn=1 THEN person_number END) AS PNUM1,
       MAX(CASE WHEN rn=2 THEN person_number END) AS PNUM2,
       MAX(CASE WHEN rn=3 THEN person_number END) AS PNUM3,
       MAX(CASE WHEN rn=1 THEN person_id END)     AS PID1,
       MAX(CASE WHEN rn=2 THEN person_id END)     AS PID2,
       MAX(CASE WHEN rn=3 THEN person_id END)     AS PID3
FROM (
  SELECT p.person_number, TO_CHAR(p.person_id) person_id,
         ROW_NUMBER() OVER (ORDER BY p.person_number) rn
  FROM per_all_assignments_m a
  JOIN per_all_people_f p
    ON p.person_id = a.person_id
   AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
  WHERE a.legal_entity_id = 300000046974965          -- US1 legal entity
    AND a.effective_latest_change = 'Y'
    AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
    AND a.assignment_type = 'E' AND a.primary_flag = 'Y'
    AND REGEXP_LIKE(p.person_number, '^[0-9]+$')      -- seeded demo persons only
) WHERE rn <= 3
```

Notes on the HCM tables (reached through the `ApplicationDB_FSCM` BIP relay with
`hcm_impl` credentials — no separate HCM data source needed):

- **`per_contact_relships_f`** is the person contact-relationship BASE table (409
  rows on this pod). Columns used: `contact_relationship_id` (PK), `person_id`
  (the employee), `contact_person_id` (the dependent/contact), `contact_type`,
  `dependent_flag`, `effective_start_date`.
- **`hcm_lookups` WHERE `lookup_type='CONTACT'`** is the LOV that `ContactType`
  validates against. `C` (Child) is heavily used on this pod (109 existing rows)
  and is a proven-valid dependent type.
- **`hrc_integration_key_map`** maps each existing person to a `FUSION`-owned
  source key equal to their `person_id` — the mechanism that lets the unqualified
  `RelatedPersonId` FK resolve to a seeded employee.

## Verification (read-only, direct single-table read)

- **Good -> base.** Direct read of `PER_CONTACT_RELSHIPS_F` joined to
  `PER_PERSON_NAMES_F` on the contact person, scoped to `dependent_flag = 'Y'` and
  the discovered prefixed dependent last names. A `CONTACT_RELATIONSHIP_ID` present
  for each good dependent last name = pass.

```sql
SELECT nm.last_name AS LNAME,
       TO_CHAR(MAX(cr.contact_relationship_id)) AS RID,
       MAX(cr.contact_type) AS CT,
       MAX(cr.dependent_flag) AS DF
FROM per_contact_relships_f cr
JOIN per_person_names_f nm
  ON (nm.person_id = cr.contact_person_id OR nm.person_id = cr.person_id)
 AND nm.name_type = 'GLOBAL'
 AND SYSDATE BETWEEN nm.effective_start_date AND nm.effective_end_date
WHERE cr.dependent_flag = 'Y'
  AND SYSDATE BETWEEN cr.effective_start_date AND cr.effective_end_date
  AND nm.last_name IN ('Dep<PREFIX>One','Dep<PREFIX>Two','Dep<PREFIX>Bad')
GROUP BY nm.last_name
```

- **Bad -> HDL error, absent from base.** The bad evidence is the load-time HDL
  message keyed by the ContactRelationship `SourceSystemId` (`<PREFIX>DMTDEP-BAD_REL`):
  *"The ZZINVALID value for the ContactType attribute is invalid and doesn't exist
  in the CONTACT list of values."* The base read above returns no `dependent_flag='Y'`
  row for the bad dependent, confirming absence.

## How to run it

```bash
cd gold_regression/harness
python run_object.py BenDependent --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90419` |
| HDL data set RequestId | `9764674` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 12 ok / 0 err; load **2 ok / 1 err** |
| Discovered employees | `${PNUM1}=10` / `${PID1}=300000047626100`, `${PNUM2}=100` / `${PID2}=300000047887398`, `${PNUM3}=1006` / `${PID3}=300000066861968` |

**Good rows → base table `PER_CONTACT_RELSHIPS_F` (2/2):**

| Dependent (last name) | CONTACT_RELATIONSHIP_ID | ContactType | DependentFlag |
|---|---|---|---|
| `Dep90419One` | `300000331556109` | `C` | `Y` |
| `Dep90419Two` | `300000331556120` | `C` | `Y` |

**Bad row → HDL error, no relationship created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `90419DMTDEP-BAD_REL` | `The ZZINVALID value for the ContactType attribute is invalid and doesn't exist in the CONTACT list of values.` |

The two good dependents reached `PER_CONTACT_RELSHIPS_F` with real relationship ids
against existing demo employees; the bad relationship errored in the loader (file
line 16) and created nothing. Gold zip `BenDependent_gold.zip` (last built at
prefix 90419) kept here.

### Earlier attempts (all fixed, in order)

1. **One file per business object.** First DAT was named `ContactRelationship.dat`
   and carried `Person`/`PersonName`/`PersonLegislativeData` sections. HDL treats
   the file name as the top-level object and rejected those as invalid
   discriminators for ContactRelationship. Fix: top-level object is `Contact`
   (file `Contact.dat`) with children `ContactName`, `ContactLegislativeData`,
   `ContactRelationship`.
2. **Existing employee could not be referenced by user key.**
   `PersonId(PersonNumber)`, `RelatedPersonId(PersonNumber)`, and the
   `RelatedPersonNumber`+`ExistingPerson` pair were all rejected by the current
   business-object version. Fix: unqualified `RelatedPersonId = person_id`
   surrogate, resolved through the seeded `FUSION` source key in
   `HRC_INTEGRATION_KEY_MAP`.
3. **`SourceSystemOwner=FUSION` on our own records rejected** ("FUSION is
   unknown"). Fix: our new records use `HRC_SQLLOADER`; only the reference to the
   existing person rides the FUSION key.
4. **Date of birth after start date.** DOB `2015` with StartDate `1990` failed.
   Fix: children born 2010-2012, person start/effective 2020/01/01.
