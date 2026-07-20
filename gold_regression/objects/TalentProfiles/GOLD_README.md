# TalentProfiles — gold regression fixture (HDL, talent profile items)

A standalone, reloadable **HDL** fixture (2 good talent-profile items + 1 bad)
that loads directly into Oracle Fusion HCM through the HCM Data Loader REST
service (upload → createFileDataSet → poll), verified read-only via BIP against
the base tables `HRT_PROFILE_ITEMS` / `HRT_PROFILES_B`. No DMT tool code and no
DMT database are in the load path.

## What this fixture loads (and why it is portable — rules 6/7/8)

A talent profile item is a competency/skill/etc. row that hangs off an EXISTING
person's EXISTING talent profile. It references content already shipped on the pod
(a content type, a content item, a rating model). This fixture does **not** create
a person, does **not** create a profile, and does **not** reference anything we
loaded earlier.

At load time it runs two read-only BIP queries against the target pod and discovers:

- **Two existing active person profiles** (`ProfileTypeCode = PERSON`,
  `profile_status_code = 'A'`) whose `ProfileCode` is the pod-native `PERS_<id>`
  form, and which do **not** already carry the content item we are about to add
  (so the MERGE creates a new item rather than colliding).
- A real **COMPETENCY content item** (`Oral Communication`), its **rating model
  code** (`PROFICIENCY`, model id 5), a valid **rating level code** for that model
  (`3`), and the **section id** COMPETENCY items live in on this pod (`101`).

Those discovered values are stamped into `TalentProfile.dat`. The profile-item
records themselves are new (prefix-stamped `SourceSystemId`, so they reload cleanly
on any future run). Because the person, the profile, the content item, the rating
model and the section are all discovered from what already exists on the target,
the fixture is self-sufficient against a fresh demo pod.

## The DAT (`TalentProfile.dat`, pipe-delimited HDL)

One `TalentProfile.dat` inside `TalentProfiles_gold.zip`. One `ProfileItem`
section, three MERGE lines. The item is attached to an existing profile by
`ProfileCode` (no source-system FK to a person/profile we own):

```
METADATA|ProfileItem|SourceSystemOwner|SourceSystemId|ProfileCode|ContentType|ContentItem|SectionId|DateFrom|RatingModelCode1|RatingLevelCode1|QualifierId1|QualifierId2
MERGE|ProfileItem|HRC_SQLLOADER|${PREFIX}DMTTP001|${PROFILE_CODE1}|COMPETENCY|${CONTENT_ITEM}|${SECTION_ID}|${GL_DATE_SLASH}|${RATING_MODEL}|${RATING_LEVEL}|${QUALIFIER_ID}|${PERSON_ID1}
MERGE|ProfileItem|HRC_SQLLOADER|${PREFIX}DMTTP002|${PROFILE_CODE2}|COMPETENCY|${CONTENT_ITEM}|${SECTION_ID}|${GL_DATE_SLASH}|${RATING_MODEL}|${RATING_LEVEL}|${QUALIFIER_ID}|${PERSON_ID2}
MERGE|ProfileItem|HRC_SQLLOADER|${PREFIX}DMTTP-BAD|${PROFILE_CODE1}|COMPETENCY|DMT NONEXISTENT CONTENT ITEM ${PREFIX}|${SECTION_ID}|${GL_DATE_SLASH}|${RATING_MODEL}|${RATING_LEVEL}|${QUALIFIER_ID}|${PERSON_ID1}
```

| Row | SourceSystemId | ProfileCode | ContentItem | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}DMTTP001` | `${PROFILE_CODE1}` (discovered) | `Oral Communication` (discovered) | valid → `HRT_PROFILE_ITEMS` |
| GOOD-2 | `${PREFIX}DMTTP002` | `${PROFILE_CODE2}` (discovered) | `Oral Communication` (discovered) | valid → `HRT_PROFILE_ITEMS` |
| BAD-1  | `${PREFIX}DMTTP-BAD` | `${PROFILE_CODE1}` | `DMT NONEXISTENT CONTENT ITEM ${PREFIX}` | HDL error, no item created |

**Tokens stamped**

- `${PREFIX}` on each `SourceSystemId` — keeps the new items unique and reloadable,
  and lets the base read find them via `hrc_integration_key_map`.
- `${PROFILE_CODE1}` / `${PROFILE_CODE2}` — two discovered existing person profiles.
- `${CONTENT_ITEM}` — discovered COMPETENCY content item (`Oral Communication`).
- `${RATING_MODEL}` — that item's rating model code (`PROFICIENCY`).
- `${RATING_LEVEL}` — a valid rating level code on that model (`3`).
- `${SECTION_ID}` — the profile section COMPETENCY items live in (`101`).
- `${QUALIFIER_ID}` — the evaluator-type instance qualifier id (discovered: `9`).
- `${PERSON_ID1}` / `${PERSON_ID2}` — each target profile's own person id, used as
  the evaluator person (`QualifierId2`).
- `${GL_DATE_SLASH}` — today's date (YYYY/MM/DD), the item's `DateFrom`.

### QualifierId1 + QualifierId2 are BOTH required for a COMPETENCY item (key gotcha)

A COMPETENCY profile item needs an instance-qualifier pair or HDL rejects it and the
item never reaches the base table:

- **`QualifierId1`** = the evaluator-type instance qualifier id (Fusion's "Official"
  / manager / self evaluator context). We discover the most-used value among existing
  COMPETENCY items on the pod (`section_id = 101`) — here `9`.
- **`QualifierId2`** = the Person Id of the evaluator. We use each target profile's
  own person id (self-evaluation is always valid and needs no extra discovery).

First attempt (prefix 62645) supplied neither → both good rows failed
*"The value of the attribute QualifierId1 isn't valid."* Second attempt (prefix
24821) supplied only `QualifierId1=9` → the error moved to
*"The value of the attribute QualifierId2 isn't valid."* Supplying **both**
`QualifierId1` (discovered qualifier) and `QualifierId2` (the profile's own person id)
loaded the two good items clean (prefix 10554). Confirmed against Oracle docs:
QualifierId1 = evaluator-type qualifier, QualifierId2 = evaluator person id (see
Sources). This mirrors the pod's second-most-common real combo (`Q1=9, Q2=<person>`).

### Why `ProfileCode`, not a source-system FK (key gotcha)

The DMT generator's ProfileItem uses `TalentProfileId(SourceSystemId)` — a
source-system FK back to a profile **we** loaded. That only resolves if the parent
profile is known to source-system owner `HRC_SQLLOADER`. Here the profiles already
exist on the pod and belong to owner `FUSION`, so a `HRC_SQLLOADER` FK would not
resolve. The HDL `ProfileItem` object accepts `ProfileCode` directly (the pod-native
`PERS_<profile_id>`), which is exactly how you attach an item to an existing
profile without owning its parent. That is what makes this portable.

**Bad-row design.** The bad row names a content item that does not exist
(`DMT NONEXISTENT CONTENT ITEM ${PREFIX}`). HDL rejects it in the loader with a
content-item lookup error and creates no profile item. The two good rows still load
(partial success: terminal `ORA_IN_ERROR`, load 2 ok / 1 err).

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `SourceSystemId` + `MessageText` |

- **REST resource is `dataLoadDataSets`** (not `hcmDataLoader`, which 404s).
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
  `ORA_IN_ERROR` is the EXPECTED terminal here (the one bad row errors on purpose;
  the two good rows still load).

## Discovery (run before build, read-only BIP, role `hcm_impl`)

Two queries, first row each. HCM base tables are reached through the
`ApplicationDB_FSCM` BIP relay with `hcm_impl` credentials.

1. `COMPETENCY_ITEM` — the content item + its rating model code, a valid rating
   level code, and the COMPETENCY section id:

```sql
SELECT 'Oral Communication' AS CONTENT_ITEM,
       rm.rating_model_code  AS RATING_MODEL,
       rl.rating_level_code  AS RATING_LEVEL,
       TO_CHAR(pi.section_id) AS SECTION_ID
FROM   hrt_content_items_b itb
JOIN   hrt_content_items_tl itm ON itb.content_item_id=itm.content_item_id AND itm.language='US'
JOIN   hrt_content_types_b  ct  ON itb.content_type_id=ct.content_type_id
JOIN   hrt_rating_models_b  rm  ON rm.rating_model_id=itb.rating_model_id
JOIN   hrt_rating_levels_b  rl  ON rl.rating_model_id=itb.rating_model_id AND rl.rating_level_code='3'
JOIN   hrt_profile_items    pi  ON pi.content_item_id=itb.content_item_id
WHERE  ct.context_name='COMPETENCY' AND itm.name='Oral Communication' AND ROWNUM=1
```

→ `${CONTENT_ITEM}='Oral Communication'`, `${RATING_MODEL}='PROFICIENCY'`,
`${RATING_LEVEL}='3'`, `${SECTION_ID}='101'`.

2. `TWO_PROFILES_WITHOUT_ITEM` — two existing active PERSON profiles that do not
   already carry `Oral Communication` (so the MERGE adds a new item):

```sql
SELECT MAX(CASE WHEN rn=1 THEN profile_code END) AS PROFILE_CODE1,
       MAX(CASE WHEN rn=2 THEN profile_code END) AS PROFILE_CODE2
FROM ( SELECT prf.profile_code,
              ROW_NUMBER() OVER (ORDER BY pap.person_number) rn
       FROM   hrt_profiles_b prf
       JOIN   hrt_profile_types_b ptb ON prf.profile_type_id=ptb.profile_type_id AND ptb.profile_type_code='PERSON'
       JOIN   per_all_people_f pap ON prf.person_id=pap.person_id
              AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
       WHERE  prf.profile_status_code='A'
         AND  prf.profile_code LIKE 'PERS\_%' ESCAPE '\'
         AND  REGEXP_LIKE(pap.person_number,'^[0-9]+$')
         AND  NOT EXISTS (SELECT 1 FROM hrt_profile_items pi
                          JOIN hrt_content_items_b cib ON pi.content_item_id=cib.content_item_id
                          JOIN hrt_content_items_tl cit ON cib.content_item_id=cit.content_item_id AND cit.language='US'
                          WHERE pi.profile_id=prf.profile_id AND cit.name='Oral Communication') )
WHERE rn<=2
```

→ `${PROFILE_CODE1}`, `${PROFILE_CODE2}` (e.g. `PERS_300000194232824`,
`PERS_300000047627793`), and each profile's own `${PERSON_ID1}` / `${PERSON_ID2}`
(used as the evaluator person for `QualifierId2`).

3. `OFFICIAL_QUALIFIER` — the most-used evaluator-type instance qualifier id among
   existing COMPETENCY items, so the pair we stamp matches how this pod records them:

```sql
SELECT TO_CHAR(qualifier_id1) AS QUALIFIER_ID
FROM ( SELECT pi.qualifier_id1, COUNT(*) cnt
       FROM hrt_profile_items pi
       WHERE pi.section_id = 101 AND pi.qualifier_id1 IS NOT NULL
       GROUP BY pi.qualifier_id1 ORDER BY COUNT(*) DESC )
WHERE ROWNUM = 1
```

→ `${QUALIFIER_ID}='9'`.

Notes on the HCM talent tables:
- `hrt_profiles_b` / `hrt_profile_types_b` — the person's profile; `profile_code`
  is the pod-native `PERS_<profile_id>` for person profiles.
- `hrt_content_items_b` (+ `_tl` for the US name) / `hrt_content_types_b`
  (`context_name='COMPETENCY'`) — the content item catalog.
- `hrt_rating_models_b` / `hrt_rating_levels_b` — rating model `PROFICIENCY`
  (id 5) with level codes `1`–`5`.
- `hrt_profile_items` — where the loaded items land; COMPETENCY items sit in
  `section_id = 101`.
- The `_vl`/`_tl` name-view variants SOAP-fault through this relay; base tables +
  the `_tl` language join work.

## Verification (read-only, direct single-table reads)

- **Good → base.** Direct read of `HRT_PROFILE_ITEMS` joined to
  `hrc_integration_key_map` (the HDL source-key → surrogate-id map) filtered by the
  run's `SourceSystemId` prefix. A `PROFILE_ITEM_ID` present for each good
  `SourceSystemId` = pass.

```sql
SELECT km.source_system_id       AS SSID,
       TO_CHAR(pi.profile_item_id) AS PROFILE_ITEM_ID
FROM   hrt_profile_items pi
JOIN   hrc_integration_key_map km
  ON   km.surrogate_id = pi.profile_item_id
 AND   km.source_system_owner = 'HRC_SQLLOADER'
WHERE  km.source_system_id LIKE '<prefix>DMTTP%'
```

- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL
  message keyed by `SourceSystemId` (`GET .../{RequestId}/child/messages`). The base
  read above returns only the two good `SourceSystemId`s — no `<prefix>DMTTP-BAD` —
  confirming the bad item was never created.

## How to run it

```bash
cd gold_regression/harness
python run_object.py TalentProfiles --prefix <PREFIX>   # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `10554` |
| HDL data set RequestId | `9764155` |
| UCM ContentId | `UCMFA07636970` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Discovered content item | `Oral Communication` (COMPETENCY, rating model `PROFICIENCY`, section 101) |
| Discovered profiles | `PERS_300000194232824`, `PERS_300000047627793` |
| Discovered qualifier | `QualifierId1=9`; `QualifierId2` = each profile's own person id |

**Good rows → base table `HRT_PROFILE_ITEMS` (2/2), on existing `HRT_PROFILES_B` profiles:**

| SourceSystemId | PROFILE_ITEM_ID | ProfileCode (existing) | ContentItem |
|---|---|---|---|
| `10554DMTTP001` | `300000331552584` | `PERS_300000194232824` | Oral Communication |
| `10554DMTTP002` | `300000331552580` | `PERS_300000047627793` | Oral Communication |

**Bad row → HDL error, no item created (1/1):**

| SourceSystemId | HDL error |
|---|---|
| `10554DMTTP-BAD` | `You need to enter a valid value for the ContentItemId attribute. The current values are 104,DMT NONEXISTENT CONTENT ITEM 10554.` |

The two good competency items reached `HRT_PROFILE_ITEMS` with real ids and hang off
the two discovered existing person profiles; the bad item (nonexistent content item,
file line 4) errored in the loader and created nothing. Gold zip
`TalentProfiles_gold.zip` (last built at prefix 10554) kept here.

**Earlier attempts (fixed):** prefix 62645 (no qualifier) and 24821 (QualifierId1
only) failed the two good rows on `QualifierId1`/`QualifierId2 isn't valid`; supplying
both instance-qualifier attributes loaded them clean (see the QualifierId gotcha
above). The bad row errored deterministically on all three runs.

## Sources

- Guidelines for Loading Classic Talent Profile Data (HCM Data Loader):
  https://docs.oracle.com/en/cloud/saas/human-resources/fahbo/guidelines-for-loading-talent-profile-data.html
- HDL — Loading Competencies against Worker (QualifierId1 = evaluator type,
  QualifierId2 = evaluator person id):
  https://fusionhcmconsulting.com/2022/03/hdl-loading-competencies-against-worker/
- HDL — Sample HDL to load Performance Rating (SourceType / QualifierId for UI
  visibility): https://fusionhcmconsulting.com/2021/09/hdl-sample-hdl-to-load-performance-rating/
- Instance Qualifier Sets:
  https://docs.oracle.com/en/cloud/saas/human-resources/faucf/instance-qualifier-sets.html
