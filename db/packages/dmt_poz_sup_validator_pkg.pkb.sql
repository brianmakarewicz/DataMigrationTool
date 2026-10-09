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
    PROCEDURE VALIDATE_SUPPLIERS (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        l_failed NUMBER := 0;
    BEGIN
        -- No upstream dependency, but VENDOR_NAME is mandatory: the TFM column is
        -- NOT NULL, so a null-name STG row would abort the whole set-based
        -- transform INSERT (ORA-01400) and crash the object. Reject it here as a
        -- per-row [PRE_VALIDATION] failure so it is accounted FAILED and the
        -- transform (which excludes pre-validated-failed rows) never sees it.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Suppliers', 'Suppliers', s.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Supplier is missing the mandatory VENDOR_NAME — row rejected before transform.'
        FROM   DMT_POZ_SUPPLIERS_STG_TBL s
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_POZ_SUPPLIERS_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id)
        AND    s.VENDOR_NAME IS NULL;
        l_failed := SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id   => p_run_id,
                p_message  => 'VALIDATE_SUPPLIERS: ' || l_failed ||
                              ' supplier row(s) rejected — missing mandatory VENDOR_NAME.',
                p_log_type => DMT_UTIL_PKG.C_LOG_WARN,
                p_package  => C_PKG,
                p_procedure=> 'VALIDATE_SUPPLIERS');
        END IF;
    END VALIDATE_SUPPLIERS;

    -- --------------------------------------------------------
    -- VALIDATE_ADDRESSES
    -- Parent Supplier must have a LOADED TFM row (any run):
    -- source-value match on VENDOR_NAME, outcome on the TFM tier.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_ADDRESSES (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; the STG row keeps
        -- its status only (no message), flagged FAILED later by FLAG_STG_FAILED (§7).
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierAddresses', 'Supplier Addresses', a.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Supplier ''' || a.VENDOR_NAME ||
               ''' has no LOADED TFM row in any run — address skipped.'
        FROM   DMT_POZ_SUP_ADDR_STG_TBL a
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, a.STG_STATUS, p_run_id, 'DMT_POZ_SUP_ADDR_STG_TBL', a.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR a.SCENARIO_ID = p_scenario_id)
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_POZ_SUPPLIERS_STG_TBL s
                   JOIN   DMT_POZ_SUPPLIERS_TFM_TBL t
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
    PROCEDURE VALIDATE_SITES (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; FLAG_STG_FAILED (§7)
        -- flags the STG row FAILED afterwards (status only, no message).
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierSites', 'Supplier Sites', si.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Supplier ''' || si.VENDOR_NAME ||
               ''' has no LOADED TFM row in any run — site skipped.'
        FROM   DMT_POZ_SUP_SITE_STG_TBL si
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, si.STG_STATUS, p_run_id, 'DMT_POZ_SUP_SITE_STG_TBL', si.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR si.SCENARIO_ID = p_scenario_id)
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_POZ_SUPPLIERS_STG_TBL s
                   JOIN   DMT_POZ_SUPPLIERS_TFM_TBL t
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
    PROCEDURE VALIDATE_SITE_ASSIGNMENTS (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; FLAG_STG_FAILED (§7)
        -- flags the STG row FAILED afterwards (status only, no message).
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierSiteAssignments', 'Site Assignments', a.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Site ''' || a.VENDOR_NAME ||
               ' / ' || a.VENDOR_SITE_CODE ||
               ''' has no LOADED TFM row in any run — site assignment skipped.'
        FROM   DMT_POZ_SUP_SITE_ASSN_STG_TBL a
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, a.STG_STATUS, p_run_id, 'DMT_POZ_SUP_SITE_ASSN_STG_TBL', a.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR a.SCENARIO_ID = p_scenario_id)
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_POZ_SUP_SITE_STG_TBL sis
                   JOIN   DMT_POZ_SUP_SITE_TFM_TBL t
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
    PROCEDURE VALIDATE_CONTACTS (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        l_failed NUMBER := 0;
    BEGIN
        -- Record the rejection in the run-stamped error table; FLAG_STG_FAILED (§7)
        -- flags the STG row FAILED afterwards (status only, no message).
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'SupplierContacts', 'Supplier Contacts', c.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Supplier ''' || c.VENDOR_NAME ||
               ''' has no LOADED TFM row in any run — contact skipped.'
        FROM   DMT_POZ_SUP_CONTACTS_STG_TBL c
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, c.STG_STATUS, p_run_id, 'DMT_POZ_SUP_CONTACTS_STG_TBL', c.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR c.SCENARIO_ID = p_scenario_id)
        AND    NOT EXISTS (
                   SELECT 1
                   FROM   DMT_POZ_SUPPLIERS_STG_TBL s
                   JOIN   DMT_POZ_SUPPLIERS_TFM_TBL t
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
    -- Each per-object flagger flips ONLY its own STG table's rows (those carrying
    -- a recorded error row for this run) to 'FAILED'. This lets a per-object
    -- supplier runner flag just its own object, giving per-object isolation.
    PROCEDURE FLAG_SUPPLIERS_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE>>
        UPDATE DMT_POZ_SUPPLIERS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Suppliers'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_SUPPLIERS_STG_FAILED;

    PROCEDURE FLAG_ADDRESSES_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE>>
        UPDATE DMT_POZ_SUP_ADDR_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Supplier Addresses'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_ADDRESSES_STG_FAILED;

    PROCEDURE FLAG_SITES_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE>>
        UPDATE DMT_POZ_SUP_SITE_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Supplier Sites'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_SITES_STG_FAILED;

    PROCEDURE FLAG_SITE_ASSIGNMENTS_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE>>
        UPDATE DMT_POZ_SUP_SITE_ASSN_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Site Assignments'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_SITE_ASSIGNMENTS_STG_FAILED;

    PROCEDURE FLAG_CONTACTS_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE>>
        UPDATE DMT_POZ_SUP_CONTACTS_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Supplier Contacts'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_CONTACTS_STG_FAILED;

    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- Flag all five supplier STG tables in sequence (orchestrator path).
        FLAG_SUPPLIERS_STG_FAILED(p_run_id, p_scenario_id);
        FLAG_ADDRESSES_STG_FAILED(p_run_id, p_scenario_id);
        FLAG_SITES_STG_FAILED(p_run_id, p_scenario_id);
        FLAG_SITE_ASSIGNMENTS_STG_FAILED(p_run_id, p_scenario_id);
        FLAG_CONTACTS_STG_FAILED(p_run_id, p_scenario_id);
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Orchestrates all 5 object upstream checks in dependency order.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
        l_sup_failed   NUMBER;
        l_addr_failed  NUMBER;
        l_site_failed  NUMBER;
        l_assn_failed  NUMBER;
        l_cont_failed  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start — pre-transform upstream dependency check.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        VALIDATE_SUPPLIERS(p_run_id, p_scenario_id, p_run_mode);
        VALIDATE_ADDRESSES(p_run_id, p_scenario_id, p_run_mode);
        VALIDATE_SITES(p_run_id, p_scenario_id, p_run_mode);
        VALIDATE_SITE_ASSIGNMENTS(p_run_id, p_scenario_id, p_run_mode);
        VALIDATE_CONTACTS(p_run_id, p_scenario_id, p_run_mode);

        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id, p_scenario_id);

        -- Summary counts — from the run-stamped error table, never from STG.
        SELECT COUNT(*) INTO l_sup_failed FROM DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Suppliers';
        SELECT COUNT(*) INTO l_addr_failed FROM DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Addresses';
        SELECT COUNT(*) INTO l_site_failed FROM DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Sites';
        SELECT COUNT(*) INTO l_assn_failed FROM DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Site Assignments';
        SELECT COUNT(*) INTO l_cont_failed FROM DMT_STG_TFM_ERROR_TBL WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Supplier Contacts';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures — ' ||
                                'Suppliers: ' || l_sup_failed ||
                                ' | Addresses: ' || l_addr_failed ||
                                ' | Sites: ' || l_site_failed ||
                                ' | Assignments: ' || l_assn_failed ||
                                ' | Contacts: ' || l_cont_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- NO COMMIT — orchestrator controls transaction boundaries

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

    -- ============================================================
    -- VALIDATE_SUPPLIERS_LINE_BREAKS -- STANDARD line-break check (backlog #651; design
    -- section 5, [POST_VALIDATION]). Runs after the transform and before the
    -- FBDI generator: every STAGED TFM row of this run holding a carriage return
    -- or line feed in any CSV value is marked FAILED with a message naming the
    -- field(s) (DMT_UTIL_PKG.LINE_BREAK_ERROR), so it is never written to a CSV
    -- and never silently stripped. One MERGE block per TFM table the generator
    -- reads, byte-identical except the table name (EDIT-TABLE). Does NOT commit --
    -- the caller owns the transaction. Checked by scripts/check_line_break_validation.py.
    -- ============================================================
    PROCEDURE VALIDATE_SUPPLIERS_LINE_BREAKS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_POZ_SUPPLIERS_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_POZ_SUPPLIERS_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => 'VALIDATE_SUPPLIERS_LINE_BREAKS: ' || l_failed ||
                               ' row(s) failed -- a value holds a line break (CR/LF).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => 'VALIDATE_SUPPLIERS_LINE_BREAKS');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'VALIDATE_SUPPLIERS_LINE_BREAKS failed.',
                SQLERRM, C_PKG, 'VALIDATE_SUPPLIERS_LINE_BREAKS');
            RAISE;
    END VALIDATE_SUPPLIERS_LINE_BREAKS;

    -- ============================================================
    -- VALIDATE_ADDRESSES_LINE_BREAKS -- STANDARD line-break check (backlog #651; design
    -- section 5, [POST_VALIDATION]). Runs after the transform and before the
    -- FBDI generator: every STAGED TFM row of this run holding a carriage return
    -- or line feed in any CSV value is marked FAILED with a message naming the
    -- field(s) (DMT_UTIL_PKG.LINE_BREAK_ERROR), so it is never written to a CSV
    -- and never silently stripped. One MERGE block per TFM table the generator
    -- reads, byte-identical except the table name (EDIT-TABLE). Does NOT commit --
    -- the caller owns the transaction. Checked by scripts/check_line_break_validation.py.
    -- ============================================================
    PROCEDURE VALIDATE_ADDRESSES_LINE_BREAKS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_POZ_SUP_ADDR_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_POZ_SUP_ADDR_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => 'VALIDATE_ADDRESSES_LINE_BREAKS: ' || l_failed ||
                               ' row(s) failed -- a value holds a line break (CR/LF).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => 'VALIDATE_ADDRESSES_LINE_BREAKS');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'VALIDATE_ADDRESSES_LINE_BREAKS failed.',
                SQLERRM, C_PKG, 'VALIDATE_ADDRESSES_LINE_BREAKS');
            RAISE;
    END VALIDATE_ADDRESSES_LINE_BREAKS;

    -- ============================================================
    -- VALIDATE_SITES_LINE_BREAKS -- STANDARD line-break check (backlog #651; design
    -- section 5, [POST_VALIDATION]). Runs after the transform and before the
    -- FBDI generator: every STAGED TFM row of this run holding a carriage return
    -- or line feed in any CSV value is marked FAILED with a message naming the
    -- field(s) (DMT_UTIL_PKG.LINE_BREAK_ERROR), so it is never written to a CSV
    -- and never silently stripped. One MERGE block per TFM table the generator
    -- reads, byte-identical except the table name (EDIT-TABLE). Does NOT commit --
    -- the caller owns the transaction. Checked by scripts/check_line_break_validation.py.
    -- ============================================================
    PROCEDURE VALIDATE_SITES_LINE_BREAKS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_POZ_SUP_SITE_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_POZ_SUP_SITE_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => 'VALIDATE_SITES_LINE_BREAKS: ' || l_failed ||
                               ' row(s) failed -- a value holds a line break (CR/LF).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => 'VALIDATE_SITES_LINE_BREAKS');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'VALIDATE_SITES_LINE_BREAKS failed.',
                SQLERRM, C_PKG, 'VALIDATE_SITES_LINE_BREAKS');
            RAISE;
    END VALIDATE_SITES_LINE_BREAKS;

    -- ============================================================
    -- VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS -- STANDARD line-break check (backlog #651; design
    -- section 5, [POST_VALIDATION]). Runs after the transform and before the
    -- FBDI generator: every STAGED TFM row of this run holding a carriage return
    -- or line feed in any CSV value is marked FAILED with a message naming the
    -- field(s) (DMT_UTIL_PKG.LINE_BREAK_ERROR), so it is never written to a CSV
    -- and never silently stripped. One MERGE block per TFM table the generator
    -- reads, byte-identical except the table name (EDIT-TABLE). Does NOT commit --
    -- the caller owns the transaction. Checked by scripts/check_line_break_validation.py.
    -- ============================================================
    PROCEDURE VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_POZ_SUP_SITE_ASSN_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_POZ_SUP_SITE_ASSN_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => 'VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS: ' || l_failed ||
                               ' row(s) failed -- a value holds a line break (CR/LF).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => 'VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS failed.',
                SQLERRM, C_PKG, 'VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS');
            RAISE;
    END VALIDATE_SITE_ASSIGNMENTS_LINE_BREAKS;

    -- ============================================================
    -- VALIDATE_CONTACTS_LINE_BREAKS -- STANDARD line-break check (backlog #651; design
    -- section 5, [POST_VALIDATION]). Runs after the transform and before the
    -- FBDI generator: every STAGED TFM row of this run holding a carriage return
    -- or line feed in any CSV value is marked FAILED with a message naming the
    -- field(s) (DMT_UTIL_PKG.LINE_BREAK_ERROR), so it is never written to a CSV
    -- and never silently stripped. One MERGE block per TFM table the generator
    -- reads, byte-identical except the table name (EDIT-TABLE). Does NOT commit --
    -- the caller owns the transaction. Checked by scripts/check_line_break_validation.py.
    -- ============================================================
    PROCEDURE VALIDATE_CONTACTS_LINE_BREAKS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_POZ_SUP_CONTACTS_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_POZ_SUP_CONTACTS_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => 'VALIDATE_CONTACTS_LINE_BREAKS: ' || l_failed ||
                               ' row(s) failed -- a value holds a line break (CR/LF).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => 'VALIDATE_CONTACTS_LINE_BREAKS');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'VALIDATE_CONTACTS_LINE_BREAKS failed.',
                SQLERRM, C_PKG, 'VALIDATE_CONTACTS_LINE_BREAKS');
            RAISE;
    END VALIDATE_CONTACTS_LINE_BREAKS;

END DMT_POZ_SUP_VALIDATOR_PKG;
/
