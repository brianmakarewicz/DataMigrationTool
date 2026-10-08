-- ============================================================
-- DMT_AR_RECON_V4_DM (2026-10-07), deployed ALONGSIDE V1, V2 and V3
-- (never overwritten). Change from V3: rows are FOUND only by the
-- Fusion job ids of ONE AutoInvoice load (owner decision 2026-10-07,
-- design section 5 "Reports find rows by Fusion job id"); the run
-- prefix is no longer a search value anywhere.
--   BASE lines: RA_CUSTOMER_TRX_LINES_ALL.REQUEST_ID = :P_IMPORT_ESS_ID.
--     Fusion stamps the AutoInvoiceImportEss request id on the
--     transaction header and its lines (known-good 10073584; DMT runs
--     249/250: lines and headers carry 10074800 / 10074833).
--   BASE distributions: through their loaded line (the line's
--     REQUEST_ID = :P_IMPORT_ESS_ID).
--   INTERFACE lines and distributions: LOAD_REQUEST_ID =
--     :P_LOAD_REQUEST_ID, unchanged. The import request is NOT added
--     here: AutoInvoice leaves REQUEST_ID NULL on the interface lines
--     it rejects (load 10073932, run 245), so it would hide the very
--     rejections this tier reports. RA_INTERFACE_ERRORS_ALL has no
--     REQUEST_ID column; its rows are scoped to this load's interface
--     rows exactly as in V2/V3.
--   "Did not load" (the INTERFACE tiers' NOT EXISTS) now means: no
--     base line of THIS import carries the row's flexfield key. V3
--     looked across every base line in the pod.
-- The flexfield key (ATTRIBUTE1 / ATTRIBUTE2) is used only as
-- RECORD_KEY, to match a returned row to its TFM row. Columns, keys,
-- keyset paging and parameters are unchanged from V3. P_PREFIX and
-- P_RUN_ID stay declared for contract symmetry only.
-- ============================================================
-- (V3 history follows.)
-- DMT_AR_RECON_V3_DM (2026-10-07), deployed ALONGSIDE V1 and V2
-- (never overwritten). Change from V2: the LINE RECORD_KEY is
-- INTERFACE_LINE_ATTRIBUTE1 || '/' || INTERFACE_LINE_ATTRIBUTE2, unique
-- per line. V2 keyed lines on ATTRIBUTE1 alone, which every line of one
-- DMT invoice shares, so a keyset page boundary inside such a run of
-- equal keys dropped rows ("> last key" skips the rest of the run).
-- '/' is used because '~' and '|' delimit the BIP parameter string the
-- shared fetch builds. Distribution keys were already unique
-- (ATTRIBUTE1:ACCOUNT_CLASS:ordinal) and are unchanged. Ordering and the
-- keyset comparison are pinned to BINARY so they agree with each other
-- regardless of the BIP session's NLS_SORT.
-- ============================================================
-- (V2 history follows.)
-- DMT_AR_RECON_V2_DM (2026-10-07), deployed ALONGSIDE V1
-- DMT_AR_RECON_DM (never overwritten). Only change from V1: both
-- RA_INTERFACE_ERRORS_ALL aggregations are scoped to this load's
-- interface lines / distributions. V1 failed with ORA-01489 once a load's line error carried
-- INTERFACE_DISTRIBUTION_ID = 0. Columns, keys and parameters are
-- unchanged.
-- ============================================================
-- ARInvoices reconciliation data model -- BIP reconciliation
-- report contract v1 (nine columns, keyset pagination, the six
-- standard parameters). Same shape as DMT_GL_BAL_RECON_DM.xdm and
-- DMT_REQ_RECON_DM.xdm.
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
-- :P_CHUNK_SIZE of them. An empty :P_AFTER_KEY selects from the start.
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
--   recon key directly. AR uses automatic transaction numbering, so
--   the base TRX_NUMBER is Fusion-assigned and does NOT carry the DMT
--   prefix -- the recon key, not the number, is the read-back key.
--   The base distribution carries no interface key, so it is
--   confirmed transitively through its loaded parent line.
--
-- Row selection (V4, by job id only):
--   BASE  line rows: RA_CUSTOMER_TRX_LINES_ALL where REQUEST_ID =
--         :P_IMPORT_ESS_ID. Joined to RA_CUSTOMER_TRX_ALL for the
--         header CUSTOMER_TRX_ID.
--   BASE  dist rows: RA_CUST_TRX_LINE_GL_DIST_ALL joined to the base
--         line by CUSTOMER_TRX_LINE_ID (confirmed transitively), the
--         line selected by REQUEST_ID = :P_IMPORT_ESS_ID.
--   INTERFACE rows (both tiers): the interface rows of the load
--         :P_LOAD_REQUEST_ID that did NOT load in this import (no base
--         line of :P_IMPORT_ESS_ID carries their key), so no row is
--         counted twice.
--   :P_RUN_ID / :P_PREFIX are declared for contract symmetry only.
--
-- FUSION_STATUS is normalized in this DM to exactly SUCCESS/ERROR:
--   BASE  (row present in a Fusion base table)  => SUCCESS
--   INTERFACE (rejection left in the interface) => ERROR
-- FUSION_ID is non-null on every BASE row (CUSTOMER_TRX_LINE_ID for a
-- line, CUST_TRX_LINE_GL_DIST_ID for a distribution). ERROR_MESSAGE
-- is non-null on every ERROR row (real Fusion reject text from
-- RA_INTERFACE_ERRORS_ALL, enriched with INVALID_VALUE, correlated
-- per tier on INTERFACE_LINE_ID / INTERFACE_DISTRIBUTION_ID).
--
-- JOB-LEVEL ABORT (honest): when AutoInvoice aborts at job level it
-- creates no transaction and writes no per-row error, so the BASE
-- tiers return nothing and the INTERFACE tiers return the load's rows
-- without an error message; the reconciler leaves them for the
-- UNACCOUNTED sweep, never a fabricated outcome. Since the known-good
-- fixes (runs 249/250) AutoInvoice creates DMT transactions on the pod.
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- ========== BASE tier: positive proof, one block per record type ==========

    -- BASE / lines. RECORD_KEY (V3) = INTERFACE_LINE_ATTRIBUTE1 || '/' ||
    -- INTERFACE_LINE_ATTRIBUTE2, both persisted verbatim on the base line -- the SAME
    -- expression the INTERFACE line block below emits, so a single TFM
    -- RECON_KEY joins both tiers of this record type. FUSION_ID is the base
    -- line's parent CUSTOMER_TRX_ID: it is the non-null base-table id the
    -- reconciler stamps into DMT_RA_LINES_TFM_TBL.FUSION_CUSTOMER_TRX_ID
    -- (positive proof the line reached RA_CUSTOMER_TRX_LINES_ALL and links to
    -- a created Fusion transaction). The base CUSTOMER_TRX_LINE_ID is carried
    -- as SOURCE_REF for traceability.
    SELECT
        'ARInvoices'                         AS object_type,
        bl.interface_line_attribute1 || '/' || bl.interface_line_attribute2
                                             AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        bh.customer_trx_id                   AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        bl.request_id                        AS load_request_id,
        TO_CHAR(bl.customer_trx_line_id)     AS source_ref,
        bl.interface_line_attribute2         AS dmt_reference
    FROM   ra_customer_trx_lines_all bl
    JOIN   ra_customer_trx_all bh
           ON bh.customer_trx_id = bl.customer_trx_id
    -- V4: found by the AutoInvoice import job id, never by the prefix.
    WHERE  bl.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- BASE / distributions. The base distribution carries NO interface key
    -- (verified against the live data dictionary -- RA_CUST_TRX_LINE_GL_DIST_ALL
    -- has none of the INTERFACE_LINE_ATTRIBUTE columns), so it is confirmed
    -- TRANSITIVELY through its loaded parent line (joined by CUSTOMER_TRX_LINE_ID).
    -- RECORD_KEY is the PARENT LINE's stamped recon key (INTERFACE_LINE_ATTRIBUTE1),
    -- the distribution's ACCOUNT_CLASS, and a DETERMINISTIC per-line ordinal -- the
    -- SAME three-part expression the INTERFACE distribution block below emits and
    -- the SAME expression DMT_AR_TRANSFORM_PKG stamps into the TFM RECON_KEY, so a
    -- single distribution TFM RECON_KEY joins both tiers of this record type.
    --
    -- WHY THE ORDINAL (PR #371 review, second round): a real AR line commonly
    -- carries 2+ distributions of the SAME ACCOUNT_CLASS (888 such lines exist in
    -- the demo base table), so parent-line-key || account_class still COLLIDES
    -- across siblings, which would drop rows at a keyset page boundary and
    -- misattribute one sibling's FUSION_ID onto another. The ordinal
    --   ROW_NUMBER() OVER (PARTITION BY parent_line_key, account_class
    --                      ORDER BY amount, acctd_amount, percent, <dist id>)
    -- makes the key unique per distribution. The ORDER BY leads with the business
    -- amounts AutoInvoice copies VERBATIM from the interface distribution onto the
    -- base distribution (AMOUNT, ACCTD_AMOUNT, PERCENT), so the ordinal a
    -- distribution receives agrees on all three sides (BASE here, INTERFACE below,
    -- and the TFM stamp) for every sibling that differs on any business amount --
    -- the overwhelming majority; only 11 fully-identical same-class same-amount
    -- groups exist in the entire demo base table. The trailing id
    -- (CUST_TRX_LINE_GL_DIST_ID here) only breaks ties among distributions that
    -- are identical on every business amount; for those the pairing is
    -- order-arbitrary but content-correct (indistinguishable business records
    -- drawing FUSION_IDs from the same pool). The key is GUARANTEED UNIQUE either
    -- way, so no page row is ever dropped. A base distribution row existing for
    -- that key is positive proof the line's distributions landed (AutoInvoice
    -- creates a line and its GL distributions atomically). FUSION_ID is the real
    -- base distribution id CUST_TRX_LINE_GL_DIST_ID, stamped into
    -- DMT_RA_DISTS_TFM_TBL.FUSION_CUST_TRX_LINE_GL_DIST_ID. The base dist id and
    -- account class are carried as SOURCE_REF for traceability.
    SELECT
        'ARInvoices.Distribution'            AS object_type,
        bl.interface_line_attribute1 || ':' || gd.account_class || ':' ||
        ROW_NUMBER() OVER (
            PARTITION BY bl.interface_line_attribute1, gd.account_class
            ORDER BY gd.amount, gd.acctd_amount, gd.percent, gd.cust_trx_line_gl_dist_id
        )                                    AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        gd.cust_trx_line_gl_dist_id          AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        bl.request_id                        AS load_request_id,
        gd.account_class || ':' || gd.cust_trx_line_gl_dist_id       AS source_ref,
        bl.interface_line_attribute2         AS dmt_reference
    FROM   ra_cust_trx_line_gl_dist_all gd
    JOIN   ra_customer_trx_lines_all bl
           ON bl.customer_trx_line_id = gd.customer_trx_line_id
    -- V4: through the loaded line of this import job, never by the prefix.
    WHERE  bl.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- ========== INTERFACE tier: rejections only (no base row) ==========

    -- INTERFACE / lines. RECORD_KEY (V3) = ATTRIBUTE1 || '/' || ATTRIBUTE2. A line
    -- is a rejection when it has NO base row. Error text is the real
    -- AutoInvoice reject text, enriched with the offending value.
    SELECT
        'ARInvoices'                         AS object_type,
        l.interface_line_attribute1 || '/' || l.interface_line_attribute2
                                             AS record_key,
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
        -- V2: only this load's lines (the unscoped GROUP BY aggregated every
        -- error row in the pod and could overflow LISTAGG).
        WHERE  e.interface_line_id IN (
                   SELECT li.interface_line_id FROM ra_interface_lines_all li
                   WHERE  li.load_request_id = :P_LOAD_REQUEST_ID)
        GROUP BY e.interface_line_id
    ) le ON le.interface_line_id = l.interface_line_id
    WHERE  l.load_request_id = :P_LOAD_REQUEST_ID
    AND    l.line_type = 'LINE'
    -- V4: "did not load" = no base line of THIS import job carries the key.
    AND    NOT EXISTS (
        SELECT 1 FROM ra_customer_trx_lines_all bl
        WHERE  bl.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    bl.interface_line_attribute1 = l.interface_line_attribute1
        AND    NVL(bl.interface_line_context,'~') = NVL(l.interface_line_context,'~')
    )

    UNION ALL

    -- INTERFACE / distributions. RECORD_KEY = the stamped recon key carried on
    -- the interface distribution (INTERFACE_LINE_ATTRIBUTE1, inherited from the
    -- parent line), the distribution's ACCOUNT_CLASS, and the SAME deterministic
    -- per-line ordinal the BASE distribution block above and the TFM stamp emit --
    -- so a single distribution TFM RECON_KEY joins both tiers. The ordinal
    --   ROW_NUMBER() OVER (PARTITION BY interface_line_attribute1, account_class
    --                      ORDER BY amount, acctd_amount, percent, interface_distribution_id)
    -- uses the same round-tripping business amounts as the BASE block, so the
    -- ordinal a distribution receives matches its BASE ordinal for every sibling
    -- that differs on any amount (see the BASE distribution block for the full
    -- rationale and the documented tie-break assumption). A line appears in exactly
    -- ONE tier -- all its distributions are BASE rows if the line loaded, or all
    -- INTERFACE rejections if it did not -- so partitioning within this tier covers
    -- the same set of a line's distributions the TFM stamp partitioned over. A
    -- distribution is a rejection when its parent line has no base row (so ALL of a
    -- rejected line's interface distributions survive the NOT EXISTS filter, and
    -- the analytic partition is complete for the line). Error text is correlated on
    -- INTERFACE_DISTRIBUTION_ID; the account class and interface distribution id
    -- are carried as SOURCE_REF for traceability.
    SELECT
        'ARInvoices.Distribution'            AS object_type,
        d.interface_line_attribute1 || ':' || d.account_class || ':' ||
        ROW_NUMBER() OVER (
            PARTITION BY d.interface_line_attribute1, d.account_class
            ORDER BY d.amount, d.acctd_amount, d.percent, d.interface_distribution_id
        )                                    AS record_key,
        'INTERFACE'                          AS source_type,
        'ERROR'                              AS fusion_status,
        CAST(NULL AS NUMBER)                 AS fusion_id,
        CASE WHEN de.error_message IS NOT NULL
             THEN '[DIST] ' || de.error_message END AS error_message,
        d.load_request_id                    AS load_request_id,
        d.account_class || ':' || d.interface_distribution_id        AS source_ref,
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
        -- V2: only this load's distributions. AutoInvoice writes some LINE
        -- errors with INTERFACE_DISTRIBUTION_ID = 0; the unscoped GROUP BY put
        -- every such row in the pod into one group and failed the whole report
        -- with ORA-01489 (run 246, load 10074714).
        WHERE  e.interface_distribution_id IN (
                   SELECT di.interface_distribution_id FROM ra_interface_distributions_all di
                   WHERE  di.load_request_id = :P_LOAD_REQUEST_ID)
        GROUP BY e.interface_distribution_id
    ) de ON de.interface_distribution_id = d.interface_distribution_id
    WHERE  d.load_request_id = :P_LOAD_REQUEST_ID
    -- V4: "did not load" = no base line of THIS import job carries the key.
    AND    NOT EXISTS (
        SELECT 1 FROM ra_customer_trx_lines_all bl
        WHERE  bl.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    bl.interface_line_attribute1 = d.interface_line_attribute1
        AND    NVL(bl.interface_line_context,'~') = NVL(d.interface_line_context,'~')
    )
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in
-- BIP, so treat NULL as "from the start": return every row. On later
-- pages P_AFTER_KEY carries the previous page's last RECORD_KEY and only
-- greater keys are returned. RECORD_KEY is compared as text (the recon
-- key is a string); the reconciler feeds back the exact key it received.
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
