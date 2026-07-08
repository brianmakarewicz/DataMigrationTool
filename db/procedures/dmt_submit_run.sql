-- PROCEDURE DMT_SUBMIT_RUN

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_SUBMIT_RUN" (
    p_pipeline_codes IN VARCHAR2,
    p_scenario     IN  VARCHAR2 DEFAULT NULL,
    p_run_mode     IN  VARCHAR2 DEFAULT 'NEW',
    p_submitted_by IN  VARCHAR2 DEFAULT NULL,
    x_run_id       OUT NUMBER
) AS
    l_prefix    VARCHAR2(20);
    l_remaining VARCHAR2(4000);
    l_pipeline  VARCHAR2(60);
    l_cemli     VARCHAR2(60);
    l_pos       PLS_INTEGER;
    l_sort      PLS_INTEGER := 0;
    l_deps      VARCHAR2(4000);
    l_seq       VARCHAR2(4000);
    l_all_cemlis VARCHAR2(4000);

    FUNCTION get_seq(p_code VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE UPPER(p_code)
            WHEN 'P2P' THEN 'Items,ItemCategories,ItemCategoryAssignments,Suppliers,SupplierAddresses,SupplierSites,SupplierSiteAssignments,SupplierContacts,PurchaseOrders,BlanketPOs,Contracts,APInvoices,1099Invoices,Requisitions'
            WHEN 'O2C' THEN 'Customers,ARInvoices'
            WHEN 'FINANCIALS' THEN 'GLBalances,GLBudgets,PlanBudgets,Assets'
            WHEN 'PROJECTS' THEN 'Projects,BillingEvents,Expenditures,Grants,ProjectBudgets'
            WHEN 'HCM' THEN 'Workers,Assignments,Salaries,SalaryBases,PayrollRels,TaxCards,W2Balances,BenParticipant,BenDependent,BenBeneficiary,Absences,TalentProfiles,PerfEvaluations,WorkSchedules'
            ELSE NULL
        END;
    END;

    FUNCTION get_deps(p_cemli VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_cemli
            WHEN 'ItemCategoryAssignments' THEN 'Items,ItemCategories'
            WHEN 'SupplierAddresses' THEN 'Suppliers'
            WHEN 'SupplierSites' THEN 'Suppliers,SupplierAddresses'
            WHEN 'SupplierSiteAssignments' THEN 'SupplierSites'
            WHEN 'SupplierContacts' THEN 'Suppliers'
            WHEN 'PurchaseOrders' THEN 'Items,Suppliers'
            WHEN 'BlanketPOs' THEN 'Items,Suppliers'
            WHEN 'Contracts' THEN 'Suppliers'
            WHEN 'APInvoices' THEN 'Suppliers'
            WHEN '1099Invoices' THEN 'Suppliers'
            WHEN 'Requisitions' THEN 'Items,Suppliers'
            WHEN 'ARInvoices' THEN 'Customers'
            WHEN 'BillingEvents' THEN 'Projects'
            WHEN 'Expenditures' THEN 'Projects'
            WHEN 'Grants' THEN 'Projects'
            WHEN 'ProjectBudgets' THEN 'Projects'
            WHEN 'Assignments' THEN 'Workers'
            WHEN 'Salaries' THEN 'Workers,Assignments'
            WHEN 'SalaryBases' THEN 'Salaries'
            WHEN 'PayrollRels' THEN 'Workers'
            WHEN 'TaxCards' THEN 'Workers'
            WHEN 'BenParticipant' THEN 'Workers'
            WHEN 'BenDependent' THEN 'Workers'
            WHEN 'BenBeneficiary' THEN 'Workers'
            WHEN 'Absences' THEN 'Workers'
            WHEN 'TalentProfiles' THEN 'Workers'
            WHEN 'PerfEvaluations' THEN 'Workers'
            ELSE NULL
        END;
    END;

BEGIN
    SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

    -- Expand all pipelines into CEMLI list
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
            l_seq := get_seq(l_pipeline);
        END IF;
        IF l_seq IS NOT NULL THEN
            l_all_cemlis := CASE WHEN l_all_cemlis IS NOT NULL THEN l_all_cemlis || ',' END || l_seq;
        END IF;
    END LOOP;

    -- Create run
    INSERT INTO DMT_PIPELINE_RUN_TBL (
        PIPELINE_CODES, RUN_TYPE, SUBMITTED_BY,
        CEMLI_SEQUENCE, SCENARIO_NAME, RUN_MODE,
        PREFIX, ON_FAILURE_POLICY
    ) VALUES (
        p_pipeline_codes, 'PIPELINE', p_submitted_by,
        l_all_cemlis, p_scenario, p_run_mode,
        l_prefix, 'HALT'
    ) RETURNING RUN_ID INTO x_run_id;

    -- Create queue rows
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
            l_deps := get_deps(l_cemli);
            INSERT INTO DMT_WORK_QUEUE_TBL (RUN_ID, PIPELINE, CEMLI_CODE, SORT_ORDER, DEPENDS_ON, WORK_STATUS)
            VALUES (x_run_id, 'STANDALONE', l_cemli, l_sort, l_deps, CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END);
        ELSE
            DECLARE
                l_seq2 VARCHAR2(4000) := get_seq(l_pipeline) || ',';
                l_pos2 PLS_INTEGER;
            BEGIN
                LOOP
                    l_pos2 := INSTR(l_seq2, ',');
                    EXIT WHEN l_pos2 = 0;
                    l_cemli := TRIM(SUBSTR(l_seq2, 1, l_pos2 - 1));
                    l_seq2 := SUBSTR(l_seq2, l_pos2 + 1);
                    IF l_cemli IS NULL THEN CONTINUE; END IF;
                    l_sort := l_sort + 1;
                    l_deps := get_deps(l_cemli);
                    INSERT INTO DMT_WORK_QUEUE_TBL (RUN_ID, PIPELINE, CEMLI_CODE, SORT_ORDER, DEPENDS_ON, WORK_STATUS)
                    VALUES (x_run_id, UPPER(l_pipeline), l_cemli, l_sort, l_deps, CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END);
                END LOOP;
            END;
        END IF;
    END LOOP;

    COMMIT;
END;
/
