-- DMT_RCV_HEADERS_DETAIL_V
-- Backlog #25: repointed off the always-empty orphan DMT_RCV_HEADERS_* tables
-- onto the live Inventory-Transactions pipeline the MiscReceipts generator
-- actually writes (DMT_INV_TRX_*). The view name is retained so the existing
-- app-500 page-4 "Receipt Headers" interactive report (SELECT * ... WHERE
-- SCENARIO_ID) keeps working; its columns are now INV-transaction-native
-- (the old RCV receipt-header columns had no INV_TRX equivalent). One row per
-- transaction staging row, latest transform attempt wins.
CREATE OR REPLACE EDITIONABLE VIEW "DMT_RCV_HEADERS_DETAIL_V" (
    "RUN_STATUS", "ERROR_TEXT", "RECONCILIATION_STATUS",
    "ITEM_NUMBER", "ORGANIZATION_NAME", "SUBINVENTORY_CODE", "LOCATOR_NAME",
    "TRANSACTION_QUANTITY", "TRANSACTION_UOM", "TRANSACTION_UNIT_OF_MEASURE",
    "PRIMARY_QUANTITY", "TRANSACTION_DATE", "TRANSACTION_TYPE_NAME",
    "TRANSACTION_SOURCE_TYPE_NAME", "TRANSACTION_REFERENCE",
    "REVISION", "SOURCE_CODE", "FUSION_ID", "RECON_KEY",
    "SOURCE_ID", "STG_SEQUENCE_ID", "RUN_ID", "PREFIX",
    "SCENARIO_ID", "STAGE_DATE", "LAST_UPDATED_DATE"
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
    stg.ITEM_NUMBER,
    stg.ORGANIZATION_NAME,
    stg.SUBINVENTORY_CODE,
    stg.LOCATOR_NAME,
    stg.TRANSACTION_QUANTITY,
    stg.TRANSACTION_UOM,
    stg.TRANSACTION_UNIT_OF_MEASURE,
    stg.PRIMARY_QUANTITY,
    stg.TRANSACTION_DATE,
    stg.TRANSACTION_TYPE_NAME,
    stg.TRANSACTION_SOURCE_TYPE_NAME,
    stg.TRANSACTION_REFERENCE,
    stg.REVISION,
    stg.SOURCE_CODE,
    tfm.FUSION_ID,
    tfm.RECON_KEY,
    stg.SOURCE_ID,
    stg.STG_SEQUENCE_ID,
    tfm.RUN_ID,
    cm.PREFIX,
    stg.SCENARIO_ID,
    stg.STAGE_DATE,
    NVL(tfm.LAST_UPDATED_DATE, stg.LAST_UPDATED_DATE)        AS LAST_UPDATED_DATE
FROM DMT_INV_TRX_STG_TBL stg
LEFT JOIN (
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY t.STG_SEQUENCE_ID
                              ORDER BY t.TFM_SEQUENCE_ID DESC) AS rn
    FROM   DMT_INV_TRX_TFM_TBL t
) tfm ON tfm.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND tfm.rn = 1
LEFT JOIN DMT_PIPELINE_RUN_TBL cm
    ON cm.RUN_ID = tfm.RUN_ID;
