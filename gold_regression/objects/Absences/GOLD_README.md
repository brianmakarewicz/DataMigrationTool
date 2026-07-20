# Absences — GOLD (HDL PersonAbsenceEntry)

**Status: ✅ LIVE-PROVEN 2026-07-19** — prefix 15886, HDL RequestId 9764443.
Previously ⛔ BLOCKED ("conflicting processing and approval statuses" on every AbsenceStatus).
The blocker was a data-shape bug in our own fixture, not a pod configuration problem.

## What the old blocker actually was (research finding)

HDL `PersonAbsenceEntry` carries TWO independent status attributes:

- **AbsenceStatus** — the entry/processing status of the absence (e.g. `SUBMITTED`, `WITHDRAWN`).
- **ApprovalStatus** — the approval-notification status (e.g. `APPROVED`, `AWAITING`).

Our old generator (`db/packages/dmt_absence_hdl_gen_pkg`) emits only **AbsenceStatus** and has
**no ApprovalStatus attribute at all** (its column list is
`...|AbsenceType|AbsenceStatus|StartDate|EndDate|...`). Every prior attempt therefore only ever
varied `AbsenceStatus` (SUBMITTED, APPROVED, COMPLETED, CONFIRMED, ORA_* variants, NULL) while
`ApprovalStatus` was never supplied. Fusion cannot reconcile a processing status against a
missing/undefined approval status, which is exactly the "conflicting processing and approval
statuses" rejection — it fires for *all* AbsenceStatus values because the real problem is the
absent second attribute, not the value of the first.

**The fix is the documented combination:** supply BOTH, with
`AbsenceStatus=SUBMITTED` and `ApprovalStatus=APPROVED` for a recorded, approved absence.

Evidence this is the correct, pod-native combination — every real recorded absence on the
demo pod uses exactly this pair:

```
SELECT at.name, e.absence_status_cd, e.approval_status_cd, COUNT(*)
FROM anc_per_abs_entries e JOIN anc_absence_types_vl at ON at.absence_type_id=e.absence_type_id
GROUP BY at.name, e.absence_status_cd, e.approval_status_cd ORDER BY 4 DESC;
-- Vacation | SUBMITTED | APPROVED | 611   (and every high-count row is SUBMITTED/APPROVED)
```

Web sources confirming the two-attribute contract and the SUBMITTED/APPROVED combination:
- oracleprasan.blogspot.com — HDL to update an absence leave entry: metadata carries both
  `ApprovalStatus` and `AbsenceStatus`; a submitted+approved row is `APPROVED | SUBMITTED`.
- saurabhm7.blogspot.com — full PersonAbsenceEntry.dat example: metadata
  `...|AbsenceStatus|ApprovalStatus|...`, values `SUBMITTED` / `APPROVED`.
- Oracle Fusion HCM "Loading Absences Topics" (20D) and Cloud Customer Connect threads —
  same two-attribute structure.

**Portability note (rules 6/7/8): this fixture creates NO worker.** It attaches new absence
entries to persons that already exist on the pod, discovered at load time. There is no
dependency on any worker we loaded earlier.

## Object

- Type: HDL, resource `dataLoadDataSets` (REST upload → createFileDataSet → poll).
- Cred role / auth user: **hcm_impl**. UCM account `hcm$/dataloader$/import$`.
- Zip member (DAT): `PersonAbsenceEntry.dat`, discriminator `PersonAbsenceEntry`.
- Base table (the pass bar): **`ANC_PER_ABS_ENTRIES`**.

### DAT metadata (proven working, 2026-07-19)

```
METADATA|PersonAbsenceEntry|Employer|PersonNumber|AbsenceType|AbsenceReason|AbsenceStatus|ApprovalStatus|StartDate|EndDate|Duration|SourceSystemOwner|SourceSystemId
```

- `Employer` = the legal employer NAME (`US1 Legal Entity`), not an id.
- `PersonNumber` references an EXISTING person (discovered) — not `PersonId(SourceSystemId)`.
- `AbsenceType` = absence type NAME (`Vacation`).
- **`AbsenceStatus=SUBMITTED` and `ApprovalStatus=APPROVED`** (the combination that clears the
  old blocker).
- `Duration` — US `Vacation` is an **hours-based** type, so Duration is in HOURS. A 2-day range
  (StartDate 2026/08/03 → EndDate 2026/08/04) carries Duration `16` (2 × 8h). Fusion may
  recalculate the stored duration from the assignment's work schedule (observed base value 18);
  the entry is still created with a real id — that is a pass.
- `SourceSystemId` carries the `${PREFIX}` so re-runs never collide.

## Good / bad rows

- **GOOD (2):** persons `${PNUM1}` and `${PNUM2}`, a `Vacation` absence 2026/08/03–2026/08/04,
  `SUBMITTED`/`APPROVED`, Duration 16h. → base rows in `ANC_PER_ABS_ENTRIES`.
- **BAD (1):** person `${PNUM3}`, `AbsenceType='DMT NONEXISTENT ABSENCE TYPE'` (all other fields
  valid). Deterministic HDL error, creates nothing:
  *"You need to enter a valid value for the AbsenceTypeId attribute."*

## Discovery (load-time, hcm_impl — portability rule 7)

One step, `US_EMPLOYER_AND_ELIGIBLE_PERSONS`, returns the Employer name plus three eligible US
persons. Eligibility = an active primary employee assignment on the US legal entity
(`legal_entity_id = 300000046974965`) with a payroll relationship on the US LDG
(`legislative_data_group_id = 300000046974970`), person_number numeric, and NO existing US
Vacation entry (`absence_type_id = 300000071752546`) on the target start date (so re-runs are
clean). Employer name comes from the `HCM_LEMP` classification for `US1 Legal Entity`.

Discovered tokens → `${EMPLOYER}`, `${PNUM1}`, `${PNUM2}`, `${PNUM3}`.

## Full orchestration (what run_object.py does)

1. **Discover** the Employer name + 3 eligible persons (read-only BIP, hcm_impl).
2. **Build** `Absences_gold.zip` — stamp `${PREFIX}` + discovered tokens into
   `PersonAbsenceEntry.dat`, zip the single DAT.
3. **Load (HDL, hcm_impl):**
   - `POST dataLoadDataSets/action/uploadFile` `{content(b64 zip), fileName}` → ContentId.
   - `POST dataLoadDataSets/action/createFileDataSet` `{contentId, fileAction:"IMPORT_AND_LOAD"}`
     → RequestId.
   - `GET dataLoadDataSets/{RequestId}` poll `DataSetStatusCode` until terminal.
     Terminal here is `ORA_IN_ERROR` — expected, because the 1 intentional bad row makes the
     data set report `load 2 ok / 1 err`. The 2 good rows still loaded to base.
   - `GET dataLoadDataSets/{RequestId}/child/messages` for the bad-row error text.
4. **Verify (read-only BIP, hcm_impl):** direct single-table read of `ANC_PER_ABS_ENTRIES`.

## Verify SQL (read-only, hcm_impl)

Good → base (keyed by discovered person_number, scoped to the discovered Vacation type + this
run's start date):

```sql
SELECT p.person_number AS PNUM,
       TO_CHAR(MAX(e.per_absence_entry_id)) AS EID,
       TO_CHAR(MAX(e.duration)) AS DUR
FROM   anc_per_abs_entries e
JOIN   per_all_people_f p ON p.person_id = e.person_id
       AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
WHERE  e.absence_type_id = 300000071752546     -- US Vacation
AND    e.start_date = DATE '2026-08-03'
AND    p.person_number IN ('${PNUM1}','${PNUM2}','${PNUM3}')
GROUP BY p.person_number;
```

Bad → the HDL message list keyed on `SourceSystemId = '${PREFIX}DMTABS-BAD'` carries the
AbsenceTypeId error; the bad person has no Vacation entry on 2026-08-03 in the read above
(absent from base).

## Last live evidence (2026-07-19)

- Prefix **15886**, HDL RequestId **9764443**, terminal `ORA_IN_ERROR` (import 3 ok/0 err,
  load 2 ok / 1 err — the 1 err is the intentional bad row).
- Discovered: Employer `US1 Legal Entity`; persons `2`, `3` (good), `4` (bad).
- GOOD → `ANC_PER_ABS_ENTRIES`: person 2 → per_absence_entry_id **300000331553437**;
  person 3 → **300000331555559** (both Vacation, start 2026-08-03, stored duration 18).
- BAD → HDL error on line 4, SourceSystemId `15886DMTABS-BAD`:
  *"You need to enter a valid value for the AbsenceTypeId attribute. The current values are
  DMT NONEXISTENT ABSENCE TYPE,2026-08-03,300000047341483,300000046974965."* No entry created.
- verify.py `pass: true`.

## Pod reference ids (US demo)

- US legal entity / employer org: `300000046974965` (`US1 Legal Entity`).
- US LDG: `300000046974970`.
- US Vacation absence type: `300000071752546`. US Sick: `300000073800559`.
