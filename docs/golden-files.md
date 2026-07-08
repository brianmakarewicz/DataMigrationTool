# Golden Files Inventory — FBDI/HDL Generator Byte-Compare Testing (Stage B4)

Inventory of known-good generator outputs available in this repo for byte-comparing the
rebuilt generators against the proven old stack (ConversionTool / DMT_OWNER on queryapp ATP).

A file is **usable as golden** only if it is generator OUTPUT (position-based, headerless
FBDI interface CSV inside a zip, or an HDL `.dat`) captured from a proven run of the old
stack. Headered CSVs are pipeline INPUT test data and are not golden-compare material.

## Manifest

### `test/fbdi_zips/` — generated FBDI output (golden candidates)

All `*_116.zip` files below were captured **2026-07-08** from the old stack's ATP
(`DMT_OWNER.DMT_FBDI_ZIP_TBL`, `INTEGRATION_ID = 116`) via `ConversionTool/scripts/extract_zip.py`.
**Run 116 provenance:** full RegressionTest scenario run of 2026-07-04 (prefix 9627, RUN_MODE=ALL,
submitted by REGRESSION_AGENT), `DMT_PIPELINE_RUN_TBL.RUN_STATUS = COMPLETED` (not COMPLETED_ERRORS),
all 36 `DMT_WORK_QUEUE_TBL` entries `WORK_STATUS = DONE` — the newest fully proven run on the ATP.
Original ATP filenames differed for some objects (noted per row); copies renamed to the
`{ObjectType}_{integration_id}.zip` convention.

| Object (CEMLI) | File | Format | Contents / rows | Provenance | Usable as golden |
|---|---|---|---|---|---|
| Suppliers (import 1 of 5) | `test/fbdi_zips/Suppliers_100000898.zip` | FBDI zip | `PoSupplierImport.csv` — 3 rows, headerless position-based | Old-stack generator output, run/integration 100000898 (regression scenario, 9427RT prefix data) | **Yes** |
| Suppliers (import 1 of 5) | `test/fbdi_zips/Suppliers_116.zip` | FBDI zip | `PoSupplierImport.csv` — 3 rows | Run 116 (see above) | **Yes** |
| Suppliers — Addresses (import 2 of 5) | `test/fbdi_zips/SupplierAddresses_100000899.zip` | FBDI zip | `PozSupAddressesInt.csv` — 3 rows | Old-stack generator output, run 100000899 | **Yes** |
| Suppliers — Addresses (import 2 of 5) | `test/fbdi_zips/SupplierAddresses_116.zip` | FBDI zip | `PozSupAddressesInt.csv` — 3 rows | Run 116 | **Yes** |
| Suppliers — Sites (import 3 of 5) | `test/fbdi_zips/SupplierSites_116.zip` | FBDI zip | `PozSupplierSitesInt.csv` — 3 rows | Run 116 | **Yes** |
| Suppliers — Site Assignments (import 4 of 5) | `test/fbdi_zips/SupplierSiteAssignments_116.zip` | FBDI zip | `PozSiteAssignmentsInt.csv` — 3 rows | Run 116 | **Yes** |
| Suppliers — Contacts (import 5 of 5) | `test/fbdi_zips/SupplierContacts_116.zip` | FBDI zip | `PozSupContactsInt.csv` — 3 rows | Run 116 | **Yes** |
| PurchaseOrders — Standard | `test/fbdi_zips/PurchaseOrders_116.zip` | FBDI zip | `PoHeadersInterfaceOrder.csv` — 7 rows, `PoLinesInterfaceOrder.csv` — 4, `PoLineLocationsInterfaceOrder.csv` — 3, `PoDistributionsInterfaceOrder.csv` — 3 | Run 116 (ATP filename `PO_US1BusinessUnit_116.zip`) | **Yes** |
| PurchaseOrders — Blanket variant | `test/fbdi_zips/BlanketPOs_100000905.zip` | FBDI zip | `PoHeadersInterfaceBlanket.csv` — 2 rows, `PoLinesInterfaceBlanket.csv` — 1 row | Old-stack generator output, run 100000905 | **Yes** (blanket variant only; standard PO covered by `PurchaseOrders_116.zip`) |
| Requisitions | `test/fbdi_zips/Requisitions_116.zip` | FBDI zip | `PorReqHeadersInterfaceAll.csv` — 4 rows, `PorReqLinesInterfaceAll.csv` — 4, `PorReqDistsInterfaceAll.csv` — 4 | Run 116 (ATP filename `REQ_116.zip`) | **Yes** |
| APInvoices | `test/fbdi_zips/APInvoices_116.zip` | FBDI zip | `ApInvoicesInterface.csv` — 4 rows, `ApInvoiceLinesInterface.csv` — 4 rows | Run 116 (ATP filename `AP_US1BusinessUnit_116.zip`) | **Yes** |
| Customers | `test/fbdi_zips/Customers_116.zip` | FBDI zip | 7 CSVs, 3 rows each: `HzImpPartiesT`, `HzImpLocationsT`, `HzImpPartySitesT`, `HzImpPartySiteUsesT`, `HzImpAccountsT`, `HzImpAcctSitesT`, `HzImpAcctSiteUsesT` | Run 116 | **Yes** |
| ARInvoices | `test/fbdi_zips/ARInvoices_116.zip` | FBDI zip | `RaInterfaceLinesAll.csv` — 3 rows | Run 116 (ATP filename `ARInvoices_US1BusinessUnit_Manual-Other_116.zip`) | **Yes** |
| GLBalances | `test/fbdi_zips/GLBalances_100000740.zip` | FBDI zip | `GlInterface.csv` — 3 rows | Old-stack generator output, run 100000740 | **Yes** |
| Assets | `test/fbdi_zips/Assets_116.zip` | FBDI zip | `FaMassAdditions.csv` — 3 rows, `FaMassaddDistributions.csv` — 3 rows | Run 116 (ATP filename `Assets_116_US_CORP.zip`, US CORP book partition) | **Yes** |
| Projects | `test/fbdi_zips/Projects_116.zip` | FBDI zip | `PjfProjectsAllXface.csv` — 3 rows, `PjfProjElementsXface.csv` — 3, `PjfProjectPartiesInt.csv` — 2, `PjcTxnControlsStage.csv` — 2 | Run 116 | **Yes** |
| Expenditures | `test/fbdi_zips/Expenditures_116.zip` | FBDI zip | `PjcTxnXfaceStageAll.csv` — 3 rows | Run 116 | **Yes** |
| BillingEvents | `test/fbdi_zips/BillingEvents_116.zip` | FBDI zip | `PjbBillingEventsXface.csv` — 3 rows | Run 116 | **Yes** |
| ProjectBudgets | `test/fbdi_zips/ProjectBudgets_116.zip` | FBDI zip | `PjoPlanVersionsXface.csv` — 2 rows | Run 116 | **Yes** |
| Workers (HDL) | `test/fbdi_zips/Workers_116.zip` | HDL zip | `Worker.dat` — 10 METADATA + 25 MERGE lines | Run 116 (ATP filename `Worker_116.zip`; the HDL generators write to `DMT_FBDI_ZIP_TBL` too) | **Yes** |
| Salary (HDL) | `test/fbdi_zips/Salaries_116.zip` | HDL zip | `Salary.dat` — 1 METADATA + 3 MERGE lines | Run 116 (ATP filename `Salary_116.zip`, object type `Salaries`) | **Yes** |
| TalentProfiles (HDL) | `test/fbdi_zips/TalentProfiles_116.zip` | HDL zip | `TalentProfile.dat` — 1 METADATA + 3 MERGE lines | Run 116 | **Yes** |

> Note: on the ATP, `WorkerAssignments` also records a file named `Worker_116.zip` (54 bytes,
> empty). When re-extracting, pull object types one at a time (`extract_zip.py 116 Workers`)
> or the second write clobbers the first in `output/`.

### `test/regression_test_bundle.zip` — pipeline INPUT (not golden)

24 headered CSVs (~3 data rows each: 2 GOOD + 1 BAD per object), built by the old stack's
`scripts/build_regression_zip.py` from `DMT_UPLOAD_DICT_TBL` column definitions. Files:
`AP_INVOICES, AP_PAY_TERM_HDR, AP_PAY_TERM_LINE, CE_BANK, CE_BANK_ACCT, CE_BRANCH,
EGP_ITEM, EGP_ITEM_CAT, FA_ASSET_HDR, FND_LOOKUP_TYPE, FND_LOOKUP_VALUE, FND_VS_SET,
FND_VS_VALUE, GL_CALENDAR, GL_INTERFACE, HZ_PARTIES, INV_UOM, PJF_PROJECTS, POZ_SUPPLIERS,
PO_HEADERS, RA_LINES, WORKER, ZX_RATE, ZX_REGIME`.

**Not usable as golden output** — these are staging-load inputs (headers, business column
names). They ARE the right input data to feed the rebuilt pipeline when producing outputs
to compare against golden files, so keep the bundle for that purpose.

### Old repo `ConversionTool/output/` — stale early outputs (reference only)

`PozSuppliersInt.zip` (6 rows), `sup_addr_1000000{01,02}.zip` (4 rows), `sup_site_1000000{02,05}.zip`
(3 rows) — supplier-family generator outputs from March 2026, before many later generator
fixes. **Do not use as golden**; re-capture instead. (Old repo is read-only; files not copied.)

## Coverage vs the 15 proven objects

| # | Object | Golden output in repo? | Notes |
|---|---|---|---|
| 1 | Suppliers | **Yes** | All 5 imports from run 116; imports 1-2 also from runs 100000898/100000899 |
| 2 | PurchaseOrders | **Yes** | Standard PO from run 116 + blanket variant from run 100000905 |
| 3 | Requisitions | **Yes** | `Requisitions_116.zip` |
| 4 | APInvoices | **Yes** | `APInvoices_116.zip` |
| 5 | Customers | **Yes** | `Customers_116.zip` (7 interface CSVs) |
| 6 | ARInvoices | **Yes** | `ARInvoices_116.zip` |
| 7 | GLBalances | **Yes** | `GLBalances_100000740.zip` |
| 8 | Assets | **Yes** | `Assets_116.zip` (US CORP book) |
| 9 | Projects | **Yes** | `Projects_116.zip` (4 interface CSVs) |
| 10 | Expenditures | **Yes** | `Expenditures_116.zip` |
| 11 | BillingEvents | **Yes** | `BillingEvents_116.zip` |
| 12 | ProjectBudgets | **Yes** | `ProjectBudgets_116.zip` |
| 13 | Workers (HDL) | **Yes** | `Workers_116.zip` (`Worker.dat`) |
| 14 | Salary (HDL) | **Yes** | `Salaries_116.zip` (`Salary.dat`) |
| 15 | TalentProfiles (HDL) | **Yes** | `TalentProfiles_116.zip` (`TalentProfile.dat`) |

**Coverage: 15 of 15 covered** (captured 2026-07-08 from proven run 116, plus the 4 earlier
captures). Generated content embeds run-scoped tokens — run id `116`, prefix `9627`, interface
keys, dates — so the compare harness must replay with pinned run id/prefix/date or normalize
before diffing (see step 5 below).

## Byte-compare harness (Stage B4)

Lives in `test/golden/`:

- `compare_fbdi.py` — stdlib-only compare: extracts both zips, rewrites the declared
  run-scoped tokens on both sides to shared placeholders, masks declared generation-date
  CSV positions (only when both sides are `YYYY/MM/DD`), then byte-compares. Any other
  difference is reported field-by-field and fails the run — never widen the map to make
  a compare pass.
- `normalization_map.json` — per-object token/date-mask data (golden token → `$PREFIX`/
  `$RUN_ID`, match mode, optional field-position restriction). Extend with one entry per
  object; no code changes needed for new FBDI objects.
- `inputs/{Object}_input.csv` — headered staging input reproducing the golden's exact
  source rows (from the old stack's `insert_regression_test_data.py`). NOTE: the
  repo-level `regression_test_bundle.zip` CSVs are dictionary-built and hold DIFFERENT
  data — they cannot reproduce the run-116/100000740 goldens.
- `test_glbalances_golden.sh` — reference orchestration: land input via
  `DMT_CSV_LOADER_PKG`, run row via `DMT_PIPELINE_INIT_PKG.INIT_RUN`, transform,
  `GENERATE_FBDI`, extract from `DMT_FBDI_ZIP_TBL`, compare. Verified byte-identical
  2026-07-08 on dmt2-local.
- `run_golden_tests.sh` — sibling of `test/unit/run_unit_tests.sh`; runs every
  `test_*_golden.sh`, exit 0 only if all pass (CI hook).

## Capture procedure for the gaps

The old stack's ATP (queryapp, schema `DMT_OWNER`) retains every generated artifact per run:

- `DMT_FBDI_ZIP_TBL` — one BLOB zip per object per run (`INTEGRATION_ID`, `OBJECT_TYPE`,
  `FILENAME`, `ZIP_CONTENT`). **HDL generators write here too** (all
  `packages/generators/hdl/dmt_*_hdl_gen_pkg.pkb` insert into `DMT_FBDI_ZIP_TBL`), so HDL
  `.dat` output is captured the same way.
- `DMT_FBDI_CSV_TBL` — the individual member CSVs, if per-file capture is preferred.

An extractor already exists in the old repo — **`ConversionTool/scripts/extract_zip.py`**
(read-only use; run from the old repo, it connects via `conn_helper.connect_atp('queryapp','DMT_OWNER')`):

```
# list the 20 most recent zips (integration id, object type, filename, size, date)
python scripts/extract_zip.py

# extract all zips for one run, or one object of that run, to ConversionTool/output/
python scripts/extract_zip.py <integration_id> [object_type]
```

Recommended capture steps per missing object:

1. In the old stack, run the regression scenario for the object (modes/prefix per the old
   repo rules — always UsePrefix=Y) OR identify the most recent proven-LOADED run's
   `INTEGRATION_ID` (list mode of `extract_zip.py`, or `DMT_MIGRATION_LOG`/status.md history).
   Prefer an existing proven run over generating a new one — no new load needed just to
   capture generator output.
2. `python scripts/extract_zip.py <integration_id>` — extracts every object zip for that run.
3. Copy the extracted zips into `DMT2/test/fbdi_zips/` using the existing naming convention
   `{ObjectType}_{integration_id}.zip` (HDL: keep whatever `FILENAME` the generator recorded,
   e.g. `Worker_{id}.zip` containing `Worker.dat`).
4. Record the source `INTEGRATION_ID` and capture date in this manifest.
5. For byte-compare, note that generated content embeds run-scoped values (interface keys
   like `100000318_HDR_100000070`, prefixes like `9427RT`, dates). The compare harness must
   either replay with pinned run IDs/prefix/date or normalize those tokens before diffing.

~~Also re-capture fresh Suppliers imports 3-5 (Sites, Site Assignments, Contacts) and a
standard (non-blanket) PurchaseOrders zip to complete the two partial objects.~~
**Done 2026-07-08** — all 15 objects captured from run 116 (see manifest above); no gaps remain.
