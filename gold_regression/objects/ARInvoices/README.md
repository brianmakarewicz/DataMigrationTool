# ARInvoices — AutoInvoice / Receivables transactions import (call library)

This is the durable how-to-call reference for the AR AutoInvoice object. The full gold-fixture
narrative and live evidence live in `GOLD_README.md`; this file is the short, reliable summary
of the load contract and the current blocker so we never re-derive it mid-error.

## What loads

One FBDI zip, one CSV (`RaInterfaceLinesAll.csv`, 373-column AutoInvoice interface layout, no
header row, position-based). AutoInvoice derives accounting distributions from AutoAccounting,
so no distributions CSV is needed. Rows land in `RA_INTERFACE_LINES_ALL`; AutoInvoice then
promotes valid ones into `RA_CUSTOMER_TRX_ALL` / `RA_CUSTOMER_TRX_LINES_ALL` and rejects invalid
ones into `RA_INTERFACE_ERRORS_ALL`.

## The load call (proven working — rows reach the interface table)

- Endpoint: `{FUSION_URL}/fscmService/ErpIntegrationService`, operation `loadAndImportData`,
  HTTP Basic auth as credential role `fin_impl`.
- UCM DocumentAccount: `fin/receivables/import`; `interfaceDetails` = `2`.
- Load `JobName`: `/oracle/apps/ess/financials/receivables/transactions/autoInvoices,AutoInvoiceImportEss`.
- Load `ParameterList` (comma-separated): `${BU_NAME},${BATCH_SOURCE},${GL_DATE},,,,,,,,,,,,,,,,,,,,N,Y,`.
- SQL*Loader loads all rows cleanly ("3 Rows successfully loaded, 0 not loaded"). Verified live.

## The AutoInvoice submit — the exact, history-proven argument lists

Discovered at load time (read-only BIP, role `fin_impl`): `${BU_ID}` (org id), `${BATCH_SOURCE}`
(batch source name), `${BSID}` (batch source id), `${GL_DATE}` (today, an open period).

**Standalone `AutoInvoiceImportEss` — the exact list history proves succeeds (24 args):**

```
${BU_ID}~${BATCH_SOURCE}~${GL_DATE}~ (19 empty) ~N~Y
```

arg1 = org id, arg2 = batch source **name**, arg3 = default date, args 4–22 = blank,
arg23 = `N`, arg24 = `Y`. This is byte-for-byte the argument set of the 34 SUCCEEDED
`AutoInvoiceImportEss` runs in `fusion.ess_request_history` (e.g. request 9763525). **Caveat:**
those successful runs all processed 0 rows. When real rows are present on this demo pod, this
job aborts with "consolidated billing is enabled … run the Master instead" (see blocker below).

**Standalone `AutoInvoiceMasterEss` — named-argument contract (from its own ESS log echo):**
arg1 = worker count (`1`), arg2 = org id, arg3 = batch source id, arg4 = batch source name,
arg5 = default date, args 6–25 = filter ranges, arg26 = base-due-date flag (`N`),
arg27 = minimum-due-date flag (`Y`), arg28 = `load_request_id` (must point at a *completed*
"Load Interface File for Import" request, or be present-but-empty to select all eligible rows).

## Discovery queries (read-only BIP, role fin_impl)

See `recipe.json` `discovery` block: `AR_BU` (a BU with existing AR transactions, prefer
`US1 Business Unit`), `AR_BATCH_SOURCE` (prefer `Receivables Import`), `AR_TRX_TYPE` (prefer
`Invoice`), `AR_BILL_CUSTOMER` (an existing active bill-to account in that BU). Nothing is
hardcoded.

## Verification (read-only, direct single-table reads)

- Good → base: `RA_CUSTOMER_TRX_ALL WHERE trx_number LIKE '<prefix>RT-AR-%'`; lines in
  `RA_CUSTOMER_TRX_LINES_ALL`.
- Bad → interface + absent from base: `RA_INTERFACE_LINES_ALL WHERE interface_line_context =
  '<prefix>'` joined to `RA_INTERFACE_ERRORS_ALL` on `interface_line_id` for the message.

## Current status — TABLED (does not reach base on this pod)

As of 2026-07-20, with the real history-derived ParameterList in hand, the good rows still do
not reach `RA_CUSTOMER_TRX_ALL`. Root cause (full evidence in `GOLD_README.md`):

1. **Consolidated Billing is enabled** on the `US1 Business Unit` on this demo pod. That forbids
   the standalone `AutoInvoiceImportEss` route ("run the Master instead") whenever real rows are
   present.
2. The **Master's `load_request_id` slot (arg 28) is unreachable via `submitESSJobRequest`** on
   this release: a trailing empty tilde slot is stripped in transit, and the Master's named
   parser has a fixed +2 offset from the default-date slot onward, so the `N`/`Y` flags fall
   into the `load_request_id` slot and the job aborts with "The load request id N is invalid".
   A `#NULL` sentinel in slot 28 does not help.
3. No **completed** load request id exists to feed the Master, because loadAndImportData's
   `InterfaceLoaderController` ends in ERROR (state 12) on this pod (its chained AutoInvoice is
   itself blocked by consolidated billing), even though SQL*Loader loaded the rows cleanly.

**Ways forward (see `GOLD_README.md`):** capture a genuine row-processing Master run from the
Fusion UI and read its `submit.argumentN` values from `fusion.ess_request_property`; or switch
the AR path to the `importBulkData` ERP Integration operation (single managed load+import); or
disable Consolidated Billing for the chosen BU so the standalone `AutoInvoiceImportEss` (whose
argument list is now proven from history) can process the rows directly.

## ESS log reading

Download with `downloadESSJobExecutionDetails` (fileType `LOG`) on the ERP Integration service
for the request id; the response is MTOM multipart — the log is a `PK`-signature zip in the
binary part containing `<requestid>.log`. This log states exactly how the program parsed each
argument and why it selected or rejected rows.
