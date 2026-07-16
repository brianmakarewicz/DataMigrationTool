# Purchase Orders

## Status
E2E ACCEPTED (LOADED)

## Pipeline
- Module: Procurement
- FBDI Template: PoHeadersInterfaceOrder.xlsm
- Interface Tables: PO_HEADERS_INTERFACE, PO_LINES_INTERFACE, PO_LINE_LOCATIONS_INTERFACE, PO_DISTRIBUTIONS_INTERFACE
- UCM Account: prc/purchaseOrder/import
- ESS Job: ImportSPOJob
- ParameterList: 9-arg format; see memory/project_c004_purchase_orders.md
- Loader Type: SQLLOADER
- Auth User: calvin.roth
- Grouping: Grouped by PRC_BU_NAME

## Code References
- STG Table DDL (Headers): `schema/tables/18_dmt_po_headers_int_stg_tbl.sql`
- STG Table DDL (Lines): `schema/tables/19_dmt_po_lines_int_stg_tbl.sql`
- STG Table DDL (LineLocations): `schema/tables/20_dmt_po_line_locs_int_stg_tbl.sql`
- STG Table DDL (Distributions): `schema/tables/21_dmt_po_dists_int_stg_tbl.sql`
- TFM Table DDL (Headers): `schema/tables/22_dmt_po_headers_int_tfm_tbl.sql`
- TFM Table DDL (Lines): `schema/tables/23_dmt_po_lines_int_tfm_tbl.sql`
- TFM Table DDL (LineLocations): `schema/tables/24_dmt_po_line_locs_int_tfm_tbl.sql`
- TFM Table DDL (Distributions): `schema/tables/25_dmt_po_dists_int_tfm_tbl.sql`
- Validator: `packages/validators/dmt_po_validator_pkg.*`
- Transformer: `packages/transformers/dmt_po_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/po/dmt_po_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_po_results_pkg.*`
- BIP Data Model/Report: `bip/PurchaseOrders/`

## Reference Files
None in this folder.

## Known Issues
None currently. Multi-BU grouping working correctly.

## History
- E2E ACCEPTED (LOADED) confirmed. Grouped FBDI pattern validated.
- 9-arg ParameterList documented in memory/project_c004_purchase_orders.md.

## Known-good Fusion record & mapping (2026-07-15)

Investigation of the run-155 PO header rejection (GOOD header rejected, cascaded to its
lines/locations/distributions). All facts below were read live from the demo Fusion
instance (read-only, fin_impl) via `scripts/fusion_bip_query.py`. Nothing was changed.

### Root cause (high confidence)

Our regression PO shipment (line-location) rows do NOT populate `SHIP_TO_LOCATION`.
The staging table `DMT_PO_LINE_LOCS_INT_STG_TBL` has a `SHIP_TO_LOCATION` column, the
transformer (`db/packages/dmt_po_transform_pkg.pkb.sql`, ~line 168 and ~line 576) passes
it straight through to the FBDI, but the regression seed
(`scripts/insert_regression_test_data.py`, section "15. PO Line Locations", ~lines 925-936)
inserts only SHIPMENT_NUM, QUANTITY, DESTINATION_TYPE_CODE='EXPENSE' and NEED_BY_DATE.
So the FBDI ships an empty ship-to location. Oracle's PO import requires a valid ship-to
location on every expense shipment; a missing/invalid one rejects the shipment and
cascades to reject the whole document (header + lines + distributions).

This matches the errors persisted in `PO_INTERFACE_ERRORS` on the instance. The most
frequent English-language failures on this demo pod are, in order:
- `SHIP_TO_LOCATION_ID` — `FND_CMN_INVALID_ATTRB_API_SERV` (attribute not valid) — thousands of rows.
- `SHIP_TO_LOCATION` — "The ship-to location isn't valid. Verify that the location is a Ship-to Site and ...".
- `VENDOR_SITE_CODE` / `VENDOR_SITE_ID` — "The supplier site isn't valid ..." (expected for our BAD row, and for GOOD rows if the RT supplier site did not load first).
- `CATEGORY` / `CATEGORY_ID` — "The value of the attribute isn't valid" / "You must enter a value".
- `PO_HEADER_ID` — "You must provide at least one distribution for each schedule".

Note: the exact run-155 interface rows are already purged (interface tables are cleared
after each import; `document_num` is null on processed headers), so we could not read the
literal error text tied to source key `155_HDR_100000351`. The attribution above is by
matching our test-data profile to the errors that remain persisted. Treat the ship-to
gap as the primary cause; the category value is a strong secondary suspect (see below).

### Real, successfully-created PO to mimic (US1 Business Unit)

`PO_HEADERS_ALL.po_header_id = 2146`, `segment1 = 162354`, type `STANDARD`. Driving values:

| Field | Real good-PO value | Our test-data value | Match? |
|---|---|---|---|
| Procurement BU / Requisitioning BU | US1 Business Unit | US1 Business Unit | OK |
| Sold-to LE / Bill-to BU | (US1 LE / US1 BU) | US1 Legal Entity / US1 Business Unit | OK (name form to verify) |
| Currency | USD | USD | OK |
| Supplier (vendor) | EIP Inc (vendor_id 300000047507499) | RT Supplier Good-1/2 (RT-SUP-G1/2) | OK **only if** the RT supplier loaded earlier in the same P2P run |
| Supplier site | EIP US1 (vendor_site_id 300000047507525) | RT-SITE-G1/2 | same caveat as supplier |
| Buyer / agent | agent_id 300000047340498 (active US1 buyer) | "Roth, Calvin" | verify Roth is an active US1 buyer |
| Line type | line_type_id 1 (Goods/Services) | 'Goods' | verify 'Goods' resolves on this pod |
| UOM | uom_code 'zzu' on this sample line | 'Each' | 'Each' is standard-valid; sample PO used an odd services UOM |
| Category | (services category) | 'Miscellaneous' | **verify 'Miscellaneous' is a valid purchasing category** |
| Quantity / Unit price | 1 / positive | 10 / 100.00 etc. | OK |
| **Ship-to location** | **Seattle** (location_id 300000047013200, ship_to_site_flag = Y) | **NULL (not set)** | **MISSING — root cause** |
| Ship-to organization | org 300000047274444 | NULL | set if the pod requires it |
| Destination type | EXPENSE | EXPENSE | OK |
| Charge account | valid CCID (e.g. code_combination_id 10357) | segments 101-10-68010-120-000-000 | verify this combination is valid/enabled for US1 |

"Seattle" is confirmed a valid ship-to site for this instance (`HR_LOCATIONS_ALL.ship_to_site_flag = 'Y'`).

### Precise test-data change needed (propose — do not edit the seed yet)

In `scripts/insert_regression_test_data.py`, section "15. PO Line Locations"
(the `DMT_PO_LINE_LOCS_INT_STG_TBL` insert, ~lines 925-936), add `SHIP_TO_LOCATION`
(and optionally `SHIP_TO_ORGANIZATION_CODE`) to the column list and set it to a valid
ship-to location for the US1 Business Unit — use **'Seattle'** for the GOOD rows
(leave the BAD row without one, or with a bad value, so it still fails as intended).

Example (GOOD rows only):
```sql
INSERT INTO DMT_OWNER.DMT_PO_LINE_LOCS_INT_STG_TBL (
    INTERFACE_LINE_LOCATION_KEY, INTERFACE_LINE_KEY,
    SHIPMENT_NUM, QUANTITY, DESTINATION_TYPE_CODE,
    SHIP_TO_LOCATION,          -- ADD THIS
    NEED_BY_DATE, SOURCE_ID
) VALUES (
    :llkey, :lkey, :snum, :qty, 'EXPENSE',
    'Seattle',                 -- ADD THIS (valid US1 ship-to site)
    DATE '2025-12-31', :src
)
```

Also verify, before the next live PO run, that the GOOD line's `CATEGORY = 'Miscellaneous'`
resolves to a valid purchasing category on this pod (the persisted errors show many
`CATEGORY`/`CATEGORY_ID` rejections). If it does not, change it to a known-valid category.

### Reusable read-only queries (fin_impl)

Recent standard POs for a BU (find a template):
```
python scripts/fusion_bip_query.py --cred fin_impl --cols POH,SEG,PBU,SUP,SITE,AGENT,CUR \
 "SELECT ph.po_header_id POH, ph.segment1 SEG, bu.name PBU, ph.vendor_id SUP, ph.vendor_site_id SITE, ph.agent_id AGENT, ph.currency_code CUR FROM PO_HEADERS_ALL ph, HR_ALL_ORGANIZATION_UNITS bu WHERE ph.prc_bu_id=bu.organization_id AND ph.type_lookup_code='STANDARD' AND bu.name LIKE '%US1%' AND ROWNUM<=3 ORDER BY ph.po_header_id DESC"
```

Shipment + distribution driving values for one PO:
```
python scripts/fusion_bip_query.py --cred fin_impl --cols SHIPLOC,ORG,DESTTYPE,ACCT \
 "SELECT pll.ship_to_location_id SHIPLOC, pll.ship_to_organization_id ORG, pll.destination_type_code DESTTYPE, pd.code_combination_id ACCT FROM PO_LINE_LOCATIONS_ALL pll, PO_DISTRIBUTIONS_ALL pd WHERE pll.line_location_id=pd.line_location_id AND pll.po_header_id=2146 AND ROWNUM<=3"
```

Persisted PO import errors, grouped (what the pod actually rejects):
```
python scripts/fusion_bip_query.py --cred fin_impl --cols COL,ERR,CNT \
 "SELECT column_name COL, SUBSTR(error_message,1,80) ERR, COUNT(*) CNT FROM PO_INTERFACE_ERRORS GROUP BY column_name, SUBSTR(error_message,1,80) ORDER BY CNT DESC"
```

Confirm a ship-to location is valid:
```
python scripts/fusion_bip_query.py --cred fin_impl --cols LOC,SHIPFLAG \
 "SELECT location_code LOC, ship_to_site_flag SHIPFLAG FROM HR_LOCATIONS_ALL WHERE location_code='Seattle' AND ROWNUM<=3"
```

### Uncertainty
- Exact run-155 error text could not be read (interface rows purged); root cause is inferred
  by matching our test-data profile to persisted `PO_INTERFACE_ERRORS`.
- Buyer name ("Roth, Calvin"), line type ('Goods') and category ('Miscellaneous') were not
  positively re-validated against this pod's setup here (buyer-name views differ by release);
  the ship-to gap is the one confirmed, concrete defect.
