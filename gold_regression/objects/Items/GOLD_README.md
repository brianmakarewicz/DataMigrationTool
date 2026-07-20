# Items — Gold Regression Fixture (LIVE-PROVEN)

Import Items / EGP item import via FBDI. **This is an SCM object — the SOAP load AND the
read-only BIP verify both use the `scm_impl` credential** (Financials `fin_impl` cannot see
SCM item tables and cannot submit the SCM item-import job).

Standalone load path only: the harness assembles the FBDI zip and calls the Fusion ERP
Integration SOAP service directly. No DMT database, no DMT pipeline PL/SQL is in the load
path. Verification is the read-only BIP ephemeral-relay only (direct single-table reads).

## Last live-proven evidence

- **Date:** 2026-07-19
- **Result:** PASS (both directions)
- **Prefix:** `69160`
- **Load ESS request id (loadAndImportData):** `9763999`
- **Chained Item Import child request:** `9764006` (ItemImportJobDef)
- **Good rows → base `EGP_SYSTEM_ITEMS_B` (org 000):**
  - `69160RT-ITEM-G1` → INVENTORY_ITEM_ID `100002547248242`
  - `69160RT-ITEM-G2` → INVENTORY_ITEM_ID `100002547248243`
- **Bad row `69160RT-ITEM-BAD1` (invalid org):** rejected by Item Import
  ("You must provide a valid value for the attribute organization"), never created in
  `EGP_SYSTEM_ITEMS_B` — proven ABSENT from base.
- Earlier proving runs the same day: prefix `10455` (load `9763934`, good ids
  `100002547355608/609`); prefix `90843` (load `9763853`, good ids
  `100002547355563/564`). All three reached base with the fix below.

## The object

One object = one FBDI zip = one ESS load job. Items ships a **single CSV**,
`EgpSystemItemsInterface.csv` (interface table `EGP_SYSTEM_ITEMS_INTERFACE`, **399
positional columns, no header row**). Item Categories are NOT required for a plain item
create, so this gold fixture carries only the items CSV. `EgpItemCategoriesInterface.csv`
would be added to the same zip only if a category assignment were being tested.

## Exact web-service call

- **Endpoint:** `{fusion_url}/fscmService/ErpIntegrationService`
- **Operation:** `loadAndImportData` (uploads the zip to UCM, runs "Load File to Interface
  Tables", then chains the import job named in `<JobName>`).
- **Auth user:** `scm_impl` (HTTP Basic).
- **DocumentAccount (UCM):** `scm/item/import`
- **JobName (comma form):** `/oracle/apps/ess/scm/productModel/items,ItemImportJobDef`
  (raw semicolon form: `/oracle/apps/ess/scm/productModel/items;ItemImportJobDef`)
- **interfaceDetails:** `29` (the Items interface-details id from the DMT2 ERP interface
  options seed row for business object `item`, UCM account `scm/item/import`).

### Full ParameterList (7 positional args, comma-separated)

```
${PREFIX},null,CREATE,Y,ORA_COMP,N,Y
```

| # | Argument | Value used | Meaning |
|---|----------|------------|---------|
| 1 | Batch ID | `${PREFIX}` (numeric) | Item-import batch id. **Must equal the BATCH_ID stamped in column 2 of every CSV row.** |
| 2 | Organization | `null` (literal string) | Process-all-orgs mode, so no single org is named. |
| 3 | Process Only | `CREATE` | Create new items (not SYNC/UPDATE). |
| 4 | Process All Organizations | `Y` | Process every org referenced in the file. |
| 5 | Delete Processed Rows | `ORA_COMP` | Delete only *completed* (successful) rows. **Deliberately not `ORA_ER`** — `ORA_ER` deletes error rows and would purge the bad row before we can read it. Even with `ORA_COMP`, Item Import purges the errored row once the batch fully completes, so bad-row proof is by absence from base (see below). |
| 6 | Reprocess Error | `N` | Do not reprocess prior errors. |
| 7 | Process Sequentially | `Y` | Process the batch sequentially. |

### Downstream jobs

None to submit. `loadAndImportData` chains `ItemImportJobDef` itself; that job internally
submits its own async children (file transfer, item batch import, Manufacturer index
rebuild, Item Search Keyword, Elastic Search ingest). We only poll the top-level load
request to a terminal status, then wait for the base-table replica to refresh (~2 min on
this pod) before verifying.

## Portability — discovery at load time (no upstream dependency)

An item needs an existing item master organization, an item class, a valid item status,
and a valid primary UOM. **None of these are hardcoded and none reference our own earlier
loads.** One read-only BIP query (`scm_impl`) discovers all four on the TARGET pod:

```sql
SELECT p.ORGANIZATION_CODE AS ORG,
       (SELECT MIN(ic.ITEM_CLASS_NAME) FROM EGP_ITEM_CLASSES_VL ic
         WHERE ic.ITEM_CLASS_NAME = 'Root Item Class') AS ICLASS,
       (SELECT b.INVENTORY_ITEM_STATUS_CODE
          FROM EGP_SYSTEM_ITEMS_B b
          JOIN INV_ORG_PARAMETERS p2 ON p2.ORGANIZATION_ID = b.ORGANIZATION_ID
         WHERE p2.ORGANIZATION_CODE = p.ORGANIZATION_CODE
           AND b.INVENTORY_ITEM_STATUS_CODE = 'Active' AND ROWNUM = 1) AS STATUS,
       (SELECT u.UNIT_OF_MEASURE FROM INV_UNITS_OF_MEASURE_VL u
         WHERE u.UOM_CODE = 'ECH') AS UOM
FROM   INV_ORG_PARAMETERS p
WHERE  p.MASTER_ORGANIZATION_ID = p.ORGANIZATION_ID
AND    p.ORGANIZATION_CODE = '000'
```

On the demo pod this returns `ORG='000'`, `ICLASS='Root Item Class'`, `STATUS='Active'`,
`UOM='Each'`. These are stamped into the CSV as `${ORG}`, `${ICLASS}`, `${STATUS}`,
`${UOM}`. `Root Item Class` is the universal root of the item-class hierarchy and exists on
every pod; `000` is the seeded item master organization; `Active` is a standard shipped
status; `ECH`/`Each` is the standard "Each" UOM. The good/bad item numbers are stamped
fresh with `${PREFIX}` so re-runs never collide.

### CRITICAL data-quality lesson: PRIMARY_UOM_NAME wants the UOM *name*, not the code

Interface column 13 is `PRIMARY_UOM_NAME`. Passing the UOM **code** (`ECH`) fails with
`PRIMARY_UOM_NAME - The value of the attribute Primary Unit of Measure isn't valid.` The
column expects the UOM **display name** (`Each`). The discovery query therefore selects
`UNIT_OF_MEASURE` (name), not `UOM_CODE`. This single fix moved the good rows from
rejected to reaching base.

## The CSV rows (positional, 399 columns)

Populated positions (1-based), from the DMT2 FBDI generator column map:

| Pos | Column | Good rows | Bad row |
|-----|--------|-----------|---------|
| 1 | TRANSACTION_TYPE | `CREATE` | `CREATE` |
| 2 | BATCH_ID | `${PREFIX}` | `${PREFIX}` |
| 4 | ITEM_NUMBER | `${PREFIX}RT-ITEM-G1` / `-G2` | `${PREFIX}RT-ITEM-BAD1` |
| 6 | ORGANIZATION_CODE | `${ORG}` (=`000`) | `ZZ_NO_SUCH_ORG` ← the defect |
| 7 | DESCRIPTION | "DMT Gold regression item G1/G2" | "DMT Gold regression BAD item (invalid org)" |
| 9 | SOURCE_SYSTEM_CODE | `DMT` | `DMT` |
| 10 | SOURCE_SYSTEM_REFERENCE | `${PREFIX}RT-ITEM-G1` / `-G2` | `${PREFIX}RT-ITEM-BAD1` |
| 13 | PRIMARY_UOM_NAME | `${UOM}` (=`Each`) | `${UOM}` |
| 15 | INVENTORY_ITEM_STATUS_CODE | `${STATUS}` (=`Active`) | `${STATUS}` |
| 16 | NEW_ITEM_CLASS_NAME | `${ICLASS}` (=`Root Item Class`) | `${ICLASS}` |

All other 389 positions are empty (`TRAILING NULLCOLS` in the control file).

The **bad row's** only defect is an invalid `ORGANIZATION_CODE`. Item Import loads it to the
interface, then the item-import validation rejects it with a deterministic Fusion error and
never creates it in the base table.

## Verification (read-only BIP, direct single-table reads)

**Good → base table** (run as `scm_impl`; allow ~2 min for the base replica to refresh):

```sql
SELECT b.ITEM_NUMBER, b.INVENTORY_ITEM_ID, p.ORGANIZATION_CODE
FROM   EGP_SYSTEM_ITEMS_B b
JOIN   INV_ORG_PARAMETERS p ON p.ORGANIZATION_ID = b.ORGANIZATION_ID
WHERE  b.ITEM_NUMBER LIKE '<prefix>' || 'RT-ITEM-%'
```

Two rows with real `INVENTORY_ITEM_ID`s == good pass.

**Bad → interface error / absent from base.** Immediately after load the bad row is present
in `EGP_SYSTEM_ITEMS_INTERFACE` with `PROCESS_STATUS = 3` for `LOAD_REQUEST_ID = <load id>`.
Its error text is echoed in the `ItemImportJobDef` ESS report (download via
`downloadESSJobExecutionDetails`, fileType `LOG` — the log is a ZIP whose member is the
`.log` file):

```
<prefix>RT-ITEM-BAD1(ZZ_NO_SUCH_ORG) :
    <prefix>RT-ITEM-BAD1, ORGANIZATION_ID - You must provide a valid value for the attribute organization.
```

Item Import **purges the errored interface row after the batch completes**, so the
authoritative, durable BAD proof is **ABSENCE from base** (`EGP_SYSTEM_ITEMS_B` returns
zero rows for the bad key) while the two good rows from the SAME load reached base with real
ids. The recipe declares `"bad_proof_is_absence": true` with a `"bad_absence_note"`
documenting the captured error. (This is the same pattern used by objects whose import
purges its interface table.)

## Files

- `recipe.json` — the full self-contained recipe (type, creds, job, ParameterList,
  discovery query, good/bad rows, verify blocks).
- `artifact/EgpSystemItemsInterface.csv` — the templated 399-column CSV (2 good + 1 bad,
  `${PREFIX}` and discovered `${TOKEN}` placeholders).
- `Items_gold.zip` — the last assembled ready-to-load artifact (frozen at prefix 69160).

## Re-run

```
cd gold_regression/harness
python run_object.py Items            # fresh random prefix, full discover→build→load→verify
```

`run_object.py` verifies immediately after the load returns; because the base replica lags
~2 min on this pod, the good-row base read can show 0 on that first pass. Re-run
`python verify.py Items <load_request_id> <prefix>` a couple of minutes later to see the
green result (both good ids in base). Base table is the pass bar; poll patiently.
