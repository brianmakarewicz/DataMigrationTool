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
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL,
        p_inv_type_filter   IN VARCHAR2 DEFAULT NULL
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
