-- MIRROR of the deployed Contract-v1 data model
-- bip/Items/DMT_ITEM_RECON_V2_DM.xdm (deploy target /Custom/DMT2/Items/).
-- V2 (2026-10-06) is deployed alongside the original DMT_ITEM_RECON_DM.xdm
-- (BIP objects are never overwritten). V2 category tiers also accept
-- request_id = P_IMPORT_ESS_ID, and the category ERROR_MESSAGE is
-- MESSAGE_NAME: TEXT from EGP_IMPORT_ERRORS for both the category and the
-- item interface table under the row's TRANSACTION_ID + REQUEST_ID.
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
-- RUN SCOPING: the ITEM MASTER tiers scope by P_PREFIX (embedded at the front of
-- every ITEM_NUMBER, surviving to interface and base tables) so every chunk of a
-- multi-request Item Import load is seen in one pass. The ITEM CATEGORY tiers
-- scope by (P_LOAD_REQUEST_ID OR P_PREFIX): a category's xref-resolved ITEM_NUMBER
-- may carry no current-run prefix, so P_LOAD_REQUEST_ID (the InterfaceLoaderController
-- request id Fusion stamps on the category interface row) catches those, with the
-- P_PREFIX arm as a fallback for older loads that left LOAD_REQUEST_ID NULL. This
-- dual scope fixed run 229's blank UNACCOUNTED EGP-2775085 category rows.
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
           -- VARCHAR2 to match the BASE tier's composite fusion_id: BIP derives
           -- one datatype per UNION column, so every branch's fusion_id must be
           -- the same type or the report data model 500s at runtime.
           CAST(NULL AS VARCHAR2(100))                     AS fusion_id,
           CASE WHEN ie.error_message IS NOT NULL
                THEN '[ITEM] ' || ie.error_message END
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
    -- FUSION_ID is the per-org composite INVENTORY_ITEM_ID~ORGANIZATION_ID from
    -- EGP_SYSTEM_ITEMS_B: an inventory item is loaded PER ORGANIZATION, so its
    -- real identity in the base table is the pair (INVENTORY_ITEM_ID,
    -- ORGANIZATION_ID). The item id alone dropped the org, so two rows for the
    -- same item in different orgs collided. Per-item-per-org grain is preserved
    -- (RECORD_KEY = ITEM_NUMBER~ORGANIZATION_CODE, one row per org). The '~'
    -- composite rides the shared Contract v1 string FUSION_ID (widened in #456).
    SELECT 'Item'                                          AS object_type,
           i.item_number || '~' || i.organization_code     AS record_key,
           'BASE'                                          AS source_type,
           'SUCCESS'                                       AS fusion_status,
           TO_CHAR(b.inventory_item_id) || '~'
             || TO_CHAR(b.organization_id)                 AS fusion_id,
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
           -- VARCHAR2 to match the other branches' fusion_id (BIP derives one
           -- datatype per UNION column; a NUMBER here 500s the report).
           CAST(NULL AS VARCHAR2(100))                                         AS fusion_id,
           ce.error_message                                                     AS error_message,
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
        -- V2: real Fusion error per category row = every EGP_IMPORT_ERRORS row
        -- Fusion logged under the category row's TRANSACTION_ID and REQUEST_ID,
        -- from the category interface table AND the item interface table (a
        -- category naming a missing item gets EGP_ITEM_NOT_EXIST logged against
        -- EGP_SYSTEM_ITEMS_INTERFACE with the same transaction id). Each message
        -- is MESSAGE_NAME: [COLUMN: ] TEXT; category errors first, then by id.
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
        GROUP BY e.transaction_id, e.request_id
    ) ce ON ce.transaction_id = ic.transaction_id
        AND ce.request_id     = ic.request_id
    -- Run-scope category rows by EITHER of two run-scoped selectors, so no
    -- rejected category row is ever silently dropped (the defect behind run 229's
    -- blank UNACCOUNTED EGP-2775085 rows):
    --   (a) ic.load_request_id = :P_LOAD_REQUEST_ID -- the bundled Item Import
    --       stamps the InterfaceLoaderController request id (the value the
    --       reconciler binds here) onto the category interface row. Proven live
    --       (run 229, load_request_id 10065634/10065638) to return every rejected
    --       category row, INCLUDING the bad row NONEXISTENT-DMT-ITEM whose item
    --       number carries no run prefix.
    --   (b) ic.item_number LIKE :P_PREFIX || '%' -- a safety net for rows where
    --       Fusion left load_request_id NULL (older loads) or chunked the load
    --       under a different id: a category whose xref-resolved item number
    --       carries THIS run's prefix is unambiguously this run's.
    -- Both predicates are this-run-only (the prefix is a per-run sequence value
    -- and the load request id is this run's controller), so the OR never pulls
    -- another run's rows. The real EGP_IMPORT_ERRORS text is harvested on
    -- TRANSACTION_ID (join ce above); base-absence makes the row a rejection.
    -- V2 adds selector (c) ic.request_id = :P_IMPORT_ESS_ID: Fusion stamps the
    -- Item Import request id there (verified live run 236), so a caller that
    -- binds either ESS id still reaches the row.
    WHERE  b.item_category_assignment_id IS NULL
    AND    (   (:P_LOAD_REQUEST_ID IS NOT NULL AND ic.load_request_id = :P_LOAD_REQUEST_ID)
            OR (:P_IMPORT_ESS_ID   IS NOT NULL AND ic.request_id      = :P_IMPORT_ESS_ID)
            OR (:P_PREFIX IS NOT NULL AND ic.item_number LIKE :P_PREFIX || '%') )

    UNION ALL

    -- ---- Item category, BASE tier (positive proof -> LOADED) ----------------
    SELECT 'ItemCategory'                                                        AS object_type,
           ic.item_number || '~' || ic.organization_code || '~'
             || ic.category_set_name || '~' || ic.category_code                  AS record_key,
           'BASE'                                                              AS source_type,
           'SUCCESS'                                                           AS fusion_status,
           -- Category tier stays OWN-grain (ITEM_CATEGORY_ASSIGNMENT_ID); wrapped
           -- in TO_CHAR only so both tiers share the one string FUSION_ID column.
           TO_CHAR(b.item_category_assignment_id)                              AS fusion_id,
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
    -- Same two run-scoped selectors as the category INTERFACE tier (load request
    -- id OR this run's item-number prefix), so a genuinely loaded category is
    -- never dropped on a NULL load_request_id. See the INTERFACE tier note.
    WHERE  (   (:P_LOAD_REQUEST_ID IS NOT NULL AND ic.load_request_id = :P_LOAD_REQUEST_ID)
            OR (:P_IMPORT_ESS_ID   IS NOT NULL AND ic.request_id      = :P_IMPORT_ESS_ID)
            OR (:P_PREFIX IS NOT NULL AND ic.item_number LIKE :P_PREFIX || '%') )
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
