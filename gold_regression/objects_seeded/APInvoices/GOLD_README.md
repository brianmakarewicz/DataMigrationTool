# APInvoices — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/APInvoices/`). Same two good + one
bad AP invoices (header + lines), loaded via `loadAndImportData` (which chains **Import
Payables Invoices**) with read-only BIP verification. The one difference from v1: the
supplier, site, Business Unit id and ledger id are **hard-coded to standard seeded
values**, not discovered.

## The hard-coded seeds (what v1 discovered → now literals)

v1 discovered a standard demo supplier with an active pay site in the US1 Business Unit.
On this pod it resolved to `Lee Supplies` / `Lee US1`. All of these are standard seeded
demo data we never loaded, confirmed live via read-only BIP:

| Reference | Literal value | Where used |
|---|---|---|
| Supplier name | `Lee Supplies` | header col 7 (`${SUPPLIER_NAME}` → literal) |
| Supplier number | `1252` | header col 8 |
| Supplier site | `Lee US1` | header col 9 |
| Business Unit name | `US1 Business Unit` | header col 2 (`${BU_NAME}` → literal) |
| Business Unit id | `300000046987012` | ParameterList arg 2 (`${BU_ID}` → literal) |
| Primary ledger id | `300000046975971` | ParameterList arg 12 (`${LEDGER_ID}` → literal) |

The supplier lock state does **not** matter here — a lock only blocks supplier-profile
edits, not invoice import — so hard-coding Lee Supplies (which v1 also used live) is safe.

`${PREFIX}` stays on the invoice natural keys (`INVOICE_ID` col 1, `INVOICE_NUM` col 4)
and on the import-set `GROUP_ID` (col 13). `GROUP_ID` must equal ParameterList arg 9
(the Import Set); both are `${PREFIX}`. The `GL_DATE` in the ParameterList is a
prefix-independent derived token (today's date). The discovery block is removed from
`recipe.json`.

## Bad row

BAD-1 references a supplier that cannot exist (`DMT DOES NOT EXIST VENDOR` / `99999999` /
`FAKE-SITE-XYZ`). Import Payables Invoices rejects it with `INVALID SUPPLIER` in
`AP_INTERFACE_REJECTIONS`; it never reaches `AP_INVOICES_ALL`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

| Field | Value |
|---|---|
| Prefix | `23880` |
| Hard-coded supplier / site / BU / ledger | `Lee Supplies` (1252) / `Lee US1` / `US1 Business Unit` (300000046987012) / 300000046975971 |
| Load ESS request id | `9766104` |
| Terminal status | `SUCCEEDED` |
| Credential role | `fin_impl` |

Good rows → base `AP_INVOICES_ALL` (2/2):

| INVOICE_NUM | INVOICE_ID | Amount |
|---|---|---|
| `23880RT-APINV-G1` | `1555378` | 1500 |
| `23880RT-APINV-G2` | `1555379` | 2750 |

Bad row → interface rejection, absent from base (1/1):

| INVOICE_NUM | Rejection error |
|---|---|
| `23880RT-APINV-BAD1` | `INVALID SUPPLIER` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py APInvoices
```
