-- PACKAGE BODY DMT_SCHEDULER_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_SCHEDULER_PKG" 
AS
    C_PKG CONSTANT VARCHAR2(30) := 'DMT_SCHEDULER_PKG';

    -- ============================================================
    -- Pipeline CEMLI sequences
    -- ============================================================
    FUNCTION GET_CEMLI_SEQUENCE (p_pipeline_code IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE UPPER(p_pipeline_code)
            WHEN 'P2P' THEN
                -- ItemCategories (and the never-wired ItemCategoryAssignments) are NOT separate
                -- tokens: their CSV is bundled into the single Items FBDI ZIP / ItemImportJobDef
                -- ESS call, and the 'Items' token validates/transforms/reconciles them inline
                -- (see DMT_LOADER_PKG.run_one_object_type 'Items' branch). One token => one card.
                'Items,'
                || 'Suppliers,SupplierAddresses,SupplierSites,SupplierSiteAssignments,SupplierContacts,'
                || 'PurchaseOrders,BlanketPOs,Contracts,APInvoices,1099Invoices,Requisitions'
            WHEN 'O2C' THEN
                'Customers,ARInvoices'
            WHEN 'OTC' THEN
                'Customers,ARInvoices'
            WHEN 'PROJECTS' THEN
                'Projects,BillingEvents,Expenditures,Grants,ProjectBudgets'
            WHEN 'HCM' THEN
                'Workers,Assignments,Salaries,SalaryBases,PayrollRels,TaxCards,W2Balances,'
                || 'BenParticipant,BenDependent,BenBeneficiary,Absences,TalentProfiles,PerfEvaluations,WorkSchedules'
            WHEN 'FINANCIALS' THEN
                -- PlanBudgets (EPBCS PlanningBudgets) is DORMANT — no ERP-options seed exists
                -- on this instance, so it is excluded from the queue. Re-add once EPBCS is seeded.
                'GLBalances,GLBudgets,Assets'
            WHEN 'CONFIGURATION' THEN
                'GLCalendar,ValueSets,ValueSetValues,Lookups'
            ELSE NULL
        END;
    END GET_CEMLI_SEQUENCE;

    -- ============================================================
    -- CEMLI dependency graph
    -- ============================================================
    FUNCTION GET_CEMLI_DEPENDENCIES (p_pipeline_code IN VARCHAR2, p_cemli_code IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_cemli_code
            -- P2P
            -- ItemCategories / ItemCategoryAssignments are bundled into the Items token (one FBDI
            -- ZIP); they are no longer emitted as standalone CEMLIs, so no dependency rows are needed.
            WHEN 'Items'                    THEN NULL
            WHEN 'Suppliers'                THEN NULL
            WHEN 'SupplierAddresses'        THEN 'Suppliers'
            WHEN 'SupplierSites'            THEN 'Suppliers,SupplierAddresses'
            WHEN 'SupplierSiteAssignments'  THEN 'SupplierSites'
            WHEN 'SupplierContacts'         THEN 'Suppliers'
            WHEN 'PurchaseOrders'           THEN 'Items,Suppliers'
            WHEN 'BlanketPOs'               THEN 'Items,Suppliers'
            WHEN 'Contracts'                THEN 'Suppliers'
            WHEN 'APInvoices'               THEN 'Suppliers'
            WHEN '1099Invoices'             THEN 'Suppliers'
            WHEN 'Requisitions'             THEN 'Items,Suppliers'
            WHEN 'MiscReceipts'             THEN NULL
            -- O2C
            WHEN 'Customers'                THEN NULL
            WHEN 'ARInvoices'               THEN 'Customers'
            -- Projects
            WHEN 'Projects'                 THEN NULL
            WHEN 'BillingEvents'            THEN 'Projects'
            WHEN 'Expenditures'             THEN 'Projects'
            WHEN 'Grants'                   THEN 'Projects'
            WHEN 'ProjectBudgets'           THEN 'Projects'
            -- Financials
            WHEN 'GLBalances'               THEN NULL
            WHEN 'GLBudgets'                THEN NULL
            WHEN 'PlanBudgets'              THEN NULL
            WHEN 'Assets'                   THEN NULL
            -- HCM
            WHEN 'Workers'                  THEN NULL
            WHEN 'Assignments'              THEN 'Workers'
            WHEN 'Salaries'                 THEN 'Workers,Assignments'
            WHEN 'SalaryBases'              THEN 'Salaries'
            WHEN 'PayrollRels'              THEN 'Workers'
            WHEN 'TaxCards'                 THEN 'Workers'
            WHEN 'W2Balances'               THEN NULL
            WHEN 'BenParticipant'           THEN 'Workers'
            WHEN 'BenDependent'             THEN 'Workers'
            WHEN 'BenBeneficiary'           THEN 'Workers'
            WHEN 'Absences'                 THEN 'Workers'
            WHEN 'TalentProfiles'           THEN 'Workers'
            WHEN 'PerfEvaluations'          THEN 'Workers'
            WHEN 'WorkSchedules'            THEN NULL
            -- Configuration
            WHEN 'GLCalendar'               THEN NULL
            WHEN 'ValueSets'                THEN NULL
            WHEN 'ValueSetValues'           THEN 'ValueSets'
            WHEN 'Lookups'                  THEN NULL
            ELSE NULL
        END;
    END GET_CEMLI_DEPENDENCIES;

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
            EXIT WHEN l_pos = 0;
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
                    EXIT WHEN l_seq_pos = 0;
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
            EXIT WHEN l_pos = 0;
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
            EXIT WHEN l_pos = 0;
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
    -- Populates APEX_COLLECTION 'PLAN_PREVIEW' with proposed queue
    -- rows. Returns a SYS_REFCURSOR over the collection.
    -- Collection columns:
    --   C001 = PIPELINE, C002 = CEMLI_CODE, C003 = DEPENDS_ON,
    --   C004 = INITIAL_STATUS, N001 = SORT_ORDER
    -- ============================================================
    FUNCTION PLAN_RUN (
        p_pipeline_codes   IN  VARCHAR2
    ) RETURN SYS_REFCURSOR IS
        C_COLLECTION CONSTANT VARCHAR2(30) := 'PLAN_PREVIEW';
        l_cur          SYS_REFCURSOR;
        l_remaining    VARCHAR2(4000);
        l_pipeline     VARCHAR2(30);
        l_pos          PLS_INTEGER;
        l_sort         PLS_INTEGER := 0;
        l_deps         VARCHAR2(4000);
        l_cemli        VARCHAR2(60);
    BEGIN
        IF APEX_COLLECTION.COLLECTION_EXISTS(C_COLLECTION) THEN
            APEX_COLLECTION.DELETE_COLLECTION(C_COLLECTION);
        END IF;
        APEX_COLLECTION.CREATE_COLLECTION(C_COLLECTION);

        IF p_pipeline_codes IS NULL THEN
            OPEN l_cur FOR
                SELECT N001 AS sort_order, C001 AS pipeline, C002 AS cemli_code,
                       C003 AS depends_on, C004 AS initial_status
                FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = C_COLLECTION
                ORDER BY N001;
            RETURN l_cur;
        END IF;

        l_remaining := REPLACE(p_pipeline_codes, ' ', '') || ',';
        LOOP
            l_pos := INSTR(l_remaining, ',');
            EXIT WHEN l_pos = 0;
            l_pipeline := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
            l_remaining := SUBSTR(l_remaining, l_pos + 1);
            IF l_pipeline IS NULL THEN CONTINUE; END IF;

            IF l_pipeline LIKE 'STANDALONE:%' THEN
                l_cemli := SUBSTR(l_pipeline, 12);
                l_sort := l_sort + 1;
                l_deps := GET_CEMLI_DEPENDENCIES('STANDALONE', l_cemli);
                APEX_COLLECTION.ADD_MEMBER(
                    p_collection_name => C_COLLECTION,
                    p_c001 => 'STANDALONE', p_c002 => l_cemli,
                    p_c003 => l_deps,
                    p_c004 => CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END,
                    p_n001 => l_sort
                );
                CONTINUE;
            END IF;

            DECLARE
                l_seq VARCHAR2(4000) := GET_CEMLI_SEQUENCE(l_pipeline);
                l_seq_remaining VARCHAR2(4000);
                l_seq_pos PLS_INTEGER;
            BEGIN
                IF l_seq IS NULL THEN
                    l_sort := l_sort + 1;
                    APEX_COLLECTION.ADD_MEMBER(
                        p_collection_name => C_COLLECTION,
                        p_c001 => UPPER(l_pipeline),
                        p_c002 => '** Unknown pipeline: ' || l_pipeline || ' **',
                        p_c003 => NULL, p_c004 => 'ERROR', p_n001 => l_sort
                    );
                    CONTINUE;
                END IF;

                l_seq_remaining := l_seq || ',';
                LOOP
                    l_seq_pos := INSTR(l_seq_remaining, ',');
                    EXIT WHEN l_seq_pos = 0;
                    l_cemli := TRIM(SUBSTR(l_seq_remaining, 1, l_seq_pos - 1));
                    l_seq_remaining := SUBSTR(l_seq_remaining, l_seq_pos + 1);
                    IF l_cemli IS NULL THEN CONTINUE; END IF;

                    l_sort := l_sort + 1;
                    l_deps := GET_CEMLI_DEPENDENCIES(l_pipeline, l_cemli);
                    APEX_COLLECTION.ADD_MEMBER(
                        p_collection_name => C_COLLECTION,
                        p_c001 => UPPER(l_pipeline),
                        p_c002 => l_cemli,
                        p_c003 => l_deps,
                        p_c004 => CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END,
                        p_n001 => l_sort
                    );
                END LOOP;
            END;
        END LOOP;

        OPEN l_cur FOR
            SELECT N001 AS sort_order, C001 AS pipeline, C002 AS cemli_code,
                   C003 AS depends_on, C004 AS initial_status
            FROM APEX_COLLECTIONS WHERE COLLECTION_NAME = C_COLLECTION
            ORDER BY N001;
        RETURN l_cur;
    END PLAN_RUN;

END DMT_SCHEDULER_PKG;
/
