-- PACKAGE BODY DMT_MISC_RECEIPT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_MISC_RECEIPT_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_MISC_RECEIPT_VALIDATOR_PKG body
-- MiscReceipts pre- and post-transform validation.
-- Stub — no rules implemented yet.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_MISC_RECEIPT_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency check before transformation.
    -- Future: validate ITEM_NUM exists in Fusion inventory org,
    -- validate VENDOR_NAME/VENDOR_NUM if receipt is PO-based, etc.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id   IN NUMBER,
        p_dependent_prefix IN VARCHAR2 DEFAULT NULL
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(none)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- No pre-transform validations implemented yet.
        -- Future: check ITEM_NUMBER exists in target inventory org,
        -- validate TO_ORGANIZATION_CODE is a valid Fusion org, etc.
        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. No rules applied (stub).',
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
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        -- No post-transform validations implemented yet.
        -- Future: check QUANTITY > 0, UNIT_OF_MEASURE not null,
        -- TO_ORGANIZATION_CODE is valid, TRANSACTION_DATE not future, etc.
        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. No rules applied (stub).',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

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

END DMT_MISC_RECEIPT_VALIDATOR_PKG;
/
