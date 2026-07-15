-- PACKAGE BODY DMT_REST_LOOKUP_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REST_LOOKUP_PKG" 
AS
-- ============================================================
-- DMT_REST_LOOKUP_PKG body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_REST_LOOKUP_PKG';


    FUNCTION LOOKUP_RECORD (
        p_object_type  IN VARCHAR2,
        p_key_value    IN VARCHAR2
    ) RETURN CLOB
    IS
        l_cfg_endpoint     DMT_REST_LOOKUP_TBL.REST_ENDPOINT%TYPE;
        l_cfg_filter       DMT_REST_LOOKUP_TBL.QUERY_FILTER%TYPE;
        l_cfg_fields       DMT_REST_LOOKUP_TBL.DISPLAY_FIELDS%TYPE;
        l_cfg_labels       DMT_REST_LOOKUP_TBL.DISPLAY_LABELS%TYPE;
        l_cfg_auth         DMT_REST_LOOKUP_TBL.AUTH_TYPE%TYPE;

        l_base_url         VARCHAR2(500);
        l_username         VARCHAR2(200);
        l_password         VARCHAR2(200);
        l_full_url         VARCHAR2(4000);
        l_response         CLOB;
        l_status           NUMBER;
        l_result           CLOB;

        l_items_json       CLOB;
        l_first_item       CLOB;
        l_field_name       VARCHAR2(200);
        l_field_label      VARCHAR2(200);
        l_field_value      VARCHAR2(4000);
        l_fields_str       VARCHAR2(1000);
        l_labels_str       VARCHAR2(1000);
        l_pos              NUMBER;
        l_sep              VARCHAR2(1) := ',';
        l_resolved_type    DMT_REST_LOOKUP_TBL.OBJECT_TYPE%TYPE;
        l_first_field      BOOLEAN := TRUE;
    BEGIN
        -- Validate inputs
        IF p_object_type IS NULL OR p_key_value IS NULL THEN
            RETURN '{"error":"Object type and key value are required."}';
        END IF;

        -- Resolve the object type. The page-57 "Verify in Fusion" button passes
        -- the sub-object DISPLAY LABEL (e.g. 'Parties', 'PO Lines'). The registry
        -- (DMT_REST_LOOKUP_TBL) is keyed either by that same display label OR by
        -- the object code (e.g. 'Customers'). Try a direct match first; if none,
        -- map the display label to its object code via the display catalog and
        -- fall back to the object-level lookup — so every sub-object of an object
        -- resolves to at least that object's REST verification.
        BEGIN
            SELECT OBJECT_TYPE INTO l_resolved_type
            FROM   DMT_OWNER.DMT_REST_LOOKUP_TBL
            WHERE  OBJECT_TYPE = p_object_type AND ENABLED = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                BEGIN
                    SELECT rl.OBJECT_TYPE INTO l_resolved_type
                    FROM   DMT_OWNER.DMT_REST_LOOKUP_TBL rl
                    WHERE  rl.ENABLED = 'Y'
                    AND    rl.OBJECT_TYPE = (
                               SELECT MIN(c.CEMLI_CODE)
                               FROM   DMT_OWNER.DMT_V_CEMLI_TFM_TABLES c
                               WHERE  c.DISPLAY_NAME = p_object_type);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        RETURN '{"error":"No REST lookup configured for object type: ' ||
                               REPLACE(p_object_type, '"', '\"') || '"}';
                END;
        END;

        SELECT REST_ENDPOINT, QUERY_FILTER, DISPLAY_FIELDS, DISPLAY_LABELS, AUTH_TYPE
        INTO   l_cfg_endpoint, l_cfg_filter, l_cfg_fields, l_cfg_labels, l_cfg_auth
        FROM   DMT_OWNER.DMT_REST_LOOKUP_TBL
        WHERE  OBJECT_TYPE = l_resolved_type
        AND    ENABLED = 'Y';

        -- Get Fusion URL and credentials
        l_base_url := DMT_UTIL_PKG.GET_CONFIG('FUSION_URL');
        IF l_base_url IS NULL THEN
            RETURN '{"error":"FUSION_URL not configured in DMT_CONFIG_TBL."}';
        END IF;

        IF l_cfg_auth = 'HCM' THEN
            l_username := NVL(DMT_UTIL_PKG.GET_CONFIG('HCM_USERNAME'),
                              DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME'));
            l_password := NVL(DMT_UTIL_PKG.GET_CONFIG('HCM_PASSWORD'),
                              DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD'));
        ELSE
            l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
            l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');
        END IF;

        -- Build the full URL:
        --   {base}{endpoint}?onlyData=true&limit=1&q={filter}
        -- Replace {KEY} in the filter with the actual value (URL-encoded)
        -- Strip trailing slash from base URL to avoid double slashes
        -- Note: the &fields= parameter is intentionally omitted — some Fusion
        -- REST endpoints reject requests with unrecognised field names (HTTP 400).
        -- We fetch all fields and extract only the configured ones from items[0].
        l_full_url := RTRIM(l_base_url, '/') || l_cfg_endpoint ||
                      '?onlyData=true&limit=1';

        l_full_url := l_full_url ||
                      '&q=' || REPLACE(l_cfg_filter, '{KEY}',
                                       UTL_URL.ESCAPE(p_key_value, TRUE, 'UTF-8'));

        -- Call Fusion REST API
        BEGIN
            DMT_UTIL_PKG.HTTP_REQUEST(
                p_url          => l_full_url,
                p_method       => 'GET',
                p_content_type => 'application/json',
                x_response     => l_response,
                x_status_code  => l_status
            );
        EXCEPTION
            WHEN OTHERS THEN
                RETURN '{"error":"REST call failed: ' ||
                       REPLACE(REPLACE(SQLERRM, '"', '\"'), CHR(10), ' ') || '"}';
        END;

        IF l_response IS NULL OR DBMS_LOB.GETLENGTH(l_response) = 0 THEN
            RETURN '{"error":"Empty response from Fusion REST API."}';
        END IF;

        -- Parse the JSON response.
        -- Fusion REST returns: {"items":[{...}], "count":N, ...}
        -- We want items[0] fields.
        DECLARE
            l_count NUMBER;
        BEGIN
            SELECT JSON_VALUE(l_response, '$.count' RETURNING NUMBER)
            INTO   l_count
            FROM   DUAL;

            IF l_count = 0 THEN
                RETURN '{"error":"Record not found in Fusion for ' ||
                       REPLACE(p_object_type, '"', '\"') || ' = ' ||
                       REPLACE(p_key_value, '"', '\"') || '"}';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- count field might not exist; try to parse items directly
                NULL;
        END;

        -- Build result JSON by extracting each configured field from items[0]
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.WRITEAPPEND(l_result, 11, '{"fields":[');

        l_fields_str := l_cfg_fields;
        l_labels_str := l_cfg_labels;
        l_first_field := TRUE;

        LOOP
            -- Pop next field name
            l_pos := INSTR(l_fields_str, l_sep);
            IF l_pos > 0 THEN
                l_field_name  := TRIM(SUBSTR(l_fields_str, 1, l_pos - 1));
                l_fields_str  := SUBSTR(l_fields_str, l_pos + 1);
            ELSE
                l_field_name  := TRIM(l_fields_str);
                l_fields_str  := NULL;
            END IF;

            -- Pop next label
            l_pos := INSTR(l_labels_str, l_sep);
            IF l_pos > 0 THEN
                l_field_label := TRIM(SUBSTR(l_labels_str, 1, l_pos - 1));
                l_labels_str  := SUBSTR(l_labels_str, l_pos + 1);
            ELSE
                l_field_label := TRIM(l_labels_str);
                l_labels_str  := NULL;
            END IF;

            EXIT WHEN l_field_name IS NULL;

            -- Extract value from JSON items[0] using dynamic SQL
            -- (JSON_VALUE path must be a literal, so we build it dynamically)
            BEGIN
                EXECUTE IMMEDIATE
                    'SELECT JSON_VALUE(:1, ''$.items[0].' || l_field_name ||
                    ''' RETURNING VARCHAR2(4000)) FROM DUAL'
                INTO l_field_value
                USING l_response;
            EXCEPTION
                WHEN OTHERS THEN
                    l_field_value := NULL;
            END;

            -- Append to result
            IF NOT l_first_field THEN
                DBMS_LOB.WRITEAPPEND(l_result, 1, ',');
            END IF;
            l_first_field := FALSE;

            DECLARE
                l_entry VARCHAR2(4000);
            BEGIN
                l_entry := '{"label":"' ||
                           REPLACE(NVL(l_field_label, l_field_name), '"', '\"') ||
                           '","value":"' ||
                           REPLACE(NVL(l_field_value, ''), '"', '\"') || '"}';
                DBMS_LOB.WRITEAPPEND(l_result, LENGTH(l_entry), l_entry);
            END;

            EXIT WHEN l_fields_str IS NULL;
        END LOOP;

        -- Close JSON
        DECLARE
            l_footer VARCHAR2(200);
        BEGIN
            l_footer := '],"source":"Fusion REST API","object":"' ||
                        REPLACE(p_object_type, '"', '\"') ||
                        '","key":"' || REPLACE(p_key_value, '"', '\"') ||
                        '","timestamp":"' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '"}';
            DBMS_LOB.WRITEAPPEND(l_result, LENGTH(l_footer), l_footer);
        END;

        RETURN l_result;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_message => 'LOOKUP_RECORD failed. ObjectType=' || p_object_type ||
                             ' Key=' || p_key_value,
                p_sqlerrm => SQLERRM,
                p_package => C_PKG,
                p_procedure => 'LOOKUP_RECORD');
            RETURN '{"error":"' || REPLACE(REPLACE(SQLERRM, '"', '\"'), CHR(10), ' ') || '"}';
    END LOOKUP_RECORD;

END DMT_REST_LOOKUP_PKG;
/
