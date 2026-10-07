# DMT2 CI/CD — test on TEST, then promote to PROD

Script-first pipeline (owner decision 2026-09-17). The **deterministic regression
is the gate**: nothing reaches prod until the branch passes the same regression on
local. Runner: `scripts/ci_promote.py` (wraps the existing `dmt_regression_run.py`).

## Instances

| Role | DB | APEX | Schema |
|------|----|------|--------|
| TEST | local Docker `dmt2-local` (port 1523), Oracle Free 23ai | 26.1 (`dmt2-ords`, port 8182; upgraded 24.2→26.1 2026-09-17 to match ATP) | `DMT_OWNER` |
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

## The promotion gate (strict; owner-only override)

Owner's rule: nothing is promoted to ATP unless the exact code being promoted passed a
**full local regression** AND the **Playwright console click-through for that same run**
(`test/playwright/dmt_console_verify.py --run-id N`). After promotion, the same
click-through runs against ATP. The step-by-step runbook is the project skill
`.claude/skills/deploy-dmt2-atp/SKILL.md`.

`deploy-prod` enforces this through `scripts/promotion_gate.py`:

- `deploy-local`, `regression-local` and `clickthrough-local` (or `test-local`, which runs
  all three) each record evidence in the gitignored `.ci_evidence/promotion_evidence.json`:
  the git commit SHA, the git tree SHA, whether the tree was clean, the run id, the verdict
  and the time. Every record and every gate decision is also appended to
  `.ci_evidence/promotion_log.jsonl`.
- `deploy-prod` refuses unless, for the commit it is about to deploy: the local deploy was
  clean and happened before the regression started; the regression covered every pipeline,
  had verdict PASS (exit 0) and finished within 24 hours; and a PASS click-through ran for
  that same run id after the regression finished. The working tree must be clean.
- Evidence matches when the commit SHA matches, or when the git tree SHA matches (identical
  files, e.g. after the reviewer's squash merge). Any file difference refuses.
- The only exception is `deploy-prod --yes --owner-override "<reason>"`, for the owner
  personally. It waives only regression and click-through failures (clean local deploy
  evidence and a clean tree are still required), needs a non-empty reason, refuses unless
  stdin is an interactive terminal, and asks for the commit's short SHA to be typed. Every
  attempt is printed loudly and logged to `promotion_log.jsonl` (reason, SHA, git user,
  time, bypassed checks). Agents and CI must never use it; they report a refusal to the
  owner.
- `python scripts/ci_promote.py gate` shows the decision
  without deploying. `python test/unit/test_promotion_gate.py` proves the refusals offline
  with fake evidence in a temp directory.
- `test-prod` now runs the ATP regression and then the click-through against the ATP
  console for that ATP run (`clickthrough-atp --run-id N` repeats just the click-through).
- `runtime-config --target local|atp` re-applies the Fusion passwords (global and per-object
  overrides such as Grants' `ppm_impl`) and the Fusion network access from
  `connections.json`. `deploy-local` and `deploy-prod` run it automatically after deploying.

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
- **Hands-off automation — now wired (Phase 2).** `.github/workflows/ci-promote-local.yml`
  fires on every push to a non-`main` branch and runs the same hard gate automatically:
  `python scripts/ci_promote.py test-local` (deploy local + deterministic regression),
  then a quick Playwright UI smoke of the local console
  (`python scripts/dmt_apex_playwright_gate.py`). It runs `runs-on: [self-hosted, dmt2-docker]`
  because only the local machine can reach the local Docker DB. It is **additive** — the cloud
  PR reviewer (`.github/workflows/pr-review.yml`, `runs-on: ubuntu-latest`) is untouched and
  remains the binding approver/merger; this workflow just proves the branch on the local stack
  the cloud runner can't reach.
  - **Manual infra step (a human does this once).** Install a self-hosted GitHub Actions
    runner on the local machine and give it the labels `self-hosted` and `dmt2-docker`
    (repo → Settings → Actions → Runners → New self-hosted runner). The runner's service
    account needs: the local Docker DB (`dmt2-local`, port 1523) up, SQLcl + JDK 21 on PATH,
    the Python deps `oracledb`/`requests`, Node + the Playwright install used by
    `playwright_verify.js`, and read access to `~/workspace/connections.json`. Add the
    Playwright smoke account as repo secrets `DMT2_UI_USER` / `DMT2_UI_PASS` (a non-admin
    account — never `DMTADMIN`). Until the runner is installed, the workflow just queues;
    everything still runs by hand with the `ci_promote.py` stages above.

## The implementation loop

Work `docs/backlog.html` top-down in ROI order (open the "Rank by ROI" view, or sort by the
ROI column descending — highest-ROI still-open items surface first). For each item: branch →
implement → `test-local` (gate) → `merge` → `deploy-prod --yes` → `test-prod --yes`.
