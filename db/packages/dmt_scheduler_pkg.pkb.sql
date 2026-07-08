-- PACKAGE BODY DMT_SCHEDULER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_SCHEDULER_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_SCHEDULER_PKG';

    -- ============================================================
    -- Pipeline CEMLI sequences — registry-driven (Stage C task 3).
    -- Reads DMT_PIPELINE_DEF_TBL (the decided section-6 seed content)
    -- instead of the retired hardcoded CASE. Only objects with a
    -- registered EXEC_PROC are queued: an unbuilt registration
    -- (ARReceipts, the CONFIGURATION objects pending the section-12
    -- fold) must not create work items EXECUTE_ONE cannot dispatch.
    -- 'OTC' is accepted as an alias of the canonical 'O2C'.
    -- ============================================================
    FUNCTION GET_CEMLI_SEQUENCE (p_pipeline_code IN VARCHAR2) RETURN VARCHAR2 IS
        l_pipeline VARCHAR2(30);
        l_seq      VARCHAR2(4000);
    BEGIN
        l_pipeline := UPPER(p_pipeline_code);
        IF l_pipeline = 'OTC' THEN
            l_pipeline := 'O2C';
        END IF;

        SELECT LISTAGG(CEMLI_CODE, ',') WITHIN GROUP (ORDER BY SORT_ORDER)
        INTO   l_seq
        FROM   DMT_OWNER.DMT_PIPELINE_DEF_TBL
        WHERE  PIPELINE_CODE = l_pipeline
        AND    EXEC_PROC IS NOT NULL;

        RETURN l_seq;  -- NULL when the pipeline is unknown (existing contract)
    END GET_CEMLI_SEQUENCE;

    -- ============================================================
    -- CEMLI dependency graph — registry-driven (Stage C task 3).
    -- One pipeline home per object (DMT_PIPELINE_DEF_UK1), so the
    -- pipeline code parameter is no longer consulted; it is kept
    -- for signature compatibility with existing callers.
    -- ============================================================
    FUNCTION GET_CEMLI_DEPENDENCIES (p_pipeline_code IN VARCHAR2, p_cemli_code IN VARCHAR2) RETURN VARCHAR2 IS
        l_deps VARCHAR2(4000);
    BEGIN
        SELECT DEPENDS_ON
        INTO   l_deps
        FROM   DMT_OWNER.DMT_PIPELINE_DEF_TBL
        WHERE  CEMLI_CODE = p_cemli_code;

        RETURN l_deps;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;  -- unregistered object: no dependencies (existing contract)
    END GET_CEMLI_DEPENDENCIES;

    -- ============================================================
    -- assert_objects_not_active — one-active-run-per-object rule
    -- (section 2, decided 2026-07-07): an object may be part of only
    -- one active run at a time, enforced at submission — a run whose
    -- selection includes an object already in an active run is
    -- rejected with a clear message naming the object and the
    -- blocking run.
    -- ============================================================
    PROCEDURE assert_objects_not_active (p_cemli_csv IN VARCHAR2) IS
        l_remaining    VARCHAR2(4000);
        l_cemli        VARCHAR2(60);
        l_pos          PLS_INTEGER;
        l_blocking_run NUMBER;
    BEGIN
        l_remaining := REPLACE(p_cemli_csv, ' ', '') || ',';
        LOOP
            l_pos := INSTR(l_remaining, ',');
            EXIT WHEN NVL(l_pos, 0) = 0;
            l_cemli := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_cemli IS NULL THEN CONTINUE; END IF;

            SELECT MAX(q.RUN_ID)
            INTO   l_blocking_run
            FROM   DMT_WORK_QUEUE_TBL q
            JOIN   DMT_PIPELINE_RUN_TBL r ON r.RUN_ID = q.RUN_ID
            WHERE  q.CEMLI_CODE = l_cemli
            AND    r.RUN_STATUS IN ('QUEUED', 'IN_PROGRESS')
            AND    q.WORK_STATUS NOT IN ('DONE', 'FAILED', 'SKIPPED');

            IF l_blocking_run IS NOT NULL THEN
                RAISE_APPLICATION_ERROR(-20105,
                    'Object ' || l_cemli || ' is already part of active run #'
                    || l_blocking_run
                    || '. An object may be part of only one active run at a time; '
                    || 'wait for that run to finish.');
            END IF;
        END LOOP;
    END assert_objects_not_active;

    -- ============================================================
    -- Internal: create PIPELINE_RUN + WORK_QUEUE rows
    -- ============================================================
    PROCEDURE create_run_and_queue (
        p_pipeline_codes   IN  VARCHAR2,
        p_cemli_csv        IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2,
        p_run_mode         IN  VARCHAR2,
        p_on_failure       IN  VARCHAR2,
        p_submitted_by     IN  VARCHAR2,
        x_run_id           OUT NUMBER
    ) IS
        l_prefix        VARCHAR2(20);
        l_remaining     VARCHAR2(4000);
        l_cemli         VARCHAR2(60);
        l_pipeline      VARCHAR2(30);
        l_pos           PLS_INTEGER;
        l_sort          PLS_INTEGER := 0;
        l_deps          VARCHAR2(4000);
        l_has_deps      BOOLEAN;
        l_is_split      NUMBER;
    BEGIN
        -- One-active-run-per-object (section 2): reject before creating anything.
        assert_objects_not_active(p_cemli_csv);

        -- Assign prefix from sequence
        SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

        -- Create PIPELINE_RUN row
        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            PIPELINE_CODES, RUN_TYPE, SUBMITTED_BY,
            CEMLI_SEQUENCE, SCENARIO_NAME, RUN_MODE,
            PREFIX, ON_FAILURE_POLICY
        ) VALUES (
            p_pipeline_codes, 'PIPELINE', p_submitted_by,
            p_cemli_csv, p_scenario_name, p_run_mode,
            l_prefix, NVL(p_on_failure, 'HALT')
        ) RETURNING RUN_ID INTO x_run_id;

        -- Determine pipeline label for each CEMLI (for multi-pipeline batches)
        -- We need to know which pipeline each CEMLI belongs to for tile grouping.
        -- Parse pipeline_codes and expand each, inserting queue rows.
        l_remaining := REPLACE(p_pipeline_codes, ' ', '') || ',';
        LOOP
            l_pos := INSTR(l_remaining, ',');
            EXIT WHEN NVL(l_pos, 0) = 0;
            l_pipeline := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_pipeline IS NULL THEN CONTINUE; END IF;

            -- Check for STANDALONE:ObjectName pattern
            IF l_pipeline LIKE 'STANDALONE:%' THEN
                l_cemli := SUBSTR(l_pipeline, 12);  -- after 'STANDALONE:'
                l_sort := l_sort + 1;
                l_deps := GET_CEMLI_DEPENDENCIES('STANDALONE', l_cemli);

                -- Split objects get PARTITION_KEY='ALL' so dispatch_ready
                -- picks them up directly (EXECUTE_ONE handles grouping internally).
                SELECT COUNT(*) INTO l_is_split
                FROM DMT_CEMLI_SPLIT_CFG WHERE CEMLI_CODE = l_cemli;

                INSERT INTO DMT_OWNER.DMT_WORK_QUEUE_TBL (
                    RUN_ID, PIPELINE, CEMLI_CODE, SORT_ORDER, DEPENDS_ON,
                    WORK_STATUS, PARTITION_KEY, PARTITION_LABEL
                ) VALUES (
                    x_run_id, 'STANDALONE', l_cemli, l_sort, l_deps,
                    CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END,
                    CASE WHEN l_is_split > 0 THEN 'ALL' END,
                    CASE WHEN l_is_split > 0 THEN 'All Groups' END
                );
                CONTINUE;
            END IF;

            -- Standard pipeline: expand CEMLI sequence
            DECLARE
                l_seq VARCHAR2(4000) := GET_CEMLI_SEQUENCE(l_pipeline);
                l_seq_remaining VARCHAR2(4000);
                l_seq_pos PLS_INTEGER;
            BEGIN
                IF l_seq IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20101, 'Unknown pipeline code: ' || l_pipeline);
                END IF;

                l_seq_remaining := l_seq || ',';
                LOOP
                    l_seq_pos := INSTR(l_seq_remaining, ',');
                    EXIT WHEN NVL(l_seq_pos, 0) = 0;
                    l_cemli := TRIM(SUBSTR(l_seq_remaining, 1, l_seq_pos - 1));
                    l_seq_remaining := SUBSTR(l_seq_remaining, l_seq_pos + 1);
                    IF l_cemli IS NULL THEN CONTINUE; END IF;

                    l_sort := l_sort + 1;
                    l_deps := GET_CEMLI_DEPENDENCIES(l_pipeline, l_cemli);

                    SELECT COUNT(*) INTO l_is_split
                    FROM DMT_CEMLI_SPLIT_CFG WHERE CEMLI_CODE = l_cemli;

                    INSERT INTO DMT_OWNER.DMT_WORK_QUEUE_TBL (
                        RUN_ID, PIPELINE, CEMLI_CODE, SORT_ORDER, DEPENDS_ON,
                        WORK_STATUS, PARTITION_KEY, PARTITION_LABEL
                    ) VALUES (
                        x_run_id, UPPER(l_pipeline), l_cemli, l_sort, l_deps,
                        CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END,
                        CASE WHEN l_is_split > 0 THEN 'ALL' END,
                        CASE WHEN l_is_split > 0 THEN 'All Groups' END
                    );
                END LOOP;
            END;
        END LOOP;

        COMMIT;

        -- Poller is started separately (continuous mode or manual).
        -- SUBMIT just creates the data.

        DMT_UTIL_PKG.LOG(x_run_id,
            'Pipeline submitted: Run #' || x_run_id
            || ' | Pipelines: ' || p_pipeline_codes
            || ' | Prefix: ' || l_prefix
            || ' | Mode: ' || p_run_mode
            || ' | OnFailure: ' || NVL(p_on_failure, 'HALT'),
            'INFO', C_PKG, 'create_run_and_queue');

    END create_run_and_queue;

    -- ============================================================
    -- SUBMIT_PIPELINE
    -- ============================================================
    PROCEDURE SUBMIT_PIPELINE (
        p_pipeline_codes   IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW',
        p_on_failure       IN  VARCHAR2 DEFAULT 'HALT',
        p_submitted_by     IN  VARCHAR2 DEFAULT NULL,
        x_run_id           OUT NUMBER
    ) IS
        l_all_cemlis VARCHAR2(4000);
        l_remaining  VARCHAR2(4000);
        l_pipeline   VARCHAR2(30);
        l_pos        PLS_INTEGER;
        l_seq        VARCHAR2(4000);
    BEGIN
        IF p_pipeline_codes IS NULL THEN
            RAISE_APPLICATION_ERROR(-20101, 'No pipeline codes specified.');
        END IF;

        -- Build combined CEMLI list for CEMLI_SEQUENCE column
        l_remaining := REPLACE(p_pipeline_codes, ' ', '') || ',';
        LOOP
            l_pos := INSTR(l_remaining, ',');
            EXIT WHEN NVL(l_pos, 0) = 0;
            l_pipeline := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_pipeline IS NULL THEN CONTINUE; END IF;

            IF l_pipeline LIKE 'STANDALONE:%' THEN
                l_seq := SUBSTR(l_pipeline, 12);
            ELSE
                l_seq := GET_CEMLI_SEQUENCE(l_pipeline);
                IF l_seq IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20101, 'Unknown pipeline code: ' || l_pipeline);
                END IF;
            END IF;

            l_all_cemlis := CASE WHEN l_all_cemlis IS NOT NULL
                            THEN l_all_cemlis || ',' ELSE '' END || l_seq;
        END LOOP;

        create_run_and_queue(
            p_pipeline_codes => p_pipeline_codes,
            p_cemli_csv      => l_all_cemlis,
            p_scenario_name  => p_scenario_name,
            p_run_mode       => p_run_mode,
            p_on_failure     => p_on_failure,
            p_submitted_by   => p_submitted_by,
            x_run_id         => x_run_id
        );
    END SUBMIT_PIPELINE;

    -- ============================================================
    -- SUBMIT_OBJECTS
    -- ============================================================
    PROCEDURE SUBMIT_OBJECTS (
        p_objects          IN  VARCHAR2,
        p_scenario_name    IN  VARCHAR2 DEFAULT NULL,
        p_run_mode         IN  VARCHAR2 DEFAULT 'NEW',
        p_on_failure       IN  VARCHAR2 DEFAULT 'HALT',
        p_submitted_by     IN  VARCHAR2 DEFAULT NULL,
        x_run_id           OUT NUMBER
    ) IS
        l_pipeline_codes VARCHAR2(500);
        l_cemli_csv      VARCHAR2(4000);
        l_remaining      VARCHAR2(4000);
        l_obj            VARCHAR2(60);
        l_pos            PLS_INTEGER;
    BEGIN
        IF p_objects IS NULL THEN
            RAISE_APPLICATION_ERROR(-20103, 'No objects specified.');
        END IF;

        -- Convert pipe-delimited to STANDALONE: prefixed CSV
        l_remaining := p_objects || '|';
        LOOP
            l_pos := INSTR(l_remaining, '|');
            EXIT WHEN NVL(l_pos, 0) = 0;
            l_obj := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_obj IS NULL THEN CONTINUE; END IF;

            l_pipeline_codes := CASE WHEN l_pipeline_codes IS NOT NULL
                                THEN l_pipeline_codes || ',' ELSE '' END
                                || 'STANDALONE:' || l_obj;
            l_cemli_csv := CASE WHEN l_cemli_csv IS NOT NULL
                           THEN l_cemli_csv || ',' ELSE '' END || l_obj;
        END LOOP;

        create_run_and_queue(
            p_pipeline_codes => l_pipeline_codes,
            p_cemli_csv      => l_cemli_csv,
            p_scenario_name  => p_scenario_name,
            p_run_mode       => p_run_mode,
            p_on_failure     => p_on_failure,
            p_submitted_by   => p_submitted_by,
            x_run_id         => x_run_id
        );
    END SUBMIT_OBJECTS;

    -- ============================================================
    -- CANCEL_RUN
    -- ============================================================
    PROCEDURE CANCEL_RUN (
        p_run_id IN NUMBER
    ) IS
        l_status VARCHAR2(30);
    BEGIN
        SELECT RUN_STATUS INTO l_status
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;

        IF l_status NOT IN ('QUEUED', 'IN_PROGRESS') THEN
            RAISE_APPLICATION_ERROR(-20104, 'Run ' || p_run_id || ' is already ' || l_status);
        END IF;

        -- Mark all non-terminal queue rows as SKIPPED
        UPDATE DMT_WORK_QUEUE_TBL
        SET    WORK_STATUS  = 'SKIPPED',
               ERROR_MESSAGE = 'Cancelled by user',
               COMPLETED_AT  = SYSTIMESTAMP
        WHERE  RUN_ID = p_run_id
        AND    WORK_STATUS NOT IN ('DONE', 'FAILED', 'SKIPPED');

        UPDATE DMT_PIPELINE_RUN_TBL
        SET    RUN_STATUS     = 'CANCELLED',
               COMPLETED_DATE = SYSTIMESTAMP,
               ERROR_MESSAGE  = 'Cancelled by user'
        WHERE  RUN_ID = p_run_id;

        COMMIT;

        DMT_UTIL_PKG.LOG(p_run_id,
            'Run #' || p_run_id || ' cancelled.',
            'INFO', C_PKG, 'CANCEL_RUN');
    END CANCEL_RUN;

    -- ============================================================
    -- PLAN_RUN — preview without committing
    -- Populates DMT_PLAN_PREVIEW_GTT (session-scoped, ON COMMIT
    -- DELETE ROWS) with the proposed queue rows and returns a
    -- SYS_REFCURSOR over it. Previously used APEX_COLLECTION, which
    -- made this package invalid on any database without APEX (the
    -- local Docker engine instance); the GTT was already committed
    -- for exactly this purpose.
    -- ============================================================
    FUNCTION PLAN_RUN (
        p_pipeline_codes   IN  VARCHAR2
    ) RETURN SYS_REFCURSOR IS
        l_cur          SYS_REFCURSOR;
        l_remaining    VARCHAR2(4000);
        l_pipeline     VARCHAR2(30);
        l_pos          PLS_INTEGER;
        l_sort         PLS_INTEGER := 0;
        l_deps         VARCHAR2(4000);
        l_cemli        VARCHAR2(60);
    BEGIN
        DELETE FROM DMT_PLAN_PREVIEW_GTT;

        IF p_pipeline_codes IS NULL THEN
            OPEN l_cur FOR
                SELECT SORT_ORDER, PIPELINE, CEMLI_CODE, DEPENDS_ON, INITIAL_STATUS
                FROM DMT_PLAN_PREVIEW_GTT
                ORDER BY SORT_ORDER;
            RETURN l_cur;
        END IF;

        l_remaining := REPLACE(p_pipeline_codes, ' ', '') || ',';
        LOOP
            l_pos := INSTR(l_remaining, ',');
            EXIT WHEN NVL(l_pos, 0) = 0;
            l_pipeline := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_pipeline IS NULL THEN CONTINUE; END IF;

            IF l_pipeline LIKE 'STANDALONE:%' THEN
                l_cemli := SUBSTR(l_pipeline, 12);
                l_sort := l_sort + 1;
                l_deps := GET_CEMLI_DEPENDENCIES('STANDALONE', l_cemli);
                INSERT INTO DMT_PLAN_PREVIEW_GTT
                    (SORT_ORDER, PIPELINE, CEMLI_CODE, DEPENDS_ON, INITIAL_STATUS)
                VALUES
                    (l_sort, 'STANDALONE', l_cemli, l_deps,
                     CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END);
                CONTINUE;
            END IF;

            DECLARE
                l_seq VARCHAR2(4000) := GET_CEMLI_SEQUENCE(l_pipeline);
                l_seq_remaining VARCHAR2(4000);
                l_seq_pos PLS_INTEGER;
            BEGIN
                IF l_seq IS NULL THEN
                    l_sort := l_sort + 1;
                    INSERT INTO DMT_PLAN_PREVIEW_GTT
                        (SORT_ORDER, PIPELINE, CEMLI_CODE, DEPENDS_ON, INITIAL_STATUS)
                    VALUES
                        (l_sort, UPPER(l_pipeline),
                         '** Unknown pipeline: ' || l_pipeline || ' **',
                         NULL, 'ERROR');
                    CONTINUE;
                END IF;

                l_seq_remaining := l_seq || ',';
                LOOP
                    l_seq_pos := INSTR(l_seq_remaining, ',');
                    EXIT WHEN NVL(l_seq_pos, 0) = 0;
                    l_cemli := TRIM(SUBSTR(l_seq_remaining, 1, l_seq_pos - 1));
                    l_seq_remaining := SUBSTR(l_seq_remaining, l_seq_pos + 1);
                    IF l_cemli IS NULL THEN CONTINUE; END IF;

                    l_sort := l_sort + 1;
                    l_deps := GET_CEMLI_DEPENDENCIES(l_pipeline, l_cemli);
                    INSERT INTO DMT_PLAN_PREVIEW_GTT
                        (SORT_ORDER, PIPELINE, CEMLI_CODE, DEPENDS_ON, INITIAL_STATUS)
                    VALUES
                        (l_sort, UPPER(l_pipeline), l_cemli, l_deps,
                         CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END);
                END LOOP;
            END;
        END LOOP;

        OPEN l_cur FOR
            SELECT SORT_ORDER, PIPELINE, CEMLI_CODE, DEPENDS_ON, INITIAL_STATUS
            FROM DMT_PLAN_PREVIEW_GTT
            ORDER BY SORT_ORDER;
        RETURN l_cur;
    END PLAN_RUN;

END DMT_SCHEDULER_PKG;
/
