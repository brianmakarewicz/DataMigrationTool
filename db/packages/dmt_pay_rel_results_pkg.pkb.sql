-- PACKAGE BODY DMT_PAY_REL_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PAY_REL_RESULTS_PKG"
AS
-- ============================================================
-- DMT_PAY_REL_RESULTS_PKG body
-- PayrollRelationship HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_PAY_REL_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'PayrollRelationships';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_PAYROLLRELATIONSHIPS (private)
    -- The Contract v1 base-tier positive proof for the PayrollRelationship record
    -- (design section 5), mirroring APPLY_CONTRACT_V1_WORKERS / _SALARIES. The
    -- shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the PayrollRelationships
    -- recon report over BIP and returns the parsed rows (no dynamic SQL, no TFM
    -- reference there); the APPLY here is STATIC SQL against the compile-time-known
    -- PayrollRelationship TFM table. It confirms each migrated payroll relationship
    -- in the Fusion HCM payroll base table (PAY_PAY_RELATIONSHIPS_F, via the load's
    -- HRC_INTEGRATION_KEY_MAP row) by its SourceSystemId and marks that TFM row
    -- LOADED with the real Fusion PAYROLL_RELATIONSHIP_ID stamped into
    -- FUSION_PAYROLL_RELATIONSHIP_ID; any ERROR row is marked FAILED with the real
    -- Fusion error. This REPLACES the bulk LOOKUP_FUSION_IDS positive path for
    -- PayrollRelationships. The HDL data set request id is the Contract v1
    -- P_LOAD_REQUEST_ID.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_PAYROLLRELATIONSHIPS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(40) := 'APPLY_CONTRACT_V1_PAYROLLRELATIONSHIPS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count is done statically here (not in the shared pkg),
        -- and drives the shared fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_PAY_REL_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                'APPLY_CONTRACT_V1_PAYROLLRELATIONSHIPS: Contract v1 fetch failed '
                || 'for PayrollRelationships (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': PayrollRelationships recon report returned '
                               || 'zero rows; GENERATED rows left for the unaccounted '
                               || 'sweep (never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                l_rc   := 0;     -- backlog #65: reset per row so a prior row's tier
                l_tier := NULL;  -- cannot mislabel this row's audit log line.
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: relationship found in PAY_PAY_RELATIONSHIPS_F
                    -- with a real id. The ONLY path to LOADED.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481), mirroring
                    -- DMT_WORKER_RESULTS_PKG. Tier 1 is the stamped Slot A reference
                    -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches
                    -- NO TFM row do we fall through: tier 2 (the Slot C DFF stamp:
                    -- TFM_SEQUENCE_ID = the trailing segment of DFF_KEY) -- for HDL
                    -- PayrollRelationships there is NO DFF carrier so DFF_KEY is null and
                    -- tier 2 is skipped -- and then tier 3 (the business key:
                    -- PERSON_NUMBER = BUSINESS_KEY, the SourceSystemId the report
                    -- returns). Every tier-1 hit short-circuits, so loaded outcomes are
                    -- identical to before. Static UPDATEs.
                    UPDATE DMT_PAY_REL_TFM_TBL
                    SET    TFM_STATUS                     = 'LOADED',
                           FUSION_PAYROLL_RELATIONSHIP_ID = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE           = SYSDATE,
                           LAST_UPDATED_DATE              = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_rc := SQL%ROWCOUNT;
                    l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                    -- Tier 2 (DFF): only when tier 1 matched nothing and a DFF stamp is
                    -- present. HDL PayrollRelationships have no DFF carrier, so this is
                    -- normally a no-op; kept uniform with the shared three-tier template.
                    IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                        l_dff_seq := TO_NUMBER(
                            REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                        IF l_dff_seq IS NOT NULL THEN
                            UPDATE DMT_PAY_REL_TFM_TBL
                            SET    TFM_STATUS                     = 'LOADED',
                                   FUSION_PAYROLL_RELATIONSHIP_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE           = SYSDATE,
                                   LAST_UPDATED_DATE              = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    TFM_SEQUENCE_ID = l_dff_seq
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                        END IF;
                    END IF;

                    -- Tier 3 (business key): last resort, only when tiers 1 and 2 both
                    -- matched nothing. The relationship's business key is PERSON_NUMBER,
                    -- equal to the SourceSystemId the report returns as BUSINESS_KEY.
                    IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                        UPDATE DMT_PAY_REL_TFM_TBL
                        SET    TFM_STATUS                     = 'LOADED',
                               FUSION_PAYROLL_RELATIONSHIP_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE           = SYSDATE,
                               LAST_UPDATED_DATE              = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    PERSON_NUMBER = l_rows(i).BUSINESS_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                    END IF;

                    l_loaded := l_loaded + l_rc;
                    IF l_tier IN ('TIER2','TIER3') THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            C_PROC || ': matched a LOADED PayrollRelationship via ' || l_tier ||
                            ' fallback (tier 1 stamped ref did not resolve). '
                            || 'PAYROLL_RELATIONSHIP_ID ' || l_rows(i).FUSION_ID || '.',
                            'INFO', C_PKG, C_PROC);
                    END IF;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE.
                    UPDATE DMT_PAY_REL_TFM_TBL
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
                    -- INTERFACE/SUCCESS (corroborating, never sufficient) or a
                    -- non-terminal status with no real error: leave the row for
                    -- the existing unaccounted sweep. Never fabricate an outcome.
                    NULL;
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
    END APPLY_CONTRACT_V1_PAYROLLRELATIONSHIPS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Reconciles the PayrollRelationship TFM table. The per-record HDL error path
    -- runs first (real [FUSION_ERROR] rows are marked FAILED), then the Contract v1
    -- base-table proof promotes rows to LOADED from PAY_PAY_RELATIONSHIPS_F.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. RequestId: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- 1. PayrollRelationship — Contract v1 base-table proof (design section 5).
        -- The per-record HDL error path still runs (real [FUSION_ERROR] rows are
        -- marked FAILED here), but LOADED promotion is DEFERRED to the shared
        -- Contract v1 parser below: a PayrollRelationship row reaches LOADED only
        -- when the relationship is positively confirmed in the Fusion base table
        -- (PAY_PAY_RELATIONSHIPS_F) with a real payroll relationship id, which the
        -- parser stamps into FUSION_PAYROLL_RELATIONSHIP_ID.
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id       => p_request_id,
            p_tfm_table        => 'DMT_PAY_REL_TFM_TBL',
            p_stg_table        => 'DMT_PAY_REL_STG_TBL',
            p_key_column       => 'PERSON_NUMBER',
            p_dataset_status   => p_dataset_status,
            p_log_context      => C_CEMLI || ' > PayrollRelationship',
            p_defer_base_proof => TRUE,
            p_cemli_code     => C_CEMLI);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape:
        -- the shared package fetches the parsed report rows (no dynamic SQL, no TFM
        -- reference there) and the APPLY is done here as STATIC SQL against the
        -- compile-time-known PayrollRelationship TFM table. Extracted into its own
        -- private procedure (one BEGIN/END per procedure).
        APPLY_CONTRACT_V1_PAYROLLRELATIONSHIPS(p_run_id, p_request_id);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 1 object type(s) reconciled.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_PAY_REL_RESULTS_PKG;
/
