-- DMT_V_CATALOG_HEALTH
CREATE OR REPLACE EDITIONABLE VIEW "DMT_V_CATALOG_HEALTH" ("CEMLI_CODE", "TFM_TABLE", "DISPLAY_NAME", "STATUS_COLUMN", "ISSUE")  AS 
  SELECT c.cemli_code,
       c.tfm_table,
       c.display_name,
       c.status_column,
       CASE
           WHEN ut.table_name  IS NULL THEN 'MISSING_TABLE'
           WHEN utc.column_name IS NULL THEN 'MISSING_STATUS_COLUMN'
       END AS issue
FROM   DMT_OWNER.DMT_V_CEMLI_TFM_TABLES c
LEFT JOIN USER_TABLES ut
       ON ut.table_name = c.tfm_table
LEFT JOIN USER_TAB_COLUMNS utc
       ON utc.table_name  = c.tfm_table
      AND utc.column_name = c.status_column
WHERE  ut.table_name IS NULL
   OR  utc.column_name IS NULL;
