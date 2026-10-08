-- DMT_ASSIGNMENTS_RECON_V2_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_ASSIGNMENTS_RECON_V2_DM.xdm (the registered
-- version), kept here for review and for running the query standalone against
-- live Fusion (bind the six parameters). V1 (DMT_ASSIGNMENTS_RECON_DM.xdm) stays
-- deployed and in the repo; BIP objects are never overwritten.
--
-- Work relationship and assignment tiers of the Workers HDL load. Rows are
-- selected by the HDL request id (P_LOAD_REQUEST_ID = the data set RequestId),
-- never by the run prefix: HRC_DL_DATA_SET_BUS_OBJS -> HRC_DL_FILE_LINES ->
-- HRC_DL_FILE_ROWS gives each SourceSystemOwner + SourceSystemId this load sent;
-- each is joined to HRC_INTEGRATION_KEY_MAP on its own owner and id (no owner
-- literal: the owner is per DMT instance, backlog #287), and returned only when
-- this load's physical line finished LOADED_SUCCESS and the surrogate exists in
-- the base table.
--
--   'WorkRelationship' (key-map PeriodOfService) -> PER_PERIODS_OF_SERVICE,
--       FUSION_ID = PERSON_ID, RECORD_KEY '<person>_POS'.
--   'Assignment'       (key-map Assignment)      -> PER_ALL_ASSIGNMENTS_M,
--       FUSION_ID = ASSIGNMENT_ID, RECORD_KEY '<assignment>_ASG' / '_TRM'.
--
-- Proven read-only on 2026-10-07 against request 10070511 (run 238): returns
-- the G1 / G1B _ASG and _TRM rows and 93294RT-WKR-G1_POS; the rejected BASG
-- lines (UNPROCESSED) are not returned.

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
    SELECT DECODE(m.object_name, 'PeriodOfService', 'WorkRelationship', m.object_name) AS object_type,
           r.key_source_id                   AS record_key,
           'BASE'                            AS source_type,
           'SUCCESS'                         AS fusion_status,
           MAX(DECODE(m.object_name, 'PeriodOfService', pos.person_id, a.assignment_id)) AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))      AS error_message,
           :P_LOAD_REQUEST_ID                AS load_request_id,
           r.key_source_id                   AS source_ref,
           CAST(NULL AS VARCHAR2(240))       AS dmt_reference
    FROM   hrc_dl_data_set_bus_objs b
    JOIN   hrc_dl_file_lines        l   ON l.data_set_bus_obj_id = b.data_set_bus_obj_id
    JOIN   hrc_dl_file_rows         r   ON r.line_id = l.line_id
    JOIN   hrc_integration_key_map  m   ON m.source_system_owner = r.key_source_owner
                                       AND m.source_system_id    = r.key_source_id
    LEFT JOIN per_periods_of_service pos ON m.object_name = 'PeriodOfService'
                                        AND pos.period_of_service_id = m.surrogate_id
    LEFT JOIN per_all_assignments_m  a   ON m.object_name = 'Assignment'
                                        AND a.assignment_id = m.surrogate_id
    WHERE  b.request_id = :P_LOAD_REQUEST_ID
    AND    m.object_name IN ('PeriodOfService', 'Assignment')
    AND    EXISTS (SELECT 1
                   FROM   hrc_dl_physical_lines p
                   WHERE  p.row_id = r.row_id
                   AND    p.validated_loaded_status = 'LOADED_SUCCESS')
    GROUP BY m.object_name, r.key_source_id
)
WHERE  fusion_id IS NOT NULL
AND    (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
