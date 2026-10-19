#!/usr/bin/env python3
"""check_fbdi_upload_mappings.py -- conformance checker for backlog #792 (owner request
2026-10-19): every FBDI file the pipeline's generators write can also be uploaded
through Smart Upload in FBDI format.

THE RULE
--------
Each .csv file an FBDI generator package (db/packages/*_fbdi_gen_pkg.pkb.sql) writes
into its zip is registered for upload: the committed seed
db/seed/dmt_upload_fbdi_metadata.sql routes that file name to at least one staging
object (DMT_UPLOAD_FBDI_FILE_TBL) with its own per-file positions
(DMT_UPLOAD_FBDI_POS_TBL). The seed is generated from
test/upload_samples/fbdi_column_maps.py and must be up to date with it.

WHAT IS CHECKED (statically, committed files only)
--------------------------------------------------
1. FBDI-UPLOAD-REG|<pkg>|<file>: every '<name>.csv' string literal in a generator
   package body (comments removed) is registered in the seed's file registry, unless
   fbdi_column_maps.NOT_UPLOADABLE lists it with a reason (PlanningBudgets).
2. FBDI-UPLOAD-POS|<file>|<object>: every registered (file, object) pair has at least
   one position in the seed.
3. FBDI-UPLOAD-SEED-SYNC|db/seed/dmt_upload_fbdi_metadata.sql: the committed seed is
   byte-identical (line endings aside) to what gen_fbdi_metadata_seed.py renders from
   the maps.

NOT CHECKED (printed every run, per the "checker fidelity" rule): that each slot number
matches the generator's actual column order, and that each mapped name exists in the
staging table (the seed filters names against the dictionary at deploy time). Both are
proven by test/upload_samples/roundtrip_test.py on the local database, which uploads the
rebuilt FBDIFormat.zip and the real generated files and compares staged values.

Violations that existed when the rule was introduced would be listed in
scripts/standards_known_violations.json (checker "check_fbdi_upload_mappings"); there
were none. Only a NEW violation fails.

Exit codes: 0 = no new violations, 1 = new violations, 2 = inputs not found.
"""

import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import standards_known_violations as skv  # noqa: E402

CHECKER = "check_fbdi_upload_mappings"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PKG_DIR = os.path.join(REPO, "db", "packages")
SEED = os.path.join(REPO, "db", "seed", "dmt_upload_fbdi_metadata.sql")
SAMPLES = os.path.join(REPO, "test", "upload_samples")

CSV_LITERAL_RE = re.compile(r"'([A-Za-z0-9_]+\.csv)'")
REG_RE = re.compile(r"select '([^']+)' fbdi_csv_filename, '([^']+)' object_code, \d+ load_order", re.I)
POS_HDR_RE = re.compile(r"^-- (\S+\.csv) -> (\S+)\n(.*?)\n(?=-- \S+\.csv -> |commit;)", re.M | re.S)


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read().replace("\r\n", "\n")


def main():
    print("Every generated FBDI file is registered for FBDI upload (#792)")
    print("=" * 80)
    for p in (PKG_DIR, SEED, SAMPLES):
        if not os.path.exists(p):
            print("ERROR: input not found: " + p)
            return 2
    sys.path.insert(0, SAMPLES)
    import fbdi_column_maps as maps  # noqa: E402
    import gen_fbdi_metadata_seed as gen  # noqa: E402

    seed = read(SEED)
    registered, names = {}, {}
    for f, o in REG_RE.findall(seed):
        registered.setdefault(f.upper(), set()).add(o)
        names[f.upper()] = f
    found = []

    print("Generated files -> upload registry:")
    for path in sorted(glob.glob(os.path.join(PKG_DIR, "*_fbdi_gen_pkg.pkb.sql"))):
        pkg = os.path.basename(path).split(".")[0].upper()
        files = sorted(set(CSV_LITERAL_RE.findall(strip_comments(read(path)))))
        for fn in files:
            if fn in maps.NOT_UPLOADABLE:
                print("  SKIP  %-34s %-36s allowlisted: %s" % (pkg, fn, maps.NOT_UPLOADABLE[fn]))
            elif fn.upper() in registered:
                print("  PASS  %-34s %-36s -> %s" % (pkg, fn, ", ".join(sorted(registered[fn.upper()]))))
            else:
                print("  FAIL  %-34s %-36s not registered" % (pkg, fn))
                found.append(("FBDI-UPLOAD-REG|%s|%s" % (pkg, fn),
                              "%s writes %s but no staging object is registered for it in %s "
                              "(add it to test/upload_samples/fbdi_column_maps.py FILES and "
                              "regenerate the seed)" % (pkg, fn, os.path.relpath(SEED, REPO))))
        if not files:
            print("  NOTE  %-34s writes no .csv literal" % pkg)

    print("\nRegistered pairs carry positions:")
    blocks = {(m.group(1), m.group(2)): m.group(3) for m in POS_HDR_RE.finditer(seed)}
    for f in sorted(registered):
        for o in sorted(registered[f]):
            key = next((k for k in blocks if k[0].upper() == f and k[1] == o), None)
            n = len(re.findall(r" fbdi_position from dual", blocks[key])) if key else 0
            if n == 0:
                found.append(("FBDI-UPLOAD-POS|%s|%s" % (f, o),
                              "%s -> %s is registered without any position" % (f, o)))
            print("  %s  %-36s %-22s %d positions" % ("PASS" if n else "FAIL", names[f], o, n))

    print("\nCommitted seed matches the maps:")
    if gen.render() != seed:
        print("  FAIL  db/seed/dmt_upload_fbdi_metadata.sql is stale")
        found.append(("FBDI-UPLOAD-SEED-SYNC|db/seed/dmt_upload_fbdi_metadata.sql",
                      "the committed seed differs from test/upload_samples/fbdi_column_maps.py; run "
                      "python test/upload_samples/gen_fbdi_metadata_seed.py and commit"))
    else:
        print("  PASS  db/seed/dmt_upload_fbdi_metadata.sql")

    print("\nNot checked: that each slot number matches the generator's column order, and that each "
          "mapped name is a staging column (the seed filters against the dictionary at deploy). Both "
          "are proven on the local database by test/upload_samples/roundtrip_test.py.")
    return skv.report(CHECKER, found)


if __name__ == "__main__":
    sys.exit(main())
