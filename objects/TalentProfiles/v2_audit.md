# Talent Profiles — V2 Audit (2026-04-04)

## Status: PASS (METADATA) — V2 fixes applied, load blocked by ProfileStatusCode

## Generator: DMT_TALENT_PROF_HDL_GEN_PKG
- DAT filename: `TalentProfile.dat` — correct
- Version: V2
- Parent/child: TalentProfile + ProfileItem

## METADATA vs V2 Findings

Parent: `SSO|SSID|PersonId(SSID)|ProfileCode|ProfileTypeCode|ProfileStatusCode|ProfileUsageCode|Description`
Child: `SSO|SSID|TalentProfileId(SSID)|ContentTypeName|ContentItemName|DateFrom|DateTo|Rating|ProfileCode|InterestLevel`

PersonNumber removed, PersonId(SourceSystemId) FK added. Matches V2 findings.

## Discriminators: `TalentProfile`, `ProfileItem` — correct
## METADATA validated: Yes (2026-03-22)
## E2E LOADED: No — blocked by ProfileStatusCode invalid value

## Action Required
Discover valid ProfileStatusCode values on demo instance (e.g., via REST LOV query).
