-- PACKAGE BODY DMT_POZ_SUP_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_VALIDATOR_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_VALIDATOR_PKG Body
-- Pre-transform upstream dependency validator.
--
-- Dependency rule (Overview pre-validate, decided 2026-07-07):
-- the upstream record must have a LOADED TFM row from any run.
-- The match compares the source values as they appear in the data
-- (no prefix) on both staging sides, then joins to the parent's
-- TFM outcome via STG_SEQUENCE_ID. STG status is never consulted
-- for Fusion outcomes — the staging vocabulary is only
-- NEW / TRANSFORMED / FAILED, and the TFM row is the sole record
-- of the Fusion outcome.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_VALIDATOR_PKG';

    -- --------------------------------------------------------
    -- VALIDATE_SUPPLIERS
    -- No upstream dependency — all NEW rows pass through.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_SUPPLIERS (p_run_id IN NUMBER) IS
    BEGIN
        -- Suppliers have no upstream dependency — nothing to check.
        NULL;
    END VALIDATE_SUPPLIERS;

    -- --------------------------------------------------------
    -- VALIDATE_ADDRESSES
    -- Parent Supplier must have a LOADED TFM row (any run):
    -- source-value match on VENDOR_NAME, outcome on the TFM tier.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_ADDRESSES (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; the STG row keeps
        -- its status only (no message), flagged FAILED later by FLAG_STG_FAILED (§7).
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierAddresses', 'Supplier Addresses', a.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Supplier ''' || a.VENDOR_NAME ||
               ''' has no LOADED TFM row in any run — address skipped.'
        FROM   DMT_OWNER.DMT_POZ_SUP_ADDR_STG_TBL a
        WHERE  a.STG_STATUS = 'NEW'
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                   JOIN   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                          ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                   WHERE  s.VENDOR_NAME = a.VENDOR_NAME
                   AND    t.TFM_STATUS      = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_ADDRESSES: ' || l_failed ||
                                    ' address row(s) blocked — parent supplier has no LOADED TFM row.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_ADDRESSES');
        END IF;
    END VALIDATE_ADDRESSES;

    -- --------------------------------------------------------
    -- VALIDATE_SITES
    -- Parent Supplier must have a LOADED TFM row (any run):
    -- source-value match on VENDOR_NAME, outcome on the TFM tier.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_SITES (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; FLAG_STG_FAILED (§7)
        -- flags the STG row FAILED afterwards (status only, no message).
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierSites', 'Supplier Sites', si.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Supplier ''' || si.VENDOR_NAME ||
               ''' has no LOADED TFM row in any run — site skipped.'
        FROM   DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL si
        WHERE  si.STG_STATUS = 'NEW'
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                   JOIN   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                          ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                   WHERE  s.VENDOR_NAME = si.VENDOR_NAME
                   AND    t.TFM_STATUS      = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_SITES: ' || l_failed ||
                                    ' site row(s) blocked — parent supplier has no LOADED TFM row.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_SITES');
        END IF;
    END VALIDATE_SITES;

    -- --------------------------------------------------------
    -- VALIDATE_SITE_ASSIGNMENTS
    -- Parent Site must have a LOADED TFM row (any run):
    -- source-value match on VENDOR_NAME + VENDOR_SITE_CODE,
    -- outcome on the TFM tier.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_SITE_ASSIGNMENTS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; FLAG_STG_FAILED (§7)
        -- flags the STG row FAILED afterwards (status only, no message).
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierSiteAssignments', 'Site Assignments', a.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Site ''' || a.VENDOR_NAME ||
               ' / ' || a.VENDOR_SITE_CODE ||
               ''' has no LOADED TFM row in any run — site assignment skipped.'
        FROM   DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL a
        WHERE  a.STG_STATUS = 'NEW'
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL sis
                   JOIN   DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL t
                          ON t.STG_SEQUENCE_ID = sis.STG_SEQUENCE_ID
                   WHERE  sis.VENDOR_NAME      = a.VENDOR_NAME
                   AND    sis.VENDOR_SITE_CODE = a.VENDOR_SITE_CODE
                   AND    t.TFM_STATUS             = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_SITE_ASSIGNMENTS: ' || l_failed ||
                                    ' assignment row(s) blocked — parent site has no LOADED TFM row.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_SITE_ASSIGNMENTS');
        END IF;
    END VALIDATE_SITE_ASSIGNMENTS;

    -- --------------------------------------------------------
    -- VALIDATE_CONTACTS
    -- Parent Supplier must have a LOADED TFM row (any run):
    -- source-value match on VENDOR_NAME, outcome on the TFM tier.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_CONTACTS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; FLAG_STG_FAILED (§7)
        -- flags the STG row FAILED afterwards (status only, no message).
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierContacts', 'Supplier Contacts', c.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Supplier ''' || c.VENDOR_NAME ||
               ''' has no LOADED TFM row in any run — contact skipped.'
        FROM   DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL c
        WHERE  c.STG_STATUS = 'NEW'
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
                   JOIN   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
                          ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                   WHERE  s.VENDOR_NAME = c.VENDOR_NAME
                   AND    t.TFM_STATUS      = 'LOADED'
               );
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_CONTACTS: ' || l_failed ||
                                    ' contact row(s) blocked — parent supplier has no LOADED TFM row.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_CONTACTS');
        END IF;
    END VALIDATE_CONTACTS;

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

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Supplier Sites'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Site Assignments'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Supplier Contacts'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_UPSTREAM
    -- Orchestrates all 5 object upstream checks in dependency order.
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

        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id);

        -- Summary counts — from the run-stamped error table, never from STG.
        l_sup_failed := 0;  -- Suppliers has no upstream pre-validation dependency
        SELECT COUNT(*) INTO l_addr_failed FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Addresses';
        SELECT COUNT(*) INTO l_site_failed FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Sites';
        SELECT COUNT(*) INTO l_assn_failed FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Site Assignments';
        SELECT COUNT(*) INTO l_cont_failed FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Contacts';

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
