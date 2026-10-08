-- PACKAGE BODY DMT_EGP_ITEM_CAT_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_CAT_RESULTS_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_RESULTS_PKG Body
-- Post-load BIP reconciliation for Item Categories.
-- Pattern: identical to DMT_EGP_ITEM_RESULTS_PKG.
-- ============================================================

    C_PKG   CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_CAT_RESULTS_PKG';
    C_CEMLI CONSTANT VARCHAR2(30) := 'ItemCategories';

    -- --------------------------------------------------------
    -- (bip_soap_post + FETCH_BIP_RESULTS removed — the BIP runReport transport
    --  is now the shared DMT_UTIL_PKG.RUN_BIP_REPORT, called from RECONCILE_BATCH.
    --  It builds the same v2 runReport envelope, posts it, checks the SOAP fault,
    --  extracts <reportBytes> and decodes any size, returning the parsed XMLTYPE.
    --  b64_to_clob was already centralised in DMT_UTIL_PKG.BASE64_DECODE_CLOB.)

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- Parses BIP XML response (base64 reportBytes), updates
    -- TFM rows, then echoes back to STG table.
    --
    -- The report's STATUS element is derived from positive presence in the base
    -- table EGP_ITEM_CATEGORIES ('PROCESSED' = present, 'REJECTED' = absent), not
    -- from the interface PROCESS_FLAG. PROCESS_FLAG is still carried for display.
    -- Match key: ITEM_NUMBER + ORGANIZATION_CODE + CATEGORY_SET_NAME
    --
    -- Standard LOADED-promotion shape, natural-key variant (design: "Standard
    -- LOADED-promotion shape", clause (1)/(5)). ItemCategories has NO registered
    -- Fusion surrogate id (DMT_BIP_REPORT_TBL.FUSION_ID_COLUMN is empty for it): a
    -- category assignment's identity is the natural key above, so promotion is keyed
    -- on it and NO FUSION_*_ID is captured (none exists; none is fabricated). The
    -- guard is the report's positive base-table presence (STATUS='PROCESSED'); a row
    -- the base-table join does not return as PROCESSED is never promoted to LOADED.
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml            IN XMLTYPE
    ) IS
        C_PROC       CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml        XMLTYPE := p_xml;
        l_loaded     NUMBER := 0;
        l_failed     NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- l_xml is the decoded BIP report XMLTYPE from RUN_BIP_REPORT (NULL on
        -- zero rows).
        IF l_xml IS NULL THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => C_PROC || ': No <reportBytes> in BIP response. No rows updated.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RETURN;
        END IF;

        -- Process category rows from BIP XML.
        -- STATUS comes from the report's base-table join (positive presence in
        -- EGP_ITEM_CATEGORIES on inventory_item_id + organization_id + category_id
        -- + category_set_id): 'PROCESSED' = the category assignment genuinely
        -- reached the base table, 'REJECTED' = it did not. We no longer infer
        -- loaded/failed from the interface PROCESS_FLAG -- Rule #1: base
        -- confirmation, not interface inference. (Validated live 2026-07-14: a
        -- PROCESS_FLAG=3 "validation error" row was found present in the base table.)
        FOR r IN (
            SELECT x.item_number,
                   x.organization_code,
                   x.category_set_name,
                   UPPER(x.status)        AS status,
                   x.error_message
            FROM   XMLTABLE('/DATA_DS/G_1' PASSING l_xml
                COLUMNS
                    item_number        VARCHAR2(300)  PATH 'ITEM_NUMBER',
                    organization_code  VARCHAR2(30)   PATH 'ORGANIZATION_CODE',
                    category_set_name  VARCHAR2(100)  PATH 'CATEGORY_SET_NAME',
                    status             VARCHAR2(15)   PATH 'STATUS',
                    error_message      VARCHAR2(4000) PATH 'ERROR_MESSAGE'
            ) x
        ) LOOP
            IF r.status = 'PROCESSED' THEN
                UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
                SET    TFM_STATUS              = 'LOADED',
                       RESULTS_UPDATED_DATE    = SYSDATE,
                       LAST_UPDATED_DATE       = SYSDATE
                WHERE  RUN_ID      = p_run_id
                AND    ITEM_NUMBER         = r.item_number
                AND    ORGANIZATION_CODE   = r.organization_code
                AND    CATEGORY_SET_NAME   = r.category_set_name
                AND    TFM_STATUS         != 'LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.error_message IS NOT NULL THEN
                -- FAILED only with a REAL Fusion error. A non-PROCESSED status
                -- simply means the category assignment is not in the base table;
                -- that base-absence is NOT a verdict. We mark FAILED only when the
                -- report carried a real per-row Fusion error message. When it did
                -- not, the row is left GENERATED for the honest unaccounted sweep
                -- (never a fabricated FAILED on base-absence alone).
                UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
                SET    TFM_STATUS              = 'FAILED',
                       ERROR_TEXT              = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || r.error_message),
                       RESULTS_UPDATED_DATE    = SYSDATE,
                       LAST_UPDATED_DATE       = SYSDATE
                WHERE  RUN_ID      = p_run_id
                AND    ITEM_NUMBER         = r.item_number
                AND    ORGANIZATION_CODE   = r.organization_code
                AND    CATEGORY_SET_NAME   = r.category_set_name
                AND    TFM_STATUS         != 'FAILED';
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- Echo outcomes back to STG table
        UPDATE DMT_EGP_ITEM_CAT_STG_TBL stg
        SET    stg.STG_STATUS            = 'LOADED',
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_EGP_ITEM_CAT_TFM_TBL t
            WHERE  t.RUN_ID = p_run_id AND t.TFM_STATUS = 'LOADED');

        UPDATE DMT_EGP_ITEM_CAT_STG_TBL stg
        SET    stg.STG_STATUS            = 'FAILED',
               stg.ERROR_TEXT        = DMT_UTIL_PKG.APPEND_ERROR(stg.ERROR_TEXT,
                   (SELECT t.ERROR_TEXT FROM DMT_EGP_ITEM_CAT_TFM_TBL t
                    WHERE  t.STG_SEQUENCE_ID = stg.STG_SEQUENCE_ID
                    AND    t.RUN_ID  = p_run_id)),
               stg.LAST_UPDATED_DATE = SYSDATE
        WHERE  stg.STG_SEQUENCE_ID IN (
            SELECT t.STG_SEQUENCE_ID FROM DMT_EGP_ITEM_CAT_TFM_TBL t
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
        l_xml      XMLTYPE;
        l_err_code NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Shared transport: parsed XMLTYPE (NULL on zero rows). On transport/SOAP
        -- failure it returns NULL with C_ERROR — raise so the failure is loud (as
        -- the old FETCH_BIP_RESULTS raised).
        DMT_UTIL_PKG.RUN_BIP_REPORT(
            p_run_id     => p_run_id,
            p_cemli_code => C_CEMLI,
            p_params     => 'P_BATCH_ID|' || TO_CHAR(p_run_id) ||
                            '~P_LOAD_REQUEST_ID|' || TO_CHAR(p_load_ess_id),
            x_report_xml => l_xml,
            x_error_code => l_err_code);
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20034,
                C_PROC || ': BIP runReport fetch failed for ' || C_CEMLI ||
                ' (detail in DMT_LOG_TBL).');
        END IF;

        PARSE_AND_UPDATE(p_run_id, l_xml);

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

END DMT_EGP_ITEM_CAT_RESULTS_PKG;
/
