-- PACKAGE BODY DMT_AR_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AR_VALIDATOR_PKG"
AS
-- ============================================================
-- DMT_AR_VALIDATOR_PKG body
-- ARInvoices pre- and post-transform validation.
--
-- Pre-validation rejections are recorded in the run-stamped error table
-- DMT_OWNER.DMT_STG_TFM_ERROR_TBL (design §7); the STG rows keep their
-- status only (no message) and are flagged FAILED afterwards by the
-- standard FLAG_STG_FAILED helper. No validator writes ERROR_TEXT on a
-- *_STG_TBL row.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AR_VALIDATOR_PKG';

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks record WHY in the error table; this sets the STG
    -- status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_RA_LINES_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'AR Lines'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_RA_DISTS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'AR Distributions'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency: the AR line's bill-to customer account must
    --   have LOADED. Per design section 5, LOADED is a TFM-only status
    --   (STG never carries it), so the check reads the customer account's
    --   TFM row: a customer-account STG row whose ACCOUNT_NUMBER matches the
    --   AR line's BILL_CUSTOMER_ACCOUNT_NUMBER, joined to its
    --   DMT_HZ_ACCOUNTS_TFM_TBL row with TFM_STATUS='LOADED' (linked 1:1 by
    --   STG_SEQUENCE_ID).
    -- Failed lines cascade to child distributions via
    -- INTERFACE_LINE_CONTEXT + INTERFACE_LINE_ATTRIBUTE1 match.
    -- Rejections are recorded in DMT_STG_TFM_ERROR_TBL (design §7); FLAG_STG_FAILED
    --   flags the STG rows FAILED afterwards (status only, no message). The cascade
    --   identifies a failed line by the presence of its error row this run, not by
    --   a STG message.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_dep_prefix    VARCHAR2(30);
        l_line_failed   NUMBER := 0;
        l_dist_failed   NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(from CONVERSION_MASTER)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Resolve dependent prefix: use parameter if supplied, else read from CONVERSION_MASTER
        IF p_dependent_prefix IS NOT NULL THEN
            l_dep_prefix := p_dependent_prefix;
        ELSE
            SELECT PREFIX
            INTO   l_dep_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        END IF;

        -- Step 1: Record a rejection for AR lines whose bill-to customer account
        -- is not LOADED. Only enforced when customer accounts have been migrated
        -- (at least one LOADED TFM row exists). When no customer accounts have been
        -- migrated, all AR rows pass through unchecked -- this allows AR pipeline
        -- testing before the customer pipeline runs. LOADED lives only on the TFM
        -- table (design section 5), so both the gate and the NOT EXISTS join the
        -- customer-account STG row to its TFM row (1:1 by STG_SEQUENCE_ID) and
        -- require TFM_STATUS='LOADED'.
        DECLARE
            l_any_loaded NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_any_loaded
            FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL
            WHERE  TFM_STATUS = 'LOADED' AND ROWNUM = 1;

            IF l_any_loaded > 0 AND DMT_UTIL_PKG.GET_CONFIG('VALIDATE_UPSTREAM_DEPS') = 'Y' THEN
                INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'ARInvoices', 'AR Lines', ln.STG_SEQUENCE_ID,
                       '[PRE_VALIDATION] Customer account ''' ||
                       ln.BILL_CUSTOMER_ACCOUNT_NUMBER ||
                       ''' is not loaded — AR invoice line skipped.'
                FROM   DMT_OWNER.DMT_RA_LINES_STG_TBL ln
                WHERE  ln.STG_STATUS IN ('NEW', 'RETRY')
                AND    ln.BILL_CUSTOMER_ACCOUNT_NUMBER IS NOT NULL
                AND    NOT EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL c
                           JOIN   DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
                                  ON t.STG_SEQUENCE_ID = c.STG_SEQUENCE_ID
                           WHERE  c.ACCOUNT_NUMBER = ln.BILL_CUSTOMER_ACCOUNT_NUMBER
                           AND    t.TFM_STATUS     = 'LOADED'
                       );
                l_line_failed := SQL%ROWCOUNT;

                -- Step 2: Cascade to distributions for any line rejected this run.
                -- Distributions link to lines via INTERFACE_LINE_CONTEXT + INTERFACE_LINE_ATTRIBUTE1.
                INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'ARInvoices', 'AR Distributions', d.STG_SEQUENCE_ID,
                       '[PRE_VALIDATION] Parent AR invoice line (context=''' ||
                       d.INTERFACE_LINE_CONTEXT || ''', attr1=''' ||
                       d.INTERFACE_LINE_ATTRIBUTE1 ||
                       ''') failed upstream validation — distribution skipped.'
                FROM   DMT_OWNER.DMT_RA_DISTS_STG_TBL d
                WHERE  d.STG_STATUS IN ('NEW', 'RETRY')
                AND    EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_RA_LINES_STG_TBL ln
                           JOIN   DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
                                  ON e.STG_SEQUENCE_ID = ln.STG_SEQUENCE_ID
                                 AND e.RUN_ID          = p_run_id
                                 AND e.SUB_OBJECT      = 'AR Lines'
                           WHERE  ln.INTERFACE_LINE_CONTEXT    = d.INTERFACE_LINE_CONTEXT
                           AND    ln.INTERFACE_LINE_ATTRIBUTE1 = d.INTERFACE_LINE_ATTRIBUTE1
                       );
                l_dist_failed := SQL%ROWCOUNT;

                -- Standard final step: flag the STG rows FAILED from the recorded
                -- error rows (status only, no message) so FAILED-mode reruns select
                -- on them (§7).
                FLAG_STG_FAILED(p_run_id);
            END IF;
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures — ' ||
                                'Lines: ' || l_line_failed ||
                                ' | Distributions: ' || l_dist_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Data quality checks on TFM rows after transformation.
    -- Stub -- no rules implemented yet.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        -- No post-transform validations implemented yet.
        -- Future: check CURRENCY_CODE, AMOUNT > 0, LINE_TYPE valid, etc.
        NULL;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_AR_VALIDATOR_PKG;
/
