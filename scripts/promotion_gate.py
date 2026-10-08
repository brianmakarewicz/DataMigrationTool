#!/usr/bin/env python3
"""
promotion_gate.py - the hard gate in front of every DMT2 promotion to ATP (GOLD).

The owner's rule: nothing is promoted to ATP unless BOTH of these passed locally
for the exact code being promoted:
  1. a full local regression run (scripts/dmt_regression_run.py, all pipelines,
     verdict PASS / exit 0), and
     (owner decision 2026-10-08: "if something never passed before, I don't want
     to hold everything up" - verdict 'PASS (known review items only)' / exit 0 is
     also accepted. The harness gives it only when there are zero failures and
     every review item is a never-passed item listed in
     scripts/regression_known_review.json; any NEW review item still blocks.)
  2. the Playwright console click-through for that same run id
     (test/playwright/dmt_console_verify.py --run-id N, verdict PASS).

This module records that evidence and checks it. It deliberately has no
database or network dependency, so the gate itself can be tested offline.

Where the evidence lives
------------------------
A small JSON file plus an append-only log, both under a gitignored directory at
the repo root:

    .ci_evidence/promotion_evidence.json   latest evidence per step
    .ci_evidence/promotion_log.jsonl       every record + every gate decision

DMT2_PROMOTE_EVIDENCE_DIR points both at another directory (used by the gate's
own tests so fake evidence never lands in the repo). Pointing it elsewhere does
not weaken the gate: the evidence found there must still match the commit.

How evidence is tied to the code
--------------------------------
Every record stores the git commit SHA, the git tree SHA (a hash of the exact
file contents) and whether the working tree had uncommitted changes in it when
the step ran. The gate accepts evidence for the commit being promoted when the
commit SHA matches, or when the tree SHA matches. The tree match exists for one
reason: the PR reviewer squash-merges, so main gets a new commit SHA whose files
are byte-for-byte identical to the branch commit the regression ran on. Any
difference in any file changes the tree SHA, so the gate still refuses.

To get past the gate, run the regression and the click-through on the code you
want to promote.

The owner override (owner only, never agents or CI)
---------------------------------------------------
The owner (2026-10-07) kept the gate strict and allowed exactly one exception: an
explicit override by the owner personally, `ci_promote.py deploy-prod --yes
--owner-override "<reason>"`. It is deliberately narrow:
  * it waives ONLY regression and click-through failures. Missing or failed local
    deploy evidence, a dirty working tree, or missing/unreadable evidence are
    never waivable;
  * it needs a non-empty reason;
  * it needs an interactive typed confirmation: the person types the short SHA of
    the commit being promoted. stdin must be a real terminal (TTY), so an agent,
    a pipe or CI cannot use it;
  * every attempt, accepted or refused, is printed loudly and appended to
    promotion_log.jsonl with the reason, SHA, git user, time and the failing
    checks it bypassed.
Agents must never use it: a gate refusal is reported to the owner.
"""
import datetime as _dt
import getpass
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# A full regression covers at least every one of these pipelines (extra ones,
# e.g. CONFIGURATION, are fine). A subset run (e.g. --pipelines HCM) is useful
# while developing but is never promotion evidence.
FULL_PIPELINES = "P2P,O2C,FINANCIALS,PROJECTS,HCM"

# Evidence older than this is stale: the local stack, Fusion data, or
# credentials may have moved on since. 24 hours covers "regress in the
# afternoon, promote the next morning" without letting week-old proof through.
MAX_EVIDENCE_AGE_HOURS = 24

# Regression verdicts that count as a pass (always together with exit code 0).
# The second exists only for known, never-passed review items (owner decision
# 2026-10-08; see scripts/regression_known_review.json). Nothing else passes.
PASSING_REGRESSION_VERDICTS = ("PASS", "PASS (known review items only)")

UNTRACKED_MATTERS = ("db/", "apex/", "bip/", "scripts/", "test/")

LOCAL_UI_PREFIXES =("http://localhost", "http://127.0.0.1")

EVIDENCE_FILE = "promotion_evidence.json"
LOG_FILE = "promotion_log.jsonl"
SCHEMA_VERSION = 1

# Gate checks are grouped so the owner override can tell which failures it may
# waive. Only these two groups are waivable; everything else (local deploy,
# dirty tree, missing or unreadable evidence) always blocks.
WAIVABLE = ("regression", "clickthrough")


# ---------------------------------------------------------------- locations
def evidence_dir():
    d = os.environ.get("DMT2_PROMOTE_EVIDENCE_DIR")
    return Path(d) if d else REPO / ".ci_evidence"


def _now():
    return _dt.datetime.now(_dt.timezone.utc)


def _iso(ts):
    return ts.astimezone(_dt.timezone.utc).isoformat(timespec="seconds")


def _parse(ts):
    if not ts:
        return None
    try:
        t = _dt.datetime.fromisoformat(ts)
    except (TypeError, ValueError):
        return None
    return t if t.tzinfo else t.replace(tzinfo=_dt.timezone.utc)


# ---------------------------------------------------------------- git identity
def _git(*args, cwd=None):
    p = subprocess.run(["git", *args], cwd=cwd or REPO,
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {p.stderr.strip()}")
    return p.stdout.strip()


def code_identity(cwd=None):
    """The commit and tree SHA of HEAD, plus the list of uncommitted changes.

    Any modified tracked file counts as a change. Untracked files count when
    they sit in a directory whose contents get deployed or executed (db/,
    apex/, bip/, scripts/, test/): deploy-local globs db/**/*.sql from the
    working tree, so an untracked .sql file there would be deployed and tested
    without being part of the commit. Gitignored paths (including the evidence
    directory) never appear in git status."""
    commit = _git("rev-parse", "HEAD", cwd=cwd)
    tree = _git("rev-parse", "HEAD^{tree}", cwd=cwd)
    status = _git("status", "--porcelain", "--untracked-files=all", cwd=cwd)
    changes = []
    for ln in status.splitlines():
        if not ln.strip():
            continue
        if ln.startswith("??") and not ln[3:].lstrip('"').startswith(UNTRACKED_MATTERS):
            continue
        changes.append(ln)
    return {"commit": commit, "tree": tree,
            "dirty": bool(changes), "dirty_files": changes[:20]}


# ---------------------------------------------------------------- storage
def load_evidence():
    f = evidence_dir() / EVIDENCE_FILE
    if not f.exists():
        return None
    try:
        return json.loads(f.read_text(encoding="utf-8"))
    except ValueError as e:
        return {"_unreadable": str(e)}


def _save_evidence(ev):
    d = evidence_dir()
    d.mkdir(parents=True, exist_ok=True)
    tmp = d / (EVIDENCE_FILE + ".tmp")
    tmp.write_text(json.dumps(ev, indent=2), encoding="utf-8")
    os.replace(tmp, d / EVIDENCE_FILE)


def log_event(event):
    """Append one line to the durable promotion log. Never rewritten."""
    d = evidence_dir()
    d.mkdir(parents=True, exist_ok=True)
    event = dict(event)
    event.setdefault("at", _iso(_now()))
    with open(d / LOG_FILE, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(event) + "\n")


def record(step, data, identity=None):
    """Record evidence for one step (deploy_local, regression,
    clickthrough_local, clickthrough_atp). Overwrites the previous evidence for
    that step and appends to the log."""
    ident = identity or code_identity()
    entry = dict(data)
    entry.update(commit=ident["commit"], tree=ident["tree"],
                 dirty=ident["dirty"], dirty_files=ident.get("dirty_files", []))
    entry.setdefault("at", _iso(_now()))
    ev = load_evidence() or {}
    if "_unreadable" in ev:
        ev = {}
    ev["schema"] = SCHEMA_VERSION
    ev[step] = entry
    _save_evidence(ev)
    log_event({"event": "record", "step": step, **entry})
    return entry


# ---------------------------------------------------------------- the gate
def _same_code(entry, ident):
    """Return (matches, how)."""
    if entry.get("commit") == ident["commit"]:
        return True, "commit SHA matches"
    if entry.get("tree") and entry.get("tree") == ident["tree"]:
        return True, (f"tree SHA matches (commit {entry.get('commit', '?')[:12]} "
                      f"has identical files, e.g. a squash merge)")
    return False, (f"evidence is for commit {str(entry.get('commit'))[:12]} "
                   f"(tree {str(entry.get('tree'))[:12]}), promoting commit "
                   f"{ident['commit'][:12]} (tree {ident['tree'][:12]})")


def check_gate(ident=None, now=None, evidence=None):
    """Decide whether the code at `ident` may be promoted.

    Returns (ok, lines): ok is True only when every check passed; lines is a
    human-readable explanation, one check per line, suitable for printing."""
    ok, lines, _ = check_gate_detail(ident, now, evidence)
    return ok, lines


def check_gate_detail(ident=None, now=None, evidence=None):
    """check_gate plus the failing checks as (group, message) pairs, where
    group is one of: general, deploy, regression, clickthrough."""
    ident = ident or code_identity()
    now = now or _now()
    ev = evidence if evidence is not None else load_evidence()
    lines, ok = [], True
    failures = []
    group = "general"

    def fail(msg):
        nonlocal ok
        ok = False
        failures.append((group, msg))
        lines.append("  REFUSED  " + msg)

    def good(msg):
        lines.append("  ok       " + msg)

    lines.append(f"  promoting commit {ident['commit']} (tree {ident['tree']})")
    if ident["dirty"]:
        fail("working tree has uncommitted or untracked changes, so the commit "
             "SHA does not describe the code that would be deployed: "
             + "; ".join(ident.get("dirty_files", [])[:5]))

    where = evidence_dir() / EVIDENCE_FILE
    if not ev:
        fail(f"no promotion evidence found at {where}. Run the full local "
             f"regression and the local click-through first "
             f"(python scripts/ci_promote.py test-local).")
        return False, lines, failures
    if "_unreadable" in ev:
        fail(f"promotion evidence at {where} is unreadable: {ev['_unreadable']}")
        return False, lines, failures

    max_age = _dt.timedelta(hours=MAX_EVIDENCE_AGE_HOURS)

    # ---- 1. local deploy of this code -----------------------------------
    group = "deploy"
    dep = ev.get("deploy_local")
    if not dep:
        fail("no record that this code was deployed to the local DB "
             "(python scripts/ci_promote.py deploy-local)")
    else:
        same, how = _same_code(dep, ident)
        (good if same else fail)(f"local deploy: {how}")
        if not dep.get("ok"):
            fail("local deploy did not finish clean (invalid objects after deploy)")
        if dep.get("dirty"):
            fail("local deploy ran from a working tree with uncommitted changes")

    # ---- 2. full local regression ---------------------------------------
    group = "regression"
    reg = ev.get("regression")
    reg_end = None
    if not reg:
        fail("no local regression evidence (python scripts/ci_promote.py regression-local)")
    else:
        rid = reg.get("run_id")
        same, how = _same_code(reg, ident)
        (good if same else fail)(f"regression run {rid}: {how}")
        if reg.get("target") != "local":
            fail(f"regression run {rid} ran on '{reg.get('target')}', not local")
        ran = {p.strip() for p in str(reg.get("pipelines") or "").split(",") if p.strip()}
        missing = [p for p in FULL_PIPELINES.split(",") if p not in ran]
        if missing:
            fail(f"regression run {rid} covered pipelines '{reg.get('pipelines')}', "
                 f"missing {','.join(missing)} from the full set {FULL_PIPELINES}")
        if reg.get("exit_code") != 0 or reg.get("verdict") not in PASSING_REGRESSION_VERDICTS:
            fail(f"regression run {rid} did not pass: verdict "
                 f"'{reg.get('verdict')}', exit code {reg.get('exit_code')}")
        else:
            good(f"regression run {rid} verdict {reg.get('verdict')} (exit 0)"
                 + (f", {reg.get('known_review')} known pre-existing review item(s)"
                    if reg.get("known_review") else ""))
        if reg.get("dirty"):
            fail(f"regression run {rid} ran from a working tree with uncommitted changes")
        if not rid:
            fail("regression evidence has no run id")
        reg_end = _parse(reg.get("finished_at"))
        if not reg_end:
            fail("regression evidence has no finish time")
        elif now - reg_end > max_age:
            fail(f"regression run {rid} is stale: finished {reg.get('finished_at')}, "
                 f"older than {MAX_EVIDENCE_AGE_HOURS}h")
        elif reg_end > now + _dt.timedelta(minutes=5):
            fail(f"regression run {rid} finish time {reg.get('finished_at')} is in the future")
        else:
            good(f"regression run {rid} is recent (finished {reg.get('finished_at')})")
        if dep and reg_end:
            dep_at = _parse(dep.get("at"))
            reg_start = _parse(reg.get("started_at")) or reg_end
            if dep_at and dep_at > reg_start:
                fail(f"local deploy ({dep.get('at')}) happened after regression run "
                     f"{rid} started ({reg.get('started_at')}), so the run did not "
                     f"test the deployed code")

    # ---- 3. local click-through for the same run ------------------------
    group = "clickthrough"
    ct = ev.get("clickthrough_local")
    if not ct:
        fail("no local console click-through evidence "
             "(python scripts/ci_promote.py clickthrough-local)")
    else:
        same, how = _same_code(ct, ident)
        (good if same else fail)(f"local click-through: {how}")
        if reg and str(ct.get("run_id")) != str(reg.get("run_id")):
            fail(f"local click-through drilled run {ct.get('run_id')}, but the "
                 f"regression evidence is run {reg.get('run_id')}")
        if not str(ct.get("base_url", "")).startswith(LOCAL_UI_PREFIXES):
            fail(f"click-through ran against {ct.get('base_url')}, not the local console")
        if ct.get("exit_code") != 0 or ct.get("verdict") != "PASS":
            fail(f"local click-through for run {ct.get('run_id')} did not pass: "
                 f"verdict '{ct.get('verdict')}', exit code {ct.get('exit_code')}")
        else:
            good(f"local click-through for run {ct.get('run_id')} verdict PASS "
                 f"({ct.get('steps_passed')}/{ct.get('steps_total')} steps)")
        if ct.get("dirty"):
            fail("local click-through ran from a working tree with uncommitted changes")
        ct_at = _parse(ct.get("at"))
        if not ct_at:
            fail("click-through evidence has no time")
        else:
            if now - ct_at > max_age:
                fail(f"local click-through is stale: ran {ct.get('at')}, "
                     f"older than {MAX_EVIDENCE_AGE_HOURS}h")
            if reg_end and ct_at < reg_end:
                fail(f"local click-through ({ct.get('at')}) ran before regression "
                     f"run {reg.get('run_id')} finished ({reg.get('finished_at')})")

    return ok, lines, failures


# ---------------------------------------------------------------- owner override
def git_user():
    """Who is at the keyboard, as git knows them (name <email>), plus the OS
    login, for the override log."""
    parts = []
    for key in ("user.name", "user.email"):
        try:
            parts.append(_git("config", key))
        except RuntimeError:
            parts.append("?")
    try:
        os_user = getpass.getuser()
    except Exception:  # noqa: BLE001 - best effort only
        os_user = "?"
    return f"{parts[0]} <{parts[1]}> (os user {os_user})"


def authorize_owner_override(reason, ident, failures, stdin=None,
                             ask=None, user=None):
    """Decide whether the owner override may waive this gate refusal.

    Returns (accepted, message). Refuses unless: stdin is an interactive TTY,
    the reason is non-empty, every failing check is a waivable one
    (regression / click-through), and the person types the commit's short SHA.
    Every attempt is logged to promotion_log.jsonl. `stdin`, `ask` (the prompt
    function) and `user` exist so the tests can drive it."""
    stdin = stdin if stdin is not None else sys.stdin
    ask = ask or input
    short = ident["commit"][:7]
    bypassed = [m for g, m in failures if g in WAIVABLE]
    blocking = [m for g, m in failures if g not in WAIVABLE]
    who = user or git_user()

    def done(accepted, why):
        log_event({"event": "owner_override",
                   "decision": "ACCEPTED" if accepted else "REFUSED",
                   "why": why, "reason": (reason or "").strip(),
                   "commit": ident["commit"], "short_sha": short,
                   "tree": ident["tree"], "git_user": who,
                   "bypassed_checks": bypassed if accepted else [],
                   "failing_checks": [m for _, m in failures]})
        return accepted, why

    try:
        tty = bool(stdin.isatty())
    except Exception:  # noqa: BLE001 - a closed or odd stdin is not a TTY
        tty = False
    if not tty:
        return done(False, "stdin is not an interactive terminal; the owner "
                           "override is for the owner at a keyboard only, never "
                           "agents, pipes or CI")
    if not (reason or "").strip():
        return done(False, "the owner override needs a non-empty reason")
    if blocking:
        return done(False, "the owner override only waives regression and "
                           "click-through failures; these still block: "
                           + "; ".join(blocking))
    if not bypassed:
        return done(False, "nothing to override: no failing gate checks")
    print("!" * 72)
    print("OWNER OVERRIDE REQUESTED. This deploys to ATP WITHOUT a clean "
          "regression and click-through.")
    print(f"  reason: {reason.strip()}")
    print(f"  by:     {who}")
    print("  checks that would be bypassed:")
    for m in bypassed:
        print(f"    - {m}")
    print("!" * 72)
    try:
        typed = ask(f"Type the short SHA of the commit being promoted ({short}) "
                    f"to confirm: ")
    except EOFError:
        typed = ""
    typed = (typed or "").strip().lower()
    if len(typed) < 7 or not ident["commit"].lower().startswith(typed):
        return done(False, f"typed confirmation '{typed}' does not match commit "
                           f"{short}")
    return done(True, f"owner override accepted for commit {short}")


def _reg_field(key):
    """One field of the recorded regression evidence, for the promotion log."""
    ev = load_evidence() or {}
    return (ev.get("regression") or {}).get(key) if isinstance(ev, dict) else None


def enforce(ident=None, stage="deploy-prod", owner_override=None,
            stdin=None, ask=None, user=None):
    """Print the gate decision, log it durably, and return True/False.

    owner_override: the owner's reason string (deploy-prod only). It is only
    consulted when the gate refuses; see authorize_owner_override."""
    ident = ident or code_identity()
    ok, lines, failures = check_gate_detail(ident)
    banner = "PASSED" if ok else "REFUSED"
    print("=" * 72)
    print(f"PROMOTION GATE {banner} ({stage})")
    print("\n".join(lines))
    print(f"  evidence: {evidence_dir() / EVIDENCE_FILE}")
    print("=" * 72)
    log_event({"event": "gate", "stage": stage, "decision": banner,
               "commit": ident["commit"], "tree": ident["tree"],
               "dirty": ident["dirty"],
               "regression_verdict": _reg_field("verdict"),
               "regression_known_review": _reg_field("known_review"),
               "regression_new_review": _reg_field("new_review"),
               "known_review_file_sha256": _reg_field("known_review_file_sha256"),
               "reasons": [l.strip() for l in lines if "REFUSED" in l]})
    if ok or owner_override is None:
        if ok and owner_override is not None:
            print("  (owner override not needed: the gate passed on its own, "
                  "so nothing is logged as an override)")
        return ok
    accepted, why = authorize_owner_override(owner_override, ident, failures,
                                             stdin=stdin, ask=ask, user=user)
    print("!" * 72)
    if accepted:
        print(f"PROMOTION GATE OVERRIDDEN BY OWNER ({stage}): {why}")
        print(f"  reason: {owner_override.strip()}")
        print(f"  logged to {evidence_dir() / LOG_FILE}")
    else:
        print(f"OWNER OVERRIDE REFUSED ({stage}): {why}")
    print("!" * 72)
    return accepted


if __name__ == "__main__":
    import sys
    sys.exit(0 if enforce(stage="gate (check only)") else 1)
