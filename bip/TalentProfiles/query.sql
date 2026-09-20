-- DMT_TALENT_PROF_RECON_DM query (BIP reconciliation report contract v1).
-- Mirror of the CDATA SQL in DMT_TALENT_PROF_RECON_DM.xdm, kept here for review
-- and for running the query standalone against live Fusion (bind the six
-- Contract v1 parameters).
--
-- TalentProfiles loads through HCM Data Loader (DMT_TALENT_PROF_HDL_GEN_PKG) as
-- a two-component object written into one TalentProfiles_<run>.zip:
--     * the parent  TalentProfile.dat  (business object 'TalentProfile'),
--       SourceSystemId = (prefixed PERSON_NUMBER) || '_TPROF'
--     * the child    ProfileItem.dat   (business object 'ProfileItem'),
--       SourceSystemId = (prefixed PERSON_NUMBER) || '_TPITM', with a
--       TalentProfileId(SourceSystemId) FK back to the parent.
-- Both are written with SourceSystemOwner 'HRC_SQLLOADER'. The transform stamps
-- both keys as RECON_KEY on their respective TFM rows (DMT_TALENT_PROF_TRANSFORM_PKG).
--
-- An HDL load has no interface table, so this report returns the BASE tier only:
-- one row per migrated component positively confirmed by a HRC_INTEGRATION_KEY_MAP
-- entry, with a real Fusion base-table id as FUSION_ID. Per-record HDL failures
-- are captured separately (RECONCILE tags [FUSION_ERROR] from the HDL response
-- before this report runs), so this report returns BASE / SUCCESS rows only.
--
-- One row per component, distinguished by OBJECT_TYPE:
--   * ProfileItem   -> FUSION_ID = HRT_PROFILE_ITEMS.PROFILE_ITEM_ID
--                      RECORD_KEY = the item's SourceSystemId.
--   * TalentProfile -> FUSION_ID = HRT_PROFILES_B.PROFILE_ID (the parent profile,
--                      reached from the item via HRT_PROFILE_ITEMS.PROFILE_ID),
--                      RECORD_KEY = 'PROF:' || PROFILE_ID.
--
-- NINE response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE('BASE'), FUSION_STATUS('SUCCESS'),
--   FUSION_ID, ERROR_MESSAGE (NULL), LOAD_REQUEST_ID (NULL),
--   SOURCE_REF (= RECORD_KEY), DMT_REFERENCE (NULL).
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID, P_PREFIX,
--   P_CHUNK_SIZE, P_AFTER_KEY.  Keyset pagination by RECORD_KEY (P_AFTER_KEY).
--
-- WHY THE PARENT IS ANCHORED THROUGH THE CHILD (honest note, verified live
-- 2026-09-20, fin_impl / ApplicationDB_FSCM):
--   * The ONLY HRC_SQLLOADER-owned talent object in HRC_INTEGRATION_KEY_MAP on
--     the pod is OBJECT_NAME='ProfileItem' (4 rows). There is NO HRC_SQLLOADER
--     'Profile'/'TalentProfile' key-map row — this HDL path registers a key map
--     entry for the child item only, not for the parent profile.
--   * ProfileItem SURROGATE_ID round-trips to HRT_PROFILE_ITEMS.PROFILE_ITEM_ID
--     (all 4 matched), and each item's PROFILE_ID round-trips to a real
--     HRT_PROFILES_B row (PROFILE_CODE 'PERS_<profile_id>'). So the parent is
--     provably in its base table; it is just reached through the child rather
--     than through its own key-map row.
--   * The live rows predate the current _TPROF/_TPITM SourceSystemId format
--     (they are earlier discovery/seed loads: '10554DMTTP001', 'DMTTP-SEED-1').
--     There are ZERO %_TPROF / %_TPITM key-map rows on the pod yet, so a
--     reconciler round-trip against a real gen-package run could not be shown;
--     the standalone proof below uses the live prefix '10554' data that exists.
--   * BASE-TABLE NOTE: HRT_PROFILE_ITEMS and HRT_PROFILES_B are both selectable
--     by name from the BIP reporting user (the *_B suffix variants and *_VL are
--     not). This report joins the key map to HRT_PROFILE_ITEMS so every returned
--     FUSION_ID is a verified base-table id, not a bare SURROGATE_ID.
--
-- Base-tier matching is by run prefix (P_PREFIX). LOAD_REQUEST_ID / P_IMPORT_ESS_ID
-- do not survive into the base table for an HDL load, so they are not filters here;
-- LOAD_REQUEST_ID is returned NULL per the contract column mapping.

SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Child component: one HRC_INTEGRATION_KEY_MAP row per ProfileItem
    -- (OBJECT_NAME='ProfileItem', SOURCE_SYSTEM_OWNER='HRC_SQLLOADER'); its
    -- SURROGATE_ID is the HRT_PROFILE_ITEMS.PROFILE_ITEM_ID (join proves the
    -- base row exists and yields the parent PROFILE_ID for the parent component).
    SELECT 'ProfileItem'                  AS object_type,
           m.source_system_id             AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           i.profile_item_id              AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           m.source_system_id             AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   hrc_integration_key_map m
    JOIN   hrt_profile_items i
           ON i.profile_item_id = m.surrogate_id
    WHERE  m.object_name         = 'ProfileItem'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    UNION ALL
    -- Parent component: the distinct talent profile behind the migrated items,
    -- confirmed in HRT_PROFILES_B by its PROFILE_ID (reached via the item).
    -- One row per distinct parent profile in this run's prefix.
    SELECT 'TalentProfile'               AS object_type,
           'PROF:' || i.profile_id        AS record_key,
           'BASE'                         AS source_type,
           'SUCCESS'                      AS fusion_status,
           MAX(i.profile_id)              AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))   AS error_message,
           CAST(NULL AS VARCHAR2(30))     AS load_request_id,
           'PROF:' || i.profile_id        AS source_ref,
           CAST(NULL AS VARCHAR2(4000))   AS dmt_reference
    FROM   hrc_integration_key_map m
    JOIN   hrt_profile_items i
           ON i.profile_item_id = m.surrogate_id
    WHERE  m.object_name         = 'ProfileItem'
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    GROUP BY i.profile_id
)
-- Keyset predicate. An empty P_AFTER_KEY (first page) binds to NULL in BIP, so
-- treat NULL as "from the start": every non-null RECORD_KEY sorts after the empty
-- string. On later pages P_AFTER_KEY carries the previous page's last RECORD_KEY
-- and only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
