#!/usr/bin/env python3
"""
test_check_fbdi_upload_mappings.py - offline proof of scripts/check_fbdi_upload_mappings.py,
the CI rule that every FBDI file a generator writes is registered for FBDI upload
(backlog #792).

What it proves (no database, no Fusion):
  * the committed repository passes (exit 0);
  * a generator writing a .csv file that is not registered fails as FBDI-UPLOAD-REG;
  * a .csv name that appears only in a comment is ignored;
  * an allowlisted file (EpbcsDataImport.csv, PlanningBudgets) does not fail;
  * a committed seed that differs from the maps fails as FBDI-UPLOAD-SEED-SYNC.

    python test/unit/test_check_fbdi_upload_mappings.py
"""
import contextlib
import io
import shutil
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import check_fbdi_upload_mappings as chk  # noqa: E402

passed = failed = 0


def check(cond, name):
    global passed, failed
    if cond:
        passed += 1
        print(f"PASS  {name}")
    else:
        failed += 1
        print(f"FAIL  {name}")


def run():
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        rc = chk.main()
    return rc, out.getvalue()


rc, _ = run()
check(rc == 0, "committed repository passes")

real_pkg_dir, real_seed = chk.PKG_DIR, chk.SEED
tmp = Path(tempfile.mkdtemp())
try:
    pkgs = tmp / "packages"
    pkgs.mkdir()
    (pkgs / "dmt_x_fbdi_gen_pkg.pkb.sql").write_text(
        "BEGIN\n"
        "  -- writes OnlyInAComment.csv (comment, ignored)\n"
        "  DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 1, 'X', 'GlInterface.csv', 0, l_csv, l_id);\n"
        "  DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 2, 'X', 'EpbcsDataImport.csv', 0, l_csv, l_id);\n"
        "  DMT_UTIL_PKG.REGISTER_CSV(p_run_id, l_zip_id, 3, 'X', 'NotRegistered.csv', 0, l_csv, l_id);\n"
        "END;\n", encoding="utf-8")
    chk.PKG_DIR = str(pkgs)
    rc, out = run()
    check(rc == 1 and "FBDI-UPLOAD-REG|DMT_X_FBDI_GEN_PKG|NotRegistered.csv" in out,
          "an unregistered generated file fails")
    check("OnlyInAComment.csv" not in out, "a .csv name in a comment is ignored")
    check("allowlisted" in out and "EpbcsDataImport.csv" in out and
          "FBDI-UPLOAD-REG|DMT_X_FBDI_GEN_PKG|EpbcsDataImport.csv" not in out,
          "the PlanningBudgets file is allowlisted")
    check("GlInterface.csv" in out and "PASS" in out, "a registered file passes")
    chk.PKG_DIR = real_pkg_dir

    stale = tmp / "seed.sql"
    shutil.copy(real_seed, stale)
    stale.write_text(stale.read_text(encoding="utf-8").replace("commit;", "-- edited\ncommit;"),
                     encoding="utf-8")
    chk.SEED = str(stale)
    rc, out = run()
    check(rc == 1 and "FBDI-UPLOAD-SEED-SYNC" in out, "a stale committed seed fails")
finally:
    chk.PKG_DIR, chk.SEED = real_pkg_dir, real_seed
    shutil.rmtree(tmp, ignore_errors=True)

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
