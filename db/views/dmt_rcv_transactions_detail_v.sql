-- DMT_RCV_TRANSACTIONS_DETAIL_V
-- Backlog #25: repointed off the always-empty orphan DMT_RCV_TRANSACTIONS_*
-- tables onto the live Inventory-Transactions lot/serial child pipeline
-- (DMT_INV_TRX_LOTS_* and DMT_INV_TRX_SERIALS_*) that the MiscReceipts
-- generator actually writes. The view name is retained so the existing
-- app-500 page-4 "Receipt Transactions" interactive report (SELECT * ...
-- WHERE SCENARIO_ID) keeps working. One row per lot or serial child staging
-- row, latest transform attempt wins, tagged by RECORD_TYPE.
CREATE OR REPLACE EDITIONABLE VIEW "DMT_RCV_TRANSACTIONS_DETAIL_V" (
    "RUN_STATUS", "ERROR_TEXT", "RECONCILIATION_STATUS", "RECORD_TYPE",
    "LOT_OR_SERIAL", "SECONDARY_VALUE", "TRANSACTION_QUANTITY",
    "PRIMARY_QUANTITY", "STATUS_CODE", "SOURCE_CODE", "RECON_KEY",
    "SOURCE_ID", "STG_SEQUENCE_ID", "RUN_ID", "PREFIX",
    "SCENARIO_ID", "LAST_UPDATED_DATE"
) AS
  SELECT
    NVL(tfm.TFM_STATUS, stg.STG_STATUS)                      AS RUN_STATUS,
    tfm.ERROR_TEXT                                           AS ERROR_TEXT,
    CASE
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'LOADED' THEN 'CONFIRMED'
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'UNACCOUNTED' THEN 'UNACCOUNTED'
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'FAILED' AND tfm.ERROR_TEXT IS NOT NULL THEN 'CONFIRMED'
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'FAILED' AND tfm.ERROR_TEXT IS NULL THEN 'UNRECONCILED'
        ELSE 'IN_PROGRESS'
    END                                                      AS RECONCILIATION_STATUS,
    'Lot'                                                    AS RECORD_TYPE,
    stg.LOT_NUMBER                                           AS LOT_OR_SERIAL,
    CAST(NULL AS VARCHAR2(80))                               AS SECONDARY_VALUE,
    stg.TRANSACTION_QUANTITY,
    stg.PRIMARY_QUANTITY,
    stg.STATUS_CODE,
    stg.SOURCE_CODE,
    tfm.RECON_KEY,
    stg.SOURCE_ID,
    stg.STG_SEQUENCE_ID,
    tfm.RUN_ID,
    cm.PREFIX,
    stg.SCENARIO_ID,
    NVL(tfm.LAST_UPDATED_DATE, stg.LAST_UPDATED_DATE)        AS LAST_UPDATED_DATE
FROM DMT_INV_TRX_LOTS_STG_TBL stg
LEFT JOIN (
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY t.STG_SEQUENCE_ID
                              ORDER BY t.TFM_SEQUENCE_ID DESC) AS rn
    FROM   DMT_INV_TRX_LOTS_TFM_TBL t
) tfm ON tfm.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND tfm.rn = 1
LEFT JOIN DMT_PIPELINE_RUN_TBL cm
    ON cm.RUN_ID = tfm.RUN_ID
UNION ALL
  SELECT
    NVL(tfm.TFM_STATUS, stg.STG_STATUS),
    tfm.ERROR_TEXT,
    CASE
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'LOADED' THEN 'CONFIRMED'
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'UNACCOUNTED' THEN 'UNACCOUNTED'
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'FAILED' AND tfm.ERROR_TEXT IS NOT NULL THEN 'CONFIRMED'
        WHEN NVL(tfm.TFM_STATUS, stg.STG_STATUS) = 'FAILED' AND tfm.ERROR_TEXT IS NULL THEN 'UNRECONCILED'
        ELSE 'IN_PROGRESS'
    END,
    'Serial',
    stg.FM_SERIAL_NUMBER,
    stg.TO_SERIAL_NUMBER,
    CAST(NULL AS NUMBER),
    CAST(NULL AS NUMBER),
    stg.STATUS_CODE,
    CAST(NULL AS VARCHAR2(30)),
    tfm.RECON_KEY,
    stg.SOURCE_ID,
    stg.STG_SEQUENCE_ID,
    tfm.RUN_ID,
    cm.PREFIX,
    stg.SCENARIO_ID,
    NVL(tfm.LAST_UPDATED_DATE, stg.LAST_UPDATED_DATE)
FROM DMT_INV_TRX_SERIALS_STG_TBL stg
LEFT JOIN (
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY t.STG_SEQUENCE_ID
                              ORDER BY t.TFM_SEQUENCE_ID DESC) AS rn
    FROM   DMT_INV_TRX_SERIALS_TFM_TBL t
) tfm ON tfm.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND tfm.rn = 1
LEFT JOIN DMT_PIPELINE_RUN_TBL cm
    ON cm.RUN_ID = tfm.RUN_ID;
