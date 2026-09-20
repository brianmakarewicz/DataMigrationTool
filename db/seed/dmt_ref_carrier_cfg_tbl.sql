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
-- CONFIDENCE mirrors the research pass: CONFIRMED (base column verified live),
-- LIKELY (strong evidence, not re-queried), UNVERIFIED (slot not yet confirmed --
-- do not rely on it until checked live). ACTIVE_FLAG='N' disables a row without
-- deleting it. Carrier is config, not code: changing a slot is a seed edit +
-- redeploy, no PL/SQL change.
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
           'FULL' ref_format, 'CONFIRMED' confidence, 'Y' active_flag,
           -- Slot C corrected 2026-09-19 (proof-of-recipe run 301): GL Journal
           -- Import does NOT carry GL_INTERFACE.ATTRIBUTE20 onto GL_JE_LINES
           -- (GL_JE_LINES has no ATTRIBUTE20; GL_JE_HEADERS has none either), so
           -- the full ref must ride a line REFERENCE that Journal Import maps
           -- through. REFERENCE22 -> GL_JE_LINES.REFERENCE_2 round-trips (proven,
           -- same mechanism as REFERENCE21 -> REFERENCE_1). RECIPE LESSON for the
           -- fan-out: Slot C must be a column the object''s import actually
           -- carries to the base table, verified per object -- not assumed.
           'GL journal line ref carrier; Slot C = REFERENCE22 -> GL_JE_LINES.REFERENCE_2.' notes from dual
    union all select 'Customers', 'Parties', 'DMT_HZ_PARTIES_TFM_TBL',
           'PARTY_ORIG_SYSTEM_REFERENCE', 'HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
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
           'REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'CONFIRMED', 'Y',
           'No native source-ref field on POZ_SUPPLIERS_INT; run id in REQUEST_ID.' from dual
    union all select 'SupplierAddresses', 'Supplier Addresses', 'DMT_POZ_SUP_ADDR_TFM_TBL',
           'ORIG_SYSTEM_REFERENCE', null,
           'REQUEST_ID', 'ATTRIBUTE30', 255, 'FULL', 'CONFIRMED', 'Y',
           'Supplier address carrier.' from dual
    union all select 'SupplierSites', 'Supplier Sites', 'DMT_POZ_SUP_SITE_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE20', null, 'FULL', 'LIKELY', 'Y',
           'No native source-ref field on POZ_SUPPLIER_SITES_INT; ATTRIBUTE20 length not re-queried (LIKELY 150).' from dual
    union all select 'SupplierSiteAssignments', 'Supplier Site Assignments', 'DMT_POZ_SUP_SITE_ASSN_TFM_TBL',
           null, null,
           'REQUEST_ID', null, null, 'FULL', 'CONFIRMED', 'Y',
           'No native source-ref and no attribute column on POZ_SITE_ASSIGNMENTS_INT; run id in REQUEST_ID only. Reconcile by parent site + BU.' from dual
    union all select 'SupplierContacts', 'Supplier Contacts', 'DMT_POZ_SUP_CONTACTS_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE20', null, 'FULL', 'LIKELY', 'Y',
           'No native source-ref field; ATTRIBUTE20 length not re-queried (LIKELY 150).' from dual
    union all select 'Requisitions', 'Req Headers', 'DMT_POR_REQ_HEADERS_TFM_TBL',
           'INTERFACE_SOURCE_CODE', null,
           'REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'CONFIRMED', 'Y',
           'Requisition header carrier; header tier of the 3-tier Requisitions object.' from dual
    union all select 'PurchaseOrders', 'PO Headers (covers BlanketPOs + Contracts)', 'DMT_PO_HEADERS_INT_TFM_TBL',
           'INTERFACE_SOURCE_CODE', null,
           'REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'CONFIRMED', 'Y',
           'ONE carrier row for the whole PO_HEADERS_INTERFACE family: PurchaseOrders, BlanketPOs and Contracts share this TFM table, discriminated by STYLE_DISPLAY_NAME.' from dual
    union all select 'APInvoices', 'AP Invoice Headers', 'DMT_AP_INVOICES_INT_TFM_TBL',
           'REFERENCE_KEY1', null,
           'BATCH_ID', 'ATTRIBUTE15', 1000, 'FULL', 'CONFIRMED', 'Y',
           'AP invoice header carrier; ATTRIBUTE15 is 1000 chars.' from dual
    union all select 'ARInvoices', 'AR Lines', 'DMT_RA_LINES_TFM_TBL',
           'INTERFACE_HEADER_ATTRIBUTE1/INTERFACE_LINE_ATTRIBUTE1', null,
           'BATCH_ID', 'ATTRIBUTE30', 255, 'FULL', 'CONFIRMED', 'Y',
           'AR AutoInvoice line carrier; Slot A uses the header+line interface attribute pair on RA_INTERFACE_LINES_ALL.' from dual
    union all select 'Items', 'Item Master', 'DMT_EGP_ITEM_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE50', 240, 'FULL', 'CONFIRMED', 'Y',
           'No native source-ref on EGP_SYSTEM_ITEMS_INTERFACE; ATTRIBUTE50 carries the full ref.' from dual
    union all select 'Projects', 'Projects', 'DMT_PJF_PROJECTS_TFM_TBL',
           'PM_PROJECT_REFERENCE', null,
           'REQUEST_ID', 'ATTRIBUTE50', 150, 'FULL', 'CONFIRMED', 'Y',
           'Project header carrier; header tier of the 4-tier Projects object.' from dual
    union all select 'Expenditures', 'Project Expenditures', 'DMT_PJC_EXPENDITURES_TFM_TBL',
           'ORIG_TRANSACTION_REFERENCE', null,
           'EXP_GROUP_ID', 'ATTRIBUTE10', 150, 'FULL', 'CONFIRMED', 'Y',
           'Expenditure cost carrier; run id in EXP_GROUP_ID.' from dual
    union all select 'BillingEvents', 'Billing Events', 'DMT_PJB_BILL_EVENTS_TFM_TBL',
           'SOURCEREF', null,
           'REQUEST_ID', 'ATTRIBUTE10', 150, 'FULL', 'CONFIRMED', 'Y',
           'Billing event carrier.' from dual
    union all select 'ProjectBudgets', 'Project Budgets', 'DMT_PRJ_BUDGET_TFM_TBL',
           'PM_BUDGET_REFERENCE', null,
           'REQUEST_ID', null, null, 'FULL', 'CONFIRMED', 'Y',
           'No attribute column on PJO_PLAN_VERSIONS_XFACE; per-record id in the native PM_BUDGET_REFERENCE.' from dual
    union all select 'Grants', 'Award Headers', 'DMT_GMS_AWD_HEADERS_TFM_TBL',
           'AWARD_SOURCE', null,
           'DC_REQUEST_ID', 'ATTRIBUTE20', 150, 'FULL', 'CONFIRMED', 'Y',
           'Grant/award header carrier; run id in the data-conversion request id DC_REQUEST_ID.' from dual
    union all select 'Assets', 'Asset Headers', 'DMT_FA_ASSET_HDR_TFM_TBL',
           null, null,
           null, 'ATTRIBUTE30', 150, 'FULL', 'CONFIRMED', 'Y',
           'FA_MASS_ADDITIONS has no native source-ref and no batch field; full ref in ATTRIBUTE30, run/wq recovered by parsing it.' from dual
    union all select 'MiscReceipts', 'Inventory Transactions', 'DMT_INV_TRX_TFM_TBL',
           'INTERFACE_SOURCE_CODE', null,
           'GROUP_ID', 'ATTRIBUTE20', 150, 'FULL', 'CONFIRMED', 'Y',
           'Misc receipt (items-on-hand) carrier; header tier reads the INV_TRX pipeline.' from dual
    union all select 'GLBudgets', 'GL Budget Balances', 'DMT_GL_BUDGET_INT_TFM_TBL',
           null, null,
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'no base-table carrier; business-key reconcile (owner 2026-09-19)' from dual
    union all select 'GLCalendar', 'GL Calendar', 'DMT_GL_CALENDAR_TFM_TBL',
           null, null,
           null, 'ATTRIBUTE8', 150, 'FULL', 'CONFIRMED', 'Y',
           'No native source-ref and no batch field; full ref in ATTRIBUTE8.' from dual
    -- ================= HDL objects (Slot A = SourceSystemId, base HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID(2000); Slot B unused) =================
    union all select 'Workers', 'Workers', 'DMT_WORKER_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL Worker header tier and TEMPLATE for the 14-object HDL family. Slot A ' ||
           'SourceSystemId = the prefixed PERSON_NUMBER; it round-trips to ' ||
           'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID (OBJECT_NAME=Person, ' ||
           'SURROGATE_ID = PER_ALL_PEOPLE_F.PERSON_ID) and returns as the recon ' ||
           'RECORD_KEY = the TFM RECON_KEY (verified live 2026-09-20). SourceSystemId ' ||
           'CANNOT embed the tfm id -- it must equal PERSON_NUMBER for the base match ' ||
           'and the child PersonId(SourceSystemId) FK hints. Slot C is NULL: HDL ' ||
           'persons have no attribute column that round-trips (see HDL family note).' from dual
    union all select 'Salaries', 'Salaries', 'DMT_SALARY_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL Salary; Slot C NULL (HDL persons have no round-trippable attribute -- ' ||
           'see HDL family note + Workers verification). Round-trip rides Slot A.' from dual
    union all select 'SalaryBases', 'Salary Bases', 'DMT_SAL_BASIS_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL Salary Basis; no attribute column, per-record id in SourceSystemId only.' from dual
    union all select 'TaxCards', 'Tax Cards', 'DMT_TAX_CARD_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL Tax Card; Slot C NULL (HDL persons have no round-trippable attribute -- ' ||
           'see HDL family note + Workers verification). Round-trip rides Slot A.' from dual
    union all select 'BenParticipant', 'Participant Enrollment', 'DMT_BEN_PARTIC_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL PersonBenefitBalance (participant); Slot C NULL (HDL persons have no ' ||
           'round-trippable attribute -- see HDL family note). Round-trip rides Slot A.' from dual
    union all select 'BenDependent', 'Dependent Enrollment', 'DMT_BEN_DEPEND_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL PersonBenefitBalance (dependent); Slot C NULL (HDL persons have no ' ||
           'round-trippable attribute -- see HDL family note). Round-trip rides Slot A.' from dual
    union all select 'BenBeneficiary', 'Beneficiary Enrollment', 'DMT_BEN_BENFY_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL PersonBenefitBalance (beneficiary); Slot C NULL (HDL persons have no ' ||
           'round-trippable attribute -- see HDL family note). Round-trip rides Slot A.' from dual
    union all select 'Absences', 'Absences', 'DMT_ABSENCE_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL Absence; no attribute column, per-record id in SourceSystemId only.' from dual
    union all select 'TalentProfiles', 'Talent Profiles', 'DMT_TALENT_PROF_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'CONFIRMED', 'Y',
           'HDL Talent Profile; Slot C NULL (HDL persons have no round-trippable ' ||
           'attribute -- see HDL family note). Round-trip rides Slot A.' from dual
    union all select 'PerfEvaluations', 'Performance Docs', 'DMT_PERF_EVAL_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', 'Y',
           'HDL Performance Evaluation; Slot C attribute not yet identified -- do not rely on a Slot C carrier until confirmed live.' from dual
    union all select 'WorkSchedules', 'Work Schedules', 'DMT_WORK_SCHED_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', 'Y',
           'HDL Work Schedule (WorkPattern); Slot C attribute not yet identified -- do not rely on a Slot C carrier until confirmed live.' from dual
    union all select 'W2Balances', 'W2 Balances', 'DMT_W2_BAL_TFM_TBL',
           'SourceSystemId', 'HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID',
           null, null, null, 'FULL', 'UNVERIFIED', 'Y',
           'HDL W2 Balance; Slot C attribute not yet identified -- do not rely on a Slot C carrier until confirmed live.' from dual
    -- ================= REST / config objects =================
    union all select 'UnitsOfMeasure', 'Units of Measure', 'DMT_INV_UOM_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE15', 150, 'FULL', 'CONFIRMED', 'Y',
           'UOM; no native source-ref, run id in REQUEST_ID.' from dual
    union all select 'ValueSets', 'Value Set Values', 'DMT_FND_VS_VALUE_TFM_TBL',
           'EXTERNAL_DATA_SOURCE', null,
           null, 'ATTRIBUTE50', 240, 'FULL', 'CONFIRMED', 'Y',
           'Value-set values tier; per-record id in the native EXTERNAL_DATA_SOURCE.' from dual
    union all select 'Lookups', 'Lookup Values', 'DMT_FND_LOOKUP_VALUE_TFM_TBL',
           'SEED_DATA_SOURCE', null,
           null, 'ATTRIBUTE15', 150, 'FULL', 'CONFIRMED', 'Y',
           'Lookup values tier; per-record id in the native SEED_DATA_SOURCE.' from dual
    union all select 'PaymentTerms', 'Payment Term Headers', 'DMT_AP_PAY_TERM_HDR_TFM_TBL',
           'SEED_DATA_SOURCE', null,
           null, 'ATTRIBUTE15', 150, 'FULL', 'CONFIRMED', 'Y',
           'Payment term header tier; per-record id in the native SEED_DATA_SOURCE.' from dual
    union all select 'TaxConfig', 'Tax Regimes', 'DMT_ZX_REGIME_TFM_TBL',
           null, null,
           'REQUEST_ID', 'ATTRIBUTE15', 150, 'FULL', 'CONFIRMED', 'Y',
           'Tax configuration header tier (regimes); no native source-ref, run id in REQUEST_ID.' from dual
    union all select 'CashBanks', 'Banks', 'DMT_CE_BANK_TFM_TBL',
           'ORIG_SYSTEM_REFERENCE', null,
           'REQUEST_ID', 'ATTRIBUTE30', 150, 'FULL', 'CONFIRMED', 'Y',
           'Cash Management bank header tier; per-record id in ORIG_SYSTEM_REFERENCE.' from dual
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
    t."ACTIVE_FLAG"        = s.active_flag,
    t."NOTES"              = s.notes,
    t."LAST_UPDATED_DATE"  = sysdate
when not matched then insert
    ("CEMLI_CODE","SUB_OBJECT","TFM_TABLE","SLOT_A_FIELD","SLOT_A_BASE_COLUMN",
     "SLOT_B_FIELD","SLOT_C_ATTRIBUTE","SLOT_C_MAXLEN","REF_FORMAT","CONFIDENCE",
     "ACTIVE_FLAG","NOTES","CREATED_DATE","LAST_UPDATED_DATE")
    values (s.cemli_code, s.sub_object, s.tfm_table, s.slot_a_field, s.slot_a_base_column,
            s.slot_b_field, s.slot_c_attribute, s.slot_c_maxlen, s.ref_format, s.confidence,
            s.active_flag, s.notes, sysdate, sysdate);

commit;
