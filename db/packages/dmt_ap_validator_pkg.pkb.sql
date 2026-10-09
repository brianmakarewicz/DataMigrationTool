-- PACKAGE BODY DMT_AP_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_AP_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_AP_VALIDATOR_PKG body
-- APInvoices pre- and post-transform validation.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_AP_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- NO SUPPLIER-DEPENDENCY CHECK.
    --   AP invoices reference PRE-EXISTING Fusion suppliers (the invoice's vendor
    --   already lives in Fusion — e.g. vendor 1254), NOT suppliers migrated earlier
    --   in this same run. There is therefore nothing upstream to pre-check: Fusion
    --   validates the supplier at load time and the reconciler reports any rejection
    --   as a Fusion error (e.g. INVALID SUPPLIER for a bad vendor 99999). Nothing is
    --   failed here.
    --
    --   History: the old guard failed any AP header whose vendor had no LOADED
    --   supplier TFM row. It originally checked the illegal value STG_STATUS='LOADED'
    --   (STG never holds LOADED, per design section 5), so it was dormant/always-zero.
    --   A mechanical section-5 fix pointed it at the TFM row instead, which ACTIVATED
    --   it — and then every good AP invoice (referencing a pre-existing supplier, never
    --   a migrated one) failed as soon as any supplier reached TFM_STATUS='LOADED'.
    --   Removed here so the committed code matches the behaviour proven live in run 130
    --   (good invoices to ap_invoices_all, bad vendor rejected by Fusion). When the
    --   canonical per-object flow lands, upstream validation becomes a run PARAMETER
    --   that defaults OFF for objects (AP, AR) that reference pre-existing Fusion data.
    -- --------------------------------------------------------
    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks above record WHY in the error table; this sets the
    -- STG status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_AP_INVOICES_INT_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'AP Invoice Headers'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_AP_INVOICE_LINES_INT_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'AP Invoice Lines'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_inv_type_filter   IN VARCHAR2 DEFAULT NULL,
        p_scenario_id     IN NUMBER   DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW'
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM: no supplier-dependency check ' ||
                                '(see procedure header). AP invoices reference pre-existing ' ||
                                'Fusion suppliers; Fusion validates the supplier at load and ' ||
                                'the reconciler reports any rejection. Nothing failed here. ' ||
                                'inv_type_filter=' || NVL(p_inv_type_filter, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');


        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id, p_scenario_id);
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
    -- Stub — no rules implemented yet.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        -- No post-transform validations implemented yet.
        -- Future: check INVOICE_AMOUNT > 0, INVOICE_DATE not future, CURRENCY_CODE valid, etc.
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

    -- ============================================================
    -- VALIDATE_LINE_BREAKS -- STANDARD line-break check (backlog #651; design
    -- section 5, [POST_VALIDATION]). Runs after the transform and before the
    -- FBDI generator: every STAGED TFM row of this run holding a carriage return
    -- or line feed in any CSV value is marked FAILED with a message naming the
    -- field(s) (DMT_UTIL_PKG.LINE_BREAK_ERROR), so it is never written to a CSV
    -- and never silently stripped. One UPDATE block per TFM table the generator
    -- reads, byte-identical except the table name (EDIT-TABLE). Does NOT commit --
    -- the caller owns the transaction. Checked by scripts/check_line_break_validation.py.
    -- ============================================================
    PROCEDURE VALIDATE_LINE_BREAKS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- <<EDIT-TABLE -- one TFM table the generator reads; repeat this whole block
        --   (EDIT-TABLE through the ROWCOUNT line) once per table>>
        UPDATE DMT_AP_INVOICES_INT_TFM_TBL t
        -- <<END EDIT-TABLE -- everything below is FIXED>>
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                         p_existing  => t.ERROR_TEXT,
                                         p_new_error => DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                                            p_row_json => JSON_OBJECT(t.* RETURNING CLOB))),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'STAGED'
        AND    DMT_UTIL_PKG.LINE_BREAK_ERROR(p_row_json => JSON_OBJECT(t.* RETURNING CLOB)) IS NOT NULL;
        l_failed := l_failed + SQL%ROWCOUNT;

        -- <<EDIT-TABLE -- one TFM table the generator reads; repeat this whole block
        --   (EDIT-TABLE through the ROWCOUNT line) once per table>>
        UPDATE DMT_AP_INVOICE_LINES_INT_TFM_TBL t
        -- <<END EDIT-TABLE -- everything below is FIXED>>
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                         p_existing  => t.ERROR_TEXT,
                                         p_new_error => DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                                            p_row_json => JSON_OBJECT(t.* RETURNING CLOB))),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'STAGED'
        AND    DMT_UTIL_PKG.LINE_BREAK_ERROR(p_row_json => JSON_OBJECT(t.* RETURNING CLOB)) IS NOT NULL;
        l_failed := l_failed + SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => 'VALIDATE_LINE_BREAKS: ' || l_failed ||
                               ' row(s) failed -- a value holds a line break (CR/LF).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => 'VALIDATE_LINE_BREAKS');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'VALIDATE_LINE_BREAKS failed.',
                SQLERRM, C_PKG, 'VALIDATE_LINE_BREAKS');
            RAISE;
    END VALIDATE_LINE_BREAKS;

END DMT_AP_VALIDATOR_PKG;
/
