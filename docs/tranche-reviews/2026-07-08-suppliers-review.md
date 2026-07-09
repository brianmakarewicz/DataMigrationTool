# Blind Tranche Review — Suppliers vertical slice (2026-07-08)

Reviewer: blind subagent (spec read in full; deployed DB state verified against git).
**Verdict: FAIL** — object model, seeds, identity conversions, deploy-guard concept, and
test scaffolding praised; but the ported code ships HIGH violations of binding accepted
rules, and the E2E's success masked them (the old architecture works; it is not the
decided architecture).

## HIGH findings — dispositions
| # | Finding | Disposition |
|---|---------|-------------|
| H1 | Reconciler writes Fusion outcomes back to STAGING (five echo blocks) — violates the most-repeated decided rule; second writer of row status | **FIX NOW** (agent dispatched): remove all five blocks; TFM is the sole outcome record. |
| H2 | Validators check parent STG STATUS='LOADED' (illegal value on STG) instead of the parent's LOADED TFM row — depends on H1's write-back | **FIX NOW**: rewrite all four checks to the spec's TFM-tier pre-validate. |
| H3 | Tests pin H1/H2 green with misquoted spec citations; live test celebrates retired P_BATCH_ID | **FIX NOW**: fixtures create TFM-tier parent state; citations corrected; P_BATCH_ID marked legacy-pending-contract. |
| H4 | **Fusion password logged in PLAINTEXT** to DMT_LOG_TBL on every reconciliation (raw SOAP envelope) | **FIX NOW, security**: shared MASK_CREDENTIALS helper on every envelope log across all packages; committed scrub tool cleanses the local log. NOTE: the frozen ATP's log table has the same exposure from the old stack — flagged to owner. |
| H5 | Two more private UTL_HTTP transports; one checks no HTTP status at all | **FIX NOW**: delegate/status-check; full consolidation stays the tracked transport refactor. |
| H6 | New BIP reports built to retired P_BATCH_ID pattern, not Contract v1 (names, params, columns, no pagination) | **TRACKED WORK ITEM — "Suppliers Contract v1 report rework"**: already the planned section-12 conformance work; schedule before Wave-1 reconciliation reuse. |
| H7 | LOADED granted from interface tier alone (Rule #1 gap; already on the section-12 backlog for these 15 reports) | **TRACKED with H6** — BASE-tier proof lands with the contract rework. |
| H8 | Null FUSION_VENDOR_SITE_ID on LOADED site rows — hidden ("Known Issues: None") | **FIX NOW (tracking)**: README Known Issue + appended residue note on affected rows; id backfill lands with H6. |
| H9 | bip/*/query.sql mirrors contradict deployed .xdm (three meanings of P_BATCH_ID) | **FIX NOW**: regenerate mirrors byte-matching the .xdm SQL. |
| H10 | Error-code contract absent in all 13 new packages ("applies to all new code immediately") | **OWNER DECISION PENDING** (same open item as the utility layer): retrofit vs a documented exception for ported object packages until their rewrite. |
| H11 | Contract indexes missing (TFM RUN_ID, (RUN_ID,STATUS); STG SCENARIO_ID; RECON_KEY absent) | **DEFER to the contract-index sweep** (accepted rule; one dedicated pass across all objects). |

## MEDIUM/LOW — grouped dispositions
- M1 retired/invented statuses (RETRY, TRANSFORM_FAILED, VALIDATED/INVALID, LOADED in STG
  comments): **status-vocabulary sweep** (red rule pending) + fixed where F2 touches.
- M2 dead stub validators (would corrupt if called): **delete in the sweep**; tracked.
- M3 ERROR_TEXT=NULL reset (accumulate-never-overwrite violation): **FIX NOW**.
- M4 FAILED-mode selection incomplete; ALL not scenario-gated; p_include_untagged remains:
  **per-object port backlog** (masked-by-H1 behavior re-tested after F2).
- M5 SupplierContacts dependency: seed (SiteAssignments) vs spec (Suppliers) vs README —
  **OWNER: red spec amendment needed**; the live collision justifies the seed's order.
- M6 "sub-object" wording in tests: **FIX NOW**.
- M7 mojibake in 10 table files + seed: **mojibake sweep** (red rule pending).
- M8 index/FK naming off-pattern, unnamed scenario FKs: **naming/constraint sweep**.
- M9 generators use explicit FBDI sequences + MAX() lineage: **per-object identity/RETURNING
  rework with the generator framework refactor**.
- M10 deploy-guard bypass surface (unvalidated object names; REGEXP XML parsing; swallowed
  deletes): **tracked hardening item with the transport refactor**.
- M11 no breadcrumbs/headers in 13 packages: **rolling cleanup**.
- M12-M14, L1-L3: logged; folded into the sweeps above; L2 (README citing external memory
  file) fixed with F4's README edit.

## Proposed rules: 5, added in red to the canonical doc (same PR as this log).
## Re-review: required after the fix PR merges (protocol).
