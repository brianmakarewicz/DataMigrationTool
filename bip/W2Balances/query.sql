-- DMT_W2_BAL_RECON_DM query (BIP reconciliation report contract v1).
-- Mirror of the CDATA SQL in DMT_W2_BAL_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six Contract v1
-- parameters).
--
-- W2Balances (payroll balance initialization) loads through HCM Data Loader as
-- the "Balance Initialization" business object: two HDL objects in one zip,
-- InitializeBalanceBatchHeader (parent) and InitializeBalanceBatchLine (child,
-- referenced by BatchName). DMT_W2_BAL_HDL_GEN_PKG emits ONE batch per run with
-- BatchName = <run prefix> || '_W2BAL'. An HDL load has no interface table, so
-- this report returns the BASE tier only: one row per migrated batch positively
-- confirmed in PAY_BAL_BATCH_HEADERS, with the Fusion-assigned BATCH_ID as
-- FUSION_ID. Per-record HDL failures are captured separately (RECONCILE_HDL tags
-- [FUSION_ERROR] from the HDL response before this report runs), so this report
-- returns BASE / SUCCESS rows only.
--
-- KEY GRANULARITY = THE BATCH, NOT THE PERSON. RECORD_KEY / SOURCE_REF =
-- PAY_BAL_BATCH_HEADERS.BATCH_NAME = the run's BatchName (<prefix>_W2BAL) = the
-- W2Balances TFM row's RECON_KEY. The balance-init batch is loaded and confirmed
-- as a single unit, so its reconciliation key is coarser than the per-person HDL
-- objects (Salaries, BenBeneficiary).
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE('BASE'), FUSION_STATUS('SUCCESS'),
--   FUSION_ID (= BATCH_ID), ERROR_MESSAGE (NULL), LOAD_REQUEST_ID (NULL),
--   SOURCE_REF (= BATCH_NAME), DMT_REFERENCE (NULL).
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX,
--   P_CHUNK_SIZE, P_AFTER_KEY.  Keyset pagination by RECORD_KEY (P_AFTER_KEY).
--
-- WHY THE BASE TABLE, NOT HRC_INTEGRATION_KEY_MAP - HONEST NOTE
-- (verified live 2026-09-20, fin_impl / ApplicationDB_FSCM):
--   * The standard HDL recipe drives off HRC_INTEGRATION_KEY_MAP scoped by our
--     prefixed SourceSystemId (SOURCE_SYSTEM_OWNER='HRC_SQLLOADER'). That does
--     NOT apply here. On this pod the balance-init map rows are owned by FUSION,
--     not HRC_SQLLOADER, and their SOURCE_SYSTEM_ID is Fusion's internal
--     surrogate (identical to SURROGATE_ID, e.g. 300000331552768), not our
--     controllable BatchName:
--       SELECT object_name, source_system_owner, COUNT(*)
--       FROM   hrc_integration_key_map
--       WHERE  object_name LIKE 'InitializeBalanceBatch%'
--       GROUP  BY object_name, source_system_owner;
--         -> InitializeBalanceBatchHeader / FUSION / 7
--            InitializeBalanceBatchLine   / FUSION / 13
--     So the map cannot be scoped by our run prefix. Our only prefix-scoped,
--     controllable business key lives in PAY_BAL_BATCH_HEADERS.BATCH_NAME.
--   * Round-trip proven: HRC_INTEGRATION_KEY_MAP.SURROGATE_ID for
--     InitializeBalanceBatchHeader 300000331552768 == PAY_BAL_BATCH_HEADERS
--     .BATCH_ID 300000331552768, BATCH_NAME 'DMTW232147'. The key-map surrogate
--     and the base PK are the same number; the base table also carries the
--     business key the map lacks.
--
-- LIVE STATE ON THIS POD (verified 2026-09-20):
--   * PAY_BAL_BATCH_HEADERS holds seven DMT balance batches (DMTPROBE1,
--     DMTW210163, DMTW225314, DMTW232147, DMTW241088, DMTW260133, DMTW265405),
--     older-format names predating the current '_W2BAL' suffix. Their BATCH_ID
--     values are real Fusion base ids.
--   * No batch carries the current-generator BatchName shape (<prefix>_W2BAL)
--     yet, so a run today returns zero rows for its prefix until a real DMT
--     balance batch lands. Zero rows is never LOADED. The standalone validation
--     in the PR body pages the existing 'DMT%' batches to prove the nine-column
--     shape, the real BATCH_ID round-trip, and keyset paging (page then empty).

SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'W2Balances'                   AS object_type,
           h.batch_name                   AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(h.batch_id)                AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           h.batch_name                   AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   pay_bal_batch_headers h
    WHERE  h.batch_name LIKE :P_PREFIX || '%'
    GROUP BY h.batch_name
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
