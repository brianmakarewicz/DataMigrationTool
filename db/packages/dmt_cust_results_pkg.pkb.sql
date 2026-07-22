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
    -- PARSE_AND_UPDATE  (two-tier, fail-CLOSED -- Rule #1)
    -- Reads the Contract v1 report rows under /DATA_DS/G_1. Each row is
    -- one record type keyed by ORIG_SYSTEM_REFERENCE, carrying either a
    -- FUSION_ID (positive proof the record landed in the Fusion BASE
    -- table, from HZ_ORIG_SYS_REFERENCES) or an ERROR_MESSAGE (the row
    -- was rejected by Fusion, from HZ_IMP_ERRORS).
    --
    -- A TFM row is marked LOADED ONLY when a report row for its record
    -- type carries a non-null FUSION_ID for its ORIG_SYSTEM_REFERENCE --
    -- that FUSION_ID is stored in the record type's own FUSION_*_ID
    -- column. A TFM row is marked FAILED when a report row carries error
    -- text. There is NO interface-status path and NO parent->child
    -- cascade: every record type is confirmed against its own base id,
    -- so a GOOD row without a base id is never LOADED and a BAD row is
    -- never presumed loaded from a NULL interface status.
    --
    -- Any TFM row still GENERATED after the report is applied (no base id
    -- AND no error text) is unaccounted -> swept to FAILED with a
    -- reconciliation error (absence is never LOADED). Seven TFM tables
    -- only; nothing is written back to staging. NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id          IN NUMBER,
        p_report_xml      IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_loaded NUMBER := 0;
        l_failed NUMBER := 0;
        l_rc     NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- NULL report = BIP returned 0 rows from both tiers. We could determine
        -- neither a base-table LOADED nor a real Fusion per-record error, so we
        -- do NOT fabricate a FAILED (no absence=LOADED either). The GENERATED
        -- rows across all seven tables are left as-is (unaccounted); the
        -- accounting gate reports the object not-DONE and the funnel surfaces
        -- them as unreconciled.
        IF p_report_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id  => p_run_id,
                p_message => C_PROC || ': BIP report returned zero rows. ' ||
                             'GENERATED rows left unaccounted (not marked FAILED).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        -- Apply the two-tier report. One pass over the decoded rows;
        -- each row dispatches by RECORD_TYPE to the matching TFM table.
        -- FUSION_ID present  => LOADED, store the record type's own base id.
        -- ERROR_MESSAGE only => FAILED with the Fusion reject text.
        -- The base (LOADED) row wins over an error row for the same key
        -- because the LOADED UPDATE and the FAILED UPDATE both guard on
        -- TFM_STATUS NOT IN ('LOADED','FAILED'); processing the report so
        -- that any base row's LOADED is not overwritten by a later error
        -- row is guaranteed by that guard, whichever order they arrive.
        FOR r IN (
            SELECT x.record_type,
                   x.orig_system_reference,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING p_report_xml
                COLUMNS
                    record_type           VARCHAR2(30)   PATH 'RECORD_TYPE',
                    orig_system_reference VARCHAR2(255)  PATH 'ORIG_SYSTEM_REFERENCE',
                    fusion_id             VARCHAR2(30)   PATH 'FUSION_ID',
                    error_msg             VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            -- SQL%ROWCOUNT is captured on the line immediately after each
            -- individual UPDATE (never after END CASE -- a CASE is a control
            -- structure, so after its ELSE NULL branch SQL%ROWCOUNT would be
            -- stale from a prior iteration).
            l_rc := 0;
            IF r.fusion_id IS NOT NULL THEN
                -- Positive proof: the record landed in its Fusion BASE table.
                CASE r.record_type
                WHEN 'Parties' THEN
                    UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                    SET TFM_STATUS='LOADED', FUSION_PARTY_ID=TO_NUMBER(r.fusion_id),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND PARTY_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'Locations' THEN
                    UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL
                    SET TFM_STATUS='LOADED', FUSION_LOCATION_ID=TO_NUMBER(r.fusion_id),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND LOCATION_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'PartySites' THEN
                    UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL
                    SET TFM_STATUS='LOADED', FUSION_PARTY_SITE_ID=TO_NUMBER(r.fusion_id),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND SITE_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'PartySiteUses' THEN
                    -- INTERIM KEY (2026-07-21, run234_Customers findings): the site
                    -- use's own SITEUSE_ORIG_SYSTEM_REF is written NULL into Fusion, so
                    -- the report cannot key on it. Match on the parent site reference +
                    -- site_use_type pair the report emits as ORIG_SYSTEM_REFERENCE
                    -- (SITE_ORIG_SYSTEM_REFERENCE || '/' || SITE_USE_TYPE). Both columns
                    -- are present on every TFM row and the pair is unique per run
                    -- prefix, so no wrong-row match.
                    UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL
                    SET TFM_STATUS='LOADED', FUSION_PARTY_SITE_USE_ID=TO_NUMBER(r.fusion_id),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id
                    AND SITE_ORIG_SYSTEM_REFERENCE||'/'||SITE_USE_TYPE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'Accounts' THEN
                    UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL
                    SET TFM_STATUS='LOADED', FUSION_CUST_ACCOUNT_ID=TO_NUMBER(r.fusion_id),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND CUST_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'AccountSites' THEN
                    UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL
                    SET TFM_STATUS='LOADED', FUSION_CUST_ACCT_SITE_ID=TO_NUMBER(r.fusion_id),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND CUST_SITE_ORIG_SYS_REF=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'AccountSiteUses' THEN
                    UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL
                    SET TFM_STATUS='LOADED', FUSION_SITE_USE_ID=TO_NUMBER(r.fusion_id),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND CUST_SITEUSE_ORIG_SYS_REF=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                ELSE NULL;
                END CASE;
                l_loaded := l_loaded + l_rc;

            ELSIF r.error_msg IS NOT NULL THEN
                -- Mechanism 2 (two-location read), DRAFT 2026-07-22.
                -- The V2 data model emits, per record type, that interface row's own
                -- outcome from IMPORT_STATUS_CODE (S=created -> NULL here; E=rejected,
                -- W=held -> a real "not created in base -- interface status 'X'"
                -- message with the batch-level HZ_IMP_ERRORS.MESSAGE_NAME appended as
                -- context). This is the row's own Fusion-recorded outcome, so it is
                -- tagged [INTERFACE_ERROR]. APPEND_ERROR keeps ERROR_TEXT append-only,
                -- so if the import-report pass already wrote an error the two
                -- concatenate. Handle all seven record types so no real interface
                -- status is ever discarded.
                CASE r.record_type
                WHEN 'Parties' THEN
                    UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[INTERFACE_ERROR] '||r.error_msg),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND PARTY_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'Locations' THEN
                    UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[INTERFACE_ERROR] '||r.error_msg),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND LOCATION_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'PartySites' THEN
                    UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[INTERFACE_ERROR] '||r.error_msg),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND SITE_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'PartySiteUses' THEN
                    -- INTERIM KEY (2026-07-21): same parent-ref + site_use_type key as
                    -- the base tier above, so W/E interface rows attribute to the right
                    -- TFM row instead of sweeping to UNACCOUNTED.
                    UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[INTERFACE_ERROR] '||r.error_msg),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id
                    AND SITE_ORIG_SYSTEM_REFERENCE||'/'||SITE_USE_TYPE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'Accounts' THEN
                    UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[INTERFACE_ERROR] '||r.error_msg),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND CUST_ORIG_SYSTEM_REFERENCE=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'AccountSites' THEN
                    UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[INTERFACE_ERROR] '||r.error_msg),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND CUST_SITE_ORIG_SYS_REF=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                WHEN 'AccountSiteUses' THEN
                    UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL
                    SET TFM_STATUS='FAILED',
                        ERROR_TEXT=DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,'[INTERFACE_ERROR] '||r.error_msg),
                        RESULTS_UPDATED_DATE=SYSDATE, LAST_UPDATED_DATE=SYSDATE
                    WHERE RUN_ID=p_run_id AND CUST_SITEUSE_ORIG_SYS_REF=r.orig_system_reference
                    AND TFM_STATUS NOT IN ('LOADED','FAILED');
                    l_rc := SQL%ROWCOUNT;
                ELSE NULL;
                END CASE;
                l_failed := l_failed + l_rc;
            END IF;
        END LOOP;

        -- ================================================================
        -- Mechanism 1 — SAME-FBDI parent/child cascade (DMT_DESIGN.html §5
        -- "Cascade to children" + the [FUSION_ERROR] tag rule). DRAFT 2026-07-22.
        --
        -- Within the one Customers FBDI the HZ records form a hierarchy:
        --   Party Site  --(SITE_ORIG_SYSTEM_REFERENCE)-->  Party Site Use
        --   Account Site --(CUST_SITE_ORIG_SYS_REF)----->  Account Site Use
        -- A child still GENERATED (neither base-confirmed LOADED nor given its OWN
        -- interface error above) inherits its directly-linked parent's outcome ONLY
        -- when that parent is FAILED and carries a REAL error string. The single
        -- permitted composed form (§5) is the fixed prefix
        --   '[FUSION_ERROR]The parent record has the following Fusion error: '
        -- followed by the parent's real ERROR_TEXT, and the parent's key for source
        -- attribution. If the parent has no real error, the child STAYS GENERATED and
        -- the shared sweep marks it [UNACCOUNTED] -- never a generic "parent failed".
        --
        -- This resolves run-240 G1: party site 10121RT-PSITE-G1 is FAILED (held/
        -- rejected at the interface), so its two child site uses inherit that exact
        -- interface finding instead of sweeping to UNACCOUNTED.
        -- ================================================================
        -- Party Site Uses inherit from their parent Party Site.
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL u
        SET    u.TFM_STATUS = 'FAILED',
               u.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(u.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: '
                   || (SELECT p.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.SITE_ORIG_SYSTEM_REFERENCE = u.SITE_ORIG_SYSTEM_REFERENCE
                       AND   p.TFM_STATUS = 'FAILED'
                       AND   p.ERROR_TEXT IS NOT NULL
                       AND   ROWNUM = 1)
                   || ' (via parent party site ' || u.SITE_ORIG_SYSTEM_REFERENCE || ')'),
               u.RESULTS_UPDATED_DATE = SYSDATE, u.LAST_UPDATED_DATE = SYSDATE
        WHERE  u.RUN_ID = p_run_id
        AND    u.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.SITE_ORIG_SYSTEM_REFERENCE = u.SITE_ORIG_SYSTEM_REFERENCE
                       AND   p.TFM_STATUS = 'FAILED'
                       AND   p.ERROR_TEXT IS NOT NULL);

        -- Account Site Uses inherit from their parent Account Site.
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL u
        SET    u.TFM_STATUS = 'FAILED',
               u.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(u.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: '
                   || (SELECT p.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.CUST_SITE_ORIG_SYS_REF = u.CUST_SITE_ORIG_SYS_REF
                       AND   p.TFM_STATUS = 'FAILED'
                       AND   p.ERROR_TEXT IS NOT NULL
                       AND   ROWNUM = 1)
                   || ' (via parent account site ' || u.CUST_SITE_ORIG_SYS_REF || ')'),
               u.RESULTS_UPDATED_DATE = SYSDATE, u.LAST_UPDATED_DATE = SYSDATE
        WHERE  u.RUN_ID = p_run_id
        AND    u.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL p
                       WHERE p.RUN_ID = p_run_id
                       AND   p.CUST_SITE_ORIG_SYS_REF = u.CUST_SITE_ORIG_SYS_REF
                       AND   p.TFM_STATUS = 'FAILED'
                       AND   p.ERROR_TEXT IS NOT NULL);

        -- (No absence-!=-LOADED sweep: a record neither confirmed LOADED nor given
        -- a real Fusion error is left GENERATED (unaccounted) — no fabricated FAILED.)

        -- No write-back to staging: the TFM row is the sole record of the
        -- Fusion outcome (design section 2). NO COMMIT -- the orchestrator
        -- controls transaction boundaries.

        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' complete. LOADED (base-confirmed): ' || l_loaded ||
                         ', FAILED (Fusion reject): ' || l_failed || '.',
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
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
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

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

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
