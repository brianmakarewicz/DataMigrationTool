# DMT2 APEX app — git-first, like the database

The Data Migration Console is **APEX application 500** (workspace `DMT2`, 40 pages).
Its definition lives in git as a **split export** under `apex/f500/` — one file per
page/component, so changes diff like source code.

**`apex/f500/` is the single source of truth**, exactly like `db/` is for the schema.
You do not edit an instance and hope it matches git; you import the committed export.

## Instances

| Role | Where | Parsing schema |
|------|-------|----------------|
| TEST | local Oracle Free Docker (port 1523) | `DMT_OWNER` |
| GOLD (prod) | queryapp ATP | `DMT2_OWNER` |

Baseline captured 2026-09-17 by exporting the live ATP app 500 (the latest good
version). The previous monolith `apex/DMTApplication.sql` was a stale app-155 export
and has been removed.

## Workflow (change → TEST → gold)

1. Make the change in the **local TEST** builder.
2. Export it back to git:
   `python scripts/apex_deploy.py export --target local`
   then replace `apex/f500/` with the new tree so deleted pages show as git deletions.
3. Commit + open a PR (the diff shows exactly which pages changed).
4. After review/merge, promote to gold:
   `python scripts/apex_deploy.py import --target atp`

Never edit the ATP (gold) app directly — that is what creates drift.

## Open item — APEX version gap blocks TEST import (owner decision pending)

Local Docker **does** have APEX (24.2, container `dmt2-ords` on port 8182, workspace
`DMT`, currently serving app 172). But **ATP is on APEX 26.1**, and a 26.1 export
cannot be imported into 24.2 (newer-into-older is unsupported). So the `apex/f500`
baseline (captured from ATP 26.1) will not import to local as-is — `import --target
local` is skipped in the CI pipeline for now.

Local app 172 is **structurally identical** to ATP app 500 (same 41-page set), so
local remains a working mirror in the meantime. Two ways to close the gap:
- **(A, recommended)** upgrade local Docker APEX 24.2 → 26.1 so it truly mirrors prod
  and the ATP baseline imports cleanly; or
- **(B)** keep local on 24.2 and make the git canonical a 24.2-sourced export (imports
  up to 26.1), accepting that 26.1-only features are not represented.

The DB half of the pipeline is unaffected — local DB syncs from `db/` and the ATP
APEX import from `apex/f500` works today.
