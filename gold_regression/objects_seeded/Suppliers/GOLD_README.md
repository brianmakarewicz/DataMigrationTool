# Suppliers — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/Suppliers/`). Same two good + one
bad supplier, loaded via `loadAndImportData` (which chains **Import Suppliers**) with
read-only BIP verification against the base and interface tables. No DMT tool code and no
DMT database are in the load path.

## The hard-coded seeds (what v1 discovered → now literals)

**None to convert.** Suppliers is a top-level object: it creates a brand-new supplier and
references nothing that has to be discovered. Its only reference fields are standard Fusion
enumeration values, already literal in the template:

| Field (CSV position) | Literal value | Meaning |
|---|---|---|
| Tax organization type (col 6) | `CORPORATION` | standard org-type lookup code |
| Supplier type (col 7) | `SUPPLIER` | standard supplier-type lookup code |
| Business relationship (col 9) | `SPEND_AUTHORIZED` | standard relationship lookup code |

These are seeded enumeration codes present on every demo pod, not records we loaded, so no
`${TOKEN}` discovery ever existed for this object. The v1 recipe (in
`harness/objects.json`) already had **no discovery block** and no `${TOKEN}` — only
`${PREFIX}`. The conversion is therefore a straight copy: the recipe now lives at
`recipe.json` in this folder (identical to the v1 objects.json block), and the template is
copied unchanged. Confirmed: the only placeholder in `artifact/PoSupplierImport.csv` is
`${PREFIX}`.

`${PREFIX}` stays on the new supplier's own duplicate-causing keys — `VENDOR_NAME` (col 2)
and `SEGMENT1` (col 4) — on all three rows, exactly as v1, so the same fixture reloads on
any run without colliding.

## Bad row

BAD-1 is a well-formed CREATE whose only defect is an invalid tax organization type
(`INVALID_ORG_TYPE` instead of `CORPORATION`). Import Suppliers rejects it in
`POZ_SUPPLIER_INT_REJECTIONS` with a "valid tax organization type" error; it lands in the
interface `POZ_SUPPLIERS_INT` but never reaches base `POZ_SUPPLIERS`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

| Field | Value |
|---|---|
| Prefix | `19927` |
| Hard-coded references | `CORPORATION` / `SUPPLIER` / `SPEND_AUTHORIZED` (standard enumeration codes) |
| Load ESS request id | `9766157` |
| Terminal status | `SUCCEEDED` |
| Credential role | `fin_impl` |

Good rows → base `POZ_SUPPLIERS` (2/2):

| SEGMENT1 | VENDOR_ID | VENDOR_NAME |
|---|---|---|
| `19927RT-SUP-G1` | `300000331567990` | `19927RT Supplier Good-1` |
| `19927RT-SUP-G2` | `300000331567997` | `19927RT Supplier Good-2` |

Bad row → interface rejection, absent from base (1/1):

| SEGMENT1 | Rejection error |
|---|---|
| `19927RT-SUP-BAD1` | `You must provide a valid tax organization type. [ORGANIZATION_TYPE_LOOKUP_CODE]` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Suppliers
```
