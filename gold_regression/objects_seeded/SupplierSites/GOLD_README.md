# SupplierSites — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/SupplierSites/`). Same two good
sites + one bad site, loaded via `loadAndImportData` (chained `ImportSupplierSites`)
with read-only BIP verification against the base and interface tables. The one
difference from v1: the parent supplier, its existing address (party site), and the
procurement business unit are **hard-coded to standard seeded values**, not discovered
at load time.

A supplier **site** is not a top-level record. It attaches to an existing supplier, an
existing supplier address (a party site on that supplier), and a procurement business
unit. This fixture creates NEW sites (fresh site codes stamped with `${PREFIX}`) and
borrows those three references from seeded demo data.

## The hard-coded seed (what v1 discovered → now literals)

v1 discovery resolved to `ABC Bank` / `ABC Bank US1` / `US1 Business Unit`. This v2
fixture instead hard-codes **`Staffing Services`**, the same seeded supplier the
SupplierAddresses v2 fixture uses, so the whole supplier family points at one stable,
unlocked seeded supplier. Confirmed live (read-only BIP) that this supplier is seeded
(no prefix), unlocked, and already owns a usable party site under the procurement BU:

| Reference | Literal value | Id (documentary) |
|---|---|---|
| Supplier (unlocked) | `Staffing Services` (segment1 `1253`, `SUPPLIER_LOCKED_FLAG = N`) | vendor_id `300000047414571` |
| Existing address (party site on that supplier) | `Staffing US1` | party_site_id `300000047414586` |
| Procurement BU | `US1 Business Unit` | bu_id `300000046987012` |

Why not the lowest-numbered supplier: `Lee Supplies` (1252) is **locked** on this pod, so
any site attached to it is rejected with "This supplier profile is locked for editing."
`Staffing Services` (1253) is unlocked and has an existing address, so its new sites load.

- Template `artifact/PozSupplierSitesInt.csv`: column 2 `SUPPLIER_NAME` = `Staffing Services`,
  column 3 `PROCUREMENT_BU` = `US1 Business Unit`, column 4 `PARTY_SITE_NAME` = `Staffing US1`
  on the two good rows.
- `recipe.json` base read is scoped to `vendor_id = 300000047414571` (Staffing Services),
  and the discovery block is removed.
- `${PREFIX}` stays on the three new-record keys (`${PREFIX}RT-SITE-G1/G2/BAD`) and on the
  bad row's `${PREFIX}NO SUCH SUPPLIER` supplier name.

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService`, operation `loadAndImportData` |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json) |
| UCM DocumentAccount | `prc/supplier/import` |
| `interfaceDetails` | `25` |
| `JobName` | `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSites` (last `;` → `,`) |
| `ParameterList` | `NEW,N` |

One CSV inside the zip: `PozSupplierSitesInt.csv` (no header row; position-based, 199
columns per the CTL). Three rows, all `IMPORT_ACTION=CREATE`. The returned Load ESS
request id is stamped on every `POZ_SUPPLIER_SITES_INT` row (including rejects), so it is
the interface/rejection selection key.

## Bad row

BAD-1 (`${PREFIX}RT-SITE-BAD`) names a supplier that does not exist
(`${PREFIX}NO SUCH SUPPLIER`), so it is deterministically rejected on an invalid supplier
reference. It lands in `POZ_SUPPLIER_SITES_INT` with a rejection in
`POZ_SUPPLIER_INT_REJECTIONS`, and never reaches `POZ_SUPPLIER_SITES_ALL_M`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database, no DMT code in the load path); verification
via the read-only BIP relay only.

| Field | Value |
|---|---|
| Prefix | `27224` |
| Hard-coded supplier / address / BU | `Staffing Services` / `Staffing US1` / `US1 Business Unit` (vendor_id 300000047414571) |
| Load ESS request id | `9766159` |
| Terminal status | `SUCCEEDED` (terminal at 60s) |
| Credential role | `fin_impl` |

**Good sites → base table `POZ_SUPPLIER_SITES_ALL_M` (2/2):**

| VENDOR_SITE_CODE | VENDOR_SITE_ID | VENDOR_ID |
|---|---|---|
| `27224RT-SITE-G1` | `300000331568020` | `300000047414571` |
| `27224RT-SITE-G2` | `300000331568027` | `300000047414571` |

**Bad site → interface rejection, absent from base (1/1):**

| VENDOR_SITE_CODE | Rejection error |
|---|---|
| `27224RT-SITE-BAD` | `You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]; A value is required. You must provide a value. [VENDOR_ID]` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py SupplierSites
```
