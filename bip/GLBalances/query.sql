-- ============================================================
-- GLBalances BIP Reconciliation Query (Two-Tier)
-- Data source: ApplicationDB_FSCM
-- Parameters: :P_BATCH_ID = Load ESS request ID (LOAD_REQUEST_ID in GL_INTERFACE)
--             :P_IMPORT_ESS_ID = Import ESS request ID (for base table lookup)
--
-- Tier 1 (INTERFACE): Rows still in GL_INTERFACE after import.
--   GL journal import DELETES successfully imported rows from GL_INTERFACE.
--   Rows remaining here are errors/rejections.
--   No separate GL error table exists; reference10 is the error message column
--   populated by the import process.
--
-- Tier 2 (BASE): Journal entries created in GL_JE_HEADERS/GL_JE_LINES.
--   Linked via GL_JE_HEADERS.REQUEST_ID = Import ESS job ID.
--   REFERENCE_1 in GL_JE_LINES maps back to REFERENCE1 in our TFM table.
--
-- AD#19 compliance:
--   reference10 IS the real error message — no CAST(NULL) placeholder.
--   No rejection table exists (verified: no GL%ERR% tables in ALL_TABLES).
--   Remaining interface rows after import = FAILED by definition.
-- ============================================================
SELECT
    gi.reference1,
    gi.status                            AS import_status,
    'INTERFACE'                          AS source_type,
    CAST(NULL AS NUMBER)                 AS fusion_id,
    gi.reference10                       AS error_message
FROM   gl_interface gi
WHERE  gi.load_request_id = :P_BATCH_ID

UNION ALL

-- Tier 2 (BASE): positively confirm journals in GL_JE base tables.
-- Keyed on GROUP_ID = run_id (set in transform) — NOT request_id, which is not
-- exposed on ApplicationDB_FSCM. Balance (DR=CR) discriminates postable vs not.
-- gl_je_lines.reference_1 is NULL, so REFERENCE1 is recovered from the batch name.
SELECT
    CASE WHEN INSTR(jb.name, ' Spreadsheet ') > 0
         THEN SUBSTR(jb.name, 1, INSTR(jb.name, ' Spreadsheet ') - 1)
         ELSE jb.name END                AS reference1,
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
WHERE  jb.group_id = :P_GROUP_ID
   OR  (:P_IMPORT_ESS_ID IS NOT NULL AND jb.name LIKE '%' || :P_IMPORT_ESS_ID || '%')
