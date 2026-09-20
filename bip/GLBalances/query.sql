-- ============================================================
-- GLBalances BIP reconciliation query — BIP reconciliation
-- report contract v1 (nine columns, keyset pagination).
-- Data source: ApplicationDB_FSCM. This mirrors the SQL embedded
-- in DMT_GL_BAL_RECON_DM.xdm for review; the .xdm is authoritative.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY (names must match what
--   DMT_GL_RESULTS_PKG sends). No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- Row selection: BASE rows join the run's own journal batch by
--   GL_JE_BATCHES.GROUP_ID = :P_RUN_ID (run id written as GROUP_ID
--   at transform, survives Journal Import). INTERFACE rows are the
--   GL_INTERFACE rejections the load ESS job left carrying
--   :P_LOAD_REQUEST_ID.
--
-- FUSION_STATUS normalized SUCCESS/ERROR in the DM:
--   BASE balanced => SUCCESS; BASE unbalanced / INTERFACE => ERROR.
--
-- Keys (need source "Import Journal References" = ON):
--   RECORD_KEY / SOURCE_REF = GL_JE_LINES.REFERENCE_1 (= TFM RECON_KEY)
--   DMT_REFERENCE           = GL_JE_LINES.REFERENCE_2 (Slot C ref)
--   FUSION_ID               = GL_JE_HEADERS.JE_HEADER_ID
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT
        'GLBalances'                         AS object_type,
        jl.reference_1                       AS record_key,
        'BASE'                               AS source_type,
        CASE WHEN jh.running_total_dr = jh.running_total_cr
             THEN 'SUCCESS' ELSE 'ERROR' END AS fusion_status,
        jh.je_header_id                      AS fusion_id,
        CASE WHEN jh.running_total_dr <> jh.running_total_cr
             THEN '[LINE] Journal imported (JE_HEADER_ID=' || jh.je_header_id
                  || ') but UNBALANCED: DR=' || jh.running_total_dr
                  || ' CR=' || jh.running_total_cr || '. Will not post.'
        END                                  AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        jl.reference_1                       AS source_ref,
        jl.reference_2                       AS dmt_reference
    FROM   gl_je_batches jb
    JOIN   gl_je_headers jh ON jh.je_batch_id = jb.je_batch_id
    JOIN   gl_je_lines   jl ON jl.je_header_id = jh.je_header_id
    WHERE  jb.group_id = :P_RUN_ID

    UNION ALL

    SELECT
        'GLBalances'                         AS object_type,
        gi.reference21                       AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        '[LINE] ' || NVL(gi.reference10,
             'Rejected by Journal Import (row not created in base tables).')
                                             AS error_message,
        gi.load_request_id                   AS load_request_id,
        gi.reference21                       AS source_ref,
        gi.reference22                       AS dmt_reference
    FROM   gl_interface gi
    WHERE  gi.load_request_id = :P_LOAD_REQUEST_ID
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
