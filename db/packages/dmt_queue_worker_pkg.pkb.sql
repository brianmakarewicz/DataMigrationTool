-- PACKAGE BODY DMT_QUEUE_WORKER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_QUEUE_WORKER_PKG"
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_QUEUE_WORKER_PKG';

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
    -- point of the registry — so this package carries this dynamic
    -- call plus the catalog-driven accounting reads below, all
    -- pending an explicit approved-exception ruling for registry
    -- dispatch. The procedure name is validated against a strict
    -- PKG.PROC identifier pattern before execution (no user-supplied
    -- text ever reaches the block), and all call shapes use named
    -- notation with bind variables.
    --
    -- p_style: EXEC        p_proc(p_run_id, p_scenario_name,
    --                             p_run_mode,
    --                             p_skip_bu_refresh => TRUE)
    --          RECON       p_proc(p_run_id, p_load_ess_id, p_import_ess_id)
    --          RECON_CEMLI p_proc(p_run_id, p_cemli_code,
    --                             p_load_ess_id, p_import_ess_id)
    -- (p_include_untagged is REMOVED end-to-end: scenarios are
    --  mandatory at ingestion — Overview glossary "Scenario" — so an
    --  untagged-row switch cannot exist; design section 12 removal.)
    -- ============================================================
    PROCEDURE invoke_registered (
        p_proc             IN VARCHAR2,
        p_style            IN VARCHAR2,
        p_run_id           IN NUMBER,
        p_cemli_code       IN VARCHAR2,
        p_scenario_name    IN VARCHAR2 DEFAULT NULL,
        p_run_mode         IN VARCHAR2 DEFAULT NULL,
        p_load_ess_id      IN NUMBER   DEFAULT NULL,
        p_import_ess_id    IN NUMBER   DEFAULT NULL,
        p_work_queue_id    IN NUMBER   DEFAULT NULL
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
                || 'p_run_mode => :b3, '
                || 'p_skip_bu_refresh => TRUE); END;'
                USING p_run_id, p_scenario_name, p_run_mode;
        ELSIF p_style = 'RECON_CEMLI' THEN
            EXECUTE IMMEDIATE
                'BEGIN ' || p_proc || '(p_run_id => :b1, p_cemli_code => :b2, '
                || 'p_load_ess_id => :b3, p_import_ess_id => :b4, '
                || 'p_work_queue_id => :b5); END;'
                USING p_run_id, p_cemli_code, p_load_ess_id, p_import_ess_id, p_work_queue_id;
        ELSIF p_style = 'RECON' THEN
            EXECUTE IMMEDIATE
                'BEGIN ' || p_proc || '(p_run_id => :b1, p_load_ess_id => :b2, '
                || 'p_import_ess_id => :b3, p_work_queue_id => :b4); END;'
                USING p_run_id, p_load_ess_id, p_import_ess_id, p_work_queue_id;
        ELSE
            RAISE_APPLICATION_ERROR(-20102,
                'invoke_registered: unknown dispatch style ' || p_style);
        END IF;
    END invoke_registered;

    -- ============================================================
    -- assert_catalog_identifier — validate a catalog-supplied table
    -- or column name before it is concatenated into a SQL text.
    -- Same posture as invoke_registered: the values come only from
    -- the seeded registry DMT_CEMLI_CATALOG_TBL, and are still
    -- pattern-checked so no non-identifier text can ever reach a
    -- dynamic statement.
    -- ============================================================
    PROCEDURE assert_catalog_identifier (p_name IN VARCHAR2, p_what IN VARCHAR2) IS
    BEGIN
        IF p_name IS NULL
           OR NOT REGEXP_LIKE(p_name, '^[A-Z][A-Z0-9_$#]*$') THEN
            RAISE_APPLICATION_ERROR(-20103,
                'Catalog ' || p_what || ' "' || p_name ||
                '" is not a valid SQL identifier (DMT_CEMLI_CATALOG_TBL seed defect)');
        END IF;
    END assert_catalog_identifier;

    -- ============================================================
    -- ACCOUNT_ROWS — catalog-driven accounting counts (design
    -- section 5 "Object-status accounting": an object is DONE iff
    -- every record is accounted for — base-loaded OR interface-
    -- errored; FAILED only if any record is unaccounted).
    -- Replaces the retired read of the hardcoded legacy view
    -- DMT_OBJECT_DETAIL_V: counts come from DMT_CEMLI_CATALOG_TBL
    -- (one row per record type: TFM_TABLE, STATUS_COLUMN,
    -- ROW_FILTER). Objects with no TFM_TABLE registered (mock/
    -- unbuilt record types) contribute zero rows.
    -- Whole-object accounting for every work item — partition-aware
    -- accounting (PARTITION_KEY other than ALL/NULL) is Stage C
    -- task 5 (partition model rework), noted 2026-07-08.
    -- ============================================================
    PROCEDURE ACCOUNT_ROWS (
        p_run_id      IN  NUMBER,
        p_cemli_code  IN  VARCHAR2,
        x_total       OUT NUMBER,
        x_loaded      OUT NUMBER,
        x_failed      OUT NUMBER,
        x_unaccounted OUT NUMBER
    ) IS
        l_sql   VARCHAR2(4000);
        l_cnt   NUMBER;
        l_ld    NUMBER;
        l_fl    NUMBER;
        l_un    NUMBER;
    BEGIN
        x_total       := 0;
        x_loaded      := 0;
        x_failed      := 0;
        x_unaccounted := 0;

        FOR r IN (
            SELECT TFM_TABLE, NVL(STATUS_COLUMN, 'TFM_STATUS') AS STATUS_COLUMN, ROW_FILTER
            FROM   DMT_OWNER.DMT_CEMLI_CATALOG_TBL
            WHERE  CEMLI_CODE = p_cemli_code
            AND    TFM_TABLE IS NOT NULL
            ORDER BY SORT_ORDER
        ) LOOP
            assert_catalog_identifier(r.TFM_TABLE, 'TFM_TABLE');
            assert_catalog_identifier(r.STATUS_COLUMN, 'STATUS_COLUMN');

            -- Accounted = LOADED, or FAILED with non-empty ERROR_TEXT.
            -- FAILED + empty ERROR_TEXT is the derived UNRECONCILED
            -- classification (Overview row-status table) — unaccounted.
            l_sql :=
                'SELECT COUNT(*), '
                || 'SUM(CASE WHEN ' || r.STATUS_COLUMN || ' = ''LOADED'' THEN 1 ELSE 0 END), '
                || 'SUM(CASE WHEN ' || r.STATUS_COLUMN || ' = ''FAILED'''
                || '          AND ERROR_TEXT IS NOT NULL'
                || '          AND DBMS_LOB.GETLENGTH(ERROR_TEXT) > 0 THEN 1 ELSE 0 END) '
                || 'FROM DMT_OWNER.' || r.TFM_TABLE
                || ' WHERE RUN_ID = :run_id'
                || CASE WHEN r.ROW_FILTER IS NOT NULL
                        THEN ' AND ' || r.ROW_FILTER END;

            EXECUTE IMMEDIATE l_sql INTO l_cnt, l_ld, l_fl USING p_run_id;

            l_un := l_cnt - NVL(l_ld, 0) - NVL(l_fl, 0);
            x_total       := x_total       + l_cnt;
            x_loaded      := x_loaded      + NVL(l_ld, 0);
            x_failed      := x_failed      + NVL(l_fl, 0);
            x_unaccounted := x_unaccounted + l_un;
        END LOOP;
    END ACCOUNT_ROWS;

    -- ============================================================
    -- MARK_GENERATED_ROWS_FAILED — the section-5 [LOAD_ERROR] rule
    -- made catalog-generic: "When the load ESS job fails, every
    -- GENERATED row of that ZIP is marked FAILED with this tag plus
    -- the job's diagnostics" (tag table, [LOAD_ERROR] row). Also the
    -- timeout trigger (section 2 Timeouts: "when it expires, every
    -- GENERATED row of the file is marked FAILED with a
    -- [LOAD_ERROR]-tagged timeout message ... and reconciliation
    -- still runs"). ERROR_TEXT accumulates via APPEND_ERROR — a row
    -- later confirmed in Fusion is flipped LOADED by reconciliation
    -- with the timeout text kept as history.
    -- ============================================================
    PROCEDURE MARK_GENERATED_ROWS_FAILED (
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2,
        p_error_text IN VARCHAR2
    ) IS
        l_sql VARCHAR2(4000);
    BEGIN
        FOR r IN (
            SELECT TFM_TABLE, NVL(STATUS_COLUMN, 'TFM_STATUS') AS STATUS_COLUMN, ROW_FILTER
            FROM   DMT_OWNER.DMT_CEMLI_CATALOG_TBL
            WHERE  CEMLI_CODE = p_cemli_code
            AND    TFM_TABLE IS NOT NULL
            ORDER BY SORT_ORDER
        ) LOOP
            assert_catalog_identifier(r.TFM_TABLE, 'TFM_TABLE');
            assert_catalog_identifier(r.STATUS_COLUMN, 'STATUS_COLUMN');

            l_sql :=
                'UPDATE DMT_OWNER.' || r.TFM_TABLE
                || ' SET ' || r.STATUS_COLUMN || ' = ''FAILED'','
                || ' ERROR_TEXT = DMT_OWNER.DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, :msg)'
                || ' WHERE RUN_ID = :run_id'
                || ' AND ' || r.STATUS_COLUMN || ' = ''GENERATED'''
                || CASE WHEN r.ROW_FILTER IS NOT NULL
                        THEN ' AND ' || r.ROW_FILTER END;

            EXECUTE IMMEDIATE l_sql USING p_error_text, p_run_id;
        END LOOP;
        COMMIT;
    END MARK_GENERATED_ROWS_FAILED;

    -- ============================================================
    -- apply_accounting_gate — THE single accounting gate. The only
    -- code that writes WORK_STATUS = DONE (proposed rule "Terminal
    -- work-item states pass one accounting gate", 2026-07-08).
    -- Overview work-item status table:
    --   DONE   "Item finished and every row is accounted for — each
    --           row ended either LOADED ... or FAILED with a
    --           reportable error. Rows may have failed; DONE means
    --           nothing is unexplained."
    --   FAILED "Item ended with at least one row unaccounted for".
    -- ============================================================
    PROCEDURE apply_accounting_gate (
        p_queue_id   IN NUMBER,
        p_run_id     IN NUMBER,
        p_cemli_code IN VARCHAR2
    ) IS
        l_total       NUMBER;
        l_loaded      NUMBER;
        l_failed      NUMBER;
        l_unaccounted NUMBER;
    BEGIN
        ACCOUNT_ROWS(p_run_id, p_cemli_code,
                     l_total, l_loaded, l_failed, l_unaccounted);

        IF l_unaccounted > 0 THEN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS  = 'FAILED',
                ERROR_MESSAGE = l_unaccounted || ' record(s) unaccounted — not confirmed in '
                                || 'base tables or interface error tables ('
                                || l_loaded || ' loaded, ' || l_failed || ' errored). '
                                || 'Object cannot be confirmed.',
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
            DMT_UTIL_PKG.LOG(p_run_id,
                'Object ' || p_cemli_code || ' FAILED: ' || l_unaccounted ||
                ' record(s) unaccounted (' || l_loaded || ' loaded, ' || l_failed || ' errored).',
                'WARN', C_PKG, 'apply_accounting_gate');
        ELSE
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'DONE',
                COMPLETED_AT = SYSTIMESTAMP
            WHERE QUEUE_ID = p_queue_id;
            DMT_UTIL_PKG.LOG(p_run_id,
                'Object ' || p_cemli_code || ' DONE: all records accounted (' ||
                l_loaded || ' loaded, ' || l_failed || ' errored of ' || l_total || ').',
                'INFO', C_PKG, 'apply_accounting_gate');
        END IF;
    END apply_accounting_gate;

    -- ============================================================
    -- EXECUTE_ONE — called by one-shot child job DMT_WQ_{queue_id}
    -- Runs in its own DB session. Does the full validate -> transform
    -- -> generate -> SUBMIT_LOAD cycle for one queue row. The item
    -- keeps the processing status it was claimed with (PROCESSING —
    -- the status covering the whole data phase)
    -- for the WHOLE data phase; it leaves it only when the load is
    -- submitted (→ AWAITING_LOAD) or the phase settles (Overview
    -- work-item status table, PROCESSING row: "the item leaves
    -- PROCESSING when the load is submitted (→ LOADING/AWAITING_LOAD)
    -- or the phase fails").
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

        -- A7b (2026-07-08): the premature WORK_STATUS = 'LOADING' write that
        -- used to sit here is removed — LOADING before validate/transform/
        -- generate contradicted the Overview status table (LOADING = "Load
        -- submission in progress"). The row stays in its claimed processing
        -- status (PROCESSING) until the load submission completes.

        -- Set async mode: run_one_object_type returns after SUBMIT_LOAD.
        -- SYNC (MiscReceipts) and LOCAL (mocks) run inline.
        DMT_LOADER_PKG.g_async_mode := (l_exec_mode = 'ASYNC');
        DMT_LOADER_PKG.g_load_ess_id := NULL;
        -- Spawn-per-partition: a partitioned child row carries its single partition value
        -- (a BOOK_TYPE_CODE / BATCH_ID); the loader uses this to skip re-transform and
        -- generate/load only that partition.
        DMT_LOADER_PKG.g_partition_key := l_rec.PARTITION_KEY;
        -- Work-queue-ID core (2026-07-20): the id of the item generating these rows, so
        -- the generators stamp WORK_QUEUE_ID and reconcile sweeps only this item's rows.
        DMT_LOADER_PKG.g_work_queue_id := p_queue_id;

        -- Spawn-per-partition split (generalized from the Assets-only per-book path,
        -- 2026-07-20). An object configured in DMT_CEMLI_SPLIT_CFG with a
        -- CHILD_PARTITION_COLUMN loads by: the un-partitioned PARENT row transforms once
        -- (STG -> TFM STAGED), then spawns one child work-queue item per distinct value
        -- of that column. Each child generates + loads + reconciles + sweeps ONLY its
        -- own partition (scoped by WORK_QUEUE_ID) and settles independently.
        -- Assets -> BOOK_TYPE_CODE, Items -> BATCH_ID, Requisitions -> BATCH_ID.
        IF l_rec.PARTITION_KEY IS NULL THEN
            DECLARE
                l_child_col   VARCHAR2(30);
                l_tfm_table   VARCHAR2(128);
            BEGIN
                BEGIN
                    SELECT CHILD_PARTITION_COLUMN, TFM_TABLE
                    INTO   l_child_col, l_tfm_table
                    FROM   DMT_OWNER.DMT_CEMLI_SPLIT_CFG
                    WHERE  CEMLI_CODE = l_rec.CEMLI_CODE;
                EXCEPTION WHEN NO_DATA_FOUND THEN
                    l_child_col := NULL;
                END;

                IF l_child_col IS NOT NULL THEN
                    -- 1. Transform-only pass (validate + STG -> TFM STAGED, no generate).
                    --    Generalizes RUN_ASSETS_TRANSFORM_ONLY to any configured object.
                    DMT_LOADER_PKG.RUN_TRANSFORM_ONLY(
                        p_run_id        => l_rec.RUN_ID,
                        p_cemli_code    => l_rec.CEMLI_CODE,
                        p_scenario_name => l_run_rec.SCENARIO_NAME,
                        p_run_mode      => l_run_rec.RUN_MODE);

                    -- 2. Spawn one READY child per distinct partition value, tagged with
                    --    PARENT_QUEUE_ID for traceability. Dynamic because the TFM table
                    --    and partition column come from the registry.
                    DECLARE
                        l_cnt   PLS_INTEGER := 0;
                        l_keys  SYS.ODCIVARCHAR2LIST;
                    BEGIN
                        EXECUTE IMMEDIATE
                            'SELECT DISTINCT TO_CHAR(' || l_child_col || ') FROM DMT_OWNER.' || l_tfm_table ||
                            ' WHERE RUN_ID = :b1 AND TFM_STATUS = ''STAGED'' AND ' || l_child_col || ' IS NOT NULL'
                            BULK COLLECT INTO l_keys USING l_rec.RUN_ID;

                        IF l_keys IS NOT NULL THEN
                            FOR i IN 1 .. l_keys.COUNT LOOP
                                INSERT INTO DMT_WORK_QUEUE_TBL (
                                    RUN_ID, PIPELINE, CEMLI_CODE, PARTITION_KEY, PARTITION_LABEL,
                                    PARENT_QUEUE_ID, SORT_ORDER, DEPENDS_ON, WORK_STATUS
                                ) VALUES (
                                    l_rec.RUN_ID, l_rec.PIPELINE, l_rec.CEMLI_CODE, l_keys(i), l_keys(i),
                                    p_queue_id, l_rec.SORT_ORDER, l_rec.DEPENDS_ON, 'READY'
                                );
                                l_cnt := l_cnt + 1;
                            END LOOP;
                        END IF;

                        -- Accounting-gate exemption (mirrors the Assets per-book rule):
                        -- this parent row is split BOOKKEEPING, not a data item. Its
                        -- records are owned and accounted by the per-partition child
                        -- items spawned above, so it is marked DONE directly.
                        UPDATE DMT_WORK_QUEUE_TBL
                        SET WORK_STATUS = 'DONE', COMPLETED_AT = SYSTIMESTAMP,
                            PARTITION_LABEL = CASE WHEN l_cnt = 0 THEN 'No qualifying rows'
                                                   ELSE '(split into ' || l_cnt || ' partition(s))' END
                        WHERE QUEUE_ID = p_queue_id;
                        COMMIT;
                    END;

                    DMT_LOADER_PKG.g_async_mode := FALSE;
                    DMT_LOADER_PKG.g_partition_key := NULL;
                    DMT_LOADER_PKG.g_work_queue_id := NULL;
                    RETURN;
                END IF;
            END;
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
            p_run_mode         => l_run_rec.RUN_MODE);

        l_load_ess_id := DMT_LOADER_PKG.g_load_ess_id;
        DMT_LOADER_PKG.g_async_mode := FALSE;
        DMT_LOADER_PKG.g_load_ess_id := NULL;
        DMT_LOADER_PKG.g_partition_key := NULL;
        DMT_LOADER_PKG.g_work_queue_id := NULL;

        IF l_load_ess_id IS NOT NULL THEN
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'AWAITING_LOAD',
                LOAD_ESS_JOB_ID = l_load_ess_id,
                POLL_COUNT = 0,
                NEXT_POLL_AFTER = SYS_EXTRACT_UTC(SYSTIMESTAMP) + INTERVAL '60' SECOND
            WHERE QUEUE_ID = p_queue_id;
        ELSIF l_recon_proc IS NOT NULL THEN
            -- No load ESS id (LOCAL objects, or a cycle that reconciles
            -- separately): route to RECONCILING so the registered
            -- reconciler + the accounting gate settle the item on the
            -- same RECONCILE_ONE path a real object takes after its jobs.
            UPDATE DMT_WORK_QUEUE_TBL
            SET WORK_STATUS = 'RECONCILING'
            WHERE QUEUE_ID = p_queue_id;
        ELSE
            -- A4 (2026-07-08): no more unconditional DONE. SYNC/HDL cycles
            -- (loader ran its full inline cycle, no queue-dispatched
            -- reconciler) still settle ONLY through the accounting gate —
            -- section 5 "Object-status accounting": DONE iff every record
            -- is accounted for; FAILED if any record is unaccounted.
            apply_accounting_gate(p_queue_id, l_rec.RUN_ID, l_rec.CEMLI_CODE);
        END IF;
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_LOADER_PKG.g_async_mode := FALSE;
            DMT_LOADER_PKG.g_load_ess_id := NULL;
            DMT_LOADER_PKG.g_partition_key := NULL;
            DMT_LOADER_PKG.g_work_queue_id := NULL;

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
            p_import_ess_id => TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID),
            -- Work-queue-ID core: the reconciler sweeps only THIS item's rows.
            -- For a spawn-per-partition child this is its own (child) queue id;
            -- for a single-item object it is the object's own queue id.
            p_work_queue_id => p_queue_id);

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
                        TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID),
                        p_work_queue_id => p_queue_id);
                END IF;
            END;
        END IF;

        -- B1 (2026-07-08): the object-level DONE/FAILED decision now runs
        -- through the single catalog-driven accounting gate (was: an inline
        -- read of the hardcoded legacy DMT_OBJECT_DETAIL_V).
        apply_accounting_gate(p_queue_id, l_rec.RUN_ID, l_rec.CEMLI_CODE);
        COMMIT;

    EXCEPTION
        -- Code-classified failure split (run 179 fix). The old blanket handler
        -- failed the whole object on ANY reconcile exception -- including a
        -- single transient transport blip during the BIP verify call. Run 179:
        -- MiscReceipts and Expenditures both LOADED and IMPORTED cleanly, then a
        -- one-off ORA-29273 (HTTP request failed) on a BIP fetch marked the whole
        -- object FAILED with 0 records, even though the data was already in Fusion.
        --
        -- A transient transport failure is NOT the object's verdict. On these we
        -- route the work item back to RECONCILING so the poller re-spawns
        -- DMT_RC_{queue_id} next tick and re-runs the verify (mirrors the existing
        -- "retry next tick" idiom: dispatch_reconcile re-dispatches any RECONCILING
        -- row whose one-shot child job has auto-dropped). We retry up to 3 attempts
        -- total, tracked in a reconcile-owned sentinel in ERROR_MESSAGE
        -- ('[RECONCILE_RETRY n]') -- nothing else reads ERROR_MESSAGE as data, and
        -- POLL_COUNT still carries stale AWAITING-phase poll history at this point,
        -- so it cannot be compared to a small cap. After 3 exhausted attempts we
        -- fail with an honest message that says the load could not be VERIFIED --
        -- not that the data failed. Any other exception (genuine BIP/SOAP
        -- application fault, bad SQL, etc.) fails immediately, exactly as before.
        WHEN OTHERS THEN
            DECLARE
                C_MAX_RETRY  CONSTANT PLS_INTEGER := 3;
                l_err        VARCHAR2(4000) := SQLERRM;
                l_code       PLS_INTEGER    := SQLCODE;
                l_transient  BOOLEAN;
                l_msg        VARCHAR2(4000);
                l_attempt    PLS_INTEGER;
            BEGIN
                -- HTTP / network transport codes only. Primary case is ORA-29273
                -- (UTL_HTTP request failed); the rest are transfer/TNS timeouts and
                -- connection resets seen on the same BIP/ESS calls. SQLCODE is
                -- negative for ORA-nnnnn errors.
                l_transient := l_code IN (
                    -29273,  -- HTTP request failed
                    -29276,  -- transfer timeout
                    -12170,  -- TNS: connect timeout occurred
                    -12535,  -- TNS: operation timed out
                    -12547,  -- TNS: lost contact
                    -12571   -- TNS: packet writer failure
                );

                IF l_transient THEN
                    -- Prior attempt count from the reconcile-owned sentinel.
                    BEGIN
                        SELECT NVL(TO_NUMBER(
                                 REGEXP_SUBSTR(ERROR_MESSAGE,
                                   '\[RECONCILE_RETRY ([0-9]+)\]', 1, 1, NULL, 1)), 0)
                        INTO   l_attempt
                        FROM   DMT_WORK_QUEUE_TBL
                        WHERE  QUEUE_ID = p_queue_id;
                    EXCEPTION WHEN OTHERS THEN
                        l_attempt := 0;
                    END;
                    l_attempt := l_attempt + 1;

                    IF l_attempt < C_MAX_RETRY THEN
                        -- Route back to RECONCILING for another tick. Stamp the
                        -- attempt so the next failure can count. Do NOT set
                        -- COMPLETED_AT -- the item is not terminal.
                        UPDATE DMT_WORK_QUEUE_TBL
                        SET WORK_STATUS = 'RECONCILING',
                            ERROR_MESSAGE = '[RECONCILE_RETRY ' || l_attempt || '] '
                                || 'transient transport failure, retrying: '
                                || SUBSTR(l_err, 1, 3400)
                        WHERE QUEUE_ID = p_queue_id;
                        COMMIT;

                        BEGIN
                            DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                                'RECONCILE_ONE transient transport failure for '
                                || l_rec.CEMLI_CODE || ' (attempt ' || l_attempt
                                || ' of ' || C_MAX_RETRY || '); routing back to '
                                || 'RECONCILING for retry next tick ('
                                || SUBSTR(l_err, 1, 300) || ')',
                                'WARN', C_PKG, 'RECONCILE_ONE');
                        EXCEPTION WHEN OTHERS THEN NULL;
                        END;
                    ELSE
                        -- Cap reached: fail honestly. The data may well be loaded;
                        -- we simply could not VERIFY it after 3 tries.
                        l_msg := 'Reconciliation could not be verified after '
                            || C_MAX_RETRY || ' attempts (last error: '
                            || SUBSTR(l_err, 1, 3400) || ')';
                        UPDATE DMT_WORK_QUEUE_TBL
                        SET WORK_STATUS = 'FAILED',
                            ERROR_MESSAGE = SUBSTR(l_msg, 1, 4000),
                            COMPLETED_AT = SYSTIMESTAMP
                        WHERE QUEUE_ID = p_queue_id;
                        COMMIT;

                        BEGIN
                            DMT_UTIL_PKG.LOG_ERROR(l_rec.RUN_ID,
                                'RECONCILE_ONE could not verify ' || l_rec.CEMLI_CODE
                                || ' after ' || C_MAX_RETRY || ' transient attempts',
                                SQLERRM, C_PKG, 'RECONCILE_ONE');
                        EXCEPTION WHEN OTHERS THEN NULL;
                        END;
                    END IF;
                ELSE
                    -- Non-transient (genuine application fault): fail immediately,
                    -- exactly as the original blanket handler did.
                    UPDATE DMT_WORK_QUEUE_TBL
                    SET WORK_STATUS = 'FAILED',
                        ERROR_MESSAGE = 'Reconciliation failed: ' || SUBSTR(l_err, 1, 3500),
                        COMPLETED_AT = SYSTIMESTAMP
                    WHERE QUEUE_ID = p_queue_id;
                    COMMIT;

                    BEGIN
                        DMT_UTIL_PKG.LOG_ERROR(l_rec.RUN_ID,
                            'RECONCILE_ONE failed for ' || l_rec.CEMLI_CODE,
                            SQLERRM, C_PKG, 'RECONCILE_ONE');
                    EXCEPTION WHEN OTHERS THEN NULL;
                    END;
                END IF;
            END;
    END RECONCILE_ONE;

    -- ============================================================
    -- submit_postrun_job — Phase-2 staged load.
    -- After the import job (e.g. PrepareMassAdditions) succeeds, a CEMLI
    -- whose registry row carries a POSTRUN_JOB runs a standalone follow-up
    -- ESS job before reconcile (Assets: PostMassAdditions). Returns the
    -- follow-up ESS request id, or NULL when the CEMLI has no POSTRUN_JOB
    -- (every active CEMLI except Assets → NULL → unchanged behavior).
    -- C5 (2026-07-08): the job name is read from DMT_PIPELINE_DEF_TBL
    -- .POSTRUN_JOB — the section-6 registry column ("POSTRUN_JOB (the
    -- per-object post-run ESS job — today only Assets has one ...)").
    -- The duplicate POST_LOAD_JOB_NAME on DMT_ERP_INTERFACE_OPTIONS_TBL
    -- is no longer read (one fact, one home); the column itself is left
    -- for the ERP-options triage.
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
            SELECT POSTRUN_JOB INTO l_job
            FROM   DMT_OWNER.DMT_PIPELINE_DEF_TBL
            WHERE  CEMLI_CODE = p_cemli_code;
        EXCEPTION WHEN NO_DATA_FOUND THEN l_job := NULL;
        END;
        IF l_job IS NULL THEN
            RETURN NULL;  -- no post-run stage for this CEMLI
        END IF;

        -- The registry stores the Fusion form 'package;JobDefinition'
        -- (semicolon, as FUN_ERP_INTERFACE_OPTIONS does); SUBMIT_IMPORT_JOB
        -- needs the comma form. Convert the last semicolon.
        IF INSTR(l_job, ';', -1) > 0 THEN
            l_job := SUBSTR(l_job, 1, INSTR(l_job, ';', -1) - 1)
                     || ','
                     || SUBSTR(l_job, INSTR(l_job, ';', -1) + 1);
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
        l_timeout_min PLS_INTEGER;
        l_recon_proc  VARCHAR2(200);
        l_exec_proc   VARCHAR2(200);
        l_exec_mode   VARCHAR2(10);
        l_recon_cemli VARCHAR2(1);
    BEGIN
        SELECT * INTO l_rec FROM DMT_WORK_QUEUE_TBL WHERE QUEUE_ID = p_queue_id;

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

        -- A3 (2026-07-08): configurable poll timeout — section 2 "Timeouts
        -- (decided 2026-07-07)": "The polling timeout is configurable —
        -- ESS_POLL_TIMEOUT_MINUTES in DMT_CONFIG_TBL (default 30) ... A
        -- timeout is a trigger for the failure path, never a verdict: when
        -- it expires, every GENERATED row of the file is marked FAILED with
        -- a [LOAD_ERROR]-tagged timeout message ... and reconciliation still
        -- runs ... The work item ends DONE or FAILED by the accounting rule
        -- alone, never directly from the timer."
        -- POLL_COUNT approximates elapsed minutes: the heartbeat schedules
        -- one poll per ~60-second tick (C_POLL_INTERVAL / NEXT_POLL_AFTER).
        -- Checked BEFORE any Fusion call so the timeout works offline too.
        -- Engine re-review ITEM 2 (2026-07-08): a non-numeric config value
        -- must not raise here — the outer handler would FAIL the work item,
        -- turning a config typo into a verdict. On conversion failure, WARN
        -- and fall back to the documented default of 30 minutes.
        BEGIN
            l_timeout_min := NVL(TO_NUMBER(DMT_UTIL_PKG.GET_CONFIG('ESS_POLL_TIMEOUT_MINUTES')), 30);
        EXCEPTION
            WHEN VALUE_ERROR OR INVALID_NUMBER THEN
                DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                    'ESS_POLL_TIMEOUT_MINUTES config value "' ||
                    DMT_UTIL_PKG.GET_CONFIG('ESS_POLL_TIMEOUT_MINUTES') ||
                    '" is not a number; using default 30.',
                    'WARN', C_PKG, 'POLL_ONE');
                l_timeout_min := 30;
        END;
        IF l_rec.POLL_COUNT >= l_timeout_min THEN
            -- A timeout is a trigger for the failure path, never a per-record
            -- verdict (section 2). We do NOT pre-stamp the GENERATED rows FAILED
            -- with a fabricated "[LOAD_ERROR] poll timeout" message: that asserts a
            -- failure we did not observe and would hide any row reconciliation
            -- cannot resolve. We log the timeout and route to reconcile with the
            -- rows left GENERATED. Reconciliation writes each per-record verdict
            -- (LOADED if the job actually finished after we stopped watching,
            -- FAILED on a REAL interface/base error, otherwise LEFT GENERATED /
            -- unaccounted). The object is settled by the accounting gate alone.
            DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                'ESS poll timeout for ' || l_rec.CEMLI_CODE || ' (job ' || l_ess_id ||
                ', ' || l_rec.POLL_COUNT || ' polls >= ' || l_timeout_min ||
                ' min). Routing to reconcile; rows left GENERATED so reconciliation '
                || 'writes each per-record verdict.',
                'WARN', C_PKG, 'POLL_ONE');

            get_dispatch(l_rec.CEMLI_CODE, l_exec_proc, l_exec_mode, l_recon_proc, l_recon_cemli);
            IF l_recon_proc IS NOT NULL THEN
                -- Reconciliation still runs — if the job actually completed
                -- after we stopped watching, it finds the records in Fusion
                -- and flips them LOADED.
                UPDATE DMT_WORK_QUEUE_TBL
                SET WORK_STATUS = 'RECONCILING'
                WHERE QUEUE_ID = p_queue_id;
            ELSE
                -- No queue-dispatched reconciler registered: settle by the
                -- accounting rule alone (never directly from the timer).
                apply_accounting_gate(p_queue_id, l_rec.RUN_ID, l_rec.CEMLI_CODE);
            END IF;
            COMMIT;
            RETURN;
        END IF;

        -- Resolve the per-CEMLI Fusion credentials used to SUBMIT this job. getESSJobStatus
        -- must be called as the submitting user — polling another user's ESS request returns
        -- HTTP 500. P2P jobs are submitted by overrides (SCM_IMPL/calvin.roth); without this
        -- the async poll used the default user and 500'd persistently (Runs 86/96/97).
        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(l_rec.CEMLI_CODE, l_ess_user, l_ess_pass);

        -- Single ESS status check.
        -- A5 (2026-07-08): a failure of the STATUS-CHECK call is never the
        -- job's status. Section 2 (POLL_ONE row): "Transient SOAP faults
        -- retry next tick; EXPIRED is not treated as terminal." A raised
        -- fault here leaves l_status NULL, which falls to the retry-next-
        -- tick branch below — only definitive terminal ESS states advance
        -- the work item. (Was: WHEN OTHERS THEN l_status := 'ERROR', which
        -- sent the item to premature reconcile on any transient fault.)
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
            WHEN OTHERS THEN
                l_status := NULL;
                DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                    'ESS status check failed for job ' || l_ess_id ||
                    ' — retrying next tick (' || SUBSTR(SQLERRM, 1, 300) || ')',
                    'WARN', C_PKG, 'POLL_ONE');
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
                        NEXT_POLL_AFTER = SYS_EXTRACT_UTC(SYSTIMESTAMP) + INTERVAL '60' SECOND
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

                -- Phase-2 staged load: if this CEMLI has a post-run job in
                -- the registry (Assets → PostMassAdditions), submit it and
                -- poll it before reconcile. Others → NULL → straight to
                -- RECONCILING.
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
                        NEXT_POLL_AFTER = SYS_EXTRACT_UTC(SYSTIMESTAMP) + INTERVAL '60' SECOND
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
            -- ('CANCELLED' here is a Fusion ESS JOB state — this list is the
            -- ESS vocabulary, not the run-status vocabulary.)
            -- A terminal job error is NOT, by itself, an object failure. FBDI import jobs
            -- report job-level ERROR on PARTIAL success — some records reach Fusion base
            -- tables, some land in the interface error table — which is still a SUCCESSFUL
            -- object. So route to RECONCILING and let BIP positively account for every
            -- record; RECONCILE_ONE then settles the item through the accounting gate
            -- (every record accounted: base = LOADED, interface-error = FAILED) or fails
            -- it (any record unaccounted, or the import never produced data). This is the
            -- only place that decides per-record outcome, so the job's coarse ERROR must
            -- not short-circuit it.
            -- ('EXPIRED' is excluded above — it is a per-tick poll artifact, not a status.)
            IF l_rec.WORK_STATUS = 'AWAITING_LOAD' THEN
                -- The load ESS job ended in a terminal error state. That is a real
                -- observed event about the JOB, but it is NOT a per-record verdict:
                -- an FBDI load can end ERROR/WARNING on partial success (some rows
                -- reach base, some land in the interface error table). We therefore
                -- do NOT pre-stamp the GENERATED rows FAILED with a generic
                -- "[LOAD_ERROR] ... not yet confirmed" message — that fabricates a
                -- failure we have not observed and would hide any row reconciliation
                -- cannot resolve. Instead we log the job error and route to
                -- reconcile with the rows left GENERATED. Reconciliation is the one
                -- place that writes a per-record verdict: LOADED when confirmed in a
                -- base table, FAILED when it has a REAL interface/base error, and
                -- LEFT GENERATED (unaccounted) otherwise — surfaced by the
                -- accounting gate (object not-DONE) and the funnel (UNRECONCILED).
                DMT_UTIL_PKG.LOG(l_rec.RUN_ID,
                    'Load ESS job ' || l_ess_id || ' ended ' || l_status ||
                    ' for ' || l_rec.CEMLI_CODE || '. Routing to reconcile; rows left '
                    || 'GENERATED so reconciliation writes each per-record verdict. '
                    || 'Check the ESS job log for load diagnostics.',
                    'WARN', C_PKG, 'EXECUTE_ONE');
                -- Capture the import job id (if any) first so the reconciler
                -- can read the import error table.
                IF l_rec.IMPORT_ESS_JOB_ID IS NULL THEN
                    BEGIN
                        l_import_id := DMT_LOADER_PKG.GET_IMPORT_ESS_ID(
                            l_rec.RUN_ID, l_rec.CEMLI_CODE, l_rec.LOAD_ESS_JOB_ID);
                    EXCEPTION WHEN OTHERS THEN l_import_id := NULL;
                    END;
                ELSE
                    l_import_id := l_rec.IMPORT_ESS_JOB_ID;
                END IF;
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
            -- Non-terminal (WAIT/RUNNING), EXPIRED-this-tick, or a transient
            -- status-check fault (l_status NULL) → poll again next tick.
            UPDATE DMT_WORK_QUEUE_TBL
            SET POLL_COUNT = l_rec.POLL_COUNT + 1,
                LAST_POLL_AT = SYSTIMESTAMP,
                NEXT_POLL_AFTER = SYS_EXTRACT_UTC(SYSTIMESTAMP) + INTERVAL '60' SECOND
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

    -- ============================================================
    -- fail_run_preflight -- halt a run whose preflight did not pass:
    -- FAIL every not-yet-terminal work item with a clear message and set
    -- PREFLIGHT_STATUS = 'FAILED'. RUN_STATUS is left to the heartbeat
    -- rollup (one-writer-per-status-altitude) -- with all items terminal
    -- FAILED, the rollup settles the run FAILED. Nothing is dispatched.
    -- ============================================================
    PROCEDURE fail_run_preflight (p_run_id IN NUMBER) IS
        C_HALT_MSG CONSTANT VARCHAR2(400) :=
            'Preflight failed before any load: the Fusion lookup refresh or a run '
            || 'credential did not pass. Run halted; nothing was submitted. See the '
            || 'activity log for this run for the specific failure.';
    BEGIN
        UPDATE DMT_WORK_QUEUE_TBL
        SET    WORK_STATUS   = 'FAILED',
               ERROR_MESSAGE = C_HALT_MSG,
               COMPLETED_AT  = SYSTIMESTAMP
        WHERE  RUN_ID = p_run_id
          AND  WORK_STATUS NOT IN ('DONE', 'FAILED', 'SKIPPED');

        UPDATE DMT_PIPELINE_RUN_TBL
        SET    PREFLIGHT_STATUS = 'FAILED'
        WHERE  RUN_ID = p_run_id;
        COMMIT;
    END fail_run_preflight;

    -- ============================================================
    -- PREFLIGHT_ONE -- the async preflight worker (child job). Runs the
    -- run's preflight OFF the heartbeat tick so its live Fusion calls
    -- (lookup refresh + credential probes) never stall dispatch/polling.
    -- Success -> PREFLIGHT_STATUS 'OK' (dispatch_ready then releases the
    -- run's items). Failure -> the run is halted via fail_run_preflight.
    -- Always resolves the run out of the 'PREFLIGHTING' claim, so a run
    -- can never get stuck mid-preflight.
    -- ============================================================
    PROCEDURE PREFLIGHT_ONE (p_run_id IN NUMBER) IS
        C_PROC CONSTANT VARCHAR2(30) := 'PREFLIGHT_ONE';
        l_step VARCHAR2(200);
        l_code NUMBER;
    BEGIN
        l_step := 'running preflight for run ' || p_run_id;
        DMT_UTIL_PKG.RUN_PREFLIGHT(p_run_id => p_run_id, x_error_code => l_code);

        IF l_code = DMT_UTIL_PKG.C_SUCCESS THEN
            UPDATE DMT_PIPELINE_RUN_TBL
            SET    PREFLIGHT_STATUS = 'OK'
            WHERE  RUN_ID = p_run_id;
            COMMIT;
        ELSE
            fail_run_preflight(p_run_id);
            DMT_UTIL_PKG.LOG(p_run_id    => p_run_id,
                             p_message   => C_PROC || ': preflight failed -- run halted, nothing loaded.',
                             p_log_type  => DMT_UTIL_PKG.C_LOG_ERROR,
                             p_package   => C_PKG,
                             p_procedure => C_PROC);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            fail_run_preflight(p_run_id);
            DMT_UTIL_PKG.LOG_ERROR(p_run_id    => p_run_id,
                                   p_message   => l_step,
                                   p_sqlerrm   => SQLERRM,
                                   p_package   => C_PKG,
                                   p_procedure => C_PROC);
    END PREFLIGHT_ONE;

END DMT_QUEUE_WORKER_PKG;
/
