#!/usr/bin/env python3
"""
test_promotion_gate.py - offline proof that the ATP promotion gate refuses and
accepts for the right reasons.

Writes FAKE evidence into a throwaway temp directory (DMT2_PROMOTE_EVIDENCE_DIR),
never into the repo's .ci_evidence/, and deletes it afterwards. Needs no
database, no browser and no network: only git, for the current commit's SHAs.

    python test/unit/test_promotion_gate.py

Exit 0 when every scenario got the expected decision, 1 otherwise.
"""
import datetime as dt
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import promotion_gate as gate  # noqa: E402

NOW = dt.datetime.now(dt.timezone.utc)


def iso(hours_ago):
    return (NOW - dt.timedelta(hours=hours_ago)).isoformat(timespec="seconds")


def good_evidence(commit, tree, run_id=412):
    """Evidence a real test-local would leave: deploy, then a full PASS
    regression, then a PASS click-through of that same run."""
    base = {"commit": commit, "tree": tree, "dirty": False, "dirty_files": []}
    return {
        "schema": 1,
        "deploy_local": {**base, "ok": True, "at": iso(3.0)},
        "regression": {**base, "ok": True, "run_id": run_id, "verdict": "PASS",
                       "exit_code": 0, "target": "local",
                       "pipelines": "P2P,O2C,FINANCIALS,PROJECTS,HCM",
                       "started_at": iso(2.9), "finished_at": iso(1.5),
                       "at": iso(1.5)},
        "clickthrough_local": {**base, "ok": True, "run_id": run_id,
                               "verdict": "PASS", "exit_code": 0,
                               "base_url": "http://localhost:8182/ords",
                               "steps_total": 41, "steps_passed": 41,
                               "failed_steps": [], "at": iso(1.0)},
    }


def main():
    real = gate.code_identity()
    # Judge the evidence logic against a clean identity for the real HEAD;
    # the dirty-tree refusal is exercised separately below.
    ident = {"commit": real["commit"], "tree": real["tree"],
             "dirty": False, "dirty_files": []}
    other = "0" * 40

    def mutate(fn):
        ev = good_evidence(ident["commit"], ident["tree"])
        fn(ev)
        return ev

    scenarios = [
        ("no evidence at all", None, ident, False),
        ("stale: regression finished 30h ago",
         mutate(lambda e: (e["regression"].update(started_at=iso(31), finished_at=iso(30)),
                           e["deploy_local"].update(at=iso(32)))), ident, False),
        ("evidence is for a different commit and tree",
         mutate(lambda e: [e[k].update(commit=other, tree=other)
                           for k in ("deploy_local", "regression", "clickthrough_local")]),
         ident, False),
        ("click-through drilled a different run id",
         mutate(lambda e: e["clickthrough_local"].update(run_id=411)), ident, False),
        ("click-through failed",
         mutate(lambda e: e["clickthrough_local"].update(verdict="FAIL", exit_code=1)),
         ident, False),
        ("click-through ran before the regression finished",
         mutate(lambda e: e["clickthrough_local"].update(at=iso(2.0))), ident, False),
        ("click-through ran against ATP, not local",
         mutate(lambda e: e["clickthrough_local"].update(
             base_url="https://example.adb.oraclecloudapps.com/ords")), ident, False),
        ("regression verdict 'PASS (with review items)' (exit 2)",
         mutate(lambda e: e["regression"].update(verdict="PASS (with review items)",
                                                 exit_code=2)), ident, False),
        ("regression was a subset (--pipelines HCM)",
         mutate(lambda e: e["regression"].update(pipelines="HCM")), ident, False),
        ("deploy-local happened after the regression started",
         mutate(lambda e: e["deploy_local"].update(at=iso(2.0))), ident, False),
        ("working tree has uncommitted changes",
         good_evidence(ident["commit"], ident["tree"]),
         {**ident, "dirty": True, "dirty_files": [" M db/packages/x.pkb.sql"]}, False),
        ("MATCHING evidence for this commit", good_evidence(ident["commit"], ident["tree"]),
         ident, True),
        ("MATCHING tree after a squash merge (new commit SHA, identical files)",
         good_evidence(other, ident["tree"]), ident, True),
        ("full set plus CONFIGURATION",
         mutate(lambda e: e["regression"].update(
             pipelines="P2P,O2C,FINANCIALS,PROJECTS,HCM,CONFIGURATION")), ident, True),
    ]

    tmp = tempfile.mkdtemp(prefix="dmt2_gate_test_")
    os.environ["DMT2_PROMOTE_EVIDENCE_DIR"] = tmp
    failures = 0
    try:
        for name, ev, who, expect in scenarios:
            f = Path(tmp) / gate.EVIDENCE_FILE
            if f.exists():
                f.unlink()
            if ev is not None:
                f.write_text(json.dumps(ev), encoding="utf-8")
            ok, lines = gate.check_gate(ident=who, now=NOW)
            verdict = "ACCEPTED" if ok else "REFUSED"
            right = ok == expect
            failures += 0 if right else 1
            print(f"[{'PASS' if right else 'WRONG'}] {name}: gate {verdict} "
                  f"(expected {'ACCEPTED' if expect else 'REFUSED'})")
            for ln in lines:
                if "REFUSED" in ln or ok:
                    print("      " + ln.strip())
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"\n{len(scenarios) - failures}/{len(scenarios)} scenarios decided correctly")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
