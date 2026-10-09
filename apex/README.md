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
version-checked, and it never touches the database:

- **Destination.** It writes to the host folder that the `dmt2-ords` container
  actually bind-mounts at `/opt/oracle/apex` (read from `docker inspect`), plus
  `/images`. If that container does not exist it falls back to
  `<repo>/apex/installer/apex/images`. `APEX_IMAGES_DEST` overrides both.
- **Source.** Set `APEX_IMAGES_SRC` to a populated APEX 26.1 `images/` folder. If
  it is unset, the script uses the sibling-workspace folder
  `../APEXResourceTracker/cicd/docker/downloads/apex/images` when it exists. No
  machine-specific path is committed.
- **Behaviour.** If the destination already holds APEX 26.1, it copies nothing.
  Otherwise it copies the source in additively (it never deletes files from the
  destination) and verifies `images/apex_version.txt` says 26.1. If no source is
  configured, it prints a warning and exits successfully, so the DB build still
  works on machines and CI runners without the image set.
- **Live check and self-repair.** When `dmt2-ords` is running, it requires
  `http://localhost:8182/i/apex_version.txt` to return HTTP 200 with version 26.1.
  If it does not, the script repairs the web tier itself: it sets ORDS
  `standalone.static.path` to `/opt/oracle/apex/images` when missing, restarts
  `dmt2-ords` (the restart also re-mounts an images folder that was wiped and
  recreated) and waits up to `ORDS_WAIT_S` (default 240 s) for HTTP 200. It fails
  only if `/i/` is still broken after that.
- **When it runs.** `build_local_db.sh` (with or without `--fresh`) runs it right
  after the container step, before the DB install, so a later install failure can
  never leave the console login broken, and once more at the end as the strict
  check. Proven offline with fake docker/curl/SQLcl:
  `sh test/unit/test_apex_images_rebuild.sh`.

You can also run it on its own: `sh db/tools/provision_apex_images.sh`. The
expected version can be changed with `APEX_VERSION`.
