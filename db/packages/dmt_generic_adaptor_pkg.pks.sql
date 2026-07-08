-- PACKAGE DMT_GENERIC_ADAPTOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_GENERIC_ADAPTOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_GENERIC_ADAPTOR_PKG
-- Accepts supplier data from a CSV upload (via APEX or file)
-- and loads it into DMT staging tables in canonical format
-- ============================================================

    -- Stage suppliers from a CSV CLOB (uploaded via APEX).
    -- Returns the BATCH_ID created.
    FUNCTION STAGE_SUPPLIERS_FROM_CSV (
        p_csv_data      IN CLOB,
        p_source_system IN VARCHAR2 DEFAULT 'GENERIC'
    ) RETURN NUMBER;

END DMT_GENERIC_ADAPTOR_PKG;
/
