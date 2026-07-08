# Blind Tranche Review — Sequences (2026-07-07)

Reviewer: blind subagent (no build context; read DMT_DESIGN.html in full first).
Scope: all 206 files in `db/sequences/` + install.sql enrollment.
**Verdict: PASS-WITH-FINDINGS.** Mechanically sound (uniform guarded template, exact 1:1
install enrollment, symmetric STG/TFM coverage, full canonical-object coverage), but the
content visibly inherits live-snapshot drift the design had already decided to kill.

Proposed rules: 4, added to DMT_DESIGN.html section 7 in RED (pending user review):
sequence-name-derives-from-table · no-legacy-objects-in-install-tree ·
committed-DDL-is-greenfield-state · one-PK-generation-mechanism.

## Findings and dispositions

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| 1 | HIGH | 30 Grants sequences use invented abbreviations (GMS_AWD_HDR etc.) matching no table | **DEFER to naming sweep** — rename must land in the same commit as the package/table references that use them (Phase 2 port, per-family). Tracked. |
| 2 | HIGH | Supplier family uses a second scheme (`{stem}_ID_SEQ`/`{stem}_TFM_ID_SEQ`); STG side omits the layer designator | **DEFER to naming sweep** — same reasoning as #1; Suppliers is the Stage D vertical slice, so this lands first. |
| 3 | HIGH | Retired `DMT_PREFIX_SEQ` re-seeded (design: repoint callers to DMT_RUN_PREFIX_SEQ and drop) | **DEFER, tracked as P1** — drop file + repoint callers together when the engine packages port (Stage C). Dropping the file alone breaks install if any package references it. |
| 4 | HIGH | `DMT_RUN_PREFIX_SEQ` contradicted the decided 4-digit spec (START 9627, unbounded MAXVALUE) | **FIXED 2026-07-07** — now START WITH 1000 MAXVALUE 9999 NOCYCLE (design section 6 / Q5). |
| 5 | MED | Legacy `DMT_PREFIX_MASTER_ID_SEQ` re-seeded | **DEFER, tracked** — drop with the legacy table + util functions (existing P1). |
| 6 | MED | PlanningBudgets sequences seeded (object OUT OF SCOPE 2026-07-07) | **DEFER, tracked** — remove with its STG/TFM tables as one commit. |
| 7 | MED | Orphaned RCV_HEADERS/RCV_TRANSACTIONS sequences re-imported (MiscReceipts uses INV_TRX) | **DEFER, tracked** — remove with the orphaned tables as one commit. |
| 8 | MED | `_ID_` infix inconsistent across 9 infrastructure sequences | **DEFER to naming sweep** (covered by proposed rule 1). |
| 9 | MED | Spec says 16 GMS_AWD staging tables; tranche (and tables tree) has 15 | **INVESTIGATE** — reconcile spec count vs tree before Grants object work; likely a spec typo or a genuinely missing table. Open. |
| 10 | MED | All 206 START WITH values are live-ATP counters, not greenfield values | **DEFER to sweep** (covered by proposed rule 3) — mechanical `START WITH 1` normalization, one commit, after user accepts the rule. |
| 11 | MED | Two PK mechanisms in use (8 identity tables vs named sequences) | **DECISION NEEDED** (proposed rule 4) — pick one mechanism; folded into tables-tranche triage. |
| 12 | LOW | ESS_FILE / BIP_RPT sequence stems drift from their tables | **DEFER to naming sweep** (covered by proposed rule 1). |
| 13 | LOW | Sequence headers don't state which table/PK they serve | **DEFER** — resolved automatically if proposed rule 1 is adopted (name = table); otherwise add headers in the sweep. |

## Verified clean
- One uniform guarded idempotent template across all 206 files (within the approved
  deploy-script dynamic-SQL exception).
- install.sql enrollment exact (206:206, no dupes/missing).
- Every STG sequence has a TFM partner and vice versa.
- DMT_LOG_ID_SEQ and DMT_UPLOAD_BATCH_SEQ present per spec; DMT_SCENARIO_TBL correctly
  needs none (identity) — pending the #11 mechanism decision.
