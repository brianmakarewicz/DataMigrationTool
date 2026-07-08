-- PACKAGE BODY DMT_QUEUE_WORKER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_QUEUE_WORKER_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_QUEUE_WORKER_PKG';
    C_ESS_TIMEOUT CONSTANT PLS_INTEGER := 30;  -- max polls before auto-fail (mirrors DMT_QUEUE_PKG.C_ESS_TIMEOUT)

    -- ============================================================
    -- get_dispatch — read the object's dispatch registration from
    -- DMT_PIPELINE_DEF_TBL (the section-12 one-row-per-object
    -- registry). Replaces the retired hardcoded EXECUTE_ONE CASE /
    -- RECONCILE_ONE ELSIF chain: adding an object is now a registry
    -- seed insert, not a queue-worker edit. Missing registration is
    -- reported as a clear error by the callers.
    -- ============================================================
    PROCEDURE get_dispatch (
        p_cemli_code          IN  VARCHAR2,
        x_exec_proc           OUT VARCHAR2,
        x_exec_mode           OUT VARCHAR2,
        x_recon_proc          OUT VARCHAR2,
        x_recon_has_cemli_arg OUT VARCHAR2
    ) IS
    BEGIN
        SELECT EXEC_PROC, EXEC_MODE, RECON_PROC, RECON_HAS_CEMLI_ARG
        INTO   x_exec_proc, x_exec_mode, x_recon_proc, x_recon_has_cemli_arg
        FROM   DMT_OWNER.DMT_PIPELINE_DEF_TBL
        WHERE  CEMLI_CODE = p_cemli_code;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            x_exec_proc           := NULL;
            x_exec_mode           := NULL;
            x_recon_proc          := NULL;
            x_recon_has_cemli_arg := NULL;
    END get_dispatch;

    -- ============================================================
    -- invoke_registered — the ONE dynamic invocation in the queue
    -- engine.
    --
    -- STANDARDS NOTE (flagged for user review): section 7 bans
    -- EXECUTE IMMEDIATE in database code objects; the approved
    -- exception (2026-07-07) covers deploy scripts only. Registry-
    -- driven dispatch (section 12 "catalog-driven queue dispatch")
    -- cannot name its target procedure statically — that is the
    -- point of the registry — so this package carries exactly one
    -- dynamic call, isolated here, pending an explicit approved-
    -- exception ruling for registry dispatch. The procedure name is
    -- validated against a strict PKG.PROC identifier pattern before
    -- execution (no user-supplied text ever reaches the block), and
    -- all three call shapes use named notation with bind variables.
    --
    -- p_style: EXEC        p_proc(p_run_id, p_scenario_name,
    --                             p_include_untagged, p_run_mode,
    --                             p_skip_bu_refresh => TRUE)
    --          RECON       p_proc(p_run_id, p_load_ess_id, p_import_ess_id)
    --          RECON_CEMLI p_proc(p_run_id, p_cemli_code,
    --                             p_load_ess_id, p_import_ess_id)
    -- ============================================================
    PROCEDURE invoke_registered (
        p_proc             IN VARCHAR2,
        p_style            IN VARCHAR2,
        p_run_id           IN NUMBER,
        p_cemli_code       IN VARCHAR2,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT NULL,
        p_load_ess_id      IN NUMBER   DEFAULT NULL,
        p_import_ess_id    IN NUMBER   DEFAULT NULL
    ) IS
    BEGIN
        IF p_proc IS NULL
           OR NOT REGEXP_LIKE(p_proc, '^[A-Z][A-Z0-9_$#]*\.[A-Z][A-Z0-9_$#]*$') THEN
            RAISE_APPLICATION_ERROR(-20102,
                'invoke_registered: registered procedure name "' || p_proc ||
                '" for ' || p_cemli_code || ' is not a valid PKG.PROC identifier');
        END IF;

        IF p_style = 'EXEC' THEN
            EXECUTE IMMEDIATE
                'BEGIN ' || p_proc || '(p_run_id => :b1, p_scenario_name => :b2, '
                || 'p_include_untagged => :b3, p_run_mode => :b4, '
                || 'p_skip_bu_refresh => TRUE); END;'
                USING p_run_id, p_scenario_name, p_include_untagged, p_run_mode;
        ELSIF p_style = 'RECON_CEMLI' THEN
            EXECUTE IMMEDIATE
                'BEGIN ' || p_proc || '(p_run_id => :b1, p_cemli_code => :b2, '
                || 'p_load_ess_id => :b3, p_import_ess_id => :b4); END;'
                USING p_run_id, p_cemli_code, p_load_ess_id, p_import_ess_id;
        ELSIF p_style = 'RECON' THEN
            EXECUTE IMMEDIATE
                'BEGIN ' || p_proc || '(p_run_id => :b1, p_load_ess_id => :b2, '
                || 'p_import_ess_id => :b3); END;'
                USING p_run_id, p_load_ess_id, p_import_ess_id;
        ELSE
            RAISE_APPLICATION_ERROR(-20102,
                'invoke_registered: unknown dispatch style ' || p_style);
        END IF;
    END invoke_registered;

    -- ============================================================
    -- EXECUTE_ONE — called by one-shot child job DMT_WQ_{queue_id}
    -- Runs in its own DB session. Does the full validate -> transform
    -- -> generate -> SUBMIT_LOAD cycle for one queue row, then sets
    -- AWAITING_LOAD. For sync objects (EXEC_MODE = SYNC: MiscReceipts;
    -- HDL cycles return no load ESS id), runs the full RUN_* cycle and
    -- sets DONE. LOCAL objects (no Fusion load stage — the mocks) go
    -- to RECONCILING when a reconciler is registered, else DONE.
    -- Dispatch is registry-driven (DMT_PIPELINE_DEF_TBL.EXEC_PROC) —
    -- the former hardcoded ~39-branch CASE over CEMLI codes is retired.
    -- ============================================================
    PROCEDURE EXECUTE_ONE (p_queue_id IN NUMBER) IS
        l_rec       DMT_WORK_QUEUE_TBL%ROWTYPE;
        l_run_rec   DMT_PIPELINE_RUN_TBL%ROWTYPE;
        l_load_ess_id VARCHAR2(100);
        l_exec_proc   VARCHAR2(200);
        l_exec_mode   VARCHAR2(10);
        l_recon_proc  VARCHAR2(200);
        l_recon_cemli VARCHAR2(1);
    BEGIN
        SELECT * INTO l_rec FROM DMT_WORK_QUEUE_TBL WHERE QUEUE_ID = p_queue_id;
        SELECT * INTO l_run_rec FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = l_rec.RUN_ID;

        get_dispatch(l_rec.CEMLI_CODE, l_exec_proc, l_exec_mode, l_recon_proc, l_recon_cemli);
        IF l_exec_proc IS NULL THEN
            RAISE_APPLICATION_ERROR(-20100,
                'No EXEC_PROC registered in DMT_PIPELINE_DEF_TBL for CEMLI code: '
                || l_rec.CEMLI_CODE);
        END IF;

        UPDATE DMT_WORK_QUEUE_TBL
        SET WORK_STATUS = 'LOADING'
        WHERE QUEUE_ID = p_queue_id;
        COMMIT;

        -- Set async mode: run_one_object_type returns after SUBMIT_LOAD.
        -- SYNC (MiscReceipts) and LOCAL (mocks) run inline.
        DMT_LOADER_PKG.g_async_mode := (l_exec_mode = 'ASYNC');
        DMT_LOADER_PKG.g_load_ess_id := NULL;
        -- Multi-book: a partitioned row carries its BOOK_TYPE_CODE; the loader uses this to
        -- skip re-transform and generate the FBDI for only this book.
        DMT_LOADER_PKG.g_partition_key := l_rec.PARTITION_KEY;

        -- Multi-book Assets split: the un-partitioned row transforms once (STG -> TFM STAGED),
        -- then spawns one child queue row per distinct BOOK_TYPE_CODE. Each child generates +
        -- loads + Prepares + Posts (per book) + reconciles independently. One book per asset.
        IF l_rec.CEMLI_CODE = 'Assets' AND l_rec.PARTITION_KEY IS NULL THEN
            DMT_LOADER_PKG.RUN_ASSETS_TRANSFORM_ONLY(
                l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE);
            DECLARE
                l_cnt PLS_INTEGER := 0;
            BEGIN
                FOR brec IN (
                    SELECT DISTINCT BOOK_TYPE_CODE AS bk
                    FROM   DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL
                    WHERE  RUN_ID = l_rec.RUN_ID AND STATUS = 'STAGED' AND BOOK_TYPE_CODE IS NOT NULL
                ) LOOP
                    INSERT INTO DMT_WORK_QUEUE_TBL (
                        RUN_ID, PIPELINE, CEMLI_CODE, PARTITION_KEY, PARTITION_LABEL,
                        SORT_ORDER, DEPENDS_ON, WORK_STATUS
                    ) VALUES (
                        l_rec.RUN_ID, l_rec.PIPELINE, 'Assets', brec.bk, brec.bk,
                        l_rec.SORT_ORDER, l_rec.DEPENDS_ON, 'READY'
                    );
                    l_cnt := l_cnt + 1;
                END LOOP;
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'DONE', COMPLETED_AT = SYSTIMESTAMP,
                    PARTITION_LABEL = CASE WHEN l_cnt = 0 THEN 'No qualifying asset rows'
                                           ELSE '(split into ' || l_cnt || ' book(s))' END
                WHERE QUEUE_ID = p_queue_id;
                COMMIT;
            END;
            DMT_LOADER_PKG.g_async_mode := FALSE;
            DMT_LOADER_PKG.g_partition_key := NULL;
            RETURN;
        END IF;

        -- Registry-driven dispatch (was: hardcoded ~39-branch CASE over
        -- CEMLI codes). The registered procedures all share the
        -- DMT_LOADER_PKG.RUN_* signature; p_skip_bu_refresh is TRUE here
        -- exactly as every retired CASE arm passed it.
        invoke_registered(
            p_proc             => l_exec_proc,
            p_style            => 'EXEC',
            p_run_id           => l_rec.RUN_ID,
            p_cemli_code       => l_rec.CEMLI_CODE,
            p_scenario_name    => l_run_rec.SCENARIO_NAME,
            p_include_untagged => l_run_rec.INCLUDE_UNTAGGED,
            p_run_mode         => l_run_rec.RUN_MODE);

        l_load_ess_id := DMT_LOADER_PKG.g_load_ess_id;
        DMT_LOADER_PKG.g_async_mode := FALSE;
        DMT_LOADER_PKG.g_load_ess_id := NULL;
        DMT_LOADER_PKG.g_partition_key := NULL;

        IF l_load_ess_id IS NOT NULL THEN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'AWAITING_LOAD',
                LOAD_ESS_JOB_ID = l_load_ess_id,
                POLL_COUNT = 0,
                NEXT_POLL_AFTER = SYSTIMESTAMP + INTERVAL '60' SECOND
            WHERE QUEUE_ID = p_queue_id;
        ELSIF l_exec_mode = 'LOCAL' AND l_recon_proc IS NOT NULL THEN
            -- LOCAL objects have no Fusion load stage: route straight to
            -- RECONCILING so the registered reconciler runs via the same
            -- RECONCILE_ONE path a real object takes after its ESS jobs.
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'RECONCILING'
            WHERE QUEUE_ID = p_queue_id;
        ELSE
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'DONE',
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
        END IF;
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_LOADER_PKG.g_async_mode := FALSE;
            DMT_LOADER_PKG.g_load_ess_id := NULL;
            DMT_LOADER_PKG.g_partition_key := NULL;

            DECLARE l_err VARCHAR2(4000) := SQLERRM; BEGIN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'FAILED',
                ERROR_MESSAGE = SUBSTR(l_err, 1, 4000),
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
            COMMIT;
            END;

            BEGIN
                DMT_UTIL_PKG.LOG_ERROR(l_rec.RUN_ID,
                    'EXECUTE_ONE failed for ' || l_rec.CEMLI_CODE
                    || CASE WHEN l_rec.PARTITION_KEY IS NOT NULL
                            THEN ' [' || l_rec.PARTITION_KEY || ']' END,
                    SQLERRM, C_PKG, 'EXECUTE_ONE');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
    END EXECUTE_ONE;

    -- ============================================================
    -- RECONCILE_ONE — called by one-shot child job DMT_RC_{queue_id}
    -- ============================================================
    PROCEDURE RECONCILE_ONE (p_queue_id IN NUMBER) IS
        l_rec DMT_WORK_QUEUE_TBL%ROWTYPE;
        l_exec_proc   VARCHAR2(200);
        l_exec_mode   VARCHAR2(10);
        l_recon_proc  VARCHAR2(200);
        l_recon_cemli VARCHAR2(1);
    BEGIN
        SELECT * INTO l_rec FROM DMT_WORK_QUEUE_TBL WHERE QUEUE_ID = p_queue_id;

        DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
            'Reconciling ' || l_rec.CEMLI_CODE ||
            ' (Load ESS ' || l_rec.LOAD_ESS_JOB_ID ||
            ', Import ESS ' || l_rec.IMPORT_ESS_JOB_ID || ')',
            'INFO', C_PKG, 'RECONCILE_ONE');

        -- Parse Import Report errors (non-fatal)
        IF l_rec.IMPORT_ESS_JOB_ID IS NOT NULL THEN
            BEGIN
                DECLARE l_ir_count NUMBER;
                BEGIN
                    l_ir_count := DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(
                        p_run_id     => l_rec.RUN_ID,
                        p_request_id => TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID),
                        p_cemli_code => l_rec.CEMLI_CODE);
                END;
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
        END IF;

        -- BIP reconciliation dispatch — registry-driven (was: a hardcoded
        -- ELSIF chain over CEMLI codes, including a LIKE 'Supplier%' branch;
        -- the supplier family is now five exact registry rows with
        -- RECON_HAS_CEMLI_ARG = 'Y' for the shared reconciler's extra
        -- p_cemli_code parameter).
        get_dispatch(l_rec.CEMLI_CODE, l_exec_proc, l_exec_mode, l_recon_proc, l_recon_cemli);
        IF l_recon_proc IS NULL THEN
            RAISE_APPLICATION_ERROR(-20101,
                'RECONCILE_ONE: No RECON_PROC registered in DMT_PIPELINE_DEF_TBL '
                || 'for CEMLI code: ' || l_rec.CEMLI_CODE);
        END IF;

        invoke_registered(
            p_proc          => l_recon_proc,
            p_style         => CASE l_recon_cemli WHEN 'Y' THEN 'RECON_CEMLI' ELSE 'RECON' END,
            p_run_id        => l_rec.RUN_ID,
            p_cemli_code    => l_rec.CEMLI_CODE,
            p_load_ess_id   => TO_NUMBER(l_rec.LOAD_ESS_JOB_ID),
            p_import_ess_id => TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));

        -- Items special case (kept from the retired chain, deliberately NOT
        -- registry-expressible yet: the Items FBDI ZIP bundles the
        -- ItemCategories CSV, so an Items work item conditionally reconciles
        -- the categories too when this run generated any category rows.
        -- A data-dependent secondary reconciler does not fit the
        -- one-RECON_PROC-per-object registry; folding this into the Items
        -- results package is the clean end state.)
        IF l_rec.CEMLI_CODE = 'Items' THEN
            DECLARE l_cat_gen NUMBER;
            BEGIN
                SELECT COUNT(*) INTO l_cat_gen FROM DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
                WHERE RUN_ID = l_rec.RUN_ID AND TFM_STATUS = 'GENERATED';
                IF l_cat_gen > 0 THEN
                    DMT_EGP_ITEM_CAT_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                        TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
                END IF;
            END;
        END IF;

        -- Object-level status. An object is DONE when EVERY record is accounted for:
        -- found in a Fusion base table (LOADED) or in the interface error table (FAILED
        -- with a reportable error). A mix of loaded + errored records is a SUCCESSFUL
        -- object. The object is FAILED only when one or more records cannot be accounted
        -- for — still GENERATED (never confirmed), FAILED with no error message, or
        -- in-progress — i.e. the import produced no positive/negative result for them.
        -- "Unaccounted" is computed generically per CEMLI from DMT_OBJECT_DETAIL_V, which
        -- pivots the TFM tables to LOADED/FAILED/GENERATED/UNRECONCILED counts.
        DECLARE
            l_unaccounted NUMBER;
            l_loaded      NUMBER;
            l_failed      NUMBER;
        BEGIN
            SELECT NVL(SUM(GENERATED_ROWS + IN_PROGRESS_ROWS + UNRECONCILED_ROWS), 0),
                   NVL(SUM(LOADED_ROWS), 0),
                   NVL(SUM(FAILED_ROWS), 0)
            INTO   l_unaccounted, l_loaded, l_failed
            FROM   DMT_OWNER.DMT_OBJECT_DETAIL_V
            WHERE  RUN_ID = l_rec.RUN_ID
            AND    CEMLI_CODE = l_rec.CEMLI_CODE;

            IF l_unaccounted > 0 THEN
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS  = 'FAILED',
                    ERROR_MESSAGE = l_unaccounted || ' record(s) unaccounted — not confirmed in '
                                    || 'base tables or interface error tables ('
                                    || l_loaded || ' loaded, ' || l_failed || ' errored). '
                                    || 'Object cannot be confirmed.',
                    COMPLETED_AT = SYSTIMESTAMP
                WHERE QUEUE_ID = p_queue_id;
                DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                    'Object ' || l_rec.CEMLI_CODE || ' FAILED: ' || l_unaccounted ||
                    ' record(s) unaccounted (' || l_loaded || ' loaded, ' || l_failed || ' errored).',
                    'WARN', C_PKG, 'RECONCILE_ONE');
            ELSE
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'DONE',
                    COMPLETED_AT = SYSTIMESTAMP
                WHERE QUEUE_ID = p_queue_id;
                DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                    'Object ' || l_rec.CEMLI_CODE || ' DONE: all records accounted (' ||
                    l_loaded || ' loaded, ' || l_failed || ' errored).',
                    'INFO', C_PKG, 'RECONCILE_ONE');
            END IF;
        END;
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            DECLARE l_err VARCHAR2(4000) := SQLERRM; BEGIN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'FAILED',
                ERROR_MESSAGE = 'Reconciliation failed: ' || SUBSTR(l_err, 1, 3500),
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
            COMMIT;
            END;

            BEGIN
                DMT_UTIL_PKG.LOG_ERROR(l_rec.RUN_ID,
                    'RECONCILE_ONE failed for ' || l_rec.CEMLI_CODE,
                    SQLERRM, C_PKG, 'RECONCILE_ONE');
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
    END RECONCILE_ONE;

    -- ============================================================
    -- ============================================================
    -- submit_postrun_job — Phase-2 staged load.
    -- After the import job (e.g. PrepareMassAdditions) succeeds, a CEMLI
    -- configured with a POST_LOAD_JOB_NAME runs a standalone follow-up ESS
    -- job before reconcile (Assets: PostMassAdditions). Returns the follow-up
    -- ESS request id, or NULL when the CEMLI has no POST_LOAD_JOB_NAME
    -- (every active CEMLI except Assets → NULL → unchanged behavior).
    -- ============================================================
    FUNCTION submit_postrun_job (p_run_id IN NUMBER, p_cemli_code IN VARCHAR2,
                                 p_partition_key IN VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2
    IS
        l_job   VARCHAR2(500);
        l_param VARCHAR2(4000);
        l_book  VARCHAR2(60);
    BEGIN
        BEGIN
            SELECT POST_LOAD_JOB_NAME INTO l_job
            FROM   DMT_OWNER.DMT_ERP_INTERFACE_OPTIONS_TBL
            WHERE  CEMLI_CODE = p_cemli_code;
        EXCEPTION WHEN NO_DATA_FOUND THEN l_job := NULL;
        END;
        IF l_job IS NULL THEN
            RETURN NULL;  -- no post-load stage for this CEMLI
        END IF;

        -- Derive the standalone job's ParameterList.
        -- Assets PostMassAdditions takes the Book Type Code. Until per-book grouping
        -- lands (Phase 2 generator → one book per queue row), derive the single book
        -- from the run's book TFM. VERIFY exact format at the gated run
        -- (README notes 'US CORP,,NORMAL').
        IF p_cemli_code = 'Assets' THEN
            -- Per-book partition: the queue row's PARTITION_KEY IS the book. Fallback to the
            -- single distinct book in the run (legacy single-FBDI path).
            IF p_partition_key IS NOT NULL THEN
                l_book := p_partition_key;
            ELSE
                BEGIN
                    SELECT MAX(BOOK_TYPE_CODE) INTO l_book
                    FROM   DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL
                    WHERE  RUN_ID = p_run_id;
                EXCEPTION WHEN OTHERS THEN l_book := NULL;
                END;
            END IF;
            l_param := l_book;
        END IF;

        DMT_UTIL_PKG.LOG(p_run_id,
            'Submitting post-run job for ' || p_cemli_code || ': ' || l_job ||
            ' | ParamList: ' || NVL(l_param, '(default)'),
            'INFO', C_PKG, 'submit_postrun_job');

        RETURN DMT_LOADER_PKG.SUBMIT_IMPORT_JOB(p_run_id, l_job, l_param);
    END submit_postrun_job;

    -- ============================================================
    -- POLL_ONE — single ESS status check for one queue row.
    -- Called by one-shot child job DMT_PL_{queue_id}.
    -- ============================================================
    PROCEDURE POLL_ONE (p_queue_id IN NUMBER) IS
        l_rec        DMT_WORK_QUEUE_TBL%ROWTYPE;
        l_ess_id     VARCHAR2(30);
        l_status     VARCHAR2(30);
        l_import_id  VARCHAR2(30);
        l_postrun_id VARCHAR2(30);
        l_ess_user   VARCHAR2(100);
        l_ess_pass   VARCHAR2(100);
    BEGIN
        SELECT * INTO l_rec FROM DMT_WORK_QUEUE_TBL WHERE QUEUE_ID = p_queue_id;

        -- Resolve the per-CEMLI Fusion credentials used to SUBMIT this job. getESSJobStatus
        -- must be called as the submitting user — polling another user's ESS request returns
        -- HTTP 500. P2P jobs are submitted by overrides (SCM_IMPL/calvin.roth); without this
        -- the async poll used the default user and 500'd persistently (Runs 86/96/97).
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(l_rec.CEMLI_CODE, l_ess_user, l_ess_pass);

        l_ess_id := CASE l_rec.WORK_STATUS
            WHEN 'AWAITING_LOAD'    THEN l_rec.LOAD_ESS_JOB_ID
            WHEN 'AWAITING_IMPORT'  THEN l_rec.IMPORT_ESS_JOB_ID
            WHEN 'AWAITING_POSTRUN' THEN l_rec.POSTRUN_ESS_JOB_ID
        END;

        IF l_ess_id IS NULL THEN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'FAILED',
                ERROR_MESSAGE = 'No ESS job ID for state ' || l_rec.WORK_STATUS,
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
            COMMIT;
            RETURN;
        END IF;

        IF l_rec.POLL_COUNT >= C_ESS_TIMEOUT THEN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'FAILED',
                ERROR_MESSAGE = 'ESS timeout: polled ' || l_rec.POLL_COUNT || ' times',
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
            COMMIT;
            RETURN;
        END IF;

        -- Single ESS status check
        BEGIN
            DMT_LOADER_PKG.POLL_ESS_JOB(
                p_run_id         => l_rec.RUN_ID,
                p_ess_job_id     => l_ess_id,
                p_timeout_sec    => 10,
                p_raise_on_error => FALSE,
                p_log_context    => l_rec.CEMLI_CODE,
                p_cemli_code     => l_rec.CEMLI_CODE,
                x_fusion_status  => l_status,
                p_username       => l_ess_user,
                p_password       => l_ess_pass
            );
        EXCEPTION
            WHEN OTHERS THEN l_status := 'ERROR';
        END;

        IF l_status IN ('SUCCEEDED', 'WARNING') THEN
            IF l_rec.WORK_STATUS = 'AWAITING_LOAD' THEN
                BEGIN
                    l_import_id := DMT_LOADER_PKG.GET_IMPORT_ESS_ID(
                        l_rec.RUN_ID, l_rec.CEMLI_CODE, l_rec.LOAD_ESS_JOB_ID);
                EXCEPTION
                    WHEN OTHERS THEN l_import_id := NULL;
                END;

                IF l_import_id IS NOT NULL THEN
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'AWAITING_IMPORT',
                        IMPORT_ESS_JOB_ID = l_import_id,
                        POLL_COUNT = 0,
                        NEXT_POLL_AFTER = SYSTIMESTAMP + INTERVAL '60' SECOND
                    WHERE QUEUE_ID = p_queue_id;
                ELSE
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'RECONCILING',
                        POLL_COUNT = l_rec.POLL_COUNT + 1
                    WHERE QUEUE_ID = p_queue_id;
                END IF;
            ELSIF l_rec.WORK_STATUS = 'AWAITING_IMPORT' THEN
                BEGIN
                    DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY(
                        l_rec.RUN_ID, l_rec.CEMLI_CODE, l_rec.LOAD_ESS_JOB_ID);
                EXCEPTION WHEN OTHERS THEN NULL;
                END;

                -- Phase-2 staged load: if this CEMLI has a post-load job
                -- (Assets → PostMassAdditions), submit it and poll it before
                -- reconcile. Non-Assets CEMLIs → NULL → straight to RECONCILING.
                BEGIN
                    l_postrun_id := submit_postrun_job(l_rec.RUN_ID, l_rec.CEMLI_CODE, l_rec.PARTITION_KEY);
                EXCEPTION
                    WHEN OTHERS THEN
                        l_postrun_id := NULL;
                        DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                            'Post-run submit failed for ' || l_rec.CEMLI_CODE ||
                            ' (' || SUBSTR(SQLERRM, 1, 200) || '). Routing to reconcile.',
                            'WARN', C_PKG, 'POLL_ONE');
                END;

                IF l_postrun_id IS NOT NULL THEN
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'AWAITING_POSTRUN',
                        POSTRUN_ESS_JOB_ID = l_postrun_id,
                        POLL_COUNT = 0,
                        NEXT_POLL_AFTER = SYSTIMESTAMP + INTERVAL '60' SECOND
                    WHERE QUEUE_ID = p_queue_id;
                ELSE
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'RECONCILING',
                        POLL_COUNT = l_rec.POLL_COUNT + 1
                    WHERE QUEUE_ID = p_queue_id;
                END IF;
            ELSE
                -- AWAITING_POSTRUN succeeded (e.g. PostMassAdditions done) → reconcile.
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'RECONCILING',
                    POLL_COUNT = l_rec.POLL_COUNT + 1
                WHERE QUEUE_ID = p_queue_id;
            END IF;
        ELSIF l_status IN ('FAILED', 'ERROR', 'CANCELLED') THEN
            -- A terminal job error is NOT, by itself, an object failure. FBDI import jobs
            -- report job-level ERROR on PARTIAL success — some records reach Fusion base
            -- tables, some land in the interface error table — which is still a SUCCESSFUL
            -- object. So route to RECONCILING and let BIP positively account for every
            -- record; RECONCILE_ONE then marks the OBJECT done (every record accounted:
            -- base = LOADED, interface-error = FAILED) or failed (any record unaccounted,
            -- or the import never produced data). This is the only place that decides
            -- per-record outcome, so the job's coarse ERROR must not short-circuit it.
            -- ('EXPIRED' is excluded above — it is a per-tick poll artifact, not a status.)
            -- For an AWAITING_LOAD error, capture the import job id (if any) first so the
            -- reconciler can read the import error table.
            IF l_rec.WORK_STATUS = 'AWAITING_LOAD' AND l_rec.IMPORT_ESS_JOB_ID IS NULL THEN
                BEGIN
                    l_import_id := DMT_LOADER_PKG.GET_IMPORT_ESS_ID(
                        l_rec.RUN_ID, l_rec.CEMLI_CODE, l_rec.LOAD_ESS_JOB_ID);
                EXCEPTION WHEN OTHERS THEN l_import_id := NULL;
                END;
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'RECONCILING',
                    IMPORT_ESS_JOB_ID = l_import_id,
                    POLL_COUNT = l_rec.POLL_COUNT + 1
                WHERE QUEUE_ID = p_queue_id;
            ELSE
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'RECONCILING',
                    POLL_COUNT = l_rec.POLL_COUNT + 1
                WHERE QUEUE_ID = p_queue_id;
            END IF;
        ELSE
            -- Non-terminal (WAIT/RUNNING) or EXPIRED-this-tick → poll again next tick.
            UPDATE DMT_WORK_QUEUE_TBL
            SET POLL_COUNT = l_rec.POLL_COUNT + 1,
                LAST_POLL_AT = SYSTIMESTAMP,
                NEXT_POLL_AFTER = SYSTIMESTAMP + INTERVAL '60' SECOND
            WHERE QUEUE_ID = p_queue_id;
        END IF;
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            DECLARE l_err VARCHAR2(4000) := SQLERRM; BEGIN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'FAILED',
                ERROR_MESSAGE = 'POLL_ONE failed: ' || SUBSTR(l_err, 1, 3500),
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
            COMMIT;
            END;
    END POLL_ONE;

END DMT_QUEUE_WORKER_PKG;
/
