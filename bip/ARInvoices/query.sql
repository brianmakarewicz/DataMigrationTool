-- ============================================================
-- ARInvoices BIP reconciliation query -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination, the six standard
-- parameters). Same shape as DMT_GL_BAL_RECON_DM.xdm and
-- DMT_REQ_RECON_DM.xdm. This file MIRRORS the CDATA body of the
-- deployed data model bip/ARInvoices/DMT_AR_RECON_DM.xdm (deploy
-- target /Custom/DMT2/ARInvoices/); the .xdm is authoritative --
-- regenerate this file whenever the data model changes so the
-- mirror never drifts.
--
-- Data source: ApplicationDB_FSCM
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
--
-- SIX parameters (Contract v1): P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY.
--   No P_OFFSET / P_LIMIT.
--
-- KEYSET pagination: rows are ordered by RECORD_KEY and only rows
-- whose RECORD_KEY sorts AFTER :P_AFTER_KEY are returned, at most
-- :P_CHUNK_SIZE of them. The reconciler's shared fetch loop calls
-- with an empty cursor first, then passes the last RECORD_KEY it
-- received on each next call, until a page returns fewer than
-- P_CHUNK_SIZE rows. An empty :P_AFTER_KEY selects from the start.
--
-- MULTI-TIER object. ARInvoices (AutoInvoice) is one FBDI zip
-- carrying two record types -- lines and distributions -- each with
-- its own interface table, its own base table, and (via the stamped
-- recon key) its own read-back key. OBJECT_TYPE discriminates the
-- tier and the four SELECT blocks are UNION ALL-ed, then ordered by
-- RECORD_KEY.
--
-- STAMPED RECON KEY (= TFM RECON key, read back from Fusion):
--   The transform writes INTERFACE_LINE_ATTRIBUTE1 = the prefixed
--   TRX_NUMBER (DMT_AR_TRANSFORM_PKG:
--     INTERFACE_LINE_ATTRIBUTE1 := PREFIXED(prefix, TRX_NUMBER))
--   and INTERFACE_LINE_ATTRIBUTE2 = the STG_SEQUENCE_ID.
--   AutoInvoice PERSISTS both attribute columns onto the base line
--   RA_CUSTOMER_TRX_LINES_ALL, so the base line is keyed on the
--   recon key directly (INTERFACE_LINE_ATTRIBUTE1). AR uses
--   automatic transaction numbering, so the base TRX_NUMBER is
--   Fusion-assigned and does NOT carry the DMT prefix -- the recon
--   key, not the number, is the read-back key. The base distribution
--   carries no interface key, so it is confirmed transitively
--   through its loaded parent line (same pattern as Requisitions
--   distributions).
--
-- Row selection:
--   BASE  line rows: RA_CUSTOMER_TRX_LINES_ALL where
--         INTERFACE_LINE_ATTRIBUTE1 LIKE :P_PREFIX || '%' (the
--         run-scoped prefix the transform stamped; the base line
--         persists it verbatim). Joined to RA_CUSTOMER_TRX_ALL to
--         return the header CUSTOMER_TRX_ID for traceability.
--   BASE  dist rows: RA_CUST_TRX_LINE_GL_DIST_ALL joined to the
--         base line by CUSTOMER_TRX_LINE_ID (confirmed transitively
--         through the loaded parent line; RECORD_KEY is derived from
--         the parent recon key + account class + the dist id so it is
--         deterministic, unique and traceable to the parent).
--   INTERFACE rows (both tiers): the interface rows that did NOT
--         load are the rejections. AutoInvoice does NOT purge
--         interface rows, so success rows persist too; they are
--         handled by the BASE tiers only, and the INTERFACE tiers
--         return rejections only -- a line/dist with NO base row --
--         so no row is counted twice. Selected by the load ESS
--         request id :P_LOAD_REQUEST_ID (RA_INTERFACE_LINES_ALL /
--         RA_INTERFACE_DISTRIBUTIONS_ALL.LOAD_REQUEST_ID), which is
--         the batch the run submitted.
--   :P_RUN_ID / :P_IMPORT_ESS_ID are declared for contract symmetry
--   and stamped into LOAD_REQUEST_ID for traceability.
--
-- FUSION_STATUS is normalized in this DM to exactly SUCCESS/ERROR:
--   BASE  (row present in a Fusion base table)  => SUCCESS
--   INTERFACE (rejection left in the interface) => ERROR
-- FUSION_ID is non-null on every BASE row (the Fusion surrogate id:
--   CUSTOMER_TRX_LINE_ID for a line, CUST_TRX_LINE_GL_DIST_ID for a
--   distribution). ERROR_MESSAGE is non-null on every ERROR row (the
--   real Fusion rejection text from RA_INTERFACE_ERRORS_ALL,
--   enriched with INVALID_VALUE, correlated per tier on
--   INTERFACE_LINE_ID / INTERFACE_DISTRIBUTION_ID).
--
-- RESIDUAL NOTE (honest): AR AutoInvoice is a known residual on the
-- demo instance -- AutoInvoice job-level aborts, so no AR line has
-- ever reached RA_CUSTOMER_TRX_LINES_ALL. The BASE tiers below are
-- therefore expected to return zero rows against current data; they
-- are the correct SHAPE for when AutoInvoice runs clean. The
-- INTERFACE tiers return the interface rows that exist. This is the
-- job-level-abort failure shape: Fusion produced no per-row verdict,
-- so unloaded rows are honestly left as interface rejections, never
-- a fabricated SUCCESS.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- ========== BASE tier: positive proof, one block per record type ==========

    -- BASE / lines. RECORD_KEY = the stamped recon key, persisted
    -- verbatim on the base line as INTERFACE_LINE_ATTRIBUTE1.
    SELECT
        'ARInvoices'                         AS object_type,
        bl.interface_line_attribute1         AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        bl.customer_trx_line_id              AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        TO_CHAR(bh.customer_trx_id)          AS source_ref,
        bl.interface_line_attribute2         AS dmt_reference
    FROM   ra_customer_trx_lines_all bl
    JOIN   ra_customer_trx_all bh
           ON bh.customer_trx_id = bl.customer_trx_id
    WHERE  bl.interface_line_attribute1 LIKE :P_PREFIX || '%'

    UNION ALL

    -- BASE / distributions. The base distribution carries NO
    -- interface key, so it is confirmed transitively through its
    -- loaded parent line (joined by CUSTOMER_TRX_LINE_ID). RECORD_KEY
    -- is derived from the parent's stamped recon key plus the account
    -- class plus the base dist id so it is deterministic, unique and
    -- traceable to the parent line.
    SELECT
        'ARInvoices.Distribution'            AS object_type,
        bl.interface_line_attribute1 || ':DIST:' || gd.account_class
            || ':' || gd.cust_trx_line_gl_dist_id                    AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        gd.cust_trx_line_gl_dist_id          AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_IMPORT_ESS_ID)          AS load_request_id,
        bl.interface_line_attribute1         AS source_ref,
        bl.interface_line_attribute2         AS dmt_reference
    FROM   ra_cust_trx_line_gl_dist_all gd
    JOIN   ra_customer_trx_lines_all bl
           ON bl.customer_trx_line_id = gd.customer_trx_line_id
    WHERE  bl.interface_line_attribute1 LIKE :P_PREFIX || '%'

    UNION ALL

    -- ========== INTERFACE tier: rejections only (no base row) ==========

    -- INTERFACE / lines. RECORD_KEY = the stamped recon key. A line
    -- is a rejection when it has NO base row (its recon key is not
    -- present in RA_CUSTOMER_TRX_LINES_ALL). Error text is the real
    -- AutoInvoice reject text for the line, enriched with the
    -- offending value.
    SELECT
        'ARInvoices'                         AS object_type,
        l.interface_line_attribute1          AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN le.error_message IS NOT NULL
             THEN '[LINE] ' || le.error_message END
                                             AS error_message,
        l.load_request_id                    AS load_request_id,
        l.interface_line_attribute1          AS source_ref,
        l.interface_line_attribute2          AS dmt_reference
    FROM   ra_interface_lines_all l
    LEFT   JOIN (
        SELECT e.interface_line_id,
               NULLIF(LISTAGG(
                   CASE
                       WHEN e.invalid_value IS NOT NULL
                       THEN e.message_text || ' [value=' || e.invalid_value || ']'
                       ELSE e.message_text
                   END, '; ') WITHIN GROUP (ORDER BY e.message_text), '') AS error_message
        FROM   ra_interface_errors_all e
        WHERE  e.interface_line_id IS NOT NULL
        GROUP BY e.interface_line_id
    ) le ON le.interface_line_id = l.interface_line_id
    WHERE  l.load_request_id = :P_LOAD_REQUEST_ID
    AND    l.line_type = 'LINE'
    AND    NOT EXISTS (
        SELECT 1 FROM ra_customer_trx_lines_all bl
        WHERE  bl.interface_line_attribute1 = l.interface_line_attribute1
        AND    NVL(bl.interface_line_context,'~') = NVL(l.interface_line_context,'~')
    )

    UNION ALL

    -- INTERFACE / distributions. RECORD_KEY = the stamped recon key
    -- carried on the interface distribution plus the account class.
    -- A distribution is a rejection when its parent line has no base
    -- row. Error text is correlated on INTERFACE_DISTRIBUTION_ID.
    SELECT
        'ARInvoices.Distribution'            AS object_type,
        d.interface_line_attribute1 || ':DIST:' || d.account_class
            || ':' || d.interface_distribution_id                    AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN de.error_message IS NOT NULL
             THEN '[DIST] ' || de.error_message END AS error_message,
        d.load_request_id                    AS load_request_id,
        d.interface_line_attribute1          AS source_ref,
        CAST(NULL AS VARCHAR2(4000))         AS dmt_reference
    FROM   ra_interface_distributions_all d
    LEFT   JOIN (
        SELECT e.interface_distribution_id,
               NULLIF(LISTAGG(
                   CASE
                       WHEN e.invalid_value IS NOT NULL
                       THEN e.message_text || ' [value=' || e.invalid_value || ']'
                       ELSE e.message_text
                   END, '; ') WITHIN GROUP (ORDER BY e.message_text), '') AS error_message
        FROM   ra_interface_errors_all e
        WHERE  e.interface_distribution_id IS NOT NULL
        GROUP BY e.interface_distribution_id
    ) de ON de.interface_distribution_id = d.interface_distribution_id
    WHERE  d.load_request_id = :P_LOAD_REQUEST_ID
    AND    NOT EXISTS (
        SELECT 1 FROM ra_customer_trx_lines_all bl
        WHERE  bl.interface_line_attribute1 = d.interface_line_attribute1
        AND    NVL(bl.interface_line_context,'~') = NVL(d.interface_line_context,'~')
    )
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start": return every row. On later
-- pages P_AFTER_KEY carries the previous page's last RECORD_KEY and only
-- greater keys are returned. RECORD_KEY is compared as text (the recon
-- key is a string); the reconciler feeds back the exact key it received.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
