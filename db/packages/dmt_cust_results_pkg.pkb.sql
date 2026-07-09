-- PACKAGE BODY DMT_CUST_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CUST_RESULTS_PKG" AS
-- ============================================================
-- DMT_CUST_RESULTS_PKG body
-- Customers BIP reconciliation (ONE object, seven HZ record types).
--
-- Primary reconciliation on HZ_IMP_PARTIES_T; the six child record
-- types (locations, party sites, party site uses, accounts, account
-- sites, account site uses) cascade from the party outcome via
-- ORIG_SYSTEM_REFERENCE linkage.
--
-- Transport is the shared DMT_UTIL_PKG.RUN_BIP_REPORT (no private
-- UTL_HTTP copy, no raw-envelope logging -- the shared transport
-- never logs the request envelope, which carries credentials).
-- Outcomes are written to the seven TFM tables only: nothing is
-- written back to staging; the TFM row is the sole record of the
-- Fusion outcome (design section 2).
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_CUST_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Customers';

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- Delegates to DMT_UTIL_PKG.RUN_BIP_REPORT with the CEMLI's
    -- registered report and the Contract v1 parameters (design
    -- section 5): P_RUN_ID, P_LOAD_REQUEST_ID (the load ESS request
    -- id -- the report filters HZ_IMP_PARTIES_T on LOAD_REQUEST_ID,
    -- which is populated even when the chained import job errors),
    -- P_IMPORT_ESS_ID and P_PREFIX (from DMT_PIPELINE_RUN_TBL).
    -- PROCEDURE per the section 7 procedures-only contract:
    -- x_report_xml NULL with x_error_code = C_SUCCESS = zero rows;
    -- failures are logged here and reported via x_error_code --
    -- exceptions never escape.
    -- --------------------------------------------------------
    PROCEDURE FETCH_BIP_RESULTS (
        p_run_id          IN  NUMBER,
        p_load_ess_id     IN  NUMBER,
        x_report_xml      OUT XMLTYPE,
        x_error_code      OUT NUMBER,
        p_import_ess_id   IN  NUMBER DEFAULT NULL
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_step   VARCHAR2(500);
        l_prefix VARCHAR2(20);
    BEGIN
        x_report_xml := NULL;
        x_error_code := DMT_UTIL_PKG.C_ERROR;   -- pessimistic until proven

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start. CEMLI: ' || C_CEMLI ||
                         ' | P_RUN_ID: ' || p_run_id ||
                         ' | P_LOAD_REQUEST_ID: ' || p_load_ess_id ||
                         ' | P_IMPORT_ESS_ID: ' || NVL(TO_CHAR(p_import_ess_id), '(null)'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        l_step := 'reading run prefix for run ' || p_run_id;
        SELECT PREFIX INTO l_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        -- Shared transport: resolves REPORT_CATALOG_PATH from
        -- DMT_BIP_REPORT_TBL; HTTP/SOAP/decode failures are logged by
        -- RUN_BIP_REPORT and surfaced through x_error_code. It never
        -- logs the request envelope (credentials never reach DMT_LOG_TBL).
        l_step := 'running Contract v1 reconciliation report for ' || C_CEMLI;
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_RUN_ID|'           || TO_CHAR(p_run_id) ||
                            '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id) ||
                            '~P_IMPORT_ESS_ID|'   || TO_CHAR(p_import_ess_id) ||
                            '~P_PREFIX|'          || l_prefix,
            x_report_xml => x_report_xml,
            x_error_code => x_error_code);

        IF x_error_code != DMT_UTIL_PKG.C_SUCCESS THEN
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ' failed while ' || l_step ||
                             ' (detail logged by RUN_BIP_REPORT).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete. CEMLI: ' || C_CEMLI ||
                         CASE WHEN x_report_xml IS NULL
                              THEN ' | Report returned zero rows.'
                              ELSE ' | Report data received.'
                         END,
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            x_report_xml := NULL;
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id  => p_run_id,
                p_message => C_PROC || ' failed while ' || l_step ||
                             ' | CEMLI: ' || C_CEMLI,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- Reads party rows under /DATA_DS/G_1 of the decoded report and
    -- updates DMT_HZ_PARTIES_TFM_TBL (primary), then cascades the
    -- LOADED/FAILED outcome to the six child TFM tables via
    -- ORIG_SYSTEM_REFERENCE linkage. Any remaining GENERATED child row
    -- (sent to Fusion but not matched by the cascade) is marked FAILED
    -- with a reconciliation error -- absence is never LOADED (Rule #1).
    -- Writes the seven TFM tables only; nothing is written back to
    -- staging.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id          IN NUMBER,
        p_report_xml      IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_loaded NUMBER := 0;
        l_failed NUMBER := 0;
        l_sweep  NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- NULL report = BIP returned 0 rows. Positive verification is
        -- impossible, so every GENERATED row across all seven tables is
        -- FAILED with a reconciliation error (no absence=LOADED, Rule #1).
        IF p_report_xml IS NULL THEN
            UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_sweep := SQL%ROWCOUNT;

            UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_sweep := l_sweep + SQL%ROWCOUNT;

            UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_sweep := l_sweep + SQL%ROWCOUNT;

            UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_sweep := l_sweep + SQL%ROWCOUNT;

            UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_sweep := l_sweep + SQL%ROWCOUNT;

            UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_sweep := l_sweep + SQL%ROWCOUNT;

            UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL
            SET    TFM_STATUS = 'FAILED',
                   ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
            l_sweep := l_sweep + SQL%ROWCOUNT;

            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': BIP report returned zero rows. ' ||
                             l_sweep || ' GENERATED rows marked FAILED (not reconciled).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        -- Primary: party rows from the decoded report.
        -- HZ_IMP_PARTIES_T INTERFACE_STATUS: NULL/1/C = success, 4/E = error.
        FOR r IN (
            SELECT x.party_orig_system_reference,
                   x.party_number,
                   x.party_id,
                   UPPER(x.interface_status) AS interface_status,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    party_orig_system_reference VARCHAR2(255)  PATH 'PARTY_ORIG_SYSTEM_REFERENCE',
                    party_number               VARCHAR2(30)    PATH 'PARTY_NUMBER',
                    party_id                   VARCHAR2(20)    PATH 'PARTY_ID',
                    interface_status           VARCHAR2(50)    PATH 'INTERFACE_STATUS',
                    error_msg                  VARCHAR2(4000)  PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.interface_status IS NULL
               OR r.interface_status IN ('1','C','COMPLETED','SUCCESS','PROCESSED') THEN
                UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                SET    TFM_STATUS           = 'LOADED',
                       FUSION_PARTY_ID      = TO_NUMBER(r.party_id),
                       FUSION_PARTY_NUMBER  = r.party_number,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PARTY_ORIG_SYSTEM_REFERENCE = r.party_orig_system_reference
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.interface_status IN ('4','E','ERROR','REJECTED','FAILED','FAILURE') THEN
                UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                SET    TFM_STATUS           = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                           '[FUSION_ERROR] ' || NVL(r.error_msg,
                             'Party import failed. INTERFACE_STATUS: ' || r.interface_status)),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID = p_run_id
                AND    PARTY_ORIG_SYSTEM_REFERENCE = r.party_orig_system_reference
                AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- ============================================================
        -- Cascade LOADED to child TFM tables (static UPDATEs, one per
        -- child table -- no dynamic SQL). A child is LOADED when its
        -- parent (party for party-level children; account/site for the
        -- deeper tiers) reached LOADED.
        -- ============================================================

        -- Party Sites: parent party LOADED
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
        SET    ps.TFM_STATUS = 'LOADED',
               ps.RESULTS_UPDATED_DATE = SYSDATE, ps.LAST_UPDATED_DATE = SYSDATE
        WHERE  ps.RUN_ID = p_run_id AND ps.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.PARTY_ORIG_SYSTEM_REFERENCE = ps.PARTY_ORIG_SYSTEM_REFERENCE
                       AND   p.TFM_STATUS = 'LOADED');

        -- Party Site Uses: parent party site LOADED
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL psu
        SET    psu.TFM_STATUS = 'LOADED',
               psu.RESULTS_UPDATED_DATE = SYSDATE, psu.LAST_UPDATED_DATE = SYSDATE
        WHERE  psu.RUN_ID = p_run_id AND psu.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
                       WHERE ps.RUN_ID = p_run_id
                       AND   ps.SITE_ORIG_SYSTEM_REFERENCE = psu.SITE_ORIG_SYSTEM_REFERENCE
                       AND   ps.TFM_STATUS = 'LOADED');

        -- Locations: LOADED when at least one owning party site is LOADED
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL loc
        SET    loc.TFM_STATUS = 'LOADED',
               loc.RESULTS_UPDATED_DATE = SYSDATE, loc.LAST_UPDATED_DATE = SYSDATE
        WHERE  loc.RUN_ID = p_run_id AND loc.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
                       WHERE ps.RUN_ID = p_run_id
                       AND   ps.LOCATION_ORIG_SYSTEM_REFERENCE = loc.LOCATION_ORIG_SYSTEM_REFERENCE
                       AND   ps.TFM_STATUS = 'LOADED');

        -- Accounts: parent party LOADED
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
        SET    a.TFM_STATUS = 'LOADED',
               a.RESULTS_UPDATED_DATE = SYSDATE, a.LAST_UPDATED_DATE = SYSDATE
        WHERE  a.RUN_ID = p_run_id AND a.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.PARTY_ORIG_SYSTEM_REFERENCE = a.PARTY_ORIG_SYSTEM_REFERENCE
                       AND   p.TFM_STATUS = 'LOADED');

        -- Account Sites: parent account LOADED
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
        SET    acs.TFM_STATUS = 'LOADED',
               acs.RESULTS_UPDATED_DATE = SYSDATE, acs.LAST_UPDATED_DATE = SYSDATE
        WHERE  acs.RUN_ID = p_run_id AND acs.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
                       WHERE a.RUN_ID = p_run_id
                       AND   a.CUST_ORIG_SYSTEM_REFERENCE = acs.CUST_ORIG_SYSTEM_REFERENCE
                       AND   a.TFM_STATUS = 'LOADED');

        -- Account Site Uses: parent account site LOADED
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL asu
        SET    asu.TFM_STATUS = 'LOADED',
               asu.RESULTS_UPDATED_DATE = SYSDATE, asu.LAST_UPDATED_DATE = SYSDATE
        WHERE  asu.RUN_ID = p_run_id AND asu.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
                       WHERE acs.RUN_ID = p_run_id
                       AND   acs.CUST_SITE_ORIG_SYS_REF = asu.CUST_SITE_ORIG_SYS_REF
                       AND   acs.TFM_STATUS = 'LOADED');

        -- ============================================================
        -- Cascade FAILED to child TFM tables (parent rejected by Fusion).
        -- ============================================================

        -- Party Sites: parent party FAILED
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
        SET    ps.TFM_STATUS = 'FAILED',
               ps.ERROR_TEXT  = DMT_UTIL_PKG.APPEND_ERROR(ps.ERROR_TEXT,
                   '[FUSION_ERROR] Parent party ''' || ps.PARTY_ORIG_SYSTEM_REFERENCE || ''' was rejected by Fusion.'),
               ps.RESULTS_UPDATED_DATE = SYSDATE, ps.LAST_UPDATED_DATE = SYSDATE
        WHERE  ps.RUN_ID = p_run_id AND ps.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.PARTY_ORIG_SYSTEM_REFERENCE = ps.PARTY_ORIG_SYSTEM_REFERENCE
                       AND   p.TFM_STATUS = 'FAILED');

        -- Party Site Uses: parent party site FAILED
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL psu
        SET    psu.TFM_STATUS = 'FAILED',
               psu.ERROR_TEXT  = DMT_UTIL_PKG.APPEND_ERROR(psu.ERROR_TEXT,
                   '[FUSION_ERROR] Parent party site was rejected by Fusion.'),
               psu.RESULTS_UPDATED_DATE = SYSDATE, psu.LAST_UPDATED_DATE = SYSDATE
        WHERE  psu.RUN_ID = p_run_id AND psu.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
                       WHERE ps.RUN_ID = p_run_id
                       AND   ps.SITE_ORIG_SYSTEM_REFERENCE = psu.SITE_ORIG_SYSTEM_REFERENCE
                       AND   ps.TFM_STATUS = 'FAILED');

        -- Accounts: parent party FAILED
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
        SET    a.TFM_STATUS = 'FAILED',
               a.ERROR_TEXT  = DMT_UTIL_PKG.APPEND_ERROR(a.ERROR_TEXT,
                   '[FUSION_ERROR] Parent party ''' || a.PARTY_ORIG_SYSTEM_REFERENCE || ''' was rejected by Fusion.'),
               a.RESULTS_UPDATED_DATE = SYSDATE, a.LAST_UPDATED_DATE = SYSDATE
        WHERE  a.RUN_ID = p_run_id AND a.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.PARTY_ORIG_SYSTEM_REFERENCE = a.PARTY_ORIG_SYSTEM_REFERENCE
                       AND   p.TFM_STATUS = 'FAILED');

        -- Account Sites: parent account FAILED
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
        SET    acs.TFM_STATUS = 'FAILED',
               acs.ERROR_TEXT  = DMT_UTIL_PKG.APPEND_ERROR(acs.ERROR_TEXT,
                   '[FUSION_ERROR] Parent account was rejected by Fusion.'),
               acs.RESULTS_UPDATED_DATE = SYSDATE, acs.LAST_UPDATED_DATE = SYSDATE
        WHERE  acs.RUN_ID = p_run_id AND acs.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
                       WHERE a.RUN_ID = p_run_id
                       AND   a.CUST_ORIG_SYSTEM_REFERENCE = acs.CUST_ORIG_SYSTEM_REFERENCE
                       AND   a.TFM_STATUS = 'FAILED');

        -- Account Site Uses: parent account site FAILED
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL asu
        SET    asu.TFM_STATUS = 'FAILED',
               asu.ERROR_TEXT  = DMT_UTIL_PKG.APPEND_ERROR(asu.ERROR_TEXT,
                   '[FUSION_ERROR] Parent account site was rejected by Fusion.'),
               asu.RESULTS_UPDATED_DATE = SYSDATE, asu.LAST_UPDATED_DATE = SYSDATE
        WHERE  asu.RUN_ID = p_run_id AND asu.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
                       WHERE acs.RUN_ID = p_run_id
                       AND   acs.CUST_SITE_ORIG_SYS_REF = asu.CUST_SITE_ORIG_SYS_REF
                       AND   acs.TFM_STATUS = 'FAILED');

        -- ============================================================
        -- Sweep: any child row still GENERATED was sent to Fusion but not
        -- matched by the cascade (e.g. references a party outside this
        -- batch). Positive proof is impossible, so mark FAILED -- absence
        -- is never LOADED (Rule #1). Six static UPDATEs, one per child
        -- table (replaces the retired EXECUTE IMMEDIATE loop).
        -- ============================================================
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not matched by BIP reconciliation or cascade. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        l_sweep := l_sweep + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not matched by BIP reconciliation or cascade. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        l_sweep := l_sweep + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not matched by BIP reconciliation or cascade. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        l_sweep := l_sweep + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not matched by BIP reconciliation or cascade. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        l_sweep := l_sweep + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not matched by BIP reconciliation or cascade. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        l_sweep := l_sweep + SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not matched by BIP reconciliation or cascade. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        l_sweep := l_sweep + SQL%ROWCOUNT;

        -- Any party row still GENERATED (BIP report carried no row for it)
        -- is also unaccounted -> FAILED (Rule #1: absence is never LOADED).
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
        SET    TFM_STATUS = 'FAILED',
               ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Party not found in BIP reconciliation for this run. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';
        l_sweep := l_sweep + SQL%ROWCOUNT;

        -- No write-back to staging: the TFM row is the sole record of the
        -- Fusion outcome (design section 2). NO COMMIT -- the orchestrator
        -- controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete. Parties LOADED: ' || l_loaded ||
                         ', FAILED: ' || l_failed ||
                         ', not-reconciled (all tiers): ' || l_sweep || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id  => p_run_id,
                p_message => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH - orchestrates FETCH then PARSE.
    -- Public 3-arg signature unchanged: DMT_LOADER_PKG caller unaffected.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id          IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml  XMLTYPE;
        l_err  NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                         ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        FETCH_BIP_RESULTS(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            x_report_xml    => l_xml,
            x_error_code    => l_err,
            p_import_ess_id => p_import_ess_id);

        IF l_err != DMT_UTIL_PKG.C_SUCCESS THEN
            -- Route the failure: RECONCILE_BATCH's contract with the queue
            -- engine is exception-based, so a fetch failure raises and the
            -- work item fails loudly -- never a silent zero-row "success"
            -- (design section 5).
            RAISE_APPLICATION_ERROR(-20038,
                'RECONCILE_BATCH: FETCH_BIP_RESULTS failed for CEMLI ' ||
                C_CEMLI || ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml);

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id  => p_run_id,
                p_message => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_CUST_RESULTS_PKG;
/
