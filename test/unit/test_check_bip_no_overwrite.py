#!/usr/bin/env python3
"""
test_check_bip_no_overwrite.py - offline proof of scripts/check_bip_no_overwrite.py,
the CI rule for the owner rule "a Fusion BIP catalog object is never overwritten or
deleted" (backlog #757).

What it proves (no database, no Fusion):
  * the pre-fix DEPLOY_RECON_REPORT shape (DELETE_CATALOG_OBJECT before create) is
    caught as BIP-NO-DELETE;
  * a deleteObjectInSession on a shared catalog path is caught, while the
    personal-folder scratch cleanup DELETE_DM (path literal '/~...') is allowed;
  * a createObjectInSession unit with no exists-check is caught as
    BIP-CREATE-UNCHECKED, and the same unit calling assert_catalog_path_absent passes;
  * updateFlag driven by a parameter, uploadTemplateForReportInSession and an
    overwrite=true flag are caught as BIP-NO-OVERWRITE; updateFlag false passes;
  * a direct catalog create from Python is caught;
  * comment lines are ignored;
  * the committed repository passes (exit 0).

    python test/unit/test_check_bip_no_overwrite.py
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import check_bip_no_overwrite as chk  # noqa: E402

passed = failed = 0


def check(cond, name):
    global passed, failed
    if cond:
        passed += 1
        print(f"PASS  {name}")
    else:
        failed += 1
        print(f"FAIL  {name}")


def rules(rel, text):
    return [f[0] for f in chk.scan_text(rel, text)]


PKG = "db/packages/x_pkg.pkb.sql"

old_recon = """
    PROCEDURE DEPLOY_RECON_REPORT (p_folder IN VARCHAR2) IS
    BEGIN
        DELETE_CATALOG_OBJECT(l_token, p_folder || '/R.xdo');
        DEPLOY_CATALOG_OBJECT(l_token, p_folder, 'R', 'xdo', l_xdo);
    END DEPLOY_RECON_REPORT;
"""
check("BIP-NO-DELETE" in rules(PKG, old_recon), "delete-before-create (the #757 shape) is caught")

shared_delete = """
    PROCEDURE PURGE_IT IS
    BEGIN
        l_env := '<v2:deleteObjectInSession><v2:objectAbsolutePath>'||p_path||'</v2:objectAbsolutePath>';
    END PURGE_IT;
"""
check("BIP-NO-DELETE" in rules(PKG, shared_delete), "deleteObjectInSession on a catalog path is caught")

scratch = """
    PROCEDURE DELETE_DM (p_session_token IN VARCHAR2, p_xdm_name IN VARCHAR2) IS
    BEGIN
        l_env := '    <v2:deleteObjectInSession>'||
            '      <v2:objectAbsolutePath>/~'||bip_username||'/'||p_xdm_name||'.xdm</v2:objectAbsolutePath>';
    END DELETE_DM;
"""
check(rules("db/packages/dmt_bip_deploy_pkg.pkb.sql", scratch) == [],
      "personal-folder scratch cleanup DELETE_DM is allowed")
check("BIP-NO-DELETE" in rules("db/packages/dmt_bip_deploy_pkg.pkb.sql",
                               scratch.replace(">/~'||bip_username||'/'||", ">'||p_folder||'/'||")),
      "DELETE_DM without the personal-folder path is caught")

unchecked = """
    PROCEDURE PUT_IT IS
    BEGIN
        l_env := '<v2:createObjectInSession><v2:folderAbsolutePathURL>'||p_folder||'</v2:folderAbsolutePathURL>';
    END PUT_IT;
"""
check(rules(PKG, unchecked) == ["BIP-CREATE-UNCHECKED"], "create without the exists-check is caught")
guarded = unchecked.replace("    BEGIN\n", "    BEGIN\n        assert_catalog_path_absent(t, p_folder || '/X.xdm');\n")
check(rules(PKG, guarded) == [], "create after assert_catalog_path_absent passes")

check("BIP-NO-OVERWRITE" in rules(PKG, "x := '<v2:updateFlag>'||p_update_existing||'</v2:updateFlag>';"),
      "updateFlag driven by a parameter is caught")
check(rules(PKG, "x := '<v2:updateFlag>false</v2:updateFlag>';") == [], "updateFlag false passes")
check("BIP-NO-OVERWRITE" in rules(PKG, "a := 'ReportService/uploadTemplateForReportInSessionRequest';"),
      "uploadTemplateForReportInSession (template replace) is caught")
check("BIP-NO-OVERWRITE" in rules("scripts/x.py", "client.deploy(path, overwrite=True)\n"),
      "an overwrite=True flag is caught")
check("BIP-CREATE-UNCHECKED" in rules("scripts/x.py", "svc.createObjectInSession(folder, name)\n"),
      "a direct Python catalog create is caught")
check(rules(PKG, "    -- DELETE_CATALOG_OBJECT used to run here; updateFlag>true\n") == []
      and rules("scripts/x.py", "# deleteObjectInSession is never called\n") == [],
      "comment lines are ignored")

check(chk.main() == 0, "the committed repository passes the checker")

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
