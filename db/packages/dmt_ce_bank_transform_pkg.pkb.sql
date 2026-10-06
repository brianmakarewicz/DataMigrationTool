-- PACKAGE BODY DMT_CE_BANK_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CE_BANK_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_CE_BANK_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_CE_BANK_TRANSFORM_PKG';

    -- Run prefix on the user-facing unique keys (owner decision: configuration
    -- objects prefix their keys exactly like Suppliers/Customers/Items, so a
    -- scenario can be re-loaded run after run). Keys and Fusion limits (REST
    -- describe; the TFM columns are the same width):
    --   bank    BANK_NAME     360  (cashBanks.BankName; unique per country)
    --   branch  BANK_NAME     360  (FK to the prefixed parent bank; the branch
    --                               name is unique within that new bank)
    --   account BANK_NAME     360  (FK) and ACCOUNT_NAME 80 (BankAccountName)
    -- A key that cannot carry the full prefix within its limit is NOT truncated
    -- (a truncated key can collide): the row is recorded FAILED with a
    -- [TRANSFORM_ERROR] naming the limit. The reconciler matches the base views
    -- on these same prefixed TFM values.
    C_BANK_NAME_MAX    CONSTANT PLS_INTEGER := 360;
    C_ACCOUNT_NAME_MAX CONSTANT PLS_INTEGER := 80;

    -- --------------------------------------------------------
    -- Private: read run prefix from DMT_PIPELINE_RUN_TBL
    -- --------------------------------------------------------
    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    -- ============================================================
    -- TRANSFORM_BANKS
    -- ============================================================
    PROCEDURE TRANSFORM_BANKS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BANKS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BANKS');

        l_prefix := get_prefix(p_run_id);

        IF p_reprocess_errors THEN
            UPDATE DMT_CE_BANK_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED')
            AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                    OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
        END IF;

        -- Prefix-fit guard (see package header): never truncate a key.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'CashBanks', 'Banks', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] BANK_NAME "' || s.BANK_NAME || '" cannot carry run prefix '
               || l_prefix || ': ' || LENGTH(l_prefix || s.BANK_NAME)
               || ' chars exceeds the Fusion limit of ' || C_BANK_NAME_MAX
               || ' (not truncated, to avoid a key collision).'
        FROM   DMT_CE_BANK_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND LENGTH(l_prefix || s.BANK_NAME) > C_BANK_NAME_MAX
        AND NOT EXISTS (SELECT 1 FROM DMT_CE_BANK_TFM_TBL t
                        WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND e.SUB_OBJECT = 'Banks');
        l_fail_count := SQL%ROWCOUNT;
        UPDATE DMT_CE_BANK_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Banks')
        AND    STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        INSERT INTO DMT_CE_BANK_TFM_TBL (
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
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.BANK_NAME, C_BANK_NAME_MAX),
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
        FROM DMT_CE_BANK_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_CE_BANK_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND LENGTH(l_prefix || s.BANK_NAME) <= C_BANK_NAME_MAX
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_CE_BANK_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_CE_BANK_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BANKS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BANKS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'CashBanks', 'Banks', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_CE_BANK_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                        /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_CE_BANK_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Banks');
                UPDATE DMT_CE_BANK_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Banks')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
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
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BRANCHES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BRANCHES');

        l_prefix := get_prefix(p_run_id);

        IF p_reprocess_errors THEN
            UPDATE DMT_CE_BRANCH_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED')
            AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                    OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
        END IF;

        -- Prefix-fit guard on the parent-bank FK (see package header).
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'CashBanks', 'Bank Branches', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] parent BANK_NAME "' || s.BANK_NAME || '" cannot carry run prefix '
               || l_prefix || ': ' || LENGTH(l_prefix || s.BANK_NAME)
               || ' chars exceeds the Fusion limit of ' || C_BANK_NAME_MAX
               || ' (not truncated, to avoid a key collision).'
        FROM   DMT_CE_BRANCH_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND LENGTH(l_prefix || s.BANK_NAME) > C_BANK_NAME_MAX
        AND NOT EXISTS (SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL t
                        WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND e.SUB_OBJECT = 'Bank Branches');
        l_fail_count := SQL%ROWCOUNT;
        UPDATE DMT_CE_BRANCH_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Bank Branches')
        AND    STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        INSERT INTO DMT_CE_BRANCH_TFM_TBL (
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
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.BANK_NAME, C_BANK_NAME_MAX),
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
        FROM DMT_CE_BRANCH_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND LENGTH(l_prefix || s.BANK_NAME) <= C_BANK_NAME_MAX
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_CE_BRANCH_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_BRANCHES complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_BRANCHES');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'CashBanks', 'Bank Branches', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_CE_BRANCH_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                        /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_CE_BRANCH_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Bank Branches');
                UPDATE DMT_CE_BRANCH_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Bank Branches')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
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
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCOUNTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCOUNTS');

        l_prefix := get_prefix(p_run_id);

        IF p_reprocess_errors THEN
            UPDATE DMT_CE_BANK_ACCT_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED')
            AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                    OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
        END IF;

        -- Prefix-fit guard on ACCOUNT_NAME and the parent-bank FK (see header).
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'CashBanks', 'Bank Accounts', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] '
               || CASE WHEN LENGTH(l_prefix || s.ACCOUNT_NAME) > C_ACCOUNT_NAME_MAX
                       THEN 'ACCOUNT_NAME "' || s.ACCOUNT_NAME || '" ('
                            || LENGTH(l_prefix || s.ACCOUNT_NAME) || ' chars with prefix, limit '
                            || C_ACCOUNT_NAME_MAX || ') ' END
               || CASE WHEN LENGTH(l_prefix || s.BANK_NAME) > C_BANK_NAME_MAX
                       THEN 'parent BANK_NAME "' || s.BANK_NAME || '" ('
                            || LENGTH(l_prefix || s.BANK_NAME) || ' chars with prefix, limit '
                            || C_BANK_NAME_MAX || ') ' END
               || 'cannot carry run prefix ' || l_prefix
               || ' within the Fusion limit (not truncated, to avoid a key collision).'
        FROM   DMT_CE_BANK_ACCT_STG_TBL s
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND (LENGTH(l_prefix || s.ACCOUNT_NAME) > C_ACCOUNT_NAME_MAX
             OR LENGTH(l_prefix || s.BANK_NAME) > C_BANK_NAME_MAX)
        AND NOT EXISTS (SELECT 1 FROM DMT_CE_BANK_ACCT_TFM_TBL t
                        WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
        AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                        WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                        AND e.SUB_OBJECT = 'Bank Accounts');
        l_fail_count := SQL%ROWCOUNT;
        UPDATE DMT_CE_BANK_ACCT_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Bank Accounts')
        AND    STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        INSERT INTO DMT_CE_BANK_ACCT_TFM_TBL (
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
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.BANK_NAME, C_BANK_NAME_MAX),
                    s.BRANCH_NAME,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.ACCOUNT_NAME, C_ACCOUNT_NAME_MAX),
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
        FROM DMT_CE_BANK_ACCT_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND NOT EXISTS (
            SELECT 1 FROM DMT_CE_BANK_ACCT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND LENGTH(l_prefix || s.ACCOUNT_NAME) <= C_ACCOUNT_NAME_MAX
        AND LENGTH(l_prefix || s.BANK_NAME) <= C_BANK_NAME_MAX
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_CE_BANK_ACCT_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND    EXISTS (
            SELECT 1 FROM DMT_CE_BANK_ACCT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_ACCOUNTS complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_ACCOUNTS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'CashBanks', 'Bank Accounts', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_CE_BANK_ACCT_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
                        /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
                        OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED','TRANSFORM_FAILED'))
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_CE_BANK_ACCT_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Bank Accounts');
                UPDATE DMT_CE_BANK_ACCT_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Bank Accounts')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
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
