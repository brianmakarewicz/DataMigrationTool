#!/usr/bin/env python3
"""
test_subprocess_decode.py - offline proof of the SQLcl output decode guard
(backlog 646).

`ci_promote.py test-local` crashed in deploy_db -> _sqlcl: subprocess.run(...,
text=True) decoded SQLcl's output with the Windows default cp1252, hit byte 0x9d
(undefined in cp1252; it is the last byte of a UTF-8 right double quote), the
reader thread died so p.stdout was None, and `p.stdout + p.stderr` raised
TypeError. Both _sqlcl helpers (ci_promote, apex_deploy) now decode UTF-8 with
errors='replace' and tolerate a None stream.

The "SQLcl" here is a tiny Python child that writes raw bytes, so this never
touches a database. Needs no network.

    python test/unit/test_subprocess_decode.py

Exit 0 when every scenario passes, 1 otherwise.
"""
import subprocess
import sys
import tempfile
import types
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import ci_promote as cp  # noqa: E402
import apex_deploy as ad  # noqa: E402

# 0x9d alone, a UTF-8 right double quote (e2 80 9d), and a cp1252-undefined 0x81.
PAYLOAD = b"before \x9d mid \xe2\x80\x9d after \x81 INVALID_AFTER_DEPLOY=0\n"

CHILD = (
    "import sys\n"
    "sys.stdin.read()\n"
    f"sys.stdout.buffer.write({PAYLOAD!r})\n"
    "sys.stderr.buffer.write(b'err \\x9d\\n')\n"
)

failures = []


def check(name, cond, detail=""):
    print(f"{'PASS' if cond else 'FAIL'}  {name}"
          + (f"  ({detail})" if detail and not cond else ""))
    if not cond:
        failures.append(name)


def main():
    with tempfile.TemporaryDirectory() as td:
        child = Path(td) / "fake_sqlcl.py"
        child.write_text(CHILD, encoding="utf-8")

        # 1. _combined_output tolerates None streams (the reader-thread-died case).
        dead = types.SimpleNamespace(stdout=None, stderr=None)
        check("combined_output(None, None) == ''", cp._combined_output(dead) == "")
        half = types.SimpleNamespace(stdout="abc", stderr=None)
        check("combined_output('abc', None) == 'abc'",
              cp._combined_output(half) == "abc")

        # 2. ci_promote._sqlcl: [SQLCL, "-s", connstr] becomes
        #    [python, "-s", fake_sqlcl.py]; no cp1252 crash, marker survives.
        cp.SQLCL = sys.executable
        cp.TARGET["fake"] = lambda: {"tns": None, "connstr": str(child)}
        try:
            out = cp._sqlcl("fake", "select 1 from dual;\n")
            check("ci_promote._sqlcl returns str", isinstance(out, str))
            check("ci_promote._sqlcl keeps INVALID_AFTER_DEPLOY marker",
                  "INVALID_AFTER_DEPLOY=0" in out, repr(out))
            check("ci_promote._sqlcl keeps the real right double quote",
                  "”" in out, repr(out))
            check("ci_promote._sqlcl includes stderr", "err" in out, repr(out))
        except Exception as e:  # the regression itself
            check("ci_promote._sqlcl does not raise", False, repr(e))

        # 3. apex_deploy._sqlcl: same, by redirecting its "sql" command to the child.
        real_run = subprocess.run

        def fake_run(cmd, *a, **kw):
            return real_run([sys.executable, str(child)], *a, **kw)

        ad.subprocess.run = fake_run
        try:
            rc, out = ad._sqlcl("S", "pw", "dsn", None, "select 1 from dual;\n")
            check("apex_deploy._sqlcl rc == 0", rc == 0, rc)
            check("apex_deploy._sqlcl keeps marker",
                  "INVALID_AFTER_DEPLOY=0" in out, repr(out))
        except Exception as e:
            check("apex_deploy._sqlcl does not raise", False, repr(e))
        finally:
            ad.subprocess.run = real_run

        # 4. Control: the old call shape really does lose stdout under cp1252.
        #    (Silence the expected reader-thread traceback.)
        import threading
        saved_hook = threading.excepthook
        threading.excepthook = lambda args: None
        try:
            p = real_run([sys.executable, str(child)], input="", capture_output=True,
                         text=True, encoding="cp1252")
        finally:
            threading.excepthook = saved_hook
        check("control: cp1252 decode loses stdout (old crash shape)",
              p.stdout is None, repr(p.stdout))

    print(f"\n{'ALL PASS' if not failures else f'{len(failures)} FAILED'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
