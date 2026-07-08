# Stage B4 — Golden byte-compare harness (2026-07-08)

**GLBalances verdict: byte-identical** to the golden after exactly three declared
normalizations (prefix, run/group id, DATE_CREATED mask) — verified on two consecutive
local runs; negative tests prove the compare cannot pass vacuously. Full pipeline driven
locally: land → INIT_RUN → transform → generate → extract → compare. GL generate path is
Fusion-free (pure SQL over TFM).

Harness: `test/golden/compare_fbdi.py` (stdlib, per-line round-trip self-check so
field-compare is provably byte-compare) + `normalization_map.json` (per-object data, no
code changes to extend) + `test_glbalances_golden.sh` + `run_golden_tests.sh` (CI runner).

## Defect found and FIXED
`DMT_PIPELINE_INIT_PKG` body was INVALID (one of the two known-invalid packages carried
from the old ATP): referenced nonexistent DMT_INTEGRATION_ID_SEQ, inserted into the
DMT_CONVERSION_MASTER_TBL compatibility VIEW (non-insertable), used STATUS 'OPEN'
(violates the run-status check), omitted NOT NULL CEMLI_SEQUENCE. Rewritten to insert
into DMT_PIPELINE_RUN_TBL directly.

## Documented for the Stage B blind review (not fixed)
1. **Two prefix sequences are both in live use**: DMT_SCHEDULER_PKG.create_run_and_queue
   draws from DMT_RUN_PREFIX_SEQ (~1000, greenfield) while DMT_PIPELINE_INIT_PKG's spec
   uses DMT_PREFIX_SEQ (~9590, retired) — the exact dual-sequence uniqueness hazard the
   design closed. Consolidate to DMT_RUN_PREFIX_SEQ and drop DMT_PREFIX_SEQ at the
   Stage C engine port (already a P1).
2. DMT_GL_TRANSFORM_PKG TFM insert has no ORDER BY — generated CSV row order relies on
   heap-scan order; determinism risk at scale. Ordering standard candidate for generators.
3. `test/regression_test_bundle.zip` GL input differs from the goldens' source data —
   golden-matching inputs must come from the old `insert_regression_test_data.py` rows
   (done for GL, in `test/golden/inputs/`); repeat per object when extending.

## Extension effort (for Stage D/E planning)
Single-CSV FBDI ~1–2h each; multi-CSV (APInvoices/Assets/Requisitions/Projects/POs/
Customers) ~half-day each (needs regex-pattern tokens for embedded interface keys);
Suppliers ~1 day (5 imports, cross-file keys); HDL needs a pipe-delimited format mode
(~half-day first, then 1–2h each).
