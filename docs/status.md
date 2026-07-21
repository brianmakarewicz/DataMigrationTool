# DMT2 -- Session Status Log

## Session -- 2026-07-16/17
**What was done:** Regression hardening, cross-object reference standard, upload
completion, and the funnel view -- eight PRs merged, one open.

Merged:
- **STG-error wiring generalized** -- 8 pre-validators write `DMT_STG_TFM_ERROR_TBL`
  `[PRE_VALIDATION]` rows; the standard `FLAG_STG_FAILED` helper is on all 42
  STG-owning validators (PRs #164, #167).
- **Full-fidelity upload completed (both formats)** -- proprietary multi-CSV zip
  (94 objects, 5,107 dict columns) + FBDI zip with seeded filenames/positions +
  new `UPLOAD_ZIP_AUTO` auto-detect routing; proven on Docker; two test zips in
  `test/upload_samples/` (PR #171).
- **`DMT_XREF_PKG`** -- shared cross-reference resolver, one function per
  referenceable key returning the most-recent-LOADED value or the raw source
  value; BillingEvents `PROJECT_NUMBER` converted onto it (PR #172). Established
  as the §7 standard for prefixing cross-object references; other transformers to
  follow (backlog, PR #174).
- **Expenditures NONLABOR fix** -- generator now emits the 4 `NON_LABOR_RESOURCE`
  columns for NONLABOR rows (fixes the ORA-01400 zero-load; PR #173).
- **Funnel view** -- `DMT_OBJECT_FUNNEL_V` built and deployed; per run/object/
  sub-object stage counts; APEX UI unblocked (prompt handed off) (PR #178).
- **Transform-stage error-capture standard documented** -- §7 RED rule +
  `GENERIC_OBJECT_FLOW.html` step 3.3b (shared `DMT_TFM_ERRLOG` + `LOG ERRORS` +
  fold + row-by-row fallback). Code not yet built (PR #176).

Regression + diagnosis:
- Rebuilt the RegressionTest scenario data (STG-only rebuild SQL; never deletes
  TFM). Ran two full regressions: 167 (ALL-mode) and 168.
- Root-caused the three zero-load objects: **AR** = demo pod has consolidated
  billing enabled, which rejects the master-mode AutoInvoice job (parked, needs
  the non-master job path); **BillingEvents** = transformer prefixed
  `PROJECT_NUMBER` (fixed via `DMT_XREF_PKG`); **Expenditures** = generator column
  shift (fixed, PR #173).

**New finding logged (backlog):** ALL/FAILED-mode transform re-reads rows that
pre-validation rejected, so pre-validation is bypassed outside NEW mode. The
funnel view compensates (reaching TFM wins), but the transform predicate should
exclude pre-validation-failed rows in every mode.

**Open PRs:** #169 (APEX run-detail in-progress-icon fix -- changes requested,
UI side). All of this session's PRs merged.

**What's next:** build the transform-stage error wiring (documented standard);
have the APEX agent build the funnel UI + the "Auto detect" upload radio; the AR
non-master AutoInvoice job change (parked); retest BillingEvents/Expenditures on
the next regression; convert the other transformers to `DMT_XREF_PKG`.

## Session -- 2026-07-14
**What was done:** Requirements-design review of the canonical design doc
(`workspace/DMT2/docs/DMT_DESIGN.html`); artifact republished. Related edits to
`objects/Customers/README.md`. Specifics:
- Added subsection 7.1 "Canonical per-object processing recipe," built from the real
  DMT2 code (Suppliers template plus GLBalances/Customers partitioning).
- Decided to RETIRE 1099Invoices as a separate object -- it is AP filtered to invoice
  type 1099.
- Rewrote the BIP-mirror rule in plain English and added the change-the-model sequence
  (accepted).
- Verified BIP objects against the single-source object list: all 25 FBDI objects match.
  Found two naming splits (GLBudgets vs GLBudgetBalances; Lookups vs COMMON_LOOKUPS) plus
  a `/Custom/DMT/` path drift. Logged a BIP conformance-checker rule (red, awaiting approval).
- Tightened the seed-departure rule to require owner approval before a departure ships (red).
- Moved the HZ customer-batch resolved issue out of the standards table into
  `objects/Customers/README.md`; corrected that README's stale "blocked" status.
- Merged the two section-1 tables into one: folded BIP data-model / report / interface into
  the object table as three columns and deleted the standalone BIP table, so the object list
  can no longer diverge.
- Added a "Depends on" column to all four object tables (from DMT_PIPELINE_DEF_TBL.DEPENDS_ON).
- Added four specific engine-cleanup backlog entries (red) with exact files, procedures, and
  line numbers: (1) reconcile double-registration fail-open (dmt_queue_worker_pkg vs loader
  ELSIF 1152-1201, x_success:=TRUE fall-through at :1203); (2) GLBudgets dual identity
  (RUN_GL_BUDGETS renames to 'GLBudgetBalances' at dmt_loader_pkg.pkb.sql:4726 plus 9 loader
  arms); (3) retire 1099Invoices; (4) remove dead PlanningBudgets engine arms.
- Promoted the 15 owner-approved rules plus the Pipeline column, the SupplierBankAccounts row,
  and the canonical lookup registry to accepted (black).

**Rule established this session:** In this design doc, RED means exactly one thing --
awaiting the owner's approval. Work-done status is tracked in the Status column, never by
color. Proposed work becomes a backlog item, which may be red until approved.

**Open items awaiting the owner (all red in the doc):** the Post-Install rule
(setup_runtime_config.py taking the connections-file path as an argument -- not yet approved),
the tightened seed-departure rule, the BIP checker rule, the four new backlog entries, and
the pre-existing red section-12 rows from earlier sessions.

**What's next:** These design-doc changes are NOT this session's priority for follow-up work.
The active priority order (restated by the owner 2026-07-14) is:
1. DMT rebuild on the local Docker (primary).
2. Generic per-object flow review (the canonical per-object processing recipe / generic
   starter flow).
3. APEX install on the local Docker.
4. Requirements design review (DMT_DESIGN.html) -- this session's work; now behind the three
   above. Next design-doc action is to get owner rulings on the red items listed above, then
   promote or remove them.

**Blockers:** Today's DMT_DESIGN.html and Customers/README.md changes are NOT yet committed to
git. DMT2 main is protected, so this needs a short-lived branch plus a PR before the changes
land. Three timestamped safety archives (DMT_DESIGN.html.archive.2026071*) are in docs/ and
should not be committed.
