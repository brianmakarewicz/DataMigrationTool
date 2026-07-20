-- PACKAGE BODY DMT_WORKER_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORKER_VALIDATOR_PKG"
AS
-- ============================================================
-- DMT_WORKER_VALIDATOR_PKG body
-- Worker HDL pre- and post-transform validation.
--
-- Accepted architecture (design section 7):
--   - Validation runs on STG rows (pre) / TFM rows (post).
--   - A pre-validation rejection is recorded in the run-stamped error
--     table DMT_OWNER.DMT_STG_TFM_ERROR_TBL; the STG row keeps its status
--     only (no message) and is flagged FAILED by FLAG_STG_FAILED. No
--     validator writes ERROR_TEXT on a *_STG_TBL row.
--   - A failing TFM row is tagged with TFM_STATUS = 'FAILED' and its
--     ERROR_TEXT gets an appended, prefixed message.
--   - Never writes a staging status of 'LOADED'; never reads
--     STG_STATUS = 'LOADED'; no INSTR/SUBSTR parsing; no network.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_WORKER_VALIDATOR_PKG';

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks record WHY in the error table; this sets the STG
    -- status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_OWNER.DMT_WORKER_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Workers'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Data-quality checks on the Worker STG rows before transform.
    -- Offline, structural rules only (no Fusion dependency lookups):
    --   R1  PERSON_NUMBER must be present (the HDL SourceSystemId /
    --       PersonNumber; a worker with no number cannot be loaded).
    --   R2  ACTION_CODE must be one of the supported new-hire actions
    --       (HIRE, ADD_CWK) -- an unknown action fails the HDL load.
    --   R3  A valid worker must have at least one Assignment source row with a
    --       real ASSIGNMENT_NUMBER (joined by PERSON_NUMBER). The Worker load
    --       builds its required assignment section from that number and never
    --       fabricates one, so a worker with no assignment row is rejected.
    -- A failing row is set to STG_STATUS='FAILED' with an appended
    -- [PRE_VALIDATION] message; passing rows are left untouched (NEW).
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
        C_PROC CONSTANT VARCHAR2(30) := 'VALIDATE_PRE_TRANSFORM';
        l_bad  PLS_INTEGER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' start.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        -- Record the rejection in the run-stamped error table; the STG row keeps
        -- its status only (no message), flagged FAILED later by FLAG_STG_FAILED (§7).
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Workers', 'Workers', w.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] ' ||
               CASE WHEN w.PERSON_NUMBER IS NULL
                    THEN 'PERSON_NUMBER is required.'
                    ELSE 'ACTION_CODE ' || w.ACTION_CODE ||
                         ' is not a supported worker action (HIRE, ADD_CWK).'
               END
        FROM   DMT_OWNER.DMT_WORKER_STG_TBL w
        WHERE  w.STG_STATUS = 'NEW'
        AND (  w.PERSON_NUMBER IS NULL
            OR NVL(w.ACTION_CODE, 'X') NOT IN ('HIRE', 'ADD_CWK') );
        l_bad := SQL%ROWCOUNT;

        -- R3: a new-hire worker needs at least one Assignment source row (with a
        -- real ASSIGNMENT_NUMBER) so the Worker load can build its required
        -- WorkTerms + Assignment sections from that number. The Worker load no
        -- longer fabricates an assignment number from the person, so a worker
        -- with no matching assignment row cannot be loaded — it is a validation
        -- failure, not a fabricated placeholder. Only workers that passed R1/R2
        -- above (still NEW, valid action, non-null person) are checked here.
        INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'Workers', 'Workers', w.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] No assignment row found for this worker '
               || '(PERSON_NUMBER=' || w.PERSON_NUMBER
               || '); an assignment number is required and cannot be fabricated.'
        FROM   DMT_OWNER.DMT_WORKER_STG_TBL w
        WHERE  w.STG_STATUS = 'NEW'
        AND    w.PERSON_NUMBER IS NOT NULL
        AND    NVL(w.ACTION_CODE, 'X') IN ('HIRE', 'ADD_CWK')
        AND    NOT EXISTS (
                   SELECT 1 FROM DMT_OWNER.DMT_ASSIGNMENT_STG_TBL a
                   WHERE  a.PERSON_NUMBER = w.PERSON_NUMBER
                   AND    a.ASSIGNMENT_NUMBER IS NOT NULL );
        l_bad := l_bad + SQL%ROWCOUNT;

        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id);

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Rows tagged FAILED: ' || l_bad,
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
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Content checks on the Worker TFM rows for this run (after the
    -- prefix has been applied). Currently no post-transform rules are
    -- required for Workers -- the pre-transform structural checks plus
    -- the Fusion HDL load itself cover the known failure modes -- so
    -- this runs as a no-op that logs start/complete. Kept as a named
    -- entry point so the orchestration contract is stable.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
        C_PROC CONSTANT VARCHAR2(30) := 'VALIDATE_POST_TRANSFORM';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' start. (no post-transform rules for Workers)',
            p_package   => C_PKG,
            p_procedure => C_PROC);

        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete.',
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
    END VALIDATE_POST_TRANSFORM;

END DMT_WORKER_VALIDATOR_PKG;
/
