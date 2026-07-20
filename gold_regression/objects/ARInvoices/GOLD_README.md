# ARInvoices — gold regression fixture (AutoInvoice / Receivables transactions import)

A standalone, reloadable FBDI fixture (2 good + 1 bad AR transaction line) that loads
directly into Oracle Fusion Receivables through the ERP Integration SOAP service, then runs
the AutoInvoice import. No DMT tool code and no DMT database are in the load path; verification
is the read-only BIP relay only.

**Portable.** The Business Unit, its org id and primary ledger, the AutoInvoice-enabled
transaction batch source (and its id), the transaction type, and an existing bill-to customer
account are all **discovered at load time** by read-only BIP queries against the target pod.
Nothing is hardcoded and the fixture never depends on data we loaded earlier. The transactions
are created fresh (prefix-stamped transaction number + interface line reference); every
reference inside them is a discovered, already-present value.

## The one CSV (FBDI, no header row, position-based)

- `RaInterfaceLinesAll.csv` — AutoInvoice interface lines (373-column layout). Byte-template
  taken from the proven `test/fbdi_zips/ARInvoices_116.zip`. **No distributions CSV is needed**
  — AutoInvoice derives the accounting distributions from AutoAccounting, and the proven run
  116 loaded with lines only.

Three rows, all keyed by a prefix-stamped transaction number (col 7) and a prefix-stamped
interface line reference (col 38, `INTERFACE_LINE_ATTRIBUTE1`), with the run prefix stamped in
`INTERFACE_LINE_CONTEXT` (col 37) so a single read finds every row for a run:

| Row | TRX_NUMBER (col 7) | Bill acct (col 19) | Amount (col 32) | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-AR-G1` | discovered `${BILL_ACCT}` | 3200 | valid → base |
| GOOD-2 | `${PREFIX}RT-AR-G2` | discovered `${BILL_ACCT}` | 1800 | valid → base |
| BAD-1  | `${PREFIX}RT-AR-BAD1` | `999999999` (nonexistent) | 500 | rejected → interface error |

Populated columns (1-indexed, per `db/packages/dmt_ar_fbdi_gen_pkg.pkb.sql` `gen_lines_csv`):
2 = `BATCH_SOURCE_NAME` (`${BATCH_SOURCE}`), 3 = `CUST_TRX_TYPE_NAME` (`${TRX_TYPE}`),
4 = `TERM_NAME` (`Net 30`), 5 = `TRX_DATE`, 6 = `GL_DATE` (both `${GL_DATE_SLASH}` = today,
an open period), 7 = `TRX_NUMBER`, 19 = `BILL_CUSTOMER_ACCOUNT_NUMBER`, 26 = `LINE_TYPE`
(`LINE`), 27 = `DESCRIPTION`, 28 = `CURRENCY_CODE` (`USD`), 29 = `CONVERSION_TYPE` (`User`),
32 = `AMOUNT`, 37 = `INTERFACE_LINE_CONTEXT` (`${PREFIX}`), 38 = `INTERFACE_LINE_ATTRIBUTE1`
(the line reference), 39 = `INTERFACE_LINE_ATTRIBUTE2` (`1`), 287 = BU name (`${BU_NAME}`).

**Critical layout facts (learned live):**

- **The trx/GL date must be today (an open period).** The byte-template carried `2025/06/15`;
  a stale date lands in a closed accounting period and AutoInvoice cannot derive a GL date.
  The dates are tokenized to `${GL_DATE_SLASH}` and stamped to today at build time.
- The bad row references a customer account (`999999999`) that cannot exist, so AutoInvoice is
  expected to reject it into `RA_INTERFACE_ERRORS_ALL` and never create a transaction.

## The ESS orchestration (full, in order)

AR AutoInvoice is a **two-job** flow (this is the key difference from AP invoices):

1. **`loadAndImportData`** (SOAP, ERP Integration service) uploads the zip to UCM, runs
   "Load File to Interface Tables" to unpack `RaInterfaceLinesAll.csv` into
   `RA_INTERFACE_LINES_ALL`, and chains the AutoInvoice **import** job named below. The parent
   request reaches SUCCEEDED once the file is loaded. Poll it with `getESSJobStatus` every 60s.
2. **`AutoInvoiceMasterEss`** — "Import Receivables Transactions Using AutoInvoice" — submitted
   separately with `submitESSJobRequest`. This is the job that actually selects the interface
   rows, validates them, and creates transactions in the base tables. Poll it to terminal.

Why two jobs: the chained import inside `loadAndImportData` (AutoInvoiceImportEss) needs a
Business Unit and, per the proven MCCS package (`RICE_005-XXCNV_AR_INVOICE_STG_PKG.sql`), the
load parent reports SUCCEEDED even when that chained import selects nothing. The standalone
`AutoInvoiceMasterEss` is the job that does the real work.

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Load operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role `fin_impl` |
| UCM DocumentAccount | `fin/receivables/import` |
| `<typ:interfaceDetails>` | `2` (AR `ERP_INTERFACE_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`) |
| Load `<erp:JobName>` | `/oracle/apps/ess/financials/receivables/transactions/autoInvoices,AutoInvoiceImportEss` (seed stores it with `;` before the definition; `loadAndImportData` needs the last `;` → `,`) |
| Load `<erp:ParameterList>` | `${BU_NAME},${BATCH_SOURCE},${GL_DATE},,,,,,,,,,,,,,,,,,,,N,Y,` (comma-separated; blank = not passed) |
| Master job | `submitESSJobRequest`, jobPackageName `/oracle/apps/ess/financials/receivables/transactions/autoInvoices`, jobDefinitionName `AutoInvoiceMasterEss` |
| Master ParameterList | tilde-separated positional args (below) |

**AutoInvoiceMasterEss positional arguments** (confirmed from the job's own ESS log echo,
request 9763477 — `RAAMTR` is prepended by the program as arg 0):

| # | Value | Meaning |
|---|---|---|
| 1 | `1` | Worker/thread count |
| 2 | `${BU_ID}` | Business Unit / org id (discovered) |
| 3 | `${BSID}` | Transaction batch source id (discovered — **id, not name**) |
| 4 | (blank) | Batch source name |
| 5 | `${GL_DATE}` | Default date (today, `YYYY-MM-DD`) |
| 6–25 | (blank) | flexfield / trx type / customer / date / order range filters |
| 26 | `N` | Base due date on invoice date flag |
| 27 | `Y` | Minimum due date offset flag |
| 28 | (blank) | Load request id (must be present-but-empty) |

Each positional argument is sent as its own `<typ:paramList>` element (Fusion's ParameterList
delimiter is `~`). The harness `submit_ess` splits on `~` and preserves every empty slot,
including the trailing empty load-request-id slot.

## Discovery (run before build, read-only BIP)

Four steps, credential role `fin_impl`:

1. `AR_BU` — a Business Unit that already has Receivables transactions (guarantees AR is set up
   for it), preferring `US1 Business Unit`. Returns `${BU_NAME}`, `${BU_ID}`, `${LEDGER_ID}`.
2. `AR_BATCH_SOURCE` — an `IMPORT`/`FOREIGN` transaction batch source, preferring
   `Receivables Import` (the seeded AutoInvoice import source). Returns `${BATCH_SOURCE}`,
   `${BSID}`.
3. `AR_TRX_TYPE` — an active `INV` transaction type, preferring `Invoice`. Returns `${TRX_TYPE}`.
4. `AR_BILL_CUSTOMER` — an existing active bill-to customer **account number** that already
   transacts in the discovered BU (join `ra_customer_trx_all` → `hz_cust_accounts` →
   `hz_cust_site_uses_all`). Returns `${BILL_ACCT}`.

## Verification (read-only, via the BIP relay — direct single-table reads)

- **Good → base.** Direct read of `RA_CUSTOMER_TRX_ALL` by prefix on the natural key:
  `WHERE trx_number LIKE '<prefix>RT-AR-%'`. Each good TRX_NUMBER present with a real
  `CUSTOMER_TRX_ID` = pass. Lines confirmable in `RA_CUSTOMER_TRX_LINES_ALL`.
- **Bad → interface + absent from base.** Direct read of `RA_INTERFACE_LINES_ALL` by
  `interface_line_context = <prefix>`, joined to `RA_INTERFACE_ERRORS_ALL` on
  `interface_line_id` for the `message_text`; and the base read confirms the bad TRX_NUMBER is
  absent.

Tables: interface `RA_INTERFACE_LINES_ALL`, errors `RA_INTERFACE_ERRORS_ALL`, base
`RA_CUSTOMER_TRX_ALL` / `RA_CUSTOMER_TRX_LINES_ALL`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py ARInvoices --prefix <PREFIX>   # discover -> build -> load -> master -> verify
```

## Reading the AutoInvoice ESS log (essential for debugging)

The AutoInvoice job's own log states exactly how it parsed each argument and why it selected /
rejected rows. Download it with `downloadESSJobExecutionDetails` (fileType `LOG`) on the
ERP Integration service for the Master request id; the response is MTOM multipart — the log is
a `PK`-signature zip in the binary part containing `<requestid>.log`.

## Live evidence

**2026-07-20 — STILL TABLED after using the real historical ParameterList. Root cause now
fully identified from ESS_REQUEST_HISTORY and the ESS logs (see the retry section at the
bottom). The blocker is a pod-configuration + standalone-submit limitation, not a
ParameterList value we can still tune.**

**2026-07-19 — TABLED (not yet gold). The data loads to the interface; AutoInvoice does not
yet create the base transactions on this pod.**

Standalone load path only (no DMT database / code in the load path); verification and ESS-log
reads via read-only SOAP + the BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Discovered BU / ledger | `US1 Business Unit` (`300000046987012`) / `300000046975971` |
| Discovered batch source / id | `Receivables Import` / `300000049759128` |
| Discovered transaction type | `Invoice` |
| Discovered bill-to customer account | `10000` (Owens & Minor) |
| Last prefixes attempted | `90218` … `90224` |
| Load requests (all SUCCEEDED) | e.g. `9763470` (prefix 90223) |
| AutoInvoice Master requests (all SUCCEEDED) | e.g. `9763477` (prefix 90223) |

**What works:** every load reaches `RA_INTERFACE_LINES_ALL` (all three rows, with the correct
batch source name, transaction type, bill-to account, BU name, and a today GL date). Both ESS
jobs reach SUCCEEDED.

**The blocker (documented, reproducible):** `AutoInvoiceMasterEss` aborts before selecting any
rows. Its ESS log ends with:

```
Argument List 28 load_request_id ::: N
The load request id N is invalid :::
The Load request id is invalid or is not in a completed status ... please review the load request id provided
```

The job's raw `argv` echo shows the arguments arrive in the right raw positions (org id, batch
source id, default date, `N`, `Y`), but the program's second, named-slot parse reads the
trailing flag into the `load_request_id` slot and stops. As a result `RA_INTERFACE_LINES_ALL`
rows keep a NULL `request_id` / NULL `interface_status` — AutoInvoice never claims them — so no
row (good or bad) reaches `RA_CUSTOMER_TRX_ALL` and no `RA_INTERFACE_ERRORS_ALL` row is written.
Because AutoInvoice aborts before validating individual rows, even the intended bad-row
rejection is not produced.

**Web finding:** Oracle documents that AutoInvoice "finds no records to process" when the
selection parameters don't match, and that in a Fusion ParameterList "a corresponding entry
must be blank when a parameter is not passed" (positional). Combined with the ESS log, the
remaining issue is the exact `AutoInvoiceMasterEss` positional contract for the trailing
flag / load-request-id slots when the job is submitted standalone via `submitESSJobRequest`
(as opposed to the UI). The data fixture, discovery, load, and both ESS submissions are all
proven; the last gap is this single ParameterList tail alignment.

**Next step when resumed:** capture the exact parameter contract from a known-good AutoInvoice
Master run submitted from the Fusion UI (Scheduled Processes) for this pod's release, or use
the `ess-param-lookup` skill, and align the trailing positions. Then re-run with a fresh prefix.
The whole harness path is ready; only the Master ParameterList tail is unresolved.

---

## 2026-07-20 retry — used the REAL historical ParameterList from ESS_REQUEST_HISTORY. STILL TABLED.

I queried the live `fusion.ess_request_history` view (via the read-only BIP relay, credential
role `fin_impl`; the view resolves to `FUSION.REQUEST_HISTORY_VIEW`, and each request's
positional arguments are stored in `fusion.ess_request_property` as
`name = 'submit.argumentN', value = ...`). State code 10 = SUCCEEDED, 12 = ERROR. Findings:

**1. There has NEVER been a successful standalone `AutoInvoiceMasterEss` run on this pod.**
All 6 AutoInvoiceMasterEss requests in history are state 12 (ERROR) — every one of them is a
prior agent attempt. So there is no known-good Master ParameterList to copy. The Master's own
argument echo (request 9763477) shows exactly why it fails, and it is the same failure every
time — the argument list is read one slot short at the end, so the `N`/`Y` due-date flags fall
into the final `load_request_id` slot and the job aborts with "The load request id N is invalid".

**2. The real successful AR path on this pod is the CHAINED IMPORT job, and it succeeds only
because it selects ZERO rows.** `AutoInvoiceImportEss` has 34 runs, all state 10 (SUCCEEDED).
I pulled the exact arguments of a successful one (request 9763525):

| Arg | Value | Meaning |
|---|---|---|
| 1 | `300000046987012` | Business Unit / org id |
| 2 | `Receivables Import` | batch source **name** (not id) |
| 3 | `2026-07-19` | default date (today) |
| 4–22 | (blank) | filter ranges |
| 23 | `N` | base due date flag |
| 24 | `Y` | minimum due date flag |

But that "successful" run processed **0 interface rows** (`ra_interface_lines_all` where
`request_id = 9763525` returns 0), created **0** base transactions, and wrote **0** errors. It
is SUCCEEDED only in the empty sense — nothing to do. So the history does not prove a
row-processing AutoInvoice; it proves an empty one.

**3. Submitting `AutoInvoiceImportEss` standalone with that exact 24-argument list is
functionally blocked on this pod by Consolidated Billing.** I re-ran it (load request 9764773,
import request 9764788, prefix 90231). The import went to ERROR, and its ESS log states the
reason in plain words:

```
Consolidation Billing Enabled Y
 Run AI from Master!!!
The invoices couldn't be imported because consolidated billing is enabled.
Run the Import Receivables Transactions Using AutoInvoice process instead.
```

So the standalone Import job (RAXTRX) refuses to run when there are actual rows to process and
tells you to run the Master (RAXMTR = "Import Receivables Transactions Using AutoInvoice").

**4. The Master (`AutoInvoiceMasterEss`) cannot be aligned through `submitESSJobRequest` on
this pod.** Two independent problems in the Master's own argument echo:

- **Trailing empty tilde slots are stripped by the ESS submit layer.** The `load_request_id`
  slot is argument 28 and must be present-but-empty when you want the Master to select all
  eligible rows. But a trailing empty `<paramList/>` is dropped in transit, so the `N`/`Y`
  flags shift into the `load_request_id` slot and the job aborts with "The load request id N is
  invalid". Putting a non-empty sentinel (`#NULL`) in slot 28 does not help — the Master's
  named-argument parser still reads `N` into the load_request_id slot (retry prefix 90235,
  import request 9765002, which reports SUCCEEDED at the wrapper level but internally aborts
  with the same "load request id N is invalid").
- **A fixed +2 offset in the Master's named parse begins at the default-date slot.** Even when
  the raw argv is perfectly aligned (verified in the request 9764903 log: raw slot 5 = the
  date, raw slot 4 = the batch source name), the program's *named* mapping reads the date at
  "argument 7 transaction type id" and the worker count at "argument 8 low bill-to customer
  number". Rearranging the non-empty leading arguments does not close this — the required
  trailing `load_request_id` slot is simply unreachable via the SOAP submit on this release.

**5. The one path the Master would accept — a real completed load_request_id — is also blocked,
because loadAndImportData's own loader finishes in ERROR (state 12) on this pod.** The Master's
`load_request_id` must point at a *completed* "Load Interface File for Import" request. But the
`InterfaceLoaderController` requests that loadAndImportData returns (e.g. 9764965) are state 12
(ERROR), even though the SQL*Loader child cleanly loaded all three rows
("3 Rows successfully loaded. 0 Rows not loaded due to data errors."). The controller is marked
ERROR because the AutoInvoice import it chains is itself blocked by consolidated billing (item 3).
So there is no completed load request id to hand the Master, and the Master's happy path is
closed too. Historically 28 InterfaceLoaderController runs did reach state 10, but 909 are
state 12 — the state-10 ones correspond to the empty (0-row) imports.

**Net:** with the real historical ParameterList in hand, the data still does not reach
`RA_CUSTOMER_TRX_ALL`. The blocker is not a value we can still tune. It is (a) Consolidated
Billing being enabled on the `US1 Business Unit` on this demo pod, which forces the Master
route and forbids the standalone Import route, combined with (b) the Master's `load_request_id`
argument slot being unreachable through `submitESSJobRequest` on this pod's release (trailing
empty stripping + a +2 named-parse offset), and (c) no completed load request id existing to
feed the Master, because loadAndImportData's loader controller ends in ERROR here.

**Evidence (prefixes / request ids, all standalone SOAP + read-only BIP relay):**

| Prefix | Load (InterfaceLoaderController) | AutoInvoice request | Job | Outcome |
|---|---|---|---|---|
| 90231 | 9764773 (state 12) | 9764788 | AutoInvoiceImportEss standalone | ERROR — "consolidated billing enabled, run the Master" |
| 90233 | 9764876 (state 12) | 9764903 | AutoInvoiceMasterEss (bs-name filled) | wrapper SUCCEEDED, log aborts "load request id N is invalid" |
| 90235 | 9764965 (state 12) | 9765002 | AutoInvoiceMasterEss (#NULL slot 28) | wrapper SUCCEEDED, log aborts "load request id N is invalid" |

Every run left all three interface rows unclaimed (`interface_status` NULL, `request_id` NULL);
no base transaction and no `RA_INTERFACE_ERRORS_ALL` row was produced, so neither the good rows
nor the intended bad-row rejection was realised.

**Real next steps when resumed (in priority order):**
1. Capture a genuinely-successful, row-processing Master run submitted from the Fusion UI
   (Scheduled Processes) on this pod, then read its `submit.argumentN` values from
   `fusion.ess_request_property` — that is the only way to learn the exact slot the UI uses for
   `load_request_id` and how it avoids the trailing-strip problem. (The `ess-param-lookup`
   skill drives that UI.)
2. Or switch the whole AR path to `importBulkData` (the ERP Integration operation that both
   loads and runs AutoInvoice as a single managed request and does not require us to hand-build
   the Master's `load_request_id`), which sidesteps both the standalone-Import consolidated-
   billing block and the Master's unreachable trailing slot.
3. Or disable Consolidated Billing for the chosen Business Unit on the demo pod (a functional
   setup change), which would let the standalone `AutoInvoiceImportEss` — whose argument list we
   have now proven byte-for-byte from history — process the rows directly.
