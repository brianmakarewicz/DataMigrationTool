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
    ) RETURN DMT_PARTITION_KEY_TBL IS
        l_keys DMT_PARTITION_KEY_TBL;
    BEGIN
        -- One JSON object per distinct batch, keyed by the partition column name
        -- (JSON_OBJECT escapes the value correctly). Composite keys would add more
        -- keys to the same object without changing the callers.
        SELECT JSON_OBJECT('BATCH_ID' VALUE TO_CHAR(BATCH_ID))
        BULK COLLECT INTO l_keys
        FROM (
            SELECT BATCH_ID
            FROM   DMT_EGP_ITEM_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            AND    BATCH_ID IS NOT NULL
            UNION
            SELECT BATCH_ID
            FROM   DMT_EGP_ITEM_CAT_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
            AND    BATCH_ID IS NOT NULL
        );
        RETURN l_keys;
    END GET_PARTITION_KEYS;

    -- --------------------------------------------------------
    -- (bip_soap_post + FETCH_BIP_RESULTS removed — the BIP runReport transport
    --  is now the shared DMT_UTIL_PKG.RUN_BIP_REPORT, called from RECONCILE_BATCH
    --  / LOAD_AND_RECONCILE. It builds the same v2 runReport envelope, posts it,
    --  checks the SOAP fault, extracts <reportBytes> and decodes any size,
    --  returning the parsed XMLTYPE. b64_to_clob was already centralised in
    --  DMT_UTIL_PKG.BASE64_DECODE_CLOB.)

    -- --------------------------------------------------------
    -- PARSE_AND_UPDATE
    -- Receives the already-decoded BIP report XMLTYPE (NULL on zero rows) from
    -- the shared transport DMT_UTIL_PKG.RUN_BIP_REPORT and updates TFM rows
    -- (nothing is copied back to STG, backlog #310).
    --
    -- The report's STATUS element is derived from positive presence in the base
    -- table EGP_SYSTEM_ITEMS_B ('PROCESSED' = present, 'REJECTED' = absent), not
    -- from the interface PROCESS_FLAG. PROCESS_FLAG is still carried for display.
    -- Match key: ITEM_NUMBER + ORGANIZATION_CODE
    -- --------------------------------------------------------
    PROCEDURE PARSE_AND_UPDATE (
        p_run_id IN NUMBER,
        p_xml            IN XMLTYPE
    ) IS
        C_PROC   CONSTANT VARCHAR2(30) := 'PARSE_AND_UPDATE';
        l_xml    XMLTYPE := p_xml;
        l_loaded NUMBER := 0;
        l_failed NUMBER := 0;
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
                -- LEGACY PATH: the registered Items report is now the nine-column
                -- Contract v1 DM (DMT_ITEM_RECON_DM), which emits OBJECT_TYPE /
                -- FUSION_ID (the per-org composite), not the STATUS / INVENTORY_ITEM_ID
                -- elements this loop reads, so this branch no longer matches rows --
                -- LOADED-with-composite is stamped by APPLY_CONTRACT_V1_ITEMS above.
                -- Retained only for the standalone dev/test transport shape.
                UPDATE DMT_EGP_ITEM_TFM_TBL
                SET    TFM_STATUS              = 'LOADED',
                       FUSION_INVENTORY_ITEM_ID = r.inventory_item_id,
                       RESULTS_UPDATED_DATE    = SYSDATE,
                       LAST_UPDATED_DATE       = SYSDATE
                WHERE  RUN_ID      = p_run_id
                AND    ITEM_NUMBER         = r.item_number
                AND    ORGANIZATION_CODE   = r.organization_code
                AND    TFM_STATUS         != 'LOADED';
                l_loaded := l_loaded + SQL%ROWCOUNT;
            ELSIF r.error_message IS NOT NULL THEN
                -- FAILED only with a REAL Fusion error. A non-PROCESSED status
                -- means the item is not in the base table, but base-absence is NOT
                -- a verdict: the item load splits across several load-controller
                -- requests, so an item absent from THIS report may still load (and
                -- reconcile LOADED) on a later sub-load's report. We mark FAILED
                -- only when the report carried a real per-row Fusion error message;
                -- otherwise the row is left GENERATED so a later reconcile can still
                -- promote it to LOADED (this is what resolves the two-batch Items
                -- reconcile race) and the honest sweep accounts for the rest.
                UPDATE DMT_EGP_ITEM_TFM_TBL
                SET    TFM_STATUS              = 'FAILED',
                       ERROR_TEXT              = DMT_UTIL_PKG.APPEND_ERROR(ERROR_TEXT,
                                                     '[FUSION_ERROR] ' || r.error_message),
                       RESULTS_UPDATED_DATE    = SYSDATE,
                       LAST_UPDATED_DATE       = SYSDATE
                WHERE  RUN_ID      = p_run_id
                AND    ITEM_NUMBER         = r.item_number
                AND    ORGANIZATION_CODE   = r.organization_code
                -- Never downgrade a confirmed LOADED. The item load can split
                -- across several load-controller requests; an item confirmed
                -- present by one sub-load must not be flipped to FAILED because
                -- a later sub-load's report doesn't carry it.
                AND    TFM_STATUS      NOT IN ('LOADED','FAILED');
                l_failed := l_failed + SQL%ROWCOUNT;
            END IF;
        END LOOP;

        -- Outcomes stay on the TFM rows only. Nothing is copied back to STG (backlog #310):
        -- a FAILED-mode rerun finds these rows through DMT_UTIL_PKG.FAILED_RETRY_SELECTED.

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
    -- APPLY_CONTRACT_V1_ITEMS (private)
    -- The Contract v1 base-tier positive proof for Items -- the SINGLE-TIER FBDI
    -- template (design section 5, Option A shape; owner decision on PR #248),
    -- copied from DMT_EXPENDITURE_RESULTS_PKG / DMT_WORKER_RESULTS_PKG, with the
    -- Items twist: Items carries TWO record types in ONE object, so this APPLY
    -- handles BOTH TFM tables from the ONE report:
    --   OBJECT_TYPE='Item'         -> DMT_EGP_ITEM_TFM_TBL      (FUSION_INVENTORY_ITEM_ID)
    --   OBJECT_TYPE='ItemCategory' -> DMT_EGP_ITEM_CAT_TFM_TBL  (FUSION_CATEGORY_ID)
    --
    -- The shared package DMT_RECON_CONTRACT_PKG.FETCH_ROWS runs the Items
    -- nine-column recon report over BIP (keyset paged, run-prefix scoped) and
    -- returns the parsed rows -- no dynamic SQL, no TFM reference there. The APPLY
    -- here is STATIC SQL against the compile-time-known Items TFM tables:
    --   * BASE / SUCCESS / FUSION_ID NOT NULL -> LOADED, stamp FUSION_ID into the
    --       tier's Fusion-id column. The ONLY path to LOADED.
    --   * FUSION_STATUS = ERROR with a real message -> FAILED, message appended as
    --       '[FUSION_ERROR] ' || message (never composed).
    --   * everything else (INTERFACE/SUCCESS, corroborating only; non-terminal) is
    --       left for the existing import-report harvest and the shared unaccounted
    --       sweep. Never fabricate an outcome.
    -- Match is on RECON_KEY = the report's RECORD_KEY (see the RECON_KEY stamps in
    -- DMT_EGP_ITEM_TRANSFORM_PKG and DMT_EGP_ITEM_CAT_TRANSFORM_PKG). Rows already
    -- terminal (LOADED/FAILED) are never touched, so this runs safely alongside the
    -- existing PARSE_AND_UPDATE path without double-counting.
    -- --------------------------------------------------------
    --
    -- ESS ids (run 236 fix): the report's P_LOAD_REQUEST_ID is the LOAD
    -- (InterfaceLoaderController) request id and P_IMPORT_ESS_ID is the Item
    -- Import request id. Fusion stamps the load id on
    -- EGP_ITEM_CATEGORIES_INTERFACE.LOAD_REQUEST_ID and the import id on its
    -- REQUEST_ID (verified live, run 236). Passing the import id as the load id
    -- (the old NVL(import, load) bind) made the category tier return nothing,
    -- because category item numbers carry a prior run's prefix (xref-resolved)
    -- or no prefix at all, so the prefix fallback could not rescue them.
    PROCEDURE APPLY_CONTRACT_V1_ITEMS (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER,
        p_import_ess_id IN NUMBER
    ) IS
        C_PROC      CONSTANT VARCHAR2(30) := 'APPLY_CONTRACT_V1_ITEMS';
        l_gen_count NUMBER := 0;
        l_rows      DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_err_code  NUMBER;
        l_loaded    NUMBER := 0;
        l_failed    NUMBER := 0;
        l_idfill    NUMBER := 0;    -- LOADED category rows given their missing Fusion id
        l_rc        NUMBER := 0;    -- backlog #65: rows matched by the current tier
        l_dff_seq   NUMBER;          -- backlog #65 tier 2: TFM_SEQUENCE_ID from DFF_KEY
        l_tier      VARCHAR2(10);    -- backlog #65: which tier matched (audit log)
    BEGIN
        -- Generated-row count across BOTH Items TFM tables (static, this object's
        -- own tables) drives the shared fetch's keyset page-count cap.
        SELECT (SELECT COUNT(*) FROM DMT_EGP_ITEM_TFM_TBL     WHERE RUN_ID = p_run_id)
             + (SELECT COUNT(*) FROM DMT_EGP_ITEM_CAT_TFM_TBL WHERE RUN_ID = p_run_id)
        INTO   l_gen_count
        FROM   DUAL;

        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code    => C_CEMLI,
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id,
            p_row_cap       => l_gen_count,
            x_rows          => l_rows,
            x_error_code    => l_err_code);

        -- A transport / SOAP failure raises loudly (design section 5: never a
        -- silent retry, never a zero-row "success"); the fetch already logged detail.
        IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            RAISE_APPLICATION_ERROR(-20096,
                'APPLY_CONTRACT_V1_ITEMS: Contract v1 fetch failed for Items '
                || '(detail in DMT_LOG_TBL).');
        END IF;

        IF l_rows.COUNT = 0 THEN
            -- Zero report rows is never success (design section 5): leave the
            -- remaining GENERATED rows for the existing unaccounted sweep.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': Items recon report returned zero rows; '
                               || 'GENERATED rows left for the unaccounted sweep '
                               || '(never a silent success).',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
        ELSE
            FOR i IN 1 .. l_rows.COUNT LOOP
                -- ---- Item master tier -----------------------------------------
                IF l_rows(i).OBJECT_TYPE = 'Item' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Positive proof: item present in EGP_SYSTEM_ITEMS_B with a
                        -- real id. The ONLY path to LOADED. Keyed on RECON_KEY.
                        -- FUSION_ID is the per-org composite
                        -- INVENTORY_ITEM_ID~ORGANIZATION_ID (an inventory item is
                        -- loaded PER ORGANIZATION; the item id alone dropped the org
                        -- and let two orgs' rows collide). Stamped verbatim into the
                        -- widened VARCHAR2 FUSION_INVENTORY_ITEM_ID -- line-grain proof.
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A reference
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches NO
                        -- TFM row do we fall through: tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID
                        -- = trailing segment of DFF_KEY) and then tier 3 (the business key:
                        -- RECON_KEY = BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1 hit short-
                        -- circuits, so loaded outcomes are identical to before.
                        l_rc := 0; l_tier := NULL;
                        UPDATE DMT_EGP_ITEM_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_INVENTORY_ITEM_ID = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_EGP_ITEM_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_INVENTORY_ITEM_ID = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_EGP_ITEM_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_INVENTORY_ITEM_ID = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED Item master via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;

                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        -- A real, specific Fusion error -> FAILED on the exact
                        -- message (never composed). Keyed on RECON_KEY.
                        UPDATE DMT_EGP_ITEM_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL; -- INTERFACE/SUCCESS or non-terminal: leave for the sweep.
                    END IF;

                -- ---- Item category tier ---------------------------------------
                ELSIF l_rows(i).OBJECT_TYPE = 'ItemCategory' THEN
                    IF l_rows(i).SOURCE_TYPE = 'BASE'
                       AND l_rows(i).FUSION_STATUS = 'SUCCESS'
                       AND l_rows(i).FUSION_ID IS NOT NULL THEN
                        -- Positive proof: category assignment present in
                        -- EGP_ITEM_CATEGORIES with a real id. The ONLY path to LOADED.
                        -- Backlog #65 three-tier match. Tier 1 is the stamped Slot A reference
                        -- (RECON_KEY = RECORD_KEY, exactly as before). Only if tier 1 matches NO
                        -- TFM row do we fall through: tier 2 (the Slot C DFF stamp: TFM_SEQUENCE_ID
                        -- = trailing segment of DFF_KEY) and then tier 3 (the business key:
                        -- RECON_KEY = BUSINESS_KEY -- the per-record SOURCE_REF equals RECON_KEY, so
                        -- tier 3 is the same key and safely degenerate). Every tier-1 hit short-
                        -- circuits, so loaded outcomes are identical to before.
                        l_rc := 0; l_tier := NULL;
                        UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
                        SET    TFM_STATUS           = 'LOADED',
                               FUSION_CATEGORY_ID   = l_rows(i).FUSION_ID,
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_rc := SQL%ROWCOUNT;
                        l_tier := CASE WHEN l_rc > 0 THEN 'TIER1' END;

                        IF l_rc = 0 AND l_rows(i).DFF_KEY IS NOT NULL THEN
                            l_dff_seq := TO_NUMBER(
                                REGEXP_SUBSTR(l_rows(i).DFF_KEY, '[0-9]+$') DEFAULT NULL ON CONVERSION ERROR);
                            IF l_dff_seq IS NOT NULL THEN
                                UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
                                SET    TFM_STATUS           = 'LOADED',
                                       FUSION_CATEGORY_ID   = l_rows(i).FUSION_ID,
                                       RESULTS_UPDATED_DATE = SYSDATE,
                                       LAST_UPDATED_DATE    = SYSDATE
                                WHERE  RUN_ID    = p_run_id
                                AND    TFM_SEQUENCE_ID = l_dff_seq
                                AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                                l_rc := SQL%ROWCOUNT;
                                IF l_rc > 0 THEN l_tier := 'TIER2'; END IF;
                            END IF;
                        END IF;

                        IF l_rc = 0 AND l_rows(i).BUSINESS_KEY IS NOT NULL THEN
                            UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
                            SET    TFM_STATUS           = 'LOADED',
                                   FUSION_CATEGORY_ID   = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    RECON_KEY = l_rows(i).BUSINESS_KEY
                            AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                            l_rc := SQL%ROWCOUNT;
                            IF l_rc > 0 THEN l_tier := 'TIER3'; END IF;
                        END IF;

                        -- Id backfill (run 236 fix): a category row may already be
                        -- LOADED with NO Fusion id, stamped by the retired secondary
                        -- ItemCategories reconciler whose report never returned the
                        -- assignment id. The base row is positive proof, so record its
                        -- real ITEM_CATEGORY_ASSIGNMENT_ID. Status is not changed.
                        IF l_rc = 0 THEN
                            UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
                            SET    FUSION_CATEGORY_ID   = l_rows(i).FUSION_ID,
                                   RESULTS_UPDATED_DATE = SYSDATE,
                                   LAST_UPDATED_DATE    = SYSDATE
                            WHERE  RUN_ID    = p_run_id
                            AND    RECON_KEY = l_rows(i).RECORD_KEY
                            AND    TFM_STATUS = 'LOADED'
                            AND    FUSION_CATEGORY_ID IS NULL;
                            l_idfill := l_idfill + SQL%ROWCOUNT;
                        END IF;

                        l_loaded := l_loaded + l_rc;
                        IF l_tier IN ('TIER2','TIER3') THEN
                            DMT_UTIL_PKG.LOG(p_run_id,
                                C_PROC || ': matched a LOADED Item category via ' || l_tier ||
                                ' fallback (tier 1 stamped ref did not resolve). FUSION_ID '
                                || l_rows(i).FUSION_ID || '.', 'INFO', C_PKG, C_PROC);
                        END IF;

                    ELSIF l_rows(i).FUSION_STATUS = 'ERROR'
                          AND l_rows(i).ERROR_MESSAGE IS NOT NULL THEN
                        UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
                        SET    TFM_STATUS           = 'FAILED',
                               ERROR_TEXT           = DMT_UTIL_PKG.APPEND_ERROR(
                                                        ERROR_TEXT,
                                                        '[FUSION_ERROR] ' || l_rows(i).ERROR_MESSAGE),
                               RESULTS_UPDATED_DATE = SYSDATE,
                               LAST_UPDATED_DATE    = SYSDATE
                        WHERE  RUN_ID    = p_run_id
                        AND    RECON_KEY = l_rows(i).RECORD_KEY
                        AND    TFM_STATUS NOT IN ('LOADED', 'FAILED');
                        l_failed := l_failed + SQL%ROWCOUNT;
                    ELSE
                        NULL; -- INTERFACE/SUCCESS or non-terminal: leave for the sweep.
                    END IF;
                ELSE
                    NULL; -- Unknown OBJECT_TYPE: leave for the sweep (never fabricate).
                END IF;
            END LOOP;
        END IF;

        DMT_UTIL_PKG.LOG(
            p_run_id    => p_run_id,
            p_message   => C_PROC || ' complete. Report rows: ' || l_rows.COUNT
                           || ' | LOADED: ' || l_loaded
                           || ' | FAILED: ' || l_failed
                           || ' | category ids filled on already-LOADED rows: ' || l_idfill
                           || ' | LoadReqId: ' || NVL(TO_CHAR(p_load_ess_id), '(null)')
                           || ' | ImportReqId: ' || NVL(TO_CHAR(p_import_ess_id), '(null)') || '.',
            p_package   => C_PKG,
            p_procedure => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END APPLY_CONTRACT_V1_ITEMS;

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
        l_any BOOLEAN := FALSE;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => C_PROC || ' start. load_ess_id: ' || p_load_ess_id,
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- Contract v1 base-tier positive proof (single-tier FBDI template, both
        -- Items record types): the shared fetch returns the nine-column recon
        -- report rows and the APPLY is STATIC SQL against this object's two TFM
        -- tables, keyed on RECON_KEY. This is the ONLY path to LOADED (a real
        -- base-table row). It runs FIRST so a genuinely-costed row is confirmed
        -- before the interface/import-report harvest below looks at what is left.
        -- Rows already terminal are untouched. Item master rows are scoped by the
        -- run prefix. Item category rows are scoped by the LOAD ESS id (the value
        -- Fusion stamps on EGP_ITEM_CATEGORIES_INTERFACE.LOAD_REQUEST_ID) or the
        -- import ESS id (stamped on its REQUEST_ID), so each is passed as itself;
        -- the old NVL(import, load) bind sent the import id as the load id and
        -- the category tier returned nothing (run 236).
        APPLY_CONTRACT_V1_ITEMS(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id);

        -- One Item Import can spread its interface rows across SEVERAL
        -- InterfaceLoaderController requests (Fusion chunks the FBDI load), and
        -- the base-table report is filtered by a single load_request_id. So we
        -- reconcile once per load-controller request recorded for this run's
        -- Items load; a single p_load_ess_id would see only some of the items.
        FOR lr IN (
            SELECT DISTINCT REQUEST_ID
            FROM   DMT_ESS_JOB_TBL
            WHERE  RUN_ID         = p_run_id
            AND    CEMLI_CODE     = 'Items'
            AND    JOB_SHORT_NAME = 'InterfaceLoaderController'
            AND    REQUEST_ID IS NOT NULL
        ) LOOP
            l_any := TRUE;
            -- Shared transport: parsed XMLTYPE (NULL on zero rows). On
            -- transport/SOAP failure it returns NULL with C_ERROR — raise so the
            -- failure is loud (as the old FETCH_BIP_RESULTS raised).
            DMT_UTIL_PKG.RUN_BIP_REPORT(
                p_run_id     => p_run_id,
                p_cemli_code => C_CEMLI,
                p_params     => 'P_BATCH_ID|' || TO_CHAR(p_run_id) ||
                                '~P_LOAD_REQUEST_ID|' || TO_CHAR(lr.REQUEST_ID),
                x_report_xml => l_xml,
                x_error_code => l_err_code);
            IF l_err_code <> DMT_UTIL_PKG.C_SUCCESS THEN
                RAISE_APPLICATION_ERROR(-20034,
                    C_PROC || ': BIP runReport fetch failed for ' || C_CEMLI ||
                    ' (detail in DMT_LOG_TBL).');
            END IF;
            PARSE_AND_UPDATE(p_run_id, l_xml);
        END LOOP;

        -- Fallback: if no load-controller request was recorded, use the id passed in.
        IF NOT l_any AND p_load_ess_id IS NOT NULL THEN
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
    -- RESET_UNACCOUNTED (backlog #95) -- see spec. Static UPDATE(s) over the
    -- compile-time-known Items TFM table(s). Flips this run's UNACCOUNTED rows
    -- back to GENERATED and strips the trailing [UNACCOUNTED] tag from ERROR_TEXT
    -- (CLOB-safe REGEXP_REPLACE -- plain REPLACE raises ORA-22849), preserving any
    -- prior real error. Scoped by run, and by work-queue item when given. NO
    -- dynamic SQL; NO COMMIT.
    -- --------------------------------------------------------
    PROCEDURE RESET_UNACCOUNTED (
        p_run_id        IN NUMBER,
        p_load_ess_id   IN NUMBER   DEFAULT NULL,
        p_import_ess_id IN NUMBER   DEFAULT NULL,
        p_work_queue_id IN NUMBER   DEFAULT NULL
    ) IS
        C_PROC  CONSTANT VARCHAR2(30) := 'RESET_UNACCOUNTED';
        l_reset NUMBER := 0;
    BEGIN
        UPDATE DMT_EGP_ITEM_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;
        UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
        SET    TFM_STATUS = 'GENERATED',
               ERROR_TEXT = CASE
                              WHEN DBMS_LOB.GETLENGTH(
                                     REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')) > 0
                              THEN REGEXP_REPLACE(ERROR_TEXT, '( \| )?\[UNACCOUNTED\]$')
                              ELSE NULL
                            END,
               LAST_UPDATED_DATE = SYSDATE
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'UNACCOUNTED'
        AND    (p_work_queue_id IS NULL OR WORK_QUEUE_ID = p_work_queue_id);
        l_reset := l_reset + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(p_run_id,
            C_PROC || ': reset ' || l_reset || ' UNACCOUNTED Items row(s) to GENERATED '
            || 'for re-reconcile.',
            'INFO', C_PKG, C_PROC);
        -- NO COMMIT -- the caller (RERUN_RUN) owns the transaction.
    END RESET_UNACCOUNTED;

END DMT_EGP_ITEM_RESULTS_PKG;
/
