-- PACKAGE BODY DMT_REST_QUERY_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REST_QUERY_PKG" 
AS
-- ============================================================
-- DMT_REST_QUERY_PKG body
-- Thin wrapper over DMT_REST_LOOKUP_PKG.LOOKUP_RECORD.
-- Translates the lookup JSON format into the APEX modal format.
-- JSON_OBJECT called via SELECT INTO (PL/SQL RETURNING CLOB
-- not supported on ATP 19c).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_REST_QUERY_PKG';


    -- Private: build error JSON safely via SQL JSON_OBJECT
    FUNCTION error_json (p_message IN VARCHAR2) RETURN CLOB
    IS
        l_out CLOB;
    BEGIN
        SELECT JSON_OBJECT(
                   'status'  VALUE 'error',
                   'message' VALUE p_message
               ) INTO l_out FROM DUAL;
        RETURN l_out;
    END error_json;


    FUNCTION QUERY_FUSION_RECORD (
        p_sub_object   IN VARCHAR2,
        p_display_key  IN VARCHAR2,
        p_tfm_seq_id   IN NUMBER DEFAULT NULL,
        p_lookup_key   IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_lookup_json  CLOB;
        l_result       CLOB;
        l_error_msg    VARCHAR2(4000);
    BEGIN
        -- Log the request (includes TFM seq for traceability)
        DMT_UTIL_PKG.LOG(
            p_message   => 'REST query: sub_object=' || p_sub_object ||
                           ' key=' || NVL(p_lookup_key, p_display_key) ||
                           ' tfm_seq=' || p_tfm_seq_id,
            p_log_type  => 'INFO',
            p_package   => C_PKG,
            p_procedure => 'QUERY_FUSION_RECORD');

        -- Delegate to the existing lookup package
        -- Use p_lookup_key when available (resolves parent key for child objects)
        l_lookup_json := DMT_REST_LOOKUP_PKG.LOOKUP_RECORD(
            p_object_type => p_sub_object,
            p_key_value   => NVL(p_lookup_key, p_display_key)
        );

        IF l_lookup_json IS NULL THEN
            RETURN error_json('No response from lookup.');
        END IF;

        -- Check if LOOKUP_RECORD returned an error: {"error":"..."}
        l_error_msg := JSON_VALUE(l_lookup_json, '$.error');
        IF l_error_msg IS NOT NULL THEN
            RETURN error_json(l_error_msg);
        END IF;

        -- LOOKUP_RECORD returned success: {"fields":[...],"source":"...","object":"...","key":"...","timestamp":"..."}
        -- Reformat to: {"status":"ok","rows":[...],"object":"...","key":"..."}
        BEGIN
            SELECT JSON_OBJECT(
                       'status' VALUE 'ok',
                       'rows'   VALUE JSON_QUERY(l_lookup_json, '$.fields'),
                       'object' VALUE NVL(JSON_VALUE(l_lookup_json, '$.object'), p_sub_object),
                       'key'    VALUE NVL(JSON_VALUE(l_lookup_json, '$.key'), p_display_key)
                   )
            INTO   l_result
            FROM   DUAL;
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG_ERROR(
                    p_message   => 'JSON reformat failed for lookup response',
                    p_sqlerrm   => SQLERRM,
                    p_package   => C_PKG,
                    p_procedure => 'QUERY_FUSION_RECORD');
                RETURN error_json('Failed to parse lookup response.');
        END;

        RETURN l_result;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'QUERY_FUSION_RECORD failed. sub_object=' || p_sub_object ||
                               ' key=' || p_display_key || ' tfm_seq=' || p_tfm_seq_id,
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => 'QUERY_FUSION_RECORD');
            RETURN error_json(SQLERRM);
    END QUERY_FUSION_RECORD;

END DMT_REST_QUERY_PKG;
/
