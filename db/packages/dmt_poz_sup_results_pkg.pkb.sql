-- PACKAGE BODY DMT_POZ_SUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_RESULTS_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_RESULTS_PKG Body
-- BIP reconciliation for the Suppliers supplier-family object.
-- Procedures relocated verbatim from the former shared
-- DMT_POZ_SUP_RESULTS_PKG (backlog #43). Transport is the shared
-- DMT_UTIL_PKG.RUN_BIP_REPORT. Outcomes written to the TFM table only.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_RESULTS_PKG';

    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        x_report_xml      OUT XMLTYPE,
        x_error_code      OUT NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step       VARCHAR2(500);
        l_prefix     VARCHAR2(20);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'FETCH_BIP_RESULTS start. CEMLI: ' || p_cemli_code ||
                                ' | P_RUN_ID: ' || p_run_id ||
                                ' | P_LOAD_REQUEST_ID: ' || p_load_ess_id ||
                                ' | P_IMPORT_ESS_ID: ' || NVL(TO_CHAR(p_import_ess_id), '(null)'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_step := 'reading run prefix for run ' || p_run_id;
        SELECT PREFIX INTO l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        -- Shared transport: resolves REPORT_CATALOG_PATH from
        -- DMT_BIP_REPORT_TBL; HTTP/SOAP/decode failures are logged by
        -- RUN_BIP_REPORT and surfaced through x_error_code. It never
        -- logs the request envelope (credentials never reach DMT_LOG_TBL).
        l_step := 'running Contract v1 reconciliation report for ' || p_cemli_code;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => p_cemli_code,
            p_params     => 'P_RUN_ID|'          || TO_CHAR(p_run_id) ||
                            DMT_UTIL_PKG.C_BIP_PARAM_SEP || 'P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                            DMT_UTIL_PKG.C_BIP_PARAM_SEP || 'P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                            DMT_UTIL_PKG.C_BIP_PARAM_SEP || 'P_PREFIX|'          || l_prefix,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'FETCH_BIP_RESULTS failed while ' || l_step ||
                                    ' (detail logged by RUN_BIP_REPORT).',
                p_log_type       => DMT_UTIL_PKG.C_LOG_ERROR,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'FETCH_BIP_RESULTS complete. CEMLI: ' || p_cemli_code ||
                                CASE WHEN x_report_xml IS NULL
                                     THEN ' | Report returned zero rows.'
                                     ELSE ' | Report data received.'
                                END,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'FETCH_BIP_RESULTS failed while ' || l_step ||
                                    ' | CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
    END FETCH_BIP_RESULTS;

    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_cemli_code     IN VARCHAR2,
        p_report_xml     IN XMLTYPE
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'PARSE_AND_UPDATE start. CEMLI: ' || p_cemli_code,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'PARSE_AND_UPDATE: BIP report returned zero rows for CEMLI: ' ||
                                    p_cemli_code || '. No TFM rows updated.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        -- Process rows using XMLTable — requires no legacy XMLSEQUENCE
        IF p_cemli_code = 'Suppliers' THEN
            FOR r IN (
                SELECT x.vendor_name, x.segment1,
                       x.vendor_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                    COLUMNS
                        vendor_name    VARCHAR2(360)  PATH 'VENDOR_NAME',
                        segment1       VARCHAR2(30)   PATH 'SEGMENT1',
                        vendor_id      NUMBER         PATH 'VENDOR_ID',
                        fusion_status  VARCHAR2(50)   PATH 'STATUS',
                        error_msg      VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_POZ_SUPPLIERS_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_VENDOR_ID     = r.vendor_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    (SEGMENT1 = r.segment1 OR (SEGMENT1 IS NULL AND r.segment1 IS NULL))
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE')
                  AND r.error_msg IS NOT NULL THEN
                    -- A Fusion error is always an error (design rule 2026-09-15):
                    -- never reinterpret the message (e.g. "already exists") as a
                    -- success. LOADED comes only from a real base-table hit above.
                    UPDATE DMT_POZ_SUPPLIERS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    (SEGMENT1 = r.segment1 OR (SEGMENT1 IS NULL AND r.segment1 IS NULL))
                    AND    TFM_STATUS              NOT IN ('FAILED', 'LOADED');   -- never flip a proven-LOADED row (report row order is not guaranteed)
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;

        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            FOR r IN (
                SELECT x.vendor_name, x.party_site_name,
                       x.party_site_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                    COLUMNS
                        vendor_name      VARCHAR2(360)  PATH 'VENDOR_NAME',
                        party_site_name  VARCHAR2(240)  PATH 'PARTY_SITE_NAME',
                        party_site_id    NUMBER         PATH 'PARTY_SITE_ID',
                        fusion_status    VARCHAR2(50)   PATH 'STATUS',
                        error_msg        VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_POZ_SUP_ADDR_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_PARTY_SITE_ID = r.party_site_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    PARTY_SITE_NAME      = r.party_site_name
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE')
                  AND r.error_msg IS NOT NULL THEN
                    -- A Fusion error is always an error (design rule 2026-09-15):
                    -- "already exists" is a rejection, not a success.
                    UPDATE DMT_POZ_SUP_ADDR_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    PARTY_SITE_NAME      = r.party_site_name
                    AND    TFM_STATUS              NOT IN ('FAILED', 'LOADED');   -- never flip a proven-LOADED row (report row order is not guaranteed)
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;

        ELSIF p_cemli_code = 'SupplierSites' THEN
            FOR r IN (
                SELECT x.vendor_name, x.vendor_site_code,
                       x.vendor_site_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                    COLUMNS
                        vendor_name      VARCHAR2(360)  PATH 'VENDOR_NAME',
                        vendor_site_code VARCHAR2(15)   PATH 'VENDOR_SITE_CODE',
                        vendor_site_id   NUMBER         PATH 'VENDOR_SITE_ID',
                        fusion_status    VARCHAR2(50)   PATH 'STATUS',
                        error_msg        VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED')
                   AND r.vendor_site_id IS NOT NULL THEN
                    -- Standard LOADED-promotion shape (design: "Standard
                    -- LOADED-promotion shape"): a row is promoted to LOADED ONLY
                    -- with its captured Fusion surrogate id (FUSION_VENDOR_SITE_ID),
                    -- and the SAME update writes it, guarded statically by
                    -- r.vendor_site_id IS NOT NULL. A PROCESSED site whose id the
                    -- interface tier did not return is deliberately NOT promoted
                    -- (see the ELSIF below) -- it is left GENERATED and surfaced by
                    -- the unaccounted sweep, never marked LOADED without proof.
                    UPDATE DMT_POZ_SUP_SITE_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_VENDOR_SITE_ID = r.vendor_site_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    FUSION_VENDOR_SITE_ID IS NULL
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED')
                      AND r.vendor_site_id IS NULL THEN
                    -- PROCESSED but the interface tier returned NO VENDOR_SITE_ID.
                    -- Per the standard, a null id can never reach LOADED: leave the
                    -- row GENERATED (the shared sweep alone marks it UNACCOUNTED with
                    -- the bare tag) and log the observation to DMT_LOG_TBL so it is
                    -- never silent. No ERROR_TEXT is written here: [RECONCILE_ERROR]
                    -- is retired (DMT_DESIGN section 5 tag table; backlog #213).
                    -- (Formerly this promoted to LOADED with a NULL id -- that
                    -- silent false-positive is now surfaced. objects/Suppliers
                    -- README Known Issues / Contract v1 report rework tracks the
                    -- interface-tier id backfill.)
                    DMT_UTIL_PKG.LOG(
                        p_run_id    => p_run_id,
                        p_message   => 'Supplier site ' || r.vendor_name || ' / ' || r.vendor_site_code
                                       || ': interface status ' || r.fusion_status
                                       || ' but no VENDOR_SITE_ID returned; row left GENERATED for the shared sweep.',
                        p_log_type  => 'WARN',
                        p_package   => C_PKG,
                        p_procedure => 'PARSE_AND_UPDATE');
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE')
                  AND r.error_msg IS NOT NULL THEN
                    -- A Fusion error is always an error (design rule 2026-09-15):
                    -- "already exists" is a rejection, not a success.
                    UPDATE DMT_POZ_SUP_SITE_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    TFM_STATUS              NOT IN ('FAILED', 'LOADED');   -- never flip a proven-LOADED row (report row order is not guaranteed)
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;

        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            FOR r IN (
                SELECT x.vendor_name, x.vendor_site_code, x.bu_name,
                       x.assignment_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                    COLUMNS
                        vendor_name      VARCHAR2(360)  PATH 'VENDOR_NAME',
                        vendor_site_code VARCHAR2(15)   PATH 'VENDOR_SITE_CODE',
                        bu_name          VARCHAR2(240)  PATH 'BUSINESS_UNIT_NAME',
                        assignment_id    NUMBER         PATH 'ASSIGNMENT_ID',
                        fusion_status    VARCHAR2(50)   PATH 'STATUS',
                        error_msg        VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_POZ_SUP_SITE_ASSN_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_ASSIGNMENT_ID = r.assignment_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    BUSINESS_UNIT_NAME   = r.bu_name
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE')
                  AND r.error_msg IS NOT NULL THEN
                    -- A Fusion error is always an error (design rule 2026-09-15):
                    -- "already exists" is a rejection, not a success.
                    UPDATE DMT_POZ_SUP_SITE_ASSN_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    BUSINESS_UNIT_NAME   = r.bu_name
                    AND    TFM_STATUS              NOT IN ('FAILED', 'LOADED');   -- never flip a proven-LOADED row (report row order is not guaranteed)
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;

        ELSIF p_cemli_code = 'SupplierContacts' THEN
            FOR r IN (
                SELECT x.vendor_name, x.first_name, x.last_name,
                       x.contact_id,
                       UPPER(x.fusion_status) AS fusion_status,
                       x.error_msg
                FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                    COLUMNS
                        vendor_name   VARCHAR2(360)  PATH 'VENDOR_NAME',
                        first_name    VARCHAR2(150)  PATH 'FIRST_NAME',
                        last_name     VARCHAR2(150)  PATH 'LAST_NAME',
                        contact_id    NUMBER         PATH 'CONTACT_ID',
                        fusion_status VARCHAR2(50)   PATH 'STATUS',
                        error_msg     VARCHAR2(4000) PATH 'ERROR_MESSAGE'
                ) x
            ) LOOP
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_POZ_SUP_CONTACTS_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_CONTACT_ID    = r.contact_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    FIRST_NAME           = r.first_name
                    AND    LAST_NAME            = r.last_name
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE')
                  AND r.error_msg IS NOT NULL THEN
                    -- A Fusion error is always an error (design rule 2026-09-15):
                    -- "already exists" is a rejection, not a success.
                    UPDATE DMT_POZ_SUP_CONTACTS_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    FIRST_NAME           = r.first_name
                    AND    LAST_NAME            = r.last_name
                    AND    TFM_STATUS              NOT IN ('FAILED', 'LOADED');   -- never flip a proven-LOADED row (report row order is not guaranteed)
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END LOOP;

        ELSE
            RAISE_APPLICATION_ERROR(-20037,
                'PARSE_AND_UPDATE: Unknown CEMLI_CODE = ''' || p_cemli_code ||
                '''. Valid values: Suppliers, SupplierAddresses, ' ||
                'SupplierSites, SupplierSiteAssignments, SupplierContacts');
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'PARSE_AND_UPDATE complete. CEMLI: ' || p_cemli_code ||
                                ' | LOADED: ' || l_loaded || ' | FAILED: ' || l_failed,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'PARSE_AND_UPDATE failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml   XMLTYPE;
        l_err   NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RECONCILE_BATCH start. CEMLI: ' || p_cemli_code ||
                                ' | Load ESS ID: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        FETCH_BIP_RESULTS(
            p_run_id        => p_run_id,
            p_cemli_code    => p_cemli_code,
            p_load_ess_id   => p_load_ess_id,
            x_report_xml    => l_xml,
            x_error_code    => l_err,
            p_import_ess_id => p_import_ess_id);
        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            -- Route the failure: RECONCILE_BATCH's contract with the
            -- queue engine (invoke_registered) is exception-based, so
            -- a fetch failure raises and the work item fails loudly —
            -- never a silent zero-row "success" (design section 5).
            RAISE_APPLICATION_ERROR(-20038,
                'RECONCILE_BATCH: FETCH_BIP_RESULTS failed for CEMLI ' ||
                p_cemli_code || ' (detail in DMT_LOG_TBL).');
        END IF;
        PARSE_AND_UPDATE(p_run_id, p_cemli_code, l_xml);

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'RECONCILE_BATCH complete. CEMLI: ' || p_cemli_code,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'RECONCILE_BATCH failed. CEMLI: ' || p_cemli_code,
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_cemli_code    IN VARCHAR2,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        IF p_cemli_code = 'Suppliers' THEN
            UPDATE DMT_POZ_SUPPLIERS_TFM_TBL
            SET    TFM_STATUS = 'GENERATED',
                   ERROR_TEXT = CASE
                                  WHEN DBMS_LOB.GETLENGTH(
                                         REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                                  THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                                  ELSE NULL
                                END,
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'UNACCOUNTED'
            AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
            l_reset := SQL%ROWCOUNT;

        ELSIF p_cemli_code = 'SupplierAddresses' THEN
            UPDATE DMT_POZ_SUP_ADDR_TFM_TBL
            SET    TFM_STATUS = 'GENERATED',
                   ERROR_TEXT = CASE
                                  WHEN DBMS_LOB.GETLENGTH(
                                         REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                                  THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                                  ELSE NULL
                                END,
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'UNACCOUNTED'
            AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
            l_reset := SQL%ROWCOUNT;

        ELSIF p_cemli_code = 'SupplierSites' THEN
            UPDATE DMT_POZ_SUP_SITE_TFM_TBL
            SET    TFM_STATUS = 'GENERATED',
                   ERROR_TEXT = CASE
                                  WHEN DBMS_LOB.GETLENGTH(
                                         REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                                  THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                                  ELSE NULL
                                END,
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'UNACCOUNTED'
            AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
            l_reset := SQL%ROWCOUNT;

        ELSIF p_cemli_code = 'SupplierSiteAssignments' THEN
            UPDATE DMT_POZ_SUP_SITE_ASSN_TFM_TBL
            SET    TFM_STATUS = 'GENERATED',
                   ERROR_TEXT = CASE
                                  WHEN DBMS_LOB.GETLENGTH(
                                         REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                                  THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                                  ELSE NULL
                                END,
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'UNACCOUNTED'
            AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
            l_reset := SQL%ROWCOUNT;

        ELSIF p_cemli_code = 'SupplierContacts' THEN
            UPDATE DMT_POZ_SUP_CONTACTS_TFM_TBL
            SET    TFM_STATUS = 'GENERATED',
                   ERROR_TEXT = CASE
                                  WHEN DBMS_LOB.GETLENGTH(
                                         REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                                  THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                                  ELSE NULL
                                END,
                   LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'UNACCOUNTED'
            AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
            l_reset := SQL%ROWCOUNT;

        ELSE
            RAISE_APPLICATION_ERROR(-20037,
                'RESET_UNACCOUNTED: Unknown CEMLI_CODE = ''' || p_cemli_code ||
                '''. Valid values: Suppliers, SupplierAddresses, ' ||
                'SupplierSites, SupplierSiteAssignments, SupplierContacts');
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED ' || p_cemli_code ||
            ' row(s) to GENERATED for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_POZ_SUP_RESULTS_PKG;
/
