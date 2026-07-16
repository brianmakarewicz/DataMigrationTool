# TaxCalculationCard

## Status
NOT BUILT (HDL)

## Pipeline
- Module: HCM
- HDL File: TaxCalculationCard.dat
- Loader Type: HDL (REST upload/submit/poll)
- Auth User: fin_impl

## Code References
- STG Table DDL: `schema/tables/132_dmt_tax_card_stg_tbl.sql`
- STG Table DDL (Components): `schema/tables/134_dmt_tax_card_comp_stg_tbl.sql`
- TFM Table DDL: `schema/tables/133_dmt_tax_card_tfm_tbl.sql`
- TFM Table DDL (Components): `schema/tables/135_dmt_tax_card_comp_tfm_tbl.sql`
- Validator: `packages/validators/dmt_tax_card_validator_pkg.*`
- Transformer: `packages/transformers/dmt_tax_card_transform_pkg.*`
- HDL Generator: `packages/generators/hdl/dmt_tax_card_hdl_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_tax_card_results_pkg.*`

## Reference Files
None.

## Known Issues
None -- not yet built.

## Minimal test-data plan (2026-07-15)

Goal: add a US calculation card to the existing proven worker `RT-WKR-G1` so it loads to the
tax-card base tables (`PAY_DIR_CARDS_F` and related). IMPORTANT: the generator carries an
unresolved load blocker (see prerequisites) — a minimal seed can be written but is NOT expected
to reach the base table until that blocker is closed.

### STG tables and required columns
Parent — `DMT_TAX_CARD_STG_TBL`. Generator (`DMT_TAX_CARD_HDL_GEN_PKG`) emits only four columns
for the CalculationCard discriminator: SourceSystemOwner (constant HRC_SQLLOADER), SourceSystemId
(`PERSON_NUMBER || '_TAXCARD'`), EffectiveStartDate, LegislativeDataGroupName. So the only
columns that matter for the parent are:
- PERSON_NUMBER (drives SourceSystemId only — the DAT does NOT emit a PersonId FK) — `RT-WKR-G1`
- EFFECTIVE_START_DATE (YYYY/MM/DD string) — REQUIRED for this object (unlike most HDL objects)
- LEGISLATIVE_DATA_GROUP_NAME — `US Legislative Data Group`
- SOURCE_ID, STG_STATUS='NEW'
Note: DIRECTIVE_CARD_NAME, TAX_REPORTING_UNIT, COMPONENT_GROUP_NAME columns exist on the STG
table but the generator comments mark them INVALID in V2 and does not emit them.

Child — `DMT_TAX_CARD_COMP_STG_TBL` (CardComponent). Generator emits: SourceSystemId
(`PERSON_NUMBER || '_TAXCOMP'`), CalculationCardId(SourceSystemId) (= `PERSON_NUMBER || '_TAXCARD'`,
FK to parent), ComponentName, ComponentValue, LegislativeDataGroupName. Required to seed:
- PERSON_NUMBER — `RT-WKR-G1`
- COMPONENT_NAME, COMPONENT_VALUE
- LEGISLATIVE_DATA_GROUP_NAME — `US Legislative Data Group`
- SOURCE_ID, STG_STATUS='NEW'

### Real reference values (confirmed live 2026-07-15, hcm_impl)
- LDG `US Legislative Data Group` is a real legislative data group
  (`per_legislative_data_groups_vl` WHERE name LIKE 'US%').
- Calculation cards exist on this instance: `SELECT COUNT(*) FROM pay_dir_cards_f` = 9377 rows,
  so the tax-card base structure is populated and queryable.
- The DAT the generator produces does NOT link the card to a person (no PersonId FK is emitted
  on CalculationCard), which is part of the load blocker below.

### Proposed seed rows (dates as YYYY/MM/DD strings)
GOOD — parent (+ optional component) keyed to RT-WKR-G1:
- Parent `DMT_TAX_CARD_STG_TBL`: PERSON_NUMBER='RT-WKR-G1', EFFECTIVE_START_DATE='2026/01/01',
  LEGISLATIVE_DATA_GROUP_NAME='US Legislative Data Group', SOURCE_ID='RT-TAXCARD-G1',
  STG_STATUS='NEW'.
- Component `DMT_TAX_CARD_COMP_STG_TBL`: PERSON_NUMBER='RT-WKR-G1',
  COMPONENT_NAME='Federal Taxes', COMPONENT_VALUE='S',
  LEGISLATIVE_DATA_GROUP_NAME='US Legislative Data Group', SOURCE_ID='RT-TAXCOMP-G1',
  STG_STATUS='NEW'. (Component name/value are provisional — need confirmation against a real US
  card once the load path works.)

BAD — distinct parent record; fails on an invalid LDG:
- Parent `DMT_TAX_CARD_STG_TBL`: PERSON_NUMBER='RT-WKR-B-TAX', EFFECTIVE_START_DATE='2026/01/01',
  LEGISLATIVE_DATA_GROUP_NAME='NONEXISTENT LDG', SOURCE_ID='RT-TAXCARD-B1', STG_STATUS='NEW'.
  (Distinct PERSON_NUMBER → distinct SourceSystemId discriminator, so no duplicate-line error.)

### Prerequisites / blockers
BLOCKER (from the generator itself, `DMT_TAX_CARD_HDL_GEN_PKG` header comments): the
CalculationCard load requires `SourceType` (PSU/TRU/PREL) on the internal `DIRCardDEO` entity,
and no valid HDL child discriminator has been found to carry it. `PersonId(SourceSystemId)`,
`DirectiveCardName`, `TaxReportingUnit`, and `ComponentGroupName` are all marked INVALID in V2,
and `CardAssociation` / `DIRCardCompDefn` are not valid child discriminators. `SourceType` placed
on CalculationCard passes import but is not mapped to DIRCardDEO at load. Result: GOOD rows will
NOT reach `PAY_DIR_CARDS_F` with the current generator, so Rule #1 cannot be met yet.

Additional likely prerequisite once the discriminator is solved: a US Tax Reporting Unit assigned
to the worker (SourceType=TRU associations reference a TRU). RT-WKR-G1 has no TRU assignment, so
even after the discriminator fix, either the worker needs a TRU association first or the object
should target a real seeded worker (e.g. person 10) that already has one.

Recommendation: TABLE this object until the SourceType/DIRCardDEO discriminator blocker is
resolved (generator change, out of scope here). Seed TalentProfiles first; TaxCards is not a
live-pass candidate today.
