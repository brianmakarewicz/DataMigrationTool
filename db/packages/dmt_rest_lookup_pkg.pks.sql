-- PACKAGE DMT_REST_LOOKUP_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REST_LOOKUP_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REST_LOOKUP_PKG
-- Look up LOADED records against live Fusion REST APIs.
--
-- Called from APEX via Ajax callback. Takes an object type and
-- lookup key, queries Fusion, and returns a lightweight JSON
-- object with the configured display fields.
--
-- Configuration lives in DMT_REST_LOOKUP_TBL (one row per
-- object type with REST endpoint, query filter, and field list).
-- ============================================================

    -- Main entry point for APEX.
    -- Returns JSON like:
    --   {"fields":[{"label":"Supplier ID","value":"12345"},...],"source":"Fusion REST","timestamp":"..."}
    -- On error returns:
    --   {"error":"message"}
    FUNCTION LOOKUP_RECORD (
        p_object_type  IN VARCHAR2,
        p_key_value    IN VARCHAR2
    ) RETURN CLOB;

END DMT_REST_LOOKUP_PKG;
/
