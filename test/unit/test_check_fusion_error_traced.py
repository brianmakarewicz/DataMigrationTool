#!/usr/bin/env python3
"""Offline test of the [FUSION_ERROR] assignment tracing in
scripts/check_sweep_unaccounted.py (rule SWEEP-FUSION-ERROR-FORM, backlog #601).

Design section 5, the [FUSION_ERROR] tag row: "The single permitted construction is
'[FUSION_ERROR]' || l_fusion_error ... No status code, observation, or 'cannot
verify'-style sentence may ever accompany this tag". The checker already caught such
text written as a literal next to the tag; this proves it now also catches it when the
text is built in a local variable first (one level of assignment tracing), and that
it does not flag separators between real Fusion fields, pattern arguments, a variable
of the same name in another subprogram, the sanctioned related-record prefix, or a
function call. It also proves the extension traces real assignments on current main
and finds no violation there. No database needed.

    python test/unit/test_check_fusion_error_traced.py
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import check_sweep_unaccounted as chk  # noqa: E402
import standards_sql_lineage as lineage  # noqa: E402

FLAGGED = {
    "the backlog example (l_msg := 'transport failed: ' || x)":
        "PROCEDURE p IS l_msg VARCHAR2(400); BEGIN l_msg := 'transport failed: ' || x; "
        "UPDATE t SET e = APPEND_ERROR(e, '[FUSION_ERROR] ' || l_msg); END;",
    "a declaration initializer":
        "PROCEDURE p IS l_msg VARCHAR2(400) := 'HTTP ' || l_code; BEGIN "
        "x := '[FUSION_ERROR] ' || l_msg; END;",
    "a bare sentence assigned":
        "PROCEDURE p IS BEGIN l_m := 'could not verify'; x := '[FUSION_ERROR] '||l_m; END;",
    "composed text wrapped in SUBSTR":
        "PROCEDURE p IS BEGIN l_m := SUBSTR('upload failed: ' || y, 1, 4000); "
        "x := '[FUSION_ERROR] '||l_m; END;",
    "the tag held in a constant":
        "PROCEDURE p IS c_fe CONSTANT VARCHAR2(20) := '[FUSION_ERROR] '; BEGIN "
        "l_m := 'boom ' || y; x := c_fe || l_m; END;",
}
CLEAN = {
    "separators between real Fusion fields":
        "PROCEDURE p IS BEGIN l_m := l_m || ' | '; l_m := a || ': ' || b; "
        "x := '[FUSION_ERROR] '||l_m; END;",
    "a pattern argument of REGEXP_SUBSTR":
        "PROCEDURE p IS BEGIN l_m := REGEXP_SUBSTR(c, 'Error on[^'||CHR(10)||']*'); "
        "x := '[FUSION_ERROR] '||l_m; END;",
    "the same name assigned in another subprogram":
        "PROCEDURE a IS BEGIN l_m := 'mine ' || y; END; "
        "PROCEDURE b IS BEGIN l_m := z; x := '[FUSION_ERROR] '||l_m; END;",
    "the sanctioned related-record prefix":
        "PROCEDURE p IS BEGIN l_m := 'The parent record has the following Fusion error: ' || y; "
        "x := '[FUSION_ERROR] '||l_m; END;",
    "a function call after the tag (not a variable)":
        "PROCEDURE p IS BEGIN x := '[FUSION_ERROR] '||get_err('abc' || y); END;",
    "a real error copied from the report":
        "PROCEDURE p IS BEGIN l_m := r.error_message; x := '[FUSION_ERROR] '||l_m; END;",
}


def main():
    checks = []
    for name, text in FLAGGED.items():
        checks.append(("flags " + name, len(chk.check_fusion_error_traced("x.pkb.sql", text)) == 1))
    for name, text in CLEAN.items():
        checks.append(("does not flag " + name,
                       chk.check_fusion_error_traced("x.pkb.sql", text) == []))

    traced, found = 0, []
    follow = re.compile(chk.FE_VAR_FOLLOW_RE % "", re.I)
    for path in chk.scan_files():
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = lineage.strip_comments(fh.read())
        for m in follow.finditer(text):
            a, b = chk._subprogram_span(text, m.start())
            traced += len(chk._assignments(text, m.group(1), a, b))
        found += chk.check_fusion_error_traced(path, text)
    checks.append(("current main: assignments are actually traced (%d)" % traced, traced > 0))
    checks.append(("current main: no composed [FUSION_ERROR] via a variable", found == []))

    bad = 0
    for name, ok in checks:
        bad += 0 if ok else 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    print(f"\n{len(checks) - bad}/{len(checks)} checks passed")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
