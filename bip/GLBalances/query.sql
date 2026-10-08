-- ============================================================
-- GLBalances BIP reconciliation query: mirror of the SQL embedded in
-- DMT_GL_BAL_RECON_V3_DM.xdm (the deployed data model the registry points
-- at; the .xdm is authoritative). Data source: ApplicationDB_FSCM.
-- ============================================================
-- ============================================================
-- GLBalances reconciliation data model V3 (backlog #173), Contract v1:
-- nine columns, keyset pagination, the six standard parameters.
-- Deployed ALONGSIDE DMT_GL_BAL_RECON_DM (V1), never overwriting it.
-- (A V2 data model was deployed to Fusion during research and never
-- registered; V3 supersedes it.)
--
-- How DMT loads GL now: every journal carries its own GROUP_ID and the
-- Import Journals job runs once per load with GroupID = ALL. Journal
-- Import rejects all-or-nothing per group, so a rejected line takes down
-- only its own journal (proven 2026-10-07, probe load 10075714).
--
-- ERROR_MESSAGE carries only Journal Import's own error for the row:
--   GL_INTERFACE.STATUS (the error code or codes, e.g. EF04 or
--   EF04,EC03), followed by ': ' and GL_INTERFACE.STATUS_DESCRIPTION
--   (Fusion's message text) when Fusion wrote one; the code alone when it
--   did not. Nothing is composed around it.
-- An unbalanced base journal has no Fusion error behind it (Journal Import
--   accepts it), so it is returned BASE / ERROR with a NULL message: neither
--   LOADED nor FAILED, it falls to UNACCOUNTED.
-- Lines of a rejected journal that have no error of their own (status P)
--   are not returned; the reconciler quotes the rejected line's error onto
--   them (PROPAGATE_DOCUMENT_ERRORS, the journal = one GROUP_ID).
--
-- Rows are selected by Fusion job id, never by run id or prefix:
--   BASE      batches created by the Journal Import child of OUR Import
--             Journals job (:P_IMPORT_ESS_ID). GL_JE_BATCHES.REQUEST_ID is
--             always NULL on this pod; Journal Import writes its own request
--             id into the batch name ("<name> <source> A <group> <request> N"),
--             which is the only job link the base tables carry. Scoped to the
--             job's ledger argument (submit.argument3) and to batches created
--             after the job started.
--   INTERFACE rows our load job (:P_LOAD_REQUEST_ID) put in GL_INTERFACE that
--             Journal Import rejected (status code starting with E).
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY (P_RUN_ID and P_PREFIX are
--   declared for the contract and not used to select rows).
--
-- Keys (need source "Import Journal References" = ON):
--   RECORD_KEY / SOURCE_REF = GL_JE_LINES.REFERENCE_1 (base) or
--       GL_INTERFACE.REFERENCE21 (interface) = TFM RECON_KEY,
--   DMT_REFERENCE           = REFERENCE_2 / REFERENCE22 (Slot C ref),
--   FUSION_ID               = JE_HEADER_ID~JE_LINE_NUM (line grain).
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Tier: BASE. One row per GL_JE_LINES line of the batches our Journal
    -- Import job created.
    SELECT
        'GLBalances'                         AS object_type,
        jl.reference_1                       AS record_key,
        'BASE'                               AS source_type,
        CASE WHEN jh.running_total_dr = jh.running_total_cr
             THEN 'SUCCESS' ELSE 'ERROR' END AS fusion_status,
        jh.je_header_id || '~' || jl.je_line_num AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        jl.reference_1                       AS source_ref,
        jl.reference_2                       AS dmt_reference
    FROM   gl_je_batches jb
    JOIN   gl_je_headers jh ON jh.je_batch_id = jb.je_batch_id
    JOIN   gl_je_lines   jl ON jl.je_header_id = jh.je_header_id
    WHERE  jb.creation_date >= (SELECT h.processstart
                                FROM   fusion_ora_ess.request_history h
                                WHERE  h.requestid = TO_NUMBER(:P_IMPORT_ESS_ID))
    AND    EXISTS (SELECT 1
                   FROM   fusion_ora_ess.request_history c
                   WHERE  c.parentrequestid = TO_NUMBER(:P_IMPORT_ESS_ID)
                   AND    jb.name LIKE '% ' || TO_CHAR(c.requestid) || ' %')
    AND    jh.ledger_id = (SELECT TO_NUMBER(rp.value)
                           FROM   fusion_ora_ess.request_property rp
                           WHERE  rp.requestid = TO_NUMBER(:P_IMPORT_ESS_ID)
                           AND    rp.name = 'submit.argument3')

    UNION ALL

    -- Tier: INTERFACE. Lines Journal Import rejected, still in GL_INTERFACE
    -- with their error code(s) in STATUS and, when Fusion wrote it, the
    -- message text in STATUS_DESCRIPTION.
    SELECT
        'GLBalances'                         AS object_type,
        gi.reference21                       AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS VARCHAR2(100))          AS fusion_id,
        gi.status || NVL2(gi.status_description, ': ' || gi.status_description, NULL)
                                             AS error_message,
        gi.load_request_id                   AS load_request_id,
        gi.reference21                       AS source_ref,
        gi.reference22                       AS dmt_reference
    FROM   gl_interface gi
    WHERE  gi.load_request_id = :P_LOAD_REQUEST_ID
    AND    gi.status LIKE 'E%'
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start": return every row. On later
-- pages P_AFTER_KEY carries the previous page's last RECORD_KEY and only
-- greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
