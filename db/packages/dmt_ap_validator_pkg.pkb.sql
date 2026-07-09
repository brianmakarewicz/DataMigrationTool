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
    -- Upstream dependency: VENDOR_NUM must match a LOADED supplier.
    -- For migrated suppliers: NVL(dep_prefix,'') || header.VENDOR_NUM
    --   must exist in DMT_POZ_SUPPLIERS_STG_TBL with STG_STATUS='LOADED'.
    -- Failed headers cascade to child lines via INVOICE_ID match.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_inv_type_filter   IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_dep_prefix   VARCHAR2(30);
        l_hdr_failed   NUMBER := 0;
        l_ln_failed    NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(from CONVERSION_MASTER)') ||
                                ', inv_type_filter=' || NVL(p_inv_type_filter, '(none)'),
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

        -- Step 1: Mark AP invoice headers FAILED if their supplier is not LOADED.
        -- Only enforced when suppliers have been migrated (at least one LOADED row exists).
        -- When no suppliers have been migrated, all AP rows pass through unchecked —
        -- this allows AP pipeline testing before the supplier pipeline runs.
        DECLARE
            l_any_loaded NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_any_loaded
            FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL
            WHERE  STG_STATUS = 'LOADED' AND ROWNUM = 1;

            IF l_any_loaded > 0 THEN
                UPDATE DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL h
                SET    STG_STATUS            = 'FAILED',
                       ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                               ERROR_TEXT,
                                               '[PRE_VALIDATION] Supplier ''' ||
                                               h.VENDOR_NUM ||
                                               ''' is not loaded — invoice record skipped.'),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  h.STG_STATUS IN ('NEW', 'RETRY')
                AND    (p_inv_type_filter IS NULL OR h.INVOICE_TYPE_LOOKUP_CODE LIKE p_inv_type_filter)
                AND    NOT EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                           WHERE  s.SEGMENT1 = h.VENDOR_NUM
                           AND    s.STG_STATUS   = 'LOADED'
                       );
                l_hdr_failed := SQL%ROWCOUNT;

                -- Step 2: Cascade failures to child lines for any failed header.
                UPDATE DMT_OWNER.DMT_AP_INVOICE_LINES_INT_STG_TBL ln
                SET    STG_STATUS            = 'FAILED',
                       ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                               ERROR_TEXT,
                                               '[PRE_VALIDATION] Parent invoice ''' ||
                                               ln.INVOICE_ID ||
                                               ''' failed upstream validation — line skipped.'),
                       LAST_UPDATED_DATE = SYSDATE
                WHERE  ln.STG_STATUS IN ('NEW', 'RETRY')
                AND    EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL h
                           WHERE  h.INVOICE_ID = ln.INVOICE_ID
                           AND    h.STG_STATUS     = 'FAILED'
                           AND    h.ERROR_TEXT LIKE '%[PRE_VALIDATION]%'
                           AND    (p_inv_type_filter IS NULL OR h.INVOICE_TYPE_LOOKUP_CODE LIKE p_inv_type_filter)
                       );
                l_ln_failed := SQL%ROWCOUNT;
            END IF;
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures — ' ||
                                'Headers: ' || l_hdr_failed ||
                                ' | Lines: '  || l_ln_failed,
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

END DMT_AP_VALIDATOR_PKG;
/
