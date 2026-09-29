-- Seed data for DMT_REF_CARRIER_CFG_TBL (backlog #12, owner-approved 2026-09-19).
-- One row per TFM table (the object's HEADER/primary tier). Each row names the
-- three carrier slots the generator stamps and the reconciler reads back:
--
--   Slot A -- a native source-reference field that receives the per-record TFM id
--            (SLOT_A_FIELD = the interface/HDL attribute written; SLOT_A_BASE_COLUMN
--            = the base-table column read at reconcile). NULL where none exists.
--   Slot B -- a native batch/group/request field that receives the run id. NULL
--            where none exists.
--   Slot C -- the highest text descriptive-flexfield attribute, which ALWAYS
--            receives the full reference  DMT:<run_id>:<work_queue_id>:<tfm_seq_id>.
--            SLOT_C_MAXLEN is its char length. NULL where the base table has none.
--
-- REF_FORMAT = FULL when Slot C is long enough to hold the full reference
-- (DMT:<run>:<wq>:<tfm>), COMPACT (DMT:<tfm>) only when SLOT_C_MAXLEN < 40 or the
-- sole carrier is a native field shorter than 40 chars. Every row here holds a
-- Slot C of 150+ chars (or has no Slot C at all), so every REF_FORMAT is FULL.
--
-- CONFIDENCE (re-audited 2026-09-29 against every reconciler + live Fusion):
--   CONFIRMED  -- the carrier is PROVEN to work end to end, all three true:
--                (1) SLOT_A_FIELD/Slot C is a loadable template column; (2) it
--                round-trips to a real, queryable SLOT_A_BASE_COLUMN in Fusion;
--                (3) the object's reconciler MATCHES on that carrier (its RECON_KEY
--                is stamped equal to the Slot A/C value). PROVEN_ON_RUN names the run.
--   UNVERIFIED -- any of the three is not established. Most rows here reconcile on
--                the BUSINESS KEY (INVOICE_NUM, DOCUMENT_NUM, PROJECT_NUMBER, ...) or
--                on the load request id, NOT on the carrier slot -- so the Slot A/B/C
--                values are provenance/audit only. NOTES states the real match method.
--   NONE       -- the object has no carrier column at all.
-- THE AUDIT (what changed and why): the prior pass marked almost everything CONFIRMED
-- on the weak test "the interface field exists," which is NOT the same as "it
-- round-trips to the base column the reconciler reads." Reading every *_results_pkg /
-- *_transform_pkg showed most reconcilers join RECON_KEY = a prefixed business key,
-- never the named Slot A field. Those rows are now UNVERIFIED with the true method.
-- Only the carriers a reconciler actually keys on AND that were proven on a live run
-- keep CONFIRMED (GLBalances, Customers, BillingEvents, Expenditures, Workers,
-- Salaries -- all PROVEN_ON_RUN=132). The APInvoices row is the headline fix: its
-- Slot A REFERENCE_KEY1 is not in the 164-column AP-invoice-lines FBDI template AND
-- the AP reconciler matches on the prefixed INVOICE_NUM, so REFERENCE_KEY1 is removed
-- and the row is UNVERIFIED (reconciles on business key).
--
-- PROVEN_ON_RUN = the run id whose live evidence backs a CONFIRMED claim (falsifiable:
-- CONFIRMED must cite a run); NULL where unproven. Run 132 is the proven post-run
-- comparison covering 23 objects (DMT_RUN_COMPARISON_TBL), the source of that evidence.
-- ACTIVE_FLAG='N' disables a row without deleting it. Carrier is config, not code:
-- changing a slot is a seed edit + redeploy, no PL/SQL change.
--
-- Idempotent: MERGE on the unique key TFM_TABLE converges each row on re-run.
--
-- PO family note: PurchaseOrders, BlanketPOs and Contracts all stage into the ONE
-- header TFM table DMT_PO_HEADERS_INT_TFM_TBL (discriminated by STYLE_DISPLAY_NAME),
-- so they share ONE carrier row (keyed by that table, CEMLI_CODE 'PurchaseOrders').
-- HDL family note: Slot A is universal SourceSystemId, whose base column is
-- HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID (4000 chars); Slot B is not used for HDL.
-- Slot C is NOT available for HDL persons (backlog #12, verified live 2026-09-20 on
-- the Workers proof-of-recipe): the person key map HRC_INTEGRATION_KEY_MAP has no
-- attribute/DFF column (only OBJECT_NAME, GUID, SURROGATE_ID, SOURCE_SYSTEM_OWNER,
-- SOURCE_SYSTEM_ID, ORA_PART_KEY), and the Worker.dat writes no PER_ALL_PEOPLE_F
-- ATTRIBUTE that is proven to round-trip -- so per the GL lesson (do NOT assume a DFF
-- column round-trips) we do NOT invent a Slot C. The #12 round-trip for HDL rides
-- Slot A: SourceSystemId (= the prefixed PERSON_NUMBER we write) lands in
-- HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID (OBJECT_NAME='Person', SURROGATE_ID =
-- PER_ALL_PEOPLE_F.PERSON_ID) and comes back as the recon report's RECORD_KEY, which
-- equals the TFM row's RECON_KEY -- proving the value we stamped survived to the
-- base table. Every HDL row below therefore carries SLOT_C_ATTRIBUTE = NULL.
merge into "DMT_REF_CARRIER_CFG_TBL" t
using (
    -- ================= FBDI objects =================
    select 'GLBalances' cemli_code, 'GL Journals' sub_object,
           'DMT_GL_INTERFACE_TFM_TBL' tfm_table,
           'REFERENCE21' slot_a_field, 'GL_JE_LINES.REFERENCE_1' slot_a_base_column,
           'GROUP_ID' slot_b_field, 'REFERENCE22' slot_c_attribute, 240 slot_c_maxlen,
           'FULL' ref_format, 'CONFIRMED' confidence, 132 proven_on_run, 'Y' active_flag,
           -- Slot C corrected 2026-09-19 (proof-of-recipe run 301): GL Journal
           -- Import does NOT carry GL_INTERFACE.ATTRIBUTE20 onto GL_JE_LINES
           -- (GL_JE_LINES has no ATTRIBUTE20; GL_JE_HEADERS has none either), so
           -- the full ref must ride a line REFERENCE that Journal Import maps
           -- through. REFERENCE22 -> GL_JE_LINES.REFERENCE_2 round-trips (proven,
           -- same mechanism as REFERENCE21 -> REFERENCE_1). RECIPE LESSON for the
           -- fan-out: Slot C must be a column the object''s import actually
           -- carries to the base table, verified per object -- not assumed.
           'CONFIRMED (run 132): reconciler keys RECON_KEY(=TFM_SEQUENCE_ID) stamped ' ||
           'into REFERENCE21 -> GL_JE_LINES.REFERENCE_1 (queried live, populated). ' ||
           'Slot C = REFERENCE22 -> GL_JE_LINES.REFERENCE_2.' notes from dual
    union all select 'Customers', 'Parties', 'DMT_HZ_PARTIES_TFM_TBL',
           'PARTY_ORIG_SYSTEM_REFERENCE', 'HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE',
           null, null, null, 'FULL', 'CONFIRMED', 132, 'Y',
           -- Corrected 2026-09-20 (backlog #12 proof-of-recipe, live run). This row
           -- is the TEMPLATE for the TCA family (Customers + the 5 supplier objects),
           -- all keyed on ORIG_SYSTEM_REFERENCE. THREE slots resolved to reality:
           --   Slot A = PARTY_ORIG_SYSTEM_REFERENCE. The transform already PREFIXES it
           --     and the reconciler matches Parties on it; the recon report reads the
           --     value back from the Fusion BASE table HZ_ORIG_SYS_REFERENCES
           --     (owner_table_name=HZ_PARTIES, owner_table_id=HZ_PARTIES.PARTY_ID). It
           --     is the identity carrier and VERIFIABLY round-trips -- this is the #12
           --     round-trip proof (same shape as HDL Workers riding Slot A). Its base
           --     column is HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE, NOT
           --     HZ_PARTIES.ORIG_SYSTEM_REFERENCE (that column is a legacy single-value
           --     stamp, not what the reconciler reads).
           --   Slot B = NULL. The seed guessed REQUEST_ID; the party interface TFM has
           --     no REQUEST_ID (or any batch/request) column, so there is no Slot B.
           --   Slot C = NULL. The seed guessed ATTRIBUTE30; the parties interface has
           --     only ATTRIBUTE1..ATTRIBUTE20 (no ATTRIBUTE30 column exists) and NO
           --     ATTRIBUTE is proven to round-trip to an HZ_PARTIES base column. Per the
           --     GL lesson (GL_INTERFACE.ATTRIBUTE20 did NOT carry through) we do NOT
           --     invent a Slot C. The full run-scoped ref (DMT:run:wq:tfm from
           --     BUILD_REF) is logged for audit at reconcile; the #12 round-trip rides
           --     Slot A. WORK_QUEUE_ID is stamped from g_gen_queue_id at generation.
           'TCA party carrier and TEMPLATE for the TCA family (Customers + 5 supplier ' ||
           'objects). #12 round-trip rides Slot A (PARTY_ORIG_SYSTEM_REFERENCE -> ' ||
           'HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE). Slot B/C NULL: no batch ' ||
           'column and no round-trippable attribute on the party interface.' from dual
    union all select 'Suppliers', 'Suppliers', 'DMT_POZ_SUPPLIERS_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_POZ_SUP_RESULTS_PKG reconciles by filtering POZ_SUPPLIERS_INT ' ||
           'on LOAD_REQUEST_ID (the load ESS id), not on any stamped carrier slot; no ' ||
           'SLOT_A_BASE_COLUMN verified. Slot B/C are audit-only.' from dual
    union all select 'SupplierAddresses', 'Supplier Addresses', 'DMT_POZ_SUP_ADDR_TFM_TBL',
           'ORIG_SYSTEM_REFERENCE', null,
           'REQUEST_ID', 'ATTRIBUTE30', 255, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciles on LOAD_REQUEST_ID (POZ_*_INT), not on ORIG_SYSTEM_REFERENCE; ' ||
           'no base column verified.' from dual
    union all select 'SupplierSites', 'Supplier Sites', 'DMT_POZ_SUP_SITE_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE20', null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciles on LOAD_REQUEST_ID (POZ_*_INT), not on a carrier slot; ' ||
           'ATTRIBUTE20 length not re-queried.' from dual
    union all select 'SupplierSiteAssignments', 'Supplier Site Assignments', 'DMT_POZ_SUP_SITE_ASSN_TFM_TBL',
           null, null,
           'REQUEST_ID', null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciles on LOAD_REQUEST_ID (POZ_SITE_ASSIGNMENTS_INT), not on a ' ||
           'carrier slot; no native source-ref and no attribute column.' from dual
    union all select 'SupplierContacts', 'Supplier Contacts', 'DMT_POZ_SUP_CONTACTS_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE20', null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciles on LOAD_REQUEST_ID (POZ_*_INT), not on a carrier slot; ' ||
           'ATTRIBUTE20 length not re-queried.' from dual
    union all select 'Requisitions', 'Req Headers', 'DMT_POR_REQ_HEADERS_TFM_TBL',
           'INTERFACE_SOURCE_CODE', null,
           'REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_REQ_RESULTS_PKG matches RECON_KEY = REQUISITION_NUMBER (business ' ||
           'key), not INTERFACE_SOURCE_CODE; the Slot A/B/C values are audit-only.' from dual
    union all select 'PurchaseOrders', 'PO Headers (covers BlanketPOs + Contracts)', 'DMT_PO_HEADERS_INT_TFM_TBL',
           'INTERFACE_SOURCE_CODE', null,
           'REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_PO_RESULTS_PKG matches RECON_KEY = DOCUMENT_NUM (business key), not ' ||
           'INTERFACE_SOURCE_CODE. ONE row for the PO_HEADERS_INTERFACE family (PurchaseOrders, ' ||
           'BlanketPOs, Contracts share this TFM table, discriminated by STYLE_DISPLAY_NAME).' from dual
    union all select 'APInvoices', 'AP Invoice Headers', 'DMT_AP_INVOICES_INT_TFM_TBL',
           null, null,
           'BATCH_ID', 'ATTRIBUTE15', 1000, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED (audit fix 2026-09-29): the prior Slot A REFERENCE_KEY1 is REMOVED -- it ' ||
           'is not in the fixed 164-column AP-invoice-lines FBDI template (stamping it makes ' ||
           'SqlLdr reject the load) AND DMT_AP_RESULTS_PKG matches RECON_KEY = prefixed ' ||
           'INVOICE_NUM (business key), never REFERENCE_KEY1. AP reconciles on the business ' ||
           'key today; Slot B/C are audit-only.' from dual
    -- AP invoice LINE tier. A row keyed on the lines TFM table exists in deployed
    -- instances (carried the same REFERENCE_KEY1/CONFIRMED defect as the header row).
    -- Seeded explicitly so the MERGE corrects it in place: REFERENCE_KEY1 is NOT in
    -- the fixed 164-column AP-invoice-lines FBDI template, and the AP reconciler keys
    -- the line tier on RECON_KEY = prefixed INVOICE_NUM||':LINE:'||LINE_NUMBER
    -- (business key), never REFERENCE_KEY1.
    union all select 'APInvoices', 'AP Invoice Lines', 'DMT_AP_INVOICE_LINES_INT_TFM_TBL',
           null, null,
           'BATCH_ID', 'ATTRIBUTE15', 1000, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED (audit fix 2026-09-29): Slot A REFERENCE_KEY1 REMOVED (not in the ' ||
           '164-column AP-invoice-lines FBDI template; SqlLdr rejects it). DMT_AP_RESULTS_PKG ' ||
           'keys the line tier on RECON_KEY = prefixed INVOICE_NUM||'':LINE:''||LINE_NUMBER ' ||
           '(business key). Slot B/C audit-only.' from dual
    union all select 'ARInvoices', 'AR Lines', 'DMT_RA_LINES_TFM_TBL',
           'INTERFACE_HEADER_ATTRIBUTE1/INTERFACE_LINE_ATTRIBUTE1', null,
           'BATCH_ID', 'ATTRIBUTE30', 255, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_AR_RESULTS_PKG does stamp RECON_KEY = INTERFACE_LINE_ATTRIBUTE1 ' ||
           '(the Slot A field), but AutoInvoice has 0 LOADED on the demo (blocked on the ' ||
           'functional owner), so the interface->base round-trip is unproven and no base ' ||
           'column is verified. Promote to CONFIRMED once a run loads AR lines.' from dual
    union all select 'Items', 'Item Master', 'DMT_EGP_ITEM_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE50', 240, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_EGP_ITEM_RESULTS_PKG matches RECON_KEY = ITEM_NUMBER~ORGANIZATION_CODE ' ||
           '(business key), not ATTRIBUTE50; the Slot C value is audit-only.' from dual
    union all select 'Projects', 'Projects', 'DMT_PJF_PROJECTS_TFM_TBL',
           'PM_PROJECT_REFERENCE', null,
           'REQUEST_ID', 'ATTRIBUTE50', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_PROJECT_RESULTS_PKG matches RECON_KEY = PROJECT_NUMBER ' ||
           '(= PJF_PROJECTS_ALL_B.SEGMENT1, business key), not PM_PROJECT_REFERENCE.' from dual
    union all select 'Expenditures', 'Project Expenditures', 'DMT_PJC_EXPENDITURES_TFM_TBL',
           'ORIG_TRANSACTION_REFERENCE', 'PJC_EXP_ITEMS_ALL.ORIG_TRANSACTION_REFERENCE',
           'EXP_GROUP_ID', 'ATTRIBUTE10', 150, 'FULL', 'CONFIRMED', 132, 'Y',
           'CONFIRMED (run 132): DMT_EXPENDITURE_RESULTS_PKG matches RECON_KEY = ' ||
           'ORIG_TRANSACTION_REFERENCE, which the recon DM emits from base ' ||
           'PJC_EXP_ITEMS_ALL.ORIG_TRANSACTION_REFERENCE (queried live, populated). ' ||
           'Base column filled in this audit. Run id in EXP_GROUP_ID.' from dual
    union all select 'BillingEvents', 'Billing Events', 'DMT_PJB_BILL_EVENTS_TFM_TBL',
           'SOURCEREF', 'PJB_BILLING_EVENTS.SOURCEREF',
           'REQUEST_ID', 'ATTRIBUTE10', 150, 'FULL', 'CONFIRMED', 132, 'Y',
           'CONFIRMED (run 132): DMT_BILLING_EVENT_RESULTS_PKG matches RECON_KEY = SOURCEREF, ' ||
           'which the recon DM emits from base PJB_BILLING_EVENTS.SOURCEREF (queried live, ' ||
           'populated). Base column filled in this audit.' from dual
    union all select 'ProjectBudgets', 'Project Budgets', 'DMT_PRJ_BUDGET_TFM_TBL',
           'PM_BUDGET_REFERENCE', null,
           'REQUEST_ID', null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_PRJ_BUDGET_RESULTS_PKG does stamp RECON_KEY = SRC_BUDGET_LINE_REFERENCE ' ||
           '(the PM_BUDGET_REFERENCE value), but no SLOT_A_BASE_COLUMN is verified and the object ' ||
           'was not in a proven live run (run 132 had 0 loaded, KEY_TYPE NONE).' from dual
    union all select 'Grants', 'Award Headers', 'DMT_GMS_AWD_HEADERS_TFM_TBL',
           'AWARD_SOURCE', null,
           'DC_REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_GRANTS_RESULTS_PKG matches RECON_KEY = SPONSOR_AWARD_NUMBER (business ' ||
           'key), not AWARD_SOURCE; Grants also had 0 loaded on the demo. Slot B/C audit-only.' from dual
    union all select 'Assets', 'Asset Headers', 'DMT_FA_ASSET_HDR_TFM_TBL',
           null, null,
           null, 'ATTRIBUTE30', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_FA_ASSET_RESULTS_PKG matches RECON_KEY = ASSET_NUMBER (business key), ' ||
           'not ATTRIBUTE30; the Slot C value is audit-only.' from dual
    union all select 'MiscReceipts', 'Inventory Transactions', 'DMT_INV_TRX_TFM_TBL',
           'INTERFACE_SOURCE_CODE', null,
           'GROUP_ID', 'ATTRIBUTE20', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_MISC_RECEIPT_RESULTS_PKG matches RECON_KEY = TO_CHAR(SOURCE_LINE_ID) ' ||
           '(business key), not INTERFACE_SOURCE_CODE; Slot A/B/C audit-only.' from dual
    union all select 'GLBudgets', 'GL Budget Balances', 'DMT_GL_BUDGET_INT_TFM_TBL',
           null, null,
           null, null, null, 'FULL', 'NONE', null, 'Y',
           'NONE: no carrier column exists. DMT_GL_BUDGET_RESULTS_PKG reconciles on the full ' ||
           'ledger/period/segment business-key composite (owner decision 2026-09-19).' from dual
    union all select 'GLCalendar', 'GL Calendar', 'DMT_GL_CALENDAR_TFM_TBL',
           null, null,
           null, 'ATTRIBUTE8', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler does not key on ATTRIBUTE8, and GLCalendar was not in a proven ' ||
           'live run; the Slot C value is audit-only until confirmed.' from dual
    -- ================= HDL objects (Slot A = SourceSystemId, base HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID(2000); Slot B unused) =================
    union all select 'Workers', 'Workers', 'DMT_WORKER_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 132, 'Y',
           'CONFIRMED (run 132). HDL Worker header tier and TEMPLATE for the HDL family. Slot A ' ||
           'SourceSystemId = the prefixed PERSON_NUMBER; it round-trips to ' ||
           'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID (OBJECT_NAME=Person, ' ||
           'SURROGATE_ID = PER_ALL_PEOPLE_F.PERSON_ID) and returns as the recon ' ||
           'RECORD_KEY = the TFM RECON_KEY (verified live 2026-09-20). SourceSystemId ' ||
           'CANNOT embed the tfm id -- it must equal PERSON_NUMBER for the base match ' ||
           'and the child PersonId(SourceSystemId) FK hints. Slot C is NULL: HDL ' ||
           'persons have no attribute column that round-trips (see HDL family note).' from dual
    union all select 'Salaries', 'Salaries', 'DMT_SALARY_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 132, 'Y',
           'CONFIRMED (run 132): DMT_SALARY_RESULTS_PKG matches RECON_KEY = SourceSystemId, ' ||
           'round-trips to HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID (queried live). Slot C NULL.' from dual
    union all select 'SalaryBases', 'Salary Bases', 'DMT_SAL_BASIS_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler keys on the Slot A SourceSystemId (same mechanism as the ' ||
           'CONFIRMED Workers/Salaries), but this object was not in a proven live run (not in ' ||
           'run 132). Promote to CONFIRMED once a run loads it. Slot C NULL.' from dual
    union all select 'TaxCards', 'Tax Cards', 'DMT_TAX_CARD_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler keys on the Slot A SourceSystemId (same mechanism as ' ||
           'Workers/Salaries), but not proven on a live run. Slot C NULL.' from dual
    union all select 'BenParticipant', 'Participant Enrollment', 'DMT_BEN_PARTIC_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler keys on the Slot A SourceSystemId (same mechanism as ' ||
           'Workers/Salaries), but not proven on a live run. Slot C NULL.' from dual
    union all select 'BenDependent', 'Dependent Enrollment', 'DMT_BEN_DEPEND_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler keys on the Slot A SourceSystemId (same mechanism as ' ||
           'Workers/Salaries), but not proven on a live run. Slot C NULL.' from dual
    union all select 'BenBeneficiary', 'Beneficiary Enrollment', 'DMT_BEN_BENFY_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler keys on the Slot A SourceSystemId (same mechanism as ' ||
           'Workers/Salaries), but not proven on a live run. Slot C NULL.' from dual
    union all select 'Absences', 'Absences', 'DMT_ABSENCE_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler keys on the Slot A SourceSystemId (same mechanism as ' ||
           'Workers/Salaries), but not proven on a live run. Slot C NULL.' from dual
    union all select 'TalentProfiles', 'Talent Profiles', 'DMT_TALENT_PROF_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: reconciler keys on the Slot A SourceSystemId (same mechanism as ' ||
           'Workers/Salaries), but had 0 loaded in run 132 (KEY_TYPE NONE). Slot C NULL.' from dual
    union all select 'PerfEvaluations', 'Performance Docs', 'DMT_PERF_EVAL_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: Slot A SourceSystemId mechanism assumed, not proven live; Slot C not identified.' from dual
    union all select 'WorkSchedules', 'Work Schedules', 'DMT_WORK_SCHED_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: Slot A SourceSystemId mechanism assumed, not proven live; Slot C not identified.' from dual
    union all select 'W2Balances', 'W2 Balances', 'DMT_W2_BAL_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: Slot A SourceSystemId mechanism assumed, not proven live; Slot C not identified.' from dual
    -- ================= REST / config objects =================
    union all select 'UnitsOfMeasure', 'Units of Measure', 'DMT_INV_UOM_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE15', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_INV_UOM_RESULTS_PKG matches the base table on UOM_CODE (business ' ||
           'key); no carrier slot is keyed and the object was not in a proven live run.' from dual
    union all select 'ValueSets', 'Value Set Values', 'DMT_FND_VS_VALUE_TFM_TBL',
           'EXTERNAL_DATA_SOURCE', null,
           null, 'ATTRIBUTE50', 240, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_FND_VS_RESULTS_PKG matches on VALUE_SET_CODE (business key), not ' ||
           'EXTERNAL_DATA_SOURCE; the Slot A/C values are audit-only.' from dual
    union all select 'Lookups', 'Lookup Values', 'DMT_FND_LOOKUP_VALUE_TFM_TBL',
           'SEED_DATA_SOURCE', null,
           null, 'ATTRIBUTE15', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_FND_LOOKUP_RESULTS_PKG matches on LOOKUP_TYPE (business key), not ' ||
           'SEED_DATA_SOURCE; the Slot A/C values are audit-only.' from dual
    union all select 'PaymentTerms', 'Payment Term Headers', 'DMT_AP_PAY_TERM_HDR_TFM_TBL',
           'SEED_DATA_SOURCE', null,
           null, 'ATTRIBUTE15', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_AP_PAY_TERM_RESULTS_PKG matches on NAME (business key), not ' ||
           'SEED_DATA_SOURCE; the Slot A/C values are audit-only.' from dual
    union all select 'TaxConfig', 'Tax Regimes', 'DMT_ZX_REGIME_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE15', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_ZX_RESULTS_PKG matches on TAX_REGIME_CODE (business key); no carrier ' ||
           'slot is keyed and the object was not in a proven live run.' from dual
    union all select 'CashBanks', 'Banks', 'DMT_CE_BANK_TFM_TBL',
           'ORIG_SYSTEM_REFERENCE', null,
           'REQUEST_ID', 'ATTRIBUTE30', 150, 'FULL', 'UNVERIFIED', null, 'Y',
           'UNVERIFIED: DMT_CE_BANK_RESULTS_PKG matches on BANK_NAME (business key), not ' ||
           'ORIG_SYSTEM_REFERENCE; the Slot A/C values are audit-only.' from dual
) s
on (t."TFM_TABLE" = s.tfm_table)
when matched then update set
    t."CEMLI_CODE"         = s.cemli_code,
    t."SUB_OBJECT"         = s.sub_object,
    t."SLOT_A_FIELD"       = s.slot_a_field,
    t."SLOT_A_BASE_COLUMN" = s.slot_a_base_column,
    t."SLOT_B_FIELD"       = s.slot_b_field,
    t."SLOT_C_ATTRIBUTE"   = s.slot_c_attribute,
    t."SLOT_C_MAXLEN"      = s.slot_c_maxlen,
    t."REF_FORMAT"         = s.ref_format,
    t."CONFIDENCE"         = s.confidence,
    t."PROVEN_ON_RUN"      = s.proven_on_run,
    t."ACTIVE_FLAG"        = s.active_flag,
    t."NOTES"              = s.notes,
    t."LAST_UPDATED_DATE"  = sysdate
when not matched then insert
    ("CEMLI_CODE","SUB_OBJECT","TFM_TABLE","SLOT_A_FIELD","SLOT_A_BASE_COLUMN",
     "SLOT_B_FIELD","SLOT_C_ATTRIBUTE","SLOT_C_MAXLEN","REF_FORMAT","CONFIDENCE",
     "PROVEN_ON_RUN","ACTIVE_FLAG","NOTES","CREATED_DATE","LAST_UPDATED_DATE")
    values (s.cemli_code, s.sub_object, s.tfm_table, s.slot_a_field, s.slot_a_base_column,
            s.slot_b_field, s.slot_c_attribute, s.slot_c_maxlen, s.ref_format, s.confidence,
            s.proven_on_run, s.active_flag, s.notes, sysdate, sysdate);

commit;
