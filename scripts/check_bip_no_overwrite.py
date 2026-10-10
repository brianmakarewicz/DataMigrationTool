#!/usr/bin/env python3
"""
check_bip_no_overwrite.py -- conformance checker for the owner rule on Fusion BIP
catalog objects (backlog #757; binding owner rule): a BIP data model, report,
template or folder in the Fusion catalog is NEVER overwritten or deleted. A changed
report is deployed ALONGSIDE the old one under a new versioned name (..._V2_DM).

WHAT THIS CHECKS (committed files only -- no database, no Fusion)
-----------------------------------------------------------------
Code under db/, scripts/, apex/ and gold_regression/ (.sql .pks .pkb .py .apx);
SQL '--' and Python '#' comment lines are ignored.

  BIP-NO-DELETE       A catalog delete: the SOAP operations deleteObject* /
                      deleteFolder*, or a call to the retired DELETE_CATALOG_OBJECT /
                      DELETE_REPORT procedures. The ONLY allowed deletes are the two
                      personal-folder scratch cleanups below, and each must still
                      carry its personal-folder guard:
                        db/packages/dmt_bip_deploy_pkg.pkb.sql  DELETE_DM
                          (path literal starts '/~' || bip_username)
                        db/packages/fbt_bip_pkg.pkb.sql         DELETE_DATA_MODEL
                          (refuses unless is_personal_path)
                      They remove the scratch data model RUN_DATA_MODEL /
                      RUN_DATA_MODEL_EPHEMERAL created a moment earlier in the BIP
                      user's own /~user folder, never a shared catalog object.
  BIP-NO-OVERWRITE    An overwrite: updateObject*, uploadTemplateForReport* (replaces a
                      template on an existing report), replaceObject*, moveObject*,
                      copyObject*, an updateFlag element that is not the literal
                      false, or an overwrite flag set to true.
  BIP-CREATE-UNCHECKED
                      A PL/SQL unit that creates a catalog object (createObject*,
                      uploadObject*, createReport* SOAP operations) without first
                      calling the existence guard (assert_catalog_path_absent in
                      DMT_BIP_DEPLOY_PKG, assert_absent in FBT_BIP_PKG). Exempt: a
                      unit whose target folder is the literal personal folder '/~'
                      (DMT_BIP_DEPLOY_PKG.CREATE_DM scratch). In Python, any direct
                      catalog create/upload is flagged: deploys go through
                      DMT_BIP_DEPLOY_PKG so the guard is applied.

NOT CHECKED (declared so a green run stays honest)
--------------------------------------------------
  * Operation names assembled at run time from fragments or variables.
  * docs/ and test/ (prose and negative fixtures).
  * Whether the BIP server itself overwrites on createObjectInSession: the guard
    asks objectExistInSession first, so the question never arises.

    python scripts/check_bip_no_overwrite.py

Exit 0 = PASS, 1 = at least one violation.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
SELF = os.path.abspath(__file__)
SCAN_DIRS = ("db", "scripts", "apex", "gold_regression")
EXTS = (".sql", ".pks", ".pkb", ".py", ".apx")

DELETE_RE = re.compile(r"\b(deleteObject\w*|deleteFolder\w*|DELETE_CATALOG_OBJECT|DELETE_REPORT)\b",
                       re.I)
OVERWRITE_RE = re.compile(
    r"\b(updateObject\w*|uploadTemplateForReport\w*|replaceObject\w*|moveObject\w*|copyObject\w*)\b"
    r"|<\w*:?updateFlag>(?!false<)"
    r"|<\w*:?overwrite>\s*true"
    r"|\boverwrite\s*[=:]\s*['\"]?true",
    re.I)
CREATE_RE = re.compile(r"\b(createObject\w*|uploadObject\w*|createReport\w*)\b", re.I)
GUARD_RE = re.compile(r"\b(assert_catalog_path_absent|assert_absent)\s*\(", re.I)
PERSONAL_FOLDER_RE = re.compile(r"folderAbsolutePathURL>/~'")

# (relative path, unit name) -> marker the unit must contain to stay allowed
ALLOWED_DELETES = {
    ("db/packages/dmt_bip_deploy_pkg.pkb.sql", "DELETE_DM"): "objectAbsolutePath>/~'",
    ("db/packages/fbt_bip_pkg.pkb.sql", "DELETE_DATA_MODEL"): "is_personal_path(",
}

UNIT_RE = re.compile(r"^[ \t]*(PROCEDURE|FUNCTION)[ \t]+(\w+)\b", re.I | re.M)


def code_lines(text, py):
    """[(lineno, line)] with comment lines dropped (and SQL trailing comments cut)."""
    out = []
    for n, ln in enumerate(text.splitlines(), 1):
        s = ln.lstrip()
        if py:
            if s.startswith("#"):
                continue
        else:
            if s.startswith("--"):
                continue
            i = ln.find("--")
            # cut a trailing SQL comment only when it is outside a quoted literal
            if i >= 0 and ln[:i].count("'") % 2 == 0:
                ln = ln[:i]
        out.append((n, ln))
    return out


def plsql_units(text):
    """[(name, start_offset, end_offset)] for each PROCEDURE/FUNCTION body that has
    a matching END name; (spec declarations without a body are skipped)."""
    units = []
    for m in UNIT_RE.finditer(text):
        name = m.group(2)
        end = re.compile(r"^[ \t]*END[ \t]+%s[ \t]*;" % re.escape(name), re.I | re.M)
        e = end.search(text, m.end())
        if e:
            units.append((name.upper(), m.start(), e.end()))
    return units


def unit_at(units, offset):
    """Innermost unit containing offset, or None."""
    best = None
    for name, a, b in units:
        if a <= offset < b and (best is None or a > best[1]):
            best = (name, a, b)
    return best


def scan_text(rel, text):
    """Return [(rule, rel, line, message)] for one file's text."""
    py = rel.endswith(".py")
    found = []
    lines = code_lines(text, py)
    code = "\n".join(ln for _n, ln in lines)
    lineno = [n for n, _ln in lines]

    def line_of(off):
        return lineno[min(code.count("\n", 0, off), len(lineno) - 1)] if lineno else 0

    units = [] if py else plsql_units(code)

    for m in DELETE_RE.finditer(code):
        u = unit_at(units, m.start())
        key = (rel, u[0] if u else None)
        marker = ALLOWED_DELETES.get(key)
        if marker and marker in code[u[1]:u[2]]:
            continue
        # the allowed procedures' own definitions/END lines name themselves
        if u and m.group(1).upper() == u[0] and key in ALLOWED_DELETES:
            continue
        found.append(("BIP-NO-DELETE", rel, line_of(m.start()),
                      "'%s'%s deletes a BIP catalog object -- never delete; deploy a new "
                      "version alongside" % (m.group(1), (" in %s" % u[0]) if u else "")))

    for m in OVERWRITE_RE.finditer(code):
        found.append(("BIP-NO-OVERWRITE", rel, line_of(m.start()),
                      "'%s' overwrites a BIP catalog object -- never overwrite; deploy a new "
                      "version alongside" % m.group(0).strip()))

    for m in CREATE_RE.finditer(code):
        if py:
            found.append(("BIP-CREATE-UNCHECKED", rel, line_of(m.start()),
                          "'%s' creates a catalog object directly from Python -- deploy through "
                          "DMT_BIP_DEPLOY_PKG so the exists-check is applied" % m.group(1)))
            continue
        u = unit_at(units, m.start())
        if u is None:
            found.append(("BIP-CREATE-UNCHECKED", rel, line_of(m.start()),
                          "'%s' outside a procedure/function -- no exists-check" % m.group(1)))
            continue
        body = code[u[1]:u[2]]
        if GUARD_RE.search(body) or PERSONAL_FOLDER_RE.search(body):
            continue
        found.append(("BIP-CREATE-UNCHECKED", rel, line_of(m.start()),
                      "%s calls '%s' without first calling the exists-check "
                      "(assert_catalog_path_absent / assert_absent)" % (u[0], m.group(1))))

    # one finding per (rule, line)
    seen, out = set(), []
    for f in found:
        k = (f[0], f[2])
        if k not in seen:
            seen.add(k)
            out.append(f)
    return out


def files():
    for d in SCAN_DIRS:
        for dirpath, _dirs, names in os.walk(os.path.join(ROOT, d)):
            for fn in sorted(names):
                if fn.lower().endswith(EXTS):
                    full = os.path.join(dirpath, fn)
                    if os.path.abspath(full) != SELF:
                        yield full


def main():
    found = []
    n = 0
    for full in files():
        n += 1
        rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
        with open(full, encoding="utf-8", errors="replace") as fh:
            found.extend(scan_text(rel, fh.read()))
    print("check_bip_no_overwrite: scanned %d files" % n)
    for rule, rel, line, msg in found:
        print("  %-21s %s:%d  %s" % (rule, rel, line, msg))
    print("=" * 72)
    if found:
        print("RESULT: FAIL -- %d BIP delete/overwrite violation(s). A Fusion BIP object is "
              "never overwritten or deleted (backlog #757)." % len(found))
        return 1
    print("RESULT: PASS -- no BIP catalog delete or overwrite in deploy code")
    return 0


if __name__ == "__main__":
    sys.exit(main())
