# APInvoices — gold regression fixture

A standalone, reloadable FBDI fixture (2 good + 1 bad invoice, header + lines)
that loads directly into Oracle Fusion Payables via the ERP Integration SOAP
service (`loadAndImportData`, which loads the interface AND chains **Import
Payables Invoices**), with read-only BIP verification against the base and
interface tables. No DMT tool code, no DMT database, is in the load path.

**Portable.** The supplier, supplier site, Business Unit, BU id and primary
ledger id are all **discovered at load time** by a read-only BIP query against
the target pod — nothing is hardcoded and the fixture never depends on data we
loaded earlier. The new invoices are created fresh (prefix-stamped); their
supplier / BU / ledger references are borrowed from what already exists on the
pod.

## The two CSVs (FBDI, no header row, position-based)

- `ApInvoicesInterface.csv` — invoice headers (135-column layout, per
  `db/packages/dmt_ap_fbdi_gen_pkg.pkb.sql` `gen_headers_csv` / the
  ApInvoicesInterface.ctl order). Byte-template taken from the proven
  `test/fbdi_zips/APInvoices_116.zip`.
- `ApInvoiceLinesInterface.csv` — invoice lines (INVOICE_ID join key +
  line fields, per `gen_lines_csv`).

Three header rows (+ matching lines), all keyed by a prefix-stamped
`INVOICE_ID` (col 1) so headers and lines join and re-runs never collide:

| Row | INVOICE_NUM | INVOICE_ID | Supplier / site | Amount | Purpose |
|---|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-APINV-G1` | `${PREFIX}01` | discovered | 1500 | valid → base |
| GOOD-2 | `${PREFIX}RT-APINV-G2` | `${PREFIX}02` | discovered | 2750 | valid → base |
| BAD-1  | `${PREFIX}RT-APINV-BAD1` | `${PREFIX}03` | `DMT DOES NOT EXIST VENDOR` / `99999999` / `FAKE-SITE-XYZ` | 0 | rejected → interface |

**Critical layout facts (learned live):**

- **`GROUP_ID` (header col 13) MUST equal the import ParameterList arg 9
  (the Import Set).** Both are stamped with `${PREFIX}`. If they differ, Import
  Payables Invoices selects **zero** rows, the interface rows keep a blank
  status, and nothing reaches the base table — even though the load job reports
  SUCCEEDED. This was the failure on the first live attempt (prefix 90212).
- **`SOURCE` (header col 3) MUST equal ParameterList arg 8.** Both are
  `Manual Invoice Entry` (a valid, registered AP import source on this pod).
- The BAD row deliberately references a supplier that cannot exist, so Import
  Payables Invoices rejects it with `INVALID SUPPLIER` in
  `AP_INTERFACE_REJECTIONS`. It reaches the interface and is rejected there —
  not a pre-validation.

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json) |
| UCM DocumentAccount | `fin/payables/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `1` (the AP `SOURCE_ERP_OPTIONS_ID` / `ERP_INTERFACE_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`) |
| `<erp:JobName>` | `/oracle/apps/ess/financials/payables/invoices/transactions,APXIIMPT` (seed stores it with a `;` before `APXIIMPT`; `loadAndImportData` needs the last `;` replaced with `,`) |
| `<erp:ParameterList>` | 14 args: `,${BU_ID},N,${GL_DATE},#NULL,#NULL,1000,Manual Invoice Entry,${PREFIX},N,Y,${LEDGER_ID},#NULL,1` |
| `<typ:notificationCode>` | `10` |

**APXIIMPT ParameterList — 14 positions** (confirmed against Fusion UI job
9483897, frozen-stack DB-51):

| # | Value | Meaning |
|---|---|---|
| 1 | (empty) | Invoice batch name |
| 2 | `${BU_ID}` | Business Unit id (discovered) |
| 3 | `N` | Purge |
| 4 | `${GL_DATE}` | Accounting date (today, `YYYY-MM-DD`) |
| 5 | `#NULL` | Hold name |
| 6 | `#NULL` | Hold reason |
| 7 | `1000` | (import group size) |
| 8 | `Manual Invoice Entry` | **Source** (must equal header SOURCE) |
| 9 | `${PREFIX}` | **Import Set** (must equal header GROUP_ID) |
| 10 | `N` | |
| 11 | `Y` | Summarize report |
| 12 | `${LEDGER_ID}` | Primary ledger id (discovered) |
| 13 | `#NULL` | |
| 14 | `1` | |

`loadAndImportData` returns the **Load ESS request id** in `<result>`. Poll it
with `getESSJobStatus` every 60s until terminal. The Load job also spawns
children (Load Interface File + Import Payables Invoices); on this pod the parent
reaches SUCCEEDED once they complete. `LOAD_REQUEST_ID` is stamped on every
`AP_INVOICES_INTERFACE` row and is the selection key for verifying the bad row.

## Discovery (run before build, read-only BIP)

One step, credential role `fin_impl`, picks a **standard** demo supplier (numeric
`SEGMENT1`, excludes our own `RT` suppliers) that has an active pay site in the
`US1 Business Unit`, and returns its ledger:

```sql
SELECT * FROM (
  SELECT sv.vendor_name, sv.segment1, ss.vendor_site_code,
         ss.prc_bu_id, bu.bu_name, bu.primary_ledger_id
  FROM   poz_supplier_sites_all_m ss
  JOIN   poz_suppliers_v sv        ON sv.vendor_id = ss.vendor_id
  JOIN   fun_all_business_units_v bu ON bu.bu_id = ss.prc_bu_id
  WHERE  ss.pay_site_flag = 'Y' AND bu.primary_ledger_id IS NOT NULL
  AND    bu.bu_name = 'US1 Business Unit'
  AND    NVL(ss.inactive_date, SYSDATE+1) > SYSDATE
  AND    REGEXP_LIKE(sv.segment1, '^[0-9]+$')
  AND    sv.vendor_name NOT LIKE '%RT %' AND sv.vendor_name NOT LIKE '%RT-%'
  ORDER BY TO_NUMBER(sv.segment1)
) WHERE ROWNUM = 1
```

Discovered tokens stamped into the good rows and the ParameterList:
`${SUPPLIER_NAME}`, `${SUPPLIER_NUM}`, `${SUPPLIER_SITE}`, `${BU_NAME}`,
`${BU_ID}`, `${LEDGER_ID}`.

## Verification (read-only, via the BIP relay — direct single-table reads)

Both directions are proven with **independent single-table reads**, never a
relayed multi-table join (whose NULLs are ambiguous):

- **Good → base.** Direct read of `AP_INVOICES_ALL` by the prefix on the natural
  key: `WHERE invoice_num LIKE '<prefix>RT-APINV-%'`. Each good INVOICE_NUM
  present with a real `INVOICE_ID` = pass.
- **Bad → interface + absent from base.** Direct read of
  `AP_INVOICES_INTERFACE` by `load_request_id`, LEFT JOIN `AP_INTERFACE_REJECTIONS`
  (a view) on `parent_id = invoice_id` / `parent_table='AP_INVOICES_INTERFACE'`
  for the error text; and the base read above confirms the bad INVOICE_NUM is
  absent.

Tables: interface `AP_INVOICES_INTERFACE` / `AP_INVOICE_LINES_INTERFACE`, base
`AP_INVOICES_ALL`, rejections `AP_INTERFACE_REJECTIONS`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py APInvoices --prefix <PREFIX>   # discover -> build -> load -> verify
# or step by step:
python build_artifact.py APInvoices <PREFIX>
python load_fbdi.py APInvoices ../objects/APInvoices/APInvoices_gold.zip
python verify.py APInvoices <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database / code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90213` |
| Load ESS request id (`loadAndImportData` result) | `9762926` |
| Terminal status (`getESSJobStatus`) | `SUCCEEDED` |
| Import children (state 12 = SUCCEEDED) | `9762927`+ under the load parent |
| Discovered supplier / site / BU / ledger | `Lee Supplies` (1252) / `Lee US1` / `US1 Business Unit` (`300000046987012`) / `300000046975971` |

**Good rows → base table `AP_INVOICES_ALL` (2/2):**

| INVOICE_NUM | INVOICE_ID | Amount |
|---|---|---|
| `90213RT-APINV-G1` | `1554382` | 1500 |
| `90213RT-APINV-G2` | `1554383` | 2750 |

**Bad row → interface rejection, absent from base (1/1):**

| INVOICE_NUM | Rejection error |
|---|---|
| `90213RT-APINV-BAD1` | `INVALID SUPPLIER` (`AP_INTERFACE_REJECTIONS`) |

The bad invoice landed in `AP_INVOICES_INTERFACE` (load_request_id 9762926) with
the `INVALID SUPPLIER` rejection and no row in `AP_INVOICES_ALL`. Gold zip
`APInvoices_gold.zip` (last built at prefix 90213) kept in this directory.

**First-attempt failure (prefix 90212), diagnosed and fixed:** the load reported
SUCCEEDED but 0 invoices reached the base — the header `GROUP_ID` was still `116`
from the byte-template while the ParameterList Import Set was `${PREFIX}`, so
Import Payables Invoices selected nothing. Tokenizing `GROUP_ID` to `${PREFIX}`
fixed it on the 90213 re-run.
