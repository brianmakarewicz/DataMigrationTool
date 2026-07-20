# TaxRegimes / TaxRates (canonical object README)

**Family:** Transaction tax configuration — tax **regimes**, **taxes**, **tax statuses**,
**tax rates** (ZX_* base tables). In the gold-regression library this is tracked as the single
object **TaxConfig** (status-table row 45).

**Gold status:** 🟡 **TABLED — retried 2026-07-20.** The FSM "Setup Data Import from CSV file"
path (the mechanism that made UnitsOfMeasure pass) was retried and does reach a rate-level tax
task, but that task's CSV package has no rate-header object, so it still cannot create a tax rate.
Full evidence, fixture, discovery and verify SQL live in the TaxConfig object folder:

- Fixture + recipe + finding: `objects/TaxConfig/GOLD_README.md`
- Recipe: `objects/TaxConfig/recipe.json`
- Templated file: `objects/TaxConfig/artifact/TaxRates.csv`
- Live export manifest (evidence): `objects/TaxConfig/artifact/EXPORT_MANIFEST_ZX_MANAGE_TAX_RATES.xml`

## 2026-07-20 FSM CSV import retry (why it is still tabled)

The rate-level setup task **`ZX_MANAGE_TAX_RATES_AND_TAX_RECOVERY_RATES`** reports
`ImportSupportedFlag=true` / `CSVExportImportSupportedFlag=Y`, so a non-UI CSV path exists at the
task level. But a live `setupTaskCSVExports` (ESS 9765467) lists **22 business objects, none of
which is a tax-rate header** — they are all rate **detail/child** objects (default tax accounts;
amount/unit-price/percent/quantity/gross/withheld schedules and types; recovery types) plus
`ZX_TAX_STATUS`. Two live `setupTaskCSVImports` attempts (a hand-authored `ZX_RATES` member, then
six candidate header short names) each completed but were **skipped as unknown business objects**,
and **zero rows reached `ZX_RATES_B`**. The FSM CSV import here is a detail-only round-trip onto
rates that already exist; rate headers are still created only by the UI Tax Configuration Workbook.
No prefix / base ids recorded — nothing was created.

## One-paragraph summary (the mechanism)

Fusion has two tax-config load mechanisms and neither is a standalone web-service path for a
custom rate. (1) The **Tax Configuration Content Upload Program**
(`/oracle/apps/ess/financials/tax/report;LaunchTaxConfigContentUpload`, ERP interface options
id 19, UCM `fin/tax/import`, interface `ZX_DATA_UPLOAD_INTERFACE`) IS an ESS/`loadAndImportData`
path, but Oracle documents it as **US-only tax-partner content** (geography + partner rate
content) — it cannot create arbitrary custom regimes/taxes/rates. (2) The **Tax Configuration
Workbook** (rapid-implementation Excel → CSV) DOES create regimes/taxes/rates, but is uploaded
**only** via the Manage Tax Regimes UI (**Rapid Setup Spreadsheets → Upload Tax Configuration
Workbook**) — no `loadAndImportData` JobName, no `submitESSJobRequest` jobDefinition, no
Scheduler-REST job. Both violate the harness's standalone-web-service / no-browser rule, so
TaxConfig sits behind the same "FBL delivery undecided" gate as Lookups / GLCalendar /
ValueSets / UnitsOfMeasure / PaymentTerms.

## Base tables (read-only BIP verification, proven reachable 2026-07-19)

- `ZX_REGIMES_B` — tax regimes (69 rows on this pod; US regimes present, e.g. `US EXCISE TAX`,
  `US SALES AND USE TAX`).
- `ZX_TAXES_B` — taxes (e.g. `US NY EXCISE TAX`, `CITY`, `COUNTY`).
- `ZX_STATUS_B` — tax statuses (join on `tax` + `tax_regime_code`).
- `ZX_RATES_B` — tax rates (39,077 rows), verification key `tax_rate_code`.

## Portability discovery (written and proven to return a real row)

A new rate borrows an existing US regime/tax/status discovered at load time — nothing
hardcoded:

```sql
SELECT * FROM (
  SELECT r.tax_regime_code AS RC, t.tax AS TX, s.tax_status_code AS STS
  FROM   zx_regimes_b r
  JOIN   zx_taxes_b  t ON t.tax_regime_code = r.tax_regime_code
  JOIN   zx_status_b s ON s.tax = t.tax AND s.tax_regime_code = t.tax_regime_code
  WHERE  r.country_code = 'US'
  ORDER  BY r.tax_regime_code, t.tax
) WHERE ROWNUM = 1
-- returned live: US EXCISE TAX / US NY EXCISE TAX / US NY EXCISE
```

## To promote to ✅

Confirm a schedulable / web-service tax-workbook-upload path on the pod (or make the FBL
UI-automation decision). Then upload `objects/TaxConfig/artifact/TaxRates.csv` (stamped with a
fresh `${PREFIX}` and the discovered regime/tax/status), verify good rates in `ZX_RATES_B` and
bad rate absent, and record prefix + request ids here and in `objects/TaxConfig/GOLD_README.md`.
