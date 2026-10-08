-- PACKAGE BODY DMT_ABSENCE_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ABSENCE_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_ABSENCE_RESULTS_PKG body
-- AbsenceEntry HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_ABSENCE_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'AbsenceEntries';
    -- Contract v1 CEMLI code as registered in DMT_BIP_REPORT_TBL / the catalog
    -- (design section 5). Distinct from C_CEMLI, which is only a log label.
    C_CONTRACT_CEMLI CONSTANT VARCHAR2(30) := 'Absences';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_ABSENCES (private)
    -- The Contract v1 base-tier positive proof for the Absence record (design
    -- section 5), Option A shape (owner decision on PR #248). Copied EXACTLY from
    -- the Workers template DMT_WORKER_RESULTS_PKG.APPLY_CONTRACT_V1_WORKERS. The
    -- shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Absences recon
    -- report over BIP and returns the parsed rows (no dynamic SQL, no TFM
    -- reference there); the APPLY here is STATIC SQL against the compile-time-known
    -- Absence TFM table. It confirms each migrated absence entry in the Fusion
    -- base table ANC_PER_ABS_ENTRIES (matched through HRC_INTEGRATION_KEY_MAP on
    -- the SourceSystemId we wrote) and marks that Absence TFM row LOADED with the
    -- real Fusion PER_ABSENCE_ENTRY_ID stamped into FUSION_ABSENCE_ENTRY_ID; any
    -- ERROR row is marked FAILED with the real Fusion error. The HDL data set
    -- request id is the Contract v1 P_LOAD_REQUEST_ID.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_ABSENCES (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_ABSENCES';
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
        FROM   DMT_ABSENCE_TFM_TBL
        WHERE  RUN_ID = p_run_id;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_CONTRACT_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20094,
                'APPLY_CONTRACT_V1_ABSENCES: Contract v1 fetch failed for Absences '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Absences recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
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
                    -- Positive proof: absence entry found in ANC_PER_ABS_ENTRIES
                    -- with a real id. The ONLY path to LOADED.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481), mirroring
                    -- APPLY_CONTRACT_V1_WORKERS exactly. Tier 1 is the stamped Slot A
                    -- reference (RECON_KEY = RECORD_KEY, exactly as before). Only if
                    -- tier 1 matches NO TFM row do we fall through: tier 2 (the Slot C
                    -- DFF stamp: TFM_SEQUENCE_ID = the trailing segment of DFF_KEY) --
                    -- this recon DM emits DMT_REFERENCE as CAST(NULL), so DFF_KEY is
                    -- null and tier 2 is a runtime no-op, kept uniform with the shared
                    -- template -- and then tier 3 (the business key: the report's
                    -- SOURCE_REF, returned as BUSINESS_KEY, which for this object is the
                    -- same stamped value as RECORD_KEY, so it matches the TFM RECON_KEY).
                    -- Every tier-1 hit short-circuits, so loaded outcomes are identical
                    -- to before. Static UPDATEs.
                    UPDATE DMT_ABSENCE_TFM_TBL
                    SET    TFM_STATUS              = 'LOADED',
                           FUSION_ABSENCE_ENTRY_ID = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE    = SYSDATE,
                           LAST_UPDATED_DATE       = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_rc := SQL%ROWCOUNT;
                    l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                    -- Tier 2 (DFF): only when tier 1 matched nothing and a DFF stamp is
                    -- present. This object has no DFF carrier, so this is normally a
                    -- no-op; kept uniform with the shared three-tier template.
                    IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                        l_dff_seq := TO_NUMBER(
                            REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                        IF l_dff_seq IS NOT NULL THEN
                            UPDATE DMT_ABSENCE_TFM_TBL
                            SET    TFM_STATUS              = 'LOADED',
                                   FUSION_ABSENCE_ENTRY_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE    = SYSDATE,
                                   LAST_UPDATED_DATE       = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    TFM_SEQUENCE_ID = l_dff_seq
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                        END IF;
                    END IF;

                    -- Tier 3 (business key): last resort, only when tiers 1 and 2 both
                    -- matched nothing. The business key is the report's SOURCE_REF
                    -- (returned as BUSINESS_KEY), equal to the stamped RECON_KEY value.
                    IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                        UPDATE DMT_ABSENCE_TFM_TBL
                        SET    TFM_STATUS              = 'LOADED',
                               FUSION_ABSENCE_ENTRY_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE    = SYSDATE,
                               LAST_UPDATED_DATE       = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                    END IF;

                    l_loaded := l_loaded + l_rc;
                    IF l_tier IN ('TIER2','TIER3') THEN
                        DMT_UTIL_PKG.LOG(p_run_id,
                            C_PROC || ': matched a LOADED Absence via ' || l_tier ||
                            ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                            || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                    END IF;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE.
                    UPDATE DMT_ABSENCE_TFM_TBL
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
    END APPLY_CONTRACT_V1_ABSENCES;

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


        -- 1. AbsenceEntry — Contract v1 base-table proof (design section 5).
        -- The per-record HDL error path still runs (real [FUSION_ERROR] rows are
        -- marked FAILED here), but LOADED promotion is DEFERRED to the shared
        -- Contract v1 parser below: an Absence row reaches LOADED only when the
        -- absence entry is positively confirmed in the Fusion base table
        -- (ANC_PER_ABS_ENTRIES) with a real id, which the parser stamps into
        -- FUSION_ABSENCE_ENTRY_ID.
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id       => p_request_id,
            p_tfm_table        => 'DMT_ABSENCE_TFM_TBL',
            p_stg_table        => 'DMT_ABSENCE_STG_TBL',
            p_key_column       => 'PERSON_NUMBER',
            p_dataset_status   => p_dataset_status,
            p_log_context      => C_CEMLI || ' > AbsenceEntry',
            p_defer_base_proof => TRUE,
            p_cemli_code     => C_CEMLI);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape
        -- (owner decision on PR #248): the shared package fetches the parsed report
        -- rows (no dynamic SQL, no TFM reference there) and the APPLY is done here
        -- as STATIC SQL against the compile-time-known Absence TFM table. This
        -- REPLACES the bulk LOOKUP_FUSION_IDS positive path (matches the Workers
        -- template, which carries no bulk lookup).
        APPLY_CONTRACT_V1_ABSENCES(p_run_id, p_request_id);


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

END DMT_ABSENCE_RESULTS_PKG;
/
