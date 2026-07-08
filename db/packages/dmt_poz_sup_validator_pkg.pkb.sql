-- PACKAGE BODY DMT_POZ_SUP_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_VALIDATOR_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_VALIDATOR_PKG Body
-- Pre-transform upstream dependency validator.
-- Checks parent STATUS = 'LOADED' before allowing transformation.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_SUPPLIERS
    -- No upstream dependency — all NEW/RETRY rows pass through.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_SUPPLIERS (p_run_id IN NUMBER) IS
    BEGIN
        -- Suppliers have no upstream dependency — nothing to check.
        NULL;
    END VALIDATE_SUPPLIERS;

    -- --------------------------------------------------------
    -- VALIDATE_ADDRESSES
    -- Parent Supplier must be LOADED in DMT_POZ_SUPPLIERS_STG_TBL.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_ADDRESSES (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL a
        SET    STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Supplier ''' || a.VENDOR_NAME ||
                                       ''' has not loaded successfully — address skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  a.STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                   WHERE  s.VENDOR_NAME = a.VENDOR_NAME
                   AND    s.STATUS      = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_ADDRESSES: ' || l_failed ||
                                    ' address row(s) blocked — parent supplier not LOADED.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_ADDRESSES');
        END IF;
    END VALIDATE_ADDRESSES;

    -- --------------------------------------------------------
    -- VALIDATE_SITES
    -- Parent Supplier must be LOADED in DMT_POZ_SUPPLIERS_STG_TBL.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_SITES (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL si
        SET    STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Supplier ''' || si.VENDOR_NAME ||
                                       ''' has not loaded successfully — site skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  si.STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                   WHERE  s.VENDOR_NAME = si.VENDOR_NAME
                   AND    s.STATUS      = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_SITES: ' || l_failed ||
                                    ' site row(s) blocked — parent supplier not LOADED.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_SITES');
        END IF;
    END VALIDATE_SITES;

    -- --------------------------------------------------------
    -- VALIDATE_SITE_ASSIGNMENTS
    -- Parent Site must be LOADED in DMT_POZ_SUP_SITE_STG_TBL.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_SITE_ASSIGNMENTS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL a
        SET    STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Site ''' || a.VENDOR_NAME ||
                                       ' / ' || a.VENDOR_SITE_CODE ||
                                       ''' has not loaded successfully — site assignment skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  a.STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL si
                   WHERE  si.VENDOR_NAME      = a.VENDOR_NAME
                   AND    si.VENDOR_SITE_CODE = a.VENDOR_SITE_CODE
                   AND    si.STATUS           = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_SITE_ASSIGNMENTS: ' || l_failed ||
                                    ' assignment row(s) blocked — parent site not LOADED.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_SITE_ASSIGNMENTS');
        END IF;
    END VALIDATE_SITE_ASSIGNMENTS;

    -- --------------------------------------------------------
    -- VALIDATE_CONTACTS
    -- Parent Supplier must be LOADED in DMT_POZ_SUPPLIERS_STG_TBL.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_CONTACTS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL c
        SET    STATUS            = 'FAILED',
               ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(
                                       ERROR_TEXT,
                                       '[PRE_VALIDATION] Supplier ''' || c.VENDOR_NAME ||
                                       ''' has not loaded successfully — contact skipped.'),
               LAST_UPDATED_DATE = SYSDATE
        WHERE  c.STATUS IN ('NEW', 'RETRY')
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                   WHERE  s.VENDOR_NAME = c.VENDOR_NAME
                   AND    s.STATUS      = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_CONTACTS: ' || l_failed ||
                                    ' contact row(s) blocked — parent supplier not LOADED.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_CONTACTS');
        END IF;
    END VALIDATE_CONTACTS;

    -- --------------------------------------------------------
    -- VALIDATE_UPSTREAM
    -- Orchestrates all 5 object type upstream checks in dependency order.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_UPSTREAM (p_run_id IN NUMBER) IS
        l_sup_failed   NUMBER;
        l_addr_failed  NUMBER;
        l_site_failed  NUMBER;
        l_assn_failed  NUMBER;
        l_cont_failed  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_UPSTREAM start — pre-transform upstream dependency check.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_UPSTREAM');

        VALIDATE_SUPPLIERS(p_run_id);
        VALIDATE_ADDRESSES(p_run_id);
        VALIDATE_SITES(p_run_id);
        VALIDATE_SITE_ASSIGNMENTS(p_run_id);
        VALIDATE_CONTACTS(p_run_id);

        -- Log summary counts
        SELECT COUNT(*) INTO l_sup_failed  FROM DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL    WHERE STATUS = 'FAILED' AND ERROR_TEXT LIKE '%[PRE_VALIDATION]%';
        SELECT COUNT(*) INTO l_addr_failed FROM DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL     WHERE STATUS = 'FAILED' AND ERROR_TEXT LIKE '%[PRE_VALIDATION]%';
        SELECT COUNT(*) INTO l_site_failed FROM DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL     WHERE STATUS = 'FAILED' AND ERROR_TEXT LIKE '%[PRE_VALIDATION]%';
        SELECT COUNT(*) INTO l_assn_failed FROM DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL WHERE STATUS = 'FAILED' AND ERROR_TEXT LIKE '%[PRE_VALIDATION]%';
        SELECT COUNT(*) INTO l_cont_failed FROM DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL WHERE STATUS = 'FAILED' AND ERROR_TEXT LIKE '%[PRE_VALIDATION]%';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_UPSTREAM complete. Pre-validation failures — ' ||
                                'Suppliers: ' || l_sup_failed ||
                                ' | Addresses: ' || l_addr_failed ||
                                ' | Sites: ' || l_site_failed ||
                                ' | Assignments: ' || l_assn_failed ||
                                ' | Contacts: ' || l_cont_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_UPSTREAM');

        -- NO COMMIT — orchestrator controls transaction boundaries

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_UPSTREAM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_UPSTREAM');
            RAISE;
    END VALIDATE_UPSTREAM;

END DMT_POZ_SUP_VALIDATOR_PKG;
/
