# Absences — v2 seeded gold fixture (HDL PersonAbsenceEntry) — a stateful case

Converted from the frozen v1 fixture (`../../objects/Absences/`). Same shape: two good + one
bad absence entries, loaded via HCM Data Loader (upload → createFileDataSet → poll), verified
read-only against the base table `ANC_PER_ABS_ENTRIES`. The difference from v1: the legal
employer, the eligible persons, and the absence type are **hard-coded to standard seeded
values**, not discovered at load time. The discovery block is deleted from `recipe.json`.

**Status: LIVE-PROVEN 2026-07-20 (v2). PASS. Two consecutive runs both passed (re-run safe).**

## The hard-coded seeds (what v1 discovered → now literals)

| Reference | Literal value | Confirmed seeded (no prefix) |
|---|---|---|
| Employer (legal employer NAME) | `US1 Legal Entity` (id `300000046974965`) | Standard demo US legal entity |
| Absence type NAME | `Vacation` (id `300000071752546`) | Standard demo absence type |
| Good person 1 | person number `6` (assignment `E6`) | Long-tenured seeded US1 employee |
| Good person 2 | person number `9` (assignment `E9`) | Long-tenured seeded US1 employee |
| Bad person | person number `10` (assignment `E10`) | Long-tenured seeded US1 employee |

All three persons are seeded US1-legal-entity employees on the US legislative data group
(`legislative_data_group_id = 300000046974970`) that we never loaded — single/low person
numbers with assignment start dates in the 2000s, confirmed via read-only BIP (hcm_impl). The
`Employer` and `AbsenceType` are the same values v1's discovery resolved to.

### Why persons 6 / 9 / 10, not the persons v1 happened to pick (2 / 3)

v1 discovered "eligible persons with no existing Vacation entry on the target date" and, on its
last run, landed on person numbers 2 and 3. Those two persons have a **freshly created
assignment** (effective from 2026-07-19) whose published **work schedule** only covers a narrow
window — Fusion accepted only the exact date v1 used (2026-08-03) and rejects every other date
with *"You need to enter an absence date that's on a scheduled workday."* That is fine for a
one-shot discovery run but useless for a fixed seeded fixture that must accept a **range** of
dates across many re-runs.

Persons 6 and 9 are long-tenured US1 employees (assignment start dates 2001 and 2009) with a
real, broadly-published work schedule, so any near-future Monday validates as a scheduled
workday. Both were probed live and accepted absences across a wide date range (2026-08-10 and
2027-01-04), each creating a real base entry — proven schedulable, so they are the seeded good
persons. Person 10 (also long-tenured) carries the intentional bad row.

## Re-run safety (the stateful part) — solved with a prefix-derived, schedulable date

An absence entry is keyed by **person + start/end dates**. If the date were fixed, a second run
against the same seeded person would collide on the existing entry. The fix: derive the absence
window from the run prefix so every run books a **new distinct window** on the same persons.

Two constraints shape the derived date, and both are met by a new harness token
(`ABS_START` / `ABS_END` / `ABS_START_DASH` in `harness/build_artifact.py::derived_tokens`):

1. **Distinct per run** — so consecutive runs never collide. The offset is derived from the
   prefix.
2. **A scheduled workday, near the present** — Fusion rejects a date that is not a scheduled
   workday, and the persons' work schedule only covers dates near today (a date centuries out is
   rejected). So the start is `today + (30..330) days` (offset from the prefix), then snapped
   **forward to the next Monday**; the two-day window is Monday → Tuesday, both weekdays on the
   standard demo work schedule and inside the scheduled horizon.

`${PREFIX}` also stays on each entry's `SourceSystemId`. `${ABS_START_DASH}` (YYYY-MM-DD) scopes
the verify base read to this run's exact start date.

## DAT metadata (unchanged from v1, proven working)

```
METADATA|PersonAbsenceEntry|Employer|PersonNumber|AbsenceType|AbsenceReason|AbsenceStatus|ApprovalStatus|StartDate|EndDate|Duration|SourceSystemOwner|SourceSystemId
```

- `Employer` = legal employer NAME (`US1 Legal Entity`), not an id.
- `PersonNumber` references an EXISTING seeded person (`6`, `9`, `10`) — not `PersonId(SourceSystemId)`.
- `AbsenceType` = absence type NAME (`Vacation`).
- **`AbsenceStatus=SUBMITTED` and `ApprovalStatus=APPROVED`** — the documented combination that
  clears the old "conflicting processing and approval statuses" blocker. Both attributes are
  supplied; kept exactly as v1.
- `Duration` = `16` (hours; US Vacation is an hours-based type, 2 × 8h). Fusion recalculates the
  stored duration from the assignment's work schedule (observed base value `18`); the entry is
  still created with a real id — that is a pass.
- `SourceSystemId` carries `${PREFIX}` so re-runs never collide.

## Good / bad rows

- **GOOD (2):** persons `6` and `9`, a `Vacation` absence over the prefix-derived Monday→Tuesday
  window, `SUBMITTED`/`APPROVED`, Duration 16h → base rows in `ANC_PER_ABS_ENTRIES`.
- **BAD (1):** person `10`, `AbsenceType='DMT NONEXISTENT ABSENCE TYPE'` (all other fields valid).
  Deterministic HDL error, creates nothing:
  *"You need to enter a valid value for the AbsenceTypeId attribute."* Absent from base.

## Verify SQL (read-only, hcm_impl)

Good → base, keyed by seeded person number, scoped to the seeded Vacation type and this run's
prefix-derived start date `${ABS_START_DASH}`:

```sql
SELECT p.person_number AS PNUM,
       TO_CHAR(MAX(e.per_absence_entry_id)) AS EID,
       TO_CHAR(MAX(e.duration)) AS DUR
FROM   anc_per_abs_entries e
JOIN   per_all_people_f p ON p.person_id = e.person_id
       AND SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
WHERE  e.absence_type_id = 300000071752546          -- US Vacation
AND    e.start_date = DATE '${ABS_START_DASH}'
AND    p.person_number IN ('6','9','10')
GROUP BY p.person_number;
```

Bad → the HDL message list keyed on `SourceSystemId = '${PREFIX}DMTABS-BAD'` carries the
AbsenceTypeId error; the bad person has no Vacation entry on this run's start date in the read
above (absent from base).

## Pod reference ids (US demo)

- US legal entity / employer org: `300000046974965` (`US1 Legal Entity`).
- US legislative data group: `300000046974970`.
- US Vacation absence type: `300000071752546`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

### Run 1

| Field | Value |
|---|---|
| Prefix | `16928` (absence window `2026/12/28` → `2026/12/29`, a Monday) |
| HDL data set RequestId | `9766600` |
| Terminal status | `ORA_IN_ERROR` (expected: 2 loaded, 1 errored) |

Good → base `ANC_PER_ABS_ENTRIES` (2/2): person `6` per_absence_entry_id `300000331570025`
(duration 18); person `9` per_absence_entry_id `300000331570159` (duration 18).
Bad → HDL error, no entry: `16928DMTABS-BAD` →
*"You need to enter a valid value for the AbsenceTypeId attribute..."*. Absent from base.

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `31764` (absence window `2027/05/10` → `2027/05/11`, a different Monday) |
| HDL data set RequestId | `9766622` |
| Terminal status | `ORA_IN_ERROR` (expected) |

Good → base `ANC_PER_ABS_ENTRIES` (2/2): person `6` per_absence_entry_id `300000331570394`;
person `9` per_absence_entry_id `300000331570539` — **new entry ids on the same persons**, at a
new (later) absence window. Bad row errored the same way, absent from base.

Both runs added fresh, distinct absence windows to the same seeded persons with no collision.
**Re-runs work.**

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Absences
# run it again immediately — a fresh prefix gives a fresh (later) Monday window, so it passes again
```

## Harness edit (additive only)

`harness/build_artifact.py::derived_tokens` gained three prefix-derived tokens — `ABS_START`,
`ABS_END` (YYYY/MM/DD, for the .dat StartDate/EndDate) and `ABS_START_DASH` (YYYY-MM-DD, for the
verify DATE literal). They compute `today + (30..330) days` from the prefix, snapped forward to
the next Monday. Purely additive; no existing token or behavior changed.
