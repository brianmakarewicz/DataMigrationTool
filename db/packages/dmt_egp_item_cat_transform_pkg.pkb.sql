-- PACKAGE BODY DMT_EGP_ITEM_CAT_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_CAT_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_CAT_TRANSFORM_PKG Body
--
-- ITEM_NUMBER (backlog #610, owner decision 2026-10-09): each category row is
-- linked BY ID to the item row of the SAME run -- the DMT_EGP_ITEM_TFM_TBL row
-- transformed (earlier in this same RUN_ITEMS pass) from the item STG row with
-- the same source ITEM_NUMBER and ORGANIZATION_CODE. The category stores that
-- row's TFM_SEQUENCE_ID in ITEM_TFM_SEQUENCE_ID and copies its run-prefixed
-- ITEM_NUMBER, so the FBDI carries THIS run's item number. When the item is not
-- part of the run (a category-only load for an item that already exists in
-- Fusion) ITEM_TFM_SEQUENCE_ID stays NULL and the source item number is used
-- unchanged. The previous DMT_XREF_PKG.ITEM_NUMBER lookup returned the newest
-- already-LOADED item, i.e. the PREVIOUS run's item, and is no longer used here.
--
-- REVISIONS:
--   2026-10-09  BM  Link each category to its same-run item by TFM id (#610).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_CAT_TRANSFORM_PKG';

    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);
    BEGIN
        l_prefix := get_prefix(p_run_id);
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

        INSERT INTO DMT_EGP_ITEM_CAT_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    -- Business columns
                    TRANSACTION_TYPE,
                    BATCH_ID,
                    BATCH_NUMBER,
                    ORGANIZATION_CODE,
                    ITEM_NUMBER,
                    CATEGORY_SET_NAME,
                    CATEGORY_CODE,
                    CATEGORY_NAME,
                    OLD_CATEGORY_CODE,
                    OLD_CATEGORY_NAME,
                    SOURCE_SYSTEM_CODE,
                    SOURCE_SYSTEM_REFERENCE,
                    -- Parent-child join key: the same-run item row (#610)
                    ITEM_TFM_SEQUENCE_ID,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,

                    s.TRANSACTION_TYPE,
                    -- Fusion batch id: the SAME expression as DMT_EGP_ITEM_TRANSFORM_PKG
                    -- (backlog #411) so a batch's items and categories stay together:
                    -- run prefix followed by the source BATCH_ID, else by the work-queue
                    -- id (run id outside the queue); source value unchanged when
                    -- USE_PREFIX = N.
                    TO_NUMBER(l_prefix || TO_CHAR(NVL(s.BATCH_ID, NVL(DMT_LOADER_PKG.g_gen_queue_id, p_run_id)), 'TM9')),
                    s.BATCH_NUMBER,
                    s.ORGANIZATION_CODE,
                    -- #610: THIS run's item number when the item is part of the run
                    -- (linked by id below); the source item number unchanged when it
                    -- is not (category-only load of an item already in Fusion).
                    -- Never an earlier run's item.
                    CASE WHEN pi.TFM_SEQUENCE_ID IS NOT NULL
                         THEN pi.ITEM_NUMBER
                         ELSE s.ITEM_NUMBER
                    END,
                    s.CATEGORY_SET_NAME,
                    s.CATEGORY_CODE,
                    s.CATEGORY_NAME,
                    s.OLD_CATEGORY_CODE,
                    s.OLD_CATEGORY_NAME,
                    s.SOURCE_SYSTEM_CODE,
                    s.SOURCE_SYSTEM_REFERENCE,
                    pi.TFM_SEQUENCE_ID,

                    'STAGED',
                    SYSDATE
        FROM DMT_EGP_ITEM_CAT_STG_TBL s
        -- #610: the item row of THIS run that the category belongs to -- the item
        -- TFM row (any status) transformed from the item STG row with the same
        -- source item number and organization. RUN_ITEMS transforms items before
        -- categories, so the row already exists. One row per (item, org): the
        -- lowest TFM id if the scenario staged the same item+org twice.
        LEFT JOIN (
            SELECT it.TFM_SEQUENCE_ID,
                   it.ITEM_NUMBER,
                   it.ORGANIZATION_CODE,
                   ist.ITEM_NUMBER AS SOURCE_ITEM_NUMBER,
                   ROW_NUMBER() OVER (PARTITION BY ist.ITEM_NUMBER, it.ORGANIZATION_CODE
                                      ORDER BY it.TFM_SEQUENCE_ID) AS RN
            FROM   DMT_EGP_ITEM_TFM_TBL it
            JOIN   DMT_EGP_ITEM_STG_TBL ist
                   ON ist.STG_SEQUENCE_ID = it.STG_SEQUENCE_ID
            WHERE  it.RUN_ID = p_run_id
        ) pi
               ON  pi.SOURCE_ITEM_NUMBER = s.ITEM_NUMBER
               AND pi.ORGANIZATION_CODE  = s.ORGANIZATION_CODE
               AND pi.RN = 1
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_EGP_ITEM_CAT_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        -- Scenario scoping: only transform rows for the active scenario (and, when requested,
        -- untagged rows). Without this the run sweeps the entire staging table regardless of
        -- scenario — mirrors the predicate used by the supplier/customer transforms.
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_EGP_ITEM_CAT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        -- ============================================================
        -- Contract v1 RECON_KEY stamp (item-category tier).
        -- The shared reconciler matches each report row's RECORD_KEY to the TFM
        -- row's RECON_KEY. The Items recon data model
        -- (bip/Items/DMT_ITEM_RECON_DM.xdm) emits, for OBJECT_TYPE='ItemCategory':
        --   RECORD_KEY = ITEM_NUMBER || '~' || ORGANIZATION_CODE || '~'
        --                || CATEGORY_SET_NAME || '~' || CATEGORY_CODE
        -- where ITEM_NUMBER is the run-prefixed item number (survives to
        -- EGP_ITEM_CATEGORIES_INTERFACE / EGP_ITEM_CATEGORIES). That prefixed
        -- number plus org/set/code is exactly what the INSERT above wrote into
        -- this TFM table. So RECON_KEY is set equal to the same four-part key
        -- here, byte-for-byte the string the DM builds. The '~' delimiter never
        -- appears in item numbers, org codes, category set names, or category
        -- codes. Only newly-stamped rows (RECON_KEY IS NULL) for this run are
        -- touched, so a rerun never disturbs rows already carrying a key.
        -- ============================================================
        UPDATE DMT_EGP_ITEM_CAT_TFM_TBL
        SET    RECON_KEY = ITEM_NUMBER || '~' || ORGANIZATION_CODE || '~'
                           || CATEGORY_SET_NAME || '~' || CATEGORY_CODE
        WHERE  RUN_ID = p_run_id
        AND    RECON_KEY IS NULL;

        UPDATE DMT_EGP_ITEM_CAT_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_EGP_ITEM_CAT_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_EGP_ITEM_CAT_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'Items', 'Item Categories', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_EGP_ITEM_CAT_STG_TBL s
                WHERE  ( DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_EGP_ITEM_CAT_STG_TBL', s.STG_SEQUENCE_ID) = 'Y' )
                AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_EGP_ITEM_CAT_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Item Categories');
                UPDATE DMT_EGP_ITEM_CAT_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Item Categories')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_EGP_ITEM_CAT_TRANSFORM_PKG;
/
