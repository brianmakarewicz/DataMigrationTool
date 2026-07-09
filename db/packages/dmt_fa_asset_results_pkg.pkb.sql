-- PACKAGE BODY DMT_FA_ASSET_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_FA_ASSET_RESULTS_PKG" AS
-- ============================================================
-- DMT_FA_ASSET_RESULTS_PKG body
-- Assets BIP reconciliation — Two-Tier pattern.
-- Tier 1: FA_MASS_ADDITIONS (interface table, POSTED rows removed by PostMassAdditions)
-- Tier 2: FA_ADDITIONS_B (base table, positive confirmation)
-- No absence=LOADED fallback. Every row gets positive verification
-- or is marked FAILED with a reconciliation error.
-- Cascades status to book and assignment TFM tables.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_FA_ASSET_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Assets';

    -- --------------------------------------------------------
    -- Private: POST a SOAP envelope; return full response CLOB.
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
    -- FETCH_BIP_RESULTS — passes P_BATCH_ID and P_IMPORT_ESS_ID
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
        l_import_str VARCHAR2(30) := NVL(TO_CHAR(p_import_ess_id), '');
        l_prefix     VARCHAR2(30);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. CEMLI: ' || C_CEMLI ||
                                ' | load_ess_id: ' || p_load_ess_id ||
                                ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
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

        -- Look up prefix for Tier 2 base table matching (PostMassAdditions purges interface rows)
        BEGIN
            SELECT PREFIX INTO l_prefix
            FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
            WHERE  RUN_ID = p_run_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_prefix := NULL;
                DMT_UTIL_PKG.LOG(
                    p_run_id => p_run_id,
                    p_message        => C_PROC || ': No CONVERSION_MASTER row for run_id ' ||
                                        p_run_id || '. Tier 2 (base table) reconciliation will be skipped.',
                    p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                    p_package        => C_PKG,
                    p_procedure      => C_PROC);
        END;

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
            '            <v2:item>' ||
            '              <v2:name>P_IMPORT_ESS_ID</v2:name>' ||
            '              <v2:values><v2:item>' || l_import_str || '</v2:item></v2:values>' ||
            '            </v2:item>' ||
            '            <v2:item>' ||
            '              <v2:name>P_PREFIX</v2:name>' ||
            '              <v2:values><v2:item>' || NVL(l_prefix, '') || '</v2:item></v2:values>' ||
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
    -- PARSE_AND_UPDATE — Two-tier reconciliation, no absence=LOADED
    -- INTERFACE POSTED -> LOADED, INTERFACE other -> FAILED
    -- BASE -> LOADED with asset_id
    -- Remaining GENERATED -> FAILED (not reconciled)
    -- Cascades to book and assignment TFM tables.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
        l_not_recon  NUMBER := 0;
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
            -- No reportBytes at all — BIP returned 0 rows from BOTH tiers.
            -- Mark all GENERATED rows as FAILED (not reconciled).
            UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL
            SET    TFM_STATUS               = 'FAILED',
                   ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                       '[RECONCILE_ERROR] BIP returned 0 rows from both interface and base tables. Cannot verify Fusion outcome.'),
                   RESULTS_UPDATED_DATE = SYSDATE,
                   LAST_UPDATED_DATE    = SYSDATE
            WHERE  RUN_ID       = p_run_id
            AND    TFM_STATUS               = 'GENERATED';
            l_not_recon := SQL%ROWCOUNT;
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. ' ||
                                    l_not_recon || ' GENERATED rows marked FAILED (not reconciled).',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            GOTO cascade_and_echo;
        END IF;

        -- Process rows from BIP XML — two-tier reconciliation
        FOR r IN (
            SELECT x.asset_number,
                   UPPER(x.source_type)    AS source_type,
                   UPPER(x.import_status)  AS import_status,
                   x.fusion_id,
                   x.error_msg
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    asset_number    VARCHAR2(100)  PATH 'ASSET_NUMBER',
                    import_status   VARCHAR2(50)   PATH 'IMPORT_STATUS',
                    source_type     VARCHAR2(20)   PATH 'SOURCE_TYPE',
                    fusion_id       NUMBER         PATH 'FUSION_ID',
                    error_msg       VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.source_type = 'BASE' THEN
                -- Tier 2: Found in FA_ADDITIONS_B = positively LOADED
                UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    ASSET_NUMBER         = r.asset_number
                AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                -- Tier 1: Still in FA_MASS_ADDITIONS — check posting_status
                IF r.import_status IN ('POSTED','POST','Y','PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    ASSET_NUMBER         = r.asset_number
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSE
                    UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || NVL(r.error_msg, 'Asset not posted. Posting status: ' || NVL(r.import_status, 'NULL'))),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    ASSET_NUMBER         = r.asset_number
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                END IF;
            END IF;
        END LOOP;

        -- Any GENERATED rows not matched by either tier = not reconciled
        UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL
        SET    TFM_STATUS               = 'FAILED',
               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                   '[RECONCILE_ERROR] Row not found in Fusion interface table or base application table. Cannot verify import outcome.'),
               RESULTS_UPDATED_DATE = SYSDATE,
               LAST_UPDATED_DATE    = SYSDATE
        WHERE  RUN_ID       = p_run_id
        AND    TFM_STATUS               = 'GENERATED';
        l_not_recon := SQL%ROWCOUNT;

        <<cascade_and_echo>>
        -- Cascade to book TFM — match header tfm_status
        UPDATE DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS            = 'LOADED',
               bk.LAST_UPDATED_DATE = SYSDATE
        WHERE  bk.RUN_ID    = p_run_id
        AND    bk.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = bk.RUN_ID
            AND    hdr.ASSET_NUMBER    = bk.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'LOADED');

        UPDATE DMT_OWNER.DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS            = 'FAILED',
               bk.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(bk.ERROR_TEXT,
                   '[FUSION_ERROR] Parent asset header failed or not reconciled.'),
               bk.LAST_UPDATED_DATE = SYSDATE
        WHERE  bk.RUN_ID    = p_run_id
        AND    bk.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = bk.RUN_ID
            AND    hdr.ASSET_NUMBER    = bk.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'FAILED');

        -- Cascade to assignment TFM — match header tfm_status
        UPDATE DMT_OWNER.DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS            = 'LOADED',
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID    = p_run_id
        AND    asn.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = asn.RUN_ID
            AND    hdr.ASSET_NUMBER    = asn.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'LOADED');

        UPDATE DMT_OWNER.DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS            = 'FAILED',
               asn.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(asn.ERROR_TEXT,
                   '[FUSION_ERROR] Parent asset header failed or not reconciled.'),
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID    = p_run_id
        AND    asn.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = asn.RUN_ID
            AND    hdr.ASSET_NUMBER    = asn.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'FAILED');

        -- Echo outcomes back to STG
        UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_OWNER.DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        -- NO COMMIT — orchestrator controls transaction boundaries

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. Assets LOADED: ' || l_loaded ||
                                ', FAILED: ' || l_failed ||
                                ', NOT_RECONCILED: ' || l_not_recon || '.',
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
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                                ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id, p_import_ess_id);
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

END DMT_FA_ASSET_RESULTS_PKG;
/
