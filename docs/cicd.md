# DMT2 CI/CD — test on TEST, then promote to PROD

Script-first pipeline (owner decision 2026-09-17). The **deterministic regression
is the gate**: nothing reaches prod until the branch passes the same regression on
local. Runner: `scripts/ci_promote.py` (wraps the existing `dmt_regression_run.py`).

## Instances

| Role | DB | APEX | Schema |
|------|----|------|--------|
| TEST | local Docker `dmt2-local` (port 1523), Oracle Free 23ai | 24.2 (`dmt2-ords`, port 8182) | `DMT_OWNER` |
| GOLD (prod) | queryapp ATP | 26.1 | `DMT2_OWNER` |

Both point at the **same Fusion demo pod**, which is why prefixes must not collide.

## The pipeline

```
code on a branch
   └─ python scripts/ci_promote.py test-local            # GATE (deploy local + regression)
        ├─ pass → python scripts/ci_promote.py merge --pr N
        │           └─ python scripts/ci_promote.py deploy-prod --yes
        │                 └─ python scripts/ci_promote.py test-prod --yes   # confirm deploy
        └─ fail → stop; nothing merges, nothing deploys
```

Or all at once for a PR:

```
python scripts/ci_promote.py promote --pr N --yes
```

Stages (each runnable alone):
- **deploy-local** — idempotent sync of the working tree's `db/` into local (packages,
  views, seeds, idempotent table `add_col`s), recompile, assert 0 invalid. (`install.sql`
  is fresh-install only — it exits on the first "already exists".)
- **test-local** — deploy-local, set the prefix (see below), run the deterministic
  regression on local. **Hard gate.**
- **merge** — respects the mandated review gate; it does **not** bypass it. `pr-review.yml`
  is the binding reviewer (CLAUDE.md) and auto-merges clean PRs, so this stage *waits* for
  that reviewer: it succeeds only when the PR actually reaches MERGED, or is APPROVED and then
  merged through normal branch protection (no `--admin`, no bypass). CHANGES_REQUESTED or a
  timeout fails the stage, so `promote` stops before prod. `test-local` is an additional local
  pre-check, not a substitute for the automated review.
- **deploy-prod** — pull `main`, deploy `db/` + APEX to ATP. Requires `--yes`.
- **test-prod** — run the same regression on ATP to confirm the deploy. Requires `--yes`.

Scope a run with `--pipelines HCM` (default: all five — P2P, O2C, FINANCIALS, PROJECTS, HCM).

## Prefix leapfrog (no duplicate records in the shared Fusion pod)

Each run stamps every test record with a numeric prefix from `DMT_RUN_PREFIX_SEQ`.
Each instance has its own sequence, so equal values would push duplicate records to
Fusion. **ATP's sequence is the single source of truth.**

- For a local test run, the script consumes `ATP.NEXTVAL = v` and forces the local
  sequence to issue `v` (`ALTER SEQUENCE ... RESTART START WITH v`, 23ai).
- The prod run then consumes `ATP.NEXTVAL = v+1` on its own.
- Result: local uses `v`, prod uses `v+1`, next cycle draws `v+2` — distinct, monotonic,
  no bookkeeping beyond "always draw from ATP". The historical gap between the two
  sequences is ignored; we just adopt ATP's number.

## Prerequisites / open items

- **APEX version parity — resolved 2026-09-17.** Local APEX was upgraded 24.2 → 26.1 to
  match ATP, so `apex/f500` imports to both targets and `deploy-apex --target local` works.
  If a Docker restart changes container IPs and ORDS loses its DB pool target
  (`ORA-12541` on the browser), reset it with `ords config --db-pool default set
  db.hostname host.docker.internal` / `db.port 1523` / `db.servicename FREEPDB1`, then
  restart `dmt2-ords`. See `apex/README.md`.
- **Hands-off automation (later).** This is script-first; you/the agent run it. To make
  a `git push` auto-fire the pipeline against local Docker, install a self-hosted GitHub
  Actions runner on this machine and call the same stages from a workflow.

## The implementation loop

Work `docs/backlog.html` top-down in ROI order (open the "Rank by ROI" view, or sort by the
ROI column descending — highest-ROI still-open items surface first). For each item: branch →
implement → `test-local` (gate) → `merge` → `deploy-prod --yes` → `test-prod --yes`.
