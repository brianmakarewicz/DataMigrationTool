# TaxConfig — GOLD fixture (TABLED: FSM CSV import has no tax-rate-header object on this pod)

**Object:** Transaction tax configuration — a tax **rate** attached to an existing tax
regime / tax / tax status (the regime/rate family, ZX_* base tables).
**Status:** 🟡 **TABLED — retried and re-confirmed 2026-07-20.** A portable fixture and the
confirmed workbook file format are built and committed. It is **not** live-proven. The prior
note (below) said "no non-UI path exists at all"; that is now **partly superseded** — the FSM
CSV import path *does* reach a tax-rate setup task — but the retry proved the FSM path still
cannot **create** a tax-rate header, so TaxConfig stays tabled with a sharper reason.

## 2026-07-20 retry — FSM "Setup Data Import from CSV file" (the path that made UnitsOfMeasure pass)

A sibling agent proved the object-agnostic FSM CSV import (`harness/load_fsm_csv.py`) end-to-end
for Units of Measure. We retried TaxConfig on that same mechanism. What we found, live:

- **A rate-level tax task DOES support CSV import.** `GET setupTasks?q=TaxName LIKE '%Tax Rate%'`
  returns **`ZX_MANAGE_TAX_RATES_AND_TAX_RECOVERY_RATES`** ("Manage Tax Rates and Tax Recovery
  Rates"). `GET setupTaskCSVImports/{task}` returns **`ImportSupportedFlag: true`**, and
  `GET setupTasks/{task}` returns `CSVExportImportSupportedFlag: Y`. So the earlier blanket claim
  that tax config has *no* non-UI CSV path is wrong at the task level.
- **But the task's CSV package has no tax-rate-header business object.** A live
  `setupTaskCSVExports` of that task (ESS request **9765467**, process `100007867615347`)
  enumerates **exactly 22 business objects**, and **none creates a rate**. They are all rate
  **detail/child** objects plus tax status: default-tax-account objects, and amount / unit-price /
  percent / quantity / gross / withheld **schedules and types**, recovery types, and `ZX_TAX_STATUS`.
  The real exported manifest is saved as evidence at
  `artifact/EXPORT_MANIFEST_ZX_MANAGE_TAX_RATES.xml`. There is no `ZX_RATES` / tax-rate-header
  member. These detail objects attach attributes to rates that **already exist**; they do not
  insert the base `ZX_RATES_B` row. Rate headers are still created only by the UI-only Tax
  Configuration Workbook.
- **Import attempts loaded zero.** We drove `setupTaskCSVImports` twice. (1) A hand-authored
  `ZX_RATES.csv` member (two good rates + one bad) — process `100007868615103`, ESS request
  **9765656** — completed, but the importer **skipped our CSV** ("The import process skipped …
  because all the related CSV files are missing or empty"), because `ZX_RATES` is not one of the
  task's 22 business objects. (2) Six candidate header short names
  (`ORA_ZX_TAX_RATES`, `ZX_RATES`, `ZX_TAX_RATE`, `ORA_ZX_MANAGE_TAX_RATE`, `TAX_RATE`,
  `ZX_RATES_B`) each completed HTTP 201 as an unknown-business-object no-op. **In every case
  ZERO rows reached `ZX_RATES_B`** (verified read-only via BIP for both `90210RT-TAXRATE-%` and
  `9021%RT-%`).
- **The export is itself unreliable here.** The full export took ~45 minutes and finished
  `COMPLETED_ERRORS` with the CSV members **absent** from the returned zip (only the 22-object
  manifest came back; a second, scoped export never completed at all). So we could not even learn
  the exact CSV column layout of the rate detail objects to attempt a detail-only load. The export
  ProcessLog does show the detail objects processing thousands of rows (e.g. `TaxRatePercentType`),
  confirming rate *percentage* data lives in a detail object — but that detail object still keys to
  an existing rate; it is not a header creator.

**Conclusion:** the FSM CSV import path is real for tax rates but is a **detail-only** round-trip on
this pod — it cannot create the base rate this fixture needs. `ZX_RATES_B` is BIP-readable with
`fin_impl` (confirmed), so verification is ready the moment a header-creating path exists.
**No prefix / no base ids are recorded because no rate was ever created — never faked.**

---

## Prior note (2026-07-19) — retained for history

**Status then:** 🟡 **TABLED 2026-07-19.** A portable fixture and the confirmed workbook file
format are built and committed. It is **not** live-proven, and cannot be with the current
harness, because Fusion exposes **no non-UI (web-service / ESS / REST) load path that can
CREATE an arbitrary custom tax rate** on this pod.

## The mechanism finding (why it is tabled)

There are two tax-configuration load mechanisms in Fusion, and neither gives the harness a
standalone way to create a new custom rate:

**1. Tax Configuration Content Upload Program — is an ESS path, but wrong scope.**
This is the one tax job that IS reachable by `loadAndImportData` / an ESS process:
- ERP interface options id **19** in `db/seed/dmt_erp_interface_options_tbl.sql`
  (`BUSINESS_OBJECT='taxRate'`, UCM account **`fin/tax/import`**, import job
  `/oracle/apps/ess/financials/tax/report;LaunchTaxConfigContentUpload`, SQLLOADER).
- On SaaS it runs as **Load Interface File for Import** → **Import Tax Configuration Content**,
  landing rows in the interface table **`ZX_DATA_UPLOAD_INTERFACE`**.
- **But** Oracle's documentation is explicit that this program loads **United-States-only,
  tax-partner-supplied content** (sales/use tax geography + rate content from a registered tax
  content partner such as Thomson Reuters ONESOURCE / Vertex). It **cannot create arbitrary
  custom tax regimes / taxes / rates.** It is not a general "upload my rate" FBDI.

**2. Tax Configuration Workbook (rapid implementation) — creates rates, but is UI-only.**
The mechanism that actually **creates** regimes/taxes/rates/recovery-rates is the
**Tax Configuration Workbook** (and the sibling **Tax Implementation Workbook**): an Excel
rapid-implementation workbook whose Instructions-tab macro saves each worksheet to CSV. It is
uploaded **only** through the Setup and Maintenance UI:

> Manage Tax Regimes → **Rapid Setup Spreadsheets** → **Upload Tax Configuration Workbook** →
> pick the saved compressed file → **Upload** → watch **Monitor Upload and Download Processes**.

There is:
- **no** `loadAndImportData` `<JobName>` for the tax workbook,
- **no** `submitESSJobRequest` `jobPackageName`/`jobDefinitionName` for a workbook upload,
- **no** dedicated Scheduler-REST job definition for it.

The gold-regression **HARD RULE #1** requires a standalone web-service load path (Fusion web
services directly, no DMT code, no browser); rule #2 keeps verification read-only. A UI-button
workbook upload satisfies neither. So — exactly like **Lookups** — TaxConfig sits behind the
same **"FBL delivery undecided"** gate (shared with GLCalendar, ValueSets, UnitsOfMeasure,
PaymentTerms). It is promoted to ✅ only if Oracle exposes a schedulable/web-service tax
workbook upload, or an explicit decision allows UI/browser automation for the FBL family.

**ESS history was mined (read-only BIP) and shows no prior tax-config load to copy a
ParameterList from.** `ESS_REQUEST_HISTORY` on this fresh demo pod holds only 9 requests
(ids 9570736–9570744, one consecutive batch, none tax). The `DEFINITIONNAME` column is not
BIP-serializable through the ephemeral relay (numeric columns read fine; that text column
raises an `oracle.xdo` DataException), so even a prior run's job path could not be mined this
way. There is nothing to reverse-engineer a headless workbook ParameterList from.

## What IS confirmed and built (ready to load the instant a path opens)

**Mechanism (Tax Configuration Workbook, Tax Rates worksheet → CSV).** A comma-delimited,
UTF-8 CSV of new **tax rate** rows, dates as **yyyy/MM/dd**, uploaded via the workbook action
above. The fixture adds a NEW rate under a fresh `${PREFIX}` code, attached to an **existing**
regime/tax/status discovered on the target pod.

**Tax Rates file** (`artifact/TaxRates.csv`) — header + two good rates + one bad rate:
```
Tax Regime Code,Configuration Owner,Tax,Tax Status Code,Tax Rate Code,Tax Rate Type,Rate Percentage,Effective From,Set as Default Rate,Default Effective From,Description
${TAX_REGIME_CODE},Global configuration owner,${TAX},${TAX_STATUS_CODE},${PREFIX}RT-TAXRATE-G1,PERCENTAGE,5,2020/01/01,No,,RT Gold Tax Rate G1 ${PREFIX}
${TAX_REGIME_CODE},Global configuration owner,${TAX},${TAX_STATUS_CODE},${PREFIX}RT-TAXRATE-G2,PERCENTAGE,7.25,2020/01/01,No,,RT Gold Tax Rate G2 ${PREFIX}
RT_NO_SUCH_REGIME_${PREFIX},Global configuration owner,RT_NO_SUCH_TAX,RT_NO_SUCH_STATUS,${PREFIX}RT-TAXRATE-BAD1,PERCENTAGE,9,2020/01/01,No,,RT Bad Tax Rate BAD1 ${PREFIX}
```

**Portability (rules 6–8) — discovery is written AND proven to return a real row.**
The two good rates reference `${TAX_REGIME_CODE}` / `${TAX}` / `${TAX_STATUS_CODE}`, all
discovered at load time by a read-only BIP query against the target pod (no hardcoded ids).
The new rate codes carry a fresh numeric `${PREFIX}` so re-runs never collide.

Discovery step `US_TAX_REGIME_TAX_STATUS` (executed live 2026-07-19, returned a real triple):
```sql
SELECT * FROM (
  SELECT r.tax_regime_code AS RC, t.tax AS TX, s.tax_status_code AS STS
  FROM   zx_regimes_b r
  JOIN   zx_taxes_b  t ON t.tax_regime_code = r.tax_regime_code
  JOIN   zx_status_b s ON s.tax = t.tax AND s.tax_regime_code = t.tax_regime_code
  WHERE  r.country_code = 'US'
  ORDER  BY r.tax_regime_code, t.tax
) WHERE ROWNUM = 1
-- returned: US EXCISE TAX / US NY EXCISE TAX / US NY EXCISE
```

**Good / bad design.**
- **Good:** two rates `${PREFIX}RT-TAXRATE-G1` (5%) and `${PREFIX}RT-TAXRATE-G2` (7.25%) under
  the discovered existing regime/tax/status.
- **Bad (deterministic rejection):** `${PREFIX}RT-TAXRATE-BAD1` names a parent regime
  `RT_NO_SUCH_REGIME_${PREFIX}` (plus tax/status) that does not exist on the pod. A rate whose
  parent regime is absent is rejected by the workbook loader and cannot reach the base table —
  a deterministic, pod-independent failure needing no bad reference data.

## Orchestration (when a load path exists)

The workbook upload is a single Setup action that (on success) writes directly to the ZX base
tables — `ZX_REGIMES_B`, `ZX_TAXES_B`, `ZX_STATUS_B`, `ZX_RATES_B` (and `_TL` companions).
There is no BIP-reachable tax interface/rejection table for workbook uploads; errors surface
only in the upload **process error log** (downloadable in Monitor Upload and Download
Processes), which is not BIP-reachable. So the bad-row proof is **absence from `ZX_RATES_B`**
(the same `bad_proof_is_absence` pattern used by Billing Events / Item Import / Lookups),
captured in the recipe's `bad_proof_is_absence` + `bad_absence_note`.

If a headless path opens, the likely ESS chain to verify is: **Load Interface File for Import**
(UCM `fin/tax/import`) → the workbook import process → then read the ZX base tables.

## Verify SQL (read-only BIP, direct single-table reads)

Good rates reached base:
```sql
SELECT tax_rate_code, tax_rate_id, percentage_rate
FROM   zx_rates_b
WHERE  tax_rate_code LIKE '${PREFIX}RT-TAXRATE-%';   -- expect G1 (5) + G2 (7.25) with real TAX_RATE_IDs
```
Bad rate absent from base (rejection proof):
```sql
SELECT tax_rate_code, tax_rate_id
FROM   zx_rates_b
WHERE  tax_rate_code = '${PREFIX}RT-TAXRATE-BAD1';   -- expect zero rows
```

## Live evidence

None — **tabled, never faked**. No prefix, no request ids, because no non-UI load was
attempted (there is no web-service job that creates a custom tax rate). What WAS proven live
(read-only) on 2026-07-19: the pod has US tax regimes/taxes/statuses to attach to
(`ZX_REGIMES_B` has 69 regimes, `ZX_RATES_B` has 39,077 rates), and the discovery query
returns a real regime/tax/status triple — so the fixture is genuinely portable and ready.
Promote to ✅ only after a schedulable / web-service tax-workbook-upload path is confirmed on
the pod (or the FBL UI-automation decision is made); then upload `TaxRates.csv`, verify with
the SQL above, and record prefix + result here and in `objects/TaxRegimes/README.md`.

## Sources

- Oracle: [Tax Configuration Content Upload Program](https://docs.oracle.com/en/cloud/saas/financials/25d/faitx/tax-configuration-content-upload-program.html) (US-only tax-partner content; `zx_data_upload_interface`; Load Interface File for Import → Import Tax Configuration Content)
- Oracle: [Tax Configuration Using Rapid Implementation](https://docs.oracle.com/en/cloud/saas/financials/21d/faitx/tax-configuration-using-rapid-implementation.html) (Tax Configuration Workbook uploaded via Manage Tax Regimes → Rapid Setup Spreadsheets → Upload Tax Configuration Workbook)
- Oracle: [Implementing Tax 26B (PDF)](https://docs.oracle.com/en/cloud/saas/financials/26b/faitx/implementing-tax.pdf) (Tax Configuration Workbook vs Tax Implementation Workbook; UI upload button)
- Oracle Data Model: [ZX_TAXES_B](https://docs.oracle.com/en/cloud/saas/financials/25c/oedmf/zxtaxesb-11519.html), [ZX_DATA_UPLOAD_DISCARD](https://docs.oracle.com/en/cloud/saas/financials/22c/oedmf/zxdatauploaddiscard-4973.html)
- Local seed: `db/seed/dmt_erp_interface_options_tbl.sql` line 468 (options id 19, `LaunchTaxConfigContentUpload`, `fin/tax/import`)
