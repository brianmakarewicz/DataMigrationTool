# Cross-grain error propagation: conformance review (2026-10-07, READ-ONLY)

This review checks every registered object against the requirement in `docs/DMT_DESIGN.html`
section 5 (Error handling), in the bullet "Whole-document rejection carries the real error to
every grain" (DECIDED 2026-10-07, owner).

The rule: when Fusion rejects a whole document because one of its grains failed, every row of
that document must land FAILED. Each of those rows has to quote the *real* Fusion message and
name the grain and key the message came from. A generic "parent failed" or "rejected by
import" string does not count, and neither does UNACCOUNTED. Every object that can reject a
whole document also needs a regression **cross-grain failure scenario**. That is a BAD document
whose only defect sits on one grain, used to prove that every other grain lands FAILED with the
quoted error.

Everything here was read-only. The review read the registry
(`db/seed/dmt_pipeline_def_tbl.sql`, `db/seed/dmt_bip_report_tbl.sql`, last assignment wins),
the registered `bip/<Object>/*.xdm` DMs, the `db/packages/*_results_pkg` and HDL packages,
the object READMEs, the findings docs, and `scripts/insert_regression_test_data.py`. It also ran
a few read-only Fusion queries through `scripts/fusion_bip_query.py` against the PO, AP,
BlanketPO, AR, Item, GL_INTERFACE and GL_BUDGET_INTERFACE interface tables. No code, BIP
report, seed or scenario was changed. For ARInvoices, the held-sibling-line behaviour comes
from the known-good investigation (PR #599, `docs/findings/known_good_ARInvoices.md`).

## Conformance table

The table uses these short forms:

- **WDR** means "whole-document rejection: does Fusion reject the other grains when one fails?"
- **DNC** means DOES NOT CONFORM.
- **N/A** means the rule doesn't apply. Either the object has a single grain, or Fusion
  rejects rows independently of each other.

File and line citations for every DNC verdict are in the matching backlog item in
`docs/backlog.html`.

| Object | Grains (TFM tiers) | WDR? (how known) | Recon conforms? | Regression scenario? | Backlog items |
|---|---|---|---|---|---|
| Requisitions | header / line / dist | YES. Seen live: in run 238, all siblings show `PROCESS_FLAG=FAILED` with no error of their own. | **DNC**, in every direction. Each tier joins only the row's own key, so the cascaded rows come back NULL and are UNACCOUNTED (6 rows in runs 236 and 238). | HAS (BADHDR, BADLINE and BADDIST, `:2093-2173`). It should still gain a sibling line. | #163 (P1) |
| PurchaseOrders | header / line / line location / dist | YES. Seen live: headers REJECTED with no error of their own while a line carries the error, and the reverse. | **DNC**, in every direction (3 rows UNACCOUNTED in runs 236 and 238). | NEEDS. BAD1 only covers header→children and also carries a second defect. | #164 (P1), #189 |
| BlanketPOs | header / line | PARTIAL. Header→lines YES; line→header NO (live, 7 headers were ACCEPTED while one of their lines was rejected). | **DNC** for header→lines (latent). | NEEDS. BAD1 has no line. | #165, #190 |
| Contracts | header only | N/A (single grain). | N/A | N/A | none |
| APInvoices | header / line | YES. Seen live: 38 headers REJECTED where only a line had a rejection. | Header→lines conforms. **DNC** for line→header and line→sibling lines, and the fallback is a composed string. | NEEDS. BAD1 has defects on both grains. | #166, #191 |
| MiscReceipts | transaction / lot / serial | PARTIAL. A transaction and its children stand or fall together, according to the DM comment and Fusion's inline errors. | Lot/serial→transaction conforms. Transaction→lot conforms but doesn't name the transaction key. **DNC** for transaction→serial, which is left to the sweep (UNACCOUNTED). | NEEDS. The BAD row has no children. | #167, #192 |
| Customers (7 HZ tiers) | party, location, party site, party site use, account, account site, account site use | PARTIAL, downward only. A child is held at W when its parent fails; parents commit on their own (run 236). | V3 conforms for held children: it names the parent and quotes the real text. **DNC** when the child also has its own error, because the ancestor's cause is dropped (`V3 DM:392`). Child→parent does not apply. | NEEDS. Today's cascades are accidental, and the BAD rows point at a nonexistent parent. | #168, #193 |
| ARInvoices | line / dist (the header is derived by AutoInvoice grouping) | YES, by AutoInvoice design. The source's "Reject Invoice" setting fails every line, and PR #599 found a rejected line holds back the valid lines grouped onto the same invoice, with no error written for them. | **DNC**, in every direction: held lines and distributions get NULL and are UNACCOUNTED. The multi-line RECON_KEY also collides. | NEEDS. There is no multi-line invoice and no distribution rows. | #169, #194 |
| ARReceipts | not built | N/A (no EXEC_PROC or RECON_PROC). | N/A | N/A | none. Revisit when it is built. |
| Items (+ Item Categories) | item / item category | NO for CREATE. Live, 340 items were created while their category failed. | N/A in substance. The category already pulls the item's real error on the same transaction (`V2 DM:234-237`). An optional P3 label tweak was not filed. | N/A. Categories are xref'd to a prior run's item, so an item and its category can't form one document. | none |
| Suppliers | one grain | N/A. Each supplier object is its own FBDI file and import, and gets its own rejections. | N/A | N/A | none |
| SupplierAddresses | one grain | N/A | N/A | N/A | none |
| SupplierSites | one grain | N/A | N/A | N/A | none |
| SupplierSiteAssignments | one grain | N/A | N/A | N/A | none |
| SupplierContacts | one grain | N/A | N/A | N/A | none |
| Projects | project / task / team member / txn control | PARTIAL. A rejected project leaves its children in the interface. Child→project is unproven. | **DNC**. There is no cascade at all, so children of a rejected project are UNACCOUNTED. | NEEDS. The BAD project has no children. | #170, #195 |
| BillingEvents | one grain | N/A. GOOD events load next to the BAD one. | N/A | N/A | none |
| Expenditures | one grain | NO. In the shared batch, GOOD rows load and BAD rows are rejected one by one. | N/A | N/A | none |
| Grants | award header + 14 child tiers | YES, per award. The report lists failures per award. | Header→children quotes the real text but doesn't name the award. **DNC** for child→header: the child's error is presented as the parent's. | NEEDS. The BAD award is header-only. | #171, #196 |
| ProjectBudgets | budget line (the document is the plan version) | PARTIAL/likely. The code itself assumes it. | **DNC**. Sibling lines of a rejected version are UNACCOUNTED. | NEEDS. Each project has a single line. | #172, #197 |
| GLBalances | journal line (the document is the journal/group) | YES. Seen live: `EF04` lines sit beside `P` siblings, and `EG01` appears group-wide. | **DNC**. Siblings get no real error. The line's own "error" is `REFERENCE10`, which is our description text, and `STATUS` is never read. | NEEDS. The BAD row is a one-line unbalanced journal. | #173, #198 |
| GLBudgets | budget cell (the document is RUN_NAME) | PARTIAL/likely. Seen live: 1 FAILED cell beside 592 cells left VALIDATED. | **DNC**. The VALIDATED siblings are never returned, so they are UNACCOUNTED. | NEEDS. The BAD row is isolated in its own run. | #174, #199 |
| Assets | header / book / assignment, plus the book batch | YES, at two scopes: within an asset, and across a book batch at SQL*Loader. | Within an asset it conforms (key not named). **DNC** for the book batch, which gets a generic `[BATCH_REJECTED]` string. | Within an asset: HAS (BAD1, defect on the assignment only). Book batch: NEEDS. | #175, #200 |
| PlanningBudgets | one grain (dormant, out of scope) | N/A | N/A | N/A | none |
| GLCalendar | one grain (periods; not built) | N/A (EXEC_PROC is NULL). | N/A | N/A. Design one in when a load path is built. | none |
| ValueSets | set / value (one FBDI file) | UNKNOWN. Set→values is YES in effect; value→set has never been observed (the ESS job fails on erpFamily). | **DNC**. No per-row Fusion error is captured and there is no cascade. | HAS for parent→child (`VS_BAD1` with a valid child value). | #176 |
| Lookups | type / value (REST) | Type→values YES in effect. Value→type N/A (separate POSTs). | Conforms (#592 quotes the parent's real text), with two edge gaps. **DNC** edge: when the parent's error body is blank, the child gets a generic string, and the cascade is keyed on call status rather than base existence. | HAS (`DMT2_BAD_LKP` with a valid value). | #177 |
| UnitsOfMeasure | one grain | N/A | N/A | N/A | none |
| PaymentTerms | header / line (REST) | Header→lines YES in effect. Line→header N/A. | **DNC**. Lines under a failed header are silently UNACCOUNTED. | NEEDS. The BAD header has no lines. | #179, #202 |
| TaxConfig | regime / rate (REST) | Regime→rates YES in effect. Rate→regime N/A. | **DNC**. Rates under a failed regime are silently UNACCOUNTED. | NEEDS. The BAD regime has no rate. | #180, #203 |
| CashBanks | bank / branch / account (REST) | Parent→children YES in effect. Child→parent N/A (each tier is reconciled before the next). | Conforms (#592 names the parent and quotes its text), with one edge gap. **DNC** edge: when the parent's error body is blank, the child gets a generic string. | NEEDS. The BAD bank has no branch or account. | #178, #201 |
| Workers (HDL) | worker, 6 person components, work relationship, assignment (9 TFM tables, one Worker.dat) | YES. HDL rejects the whole logical object (run 234 items 1-2). | **DNC**. An assignment-line error leaves the Worker and WorkRel rows UNACCOUNTED and the components possibly falsely LOADED. A person-component error leaves the assignment row UNACCOUNTED. No message names its source SSID. | NEEDS | #181, #204 |
| Salaries | one grain | N/A | N/A | N/A | none |
| SalaryBases | one grain | N/A | N/A | N/A | none |
| TaxCards | card / component | YES (HDL parent and child; inferred, since the object is blocked). | **DNC (partial)**. The error propagates through the person-number prefix, but the message names no component. There is no base-proof deferral and there is cross-person prefix bleed. | NEEDS | #182, #205 |
| W2Balances | batch header / line | PARTIAL. Header→lines YES; line→header unproven. | **DNC**. There is no SourceSystemId, so a message can't be matched; it either fans out to every row or leaves the rows UNACCOUNTED. | NEEDS | #183, #206 |
| BenParticipant | one grain | N/A | N/A | N/A | none |
| BenDependent | enrollment + designations (several rows per object) | YES (inferred). | **DNC (partial)**. Rows of the same person get the real text, but the failing designation is never named. | NEEDS | #184, #207 |
| BenBeneficiary | enrollment + designations | YES (inferred). | **DNC (partial)**. Same as BenDependent. | NEEDS | #185, #208 |
| Absences | one grain | N/A | N/A | N/A | none |
| TalentProfiles | profile / item | YES (run 234 items 5-7). | **DNC (partial)**. The error propagates through the prefix, but the source is not named, and the item table can be promoted LOADED on dataset status. | NEEDS. G1 is all good and BPROF has no item. | #186, #209 |
| PerfEvaluations | document / rating | YES (inferred). | **DNC**. There is no SourceSystemId, so a message is either broadcast to every document or leaves the rows UNACCOUNTED. | NEEDS | #187, #210 |
| WorkSchedules | pattern / shift (plus the schedule assignment) | YES for a pattern and its shifts (inferred). | **DNC (partial)**. The source is not named, shifts are not deferred, and a `_WSASG` error never matches the row. | NEEDS | #188, #211 |

## Summary

- **Conforms and already has the scenario:** none.
- **Not applicable:** Contracts, Items, Suppliers, SupplierAddresses, SupplierSites,
  SupplierSiteAssignments, SupplierContacts, BillingEvents, Expenditures, Salaries,
  SalaryBases, BenParticipant, Absences, UnitsOfMeasure. GLCalendar, ARReceipts and
  PlanningBudgets are also out of scope here because they are not built or dormant.
- **Does not conform:** 26 objects, filed as one item each, #163-#188.
  - **P1:** Requisitions and PurchaseOrders, because they produce UNACCOUNTED rows in the latest
    runs (236 and 238).
  - **BlanketPOs is P2, not P1.** Its gap is real but latent: RT-BPA-BAD1 has no line, so runs
    236 and 238 have nothing UNACCOUNTED for it.
  - **The rest are P2.** Most are latent because the seed never exercises them.
- **Needs a regression scenario:** 23 objects, filed as #189-#211.
- **Already have one:**
  - Requisitions.
  - Assets, within one asset.
  - ValueSets and Lookups, parent→child.
- **Shared root causes** worth fixing once:
  - **HDL objects:** `dmt_hdl_util_pkg.RECONCILE_HDL` builds the message as
    `'[FUSION_ERROR] '||LISTAGG(jt.msg)` with no SourceSystemId, file or line. It also matches by
    a `LIKE` prefix, and its Step 2 promotes child tables to LOADED on dataset status. Fixing
    those three things covers most of #181-#188.
  - **FBDI document objects (Reqs, PO, BPA, AP, AR):** the fix has the same shape everywhere. A
    new DM version, deployed alongside the current one, gives a rejected row that has no error of
    its own the list of real errors from its document, each tagged with its grain and key.
