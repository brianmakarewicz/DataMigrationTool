# Tax Calculation Card — V2 Audit (2026-04-04)

## Status: PASS (METADATA) — V2 fixes applied, load blocked by SourceType/DIRCardDEO

## Generator: DMT_TAX_CARD_HDL_GEN_PKG
- DAT filename: `CalculationCard.dat` — correct
- Version: V2
- Parent/child: CalculationCard + CardComponent

## METADATA vs V2 Findings

| Attribute | Status |
|-----------|--------|
| PersonId(SourceSystemId) | Removed (V2 invalid for CalculationCard) | PASS |
| DirectiveCardName | Removed (V2 invalid) | PASS |
| TaxReportingUnit | Removed (V2 invalid) | PASS |
| ComponentGroupName | Removed (V2 invalid) | PASS |
| EffectiveStartDate | KEPT — required (exception to other objects) | PASS |

Parent METADATA: `SSO|SSID|EffectiveStartDate|LegislativeDataGroupName`
Child METADATA: `SSO|SSID|CalculationCardId(SSID)|ComponentName|ComponentValue|LegislativeDataGroupName`

## Discriminators: `CalculationCard`, `CardComponent` — correct
## METADATA validated: Yes (2026-03-25)
## E2E LOADED: No — BLOCKED

## Blocker
SourceType passes import on CalculationCard but load requires it on DIRCardDEO internal entity.
CardAssociation and DIRCardCompDefn are NOT valid child discriminators.
Need to discover the correct child discriminator that maps SourceType to DIRCardDEO.
