#!/usr/bin/env python3
"""One-shot generator for the WORK_QUEUE_ID foundation change.

For every real TFM CREATE TABLE file plus the FBDI CSV and ZIP tables:
  1. Insert  "WORK_QUEUE_ID" NUMBER,  into the CREATE TABLE column list
     (on the line immediately before the PRIMARY KEY constraint line).
  2. Emit the FK ALTER for _foreign_keys.sql and the migration script.

The WORK_QUEUE_ID column is NULLABLE for now (NOT NULL is a later phase once
the code stamps it). FK -> DMT_WORK_QUEUE_TBL(QUEUE_ID).

Constraint names are derived from each table's PK constraint (replace _PK with
_WQFK); if that would exceed Oracle's 30-char identifier limit the base is
truncated and a short deterministic hash appended so names stay unique.

Run from the worktree root:  python scripts/gen_work_queue_id.py
"""
import hashlib
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TABLES = ROOT / "db" / "tables"

# Real object TFM tables carry transformed records keyed on TFM_SEQUENCE_ID.
# dmt_mock_tfm_tbl (test-only fixture, PK MOCK_ID) and dmt_stg_tfm_error_tbl
# (error log, PK ERROR_ID) are NOT object transform tables and are excluded.
EXCLUDE = {"dmt_mock_tfm_tbl.sql", "dmt_stg_tfm_error_tbl.sql"}

# The FBDI staging/holding tables (one zip -> many csv rows).
EXTRA = ["dmt_fbdi_csv_tbl.sql", "dmt_fbdi_zip_tbl.sql"]

PK_RE = re.compile(r'CONSTRAINT "([A-Z0-9_]+)" PRIMARY KEY')

# Column line inserted into the CREATE TABLE list. Tabs+spacing to match the
# generated-from-ATP indentation used by the surrounding column lines.
COL_LINE = '\t"WORK_QUEUE_ID" NUMBER, \n'


def fk_name(pk_name: str) -> str:
    """Derive a unique <=30-char FK constraint name from the PK name."""
    base = pk_name[:-3] if pk_name.endswith("_PK") else pk_name  # strip _PK
    cand = base + "_WQFK"
    if len(cand) <= 30:
        return cand
    # Too long: truncate the base and append a 4-char hash of the full base so
    # the name stays deterministic and collision-resistant.
    h = hashlib.md5(base.encode()).hexdigest()[:4].upper()
    keep = 30 - len("_WQFK_") - len(h)  # room for "_WQFK_" + hash
    return f"{base[:keep]}_WQFK_{h}"


def process(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    # Find the CREATE TABLE column list's PK line: the CONSTRAINT ... PRIMARY KEY
    # inside the execute-immediate DDL. There is exactly one per file.
    pk_line_idx = None
    pk_name = None
    for i, ln in enumerate(lines):
        m = PK_RE.search(ln)
        if m:
            pk_line_idx = i
            pk_name = m.group(1)
            break
    if pk_line_idx is None:
        raise RuntimeError(f"no PK constraint found in {path.name}")

    # Derive table name from the CREATE TABLE statement.
    tm = re.search(r'CREATE TABLE "([A-Z0-9_]+)"', text)
    table_name = tm.group(1)

    already = 'WORK_QUEUE_ID' in text
    if not already:
        lines.insert(pk_line_idx, COL_LINE)
        path.write_text("".join(lines), encoding="utf-8")

    return table_name, fk_name(pk_name)


def main():
    targets = sorted(
        p for p in TABLES.glob("*tfm*.sql") if p.name not in EXCLUDE
    )
    targets += [TABLES / e for e in EXTRA]

    fks = []  # (table_name, fk_constraint_name)
    seen_fk = {}
    for p in targets:
        tname, fkname = process(p)
        if fkname in seen_fk:
            raise RuntimeError(
                f"FK name collision {fkname}: {seen_fk[fkname]} vs {tname}"
            )
        seen_fk[fkname] = tname
        fks.append((tname, fkname))

    print(f"Processed {len(fks)} tables")
    # Write the FK/migration fragments to a temp file the caller assembles.
    frag = ROOT / "scripts" / "_wq_fk_fragments.txt"
    with frag.open("w", encoding="utf-8") as fh:
        for tname, fkname in fks:
            fh.write(f"{tname}|{fkname}\n")
    print(f"Fragments -> {frag}")


if __name__ == "__main__":
    main()
