# W2 Balances — V2 Audit (2026-04-04)

## Status: BLOCKED — HDL filename unknown

## Generator: DMT_W2_BAL_HDL_GEN_PKG
- DAT filename in code: `PayrollBalanceInitialization.dat` — **REJECTED by Fusion**
- Version: V2 (assumed)
- Parent/child: BalanceInitialization + BalInitializationDetails

## METADATA
V2 fixes applied (PersonNumber removed, PersonId(SourceSystemId) FK added).
Generator METADATA looks reasonable BUT the filename is invalid.

## Blocker
16+ filename variants tried and ALL rejected by Fusion:
PayrollBalanceInitialization.dat, BalanceInitialization.dat, PayrollBalance.dat,
BalanceAdjustment.dat, PayBalance.dat, PayrollBalanceAdjustment.dat,
PayrollRunResults.dat, InitializeBalance.dat, PayrollBalInitialization.dat,
GlobalPayrollBalance.dat, PayrollData.dat, and more.

**This object may not be HDL-loadable on this Fusion version, or may require a different API.**

## Action Required
- Research Oracle Support / MOS for correct HDL filename
- Or determine if this requires a different loading approach (e.g., spreadsheet loader, REST API)
