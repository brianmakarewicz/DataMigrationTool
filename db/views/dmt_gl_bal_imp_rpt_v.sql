-- DMT_GL_BAL_IMP_RPT_V
CREATE OR REPLACE FORCE EDITIONABLE VIEW "DMT_GL_BAL_IMP_RPT_V" ("INTEGRATION_ID", "ORCHESTRATION_CODE", "RUN_STATUS", "START_DATE", "END_DATE", "PREFIX", "STG_SEQUENCE_ID", "TFM_SEQUENCE_ID", "LEDGER_NAME", "PERIOD_NAME", "ACTUAL_FLAG", "CURRENCY_CODE", "ENTERED_DR", "ENTERED_CR", "SEGMENT1", "SEGMENT2", "SEGMENT3", "STG_STATUS", "TFM_STATUS", "EFFECTIVE_STATUS", "RECONCILIATION_STATUS", "STG_ERRORS", "TFM_ERRORS", "ALL_ERRORS", "RESULTS_UPDATED_DATE", "STAGE_DATE", "SOURCE_RECORD_ID")  AS 
  SELECT
    t.INTEGRATION_ID,
    m.ORCHESTRATION_CODE,
    m.STATUS                                        AS RUN_STATUS,
    m.START_DATE,
    m.END_DATE,
    m.PREFIX,
    -- Identification (from STG -- always present)
    s.STG_SEQUENCE_ID,
    t.TFM_SEQUENCE_ID,
    s.LEDGER_NAME,
    s.PERIOD_NAME,
    s.ACTUAL_FLAG,
    s.CURRENCY_CODE,
    s.ENTERED_DR,
    s.ENTERED_CR,
    s.SEGMENT1,
    s.SEGMENT2,
    s.SEGMENT3,
    -- Raw status from each layer
    s.STATUS                                        AS STG_STATUS,
    t.TFM_STATUS                                    AS TFM_STATUS,
    -- Effective status: worst wins
    CASE
        WHEN 'FAILED' IN (s.STATUS, NVL(t.TFM_STATUS, 'X'))  THEN 'FAILED'
        WHEN t.TFM_STATUS = 'GENERATED'                        THEN 'GENERATED'
        WHEN t.TFM_STATUS IS NOT NULL                          THEN t.TFM_STATUS
        ELSE s.STATUS
    END                                             AS EFFECTIVE_STATUS,
    -- Reconciliation status (badge color)
    CASE
        WHEN NVL(t.TFM_STATUS, s.STATUS) = 'LOADED' THEN 'CONFIRMED'
        WHEN NVL(t.TFM_STATUS, s.STATUS) = 'FAILED' AND COALESCE(t.ERROR_TEXT, s.ERROR_TEXT) IS NOT NULL THEN 'CONFIRMED'
        WHEN NVL(t.TFM_STATUS, s.STATUS) = 'FAILED' AND COALESCE(t.ERROR_TEXT, s.ERROR_TEXT) IS NULL THEN 'UNRECONCILED'
        ELSE 'IN_PROGRESS'
    END                                             AS RECONCILIATION_STATUS,
    -- Error text from each layer
    DBMS_LOB.SUBSTR(s.ERROR_TEXT, 4000, 1)         AS STG_ERRORS,
    DBMS_LOB.SUBSTR(t.ERROR_TEXT, 4000, 1)         AS TFM_ERRORS,
    -- Combined errors
    CASE
        WHEN s.ERROR_TEXT IS NOT NULL AND t.ERROR_TEXT IS NOT NULL
        THEN DBMS_LOB.SUBSTR(s.ERROR_TEXT, 2000, 1) || ' | ' ||
             DBMS_LOB.SUBSTR(t.ERROR_TEXT, 2000, 1)
        ELSE DBMS_LOB.SUBSTR(COALESCE(s.ERROR_TEXT, t.ERROR_TEXT), 4000, 1)
    END                                             AS ALL_ERRORS,
    -- Fusion outcome (NULL until reconciliation completes)
    t.RESULTS_UPDATED_DATE,
    s.STAGE_DATE,
    s.SOURCE_ID                                     AS SOURCE_RECORD_ID
FROM
    DMT_OWNER.DMT_GL_INTERFACE_STG_TBL           s
    LEFT JOIN DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL t
        ON  t.STG_SEQUENCE_ID  = s.STG_SEQUENCE_ID
    LEFT JOIN DMT_OWNER.DMT_CONVERSION_MASTER_TBL m
        ON  m.INTEGRATION_ID   = t.INTEGRATION_ID
ORDER BY
    t.INTEGRATION_ID DESC NULLS LAST,
    s.LEDGER_NAME,
    s.PERIOD_NAME;
