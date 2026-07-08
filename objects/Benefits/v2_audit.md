# Benefits (Participant / Dependent / Beneficiary) — V2 Audit (2026-04-04)

## Status: PASS (METADATA) — V2 fixes applied, load blocked by BenefitBalanceName LOV

All three generators share the same DAT structure:
- DMT_BEN_PARTIC_HDL_GEN_PKG
- DMT_BEN_DEPEND_HDL_GEN_PKG
- DMT_BEN_BENFY_HDL_GEN_PKG

## DAT Details
- DAT filename: `PersonBenefitBalance.dat` — correct (all three use this)
- Discriminator: `PersonBenefitBalance` — correct (DependentBenefitBalance/BeneficiaryBenefitBalance are NOT valid)
- Version: V2

## METADATA
All three generators use identical METADATA:
`SSO|SSID|PersonId(SSID)|EffectiveStartDate|BenefitBalanceName`

Matches V2 validated METADATA exactly.

## METADATA validated: Yes (2026-03-25)
## E2E LOADED: No — BLOCKED

## Blocker
BenefitBalanceName must be a valid benefit balance name in Fusion (instance-specific).
Test error: "enter a valid value for the BnftsBalId attribute" — data quality, not METADATA.
Need to discover valid BenefitBalanceName values on demo instance.
