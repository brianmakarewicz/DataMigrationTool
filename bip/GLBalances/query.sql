-- ============================================================
-- GLBalances BIP Reconciliation Query (Two-Tier, per-line key)
-- Data source: ApplicationDB_FSCM
-- Parameters (Contract v1 — names must match what DMT_GL_RESULTS_PKG sends):
--             :P_LOAD_REQUEST_ID = Load ESS request ID (LOAD_REQUEST_ID in GL_INTERFACE)
--             :P_RUN_ID          = pipeline run id (= GL_JE_BATCHES.GROUP_ID, set in transform)
--             :P_IMPORT_ESS_ID   = Import ESS request ID (declared for Contract v1; unused here)
--             :P_PREFIX          = run prefix (declared for Contract v1; unused here)
--
-- RECORD_KEY: the per-line reconciliation key (RECON_KEY = prefix-stg_sequence_id),
--   written by the generator to GL_INTERFACE.REFERENCE21, which Journal Import
--   carries onto GL_JE_LINES.REFERENCE_1 (proven empirically 2026-07-11; requires
--   the journal source's "Import Journal References" flag, confirmed ON). Matching
--   is per LINE on this key, so two source journals that share a name never
--   collide (the reason batch-name keying was retired here).
--
-- Tier 1 (INTERFACE): rows still in GL_INTERFACE after import are errors/rejections
--   (import DELETEs successfully-imported rows). REFERENCE10 is the import error
--   message; REFERENCE21 carries our per-line key.
--
-- Tier 2 (BASE): journal lines created in GL_JE_LINES. One row per line, keyed on
--   REFERENCE_1. Balance (DR=CR) at the header discriminates postable vs not; every
--   line of an unbalanced journal fails (the whole journal will not post).
-- ============================================================
SELECT
    gi.reference21                       AS record_key,
    gi.status                            AS import_status,
    'INTERFACE'                          AS source_type,
    CAST(NULL AS NUMBER)                 AS fusion_id,
    gi.reference10                       AS error_message
FROM   gl_interface gi
WHERE  gi.load_request_id = :P_LOAD_REQUEST_ID

UNION ALL

SELECT
    jl.reference_1                       AS record_key,
    CASE WHEN jh.running_total_dr = jh.running_total_cr
         THEN 'SUCCESS' ELSE 'UNBALANCED' END  AS import_status,
    'BASE'                               AS source_type,
    jh.je_header_id                      AS fusion_id,
    CASE WHEN jh.running_total_dr <> jh.running_total_cr
         THEN 'Journal imported (JE_HEADER_ID=' || jh.je_header_id
              || ') but UNBALANCED: DR=' || jh.running_total_dr
              || ' CR=' || jh.running_total_cr || '. Will not post.'
    END                                  AS error_message
FROM   gl_je_batches jb
JOIN   gl_je_headers jh ON jh.je_batch_id = jb.je_batch_id
JOIN   gl_je_lines   jl ON jl.je_header_id = jh.je_header_id
WHERE  jb.group_id = :P_RUN_ID
