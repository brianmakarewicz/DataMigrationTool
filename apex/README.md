# DMT2 APEX app — git-first, like the database

The Data Migration Console is version-controlled as **APEXLang source (`.apx`)**
under `apex/f501src/livedmt2/` — one file per page/component (application.apx,
`pages/`, `shared-components/`, `page-groups.apx`), so changes diff like source
code.

**`apex/f501src/livedmt2/` is the single source of truth**, exactly like `db/`
is for the schema. You do not edit an instance and hope it matches git; you
import the committed source.

> The older split-SQL export under `apex/f500/` is a legacy baseline kept for
> reference only. It is no longer the deploy source and `apex_deploy.py` does
> not use it.

## Instances

| Role | Where | App id | Workspace | Parsing schema |
|------|-------|--------|-----------|----------------|
| TEST (local dev) | Oracle Free Docker (port 1523) | 501 | `DMT` | `DMT_OWNER` |
| GOLD (prod) | queryapp ATP | 500 | `DMT2` | `DMT2_OWNER` |

Both instances run **APEX 26.1**, so APEXLang import/export round-trips cleanly
on both. The same committed source imports to app 501 locally and app 500 on
ATP (the script overrides the app id and workspace per target).

## Workflow (change → TEST → gold)

1. Make the change in the **local TEST** builder (app 501).
2. Export it back to git:
   `python scripts/apex_deploy.py export --target local`
   then sync the exported tree into `apex/f501src/livedmt2/` so deleted pages
   show as git deletions.
3. Commit + open a PR (the diff shows exactly which pages changed).
4. After review/merge, promote to gold:
   `python scripts/apex_deploy.py import --target atp`

Never edit the ATP (gold) app directly — that is what creates drift.

## CRLF gotcha (handled by the script)

The committed `.apx` files are LF, but this Windows checkout has
`core.autocrlf=true` and no `.gitattributes`, so the working-tree copies are
CRLF. SQLcl's APEXLang parser rejects CRLF and imports fail spuriously.
`apex_deploy.py import` stages a CRLF→LF copy into a temp directory and imports
that; the committed source is never modified. (If you ever import by hand, strip
CR first, or add `*.apx text eol=lf` to a `.gitattributes` and re-checkout.)

## Version parity — both instances on APEX 26.1

Local Docker APEX was upgraded **24.2 → 26.1** (container `dmt2-ords` on port
8182, workspace `DMT`) to match ATP, which is what makes the APEXLang round-trip
work on both. Upgrade notes (for the next time / other environments):
- Run `apexins.sql SYSAUX SYSAUX TEMP /i/` as SYS inside `FREEPDB1`.
- If a prior attempt was interrupted, drop the partial version schema first
  (`alter session set "_oracle_script"=true; drop user APEX_<ver> cascade;`).
- After upgrade, recompile invalidated DMT objects (APEX-dependent packages/procs).
- ORDS (`dmt2-ords`) connects to the DB at `host.docker.internal:1523/FREEPDB1`; if a
  Docker restart changes container IPs and the pool loses its target, reset it:
  `ords --config /etc/ords/config config --db-pool default set db.hostname host.docker.internal`
  (and `db.port 1523`, `db.servicename FREEPDB1`), then restart the ORDS container.

## APEX static images (`/i/`) are re-provisioned automatically (backlog #159)

The `dmt2-ords` container serves the APEX static files (`/i/`) from the host
bind-mount `apex/installer/apex` → `/opt/oracle/apex` (read-only); `/i/` is the
`images/` subfolder. Those ~29k 26.1 image files (~500 MB of JS/CSS) are **not
committed to git**, so a fresh clone or a `build_local_db.sh --fresh` leaves the
folder empty — then `/i/` 404s, the console renders unstyled, and the Sign In
button does nothing.

**This is now handled for you.** `build_local_db.sh` runs
`db/tools/provision_apex_images.sh` on every build. That step is idempotent and
version-checked: if the served `images/` folder already holds APEX 26.1 it does
nothing; otherwise it copies the image set from the known-good 26.1 source
(`APEXResourceTracker/cicd/docker/downloads/apex/images`), verifies
`images/apex_version.txt` says 26.1, and — when `dmt2-ords` is running — confirms
`http://localhost:8182/i/apex_version.txt` serves HTTP 200. You can also run it
standalone: `sh db/tools/provision_apex_images.sh`. Override the source or
destination with `APEX_IMAGES_SRC` / `APEX_IMAGES_DEST` and the expected version
with `APEX_VERSION`.
