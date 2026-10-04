-- PACKAGE BODY DMT_LOG_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_LOG_PKG"
AS

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_LOG_PKG';

    -- --------------------------------------------------------
    -- EFFECTIVE_RETENTION_DAYS
    -- RETENTION_DAYS from config, floored at C_MIN_RETENTION_DAYS, defaulting
    -- when missing or non-numeric. Never returns less than the floor.
    -- --------------------------------------------------------
    FUNCTION EFFECTIVE_RETENTION_DAYS RETURN PLS_INTEGER IS
        l_raw  VARCHAR2(500);
        l_days PLS_INTEGER;
    BEGIN
        l_raw := DMT_UTIL_PKG.GET_CONFIG('RETENTION_DAYS');

        BEGIN
            l_days := TO_NUMBER(TRIM(l_raw));
        EXCEPTION
            WHEN VALUE_ERROR OR INVALID_NUMBER THEN
                l_days := NULL;
        END;

        -- Missing or not a positive number -> safe default.
        IF l_days IS NULL OR l_days <= 0 THEN
            l_days := C_DEFAULT_RETENTION_DAYS;
        END IF;

        -- Hard floor: never allow a retention smaller than the minimum.
        RETURN GREATEST(l_days, C_MIN_RETENTION_DAYS);
    END EFFECTIVE_RETENTION_DAYS;

    -- --------------------------------------------------------
    -- Shared eligibility predicate (count and delete must agree).
    -- A DMT_LOG_TBL row is eligible to prune ONLY when:
    --   (a) its own LOG_DATE is older than the cutoff, AND
    --   (b) it does NOT belong to a protected run. A run is protected when
    --       its DMT_PIPELINE_RUN_TBL row is still non-terminal (QUEUED /
    --       IN_PROGRESS) OR was submitted/completed within the cutoff window.
    --       Log rows with a NULL RUN_ID (no run context) are pruned purely on
    --       age -- they carry no run to protect.
    -- Expressed once as a WHERE fragment that both ROWS_ELIGIBLE_FOR_PRUNE and
    -- PRUNE_LOGS bind :cutoff into, so the preview and the delete can never
    -- diverge.
    -- --------------------------------------------------------
    --  l.LOG_DATE < :cutoff
    --  AND NOT EXISTS (
    --        SELECT 1 FROM DMT_PIPELINE_RUN_TBL r
    --         WHERE r.RUN_ID = l.RUN_ID
    --           AND (   r.RUN_STATUS IN ('QUEUED','IN_PROGRESS')
    --                OR r.SUBMITTED_DATE >= :cutoff
    --                OR r.COMPLETED_DATE >= :cutoff ) )

    FUNCTION ROWS_ELIGIBLE_FOR_PRUNE RETURN PLS_INTEGER IS
        l_cutoff DATE := TRUNC(SYSDATE) - EFFECTIVE_RETENTION_DAYS;
        l_count  PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO l_count
          FROM DMT_LOG_TBL l
         WHERE l.LOG_DATE < l_cutoff
           AND NOT EXISTS (
                 SELECT 1
                   FROM DMT_PIPELINE_RUN_TBL r
                  WHERE r.RUN_ID = l.RUN_ID
                    AND (   r.RUN_STATUS IN ('QUEUED','IN_PROGRESS')
                         OR r.SUBMITTED_DATE >= l_cutoff
                         OR r.COMPLETED_DATE >= l_cutoff ));
        RETURN l_count;
    END ROWS_ELIGIBLE_FOR_PRUNE;

    -- --------------------------------------------------------
    -- PRUNE_LOGS (full signature)
    -- --------------------------------------------------------
    PROCEDURE PRUNE_LOGS (
        p_dry_run    IN  BOOLEAN DEFAULT TRUE,
        x_deleted    OUT NUMBER,
        x_error_code OUT NUMBER
    ) IS
        l_retention PLS_INTEGER := EFFECTIVE_RETENTION_DAYS;
        l_cutoff    DATE        := TRUNC(SYSDATE) - EFFECTIVE_RETENTION_DAYS;
        l_eligible  PLS_INTEGER;
        l_batch     PLS_INTEGER;
    BEGIN
        x_deleted    := 0;
        x_error_code := DMT_UTIL_PKG.C_SUCCESS;

        l_eligible := ROWS_ELIGIBLE_FOR_PRUNE;

        DMT_UTIL_PKG.LOG(
            p_message   => 'PRUNE_LOGS'
                           || CASE WHEN p_dry_run THEN ' (DRY RUN)' ELSE '' END
                           || ': retention=' || l_retention || ' days'
                           || ' (floor=' || C_MIN_RETENTION_DAYS || '),'
                           || ' cutoff=' || TO_CHAR(l_cutoff,'YYYY-MM-DD')
                           || ', eligible rows=' || l_eligible
                           || '. Rows newer than the cutoff and rows belonging'
                           || ' to QUEUED/IN_PROGRESS or recent runs are kept.',
            p_log_type  => DMT_UTIL_PKG.C_LOG_INFO,
            p_package   => C_PKG,
            p_procedure => 'PRUNE_LOGS');

        IF p_dry_run THEN
            RETURN;  -- preview only, delete nothing
        END IF;

        -- Batched delete: remove eligible rows C_BATCH_SIZE at a time, commit
        -- each batch, stop when a batch deletes nothing. Each batch re-applies
        -- the full eligibility predicate, so an active run is protected for the
        -- whole purge even if its status flips mid-run.
        LOOP
            DELETE FROM DMT_LOG_TBL l
             WHERE l.LOG_DATE < l_cutoff
               AND NOT EXISTS (
                     SELECT 1
                       FROM DMT_PIPELINE_RUN_TBL r
                      WHERE r.RUN_ID = l.RUN_ID
                        AND (   r.RUN_STATUS IN ('QUEUED','IN_PROGRESS')
                             OR r.SUBMITTED_DATE >= l_cutoff
                             OR r.COMPLETED_DATE >= l_cutoff ))
               AND ROWNUM <= C_BATCH_SIZE;

            l_batch   := SQL%ROWCOUNT;
            x_deleted := x_deleted + l_batch;
            COMMIT;
            EXIT WHEN l_batch = 0;
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_message   => 'PRUNE_LOGS: deleted ' || x_deleted
                           || ' activity-log rows older than '
                           || TO_CHAR(l_cutoff,'YYYY-MM-DD') || '.',
            p_log_type  => DMT_UTIL_PKG.C_LOG_INFO,
            p_package   => C_PKG,
            p_procedure => 'PRUNE_LOGS');

    EXCEPTION
        WHEN OTHERS THEN
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'PRUNE_LOGS failed after deleting '
                               || x_deleted || ' rows.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => 'PRUNE_LOGS');
    END PRUNE_LOGS;

    -- --------------------------------------------------------
    -- PRUNE_LOGS (no-arg convenience wrapper: prune for real, swallow outcome)
    -- --------------------------------------------------------
    PROCEDURE PRUNE_LOGS IS
        l_deleted NUMBER;
        l_err     NUMBER;
    BEGIN
        PRUNE_LOGS(p_dry_run => FALSE, x_deleted => l_deleted, x_error_code => l_err);
    END PRUNE_LOGS;

END DMT_LOG_PKG;
/
