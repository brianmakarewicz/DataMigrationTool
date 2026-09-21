-- PACKAGE BODY DMT_CUST_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CUST_RESULTS_PKG" AS
-- ============================================================
-- DMT_CUST_RESULTS_PKG body
-- Customers BIP reconciliation (ONE object, seven HZ record types).
--
-- Contract v1 (design section 5, "BIP reconciliation report contract - v1"),
-- mirroring the proven Items reconciler (DMT_EGP_ITEM_RESULTS_PKG, PR #368):
--   * The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Customers
--     nine-column recon report over BIP (keyset paged, run-scoped) and RETURNS
--     the parsed rows -- no dynamic SQL, no TFM reference there.
--   * The APPLY here is STATIC SQL against the seven compile-time-known Customer
--     TFM tables, keyed on RECON_KEY = the report's RECORD_KEY. One report row =
--     one record type carrying OBJECT_TYPE + RECORD_KEY + SOURCE_TYPE +
--     FUSION_STATUS + FUSION_ID + ERROR_MESSAGE.
--
-- The ONLY path to LOADED is a BASE-tier row with FUSION_STATUS='SUCCESS' and a
-- non-null FUSION_ID (positive proof the record reached its Fusion base table).
-- FUSION_STATUS='ERROR' with a real ERROR_MESSAGE -> FAILED, message appended as
-- '[FUSION_ERROR] ' || message (never composed). Everything else (INTERFACE tier,
-- non-terminal) is left for the shared unaccounted sweep -- never fabricated.
--
-- There is NO parent->child cascade: the V2 report now covers all seven record
-- types on both BASE and INTERFACE tiers, so each record type is confirmed against
-- its own base id -- no fabricated cascade is needed.
--
-- Outcomes are written to the seven TFM tables only: nothing is written back to
-- staging; the TFM row is the sole record of the Fusion outcome (design section 2).
-- NO COMMIT -- the orchestrator controls transaction boundaries.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_CUST_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Customers';

    -- --------------------------------------------------------
    -- CONFIRM_REFERENCE_ROUNDTRIP (private)
    -- Backlog #12 round-trip proof for one just-LOADED party BASE row (TCA family
    -- template; mirrors DMT_GL_RESULTS_PKG / DMT_WORKER_RESULTS_PKG). For TCA the
    -- carrier is Slot A: PARTY_ORIG_SYSTEM_REFERENCE (= the run-prefixed reference
    -- the transform wrote) lands in the Fusion base table HZ_ORIG_SYS_REFERENCES
    -- (owner_table_name=HZ_PARTIES) and comes back on the recon report inside the
    -- Parties RECORD_KEY. So the proof is: the party reference the report returned
    -- equals the Slot A value the TFM row carries as PARTY_ORIG_SYSTEM_REFERENCE --
    -- the value we stamped survived to Fusion and returned unchanged. There is NO
    -- Slot C for TCA parties, so the full reference (BUILD_REF = DMT:run:wq:tfm) is
    -- logged for audit alongside the confirmed Slot A carrier. Diagnostic only: a
    -- mismatch or lookup miss logs WARN and NEVER alters the LOADED outcome
    -- (design section 7). Runs after the LOADED UPDATE so it never blocks accounting.
    -- --------------------------------------------------------
    PROCEDURE CONFIRM_REFERENCE_ROUNDTRIP (
        p_run_id     IN NUMBER,
        p_fusion_ref IN VARCHAR2,
        p_fusion_id  IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'CONFIRM_REFERENCE_ROUNDTRIP';
        l_slot_a   VARCHAR2(255);
        l_full_ref VARCHAR2(150);
    BEGIN
        -- Read the Slot A carrier and the full reference for the matched party TFM
        -- row. PARTY_ORIG_SYSTEM_REFERENCE is exactly what was written into the CSV
        -- as the party's OrigSystemReference (the reconciler's match key).
        SELECT PARTY_ORIG_SYSTEM_REFERENCE,
               DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
          INTO l_slot_a, l_full_ref
          FROM DMT_HZ_PARTIES_TFM_TBL
         WHERE RUN_ID = p_run_id AND PARTY_ORIG_SYSTEM_REFERENCE = p_fusion_ref
           AND ROWNUM = 1;

        IF p_fusion_ref IS NOT NULL AND p_fusion_ref = l_slot_a THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip OK for ORIG_SYSTEM_REFERENCE ' || p_fusion_ref ||
                ': Slot A returned from the base table '
                || '(HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE -> HZ_PARTIES, '
                || 'PARTY_ID=' || p_fusion_id || ') = ' || l_slot_a ||
                '. Full ref (audit, no Slot C for TCA): ' || l_full_ref || '.',
                'INFO', C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip MISMATCH for ORIG_SYSTEM_REFERENCE ' ||
                NVL(p_fusion_ref, '(null)') || ': expected Slot A=' || l_slot_a || '.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Round-trip proof is diagnostic only; a lookup miss must never swallow
            -- silently (design section 7) nor alter the LOADED outcome.
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip: no party TFM row found for ORIG_SYSTEM_REFERENCE ' ||
                NVL(p_fusion_ref, '(null)') || ' (proof skipped).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
    END CONFIRM_REFERENCE_ROUNDTRIP;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_CUSTOMERS (private)
    -- The Contract v1 base-tier positive proof for Customers (design section 5,
    -- Option A shape), copied from DMT_EGP_ITEM_RESULTS_PKG.APPLY_CONTRACT_V1_ITEMS,
    -- with the Customers twist: Customers carries SEVEN record types in ONE object,
    -- so this APPLY dispatches by OBJECT_TYPE to one of seven TFM tables from the
    -- ONE report:
    --   Customers.Parties         -> DMT_HZ_PARTIES_TFM_TBL         (FUSION_PARTY_ID)
    --   Customers.Locations       -> DMT_HZ_LOCATIONS_TFM_TBL       (FUSION_LOCATION_ID)
    --   Customers.PartySites      -> DMT_HZ_PARTY_SITES_TFM_TBL     (FUSION_PARTY_SITE_ID)
    --   Customers.PartySiteUses   -> DMT_HZ_PARTY_SITE_USES_TFM_TBL (FUSION_PARTY_SITE_USE_ID)
    --   Customers.Accounts        -> DMT_HZ_ACCOUNTS_TFM_TBL        (FUSION_CUST_ACCOUNT_ID)
    --   Customers.AccountSites    -> DMT_HZ_ACCT_SITES_TFM_TBL      (FUSION_CUST_ACCT_SITE_ID)
    --   Customers.AccountSiteUses -> DMT_HZ_ACCT_SITE_USES_TFM_TBL  (FUSION_SITE_USE_ID)
    --
    -- The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Customers
    -- nine-column recon report over BIP (keyset paged, run-prefix scoped) and returns
    -- the parsed rows -- no dynamic SQL, no TFM reference there. The APPLY here is
    -- STATIC SQL against the compile-time-known seven Customer TFM tables:
    --   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID into the
    --       record type's Fusion-id column. The ONLY path to LOADED.
    --   * FUSION_STATUS = ERROR with a real message -> FAILED, message appended as
    --       '[FUSION_ERROR] ' || message (never composed).
    --   * everything else (INTERFACE/SUCCESS, corroborating only; non-terminal) is
    --       left for the shared unaccounted sweep. Never fabricate an outcome.
    -- Match is on RECON_KEY = the report's RECORD_KEY (see the RECON_KEY stamps in
    -- DMT_CUST_TRANSFORM_PKG). Rows already terminal (LOADED/FAILED) are never
    -- touched, so this runs safely and idempotently.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_CUSTOMERS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_CUSTOMERS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;
    BEGIN
        -- Generated-row count across all SEVEN Customer TFM tables (static, this
        -- object's own tables) drives the shared fetch's keyset page-count cap.
        SELECT (SELECT COUNT(*) FROM DMT_HZ_PARTIES_TFM_TBL         WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_HZ_LOCATIONS_TFM_TBL       WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_HZ_PARTY_SITES_TFM_TBL     WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_HZ_PARTY_SITE_USES_TFM_TBL WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_HZ_ACCOUNTS_TFM_TBL        WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_HZ_ACCT_SITES_TFM_TBL      WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_HZ_ACCT_SITE_USES_TFM_TBL  WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   DUAL;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => TO_NUMBER(p_request_id),
            p_import_ess_id => NULL,
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20038,
                C_PROC || ': Contract v1 fetch failed for Customers '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the shared unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Customers recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc := 0;

                -- ---- Parties --------------------------------------------------
                IF l_rows(i).OBJECT_TYPE = 'Customers.Parties' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_HZ_PARTIES_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PARTY_ID      = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_loaded := l_loaded + l_rc;
                        -- Backlog #12 round-trip proof for a just-LOADED party; the
                        -- Slot A carrier is the reference embedded in RECORD_KEY after
                        -- the 'Customers.Parties~' prefix. Diagnostic only.
                        IF l_rc > 0 THEN
                            CONFIRM_REFERENCE_ROUNDTRIP(
                                p_run_id     => p_run_id,
                                p_fusion_ref => SUBSTR(l_rows(i).RECORD_KEY,
                                                       INSTR(l_rows(i).RECORD_KEY, '~') + 1),
                                p_fusion_id  => l_rows(i).FUSION_ID);
                        END IF;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_HZ_PARTIES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL; -- INTERFACE/SUCCESS or non-terminal: leave for the sweep.
                    END IF;

                -- ---- Locations ------------------------------------------------
                ELSIF l_rows(i).OBJECT_TYPE = 'Customers.Locations' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_HZ_LOCATIONS_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_LOCATION_ID   = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_HZ_LOCATIONS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL;
                    END IF;

                -- ---- Party Sites ----------------------------------------------
                ELSIF l_rows(i).OBJECT_TYPE = 'Customers.PartySites' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_HZ_PARTY_SITES_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PARTY_SITE_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_HZ_PARTY_SITES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL;
                    END IF;

                -- ---- Party Site Uses ------------------------------------------
                ELSIF l_rows(i).OBJECT_TYPE = 'Customers.PartySiteUses' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_HZ_PARTY_SITE_USES_TFM_TBL
                        SET    TFM_STATUS               = 'LOADED',
                               FUSION_PARTY_SITE_USE_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE     = SYSDATE,
                               LAST_UPDATED_DATE        = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_HZ_PARTY_SITE_USES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL;
                    END IF;

                -- ---- Accounts -------------------------------------------------
                ELSIF l_rows(i).OBJECT_TYPE = 'Customers.Accounts' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_HZ_ACCOUNTS_TFM_TBL
                        SET    TFM_STATUS             = 'LOADED',
                               FUSION_CUST_ACCOUNT_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE   = SYSDATE,
                               LAST_UPDATED_DATE      = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_HZ_ACCOUNTS_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL;
                    END IF;

                -- ---- Account Sites --------------------------------------------
                ELSIF l_rows(i).OBJECT_TYPE = 'Customers.AccountSites' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_HZ_ACCT_SITES_TFM_TBL
                        SET    TFM_STATUS               = 'LOADED',
                               FUSION_CUST_ACCT_SITE_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE     = SYSDATE,
                               LAST_UPDATED_DATE        = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_HZ_ACCT_SITES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL;
                    END IF;

                -- ---- Account Site Uses ----------------------------------------
                ELSIF l_rows(i).OBJECT_TYPE = 'Customers.AccountSiteUses' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        UPDATE DMT_HZ_ACCT_SITE_USES_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_SITE_USE_ID   = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_loaded := l_loaded + SQL%ROWCOUNT;
                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_HZ_ACCT_SITE_USES_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL;
                    END IF;

                ELSE
                    NULL; -- Unknown OBJECT_TYPE: leave for the sweep (never fabricate).
                END IF;
            END LOOP;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_CUSTOMERS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH - Contract v1 recon for Customers.
    -- Public 4-arg signature unchanged (pipeline def calls
    -- DMT_CUST_RESULTS_PKG.RECONCILE_BATCH). Delegates to the shared fetch +
    -- static per-object APPLY. No COMMIT (orchestrator owns the transaction).
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id          IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id  => p_run_id,
            p_message => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                         ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- Contract v1 base-tier positive proof: the shared fetch returns the
        -- nine-column recon report rows and the APPLY is STATIC SQL against this
        -- object's seven TFM tables, keyed on RECON_KEY. This is the ONLY path to
        -- LOADED (a real base-table row). The load ESS id feeds the report's
        -- LOAD_REQUEST_ID for traceability; run-scoped selection is by the stamped
        -- prefix (see the report DM header). Rows already terminal are untouched.
        APPLY_CONTRACT_V1_CUSTOMERS(
            p_run_id     => p_run_id,
            p_request_id => TO_CHAR(NVL(p_import_ess_id, p_load_ess_id)));

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
