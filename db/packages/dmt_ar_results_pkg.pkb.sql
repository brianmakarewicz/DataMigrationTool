-- PACKAGE BODY DMT_AR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AR_RESULTS_PKG"
AS
-- ============================================================
-- DMT_AR_RESULTS_PKG body
-- ARInvoices post-load reconciliation — Contract v1, MULTI-TIER template.
--
-- Reuses the ONE shared Contract v1 fetch, DMT_RECON_CONTRACT_PKG.FETCH_ROWS,
-- exactly as the Workers and Requisitions templates do. A single FETCH_ROWS call
-- runs the ARInvoices Contract v1 report (nine columns, keyset paginated) over
-- BIP and returns BOTH tiers' rows in one collection; each row's OBJECT_TYPE says
-- which tier it belongs to.
--
-- The APPLY is STATIC SQL against the compile-time-known TFM tables (Option A,
-- owner decision on PR #248): one UPDATE pair PER TIER, filtering the report rows
-- by OBJECT_TYPE and joining that tier's TFM table on RECON_KEY = RECORD_KEY.
--
--   Tier           OBJECT_TYPE literal          TFM table               FUSION_ID column
--   ----------     --------------------------   ---------------------   ------------------------------
--   lines          'ARInvoices'                 DMT_RA_LINES_TFM_TBL     FUSION_CUSTOMER_TRX_ID
--   distributions  'ARInvoices.Distribution'    DMT_RA_DISTS_TFM_TBL     FUSION_CUST_TRX_LINE_GL_DIST_ID
--
-- Per tier the rule is the shared Contract v1 apply rule:
--   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID.
--   * FUSION_STATUS = ERROR with a real ERROR_MESSAGE -> FAILED, message
--     appended as '[FUSION_ERROR] ' || message (never composed). A '#IMPORT_REPORT#'
--     marker row is NOT a real message: it is left for the import-report harvest,
--     so the marker rows are skipped here.
--   * Everything else is left GENERATED for the shared unaccounted sweep;
--     INTERFACE/SUCCESS corroborates but is never sufficient for LOADED.
--
-- The RECON_KEY on each tier's TFM row is stamped by DMT_AR_TRANSFORM_PKG to
-- equal that tier's report RECORD_KEY:
--   * LINES stamp RECON_KEY = INTERFACE_LINE_ATTRIBUTE1 (the prefixed TRX_NUMBER).
--     AutoInvoice persists INTERFACE_LINE_ATTRIBUTE1 onto the base line, so the
--     base line is keyed directly on the stamped key.
--   * DISTRIBUTIONS stamp RECON_KEY = INTERFACE_LINE_ATTRIBUTE1 || ':' ||
--     ACCOUNT_CLASS. The base distribution carries no interface key of its own,
--     so it is confirmed TRANSITIVELY through its parent line; the data model
--     emits the parent line's stamped key, the distribution's ACCOUNT_CLASS, and a
--     DETERMINISTIC per-line ordinal as the distribution RECORD_KEY. The ordinal is
--     required as a per-distribution discriminator (PR #371 review, second round):
--     a real AR line commonly carries 2+ distributions of the SAME ACCOUNT_CLASS
--     (888 such lines exist in the live demo base table), so parent-line-key ||
--     account_class alone is NOT unique -- without the ordinal, sibling
--     distributions would share one key, dropping rows at a keyset page boundary
--     and stamping one sibling's FUSION_ID onto another. The ordinal is
--     ROW_NUMBER() OVER (PARTITION BY parent_line_key, account_class ORDER BY
--     amount, acctd_amount, percent, <dist id>), computed IDENTICALLY in the TFM
--     stamp (DMT_AR_TRANSFORM_PKG) and both data model distribution blocks; leading
--     the ORDER BY with the business amounts AutoInvoice copies verbatim from the
--     interface distribution onto the base distribution keeps the ordinal in
--     agreement across all three sides. That coupling is what makes the per-tier
--     join hit exactly one TFM row.
--
-- After the two tiers settle, outcomes are echoed back to both STG tables. No
-- composed parent/child roll-up is needed: each tier has its own BASE and
-- INTERFACE rows in the report, so each tier accounts for itself directly (a
-- distribution transitively via its parent line's key).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_AR_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'ARInvoices';

    -- Import-report marker: an ERROR row carrying this exact ERROR_MESSAGE is a
    -- placeholder for the separate import-report harvest, not a real Fusion error.
    -- Guard against it so a marker never produces a FAILED with fake text.
    C_IMPORT_MARKER CONSTANT VARCHAR2(30) := '#IMPORT_REPORT#';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_ARINVOICES (private)
    -- The Contract v1 apply for both ARInvoices tiers, Option A shape. One shared
    -- FETCH_ROWS call returns every tier's rows; the apply is STATIC SQL, one pair
    -- of UPDATEs per tier, discriminated by OBJECT_TYPE and joined on
    -- RECON_KEY = RECORD_KEY.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_ARINVOICES (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_ARINVOICES';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_line_loaded NUMBER := 0;  l_line_failed NUMBER := 0;
        l_dist_loaded NUMBER := 0;  l_dist_failed NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count across both tiers drives the shared fetch's keyset
        -- page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_RA_LINES_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_RA_DISTS_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   dual;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                C_PROC || ': Contract v1 fetch failed for ARInvoices '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': ARInvoices recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                -- ===== TIER: LINES (OBJECT_TYPE = 'ARInvoices') =====
                IF l_rows(i).OBJECT_TYPE = 'ARInvoices' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Backlog #65 three-tier match (owner order on PR #481). Tier 1 is
                        -- the stamped recon key (RECON_KEY = RECORD_KEY, exactly as before).
                        -- Tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing numeric
                        -- segment of DFF_KEY) is kept uniform with the shared template; AR's
                        -- DMT_REFERENCE is the line's INTERFACE_LINE_ATTRIBUTE2 reference
                        -- string, not a numeric carrier, so tier 2 is normally a no-op. There
                        -- is NO tier 3 for AR lines: the recon DM returns SOURCE_REF (the
                        -- business key) on the line as INTERFACE_LINE_ATTRIBUTE1 -- the SAME
                        -- unprefixed value it emits as RECORD_KEY -- so a business-key
                        -- fall-through would match on exactly the RECON_KEY column again,
                        -- byte-redundant with tier 1 (the prefixed TRX_NUMBER column is a
                        -- different value and is NOT what the report returns). Every tier-1 hit
                        -- short-circuits, so loaded outcomes are identical to before. Static
                        -- UPDATEs.
                        UPDATE DMT_RA_LINES_TFM_TBL
                        SET    TFM_STATUS             = 'LOADED',
                               FUSION_CUSTOMER_TRX_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE   = SYSDATE,
                               LAST_UPDATED_DATE      = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_RA_LINES_TFM_TBL
                                SET    TFM_STATUS             = 'LOADED',
                                       FUSION_CUSTOMER_TRX_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE   = SYSDATE,
                                       LAST_UPDATED_DATE      = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        l_line_loaded := l_line_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED AR line via TIER2 '
                                || 'fallback (tier 1 stamped key did not resolve). CUSTOMER_TRX_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_IMPORT_MARKER THEN
                        UPDATE DMT_RA_LINES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_line_failed := l_line_failed + SQL%ROWCOUNT;
                    END IF;

                -- ===== TIER: DISTRIBUTIONS (OBJECT_TYPE = 'ARInvoices.Distribution') =====
                ELSIF l_rows(i).OBJECT_TYPE = 'ARInvoices.Distribution' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Backlog #65 three-tier match. Tier 1 is the stamped recon key
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Tier 2 (DFF numeric
                        -- segment -> TFM_SEQUENCE_ID) is kept uniform with the shared
                        -- template; AR carries no numeric DFF carrier so it is normally a
                        -- no-op. There is NO tier 3 for distributions: a base distribution
                        -- carries no source-side business key of its own (its only identity
                        -- is the composite parent-line/account-class/ordinal recon key, so a
                        -- business-key fall-through would be redundant with tier 1). Every
                        -- tier-1 hit short-circuits, so loaded outcomes are identical to
                        -- before. Static UPDATEs.
                        UPDATE DMT_RA_DISTS_TFM_TBL
                        SET    TFM_STATUS                     = 'LOADED',
                               FUSION_CUST_TRX_LINE_GL_DIST_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE           = SYSDATE,
                               LAST_UPDATED_DATE              = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_RA_DISTS_TFM_TBL
                                SET    TFM_STATUS                     = 'LOADED',
                                       FUSION_CUST_TRX_LINE_GL_DIST_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE           = SYSDATE,
                                       LAST_UPDATED_DATE              = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        l_dist_loaded := l_dist_loaded + l_rc;
                        IF l_tier = 'TIER2' THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED AR distribution via TIER2 '
                                || 'fallback (tier 1 stamped key did not resolve). '
                                || 'CUST_TRX_LINE_GL_DIST_ID ' || l_rows(i).FUSION_ID || '.',
                                'INFO', C_PKG, C_PROC);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL
                          AND l_rows(i).ERROR_MESSAGE != C_IMPORT_MARKER THEN
                        UPDATE DMT_RA_DISTS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_dist_failed := l_dist_failed + SQL%ROWCOUNT;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        -- ============================================================
        -- Echo tier outcomes back to the two STG tables.
        -- ============================================================
        -- Lines
        UPDATE DMT_RA_LINES_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_RA_LINES_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_RA_LINES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_LINES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Distributions
        UPDATE DMT_RA_DISTS_STG_TBL stg
        SET    stg.STG_STATUS = 'LOADED', stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_RA_DISTS_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_RA_DISTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_RA_DISTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | lines LOADED/FAILED: ' || l_line_loaded || '/' || l_line_failed
                           || ' | dists LOADED/FAILED: '  || l_dist_loaded || '/' || l_dist_failed
                           || '. Unmatched rows left for the unaccounted sweep.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_ARINVOICES;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH — entry point (signature unchanged). Calls the shared
    -- Contract v1 apply. The ARInvoices load ESS id is the Contract v1
    -- P_LOAD_REQUEST_ID; the report's run-scoped selectors pick up the whole run
    -- regardless of how many batches it submitted (AR is grouped by BU+BatchSource).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        APPLY_CONTRACT_V1_ARINVOICES(p_run_id, TO_CHAR(p_load_ess_id));

        -- Unresolved records are intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object not-DONE
        -- and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;


    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known ARInvoices TFM table(s). Flips this run's UNACCOUNTED rows
    -- back to GENERATED and strips the trailing [UNACCOUNTED] tag from ERROR_TEXT
    -- (CLOB-safe REGEXP_REPLACE -- plain REPLACE raises ORA-22849), preserving any
    -- prior real error. Scoped by run, and by work-queue item when given. NO
    -- dynamic SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        UPDATE DMT_RA_LINES_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_RA_DISTS_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED ARInvoices row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_AR_RESULTS_PKG;
/
