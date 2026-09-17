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

## Prerequisite for TEST imports (one-time, not yet done)

The local Docker DB currently has no confirmed APEX instance or `DMT2` workspace, so
`import --target local` will not succeed until that is stood up: install APEX + ORDS
on `dmt2-local`, create the `DMT2` workspace bound to `DMT_OWNER`, then import. Until
then the git baseline still protects against ATP drift (re-export and diff any time).
