---
name: deploy-dmt2-atp
description: Promote DMT2 from main to the ATP GOLD instance, in order, with the hard gate. Use whenever someone asks to deploy, promote, push, or release DMT2 to ATP / GOLD / prod, or to "get ATP up to date with main". Covers syncing main, deploying locally, the full local regression, the local Playwright click-through, promoting through scripts/ci_promote.py (which refuses without evidence), the per-object Fusion credentials step (e.g. Grants runs as ppm_impl), and the post-promotion click-through against ATP.
---

# Deploy DMT2 to ATP (GOLD)

The owner's rule is simple: **nothing goes to ATP unless the exact code being promoted
has passed a full local regression AND the Playwright console click-through for that
same run.** After promotion, the same click-through runs against ATP.

This used to be a remembered rule, and it was skipped once. It is now enforced by
`scripts/ci_promote.py`: the ATP deploy step refuses to run unless it finds recent,
passing evidence for the current commit. If the gate refuses, do the missing step;
never edit the evidence file by hand and never deploy to ATP some other way.

**Agents must never use the owner override.** `deploy-prod` has an
`--owner-override "<reason>"` option, but it exists only for the owner personally,
typing at a real terminal (see "Owner override" below). An agent that hits a gate
refusal stops and reports the refusal to the owner, with the exact REFUSED lines
the gate printed, and does nothing else to get the code onto ATP.

Run every command from the canonical working directory
`C:\Users\Monroe\workspace\DMT2` (not a worktree), in this order. Do not skip or
reorder steps.

## 1. Sync main

```bash
git checkout main
git fetch
git merge --ff-only origin/main
git status
```

`git status` must show a clean tree. The gate refuses to promote when there are
uncommitted changes or untracked files under `db/`, `apex/`, `bip/`, `scripts/` or
`test/`, because then the commit SHA would not describe the code being deployed.

## 2. Deploy main to the local Docker instance

```bash
python scripts/ci_promote.py deploy-local
```

This installs the working tree's `db/` and the APEX app into the local instance
(`dmt2-local`, port 1523), checks that nothing is left invalid, and then re-applies
the Fusion passwords and network access from `connections.json` (the same
credentials step as step 7, run against local). It records the deploy as evidence.

## 3. Run the full local regression

```bash
python scripts/ci_promote.py regression-local
```

Do not pass `--pipelines`: the gate only accepts a run that covered every pipeline
(P2P, O2C, FINANCIALS, PROJECTS, HCM). The run can take up to 90 minutes. It draws
its prefix from ATP so local and ATP never send duplicate records to the shared
Fusion pod. The run id and the verdict are recorded as evidence.

The verdict must be **PASS** (exit code 0). "PASS (with review items)" or FAIL is
not a pass, and the gate will refuse. Investigate and fix the failures, commit the
fix through a PR, and start again from step 1.

## 4. Run the local console click-through for that same run

```bash
python scripts/ci_promote.py clickthrough-local
```

This runs `test/playwright/dmt_console_verify.py --run-id <the regression run id>`
against the local console. It logs in as the non-admin `DMT_SMOKE` user, visits every
page, does the full drill-down (run detail, object detail, ESS job pages, record
detail, activity log, run comparison) and checks the verify links. The verdict must
be PASS.

Steps 2, 3 and 4 can be run in one go with `python scripts/ci_promote.py test-local`,
which stops at the first step that fails.

## 5. Check the gate (optional, read-only)

```bash
python scripts/ci_promote.py gate
```

This prints exactly what the ATP deploy step will decide, one line per check, without
deploying anything. It needs all of these, for the current commit:

- a clean local deploy of this code, made before the regression started;
- a full local regression with exit code 0, finished within the last 24 hours, whose
  verdict is PASS or `PASS (known review items only)`. The second verdict means zero
  failures and every review item is a never-passed item listed in
  `scripts/regression_known_review.json` (owner decision 2026-10-08: "if something
  never passed before, I don't want to hold everything up"). Any NEW review item or
  any failure still blocks. Never add an item to that file to get past the gate; an
  item belongs there only if it has never passed, and the owner decides. When the
  harness prints "KNOWN item cleared", delete that entry;
- a PASS click-through of the local console for that same run id, run after the
  regression finished.

Evidence matches the current commit when the commit SHA matches, or when the files
are byte-for-byte identical (same git tree), which is what a squash merge produces.

## 6. Promote to ATP

```bash
python scripts/ci_promote.py deploy-prod --yes
```

This checks out and pulls `main`, re-checks the gate against the commit it is about
to deploy, and only then deploys `db/` (including `db/migrations/`) and the APEX app
to ATP as `DMT2_OWNER`. If the gate refuses, it prints why and deploys nothing. Every
gate decision, refused or passed, is appended to `.ci_evidence/promotion_log.jsonl`.

If you are an agent and the gate refuses here, stop and report it to the owner.

### Owner override (the owner personally, never an agent or CI)

The gate stays strict: it needs a clean regression PASS or `PASS (known review
items only)` (exit 0) and a passing
click-through for the same run on the same code. The one exception is an explicit
override by the owner:

```bash
python scripts/ci_promote.py deploy-prod --yes --owner-override "<why this is acceptable>"
```

- It waives only regression and click-through failures. It still needs clean local
  deploy evidence for this commit and a clean working tree.
- The reason must not be empty.
- stdin must be an interactive terminal, and the owner must type the short SHA of the
  commit being promoted. Run from an agent, a pipe or CI, it is refused.
- It prints loud banners, and every attempt (accepted or refused) is appended to
  `.ci_evidence/promotion_log.jsonl` as an `owner_override` event with the reason,
  the SHA, the git user, the time and the failing checks it bypassed.

## 7. Per-object Fusion credentials on ATP

`deploy-prod` runs this automatically after a successful deploy. Run it again by hand
whenever credentials change or an object fails with a 401 on ATP:

```bash
python scripts/ci_promote.py runtime-config --target atp --yes
```

It runs `db/tools/setup_runtime_config.py` against ATP. Passwords are never stored in
git, so a deploy can leave them masked or stale. The script sets the global Fusion
password, every per-object credential override in `DMT_ERP_INTERFACE_OPTIONS_TBL`,
and the network access to the Fusion host, all from `~/workspace/connections.json`.

Some objects must run as a specific Fusion user. Grants is the main example: it is
submitted, polled and reconciled as `ppm_impl`, because `fin_impl` is not set up for
the award business unit and Fusion rejects the awards with "requisite setup steps
haven't been completed". Check the script's output: a line saying there is no
password for an override user means `connections.json` is missing that user. Add the
user there and re-run; never type a password into the database by hand.

## 8. Verify ATP after promotion

```bash
python scripts/ci_promote.py test-prod --yes
```

This runs the same regression on ATP and then the same console click-through against
the ATP console (`--base-url` set to the ATP ORDS URL from `connections.json`) for
that ATP run. Both must pass. To repeat only the click-through for an existing ATP
run:

```bash
python scripts/ci_promote.py clickthrough-atp --run-id <ATP run id>
```

If either fails, the code is already on ATP: investigate immediately, and report it
to the owner rather than re-running until it goes green.

## Reporting

When done, report the commit SHA promoted, the local regression run id and verdict,
the local click-through result (steps passed out of total), the ATP run id and
verdict, and the ATP click-through result. If anything was refused or failed, say
which check and why, in plain words. A gate refusal is always reported to the owner;
it is never worked around.
