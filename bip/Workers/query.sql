-- DMT_WORKERS_RECON_V2_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_WORKERS_RECON_V2_DM.xdm (the registered
-- version), kept here for review and for running the query standalone against
-- live Fusion (bind the six parameters). V1 (DMT_WORKERS_RECON_DM.xdm) stays
-- deployed and in the repo; BIP objects are never overwritten. Backlog #289.
--
-- Person tiers of the Workers HDL load. Rows are selected by the HDL request id
-- (P_LOAD_REQUEST_ID = the data set RequestId), never by the run prefix:
-- HRC_DL_DATA_SET_BUS_OBJS -> HRC_DL_FILE_LINES -> HRC_DL_FILE_ROWS gives each
-- SourceSystemOwner + SourceSystemId this load sent; each is joined to
-- HRC_INTEGRATION_KEY_MAP on its own owner and id and returned only when this
-- load's physical line finished LOADED_SUCCESS and the surrogate exists in the
-- component's own base table. Every component is proven on its own row:
--   Person                -> PER_ALL_PEOPLE_F.PERSON_ID
--   PersonName            -> PER_PERSON_NAMES_F.PERSON_NAME_ID
--   EmailAddress          -> PER_EMAIL_ADDRESSES.EMAIL_ADDRESS_ID
--   Phone                 -> PER_PHONES.PHONE_ID
--   Address               -> PER_ADDRESSES_F.ADDRESS_ID
--   NationalIdentifier    -> PER_NATIONAL_IDENTIFIERS.NATIONAL_IDENTIFIER_ID
--   PersonLegislativeInfo -> PER_PEOPLE_LEGISLATIVE_F.PERSON_LEGISLATIVE_ID
-- The work relationship and assignment tiers are proven by
-- DMT_ASSIGNMENTS_RECON_V2_DM.
--
-- Proven read-only on 2026-10-07 against request 10070511 (run 238): returns
-- Person 93294RT-WKR-G1 and PersonName 93294RT-WKR-G1_NME with their ids.

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
    SELECT m.object_name                     AS object_type,
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
    AND    m.object_name IN ('Person', 'PersonName', 'EmailAddress', 'Phone',
                             'Address', 'PersonAddress', 'NationalIdentifier',
                             'PersonLegislativeInfo')
    AND    EXISTS (SELECT 1
                   FROM   hrc_dl_physical_lines p
                   WHERE  p.row_id = r.row_id
                   AND    p.validated_loaded_status = 'LOADED_SUCCESS')
    AND    (   (m.object_name = 'Person'
                AND EXISTS (SELECT 1 FROM per_all_people_f x
                            WHERE x.person_id = m.surrogate_id))
            OR (m.object_name = 'PersonName'
                AND EXISTS (SELECT 1 FROM per_person_names_f x
                            WHERE x.person_name_id = m.surrogate_id))
            OR (m.object_name = 'EmailAddress'
                AND EXISTS (SELECT 1 FROM per_email_addresses x
                            WHERE x.email_address_id = m.surrogate_id))
            OR (m.object_name = 'Phone'
                AND EXISTS (SELECT 1 FROM per_phones x
                            WHERE x.phone_id = m.surrogate_id))
            OR (m.object_name IN ('Address', 'PersonAddress')
                AND EXISTS (SELECT 1 FROM per_addresses_f x
                            WHERE x.address_id = m.surrogate_id))
            OR (m.object_name = 'NationalIdentifier'
                AND EXISTS (SELECT 1 FROM per_national_identifiers x
                            WHERE x.national_identifier_id = m.surrogate_id))
            OR (m.object_name = 'PersonLegislativeInfo'
                AND EXISTS (SELECT 1 FROM per_people_legislative_f x
                            WHERE x.person_legislative_id = m.surrogate_id)))
    GROUP BY m.object_name, r.key_source_id
)
WHERE  (:P_AFTER_KEY IS NULL
        OR NLSSORT(record_key, 'NLS_SORT=BINARY') > NLSSORT(:P_AFTER_KEY, 'NLS_SORT=BINARY'))
ORDER BY NLSSORT(record_key, 'NLS_SORT=BINARY')
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
