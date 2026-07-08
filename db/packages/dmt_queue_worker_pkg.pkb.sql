-- PACKAGE BODY DMT_QUEUE_WORKER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_QUEUE_WORKER_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_QUEUE_WORKER_PKG';
    C_ESS_TIMEOUT CONSTANT PLS_INTEGER := 30;  -- max polls before auto-fail (mirrors DMT_QUEUE_PKG.C_ESS_TIMEOUT)

    -- ============================================================
    -- EXECUTE_ONE — called by one-shot child job DMT_WQ_{queue_id}
    -- Runs in its own DB session. Does the full validate -> transform
    -- -> generate -> SUBMIT_LOAD cycle for one queue row, then sets
    -- AWAITING_LOAD. For sync-only objects (MiscReceipts, grouped,
    -- HDL), runs the full RUN_* cycle and sets DONE.
    -- ============================================================
    PROCEDURE EXECUTE_ONE (p_queue_id IN NUMBER) IS
        l_rec       DMT_WORK_QUEUE_TBL%ROWTYPE;
        l_run_rec   DMT_PIPELINE_RUN_TBL%ROWTYPE;
        l_load_ess_id VARCHAR2(100);
    BEGIN
        SELECT * INTO l_rec FROM DMT_WORK_QUEUE_TBL WHERE QUEUE_ID = p_queue_id;
        SELECT * INTO l_run_rec FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = l_rec.RUN_ID;

        UPDATE DMT_WORK_QUEUE_TBL
        SET WORK_STATUS = 'LOADING'
        WHERE QUEUE_ID = p_queue_id;
        COMMIT;

        -- Set async mode: run_one_object_type returns after SUBMIT_LOAD.
        IF l_rec.CEMLI_CODE = 'MiscReceipts' THEN
            DMT_LOADER_PKG.g_async_mode := FALSE;
        ELSE
            DMT_LOADER_PKG.g_async_mode := TRUE;
        END IF;
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

        CASE l_rec.CEMLI_CODE
            WHEN 'Items'                    THEN DMT_LOADER_PKG.RUN_ITEMS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'ItemCategories'           THEN DMT_LOADER_PKG.RUN_ITEM_CATEGORIES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Suppliers'                THEN DMT_LOADER_PKG.RUN_SUPPLIERS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'SupplierAddresses'        THEN DMT_LOADER_PKG.RUN_SUPPLIER_ADDRESSES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'SupplierSites'            THEN DMT_LOADER_PKG.RUN_SUPPLIER_SITES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'SupplierSiteAssignments'  THEN DMT_LOADER_PKG.RUN_SUPPLIER_SITE_ASSIGNMENTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'SupplierContacts'         THEN DMT_LOADER_PKG.RUN_SUPPLIER_CONTACTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'PurchaseOrders'           THEN DMT_LOADER_PKG.RUN_PURCHASE_ORDERS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'BlanketPOs'               THEN DMT_LOADER_PKG.RUN_BLANKET_POS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Contracts'                THEN DMT_LOADER_PKG.RUN_CONTRACTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'APInvoices'               THEN DMT_LOADER_PKG.RUN_AP_INVOICES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN '1099Invoices'             THEN DMT_LOADER_PKG.RUN_1099_INVOICES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Requisitions'             THEN DMT_LOADER_PKG.RUN_REQUISITIONS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'MiscReceipts'             THEN DMT_LOADER_PKG.RUN_MISC_RECEIPTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Customers'                THEN DMT_LOADER_PKG.RUN_CUSTOMERS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'ARInvoices'               THEN DMT_LOADER_PKG.RUN_AR_INVOICES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Projects'                 THEN DMT_LOADER_PKG.RUN_PROJECTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'BillingEvents'            THEN DMT_LOADER_PKG.RUN_BILLING_EVENTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Expenditures'             THEN DMT_LOADER_PKG.RUN_EXPENDITURES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Grants'                   THEN DMT_LOADER_PKG.RUN_GRANTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'ProjectBudgets'           THEN DMT_LOADER_PKG.RUN_PROJECT_BUDGETS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Workers'                  THEN DMT_LOADER_PKG.RUN_WORKERS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Assignments'              THEN DMT_LOADER_PKG.RUN_ASSIGNMENTS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Salaries'                 THEN DMT_LOADER_PKG.RUN_SALARIES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'SalaryBases'              THEN DMT_LOADER_PKG.RUN_SALARY_BASES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'PayrollRels'              THEN DMT_LOADER_PKG.RUN_PAYROLL_RELS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'TaxCards'                 THEN DMT_LOADER_PKG.RUN_TAX_CARDS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'W2Balances'               THEN DMT_LOADER_PKG.RUN_W2_BALANCES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'BenParticipant'           THEN DMT_LOADER_PKG.RUN_BEN_PARTICIPANT(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'BenDependent'             THEN DMT_LOADER_PKG.RUN_BEN_DEPENDENT(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'BenBeneficiary'           THEN DMT_LOADER_PKG.RUN_BEN_BENEFICIARY(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Absences'                 THEN DMT_LOADER_PKG.RUN_ABSENCES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'TalentProfiles'           THEN DMT_LOADER_PKG.RUN_TALENT_PROFILES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'PerfEvaluations'          THEN DMT_LOADER_PKG.RUN_PERF_EVALUATIONS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'WorkSchedules'            THEN DMT_LOADER_PKG.RUN_WORK_SCHEDULES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'GLBalances'               THEN DMT_LOADER_PKG.RUN_GL_BALANCES(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'GLBudgets'                THEN DMT_LOADER_PKG.RUN_GL_BUDGETS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'PlanBudgets'              THEN DMT_LOADER_PKG.RUN_PLAN_BUDGETS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            WHEN 'Assets'                   THEN DMT_LOADER_PKG.RUN_ASSETS(l_rec.RUN_ID, l_run_rec.SCENARIO_NAME, l_run_rec.INCLUDE_UNTAGGED, l_run_rec.RUN_MODE, TRUE);
            ELSE RAISE_APPLICATION_ERROR(-20100, 'Unknown CEMLI code: ' || l_rec.CEMLI_CODE);
        END CASE;

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

        -- BIP reconciliation dispatch
        IF l_rec.CEMLI_CODE LIKE 'Supplier%' THEN
            DMT_POZ_SUP_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID, l_rec.CEMLI_CODE,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Customers' THEN
            DMT_CUST_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Projects' THEN
            DMT_PROJECT_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'BillingEvents' THEN
            DMT_BILLING_EVENT_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Expenditures' THEN
            DMT_EXPENDITURE_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Grants' THEN
            DMT_GRANTS_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Items' THEN
            DMT_EGP_ITEM_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
            DECLARE l_cat_gen NUMBER;
            BEGIN
                SELECT COUNT(*) INTO l_cat_gen FROM DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
                WHERE RUN_ID = l_rec.RUN_ID AND TFM_STATUS = 'GENERATED';
                IF l_cat_gen > 0 THEN
                    DMT_EGP_ITEM_CAT_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                        TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
                END IF;
            END;
        ELSIF l_rec.CEMLI_CODE = 'ItemCategories' THEN
            DMT_EGP_ITEM_CAT_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Requisitions' THEN
            DMT_REQ_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'PurchaseOrders' THEN
            DMT_PO_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'ARInvoices' THEN
            DMT_AR_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'BlanketPOs' THEN
            DMT_BLANKET_PO_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Contracts' THEN
            DMT_CONTRACT_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'APInvoices' THEN
            DMT_AP_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = '1099Invoices' THEN
            DMT_1099_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'GLBalances' THEN
            DMT_GL_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'GLBudgets' THEN
            DMT_GL_BUDGET_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'PlanBudgets' THEN
            DMT_PLAN_BUDGET_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'ProjectBudgets' THEN
            DMT_PRJ_BUDGET_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'Assets' THEN
            DMT_FA_ASSET_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSIF l_rec.CEMLI_CODE = 'MiscReceipts' THEN
            DMT_MISC_RECEIPT_RESULTS_PKG.RECONCILE_BATCH(l_rec.RUN_ID,
                TO_NUMBER(l_rec.LOAD_ESS_JOB_ID), TO_NUMBER(l_rec.IMPORT_ESS_JOB_ID));
        ELSE
            RAISE_APPLICATION_ERROR(-20101,
                'RECONCILE_ONE: Unknown CEMLI code: ' || l_rec.CEMLI_CODE);
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
