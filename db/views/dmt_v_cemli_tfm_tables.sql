-- DMT_V_CEMLI_TFM_TABLES
-- The object display catalog view (DMT_DESIGN.html sections 7 and 11): a plain
-- SELECT over DMT_CEMLI_CATALOG_TBL, so the console (page 52 breakdown, page 57
-- drill), DMT_V_CATALOG_HEALTH and DMT_REST_LOOKUP_PKG read the one registry
-- instead of a hardcoded copy (#717 -- the old UNION ALL had drifted).
-- Excluded: the test-only Mock rows (test/unit/setup_mock_objects.sql) and
-- record types with no TFM table yet (ARReceipts), which have nothing to count.
CREATE OR REPLACE EDITIONABLE VIEW "DMT_V_CEMLI_TFM_TABLES" ("CEMLI_CODE", "TFM_TABLE", "DISPLAY_NAME", "SORT_ORDER", "STATUS_COLUMN", "ROW_FILTER")  AS 
  SELECT c.CEMLI_CODE,
       c.TFM_TABLE,
       c.DISPLAY_NAME,
       c.SORT_ORDER,
       c.STATUS_COLUMN,
       c.ROW_FILTER
FROM   DMT_CEMLI_CATALOG_TBL c
WHERE  c.TFM_TABLE IS NOT NULL
AND    c.CEMLI_CODE NOT IN ('MockObject', 'MockChild');
