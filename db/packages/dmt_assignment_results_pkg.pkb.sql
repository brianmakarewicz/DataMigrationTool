-- PACKAGE BODY DMT_ASSIGNMENT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_ASSIGNMENT_RESULTS_PKG"
AS
-- ============================================================
-- DMT_ASSIGNMENT_RESULTS_PKG body
-- Worker Assignment HDL reconciliation via DMT_HDL_UTIL_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_ASSIGNMENT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'WorkerAssignments';
    -- Contract v1 registration CEMLI (design section 5): the DMT_BIP_REPORT_TBL
    -- row for the Assignments recon report is keyed 'Assignments' (its report
    -- catalog path is resolved by RUN_BIP_REPORT). This is the value passed to
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS.
    C_RECON_CEMLI CONSTANT VARCHAR2(30) := 'Assignments';

    -- --------------------------------------------------------
    -- APPLY_CONTRACT_V1_ASSIGNMENTS (private)
    -- The Contract v1 base-tier positive proof for the Assignments object (design
    -- section 5), mirroring APPLY_CONTRACT_V1_SALARIES. The shared package
    -- DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Assignments recon report over BIP
    -- and returns the parsed rows (no dynamic SQL, no TFM reference there); the
    -- APPLY here is STATIC SQL against the TWO compile-time-known Assignment TFM
    -- tables. Assignments loads two record types, so the ONE report returns two
    -- base tiers discriminated by OBJECT_TYPE, applied to the matching TFM table:
    --
    --   OBJECT_TYPE='WorkRelationship' -> DMT_WORK_REL_TFM_TBL, confirmed in
    --       PER_PERIODS_OF_SERVICE (via HRC_INTEGRATION_KEY_MAP), FUSION_ID = the
    --       real PERSON_ID stamped into FUSION_PERSON_ID. RECON_KEY =
    --       '<prefixed PERSON_NUMBER>_POS'.
    --   OBJECT_TYPE='Assignment'       -> DMT_ASSIGNMENT_TFM_TBL, confirmed in
    --       PER_ALL_ASSIGNMENTS_M (via HRC_INTEGRATION_KEY_MAP), FUSION_ID = the
    --       real ASSIGNMENT_ID stamped into FUSION_ASSIGNMENT_ID. RECON_KEY =
    --       '<ASSIGNMENT_NUMBER>_ASG' (the report also returns the '_TRM'
    --       work-terms sibling; that key never matches an assignment TFM row's
    --       RECON_KEY, so it corroborates only and is left for the sweep).
    --
    -- BASE/SUCCESS/FUSION_ID-not-null is the ONLY path to LOADED. An ERROR row
    -- with a real message -> FAILED on the exact message. This REPLACES the bulk
    -- LOOKUP_FUSION_IDS positive path. The HDL data set request id is the
    -- Contract v1 P_LOAD_REQUEST_ID.
    -- --------------------------------------------------------
    PROCEDURE APPLY_CONTRACT_V1_ASSIGNMENTS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_ASSIGNMENTS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count across BOTH TFM tables drives the shared fetch's
        -- keyset page-count cap. Done statically here (not in the shared pkg).
        SELECT (SELECT COUNT(*) FROM DMT_WORK_REL_TFM_TBL    WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_ASSIGNMENT_TFM_TBL  WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   DUAL;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => C_RECON_CEMLI,
            p_run_id      => p_run_id,
            p_load_ess_id => TO_NUMBER(p_request_id),
            p_row_cap     => l_gen_count,
            x_rows        => l_rows,
            x_error_code  => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20095,
                'APPLY_CONTRACT_V1_ASSIGNMENTS: Contract v1 fetch failed for '
                || 'Assignments (detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Assignments recon report returned zero '
                               || 'rows; GENERATED rows left for the unaccounted '
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
                    -- Positive proof: base row found with a real id. The ONLY
                    -- path to LOADED. Static UPDATE against the matching TFM
                    -- table by OBJECT_TYPE.
                    --
                    -- Backlog #65 three-tier match (owner order on PR #481), mirroring
                    -- DMT_WORKER_RESULTS_PKG, applied inside each OBJECT_TYPE branch so
                    -- each record type falls through against its OWN TFM table. Tier 1
                    -- is the stamped Slot A reference (RECON_KEY = RECORD_KEY, exactly as
                    -- before). Only if tier 1 matches NO TFM row do we fall through:
                    -- tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID = the trailing
                    -- segment of DFF_KEY) -- for HDL Assignments there is NO DFF carrier
                    -- so DFF_KEY is null and tier 2 is skipped -- and then tier 3 (the
                    -- object native business key: WorkRelationship -> PERSON_NUMBER,
                    -- Assignment -> ASSIGNMENT_NUMBER, each = BUSINESS_KEY). Every tier-1
                    -- hit short-circuits, so loaded outcomes are identical to before.
                    IF l_rows(i).OBJECT_TYPE = 'WorkRelationship' THEN
                        UPDATE DMT_WORK_REL_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
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
                                UPDATE DMT_WORK_REL_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
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
                            -- WorkRelationship business key is PERSON_NUMBER.
                            UPDATE DMT_WORK_REL_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_PERSON_ID     = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    PERSON_NUMBER = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED WorkRelationship via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). PERSON_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;

                    ELSIF l_rows(i).OBJECT_TYPE = 'Assignment' THEN
                        UPDATE DMT_ASSIGNMENT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_ASSIGNMENT_ID = l_rows(i).FUSION_ID,
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
                                UPDATE DMT_ASSIGNMENT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_ASSIGNMENT_ID = l_rows(i).FUSION_ID,
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
                            -- Assignment business key is ASSIGNMENT_NUMBER.
                            UPDATE DMT_ASSIGNMENT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_ASSIGNMENT_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    ASSIGNMENT_NUMBER = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED Assignment via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). ASSIGNMENT_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;
                    END IF;

                ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                      AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                    -- A real, specific Fusion error -> FAILED on the exact
                    -- message (never composed). Static UPDATE against the
                    -- matching TFM table by OBJECT_TYPE.
                    IF l_rows(i).OBJECT_TYPE = 'WorkRelationship' THEN
                        UPDATE DMT_WORK_REL_TFM_TBL
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

                    ELSIF l_rows(i).OBJECT_TYPE = 'Assignment' THEN
                        UPDATE DMT_ASSIGNMENT_TFM_TBL
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
                    END IF;

                ELSE
                    -- INTERFACE/SUCCESS (corroborating, never sufficient), the
                    -- '_TRM' work-terms sibling key (no TFM row of its own), or a
                    -- non-terminal status with no real error: leave for the
                    -- existing unaccounted sweep. Never fabricate an outcome.
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
    END APPLY_CONTRACT_V1_ASSIGNMENTS;

    -- --------------------------------------------------------
    -- APPLY_HDL_ERRORS (private, backlog #288)
    -- Per-record HDL errors, static SQL. DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES has
    -- already staged every page of this data set's error messages in
    -- DMT_HDL_MESSAGE_GTT. A GENERATED row is marked FAILED only when a message
    -- names EXACTLY the SourceSystemId its generator wrote for it (never LIKE,
    -- never a prefix), and it gets that message, named:
    --   [FUSION_ERROR] <SourceSystemId> (<file> line <n>): <Fusion message>
    -- Replaces the dynamic-SQL DMT_HDL_UTIL_PKG.RECONCILE_HDL.
    -- --------------------------------------------------------
    PROCEDURE APPLY_HDL_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC    CONSTANT VARCHAR2(30) := 'APPLY_HDL_ERRORS';
        l_request NUMBER := TO_NUMBER(p_request_id);
        l_failed  NUMBER := 0;
    BEGIN
        -- DMT_WORK_REL_TFM_TBL: SourceSystemId = PERSON_NUMBER || '_POS'
        UPDATE DMT_WORK_REL_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.PERSON_NUMBER || '_POS')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.PERSON_NUMBER || '_POS'));
        l_failed := l_failed + SQL%ROWCOUNT;

        -- DMT_ASSIGNMENT_TFM_TBL: SourceSystemId = ASSIGNMENT_NUMBER || '_TRM' / ASSIGNMENT_NUMBER || '_ASG'
        UPDATE DMT_ASSIGNMENT_TFM_TBL t
        SET    t.TFM_STATUS           = 'FAILED',
               t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT,
                                            DMT_HDL_UTIL_PKG.ROW_ERRORS(p_request_id, t.ASSIGNMENT_NUMBER || '_TRM', t.ASSIGNMENT_NUMBER || '_ASG')),
               t.RESULTS_UPDATED_DATE = SYSDATE,
               t.LAST_UPDATED_DATE    = SYSDATE
        WHERE  t.RUN_ID     = p_run_id
        AND    t.TFM_STATUS = 'GENERATED'
        AND    EXISTS (SELECT 1
                       FROM   DMT_HDL_MESSAGE_GTT m
                       WHERE  m.REQUEST_ID       = l_request
                       AND    m.SOURCE_SYSTEM_ID IN (t.ASSIGNMENT_NUMBER || '_TRM', t.ASSIGNMENT_NUMBER || '_ASG'));
        l_failed := l_failed + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED on their own named HDL error: ' || l_failed || '.',
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
    END APPLY_HDL_ERRORS;

    -- --------------------------------------------------------
    -- APPLY_FILE_ERRORS (private, backlog #288)
    -- Whole-file rejections, static SQL. Messages that name no record (no
    -- SourceSystemId: an invalid METADATA line, an unknown file, a data-set
    -- message) reject every record of their .dat file. They are applied LAST,
    -- after the per-record errors and the base-table proof, and only to rows
    -- still GENERATED, so a row proven LOADED or already FAILED on its own error
    -- is never touched. The text is Fusion's own, named with the file and line.
    -- --------------------------------------------------------
    PROCEDURE APPLY_FILE_ERRORS (
        p_run_id     IN NUMBER,
        p_request_id IN VARCHAR2
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'APPLY_FILE_ERRORS';
        l_text   VARCHAR2(4000);
        l_failed NUMBER := 0;
    BEGIN
        -- DMT_WORK_REL_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_WORK_REL_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        -- DMT_ASSIGNMENT_TFM_TBL: whole-file messages of Worker.dat
        l_text := DMT_HDL_UTIL_PKG.FILE_LEVEL_ERRORS(p_request_id, 'Worker.dat');
        IF l_text IS NOT NULL THEN
            UPDATE DMT_ASSIGNMENT_TFM_TBL t
            SET    t.TFM_STATUS           = 'FAILED',
                   t.ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(t.ERROR_TEXT, l_text),
                   t.RESULTS_UPDATED_DATE = SYSDATE,
                   t.LAST_UPDATED_DATE    = SYSDATE
            WHERE  t.RUN_ID     = p_run_id
            AND    t.TFM_STATUS = 'GENERATED';
            l_failed := l_failed + SQL%ROWCOUNT;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows FAILED by a whole-file HDL error: ' || l_failed || '.',
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
    END APPLY_FILE_ERRORS;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- Stages the data set's HDL error messages (all pages), applies each one
    -- to the row whose SourceSystemId it names exactly, applies the base-table
    -- proof (the only path to LOADED), then the whole-file rejections.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER,
        p_request_id     IN VARCHAR2,
        p_dataset_status IN VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_msg_count NUMBER;  -- HDL error messages staged for this data set
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. RequestId: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Per-record HDL errors (backlog #288): stage every page of this data
        -- set's error messages, then mark FAILED only the rows a message names
        -- exactly. LOADED comes only from base-table proof; there is no
        -- data-set-status promotion and no write-back to the STG table.
        DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES(
            p_run_id        => p_run_id,
            p_request_id    => p_request_id,
            p_log_context   => C_CEMLI,
            x_message_count => l_msg_count,
            p_cemli_code     => C_CEMLI);
        APPLY_HDL_ERRORS(p_run_id, p_request_id);

        -- Contract v1 base-tier positive proof (design section 5), Option A shape:
        -- the shared package fetches the parsed report rows (no dynamic SQL, no TFM
        -- reference there) and the APPLY is done here as STATIC SQL against the two
        -- compile-time-known Assignment TFM tables. Extracted into its own private
        -- procedure (one BEGIN/END per procedure). This REPLACES the former
        -- LOOKUP_FUSION_IDS positive path for Assignments.
        APPLY_CONTRACT_V1_ASSIGNMENTS(p_run_id, p_request_id);

        -- Whole-file HDL rejections last, only on rows still open (backlog #288).
        APPLY_FILE_ERRORS(p_run_id, p_request_id);

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. All 2 object types reconciled.',
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

END DMT_ASSIGNMENT_RESULTS_PKG;
/
