-- PACKAGE BODY DMT_REST_LOOKUP_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_REST_LOOKUP_PKG" 
AS
-- ============================================================
-- DMT_REST_LOOKUP_PKG body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_REST_LOOKUP_PKG';

    -- Private: {"error": <message>} built with SQL JSON_OBJECT so any character in
    -- the message (quotes, newlines, bytes of a compressed HTTP error body quoted by
    -- HTTP_REQUEST) is escaped. A hand-concatenated string could be invalid JSON,
    -- which callers read as "no error" (JSON_VALUE of invalid JSON is NULL).
    FUNCTION error_json (p_message IN VARCHAR2) RETURN CLOB
    IS
        l_out CLOB;
    BEGIN
        SELECT JSON_OBJECT('error' VALUE p_message) INTO l_out FROM DUAL;
        RETURN l_out;
    END error_json;


    FUNCTION LOOKUP_RECORD (
        p_object_type  IN VARCHAR2,
        p_key_value    IN VARCHAR2
    ) RETURN CLOB
    IS
        l_cfg_endpoint     DMT_REST_LOOKUP_TBL.REST_ENDPOINT%TYPE;
        l_cfg_filter       DMT_REST_LOOKUP_TBL.QUERY_FILTER%TYPE;
        l_cfg_fields       DMT_REST_LOOKUP_TBL.DISPLAY_FIELDS%TYPE;
        l_cfg_labels       DMT_REST_LOOKUP_TBL.DISPLAY_LABELS%TYPE;
        l_cfg_cemli        DMT_REST_LOOKUP_TBL.CEMLI_CODE%TYPE;
        l_cfg_fw_version   DMT_REST_LOOKUP_TBL.REST_FRAMEWORK_VERSION%TYPE;
        l_cfg_absent_field DMT_REST_LOOKUP_TBL.ABSENT_FIELD%TYPE;
        l_cfg_absent_value DMT_REST_LOOKUP_TBL.ABSENT_VALUE%TYPE;
        l_cfg_na_reason    DMT_REST_LOOKUP_TBL.NOT_APPLICABLE_REASON%TYPE;
        l_query_param      VARCHAR2(4000);

        l_base_url         VARCHAR2(500);
        l_username         VARCHAR2(200);
        l_password         VARCHAR2(200);
        l_auth_header      VARCHAR2(600);
        l_obj_code         VARCHAR2(100);
        l_full_url         VARCHAR2(4000);
        l_response         CLOB;
        l_status           NUMBER;
        l_result           CLOB;

        l_items_json       CLOB;
        l_first_item       CLOB;
        l_resp_obj         JSON_OBJECT_T;
        l_items_arr        JSON_ARRAY_T;
        l_item0_obj        JSON_OBJECT_T;
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
            FROM   DMT_REST_LOOKUP_TBL
            WHERE  OBJECT_TYPE = p_object_type AND ENABLED = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                BEGIN
                    SELECT rl.OBJECT_TYPE INTO l_resolved_type
                    FROM   DMT_REST_LOOKUP_TBL rl
                    WHERE  rl.ENABLED = 'Y'
                    AND    rl.OBJECT_TYPE = (
                               SELECT MIN(c.CEMLI_CODE)
                               FROM   DMT_V_CEMLI_TFM_TABLES c
                               WHERE  c.DISPLAY_NAME = p_object_type);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        RETURN '{"error":"No REST lookup configured for object type: ' ||
                               REPLACE(p_object_type, '"', '\"') || '"}';
                END;
        END;

        SELECT REST_ENDPOINT, QUERY_FILTER, DISPLAY_FIELDS, DISPLAY_LABELS, CEMLI_CODE,
               REST_FRAMEWORK_VERSION, ABSENT_FIELD, ABSENT_VALUE, NOT_APPLICABLE_REASON
        INTO   l_cfg_endpoint, l_cfg_filter, l_cfg_fields, l_cfg_labels, l_cfg_cemli,
               l_cfg_fw_version, l_cfg_absent_field, l_cfg_absent_value, l_cfg_na_reason
        FROM   DMT_REST_LOOKUP_TBL
        WHERE  OBJECT_TYPE = l_resolved_type
        AND    ENABLED = 'Y';

        -- Fusion exposes no REST read resource for this object (proven on the pod and
        -- recorded on the registry row): answer NOT_APPLICABLE with the recorded reason
        -- instead of calling a resource that does not exist. Reconciliation (BIP) is
        -- the record-level proof for such objects.
        IF l_cfg_na_reason IS NOT NULL THEN
            SELECT JSON_OBJECT('not_applicable' VALUE l_cfg_na_reason)
            INTO   l_result FROM DUAL;
            RETURN l_result;
        END IF;

        -- Get Fusion URL and credentials
        l_base_url := DMT_UTIL_PKG.GET_CONFIG('FUSION_URL');
        IF l_base_url IS NULL THEN
            RETURN '{"error":"FUSION_URL not configured in DMT_CONFIG_TBL."}';
        END IF;

        -- Credential selection: verify reads Fusion as the SAME user the object's
        -- load runs as, from the same central source the loader uses, so a record
        -- is visible to the verify exactly when it was visible to the load
        -- (Requisitions and purchase agreements are data-security-scoped to their
        -- preparer/buyer, calvin.roth, and return count 0 to fin_impl; HCM objects
        -- read as hcm_impl). Every object, ERP and HCM alike, resolves its pair
        -- through DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS for its object code, i.e.
        -- DMT_ERP_INTERFACE_OPTIONS_TBL.FUSION_USERNAME/PASSWORD with the loader's
        -- own fallback to the global FUSION_USERNAME (backlog #309, #430).
        -- There is no verify-only credential: the per-object user lives in one
        -- seeded home, the ERP interface options row.
        -- The object code is, in order: the registry row's CEMLI_CODE (set on the
        -- rows whose label is not in the display catalog, e.g. 'Payroll
        -- Relationships'); else the catalog code for the label the button passed
        -- (e.g. 'Req Headers' -> 'Requisitions'); else the registry key itself
        -- (rows keyed by object code, e.g. 'SalaryBases').
        IF l_cfg_cemli IS NULL THEN
            SELECT MIN(CEMLI_CODE) INTO l_obj_code
            FROM   DMT_V_CEMLI_TFM_TABLES WHERE DISPLAY_NAME = p_object_type;
        END IF;
        l_obj_code := COALESCE(l_cfg_cemli, l_obj_code, l_resolved_type);

        DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(
            p_cemli_code => l_obj_code,
            x_username   => l_username,
            x_password   => l_password);

        -- Basic header for the resolved credentials. HTTP_REQUEST uses the GLOBAL
        -- (fin_impl) auth unless an explicit header is passed, so build it here and
        -- pass it as p_auth_header — otherwise the per-object load user above is inert.
        l_auth_header := DMT_UTIL_PKG.BASIC_AUTH_HEADER(l_username, l_password);

        -- Build the full URL:
        --   {base}{endpoint}?onlyData=true&limit=1&q={filter}
        -- Replace {KEY} in the filter with the actual value (URL-encoded)
        -- Strip trailing slash from base URL to avoid double slashes
        -- Note: the &fields= parameter is intentionally omitted — some Fusion
        -- REST endpoints reject requests with unrecognised field names (HTTP 400).
        -- We fetch all fields and extract only the configured ones from items[0].
        l_full_url := RTRIM(l_base_url, '/') || l_cfg_endpoint ||
                      '?onlyData=true&limit=1';

        -- QUERY_FILTER is either a q expression ('Attr={KEY}', or with
        -- REST_FRAMEWORK_VERSION 4 a child path such as 'Address.AddressId={KEY}')
        -- or a finder ('finder=<Name>;<param>=<value>,...{KEY}...') for resources
        -- that only answer through a finder (ledgerBalances). The key is substituted
        -- first and the whole parameter value is URL-escaped once, so spaces, quotes
        -- and the finder's ; , = separators travel encoded.
        IF l_cfg_filter LIKE 'finder=%' THEN
            l_query_param := '&finder=' || UTL_URL.ESCAPE(
                REPLACE(SUBSTR(l_cfg_filter, LENGTH('finder=') + 1), '{KEY}', p_key_value),
                TRUE, 'UTF-8');
        ELSE
            l_query_param := '&q=' || UTL_URL.ESCAPE(
                REPLACE(l_cfg_filter, '{KEY}', p_key_value), TRUE, 'UTF-8');
        END IF;
        l_full_url := l_full_url || l_query_param;

        -- Call Fusion REST API
        BEGIN
            DMT_UTIL_PKG.HTTP_REQUEST(
                p_url          => l_full_url,
                p_method       => 'GET',
                p_content_type => 'application/json',
                p_auth_header  => l_auth_header,
                x_response     => l_response,
                x_status_code  => l_status,
                p_rest_framework_version => l_cfg_fw_version
            );
        EXCEPTION
            WHEN OTHERS THEN
                RETURN error_json('REST call failed: ' || SQLERRM);
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

        -- Parse the response ONCE into a JSON object and grab items[0]. The field
        -- values are then read with the JSON_OBJECT_T.get_String PL/SQL API, which
        -- takes the field name as a runtime string argument — no dynamic SQL needed
        -- (code-standard #46: no runtime EXECUTE IMMEDIATE). Behaviour matches the
        -- former JSON_VALUE(:1, '$.items[0].<field>') extraction: a missing field or
        -- unparseable response yields a NULL value, handled the same as before.
        BEGIN
            l_resp_obj  := JSON_OBJECT_T.parse(l_response);
            l_items_arr := l_resp_obj.get_Array('items');
            IF l_items_arr IS NOT NULL AND l_items_arr.get_size > 0 THEN
                l_item0_obj := JSON_OBJECT_T(l_items_arr.get(0));
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                l_item0_obj := NULL;
        END;

        -- No item, or the registry's "absent" marker on the one item a
        -- fixed-shape resource always returns (ledgerBalances answers '#Missing'
        -- for a balance that does not exist): the record is not in Fusion.
        IF l_item0_obj IS NULL
           OR (l_cfg_absent_field IS NOT NULL
               AND l_item0_obj.has(l_cfg_absent_field)
               AND l_item0_obj.get_String(l_cfg_absent_field) = l_cfg_absent_value) THEN
            RETURN '{"error":"Record not found in Fusion for ' ||
                   REPLACE(p_object_type, '"', '\"') || ' = ' ||
                   REPLACE(p_key_value, '"', '\"') || '"}';
        END IF;

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

            -- Extract value from items[0] via the JSON_OBJECT_T PL/SQL API. The
            -- field name is a runtime argument, so no dynamic SQL is needed
            -- (previously an EXECUTE IMMEDIATE built the JSON_VALUE path). To match
            -- the former JSON_VALUE(... RETURNING VARCHAR2) behaviour exactly, a
            -- JSON string yields its text and a JSON number/boolean yields its
            -- canonical scalar text (get_String returns NULL for non-strings, so
            -- non-string scalars are read from the element's stringified form with
            -- the surrounding JSON quotes removed). A missing field yields NULL.
            DECLARE
                l_elem JSON_ELEMENT_T;
            BEGIN
                IF l_item0_obj IS NULL OR NOT l_item0_obj.has(l_field_name) THEN
                    l_field_value := NULL;
                ELSE
                    l_field_value := l_item0_obj.get_String(l_field_name);
                    IF l_field_value IS NULL THEN
                        l_elem := l_item0_obj.get(l_field_name);
                        IF l_elem IS NOT NULL AND l_elem.is_Scalar THEN
                            -- number/boolean scalar: to_String() renders it without
                            -- quotes (quotes only wrap JSON strings), so use as-is.
                            l_field_value := l_elem.to_String();
                        END IF;
                    END IF;
                END IF;
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
            l_footer VARCHAR2(4000);  -- holds the key, which can be a long finder parameter list
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
            RETURN error_json(SQLERRM);
    END LOOKUP_RECORD;

END DMT_REST_LOOKUP_PKG;
/
