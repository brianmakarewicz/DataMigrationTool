# Interface key review: TFM sequence id as the only DMT linking key

> **Scope narrowed by the owner, 2026-10-07 (read this first).** After this review was written, the owner narrowed the rule. It now covers **only the keys DMT makes up to join a parent to its children inside one FBDI or HDL file** (header to line, line to line location or schedule, line to distribution, lot to transaction line, an HDL child to its parent's SourceSystemId, and the like). Those keys must be the TFM row's own sequence id. The decision is recorded in `docs/DMT_DESIGN.html` section 6 ("Parent-child join keys are the TFM sequence id"), and the companion reconciliation rule (reports find rows by Fusion job id, never by prefix or run-id text, and keys only match a returned row to its TFM row) is in section 5.
>
> As a result, parts of the review below are **no longer violations**:
>
> - **The Slot C reference token** `DMT:<run>:<wq>:<tfm>` stays as designed on 2026-09-24. Cross-cutting finding 5 is closed with no change.
> - **Reference fields that are not join keys** are out of scope: Expenditures ORIG_TRANSACTION_REFERENCE, BillingEvents SOURCEREF and ProjectBudgets SRC_BUDGET_LINE_REFERENCE (the whole PPM table), and by the same test the ARInvoices INTERNAL_NOTES grouping stamp and the MiscReceipts TRANSACTION_REFERENCE and SOURCE_HEADER_ID. Their reports still have to stop selecting rows by prefix or run-id text, but that is reconciliation work tracked in backlog #219 and #229 to #264.
> - **Customers is an approved exception.** The TCA original system references join a customer's parts together, but Fusion keeps them permanently in HZ_ORIG_SYS_REFERENCES as the link back to the legacy system and later loads use them, so Customers keeps the prefixed legacy reference as its join key.
> - **Business keys prefixed on purpose** were already out of scope and still are.
>
> What remains in backlog #218 is **48 join-key fields in 19 objects, in 6 entries**: Requisitions (5), the PurchaseOrders / BlanketPOs / Contracts family (7), PaymentTerms (1), ARInvoices (4), MiscReceipts SOURCE_LINE_ID (1) and the 12 HCM HDL objects (30). The **HDL SourceSystemOwner precondition** below remains an open item. For HCM, check each SourceSystemId against the narrowed scope when the fix is built, because a record id that no child in the file references is not a join key. The "Owner decisions needed" list in the summary is resolved by this note, except for the HDL precondition.

Review date 2026-10-07. Read-only code review: no code changed and no database touched. Backlog item #218 tracks the fix.

## The rule under review

The owner set this rule on 2026-10-07. Every interface key that DMT writes into an FBDI or HDL file for its own linking and reconciliation must be the TFM row's own sequence id: `TFM_SEQUENCE_ID`, or that table's equivalent primary key. That covers the header, line, line location, distribution, schedule and transaction-flexfield line keys. DMT must not fabricate ids when it already has ids that work.

Reconciliation reports are moving to find rows by the Fusion job id (`REQUEST_ID` / `LOAD_REQUEST_ID`) rather than by key text. A key therefore only has to be unique within one load, and the TFM id is enough.

Business keys that Fusion shows to users and that DMT prefixes on purpose are out of scope. That means PO number, requisition number, supplier name, person number and similar. They are listed separately at the end as "business key, prefixed by design".

## How the review was done

The review covered every object's transform (`db/packages/*transform*`), its FBDI, FBL or HDL generator, its `_RESULTS_PKG` reconciler and its BIP recon data model (`bip/<CEMLI>/query.sql` and `.xdm`). It also read the shared reconciliation code: `DMT_RECON_ENGINE_PKG`, `DMT_HDL_UTIL_PKG` and `DMT_REF_ID_PKG`.

Line numbers are taken from `origin/main` at commit `010d78d`. Paths are under `db/packages/` unless they start with `bip/`. The short name `po_transform` means `dmt_po_transform_pkg.pkb.sql`, and the other short names follow the same pattern.

## Summary

- **Per-object violations:** 61 key fields in 23 objects.
  - P2P: 13 fields in 5 objects (Requisitions, PurchaseOrders, BlanketPOs, Contracts, PaymentTerms).
  - O2C/Financials: 15 fields in 3 objects (ARInvoices, MiscReceipts, Customers).
  - PPM: 3 fields in 3 objects (Expenditures, BillingEvents, ProjectBudgets).
  - HCM: 30 fields in 12 HDL objects.
- **Cross-cutting violation:** the Slot C DFF reference token `DMT:<run>:<wq>:<tfm>`, built by `DMT_REF_ID_PKG.BUILD_REF`, is stamped by 16 generators. Ten objects violate the rule only through this token: Suppliers, SupplierAddresses, SupplierSites, SupplierContacts, APInvoices, Assets, Items, GLBalances, Projects and Grants.
- **Already conforming:**
  - GLBalances RECON_KEY → REFERENCE21.
  - APInvoices header and line `INVOICE_ID`.
  - Assets `MASS_ADDITION_ID` (book and distribution).
  - MiscReceipts `INV_LOTSERIAL_INTERFACE_NUM` and its lot/serial links.
- **Where the bare TFM id cannot be used, or not without a design change:**
  - GLBudget.
  - Run-level batch and group stamps.
  - The W2Balances BatchName.
  - HDL WorkTerms versus Assignment, which share one TFM row.
  - The aggregated Benefits parent enrollments.
  - Cross-object HDL foreign keys.
  - Each case is explained under "Where the TFM id cannot be used".
- **Owner decisions needed:**
  - Customers TCA ORIG_SYSTEM_REFERENCE values: Fusion keeps them as source cross-references.
  - Expenditures, BillingEvents and ProjectBudgets source references, which users can see in Fusion.
  - The HDL SourceSystemOwner precondition.
  - The locked Slot A/C reference-carrier design dated 2026-09-24.

## Cross-cutting findings

These apply to every object and should be settled first.

1. **The TFM id is not available inside `INSERT..SELECT`.** `TFM_SEQUENCE_ID` is a column `DEFAULT <tbl>_SEQ.NEXTVAL` (an identity column on some tables). Each replacement needs one of two changes:
   - an explicit `seq.NEXTVAL` in the SELECT, reused for the key (NEXTVAL returns the same value within a row); APInvoices (`ap_transform:169`), Expenditures (`:155`) and BillingEvents (`:87`) already do this; or
   - a post-insert `UPDATE`/`MERGE` that runs before the child INSERT; GLBalances (`gl_transform:119-123`), MiscReceipts (`:267-271`) and BenDependent (`:118`) already do this.
2. **A child's parent key must be the parent's TFM id.** Most child INSERTs already join the parent TFM row (Requisitions, PO), so the change there is to select `TFM_SEQUENCE_ID` instead of the parent's fabricated key. Where the parent is a different object (HDL cross-object references), a lookup is required. See "Where the TFM id cannot be used".
3. **TFM ids are unique only per table and per DMT database.** A `--fresh` local rebuild restarts the sequences. TEST (Docker) and GOLD (ATP) also load the same Fusion pod with overlapping ranges. For FBDI this is harmless only if every recon tier is scoped by `LOAD_REQUEST_ID` or `REQUEST_ID` and never by key text, which is the planned direction. For HDL it is not harmless; see the HDL precondition below.
4. **Keyset pagination compares keys as text.** `dmt_recon_engine_pkg.pkb.sql:174` takes `MAX(record_key)` as VARCHAR2. Each data model must `ORDER BY` RECORD_KEY as text too, never `TO_NUMBER`, or `'9' > '10'` will skip rows. The Requisitions report would mix numeric line keys with prefixed requisition numbers in one keyset. If an all-digit requisition number equals a line TFM id, the strict `>` cursor drops a row. Add OBJECT_TYPE as a tiebreak in the key or in the ordering.
5. **The Slot C reference token is not the bare TFM id.** `DMT_REF_ID_PKG.BUILD_REF` (`dmt_ref_id_pkg.pkb.sql:12-28`) returns `DMT:<run>:<wq>:<tfm>` (FULL), or `DMT:<tfm>` (COMPACT, unused). It is stamped into a DFF attribute by 16 generators:

   | Generator | Line | Attribute |
   |---|---|---|
   | `dmt_ap_fbdi_gen` | 473-479 | ATTRIBUTE15 |
   | `dmt_ar_fbdi_gen` | 696-702 | ATTRIBUTE1 |
   | `dmt_billing_event_fbdi_gen` | 205-213 | ATTRIBUTE10 |
   | `dmt_egp_item_fbdi_gen` | 951-957 | ATTRIBUTE1 |
   | `dmt_expenditure_fbdi_gen` | 271-279 | ATTRIBUTE10 |
   | `dmt_fa_asset_fbdi_gen` | 644-650 | ATTRIBUTE1 |
   | `dmt_gl_fbdi_gen` | 275-278 | REFERENCE22 |
   | `dmt_grants_fbdi_gen` | 687-695 | ATTRIBUTE20 |
   | `dmt_misc_receipt_fbdi_gen` | 408-414 | ATTRIBUTE20 |
   | `dmt_po_fbdi_gen` | 667-673 | ATTRIBUTE20 |
   | `dmt_poz_sup_fbdi_gen` | 86-92 | ATTRIBUTE20 |
   | `dmt_poz_sup_addr_fbdi_gen` | 77-83 | ATTRIBUTE30 |
   | `dmt_poz_sup_site_fbdi_gen` | 83-89 | ATTRIBUTE20 |
   | `dmt_poz_sup_cont_fbdi_gen` | 77-83 | ATTRIBUTE20 |
   | `dmt_project_fbdi_gen` | 513-520 | ATTRIBUTE50 |
   | `dmt_req_fbdi_gen` | 499-505 | ATTRIBUTE20 |

   - **Limits:** DFF attributes are 150 or more characters and REFERENCE22 is 240, so a bare TFM id fits everywhere. A DFF segment backed by a numeric value set would reject the current `DMT:` text.
   - **Readers:** the tier-2 parsers use `REGEXP_SUBSTR(DFF_KEY,'[0-9]+$')` (for example `po_results:164`, `req_results:172`, `expenditure_results:652-654`, `cust_results:243`). They already accept a bare id.
   - **What must change:** the diagnostic check at `dmt_recon_engine_pkg.pkb.sql:216` (`dmt_reference LIKE 'DMT:'||run||':%'`) and the `CONFIRM_REFERENCE_ROUNDTRIP` checks.
   - **Fix:** make the change once, in `BUILD_REF`/`GET_REF_FORMAT`, and in the comments of the `dmt_ref_carrier_cfg_tbl.sql` seed.
   - **Owner decision:** this token is the reference-carrier design locked on 2026-09-24 (DMT_DESIGN section 5). Replacing it with the bare TFM id supersedes that decision, so the owner should confirm it.

## Per-object findings: violations

The "Fits?" column covers the Fusion column limits and whether the bare TFM id fits. "Reconciler impact" names code that parses or depends on the current key format and what must change.

### P2P

| Object | file:line (transform; generator) | Field | Current expression | Conforms | Fusion limit; TFM id fits? | Reconciler impact |
|---|---|---|---|---|---|---|
| Requisitions | req_transform:101; req_gen:79 | INTERFACE_HEADER_KEY | `TO_CHAR(p_run_id)\|\|'_RQHDR_'\|\|STG_SEQUENCE_ID` | No | POR_REQ_HEADERS_INTERFACE_ALL VARCHAR2(50), free text. Fits. | `bip/Requisitions/DMT_REQ_RECON_DM.xdm:193` scopes by `LIKE :P_RUN_ID\|\|'\_RQHDR\_%'`; change to `load_request_id = :P_LOAD_REQUEST_ID`. `query.sql:125` mirrors it. |
| Requisitions | req_transform:359; req_gen:175 | INTERFACE_LINE_KEY | `run_id\|\|'_RQLN_'\|\|STG_SEQUENCE_ID` | No | VARCHAR2(50). Fits. **Persists to base** POR_REQUISITION_LINES_ALL.INTERFACE_LINE_KEY. | `REQ_RECON_DM.xdm:127` (BASE lines) and `:153` (BASE dists) scope **only** by `LIKE :P_RUN_ID\|\|'\_RQLN\_%'`. They need a new base scope: `rl.request_id = :P_IMPORT_ESS_ID` (check that the column exists) or a header join on the prefixed REQUISITION_NUMBER. Change `:223` (interface) to load_request_id. RECON_KEY = INTERFACE_LINE_KEY (req_transform:469) carries over. |
| Requisitions | req_transform:360-366; req_gen:176 | INTERFACE_HEADER_KEY on the line (parent key) | subquery returning `ht.INTERFACE_HEADER_KEY` | No | 50. Fits. | Use `TO_CHAR(ht.TFM_SEQUENCE_ID)`; the join already exists. `req_results:528-624` groups by this key and is unaffected. |
| Requisitions | req_transform:629; req_gen:321 | INTERFACE_DISTRIBUTION_KEY | `run_id\|\|'_RQDIST_'\|\|STG_SEQUENCE_ID` | No | 50. Fits. | `REQ_RECON_DM.xdm:257` LIKE scope; change to load_request_id. The dist RECON_KEY `INTERFACE_LINE_KEY\|\|':DIST:'\|\|DISTRIBUTION_NUMBER` (req_transform:708) stays valid. |
| Requisitions | req_transform:630-636; req_gen:322 | INTERFACE_LINE_KEY on the dist (parent key) | subquery returning `lt.INTERFACE_LINE_KEY` | No | 50. Fits. | Use `TO_CHAR(lt.TFM_SEQUENCE_ID)`. |
| PurchaseOrders, BlanketPOs, Contracts (shared `DMT_PO_TRANSFORM_PKG`) | po_transform:146; po_gen:79, blanket_po_gen:122, contract_gen:78 | INTERFACE_HEADER_KEY | `run_id\|\|'_HDR_'\|\|STG_SEQUENCE_ID` | No | PO_HEADERS_INTERFACE VARCHAR2(50). Fits. Interface only. | `DMT_PO_RECON_DM.xdm:224`, `DMT_BLANKET_PO_RECON_DM.xdm:132` and `DMT_CONTRACT_RECON_DM.xdm:109` have `LIKE :P_RUN_ID\|\|'\_HDR\_%'`. The PO data model already filters load_request_id (`:223`), so drop the LIKE (confirm the Blanket and Contract data models do the same). Update the spec comments at `dmt_po_transform_pkg.pks.sql:27,37,48,59`. |
| PO family | po_transform:428; po_gen:206, blanket_po_gen:363 | INTERFACE_LINE_KEY | `run_id\|\|'_LN_'\|\|STG_SEQUENCE_ID` | No | PO_LINES_INTERFACE VARCHAR2(50). Fits. | `PO_RECON_DM.xdm:264` and `BLANKET_PO_RECON_DM.xdm:167` LIKE scopes; drop them. |
| PO family | po_transform:429-435; po_gen:207 | INTERFACE_HEADER_KEY on the line (parent key) | subquery returning `ht.INTERFACE_HEADER_KEY` | No | 50. Fits. | Use `TO_CHAR(ht.TFM_SEQUENCE_ID)`. TFM-side uses stay valid because keys remain unique: po_transform:510,530-533,587; `po_results:539-695,815-843`; `blanket_po_results:342-369,479`; `po_compare:25,36,136,147`. |
| PurchaseOrders | po_transform:714; po_gen:336 | INTERFACE_LINE_LOCATION_KEY | `run_id\|\|'_LOC_'\|\|STG_SEQUENCE_ID` | No | PO_LINE_LOCATIONS_INTERFACE VARCHAR2(50). Fits. | `PO_RECON_DM.xdm:304` LIKE scope; switch to load_request_id. |
| PurchaseOrders | po_transform:715-721; po_gen:337 | INTERFACE_LINE_KEY on the location (parent key) | subquery returning `lt.INTERFACE_LINE_KEY` | No | 50. Fits. | Use `TO_CHAR(lt.TFM_SEQUENCE_ID)`. The location RECON_KEY join (po_transform:815-825) still works. |
| PurchaseOrders | po_transform:997; po_gen:466 | INTERFACE_DISTRIBUTION_KEY | `run_id\|\|'_DIST_'\|\|STG_SEQUENCE_ID` | No | PO_DISTRIBUTIONS_INTERFACE VARCHAR2(50). Fits. | `PO_RECON_DM.xdm:345` LIKE scope; switch to load_request_id. |
| PurchaseOrders | po_transform:998-1004; po_gen:467 | INTERFACE_LINE_LOCATION_KEY on the dist (parent key) | subquery returning `llt.INTERFACE_LINE_LOCATION_KEY` | No | 50. Fits. | Use `TO_CHAR(llt.TFM_SEQUENCE_ID)`. The dist RECON_KEY (po_transform:1098-1112) still works. |
| PaymentTerms / PaymentTermLines | ap_pay_term_transform:121 (header), :271 (lines); ap_pay_term_fbl_gen:62, :107 | SourceGroupId (header-to-line link) | `s.SOURCE_GROUP_ID`, passed through from source | No (source key, not TFM id) | Free text. Fits. | `ap_pay_term_results:434-512` maps SOURCE_GROUP_ID → TERM_ID and must re-key on the header TFM id. The line takes the parent header TFM id through a join on STG SOURCE_GROUP_ID. Low priority: the object is REST-loaded, so first check whether the FBL file is delivered at all. |

### O2C and Financials

| Object | file:line (transform; generator) | Field | Current expression | Conforms | Fusion limit; TFM id fits? | Reconciler impact |
|---|---|---|---|---|---|---|
| ARInvoices | ar_transform:308; ar_gen:117 | INTERFACE_LINE_ATTRIBUTE1 (EXTERNAL_SOURCE context, segment Header_ID) | `PREFIXED(l_prefix, NVL(s.INTERFACE_LINE_ATTRIBUTE1, s.TRX_NUMBER), 30)` | No | VARCHAR2(150), but the segment uses **value set 50731 and the known-good values are numeric** (`docs/findings/known_good_ARInvoices.md:135-136,308`). PREFIXED adds no separator, so today's value is numeric only by luck. A TFM id is always numeric, so it fits. **Constraint:** this is an invoice-level value shared by every line, and there is no AR header TFM table. Proposal: `MIN(TFM_SEQUENCE_ID) OVER (PARTITION BY run, source invoice key)` (the invoice's first line TFM id), set in a post-insert MERGE. | `bip/ARInvoices/query.sql:115,127,167-171,182,193,202` build RECORD_KEY from ATTR1 and filter `LIKE :P_PREFIX\|\|'%'`; change the filter to REQUEST_ID / LOAD_REQUEST_ID. `ar_results:186-189` matches `ATTR1\|\|'/'\|\|ATTR2`, which works with any format. The generator joins lines to dists on ATTR1+2 (`ar_gen:631-632,754-755`). |
| ARInvoices | ar_transform:310; ar_gen:118 | INTERFACE_LINE_ATTRIBUTE2 (segment Line_ID) | `NVL(s.INTERFACE_LINE_ATTRIBUTE2, TO_CHAR(s.STG_SEQUENCE_ID))` | No | Numeric value set, VARCHAR2(150). The TFM id fits and keeps CONTEXT+ATTR1..15 globally unique (the AutoInvoice duplicate-flexfield rule). Set it post-insert. | Line RECON_KEY is derived from it (ar_transform:486-490). The consumers are the same as for ATTR1. |
| ARInvoices (distributions) | ar_transform:644; ar_gen:489 | Dist INTERFACE_LINE_ATTRIBUTE1 (parent key) | `PREFIXED(l_prefix, s.INTERFACE_LINE_ATTRIBUTE1, 30)` | No | Must equal the parent line's new ATTR1: join dist STG ATTR1/2 to line STG to find the same-run line TFM row. | The dist RECON_KEY MERGE (ar_transform:757-772, `ATTR1:ACCOUNT_CLASS:ordinal`) and the dist blocks of the data model (`query.sql:167-182`) must stay byte-identical with the line's value. |
| ARInvoices (distributions) | ar_transform:645; ar_gen:490 | Dist INTERFACE_LINE_ATTRIBUTE2 (parent key) | `s.INTERFACE_LINE_ATTRIBUTE2` (raw STG value) | No | Must equal the parent line's TFM id. **Latent bug today:** when the line's ATTR2 falls back to the STG id, the dist's ATTR2 keeps the raw source value, so the link breaks. | Same as the row above. |
| ARInvoices | ar_transform:430-438 | INTERNAL_NOTES (AutoInvoice grouping stamp) | `'DMT '\|\|PREFIXED(prefix, NVL(attr1, trx_number), 30)` | No | VARCHAR2(240). Change to `'DMT '\|\|<invoice-group TFM id>`, the same value as the new ATTR1. | No parser. It only drives grouping. |
| MiscReceipts | misc_receipt_transform:172; misc_receipt_gen:153 | SOURCE_LINE_ID | `NVL(s.SOURCE_LINE_ID, s.STG_SEQUENCE_ID)` | No | NUMBER. Fits. Set it post-insert the way INV_LOTSERIAL_INTERFACE_NUM already is (`:268`). Lots emit their own STG passthrough (gen `:452,475`) and should take the parent TFM id. Serials already re-emit the parent value (`:512,528`). | RECON_KEY = TO_CHAR(SOURCE_LINE_ID) (`:238`). `bip/MiscReceipts/query.sql:48,55,66` RECORD_KEY = source_line_id, which works with any format. |
| MiscReceipts | misc_receipt_transform:149-151; misc_receipt_gen:189 | TRANSACTION_REFERENCE (run-scope stamp) | `'DMT-'\|\|run_id[\|\|'-'\|\|source ref]` | No (run-id text) | VARCHAR2(240). This is a run selector, not a row key: drop the DMT text and pass the source value through. | `bip/MiscReceipts/query.sql:58-59` filters `= 'DMT-'\|\|:P_RUN_ID OR LIKE …`; switch to REQUEST_ID. Remove the `misc_receipt_results:169` tier-3 match on TRANSACTION_REFERENCE. |
| MiscReceipts | misc_receipt_transform:171; misc_receipt_gen:152 | SOURCE_HEADER_ID | `NVL(s.SOURCE_HEADER_ID, p_run_id)` | No (run id posing as a header id) | NUMBER. There is no header TFM table, so use the row's own TFM id (or keep the source value). | None found. |
| Customers (all 7 record types) | cust_transform:105, 319, 533/535/537, 728/730/737, 913/915, 1107/1109/1111, 1297/1299; cust_gen:154, 219, 295-299 and following | PARTY_, LOCATION_, SITE_, SITEUSE_, CUST_ (account), CUST_SITE_ and CUST_SITEUSE_ ORIG_SYSTEM_REFERENCE: the within-file linking keys (site → party, account site → site, and so on) | `PREFIXED(l_prefix, s.<source OSR>)` | No under the literal rule (7 fields) | HZ_IMP_* OSR VARCHAR2(255). Fits. Each child carries the parent's TFM id through a same-run join on the source OSR. **Owner decision:** these are TCA source-system references that Fusion keeps in HZ_ORIG_SYS_REFERENCES as cross-references for later loads, so they are partly business keys. | RECON_KEY = `'Customers.<Type>~'\|\|<OSR>` (cust_transform:189,415,615,800,989,1182,1369). `bip/Customers/query.sql:80+` builds RECORD_KEY the same way. `cust_results:284-285` parses the text after `'~'` (CONFIRM_REFERENCE_ROUNDTRIP). Drop the OSR `LIKE :P_PREFIX` arm in query.sql; load_request_id is already the primary filter (`:87-138`). AR passes `ORIG_SYSTEM_BILL_*_REF` through unprefixed (ar_transform:256-266), so any downstream OSR consumer would need an xref. |
| Customers (PartySiteUses, AccountSiteUses, synthesized when the source is NULL) | cust_gen:118-121, 129-132 | SITEUSE_ORIG_SYSTEM_REF / CUST_SITEUSE_ORIG_SYS_REF | `PREFIXED(prefix, TFM_SEQUENCE_ID\|\|'-'\|\|wqid)` | No (prefix and work-queue id wrapped around the TFM id) | 255. Use the bare `TO_CHAR(TFM_SEQUENCE_ID)`. Counted inside the 7 Customers fields above. | Same as the row above. |

### PPM

| Object | file:line (transform; generator) | Field | Current expression | Conforms | Fusion limit; TFM id fits? | Reconciler impact |
|---|---|---|---|---|---|---|
| Expenditures | expenditure_transform:228 (RECON_KEY copy :331-334); expenditure_gen:139 | ORIG_TRANSACTION_REFERENCE (Slot A recon key) | `PREFIXED(l_dep_prefix, s.ORIG_TRANSACTION_REFERENCE, 240)` | No (prefix plus source ref). **Owner confirm:** this is the legacy source reference, which users can see. | TFM 240; Fusion width not recorded in the repo. A TFM id fits. NEXTVAL is already in the INSERT (`:155`). `REVERSED_ORIG_TXN_REFERENCE` (`:230`) points at an original's reference, so a reversal pair must resolve the original row's TFM id. | `bip/Expenditures/query.sql:52,61,71,87` scope with `LIKE :P_PREFIX\|\|'%'`; change to job-id scoping. **Constraint:** the data model's comment (`:27-29`) says per-row ESS ids are not captured on this pod, so REQUEST_ID-only scoping is unproven here. `expenditure_results:247,278,327-381,445,498` are equality matches and stay OK. Drop the `:676` tier-3 business-key match. |
| BillingEvents | billing_event_transform:92 (RECON_KEY :170-173); billing_event_gen:77 | SOURCEREF (Slot A recon key) | `PREFIXED(l_prefix, s.SOURCEREF)` | No. **Owner confirm**, as for Expenditures. | TFM 240. Fits. NEXTVAL is in the INSERT (`:87`). | `bip/BillingEvents/query.sql:55,65,76` LIKE scope; switch to `be.request_id`, which is present on the pod. `billing_event_results:135-226,295-356` are equality matches and stay OK. Drop the `:637` tier-3 business-key match. |
| ProjectBudgets | prj_budget_transform:132-134 (fit guard :57-80, RECON_KEY :196-199); prj_budget_gen:126 | SRC_BUDGET_LINE_REFERENCE (→ PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE) | `PREFIXED(l_prefix, s.SRC_BUDGET_LINE_REFERENCE, 100)` | No. **Owner confirm.** | VARCHAR2(100), verified live. Fits. The INSERT has no NEXTVAL, so it needs one or a post-insert UPDATE. **Grain constraint:** the base table keeps one PM_BUDGET_REFERENCE per plan version, while the TFM has one row per budget line, so only one line's id survives and the reconciler must fan the verdict out to all of that version's lines. | The `bip/ProjectBudgets/query.sql` BASE tier (~:120-140) uses `NVL(pm_budget_reference, …)` with a `LIKE :P_PREFIX` scope; change to job-id scoping (per-row ESS ids are not captured on this pod). `prj_budget_results:201,367` are equality matches and stay OK. The fit guard at `:57-80` becomes obsolete. |

### HCM (HDL)

These rules apply to every HDL row below.

- **SourceSystemId is permanent.** It is stored for the life of the pod in HRC_INTEGRATION_KEY_MAP, per SourceSystemOwner and object. Reloading the same id updates the earlier record instead of creating a new one.
- **Every generator hardcodes the owner.** SourceSystemOwner is `C_SOURCE_SYSTEM := 'HRC_SQLLOADER'` everywhere (for example `absence_hdl_gen:27`).
- **Precondition for the TFM id.** TFM sequences restart on `--fresh` and overlap between Docker and ATP. Before any HDL SourceSystemId becomes a TFM id, SourceSystemOwner must be made unique per DMT database instance, or the id must be namespaced per instance. Otherwise a new row can silently update an unrelated earlier person.
- **Length.** HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID is 4000 characters (`dmt_ref_carrier_cfg_tbl.sql` header). `RECONCILE_HDL` reads it as VARCHAR2(200). A TFM id fits.
- **Shared reconciler fixes.**
  - `dmt_hdl_util_pkg.pkb.sql:440` matches `jt.src_ref LIKE t.<key>||'%'`. With numeric ids this would match TFM 12 to 123, so it must become exact equality.
  - The suffix branch (`:441-457`, used by `assignment_results:331` with `'_TRM,_ASG'`) goes away.
  - Every HCM BIP report except PerfEvaluations scopes by `source_system_id LIKE :P_PREFIX||'%'`, often plus a suffix such as `'%\_SAL'`. HRC_INTEGRATION_KEY_MAP has no REQUEST_ID, so scoping must move to the HDL data set or request (the HRC_DL_* tables) or to an IN-list of TFM ids.

| Object | file:line (transform; generator) | Field | Current expression | Conforms | Fusion limit; TFM id fits? | Reconciler impact |
|---|---|---|---|---|---|---|
| Workers (Person) | worker_transform:98 (RECON_KEY); worker_hdl_gen:205 | Worker SourceSystemId | `PREFIXED(prefix, PERSON_NUMBER, 30)` | No | Fits, given the precondition. The generator comment at `:160-164` says the id "must equal PERSON_NUMBER", but Fusion does not require that: the base match can join the key map to PER_ALL_PEOPLE_F on SURROGATE_ID. | `bip/Workers/query.sql:53` LIKE prefix. `worker_results:42` CONFIRM_REFERENCE_ROUNDTRIP compares RECON_KEY to the person number. `worker_results:528-589` pass `p_key_column=>'PERSON_NUMBER'`. |
| Workers (PersonName) | worker_hdl_gen:234 (id), :236 (PersonId FK) | Name id; PersonId(SourceSystemId) | `PN\|\|'_NME'`; FK `PN` | No | Fits. FK = the parent DMT_WORKER_TFM id from the same run. | `worker_results:91` `SUBSTR(p_record_key,1,LENGTH-4)` strips a 4-character suffix; replace it with a direct TFM-id match. |
| Workers (Email) | worker_hdl_gen:411/412 | Email id + PersonId FK | `PN\|\|'_EML'` | No | Fits. | `worker_results:91` suffix strip; `:549-589`. |
| Workers (Phone) | worker_hdl_gen:445/446 | Phone id + FK | `PN\|\|'_PHN'` | No | Fits. | Same. |
| Workers (Address) | worker_hdl_gen:474/476 | Address id + FK | `PN\|\|'_ADR'` | No | Fits. | Same. |
| Workers (NationalIdentifier) | worker_hdl_gen:508/509 | NID id + FK | `PN\|\|'_NID'` | No | Fits. | Same. |
| Workers (PersonLegislativeData) | worker_hdl_gen:534/536 | Legislative id + FK | `PN\|\|'_LEG'` | No | Fits. | Same. |
| Assignments (WorkRelationship) | assignment_transform:88 (DMT_WORK_REL_TFM RECON_KEY); worker_hdl_gen:262/263 | PeriodOfService id + PersonId FK | `PN\|\|'_POS'` | No | Fits. Emit from DMT_WORK_REL_TFM_TBL's own TFM id; the generator currently loops DMT_WORKER_TFM_TBL. | `bip/Assignments/query.sql:51` LIKE prefix. |
| Assignments (WorkTerms) | worker_hdl_gen:317 (id), :318 (PeriodOfServiceId FK), :370 (WorkTermsAssignmentId FK) | WorkTerms id | `ASSIGNMENT_NUMBER\|\|'_TRM'` | No | **The bare TFM id cannot be used.** WorkTerms and Assignment come from the same DMT_ASSIGNMENT_TFM_TBL row and both sit under key-map OBJECT_NAME 'Assignment', so they would collide. This needs its own TFM row or table, or a distinct owner. | `assignment_results:331` `'_TRM,_ASG'` suffixes; `bip/Assignments/query.sql:70`. |
| Assignments (Assignment) | assignment_transform:271 (RECON_KEY); worker_hdl_gen:365 | Assignment id | `PREFIXED(ASSIGNMENT_NUMBER,30)\|\|'_ASG'` | No | Fits, apart from the WorkTerms collision above. | Same as WorkTerms. |
| Salary | salary_transform:100 (RECON_KEY); salary_hdl_gen:123 | Salary id | `PN\|\|'_SAL'` | No | Fits, and also fixes a latent collision when one person has two salary rows. | `bip/Salaries/query.sql:38-39` prefix plus `'%\_SAL'`. `hcm_compare:147-192` uses the RECON_KEY list, which works with any format. |
| Salary | salary_hdl_gen:124 | AssignmentId(SourceSystemId) FK | `ASSIGNMENT_NUMBER\|\|'_ASG'` | No | **Cross-object, cross-run:** this would have to carry the Assignment TFM id from an earlier Workers run. That needs a new DMT_XREF_PKG resolver (deferred by policy) or a switch to the AssignmentNumber user key. | Same as the row above. |
| SalaryBasis | sal_basis_transform:85 (RECON_KEY); sal_basis_hdl_gen:102 | SalaryBasis id | `PREFIXED(SALARY_BASIS_NAME,240)` | No | Fits. SalaryBasisName (`:103`) stays as a business key. | `bip/SalaryBases/query.sql:45`; `sal_basis_results:221` key column SALARY_BASIS_NAME. |
| PayrollRelationships | pay_rel_transform:78 (RECON_KEY) | id / RECON_KEY | `PN\|\|'_PAYREL'` | No | Fits. **Retired path:** its dispatch rows were deleted on 2026-09-17 and there is no generator, so fix it or delete it along with the rest. | `bip/PayrollRelationships/query.sql:36-37`. |
| TalentProfiles | talent_prof_transform:74 (RECON_KEY); talent_prof_hdl_gen:119 | Profile id | `PN\|\|'_TPROF'` | No | Fits. | `bip/TalentProfiles/query.sql:83,102` LIKE prefix. |
| TalentProfiles | talent_prof_transform:145 (RECON_KEY); talent_prof_hdl_gen:147, :148 | ProfileItem id + TalentProfileId FK | `PN\|\|'_TPITM'`; FK `PN\|\|'_TPROF'` | No | Fits. FK = the profile's TFM id from the same run. | Same. |
| TalentProfiles | talent_prof_hdl_gen:120 | PersonId(SourceSystemId) FK | `PN` | No | **Cross-object** Worker key: needs an xref lookup or a switch to the PersonNumber user key. | Same. |
| Absence | absence_transform:97 (RECON_KEY); absence_hdl_gen:109 | Absence id | `PN\|\|'_ABS'` | No | Fits. | `bip/Absences/query.sql:47` LIKE prefix; `absence_results:225` PERSON_NUMBER LIKE. |
| Absence | absence_hdl_gen:110 | PersonId(SourceSystemId) FK | `PN` | No | **Cross-object** Worker key, same as TalentProfiles. | Same. |
| BenDependent | ben_depend_transform:118-134 (MERGE RECON_KEY); ben_depend_hdl_gen:175-182 | DesignateDependent id | `PN\|\|'_'\|\|DEP_PN\|\|'_'\|\|ROW_NUMBER\|\|'_BENDEP'` | No | Fits (the row's own TFM id). | `bip/BenDependent/query.sql:49-50` prefix plus `'%\_BENDEP'`. |
| BenDependent | ben_depend_hdl_gen:143/145 | DependentEnrollment (parent) id | `PN\|\|'_BENDEP'` | No | **No 1:1 TFM row:** the parent is GROUP BY PERSON_NUMBER (`~:125-140`). Use MIN(TFM_SEQUENCE_ID) of the group and fan the result out to the group. | Same. |
| BenBeneficiary | ben_benfy_hdl_gen:196 | Beneficiary designation id | `PN\|\|'_BENDSGN'\|\|line_no` | No | Fits. | `bip/BenBeneficiary/query.sql:64-65` prefix plus `'%\_BENENRL'`. |
| BenBeneficiary | ben_benfy_transform:85 (RECON_KEY); ben_benfy_hdl_gen:158 | BeneficiaryEnrollment (parent) id | `PN\|\|'_BENENRL'` | No | **Aggregated per person** (`~:147-155`), same as BenDependent. | Same. |
| TaxCalculationCard | tax_card_hdl_gen:110 | Card id | `PN\|\|'_TAXCARD'` | No | Fits. The transform sets no RECON_KEY. | `bip/TaxCards/query.sql:44` LIKE prefix; `tax_card_results:54,65` PERSON_NUMBER LIKE. |
| TaxCalculationCard | tax_card_hdl_gen:129, :130 | Component id + CalculationCardId FK | `PN\|\|'_TAXCOMP'`; FK `PN\|\|'_TAXCARD'` | No | Fits. The FK join from DMT_TAX_CARD_COMP to DMT_TAX_CARD on PERSON_NUMBER is ambiguous when a person has more than one card (already true today). | Same. |
| WorkSchedules | work_sched_transform:76 (RECON_KEY); work_sched_hdl_gen:174 | WorkPattern id | `NAME\|\|'_WPAT'` | No | Fits (DMT_WORK_SCHED TFM id). The pattern and the schedule assignment come from the same TFM row under different key-map objects, so verify per-object uniqueness. | `bip/WorkSchedules/query.sql:48-49` `'%\_WPAT'`; `work_sched_results:222,234`. |
| WorkSchedules | work_sched_hdl_gen:199 | Shift id | `NAME\|\|'_WSHIFT_'\|\|TFM_SEQUENCE_ID` | No (closest to conforming, but still a composite) | Fits (the DTL TFM id). | Same. |
| WorkSchedules | work_sched_hdl_gen:233 | ScheduleAssignment id | `PN\|\|'_WSASG'` | No | Fits (see the uniqueness caveat). | `bip/WorkSchedules/query.sql:69-70` `'%\_WSASG'`. |
| W2Balances | w2_bal_hdl_gen:196 | Line LineSequence (line key) | `l_line_seq` running counter | No | Numeric. The DTL TFM id fits. | `w2_bal_results:13-28,110`. |
| W2Balances | w2_bal_transform:79 (RECON_KEY); w2_bal_hdl_gen:167 (header), :195 (line FK) | BatchName (header key and line FK) | `prefix\|\|'_W2BAL'` | No | **The TFM id cannot be used directly.** It is one run-level header aggregated over all rows with no 1:1 TFM row, and it is a batch name users see in the UI. Recommend reclassifying it as a business key prefixed by design, or using MIN(TFM id). | `bip/W2Balances/query.sql:68-78` `batch_name LIKE prefix`. |

Count check: Workers 7 + Assignments 3 + Salary 2 + SalaryBasis 1 + PayrollRelationships 1 + TalentProfiles 3 + Absence 2 + BenDependent 2 + BenBeneficiary 2 + TaxCalculationCard 2 + WorkSchedules 3 + W2Balances 2 = 30.

## Conforming keys (no change needed)

| Object | file:line | Field | Expression |
|---|---|---|---|
| GLBalances | gl_transform:119-123; gl_gen:118 | RECON_KEY → REFERENCE21 → GL_JE_LINES.REFERENCE_1 | `TO_CHAR(TFM_SEQUENCE_ID)`, set post-insert |
| APInvoices | ap_gen:80 | Header INVOICE_ID | `TO_CHAR(TFM_SEQUENCE_ID)` |
| APInvoices | ap_gen:244-247 | Line INVOICE_ID (parent key) | the parent header's TFM_SEQUENCE_ID, through a TFM join |
| Assets | fa_asset_gen:67 | MASS_ADDITION_ID | `b.TFM_SEQUENCE_ID` (book TFM) |
| Assets | fa_asset_gen:518, 586-590 | Distribution MASS_ADDITION_ID (parent key) | `MIN(b.TFM_SEQUENCE_ID)` of the asset's book rows. With more than one book per asset, distributions link only to the first book row. |
| MiscReceipts | misc_receipt_transform:267-271; gen :94, 449-450, 472, 526 | INV_LOTSERIAL_INTERFACE_NUM and the lot/serial link to it | `TO_CHAR(p.TFM_SEQUENCE_ID)` |

**Related internal defect at APInvoices** (not a file key): the TFM column INVOICE_ID is `NVL(s.INVOICE_ID, p_run_id*10000 + s.STG_SEQUENCE_ID)` (ap_transform:174). It is used only to join headers to lines.
- If the source omits a header INVOICE_ID, the line's INVOICE_ID is NULL, and the generator join at `:246` emits a NULL line key.
- `run*10000 + stg` collides across runs once a STG id passes 10,000.
- Fix: link lines to the header TFM id at transform time.

## Where the TFM id cannot be used, or not without a design change

1. **GLBudget RECON_KEY** (gl_budget_transform:79-93): GL_BUDGET_INTERFACE and GL_BUDGET_BALANCES have no per-row carrier column, and a budget is a cell, not a transaction. The internal cell-key composite stays.
2. **Run-level batch and group stamps:** every row of a load must share these values, and they are passed as ESS arguments, so they are not row keys and stay outside the rule.
   - GLBalances GROUP_ID = run_id (gl_transform:79). This could move to REQUEST_ID.
   - GLBudget RUN_NAME (gl_budget_transform:33).
   - Customers BATCH_ID.
   - Items and ItemCategories BATCH_ID.
   - Expenditures BATCH_NAME. The loader overwrites it with the work-queue id (dmt_loader_pkg:3398-3428) because PJC_UNIQUE_BATCH_NAME applies. The per-row fallback at expenditure_transform:176-177 is dead code to delete.
3. **The W2Balances BatchName** is a run-level aggregate header that users see. Reclassify it as a business key.
4. **HDL WorkTerms versus Assignment** share one TFM row and one key-map object, so a bare TFM id collides. This needs a distinct TFM row or table.
5. **BenDependent and BenBeneficiary parent enrollments** are per-person aggregates with no single TFM row. Use MIN(TFM id) of the group and fan the result out.
6. **Cross-object HDL foreign keys** (Salary → Assignment; Absence and TalentProfiles → Person) need the parent's TFM id from an earlier Workers run. That requires a new DMT_XREF_PKG resolver, which current policy defers, or a switch to the PersonNumber/AssignmentNumber user keys.
7. **The HDL precondition:** SourceSystemOwner must be unique per DMT database instance, because HDL keys are permanent and TFM ids repeat across `--fresh` rebuilds and between Docker and ATP.
8. **Grain constraints** (the TFM id is usable, but only one id survives per Fusion row):
   - ARInvoices ATTR1 is invoice-level: use the first line's TFM id.
   - ProjectBudgets keeps one reference per plan version.
   - Projects tasks, team members and transaction controls have no carrier that round-trips (PJF_PROJECTS_ALL_B.REQUEST_ID is NULL after import on this pod), so Projects cannot move to job-id matching at the base tier yet.
   - PlanningBudgets writes no key at all (query.sql:61 returns RECORD_KEY = NULL).

## Business keys, prefixed by design (not violations)

| Object | file:line | Field |
|---|---|---|
| Requisitions | req_transform:117 | REQUISITION_NUMBER (`PREFIXED(...,64)`) |
| PO family | po_transform:151 | DOCUMENT_NUM (`PREFIXED(...,20)`) |
| APInvoices | ap_transform:177 | INVOICE_NUM (`PREFIXED(...,50)`) |
| Suppliers | poz_sup_transform:144, 146 | VENDOR_NAME; SEGMENT1 supplier number (25) |
| SupplierSites | poz_sup_site_transform:193 | VENDOR_SITE_CODE (15) |
| PaymentTerms | ap_pay_term_transform:122 | NAME (50) |
| ARInvoices | ar_transform:255 | TRX_NUMBER |
| GLBalances | gl_transform:77 | REFERENCE1 (batch name) |
| Customers | cust_transform:108, 116, 118-119, 331, 546, 916, 926, 1120, 1307 | PARTY_NUMBER, ORGANIZATION_NAME, PERSON_FIRST/LAST_NAME, ADDRESS1, PARTY_SITE_NAME, ACCOUNT_NUMBER, ACCOUNT_NAME |
| Assets | fa_asset_transform:47, 163, 250 | ASSET_NUMBER |
| Items, ItemCategories | egp_item_transform:252 | ITEM_NUMBER. The internal RECON_KEY `ITEM_NUMBER~ORG` (`:473`) and the ItemCategories composite (`egp_item_cat_transform:126-127`) are never written to the file. |
| Banks, BankBranches, BankAccounts | ce_bank_transform:129, 317, 520, 522 | BANK_NAME, ACCOUNT_NAME (REST; SOURCE_GROUP_ID/SOURCE_LINE_ID are never sent to Fusion) |
| UnitsOfMeasure | inv_uom_transform:147-151 | UOM_CODE, UNIT_OF_MEASURE |
| Lookups | fnd_lookup_transform:125-126, 322 | LOOKUP_TYPE, MEANING |
| ValueSets | fnd_vs_transform:123, 318 | VALUE_SET_CODE |
| TaxRegimes, TaxRates | zx_transform:129, 341 | TAX_REGIME_CODE |
| Projects | project_transform:178-179, 492-493, 737, 924-925 | PROJECT_NAME, PROJECT_NUMBER (SEGMENT1). These also act as the parent keys for tasks, team members and transaction controls. |
| Grants | grants_transform:94, 275, 407, … 1876 | AWARD_NUMBER, the only header-to-child link across the 14 child CSVs |
| ProjectBudgets | prj_budget_transform:126-128 | PLAN_VERSION_NAME |
| Workers and HCM | worker_transform:82 and children; assignment_transform:237, 253, 259; salary_transform:81; sal_basis_transform:74; ben_depend_transform:68; ben_benfy_transform:69; work_sched_hdl_gen:235 | PERSON_NUMBER, ASSIGNMENT_NUMBER, MANAGER_*_NUMBER, SalaryBasisName, DEPENDENT/BENEFICIARY_PERSON_NUMBER, WORK_SCHEDULE_NAME |
| BenParticipant | ben_partic_transform:89 | RECON_KEY = prefixed PersonNumber (create-only, no SourceSystemId) |
| PerfEvaluations | perf_eval_transform:78; perf_eval_hdl_gen:151-152, 193-194 | DOCUMENT_NAME; user keys AssignmentNumber and CustomaryName (no SourceSystemId) |

## Not verified (read-only BIP queries before the fix)

- Whether POR_REQUISITION_LINES_ALL and POR_REQ_DISTRIBUTIONS_ALL carry REQUEST_ID. The Requisitions BASE tier needs a replacement scope.
- The width of PJC_TXN_XFACE_ALL.ORIG_TRANSACTION_REFERENCE and of the PJB_BILLING_EVENTS_INT.SOURCEREF Fusion column.
- The grain of HRC_INTEGRATION_KEY_MAP uniqueness (owner + object + id) and how a SourceSystemOwner other than HRC_SQLLOADER behaves on this pod.
- Whether the BlanketPO and Contract recon data models already filter on load_request_id next to the `_HDR_` LIKE.
