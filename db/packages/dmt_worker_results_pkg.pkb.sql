-- PACKAGE BODY DMT_WORKER_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORKER_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_WORKER_RESULTS_PKG body
-- Worker HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_WORKER_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Workers';

    -- --------------------------------------------------------
    -- CONFIRM_REFERENCE_ROUNDTRIP (private)
    -- Backlog #12 round-trip proof for one just-LOADED Worker base row (HDL family
    -- template; mirrors DMT_GL_RESULTS_PKG.CONFIRM_REFERENCE_ROUNDTRIP). For HDL persons the
    -- carrier is Slot A: SourceSystemId (= the prefixed PERSON_NUMBER we wrote into
    -- Worker.dat) lands in HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID and comes back as
    -- the recon report's RECORD_KEY (= PER_ALL_PEOPLE_F.PERSON_NUMBER). So the proof
    -- is: the base RECORD_KEY equals the Slot A value the TFM row carries as
    -- RECON_KEY -- the value we stamped survived to the Fusion base table and
    -- returned unchanged. There is NO Slot C for HDL persons, so the full reference
    -- (BUILD_REF = DMT:run:wq:tfm) is logged for audit alongside the confirmed Slot A
    -- carrier. Diagnostic only: a mismatch or lookup miss logs WARN and NEVER alters
    -- the LOADED outcome (design section 7).
    -- --------------------------------------------------------
    PROCEDURE CONFIRM_REFERENCE_ROUNDTRIP (
        p_run_id     IN NUMBER,
        p_record_key IN VARCHAR2,
        p_fusion_id  IN NUMBER
    ) IS
        C_PROC        CONSTANT VARCHAR2(30) := 'CONFIRM_REFERENCE_ROUNDTRIP';
        l_slot_a      VARCHAR2(1000);
        l_full_ref    VARCHAR2(150);
    BEGIN
        -- Read the Slot A carrier (RECON_KEY) and the full reference for the matched
        -- TFM row. RECON_KEY is exactly what the generator wrote as SourceSystemId.
        SELECT RECON_KEY,
               DMT_REF_ID_PKG.BUILD_REF(RUN_ID, WORK_QUEUE_ID, TFM_SEQUENCE_ID)
          INTO l_slot_a, l_full_ref
          FROM DMT_WORKER_TFM_TBL
         WHERE RUN_ID = p_run_id AND RECON_KEY = p_record_key
           AND ROWNUM = 1;

        IF p_record_key IS NOT NULL AND p_record_key = l_slot_a THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip OK for RECON_KEY ' || p_record_key ||
                ': Slot A SourceSystemId returned from the base table '
                || '(HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID -> PER_ALL_PEOPLE_F, '
                || 'PERSON_ID=' || p_fusion_id || ') = ' || l_slot_a ||
                '. Full ref (audit, no Slot C for HDL): ' || l_full_ref || '.',
                'INFO', C_PKG, C_PROC);
        ELSE
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip MISMATCH for RECON_KEY ' || p_record_key ||
                ': base RECORD_KEY=' || NVL(p_record_key, '(null)') ||
                ' expected Slot A=' || l_slot_a || '.',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DMT_UTIL_PKG.LOG(p_run_id,
                'REF #12 round-trip: no TFM row found for RECON_KEY ' ||
                p_record_key || ' (proof skipped).',
                DMT_UTIL_PKG.C_LOG_WARN, C_PKG, C_PROC);
    END CONFIRM_REFERENCE_ROUNDTRIP;

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_WORKERS (private)
    -- The Contract v1 base-tier positive proof for the Worker record (design
    -- section 5), Option A shape (owner decision on PR #248). The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Workers recon report over BIP and
    -- returns the parsed rows (no dynamic SQL, no TFM reference there); the APPLY
    -- here is STATIC SQL against the compile-time-known Worker TFM table. It confirms
    -- each migrated worker in the Fusion base table (PER_ALL_PEOPLE_F) by person
    -- number and marks that Worker TFM row LOADED with the real Fusion person id
    -- stamped into FUSION_PERSON_ID; any ERROR row is marked FAILED with the real
    -- Fusion error. This REPLACES the bulk LOOKUP_FUSION_IDS positive path for
    -- Workers. The single-record REST "Verify in Fusion" button path is unchanged.
    -- The HDL data set request id is the Contract v1 P_LOAD_REQUEST_ID. This is the
    -- template the other 13 HDL objects copy.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_WORKERS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_WORKERS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
    BEGIN
        -- Generated-row count is done statically here (not in the shared pkg),
        -- and drives the shared fetch's keyset page-count cap.
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_WORKER_TFM_TBL
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
                'APPLY_CONTRACT_V1_WORKERS: Contract v1 fetch failed for Workers '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Workers recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                IF l_rows(i).SOURCE_TYPE = 'BASE'
                   AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                   AND l_rows(i).FUSION_ID IS NOT NULL THEN
                    -- Positive proof: person found in PER_ALL_PEOPLE_F with a
                    -- real id. The ONLY path to LOADED. Static UPDATE.
                    UPDATE DMT_WORKER_TFM_TBL
                    SET    TFM_STATUS           = 'LOADED',
                           FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID    = p_run_id
                    AND    RECON_KEY = l_rows(i).RECORD_KEY
                    AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;

                    -- Backlog #12 round-trip proof (Slot A): confirm the base
                    -- RECORD_KEY that came back equals the SourceSystemId (RECON_KEY)
                    -- we wrote for this TFM row. Private proc so this loop keeps one
                    -- BEGIN/END (design section 7 coding standard).
                    CONFIRM_REFERENCE_ROUNDTRIP(
                        p_run_id     => p_run_id,
                        p_record_key => l_rows(i).RECORD_KEY,
                        p_fusion_id  => l_rows(i).FUSION_ID);

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE.
                    UPDATE DMT_WORKER_TFM_TBL
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

        -- ============================================================
        -- Person-component accounting (2026-09-17). PersonName, PersonEmail,
        -- PersonPhone, PersonAddress, PersonNationalIdentifier and
        -- PersonLegislativeData are COMPONENTS of the Worker business object: they
        -- load in the same Worker.dat as part of the person, and have no
        -- independent Fusion id / base-tier lookup of their own. So the ONLY honest
        -- verdict for a component row is its parent worker's verdict, keyed by
        -- PERSON_NUMBER (= the Worker RECON_KEY, the prefixed person number):
        --   * parent worker LOADED  -> component LOADED (it loaded with the person;
        --     parent-confirmed-in-base => component accounted, not fabrication).
        --   * parent worker FAILED   -> component FAILED, carrying the parent error
        --     context (the component could not have loaded without the person).
        -- Without this, a component row stays GENERATED with no [FUSION_ERROR],
        -- ACCOUNT_ROWS counts it "awaiting base", and the Workers gate defers then
        -- fails "1 record unaccounted" even though the worker itself is LOADED.
        -- Straight set-based UPDATEs (no new dynamic-SQL site); the Worker TFM row's
        -- terminal status is the compile-time-known driver. WorkRelationship +
        -- Assignment are accounted by their own Contract v1 base tiers
        -- (DMT_ASSIGNMENT_RESULTS_PKG), so they are intentionally not touched here.
        -- ============================================================
        -- LOADED workers -> their component rows LOADED.
        UPDATE DMT_PERSON_NAME_TFM_TBL c
        SET    c.TFM_STATUS = 'LOADED', c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'LOADED');
        UPDATE DMT_PERSON_EMAIL_TFM_TBL c
        SET    c.TFM_STATUS = 'LOADED', c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'LOADED');
        UPDATE DMT_PERSON_PHONE_TFM_TBL c
        SET    c.TFM_STATUS = 'LOADED', c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'LOADED');
        UPDATE DMT_PERSON_ADDR_TFM_TBL c
        SET    c.TFM_STATUS = 'LOADED', c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'LOADED');
        UPDATE DMT_PERSON_NID_TFM_TBL c
        SET    c.TFM_STATUS = 'LOADED', c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'LOADED');
        UPDATE DMT_PERSON_LEGISL_TFM_TBL c
        SET    c.TFM_STATUS = 'LOADED', c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'LOADED');

        -- FAILED workers -> their still-open component rows FAILED with parent context
        -- (a person component cannot load without its person).
        UPDATE DMT_PERSON_NAME_TFM_TBL c
        SET    c.TFM_STATUS = 'FAILED',
               c.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT wk.ERROR_TEXT FROM DMT_WORKER_TFM_TBL wk
                    WHERE  wk.RUN_ID = p_run_id
                    AND    wk.PERSON_NUMBER = c.PERSON_NUMBER
                    AND    wk.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'FAILED');
        UPDATE DMT_PERSON_EMAIL_TFM_TBL c
        SET    c.TFM_STATUS = 'FAILED',
               c.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT wk.ERROR_TEXT FROM DMT_WORKER_TFM_TBL wk
                    WHERE  wk.RUN_ID = p_run_id
                    AND    wk.PERSON_NUMBER = c.PERSON_NUMBER
                    AND    wk.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'FAILED');
        UPDATE DMT_PERSON_PHONE_TFM_TBL c
        SET    c.TFM_STATUS = 'FAILED',
               c.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT wk.ERROR_TEXT FROM DMT_WORKER_TFM_TBL wk
                    WHERE  wk.RUN_ID = p_run_id
                    AND    wk.PERSON_NUMBER = c.PERSON_NUMBER
                    AND    wk.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'FAILED');
        UPDATE DMT_PERSON_ADDR_TFM_TBL c
        SET    c.TFM_STATUS = 'FAILED',
               c.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT wk.ERROR_TEXT FROM DMT_WORKER_TFM_TBL wk
                    WHERE  wk.RUN_ID = p_run_id
                    AND    wk.PERSON_NUMBER = c.PERSON_NUMBER
                    AND    wk.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'FAILED');
        UPDATE DMT_PERSON_NID_TFM_TBL c
        SET    c.TFM_STATUS = 'FAILED',
               c.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT wk.ERROR_TEXT FROM DMT_WORKER_TFM_TBL wk
                    WHERE  wk.RUN_ID = p_run_id
                    AND    wk.PERSON_NUMBER = c.PERSON_NUMBER
                    AND    wk.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'FAILED');
        UPDATE DMT_PERSON_LEGISL_TFM_TBL c
        SET    c.TFM_STATUS = 'FAILED',
               c.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(c.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT wk.ERROR_TEXT FROM DMT_WORKER_TFM_TBL wk
                    WHERE  wk.RUN_ID = p_run_id
                    AND    wk.PERSON_NUMBER = c.PERSON_NUMBER
                    AND    wk.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               c.RESULTS_UPDATED_DATE = SYSDATE, c.LAST_UPDATED_DATE = SYSDATE
        WHERE  c.RUN_ID = p_run_id AND c.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND EXISTS (SELECT 1 FROM DMT_WORKER_TFM_TBL wk WHERE wk.RUN_ID = p_run_id
                    AND wk.PERSON_NUMBER = c.PERSON_NUMBER AND wk.TFM_STATUS = 'FAILED');

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || ' | person components accounted by parent verdict.',
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
    END APPLY_CONTRACT_V1_WORKERS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Calls RECONCILE_HDL for each of the 7 Worker TFM tables.
    -- Each call retrieves HDL error messages and updates
    -- TFM rows to LOADED or FAILED, then echoes to STG.
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

        -- 1. Worker — Contract v1 base-table proof (design section 5).
        -- The per-record HDL error path still runs (real [FUSION_ERROR] rows are
        -- marked FAILED here), but LOADED promotion is DEFERRED to the shared
        -- Contract v1 parser below: a Worker row reaches LOADED only when the
        -- person is positively confirmed in the Fusion base table (PER_ALL_PEOPLE_F)
        -- with a real person id, which the parser stamps into FUSION_PERSON_ID.
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id       => p_request_id,
            p_tfm_table        => 'DMT_WORKER_TFM_TBL',
            p_stg_table        => 'DMT_WORKER_STG_TBL',
            p_key_column       => 'PERSON_NUMBER',
            p_dataset_status   => p_dataset_status,
            p_log_context      => C_CEMLI || ' > Worker',
            p_defer_base_proof => TRUE);

        -- 2. PersonName
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_NAME_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_NAME_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonName');

        -- 3. PersonEmail
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_EMAIL_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_EMAIL_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonEmail');

        -- 4. PersonPhone
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_PHONE_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_PHONE_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonPhone');

        -- 5. PersonAddress
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_ADDR_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_ADDR_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonAddress');

        -- 6. PersonNationalIdentifier
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_NID_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_NID_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonNationalIdentifier');

        -- 7. PersonLegislativeData
        DMT_HDL_UTIL_PKG.RECONCILE_HDL(
            p_run_id => p_run_id,
            p_request_id     => p_request_id,
            p_tfm_table      => 'DMT_PERSON_LEGISL_TFM_TBL',
            p_stg_table      => 'DMT_PERSON_LEGISL_STG_TBL',
            p_key_column     => 'PERSON_NUMBER',
            p_dataset_status => p_dataset_status,
            p_log_context    => C_CEMLI || ' > PersonLegislativeData');

        -- Contract v1 base-tier positive proof (design section 5), Option A shape
        -- (owner decision on PR #248): the shared package fetches the parsed report
        -- rows (no dynamic SQL, no TFM reference there) and the APPLY is done here
        -- as STATIC SQL against the compile-time-known Worker TFM table. Extracted
        -- into its own private procedure (one BEGIN/END per procedure).
        APPLY_CONTRACT_V1_WORKERS(p_run_id, p_request_id);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 7 object types reconciled.',
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

END DMT_WORKER_RESULTS_PKG;
/
