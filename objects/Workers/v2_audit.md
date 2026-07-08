# Workers — V2 Audit (2026-04-04)

## Status: E2E LOADED — ALL 10 COMPONENTS (3L/0F, prefix 9210, DB-20)

## Generator: DMT_WORKER_HDL_GEN_PKG
- DAT filename: `Worker.dat` — correct
- Version: V2
- 10 components: Worker, PersonName, WorkRelationship, WorkTerms, Assignment, PersonEmail, PersonPhone, PersonAddress, PersonNationalIdentifier, PersonLegislativeData

## METADATA vs V2 Findings

| Component | Generator METADATA | V2 Finding | Match |
|-----------|-------------------|------------|-------|
| Worker | `SSO\|SSID\|EffectiveStartDate\|PersonNumber\|StartDate\|DateOfBirth\|ActionCode` | LegalEntityName removed (invalid V2) | PASS |
| PersonName | `SSO\|SSID\|EffectiveStartDate\|PersonId(SSID)\|NameType\|LegislationCode\|LastName\|FirstName\|MiddleNames\|Title` | DisplayName removed (invalid V2) | PASS |
| WorkRelationship | `SSO\|SSID\|PersonId(SSID)\|LegalEmployerName\|DateStart\|WorkerType\|PrimaryFlag` | EffectiveStartDate/EndDate removed | PASS |
| WorkTerms | `SSO\|SSID\|PeriodOfServiceId(SSID)\|ActionCode\|EffectiveStartDate\|...` | OK | PASS |
| Assignment | `SSO\|SSID\|ActionCode\|EffectiveStartDate\|...\|AssignmentStatusTypeCode\|PersonTypeCode\|BusinessUnitShortCode\|PrimaryAssignmentFlag` | ManagerPersonNumber removed. ACTIVE_PROCESS used. | PASS |
| PersonEmail | `SSO\|SSID\|PersonId(SSID)\|DateFrom\|EmailType\|EmailAddress\|PrimaryFlag` | DateFrom added (DB-20 — required) | PASS |
| PersonPhone | `SSO\|SSID\|PersonId(SSID)\|LegislationCode\|DateFrom\|PhoneType\|CountryCodeNumber\|AreaCode\|PhoneNumber\|PrimaryFlag` | LegislationCode+DateFrom added (DB-20) | PASS |
| PersonAddress | Has EffectiveStartDate (valid for Address) | OK | PASS |
| PersonNID | No EffectiveStartDate/EndDate | Removed per V2 | PASS |
| PersonLegislativeData | Has EffectiveStartDate (valid for LegislativeData) | OK | PASS |

## Discriminators: All correct (Worker, PersonName, WorkRelationship, WorkTerms, Assignment, PersonEmail, PersonPhone, PersonAddress, PersonNationalIdentifier, PersonLegislativeData)

## Confirmed E2E LOADED: Yes (DB-19: mandatory 5, DB-20: all 10)

## Notes
- Conditional METADATA sections: child components only emitted when has_rows() returns true
- Empty METADATA sections omitted (V2 requirement)
- PersonPhone: LegislationCode added to disambiguate CountryCodeNumber=1 (US/CA). Derived from PersonNID TFM.
- PersonPhone: DateFrom added (required). Derived from Worker START_DATE.
- PersonPhone: PhoneNumber MUST be 7 digits. AreaCode is a separate field. 10-digit PhoneNumber fails.
- PersonEmail: DateFrom added (required). Derived from Worker START_DATE.
- PersonNID: SSN must be 9 digits WITHOUT hyphens (111223333 not 111-22-3333).
