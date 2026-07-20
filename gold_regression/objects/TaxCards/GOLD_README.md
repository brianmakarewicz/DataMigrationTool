# TaxCards — gold regression fixture (HDL, US Tax Withholding card)

Status: **PASS 2026-07-20.** A standalone, reloadable **HDL** fixture that creates a
brand-new US **Tax Withholding** calculation card on a discovered card-free payroll
relationship through the HCM Data Loader REST service (upload → createFileDataSet →
poll), verified read-only via BIP against the tax-card base tables
`PAY_DIR_CARDS_F` / `PAY_DIR_CARD_COMPONENTS_F`. No DMT tool code and no DMT database
are in the load path.

The good row is a real base **CREATE** dated this run (a new `dir_card_id` on a
relationship that had no card before), not an update — so it satisfies Rule #1 cleanly.
The bad row errors at load and never reaches base.

## What unlocked the pass (the earlier TABLED blocker, resolved)

The fixture was tabled because "every US employee already has a Tax Withholding card"
and `AssignmentNumber` resolves to the person's **default** payroll relationship (which
already has a card), so an `AssignmentNumber`-keyed load only ever produced a no-op
merge onto a pre-existing card — no new, this-run base record. Two findings fixed it:

1. **Key by `PayrollRelationshipNumber`, not `AssignmentNumber`.** Demo US employees
   have **multiple** payroll relationships; the primary/default one carries the old card,
   but a **secondary** relationship is card-free. Keying the load by that specific
   relationship's `PayrollRelationshipNumber` makes HDL target it directly and **create a
   brand-new card** there. Confirmed live: HDL's own creation-key map
   (`HRC_DL_CREATION_KEY_MAP`) reports `ACTION=NEW` with a fresh `dir_card_id` and
   `dir_card_comp_id`, and the new card is read back in `PAY_DIR_CARDS_F` with
   `effective_start_date` = this run's date.
2. **Correct child hierarchy for the settable attribute.** The prior FederalTaxes edits
   were rejected as "unknown for V2" because the attribute was on the wrong discriminator
   level. The authoritative attribute dictionary lives in the pod's HDL metadata table
   `HRC_DL_BUS_OBJECT_ATTRS_VL`. It shows the settable withholding values are on the
   **dated child** business objects `FederalTaxesBase` / `FederalTaxes2020` /
   `FederalTaxes2023` (children of `FederalTaxes`, child of `TaxWithholding`), not on
   `FederalTaxes` itself. `Extra Withholding` (VO `ExtraWithholding`) lives on
   `FederalTaxes2023`; `Additional Tax Amount` lives on `FederalTaxesBase`; and so on.
   The fixture sets `ExtraWithholding` on the `FederalTaxes2023` line so each run stamps a
   distinguishable dollar amount into the new card.

## The DAT (`TaxWithholding.dat`, pipe-delimited HDL) — proven, loads clean

```
METADATA|TaxWithholding|LegislativeDataGroupName|PayrollRelationshipNumber|CardSequence|EffectiveStartDate|SourceRef001=PayrollRelationshipNumber
MERGE|TaxWithholding|${LDG_NAME}|${PRNUM1}|1|${EFF_DATE}|${PRNUM1}
MERGE|TaxWithholding|${LDG_NAME}|${PREFIX}DMT-NO-REL|1|${EFF_DATE}|${PREFIX}DMT-NO-REL
METADATA|FederalTaxes|LegislativeDataGroupName|PayrollRelationshipNumber|CardSequence|EffectiveStartDate|SourceRef001=PayrollRelationshipNumber
MERGE|FederalTaxes|${LDG_NAME}|${PRNUM1}|1|${EFF_DATE}|${PRNUM1}
METADATA|FederalTaxes2023|LegislativeDataGroupName|PayrollRelationshipNumber|CardSequence|EffectiveStartDate|ExtraWithholding|SourceRef001=PayrollRelationshipNumber
MERGE|FederalTaxes2023|${LDG_NAME}|${PRNUM1}|1|${EFF_DATE}|${EXTRA_WH}|${PRNUM1}
```

| Row | PayrollRelationshipNumber | Purpose |
|---|---|---|
| GOOD | `${PRNUM1}` (discovered card-free US relationship) | creates a new Tax Withholding card in `PAY_DIR_CARDS_F` dated this run |
| BAD  | `${PREFIX}DMT-NO-REL` | nonexistent relationship → HDL error, no card |

The `TaxWithholding` line creates the parent card. `FederalTaxes` + `FederalTaxes2023`
carry the federal component and the `ExtraWithholding` value, all keyed by the same
`PayrollRelationshipNumber` and dated `${EFF_DATE}`.

**Tokens.** `${PREFIX}` stamps the bad-row key. `${LDG_NAME}`, `${EFF_DATE}`, `${PRNUM1}`
(the discovered card-free relationship number) and `${PRID1}` (its id, for the verify
read) are discovered at load time. `${EXTRA_WH}` is a small prefix-derived positive
integer (100–999) computed by the build step, stamped as the Federal Extra Withholding
amount so each run's value is distinguishable.

**Attribute facts learned live (V2 metadata on this pod):**

- The employee/card is keyed by **`PayrollRelationshipNumber`** (a user key), with the
  parent line carrying `SourceRef001=PayrollRelationshipNumber` inline in the METADATA
  header and the value repeated as the last column.
- Settable withholding attributes are on the **dated child** discriminators
  (`FederalTaxesBase` / `FederalTaxes2020` / `FederalTaxes2023`), NOT on `FederalTaxes`.
  Putting `ExtraWithholding` (or `AdditionalTaxAmount`, `Allowances`, `FilingStatus`, …)
  on the bare `FederalTaxes` line is rejected "unknown for V2". The complete valid list
  per object is in `HRC_DL_BUS_OBJECT_ATTRS_VL` (query by `business_object_id`).
- A `USTaxation` line naming the TRU still fails at load with
  `JBO-27035: Attribute DirRepCardId is required` (post-25B dependency on a Reporting
  Information card). It is not needed for this fixture and is omitted.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `DatFileName` + `FileLine` + `MessageText` |

Terminal `ORA_IN_ERROR` is expected here (the one bad row errors on purpose; the good
card still loads — the run reports load 1 ok / 1 err).

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns the US LDG name, the pod's date (`SYSDATE`, so `EffectiveStartDate`
always matches the pod's today — the pod runs on UTC, currently a day ahead of local),
and the first **card-free** US payroll relationship: its `PayrollRelationshipNumber`
(`${PRNUM1}`) and id (`${PRID1}`). US LDG id `300000046974970`; `Tax Withholding` card
definition id `300000000375476`. The candidate filter requires a US-LDG payroll
relationship with a primary employee assignment that has a work location, and **no
existing Tax Withholding card** on that relationship. See `recipe.json` for the exact SQL.

There are ~12 such card-free US relationships on this pod (the secondary relationships of
demo employees whose primary relationship carries the old card). Each run consumes one
(it becomes carded), so the fixture is self-renewing for a number of runs; when they run
out, a fresh card-free US relationship or worker must exist on the target pod.

## Verification (read-only, direct single-table read)

- **Good → base CREATE.** Direct read of `PAY_DIR_CARDS_F` for the discovered
  `payroll_relationship_id` (`${PRID1}`) where `dir_card_definition_id = 300000000375476`
  **and `effective_start_date >= ${EFF_DATE}`**, returning the new `dir_card_id` and a
  count of child rows in `PAY_DIR_CARD_COMPONENTS_F`. A card id present with this-run date
  = a new base card reached the base table this run.
- **Bad → HDL error, absent from base.** The bad `PayrollRelationshipNumber` resolves to
  no relationship, so HDL errors it at load (*"You need to enter a valid value for the
  SourceId attribute. The current values are &lt;prefix&gt;DMT-NO-REL."*) and it never
  appears in `PAY_DIR_CARDS_F`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py TaxCards            # discover -> build -> upload/submit/poll -> verify
```

## Live evidence

**2026-07-20 — PASS.** Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date (pod SYSDATE) | 2026/07/20 |
| Discovered LDG | `US Legislative Data Group` (id `300000046974970`) |
| Card definition | `Tax Withholding` (id `300000000375476`), `SOURCE_TYPE=PREL` |
| Base tables | `PAY_DIR_CARDS_F`, `PAY_DIR_CARD_COMPONENTS_F` |

Full end-to-end harness run, **prefix 91208** — `"pass": true`:

| Field | Value |
|---|---|
| Discovered relationship | `PayrollRelationshipNumber=2022`, id `300000096005994` (card-free before this run) |
| RequestId | `9765395` |
| ContentId | `UCMFA07638413` |
| Terminal status | `ORA_IN_ERROR` (expected: bad row errors; load 1 ok / 1 err) |
| GOOD base card | **`300000331562090`** in `PAY_DIR_CARDS_F`, `payroll_relationship_id=300000096005994`, `effective_start_date=2026/07/20`, `creation_date=2026/07/20 02:00`, 1 component |
| BAD row | `91208DMT-NO-REL` → HDL error *"You need to enter a valid value for the SourceId attribute. The current values are 91208DMT-NO-REL."*; absent from `PAY_DIR_CARDS_F` (0 rows) |

Earlier this session, keying by `PayrollRelationshipNumber=575-1` (E575's card-free
secondary relationship) first proved the mechanism: RequestId `9765343`, `ORA_SUCCESS`,
`HRC_DL_CREATION_KEY_MAP` `ACTION=NEW` for new card `300000331561987` and new component
`300000331561988` on relationship `300000162898697`, dated `2026/07/20`.

Gold zip `TaxCards_gold.zip` is kept here, rebuilt with the proven `TaxWithholding.dat`
structure (last built at prefix 91210).
