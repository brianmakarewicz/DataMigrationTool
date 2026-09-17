#!/usr/bin/env python3
"""
ci_promote.py - DMT2 CI/CD promotion pipeline (script-first).

The deterministic regression is the gate. Nothing reaches prod (ATP) until the
branch passes the same regression on local (TEST).

Pipeline (owner design 2026-09-17):
  1. deploy-local  - install the working tree's db/ into local Docker (idempotent).
  2. test-local    - run the deterministic regression on local. HARD GATE.
  3. merge         - merge the PR to main (only after test-local passes).
  4. deploy-prod   - deploy committed db/ (+ APEX) to ATP (gold).
  5. test-prod     - run the SAME regression on ATP to confirm the deploy.

Prefix leapfrog (so local and prod never push duplicate records to the shared
Fusion pod): ATP's DMT_RUN_PREFIX_SEQ is the single source of truth. For a local
test run we consume ATP.NEXTVAL = v and force the local sequence to issue v; the
prod run then consumes ATP.NEXTVAL = v+1 on its own. Distinct, monotonic, no
bookkeeping beyond "always draw from ATP" — i.e. "just use the ATP version".

Instances (from ~/workspace/connections.json; never hardcode creds):
  local (TEST) : dmt_owner  @ //localhost:1523/FREEPDB1   (Oracle Free 23ai + APEX 24.2)
  atp   (GOLD) : DMT2_OWNER @ queryapp_tp                 (ATP + APEX 26.1)

Examples:
  python scripts/ci_promote.py test-local                 # deploy branch to local + gate
  python scripts/ci_promote.py promote --pr 281           # full pipeline for a PR
  python scripts/ci_promote.py test-prod                  # re-verify prod only
  python scripts/ci_promote.py deploy-local               # just sync local from the tree

Safety: prod-affecting stages (deploy-prod, test-prod) require --yes (or the
PROMOTE_YES=1 env) so they never fire unattended by accident. test-prod and
test-local both write prefixed test records to the real Fusion demo pod — that
is what the regression does; the leapfrog keeps them from colliding.
"""
import argparse, glob, json, os, re, subprocess, sys, tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WS   = Path.home() / "workspace"
sys.path.insert(0, str(WS))

JDK  = "C:/Users/Monroe/tools/jdk-21.0.11+10"
SQLCL= "C:/Users/Monroe/tools/sqlcl/bin/sql.exe"

# ---------------------------------------------------------------- connections
def _conns():
    return json.loads((WS / "connections.json").read_text())

def _local():
    cfg = _conns()
    pw = (cfg.get("dmt2_local", {}) or {}).get("schemas", {}) \
             .get("DMT_OWNER", {}).get("password", "DmtLocal#2026")
    return {"schema": "DMT_OWNER", "pw": pw,
            "dsn": "//localhost:1523/FREEPDB1", "tns": None,
            "connstr": f"dmt_owner/{pw}@//localhost:1523/FREEPDB1"}

def _atp():
    q = _conns()["atp_queryapp"]
    pw = q["schemas"]["DMT2_OWNER"]["password"]
    return {"schema": "DMT2_OWNER", "pw": pw,
            "dsn": q["dsn"], "tns": q["wallet_dir"],
            "connstr": f"DMT2_OWNER/{pw}@{q['dsn']}"}

TARGET = {"local": _local, "atp": _atp}

# ---------------------------------------------------------------- sqlcl helper
def _sqlcl(target, script_text):
    env = dict(os.environ)
    env["JAVA_HOME"] = JDK
    env["PATH"] = f"{JDK}/bin:{os.path.dirname(SQLCL)}:" + env.get("PATH", "")
    t = TARGET[target]()
    if t["tns"]:
        env["TNS_ADMIN"] = t["tns"]
    if not script_text.rstrip().endswith("exit"):
        script_text += "\nexit\n"
    p = subprocess.run([SQLCL, "-s", t["connstr"]],
                       input=script_text, capture_output=True, text=True, env=env)
    return p.stdout + p.stderr

def _oracle(target):
    import oracledb
    t = TARGET[target]()
    kw = {}
    if t["tns"]:
        kw["config_dir"] = t["tns"]; kw["wallet_location"] = t["tns"]
        kw["wallet_password"] = _conns()["atp_queryapp"]["wallet_password"]
    return oracledb.connect(user=t["schema"], password=t["pw"], dsn=t["dsn"], **kw)

# ---------------------------------------------------------------- DB deploy
def deploy_db(target):
    """Idempotent sync of the working tree's db/ into an existing instance:
    tables (idempotent add_col/exception-wrapped), package specs, bodies, views,
    procedures, seeds - all continue-on-error - then recompile and assert 0 invalid.
    (install.sql is fresh-install only: it exits on the first 'already exists'.)"""
    order = []
    for pat in ("db/tables/*.sql", "db/packages/*.pks.sql", "db/packages/*.pkb.sql",
                "db/views/*.sql", "db/procedures/*.sql", "db/seed/*.sql"):
        order += sorted((REPO / p).as_posix() for p in
                        [q.relative_to(REPO).as_posix() for q in REPO.glob(pat)])
    lines = ["whenever sqlerror continue", "set define off", "set serveroutput off"]
    lines += [f"@@{f}" for f in order]
    lines += [
        "declare begin",
        "  for r in (select object_name,object_type from user_objects where status='INVALID') loop",
        "    begin",
        "      if r.object_type='PACKAGE BODY' then execute immediate 'alter package '||r.object_name||' compile body';",
        "      else execute immediate 'alter '||r.object_type||' '||r.object_name||' compile'; end if;",
        "    exception when others then null; end;",
        "  end loop;",
        "end;", "/",
        "set heading off",
        "select 'INVALID_AFTER_DEPLOY='||count(*) from user_objects where status='INVALID';",
        "exit",
    ]
    out = _sqlcl(target, "\n".join(lines) + "\n")
    m = re.search(r"INVALID_AFTER_DEPLOY=(\d+)", out)
    n = int(m.group(1)) if m else -1
    print(f"[deploy-db:{target}] invalid objects after deploy: {n}")
    if n != 0:
        print(out[-2000:])
    return n == 0

def deploy_apex(target):
    """APEX deploy. ATP import works from the git split baseline. Local import is
    blocked until local APEX (24.2) is upgraded to match ATP (26.1) - see the
    open owner decision - so local is skipped with a clear message, not silently."""
    if target == "local":
        print("[deploy-apex:local] SKIPPED - local APEX 24.2 < ATP 26.1; ATP export "
              "cannot import to local yet (owner decision pending). Local keeps app 172.")
        return True
    rc = subprocess.run([sys.executable, str(REPO / "scripts" / "apex_deploy.py"),
                         "import", "--target", "atp"]).returncode
    print(f"[deploy-apex:atp] {'OK' if rc == 0 else 'FAILED'}")
    return rc == 0

# ---------------------------------------------------------------- prefix leapfrog
def next_prefix_from_atp():
    """Consume ATP.DMT_RUN_PREFIX_SEQ.NEXTVAL - the single source of truth."""
    con = _oracle("atp"); cur = con.cursor()
    cur.execute("select DMT_RUN_PREFIX_SEQ.NEXTVAL from dual")
    v = int(cur.fetchone()[0]); con.close()
    print(f"[prefix] drew v={v} from ATP DMT_RUN_PREFIX_SEQ (source of truth)")
    return v

def force_local_prefix(v):
    """Make the LOCAL sequence issue exactly v next (23ai RESTART)."""
    _sqlcl("local", f"alter sequence DMT_RUN_PREFIX_SEQ restart start with {v};\nexit\n")
    print(f"[prefix] local DMT_RUN_PREFIX_SEQ set to issue {v} next")

# ---------------------------------------------------------------- regression
def run_regression(target, pipelines=None):
    """Run the deterministic regression against the target. Returns True on pass.
    pipelines: optional subset (e.g. 'HCM') passed to dmt_regression_run.py."""
    env = dict(os.environ)
    t = TARGET[target]()
    env["DMT2_CONN"] = f"{t['schema']}/{t['pw']}@{t['dsn'].replace('//','')}" \
        if target == "local" else f"{t['schema']}/{t['pw']}@{t['dsn']}"
    if t["tns"]:
        # dmt_regression_run.py reads the wallet from DMT2_WALLET / DMT2_WALLET_PW
        # (not TNS_ADMIN); set both so the ATP (prod) regression can connect.
        env["TNS_ADMIN"] = t["tns"]
        env["DMT2_WALLET"] = t["tns"]
        env["DMT2_WALLET_PW"] = _conns()["atp_queryapp"]["wallet_password"]
    cmd = [sys.executable, str(REPO / "scripts" / "dmt_regression_run.py")]
    if pipelines:
        cmd += ["--pipelines", pipelines]
    print(f"[regression:{target}] launching deterministic regression "
          f"({pipelines or 'ALL pipelines'}) ...")
    rc = subprocess.run(cmd, env=env).returncode
    print(f"[regression:{target}] {'PASS' if rc == 0 else 'FAIL'} (exit {rc})")
    return rc == 0

# ---------------------------------------------------------------- stages
def stage_deploy_local():
    ok = deploy_db("local") and deploy_apex("local")
    return ok

def stage_test_local(pipelines=None):
    if not stage_deploy_local():
        print("[test-local] deploy failed; not running regression"); return False
    v = next_prefix_from_atp()
    force_local_prefix(v)
    return run_regression("local", pipelines)

def stage_merge(pr):
    if not pr:
        print("[merge] no --pr given; skipping (merge manually or via pr-review.yml)"); return True
    rc = subprocess.run(["gh", "pr", "merge", str(pr), "--squash", "--admin"]).returncode
    print(f"[merge] PR #{pr} {'merged' if rc == 0 else 'merge FAILED'}")
    return rc == 0

def stage_deploy_prod(yes):
    if not yes:
        print("[deploy-prod] refusing without --yes (prod-affecting)"); return False
    subprocess.run(["git", "checkout", "main"], cwd=REPO)
    subprocess.run(["git", "pull", "--ff-only"], cwd=REPO)
    return deploy_db("atp") and deploy_apex("atp")

def stage_test_prod(yes, pipelines=None):
    if not yes:
        print("[test-prod] refusing without --yes (writes test data to Fusion from prod)"); return False
    return run_regression("atp", pipelines)  # ATP pulls its own NEXTVAL = v+1

def main():
    ap = argparse.ArgumentParser(description="DMT2 CI/CD promotion pipeline")
    ap.add_argument("stage", choices=["deploy-local", "test-local", "merge",
                                      "deploy-prod", "test-prod", "promote"])
    ap.add_argument("--pr", type=int, help="PR number to merge in the promote flow")
    ap.add_argument("--yes", action="store_true",
                    help="authorize prod-affecting stages (or set PROMOTE_YES=1)")
    ap.add_argument("--pipelines", help="regression pipeline subset, e.g. HCM (default: all)")
    a = ap.parse_args()
    yes = a.yes or os.environ.get("PROMOTE_YES") == "1"

    if a.stage == "deploy-local":  sys.exit(0 if stage_deploy_local() else 1)
    if a.stage == "test-local":    sys.exit(0 if stage_test_local(a.pipelines) else 1)
    if a.stage == "merge":         sys.exit(0 if stage_merge(a.pr) else 1)
    if a.stage == "deploy-prod":   sys.exit(0 if stage_deploy_prod(yes) else 1)
    if a.stage == "test-prod":     sys.exit(0 if stage_test_prod(yes, a.pipelines) else 1)

    # promote: full pipeline with the deterministic gate
    print("=== PROMOTE: test-local (gate) -> merge -> deploy-prod -> test-prod ===")
    if not stage_test_local(a.pipelines):
        sys.exit("GATE FAILED on local regression - not merging, not deploying.")
    if not stage_merge(a.pr):
        sys.exit("Merge failed - stopping before prod.")
    if not stage_deploy_prod(yes):
        sys.exit("Prod deploy failed.")
    if not stage_test_prod(yes, a.pipelines):
        sys.exit("PROD REGRESSION FAILED after deploy - investigate immediately.")
    print("=== PROMOTE complete: local passed, merged, deployed to ATP, prod verified. ===")

if __name__ == "__main__":
    main()
