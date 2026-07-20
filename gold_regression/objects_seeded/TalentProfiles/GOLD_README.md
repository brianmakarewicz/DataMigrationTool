# TalentProfiles — v2 seeded gold fixture (HDL, talent profile items) — the stateful case

Converted from the frozen v1 fixture (`../../objects/TalentProfiles/`). Same shape — two good
talent-profile competency items plus one bad — loaded through HCM Data Loader (upload →
createFileDataSet → poll) and verified read-only against the base table `HRT_PROFILE_ITEMS`.
The difference from v1: the two existing person profiles, the content item, the rating model,
the rating level, the section id and the evaluator-type qualifier are **hard-coded to standard
seeded values**, not discovered at load time. No DMT tool code and no DMT database are in the
load path.

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | Literal value | Confirmed seeded (read-only BIP) |
|---|---|---|
| Person profile 1 | `PERS_300000194232824` (person number `1`, person id `300000194232310`) | yes — seeded PERSON profile, owner FUSION, status A; we did not load it |
| Person profile 2 | `PERS_300000047627793` (person number `10`, person id `300000047626100`) | yes — seeded PERSON profile, owner FUSION, status A; we did not load it |
| Content item | `Oral Communication` (COMPETENCY) | yes — seeded content catalog item, no prefix |
| Rating model | `PROFICIENCY` | yes — seeded rating model (id 5) |
| Rating level | `3` | yes — valid level on that model |
| Section id | `101` | yes — the COMPETENCY profile section on this pod |
| Evaluator-type qualifier (`QualifierId1`) | `9` | yes — the pod's most-used evaluator-type instance qualifier for section 101 (5,144 uses) |

The discovery block is removed from `recipe.json`. All values were confirmed on the target pod
through the read-only BIP relay before being written as literals. These are the exact values
v1 discovered on this pod (recorded in `../../objects/TalentProfiles/GOLD_README.md`).

## Why this is a stateful case, and how re-run safety is actually achieved

A talent profile item is a competency row that hangs off an EXISTING person's EXISTING profile.
It does not create a person or a profile. Two live findings drove the final design:

1. **A profile-item is deduplicated on (content item + qualifier pair), not on source key.**
   The v1 run already left an `Oral Communication` item on each of these two profiles, evaluated
   by the profile's own person (`QualifierId1=9`, `QualifierId2 = own person id`). A first v2
   attempt that added `Oral Communication` at the **same** qualifier pair was rejected for both
   good rows: *"The profile items data can't be saved. Delete the duplicate attributes or contact
   your profile administrator."* HDL treats an item with the same content item and the same
   evaluator-type/evaluator-person qualifier pair as a duplicate of the existing one, and our
   fixed source key can't MERGE-update the v1 item because that item belongs to a different source
   key (`10554DMTTP001/002`).

   **Fix: give our items a distinct — but still valid — evaluator person (`QualifierId2`).**
   Instead of self-evaluation, each good row names the *other* seeded person as the evaluator:
   row 1 (subject person `300000194232310`) is evaluated by person `300000047626100`, and row 2
   (subject person `300000047626100`) is evaluated by person `300000194232310`. That makes each
   a legitimate, distinct competency evaluation — a different evaluator rating the same
   competency — so it is not a duplicate of the v1 self-evaluated item. `QualifierId1` stays `9`
   (the proven evaluator-type qualifier).

2. **A prefixed SourceSystemId is not safe here.** With the qualifier pair fixed, a `${PREFIX}`
   source key on each run would create a *new* item every run, and the second run's item would
   again duplicate the first run's (same content item + same qualifier pair). So the good rows
   carry a **FIXED (non-prefixed) SourceSystemId** — `DMTTP-SEED-1`, `DMTTP-SEED-2`. The first
   run *creates* the item under that key; every later run presents the **same** source key, so
   HDL MERGE *updates our own item* — same `PROFILE_ITEM_ID`, no duplicate, no collision. This is
   the same re-run-safe pattern as the BenParticipant fixture: re-run safety comes from owning the
   record's source key, not from a moving prefix. Only the bad row keeps a `${PREFIX}`-stamped
   SourceSystemId (it never lands, so it has no state to collide with).

## The DAT (`TalentProfile.dat`, pipe-delimited HDL)

```
METADATA|ProfileItem|SourceSystemOwner|SourceSystemId|ProfileCode|ContentType|ContentItem|SectionId|DateFrom|RatingModelCode1|RatingLevelCode1|QualifierId1|QualifierId2
MERGE|ProfileItem|HRC_SQLLOADER|DMTTP-SEED-1|PERS_300000194232824|COMPETENCY|Oral Communication|101|${GL_DATE_SLASH}|PROFICIENCY|3|9|300000047626100
MERGE|ProfileItem|HRC_SQLLOADER|DMTTP-SEED-2|PERS_300000047627793|COMPETENCY|Oral Communication|101|${GL_DATE_SLASH}|PROFICIENCY|3|9|300000194232310
MERGE|ProfileItem|HRC_SQLLOADER|${PREFIX}DMTTP-BAD|PERS_300000194232824|COMPETENCY|DMT NONEXISTENT CONTENT ITEM ${PREFIX}|101|${GL_DATE_SLASH}|PROFICIENCY|3|9|300000047626100
```

| Row | SourceSystemId | ProfileCode | ContentItem | QualifierId1 / QualifierId2 | Purpose |
|---|---|---|---|---|---|
| GOOD-1 | `DMTTP-SEED-1` (fixed) | `PERS_300000194232824` | `Oral Communication` | `9` / `300000047626100` | valid → `HRT_PROFILE_ITEMS` |
| GOOD-2 | `DMTTP-SEED-2` (fixed) | `PERS_300000047627793` | `Oral Communication` | `9` / `300000194232310` | valid → `HRT_PROFILE_ITEMS` |
| BAD-1  | `${PREFIX}DMTTP-BAD` | `PERS_300000194232824` | `DMT NONEXISTENT CONTENT ITEM ${PREFIX}` | `9` / `300000047626100` | HDL error, no item |

- `QualifierId1` + `QualifierId2` are BOTH required for a COMPETENCY item (v1 gotcha): `QualifierId1`
  is the evaluator-type instance qualifier (`9`); `QualifierId2` is the evaluator person id.
- `${GL_DATE_SLASH}` is today's date (YYYY/MM/DD), the item's `DateFrom`. It is not part of the
  dedup key, so a same-day re-run under the same fixed source key simply updates the item.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

Upload → `.../dataLoadDataSets/action/uploadFile` → ContentId; submit →
`.../dataLoadDataSets/action/createFileDataSet` (`fileAction: IMPORT_AND_LOAD`) → RequestId;
poll `.../dataLoadDataSets/{RequestId}` every 30s; errors from
`.../dataLoadDataSets/{RequestId}/child/messages`. `ORA_IN_ERROR` is the EXPECTED terminal here
(the one bad row errors on purpose; the two good rows still load — partial success).

## Verification (read-only, single-table read)

Direct read of `HRT_PROFILE_ITEMS` joined to `hrc_integration_key_map` (the HDL source-key →
surrogate-id map), scoped to `source_system_owner='HRC_SQLLOADER'` and
`source_system_id LIKE 'DMTTP-SEED-%'`. A `PROFILE_ITEM_ID` present for each fixed good source key
= pass. The bad `SourceSystemId` (`${PREFIX}DMTTP-BAD`) never appears; the bad evidence is the
load-time HDL message keyed by that source key.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

Standalone HDL load path only; verification via the read-only BIP relay only.

### Run 1

| Field | Value |
|---|---|
| Prefix | `31070` |
| HDL data set RequestId | `9766776` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 loaded, 1 errored) |

Good → base `HRT_PROFILE_ITEMS` (2/2): `DMTTP-SEED-1` → `PROFILE_ITEM_ID` `300000331574294`
(on profile `PERS_300000194232824`); `DMTTP-SEED-2` → `300000331574291`
(on profile `PERS_300000047627793`).
Bad → HDL error, no item: `31070DMTTP-BAD` →
`You need to enter a valid value for the ContentItemId attribute. The current values are
104,DMT NONEXISTENT CONTENT ITEM 31070.` — absent from base.

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `57770` |
| HDL data set RequestId | `9766803` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |

Good → base `HRT_PROFILE_ITEMS` (2/2): `DMTTP-SEED-1` → **same** `PROFILE_ITEM_ID`
`300000331574294`; `DMTTP-SEED-2` → **same** `300000331574291`. The MERGE updated *our own*
items via the fixed source keys — same profile-item ids, no duplicate, no collision. Bad row
errored the same way (`57770DMTTP-BAD`).

Both runs reached the base table on the two seeded person profiles; the bad item (nonexistent
content item) errored in the loader and created nothing. **Re-runs work** — because each good row
owns a stable SourceSystemId and a non-self evaluator qualifier pair, a second run updates its own
item instead of colliding on either the source key or the duplicate-attribute check.

## No harness change

This fixture uses only `${PREFIX}` and the existing `${GL_DATE_SLASH}` derived token; the
discovery block is removed. No edit to `harness/` was needed.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py TalentProfiles
# run it again immediately — the fixed source keys make the second run update our own
# items, so it passes again
```

## Sources

- Guidelines for Loading Classic Talent Profile Data (HCM Data Loader):
  https://docs.oracle.com/en/cloud/saas/human-resources/fahbo/guidelines-for-loading-talent-profile-data.html
- HDL — Loading Competencies against Worker (QualifierId1 = evaluator type,
  QualifierId2 = evaluator person id):
  https://fusionhcmconsulting.com/2022/03/hdl-loading-competencies-against-worker/
