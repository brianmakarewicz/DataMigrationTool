-- PACKAGE BODY DMT_POZ_SUP_ADDR_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_ADDR_VALIDATOR_PKG" AS
-- Stub: no validation rules yet. Promotes STAGED -> VALIDATED.
-- Add validation rules here without changing the orchestration flow.

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks above record WHY in the error table; this sets the
    -- STG status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Supplier Addresses'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );
    END FLAG_STG_FAILED;

    PROCEDURE VALIDATE_BATCH (p_run_id IN NUMBER) IS
        l_valid NUMBER := 0;
        l_invalid NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'VALIDATE_BATCH start (stub -- all records passed through).',
            'INFO', 'DMT_POZ_SUP_ADDR_VALIDATOR_PKG', 'VALIDATE_BATCH');

        UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL
        SET    STG_STATUS = 'VALIDATED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS = 'NEW';
        l_valid := SQL%ROWCOUNT;

        SELECT COUNT(*) INTO l_invalid
        FROM   DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL
        WHERE  STG_STATUS = 'INVALID';

        DMT_UTIL_PKG.LOG(p_run_id,
            'VALIDATE_BATCH complete. Valid: ' || l_valid || ' | Invalid: ' || l_invalid,
            'INFO', 'DMT_POZ_SUP_ADDR_VALIDATOR_PKG', 'VALIDATE_BATCH');

        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'VALIDATE_BATCH failed.', SQLERRM,
                'DMT_POZ_SUP_ADDR_VALIDATOR_PKG', 'VALIDATE_BATCH');
            RAISE;
    END VALIDATE_BATCH;

END DMT_POZ_SUP_ADDR_VALIDATOR_PKG;
/
