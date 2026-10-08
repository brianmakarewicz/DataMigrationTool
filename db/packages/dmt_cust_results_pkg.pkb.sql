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
-- The APPLY has NO parent->child cascade: the report covers all seven record
-- types on both BASE and INTERFACE tiers, so each record is confirmed against its
-- own base id or its own interface row. Held rows are handled afterwards by
-- PROPAGATE_DOCUMENT_ERRORS, which only ever quotes a real error.
--
-- Per-row error attribution (V6 report, DMT_CUST_RECON_V6_DM): an INTERFACE/ERROR
-- row is returned ONLY when the interface row has its OWN Fusion error -- its
-- HZ_IMP_ERRORS rows joined on error_id + batch_id, full text resolved from
-- FND_NEW_MESSAGES with tokens, e.g.
-- 'HZ_IMP_INVAL_VALUE_COMPARE: The value in the SET_CODE column isn't valid...'.
-- That is a real Fusion error for that record, so this APPLY marks the row FAILED
-- with '[FUSION_ERROR] ' || message. A row Fusion held or rejected with no error of
-- its own is not in the report at all, so it stays GENERATED; PROPAGATE_DOCUMENT_ERRORS
-- quotes the real error of the row that held it back, and if there is none the shared
-- sweep marks it UNACCOUNTED (V3 composed a status-code sentence for such rows and it was
-- stamped [FUSION_ERROR] with no real error behind it -- removed). An ERROR row that
-- arrives with no message (a report defect, never expected from V6) is logged as a
-- WARN and left for the sweep -- never given a fabricated verdict.
--
-- Outcomes are written to the seven TFM tables only: nothing is written back to
-- staging; the TFM row is the sole record of the Fusion outcome (design section 2).
-- NO COMMIT -- the orchestrator controls transaction boundaries.
--
-- After the per-row apply, PROPAGATE_DOCUMENT_ERRORS quotes each rejected row's
-- real Fusion error onto the rows Fusion held back with it but wrote no error for
-- (design section 5, whole-document rejection). The hold directions are the ones
-- Fusion's own HZ_IMP_*_T statuses show; see that procedure.
--
-- REVISIONS:
--   2026-10-07  BM  Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS).
--   2026-10-07  BM  V6 report: base rows by the Fusion batch id this load sent.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_CUST_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Customers';

    -- Cross-grain propagation (PROPAGATE_DOCUMENT_ERRORS).
    -- Working set: "the row TARGET_SEQ of record type TARGET_KIND was held back
    -- with a row that has its own real Fusion error, so it must carry
    -- QUOTED_ERROR". TARGET_KIND is one of PARTY, PSITE, PSU, ACCT, ASITE, ASU
    -- (locations are never part of a customer document).
    TYPE T_DOC_PAIR IS RECORD (
        TARGET_KIND  VARCHAR2(10),
        TARGET_SEQ   NUMBER,           -- TFM_SEQUENCE_ID in the target's own table
        QUOTED_ERROR VARCHAR2(4000)    -- DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(...)
    );
    TYPE T_DOC_PAIR_TBL IS TABLE OF T_DOC_PAIR;

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
    -- RESOLVE_SENT_BATCH_ID (private)
    -- The Fusion import batch id the load being reconciled sent (owner decision
    -- 2026-10-07): the TFM BATCH_ID the transform stamped (run prefix followed by
    -- the source batch id) and the generator wrote into every HZ CSV. Fusion copies
    -- it into REQUEST_ID on every HZ base row, and the V6 report selects base rows
    -- by an exact match on it (P_FUSION_BATCH_ID).
    --
    -- RUN_CUSTOMERS generates, loads and reconciles one batch at a time, so the
    -- batch of this load is the batch of the most recently generated customer FBDI
    -- of the work item (the highest parties FBDI_CSV_ID; parties is the primary CSV
    -- and is in every customer zip). A reconcile-only rerun of the work item uses the
    -- last load's ids recorded on the queue row, which are that same batch's.
    -- NULL when nothing was sent: the report then selects no base rows and the rows
    -- stay for the unaccounted sweep (never a fabricated outcome). Static SQL.
    -- --------------------------------------------------------
    PROCEDURE RESOLVE_SENT_BATCH_ID (
        p_run_id        IN  NUMBER,
        p_work_queue_id IN  NUMBER,
        x_batch_id      OUT NUMBER
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'RESOLVE_SENT_BATCH_ID';
        l_batches NUMBER;
    BEGIN
        x_batch_id := NULL;

        SELECT COUNT(DISTINCT BATCH_ID)
        INTO   l_batches
        FROM   DMT_HZ_PARTIES_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    FBDI_CSV_ID IS NOT NULL
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);

        IF l_batches = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': no customer rows of this work item were sent; '
                               || 'no Fusion batch id to select base rows by.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RETURN;
        END IF;

        SELECT BATCH_ID
        INTO   x_batch_id
        FROM   DMT_HZ_PARTIES_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    FBDI_CSV_ID IS NOT NULL
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id)
        ORDER BY FBDI_CSV_ID DESC, TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ': Fusion batch id ' || TO_CHAR(x_batch_id, 'TM9')
                           || ' (batches sent by this work item: ' || l_batches || ').',
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
    END RESOLVE_SENT_BATCH_ID;

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
    -- nine-column recon report over BIP (keyset paged; base rows selected by the
    -- Fusion batch id this load sent, interface rows by the load request id) and
    -- returns the parsed rows -- no dynamic SQL, no TFM reference there. The APPLY here is
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
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_CUSTOMERS';
        l_gen_count NUMBER := 0;
        l_batch_id  NUMBER;          -- the Fusion import batch id this load sent
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
        l_no_msg    NUMBER := 0;     -- ERROR rows the report sent with no message
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

        -- The report's INTERFACE tier filters HZ_IMP_*_T on
        -- load_request_id = :P_LOAD_REQUEST_ID, and those interface rows carry the
        -- LOAD ESS request id (InterfaceLoaderController), NOT the import ess id. So
        -- P_LOAD_REQUEST_ID must be the load ess id or the INTERFACE tier matches
        -- nothing and held/rejected records (import_status_code W/E) never come back.
        -- The BASE tier selects by REQUEST_ID = :P_FUSION_BATCH_ID: the HZ base
        -- tables carry the bulk import batch id there, not an ESS request id.
        RESOLVE_SENT_BATCH_ID(
            p_run_id        => p_run_id,
            p_work_queue_id => p_work_queue_id,
            x_batch_id      => l_batch_id);

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code      => C_CEMLI,
            p_run_id          => p_run_id,
            p_load_ess_id     => p_load_ess_id,
            p_import_ess_id   => p_import_ess_id,
            p_row_cap         => l_gen_count,
            x_rows            => l_rows,
            x_error_code      => l_err_code,
            p_fusion_batch_id => l_batch_id);

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
                l_rc   := 0;
                l_tier := NULL;  -- backlog #65: reset per row (audit-log safety)

                -- The V6 report returns an ERROR row only with the record's own
                -- HZ_IMP_ERRORS text. If one ever arrives without a message, say so loudly
                -- and leave the record for the sweep -- never invent a verdict.
                IF l_rows(i).FUSION_STATUS = 'ERROR' AND l_rows(i).ERROR_MESSAGE IS NULL THEN
                    l_no_msg := l_no_msg + 1;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        C_PROC || ': report ERROR row has no ERROR_MESSAGE for '
                        || l_rows(i).RECORD_KEY || ' (' || l_rows(i).SOURCE_TYPE
                        || '); left for the unaccounted sweep.',
                        DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
                END IF;

                -- ---- Parties --------------------------------------------------
                IF l_rows(i).OBJECT_TYPE = 'Customers.Parties' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Backlog #65 three-tier match (owner order on PR #481). Tier 1
                        -- is the stamped Slot A reference (RECON_KEY = RECORD_KEY, as
                        -- before). Only if tier 1 matches NO TFM row do we fall through:
                        -- tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing
                        -- segment of DFF_KEY) -- Customers carry NO DFF carrier so
                        -- DFF_KEY is null and tier 2 is skipped -- and then tier 3 (the
                        -- business key: PARTY_ORIG_SYSTEM_REFERENCE = BUSINESS_KEY, the
                        -- native orig-system reference the report returns as SOURCE_REF).
                        -- Every tier-1 hit short-circuits, so loaded outcomes are
                        -- identical to before. Static UPDATEs.
                        UPDATE DMT_HZ_PARTIES_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PARTY_ID      = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_HZ_PARTIES_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_PARTY_ID      = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_HZ_PARTIES_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_PARTY_ID      = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    PARTY_ORIG_SYSTEM_REFERENCE = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED party via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). PARTY_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
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
                           || ' | FAILED: ' || l_failed
                           || ' | ERROR rows without message: ' || l_no_msg || '.',
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
    -- PROPAGATE_DOCUMENT_ERRORS (private)
    -- Design section 5, "Whole-document rejection carries the real error to every
    -- grain" (decided 2026-10-07). The customer bulk import (BulkImportJob) does
    -- not reject a customer as one flat document: it HOLDS rows at import status
    -- W, with no HZ_IMP_ERRORS row of their own, when a related row fails. Which
    -- rows it holds was read from Fusion, not assumed: every HZ_IMP_*_T row of the
    -- 44 DMT loads in import batch 5001 (load request ids 9971978 .. 10070462,
    -- runs 236 / 238 included), comparing each row's status with the status of
    -- the rows it references (objects/Customers/README.md, "Cross-grain error
    -- propagation"):
    --   * A party site use with its own error holds its WHOLE party: the party,
    --     every party site, party site use, account, account site and account
    --     site use of that party went to W (43 of 43 parties that had a failed
    --     party site use and no error of their own; no party was ever held
    --     without one). The location is not held (it loads).
    --   * A party with its own error: none of its rows were created (2 of 2).
    --   * A party site with its own error: its party site uses and the account
    --     sites on it were not created (4 of 4).
    --   * An account with its own error: its account sites were not created
    --     (86 of 86; 2 held at W with no error of their own).
    --   * An account site with its own error: its account site uses were held
    --     at W (86 of 86).
    --   * Nothing else propagates. A failed account never held its party (84
    --     parties S beside a failed account); a failed account site never held
    --     its party site (86 S) or its account (2 S); a location is never part
    --     of a customer's document.
    -- So the document of a failed row is:
    --   party / party site use  -> its whole party tree (scope PARTY);
    --   party site              -> its party site uses and account sites (PSITE);
    --   account                 -> its account sites (ACCT);
    --   account site            -> its account site uses (ASITE);
    -- where an account site belongs to a party through its account OR through its
    -- party site, and an account site use belongs wherever its account site does.
    --
    -- Sources: rows of this run and work item with TFM_STATUS = 'FAILED' carrying
    --   their OWN real Fusion error -- ERROR_TEXT contains '[FUSION_ERROR]' and
    --   does NOT contain C_DOC_ERROR_MARKER (a quote is never re-quoted).
    -- Targets: every OTHER row in the source's scope that Fusion received
    --   (FBDI_CSV_ID stamped at generation, not STAGED), that is not LOADED (LOADED
    --   rows are never touched) and that does not already carry the exact quote.
    --   The quote is appended (APPEND_ERROR, never overwrite) and the row set
    --   FAILED. A held row with no failed row in its scope is untouched -- it falls
    --   to the shared UNACCOUNTED sweep.
    -- Idempotent: the "already carries the exact quote" guard means a second
    --   reconcile pass adds nothing.
    -- One collection of (target, quote) pairs is built by ONE static SELECT, then
    -- ONE static bulk UPDATE (FORALL) per target table: a MERGE cannot read a
    -- PL/SQL record collection through TABLE() (ORA-00902, AR run 248). NO
    -- dynamic SQL; NO COMMIT (caller owns the txn).
    -- --------------------------------------------------------
    PROCEDURE PROPAGATE_DOCUMENT_ERRORS (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PROPAGATE_DOCUMENT_ERRORS';
        C_TAG    CONSTANT VARCHAR2(20) := '[FUSION_ERROR]';
        l_marker VARCHAR2(30) := DMT_UTIL_PKG.C_DOC_ERROR_MARKER;
        l_pairs  T_DOC_PAIR_TBL;
        l_pty    NUMBER := 0;
        l_psite  NUMBER := 0;
        l_psu    NUMBER := 0;
        l_acct   NUMBER := 0;
        l_asite  NUMBER := 0;
        l_asu    NUMBER := 0;
        l_step   VARCHAR2(200);
    BEGIN
        l_step := 'collecting held rows and the real errors that held them for run ' || p_run_id;
        -- Work-item scope on every table, as the shared sweep scopes it: rows
        -- stamped with another work item are excluded; unstamped rows are
        -- run-scoped.
        WITH pty AS (
            SELECT t.TFM_SEQUENCE_ID seq, t.RECON_KEY rkey, t.TFM_STATUS st, t.ERROR_TEXT et,
                   t.PARTY_ORIG_SYSTEM_REFERENCE party_ref
            FROM   DMT_HZ_PARTIES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
        ),
        psite AS (
            SELECT t.TFM_SEQUENCE_ID seq, t.RECON_KEY rkey, t.TFM_STATUS st, t.ERROR_TEXT et,
                   t.PARTY_ORIG_SYSTEM_REFERENCE party_ref, t.SITE_ORIG_SYSTEM_REFERENCE psite_ref
            FROM   DMT_HZ_PARTY_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
        ),
        psu AS (
            SELECT t.TFM_SEQUENCE_ID seq, t.RECON_KEY rkey, t.TFM_STATUS st, t.ERROR_TEXT et,
                   -- The site use names its party; when it does not, its party
                   -- site does.
                   COALESCE(t.PARTY_ORIG_SYSTEM_REFERENCE,
                            (SELECT MAX(s.party_ref) FROM psite s
                             WHERE  s.psite_ref = t.SITE_ORIG_SYSTEM_REFERENCE)) party_ref,
                   t.SITE_ORIG_SYSTEM_REFERENCE psite_ref
            FROM   DMT_HZ_PARTY_SITE_USES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
        ),
        acct AS (
            SELECT t.TFM_SEQUENCE_ID seq, t.RECON_KEY rkey, t.TFM_STATUS st, t.ERROR_TEXT et,
                   t.PARTY_ORIG_SYSTEM_REFERENCE party_ref, t.CUST_ORIG_SYSTEM_REFERENCE acct_ref
            FROM   DMT_HZ_ACCOUNTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
        ),
        asite AS (
            -- An account site belongs to the party of its account (party_ref)
            -- and to the party of its party site (party_ref_s); they differ only
            -- when the source data does.
            SELECT t.TFM_SEQUENCE_ID seq, t.RECON_KEY rkey, t.TFM_STATUS st, t.ERROR_TEXT et,
                   (SELECT MAX(a.party_ref) FROM acct a
                    WHERE  a.acct_ref = t.CUST_ORIG_SYSTEM_REFERENCE) party_ref,
                   (SELECT MAX(s.party_ref) FROM psite s
                    WHERE  s.psite_ref = t.SITE_ORIG_SYSTEM_REFERENCE) party_ref_s,
                   t.SITE_ORIG_SYSTEM_REFERENCE psite_ref,
                   t.CUST_ORIG_SYSTEM_REFERENCE acct_ref,
                   t.CUST_SITE_ORIG_SYS_REF     asite_ref
            FROM   DMT_HZ_ACCT_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
        ),
        asite_dim AS (
            SELECT asite_ref, MAX(party_ref) party_ref, MAX(party_ref_s) party_ref_s,
                   MAX(psite_ref) psite_ref, MAX(acct_ref) acct_ref
            FROM   asite
            GROUP BY asite_ref
        ),
        asu AS (
            -- An account site use belongs wherever its account site belongs.
            SELECT t.TFM_SEQUENCE_ID seq, t.RECON_KEY rkey, t.TFM_STATUS st, t.ERROR_TEXT et,
                   d.party_ref, d.party_ref_s, d.psite_ref, d.acct_ref,
                   t.CUST_SITE_ORIG_SYS_REF asite_ref
            FROM   DMT_HZ_ACCT_SITE_USES_TFM_TBL t
            LEFT JOIN asite_dim d ON d.asite_ref = t.CUST_SITE_ORIG_SYS_REF
            WHERE  t.RUN_ID = p_run_id
            AND    (p_work_queue_id IS NULL OR t.WORK_QUEUE_ID IS NULL
                    OR t.WORK_QUEUE_ID = p_work_queue_id)
        ),
        -- Every customer row of the work item in one shape: its kind, its own
        -- outcome, and the references that place it in a document.
        node AS (
            SELECT 'PARTY' kind, 'party' grain, seq, rkey, st, et,
                   party_ref, CAST(NULL AS VARCHAR2(255)) party_ref_s,
                   CAST(NULL AS VARCHAR2(255)) psite_ref, CAST(NULL AS VARCHAR2(255)) acct_ref,
                   CAST(NULL AS VARCHAR2(255)) asite_ref
            FROM   pty
            UNION ALL
            SELECT 'PSITE', 'party site', seq, rkey, st, et,
                   party_ref, NULL, psite_ref, NULL, NULL
            FROM   psite
            UNION ALL
            SELECT 'PSU', 'party site use', seq, rkey, st, et,
                   party_ref, NULL, psite_ref, NULL, NULL
            FROM   psu
            UNION ALL
            SELECT 'ACCT', 'account', seq, rkey, st, et,
                   party_ref, NULL, NULL, acct_ref, NULL
            FROM   acct
            UNION ALL
            SELECT 'ASITE', 'account site', seq, rkey, st, et,
                   party_ref, party_ref_s, psite_ref, acct_ref, asite_ref
            FROM   asite
            UNION ALL
            SELECT 'ASU', 'account site use', seq, rkey, st, et,
                   party_ref, party_ref_s, psite_ref, acct_ref, asite_ref
            FROM   asu
        ),
        -- A row with its own real Fusion error, the scope of rows Fusion holds
        -- back with it (see the header), and its error in the shared quote format.
        src AS (
            SELECT n.kind, n.seq,
                   CASE n.kind
                       WHEN 'PARTY' THEN 'PARTY'
                       WHEN 'PSU'   THEN 'PARTY'
                       WHEN 'PSITE' THEN 'PSITE'
                       WHEN 'ACCT'  THEN 'ACCT'
                       WHEN 'ASITE' THEN 'ASITE'
                   END scope_kind,
                   CASE n.kind
                       WHEN 'PARTY' THEN n.party_ref
                       WHEN 'PSU'   THEN n.party_ref
                       WHEN 'PSITE' THEN n.psite_ref
                       WHEN 'ACCT'  THEN n.acct_ref
                       WHEN 'ASITE' THEN n.asite_ref
                   END scope_ref,
                   DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                       n.grain, n.rkey,
                       DBMS_LOB.SUBSTR(n.et, 3800, DBMS_LOB.INSTR(n.et, C_TAG))) quote
            FROM   node n
            WHERE  n.kind IN ('PARTY', 'PSU', 'PSITE', 'ACCT', 'ASITE')
            AND    n.st = 'FAILED'
            AND    DBMS_LOB.INSTR(n.et, C_TAG) > 0
            AND    DBMS_LOB.INSTR(n.et, l_marker) = 0
        )
        SELECT DISTINCT n.kind, n.seq, s.quote
        BULK COLLECT INTO l_pairs
        FROM   src s
        JOIN   node n
          ON   (s.scope_kind = 'PARTY' AND (n.party_ref = s.scope_ref OR n.party_ref_s = s.scope_ref))
           OR  (s.scope_kind = 'PSITE' AND n.psite_ref = s.scope_ref)
           OR  (s.scope_kind = 'ACCT'  AND n.acct_ref  = s.scope_ref)
           OR  (s.scope_kind = 'ASITE' AND n.asite_ref = s.scope_ref)
        WHERE  NOT (n.kind = s.kind AND n.seq = s.seq)
        AND    s.scope_ref IS NOT NULL
        AND    s.quote IS NOT NULL
        AND    n.st NOT IN ('LOADED', 'STAGED');

        -- One bulk UPDATE per target table (FORALL over the pairs; a pair only
        -- matches the table of its TARGET_KIND). Each pair appends its quote only
        -- when the row does not already carry it, so a row held by several failed
        -- rows gets each quote once and a second reconcile pass adds nothing.
        l_step := 'appending quoted document errors to parties';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_HZ_PARTIES_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  l_pairs(i).TARGET_KIND = 'PARTY'
            AND    t.RUN_ID = p_run_id
            AND    t.TFM_SEQUENCE_ID = l_pairs(i).TARGET_SEQ
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_pty := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to party sites';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_HZ_PARTY_SITES_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  l_pairs(i).TARGET_KIND = 'PSITE'
            AND    t.RUN_ID = p_run_id
            AND    t.TFM_SEQUENCE_ID = l_pairs(i).TARGET_SEQ
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_psite := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to party site uses';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_HZ_PARTY_SITE_USES_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  l_pairs(i).TARGET_KIND = 'PSU'
            AND    t.RUN_ID = p_run_id
            AND    t.TFM_SEQUENCE_ID = l_pairs(i).TARGET_SEQ
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_psu := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to accounts';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_HZ_ACCOUNTS_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  l_pairs(i).TARGET_KIND = 'ACCT'
            AND    t.RUN_ID = p_run_id
            AND    t.TFM_SEQUENCE_ID = l_pairs(i).TARGET_SEQ
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_acct := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to account sites';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_HZ_ACCT_SITES_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  l_pairs(i).TARGET_KIND = 'ASITE'
            AND    t.RUN_ID = p_run_id
            AND    t.TFM_SEQUENCE_ID = l_pairs(i).TARGET_SEQ
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_asite := SQL%ROWCOUNT;

        l_step := 'appending quoted document errors to account site uses';
        FORALL i IN 1 .. l_pairs.COUNT
            UPDATE DMT_HZ_ACCT_SITE_USES_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  l_pairs(i).TARGET_KIND = 'ASU'
            AND    t.RUN_ID = p_run_id
            AND    t.TFM_SEQUENCE_ID = l_pairs(i).TARGET_SEQ
            AND    t.TFM_STATUS NOT IN ('LOADED', 'STAGED')
            AND    t.FBDI_CSV_ID IS NOT NULL
            AND    NVL(DBMS_LOB.INSTR(t.ERROR_TEXT, l_pairs(i).QUOTED_ERROR), 0) = 0;
        l_asu := SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Held-row quote pairs: ' || l_pairs.COUNT
                           || ' | rows given a quoted document error: parties ' || l_pty
                           || ', party sites ' || l_psite || ', party site uses ' || l_psu
                           || ', accounts ' || l_acct || ', account sites ' || l_asite
                           || ', account site uses ' || l_asu || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed while ' || l_step || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END PROPAGATE_DOCUMENT_ERRORS;

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
        -- LOADED (a real base-table row). The report selects base rows by the
        -- Fusion batch id this load sent and interface rows by the load ESS id
        -- (see the V6 report DM header). Rows already terminal are untouched.
        APPLY_CONTRACT_V1_CUSTOMERS(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            p_work_queue_id => p_work_queue_id);

        -- Whole-document rejection (design section 5): rows the customer bulk
        -- import held back with a failed row carry that row's real error. Runs
        -- after the per-row apply and BEFORE the shared unaccounted sweep
        -- (DMT_QUEUE_WORKER_PKG.RECONCILE_ONE).
        PROPAGATE_DOCUMENT_ERRORS(p_run_id, p_work_queue_id);

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


    -- --------------------------------------------------------
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known Customers TFM table(s). Flips this run's UNACCOUNTED rows
    -- back to GENERATED and strips the trailing [UNACCOUNTED] tag from ERROR_TEXT
    -- (CLOB-safe REGEXP_REPLACE -- plain REPLACE raises ORA-22849), preserving any
    -- prior real error. Scoped by run, and by work-queue item when given. NO
    -- dynamic SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        UPDATE DMT_HZ_PARTIES_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_HZ_LOCATIONS_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_HZ_PARTY_SITES_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_HZ_PARTY_SITE_USES_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_HZ_ACCOUNTS_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_HZ_ACCT_SITES_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_HZ_ACCT_SITE_USES_TFM_TBL
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
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED Customers row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_CUST_RESULTS_PKG;
/
