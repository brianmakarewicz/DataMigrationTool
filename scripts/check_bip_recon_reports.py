#!/usr/bin/env python3
"""check_bip_recon_reports.py -- conformance checker for the BIP reconciliation
reports in bip/<Object>/ (the deployed .xdm data model and its query.sql mirror).

The PL/SQL checkers (check_sweep_unaccounted.py and friends) cannot see a fabricated
error that is invented INSIDE the report SQL: the reconciler faithfully copies
whatever ERROR_MESSAGE the report returns onto the row as [FUSION_ERROR]. This script
closes that blind spot.

WHICH REPORT IS CHECKED
-----------------------
For every bip/<Object>/ folder the "deployed reconciliation data model" is the .xdm
the BIP registry seed points at: the last DM_CATALOG_PATH for that folder in
db/seed/dmt_bip_report_tbl.sql (rows whose CEMLI_CODE has no '.', i.e. not the
per-tier auditor registrations; post-run comparison *_CMP_* models excluded). A folder
with no registry row falls back to its single DMT_*_RECON_DM.xdm. bip/common/ (lookup
and diagnostic models, not reconciliation reports) and bip/PlanningBudgets/ (object
out of scope, no catalog row -- same exemption as check_flag_stg_failed.py) are
skipped. The SQL analysed is the deployed .xdm's own SQL (it is authoritative);
query.sql is checked only for being its mirror (rule BIP-MIRROR).

RULES (each names the design-document section that states it)
-------------------------------------------------------------
BIP-XDM-COMMENT  No '--' inside an XML comment in ANY bip/**/*.xdm.
    XML 1.0 forbids '--' inside <!-- -->; BIP then rejects the data model and
    runReport returns HTTP 500 (the Items "unaccounted" defect, PR #423). Design doc
    section 5, "BIP reconciliation report contract" (a report must deploy and run).

BIP-MIRROR  bip/<Object>/query.sql mirrors the deployed .xdm SQL.
    Design doc section 7 (Coding standards), "The repo copy of a BIP report's query
    must exactly match the query deployed in Fusion". Also fails when the registered
    .xdm file does not exist in the repo (the mirror cannot be verified and the deploy
    script cannot deploy it).

BIP-NINE-COLUMNS  The report returns exactly the nine contract columns, in order:
    OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS, FUSION_ID, ERROR_MESSAGE,
    LOAD_REQUEST_ID, SOURCE_REF, DMT_REFERENCE.
    Design doc section 5, "BIP reconciliation report contract" (the seven response
    columns) plus section 7, the recon-engine record "The generic recon engine PARSES
    generically ..." (SOURCE_REF and DMT_REFERENCE make it nine; DMT_RECON_ENGINE_PKG
    reads exactly these nine). Further debug columns after the nine are tolerated
    (section 5: "further per-object columns after these seven are debug-only").

BIP-ERROR-SOURCE  ERROR_MESSAGE is built ONLY from a real Fusion error source.
    Every column that can reach the ERROR_MESSAGE value (traced through CTEs, derived
    tables, scalar sub-queries, CASE / NVL / DECODE results) must be one of the
    object's allow-listed Fusion error columns in ERROR_SOURCES below, and every string
    literal concatenated into it must be a level tag ('[HDR] ', '[LINE] ' ...), the
    '#IMPORT_REPORT#' marker, punctuation, or a single label word (' [value=',
    ' | Action: '). This catches: a CASE or literal sentence presented as the Fusion
    error, status codes / amounts / ids concatenated into a sentence, and a value from
    a non-error column (e.g. GL_INTERFACE.REFERENCE10, a line description) labelled as
    the error. Design doc section 5: the ERROR_MESSAGE column of the report contract,
    the [FUSION_ERROR] row of the ERROR_TEXT tag table ("the exact error string Fusion
    returned, with nothing composed around it"), and section 7, "A reconciler never
    fabricates a FAILED".

BIP-ERROR-ROW  No row is reported as an error without a real error row behind it.
    On every UNION branch that can return FUSION_STATUS = 'ERROR', every non-NULL
    alternative of ERROR_MESSAGE must carry at least one allow-listed Fusion error
    column (or be exactly the '#IMPORT_REPORT#' marker). A branch that can emit an
    ERROR row whose message is only literals / interface status / a list of held
    ancestors has no Fusion error behind it. (A NULL message is honest: the reconciler
    leaves that row for the UNACCOUNTED sweep.) Design doc section 5, "absence !=
    LOADED" and the [UNACCOUNTED] tag row ("if there is no specific Fusion error
    string, the record is [UNACCOUNTED], not [FUSION_ERROR]").

NOT CHECKED (declared, per the "Checker fidelity" standard in section 7):
  * NOT CHECKED: whitespace- and comment-only differences between query.sql and the
    .xdm (query.sql may carry an extra explanatory header).
  * NOT CHECKED: the six Contract-v1 parameters / parameter-set parity -- section 7
    "BIP parameter-set parity" needs the package call sites; not part of this rule set.
  * NOT CHECKED: whether an allow-listed error column is the RIGHT row's error (row
    matching / joins) -- runtime behaviour, covered by the regression scenario.
  * NOT CHECKED: what the deployed copy in Fusion actually contains -- this script
    reads the repo; deploying the repo copy is scripts/deploy_recon_bip_reports.py.

KNOWN VIOLATIONS
----------------
Violations that existed when these rules were introduced are listed in
scripts/standards_known_violations.json, each tied to its docs/backlog.html item.
Only a NEW violation fails the run (see scripts/standards_known_violations.py).

Exit code 0 = no new violations; 1 = at least one new violation.
Run from the repo root:  python scripts/check_bip_recon_reports.py
"""

import glob
import html
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import standards_known_violations as known          # noqa: E402
import standards_sql_lineage as lineage             # noqa: E402

CHECKER = "check_bip_recon_reports"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIP_DIR = os.path.join(REPO, "bip")
SEED = os.path.join(REPO, "db", "seed", "dmt_bip_report_tbl.sql")

SKIP_FOLDERS = {"common", "PlanningBudgets"}

CONTRACT = ["object_type", "record_key", "source_type", "fusion_status", "fusion_id",
            "error_message", "load_request_id", "source_ref", "dmt_reference"]

# ---------------------------------------------------------------------------
# The real Fusion error sources, per object (table -> columns). Lower case.
# A column may appear here ONLY if Fusion itself writes the rejection reason into
# it. Interface status codes, descriptions, references, ids and amounts are NOT
# error sources. Objects whose report legitimately returns no error text (HDL
# objects: failures arrive in the HDL response; REST config objects: errors arrive
# in the REST response; purging imports: '#IMPORT_REPORT#') have no entry.
# ---------------------------------------------------------------------------
ERROR_SOURCES = {
    "APInvoices": {"ap_interface_rejections": {"rejection_message", "reject_lookup_code"}},
    "ARInvoices": {"ra_interface_errors_all": {"message_text", "invalid_value"}},
    # FA_MASS_ADDITIONS carries the mass-addition's own rejection text.
    "Assets": {"fa_mass_additions": {"error_msg"}},
    # PO_INTERFACE_ERRORS: the error text and the interface column it names.
    "BlanketPOs": {"po_interface_errors": {"error_message", "column_name"}},
    "Contracts": {"po_interface_errors": {"error_message", "column_name"}},
    "PurchaseOrders": {"po_interface_errors": {"error_message", "column_name"}},
    "Requisitions": {"por_req_import_errors": {"column_name", "column_value", "text_line"}},
    # HZ import errors: the error row's own message name / text / tokens, with the
    # message dictionary text it names.
    "Customers": {"hz_imp_errors": {"message_name", "error_msg_text",
                                    "token1_value", "token2_value", "token3_value",
                                    "token4_value", "token5_value"},
                  "fnd_new_messages": {"message_text"}},
    # Journal Import writes its rejection as the error code(s) in GL_INTERFACE.STATUS
    # (e.g. EF04, EF04,EC03) and its message text in GL_INTERFACE.STATUS_DESCRIPTION
    # (e.g. 'FLEX-VALUE DOES NOT EXIST (SEGMENT=Account) ...', proven live, backlog
    # #173). REFERENCE1..REFERENCE10 are OUR carried values, never errors.
    "GLBalances": {"gl_interface": {"status", "status_description"}},
    "GLBudgets": {"gl_budget_interface": {"error_message"}},
    "Grants": {"gms_award_headers_int": {"processed_message", "message_user_details",
                                         "message_user_action"}},
    "Items": {"egp_import_errors": {"message_name", "message_text", "error_column_name"},
              "fnd_new_messages": {"message_text"}},
    "MiscReceipts": {"inv_transactions_interface": {"error_code", "error_explanation"}},
    "Suppliers": {"poz_supplier_int_rejections": {"reject_lookup_code", "attribute"}},
    "SupplierAddresses": {"poz_supplier_int_rejections": {"reject_lookup_code", "attribute"}},
    "SupplierSites": {"poz_supplier_int_rejections": {"reject_lookup_code", "attribute"}},
    "SupplierSiteAssignments": {"poz_supplier_int_rejections": {"reject_lookup_code",
                                                                "attribute"}},
    "SupplierContacts": {"poz_supplier_int_rejections": {"reject_lookup_code", "attribute"}},
}

IMPORT_REPORT_MARKER = "#IMPORT_REPORT#"
LEVEL_TAG_RE = re.compile(r"^\s*\[[A-Z][A-Z_]*\]\s?$")
NO_LETTERS_RE = re.compile(r"^[^A-Za-z]*$")
ONE_LABEL_RE = re.compile(r"^[^A-Za-z]*[A-Za-z][A-Za-z_]{0,15}[^A-Za-z]*$")


def literal_ok(lit):
    return (lit == IMPORT_REPORT_MARKER or LEVEL_TAG_RE.match(lit) is not None
            or NO_LETTERS_RE.match(lit) is not None or ONE_LABEL_RE.match(lit) is not None)


# ---------------------------------------------------------------------------
# Locating the deployed data model
# ---------------------------------------------------------------------------
def registry_dms():
    """folder -> DM file name, from the LAST registry statement naming it."""
    text = lineage.strip_comments(open(SEED, encoding="utf-8").read())
    stmts = re.split(r"(?im)^\s*/\s*$|;\s*$", text)
    out = {}
    for s in stmts:
        for chunk in re.split(r"(?i)\bunion\s+all\b", s):
            cem = path = None
            # INSERT ... VALUES (id, 'Cemli', 'Type', '/Custom/...xdm', ...) and the
            # positional UNION ALL rows of a MERGE source (select id, 'Cemli', ...).
            m = re.search(r"(?:values\s*\(|select)\s*\d+\s*,\s*'([^']+)'\s*,\s*'[^']*'\s*,"
                          r"\s*'([^']+\.xdm)'", chunk, re.I)
            if m:
                cem, path = m.group(1), m.group(2)
            else:
                m1 = re.search(r"'([^']+)'\s+cemli_code\b", chunk, re.I)
                m2 = re.search(r"'([^']+)'\s+dm_catalog_path\b", chunk, re.I)
                if m1 and m2:
                    cem, path = m1.group(1), m2.group(1)
            if not cem or "." in cem or not path:
                continue
            pm = re.match(r"^/Custom/DMT2/([^/]+)/([^/]+)\.xdm$", path)
            if not pm or "_CMP" in pm.group(2):
                continue
            out[pm.group(1)] = pm.group(2)
    return out


def xdm_sqls(path):
    """All <sql> bodies of a data model, CDATA unwrapped / entities decoded."""
    text = open(path, encoding="utf-8", errors="replace").read()
    out = []
    for m in re.finditer(r"<sql\b[^>]*>(.*?)</sql>", text, re.S | re.I):
        body = m.group(1)
        cd = re.search(r"<!\[CDATA\[(.*?)\]\]>", body, re.S)
        out.append(cd.group(1) if cd else html.unescape(body))
    return out


def normalize_sql(text):
    t = lineage.strip_comments(text)
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"\s*[;/]\s*$", "", t).strip()
    return t


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------
def check_xdm_comments():
    found = []
    for path in sorted(glob.glob(os.path.join(BIP_DIR, "**", "*.xdm"), recursive=True)):
        text = open(path, encoding="utf-8", errors="replace").read()
        # CDATA content is not markup: drop it before looking for comments.
        markup = re.sub(r"<!\[CDATA\[.*?\]\]>", " ", text, flags=re.S)
        rel = os.path.relpath(path, REPO).replace(os.sep, "/")
        for m in re.finditer(r"<!--(.*?)-->", markup, re.S):
            body = m.group(1)
            if "--" in body or body.endswith("-"):
                line = text.count("\n", 0, text.find(m.group(0))) + 1
                found.append(("BIP-XDM-COMMENT|%s|xml-comment" % rel,
                              "%s line %d: XML comment contains '--' (illegal in XML; BIP "
                              "rejects the data model)" % (rel, line)))
                break
    return found


def check_mirror(obj, dm_name, dm_path):
    key = "BIP-MIRROR|%s|%s" % (obj, dm_name)
    q = os.path.join(BIP_DIR, obj, "query.sql")
    if not os.path.exists(dm_path):
        return [(key, "registered data model bip/%s/%s.xdm does not exist in the repo "
                      "(registry/deploy name and file name disagree)" % (obj, dm_name))]
    if not os.path.exists(q):
        return [(key, "bip/%s/query.sql is missing" % obj)]
    sqls = [normalize_sql(s) for s in xdm_sqls(dm_path)]
    # query.sql mirrors a multi-dataset model as its statements in order, each
    # ended by ';' (a ';' followed by the next SELECT / WITH, or by end of file).
    qtext = lineage.strip_comments(open(q, encoding="utf-8", errors="replace").read())
    stmts = [normalize_sql(s) for s in
             re.split(r";\s*(?=(?:select|with)\b)", qtext, flags=re.I) if s.strip()]
    if stmts == sqls or (len(stmts) == 1 and stmts[0] in sqls):
        return []
    claimed = sorted(set(re.findall(r"([A-Z0-9_]+)\.xdm",
                                    open(q, encoding="utf-8", errors="replace").read())))
    return [(key, "bip/%s/query.sql does not match the SQL of the deployed %s.xdm "
                  "(query.sql names: %s)" % (obj, dm_name, ", ".join(claimed) or "none"))]


def branch_label(br, names):
    """A stable name for a UNION branch: its OBJECT_TYPE and SOURCE_TYPE literals."""
    bits = []
    for col in ("object_type", "source_type"):
        if col in names and names.index(col) < len(br.items):
            toks = br.items[names.index(col)].toks
            if toks and toks[0].kind == "str":
                bits.append(toks[0].val)
            elif toks and toks[0].kind == "ident":
                bits.append(toks[0].val.split(".")[-1])
    return "/".join(bits) if bits else "branch"


def fmt_alt(a):
    cols = ",".join(sorted("%s.%s" % c for c in a.cols)) or "-"
    lits = " ".join(repr(x) for x in sorted(a.lits)) or "-"
    return "{columns: %s; literals: %s}" % (cols, lits)


def check_sql(obj, dm_name, sql):
    found = []
    q = lineage.parse_sql(sql)
    names = q.output_names()
    if not names:
        return [("BIP-NINE-COLUMNS|%s|%s" % (obj, dm_name),
                 "could not read the report's output columns")]
    if names[:9] != CONTRACT:
        found.append(("BIP-NINE-COLUMNS|%s|%s" % (obj, dm_name),
                      "%s returns [%s], not the nine contract columns [%s]"
                      % (dm_name, ", ".join(n or "?" for n in names), ", ".join(CONTRACT))))
    if "error_message" not in names:
        return found
    err_idx = names.index("error_message")
    status_col = next((c for c in ("fusion_status", "import_status") if c in names), None)
    allowed = ERROR_SOURCES.get(obj, {})
    resolver = lineage.Resolver()
    bad_cols, bad_lits = set(), set()
    for br in lineage.unwrap_branches(q):
        if err_idx >= len(br.items):
            continue
        alts = resolver.eval(br.items[err_idx].toks, br)
        for a in lineage.non_null(alts):
            for (tbl, col) in a.cols:
                if col not in allowed.get(tbl, set()):
                    bad_cols.add("%s.%s" % (tbl, col))
            for lit in a.lits:
                if not literal_ok(lit):
                    bad_lits.add(lit)
        # BIP-ERROR-ROW: only on branches that can emit FUSION_STATUS = 'ERROR'
        if status_col is None:
            continue
        s_idx = names.index(status_col)
        if s_idx >= len(br.items):
            continue
        st = resolver.eval(br.items[s_idx].toks, br)
        if not any(x in ("ERROR", "REJECTED") for a in st for x in a.lits):
            continue
        unbacked = []
        for a in lineage.non_null(alts):
            if a.lits == frozenset({IMPORT_REPORT_MARKER}) and not a.cols:
                continue
            if not any(col in allowed.get(tbl, set()) for (tbl, col) in a.cols):
                unbacked.append(a)
        if unbacked:
            label = branch_label(br, names)
            found.append(("BIP-ERROR-ROW|%s|%s" % (obj, label),
                          "%s branch %s can return FUSION_STATUS='ERROR' with a message "
                          "that has no Fusion error column behind it: %s"
                          % (dm_name, label, " ;; ".join(fmt_alt(a) for a in unbacked[:4]))))
    for c in sorted(bad_cols):
        found.append(("BIP-ERROR-SOURCE|%s|column %s" % (obj, c),
                      "%s builds ERROR_MESSAGE from %s, which is not an allow-listed "
                      "Fusion error column for %s" % (dm_name, c, obj)))
    for lit in sorted(bad_lits):
        short = re.sub(r"\s+", " ", lit).strip()[:60]
        found.append(("BIP-ERROR-SOURCE|%s|literal '%s'" % (obj, short),
                      "%s concatenates the invented text '%s' into ERROR_MESSAGE"
                      % (dm_name, short)))
    return found


def objects_to_check():
    reg = registry_dms()
    out = []
    for d in sorted(os.listdir(BIP_DIR)):
        full = os.path.join(BIP_DIR, d)
        if not os.path.isdir(full) or d in SKIP_FOLDERS:
            continue
        dm = reg.get(d)
        note = "registry"
        if dm is None:
            recon = sorted(os.path.basename(p)[:-4] for p in
                           glob.glob(os.path.join(full, "DMT_*_RECON*_DM.xdm")))
            if len(recon) != 1:
                continue
            dm, note = recon[0], "no registry row -- single DMT_*_RECON_DM.xdm in folder"
        out.append((d, dm, os.path.join(full, dm + ".xdm"), note))
    return out


def main():
    print("BIP reconciliation report conformance check")
    print("=" * 72)
    found = check_xdm_comments()
    for obj, dm, path, note in objects_to_check():
        f = check_mirror(obj, dm, path)
        if os.path.exists(path):
            sqls = xdm_sqls(path)
        else:
            q = os.path.join(BIP_DIR, obj, "query.sql")
            sqls = [open(q, encoding="utf-8").read()] if os.path.exists(q) else []
        for sql in sqls:
            f += check_sql(obj, dm, sql)
        # de-duplicate keys (multi-dataset models)
        seen, uniq = set(), []
        for k, m in f:
            if k not in seen:
                seen.add(k)
                uniq.append((k, m))
        print("  %-5s %-24s %s.xdm  (%s)" % ("OK" if not uniq else "VIOL", obj, dm, note))
        found += uniq
    print("\nNOT CHECKED: whitespace/comment-only differences between query.sql and the .xdm")
    print("NOT CHECKED: Contract-v1 parameter set / package-vs-xdm parameter parity")
    print("NOT CHECKED: whether an allow-listed error column belongs to the RIGHT row "
          "(runtime; regression scenario)")
    print("NOT CHECKED: the copy actually deployed in Fusion (repo only)")
    print("SKIPPED: bip/common (lookup/diagnostic models), bip/PlanningBudgets (out of scope)")
    rc = known.report(CHECKER, found)
    print("=" * 72)
    print("RESULT: %s" % ("FAIL -- new BIP report violations (see NEW above)" if rc
                          else "PASS -- no new BIP report violations"))
    return rc


if __name__ == "__main__":
    sys.exit(main())
