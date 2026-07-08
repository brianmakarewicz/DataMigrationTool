-- PACKAGE DMT_UPLOAD_DICT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_UPLOAD_DICT_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_UPLOAD_DICT_PKG
-- Manages DMT_UPLOAD_DICT_TBL — the metadata-driven data
-- dictionary used by the CSV upload feature and Page 9
-- Upload Reference Guide.
--
-- SEED_DICTIONARY:     Initial population from USER_TAB_COLUMNS
--                      for all staging tables registered in
--                      DMT_UPLOAD_OBJECT_TBL.
--
-- REFRESH_DICTIONARY:  Merges current USER_TAB_COLUMNS state.
--                      Adds new columns, removes dropped columns,
--                      updates data types. Preserves manually
--                      entered DESCRIPTION and SAMPLE_VALUE.
-- ============================================================

    -- Full initial seed. Truncates DMT_UPLOAD_DICT_TBL first.
    -- Call once after creating all staging tables and seeding
    -- DMT_UPLOAD_OBJECT_TBL.
    PROCEDURE SEED_DICTIONARY;

    -- Incremental refresh. Adds/removes/updates columns without
    -- losing manually entered DESCRIPTION or SAMPLE_VALUE.
    PROCEDURE REFRESH_DICTIONARY;

END DMT_UPLOAD_DICT_PKG;
/
