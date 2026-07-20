# Projects — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/Projects/`). Same two good + one bad
project (three CSVs: projects, tasks, team members), loaded via `loadAndImportData` under
`fin_impl` with the chained **Import Projects** job (`ImportProjectJobDef`), then read-only BIP
verification. The one difference from v1: every upstream reference (project template,
carrying-out organization, currency, both project managers) is **hard-coded to a standard
seeded value** instead of discovered at load time. The discovery block is removed from
`recipe.json`.

## The hard-coded seeds (what v1 discovered → now literals)

All confirmed live via read-only BIP on `fa-esew-dev28` (2026-07-20). Every one is standard
seeded demo data we never loaded — none carries an `RT-` prefix:

| Reference | Literal value | Where used |
|---|---|---|
| Source project template number | `PRGUS Sponsored` | projects col 3 (`SOURCE_TEMPLATE_NUMBER`) |
| Carrying-out organization name | `Maintenance Prg US` | projects col 6 (`CARRYING_OUT_ORGANIZATION_NAME`) |
| Project currency | `USD` | projects col 22 (`PROJECT_CURRENCY_CODE`) |
| Project manager 1 (person number 10) | name `Mandy Steward`, email `MANDY.STEWARD_esew-dev28@oraclepdemos.com` | parties row 1 (G1) |
| Project manager 2 (person number 100) | name `Brian LineManager`, email `Brian.LineManager_esew-dev28@oraclepdemos.com` | parties row 2 (G2) |

The template number `PRGUS Sponsored` is a short human template name (not an 8+ digit
synthetic id) — the key data-quality requirement Import Projects enforces (see v1's attempt-1
lesson). Its carrying-out organization on the pod is `Maintenance Prg US` and its currency is
`USD`; the FBDI organization column must equal the template's org, so both are taken from the
same confirmed template row.

`${PREFIX}` stays on the natural keys only: the project number and name
(`${PREFIX}RT-PRJ-G1/G2/BAD1`) and the task number (`${PREFIX}G1.1` / `${PREFIX}G2.1`). Nothing
else is stamped.

### Dates are today-derived (not the v1 hard-coded 2025 window)

v1 used a fixed `2025/01/01`–`2025/12/31` window. Because a stale year eventually falls in the
past, this v2 fixture uses harness-derived date tokens instead so the project window is always
open around the run date:

- `${GL_DATE_SLASH}` — today (`YYYY/MM/DD`) — project start (col 12), task start (col 7), team
  member start (parties col 6).
- `${PRJ_FINISH_SLASH}` — today + 365 days — project finish (col 13), task finish (col 8).

Both project rows carry an explicit start and finish so the task planning dates fall inside the
project window (v1's attempt-2 lesson: missing project dates → task rejection). `PRJ_FINISH_SLASH`
was added additively to `harness/build_artifact.py::derived_tokens` (one year after today); no
existing token behavior changed.

## Good / bad rows

| Key | Kind | What makes it good/bad |
|---|---|---|
| `${PREFIX}RT-PRJ-G1` | GOOD | Seeded template `PRGUS Sponsored` + org `Maintenance Prg US` + `USD`; project window today→today+365; one task, PM `Mandy Steward`. |
| `${PREFIX}RT-PRJ-G2` | GOOD | Same; PM `Brian LineManager`. |
| `${PREFIX}RT-PRJ-BAD1` | BAD | `SOURCE_TEMPLATE_NUMBER = ZZ-NO-SUCH-TEMPLATE`. Import Projects rejects it: "The source template number isn't valid." |

## ESS orchestration (unchanged from v1)

`loadAndImportData` uploads the zip to UCM (`prj/projectFoundation/import`), runs the interface
loaders, and chains `ImportProjectJobDef` with ParameterList `,,Y` (fromProject empty,
toProject empty, reportSuccess `Y`). Auth user is `fin_impl` (not `calvin.roth`). The base-table
read is the pass bar; no separate downstream `submitESSJobRequest` is needed.

## Verification (read-only)

- **GOOD → base.** `PJF_PROJECTS_ALL_VL` filtered by `segment1 LIKE :PREFIX || 'RT-PRJ-%'`.
- **BAD → interface + absent from base.** `PJF_PROJECTS_ALL_XFACE` by `load_request_id`; the
  rejected row shows `IMPORT_STATUS=FAILURE LOAD_STATUS=COMPLETE` and is absent from the base
  table. (The authoritative bad-row error text lives only in the ImportProjectReportJob output;
  the pass/fail decision uses the base-table read.)

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN both directions. PASS (first run).**

| Field | Value |
|---|---|
| Prefix | `70047` |
| Pod | `fa-esew-dev28` |
| Load ESS request (fin_impl, loadAndImportData) | `9766260` → SUCCEEDED |

Good rows → base `PJF_PROJECTS_ALL_VL` (2/2):

| PROJECT_NUMBER | PROJECT_ID |
|---|---|
| `70047RT-PRJ-G1` | `300000331550256` |
| `70047RT-PRJ-G2` | `300000331550282` |

Bad row → interface, absent from base (1/1):

| PROJECT_NUMBER | Interface status |
|---|---|
| `70047RT-PRJ-BAD1` | `IMPORT_STATUS=FAILURE LOAD_STATUS=COMPLETE` (invalid source template; absent from `PJF_PROJECTS_ALL_VL`) |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Projects
```

## Files

- `recipe.json` — FBDI, 3-CSV member list, **no discovery block**, literal ParameterList `,,Y`,
  verify block.
- `artifact/Pjf*.csv` — the three templated CSVs (`${PREFIX}` + hard-coded seeds + date tokens).
- `Projects_gold.zip` — last assembled ready-to-load artifact.
