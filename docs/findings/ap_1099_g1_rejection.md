# AP Invoices: why RT-1099-G1 is rejected on every run

Date: 2026-10-07. Backlog #308. Object: APInvoices (`objects/APInvoices/README.md`).

## Verdict

**Bad test data.** The seed row for `RT-1099-G1` in `scripts/insert_regression_test_data.py`
(section 38) carries two invalid values on its invoice line. DMT transformed and generated
the row faithfully, and the pod has the setup a 1099 invoice needs. The seed is corrected for
scenarios minted from now on. Existing write-once scenarios are not touched.

## Fusion's real rejection

Run 254 (prefix 93310, Payables load request 10075157). Interface invoice 100000348
(`93310RT-1099-G1`), interface line 1745668. `AP_INTERFACE_REJECTIONS` holds two rows, both on
the line (`PARENT_TABLE = AP_INVOICE_LINES_INTERFACE`). `REJECTION_MESSAGE` is empty, so the
lookup code is the whole message:

| Parent | Reject lookup code |
|---|---|
| line 1745668 | `INVALID DISTRIBUTION ACCT` |
| line 1745668 | `INVALID TYPE 1099` |

The header has no rejection of its own. It is REJECTED because Payables rejects the whole
invoice when a line fails, which is the cross-grain behaviour PR #628 now reports.

**Every earlier run shows the same pair.** I queried all 54 interface invoices named
`%RT-1099-G1` on the pod, across 48 Payables loads from 2026-09-09 (load 9953865) to run 254.
All are REJECTED, every load's line carries `INVALID DISTRIBUTION ACCT` and `INVALID TYPE 1099`,
and `AP_INVOICES_ALL` holds no invoice with that number. The few loads
that also show `DUPLICATE LINE NUMBER` and header `NO INVOICE LINES` (9953865, 9989786, 9991511)
are September runs that sent the same invoice more than once in a load. That is a separate,
already-fixed duplication; the two line errors appear in those loads too. RT-1099-G1 has never
loaded.

## What Fusion received

Interface line 1745668, exactly as seeded:

| Column | Value sent | Valid? |
|---|---|---|
| `DIST_CODE_CONCATENATED` | `101-10-68010-120-000-000` | No |
| `TYPE_1099` | `07` | No |
| `INCOME_TAX_REGION` | `CA` | Yes |
| `ACCOUNTING_DATE` | 2025-06-15 | Yes today (see below) |
| `AMOUNT` | 5000, `LINE_TYPE_LOOKUP_CODE` ITEM | Yes |

Because the interface values match the seed byte for byte, the transformer and the FBDI
generator are not at fault. No column is shifted and no field is dropped.

## Proof of each cause

**1. The account delimiter is wrong.** The US1 chart of accounts (id 21) uses `.` as its segment
delimiter (`FND_ID_FLEX_STRUCTURES.CONCATENATED_SEGMENT_DELIMITER`). The same segment values with
dots, `101.10.68010.120.000.000`, are an enabled, non-summary combination (CCID 701593). The
GOOD invoices that load every run use the dotted form (`101.10.65110.110.000.000`, CCID 10667).
The dash form cannot be parsed into segments, so Payables returns `INVALID DISTRIBUTION ACCT`.

**2. `07` is not an income tax type.** `TYPE_1099` must be a code in `AP_INCOME_TAX_TYPES`. On this
pod those codes are `MISC1` to `MISC15b`, `INT 1`, `GOV 1` and similar; there is no `07`. The
accepted 1099 lines on the pod confirm it: `AP_INVOICE_LINES_ALL` holds 56,715 `MISC3` lines,
5,921 `MISC7` lines and 877 `MISC4` lines. The value `07` is the box number of the old
1099-MISC box 7 (non-employee compensation), which Fusion codes as `MISC7`.

**3. The supplier and region are fine (no pod setup gap).** Supplier JGA (1254) has
`FEDERAL_REPORTABLE_FLAG = Y`, `STATE_REPORTABLE_FLAG = Y` and default type `MISC3`. Fusion
already holds JGA invoice lines with a line-level type that differs from that default (269 `MISC4`
lines), so a line override is accepted. Region `CA` is active in `AP_INCOME_TAX_REGIONS`.
Run 254's own GOOD invoices show the 1099 setup working: `93310RT-APINV-G1` and `-G2` loaded with
`TYPE_1099 = MISC3` and `INCOME_TAX_REGION = WA`, defaulted from JGA.

**4. The fixed date is a latent problem, not a current one.** Period `06-25` of US Primary Ledger is
closed in General Ledger (application 101) but still open in Payables (application 200), and
Payables import checks the Payables period. So 2025-06-15 is not rejected today, but it will be
once Payables closes that period. The GOOD AP rows use `SYSDATE` and have no such risk.

## Fix (test data, future scenarios only)

`scripts/insert_regression_test_data.py`, section 38:

| Field | Before | After |
|---|---|---|
| line `DIST_CODE_CONCATENATED` | `101-10-68010-120-000-000` | `101.10.68010.120.000.000` |
| line `TYPE_1099` | `07` | `MISC7` |
| line `ACCOUNTING_DATE` | `DATE '2025-06-15'` | `SYSDATE` |
| header `INVOICE_DATE`, `GL_DATE` | `DATE '2025-06-15'` | `SYSDATE` |

`INCOME_TAX_REGION` stays `CA`. Supplier, site, amount, keys and `SOURCE_ID`s are unchanged, so the
row keeps its identity in expected-outcome lists.

**Not changed:** existing scenarios (including `RegressionTest2610071919`, id 341, and the current
baseline `RegressionTest2610071920`, id 342) keep the old rows, so they still expect the line
FAILED and the header FAILED_WITH_DOCUMENT. `scripts/regression_scenario.json` is not edited and
no scenario was minted. The next scenario minted with `scripts/deploy_scenario.py` picks up the
corrected row (the seed hash changes), and its expected outcomes should list `RT-1099-G1` and
`RT-1099LN-G1` as LOADED. That run is the live proof the fix works; until then the fix rests on
the pod evidence above.

## Not a DMT defect, but worth noting

DMT's AP validator passed a dash-delimited account and an unknown income tax type straight
through. That is the intended design (Fusion's rejection is the error the tool reports), so no
change is proposed.
