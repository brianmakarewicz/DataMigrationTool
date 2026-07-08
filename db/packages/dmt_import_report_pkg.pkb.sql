-- PACKAGE BODY DMT_IMPORT_REPORT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_IMPORT_REPORT_PKG" AS
-- ============================================================
-- DMT_IMPORT_REPORT_PKG body
-- Generic Fusion Import Report XML error parser.
--
-- Strategy: Fusion import reports use a consistent pattern —
-- error containers named LIST_xxx_ERROR with child elements
-- named xxx_ERROR. Each error child has message fields ending
-- in _MSG or _MESSAGE, and identifier fields.
--
-- The parser walks all top-level groups, finds elements whose
-- tag names contain 'ERROR', and extracts identifier + message
-- from each child. This works across modules without hardcoded
-- XPath per CEMLI.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_IMPORT_REPORT_PKG';

    -- --------------------------------------------------------
    -- PARSE_ERRORS
    -- --------------------------------------------------------
    FUNCTION PARSE_ERRORS (
        p_xml_clob IN CLOB
    ) RETURN t_error_list
    IS
        l_errors   t_error_list := t_error_list();
        l_xml      XMLTYPE;
        l_groups   XMLTYPE;
        l_group    XMLTYPE;
        l_items    XMLTYPE;
        l_item     XMLTYPE;
        l_grp_cnt  NUMBER;
        l_itm_cnt  NUMBER;
        l_tag      VARCHAR2(200);
        l_msg      VARCHAR2(4000);
        l_ident    VARCHAR2(500);
        l_child    XMLTYPE;
        l_ch_tag   VARCHAR2(200);
        l_ch_val   VARCHAR2(4000);
        l_ch_cnt   NUMBER;
        l_rec      t_import_error;
    BEGIN
        IF p_xml_clob IS NULL OR DBMS_LOB.GETLENGTH(p_xml_clob) = 0 THEN
            RETURN l_errors;
        END IF;

        BEGIN
            l_xml := XMLTYPE(p_xml_clob);
        EXCEPTION
            WHEN OTHERS THEN
                -- Not valid XML — return empty
                RETURN l_errors;
        END;

        -- Walk all child elements of the root node looking for
        -- elements whose tag contains 'ERROR' (case-insensitive).
        -- These are the error list containers (e.g. LIST_PROJECT_ERROR).
        l_grp_cnt := NVL(l_xml.extract('count(/*/*)').getNumberVal(), 0);

        FOR gi IN 1..l_grp_cnt LOOP
            BEGIN
                l_group := l_xml.extract('/*/*[' || gi || ']');
            EXCEPTION WHEN OTHERS THEN CONTINUE;
            END;

            IF l_group IS NULL THEN CONTINUE; END IF;

            l_tag := l_group.getRootElement();

            -- Only process groups whose tag contains 'ERROR'
            IF UPPER(l_tag) NOT LIKE '%ERROR%' THEN
                CONTINUE;
            END IF;

            -- Derive object type from the group tag (e.g. LIST_PROJECT_ERROR → PROJECT)
            l_rec.error_source := REPLACE(REPLACE(UPPER(l_tag), 'LIST_', ''), '_ERROR', '');

            -- Count child error elements
            l_itm_cnt := NVL(l_group.extract('count(/' || l_tag || '/*)').getNumberVal(), 0);

            FOR ii IN 1..l_itm_cnt LOOP
                BEGIN
                    l_item := l_group.extract('/' || l_tag || '/*[' || ii || ']');
                EXCEPTION WHEN OTHERS THEN CONTINUE;
                END;

                IF l_item IS NULL THEN CONTINUE; END IF;

                l_msg   := NULL;
                l_ident := NULL;
                l_rec.object_type := l_item.getRootElement();

                -- Walk child elements of this error item
                l_ch_cnt := NVL(l_item.extract('count(/' || l_rec.object_type || '/*)').getNumberVal(), 0);

                FOR ci IN 1..l_ch_cnt LOOP
                    BEGIN
                        l_child := l_item.extract('/' || l_rec.object_type || '/*[' || ci || ']');
                    EXCEPTION WHEN OTHERS THEN CONTINUE;
                    END;
                    IF l_child IS NULL THEN CONTINUE; END IF;

                    l_ch_tag := l_child.getRootElement();
                    l_ch_val := l_child.extract('/' || l_ch_tag || '/text()').getStringVal();

                    -- Classify the field: message vs identifier
                    IF UPPER(l_ch_tag) LIKE '%MSG%'
                       OR UPPER(l_ch_tag) LIKE '%MESSAGE%'
                       OR UPPER(l_ch_tag) LIKE '%ERR_TEXT%'
                       OR UPPER(l_ch_tag) LIKE '%ERROR_TEXT%'
                       OR UPPER(l_ch_tag) LIKE '%REJECTION%' THEN
                        IF l_msg IS NOT NULL THEN
                            l_msg := l_msg || ' | ' || l_ch_val;
                        ELSE
                            l_msg := l_ch_val;
                        END IF;
                    ELSIF UPPER(l_ch_tag) LIKE '%NUMBER%'
                          OR UPPER(l_ch_tag) LIKE '%NAME%'
                          OR UPPER(l_ch_tag) LIKE '%REFERENCE%'
                          OR UPPER(l_ch_tag) LIKE '%KEY%'
                          OR UPPER(l_ch_tag) LIKE '%ID' THEN
                        IF l_ident IS NOT NULL THEN
                            l_ident := l_ident || '/' || l_ch_val;
                        ELSE
                            l_ident := l_ch_val;
                        END IF;
                    END IF;
                END LOOP;

                -- If no message field identified, use the full XML text
                IF l_msg IS NULL THEN
                    l_msg := SUBSTR(l_item.getStringVal(), 1, 4000);
                END IF;

                l_rec.row_identifier := SUBSTR(l_ident, 1, 500);
                l_rec.error_message  := SUBSTR(l_msg, 1, 4000);

                l_errors.EXTEND;
                l_errors(l_errors.COUNT) := l_rec;
            END LOOP;
        END LOOP;

        RETURN l_errors;
    END PARSE_ERRORS;

    -- --------------------------------------------------------
    -- PARSE_AND_LOG_ERRORS
    -- --------------------------------------------------------
    FUNCTION PARSE_AND_LOG_ERRORS (
        p_run_id IN NUMBER,
        p_request_id     IN NUMBER,
        p_cemli_code     IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER
    IS
        C_PROC     CONSTANT VARCHAR2(30) := 'PARSE_AND_LOG_ERRORS';
        l_xml      CLOB;
        l_errors   t_error_list;
        l_prefix   VARCHAR2(50) := NVL(p_cemli_code, 'UNKNOWN') || ' > ';
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. ESS request: ' || p_request_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Download the ESS output XML
        BEGIN
            l_xml := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(p_request_id);
        EXCEPTION
            WHEN OTHERS THEN
                DMT_UTIL_PKG.LOG_ERROR(
                    p_run_id => p_run_id,
                    p_message        => C_PROC || ': Failed to download ESS output XML for request ' || p_request_id,
                    p_sqlerrm        => SQLERRM,
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);
                RETURN 0;
        END;

        IF l_xml IS NULL OR DBMS_LOB.GETLENGTH(l_xml) = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': ESS output XML is empty for request ' || p_request_id,
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN 0;
        END IF;

        -- Parse
        l_errors := PARSE_ERRORS(l_xml);

        IF l_errors.COUNT = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No errors found in Import Report XML. Rows: 0.',
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN 0;
        END IF;

        -- Log each error
        FOR i IN 1..l_errors.COUNT LOOP
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => '[IMPORT_REPORT] ' ||
                    NVL(l_errors(i).error_source, '?') || ' > ' ||
                    NVL(l_errors(i).row_identifier, '(no key)') || ': ' ||
                    NVL(l_errors(i).error_message, '(no message)'),
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => l_prefix || C_PROC);
        END LOOP;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Errors found: ' || l_errors.COUNT,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml);
        END IF;

        RETURN l_errors.COUNT;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN 0;
    END PARSE_AND_LOG_ERRORS;

END DMT_IMPORT_REPORT_PKG;
/
