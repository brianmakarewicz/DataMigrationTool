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
    -- NO supplier-dependency pre-validation for AP. Unlike PurchaseOrders (whose
    --   test data references DMT-migrated suppliers), AP invoices routinely
    --   reference suppliers that ALREADY EXIST in Fusion, not ones migrated in
    --   this batch (the regression fixture uses pre-existing supplier JGA / 1254).
    --   Fusion validates the supplier at load and rejects a bad one (e.g. 99999);
    --   the reconciler then marks that invoice FAILED with the reportable Fusion
    --   error. Blocking on "supplier is a DMT-migrated row" here would wrongly fail
    --   every legitimate invoice for a pre-existing supplier.
    -- History: the original check read the illegal value STG_STATUS='LOADED', which
    --   is never true, so its guard was permanently dormant and AP invoices always
    --   passed (that is why AP loaded before). A mechanical section-5 fix that
    --   pointed the guard at the TFM table ACTIVATED the check for the first time
    --   and broke AP; the correct resolution is to remove the check, not activate
    --   it (2026-07-14).
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

        -- No supplier-dependency check (see procedure header). AP invoices may
        -- reference pre-existing Fusion suppliers; Fusion validates the supplier
        -- at load and the reconciler reports any rejection. Nothing is failed here.

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. No supplier-dependency ' ||
                                'pre-validation for AP (suppliers may pre-exist in Fusion).',
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
