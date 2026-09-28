# TalentProfiles — three-source reconciliation (RUN_ID 132)

Read-only discovery. Local Docker DMT DB (`dmt_owner@//localhost:1523/FREEPDB1`); Fusion reads
via `scripts/fusion_bip_query.py --cred hcm_impl`. RUN 132 prefix = **93212**.

## Object / tables / grain
- **Loader:** HDL (TalentProfile.dat + ProfileItem.dat, one zip). No FBDI import request id.
- **TFM table:** `DMT_TALENT_PROF_TFM_TBL` (`RUN_ID`, `RECON_KEY`, `TFM_STATUS`, `PROFILE_CODE`, `FUSION_PROFILE_ID`, `ERROR_TEXT`).
- **STG table:** `DMT_TALENT_PROF_STG_TBL` (no `RUN_ID`; joined via `TFM.STG_SEQUENCE_ID`). (Child items in `DMT_TALENT_PROF_ITEM_STG_TBL`.)
- **Base tables / ids:** parent `HRT_PROFILES_B.PROFILE_ID`; child `HRT_PROFILE_ITEMS.PROFILE_ITEM_ID`.
- **Grain:** one record = one person talent profile (parent). COUNT-ONLY — no money.

## STG total (count only)
```sql
SELECT COUNT(*) AS stg_total
FROM   DMT_TALENT_PROF_STG_TBL s
WHERE  s.STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_TALENT_PROF_TFM_TBL WHERE RUN_ID = 132);
```
**Result: 2.**

## TFM errors (count + real ERROR_TEXT)
```sql
SELECT TFM_STATUS, RECON_KEY, PROFILE_CODE, FUSION_PROFILE_ID,
       DBMS_LOB.SUBSTR(ERROR_TEXT,2000,1) AS error_text
FROM   DMT_TALENT_PROF_TFM_TBL
WHERE  RUN_ID = 132 AND TFM_STATUS = 'FAILED';
```
**Result: 2 FAILED** (`93212RT-WKR-G1_TPROF`, `93212RT-WKR-BPROF_TPROF`), both carrying the same real
Fusion metadata rejection:
`[FUSION_ERROR] The METADATA line can't be processed because the ContentItemName attribute is unknown for V2 version of the ProfileItem business object.; ... ContentTypeName ...; ... Rating ...; ... TalentProfileId(SourceSystemId) attribute is unknown for V2 version of the ProfileItem business object.; The file definition for th...`

This is the known generator forward-fix (README FOLLOW-UP, run 234): the ProfileItem METADATA
line emits attributes V2 rejects, so Fusion rejects the **entire file** and the parent profiles
never load either. Both records are honestly FAILED with the real Fusion message.

## Fusion successes (count — DESIGNED; 0 LOADED, NOT CONFIRMABLE IN RUN 132)
**0 LOADED for this run.** Nothing persisted (whole-file rejection), so there is no live success to
count. The Fusion query and key path are DESIGNED below; a live check for prefix `93212` returns zero rows.

**Key path (HDL tie-back, from `bip/TalentProfiles/query.sql`).** This HDL path registers a key-map
row for the **child ProfileItem only**, not the parent profile:
- `HRC_INTEGRATION_KEY_MAP` where `OBJECT_NAME = 'ProfileItem'` and `SOURCE_SYSTEM_OWNER = 'HRC_SQLLOADER'`;
  `SOURCE_SYSTEM_ID` = child `RECON_KEY` (prefixed `PERSON_NUMBER || '_TPITM'`).
- `SURROGATE_ID` = `HRT_PROFILE_ITEMS.PROFILE_ITEM_ID` (join proves the item base row exists).
- The **parent** is reached through the child: `HRT_PROFILE_ITEMS.PROFILE_ID` → `HRT_PROFILES_B.PROFILE_ID`
  (the parent gets no key-map row of its own on this pod).

Designed live query (bind prefix = `93212`):
```sql
-- child items confirmed in base
SELECT m.source_system_id, i.profile_item_id, i.profile_id
FROM   hrc_integration_key_map m
JOIN   hrt_profile_items i ON i.profile_item_id = m.surrogate_id
WHERE  m.object_name = 'ProfileItem'
AND    m.source_system_owner = 'HRC_SQLLOADER'
AND    m.source_system_id LIKE '93212' || '%';
-- parent profiles behind those items
--   FUSION_ID = MAX(i.profile_id), RECORD_KEY = 'PROF:'||i.profile_id, GROUP BY i.profile_id
```
**Live result for prefix 93212: 0 rows** (no `_TPITM`/`_TPROF` key-map rows exist for this prefix —
verified live via hcm_impl). Consistent with 0 LOADED.

## Amount column + rationale
**NONE.** Talent profiles have no monetary attribute.

## Balance check
- STG total = 2. TFM errors = 2. Fusion successes = 0 (0 LOADED).
- **Accounting: 0 + 2 = 2 = STG total. BALANCED on FAILED accounting** — every record is accounted for
  (both honestly FAILED with a real Fusion error). The LOADED path is designed but **not confirmable in
  run 132** because nothing loaded.

## Gotchas (HDL specifics)
- Whole-file HDL rejection: an invalid METADATA attribute rejects the entire TalentProfile.dat file, so
  BOTH the GOOD and BAD records fail together — even the otherwise-valid `_G1` record. This is a generator
  forward-fix (align ProfileItem gen with the gold fixture), tracked separately from reconciliation honesty.
- No import ESS request id (HDL). Parent profile has **no own key-map row** — it is confirmed through the
  child ProfileItem's `PROFILE_ID`. Never key on the prefix alone.
- The `SOURCE_SYSTEM_OWNER = 'HRC_SQLLOADER'` filter is essential: seeded/Fusion-native ProfileItem rows
  exist that must not be miscounted as ours.
- Base tables `HRT_PROFILE_ITEMS` / `HRT_PROFILES_B` are selectable by name from the BIP user (the `_VL`/`_B`
  variants differ); read with **hcm_impl**.
