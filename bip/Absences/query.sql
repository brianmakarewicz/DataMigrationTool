-- DMT_ABSENCES_RECON_V2_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_ABSENCES_RECON_V2_DM.xdm (the registered
-- version), kept here for review and for running the query standalone against
-- live Fusion (bind the six parameters). The original data model
-- (DMT_ABSENCES_RECON_DM.xdm in the repo) stays deployed; BIP objects are never
-- overwritten. Backlog #293.
--
-- Absences HDL load (PersonAbsenceEntry.dat). Rows are selected by the HDL
-- request id (P_LOAD_REQUEST_ID = the data set RequestId), never by the run
-- prefix: HRC_DL_DATA_SET_BUS_OBJS -> HRC_DL_FILE_LINES -> HRC_DL_FILE_ROWS gives
-- each SourceSystemOwner + SourceSystemId this load sent; each is joined to
-- HRC_INTEGRATION_KEY_MAP on its own owner and id (key-map object
-- PersonAbsenceEntry) and returned only when this load's physical line finished
-- LOADED_SUCCESS and the surrogate exists in ANC_PER_ABS_ENTRIES.
--
-- RECORD_KEY = SOURCE_REF = the SourceSystemId the generator wrote, which is the
-- absence's own TFM sequence id; FUSION_ID = PER_ABSENCE_ENTRY_ID.

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
    SELECT 'Absences'                        AS object_type,
           r.key_source_id                   AS record_key,
           'BASE'                            AS source_type,
           'SUCCESS'                         AS fusion_status,
           MAX(e.per_absence_entry_id)       AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))      AS error_message,
           :P_LOAD_REQUEST_ID                AS load_request_id,
           r.key_source_id                   AS source_ref,
           CAST(NULL AS VARCHAR2(240))       AS dmt_reference
    FROM   hrc_dl_data_set_bus_objs b
    JOIN   hrc_dl_file_lines        l ON l.data_set_bus_obj_id = b.data_set_bus_obj_id
    JOIN   hrc_dl_file_rows         r ON r.line_id = l.line_id
    JOIN   hrc_integration_key_map  m ON m.source_system_owner = r.key_source_owner
                                     AND m.source_system_id    = r.key_source_id
    JOIN   anc_per_abs_entries      e ON e.per_absence_entry_id = m.surrogate_id
    WHERE  b.request_id = :P_LOAD_REQUEST_ID
    AND    m.object_name = 'PersonAbsenceEntry'
    AND    EXISTS (SELECT 1
                   FROM   hrc_dl_physical_lines p
                   WHERE  p.row_id = r.row_id
                   AND    p.validated_loaded_status = 'LOADED_SUCCESS')
    GROUP BY r.key_source_id
)
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
