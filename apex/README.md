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

## Version parity — local upgraded to APEX 26.1 (2026-09-17)

Local Docker APEX was upgraded **24.2 → 26.1** (container `dmt2-ords` on port 8182,
workspace `DMT`) to match ATP. The `apex/f500` baseline (from ATP 26.1) now imports
cleanly into local — app 500 is imported locally alongside the legacy app 172, and
`import --target local` works in the CI pipeline.

Upgrade notes (for the next time / other environments):
- Run `apexins.sql SYSAUX SYSAUX TEMP /i/` as SYS inside `FREEPDB1`.
- If a prior attempt was interrupted, drop the partial version schema first
  (`alter session set "_oracle_script"=true; drop user APEX_<ver> cascade;`).
- After upgrade, recompile invalidated DMT objects (APEX-dependent packages/procs).
- ORDS (`dmt2-ords`) connects to the DB at `host.docker.internal:1523/FREEPDB1`; if a
  Docker restart changes container IPs and the pool loses its target, reset it:
  `ords --config /etc/ords/config config --db-pool default set db.hostname host.docker.internal`
  (and `db.port 1523`, `db.servicename FREEPDB1`), then restart the ORDS container.
