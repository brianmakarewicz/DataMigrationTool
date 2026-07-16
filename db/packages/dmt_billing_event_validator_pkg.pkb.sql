-- PACKAGE BODY DMT_BILLING_EVENT_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BILLING_EVENT_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_BILLING_EVENT_VALIDATOR_PKG body
-- Billing Events pre- and post-transform validation.
-- Upstream dependency: PROJECT_NUMBER must be LOADED in projects STG.
--
-- Pre-validation rejections are recorded in the run-stamped error table
-- DMT_OWNER.DMT_STG_TFM_ERROR_TBL (design §7); the STG rows keep their
-- status only (no message) and are flagged FAILED afterwards by the
-- standard FLAG_STG_FAILED helper. No validator writes ERROR_TEXT on a
-- *_STG_TBL row.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BILLING_EVENT_VALIDATOR_PKG';

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
        UPDATE DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','RETRY')
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Billing Events'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM
    -- Upstream dependency: PROJECT_NUMBER must match a LOADED project.
    -- For migrated projects: NVL(dep_prefix,'') || event.PROJECT_NUMBER
    --   must exist in DMT_PJF_PROJECTS_STG_TBL with STG_STATUS='LOADED'.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id    IN NUMBER,
        p_dependent_prefix  IN VARCHAR2 DEFAULT NULL
    )
    IS
        l_dep_prefix   VARCHAR2(30);
        l_failed       NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start. dep_prefix=' ||
                                NVL(p_dependent_prefix, '(from CONVERSION_MASTER)'),
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- Resolve dependent prefix: use parameter if supplied, else read from CONVERSION_MASTER
        IF p_dependent_prefix IS NOT NULL THEN
            l_dep_prefix := p_dependent_prefix;
        ELSE
            SELECT PREFIX
            INTO   l_dep_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        END IF;

        -- Check PROJECT_NUMBER upstream dependency.
        -- Only enforced when projects have been migrated (at least one LOADED row exists).
        -- When no projects have been migrated, all rows pass through unchecked.
        DECLARE
            l_any_loaded NUMBER;
        BEGIN
            -- LOADED is a TFM-only status (STG never carries it, design §5), so the
            -- "have projects migrated?" gate reads the projects TFM table.
            SELECT COUNT(*) INTO l_any_loaded
            FROM   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL
            WHERE  TFM_STATUS = 'LOADED' AND ROWNUM = 1;

            IF l_any_loaded > 0 THEN
                INSERT INTO DMT_OWNER.DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'BillingEvents', 'Billing Events', e.STG_SEQUENCE_ID,
                       '[PRE_VALIDATION] Project ''' || e.PROJECT_NUMBER ||
                       ''' is not loaded — billing event record skipped.'
                FROM   DMT_OWNER.DMT_PJB_BILL_EVENTS_STG_TBL e
                WHERE  e.STG_STATUS IN ('NEW', 'RETRY')
                AND    e.PROJECT_NUMBER IS NOT NULL
                AND    NOT EXISTS (
                           SELECT 1
                           FROM   DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL p
                           JOIN   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL pt
                                  ON pt.STG_SEQUENCE_ID = p.STG_SEQUENCE_ID
                           WHERE  p.PROJECT_NUMBER = e.PROJECT_NUMBER
                           AND    pt.TFM_STATUS    = 'LOADED'
                       );
                l_failed := SQL%ROWCOUNT;

                -- Standard final step: flag the STG rows FAILED from the recorded
                -- error rows (status only, no message) so FAILED-mode reruns select
                -- on them (§7).
                FLAG_STG_FAILED(p_run_id);
            END IF;
        END;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Pre-validation failures: ' || l_failed,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    -- --------------------------------------------------------
    -- VALIDATE_POST_TRANSFORM
    -- Stub: no post-transform rules implemented yet.
    -- Future: check COMPLETION_DATE not future, BILL_TRNS_AMOUNT > 0, etc.
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        -- No post-transform validations implemented yet.
        NULL;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_BILLING_EVENT_VALIDATOR_PKG;
/
