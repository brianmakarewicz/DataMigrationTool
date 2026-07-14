# DMT2 -- Session Status Log

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
