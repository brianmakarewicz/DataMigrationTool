# TaxCards — v2 seeded gold fixture (HDL, US Tax Withholding card)

Converted from the frozen v1 fixture (`../../objects/TaxCards/`). Same shape: one good row
that creates a brand-new US **Tax Withholding** calculation card on a card-free secondary
payroll relationship, plus one bad row that errors at load. Loaded through the HCM Data Loader
REST service (upload -> createFileDataSet -> poll) and verified read-only via BIP against the
tax-card base tables `PAY_DIR_CARDS_F` / `PAY_DIR_CARD_COMPONENTS_F`. No DMT tool code and no
DMT database are in the load path.

The difference from v1: the payroll relationship and the legislative data group are
**hard-coded to standard seeded values**, not discovered at load time. The discovery block is
removed from `recipe.json`.

## The hard-coded seeds (what v1 discovered -> now literals)

| Reference | Literal value | Confirmed seeded (read-only BIP) |
|---|---|---|
| Legislative data group name | `US Legislative Data Group` (in the .dat) | yes -- `pay_legislative_data_groups` id `300000046974970`, no prefix |
| Good payroll relationship | `PayrollRelationshipNumber = 4176` (person 4176) | yes -- seeded US demo employee's secondary relationship, card-free, we never loaded it |
| Good relationship id | `300000175399856` (verify base read) | yes |
| Tax Withholding card definition id | `300000000375476` (verify base read) | yes -- standard seeded card definition |

**Why 4176 and not v1's relationship (2022).** v1 discovered whichever US relationship was
card-free at run time and it happened to pick `2022`; that v1 run then created a card on `2022`,
so `2022` is no longer card-free and cannot be reused. Confirmed live: `2022` now carries a Tax
Withholding card. I re-queried the pod for a relationship that is free of **any** calculation
card (not just the Tax Withholding one), because a relationship that already holds a *different*
tax-related card causes the FederalTaxes override to collide. `4176` (id `300000175399856`) is
the one candidate with zero cards of any definition, so it is the safe seed. There are a handful
of other US relationships with no Tax Withholding card, but most of them already hold another
card and are not safe.

## The DAT (`TaxWithholding.dat`, pipe-delimited HDL)

```
METADATA|TaxWithholding|LegislativeDataGroupName|PayrollRelationshipNumber|CardSequence|EffectiveStartDate|SourceRef001=PayrollRelationshipNumber
MERGE|TaxWithholding|US Legislative Data Group|4176|1|${GL_DATE_SLASH}|4176
MERGE|TaxWithholding|US Legislative Data Group|${PREFIX}DMT-NO-REL|1|${GL_DATE_SLASH}|${PREFIX}DMT-NO-REL
METADATA|FederalTaxes|LegislativeDataGroupName|PayrollRelationshipNumber|CardSequence|EffectiveStartDate|SourceRef001=PayrollRelationshipNumber
MERGE|FederalTaxes|US Legislative Data Group|4176|1|${GL_DATE_SLASH}|4176
METADATA|FederalTaxes2023|LegislativeDataGroupName|PayrollRelationshipNumber|CardSequence|EffectiveStartDate|ExtraWithholding|SourceRef001=PayrollRelationshipNumber
MERGE|FederalTaxes2023|US Legislative Data Group|4176|1|${GL_DATE_SLASH}|${EXTRA_WH}|4176
```

| Row | PayrollRelationshipNumber | Purpose |
|---|---|---|
| GOOD | `4176` (seeded card-free relationship) | creates a new Tax Withholding card in `PAY_DIR_CARDS_F` dated this run |
| BAD  | `${PREFIX}DMT-NO-REL` | nonexistent relationship -> HDL error, no card |

- Every card/component line is dated `${GL_DATE_SLASH}` (the pod's today), exactly as the proven
  v1 fixture did. `${EXTRA_WH}` is a small prefix-derived positive integer (100-999) stamped as
  the Federal Extra Withholding amount so each run's component value is distinguishable.
- The settable withholding value `ExtraWithholding` sits on the **dated child** business object
  `FederalTaxes2023` (child of `FederalTaxes`, child of `TaxWithholding`), not on bare
  `FederalTaxes` -- putting it on `FederalTaxes` is rejected "unknown for V2". This hierarchy
  fact carries over verbatim from v1.

**A date split does NOT work here (finding).** I first tried the Salaries re-run trick -- dating
the `FederalTaxes2023` component at a prefix-derived far-future date so each run adds a new
date-effective component. HDL rejected the good row every time with *"An override value already
exists for item Additional Tax Amount. This item is related to calculation value definition
Additional Tax Amount."* Dating the child component far away from the parent card's own start
date breaks the card. All card/component lines must share the card's start date. So TaxCards
does not get Salaries-style re-run safety.

## Re-run safety: CREATE is one-shot per relationship (documented, not date-updated)

A Tax Withholding card is created once on a given payroll relationship. Once `4176` has a card,
a second run's `TaxWithholding` MERGE targets the **existing** card (same `dir_card_id`, no new
card) and the run still passes because the card and its component are present. It is not a new
CREATE. This is the intended, documented behavior for this object:

- **First run:** creates the card on `4176` -> new `dir_card_id`, effective today, one component.
- **Second (and later) runs:** MERGE onto that same card -> same `dir_card_id`; still passes the
  base read (card + component present). No collision, no error.

The fixture is therefore reloadable but not "adds a fresh dated row each run" -- the CREATE is
consumed on the first run against a relationship. When `4176`'s card should be re-created fresh,
point the seed at another zero-card US relationship (query `pay_dir_cards_f` for a
payroll_relationship_id with no rows).

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

Upload -> `.../dataLoadDataSets/action/uploadFile` -> ContentId; submit ->
`.../dataLoadDataSets/action/createFileDataSet` (`fileAction: IMPORT_AND_LOAD`) -> RequestId;
poll `.../dataLoadDataSets/{RequestId}` every 30s; errors from
`.../dataLoadDataSets/{RequestId}/child/messages`. Terminal `ORA_IN_ERROR` is EXPECTED (the one
bad row errors on purpose; the good card still loads -- load 1 ok / 1 err).

## Verification (read-only, single-table read)

- **Good -> base CREATE.** Direct read of `PAY_DIR_CARDS_F` for the hard-coded
  `payroll_relationship_id = 300000175399856` where `dir_card_definition_id = 300000000375476`,
  returning the `dir_card_id`, its `effective_start_date`, and a count of child rows in
  `PAY_DIR_CARD_COMPONENTS_F`. A card id present = the card reached the base table.
- **Bad -> HDL error, absent from base.** The bad `PayrollRelationshipNumber` resolves to no
  relationship, so HDL errors it at load (*"You need to enter a valid value for the SourceId
  attribute. The current values are <prefix>DMT-NO-REL."*) and it never appears in
  `PAY_DIR_CARDS_F`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.** Standalone HDL load path only; verification via the
read-only BIP relay only.

### Run 1 — the CREATE

| Field | Value |
|---|---|
| Prefix | `64617` |
| HDL data set RequestId | `9766829` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 1 loaded, 1 errored) |

Good → base **CREATE** in `PAY_DIR_CARDS_F`: relationship `4176`
(payroll_relationship_id `300000175399856`) → new `dir_card_id` **`300000331574506`**,
`effective_start_date` `2026/07/20`, 1 component in `PAY_DIR_CARD_COMPONENTS_F`.
Bad → HDL error, no card: `64617DMT-NO-REL` → *"You need to enter a valid value for the
SourceId attribute. The current values are 64617DMT-NO-REL."* — absent from `PAY_DIR_CARDS_F`.
`"pass": true`.

### Run 2 (immediately after run 1 — proves re-run behavior)

| Field | Value |
|---|---|
| Prefix | `95682` |
| HDL data set RequestId | `9766857` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 1 loaded, 1 errored) |

Good → base `PAY_DIR_CARDS_F` on relationship `4176`: **same** `dir_card_id`
**`300000331574506`** as run 1, `effective_start_date` `2026/07/20`, 1 component. The second
run's `TaxWithholding` MERGE targeted the **existing** card (no new create, no collision) and
still passed the base read. Bad → HDL error, no card: `95682DMT-NO-REL` → same SourceId error,
absent from base. `"pass": true`.

**What the two runs prove.** Run 1 is a genuine base CREATE (new `dir_card_id` on a card-free
relationship). Run 2 against the same relationship is a safe no-collision MERGE onto that same
card (same `dir_card_id`), so re-runs never fail — but they do NOT create a fresh card. The CREATE
is one-shot per relationship; that is the documented, intended behavior for this object. A date
split to force a fresh dated component every run was tried and rejected by HDL (see the finding
above), so it is deliberately not used.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py TaxCards
```

## No harness change

This fixture needs no additive harness token: it reuses the existing `${GL_DATE_SLASH}` (pod
today) and `${EXTRA_WH}` (prefix-derived 100-999) derived tokens. `objects/` (v1) is untouched.
