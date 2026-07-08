# Payroll Relationship — V2 Audit (2026-04-04)

## Status: BLOCKED — NOT a standalone HDL object

## Generator: DMT_PAY_REL_HDL_GEN_PKG
- DAT filename in code: `PayrollRelationship.dat` — **REJECTED by Fusion**
- Error: "The PayrollRelationship file name isn't valid. You need to use the name of a top-level supported business object as the file name."

## METADATA
V2 fixes applied (EffectiveStartDate/EndDate/PersonNumber removed, PeriodOfServiceId(SourceSystemId) FK added).
METADATA is irrelevant since the file itself is rejected.

## Blocker
PayrollRelationship is part of the Worker.dat parent chain, NOT a standalone object.
The standalone generator CANNOT work.

## Action Required
- Architectural redesign: embed PayrollRelationship as a component inside DMT_WORKER_HDL_GEN_PKG (like WorkTerms, Assignment)
- Add a conditional PayrollRelationship METADATA section to Worker.dat generation
- DMT_PAY_REL_HDL_GEN_PKG should be retired or repurposed
