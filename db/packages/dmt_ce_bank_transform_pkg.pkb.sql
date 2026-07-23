-- PACKAGE BODY DMT_CE_BANK_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_CE_BANK_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_TRANSFORM_PKG';

    -- ============================================================
    -- TRANSFORM_BANKS
    -- ============================================================
    PROCEDURE TRANSFORM_BANKS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BANKS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BANKS');

        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_CE_BANK_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_CE_BANK_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    COUNTRY_CODE,
                    BANK_NAME,
                    BANK_NUMBER,
                    SHORT_BANK_NAME,
                    DESCRIPTION,
                    TAX_PAYER_ID,
                    TAX_REGISTRATION_NUMBER,
                    END_DATE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,
                    ATTRIBUTE2,
                    ATTRIBUTE3,
                    ATTRIBUTE4,
                    ATTRIBUTE5,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,
                    s.COUNTRY_CODE,
                    s.BANK_NAME,
                    s.BANK_NUMBER,
                    s.SHORT_BANK_NAME,
                    s.DESCRIPTION,
                    s.TAX_PAYER_ID,
                    s.TAX_REGISTRATION_NUMBER,
                    s.END_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_CE_BANK_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Banks'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_CE_BANK_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_CE_BANK_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Banks'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_CE_BANK_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BANKS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BANKS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_BANKS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_BANKS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_BANKS;

    -- ============================================================
    -- TRANSFORM_BRANCHES
    -- ============================================================
    PROCEDURE TRANSFORM_BRANCHES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BRANCHES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BRANCHES');

        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_CE_BRANCH_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_CE_BRANCH_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    SOURCE_LINE_ID,
                    BANK_NAME,
                    BRANCH_NAME,
                    BRANCH_NUMBER,
                    BIC_CODE,
                    ALTERNATE_NAME,
                    DESCRIPTION,
                    EFT_SWIFT_CODE,
                    COUNTRY_CODE,
                    ADDRESS_LINE1,
                    CITY,
                    STATE,
                    POSTAL_CODE,
                    END_DATE,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,
                    s.SOURCE_LINE_ID,
                    s.BANK_NAME,
                    s.BRANCH_NAME,
                    s.BRANCH_NUMBER,
                    s.BIC_CODE,
                    s.ALTERNATE_NAME,
                    s.DESCRIPTION,
                    s.EFT_SWIFT_CODE,
                    s.COUNTRY_CODE,
                    s.ADDRESS_LINE1,
                    s.CITY,
                    s.STATE,
                    s.POSTAL_CODE,
                    s.END_DATE,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_CE_BRANCH_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Bank Branches'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_CE_BRANCH_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_CE_BRANCH_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Bank Branches'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_CE_BRANCH_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BRANCHES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BRANCHES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_BRANCHES failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_BRANCHES',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_BRANCHES;

    -- ============================================================
    -- TRANSFORM_ACCOUNTS
    -- ============================================================
    PROCEDURE TRANSFORM_ACCOUNTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCOUNTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCOUNTS');

        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_CE_BANK_ACCT_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    SOURCE_GROUP_ID,
                    SOURCE_LINE_ID,
                    BANK_NAME,
                    BRANCH_NAME,
                    ACCOUNT_NAME,
                    ACCOUNT_NUMBER,
                    CURRENCY_CODE,
                    ACCOUNT_TYPE,
                    LEGAL_ENTITY_NAME,
                    DESCRIPTION,
                    IBAN,
                    CHECK_DIGITS,
                    MULTI_CURRENCY_ALLOWED_FLAG,
                    ACCOUNT_SUFFIX,
                    SECONDARY_ACCOUNT_REFERENCE,
                    END_DATE,
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,
                    ATTRIBUTE2,
                    ATTRIBUTE3,
                    ATTRIBUTE4,
                    ATTRIBUTE5,
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    s.SOURCE_GROUP_ID,
                    s.SOURCE_LINE_ID,
                    s.BANK_NAME,
                    s.BRANCH_NAME,
                    s.ACCOUNT_NAME,
                    s.ACCOUNT_NUMBER,
                    s.CURRENCY_CODE,
                    s.ACCOUNT_TYPE,
                    s.LEGAL_ENTITY_NAME,
                    s.DESCRIPTION,
                    s.IBAN,
                    s.CHECK_DIGITS,
                    s.MULTI_CURRENCY_ALLOWED_FLAG,
                    s.ACCOUNT_SUFFIX,
                    s.SECONDARY_ACCOUNT_REFERENCE,
                    s.END_DATE,
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,
                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_CE_BANK_ACCT_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Bank Accounts'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_CE_BANK_ACCT_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.SUB_OBJECT = 'Bank Accounts'
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID)
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_CE_BANK_ACCT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCOUNTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCOUNTS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_ACCOUNTS failed.',
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_ACCOUNTS',
                p_sqlerrm        => SQLERRM);
            RAISE;
    END TRANSFORM_ACCOUNTS;

END DMT_CE_BANK_TRANSFORM_PKG;
/
