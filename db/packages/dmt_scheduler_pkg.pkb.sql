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
    -- validate_depends_on — A13 (2026-07-08): every DEPENDS_ON token
    -- must name a registered object. Section 6: "DEPENDS_ON:
    -- comma-separated canonical CEMLI codes"; section 2: "A
    -- dependency means: the named work item(s) must be DONE before
    -- this one starts". An unknown token would otherwise be silently
    -- permissive (dependencies_met treats an absent dependency — no
    -- matching work items — as met), so a registry typo must fail
    -- loudly at submit, not run with the dependency ignored.
    -- ============================================================
    PROCEDURE validate_depends_on (
        p_cemli_code IN VARCHAR2,
        p_depends_on IN VARCHAR2
    ) IS
        l_remaining VARCHAR2(4000);
        l_dep       VARCHAR2(60);
        l_pos       PLS_INTEGER;
        l_cnt       NUMBER;
    BEGIN
        IF p_depends_on IS NULL THEN RETURN; END IF;

        l_remaining := REPLACE(p_depends_on, ' ', '') || ',';
        LOOP
            l_pos := INSTR(l_remaining, ',');
            EXIT WHEN NVL(l_pos, 0) = 0;
            l_dep := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_dep IS NULL THEN CONTINUE; END IF;

            SELECT COUNT(*) INTO l_cnt
            FROM   DMT_OWNER.DMT_PIPELINE_DEF_TBL
            WHERE  CEMLI_CODE = l_dep;

            IF l_cnt = 0 THEN
                RAISE_APPLICATION_ERROR(-20108,
                    'DEPENDS_ON token "' || l_dep || '" on object ' || p_cemli_code
                    || ' is not a registered CEMLI code in DMT_PIPELINE_DEF_TBL. '
                    || 'Fix the registry seed before submitting.');
            END IF;
        END LOOP;
    END validate_depends_on;

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
        l_use_prefix    VARCHAR2(10);
    BEGIN
        -- A9c (2026-07-08): ALL mode requires a scenario — Overview run-mode
        -- table, ALL row: "ALL (requires a scenario) | Every row in the
        -- scenario, selected directly by the run-mode parameter".
        IF UPPER(NVL(p_run_mode, 'NEW')) = 'ALL' AND p_scenario_name IS NULL THEN
            RAISE_APPLICATION_ERROR(-20107,
                'ALL run mode requires a scenario (design Overview, run-mode table): '
                || 'ALL re-runs every row IN THE SCENARIO under a new prefix.');
        END IF;

        -- A9a (2026-07-08): serialize the one-active-run check. SELECT FOR
        -- UPDATE on the (seeded, always present) USE_PREFIX configuration row
        -- makes concurrent submitters queue on this row lock until the first
        -- submission COMMITs its work-queue rows — closing the read-then-
        -- insert race in assert_objects_not_active without touching any row
        -- the heartbeat or workers write. It also IS the C6 read: prefixing
        -- is forced unless an administrator set USE_PREFIX = 'N' — the
        -- production-cutover switch; such runs store NULL prefix (design
        -- section 6, "Prefix — decided spec (2026-07-06)").
        BEGIN
            SELECT NVL(CONFIG_VALUE, 'Y') INTO l_use_prefix
            FROM   DMT_OWNER.DMT_CONFIG_TBL
            WHERE  CONFIG_KEY = 'USE_PREFIX'
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20106,
                    'USE_PREFIX configuration row is missing from DMT_CONFIG_TBL '
                    || '(seeded by db/seed/dmt_config_tbl.sql). It is required both as '
                    || 'the prefix switch and as the submission serialization lock.');
        END;

        -- One-active-run-per-object (section 2): reject before creating anything.
        assert_objects_not_active(p_cemli_csv);

        -- C6 (2026-07-08): honor USE_PREFIX exactly as DMT_PIPELINE_INIT_PKG
        -- .INIT_RUN does — one prefix per run from the single sequence, or
        -- NULL when the administrator disabled prefixing for cutover.
        IF l_use_prefix = 'Y' THEN
            SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;
        ELSE
            l_prefix := NULL;
        END IF;

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
                validate_depends_on(l_cemli, l_deps);  -- A13: unknown token = error

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
                    validate_depends_on(l_cemli, l_deps);  -- A13: unknown token = error

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
    -- (A8, 2026-07-08) CANCEL_RUN REMOVED per design section 2:
    -- "There is no cancellation (decided 2026-07-07) — runs always
    -- execute to their terminal state ... the fix is an ALL-mode
    -- re-run of the scenario under a new prefix." The CANCELLED
    -- run status is likewise removed from DMT_PIPELINE_RUN_TBL's
    -- check constraint (db/tables/dmt_pipeline_run_tbl.sql).
    -- ============================================================

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
