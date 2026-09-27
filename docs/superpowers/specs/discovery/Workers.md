# Workers — three-source reconciliation (RUN_ID 132)

Read-only discovery. Local Docker DMT DB (`dmt_owner@//localhost:1523/FREEPDB1`); Fusion reads
via `scripts/fusion_bip_query.py --cred hcm_impl` against the live demo pod. RUN 132 prefix = **93212**.

## Object / tables / grain
- **Loader:** HDL (Worker.dat). No FBDI import request id; no `IMPORT_ESS_JOB_ID`.
- **TFM table:** `DMT_WORKER_TFM_TBL` (one row per person; `RUN_ID`, `RECON_KEY`, `TFM_STATUS`, `FUSION_PERSON_ID`, `ERROR_TEXT`).
- **STG table:** `DMT_WORKER_STG_TBL` (no `RUN_ID`; joined to the run via `TFM.STG_SEQUENCE_ID`).
- **Base table / id:** `PER_ALL_PEOPLE_F.PERSON_ID` (person component). Related components
  land in `PER_PERSON_NAMES_F` / `PER_PERIODS_OF_SERVICE`; the object's LOADED/FAILED verdict is at the **person grain**.
- **Grain:** one record = one worker (person). COUNT-ONLY — no money column.

## STG total (count only)
```sql
SELECT COUNT(*) AS stg_total
FROM   DMT_WORKER_STG_TBL s
WHERE  s.STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_WORKER_TFM_TBL WHERE RUN_ID = 132);
```
**Result: 2.** (Run's record set = the 2 TFM rows for RUN 132; STG has no RUN_ID.)

## TFM errors (count + real ERROR_TEXT)
```sql
SELECT TFM_STATUS, RECON_KEY, FUSION_PERSON_ID,
       DBMS_LOB.SUBSTR(ERROR_TEXT,1000,1) AS error_text
FROM   DMT_WORKER_TFM_TBL
WHERE  RUN_ID = 132 AND TFM_STATUS = 'FAILED';
```
**Result: 1 FAILED —** `93212RT-WKR-B1`:
`[FUSION_ERROR] The WorkerName SDO, LastName attribute value is required. You must enter a value.`
Real Fusion HDL rejection. Confirmed present.

## Fusion successes (count — LIVE FROM FUSION)
**Key path (HDL tie-back — NOT an import request id).** HDL stamps every loaded business object into
`HRC_INTEGRATION_KEY_MAP` (`SOURCE_SYSTEM_ID`, `OBJECT_NAME`, `SURROGATE_ID`). The TFM row's
`RECON_KEY` (prefixed PERSON_NUMBER) equals the map's `SOURCE_SYSTEM_ID`; `SURROGATE_ID` is the
base PK and equals our captured `FUSION_PERSON_ID`. Confirm the surrogate against `PER_ALL_PEOPLE_F`.

Live query (bind prefix = `93212`), matches `bip/Workers/query.sql`:
```sql
SELECT m.object_name, m.source_system_id, m.surrogate_id
FROM   hrc_integration_key_map m
WHERE  m.source_system_id LIKE '93212' || '%'
AND    m.object_name = 'Person'
AND    EXISTS (SELECT 1 FROM per_all_people_f b WHERE b.person_id = m.surrogate_id);
```
**Result (live, hcm_impl): 1 success.**
- `Person  93212RT-WKR-G1  SURROGATE_ID 300000333896708`
- Confirmed in base: `PER_ALL_PEOPLE_F.PERSON_ID = 300000333896708`, `PERSON_NUMBER = 93212RT-WKR-G1`.
- Matches the captured `FUSION_PERSON_ID = 300000333896708` on the LOADED TFM row.

(The load also stamped PersonName `_NME` → 300000333896711 and PeriodOfService `_POS` → 300000333896710,
but the object verdict is at the person grain: 1 worker loaded.)

## Amount column + rationale
**NONE.** Workers is a count-only object; no monetary attribute.

## Balance check
Fusion successes (1) + TFM errors (1) = 2 = STG total (2). **BALANCED.**

## Gotchas (HDL specifics)
- No FBDI/import ESS request id exists for HDL; never key the Fusion tie-back on an import request id.
- Tie-back is the captured id path: TFM `RECON_KEY` = `HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID`;
  `SURROGATE_ID` = base PK = TFM `FUSION_PERSON_ID`. Never key on the prefix alone (prefix only scopes the run).
- Confirm `SURROGATE_ID` against the real base table (`PER_ALL_PEOPLE_F`) so a row counts only on base-table proof.
- Base tables `PER_ALL_PEOPLE_F` / `PER_PERSON_NAMES_F` / `PER_PERIODS_OF_SERVICE` need the **hcm_impl** cred
  (fin_impl was not required here; hcm_impl worked).
