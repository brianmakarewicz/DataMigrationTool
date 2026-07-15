-- DMT_PIPELINE_SUMMARY_V
CREATE OR REPLACE EDITIONABLE VIEW "DMT_PIPELINE_SUMMARY_V" ("RUN_ID", "INTEGRATION_ID", "SCENARIO_ID", "PIPELINE_CODES", "SCENARIO_NAME", "PREFIX", "SUBMITTED_DATE", "COMPLETED_DATE", "RUN_STATUS", "PIPELINE", "OBJECT_TYPE", "SORT_ORDER", "OBJECT_STATUS", "TOTAL_ROWS", "LOADED_ROWS", "FAILED_ROWS", "GENERATED_ROWS", "IN_PROGRESS_ROWS", "UNRECONCILED_ROWS", "CARD_SUMMARY", "CARD_CSS_CLASS", "LOAD_ESS_JOB_ID", "IMPORT_ESS_JOB_ID", "POSTRUN_ESS_JOB_ID", "ZIP_FILENAME")  AS 
  WITH cemli_lookup AS (
    -- Static mapping: CEMLI_CODE → PIPELINE + display SORT_ORDER.
    -- Must stay in sync with DMT_V_CEMLI_STATUS UNION ALL.
    SELECT 'Suppliers'              AS CEMLI_CODE, 'P2P'           AS PIPELINE,  1 AS SORT_ORDER FROM DUAL UNION ALL
    SELECT 'SupplierAddresses',                    'P2P',           2            FROM DUAL UNION ALL
    SELECT 'SupplierSites',                        'P2P',           3            FROM DUAL UNION ALL
    SELECT 'SupplierSiteAssignments',              'P2P',           4            FROM DUAL UNION ALL
    SELECT 'SupplierContacts',                     'P2P',           5            FROM DUAL UNION ALL
    SELECT 'PurchaseOrders',                       'P2P',           6            FROM DUAL UNION ALL
    SELECT 'BlanketPOs',                           'P2P',           7            FROM DUAL UNION ALL
    SELECT 'Contracts',                            'P2P',           8            FROM DUAL UNION ALL
    SELECT 'ContractPOs',                          'P2P',           8            FROM DUAL UNION ALL
    SELECT 'APInvoices',                           'P2P',           9            FROM DUAL UNION ALL
    SELECT 'Requisitions',                         'Standalone',    1            FROM DUAL UNION ALL
    SELECT 'MiscReceipts',                         'Standalone',    2            FROM DUAL UNION ALL
    SELECT 'Customers',                            'O2C',           1            FROM DUAL UNION ALL
    SELECT 'ARInvoices',                           'O2C',           2            FROM DUAL UNION ALL
    SELECT 'Projects',                             'Projects',      1            FROM DUAL UNION ALL
    SELECT 'BillingEvents',                        'Projects',      2            FROM DUAL UNION ALL
    SELECT 'Expenditures',                         'Projects',      3            FROM DUAL UNION ALL
    SELECT 'Grants',                               'Projects',      4            FROM DUAL UNION ALL
    SELECT 'ProjectBudgets',                       'Projects',      5            FROM DUAL UNION ALL
    SELECT 'GLBalances',                           'Financials',    1            FROM DUAL UNION ALL
    SELECT 'GLBudgets',                     'Financials',    2            FROM DUAL UNION ALL
    SELECT 'PlanningBudgets',                      'Financials',    3            FROM DUAL UNION ALL
    SELECT 'Assets',                               'Financials',    4            FROM DUAL UNION ALL
    SELECT 'Workers',                              'HCM',           1            FROM DUAL UNION ALL
    SELECT 'Assignments',                          'HCM',           2            FROM DUAL UNION ALL
    SELECT 'Salaries',                             'HCM',           3            FROM DUAL UNION ALL
    SELECT 'SalaryBases',                          'HCM',           4            FROM DUAL UNION ALL
    SELECT 'PayrollRelationships',                 'HCM',           5            FROM DUAL UNION ALL
    SELECT 'TaxCards',                             'HCM',           6            FROM DUAL UNION ALL
    SELECT 'W2Balances',                           'HCM',           7            FROM DUAL UNION ALL
    SELECT 'BenParticipant',                       'HCM',           8            FROM DUAL UNION ALL
    SELECT 'BenDependent',                         'HCM',           9            FROM DUAL UNION ALL
    SELECT 'BenBeneficiary',                       'HCM',          10            FROM DUAL UNION ALL
    SELECT 'Absences',                             'HCM',          11            FROM DUAL UNION ALL
    SELECT 'TalentProfiles',                       'HCM',          12            FROM DUAL UNION ALL
    SELECT 'PerfEvaluations',                      'HCM',          13            FROM DUAL UNION ALL
    SELECT 'WorkSchedules',                        'HCM',          14            FROM DUAL UNION ALL
    -- ItemCategories are bundled into the Items FBDI ZIP and roll up into the Items card
    -- (see DMT_V_CEMLI_STATUS) — no separate lookup row.
    SELECT 'Items',                                'MasterData',    1            FROM DUAL UNION ALL
    SELECT 'Banks',                                'MasterData',    3            FROM DUAL UNION ALL
    SELECT 'BankBranches',                         'MasterData',    4            FROM DUAL UNION ALL
    SELECT 'BankAccounts',                         'MasterData',    5            FROM DUAL UNION ALL
    SELECT 'GLCalendar',                           'Configuration', 1            FROM DUAL UNION ALL
    SELECT 'ValueSets',                            'Configuration', 2            FROM DUAL UNION ALL
    SELECT 'ValueSetValues',                       'Configuration', 3            FROM DUAL UNION ALL
    SELECT 'LookupTypes',                          'Configuration', 4            FROM DUAL UNION ALL
    SELECT 'LookupValues',                         'Configuration', 5            FROM DUAL UNION ALL
    SELECT 'UOM',                                  'Configuration', 6            FROM DUAL UNION ALL
    SELECT 'PaymentTerms',                         'Configuration', 7            FROM DUAL UNION ALL
    SELECT 'PaymentTermLines',                     'Configuration', 8            FROM DUAL UNION ALL
    SELECT 'TaxRegimes',                           'Configuration', 9            FROM DUAL UNION ALL
    SELECT 'TaxRates',                             'Configuration',10            FROM DUAL
),
-- Parse CEMLI_SEQUENCE CSV into individual rows per run
run_cemlis AS (
    SELECT
        r.RUN_ID,
        TRIM(REGEXP_SUBSTR(r.CEMLI_SEQUENCE, '[^,]+', 1, lvl.n)) AS CEMLI_CODE
    FROM DMT_OWNER.DMT_PIPELINE_RUN_TBL r
    CROSS JOIN (
        SELECT LEVEL AS n FROM DUAL CONNECT BY LEVEL <= 50
    ) lvl
    WHERE TRIM(REGEXP_SUBSTR(r.CEMLI_SEQUENCE, '[^,]+', 1, lvl.n)) IS NOT NULL
    -- Deprecated tokens: ItemCategories/ItemCategoryAssignments are bundled into the Items
    -- token now. Historical runs still carry them in their stored CEMLI_SEQUENCE, so filter
    -- them here to avoid rendering empty phantom cards for past runs (rows roll up into Items).
    AND   TRIM(REGEXP_SUBSTR(r.CEMLI_SEQUENCE, '[^,]+', 1, lvl.n))
              NOT IN ('ItemCategories', 'ItemCategoryAssignments')
),
-- Driver: one row per (RUN_ID, CEMLI_CODE) with pipeline/sort from lookup
driver AS (
    SELECT
        rc.RUN_ID,
        rc.CEMLI_CODE,
        NVL(lk.PIPELINE, 'Unknown')   AS PIPELINE,
        NVL(lk.SORT_ORDER, 99)        AS SORT_ORDER
    FROM run_cemlis rc
    LEFT JOIN cemli_lookup lk ON lk.CEMLI_CODE = rc.CEMLI_CODE
    UNION ALL
    -- __PIPELINE__ overview row for every run
    SELECT
        r.RUN_ID,
        '__PIPELINE__'  AS CEMLI_CODE,
        CASE r.PIPELINE_CODES
            WHEN 'ProcureToPay' THEN 'P2P'
            WHEN 'P2P'          THEN 'P2P'
            WHEN 'O2C'          THEN 'O2C'
            WHEN 'OTC'          THEN 'O2C'
            WHEN 'HCM'          THEN 'HCM'
            WHEN 'FINANCIALS'   THEN 'Financials'
            WHEN 'PROJECTS'     THEN 'Projects'
            WHEN 'STANDALONE'   THEN 'Standalone'
            ELSE INITCAP(r.PIPELINE_CODES)
        END             AS PIPELINE,
        -1              AS SORT_ORDER
    FROM DMT_OWNER.DMT_PIPELINE_RUN_TBL r
),
-- Pivot TFM status counts (unchanged from original)
pivoted AS (
    SELECT
        cs.CEMLI_CODE,
        cs.RUN_ID,
        SUM(cs.ROW_COUNT)                                                    AS TOTAL_ROWS,
        SUM(CASE WHEN cs.TFM_STATUS = 'LOADED'    THEN cs.ROW_COUNT ELSE 0 END) AS LOADED_ROWS,
        SUM(CASE WHEN cs.TFM_STATUS = 'FAILED'    THEN cs.ROW_COUNT ELSE 0 END) AS FAILED_ROWS,
        SUM(CASE WHEN cs.TFM_STATUS = 'GENERATED' THEN cs.ROW_COUNT ELSE 0 END) AS GENERATED_ROWS,
        SUM(CASE WHEN cs.TFM_STATUS NOT IN ('LOADED','FAILED','GENERATED')
                                              THEN cs.ROW_COUNT ELSE 0 END) AS IN_PROGRESS_ROWS,
        SUM(NVL(cs.UNRECONCILED_COUNT, 0))                                  AS UNRECONCILED_ROWS
    FROM   DMT_OWNER.DMT_V_CEMLI_STATUS cs
    WHERE  cs.CEMLI_CODE <> '__PIPELINE__'
    GROUP BY cs.CEMLI_CODE, cs.RUN_ID
)
SELECT
    d.RUN_ID,
    d.RUN_ID                          AS INTEGRATION_ID,
    d.RUN_ID                          AS SCENARIO_ID,
    m.PIPELINE_CODES,
    m.SCENARIO_NAME,
    m.PREFIX,
    m.SUBMITTED_DATE,
    m.COMPLETED_DATE,
    m.RUN_STATUS,
    d.PIPELINE,
    d.CEMLI_CODE                      AS OBJECT_TYPE,
    d.SORT_ORDER,
    -- Computed object status
    CASE
        WHEN d.CEMLI_CODE = '__PIPELINE__' THEN m.RUN_STATUS
        WHEN NVL(p.TOTAL_ROWS, 0) = 0     THEN 'SKIPPED'
        WHEN p.IN_PROGRESS_ROWS > 0 OR p.GENERATED_ROWS > 0
            THEN 'IN_PROGRESS'
        WHEN p.UNRECONCILED_ROWS > 0
            THEN 'UNRECONCILED'
        WHEN (p.LOADED_ROWS + p.FAILED_ROWS) = p.TOTAL_ROWS AND p.FAILED_ROWS > 0
            THEN 'COMPLETED_ERRORS'
        WHEN (p.LOADED_ROWS + p.FAILED_ROWS) = p.TOTAL_ROWS
            THEN 'COMPLETED'
        ELSE 'IN_PROGRESS'
    END                               AS OBJECT_STATUS,
    NVL(p.TOTAL_ROWS, 0)             AS TOTAL_ROWS,
    NVL(p.LOADED_ROWS, 0)            AS LOADED_ROWS,
    NVL(p.FAILED_ROWS, 0)            AS FAILED_ROWS,
    NVL(p.GENERATED_ROWS, 0)         AS GENERATED_ROWS,
    NVL(p.IN_PROGRESS_ROWS, 0)       AS IN_PROGRESS_ROWS,
    NVL(p.UNRECONCILED_ROWS, 0)      AS UNRECONCILED_ROWS,
    -- Card summary text
    CASE
        WHEN d.CEMLI_CODE = '__PIPELINE__' THEN
            CASE m.RUN_STATUS
                WHEN 'QUEUED'              THEN 'Queued - waiting to start'
                WHEN 'NO_ROWS_PROCESSED'   THEN 'No rows to process'
                WHEN 'FAILED'              THEN 'Failed at ' || NVL(m.FAILED_CEMLI, m.CURRENT_CEMLI)
                                                || ': ' || SUBSTR(m.ERROR_MESSAGE, 1, 80)
                WHEN 'IN_PROGRESS'         THEN 'Running ' || NVL(m.CURRENT_CEMLI, '...')
                                                || ' (' || NVL(m.CURRENT_STEP, 'starting') || ')'
                                                || CASE WHEN m.COMPLETED_CEMLIS IS NOT NULL
                                                    THEN ' | Done: ' || m.COMPLETED_CEMLIS
                                                    ELSE '' END
                WHEN 'COMPLETED'           THEN 'Complete'
                WHEN 'COMPLETED_ERRORS'    THEN 'Completed with errors'
                ELSE m.RUN_STATUS
            END
        WHEN NVL(p.TOTAL_ROWS, 0) = 0 THEN 'No rows'
        WHEN p.IN_PROGRESS_ROWS > 0 OR p.GENERATED_ROWS > 0
            THEN p.LOADED_ROWS || ' loaded, ' || p.GENERATED_ROWS || ' in progress'
        WHEN p.UNRECONCILED_ROWS > 0
            THEN p.LOADED_ROWS || ' loaded, ' || p.UNRECONCILED_ROWS || ' unreconciled'
        WHEN p.LOADED_ROWS > 0 AND p.FAILED_ROWS > 0
            THEN p.LOADED_ROWS || ' loaded, ' || p.FAILED_ROWS || ' errors'
        WHEN p.LOADED_ROWS > 0 AND p.FAILED_ROWS = 0
            THEN p.LOADED_ROWS || ' loaded'
        WHEN p.FAILED_ROWS > 0
            THEN p.FAILED_ROWS || ' failed'
        ELSE p.TOTAL_ROWS || ' rows'
    END                               AS CARD_SUMMARY,
    -- APEX Universal Theme CSS class
    CASE
        WHEN d.CEMLI_CODE = '__PIPELINE__' THEN
            CASE m.RUN_STATUS
                WHEN 'QUEUED'            THEN 'u-color-15'  -- grey
                WHEN 'FAILED'            THEN 'u-color-31'  -- red
                WHEN 'IN_PROGRESS'       THEN 'u-color-4'   -- yellow
                WHEN 'NO_ROWS_PROCESSED' THEN 'u-color-15'  -- grey
                WHEN 'COMPLETED'         THEN 'u-color-9'   -- green
                WHEN 'COMPLETED_ERRORS'  THEN 'u-color-16'  -- orange
                ELSE 'u-color-15'
            END
        WHEN NVL(p.TOTAL_ROWS, 0) = 0 THEN 'u-color-15'  -- grey (skipped)
        WHEN p.IN_PROGRESS_ROWS > 0 OR p.GENERATED_ROWS > 0
            THEN 'u-color-4'   -- yellow
        WHEN p.UNRECONCILED_ROWS > 0
            THEN 'u-color-31'  -- red
        WHEN (p.LOADED_ROWS + p.FAILED_ROWS) = p.TOTAL_ROWS AND p.FAILED_ROWS > 0
            THEN 'u-color-16'  -- orange
        WHEN (p.LOADED_ROWS + p.FAILED_ROWS) = p.TOTAL_ROWS
            THEN 'u-color-9'   -- green
        ELSE 'u-color-15'      -- grey
    END                               AS CARD_CSS_CLASS,
    -- Grouped/synchronous CEMLIs (GL, GL Budgets, MiscReceipts, HDL) reconcile inline and
    -- never write ESS ids back to the queue row, so fall back to DMT_ESS_JOB_TBL where the
    -- ids are always captured. Load = the depth-0 InterfaceLoaderController; Import = the
    -- depth-0 import launcher (JournalImportLauncher, ImportProjectJobDef, etc.).
    COALESCE(q.LOAD_ESS_JOB_ID,
        TO_CHAR((SELECT MAX(ej.REQUEST_ID) FROM DMT_OWNER.DMT_ESS_JOB_TBL ej
                 WHERE ej.RUN_ID = d.RUN_ID AND ej.CEMLI_CODE = d.CEMLI_CODE
                   AND ej.DEPTH_LEVEL = 0
                   AND ej.JOB_SHORT_NAME = 'InterfaceLoaderController')))  AS LOAD_ESS_JOB_ID,
    COALESCE(q.IMPORT_ESS_JOB_ID,
        TO_CHAR((SELECT MAX(ej.REQUEST_ID) FROM DMT_OWNER.DMT_ESS_JOB_TBL ej
                 WHERE ej.RUN_ID = d.RUN_ID AND ej.CEMLI_CODE = d.CEMLI_CODE
                   AND ej.DEPTH_LEVEL = 0
                   AND ej.JOB_SHORT_NAME <> 'InterfaceLoaderController')))  AS IMPORT_ESS_JOB_ID,
    q.POSTRUN_ESS_JOB_ID,
    z.FILENAME                        AS ZIP_FILENAME
FROM
    driver d
JOIN DMT_OWNER.DMT_PIPELINE_RUN_TBL m
    ON  m.RUN_ID = d.RUN_ID
LEFT JOIN pivoted p
    ON  p.RUN_ID     = d.RUN_ID
    AND p.CEMLI_CODE = d.CEMLI_CODE
LEFT JOIN DMT_OWNER.DMT_FBDI_ZIP_TBL z
    ON  z.RUN_ID      = d.RUN_ID
    AND z.OBJECT_TYPE  = d.CEMLI_CODE
LEFT JOIN DMT_OWNER.DMT_WORK_QUEUE_TBL q
    ON  q.RUN_ID      = d.RUN_ID
    AND q.CEMLI_CODE   = d.CEMLI_CODE
ORDER BY
    d.RUN_ID DESC,
    CASE d.PIPELINE
        WHEN 'Configuration' THEN 0
        WHEN 'MasterData'    THEN 1
        WHEN 'P2P'           THEN 2
        WHEN 'O2C'           THEN 3
        WHEN 'Financials'    THEN 4
        WHEN 'Projects'      THEN 5
        WHEN 'Standalone'    THEN 6
        WHEN 'HCM'           THEN 7
        ELSE 9
    END,
    d.SORT_ORDER;
