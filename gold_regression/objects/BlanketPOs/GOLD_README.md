# BlanketPOs — Gold Regression Fixture (Import Blanket Agreements / ImportBPAJob)

**Status: ✅ LIVE-PROVEN both directions** on the Fusion demo instance
(`fa-esew-dev28`), 2026-07-19.

Two good blanket purchase agreements reach the base table `PO_HEADERS_ALL`
(`TYPE_LOOKUP_CODE = BLANKET`, `DOCUMENT_STATUS = OPEN`); one bad row lands in
`PO_HEADERS_INTERFACE` with a real `PO_INTERFACE_ERRORS` message ("The supplier
site isn't valid…") and never reaches the base table.

This fixture is built and loaded **outside** the DMT pipeline (no DMT database,
no DMT PL/SQL). It assembles the four Blanket FBDI CSVs, calls the Fusion ERP
Integration SOAP service directly, submits the Import Blanket Agreements program,
and verifies with read-only single-table BIP reads.

Blanket agreements share the PO interface tables with standard orders but use a
SEPARATE FBDI template (`POBlanketPurchaseAgreementImportTemplate.xlsm`), a
different UCM account, and a different ESS job (`ImportBPAJob`, not
`ImportSPOJob`). Do not confuse this with `objects/PurchaseOrders/` — that is
standard orders.

---

## Object shape

One object = one FBDI zip = one load job. The BlanketPOs zip carries **four
position-based CSVs** (no header row, each ending in an `END` sentinel column),
in this order inside the zip:

| Member (archive name)                   | Columns | Interface table                |
|-----------------------------------------|--------:|--------------------------------|
| `PoHeadersInterfaceBlanket.csv`         |     122 | `PO_HEADERS_INTERFACE`         |
| `PoLinesInterfaceBlanket.csv`           |     108 | `PO_LINES_INTERFACE`           |
| `PoLineLocationsInterfaceBlanket.csv`   |      62 | `PO_LINE_LOCATIONS_INTERFACE`  |
| `PoGAOrgAssignInterfaceBlanket.csv`     |      10 | `PO_GA_ORG_ASSIGN_INTERFACE`   |

Column order/counts are byte-mirrored from Oracle's own BPA import template (the
canonical `objects/BlanketPOs/PoImportBlanketAgreements.zip`) and cross-checked
against the proven DMT Blanket generator
(`db/packages/dmt_blanket_po_fbdi_gen_pkg.pkb.sql`). Every field is
double-quoted; the last column of every member is the required `"END"` sentinel.
The templates live in `artifact/`; regenerate them with
`python objects/BlanketPOs/build_templates.py`.

**What makes it a BLANKET, not a STANDARD order** — two header fields:

- position 7 `DOCUMENT_TYPE_CODE = BLANKET`
- position 8 `STYLE = "Blanket Purchase Agreement"`

The GA Org Assign CSV assigns the agreement to a requisitioning / bill-to BU and
sets `Enabled = Y`, which is what leaves the created agreement usable and in
`DOCUMENT_STATUS = OPEN`.

### Rows in the fixture (3 headers, 3 lines, 3 price-break locations, 3 BU assignments)

| Suffix | Header key / agreement number | Meaning | Expected outcome |
|--------|-------------------------------|---------|------------------|
| `G1`   | `${PREFIX}RT-BPA-G1`          | good    | `PO_HEADERS_ALL` (BLANKET) |
| `G2`   | `${PREFIX}RT-BPA-G2`          | good    | `PO_HEADERS_ALL` (BLANKET) |
| `BAD1` | `${PREFIX}RT-BPA-BAD1`        | bad — invalid supplier site `ZZINVALIDSITE` | rejected into `PO_INTERFACE_ERRORS`, absent from base |

Each good agreement is one BLANKET header, one Goods line (description-based, no
item master needed) with a category and a unit price, one price-break location,
and one BU assignment that enables it.

---

## Portability — every reference is discovered at load time (no hardcoded ids)

Nothing points at data we loaded earlier. At load time the harness runs two
read-only BIP discovery queries against the target pod and stamps the results
into the templates alongside `${PREFIX}`. Both queries pick a **real,
successfully-created STANDARD PO** on the pod and borrow its references (a
blanket agreement needs the same references a standard order does).

Discovery step `BPA_TEMPLATE` (one real PO header) yields:

| Token                 | Meaning                         | Value on esew-dev28 |
|-----------------------|---------------------------------|---------------------|
| `${PRC_BU_NAME}`      | Procurement / Requisitioning BU | `US1 Business Unit` |
| `${BU_ID}`            | BU id (ParameterList args 1,8)  | `300000046987012`   |
| `${AGENT_ID}`         | buyer person id (arg 2)         | `300000047340498`   |
| `${AGENT_NAME}`       | buyer name (header pos 10)      | `Roth, Calvin`      |
| `${AGENT_EMAIL}`      | buyer email (header pos 98)     | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` |
| `${VENDOR_NAME}`      | supplier (header pos 13)        | `Lee Supplies`      |
| `${VENDOR_NUM}`       | supplier number (pos 14)        | `1252`              |
| `${VENDOR_SITE_CODE}` | supplier site (pos 15, good)    | `Lee US1`           |
| `${CURRENCY_CODE}`    | currency (pos 11)               | `USD`               |

Discovery step `BPA_LINE_REF` (one real Goods line of a US1 PO) yields:

| Token              | Meaning             | Value on esew-dev28 |
|--------------------|---------------------|---------------------|
| `${LINE_TYPE}`     | purchasing line type| `Goods`             |
| `${CATEGORY_NAME}` | purchasing category | `Computer Supplies` |

`UOM = Each` is a stock unit of measure. The bad row differs from the good rows
in exactly one field: `VENDOR_SITE_CODE = ZZINVALIDSITE`.

---

## Full ESS orchestration (in order)

The blanket-agreement import is **two ESS steps under two different users**, the
same two-user split proven on standard PurchaseOrders: fin_impl can load the
FBDI to the interface tables but cannot submit the import program; the
procurement functional user calvin.roth submits Import Blanket Agreements.

### Step 1 — Load FBDI to interface tables (auth: **fin_impl**)

`loadAndImportData` on the ERP Integration SOAP service
(`…/fscmService/ErpIntegrationService`). It base64-embeds the zip, uploads it to
UCM under the document account, then runs the interface loaders (SqlLoader) into
the four `PO_*_INTERFACE` tables.

- **DocumentAccount:** `prc/blanketPurchaseAgreement/import`
  (NOT `prc/purchaseOrder/import` — that is standard orders)
- **JobName (jobList):** `/oracle/apps/ess/prc/po/pdoi,ImportBPAJob`
- **interfaceDetails:** `23` (the BPA `ERP_INTERFACE_OPTIONS_ID`; standard PO is 21)
- **ParameterList (jobList):** the 8-arg list below.

Returns the **load request id**. Poll `getESSJobStatus` to a terminal state
(SUCCEEDED). All three headers now sit in `PO_HEADERS_INTERFACE`.

> **Why calvin.roth is not used for Step 1:** calvin.roth returns HTTP 401 on the
> loadAndImportData SOAP call (it lacks the integration-service privilege), so the
> load runs as fin_impl — identical to standard PurchaseOrders.

### Step 2 — Import Blanket Agreements (auth: **calvin.roth**)

`submitESSJobRequest` for `/oracle/apps/ess/prc/po/pdoi,ImportBPAJob` submitted
by **calvin.roth**. fin_impl cannot submit this job (`FUN-720397`); calvin.roth
can. The job reads the interface rows for the batch and creates the agreements.
Poll `getESSJobStatus` to terminal (SUCCEEDED).

Cross-user pickup works: the interface rows are created_by FIN_IMPL, but
ImportBPAJob submitted by calvin.roth still processes them because the job is
scoped by the Procurement BU (ParameterList arg 1) and the batch, not by owner.

In the harness this is declared as a `downstream_jobs` entry on the recipe with
its own `cred_role: calvin.roth`; `harness/load_fbdi.py` submits and polls the
downstream job with that role's credentials.

### The 8-argument ParameterList (comma-delimited), spelled out

`${BU_ID},${AGENT_ID},N,SUBMIT,${PREFIX},RT${PREFIX},N,${BU_ID}_${PREFIX}`

| # | Argument                | Value (this fixture) |
|---|-------------------------|----------------------|
| 1 | Procurement BU id       | `${BU_ID}` (e.g. `300000046987012`) |
| 2 | Default Buyer person id | `${AGENT_ID}` (e.g. `300000047340498`) |
| 3 | Create or Update Item   | `N` |
| 4 | Approval Action         | `SUBMIT` (also DO_NOT_APPROVE, BYPASS) |
| 5 | Batch ID (pass-through) | `${PREFIX}` (e.g. `55501`) |
| 6 | Import Source           | `RT${PREFIX}` (e.g. `RT55501`) |
| 7 | Communicate Agreements  | `N` |
| 8 | Group tag `{BU_ID}_{BatchID}` | `${BU_ID}_${PREFIX}` (e.g. `300000046987012_55501`) |

**Different from ImportSPOJob (9 args):** ImportBPAJob has **8** args, has no
"Default Requisitioning BU", and arg 3 is *Create or Update Item* (not Approval
Action). Confirmed from Fusion UI (request 9419765) and re-proven live here.

> **BATCH_ID gotcha (carried from PurchaseOrders):** `PO_HEADERS_INTERFACE.BATCH_ID`
> is a **NUMBER** column, so header position 3 must be numeric — the fixture uses
> `${PREFIX}`. The free-text ParameterList arg-8 group tag is separate; putting the
> text tag into the numeric column throws `ORA-01722` and SqlLoader rejects every
> header row before the interface tables are populated.

### No further downstream program

Once ImportBPAJob reaches SUCCEEDED the good agreements are in `PO_HEADERS_ALL`
with `DOCUMENT_STATUS = OPEN`. There is no separate accounting/validation program
to wait on before verifying. Reaching the base table is the pass bar.

---

## Verification (read-only, direct single-table reads)

### Good → base table (by prefix on the agreement number, BLANKET only)
```sql
SELECT segment1, po_header_id, type_lookup_code, document_status
FROM   po_headers_all
WHERE  segment1 LIKE :PREFIX || 'RT-BPA-%'
AND    type_lookup_code = 'BLANKET';
```
Two rows with real `po_header_id`s == pass.

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
The bad row (`…RT-BPA-BAD1`) carries
`VENDOR_SITE_CODE=ZZINVALIDSITE: The supplier site isn't valid…` and does **not**
appear in `PO_HEADERS_ALL`. `PO_INTERFACE_ERRORS` is keyed by
`INTERFACE_HEADER_ID` (join to `PO_HEADERS_INTERFACE` by that id, then to the
load by `LOAD_REQUEST_ID`).

---

## Last live-proven evidence

- **Date:** 2026-07-19 · **Pod:** fa-esew-dev28 · **Prefix:** `55501`
- **Load request (fin_impl, loadAndImportData):** `9763721` → SUCCEEDED
- **Import Blanket Agreements request (calvin.roth, ImportBPAJob):** `9763741` → SUCCEEDED
- **Good → base `PO_HEADERS_ALL` (TYPE_LOOKUP_CODE = BLANKET):**
  - `55501RT-BPA-G1` → `po_header_id = 674951` (DOCUMENT_STATUS OPEN)
  - `55501RT-BPA-G2` → `po_header_id = 674952` (DOCUMENT_STATUS OPEN)
- **Bad → `PO_INTERFACE_ERRORS`:** `55501RT-BPA-BAD1`,
  `VENDOR_SITE_CODE = ZZINVALIDSITE — "The supplier site isn't valid. Verify that
  the site is active, has the purchasing purpose assigned, is associated with the
  procurement business unit, and has an active assignment for the requisitioning
  business unit."` — absent from `PO_HEADERS_ALL`.
- **Verdict:** PASS (both directions), first live run.

### Reproduce
```
python harness/run_object.py BlanketPOs          # fresh random prefix
python harness/run_object.py BlanketPOs --prefix 55501
```

### Files
- `recipe.json` — type, 4-CSV member list, 2 discovery steps, 8-arg
  ParameterList, `downstream_jobs` (ImportBPAJob as calvin.roth), verify block.
- `artifact/Po*InterfaceBlanket.csv` — the four templated CSVs (`${PREFIX}` +
  discovered `${TOKEN}`s).
- `build_templates.py` — regenerates the four CSV templates.
- `BlanketPOs_gold.zip` — last assembled ready-to-load artifact.
