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
    -- GET_PARTITION_KEYS — distinct BOOK_TYPE_CODE tokens for one run,
    -- STATIC SQL over the asset-book transform table (this object's own
    -- table). Spawn-per-partition (work-queue-ID core, 2026-07-20): one child
    -- work item per book. Called through invoke_registered (style KEYS).
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL IS
        l_keys DMT_PARTITION_KEY_TBL;
    BEGIN
        -- One JSON object per distinct book, keyed by the partition column name.
        SELECT DISTINCT JSON_OBJECT('BOOK_TYPE_CODE' VALUE TO_CHAR(BOOK_TYPE_CODE))
        BULK COLLECT INTO l_keys
        FROM   DMT_FA_ASSET_BOOK_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'STAGED'
        AND    BOOK_TYPE_CODE IS NOT NULL;
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
            FROM   DMT_BIP_REPORT_TBL
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
            FROM   DMT_PIPELINE_RUN_TBL
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
            -- We could determine neither a base-table LOADED nor a real Fusion
            -- per-record error, so we do NOT fabricate a FAILED. The GENERATED
            -- rows are left as-is (unaccounted); the accounting gate reports the
            -- object not-DONE and the funnel surfaces them as unreconciled.
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. ' ||
                                    'GENERATED rows left unaccounted (not marked FAILED).',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
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
                UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                SET    TFM_STATUS               = 'LOADED',
                       FUSION_ASSET_ID      = r.fusion_id,
                       RESULTS_UPDATED_DATE = SYSDATE,
                       LAST_UPDATED_DATE    = SYSDATE
                WHERE  RUN_ID       = p_run_id
                AND    ASSET_NUMBER         = r.asset_number
                AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                l_loaded := l_loaded + SQL%ROWCOUNT;

            ELSIF r.source_type = 'INTERFACE' THEN
                -- Tier 1: Still in FA_MASS_ADDITIONS — check posting_status
                IF r.import_status IN ('POSTED','POST','Y','PROCESSED','SUCCESS','COMPLETED') THEN
                    UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                    SET    TFM_STATUS               = 'LOADED',
                           FUSION_ASSET_ID      = r.fusion_id,
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    ASSET_NUMBER         = r.asset_number
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_loaded := l_loaded + SQL%ROWCOUNT;
                ELSIF r.error_msg IS NOT NULL THEN
                    -- Not posted, WITH a real Fusion-returned rejection message = FAILED.
                    UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                    SET    TFM_STATUS               = 'FAILED',
                           ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || r.error_msg),
                           RESULTS_UPDATED_DATE = SYSDATE,
                           LAST_UPDATED_DATE    = SYSDATE
                    WHERE  RUN_ID       = p_run_id
                    AND    ASSET_NUMBER         = r.asset_number
                    AND    TFM_STATUS              NOT IN ('LOADED','FAILED');
                    l_failed := l_failed + SQL%ROWCOUNT;
                ELSE
                    -- Not posted but no Fusion error message returned.
                    -- No real Fusion error available; leave GENERATED for the honest sweep to mark UNACCOUNTED.
                    NULL;
                END IF;
            END IF;
        END LOOP;

        -- NO header absence pass. A header neither confirmed in a base table
        -- (marked LOADED above) nor carrying a real per-record Fusion error
        -- (marked FAILED above from the BIP report) is LEFT GENERATED
        -- (unaccounted). We do not fabricate a FAILED for "not found in base":
        -- that asserts a failure we did not observe. The accounting gate then
        -- reports the object not-DONE and the funnel surfaces it as UNRECONCILED.
        -- The child cascade below keys off the header's terminal status
        -- (LOADED or a REAL FAILED); a GENERATED header leaves its children
        -- GENERATED too, which is correct — they are unaccounted, not failed.
        l_not_recon := 0;

        <<cascade_and_echo>>
        -- Cascade to book TFM — match header tfm_status
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS            = 'LOADED',
               bk.LAST_UPDATED_DATE = SYSDATE
        WHERE  bk.RUN_ID    = p_run_id
        AND    bk.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = bk.RUN_ID
            AND    hdr.ASSET_NUMBER    = bk.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'LOADED');

        -- The parent header only reaches FAILED with a real Fusion error, so the
        -- book row carries that same real parent error in the linked-record form.
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS            = 'FAILED',
               bk.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(bk.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT hdr.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
                    WHERE  hdr.RUN_ID = bk.RUN_ID
                    AND    hdr.ASSET_NUMBER = bk.ASSET_NUMBER
                    AND    hdr.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               bk.LAST_UPDATED_DATE = SYSDATE
        WHERE  bk.RUN_ID    = p_run_id
        AND    bk.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = bk.RUN_ID
            AND    hdr.ASSET_NUMBER    = bk.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'FAILED');

        -- Cascade to assignment TFM — match header tfm_status
        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS            = 'LOADED',
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID    = p_run_id
        AND    asn.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = asn.RUN_ID
            AND    hdr.ASSET_NUMBER    = asn.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'LOADED');

        -- The parent header only reaches FAILED with a real Fusion error, so the
        -- assignment row carries that same real parent error in the linked-record form.
        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS            = 'FAILED',
               asn.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(asn.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT hdr.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
                    WHERE  hdr.RUN_ID = asn.RUN_ID
                    AND    hdr.ASSET_NUMBER = asn.ASSET_NUMBER
                    AND    hdr.TFM_STATUS = 'FAILED'
                    AND    ROWNUM = 1)),
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID    = p_run_id
        AND    asn.TFM_STATUS            = 'GENERATED'
        AND    EXISTS (
            SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL hdr
            WHERE  hdr.RUN_ID  = asn.RUN_ID
            AND    hdr.ASSET_NUMBER    = asn.ASSET_NUMBER
            AND    hdr.TFM_STATUS          = 'FAILED');

        -- Echo outcomes back to STG
        UPDATE DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_FA_ASSET_HDR_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');
        UPDATE DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_FA_ASSET_HDR_TFM_TBL t
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
    -- ACCOUNT_ALL_OR_NOTHING — Assets-ONLY exception (DMT_DESIGN section 5,
    -- "Fixed Assets all-or-nothing accounting").
    --
    -- Fixed Assets loads and posts a whole BOOK batch atomically: if any asset
    -- in a book is rejected, NONE of that book's assets commit. When that
    -- happens the two-tier BIP reconcile above confirms nothing and would leave
    -- every asset in the book UNACCOUNTED. This routine gives those a real
    -- verdict: the genuinely-rejected assets carry their actual Fusion error,
    -- and the remaining assets in the SAME book carry a generic "batch rejected"
    -- FAILED. It is scoped to ONE book partition (p_work_queue_id) and fires
    -- ONLY when no asset in that book loaded (a true all-or-nothing failure).
    --
    -- THIS PATTERN IS FORBIDDEN FOR EVERY OTHER OBJECT. All other objects
    -- account per-row and MUST leave genuinely-unknown rows UNACCOUNTED rather
    -- than blanket-failing a batch. Assets is the sole exception because its
    -- Fusion load/post is atomic per book.
    --
    -- Two error sources, matching the two failure stages:
    --   (a) LOAD stage: SQL*Loader rejected rows, so nothing reached
    --       FA_MASS_ADDITIONS and the BIP report was empty. The real per-record
    --       errors live in the load job's SQL*Loader log; we parse each
    --       "Record N: Rejected ... ORA-#### ..." and map record N to the Nth
    --       CSV row using the generator's exact join + ORDER BY b.TFM_SEQUENCE_ID.
    --   (b) POST stage: rows loaded to the interface but Post Mass Additions
    --       rejected the batch; the real error came back in the BIP report and
    --       PARSE_AND_UPDATE already marked the bad asset(s) FAILED. Here we add
    --       only the generic verdict to the good assets left unposted.
    -- --------------------------------------------------------
    PROCEDURE ACCOUNT_ALL_OR_NOTHING (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_work_queue_id IN NUMBER
    ) IS
        C_PROC     CONSTANT VARCHAR2(30) := 'ACCOUNT_ALL_OR_NOTHING';
        C_GENERIC  CONSTANT VARCHAR2(400) :=
            '[BATCH_REJECTED] Not loaded: another asset in this book batch was '
            || 'rejected by Fusion. The Fixed Assets interface load/post is '
            || 'all-or-nothing per book, so no assets in this book were committed.';
        l_book       VARCHAR2(240);
        l_remaining  NUMBER := 0;
        l_loaded     NUMBER := 0;
        l_failed_bip NUMBER := 0;
        l_proc_failed NUMBER := 0;
        l_log        CLOB;
        l_one        CLOB;
        l_start      PLS_INTEGER;
        l_next       PLS_INTEGER;
        l_recno      NUMBER;
        l_chunk      VARCHAR2(4000);
        l_err        VARCHAR2(2000);
        l_asset      VARCHAR2(100);
        l_marked     NUMBER := 0;
    BEGIN
        -- Book partition for this work item (NULL if somehow unpartitioned).
        IF p_work_queue_id IS NOT NULL THEN
            BEGIN
                SELECT PARTITION_LABEL INTO l_book
                FROM   DMT_WORK_QUEUE_TBL WHERE QUEUE_ID = p_work_queue_id;
            EXCEPTION WHEN NO_DATA_FOUND THEN l_book := NULL;
            END;
        END IF;

        -- Assets in this book still without a verdict.
        SELECT COUNT(*) INTO l_remaining
        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));
        IF l_remaining = 0 THEN
            RETURN;   -- every asset in this book already accounted; nothing to do
        END IF;

        -- How many assets in this book actually LOADED?
        SELECT COUNT(*) INTO l_loaded
        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS = 'LOADED'
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));

        -- If ANY asset in the book loaded, this was NOT an all-or-nothing batch
        -- failure. Do not fabricate failures for the rest -- leave them
        -- UNACCOUNTED for honest reporting. (Assets is atomic per book, so this
        -- branch is a safety net, not the expected path.)
        IF l_loaded > 0 THEN
            RETURN;
        END IF;

        -- Assets in this book already marked FAILED from the BIP report (post-stage).
        SELECT COUNT(*) INTO l_failed_bip
        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS = 'FAILED'
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));

        -- Poll the FAILED process before deciding this is an all-or-nothing
        -- failure. Nothing loaded can mean either (i) the load/post genuinely
        -- failed -- an atomic-batch rejection we must account -- or (ii) the load
        -- succeeded and the base rows simply have not appeared yet (lag). We only
        -- apply a verdict when there is real evidence of failure: the captured
        -- load controller reached a failed/warning state, one of its SQL*Loader
        -- children rejected rows, or the BIP report already returned a real error.
        -- Otherwise we leave the rows UNACCOUNTED (never fabricate a failure).
        SELECT COUNT(*) INTO l_proc_failed
        FROM   DMT_ESS_JOB_TBL
        WHERE  RUN_ID = p_run_id
        AND    (REQUEST_ID = p_load_ess_id OR PARENT_REQUEST_ID = p_load_ess_id)
        AND    (UPPER(STATE_TEXT) IN ('ERROR','FAILED','WARNING')
                OR STATE IN (10, 11));   -- 10=ERROR, 11=WARNING (SQL*Loader reject)

        IF l_proc_failed = 0 AND l_failed_bip = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message => C_PROC || ' book=' || NVL(l_book,'(all)') ||
                    ': nothing loaded but the load process shows no failure and BIP '
                    || 'returned no error -- leaving rows UNACCOUNTED (possible lag, '
                    || 'not fabricating a verdict).',
                p_log_type => DMT_UTIL_PKG.C_LOG_WARN,
                p_package => C_PKG, p_procedure => C_PROC);
            RETURN;
        END IF;

        -- (a) LOAD-STAGE: nothing accounted at all -> the load failed before the
        -- interface. Pull the real per-record errors from the SQL*Loader log(s).
        IF l_failed_bip = 0 THEN
            DBMS_LOB.CREATETEMPORARY(l_log, TRUE);
            FOR c IN (
                SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL
                WHERE  RUN_ID = p_run_id
                AND    PARENT_REQUEST_ID = p_load_ess_id
                AND    UPPER(JOB_SHORT_NAME) LIKE '%SQLLDR%'
                ORDER BY REQUEST_ID
            ) LOOP
                BEGIN
                    l_one := DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_TEXT(c.REQUEST_ID);
                    IF l_one IS NOT NULL THEN
                        DBMS_LOB.APPEND(l_log, l_one);
                    END IF;
                EXCEPTION WHEN OTHERS THEN NULL;  -- a missing child log is not fatal
                END;
            END LOOP;

            -- Walk each "Record N: Rejected ..." and attribute its ORA error to
            -- the Nth CSV row (generator order: HDR x BOOK join, ORDER BY book seq).
            l_start := 1;
            LOOP
                l_start := REGEXP_INSTR(l_log, 'Record [0-9]+: Rejected', l_start);
                EXIT WHEN l_start = 0;
                l_recno := TO_NUMBER(REGEXP_SUBSTR(l_log, 'Record ([0-9]+):', l_start, 1, NULL, 1));
                l_next  := REGEXP_INSTR(l_log, 'Record [0-9]+:', l_start + 1);
                IF l_next = 0 THEN l_next := DBMS_LOB.GETLENGTH(l_log) + 1; END IF;
                l_chunk := DBMS_LOB.SUBSTR(l_log, LEAST(l_next - l_start, 3999), l_start);
                -- real Fusion error = the "Error on table..." line + first ORA- line
                l_err := TRIM(REGEXP_REPLACE(
                            REGEXP_SUBSTR(l_chunk, 'Error on table[^'||CHR(10)||']*') || ' ' ||
                            REGEXP_SUBSTR(l_chunk, 'ORA-[0-9]+[^'||CHR(10)||']*'),
                            '[[:space:]]+', ' '));

                -- the asset at CSV position l_recno for this book
                BEGIN
                    SELECT ASSET_NUMBER INTO l_asset FROM (
                        SELECT h.ASSET_NUMBER,
                               ROW_NUMBER() OVER (ORDER BY b.TFM_SEQUENCE_ID) rn
                        FROM   DMT_FA_ASSET_HDR_TFM_TBL h
                        JOIN   DMT_FA_ASSET_BOOK_TFM_TBL b
                          ON   b.ASSET_NUMBER = h.ASSET_NUMBER AND b.RUN_ID = h.RUN_ID
                        WHERE  h.RUN_ID = p_run_id
                        AND    (l_book IS NULL OR b.BOOK_TYPE_CODE = l_book))
                    WHERE rn = l_recno;
                EXCEPTION WHEN NO_DATA_FOUND THEN l_asset := NULL;
                END;

                IF l_asset IS NOT NULL AND l_err IS NOT NULL THEN
                    UPDATE DMT_FA_ASSET_HDR_TFM_TBL
                    SET    TFM_STATUS = 'FAILED',
                           ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT, '[FUSION_ERROR] ' || l_err),
                           RESULTS_UPDATED_DATE = SYSDATE, LAST_UPDATED_DATE = SYSDATE
                    WHERE  RUN_ID = p_run_id AND ASSET_NUMBER = l_asset
                    AND    TFM_STATUS NOT IN ('LOADED','FAILED');
                END IF;
                l_start := l_next;
            END LOOP;

            IF DBMS_LOB.ISTEMPORARY(l_log) = 1 THEN DBMS_LOB.FREETEMPORARY(l_log); END IF;
        END IF;

        -- (b) both stages: every remaining un-accounted asset in this book was
        -- not individually rejected but still did not load, because the batch is
        -- all-or-nothing. Mark it FAILED with the generic batch message.
        UPDATE DMT_FA_ASSET_HDR_TFM_TBL h
        SET    h.TFM_STATUS = 'FAILED',
               h.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(h.ERROR_TEXT, C_GENERIC),
               h.RESULTS_UPDATED_DATE = SYSDATE, h.LAST_UPDATED_DATE = SYSDATE
        WHERE  h.RUN_ID = p_run_id
        AND    h.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    (l_book IS NULL OR EXISTS (
                   SELECT 1 FROM DMT_FA_ASSET_BOOK_TFM_TBL b
                   WHERE b.RUN_ID = h.RUN_ID AND b.ASSET_NUMBER = h.ASSET_NUMBER
                   AND   b.BOOK_TYPE_CODE = l_book));
        l_marked := SQL%ROWCOUNT;

        -- Cascade the new header FAILEDs to book + assignment + STG echo, using
        -- the same linked-record wording as PARSE_AND_UPDATE.
        UPDATE DMT_FA_ASSET_BOOK_TFM_TBL bk
        SET    bk.TFM_STATUS = 'FAILED',
               bk.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(bk.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT h.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL h
                    WHERE h.RUN_ID = bk.RUN_ID AND h.ASSET_NUMBER = bk.ASSET_NUMBER
                    AND h.TFM_STATUS = 'FAILED' AND ROWNUM = 1)),
               bk.LAST_UPDATED_DATE = SYSDATE
        WHERE  bk.RUN_ID = p_run_id AND bk.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    EXISTS (SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL h
                       WHERE h.RUN_ID = bk.RUN_ID AND h.ASSET_NUMBER = bk.ASSET_NUMBER
                       AND h.TFM_STATUS = 'FAILED');

        UPDATE DMT_FA_ASSET_ASSIGN_TFM_TBL asn
        SET    asn.TFM_STATUS = 'FAILED',
               asn.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(asn.ERROR_TEXT,
                   '[FUSION_ERROR]The parent record has the following Fusion error: ' ||
                   (SELECT h.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL h
                    WHERE h.RUN_ID = asn.RUN_ID AND h.ASSET_NUMBER = asn.ASSET_NUMBER
                    AND h.TFM_STATUS = 'FAILED' AND ROWNUM = 1)),
               asn.LAST_UPDATED_DATE = SYSDATE
        WHERE  asn.RUN_ID = p_run_id AND asn.TFM_STATUS NOT IN ('LOADED','FAILED')
        AND    EXISTS (SELECT 1 FROM DMT_FA_ASSET_HDR_TFM_TBL h
                       WHERE h.RUN_ID = asn.RUN_ID AND h.ASSET_NUMBER = asn.ASSET_NUMBER
                       AND h.TFM_STATUS = 'FAILED');

        UPDATE DMT_FA_ASSET_HDR_STG_TBL stg
        SET    stg.STG_STATUS = 'FAILED',
               stg.ERROR_TEXT = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_FA_ASSET_HDR_TFM_TBL t
                    WHERE t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_STATUS NOT IN ('LOADED','FAILED')
        AND    stg.STG_SEQUENCE_ID IN (
                   SELECT t.STG_SEQUENCE_ID FROM DMT_FA_ASSET_HDR_TFM_TBL t
                   WHERE t.RUN_ID = p_run_id AND t.TFM_STATUS = 'FAILED');

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message => C_PROC || ' book=' || NVL(l_book,'(all)') ||
                         ' all-or-nothing: ' || l_remaining || ' unaccounted, ' ||
                         l_marked || ' marked generic FAILED.',
            p_package => C_PKG, p_procedure => C_PROC);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id, p_message => C_PROC || ' failed.',
                p_sqlerrm => SQLERRM, p_package => C_PKG, p_procedure => C_PROC);
            RAISE;
    END ACCOUNT_ALL_OR_NOTHING;

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
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id ||
                                ' | import_ess_id: ' || NVL(TO_CHAR(p_import_ess_id), 'NULL'),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        l_xml := FETCH_BIP_RESULTS(p_run_id, p_load_ess_id, p_import_ess_id);
        PARSE_AND_UPDATE(p_run_id, l_xml);

        IF l_xml IS NOT NULL AND DBMS_LOB.ISTEMPORARY(l_xml) = 1 THEN
            DBMS_LOB.FREETEMPORARY(l_xml);
        END IF;

        -- Assets-ONLY exception: Fixed Assets loads/posts a book atomically, so
        -- a single rejected asset leaves the whole book unposted and the BIP
        -- reconcile above confirms nothing. Give those rows a real verdict
        -- (real Fusion error on the rejected asset(s), generic on the rest)
        -- instead of leaving the book UNACCOUNTED. Fires only on a genuinely
        -- failed load process; a still-lagging load leaves rows UNACCOUNTED.
        -- See DMT_DESIGN section 5 (Fixed Assets all-or-nothing accounting).
        ACCOUNT_ALL_OR_NOTHING(p_run_id, p_load_ess_id, p_work_queue_id);

        -- Any records still unresolved are intentionally left GENERATED
        -- (unaccounted); the accounting gate reports the object not-DONE and the
        -- funnel surfaces these as UNRECONCILED.

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
