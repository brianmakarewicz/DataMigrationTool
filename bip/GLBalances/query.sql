-- ============================================================
-- GLBalances BIP Reconciliation Query — BIP Reconciliation
-- Standard, reference implementation (P1).
-- Data source: ApplicationDB_FSCM
--
-- Returns the SIX standard columns for every row:
--   RECORD_KEY, FUSION_ID, SOURCE_REF, DMT_REFERENCE,
--   SOURCE_TYPE (BASE|INTERFACE), ERROR_MESSAGE
-- and pages with OFFSET/FETCH NEXT (:P_OFFSET / :P_LIMIT).
--
-- Parameters (names must match what DMT_GL_RESULTS_PKG sends):
--   :P_LOAD_REQUEST_ID = Load ESS request id (LOAD_REQUEST_ID in GL_INTERFACE)
--   :P_IMPORT_ESS_ID   = Import ESS request id (declared; unused here)
--   :P_RUN_ID          = pipeline run id (= GL_JE_BATCHES.GROUP_ID, set in transform)
--   :P_PREFIX          = run prefix (declared for contract symmetry; unused here)
--   :P_OFFSET          = pagination offset (rows to skip)
--   :P_LIMIT           = pagination page size (rows to fetch)
--
-- Row selection: BASE rows join to the run's own journal batch by
--   GL_JE_BATCHES.GROUP_ID = :P_RUN_ID (the run id is written as
--   GROUP_ID at transform and survives Journal Import — proven live
--   against runs 304/305). INTERFACE rows are selected by the load
--   ESS request id the interface table carries. GL needs no
--   prefix/LIKE fallback because GROUP_ID carries the run id exactly.
--
-- GL two-tier semantics WITHOUT an IMPORT_STATUS column:
--   BASE + ERROR_MESSAGE IS NULL  => balanced/postable => LOADED
--   BASE + ERROR_MESSAGE NOT NULL => unbalanced, will not post => FAILED
--
-- Keys (proven 2026-07-11; needs source "Import Journal References" = ON):
--   RECORD_KEY / SOURCE_REF = GL_JE_LINES.REFERENCE_1 (= TFM RECON_KEY)
--   DMT_REFERENCE           = GL_JE_LINES.REFERENCE_2 (run-scoped ref)
--   FUSION_ID               = GL_JE_HEADERS.JE_HEADER_ID
-- ============================================================
SELECT * FROM (
    SELECT
        gi.reference21                       AS record_key,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        gi.reference21                       AS source_ref,
        gi.reference22                       AS dmt_reference,
        'INTERFACE'                          AS source_type,
        gi.reference10                       AS error_message
    FROM   gl_interface gi
    WHERE  gi.load_request_id = :P_LOAD_REQUEST_ID

    UNION ALL

    SELECT
        jl.reference_1                       AS record_key,
        jh.je_header_id                      AS fusion_id,
        jl.reference_1                       AS source_ref,
        jl.reference_2                       AS dmt_reference,
        'BASE'                               AS source_type,
        CASE WHEN jh.running_total_dr <> jh.running_total_cr
             THEN 'Journal imported (JE_HEADER_ID=' || jh.je_header_id
                  || ') but UNBALANCED: DR=' || jh.running_total_dr
                  || ' CR=' || jh.running_total_cr || '. Will not post.'
        END                                  AS error_message
    FROM   gl_je_batches jb
    JOIN   gl_je_headers jh ON jh.je_batch_id = jb.je_batch_id
    JOIN   gl_je_lines   jl ON jl.je_header_id = jh.je_header_id
    WHERE  jb.group_id = :P_RUN_ID

    ORDER BY source_type, record_key
)
OFFSET :P_OFFSET ROWS FETCH NEXT :P_LIMIT ROWS ONLY
