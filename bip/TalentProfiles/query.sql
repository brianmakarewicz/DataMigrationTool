-- DMT_TALENTPROFILES_RECON_V3_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_TALENTPROFILES_RECON_V3_DM.xdm (the registered
-- version), kept here for review and for running the query standalone against
-- live Fusion (bind the six parameters). V1 stays deployed; BIP objects are never
-- overwritten. Backlog #451.
--
-- Rows are selected by the HDL request id (P_LOAD_REQUEST_ID), never by the run
-- prefix: the data set's file rows give each SourceSystemOwner + SourceSystemId
-- this load sent; each is joined to HRC_INTEGRATION_KEY_MAP on its own owner and
-- id and returned only when this load's physical line finished LOADED_SUCCESS and
-- the surrogate exists in its base table:
--   TalentProfile -> HRT_PROFILES_B.PROFILE_ID       (RECORD_KEY <person>_TPROF)
--     (the key map names this object 'Profile'; it is returned as OBJECT_TYPE
--      'TalentProfile'. V2 filtered on 'TalentProfile' and missed it, run 298.)
--   ProfileItem   -> HRT_PROFILE_ITEMS.PROFILE_ITEM_ID (RECORD_KEY <person>_TPITM)

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
    SELECT CASE m.object_name WHEN 'Profile' THEN 'TalentProfile'
                ELSE m.object_name END        AS object_type,
           r.key_source_id                   AS record_key,
           'BASE'                            AS source_type,
           'SUCCESS'                         AS fusion_status,
           MAX(m.surrogate_id)               AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))      AS error_message,
           :P_LOAD_REQUEST_ID                AS load_request_id,
           r.key_source_id                   AS source_ref,
           CAST(NULL AS VARCHAR2(240))       AS dmt_reference
    FROM   hrc_dl_data_set_bus_objs b
    JOIN   hrc_dl_file_lines        l ON l.data_set_bus_obj_id = b.data_set_bus_obj_id
    JOIN   hrc_dl_file_rows         r ON r.line_id = l.line_id
    JOIN   hrc_integration_key_map  m ON m.source_system_owner = r.key_source_owner
                                     AND m.source_system_id    = r.key_source_id
    WHERE  b.request_id = :P_LOAD_REQUEST_ID
    AND    m.object_name IN ('Profile', 'ProfileItem')
    AND    EXISTS (SELECT 1
                   FROM   hrc_dl_physical_lines p
                   WHERE  p.row_id = r.row_id
                   AND    p.validated_loaded_status = 'LOADED_SUCCESS')
    AND    (   (m.object_name = 'Profile'
                AND EXISTS (SELECT 1 FROM hrt_profiles_b x
                            WHERE x.profile_id = m.surrogate_id))
            OR (m.object_name = 'ProfileItem'
                AND EXISTS (SELECT 1 FROM hrt_profile_items x
                            WHERE x.profile_item_id = m.surrogate_id)))
    GROUP BY m.object_name, r.key_source_id
)
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
