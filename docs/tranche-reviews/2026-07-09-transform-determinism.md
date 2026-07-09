# Transform Determinism Fix (2026-07-09)

Not a blind review — an engineering note recording a real defect, its fix, the new
permanent guard, and the work still outstanding.

## The bug

Every transform package copies staging rows into its transform table with a plain
`INSERT INTO <obj>_TFM_TBL (...) SELECT ... FROM <obj>_STG_TBL WHERE ...` that had
**no `ORDER BY`**. When the transform table's primary key became
`GENERATED ... AS IDENTITY`, Oracle assigns each identity value in the row order the
`SELECT` happens to return. With no `ORDER BY`, that order is the heap-scan order, which
is not stable — it changed on roughly one run in six.

The FBDI/HDL generator emits rows `ORDER BY TFM_SEQUENCE_ID`. So when the identity ids
came out in a different order, the generated file's line order changed too, and the
golden byte-compare failed intermittently. Nothing was wrong with the data; only the row
order was unstable.

The Workers port found this first and fixed its own seven inserts
(`ORDER BY s.STG_SEQUENCE_ID`).

## The fix (this change)

Added a deterministic `ORDER BY s.STG_SEQUENCE_ID` to every
`INSERT INTO ..._TFM_TBL ... SELECT ... FROM ..._STG_TBL` in the four remaining
proven / Wave-1 transform packages. `STG_SEQUENCE_ID` is the staging primary key —
always present, always unique, the stable lineage key.

| Package | Inserts fixed |
|---|---|
| `dmt_poz_sup_transform_pkg` | 5 (Suppliers, Addresses, Sites, Site Assignments, Contacts) |
| `dmt_cust_transform_pkg` | 7 (Parties, Locations, Party Sites, Party Site Uses, Accounts, Acct Sites, Acct Site Uses) |
| `dmt_gl_transform_pkg` | 1 (GL interface) |
| `dmt_project_transform_pkg` | 4 (Projects, Tasks, Team Members, Txn Controls) |

All four recompiled `VALID`; the invalid baseline is unchanged. Generators and
reconcilers were **not** touched — the generators already order by `TFM_SEQUENCE_ID`.

Determinism proof: each of the five objects (Suppliers, Customers, GLBalances, Projects,
Workers) ran its golden compare **6 times consecutively, 6/6 byte-identical** — the
statistical proof the ~1-in-6 flake is gone.

## The permanent guard

`test/golden/run_golden_tests.sh` now runs every object's full
land -> transform -> generate -> extract -> golden-compare cycle **twice** (two
independent runs, new prefix each), and fails the object unless both runs pass their
golden compare. Because each run byte-compares against the one shared golden, "run 1 ==
golden AND run 2 == golden" transitively proves the two runs produced identical output.
A single-run pass is no longer sufficient. Override the repeat count with `GOLDEN_RUNS`
(default 2). This guard will catch any transform that regresses — or any of the
remaining objects that still has the bug — the moment it is added to the golden set.

## Still outstanding — the other ~35 objects

Only the five proven objects are fixed here. The remaining ~35 transform packages in
`db/packages/*_transform_pkg.pkb.sql` still have the same unordered
`INSERT INTO ..._TFM_TBL ... SELECT ... FROM ..._STG_TBL`. They are latent: their
identity-vs-heap-order flakiness will surface the same way when each is exercised by a
golden test.

Tracking decision: fix each one at its own port (when that object gets its golden test
and Wave-1/2/3 slice), applying the identical `ORDER BY <stg pk>`. The twice-through
golden guard above is the safety net — any object added to the golden set without the
`ORDER BY` will fail its determinism run instead of passing silently.

## Workers sequence cleanup (same change)

14 per-table ID sequences for the Workers / Person* tables were still enrolled in
`db/install.sql` even though those STG/TFM tables are now `AS IDENTITY` — dead objects.
Removed the 14 `@@sequences/dmt_worker_*_seq.sql` / `dmt_person_*_seq.sql` lines and the
14 sequence files, and added `db/tools/drop_retired_worker_sequences.sql` (guarded
drop-if-exists, idempotent) to drop them from an existing database. Verified: no package
referenced any of the 14; all 14 dropped from the live Docker DB and a second run SKIPs
all 14. Mirrors the existing supplier / customer / project retired-sequence tools.
