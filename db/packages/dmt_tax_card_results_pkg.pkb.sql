-- PACKAGE BODY DMT_TAX_CARD_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_TAX_CARD_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_TAX_CARD_RESULTS_PKG body
-- CalculationCard HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_TAX_CARD_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'TaxCards';

    -- --------------------------------------------------------
    -- PROMOTE_LOADED (standard LOADED-promotion shape -- STUB)
    -- Every results package carries one dedicated LOADED-promotion procedure of the
    -- standard shape (design: "Standard LOADED-promotion shape"; conformant reference
    -- DMT_CUST_RESULTS_PKG). This one is a STUB.
    -- STUB: TaxCards (payroll calculation cards) is loaded and reconciled entirely
    -- through the shared HDL path -- DMT_HDL_UTIL_PKG.RECONCILE_HDL promotes each
    -- confirmed row to LOADED and DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS captures the
    -- Fusion DIR card id, both from within the shared HDL utility (not from a static
    -- per-package UPDATE). Capturing the surrogate id here is a blocked object today.
    -- There is therefore no per-package LOADED UPDATE to perform; this stub exists so
    -- the shape reads identically package-to-package and the reviewer sees an explicit
    -- stub, never a missing proc. RECONCILE_BATCH does the real HDL reconciliation.
    -- --------------------------------------------------------
    PROCEDURE PROMOTE_LOADED (
        p_run_id IN NUMBER
    ) IS
    BEGIN
        NULL; -- STUB: LOADED promotion + id capture happen inside DMT_HDL_UTIL_PKG; nothing to promote here.
    END PROMOTE_LOADED;

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. RequestId: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);


        -- 1. CalculationCard
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_TAX_CARD_TFM_TBL',
            p_stg_table      => 'DMT_TAX_CARD_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > CalculationCard',
            p_cemli_code     => C_CEMLI);


        -- 2. CardComponent
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_TAX_CARD_COMP_TFM_TBL',
            p_stg_table      => 'DMT_TAX_CARD_COMP_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > CardComponent',
            p_cemli_code     => C_CEMLI);

        -- Post-reconciliation: capture the Fusion DIR card id on each LOADED
        -- row (design section 7 rule). Blocked object today.
        DMT_HDL_UTIL_PKG.LOOKUP_FUSION_IDS(
            p_run_id => p_run_id,
            p_object_type    => 'TaxCards',
            p_log_context    => C_CEMLI || ' > CalculationCard',
            p_cemli_code     => C_CEMLI);

        -- Standard per-package LOADED-promotion hook. For TaxCards it is a stub:
        -- promotion + id capture are done inside DMT_HDL_UTIL_PKG above.
        PROMOTE_LOADED(p_run_id => p_run_id);


        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 2 object type(s) reconciled.',
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

END DMT_TAX_CARD_RESULTS_PKG;
/
