# Reconciliation fetch paging review: header boundaries (2026-10-09)

## The rule being checked

Owner decision, 2026-10-09: a reconciliation fetch pages dynamically on header (document)
boundaries. A page is the next N headers plus every line and child that belongs to them, from
both the base and the interface tier. A fixed row cap that can split a document or drop its
children is not allowed, including caller-side multipliers such as "5 report rows per row sent".
Rows are still selected only by the load's Fusion ESS job ids; keys only order the pages and
match returned rows back to TFM rows. The accepted text is in `docs/DMT_DESIGN.html`, BIP
reconciliation report contract, "Reconciliation fetches page on header boundaries".

This is a review only. No object code was changed, nothing was deployed, and nothing was run.

## How paging works today (shared code)

Every reviewed ERP object except the five supplier objects and PlanningBudgets calls the one
shared fetch, `DMT_RECON_CONTRACT_PKG.FETCH_ROWS`.

- `db/packages/dmt_recon_contract_pkg.pkb.sql:78` reads the page size from `BIP_CHUNK_SIZE`
  (default 5,000). The page size is a row count.
- `db/packages/dmt_recon_contract_pkg.pkb.sql:80-82` derives a page-count cap from the caller's
  `p_row_cap`: `GREATEST(2, CEIL(p_row_cap / chunk) + 2)`.
- `db/packages/dmt_recon_contract_pkg.pkb.sql:191` and `:204` take the page's last `RECORD_KEY`
  as the next cursor; `:215` stops on a short page.
- `db/packages/dmt_recon_contract_pkg.pkb.sql:217-229`: when the cap is reached the fetch logs a
  WARN, exits the loop, and still returns success (`:241`). Any rows past the cap are silently
  missing. This is the "fixed cap that can drop children" the rule forbids.
- Every caller passes a generated-row count as `p_row_cap` (for example
  `db/packages/dmt_ap_results_pkg.pkb.sql:93-103`). ARInvoices multiplies it by
  `C_REPORT_ROWS_PER_TFM_ROW = 5` (`db/packages/dmt_ar_results_pkg.pkb.sql:88-95, 189`); that
  object is being fixed by another agent and is not reviewed here.
- On the data-model side, every paged report ends with `WHERE record_key > :P_AFTER_KEY ORDER BY
  record_key FETCH FIRST :P_CHUNK_SIZE ROWS ONLY` (Requisitions alone uses `WITH TIES`). The cut
  is on a row count, so a page can end in the middle of a document. When two rows share one
  `RECORD_KEY` and the cut falls between them, the strict `>` on the next page skips the second
  one, and that row is lost.

`DMT_RECON_ENGINE_PKG.fetch_and_stage` (`db/packages/dmt_recon_engine_pkg.pkb.sql:20-21, 98-111,
175-184`) pages the same row-count way with a fixed 100,000-page ceiling. No object is routed
through it any more (GLBalances moved back to `FETCH_ROWS` in
`db/migrations/2026-09-30_glbalances_shared_parser_option_a.sql`), but it should get the same fix
or be retired.

What protects us today: `FETCH_ROWS` collects every page before any TFM row is updated, so a
document split across two pages is still reconciled correctly. Rows are actually lost only in
two cases: duplicate keys at a page edge, or the page cap being hit. Both are rare at current
test volumes and both get worse at production volumes. The rule still fails every multi-row
document that is paged by row count.

## Per-object results (ERP)

"Split" means a page boundary can fall inside one document. "Drop" means a row can be lost.

| Object | Current paging (keyset column, page size, caps) | Verdict | Proposed fix | Backlog |
|---|---|---|---|---|
| (shared) `FETCH_ROWS` | Row-count pages; cursor = last `RECORD_KEY`; page cap from `p_row_cap`, hitting it returns success with rows missing (`dmt_recon_contract_pkg.pkb.sql:80-82, 215-229, 241`) | FAIL | Page size counts headers. Cursor = last header key. Stop when a page returns fewer headers than the page size. Remove `p_row_cap`. Replace the cap with a no-progress guard that raises. Give the dormant engine the same change or retire it. | #680 |
| APInvoices | `RECORD_KEY` = invoice number; lines = invoice number `:LINE:` n (`bip/APInvoices/DMT_AP_RECON_V2_DM.xdm:65, 81, 100, 127`); `FETCH FIRST :P_CHUNK_SIZE ROWS ONLY` (`:152-155`); cap from header + line TFM count (`db/packages/dmt_ap_results_pkg.pkb.sql:93-103`) | FAIL (split) | Add a header-key column (the invoice number) to every tier. Pick the next N invoice numbers after `P_AFTER_KEY`, then return all header and line rows, base and interface, for those invoices. | #681 |
| Assets | Asset number; distribution child = asset number `#DIST` (`bip/Assets/DMT_FA_ASSET_RECON_V2_DM.xdm:93, 117, 143`); row cap (`:169-172`) | FAIL (split) | Header key = asset number. Page by the next N asset numbers, then return the asset, interface and distribution rows of each. | #682 |
| BillingEvents | Single grain; key = SOURCEREF (`bip/BillingEvents/DMT_BILLING_EVENT_RECON_V2_DM.xdm:72, 90`); row cap (`:107-110`). The base filter (this import's request id) and the interface filter (not imported) cannot both return one event. | PASS | None needed beyond the shared change in #680. | none |
| BlanketPOs | Header = document number; lines = number `:LN:` n (`bip/BlanketPOs/DMT_BLANKET_PO_RECON_V2_DM.xdm:79, 96, 116, 153`); row cap (`:187-190`) | FAIL (split) | Header key = document number. Page by the next N agreements, then return all header and line rows. | #683 |
| Contracts | Single grain (contract headers only); key = document number (`bip/Contracts/DMT_CONTRACT_RECON_V2_DM.xdm:70, 89`); row cap (`:121-124`). The interface filter excludes ACCEPTED headers, so one contract never returns two rows. | PASS | None needed beyond #680. | none |
| Customers | Key = record type `~` reference (`bip/Customers/DMT_CUST_RECON_V6_DM.xdm:58, 79-140, 194`). Rows sort by record type first, so a customer's party, sites, accounts and site uses sit in different sections of the result. Row cap with unpinned collation (`:362-366`). | FAIL (split; no document grouping at all) | Header key = the party reference, carried on every record type (account, site and use rows reach it through their parent references). Page by the next N parties, then return all seven record types for them. Pin the ordering to binary. | #684 |
| Expenditures | Single grain; key = original transaction reference (`bip/Expenditures/DMT_EXP_RECON_V2_DM.xdm:79, 95, 112`); row cap (`:128-131`). Two interface branches (import rejections, and unprocessed staging rows) can both return the same transaction. | FAIL (drop at a page edge when one key returns twice) | Page by distinct transaction reference and return every row for each one on the same page. | #685 |
| GLBalances | Key = per-line recon reference (`bip/GLBalances/DMT_GL_BAL_RECON_V4_DM.xdm:65, 96`); row cap, unpinned collation (`:113-115`). The document is the journal (Journal Import holds the whole group when one line fails, `:20-24`), but lines are not ordered by journal. | FAIL (split) | Header key = the journal (for example group id plus journal reference) on base and interface rows. Page by the next N journals, then return all their lines. | #686 |
| GLBudgets | Single grain (budget cell); key = ledger, budget, period, currency and segments (`bip/GLBudgets/GL_BUDGET_DM.xdm:116-129, 211-224`); row cap, unpinned collation (`:255-257`). The base tier is a time window, not a job id, so a cell can come back as both a base row and a rejected interface row. | FAIL (drop at a page edge when one key returns twice) | Page by distinct cell key and return every row for each one on the same page; pin the collation. (The time-window base selection is a separate open item.) | #687 |
| Grants | Single grain (award header); key = contract or award number (`bip/Grants/DMT_GRANT_RECON_V2_DM.xdm:67, 88`); row cap (`:117-119`). Base and interface are exclusive. | PASS (paging only) | None needed beyond #680. The base tier still selects by `LIKE :P_PREFIX` (`:79`), which is the separate job-id item, not this rule. | none |
| Items | Item = item `~` org; category = item `~` org `~` set `~` code (`bip/Items/DMT_ITEM_RECON_V3_DM.xdm:81, 129, 148, 207`); row cap, unpinned collation (`:224-226`). `~` sorts after digits and letters, so another item's rows can fall between an item and its categories. | FAIL (split) | Header key = item number plus org. Page by the next N item-org pairs, then return item and category rows. | #688 |
| MiscReceipts | Transaction key = source line id; serial child key = serial number (`bip/MiscReceipts/DMT_INV_TRX_RECON_V2_DM.xdm:73, 91, 115`); row cap (`:130-133`). Serials are not ordered with their receipt. | FAIL (split) | Header key = the receipt's source line id on the serial rows too. Page by the next N receipts, then return the receipt and its serials. | #689 |
| PlanningBudgets | Report is dormant and returns nothing (`bip/PlanningBudgets/PLAN_BUDGET_DM.xdm:82`). The reconciler calls BIP once with only the retired `P_BATCH_ID` and no paging loop (`db/packages/dmt_plan_budget_results_pkg.pkb.sql:98-103`), so once the report is wired only the first page would ever be read. | FAIL (latent truncation) | Move to `FETCH_ROWS` with header paging when the report is wired. | #690 |
| ProjectBudgets | Base key = plan-version reference; interface key = budget-line reference, or project `::` version name when null (`bip/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V3_DM.xdm:81, 103`); row cap (`:124-127`). The lines of one plan version are not grouped with it, and lines with no reference share one key. | FAIL (split and drop) | Header key = project plus plan version on every row. Page by the next N plan versions, then return the version and all its interface lines. | #691 |
| Projects | Project = number; tasks = number `/` task; transaction controls = number `/TC/` ref; team members = project NAME `/TM/` member (`bip/Projects/DMT_PROJECT_RECON_V2_DM.xdm:82, 100, 121, 141, 177, 200, 231, 255`); row cap (`:274-277`). Team members sort away from their project. | FAIL (split) | Header key = project number on every tier, including team members. Page by the next N projects, then return all four tiers. | #692 |
| PurchaseOrders | Number; number `:LN:` n; `:LOC:` m; `:DIST:` d (`bip/PurchaseOrders/DMT_PO_RECON_V2_DM.xdm:85, 102, 121, 142, 164, 201, 241, 281`); row cap (`:314-317`) | FAIL (split) | Header key = PO number. Page by the next N POs, then return all four tiers, base and interface. | #693 |
| Requisitions | Header = requisition number; line = line TFM id (digits); distribution = line key `:DIST:` n (`bip/Requisitions/DMT_REQ_RECON_V3_DM.xdm:88, 104, 123, 143, 178, 211`). Uses `WITH TIES`, so no row is dropped (`:245-251`), but lines are not ordered with their requisition. | FAIL (split) | Header key = requisition number on line and distribution rows. Page by the next N requisitions, then return all three tiers. | #694 |
| Suppliers | No paging. One BIP call returns the whole load (`db/packages/dmt_poz_sup_results_pkg.pkb.sql:48-55`; `bip/Suppliers/SUP_DM.xdm:19-41`, no keyset). It never splits a supplier, but there is no paging at all, and a large load relies on one unbounded response. | FAIL (no paging) | Move to the Contract v1 shape with header paging by supplier. | #695 |
| SupplierSites | Same as Suppliers (`db/packages/dmt_poz_sup_site_results_pkg.pkb.sql:48`; `bip/SupplierSites/SUP_SITE_DM.xdm:19-41`) | FAIL (no paging) | As Suppliers, paged by site. | #696 |
| SupplierAddresses | Same (`db/packages/dmt_poz_sup_addr_results_pkg.pkb.sql:48`; `bip/SupplierAddresses/SUP_ADDR_DM.xdm:17-38`) | FAIL (no paging) | As Suppliers, paged by address. | #697 |
| SupplierContacts | Same (`db/packages/dmt_poz_sup_cont_results_pkg.pkb.sql:48`; `bip/SupplierContacts/SUP_CONT_DM.xdm:18-40`) | FAIL (no paging) | As Suppliers, paged by contact. | #698 |
| SupplierSiteAssignments | Same (`db/packages/dmt_poz_sup_site_assn_results_pkg.pkb.sql:48`; `bip/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm:18-56`) | FAIL (no paging) | As Suppliers, paged by assignment. | #699 |

## Not reviewed

- **ARInvoices**: another agent is fixing it. The 5x row-cap multiplier is at
  `db/packages/dmt_ar_results_pkg.pkb.sql:88-95, 189`.
- **Configuration objects (deferred)**: APPaymentTerms, CashBanks (Banks, Branches, Accounts),
  Lookups, ValueSets, UnitsOfMeasure, Taxes. CashBanks, Lookups, ValueSets, UnitsOfMeasure,
  Taxes and APPaymentTerms each call `RUN_BIP_REPORT` once, with no paging.
- **HCM objects (deferred)**: Workers, Assignments, Absences, Salaries, SalaryBases,
  BenBeneficiary, BenDependent, BenParticipant, PayrollRelationships, PerfEvaluations,
  TalentProfiles, TaxCards, W2Balances, WorkSchedules. All use `FETCH_ROWS`, so the shared change
  (#680) will reach them.
- **Post-run comparison reports** (`DMT_RUN_SUMMARY_PKG`, `db/packages/dmt_run_summary_pkg.pkb.sql:210, 393-397`)
  reuse `FETCH_ROWS` with a row cap. They are not reconciliation and are out of scope, but they
  inherit the #680 change.

## Smaller observation

Customers, GLBalances, GLBudgets, Grants, Items and PlanningBudgets order and compare
`RECORD_KEY` in the BIP session's collation, while `FETCH_ROWS` picks the next cursor with its
own ordering (`dmt_recon_contract_pkg.pkb.sql:191`). If the two collations differ, the next page
can repeat rows. Rows are not lost this way. Pinning these reports to binary ordering, as the
other reports already do, removes the risk. It is folded into each object's item.
