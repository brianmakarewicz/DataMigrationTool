# Coding Standards

## Borrow from MCCS

The MCCS codebase (`brianmakarewicz/MCCS`) is the reference implementation. Review is complete.

**Copy directly:**
- `sql/common/utl_zip.sql` -- Anton Scheffer ZIP (proven)
- `generate_encoded_zip` -- FBDI zip + base64 encode
- `populate_log_table` -- autonomous transaction logging
- `utl_http_request_clob` -- chunked UTL_HTTP write
- `getreportpayload_ws` -- BIP SOAP fetch
- RICE_013 -- per-entity package structure

**Do NOT repeat:**
- Generic c001-c500 column staging -- use semantic column names
- INSTR string parsing -- use XMLTYPE.extract() or JSON_VALUE
- Package-level variables as state -- pass p_batch_id explicitly everywhere
- Scattered COMMITs -- use savepoints, clean transaction boundaries
- Silent NULL returns -- populate ERROR_TEXT immediately, raise explicitly

## Error Logging

- Log start ("Starting validation for batch 123")
- Log complete ("Validation complete -- 47 valid, 3 invalid")
- On any exception: log context + SQLERRM before re-raising
- All log writes use autonomous transactions
- DBA must be able to reconstruct exactly what happened from the log table alone

## FBDI Submission (Resolved 2026-02-25)

SOAP two-step pattern (not REST):
1. `uploadFileToUcm` SOAP (uploads FBDI zip)
2. `submitESSJobRequest` SOAP (triggers ESS job)

Both go to `/fscmService/ErpIntegrationService` with WS-Security UsernameToken.
Private `soap_http` helper sets Content-Length + SOAPAction headers.
Do not revert to REST -- Fusion silently discards request body without Content-Length.
