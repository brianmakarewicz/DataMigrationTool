# SupplierContacts — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/SupplierContacts/`). Same two
good + one bad supplier contact, loaded via `loadAndImportData` (which loads the
interface AND chains **Import Supplier Contacts**) with read-only BIP verification.
The one difference from v1: the parent supplier the contacts attach to is
**hard-coded to a standard seeded value**, not discovered at load time.

## The hard-coded seed (what v1 discovered → now a literal)

v1 discovered "the highest-numbered active, unlocked supplier." On this demo pod that
resolved to **`St. Johns School`** (segment1 `1493`, vendor_id `300000324469533`).
This is standard seeded demo data — we never loaded it (it carries no `RT`/prefix). It
is confirmed **enabled and unlocked**, which matters: the lowest-numbered supplier
"Lee Supplies" (1252) is **locked** on this pod by a pending change request, so every
contact attached to it is rejected with a "supplier profile is locked" error. We
therefore hard-code St. Johns School, not Lee Supplies, for this object.

Verified live (read-only BIP) that the seed exists and is unlocked:
`St. Johns School | 1493 | vendor_id 300000324469533 | ENABLED Y | LOCKED N`.

- Template `artifact/PozSupContactsInt.csv`: `VENDOR_NAME` (position 2) is the literal
  `St. Johns School` on the two good rows.
- `recipe.json` has **no discovery block** (removed).
- `${PREFIX}` stays on the three contact new-record keys: `LAST_NAME`
  (`${PREFIX}RTConAliceG1/BobG2/Bad1`, position 7) and `EMAIL_ADDRESS` (position 11).

## The three rows

| Row | VENDOR_NAME | LAST_NAME (natural key) | Purpose |
|---|---|---|---|
| GOOD-1 | `St. Johns School` (seeded literal) | `${PREFIX}RTConAliceG1` | valid → base (a PERSON party) |
| GOOD-2 | `St. Johns School` (seeded literal) | `${PREFIX}RTConBobG2` | valid → base (a PERSON party) |
| BAD-1  | `${PREFIX}DMT DOES NOT EXIST SUPPLIER` | `${PREFIX}RTConBad1` | rejected → interface |

The BAD row names a supplier that cannot exist, so **Import Supplier Contacts**
rejects it into `POZ_SUP_CONTACTS_INT` with the deterministic error
`You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME.
[VENDOR_NAME]`, and it never reaches a base party.

## Base proof

A supplier contact loads as a **PERSON party in `HZ_PARTIES`** keyed by
`PER_PARTY_ID`. The base read finds each good contact by its prefixed last name
(`party_type = 'PERSON'`, `person_last_name LIKE '<prefix>RTCon%'`) — mirroring the
deployed BIP data model. `POZ_SUPPLIER_CONTACTS` does not carry the new PERSON contact
on this pod, so `HZ_PARTIES` is the base-table proof. The bad row is confirmed absent
from `HZ_PARTIES`.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database, no DMT code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Prefix | `97571` |
| Hard-coded supplier | `St. Johns School` (1493, vendor_id 300000324469533, enabled, unlocked) |
| Load ESS request id | `9766172` |
| Terminal status | `SUCCEEDED` (terminal at 60s) |
| Credential role | `fin_impl` (SOAP load and BIP relay) |

Good rows → base `HZ_PARTIES` (PERSON party) (2/2):

| LAST_NAME | FIRST_NAME | PARTY_ID |
|---|---|---|
| `97571RTConAliceG1` | `Alice` | `300000331568051` |
| `97571RTConBobG2` | `Bob` | `300000331568068` |

Bad row → interface rejection, absent from base (1/1):

| LAST_NAME | Rejection error |
|---|---|
| `97571RTConBad1` | `You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py SupplierContacts
```
