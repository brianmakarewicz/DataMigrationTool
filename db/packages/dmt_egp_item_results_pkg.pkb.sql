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
    --
    -- Ordering (backlog #610, owner decision 2026-10-09): a category row is linked
    -- by id to its same-run item row (DMT_EGP_ITEM_CAT_TFM_TBL.ITEM_TFM_SEQUENCE_ID).
    -- When that item sits in a DIFFERENT batch, the category's batch must not import
    -- before the item's batch has loaded, so its token carries an "AFTER" array of
    -- those item batch ids, e.g. {"BATCH_ID":"934608102","AFTER":["934608101"]}.
    -- The queue worker turns AFTER into a work-queue dependency on the sibling child
    -- of each listed batch and stores the token WITHOUT AFTER in PARTITION_KEY.
    -- A batch whose categories all ride with their items (the usual case: items and
    -- categories share a batch, one zip, one Item Import) has no AFTER key, so its
    -- token is unchanged.
    -- --------------------------------------------------------
    FUNCTION GET_PARTITION_KEYS (
        p_run_id IN NUMBER
    ) RETURN DMT_PARTITION_KEY_TBL IS
        l_keys DMT_PARTITION_KEY_TBL;
    BEGIN
        -- One JSON object per distinct batch, keyed by the partition column name
        -- (JSON_OBJECT escapes the value correctly). Composite keys would add more
        -- keys to the same object without changing the callers. AFTER is omitted
        -- (ABSENT ON NULL) when the batch has no cross-batch item dependency.
        SELECT JSON_OBJECT(
                   'BATCH_ID' VALUE TO_CHAR(b.BATCH_ID),
                   'AFTER'    VALUE (
                       SELECT JSON_ARRAYAGG(d.ITEM_BATCH_ID ORDER BY d.ITEM_BATCH_ID
                                            RETURNING VARCHAR2(3000))
                       FROM (
                           SELECT DISTINCT TO_CHAR(it.BATCH_ID) AS ITEM_BATCH_ID
                           FROM   DMT_EGP_ITEM_CAT_TFM_TBL c
                           JOIN   DMT_EGP_ITEM_TFM_TBL it
                                  ON it.TFM_SEQUENCE_ID = c.ITEM_TFM_SEQUENCE_ID
                           WHERE  c.RUN_ID      = p_run_id
                           AND    c.TFM_STATUS  = 'STAGED'
                           AND    c.BATCH_ID    = b.BATCH_ID
                           AND    it.RUN_ID     = p_run_id
                           AND    it.TFM_STATUS = 'STAGED'
                           AND    it.BATCH_ID  <> b.BATCH_ID
                       ) d
                   ) FORMAT JSON
                   ABSENT ON NULL
                   RETURNING VARCHAR2(4000))
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
        ) b
        ORDER BY b.BATCH_ID;
        RETURN l_keys;
    END GET_PARTITION_KEYS;

    -- --------------------------------------------------------
    -- (PARSE_AND_UPDATE removed, backlog #482. It read the pre-Contract-v1 report
    --  shape -- ITEM_NUMBER / ORGANIZATION_CODE / STATUS under /DATA_DS/G_1 -- and
    --  was fed by a second, run-scoped report call that passed the retired
    --  P_BATCH_ID = run id. The registered Items report V3 returns only the nine
    --  contract columns, so that pass matched no row. APPLY_CONTRACT_V1_ITEMS below
    --  is the one reconcile path; it selects by the work item's ESS job ids only.)

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
        -- base-table row). Rows already terminal are untouched. The report (V3)
        -- selects only by this work item's ESS job ids: the LOAD ESS id (stamped
        -- on the interface tables' LOAD_REQUEST_ID) and the Item Import ESS id
        -- (stamped on base and interface REQUEST_ID), each passed as itself; the
        -- old NVL(import, load) bind sent the import id as the load id and the
        -- category tier returned nothing (run 236).
        APPLY_CONTRACT_V1_ITEMS(
            p_run_id        => p_run_id,
            p_load_ess_id   => p_load_ess_id,
            p_import_ess_id => p_import_ess_id);

        -- No second pass (backlog #482). The old loop re-ran the report once per
        -- InterfaceLoaderController request of the whole RUN with the retired
        -- P_BATCH_ID = run id (design section 5: recon selects by ESS job id
        -- only, never by run id or prefix). V3 already covers a load that Fusion
        -- chunked over several load requests: base items and base categories are
        -- found by REQUEST_ID = this work item's Item Import id, and interface /
        -- EGP_IMPORT_ERRORS rows by LOAD_REQUEST_ID or REQUEST_ID = that import id.

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
