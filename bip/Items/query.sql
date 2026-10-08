-- MIRROR of the deployed Contract-v1 data model
-- bip/Items/DMT_ITEM_RECON_V3_DM.xdm (deploy target /Custom/DMT2/Items/).
-- V3 (2026-10-07) is deployed alongside DMT_ITEM_RECON_DM and V2 (BIP objects
-- are never overwritten). V3 finds rows only by the work item's Fusion job ids.
-- The SQL below is the byte-exact CDATA body of that .xdm; regenerate this file
-- from the .xdm whenever the data model changes -- the mirror must never drift.
-- ============================================================
-- DMT_ITEM_RECON_V3_DM (2026-10-07), deployed ALONGSIDE V1 and V2.
-- Items reconciliation data model -- BIP reconciliation report
-- contract v1 (nine columns, six parameters, keyset by RECORD_KEY).
--
-- Row selection (owner decision 2026-10-07, design section 5
-- "Reports find rows by Fusion job id"): rows are FOUND only by the
-- Fusion job ids of ONE work item. The reconciler calls this report
-- once per item batch with that batch's own load id
-- (InterfaceLoaderController, P_LOAD_REQUEST_ID) and Item Import id
-- (ItemImportJobDef, P_IMPORT_ESS_ID).
--   BASE item rows: EGP_SYSTEM_ITEMS_B.REQUEST_ID = P_IMPORT_ESS_ID
--     (Fusion stamps the Item Import job id; verified live run 238,
--     10070549 / 10070578). The organization code for RECORD_KEY is
--     read from INV_ORG_PARAMETERS.
--   BASE category rows: EGP_ITEM_CATEGORIES.REQUEST_ID =
--     P_IMPORT_ESS_ID (verified live run 238), joined to the category
--     interface row the same import processed (same REQUEST_ID and
--     ids) for the RECORD_KEY parts.
--   INTERFACE rows (both record types) and EGP_IMPORT_ERRORS rows:
--     LOAD_REQUEST_ID = P_LOAD_REQUEST_ID or REQUEST_ID =
--     P_IMPORT_ESS_ID. Fusion stamps both ids on the interface rows
--     and on the error rows (verified live run 238). Either id is
--     this work item's own, so the OR never reaches another work
--     item's rows; the import id also covers a load Fusion split
--     across several InterfaceLoaderController requests.
--   An INTERFACE row is a rejection when no base row of THIS import
--     carries it.
-- V2 selected item master rows with LIKE on the run prefix and kept
-- a prefix arm on both category tiers; V3 drops every prefix arm.
-- P_RUN_ID and P_PREFIX stay declared for contract symmetry only.
--
-- TWO RECORD TYPES IN ONE OBJECT (unchanged from V2), discriminated
-- by OBJECT_TYPE:
--   'Item'         item master, RECORD_KEY ITEM_NUMBER~ORGANIZATION_CODE
--   'ItemCategory' category assignment, RECORD_KEY
--                  ITEM_NUMBER~ORGANIZATION_CODE~CATEGORY_SET_NAME~CATEGORY_CODE
-- RECORD_KEY is built from the same values the transforms stamp into
-- RECON_KEY; it is used only to match a returned row to its TFM row.
--
-- TIER RULES (Contract v1, unchanged from V2)
--   INTERFACE: FUSION_STATUS 'ERROR'; ERROR_MESSAGE is the real
--     EGP_IMPORT_ERRORS text (NULL when Fusion logged none, and the
--     reconciler then leaves the row for the UNACCOUNTED sweep).
--   BASE: FUSION_STATUS 'SUCCESS'; FUSION_ID is the base id
--     (INVENTORY_ITEM_ID~ORGANIZATION_ID for an item,
--     ITEM_CATEGORY_ASSIGNMENT_ID for a category). The ONLY path to
--     LOADED.
-- ============================================================
SELECT object_type,
       record_key,
       source_type,
       fusion_status,
       fusion_id,
       error_message,
       load_request_id,
       source_ref,
       dmt_reference
FROM (
    -- ---- Item master, INTERFACE tier (rejections carry real Fusion text) -----
    SELECT 'Item'                                          AS object_type,
           i.item_number || '~' || i.organization_code     AS record_key,
           'INTERFACE'                                     AS source_type,
           'ERROR'                                         AS fusion_status,
           -- VARCHAR2 to match the BASE tier's composite fusion_id: BIP derives
           -- one datatype per UNION column.
           CAST(NULL AS VARCHAR2(100))                     AS fusion_id,
           CASE WHEN ie.error_message IS NOT NULL
                THEN '[ITEM] ' || ie.error_message END
                                                           AS error_message,
           TO_CHAR(i.load_request_id)                      AS load_request_id,
           i.item_number                                   AS source_ref,
           CAST(NULL AS VARCHAR2(240))                     AS dmt_reference
    FROM   egp_system_items_interface i
    LEFT   JOIN (
        -- Real Fusion error text per interface row, keyed on TRANSACTION_ID
        -- and REQUEST_ID; only this work item's error rows (job ids).
        SELECT e.transaction_id,
               e.request_id,
               LISTAGG(
                   CASE WHEN e.error_column_name IS NOT NULL
                        THEN e.error_column_name || ': ' || e.message_text
                        ELSE e.message_text END,
                   ' | ') WITHIN GROUP (ORDER BY e.error_id) AS error_message
        FROM   egp_import_errors e
        WHERE  e.transaction_id > 0
        AND    e.error_table_name = 'EGP_SYSTEM_ITEMS_INTERFACE'
        AND    (   (:P_LOAD_REQUEST_ID IS NOT NULL AND e.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID))
                OR (:P_IMPORT_ESS_ID   IS NOT NULL AND e.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)) )
        GROUP BY e.transaction_id, e.request_id
    ) ie ON ie.transaction_id = i.transaction_id
        AND ie.request_id     = i.request_id
    WHERE  (   (:P_LOAD_REQUEST_ID IS NOT NULL AND i.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID))
            OR (:P_IMPORT_ESS_ID   IS NOT NULL AND i.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)) )
    -- Fusion adds its own item interface rows (no organization code) for items
    -- a category row touches; DMT's rows always carry the organization code.
    AND    i.organization_code IS NOT NULL
    AND    NOT EXISTS (
        SELECT 1 FROM egp_system_items_b b
        WHERE  b.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    b.item_number     = i.item_number
        AND    b.organization_id = i.organization_id)

    UNION ALL

    -- ---- Item master, BASE tier (positive proof -> LOADED) ------------------
    -- Found by the Item Import job id. FUSION_ID is the per-org composite
    -- INVENTORY_ITEM_ID~ORGANIZATION_ID (an item is loaded PER ORGANIZATION).
    SELECT 'Item'                                          AS object_type,
           b.item_number || '~' || p.organization_code     AS record_key,
           'BASE'                                          AS source_type,
           'SUCCESS'                                       AS fusion_status,
           TO_CHAR(b.inventory_item_id) || '~'
             || TO_CHAR(b.organization_id)                 AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))                    AS error_message,
           TO_CHAR(b.request_id)                           AS load_request_id,
           b.item_number                                   AS source_ref,
           CAST(NULL AS VARCHAR2(240))                     AS dmt_reference
    FROM   egp_system_items_b b
    JOIN   inv_org_parameters p
           ON p.organization_id = b.organization_id
    WHERE  b.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)

    UNION ALL

    -- ---- Item category, INTERFACE tier (rejections carry real Fusion text) ---
    SELECT 'ItemCategory'                                                        AS object_type,
           ic.item_number || '~' || ic.organization_code || '~'
             || ic.category_set_name || '~' || ic.category_code                  AS record_key,
           'INTERFACE'                                                          AS source_type,
           'ERROR'                                                             AS fusion_status,
           CAST(NULL AS VARCHAR2(100))                                         AS fusion_id,
           ce.error_message                                                     AS error_message,
           TO_CHAR(ic.load_request_id)                                          AS load_request_id,
           ic.item_number                                                       AS source_ref,
           CAST(NULL AS VARCHAR2(240))                                          AS dmt_reference
    FROM   egp_item_categories_interface ic
    LEFT   JOIN (
        -- Real Fusion error per category row = every EGP_IMPORT_ERRORS row Fusion
        -- logged under the category row's TRANSACTION_ID and REQUEST_ID, from the
        -- category interface table AND the item interface table (a category naming
        -- a missing item gets EGP_ITEM_NOT_EXIST logged against
        -- EGP_SYSTEM_ITEMS_INTERFACE with the same transaction id). Each message is
        -- MESSAGE_NAME: [COLUMN: ] TEXT; category errors first, then by id. Only
        -- this work item's error rows (job ids).
        SELECT e.transaction_id,
               e.request_id,
               LISTAGG(
                   e.message_name || ': '
                   || CASE WHEN e.error_column_name IS NOT NULL
                           THEN e.error_column_name || ': ' END
                   || COALESCE(e.message_text,
                          (SELECT MAX(m.message_text)
                           FROM   fnd_new_messages m
                           WHERE  m.message_name  = e.message_name
                           AND    m.language_code = 'US')),
                   '; ') WITHIN GROUP (
                       ORDER BY CASE e.error_table_name
                                     WHEN 'EGP_ITEM_CATEGORIES_INTERFACE' THEN 0
                                     ELSE 1 END,
                                e.error_id) AS error_message
        FROM   egp_import_errors e
        WHERE  e.transaction_id > 0
        AND    e.error_table_name IN ('EGP_ITEM_CATEGORIES_INTERFACE',
                                      'EGP_SYSTEM_ITEMS_INTERFACE')
        AND    (   (:P_LOAD_REQUEST_ID IS NOT NULL AND e.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID))
                OR (:P_IMPORT_ESS_ID   IS NOT NULL AND e.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)) )
        GROUP BY e.transaction_id, e.request_id
    ) ce ON ce.transaction_id = ic.transaction_id
        AND ce.request_id     = ic.request_id
    WHERE  (   (:P_LOAD_REQUEST_ID IS NOT NULL AND ic.load_request_id = TO_NUMBER(:P_LOAD_REQUEST_ID))
            OR (:P_IMPORT_ESS_ID   IS NOT NULL AND ic.request_id      = TO_NUMBER(:P_IMPORT_ESS_ID)) )
    AND    NOT EXISTS (
        SELECT 1 FROM egp_item_categories b
        WHERE  b.request_id        = TO_NUMBER(:P_IMPORT_ESS_ID)
        AND    b.inventory_item_id = ic.inventory_item_id
        AND    b.organization_id   = ic.organization_id
        AND    b.category_id       = ic.category_id
        AND    b.category_set_id   = ic.category_set_id)

    UNION ALL

    -- ---- Item category, BASE tier (positive proof -> LOADED) ----------------
    -- Found by the Item Import job id; the category interface row the same import
    -- processed supplies the RECORD_KEY parts.
    SELECT 'ItemCategory'                                                        AS object_type,
           ic.item_number || '~' || ic.organization_code || '~'
             || ic.category_set_name || '~' || ic.category_code                  AS record_key,
           'BASE'                                                              AS source_type,
           'SUCCESS'                                                           AS fusion_status,
           TO_CHAR(b.item_category_assignment_id)                              AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))                                         AS error_message,
           TO_CHAR(b.request_id)                                                AS load_request_id,
           ic.item_number                                                       AS source_ref,
           CAST(NULL AS VARCHAR2(240))                                          AS dmt_reference
    FROM   egp_item_categories b
    JOIN   egp_item_categories_interface ic
           ON ic.request_id        = b.request_id
          AND ic.inventory_item_id = b.inventory_item_id
          AND ic.organization_id   = b.organization_id
          AND ic.category_id       = b.category_id
          AND ic.category_set_id   = b.category_set_id
    WHERE  b.request_id = TO_NUMBER(:P_IMPORT_ESS_ID)
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
