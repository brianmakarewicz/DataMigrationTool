# Contracts — Gold Regression Fixture (Import Contract Agreements / ImportCPAJob)

**Status: ✅ LIVE-PROVEN both directions** on the Fusion demo instance
(`fa-esew-dev28`), 2026-07-19.

Two good Contract Purchase Agreements reach the base table `PO_HEADERS_ALL`
with `TYPE_LOOKUP_CODE = CONTRACT`; one bad row lands in `PO_HEADERS_INTERFACE`
with a real `PO_INTERFACE_ERRORS` message ("The supplier site isn't valid…") and
never reaches the base table.

This fixture is built and loaded **outside** the DMT pipeline (no DMT database,
no DMT PL/SQL). It assembles the single Contract-agreement FBDI CSV, calls the
Fusion ERP Integration SOAP service directly, submits Import Contract Agreements
(ImportCPAJob), and verifies with read-only single-table BIP reads.

---

## Object shape

One object = one FBDI zip = one load job. A Contract Purchase Agreement (CPA) is
a **headers-only** procurement agreement — there are no lines/locations/
distributions. The zip carries **one position-based CSV** (no header row):

| Member (archive name)             | Columns          | Interface table         |
|-----------------------------------|-----------------:|-------------------------|
| `PoHeadersInterfaceContract.csv`  | 105 + `END`      | `PO_HEADERS_INTERFACE`  |

Column order/counts are byte-mirrored from the proven DMT contract FBDI generator
(`db/packages/dmt_contract_fbdi_gen_pkg.pkb.sql`, `gen_headers_csv`), which follows
Oracle's `POContractPurchaseAgreementImportTemplate.xlsm`. Every field is
double-quoted; **each data row ends with a literal, unquoted `END` field** after
column 105 (the FBDI CTL requires it — confirmed by the proven Blanket PO zip,
which shares `PO_HEADERS_INTERFACE` and the same trailing `END`). Regenerate the
template with `python objects/Contracts/build_templates.py`.

### Rows in the fixture (3 agreement headers)

| Suffix | Agreement number / key | Meaning | Expected outcome |
|--------|------------------------|---------|------------------|
| `G1`   | `${PREFIX}RT-CPA-G1`   | good    | `PO_HEADERS_ALL` (`TYPE_LOOKUP_CODE=CONTRACT`) |
| `G2`   | `${PREFIX}RT-CPA-G2`   | good    | `PO_HEADERS_ALL` (`TYPE_LOOKUP_CODE=CONTRACT`) |
| `BAD1` | `${PREFIX}RT-CPA-BAD1` | bad — invalid supplier site `ZZINVALIDSITE` | rejected into `PO_INTERFACE_ERRORS`, absent from base |

Each good agreement is one Contract Purchase Agreement between the procurement BU
and a real, active, purchasing-enabled supplier site. The bad row differs from
the good rows in exactly one field: `VENDOR_SITE_CODE = ZZINVALIDSITE`.

### How this differs from PurchaseOrders / BlanketPOs

- **Headers only** — no lines CSV (a Standard PO has 4 CSVs; a Blanket PO has 2;
  a Contract agreement has 1).
- `DOCUMENT_TYPE_CODE = CONTRACT` (a Blanket PO is `BLANKET`, a Standard PO is `STANDARD`).
- `STYLE = Contract Purchase Agreement`.
- Imported by **ImportCPAJob** (7-arg ParameterList) under UCM account
  `prc/contractPurchaseAgreement/import` (not `ImportSPOJob` / `prc/purchaseOrder/import`).

---

## Portability — every reference is discovered at load time (no hardcoded ids)

Nothing points at data we loaded earlier. At load time the harness runs one
read-only BIP discovery query against the target pod and stamps the results into
the template alongside `${PREFIX}`. The query picks a **real, successfully-created
STANDARD PO** on the pod and borrows its procurement BU, buyer, supplier, active
purchasing site, and currency — all of which a CPA needs and all of which already
ship in the pod.

Discovery step `CPA_TEMPLATE` yields:

| Token                 | Meaning                          | Value on esew-dev28 |
|-----------------------|----------------------------------|---------------------|
| `${PRC_BU_NAME}`      | Procurement BU                   | `US1 Business Unit` |
| `${BU_ID}`            | BU id (ParameterList args 1)     | `300000046987012`   |
| `${AGENT_ID}`         | buyer person id (arg 2)          | `300000047340498`   |
| `${AGENT_NAME}`       | buyer name (header)              | `Roth, Calvin`      |
| `${AGENT_EMAIL}`      | buyer email                      | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` |
| `${VENDOR_NAME}`      | supplier                         | `Lee Supplies`      |
| `${VENDOR_NUM}`       | supplier number                  | `1252`              |
| `${VENDOR_SITE_CODE}` | supplier site (good rows)        | `Lee US1`           |
| `${CURRENCY_CODE}`    | currency                         | `USD`               |

The discovery query requires the borrowed site to be a purchasing site
(`ss.purchasing_site_flag='Y'`) and active, and the BU to have a primary ledger,
so the borrowed references are valid for a new agreement on any pod.

---

## Full ESS orchestration (in order)

The contract-agreement import is **two ESS steps under two different users** —
the same two-user split proven on PurchaseOrders. fin_impl can load the FBDI to
`PO_HEADERS_INTERFACE` but cannot submit the import program; the procurement
functional user calvin.roth submits Import Contract Agreements.

### Step 1 — Load FBDI to interface table (auth: **fin_impl**)

`loadAndImportData` on the ERP Integration SOAP service
(`…/fscmService/ErpIntegrationService`). It base64-uploads the zip to UCM under
the document account, then runs the interface loader (SqlLoader) into
`PO_HEADERS_INTERFACE`.

- **DocumentAccount:** `prc/contractPurchaseAgreement/import`
- **JobName (jobList):** `/oracle/apps/ess/prc/po/pdoi,ImportCPAJob`
- **interfaceDetails:** `22` (the CPA `SOURCE_ERP_OPTIONS_ID`; the DMT loader passes
  `NVL(SOURCE_ERP_OPTIONS_ID, ERP_INTERFACE_OPTIONS_ID)`)
- **ParameterList (jobList):** the 7-arg list below.

Returns the **load request id**. Poll `getESSJobStatus` to terminal (SUCCEEDED).
All three agreement headers now sit in `PO_HEADERS_INTERFACE` (not yet imported).
loadAndImportData does not actually run ImportCPAJob under fin_impl (fin_impl lacks
the ESS job privilege — `FUN-720397`), so it runs only the loader and returns
SUCCEEDED; the real import is Step 2.

> **Why calvin.roth is not used for Step 1:** calvin.roth returns HTTP 401 on the
> loadAndImportData SOAP call (it lacks the integration-service privilege), so the
> load runs as fin_impl — identical to the PurchaseOrders learning.

### Step 2 — Import Contract Agreements (auth: **calvin.roth**)

`submitESSJobRequest` for `/oracle/apps/ess/prc/po/pdoi,ImportCPAJob` submitted by
**calvin.roth**. fin_impl cannot submit this job; calvin.roth can. The job reads
the interface rows for the batch and creates the agreements. Poll `getESSJobStatus`
to terminal (SUCCEEDED). Cross-user pickup works: the interface rows are created_by
FIN_IMPL, but ImportCPAJob submitted by calvin.roth still processes them because the
job is scoped by the Procurement BU (arg 1) and the batch, not by owner.

In the harness this is a `downstream_jobs` entry on the recipe with its own
`cred_role: calvin.roth`; `harness/load_fbdi.py` submits and polls it with that
role's creds.

### The 7-argument ParameterList (comma-delimited), spelled out

`${BU_ID},${AGENT_ID},SUBMIT,${PREFIX},RT${PREFIX},N,${BU_ID}_${PREFIX}`

| # | Argument            | Value (this fixture) |
|---|---------------------|----------------------|
| 1 | Procurement BU id   | `${BU_ID}` (e.g. `300000046987012`) |
| 2 | Default buyer id    | `${AGENT_ID}` (e.g. `300000047340498`) |
| 3 | Approval action     | `SUBMIT` (also: `DO_NOT_APPROVE`, `BYPASS`) |
| 4 | Batch ID            | `${PREFIX}` (pass-through text) |
| 5 | Import source       | `RT${PREFIX}` (pass-through text) |
| 6 | Communicate agreements | `N` |
| 7 | Group tag (free text)  | `${BU_ID}_${PREFIX}` (e.g. `300000046987012_70685`) |

The format mirrors the proven DMT loader (`dmt_loader_pkg.pkb`, Contracts grouped
block, line ~2263: `l_bu_id,l_buyer_id,'SUBMIT',,,N,l_bu_id_'||run_id`). Here args
4 and 5 carry the prefix/import-source rather than being empty; both are documented
pass-through text and do not affect the create.

> **BATCH_ID gotcha (carried from PO):** `PO_HEADERS_INTERFACE.BATCH_ID` is a
> **NUMBER** column, so the header CSV `BATCH_ID` field must be numeric — the
> fixture uses `${PREFIX}`. Arg 4 (a text batch label) and the numeric header
> BATCH_ID column are separate.

> **Trailing `END` gotcha (CPA-specific):** every CPA header data row must end with
> a literal, unquoted `END` field after column 105. Omitting it makes the SqlLoader
> reject the row. This is confirmed both by the DMT generator and the proven Blanket
> PO zip.

### No further downstream program

Once ImportCPAJob reaches SUCCEEDED the good agreements are in `PO_HEADERS_ALL`
(`DOCUMENT_STATUS = OPEN` — a functional-user SUBMIT open agreement). There is no
separate accounting/validation program to wait on before verifying. Reaching the
base table is the pass bar.

---

## Verification (read-only, direct single-table reads)

### Good → base table (by prefix on the agreement number, CONTRACT type)
```sql
SELECT segment1, po_header_id, type_lookup_code, document_status
FROM   po_headers_all
WHERE  segment1 LIKE :PREFIX || 'RT-CPA-%'
AND    type_lookup_code = 'CONTRACT';
```
Two rows with real `po_header_id`s and `TYPE_LOOKUP_CODE = CONTRACT` == pass.

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
The bad row (`…RT-CPA-BAD1`) carries
`VENDOR_SITE_CODE=ZZINVALIDSITE: The supplier site isn't valid…` and does **not**
appear in `PO_HEADERS_ALL`. `PO_INTERFACE_ERRORS` is keyed by `INTERFACE_HEADER_ID`
(join to `PO_HEADERS_INTERFACE` by that id, then to the load by `LOAD_REQUEST_ID`).

---

## Last live-proven evidence

- **Date:** 2026-07-19 · **Pod:** fa-esew-dev28 · **Prefix:** `70685`
- **Load request (fin_impl, loadAndImportData):** `9763717` → SUCCEEDED
- **Import Contract Agreements request (calvin.roth, ImportCPAJob):** `9763740` → SUCCEEDED
- **Good → base `PO_HEADERS_ALL` (`TYPE_LOOKUP_CODE=CONTRACT`):**
  - `70685RT-CPA-G1` → `po_header_id = 674953` (DOCUMENT_STATUS OPEN)
  - `70685RT-CPA-G2` → `po_header_id = 674954` (DOCUMENT_STATUS OPEN)
- **Bad → `PO_INTERFACE_ERRORS`:** `70685RT-CPA-BAD1`,
  `VENDOR_SITE_CODE = ZZINVALIDSITE — "The supplier site isn't valid. Verify that
  the site is active, has the purchasing purpose assigned, is associated with the
  procurement business unit, and has an active assignment for the requisitioning
  business unit."` — absent from `PO_HEADERS_ALL`.
- **Verdict:** PASS (both directions).

### Reproduce
```
python harness/run_object.py Contracts               # fresh random prefix
python harness/run_object.py Contracts --prefix 70685
```

### Files
- `recipe.json` — type, 1-CSV member list, 1 discovery step, 7-arg ParameterList,
  `downstream_jobs` (ImportCPAJob as calvin.roth), verify block.
- `artifact/PoHeadersInterfaceContract.csv` — the templated CSV (`${PREFIX}` +
  discovered `${TOKEN}`s, 105 cols + `END`).
- `build_templates.py` — regenerates the CSV template.
- `Contracts_gold.zip` — last assembled ready-to-load artifact.
