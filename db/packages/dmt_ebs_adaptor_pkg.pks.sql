-- PACKAGE DMT_EBS_ADAPTOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_EBS_ADAPTOR_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_EBS_ADAPTOR_PKG
-- Connects to a source Oracle EBS instance, extracts supplier data,
-- and loads it into DMT staging tables in canonical format
-- ============================================================

    -- Extract suppliers from EBS and stage for a new batch.
    -- Returns the BATCH_ID created.
    FUNCTION STAGE_SUPPLIERS (
        p_source_system  IN VARCHAR2 DEFAULT 'EBS',
        p_vendor_id_from IN NUMBER   DEFAULT NULL,  -- optional filter range
        p_vendor_id_to   IN NUMBER   DEFAULT NULL
    ) RETURN NUMBER;

END DMT_EBS_ADAPTOR_PKG;
/
