-- MIRROR of the deployed Contract-v1 data model
-- bip/Items/DMT_ITEM_RECON_DM.xdm (deploy target /Custom/DMT2/Items/).
-- The SQL below is the byte-exact CDATA body of that .xdm; regenerate
-- this file from the .xdm whenever the data model changes -- the mirror
-- must never drift.
-- ============================================================
-- Items reconciliation data model -- BIP reconciliation report
-- contract v1 (nine columns, keyset pagination, the six standard
-- parameters).
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE.
--
-- SIX parameters (Contract v1): P_RUN_ID, P_LOAD_REQUEST_ID,
--   P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY.
--
-- TWO record types in one object (OBJECT_TYPE discriminates):
--   'Item'         -> item master, keyed ITEM_NUMBER~ORGANIZATION_CODE
--   'ItemCategory' -> category assignment, keyed
--       ITEM_NUMBER~ORGANIZATION_CODE~CATEGORY_SET_NAME~CATEGORY_CODE
-- RECORD_KEY equals the TFM row's RECON_KEY (stamped by the item and
-- item-category transform packages), byte-for-byte.
--
-- RUN SCOPING is by P_PREFIX (embedded at the front of every ITEM_NUMBER,
-- surviving to interface and base tables) so every chunk of a multi-request
-- Item Import load is seen in one pass. P_LOAD_REQUEST_ID is stamped for
-- traceability but does NOT filter rows.
--
-- TIER RULES (Contract v1):
--   BASE       -> record present in its Fusion base table => SUCCESS,
--                 FUSION_ID = the base surrogate id. ONLY path to LOADED.
--   INTERFACE  -> interface row with NO base row => rejection.
--                 FUSION_STATUS normalized to ERROR; ERROR_MESSAGE is the
--                 REAL Fusion text from EGP_IMPORT_ERRORS.MESSAGE_TEXT
--                 (keyed on TRANSACTION_ID, filtered by ERROR_TABLE_NAME),
--                 with a short fallback only when Fusion left no error row.
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
    -- An interface row whose base row is ABSENT is a rejection. Contract v1
    -- requires FUSION_STATUS normalized to ERROR and a non-null ERROR_MESSAGE
    -- carrying the real Fusion rejection text, harvested from EGP_IMPORT_ERRORS
    -- (keyed on TRANSACTION_ID). Items records per-row error text there, so this
    -- object does NOT use the #IMPORT_REPORT# marker. A short fallback string is
    -- used only when Fusion left no error row for a rejected item, so the row
    -- still reaches FAILED (never UNACCOUNTED) per THE MISSION.
    SELECT 'Item'                                          AS object_type,
           i.item_number || '~' || i.organization_code     AS record_key,
           'INTERFACE'                                     AS source_type,
           'ERROR'                                         AS fusion_status,
           CAST(NULL AS NUMBER)                            AS fusion_id,
           '[ITEM] ' || NVL(ie.error_message,
               'Rejected by Item Import (process_status='
               || NVL(TO_CHAR(i.process_status), 'NULL')
               || '; item not created in base table EGP_SYSTEM_ITEMS_B).')
                                                           AS error_message,
           TO_CHAR(i.load_request_id)                      AS load_request_id,
           i.item_number                                   AS source_ref,
           CAST(NULL AS VARCHAR2(240))                     AS dmt_reference
    FROM   egp_system_items_interface i
    LEFT   JOIN egp_system_items_b b
           ON b.item_number     = i.item_number
          AND b.organization_id = i.organization_id
    LEFT   JOIN (
        -- Real Fusion error text per interface row, keyed on TRANSACTION_ID.
        -- One transaction can raise several messages; collapse them into one
        -- string, prefixed with the errored column name when Fusion records one.
        SELECT e.transaction_id,
               LISTAGG(
                   CASE WHEN e.error_column_name IS NOT NULL
                        THEN e.error_column_name || ': ' || e.message_text
                        ELSE e.message_text END,
                   ' | ') WITHIN GROUP (ORDER BY e.error_id) AS error_message
        FROM   egp_import_errors e
        WHERE  e.transaction_id > 0
        AND    e.error_table_name = 'EGP_SYSTEM_ITEMS_INTERFACE'
        GROUP BY e.transaction_id
    ) ie ON ie.transaction_id = i.transaction_id
    WHERE  :P_PREFIX IS NOT NULL
    AND    i.item_number LIKE :P_PREFIX || '%'
    AND    i.organization_code IS NOT NULL
    AND    b.item_number IS NULL

    UNION ALL

    -- ---- Item master, BASE tier (positive proof -> LOADED) ------------------
    SELECT 'Item'                                          AS object_type,
           i.item_number || '~' || i.organization_code     AS record_key,
           'BASE'                                          AS source_type,
           'SUCCESS'                                       AS fusion_status,
           b.inventory_item_id                             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))                    AS error_message,
           TO_CHAR(i.load_request_id)                      AS load_request_id,
           i.item_number                                   AS source_ref,
           CAST(NULL AS VARCHAR2(240))                     AS dmt_reference
    FROM   egp_system_items_interface i
    JOIN   egp_system_items_b b
           ON b.item_number     = i.item_number
          AND b.organization_id = i.organization_id
    WHERE  :P_PREFIX IS NOT NULL
    AND    i.item_number LIKE :P_PREFIX || '%'
    AND    i.organization_code IS NOT NULL

    UNION ALL

    -- ---- Item category, INTERFACE tier (rejections carry real Fusion text) ---
    -- Same rule as the item-master INTERFACE tier: a category interface row with
    -- no base assignment is a rejection; FUSION_STATUS='ERROR' and ERROR_MESSAGE
    -- carries the real EGP_IMPORT_ERRORS text (EGP_ITEM_CATEGORIES_INTERFACE),
    -- with a short fallback only when Fusion left no error row.
    SELECT 'ItemCategory'                                                        AS object_type,
           ic.item_number || '~' || ic.organization_code || '~'
             || ic.category_set_name || '~' || ic.category_code                  AS record_key,
           'INTERFACE'                                                          AS source_type,
           'ERROR'                                                             AS fusion_status,
           CAST(NULL AS NUMBER)                                                 AS fusion_id,
           '[CATEGORY] ' || NVL(ce.error_message,
               'Rejected by Item Import (process_status='
               || NVL(TO_CHAR(ic.process_status), 'NULL')
               || '; category assignment not created in base table '
               || 'EGP_ITEM_CATEGORIES).')                                      AS error_message,
           TO_CHAR(ic.load_request_id)                                          AS load_request_id,
           ic.item_number                                                       AS source_ref,
           CAST(NULL AS VARCHAR2(240))                                          AS dmt_reference
    FROM   egp_item_categories_interface ic
    LEFT   JOIN egp_item_categories b
           ON b.inventory_item_id = ic.inventory_item_id
          AND b.organization_id   = ic.organization_id
          AND b.category_id       = ic.category_id
          AND b.category_set_id   = ic.category_set_id
    LEFT   JOIN (
        SELECT e.transaction_id,
               LISTAGG(
                   CASE WHEN e.error_column_name IS NOT NULL
                        THEN e.error_column_name || ': ' || e.message_text
                        ELSE e.message_text END,
                   ' | ') WITHIN GROUP (ORDER BY e.error_id) AS error_message
        FROM   egp_import_errors e
        WHERE  e.transaction_id > 0
        AND    e.error_table_name = 'EGP_ITEM_CATEGORIES_INTERFACE'
        GROUP BY e.transaction_id
    ) ce ON ce.transaction_id = ic.transaction_id
    WHERE  :P_PREFIX IS NOT NULL
    AND    ic.item_number LIKE :P_PREFIX || '%'
    AND    b.item_category_assignment_id IS NULL

    UNION ALL

    -- ---- Item category, BASE tier (positive proof -> LOADED) ----------------
    SELECT 'ItemCategory'                                                        AS object_type,
           ic.item_number || '~' || ic.organization_code || '~'
             || ic.category_set_name || '~' || ic.category_code                  AS record_key,
           'BASE'                                                              AS source_type,
           'SUCCESS'                                                           AS fusion_status,
           b.item_category_assignment_id                                       AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))                                         AS error_message,
           TO_CHAR(ic.load_request_id)                                          AS load_request_id,
           ic.item_number                                                       AS source_ref,
           CAST(NULL AS VARCHAR2(240))                                          AS dmt_reference
    FROM   egp_item_categories_interface ic
    JOIN   egp_item_categories b
           ON b.inventory_item_id = ic.inventory_item_id
          AND b.organization_id   = ic.organization_id
          AND b.category_id       = ic.category_id
          AND b.category_set_id   = ic.category_set_id
    WHERE  :P_PREFIX IS NOT NULL
    AND    ic.item_number LIKE :P_PREFIX || '%'
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
