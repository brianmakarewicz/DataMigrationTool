# Items — Gold Regression Fixture (v2 seeded, LIVE-PROVEN)

Import Items / EGP item import via FBDI. **This is an SCM object — the SOAP load AND the
read-only BIP verify both use the `scm_impl` credential** (Financials `fin_impl` cannot see
SCM item tables and cannot submit the SCM item-import job).

This is the **v2 seeded** version of `../../objects/Items/` (v1, FROZEN). It is identical
except that v1's load-time discovery of the four item-master references has been replaced
with the literal seeded values those queries resolved to. There is no discovery block and
nothing is computed at run time.

Standalone load path only: the harness assembles the FBDI zip and calls the Fusion ERP
Integration SOAP service directly. No DMT database, no DMT pipeline PL/SQL is in the load
path. Verification is the read-only BIP ephemeral-relay only (direct single-table reads).

## The seeded references (v1 discovery replaced by literals)

v1 discovered four references at load time; all four are standard seeded demo data that
ships in every pod and that we did **not** load ourselves (none carries a prefix). Confirmed
present unprefixed on this pod via a read-only `scm_impl` BIP read before conversion:

| CSV pos | Column | Seeded literal | What it is |
|---|---|---|---|
| 6 | ORGANIZATION_CODE | `000` | The seeded item master organization |
| 13 | PRIMARY_UOM_NAME | `Each` | Standard "Each" UOM — **display name, not the code `ECH`** (see lesson below) |
| 15 | INVENTORY_ITEM_STATUS_CODE | `Active` | Standard shipped item status |
| 16 | NEW_ITEM_CLASS_NAME | `Root Item Class` | Universal root of the item-class hierarchy, on every pod |

Only `${PREFIX}` remains a placeholder — stamped fresh onto the item numbers (positions 4
and 10) and the batch id (position 2) so re-runs never collide. The bad row's org
`ZZ_NO_SUCH_ORG` is a deliberate literal defect, not a token.

## Last live-proven evidence (v2 seeded)

- **Date:** 2026-07-20
- **Result:** PASS (both directions)
- **Prefix:** `99133`
- **Load ESS request id (loadAndImportData):** `9766262` (terminal SUCCEEDED)
- **Good rows → base `EGP_SYSTEM_ITEMS_B` (org 000):**
  - `99133RT-ITEM-G1` → INVENTORY_ITEM_ID `100002547695816`
  - `99133RT-ITEM-G2` → INVENTORY_ITEM_ID `100002547695817`
- **Bad row `99133RT-ITEM-BAD1` (invalid org `ZZ_NO_SUCH_ORG`):** rejected by Item Import
  ("You must provide a valid value for the attribute organization", PROCESS_STATUS=3 in the
  interface before purge), never created in `EGP_SYSTEM_ITEMS_B` — proven ABSENT from base.

The SCM base replica lags ~2 min on this pod, so the good-row base read was empty on the
first pass immediately after load and returned both ids on a re-verify ~2.5 min later.

## The object

One object = one FBDI zip = one ESS load job. Items ships a **single CSV**,
`EgpSystemItemsInterface.csv` (interface table `EGP_SYSTEM_ITEMS_INTERFACE`, **399
positional columns, no header row**). Item Categories are NOT required for a plain item
create, so this gold fixture carries only the items CSV.

## Exact web-service call

- **Endpoint:** `{fusion_url}/fscmService/ErpIntegrationService`
- **Operation:** `loadAndImportData` (uploads the zip to UCM, runs "Load File to Interface
  Tables", then chains the import job named in `<JobName>`).
- **Auth user:** `scm_impl` (HTTP Basic).
- **DocumentAccount (UCM):** `scm/item/import`
- **JobName (comma form):** `/oracle/apps/ess/scm/productModel/items,ItemImportJobDef`
- **interfaceDetails:** `29`.

### Full ParameterList (7 positional args, comma-separated)

```
${PREFIX},null,CREATE,Y,ORA_COMP,N,Y
```

| # | Argument | Value | Meaning |
|---|----------|-------|---------|
| 1 | Batch ID | `${PREFIX}` | Item-import batch id. Must equal the BATCH_ID in column 2 of every CSV row. |
| 2 | Organization | `null` (literal) | Process-all-orgs mode. |
| 3 | Process Only | `CREATE` | Create new items. |
| 4 | Process All Organizations | `Y` | Process every org referenced in the file. |
| 5 | Delete Processed Rows | `ORA_COMP` | Delete only completed (successful) rows — never `ORA_ER`, which would purge the bad row before we read it. |
| 6 | Reprocess Error | `N` | Do not reprocess prior errors. |
| 7 | Process Sequentially | `Y` | Process the batch sequentially. |

## CRITICAL data-quality lesson: PRIMARY_UOM_NAME wants the UOM *name*, not the code

Interface column 13 is `PRIMARY_UOM_NAME`. Passing the UOM **code** (`ECH`) fails with
`PRIMARY_UOM_NAME - The value of the attribute Primary Unit of Measure isn't valid.` The
column expects the UOM **display name** (`Each`), which is why the seeded literal here is
`Each`, not `ECH`.

## Verification (read-only BIP, direct single-table reads)

**Good → base table** (run as `scm_impl`; allow ~2 min for the base replica):

```sql
SELECT b.ITEM_NUMBER, b.INVENTORY_ITEM_ID, p.ORGANIZATION_CODE
FROM   EGP_SYSTEM_ITEMS_B b
JOIN   INV_ORG_PARAMETERS p ON p.ORGANIZATION_ID = b.ORGANIZATION_ID
WHERE  b.ITEM_NUMBER LIKE '<prefix>' || 'RT-ITEM-%'
```

Two rows with real `INVENTORY_ITEM_ID`s == good pass.

**Bad → interface error / absent from base.** Item Import purges the errored interface row
after the batch completes, so the authoritative, durable BAD proof is **ABSENCE from base**
(`bad_proof_is_absence: true`) while the two good rows from the SAME load reached base with
real ids.

## Files

- `recipe.json` — self-contained recipe, **no discovery block**; seeds are literals in the CSV.
- `artifact/EgpSystemItemsInterface.csv` — the templated 399-column CSV (2 good + 1 bad).
  Only `${PREFIX}` is a placeholder; the four references are seeded literals.
- `Items_gold.zip` — last assembled artifact (frozen at prefix 99133).

## Re-run

```
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Items
```

`run_object.py` verifies immediately after load; because the base replica lags ~2 min, the
good-row base read can show 0 on that first pass. Re-run
`GOLD_OBJECTS_SUBDIR=objects_seeded python verify.py Items <load_request_id> <prefix>` a
couple of minutes later to see both good ids in base.
