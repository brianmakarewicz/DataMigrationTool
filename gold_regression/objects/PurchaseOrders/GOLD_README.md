# PurchaseOrders — Gold Regression Fixture (Import Orders / ImportSPOJob)

**Status: ✅ LIVE-PROVEN both directions** on the Fusion demo instance
(`fa-esew-dev28`), 2026-07-19.

Two good purchase orders reach the base tables `PO_HEADERS_ALL` / `PO_LINES_ALL`;
one bad row lands in `PO_HEADERS_INTERFACE` with a real `PO_INTERFACE_ERRORS`
message ("The supplier site isn't valid…") and never reaches the base tables.

This fixture is built and loaded **outside** the DMT pipeline (no DMT database,
no DMT PL/SQL). It assembles the four FBDI CSVs, calls the Fusion ERP
Integration SOAP service directly, submits the Import Orders program, and
verifies with read-only single-table BIP reads.

---

## Object shape

One object = one FBDI zip = one load job. The PurchaseOrders zip carries **four
position-based CSVs** (no header row), in this order inside the zip:

| Member (archive name)                | Columns | Interface table              |
|--------------------------------------|--------:|------------------------------|
| `PoHeadersInterfaceOrder.csv`        |      99 | `PO_HEADERS_INTERFACE`       |
| `PoLinesInterfaceOrder.csv`          |      98 | `PO_LINES_INTERFACE`         |
| `PoLineLocationsInterfaceOrder.csv`  |      93 | `PO_LINE_LOCATIONS_INTERFACE`|
| `PoDistributionsInterfaceOrder.csv`  |     123 | `PO_DISTRIBUTIONS_INTERFACE` |

Column order/counts are byte-mirrored from the proven DMT PO FBDI generator
(`ConversionTool/packages/generators/fbdi/po/dmt_po_fbdi_gen_pkg.pkb`). Every
field is double-quoted. The templates live in `artifact/`; regenerate them with
`python objects/PurchaseOrders/build_templates.py`.

### Rows in the fixture (3 headers, 3 lines, 3 shipments, 3 distributions)

| Suffix | Header key / PO number | Meaning | Expected outcome |
|--------|------------------------|---------|------------------|
| `G1`   | `${PREFIX}RT-PO-G1`    | good    | `PO_HEADERS_ALL` |
| `G2`   | `${PREFIX}RT-PO-G2`    | good    | `PO_HEADERS_ALL` |
| `BAD1` | `${PREFIX}RT-PO-BAD1`  | bad — invalid supplier site `ZZINVALIDSITE` | rejected into `PO_INTERFACE_ERRORS`, absent from base |

Each good PO is one STANDARD order, one Goods line (description-based, no item
master needed), one EXPENSE shipment to a real ship-to location, one
distribution to a real charge account.

---

## Portability — every reference is discovered at load time (no hardcoded ids)

Nothing points at data we loaded earlier. At load time the harness runs two
read-only BIP discovery queries against the target pod and stamps the results
into the templates alongside `${PREFIX}`. Both queries pick a **real,
successfully-created STANDARD PO** on the pod and borrow its references.

Discovery step `PO_TEMPLATE` (one real PO header) yields:

| Token                 | Meaning                        | Value on esew-dev28 |
|-----------------------|--------------------------------|---------------------|
| `${PRC_BU_NAME}`      | Procurement / Requisitioning BU| `US1 Business Unit` |
| `${BU_ID}`            | BU id (ParameterList args 1,4) | `300000046987012`   |
| `${AGENT_ID}`         | buyer person id (arg 2)        | `300000047340498`   |
| `${AGENT_NAME}`       | buyer name (header)            | `Roth, Calvin`      |
| `${AGENT_EMAIL}`      | buyer email                    | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` |
| `${SOLDTO_LE_NAME}`   | sold-to legal entity           | `US1 Legal Entity`  |
| `${VENDOR_NAME}`      | supplier                       | `Lee Supplies`      |
| `${VENDOR_NUM}`       | supplier number                | `1252`              |
| `${VENDOR_SITE_CODE}` | supplier site (good rows)      | `Lee US1`           |
| `${CURRENCY_CODE}`    | currency                       | `USD`               |
| `${SHIP_TO_LOCATION}` | ship-to location               | `Seattle`           |

Discovery step `PO_LINE_REF` (one real EXPENSE distribution of a US1 PO) yields:

| Token                   | Meaning                | Value on esew-dev28 |
|-------------------------|------------------------|---------------------|
| `${LINE_TYPE}`          | purchasing line type   | `Goods`             |
| `${CATEGORY_NAME}`      | purchasing category    | `Computer Supplies` |
| `${DELIVER_TO_LOCATION}`| deliver-to location    | `Seattle`           |
| `${CHG_S1..S6}`         | charge-account segments| `101 / 10 / 63580 / 121 / 000 / 000` |

`UOM = Each` is a stock unit of measure. The bad row differs from the good rows
in exactly one field: `VENDOR_SITE_CODE = ZZINVALIDSITE`.

---

## Full ESS orchestration (in order)

The PO import is **two ESS steps under two different users**. This split is the
key learning: fin_impl can load the FBDI to the interface tables but cannot
submit the Import Orders program; the procurement functional user calvin.roth
submits Import Orders.

### Step 1 — Load FBDI to interface tables (auth: **fin_impl**)

`loadAndImportData` on the ERP Integration SOAP service
(`…/fscmService/ErpIntegrationService`). It uploads the zip to UCM under the
document account, then runs the interface loaders (SqlLoader) into the four
`PO_*_INTERFACE` tables.

- **DocumentAccount:** `prc/purchaseOrder/import`
- **JobName (jobList):** `/oracle/apps/ess/prc/po/pdoi,ImportSPOJob`
- **interfaceDetails:** `21`
- **ParameterList (jobList):** the 9-arg list below (loadAndImportData does not
  actually run ImportSPOJob under fin_impl — fin_impl lacks access — so it runs
  only the loaders and returns SUCCEEDED; the real import is Step 2).

Returns the **load request id**. Poll `getESSJobStatus` to a terminal state
(SUCCEEDED). All three headers now sit in `PO_HEADERS_INTERFACE` with
`PROCESS_CODE = NULL` (not yet imported).

> **Why calvin.roth is not used for Step 1:** calvin.roth returns HTTP 401 on the
> loadAndImportData SOAP call (it lacks the integration-service privilege). So
> the load runs as fin_impl.

### Step 2 — Import Orders (auth: **calvin.roth**)

`submitESSJobRequest` for `/oracle/apps/ess/prc/po/pdoi,ImportSPOJob` submitted
by **calvin.roth**. fin_impl cannot submit this job
(`FUN-720397: user doesn't have access to ESS job definition`); calvin.roth can.
The job reads the interface rows for the batch and creates the POs. Poll
`getESSJobStatus` to terminal (SUCCEEDED).

Cross-user pickup works: the interface rows are created_by FIN_IMPL, but
ImportSPOJob submitted by calvin.roth still processes them because the job is
scoped by the Procurement BU (ParameterList arg 1) and the batch, not by owner.

In the harness this is declared as a `downstream_jobs` entry on the recipe with
its own `cred_role: calvin.roth`; `harness/load_fbdi.py` submits and polls a
downstream job with that role's creds.

### The 9-argument ParameterList (comma-delimited), spelled out

`${BU_ID},${AGENT_ID},SUBMIT,${BU_ID},,N,,N,${BU_ID}_${PREFIX}`

| # | Argument                         | Value (this fixture) |
|---|----------------------------------|----------------------|
| 1 | Procurement BU id / Import source| `${BU_ID}` (e.g. `300000046987012`) |
| 2 | Default buyer person id          | `${AGENT_ID}` (e.g. `300000047340498`) |
| 3 | Action                           | `SUBMIT` |
| 4 | Default requisitioning BU id     | `${BU_ID}` |
| 5 | (unused)                         | *(empty)* |
| 6 | Create/replace flag              | `N` |
| 7 | (unused)                         | *(empty)* |
| 8 | Approval / hold flag             | `N` |
| 9 | Batch label (free text)          | `${BU_ID}_${PREFIX}` (e.g. `300000046987012_16041`) |

The format mirrors the proven DMT loader
(`dmt_loader_pkg.pkb`, PurchaseOrders grouped block:
`l_bu_id,l_buyer_id,'SUBMIT',l_req_bu_id,,N,,N,l_bu_id_'||run_id`).

> **BATCH_ID gotcha (fixed):** `PO_HEADERS_INTERFACE.BATCH_ID` is a **NUMBER**
> column. The header CSV `BATCH_ID` field must therefore be numeric — the fixture
> uses `${PREFIX}`. Putting the free-text arg-9 label (`BU_ID_PREFIX`) into the
> header BATCH_ID column causes `ORA-01722: invalid number` and **all header rows
> are rejected by SqlLoader** before the interface tables are even populated.
> Arg 9 (a text batch label) and the numeric header BATCH_ID column are separate.

> **Line ACTION gotcha (fixed):** the header `ACTION` is `ORIGINAL`, but the
> **line** `ACTION` must be **blank** for a new order. A line ACTION of
> `ORIGINAL` is rejected as `PO_LINES_INTERFACE.ACTION — The value of the
> attribute isn't valid`, which cascades to reject the whole document.

### No further downstream program

Once ImportSPOJob reaches SUCCEEDED the good POs are in `PO_HEADERS_ALL`. There
is no separate accounting/validation program to wait on before verifying. (POs
are created in `DOCUMENT_STATUS = INCOMPLETE` — a functional-user SUBMIT draft.
Reaching the base table is the pass bar.)

---

## Verification (read-only, direct single-table reads)

### Good → base table (by prefix on the PO number)
```sql
SELECT segment1, po_header_id, document_status
FROM   po_headers_all
WHERE  segment1 LIKE :PREFIX || 'RT-PO-%';
```
Two rows with real `po_header_id`s == pass. Lines confirm:
```sql
SELECT h.segment1, l.line_num, l.item_description, l.unit_price
FROM   po_lines_all l JOIN po_headers_all h ON h.po_header_id = l.po_header_id
WHERE  h.segment1 LIKE :PREFIX || 'RT-PO-%';
```

### Bad → interface error (by load request id), and absent from base
```sql
SELECT h.document_num,
       h.interface_header_id,
       h.process_code,
       (SELECT LISTAGG(e.column_name || '=' || e.column_value || ': '
                       || e.error_message, ' | ')
          WITHIN GROUP (ORDER BY e.creation_date)
        FROM po_interface_errors e
        WHERE e.interface_header_id = h.interface_header_id) AS error_message
FROM   po_headers_interface h
WHERE  h.load_request_id = :LOAD_REQUEST_ID;
```
The bad row (`…RT-PO-BAD1`) carries
`VENDOR_SITE_CODE=ZZINVALIDSITE: The supplier site isn't valid…` and does **not**
appear in `PO_HEADERS_ALL`. `PO_INTERFACE_ERRORS` is keyed by
`INTERFACE_HEADER_ID` (join to `PO_HEADERS_INTERFACE` by that id, then to the
load by `LOAD_REQUEST_ID`).

---

## Last live-proven evidence

- **Date:** 2026-07-19 · **Pod:** fa-esew-dev28 · **Prefix:** `16041`
- **Load request (fin_impl, loadAndImportData):** `9763403` → SUCCEEDED
- **Import Orders request (calvin.roth, ImportSPOJob):** `9763413` → SUCCEEDED
- **Good → base `PO_HEADERS_ALL`:**
  - `16041RT-PO-G1` → `po_header_id = 674949` (STANDARD, 1 line)
  - `16041RT-PO-G2` → `po_header_id = 674950` (STANDARD, 1 line)
- **Bad → `PO_INTERFACE_ERRORS`:** `16041RT-PO-BAD1`,
  `VENDOR_SITE_CODE = ZZINVALIDSITE — "The supplier site isn't valid. Verify that
  the site is active, has the purchasing purpose assigned, is associated with the
  procurement business unit, and has an active assignment for the requisitioning
  business unit."` — absent from `PO_HEADERS_ALL`.
- **Verdict:** PASS (both directions).

### Reproduce
```
python harness/run_object.py PurchaseOrders          # fresh random prefix
python harness/run_object.py PurchaseOrders --prefix 16041
```

### Files
- `recipe.json` — type, 4-CSV member list, 2 discovery steps, 9-arg
  ParameterList, `downstream_jobs` (ImportSPOJob as calvin.roth), verify block.
- `artifact/Po*InterfaceOrder.csv` — the four templated CSVs (`${PREFIX}` +
  discovered `${TOKEN}`s).
- `build_templates.py` — regenerates the four CSV templates.
- `PurchaseOrders_gold.zip` — last assembled ready-to-load artifact.
