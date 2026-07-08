# DMT2 — Data Migration Tool Rebuild

Clean re-platform of the Data Migration Tool (frozen predecessor: `brianmakarewicz/ConversionTool`,
local `~/workspace/data-migration-tool/`). Seeded 2026-07-07 from the proven `db_full/` greenfield
install (1,055 objects, verified on local Docker).

**Master plan:** `~/workspace/data-migration-tool/DMT_REBUILD_PLAN.html` — phases, build order,
per-stage test plan, roadmap, risks. Read the "Build Order of Operations" section before building.

## Current posture (2026-07-07)

- **Docker-only.** No ATP exists yet — all work runs against the local Docker instance
  (`dmt2-local`, port **1523**). The new Always Free ATP comes later.
- **GitHub repo:** not yet created (user will create). Local git only until then.
- **Fusion BIP folder for this stack:** `/Custom/DMT2/` (never `/Custom/DMT/` — that belongs to the frozen stack).
- **FBL file delivery:** decision deferred (blocks the 6 FBL config objects only — Phase 4).
- **Frozen stack:** bugs may still be fixed on the old ATP; every such fix must be ported here.

## Local Docker DB

```bash
sh db/tools/build_local_db.sh            # bring up / reuse dmt2-local, install everything
sh db/tools/build_local_db.sh --fresh    # destroy + full rebuild
# connect: dmt_owner / DmtLocal#2026 @ //localhost:1523/FREEPDB1
```

Ports in use elsewhere: 1521 (rt-oracle-free), 1522 (old dmt-local). DMT2 = **1523**.

## Layout

| Dir | Contents |
|---|---|
| `db/` | Full schema: install.sql + sequences/tables/views/packages/procedures/jobs/seed/grants/synonyms + tools/ |
| `docs/` | DMT_DESIGN.html (authoritative requirements — tag v1.0 pending), object catalog, coding standards |
| `objects/` | Per-CEMLI README.md (read before touching any object) |
| `bip/` | BIP data models + reports per CEMLI (deploy target `/Custom/DMT2/`) |
| `apex/` | f155.sql — latest APEX export from the old stack (port DEFERRED until regression gate passes) |
| `test/` | Regression bundle + FBDI fixtures |
| `scripts/` | Core harness only: dmt_regression_run.py, dmt_run_assert.py, dmt_deploy.py, dmt_db_git_sync.py, insert_regression_test_data.py, hooks/dmt_db_guard.py |
| `cicd/` | GitHub Actions workflows + CI docker assets (to be built — Phase 1D) |

## Rules carried over from the old stack (all still binding)

1. No test passes unless GOOD rows reach Fusion base tables (LOADED via BIP) AND BAD rows reach FAILED with reportable ERROR_TEXT.
2. Pure PL/SQL pipeline; Python is dev/test shim only.
3. Git-first DDL: DB changes only by running committed files. Never connect as ADMIN/SYSTEM for DMT DDL.
4. Prefix system always on (test 9001+); never reset STG/TFM row status — re-run with a new prefix.
5. Errors accumulate in ERROR_TEXT, never overwrite.
6. Read `objects/{Name}/README.md` before working on any CEMLI.
7. APEX work is deferred until the full regression scenario passes on the engine (see plan, Stage F).

## Build-order status (plan section 4)

- [ ] Stage A — Foundation DDL proven on dmt2-local (install runs clean twice, zero invalid)
- [ ] Stage B — Common utilities unit-tested (DMT_UTIL_PKG, Fusion call layer, CSV intake, generators w/ golden files)
- [ ] Stage C — Queue engine proven with mock CEMLI
- [ ] Stage D — Suppliers vertical slice E2E
- [ ] Stage E — Remaining Wave-1 objects (3 dependency waves)
- [ ] Stage F — Full regression gate → then APEX port
