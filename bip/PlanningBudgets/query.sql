-- ============================================================
-- PlanningBudgets reconciliation data model — BIP reconciliation
-- report contract v1 (nine columns, keyset pagination, the six
-- standard parameters). Conformed to the GLBalances exemplar.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
--
-- SIX parameters (Contract v1): P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY.
--   No P_BATCH_ID / P_OFFSET / P_LIMIT.
--
-- KEYSET pagination: rows are ordered by RECORD_KEY and only rows
-- whose RECORD_KEY sorts AFTER :P_AFTER_KEY are returned, at most
-- :P_CHUNK_SIZE of them. An empty :P_AFTER_KEY (bound NULL) selects
-- from the start.
--
-- HONEST STATUS — this object is DORMANT (see objects/PlanningBudgets
-- /README.md). Planning budgets load into Oracle EPBCS through the
-- "EPBCS Data Import" job, which processes data through INTERNAL
-- planning tables that are NOT exposed to BIP SQL on
-- ApplicationDB_FSCM. Verified 2026-03-31 (re-confirmed 2026-09-20):
--   - FIN_PLAN_LINES_INTERFACE  : does not exist
--   - EPBCS_DATA_IMPORT_INT     : does not exist
--   - no table matching %PLAN%INT%, EPBCS%, or %BUDGET%INT% found
--   - no BIP-accessible base table carrying a budget-version id
-- There is therefore NO base tier to read a real FUSION_ID from and
-- NO interface tier to read rejections from. Contract v1 requires
-- FUSION_ID non-null on every BASE/SUCCESS row; because no such
-- table is reachable, this report honestly returns ZERO rows rather
-- than fabricate a FUSION_STATUS or FUSION_ID.
--
-- Zero rows is NOT a success signal for the reconciler (design
-- section 5: "Zero report rows is never success"). The reconciler
-- must leave this object's rows unaccounted until an EPBCS-accessible
-- base/interface table becomes available on the instance, at which
-- point the BASE tier below is filled in following the GLBalances
-- pattern:
--   RECORD_KEY / SOURCE_REF = the composite business key
--        SCENARIO~VERSION~ENTITY~ACCOUNT~PERIOD (= TFM RECON_KEY),
--   DMT_REFERENCE           = the run-scoped DMT:run:queue:tfm ref,
--   FUSION_ID               = the Fusion budget version id
--        (TFM column FUSION_BUDGET_VERSION_ID).
-- The parameter block, column list, ordering and keyset predicate
-- are already contract-shaped so only the FROM/WHERE need wiring.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Tier: BASE — one row per imported planning-budget line, keyed on
    -- the composite business key, once an EPBCS-accessible base table
    -- exposing the budget version id is available on the instance.
    -- Until then this selects nothing (WHERE 1 = 0), so the report is
    -- honestly empty rather than fabricated. Column shapes are fixed
    -- for XMLTABLE parity with the other Contract v1 reports.
    SELECT
        'PlanningBudgets'            AS object_type,
        CAST(NULL AS VARCHAR2(1000)) AS record_key,
        'BASE'                       AS source_type,
        CAST(NULL AS VARCHAR2(50))   AS fusion_status,
        CAST(NULL AS NUMBER)         AS fusion_id,
        CAST(NULL AS VARCHAR2(4000)) AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID) AS load_request_id,
        CAST(NULL AS VARCHAR2(1000)) AS source_ref,
        CAST(NULL AS VARCHAR2(1000)) AS dmt_reference
    FROM   DUAL
    WHERE  1 = 0
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". RECORD_KEY is compared as
-- text (the recon key is a string).
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
