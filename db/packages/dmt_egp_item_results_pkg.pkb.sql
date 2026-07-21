-- PACKAGE BODY DMT_EGP_ITEM_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_RESULTS_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_RESULTS_PKG Body
-- Post-load BIP reconciliation for Items.
-- Pattern: identical to DMT_MISC_RECEIPT_RESULTS_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'Items';

    -- --------------------------------------------------------
    -- GET_PARTITION_KEYS — distinct spawn-per-partition tokens for one run,
    -- STATIC SQL over this object's OWN transform tables. Items is the one
    -- object that UNIONs two tables: the item transform table and the
    -- item-category transform table, so a batch present only in categories
    -- (no item rows) still yields a token and spawns a child work item.
    -- Tokens are BATCH_ID rendered with TO_CHAR; the engine treats each as
    -- opaque. Called through DMT_QUEUE_WORKER_PKG.invoke_registered (KEYS).
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_OWNER.DMT_PARTITION_KEY_TBL IS
        l_keys DMT_OWNER.DMT_PARTITION_KEY_TBL;
    BEGIN
        -- One JSON object per distinct batch, keyed by the partition column name
        -- (JSON_OBJECT escapes the value correctly). Composite keys would add more
        -- keys to the same object without changing the callers.
        SELECT JSON_OBJECT('BATCH_ID' VALUE TO_CHAR(BATCH_ID))
        BULK COLLECT INTO l_keys
        FROM (
            SELECT BATCH_ID
            FROM   DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            AND    BATCH_ID IS NOT NULL
            UNION
            SELECT BATCH_ID
            FROM   DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            AND    BATCH_ID IS NOT NULL
        );
        RETURN l_keys;
    END GET_PARTITION_KEYS;

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
    -- (b64_to_clob removed â€” base64 decode is now centralised in
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
            '              <v2:values><v2:item>' || TO_CHAR(p_run_id) || '</v2:item></v2:values>' ||
            '            </v2:item>' ||
            '            <v2:item>' ||
            '              <v2:name>P_LOAD_REQUEST_ID</v2:name>' ||
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
    -- TFM rows, then echoes back to STG table.
    --
    -- The report's STATUS element is derived from positive presence in the base
    -- table EGP_SYSTEM_ITEMS_B ('PROCESSED' = present, 'REJECTED' = absent), not
    -- from the interface PROCESS_FLAG. PROCESS_FLAG is still carried for display.
    -- Match key: ITEM_NUMBER + ORGANIZATION_CODE
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml_data       IN CLOB
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml    XMLTYPE;
        l_loaded NUMBER := 0;
        l_failed NUMBER := 0;
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

        -- Process item rows from BIP XML.
        -- STATUS comes from the report's base-table join (positive presence in
        -- EGP_SYSTEM_ITEMS_B): 'PROCESSED' = the item genuinely reached the base
        -- table, 'REJECTED' = it did not. We no longer infer loaded/failed from
        -- the interface PROCESS_FLAG -- Rule #1: base confirmation, not interface
        -- inference. (Validated live 2026-07-14: some PROCESS_FLAG=7 rows never
        -- reached the base table, and some PROCESS_FLAG=3 rows did.)
        FOR r IN (
            SELECT x.item_number,
                   x.organization_code,
                   x.inventory_item_id,
                   UPPER(x.status)        AS status,
                   x.error_message
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    item_number        VARCHAR2(300)  PATH 'ITEM_NUMBER',
                    organization_code  VARCHAR2(30)   PATH 'ORGANIZATION_CODE',
                    inventory_item_id  NUMBER         PATH 'INVENTORY_ITEM_ID',
                    status             VARCHAR2(15)   PATH 'STATUS',
                    error_message      VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.status = 'PROCESSED' THEN
                -- Success: item positively present in EGP_SYSTEM_ITEMS_B.
                UPDATE DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
                SET    TFM_STATUS              = 'LOADED',
                       FUSION_INVENTORY_ITEM_ID = r.inventory_item_id,
                       RESULTS_UPDATED_DATE    = SYSDATE,
                       LAST_UPDATED_DATE       = SYSDATE
                WHERE  RUN_ID      = p_run_id
                AND    ITEM_NUMBER         = r.item_number
                AND    ORGANIZATION_CODE   = r.organization_code
                AND    TFM_STATUS         != 'LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSE
                -- Rejected: no row in the base table for this item.
                UPDATE DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
                SET    TFM_STATUS              = 'FAILED',
                       ERROR_TEXT              = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || r.error_message),
                       RESULTS_UPDATED_DATE    = SYSDATE,
                       LAST_UPDATED_DATE       = SYSDATE
                WHERE  RUN_ID      = p_run_id
                AND    ITEM_NUMBER         = r.item_number
                AND    ORGANIZATION_CODE   = r.organization_code
                AND    TFM_STATUS         != 'FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- Echo outcomes back to STG table
        -- LOADED
        UPDATE DMT_OWNER.DMT_EGP_ITEM_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_EGP_ITEM_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        -- FAILED
        UPDATE DMT_OWNER.DMT_EGP_ITEM_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   -- An item can transform into several TFM rows for one staging row
                   -- (per-org / bundled category rows), so this correlated lookup must
                   -- return a single value or it raises ORA-01427. Take the first FAILED
                   -- TFM row's error deterministically (by TFM_SEQUENCE_ID).
                   (SELECT ie.ERROR_TEXT
                    FROM  (SELECT t.ERROR_TEXT,
                                  ROW_NUMBER() OVER (ORDER BY t.TFM_SEQUENCE_ID) rn
                           FROM   DMT_OWNER.DMT_EGP_ITEM_TFM_TBL t
                           WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                           AND    t.RUN_ID     = p_run_id
                           AND    t.TFM_STATUS = 'FAILED') ie
                    WHERE ie.rn = 1)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_OWNER.DMT_EGP_ITEM_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' complete. LOADED: ' || l_loaded ||
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
        p_import_ess_id   IN NUMBER DEFAULT NULL,
        p_work_queue_id IN NUMBER DEFAULT NULL
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

        -- Unresolved records intentionally left GENERATED (unaccounted).
        -- No fabricated FAILED: the accounting gate reports the object
        -- not-DONE and the funnel surfaces these as UNRECONCILED.

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

    -- --------------------------------------------------------
    -- LOAD_AND_RECONCILE (standalone runner path, retained for dev/test)
    -- --------------------------------------------------------
    PROCEDURE LOAD_AND_RECONCILE (
        p_run_id IN NUMBER,
        p_fbdi_zip       IN BLOB,
        p_filename       IN VARCHAR2
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'LOAD_AND_RECONCILE';

        l_ucm_account       VARCHAR2(200);
        l_job_name          VARCHAR2(500);
        l_interface_details NUMBER;
        l_load_ess_id       VARCHAR2(30);
        l_import_ess_id     VARCHAR2(30);
        l_fusion_status     VARCHAR2(30);
        l_import_status     VARCHAR2(30);
        l_count             NUMBER;
        l_errmsg            VARCHAR2(4000);
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id,
            'LOAD_AND_RECONCILE start. filename=' || p_filename
            || ', zip_size=' || DBMS_LOB.GETLENGTH(p_fbdi_zip) || ' bytes.',
            C_PKG, C_PROC);

        BEGIN
            SELECT UCM_ACCOUNT,
                   REPLACE(IMPORT_JOB_NAME, ';', ','),
                   TO_NUMBER(NVL(SOURCE_ERP_OPTIONS_ID, ERP_INTERFACE_OPTIONS_ID))
            INTO   l_ucm_account, l_job_name, l_interface_details
            FROM   DMT_ERP_INTERFACE_OPTIONS_TBL
            WHERE  CEMLI_CODE = 'Items';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_errmsg := 'No ERP interface options row found for CEMLI_CODE=Items. '
                         || 'Insert a row into DMT_ERP_INTERFACE_OPTIONS_TBL with the correct '
                         || 'UCM_ACCOUNT, IMPORT_JOB_NAME, and ERP_INTERFACE_OPTIONS_ID.';
                DMT_UTIL_PKG.LOG_ERROR(p_run_id, l_errmsg, l_errmsg, C_PKG, C_PROC);

                -- No real Fusion error available; leave GENERATED for the honest sweep to mark UNACCOUNTED.
                COMMIT;
                RETURN;
        END;

        DMT_UTIL_PKG.LOG(p_run_id,
            'ERP options: UCM=' || l_ucm_account || ', job=' || l_job_name
            || ', interfaceDetails=' || l_interface_details,
            C_PKG, C_PROC);

        BEGIN
            l_load_ess_id := DMT_LOADER_PKG.SUBMIT_LOAD(
                p_run_id    => p_run_id,
                p_fbdi_zip          => p_fbdi_zip,
                p_filename          => p_filename,
                p_job_name          => l_job_name,
                p_interface_details => l_interface_details,
                p_doc_account       => l_ucm_account,
                p_parameter_list    => '#NULL',
                p_log_context       => 'Items'
            );
        EXCEPTION
            WHEN OTHERS THEN
                l_errmsg := SQLERRM;
                DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                    'SUBMIT_LOAD failed for Items.', l_errmsg, C_PKG, C_PROC);

                UPDATE DMT_EGP_ITEM_TFM_TBL
                SET    TFM_STATUS = 'FAILED',
                       ERROR_TEXT = '[FUSION_ERROR] SUBMIT_LOAD failed: ' || SUBSTR(l_errmsg, 1, 3000),
                       RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'GENERATED';

                UPDATE DMT_EGP_ITEM_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (
                    SELECT STG_SEQUENCE_ID FROM DMT_EGP_ITEM_TFM_TBL
                    WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'FAILED'
                );

                COMMIT;
                RETURN;
        END;

        DMT_UTIL_PKG.LOG(p_run_id,
            'Load ESS submitted: ' || l_load_ess_id, C_PKG, C_PROC);

        DMT_LOADER_PKG.POLL_ESS_JOB(
            p_run_id => p_run_id,
            p_ess_job_id     => l_load_ess_id,
            p_timeout_sec    => 1200,
            p_raise_on_error => FALSE,
            p_log_context    => 'Items > POLL_LOAD',
            p_cemli_code     => 'Items',
            x_fusion_status  => l_fusion_status
        );

        DMT_UTIL_PKG.LOG(p_run_id,
            'Load ESS ' || l_load_ess_id || ' status: ' || l_fusion_status, C_PKG, C_PROC);

        IF l_fusion_status IN ('SUCCEEDED', 'WARNING') THEN
            BEGIN
                l_import_ess_id := DMT_LOADER_PKG.GET_IMPORT_ESS_ID(
                    p_run_id, 'Items', l_load_ess_id
                );

                DMT_UTIL_PKG.LOG(p_run_id,
                    'Import ESS found: ' || l_import_ess_id || '. Polling...', C_PKG, C_PROC);

                DMT_LOADER_PKG.POLL_ESS_JOB(
                    p_run_id => p_run_id,
                    p_ess_job_id     => l_import_ess_id,
                    p_timeout_sec    => 1200,
                    p_raise_on_error => FALSE,
                    p_log_context    => 'Items > POLL_IMPORT',
                    p_cemli_code     => 'Items',
                    x_fusion_status  => l_import_status
                );

                DMT_UTIL_PKG.LOG(p_run_id,
                    'Import ESS ' || l_import_ess_id || ' status: ' || l_import_status, C_PKG, C_PROC);
            EXCEPTION
                WHEN OTHERS THEN
                    l_errmsg := SQLERRM;
                    DMT_UTIL_PKG.LOG(p_run_id,
                        'Could not locate Import ESS job: '
                        || l_errmsg || '. Using Load ESS status instead.',
                        C_PKG, C_PROC, 'WARN');
                    l_import_status := l_fusion_status;
            END;

            -- Use BIP reconciliation for row-level status
            RECONCILE_BATCH(p_run_id, TO_NUMBER(l_load_ess_id), TO_NUMBER(l_import_ess_id));

            DMT_UTIL_PKG.LOG(p_run_id,
                'Items load complete. ESS=' || NVL(l_import_status, l_fusion_status),
                C_PKG, C_PROC);
        ELSE
            -- No real Fusion error available; leave GENERATED for the honest sweep to mark UNACCOUNTED.
            DMT_UTIL_PKG.LOG(p_run_id,
                'Items load did not succeed. ESS=' || l_fusion_status
                || '. Rows left GENERATED for the honest sweep.',
                C_PKG, C_PROC, 'WARN');
        END IF;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            l_errmsg := SQLERRM;
            DMT_UTIL_PKG.LOG_ERROR(p_run_id,
                'LOAD_AND_RECONCILE failed.', l_errmsg, C_PKG, C_PROC);
            RAISE;
    END LOAD_AND_RECONCILE;

END DMT_EGP_ITEM_RESULTS_PKG;
/
