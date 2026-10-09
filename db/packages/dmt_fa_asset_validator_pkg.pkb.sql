-- PACKAGE BODY DMT_FA_ASSET_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FA_ASSET_VALIDATOR_PKG" AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_FA_ASSET_VALIDATOR_PKG';
    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks above record WHY in the error table; this sets the
    -- STG status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_FA_ASSET_HDR_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Asset Headers'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_FA_ASSET_BOOK_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Asset Books'
        -- <<END EDIT-SCOPE>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_FA_ASSET_ASSIGN_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Asset Assignments'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    PROCEDURE VALIDATE_PRE_TRANSFORM (p_run_id IN NUMBER, p_dependent_prefix IN VARCHAR2 DEFAULT NULL, p_scenario_id IN NUMBER DEFAULT NULL, p_run_mode IN VARCHAR2 DEFAULT 'NEW') IS
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'VALIDATE_PRE_TRANSFORM start (no rules yet).', 'INFO', C_PKG, 'VALIDATE_PRE_TRANSFORM');

        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id, p_scenario_id);
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
    PROCEDURE VALIDATE_POST_TRANSFORM (p_run_id IN NUMBER) IS
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'VALIDATE_POST_TRANSFORM start (no rules yet).', 'INFO', C_PKG, 'VALIDATE_POST_TRANSFORM');
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

    -- ============================================================
    -- VALIDATE_LINE_BREAKS -- STANDARD line-break check (backlog #651; design
    -- section 5, [POST_VALIDATION]). Runs after the transform and before the
    -- FBDI generator: every STAGED TFM row of this run holding a carriage return
    -- or line feed in any CSV value is marked FAILED with a message naming the
    -- field(s) (DMT_UTIL_PKG.LINE_BREAK_ERROR), so it is never written to a CSV
    -- and never silently stripped. One MERGE block per TFM table the generator
    -- reads, byte-identical except the table name (EDIT-TABLE). Does NOT commit --
    -- the caller owns the transaction. Checked by scripts/check_line_break_validation.py.
    -- ============================================================
    PROCEDURE VALIDATE_LINE_BREAKS (p_run_id IN NUMBER) IS
        l_failed NUMBER := 0;
    BEGIN
        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_FA_ASSET_HDR_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_FA_ASSET_HDR_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_FA_ASSET_BOOK_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_FA_ASSET_BOOK_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        -- <<EDIT-TABLE -- one TFM table the generator reads, named twice (MERGE INTO
        --   and FROM); repeat this whole block (through the ROWCOUNT line) per table>>
        MERGE INTO DMT_FA_ASSET_ASSIGN_TFM_TBL t
        USING (SELECT q.rid, q.msg
               FROM   (SELECT s.ROWID AS rid,
                              DMT_UTIL_PKG.LINE_BREAK_ERROR(
                                  p_row_json => JSON_OBJECT(s.* RETURNING CLOB)) AS msg
                       FROM   DMT_FA_ASSET_ASSIGN_TFM_TBL s
        -- <<END EDIT-TABLE -- everything below is FIXED>>
                       WHERE  s.RUN_ID     = p_run_id
                       AND    s.TFM_STATUS = 'STAGED') q
               WHERE  q.msg IS NOT NULL) lb
        ON (t.ROWID = lb.rid)
        WHEN MATCHED THEN UPDATE
        SET    t.TFM_STATUS        = 'FAILED',
               t.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(p_existing  => t.ERROR_TEXT,
                                                               p_new_error => lb.msg),
               t.LAST_UPDATED_DATE = SYSDATE
        WHERE  t.TFM_STATUS = 'STAGED';
        l_failed := l_failed + SQL%ROWCOUNT;

        IF l_failed > 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => 'VALIDATE_LINE_BREAKS: ' || l_failed ||
                               ' row(s) failed -- a value holds a line break (CR/LF).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => 'VALIDATE_LINE_BREAKS');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(p_run_id, 'VALIDATE_LINE_BREAKS failed.',
                SQLERRM, C_PKG, 'VALIDATE_LINE_BREAKS');
            RAISE;
    END VALIDATE_LINE_BREAKS;
END DMT_FA_ASSET_VALIDATOR_PKG;
/
