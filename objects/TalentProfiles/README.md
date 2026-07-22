# TalentProfiles

## Status
E2E LOADED (1 GOOD + 2 BAD, 1 correctly rejected, 2026-04-04)

## FOLLOW-UP (generator forward-fix, tracked from run 234, 2026-07-21)
On run 234 the whole Talent Profile file was rejected because the ProfileItem METADATA line
emits attributes the V2 ProfileItem object does not accept: `TalentProfileId(SourceSystemId)`,
`ContentTypeName`, `ContentItemName`, `Rating` (Fusion: "the <attr> attribute is unknown for
V2 version of the ProfileItem business object"). Because the metadata is invalid, Fusion
rejects the entire file, so the parent profiles never load either. Align the ProfileItem
generator with the proven gold fixture (`gold_regression/objects/TalentProfiles/`): attach
items by `ProfileCode`, and supply `QualifierId1` (evaluator-type qualifier) + `QualifierId2`
(the profile's person id). This is a SEPARATE forward-fix that makes the data LOAD; it is out
of scope for the reconciler honesty fix. Until then, run-234 rows are now honestly FAILED with
the real Fusion metadata message rather than left stuck at GENERATED.

## Pipeline
- Module: HCM
- HDL File: TalentProfile.dat
- Loader Type: HDL (REST upload/submit/poll)
- UCM Account: hcm$/dataloader$/import$
- Auth User: hcm_impl (password: m?CDa6^6)

## Key Attributes — Valid LOV Values
Discovered 2026-04-04 (15 values tested against demo instance):

| Attribute | Code | Description |
|-----------|------|-------------|
| ProfileUsageCode | P | Person |
| ProfileUsageCode | R | Role |
| ProfileUsageCode | J | Job |
| ProfileUsageCode | PO | Position |
| ProfileStatusCode | A | Active |
| ProfileTypeCode | PERSON | Person profile |

## Code References
- STG Table DDL: `schema/tables/136_dmt_talent_prof_stg_tbl.sql`
- STG Table DDL (Items): `schema/tables/138_dmt_talent_prof_item_stg_tbl.sql`
- TFM Table DDL: `schema/tables/137_dmt_talent_prof_tfm_tbl.sql`
- TFM Table DDL (Items): `schema/tables/139_dmt_talent_prof_item_tfm_tbl.sql`
- Validator: `packages/validators/dmt_talent_prof_validator_pkg.*`
- Transformer: `packages/transformers/dmt_talent_prof_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_talent_prof_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_talent_prof_results_pkg.*`

## Known Good Test Data
| Field | Value |
|-------|-------|
| PERSON_NUMBER | DMTW002 |
| PROFILE_CODE | DMTW002_PROF2 |
| PROFILE_TYPE_CODE | PERSON |
| PROFILE_STATUS_CODE | A |
| PROFILE_USAGE_CODE | P |

## Known Bad Test Data
| PROFILE_CODE | Failure Mode | Expected Error |
|-------------|-------------|----------------|
| BAD_PROF | PROFILE_STATUS_CODE = INVALID | Correctly rejected — invalid status code |

## Lessons Learned
- ProfileUsageCode `O` (used in early test data) is NOT valid. The correct code for person profiles is `P`.
- ProfileStatusCode must be a valid LOV code (A for Active). Arbitrary strings are rejected.
- ProfileTypeCode = PERSON is the correct value for person-linked profiles.

## History
- 2026-04-04: E2E LOADED confirmed. 1/2 good records loaded (DMTW002_PROF2 with correct P usage code), 1 correctly rejected (INVALID status code). Earlier test data with usage code O was also rejected.

## Minimal test-data plan (2026-07-15)

Goal: add a Person talent profile (plus one profile item) to the existing proven worker
`RT-WKR-G1`, so it loads to the talent base tables (`HRT_PROFILES_B` / `HRT_PROFILE_ITEMS`)
without a new hire. This object is already E2E-proven, so this is the lowest-risk of the three.

### STG tables and required columns
Parent — `DMT_TALENT_PROF_STG_TBL`. Generator emits: SourceSystemOwner (constant
HRC_SQLLOADER), SourceSystemId (`PERSON_NUMBER || '_TPROF'`), PersonId(SourceSystemId)
(= PERSON_NUMBER), ProfileCode, ProfileTypeCode, ProfileStatusCode, ProfileUsageCode,
Description. Required columns to seed:
- PERSON_NUMBER (FK to the worker) — `RT-WKR-G1`
- PROFILE_CODE — unique per person (discriminator)
- PROFILE_TYPE_CODE — `PERSON`
- PROFILE_STATUS_CODE — `A`
- PROFILE_USAGE_CODE — `P`
- DESCRIPTION (optional), SOURCE_ID, STG_STATUS='NEW'

Child (optional but recommended to prove item load) — `DMT_TALENT_PROF_ITEM_STG_TBL`.
Generator emits: SourceSystemId (`PERSON_NUMBER || '_TPITM'`), TalentProfileId(SourceSystemId)
(= `PERSON_NUMBER || '_TPROF'`, FK back to parent), ContentTypeName, ContentItemName,
DateFrom, DateTo, Rating, ProfileCode, InterestLevel. Required to seed:
- PERSON_NUMBER — `RT-WKR-G1`
- CONTENT_TYPE_NAME — `COMPETENCY`
- CONTENT_ITEM_NAME — `Oral Communication`
- PROFILE_CODE — must match the parent's PROFILE_CODE
- DATE_FROM (YYYY/MM/DD string), SOURCE_ID, STG_STATUS='NEW'

### Real reference values (confirmed live 2026-07-15, hcm_impl)
- ProfileTypeCode `PERSON`, ProfileStatusCode `A`, ProfileUsageCode `P` — already proven; real
  person profiles exist for persons 7/10/13 (`hrt_profiles_b` join `hrt_profile_types_b`,
  profile_type_code='PERSON', status 'A').
- ContentType `COMPETENCY` with real content items including `Oral Communication`,
  `People Development`, `JavaScript` (`hrt_content_items_b` join `hrt_content_items_tl`
  language='US' join `hrt_content_types_b`, context_name='COMPETENCY').
- Queries used:
  - `SELECT ct.context_name, itm.name FROM hrt_content_items_b itb JOIN hrt_content_items_tl itm ON itb.content_item_id=itm.content_item_id AND itm.language='US' JOIN hrt_content_types_b ct ON itb.content_type_id=ct.content_type_id WHERE ct.context_name='COMPETENCY'`
  - `SELECT pap.person_number, prf.profile_code, ptb.profile_type_code, prf.profile_status_code FROM hrt_profiles_b prf JOIN hrt_profile_types_b ptb ON prf.profile_type_id=ptb.profile_type_id JOIN per_all_people_f pap ON prf.person_id=pap.person_id WHERE ptb.profile_type_code='PERSON'`

### Proposed seed rows (dates as YYYY/MM/DD strings)
GOOD — parent + one item, both keyed to RT-WKR-G1:
- Parent `DMT_TALENT_PROF_STG_TBL`: PERSON_NUMBER='RT-WKR-G1', PROFILE_CODE='RT-WKR-G1_PROF',
  PROFILE_TYPE_CODE='PERSON', PROFILE_STATUS_CODE='A', PROFILE_USAGE_CODE='P',
  DESCRIPTION='Regression talent profile', SOURCE_ID='RT-TPROF-G1', STG_STATUS='NEW'.
- Item `DMT_TALENT_PROF_ITEM_STG_TBL`: PERSON_NUMBER='RT-WKR-G1', CONTENT_TYPE_NAME='COMPETENCY',
  CONTENT_ITEM_NAME='Oral Communication', PROFILE_CODE='RT-WKR-G1_PROF', DATE_FROM='2026/01/01',
  SOURCE_ID='RT-TPITM-G1', STG_STATUS='NEW'.

BAD — distinct parent record so no duplicate-line error; fails on invalid status code (proven
failure mode):
- Parent `DMT_TALENT_PROF_STG_TBL`: PERSON_NUMBER='RT-WKR-BPROF', PROFILE_CODE='RT-WKR-BPROF_PROF',
  PROFILE_TYPE_CODE='PERSON', PROFILE_STATUS_CODE='INVALID', PROFILE_USAGE_CODE='P',
  SOURCE_ID='RT-TPROF-B1', STG_STATUS='NEW'. (The SourceSystemId is `PERSON_NUMBER || '_TPROF'`,
  NOT the profile code, so the bad row must use a distinct PERSON_NUMBER to be a separate
  record — a distinct PROFILE_CODE alone would still collide.)

### Prerequisites / blockers
None. Person profile attaches directly to the worker person; no plan/unit assignment needed.
Recommended: seed this object first of the three (lowest risk, already E2E-proven).
