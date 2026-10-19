#!/usr/bin/env python
"""
Generate db/seed/dmt_upload_fbdi_metadata.sql from fbdi_column_maps.py (backlog #792).

The seed is the committed, deployable copy of the FBDI upload maps. It is generated
offline (no database): every position row is filtered at deploy time against the
object's non-admin DMT_UPLOAD_DICT_TBL columns, so a map name with no staging
column never becomes a position. scripts/check_fbdi_upload_mappings.py regenerates
it in memory and fails when the committed file differs.

Usage:
    python test/upload_samples/gen_fbdi_metadata_seed.py          # rewrite the seed
    python test/upload_samples/gen_fbdi_metadata_seed.py --check  # exit 1 if stale
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fbdi_column_maps import FILES, MAPS, FbdiFile  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
SEED = os.path.join(REPO, 'db', 'seed', 'dmt_upload_fbdi_metadata.sql')

HEADER = """\
-- Seed FBDI upload metadata (GENERATED -- do not edit by hand).
--   Source: test/upload_samples/fbdi_column_maps.py
--   Regenerate: python test/upload_samples/gen_fbdi_metadata_seed.py
--   Checked by: scripts/check_fbdi_upload_mappings.py (fails when this file is stale)
--
-- WHAT THIS DOES
--   The FBDI upload format routes each headerless, positional CSV in an Oracle FBDI
--   zip by its file name to the staging object(s) registered for it in
--   DMT_UPLOAD_FBDI_FILE_TBL, and loads it column-by-position using that file's own
--   positions in DMT_UPLOAD_FBDI_POS_TBL (backlog #792: positions are keyed per FBDI
--   file, so BlanketPOs / Contracts load the shared PO staging tables with their own
--   layouts, and Assets FaMassAdditions.csv feeds both the asset header and the asset
--   book). This seed is the INVERSE of FBDI generation: for every file the pipeline's
--   FBDI generators write, the exact 1-based slot each staging column is written to.
--
--   Source of truth: the FBDI generator packages (db/packages/*_fbdi_gen_pkg), read
--   slot by slot into test/upload_samples/fbdi_column_maps.py.
--
--   Section 1 keeps the legacy per-object copy -- DMT_UPLOAD_OBJECT_TBL.FBDI_CSV_FILENAME
--   and DMT_UPLOAD_DICT_TBL.FBDI_POSITION of the object's first file -- for the
--   per-object test tooling; the upload router and loader do not read it.
--
--   MUST run AFTER DMT_UPLOAD_DICT_PKG.SEED_DICTIONARY (db/seed/dmt_upload_object_tbl.sql):
--   positions are filtered against the dictionary's non-admin columns. Idempotent and
--   convergent: MERGE on the business keys, then delete rows the maps no longer hold.
"""


def q(s):
    return "'" + s.replace("'", "''") + "'"


def union(rows, cols, indent='    '):
    """select <v1> c1, <v2> c2 from dual union all ... for a list of value tuples."""
    out = []
    for i, r in enumerate(rows):
        sel = ', '.join(f"{v} {c}" for v, c in zip(r, cols))
        out.append(indent + ("select " if i == 0 else "union all select ") + sel + " from dual")
    return '\n'.join(out)


def positions(x):
    """[(column, slot)] of one layout, first occurrence of each name."""
    seen, out = set(), []
    for i, c in enumerate(x.cols, 1):
        if c and c not in seen:
            seen.add(c)
            out.append((c, i))
    return out


def render():
    parts = [HEADER]

    # 1) legacy per-object file name
    objs = sorted(MAPS.items())
    parts.append("-- 1) Legacy per-object copy (first file of each object) for the per-object test tooling.")
    parts.append('merge into "DMT_UPLOAD_OBJECT_TBL" t\nusing (\n'
                 + union([(q(oc), q(fn)) for oc, (fn, _c) in objs], ['object_code', 'fbdi_csv_filename'])
                 + '\n) s\non (t."OBJECT_CODE" = s.object_code)\n'
                 'when matched then update set t."FBDI_CSV_FILENAME" = s.fbdi_csv_filename;\n')
    parts.append('update "DMT_UPLOAD_DICT_TBL"\nset    "FBDI_POSITION" = null\nwhere  "OBJECT_CODE" in ('
                 + ', '.join(q(oc) for oc, _v in objs) + ');\n')
    for oc, (fn, cols) in objs:
        pos = positions(FbdiFile(fn, oc, cols, 1, False, None, None, None))
        parts.append('merge into "DMT_UPLOAD_DICT_TBL" t\nusing (\n'
                     + union([(q(oc), q(c), str(p)) for c, p in pos],
                             ['object_code', 'column_name', 'fbdi_position'])
                     + '\n) s\non (t."OBJECT_CODE" = s.object_code and t."COLUMN_NAME" = s.column_name)\n'
                     'when matched then update set t."FBDI_POSITION" = s.fbdi_position;\n')

    # 2) file registry
    reg = [(q(x.file), q(x.object), str(x.load_order), q('Y' if x.distinct else 'N'), q(x.date_mask))
           for x in FILES]
    parts.append("-- 2) FBDI file routing registry: one row per (file, staging object).")
    parts.append('merge into "DMT_UPLOAD_FBDI_FILE_TBL" t\nusing (\n'
                 + union(reg, ['fbdi_csv_filename', 'object_code', 'load_order',
                               'distinct_rows_flag', 'date_mask'])
                 + '\n) s\non (t."FBDI_CSV_FILENAME" = s.fbdi_csv_filename and t."OBJECT_CODE" = s.object_code)\n'
                 'when matched then update set t."LOAD_ORDER" = s.load_order,\n'
                 '                             t."DISTINCT_ROWS_FLAG" = s.distinct_rows_flag,\n'
                 '                             t."DATE_MASK" = s.date_mask\n'
                 'when not matched then insert ("FBDI_CSV_FILENAME", "OBJECT_CODE", "LOAD_ORDER", '
                 '"DISTINCT_ROWS_FLAG", "DATE_MASK")\n'
                 '     values (s.fbdi_csv_filename, s.object_code, s.load_order, s.distinct_rows_flag, '
                 's.date_mask);\n')
    parts.append("-- Registry rows the maps no longer hold (their positions go with them, ON DELETE CASCADE).")
    parts.append('delete from "DMT_UPLOAD_FBDI_FILE_TBL" t\nwhere not exists (\n  select 1 from (\n'
                 + union([(q(x.file), q(x.object)) for x in FILES], ['fbdi_csv_filename', 'object_code'], indent='    ')
                 + '\n  ) s\n  where s.fbdi_csv_filename = t."FBDI_CSV_FILENAME" and s.object_code = t."OBJECT_CODE");\n')

    # 3) positions, one MERGE + stale DELETE per (file, object)
    parts.append("-- 3) Positions per (file, staging object), filtered to the object's non-admin dictionary columns.")
    for x in FILES:
        pos = positions(x)
        parts.append(f"-- {x.file} -> {x.object}")
        parts.append('merge into "DMT_UPLOAD_FBDI_POS_TBL" t\nusing (\n'
                     '  select f."FBDI_FILE_ID" fbdi_file_id, s.column_name, s.fbdi_position\n'
                     '  from (\n'
                     + union([(q(c), str(p)) for c, p in pos], ['column_name', 'fbdi_position']).replace('\n', '\n  ').replace('    select', '      select', 1)
                     + '\n  ) s\n'
                     '  join "DMT_UPLOAD_FBDI_FILE_TBL" f\n'
                     f'    on f."FBDI_CSV_FILENAME" = {q(x.file)} and f."OBJECT_CODE" = {q(x.object)}\n'
                     '  join "DMT_UPLOAD_DICT_TBL" d\n'
                     '    on d."OBJECT_CODE" = f."OBJECT_CODE" and d."COLUMN_NAME" = s.column_name\n'
                     '   and d."IS_ADMIN_COLUMN" = \'N\'\n'
                     ') s\non (t."FBDI_FILE_ID" = s.fbdi_file_id and t."COLUMN_NAME" = s.column_name)\n'
                     'when matched then update set t."FBDI_POSITION" = s.fbdi_position\n'
                     'when not matched then insert ("FBDI_FILE_ID", "COLUMN_NAME", "FBDI_POSITION")\n'
                     '     values (s.fbdi_file_id, s.column_name, s.fbdi_position);\n')
        names = ', '.join(q(c) for c, _p in pos)
        parts.append('delete from "DMT_UPLOAD_FBDI_POS_TBL" t\n'
                     'where t."FBDI_FILE_ID" = (select f."FBDI_FILE_ID" from "DMT_UPLOAD_FBDI_FILE_TBL" f\n'
                     f'                         where f."FBDI_CSV_FILENAME" = {q(x.file)} and f."OBJECT_CODE" = {q(x.object)})\n'
                     f'and   t."COLUMN_NAME" not in ({names});\n')
    parts.append('commit;\n')
    return '\n'.join(parts)


def main():
    text = render()
    if '--check' in sys.argv:
        cur = open(SEED, encoding='utf-8').read().replace('\r\n', '\n') if os.path.exists(SEED) else ''
        if cur != text:
            print(f"STALE: {SEED} differs from the maps; run gen_fbdi_metadata_seed.py")
            return 1
        print("seed up to date")
        return 0
    with open(SEED, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    print(f"wrote {SEED}: {len(FILES)} file registrations, "
          f"{sum(len(positions(x)) for x in FILES)} candidate positions")
    return 0


if __name__ == '__main__':
    sys.exit(main())
