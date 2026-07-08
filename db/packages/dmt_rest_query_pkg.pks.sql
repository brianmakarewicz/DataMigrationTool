-- PACKAGE DMT_REST_QUERY_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REST_QUERY_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_REST_QUERY_PKG
-- APEX-facing wrapper for Fusion REST record verification.
--
-- Called from the Page 57 AJAX callback (QUERY_FUSION_REST).
-- Delegates to DMT_REST_LOOKUP_PKG.LOOKUP_RECORD and reformats
-- the response into the JSON shape the modal JavaScript expects.
--
-- Returns:
--   {"status":"ok","rows":[{"label":"...","value":"..."},...],"object":"...","key":"..."}
--   {"status":"error","message":"..."}
-- ============================================================

    FUNCTION QUERY_FUSION_RECORD (
        p_sub_object   IN VARCHAR2,
        p_display_key  IN VARCHAR2,
        p_tfm_seq_id   IN NUMBER DEFAULT NULL,
        p_lookup_key   IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

END DMT_REST_QUERY_PKG;
/
