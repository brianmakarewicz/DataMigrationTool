# BillingEvents — v2 seeded gold fixture (LIVE-PROVEN)

Converted from the frozen v1 fixture (`../../objects/BillingEvents/`). Same two good + one
bad project billing events (one FBDI zip, one CSV `PjbBillingEventsXface.csv`, one
`loadAndImportData` call that chains **ImportBillingEventJob**), with read-only BIP
verification. The one difference from v1: every reference the CSV needs — contract, contract
line, project, event type, organization, currency, contract type — is **hard-coded to the
standard seeded demo values**, not discovered at load time. The discovery block is removed
from `recipe.json`.

## The hard-coded seeds (what v1 discovered → now literals)

v1's `BE_REF` discovery step picked a contract line already carrying many accepted USD
invoice-type billing events. On the demo pod it resolved to contract `C10013`. All of these
are standard seeded demo data we never loaded (confirmed live via read-only BIP: 124 accepted
seeded events back this exact combination, 0 of them carry our `DMT_GOLD` source name), so
hard-coding them is portable across any pod that ships the standard Projects demo contracts.

| Reference (v1 token) | Literal value | CSV column |
|---|---|---|
| `${ORGANIZATION_NAME}` | `Consulting West US` | 3 ORGANIZATION_NAME |
| `${CONTRACT_TYPE_NAME}` | `Sell: Project Lines Soft Limit` | 4 CONTRACT_TYPE_NAME |
| `${CONTRACT_NUMBER}` | `C10013` | 5 CONTRACT_NUMBER |
| `${CONTRACT_LINE_NUMBER}` | `1` | 6 CONTRACT_LINE_NUMBER |
| `${EVENT_TYPE_NAME}` | `Percent Spent Billing` (invoice-flag event type) | 7 EVENT_TYPE_NAME |
| `${CURRENCY_CODE}` | `USD` | 10 BILL_TRNS_CURRENCY_CODE |
| `${PROJECT_NUMBER}` | `PCS10013` | 12 PROJECT_NUMBER |
| (Business Unit, for context) | `US1 Business Unit` | — (not a CSV column) |

The event-type NAME the FBDI validates against lives in `PJF_EVENT_TYPES_TL.EVENT_TYPE_NAME`
(invoice/revenue flags in `PJF_EVENT_TYPES_B`), not in any PJB table. `Percent Spent Billing`
is an invoice-flag event type, so accepted rows create `PJB_BILLING_EVENTS` base rows.

`${PREFIX}` stays on the new record's own keys (SOURCEREF `${PREFIX}RT-BE-G1/G2/BAD1` and the
event description). `${GL_DATE_MDY}` (completion date, col 9) is a prefix-independent derived
token resolved to today's date by the harness — not discovery. The event numbers are assigned
by Fusion at import.

## Load path (unchanged from v1)

| Item | Value |
|---|---|
| Type | FBDI |
| Artifact | `BillingEvents_gold.zip` → member `PjbBillingEventsXface.csv` (headerless, 78 positional fields) |
| Auth user | `fin_impl` |
| UCM document account | `prj/projectBilling/import` |
| interfaceDetails id | `68` |
| Job name | `/oracle/apps/ess/projects/billing/transactions,ImportBillingEventJob` |
| ParameterList | `#NULL` (the import job takes no positional arguments) |
| Interface table | `PJB_BILLING_EVENTS_INT` (unconditionally purged after import) |
| Base table | `PJB_BILLING_EVENTS` |

## Rows in the fixture

| SOURCEREF | Contract | Event type | Amount | Meaning |
|---|---|---|---|---|
| `${PREFIX}RT-BE-G1` | `C10013` | Percent Spent Billing | 1 | GOOD |
| `${PREFIX}RT-BE-G2` | `C10013` | Percent Spent Billing | 2 | GOOD |
| `${PREFIX}RT-BE-BAD1` | `ZZINVALID-${PREFIX}` (no such contract) | Percent Spent Billing | 3 | BAD — invalid contract → deterministic rejection |

## BAD-row proof — interface is purged, so absence is authoritative

`PJB_BILLING_EVENTS_INT` is unconditionally purged once `ImportBillingEventJob` finishes
(Oracle MOS 2534525.1). The direct interface read can race the purge: sometimes it returns the
BAD row with `IMPORT_STATUS = ERROR`, sometimes 0 rows. The recipe therefore sets
`"bad_proof_is_absence": true`: when the interface read comes back empty, the authoritative BAD
proof is that the bad key is **absent from the base table** while both good keys from the SAME
load reached base with real event ids. The fixture never fakes an error.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

| Field | Value |
|---|---|
| Prefix | `15949` |
| Hard-coded seeds | `C10013` / line 1 / `PCS10013` / Percent Spent Billing / USD / Consulting West US / Sell: Project Lines Soft Limit / US1 Business Unit |
| Load ESS request id | `9766256` |
| Terminal status | `SUCCEEDED` (~60 s) |
| Credential role | `fin_impl` |

Good rows → base `PJB_BILLING_EVENTS` (2/2):

| SOURCEREF | EVENT_ID | EVENT_NUM | Amount |
|---|---|---|---|
| `15949RT-BE-G1` | `100002547480454` | 77 | 1 |
| `15949RT-BE-G2` | `100002547480455` | 78 | 2 |

Bad row → absent from base (1/1): `15949RT-BE-BAD1` did not reach `PJB_BILLING_EVENTS`
(interface purged; rejection proven by base-absence while both good rows from the same load
reached base). `run_object.py` returned `pass: true`.

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py BillingEvents
```
