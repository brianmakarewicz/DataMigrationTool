"""
compare_schemas.py — Dictionary-level diff of the live ATP DMT_OWNER schema
(source of truth, READ-ONLY) vs the local Docker DMT_OWNER schema built from
db_full/install.sql. Writes db_full/COMPARE_REPORT.md.

Usage: python db_full/tools/compare_schemas.py
Env:   DMT_LOCAL_DSN (default localhost:1521/FREEPDB1)
       DMT_LOCAL_PWD (default DmtLocal#2026)
"""
import sys, os, re, hashlib, datetime

sys.path.insert(0, r"C:\Users\Monroe\workspace")
from conn_helper import connect_atp
import oracledb

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LOCAL_DSN = os.environ.get("DMT_LOCAL_DSN", "localhost:1521/FREEPDB1")
LOCAL_PWD = os.environ.get("DMT_LOCAL_PWD", "DmtLocal#2026")

EXCLUDE_NAME = re.compile(r"^(SYS_|ISEQ\$\$|BIN\$|DR\$|MLOG\$|RUPD\$|APEX\$)")
OBJ_TYPES = ("TABLE", "VIEW", "SEQUENCE", "PACKAGE", "PACKAGE BODY",
             "PROCEDURE", "FUNCTION", "TRIGGER", "TYPE", "SYNONYM", "INDEX", "JOB")

# Objects that are expected to be INVALID locally (no ATP_LINK db link, no
# APEX/Fusion-side grants on the local DB). Populated at runtime + static list.
EXPECTED_INVALID_REASONS = {
}


def q(cur, sql, *args):
    cur.execute(sql, args)
    return cur.fetchall()


def get_inventory(cur):
    rows = q(cur, """select object_type, object_name, status from user_objects
                     where object_type in ('TABLE','VIEW','SEQUENCE','PACKAGE','PACKAGE BODY',
                                           'PROCEDURE','FUNCTION','TRIGGER','TYPE','SYNONYM','JOB')
                     order by 1,2""")
    return {(t, n): s for t, n, s in rows if not EXCLUDE_NAME.match(n)}


def get_columns(cur):
    rows = q(cur, """select table_name, column_name, data_type,
                            case when data_type like '%CHAR%' then char_length else data_length end,
                            data_precision, data_scale, nullable
                     from user_tab_cols
                     where hidden_column='NO'
                       and table_name in (select table_name from user_tables)
                     order by table_name, column_id""")
    d = {}
    for tn, cn, dt, dl, dp, ds, nu in rows:
        if EXCLUDE_NAME.match(tn):
            continue
        # normalize LOB/date lengths (length is storage-dependent for these)
        if dt in ("CLOB", "BLOB", "DATE", "NUMBER") or dt.startswith("TIMESTAMP"):
            dl = None
        d.setdefault(tn, {})[cn] = (dt, dl, dp, ds, nu)
    return d


def get_constraints(cur):
    rows = q(cur, """select c.table_name, c.constraint_type,
                            nvl(c.search_condition_vc,'-'),
                            (select listagg(column_name,',') within group (order by position)
                               from user_cons_columns cc where cc.constraint_name=c.constraint_name),
                            nvl((select r.table_name from user_constraints r
                                 where r.constraint_name=c.r_constraint_name),'-')
                     from user_constraints c
                     where c.constraint_type in ('P','U','R','C')
                       and c.table_name in (select table_name from user_tables)""")
    s = set()
    for tn, ct, cond, cols, rtab in rows:
        if EXCLUDE_NAME.match(tn):
            continue
        cond = re.sub(r"\s+", " ", (cond or "-")).strip()
        if ct == "C" and re.match(r'^"?\w+"? IS NOT NULL$', cond):
            continue  # NOT NULL handled via column nullability
        s.add((tn, ct, cond, cols or "-", rtab))
    return s


def get_indexes(cur):
    rows = q(cur, """select i.table_name, i.uniqueness,
                            (select listagg(column_name,',') within group (order by column_position)
                               from user_ind_columns ic where ic.index_name=i.index_name)
                     from user_indexes i
                     where i.index_type not in ('LOB')
                       and i.table_name in (select table_name from user_tables)""")
    s = set()
    for tn, u, cols in rows:
        if EXCLUDE_NAME.match(tn) or cols is None:
            continue
        s.add((tn, u, cols))
    return s


def get_source_hashes(cur):
    d = {}
    cur.execute("""select type, name, text from user_source
                   where type in ('PACKAGE','PACKAGE BODY','PROCEDURE','FUNCTION','TRIGGER','TYPE')
                   order by type, name, line""")
    cur.arraysize = 5000
    bufs = {}
    for typ, name, text in cur:
        if EXCLUDE_NAME.match(name):
            continue
        bufs.setdefault((typ, name), []).append(text or "")
    for k, lines in bufs.items():
        src = "".join(lines)
        norm = "\n".join(l.rstrip() for l in src.replace("\r", "").split("\n")).strip()
        # DBMS_METADATA rewrites the declaration line on install
        # (PACKAGE   DMT_X  ->  PACKAGE "DMT_X"): strip quotes and collapse
        # whitespace on that line only; the rest still compares byte-exact.
        first, _, rest = norm.partition("\n")
        first = re.sub(r"\s*\(", " (", re.sub(r"\s+", " ", first.replace('"', ""))).strip().upper()
        norm = first + "\n" + rest
        d[k] = hashlib.sha256(norm.encode()).hexdigest()[:16]
    return d


def get_view_hashes(cur):
    d = {}
    for vn, in q(cur, "select view_name from user_views order by 1"):
        if EXCLUDE_NAME.match(vn):
            continue
        cur.execute("select text from user_views where view_name=:1", [vn])
        t = cur.fetchone()[0]
        t = t.read() if hasattr(t, "read") else t
        norm = re.sub(r"\s+", " ", (t or "")).strip().rstrip(";").upper()
        d[vn] = hashlib.sha256(norm.encode()).hexdigest()[:16]
    return d


def main():
    atp = connect_atp("queryapp", "DMT_OWNER").cursor()
    loc_conn = oracledb.connect(user="DMT_OWNER", password=LOCAL_PWD, dsn=LOCAL_DSN)
    loc = loc_conn.cursor()

    print("Collecting ATP dictionary ...")
    a_inv, a_cols, a_cons, a_idx = get_inventory(atp), get_columns(atp), get_constraints(atp), get_indexes(atp)
    a_src, a_vw = get_source_hashes(atp), get_view_hashes(atp)
    print("Collecting local dictionary ...")
    l_inv, l_cols, l_cons, l_idx = get_inventory(loc), get_columns(loc), get_constraints(loc), get_indexes(loc)
    l_src, l_vw = get_source_hashes(loc), get_view_hashes(loc)

    R = ["# db_full COMPARE REPORT",
         "",
         "Generated %s by `db_full/tools/compare_schemas.py`." % datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
         "Source of truth: ATP queryapp DMT_OWNER (read-only). Target: local Docker %s DMT_OWNER built from `db_full/install.sql`." % LOCAL_DSN,
         ""]

    only_atp = sorted(set(a_inv) - set(l_inv))
    only_loc = sorted(set(l_inv) - set(a_inv))
    common = sorted(set(a_inv) & set(l_inv))

    # column diffs
    col_diffs = []
    for tn in sorted(set(a_cols) & set(l_cols)):
        ac, lc = a_cols[tn], l_cols[tn]
        for cn in sorted(set(ac) | set(lc)):
            if cn not in lc:
                col_diffs.append("%s.%s only in ATP %s" % (tn, cn, ac[cn]))
            elif cn not in ac:
                col_diffs.append("%s.%s only in LOCAL %s" % (tn, cn, lc[cn]))
            elif ac[cn] != lc[cn]:
                col_diffs.append("%s.%s ATP=%s LOCAL=%s" % (tn, cn, ac[cn], lc[cn]))

    cons_only_a = sorted(a_cons - l_cons)
    cons_only_l = sorted(l_cons - a_cons)
    idx_only_a = sorted(a_idx - l_idx)
    idx_only_l = sorted(l_idx - a_idx)

    src_diff = sorted(k for k in set(a_src) & set(l_src) if a_src[k] != l_src[k])
    vw_diff = sorted(k for k in set(a_vw) & set(l_vw) if a_vw[k] != l_vw[k])

    # invalid objects on local
    l_invalid = sorted(k for k, s in l_inv.items() if s == "INVALID")
    a_invalid = sorted(k for k, s in a_inv.items() if s == "INVALID")

    n_code = len(set(a_src) & set(l_src))
    n_match_code = n_code - len(src_diff)
    n_vw = len(set(a_vw) & set(l_vw))
    total_a = len(a_inv)
    matched_inv = len(common)

    R += ["## Summary",
          "",
          "| Metric | Value |",
          "|---|---|",
          "| Objects in ATP (compared types) | %d |" % total_a,
          "| Objects present in both | %d (%.1f%%) |" % (matched_inv, 100.0 * matched_inv / max(total_a, 1)),
          "| Only in ATP | %d |" % len(only_atp),
          "| Only in local | %d |" % len(only_loc),
          "| Table column diffs | %d |" % len(col_diffs),
          "| Constraint diffs (ATP-only / local-only) | %d / %d |" % (len(cons_only_a), len(cons_only_l)),
          "| Index diffs (ATP-only / local-only) | %d / %d |" % (len(idx_only_a), len(idx_only_l)),
          "| Code objects hash-matching | %d / %d |" % (n_match_code, n_code),
          "| View definitions hash-matching | %d / %d |" % (n_vw - len(vw_diff), n_vw),
          "| INVALID on local | %d |" % len(l_invalid),
          "| INVALID on ATP (pre-existing) | %d |" % len(a_invalid),
          ""]

    def sec(title, items, fmt=str, limit=400):
        R.append("## %s (%d)" % (title, len(items)))
        R.append("")
        if not items:
            R.append("_none_")
        for it in items[:limit]:
            R.append("- " + fmt(it))
        if len(items) > limit:
            R.append("- ... and %d more" % (len(items) - limit))
        R.append("")

    sec("Objects only in ATP", only_atp, lambda k: "%s %s" % k)
    sec("Objects only in local", only_loc, lambda k: "%s %s" % k)
    sec("Column differences", col_diffs)
    sec("Constraints only in ATP", cons_only_a, lambda c: "%s %s cols=%s cond=%s ref=%s" % (c[0], c[1], c[3], c[2][:80], c[4]))
    sec("Constraints only in local", cons_only_l, lambda c: "%s %s cols=%s cond=%s ref=%s" % (c[0], c[1], c[3], c[2][:80], c[4]))
    sec("Indexes only in ATP (table, uniqueness, cols)", idx_only_a, lambda i: "%s %s (%s)" % i)
    sec("Indexes only in local", idx_only_l, lambda i: "%s %s (%s)" % i)
    sec("Code objects with differing source", src_diff, lambda k: "%s %s" % k)
    sec("Views with differing definitions", vw_diff)

    R.append("## INVALID objects on local Docker DB")
    R.append("")
    if not l_invalid:
        R.append("_none_")
    for k in l_invalid:
        reason = EXPECTED_INVALID_REASONS.get(k[1], "")
        pre = " (also INVALID on ATP)" if k in a_invalid else ""
        R.append("- %s %s%s %s" % (k[0], k[1], pre, reason))
    R.append("")
    R.append("## INVALID objects on ATP (pre-existing, for reference)")
    R.append("")
    for k in a_invalid:
        R.append("- %s %s" % k)
    if not a_invalid:
        R.append("_none_")
    R.append("")

    out = os.path.join(ROOT, "COMPARE_REPORT.md")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(R))
    print("Wrote", out)
    print("only_atp=%d only_local=%d col_diffs=%d src_diff=%d vw_diff=%d local_invalid=%d"
          % (len(only_atp), len(only_loc), len(col_diffs), len(src_diff), len(vw_diff), len(l_invalid)))


if __name__ == "__main__":
    main()
