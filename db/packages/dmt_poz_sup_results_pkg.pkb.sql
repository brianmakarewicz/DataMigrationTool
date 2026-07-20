-- PACKAGE BODY DMT_POZ_SUP_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_POZ_SUP_RESULTS_PKG" AS
-- ============================================================
-- DMT_POZ_SUP_RESULTS_PKG Body
-- BIP reconciliation for all 5 supplier object types.
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
-- UTL_HTTP copy, no raw envelope logging — the shared transport
-- never logs the request envelope, which carries credentials).
-- Outcomes are written to the TFM tables only: nothing is written
-- back to staging; the TFM row is the sole record of the Fusion
-- outcome (decided 2026-07-07).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_POZ_SUP_RESULTS_PKG';

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Delegates to DMT_UTIL_PKG.RUN_BIP_REPORT with the CEMLI's
    -- registered report and the Contract v1 parameters (design
    -- section 5): P_RUN_ID, P_LOAD_REQUEST_ID (the load ESS request
    -- id — the reports filter POZ_*_INT by LOAD_REQUEST_ID, which is
    -- populated even when the chained import job errors),
    -- P_IMPORT_ESS_ID and P_PREFIX (from DMT_PIPELINE_RUN_TBL).
    -- PROCEDURE per the section 7 procedures-only contract:
    -- x_report_xml NULL with x_error_code = C_SUCCESS = zero rows;
    -- failures are logged here and reported via x_error_code —
    -- exceptions never escape.
    -- --------------------------------------------------------
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
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
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
                            '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                            '~P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                            '~P_PREFIX|'          || l_prefix,
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

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- Reads ROW elements under /DATA_DS/G_1 of the decoded report
    -- and updates the appropriate TFM table. TFM only — nothing is
    -- written back to staging; the TFM row is the sole record of
    -- the Fusion outcome.
    -- --------------------------------------------------------
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
                    UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_VENDOR_ID     = r.vendor_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    (SEGMENT1 = r.segment1 OR (SEGMENT1 IS NULL AND r.segment1 IS NULL))
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL
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
                    UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_PARTY_SITE_ID = r.party_site_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    PARTY_SITE_NAME      = r.party_site_name
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_ADDR_TFM_TBL
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
                IF r.fusion_status IN ('PROCESSED','SUCCESS','COMPLETED') THEN
                    -- Known residue (objects/Suppliers/README.md Known Issues):
                    -- the interface tier may return NULL VENDOR_SITE_ID for a
                    -- PROCESSED site. The row stays LOADED — the dependent site
                    -- assignments (which require the site) load with real Fusion
                    -- ids, proving the site transitively — but the missing id is
                    -- recorded as an appended [RECONCILE_ERROR] note so it is
                    -- never silent. Id backfill lands with the Contract v1
                    -- report rework (tracked work item).
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_VENDOR_SITE_ID = r.vendor_site_id,
                           ERROR_TEXT           = CASE
                                                      WHEN r.vendor_site_id IS NULL
                                                      THEN DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                          '[RECONCILE_ERROR] Fusion id not returned by interface tier')
                                                      ELSE ERROR_TEXT
                                                  END,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    VENDOR_NAME          = r.vendor_name
                    AND    VENDOR_SITE_CODE     = r.vendor_site_code
                    AND    TFM_STATUS              != 'LOADED';
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL
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
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
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
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_SITE_ASSN_TFM_TBL
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
                    UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL
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
                ELSIF r.fusion_status IN ('ERROR','REJECTED','FAILED','FAILURE') THEN
                    UPDATE DMT_OWNER.DMT_POZ_SUP_CONTACTS_TFM_TBL
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

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Orchestrates FETCH then PARSE for one CEMLI.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_cemli_code      IN VARCHAR2,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
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

END DMT_POZ_SUP_RESULTS_PKG;
/
