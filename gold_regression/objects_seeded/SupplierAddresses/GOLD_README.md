# SupplierAddresses — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/SupplierAddresses/`). Same two
good + one bad supplier addresses, loaded via `loadAndImportData` with read-only BIP
verification. The one difference from v1: the parent supplier is **hard-coded to a
standard seeded value**, not discovered at load time.

## The hard-coded seed (what v1 discovered → now a literal)

v1 discovered "the lowest-numbered active, unlocked supplier." On this demo pod that
resolved to **`Staffing Services`** (segment1 `1253`, party_id `300000047414569`).
This is standard seeded demo data — we never loaded it (it carries no `RT`/prefix). It
is confirmed **unlocked** (`supplier_locked_flag = 'N'`), which matters: the
lowest-numbered supplier "Lee Supplies" (1252) is **locked** on this pod, so every
address attached to it is rejected with a "supplier profile is locked" error. We
therefore hard-code Staffing Services, not Lee Supplies, for this object.

- Template `artifact/PozSupAddressesInt.csv`: `VENDOR_NAME` (position 2) is the literal
  `Staffing Services` on all three rows.
- `recipe.json` verify base read is scoped to `party_id = 300000047414569` (Staffing
  Services' party), and the discovery block is removed.
- `${PREFIX}` stays on the three `PARTY_SITE_NAME` new-record keys
  (`${PREFIX}RT-ADDR-G1/G2/BAD1`).

Verified live (read-only BIP) that the seed exists and is unlocked:
`Staffing Services | 1253 | party 300000047414569 | ENABLED Y | LOCKED N`.

## Bad row

BAD-1 is a well-formed CREATE against the same valid supplier with a valid site name
and a purpose flag; the only defect is a **missing COUNTRY**. It lands in
`POZ_SUP_ADDRESSES_INT` and is rejected in `POZ_SUPPLIER_INT_REJECTIONS`, absent from
`HZ_PARTY_SITES`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

| Field | Value |
|---|---|
| Prefix | `35118` |
| Hard-coded supplier | `Staffing Services` (1253, party_id 300000047414569, unlocked) |
| Load ESS request id | `9766099` |
| Terminal status | `SUCCEEDED` |
| Credential role | `fin_impl` |

Good rows → base `HZ_PARTY_SITES` (2/2):

| PARTY_SITE_NAME | PARTY_SITE_ID |
|---|---|
| `35118RT-ADDR-G1` | `300000331567849` |
| `35118RT-ADDR-G2` | `300000331567855` |

Bad row → interface rejection, absent from base (1/1):

| PARTY_SITE_NAME | Rejection error |
|---|---|
| `35118RT-ADDR-BAD1` | `A value is required. You must provide a value. [COUNTRY]` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py SupplierAddresses
```
