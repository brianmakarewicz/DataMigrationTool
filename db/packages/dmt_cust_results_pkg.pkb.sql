-- PACKAGE BODY DMT_CUST_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_CUST_RESULTS_PKG" 
AS
-- ============================================================
-- DMT_CUST_RESULTS_PKG body
-- Customers BIP reconciliation.
-- Pattern: identical to DMT_PO_RESULTS_PKG.
-- Primary reconciliation on HZ_IMP_PARTIES_T; cascade to 6 children.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_CUST_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Customers';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
    -- (Duplicated to keep packages independent.)
    -- --------------------------------------------------------
    FUNCTION bip_soap_post (
        p_url      IN VARCHAR2,
        p_action   IN VARCHAR2,
        p_body     IN CLOB
    ) RETURN CLOB IS
        l_req      UTL_HTTP.REQ;
        l_resp     UTL_HTTP.RESP;
        l_response CLOB;
        l_chunk    VARCHAR2(32767);
        l_offset   INTEGER := 1;
        l_amount   INTEGER;
        l_body_len INTEGER;
    BEGIN
        UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
        UTL_HTTP.SET_TRANSFER_TIMEOUT(600);

        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST', 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Type',   'text/xml; charset=utf-8');
        UTL_HTTP.SET_HEADER(l_req, 'Content-Length', DBMS_LOB.GETLENGTH(p_body));
        UTL_HTTP.SET_HEADER(l_req, 'SOAPAction',     '"' || p_action || '"');
        UTL_HTTP.SET_HEADER(l_req, 'Accept',         'text/xml');

        l_body_len := DBMS_LOB.GETLENGTH(p_body);
        WHILE l_offset <= l_body_len LOOP
            l_amount := LEAST(8000, l_body_len - l_offset + 1);
            l_chunk  := DBMS_LOB.SUBSTR(p_body, l_amount, l_offset);
            UTL_HTTP.WRITE_TEXT(l_req, l_chunk);
            l_offset := l_offset + l_amount;
        END LOOP;

        l_resp := UTL_HTTP.GET_RESPONSE(l_req);

        DBMS_LOB.CREATETEMPORARY(l_response, TRUE);
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(l_resp, l_chunk, 32767);
                DBMS_LOB.APPEND(l_response, l_chunk);
            END LOOP;
        EXCEPTION WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;
        UTL_HTTP.END_RESPONSE(l_resp);

        IF l_resp.status_code NOT BETWEEN 200 AND 299 THEN
            RAISE_APPLICATION_ERROR(-20030,
                'BIP SOAP call failed. Status: ' || l_resp.status_code ||
                ' | Action: ' || p_action ||
                ' | Response (first 500): ' || DBMS_LOB.SUBSTR(l_response, 500, 1));
        END IF;

        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
            RAISE;
    END bip_soap_post;

    -- --------------------------------------------------------
    -- (b64_to_clob removed — base64 decode is now centralised in
    --  DMT_UTIL_PKG.BASE64_DECODE_CLOB / BIP_REPORT_XML, which decode CLOBs of
    --  any size. The old local copy truncated at VARCHAR2(32767).)

    -- --------------------------------------------------------
    -- FETCH_BIP_RESULTS
    -- --------------------------------------------------------
    FUNCTION FETCH_BIP_RESULTS (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) RETURN CLOB IS
        C_PROC       CONSTANT VARCHAR2(30) := 'FETCH_BIP_RESULTS';
        l_base_url   VARCHAR2(500);
        l_username   VARCHAR2(100);
        l_password   VARCHAR2(100);
        l_rpt_path   VARCHAR2(500);
        l_url        VARCHAR2(500);
        l_action     CONSTANT VARCHAR2(200) :=
            'http://xmlns.oracle.com/oxp/service/v2/ReportService/runReportRequest';
        l_env        CLOB;
        l_resp       CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. CEMLI: ' || C_CEMLI ||
                                ' | load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_base_url := RTRIM(DMT_UTIL_PKG.GET_CONFIG('FUSION_URL'), '/');
        l_username := DMT_UTIL_PKG.GET_CONFIG('FUSION_USERNAME');
        l_password := DMT_UTIL_PKG.GET_CONFIG('FUSION_PASSWORD');

        IF l_base_url IS NULL OR l_username IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20031,
                C_PROC || ': Fusion connection config is incomplete.');
        END IF;

        BEGIN
            SELECT REPORT_CATALOG_PATH
            INTO   l_rpt_path
            FROM   DMT_OWNER.DMT_BIP_REPORT_TBL
            WHERE  CEMLI_CODE = C_CEMLI;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    C_PROC || ': No row in DMT_BIP_REPORT_TBL for CEMLI_CODE = ''' || C_CEMLI || '''.');
        END;

        IF l_rpt_path IS NULL THEN
            RAISE_APPLICATION_ERROR(-20033,
                C_PROC || ': REPORT_CATALOG_PATH is NULL for CEMLI_CODE = ''' || C_CEMLI || '''.');
        END IF;

        l_url := l_base_url || '/xmlpserver/services/v2/ReportService';

        DBMS_LOB.CREATETEMPORARY(l_env, TRUE);
        DBMS_LOB.APPEND(l_env, TO_CLOB(
            '<soapenv:Envelope' ||
            ' xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"' ||
            ' xmlns:v2="http://xmlns.oracle.com/oxp/service/v2">' ||
            '  <soapenv:Header/>' ||
            '  <soapenv:Body>' ||
            '    <v2:runReport>' ||
            '      <v2:reportRequest>' ||
            '        <v2:reportAbsolutePath>' || l_rpt_path || '</v2:reportAbsolutePath>' ||
            '        <v2:attributeFormat>xml</v2:attributeFormat>' ||
            '        <v2:parameterNameValues>' ||
            '          <v2:listOfParamNameValues>' ||
            '            <v2:item>' ||
            '              <v2:name>P_BATCH_ID</v2:name>' ||
            '              <v2:values><v2:item>' || TO_CHAR(p_load_ess_id) || '</v2:item></v2:values>' ||
            '            </v2:item>' ||
            '          </v2:listOfParamNameValues>' ||
            '        </v2:parameterNameValues>' ||
            '        <v2:sizeOfDataChunkDownload>-1</v2:sizeOfDataChunkDownload>' ||
            '      </v2:reportRequest>' ||
            '      <v2:userID>' || l_username || '</v2:userID>' ||
            '      <v2:password>' || l_password || '</v2:password>' ||
            '    </v2:runReport>' ||
            '  </soapenv:Body>' ||
            '</soapenv:Envelope>'));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'BIP runReport request built. Report: ' || l_rpt_path,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_resp := bip_soap_post(l_url, l_action, l_env);
        DBMS_LOB.FREETEMPORARY(l_env);

        IF DBMS_LOB.INSTR(l_resp, 'soapenv:Fault') > 0 OR
           DBMS_LOB.INSTR(l_resp, 'soap:Fault')    > 0 THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': SOAP Fault from BIP runReport. Report: ' || l_rpt_path ||
                ' | Response (first 1000): ' || DBMS_LOB.SUBSTR(l_resp, 1000, 1));
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Response bytes: ' || DBMS_LOB.GETLENGTH(l_resp),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        RETURN l_resp;

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END FETCH_BIP_RESULTS;

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- Parses BIP XML response (base64 reportBytes), updates
    -- party TFM rows (primary), cascades to 6 child TFM tables,
    -- then echoes back to all 7 STG tables.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Decode the BIP report via the shared helper (handles any size, no
        -- VARCHAR2(32767) truncation). Returns NULL when there are no rows.
        l_xml := DMT_UTIL_PKG.BIP_REPORT_XML(p_xml_data);
        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. No rows updated.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        -- Process party rows from BIP XML
        -- HZ_IMP_PARTIES_T IMPORT_STATUS: 'C' = Complete (success), 'E' = Error
        FOR r IN (
            SELECT x.party_orig_system_reference,
                   x.party_number,
                   x.party_id,
                   UPPER(x.interface_status) AS interface_status,
                   x.batch_id
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    party_orig_system_reference VARCHAR2(255)  PATH 'PARTY_ORIG_SYSTEM_REFERENCE',
                    party_number               VARCHAR2(30)    PATH 'PARTY_NUMBER',
                    party_id                   VARCHAR2(20)    PATH 'PARTY_ID',
                    interface_status           VARCHAR2(10)    PATH 'INTERFACE_STATUS',
                    batch_id                   VARCHAR2(20)    PATH 'BATCH_ID'
            ) x
        ) LOOP
            -- INTERFACE_STATUS: NULL = pending, '1' or 'C' = Complete, '4' or 'E' = Error
            IF r.interface_status IS NULL OR r.interface_status IN ('1','C','COMPLETED','SUCCESS','PROCESSED') THEN
                UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       FUSION_PARTY_ID      = TO_NUMBER(r.party_id),
                       FUSION_PARTY_NUMBER  = r.party_number,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID              = p_run_id
                AND    PARTY_ORIG_SYSTEM_REFERENCE = r.party_orig_system_reference
                AND    TFM_STATUS                     != 'LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.interface_status IN ('4','E','ERROR','REJECTED','FAILED','FAILURE') THEN
                UPDATE DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL
                SET    TFM_STATUS               = 'FAILED',
                       ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                 '[FUSION_ERROR] Import failed. Batch ID: ' || NVL(r.batch_id, 'N/A')),
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID              = p_run_id
                AND    PARTY_ORIG_SYSTEM_REFERENCE = r.party_orig_system_reference
                AND    TFM_STATUS                     != 'FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- ============================================================
        -- Cascade LOADED to child TFM tables
        -- Linkage: PARTY_ORIG_SYSTEM_REFERENCE for party-level children,
        -- then cascading down via SITE/ACCT ORIG_SYSTEM_REFERENCE.
        -- ============================================================

        -- Locations: linked via party sites -> location ref (indirect).
        -- For simplicity, locations are set LOADED if ANY party in the batch is LOADED.
        -- A more precise linkage would require joining through party_sites.
        -- Mark all GENERATED locations as LOADED (they belong to this batch).
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL loc
        SET    loc.TFM_STATUS            = 'LOADED',
               loc.RESULTS_UPDATED_DATE = SYSDATE,
               loc.LAST_UPDATED_DATE = SYSDATE
        WHERE  loc.RUN_ID    = p_run_id
        AND    loc.TFM_STATUS           != 'LOADED'
        AND    loc.TFM_STATUS            = 'GENERATED';

        -- Party Sites: match on PARTY_ORIG_SYSTEM_REFERENCE
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
        SET    ps.TFM_STATUS            = 'LOADED',
               ps.RESULTS_UPDATED_DATE = SYSDATE,
               ps.LAST_UPDATED_DATE = SYSDATE
        WHERE  ps.RUN_ID    = p_run_id
        AND    ps.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
            WHERE  p.RUN_ID              = p_run_id
            AND    p.PARTY_ORIG_SYSTEM_REFERENCE = ps.PARTY_ORIG_SYSTEM_REFERENCE
            AND    p.TFM_STATUS                      = 'LOADED');

        -- Party Site Uses: match via party site's SITE_ORIG_SYSTEM_REFERENCE
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL psu
        SET    psu.TFM_STATUS            = 'LOADED',
               psu.RESULTS_UPDATED_DATE = SYSDATE,
               psu.LAST_UPDATED_DATE = SYSDATE
        WHERE  psu.RUN_ID    = p_run_id
        AND    psu.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
            WHERE  ps.RUN_ID           = p_run_id
            AND    ps.SITE_ORIG_SYSTEM_REFERENCE = psu.SITE_ORIG_SYSTEM_REFERENCE
            AND    ps.TFM_STATUS                    = 'LOADED');

        -- Accounts: match on PARTY_ORIG_SYSTEM_REFERENCE
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
        SET    a.TFM_STATUS            = 'LOADED',
               a.RESULTS_UPDATED_DATE = SYSDATE,
               a.LAST_UPDATED_DATE = SYSDATE
        WHERE  a.RUN_ID    = p_run_id
        AND    a.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
            WHERE  p.RUN_ID              = p_run_id
            AND    p.PARTY_ORIG_SYSTEM_REFERENCE = a.PARTY_ORIG_SYSTEM_REFERENCE
            AND    p.TFM_STATUS                      = 'LOADED');

        -- Account Sites: match via account's CUST_ORIG_SYSTEM_REFERENCE
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
        SET    acs.TFM_STATUS            = 'LOADED',
               acs.RESULTS_UPDATED_DATE = SYSDATE,
               acs.LAST_UPDATED_DATE = SYSDATE
        WHERE  acs.RUN_ID    = p_run_id
        AND    acs.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
            WHERE  a.RUN_ID              = p_run_id
            AND    a.CUST_ORIG_SYSTEM_REFERENCE = acs.CUST_ORIG_SYSTEM_REFERENCE
            AND    a.TFM_STATUS                      = 'LOADED');

        -- Account Site Uses: match via account site's CUST_SITE_ORIG_SYS_REF
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL asu
        SET    asu.TFM_STATUS            = 'LOADED',
               asu.RESULTS_UPDATED_DATE = SYSDATE,
               asu.LAST_UPDATED_DATE = SYSDATE
        WHERE  asu.RUN_ID    = p_run_id
        AND    asu.TFM_STATUS           != 'LOADED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
            WHERE  acs.RUN_ID          = p_run_id
            AND    acs.CUST_SITE_ORIG_SYS_REF = asu.CUST_SITE_ORIG_SYS_REF
            AND    acs.TFM_STATUS                  = 'LOADED');

        -- ============================================================
        -- Cascade FAILED to child TFM tables
        -- ============================================================

        -- Party Sites: parent party FAILED
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
        SET    ps.TFM_STATUS            = 'FAILED',
               ps.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(ps.ERROR_TEXT,
                   '[FUSION_ERROR] Parent party ''' || ps.PARTY_ORIG_SYSTEM_REFERENCE || ''' was rejected by Fusion.'),
               ps.RESULTS_UPDATED_DATE = SYSDATE,
               ps.LAST_UPDATED_DATE = SYSDATE
        WHERE  ps.RUN_ID    = p_run_id
        AND    ps.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
            WHERE  p.RUN_ID              = p_run_id
            AND    p.PARTY_ORIG_SYSTEM_REFERENCE = ps.PARTY_ORIG_SYSTEM_REFERENCE
            AND    p.TFM_STATUS                      = 'FAILED');

        -- Party Site Uses: parent party site FAILED
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL psu
        SET    psu.TFM_STATUS            = 'FAILED',
               psu.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(psu.ERROR_TEXT,
                   '[FUSION_ERROR] Parent party site was rejected by Fusion.'),
               psu.RESULTS_UPDATED_DATE = SYSDATE,
               psu.LAST_UPDATED_DATE = SYSDATE
        WHERE  psu.RUN_ID    = p_run_id
        AND    psu.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
            WHERE  ps.RUN_ID           = p_run_id
            AND    ps.SITE_ORIG_SYSTEM_REFERENCE = psu.SITE_ORIG_SYSTEM_REFERENCE
            AND    ps.TFM_STATUS                    = 'FAILED');

        -- Accounts: parent party FAILED
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
        SET    a.TFM_STATUS            = 'FAILED',
               a.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(a.ERROR_TEXT,
                   '[FUSION_ERROR] Parent party ''' || a.PARTY_ORIG_SYSTEM_REFERENCE || ''' was rejected by Fusion.'),
               a.RESULTS_UPDATED_DATE = SYSDATE,
               a.LAST_UPDATED_DATE = SYSDATE
        WHERE  a.RUN_ID    = p_run_id
        AND    a.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL p
            WHERE  p.RUN_ID              = p_run_id
            AND    p.PARTY_ORIG_SYSTEM_REFERENCE = a.PARTY_ORIG_SYSTEM_REFERENCE
            AND    p.TFM_STATUS                      = 'FAILED');

        -- Account Sites: parent account FAILED
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
        SET    acs.TFM_STATUS            = 'FAILED',
               acs.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(acs.ERROR_TEXT,
                   '[FUSION_ERROR] Parent account was rejected by Fusion.'),
               acs.RESULTS_UPDATED_DATE = SYSDATE,
               acs.LAST_UPDATED_DATE = SYSDATE
        WHERE  acs.RUN_ID    = p_run_id
        AND    acs.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL a
            WHERE  a.RUN_ID              = p_run_id
            AND    a.CUST_ORIG_SYSTEM_REFERENCE = acs.CUST_ORIG_SYSTEM_REFERENCE
            AND    a.TFM_STATUS                      = 'FAILED');

        -- Account Site Uses: parent account site FAILED
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL asu
        SET    asu.TFM_STATUS            = 'FAILED',
               asu.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(asu.ERROR_TEXT,
                   '[FUSION_ERROR] Parent account site was rejected by Fusion.'),
               asu.RESULTS_UPDATED_DATE = SYSDATE,
               asu.LAST_UPDATED_DATE = SYSDATE
        WHERE  asu.RUN_ID    = p_run_id
        AND    asu.TFM_STATUS           != 'FAILED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL acs
            WHERE  acs.RUN_ID          = p_run_id
            AND    acs.CUST_SITE_ORIG_SYS_REF = asu.CUST_SITE_ORIG_SYS_REF
            AND    acs.TFM_STATUS                  = 'FAILED');

        -- Locations with failed parties: mark FAILED
        -- (locations linked through party_sites — if all party_sites for a location are FAILED,
        -- the location is effectively FAILED too)
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL loc
        SET    loc.TFM_STATUS            = 'FAILED',
               loc.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(loc.ERROR_TEXT,
                   '[FUSION_ERROR] Associated party site was rejected by Fusion.'),
               loc.RESULTS_UPDATED_DATE = SYSDATE,
               loc.LAST_UPDATED_DATE = SYSDATE
        WHERE  loc.RUN_ID    = p_run_id
        AND    loc.TFM_STATUS           NOT IN ('LOADED', 'FAILED')
        AND    NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL ps
            WHERE  ps.RUN_ID              = p_run_id
            AND    ps.LOCATION_ORIG_SYSTEM_REFERENCE = loc.LOCATION_ORIG_SYSTEM_REFERENCE
            AND    ps.TFM_STATUS                      = 'LOADED');

        -- ============================================================
        -- Sweep: mark remaining GENERATED rows as FAILED
        -- These are rows that were sent to Fusion but could not be
        -- matched by the BIP reconciliation query or cascade logic
        -- (e.g. referencing a party that was never in this batch).
        -- ============================================================
        DECLARE
            l_sweep NUMBER := 0;
            l_tbl_sweep NUMBER;
        BEGIN
            FOR t IN (
                SELECT 'DMT_HZ_PARTY_SITES_TFM_TBL' AS tbl FROM DUAL UNION ALL
                SELECT 'DMT_HZ_PARTY_SITE_USES_TFM_TBL' FROM DUAL UNION ALL
                SELECT 'DMT_HZ_ACCOUNTS_TFM_TBL' FROM DUAL UNION ALL
                SELECT 'DMT_HZ_ACCT_SITES_TFM_TBL' FROM DUAL UNION ALL
                SELECT 'DMT_HZ_ACCT_SITE_USES_TFM_TBL' FROM DUAL UNION ALL
                SELECT 'DMT_HZ_LOCATIONS_TFM_TBL' FROM DUAL
            ) LOOP
                EXECUTE IMMEDIATE
                    'UPDATE DMT_OWNER.' || t.tbl ||
                    ' SET TFM_STATUS = ''FAILED'',' ||
                    '     ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,' ||
                    '         ''[RECONCILE_ERROR] Row not matched by BIP reconciliation or cascade. Cannot verify import outcome.''),' ||
                    '     RESULTS_UPDATED_DATE = SYSDATE,' ||
                    '     LAST_UPDATED_DATE = SYSDATE' ||
                    ' WHERE RUN_ID = :iid AND TFM_STATUS = ''GENERATED'''
                    USING p_run_id;
                l_tbl_sweep := SQL%ROWCOUNT;
                l_sweep := l_sweep + l_tbl_sweep;
            END LOOP;
            IF l_sweep > 0 THEN
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => C_PROC || ' sweep: ' || l_sweep ||
                                        ' GENERATED rows marked FAILED (not reconciled).',
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);
            END IF;
        END;

        -- ============================================================
        -- Echo outcomes back to all 7 STG tables
        -- ============================================================

        -- Parties
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_HZ_PARTIES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Locations
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_HZ_LOCATIONS_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_LOCATIONS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Party Sites
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_PARTY_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Party Site Uses
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_HZ_PARTY_SITE_USES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_PARTY_SITE_USES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Accounts
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Account Sites
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_ACCT_SITES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- Account Site Uses
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_HZ_ACCT_SITE_USES_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_HZ_ACCT_SITE_USES_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Parties LOADED: ' || l_loaded ||
                                ', FAILED: ' || l_failed || '.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END PARSE_AND_UPDATE;

    -- --------------------------------------------------------
    -- RECONCILE_BATCH
    -- --------------------------------------------------------
    PROCEDURE RECONCILE_BATCH (
        p_run_id  IN NUMBER,
        p_load_ess_id     IN NUMBER,
        p_import_ess_id   IN NUMBER DEFAULT NULL
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_xml CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml);

        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml);
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => C_PROC || ' failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_CUST_RESULTS_PKG;
/
