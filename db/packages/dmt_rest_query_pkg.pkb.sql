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
        l_retry_json   CLOB;
        l_result       CLOB;
        l_error_msg    VARCHAR2(4000);
        l_primary_key  VARCHAR2(400);
        l_na_reason    VARCHAR2(4000);
    BEGIN
        -- Log the request (includes TFM seq for traceability)
        DMT_UTIL_PKG.LOG(
            p_message   => 'REST query: sub_object=' || p_sub_object ||
                           ' key=' || NVL(p_lookup_key, p_display_key) ||
                           ' tfm_seq=' || p_tfm_seq_id,
            p_log_type  => 'INFO',
            p_package   => C_PKG,
            p_procedure => 'QUERY_FUSION_RECORD');

        -- Delegate to the existing lookup package. Try the reconciliation key
        -- (lookup_key) first; if the record is not found by that value, retry
        -- with the display key. Fusion resources vary in which field is
        -- queryable — some by the migration's source reference, some only by
        -- the business name — and the button carries both values, so trying
        -- both makes the verify robust without per-object key wiring.
        l_primary_key := NVL(p_lookup_key, p_display_key);
        l_lookup_json := DMT_REST_LOOKUP_PKG.LOOKUP_RECORD(
            p_object_type => p_sub_object,
            p_key_value   => l_primary_key
        );
        l_error_msg := JSON_VALUE(l_lookup_json, '$.error');

        -- No REST read resource exists for this object (registry
        -- NOT_APPLICABLE_REASON): pass the reason through as its own status, with
        -- the reason as the single displayed row so the page-57 modal shows it.
        l_na_reason := JSON_VALUE(l_lookup_json, '$.not_applicable');
        IF l_na_reason IS NOT NULL THEN
            SELECT JSON_OBJECT(
                       'status'  VALUE 'not_applicable',
                       'message' VALUE l_na_reason,
                       'rows'    VALUE JSON_ARRAY(
                                     JSON_OBJECT('label' VALUE 'Verify in Fusion (REST)',
                                                 'value' VALUE 'Not applicable: ' || l_na_reason)),
                       'object'  VALUE p_sub_object,
                       'key'     VALUE l_primary_key)
            INTO   l_result
            FROM   DUAL;
            RETURN l_result;
        END IF;

        -- The retry is a second chance, never a replacement verdict: if it does
        -- not find the record either (or errors, e.g. HTTP 500 because an id-keyed
        -- filter such as RequisitionHeaderId= was handed the display number), the
        -- FIRST lookup's "not found" is the honest answer and is what we return.
        IF l_error_msg IS NOT NULL
           AND INSTR(LOWER(l_error_msg), 'not found') > 0
           AND p_display_key IS NOT NULL
           AND p_display_key <> l_primary_key THEN
            l_retry_json := DMT_REST_LOOKUP_PKG.LOOKUP_RECORD(
                p_object_type => p_sub_object,
                p_key_value   => p_display_key
            );
            -- Accept the retry only when it actually returned fields: an error
            -- reply that is not valid JSON must never read as a success.
            IF l_retry_json IS NOT NULL
               AND JSON_VALUE(l_retry_json, '$.error') IS NULL
               AND JSON_QUERY(l_retry_json, '$.fields') IS NOT NULL THEN
                l_lookup_json := l_retry_json;
                l_error_msg   := NULL;
            END IF;
        END IF;

        IF l_lookup_json IS NULL THEN
            RETURN error_json('No response from lookup.');
        END IF;

        -- Still an error after the fallback: report it
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
