"""
snapshot_atp.py — Snapshot the LIVE ATP DMT_OWNER schema into db_full/ as
per-object DDL files plus an install.sql that rebuilds the schema from scratch.

READ-ONLY against ATP: uses only SELECT + DBMS_METADATA.
Usage:  python db_full/tools/snapshot_atp.py
"""
import sys, os, re, datetime

sys.path.insert(0, r"C:\Users\Monroe\workspace")
from conn_helper import connect_atp

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

SEED_TABLES = [
    "DMT_CEMLI_SPLIT_CFG",
    "DMT_BIP_REPORT_TBL",
    "DMT_ERP_INTERFACE_OPTIONS_TBL",
    "DMT_REST_LOOKUP_TBL",
    "DMT_CONFIG_TBL",
]
# DMT_CONFIG_TBL values masked when key matches this
CRED_KEY_RE = re.compile(r"(PASSWORD|PWD|SECRET|CREDENTIAL|WALLET|TOKEN|API_KEY|PRIVATE)", re.I)
CRED_VAL_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d)\S{8,}$")  # heuristic: secret-looking single token

EXCLUDE_NAME = re.compile(r"^(SYS_|ISEQ\$\$|BIN\$|DR\$|MLOG\$|RUPD\$|APEX\$)")


def ensure_dirs():
    for d in ("tables", "sequences", "views", "packages", "procedures",
              "functions", "triggers", "types", "synonyms", "mviews",
              "jobs", "grants", "seed", "tools"):
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)


def read_clob(v):
    return v.read() if hasattr(v, "read") else v


def wrap_idempotent(ddl, guard_sql=None, ignore_codes=(-955,)):
    """Wrap a DDL statement in a PL/SQL block that ignores 'already exists'."""
    ddl = ddl.strip().rstrip("/").rstrip().rstrip(";").strip()
    esc = ddl.replace("'", "''")
    codes = ",".join(str(c) for c in ignore_codes)
    if len(esc) > 30000:
        # too big for a PL/SQL literal — emit plain (first run only)
        return ddl + ";\n"
    return (
        "begin\n"
        f"  execute immediate '{esc}';\n"
        "exception when others then\n"
        f"  if sqlcode not in ({codes}) then raise; end if;\n"
        "end;\n/\n"
    )


def sql_lit(v, dtype):
    if v is None:
        return "NULL"
    if dtype in ("NUMBER", "FLOAT", "BINARY_DOUBLE", "BINARY_FLOAT"):
        return str(v)
    if dtype == "DATE":
        return "to_date('%s','YYYY-MM-DD HH24:MI:SS')" % v.strftime("%Y-%m-%d %H:%M:%S")
    if dtype.startswith("TIMESTAMP"):
        return "to_timestamp('%s','YYYY-MM-DD HH24:MI:SS.FF6')" % v.strftime("%Y-%m-%d %H:%M:%S.%f")
    s = read_clob(v)
    s = str(s).replace("'", "''")
    if len(s) <= 2000:
        return "'%s'" % s
    chunks = [s[i:i + 2000] for i in range(0, len(s), 2000)]
    return "||".join("to_clob('%s')" % c for c in chunks)


TRANSFORMS = """
      begin
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'SEGMENT_ATTRIBUTES',false);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'STORAGE',false);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'TABLESPACE',false);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'SQLTERMINATOR',false);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'CONSTRAINTS',true);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'REF_CONSTRAINTS',false);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'EMIT_SCHEMA',false);
        dbms_metadata.set_transform_param(dbms_metadata.session_transform,'PARTITIONING',true);
      end;"""


class ResilientCursor:
    """Cursor wrapper that reconnects (and re-applies metadata transforms) on drop."""
    def __init__(self):
        self._connect()

    def _connect(self):
        self.conn = connect_atp("queryapp", "DMT_OWNER")
        self.cur = self.conn.cursor()
        self.cur.execute(TRANSFORMS)

    def execute(self, sql, *args, **kw):
        import oracledb
        for attempt in (1, 2, 3):
            try:
                self.cur.execute(sql, *args, **kw)
                return self.cur
            except (oracledb.InterfaceError, oracledb.OperationalError, oracledb.DatabaseError) as e:
                msg = str(e)
                if attempt < 3 and any(c in msg for c in ("DPY-1001", "DPY-4011", "DPY-6005", "ORA-03113", "ORA-03135", "ORA-12570")):
                    print("  ..reconnecting after: %s" % msg.splitlines()[0])
                    try:
                        self.conn.close()
                    except Exception:
                        pass
                    self._connect()
                    continue
                raise

    def fetchall(self):
        return self.cur.fetchall()

    def fetchone(self):
        return self.cur.fetchone()

    def close(self):
        self.conn.close()


def main():
    ensure_dirs()
    cur = ResilientCursor()

    def get_ddl(obj_type, name):
        cur.execute("select dbms_metadata.get_ddl(:t,:n) from dual", t=obj_type, n=name)
        ddl = read_clob(cur.fetchone()[0])
        # ATP emits USING_NLS_COMP collation clauses; Oracle Free runs
        # MAX_STRING_SIZE=STANDARD where they raise ORA-43929. They are the
        # default pseudo-collation, so stripping is behavior-neutral.
        ddl = ddl.replace(' DEFAULT COLLATION "USING_NLS_COMP"', '')
        ddl = ddl.replace(' COLLATE "USING_NLS_COMP"', '')
        return ddl

    def names(sql, *args):
        cur.execute(sql, args)
        return [r[0] for r in cur.fetchall() if not EXCLUDE_NAME.match(r[0])]

    counts = {}
    install = []   # list of (section_header_or_None, relative_path)

    def write(sub, fname, content):
        p = os.path.join(ROOT, sub, fname)
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
        return sub + "/" + fname

    # ---------------- TABLES ----------------
    tables = names("select table_name from user_tables where nested='NO' order by table_name")
    fk_lines = []
    tab_files = []
    for t in tables:
        parts = ["-- %s (generated from ATP %s)\n" % (t, datetime.date.today())]
        ddl = get_ddl("TABLE", t)
        parts.append(wrap_idempotent(ddl))
        # non-constraint indexes
        cur.execute("""
            select index_name from user_indexes
            where table_name=:t and index_type not in ('LOB','IOT - TOP')
              and index_name not in (select index_name from user_constraints
                                     where table_name=:t and index_name is not null)
            order by index_name""", t=t, )
        for (ix,) in cur.fetchall():
            if EXCLUDE_NAME.match(ix):
                continue
            try:
                ixddl = get_ddl("INDEX", ix)
                parts.append(wrap_idempotent(ixddl, ignore_codes=(-955, -1408)))
            except Exception as e:
                parts.append("-- index %s: could not extract (%s)\n" % (ix, e))
        # comments
        try:
            cur.execute("select dbms_metadata.get_dependent_ddl('COMMENT','%s') from dual" % t)
            c = read_clob(cur.fetchone()[0]).strip()
            # split on newlines between COMMENT statements, terminate each
            stmts = re.split(r"(?<=')\s*\n\s*(?=COMMENT )", c)
            parts.append("\n".join(s.strip() + ";" for s in stmts if s.strip()) + "\n")
        except Exception:
            pass
        tab_files.append(write("tables", t.lower() + ".sql", "\n".join(parts)))
        # FKs -> deferred file
        cur.execute("select constraint_name from user_constraints where table_name=:t and constraint_type='R' order by 1", t=t)
        for (cn,) in cur.fetchall():
            try:
                fkddl = get_ddl("REF_CONSTRAINT", cn)
                fk_lines.append("-- %s.%s\n" % (t, cn) + wrap_idempotent(fkddl, ignore_codes=(-955, -2275, -2264)))
            except Exception as e:
                fk_lines.append("-- FK %s on %s: could not extract (%s)\n" % (cn, t, e))
    counts["tables"] = len(tables)
    fk_file = write("tables", "_foreign_keys.sql",
                    "-- All foreign keys, applied after every table exists\n" + "\n".join(fk_lines))

    # ---------------- SEQUENCES (skip identity ISEQ$$) ----------------
    seqs = names("select sequence_name from user_sequences order by sequence_name")
    seq_files = []
    for s in seqs:
        ddl = get_ddl("SEQUENCE", s)
        seq_files.append(write("sequences", s.lower() + ".sql",
                               "-- %s\n%s" % (s, wrap_idempotent(ddl))))
    counts["sequences"] = len(seqs)

    # ---------------- SYNONYMS ----------------
    # Built from user_synonyms, not DBMS_METADATA: EMIT_SCHEMA=FALSE strips
    # the target owner, turning cross-schema synonyms (e.g. -> DMT_LOOKUP)
    # into self-references that raise ORA-01471 on install.
    cur.execute("""select synonym_name, table_owner, table_name, db_link
                   from user_synonyms order by synonym_name""")
    syn_rows = [r for r in cur.fetchall() if not EXCLUDE_NAME.match(r[0])]
    syn_files = []
    for s, towner, tname, dblink in syn_rows:
        tgt = '"%s"."%s"' % (towner, tname) if towner else '"%s"' % tname
        if dblink:
            tgt += '@%s' % dblink
        ddl = 'CREATE OR REPLACE EDITIONABLE SYNONYM "%s" FOR %s' % (s, tgt)
        syn_files.append(write("synonyms", s.lower() + ".sql", "-- %s\n%s;\n" % (s, ddl)))
    counts["synonyms"] = len(syn_rows)

    # ---------------- VIEWS (dependency-ordered) ----------------
    views = names("select view_name from user_views order by view_name")
    vset = set(views)
    cur.execute("""select name, referenced_name from user_dependencies
                   where type='VIEW' and referenced_type='VIEW' and referenced_owner=user""")
    deps = {}
    for a, b in cur.fetchall():
        if a in vset and b in vset and a != b:
            deps.setdefault(a, set()).add(b)
    ordered, seen = [], set()
    def visit(v, stack=()):
        if v in seen or v in stack:
            return
        for d in sorted(deps.get(v, ())):
            visit(d, stack + (v,))
        seen.add(v); ordered.append(v)
    for v in sorted(views):
        visit(v)
    view_files = []
    for v in ordered:
        ddl = get_ddl("VIEW", v).strip()
        # ensure FORCE so views referencing pkgs/db-links still create
        ddl = re.sub(r"^\s*CREATE OR REPLACE (FORCE )?", "CREATE OR REPLACE FORCE ", ddl, count=1, flags=re.I)
        view_files.append(write("views", v.lower() + ".sql", "-- %s\n%s;\n" % (v, ddl.rstrip().rstrip(';'))))
    counts["views"] = len(views)

    # ---------------- MATERIALIZED VIEWS ----------------
    mvs = names("select mview_name from user_mviews order by 1")
    mv_files = []
    for m in mvs:
        ddl = get_ddl("MATERIALIZED_VIEW", m)
        mv_files.append(write("mviews", m.lower() + ".sql", "-- %s\n%s" % (m, wrap_idempotent(ddl, ignore_codes=(-955, -12006)))))
    counts["mviews"] = len(mvs)

    # ---------------- TYPES ----------------
    typs = names("select type_name from user_types order by type_name")
    typ_files = []
    for t in typs:
        ddl = get_ddl("TYPE", t)
        typ_files.append(write("types", t.lower() + ".sql", "-- %s\n%s\n/\n" % (t, ddl.rstrip().rstrip("/").rstrip())))
    counts["types"] = len(typs)

    # ---------------- CODE: package specs, bodies, procedures, functions ----------------
    def code_files(obj_type, meta_type, sub, suffix=""):
        objs = names("select object_name from user_objects where object_type=:t order by object_name", obj_type)
        out = []
        for o in objs:
            ddl = get_ddl(meta_type, o).rstrip()
            if not ddl.endswith("/"):
                ddl += "\n/"
            out.append(write(sub, o.lower() + suffix + ".sql", "-- %s %s\n%s\n" % (obj_type, o, ddl)))
        return objs, out

    # spec ordering by spec->spec dependencies
    specs = names("select object_name from user_objects where object_type='PACKAGE' order by object_name")
    sset = set(specs)
    cur.execute("""select name, referenced_name from user_dependencies
                   where type='PACKAGE' and referenced_type='PACKAGE' and referenced_owner=user""")
    sdeps = {}
    for a, b in cur.fetchall():
        if a in sset and b in sset and a != b:
            sdeps.setdefault(a, set()).add(b)
    sordered, sseen = [], set()
    def svisit(v, stack=()):
        if v in sseen or v in stack:
            return
        for d in sorted(sdeps.get(v, ())):
            svisit(d, stack + (v,))
        sseen.add(v); sordered.append(v)
    for s in sorted(specs):
        svisit(s)
    spec_files = []
    for o in sordered:
        ddl = get_ddl("PACKAGE_SPEC", o).rstrip()
        if not ddl.endswith("/"):
            ddl += "\n/"
        spec_files.append(write("packages", o.lower() + ".pks.sql", "-- PACKAGE %s\n%s\n" % (o, ddl)))
    counts["package specs"] = len(specs)

    bodies = names("select object_name from user_objects where object_type='PACKAGE BODY' order by object_name")
    body_files = []
    for o in bodies:
        ddl = get_ddl("PACKAGE_BODY", o).rstrip()
        if not ddl.endswith("/"):
            ddl += "\n/"
        body_files.append(write("packages", o.lower() + ".pkb.sql", "-- PACKAGE BODY %s\n%s\n" % (o, ddl)))
    counts["package bodies"] = len(bodies)

    procs, proc_files = code_files("PROCEDURE", "PROCEDURE", "procedures")
    counts["procedures"] = len(procs)
    funcs, func_files = code_files("FUNCTION", "FUNCTION", "functions")
    counts["functions"] = len(funcs)

    # ---------------- TRIGGERS ----------------
    trgs = names("select trigger_name from user_triggers order by 1")
    trg_files = []
    for t in trgs:
        ddl = get_ddl("TRIGGER", t).rstrip()
        if not ddl.endswith("/"):
            ddl += "\n/"
        trg_files.append(write("triggers", t.lower() + ".sql", "-- TRIGGER %s\n%s\n" % (t, ddl)))
    counts["triggers"] = len(trgs)

    # ---------------- SCHEDULER JOBS ----------------
    jobs = names("select job_name from user_scheduler_jobs order by 1")
    job_files = []
    for j in jobs:
        try:
            ddl = get_ddl("PROCOBJ", j).rstrip()
            job_files.append(write("jobs", j.lower() + ".sql",
                "-- SCHEDULER JOB %s (guarded: skip if exists)\n"
                "declare l_cnt number;\nbegin\n"
                "  select count(*) into l_cnt from user_scheduler_jobs where job_name='%s';\n"
                "  if l_cnt = 0 then\n%s\n  end if;\nend;\n/\n"
                % (j, j, "\n".join("    " + l for l in ddl.splitlines()))))
        except Exception as e:
            job_files.append(write("jobs", j.lower() + ".sql", "-- JOB %s: extract failed: %s\n" % (j, e)))
    counts["jobs"] = len(jobs)

    # ---------------- GRANTS ----------------
    grant_lines = ["-- Grants MADE by DMT_OWNER on its objects.",
                   "-- Grantees may not exist on a local test DB; errors are tolerated in install.sql.",
                   "whenever sqlerror continue"]
    cur.execute("""select grantee, privilege, table_name, grantable
                   from user_tab_privs_made where grantor=user order by table_name, grantee, privilege""")
    for grantee, priv, obj, adm in cur.fetchall():
        g = 'GRANT %s ON "%s" TO "%s"%s;' % (priv, obj, grantee, " WITH GRANT OPTION" if adm == "YES" else "")
        grant_lines.append(g)
    grants_made = write("grants", "grants_made.sql", "\n".join(grant_lines) + "\nwhenever sqlerror exit failure rollback\n")
    # grants RECEIVED (documentation; must be granted by ADMIN/other owners)
    recv = ["-- Grants/privileges RECEIVED by DMT_OWNER (for reference; grant these from the grantor/ADMIN)."]
    cur.execute("select privilege from user_sys_privs order by 1")
    recv += ["--   SYSTEM: " + r[0] for r in cur.fetchall()]
    cur.execute("select granted_role from user_role_privs order by 1")
    recv += ["--   ROLE: " + r[0] for r in cur.fetchall()]
    cur.execute("select owner, table_name, privilege from user_tab_privs_recd order by 1,2,3")
    recv += ["--   OBJECT: %s ON %s.%s" % (r[2], r[0], r[1]) for r in cur.fetchall()]
    write("grants", "grants_received_reference.sql", "\n".join(recv) + "\n")
    counts["grant stmts made"] = len(grant_lines) - 3

    # ---------------- SEED DATA ----------------
    seed_files = []
    for t in SEED_TABLES:
        # GENERATED ALWAYS identity columns are excluded: they reject explicit
        # inserts (ORA-32795). Idempotency then relies on the table's natural
        # unique key (e.g. DMT_REST_LOOKUP_TBL.OBJECT_TYPE).
        cur.execute("""select c.column_name, c.data_type from user_tab_cols c
                       where c.table_name=:t and c.virtual_column='NO' and c.hidden_column='NO'
                         and not exists (select 1 from user_tab_identity_cols i
                                         where i.table_name=c.table_name
                                           and i.column_name=c.column_name
                                           and i.generation_type='ALWAYS')
                       order by c.column_id""", t=t)
        cols = cur.fetchall()
        colnames = [c[0] for c in cols]
        cur.execute('select %s from "%s" order by 1' % (",".join('"%s"' % c for c in colnames), t))
        rows = cur.fetchall()
        lines = ["-- Seed data for %s (%d rows, snapshot %s)" % (t, len(rows), datetime.date.today()),
                 "-- Idempotent: duplicate-key inserts are skipped."]
        for row in rows:
            vals = []
            for (cn, dt), v in zip(cols, row):
                if v is not None and CRED_KEY_RE.search(cn):
                    v = "***MASKED-SET-ME***"
                elif t == "DMT_CONFIG_TBL" and cn == "CONFIG_VALUE" and v is not None:
                    key = row[colnames.index("CONFIG_KEY")]
                    if CRED_KEY_RE.search(str(key) or ""):
                        v = "***MASKED-SET-ME***"
                vals.append(sql_lit(v, dt))
            stmt = 'insert into "%s" (%s) values (%s)' % (t, ",".join('"%s"' % c for c in colnames), ",".join(vals))
            lines.append("begin\n  %s;\nexception when dup_val_on_index then null;\nend;\n/" % stmt.replace("\n", " "))
        lines.append("commit;")
        seed_files.append(write("seed", t.lower() + ".sql", "\n".join(lines) + "\n"))
        counts.setdefault("seed rows", 0)
        counts["seed rows"] += len(rows)

    # ---------------- install.sql ----------------
    hdr = """-- ============================================================================
-- db_full/install.sql — COMPLETE DMT_OWNER schema install, generated from the
-- live ATP (queryapp) schema on %s by db_full/tools/snapshot_atp.py.
--
-- Run with SQLcl connected AS DMT_OWNER (never ADMIN):
--     sql dmt_owner/<pw>@<db> @db_full/install.sql
--
-- Re-runnable: tables/sequences/indexes are guarded (already-exists ignored),
-- code objects are CREATE OR REPLACE, seeds skip duplicate keys.
-- Storage/tablespace clauses were stripped for portability (see README.md).
-- ============================================================================
set define off
set serveroutput on
whenever sqlerror exit failure rollback
alter session set current_schema = DMT_OWNER;
""" % datetime.date.today()
    L = [hdr]
    def section(title, files):
        if not files:
            return
        L.append("\nprompt == %s ==" % title)
        L.extend("@@../%s" % f for f in files)
    section("Types", typ_files)
    section("Sequences", seq_files)
    section("Tables", tab_files)
    section("Foreign keys", [fk_file])
    section("Synonyms", syn_files)
    section("Views (dependency order)", view_files)
    section("Materialized views", mv_files)
    section("Package specs (dependency order)", spec_files)
    section("Functions", func_files)
    section("Procedures", proc_files)
    section("Package bodies", body_files)
    section("Triggers", trg_files)
    section("Scheduler jobs", job_files)
    section("Grants made", [grants_made])
    section("Seed data", seed_files)
    L.append("""
prompt == Recompile schema ==
exec dbms_utility.compile_schema(schema => user, compile_all => false)

prompt == Invalid objects remaining (expected: DB-link/Fusion-dependent) ==
select object_type, object_name from user_objects where status='INVALID' order by 1,2;

prompt == db_full/install.sql complete ==
""")
    # install.sql lives in db_full/, files referenced ../<sub>/.. -> actually same dir; fix paths
    text = "\n".join(L).replace("@@../", "@@")
    with open(os.path.join(ROOT, "install.sql"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

    print("SNAPSHOT COMPLETE")
    for k, v in counts.items():
        print("  %-16s %s" % (k, v))
    cur.close()


if __name__ == "__main__":
    main()
