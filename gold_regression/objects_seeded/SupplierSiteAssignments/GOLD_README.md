# SupplierSiteAssignments — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/SupplierSiteAssignments/`). Same two
good assignments + one bad, loaded via `loadAndImportData` with read-only BIP verification.
The one difference from v1: the supplier, its site, the procurement business unit, and the
two client business units are all **hard-coded to standard seeded values**, not discovered at
load time. The discovery block is removed from `recipe.json`.

A supplier **site assignment** links an existing supplier site (a row in
`POZ_SUPPLIER_SITES_ALL_M`, owned by a procurement BU) to a **client business unit** — the
bill-to / sold-to BU allowed to transact against that site. This fixture creates NEW
assignments; it creates no supplier or site.

## The hard-coded seeds (what v1 discovered → now literals)

v1 discovered a real seeded site plus two client BUs it was not yet assigned to. On this pod
v1 resolved to `Escheatment Agency / US1 - Escheatment` under `US1 Business Unit`, with client
BUs Sweden and UK. **That exact triple is no longer re-usable** because v1's own run already
consumed both of that site's available client BUs (see re-run note below). For v2 we therefore
hard-code a different, fully-unassigned seeded site under the same procurement BU:

| FBDI field | Literal value |
|---|---|
| VENDOR_NAME (col 2) | `InterSupCH` (vendor_id 300000188707452) |
| VENDOR_SITE_CODE (col 3) | `InterSupCH US` (vendor_site_id **300000267319997**) |
| PROCUREMENT_BUSINESS_UNIT_NAME (col 4) | `US1 Business Unit` |
| BUSINESS_UNIT_NAME / BILL_TO_BU_NAME (cols 5-6), GOOD-1 | `Sweden Business Unit` |
| BUSINESS_UNIT_NAME / BILL_TO_BU_NAME (cols 5-6), GOOD-2 | `UK Business Unit` |
| BUSINESS_UNIT_NAME / BILL_TO_BU_NAME (cols 5-6), BAD-1 | `${PREFIX}NO SUCH BU` |

All of these are standard seeded demo data we never loaded (no `RT`/prefix). Confirmed live
via read-only BIP before the run:

- Site `InterSupCH US` exists under proc BU `US1 Business Unit`, and had **zero** active
  assignments (all three of the pod's valid US1 client BUs — Sweden, UK, US1 — were available).
- The `(US1 procurement BU → client BU)` pairings for Sweden and UK already exist elsewhere in
  `POZ_SITE_ASSIGNMENTS_ALL_M`, which is the pod-agnostic proof those client BUs are actually
  enabled to transact against the US1 procurement BU (an unenabled client BU is rejected by
  Fusion). On this pod exactly three client BUs are valid for US1: Sweden, UK, US1.

`${PREFIX}` stamps only the BAD row's invalid client-BU name so the same fixture reloads
without the bad key colliding. The good rows carry **no prefix** — an assignment's natural key
is `vendor_site_id + client BU`, both fixed seeded values, not a free-text code we invent.

## The FBDI artifact

`artifact/PozSiteAssignmentsInt.csv` — one CSV in the zip, no header, 15 position-based
columns per the CTL. Three `IMPORT_ACTION=CREATE` rows: GOOD-1 assigns the site to
`Sweden Business Unit`, GOOD-2 to `UK Business Unit`, BAD-1 to `${PREFIX}NO SUCH BU` (a
business unit that does not exist → deterministic Fusion rejection with reject code on
`BUSINESS_UNIT_NAME`).

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.** Standalone load path only (no DMT database, no DMT code
in the load path); verification via the read-only BIP relay only. Passed on the first run.

| Field | Value |
|---|---|
| Prefix | `37353` (used only for the bad row's invalid client-BU name) |
| Hard-coded supplier / site / proc BU | `InterSupCH` / `InterSupCH US` / `US1 Business Unit` (vendor_site_id 300000267319997) |
| Load ESS request id | `9766196` |
| Terminal status | `SUCCEEDED` (terminal at 60s) |
| Credential role | `fin_impl` (SOAP load and BIP relay) |

**Good assignments → base table `POZ_SITE_ASSIGNMENTS_ALL_M` (2/2):**

| Client BU (BUSINESS_UNIT_NAME) | ASSIGNMENT_ID | VENDOR_SITE_ID |
|---|---|---|
| `Sweden Business Unit` | `300000331568177` | `300000267319997` |
| `UK Business Unit` | `300000331568179` | `300000267319997` |

**Bad assignment → interface rejection, absent from base (1/1):**

| Client BU | Rejection error |
|---|---|
| `37353NO SUCH BU` | `You must provide a valid value. [BUSINESS_UNIT_NAME]` |

## Re-run note (IMPORTANT — inherent limitation of this object)

**A second identical run does NOT create new good base rows.** An assignment's natural key is
`vendor_site_id + client BU`, and it has no free-text component that `${PREFIX}` can vary. Once
GOOD-1/GOOD-2 assign `InterSupCH US` to Sweden and UK, those pairs exist; re-loading the same
two CREATE rows is treated by Fusion as already-assigned and produces **no new** assignment.

The harness still reports `pass: true` on a 2nd run — but only because the good-row base read
matches by `vendor_site_id + BU name` (not by this run's load), so it re-finds the assignment
ids created by the **first** run (verified: run 2 with prefix `33327`, load 9766214, returned
the same ASSIGNMENT_IDs 300000331568177 / 300000331568179 as run 1). The bad row remains
genuinely per-run because it carries the prefix.

So: **one live run is authoritatively proven** (fresh base rows created). A 2nd run "passes"
the check but creates nothing new — it re-observes run 1's rows. To get genuinely fresh good
base rows you must either pick a different unassigned seeded site or rotate to a different
client BU, and this pod only offers three valid US1 client BUs (Sweden, UK, US1) total, so
sustained re-running of the identical fixture is not possible. This is a property of the
assignment object, not of the seeding conversion.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py SupplierSiteAssignments
```
