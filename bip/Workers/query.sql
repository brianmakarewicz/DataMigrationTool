-- DMT_WORKER_RECON_DM query (Contract v1, design section 5, HDL note).
-- Mirror of the CDATA SQL in DMT_WORKER_RECON_DM.xdm, kept here for review and for
-- running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the Workers HDL load: one row per Workers HDL component
-- that Fusion actually persisted, positively confirmed in its HCM base table, with
-- the real Fusion base-table primary key as FUSION_ID. HDL per-record failures are
-- captured separately (DMT_HDL_UTIL_PKG.RECONCILE_HDL tags [FUSION_ERROR] before this
-- report runs), so this report returns BASE / SUCCESS rows only; the shared parser
-- marks a Worker component LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- THE JOIN: HDL stamps every loaded business object into HRC_INTEGRATION_KEY_MAP
--   (SOURCE_SYSTEM_ID, OBJECT_NAME, SURROGATE_ID). We drive off that map, scoped by
--   the run PREFIX on SOURCE_SYSTEM_ID, then confirm each SURROGATE_ID against its own
--   base table so a row is emitted only on real base-table proof. FUSION_ID =
--   SURROGATE_ID = the base primary key. OBJECT_TYPE = the HDL OBJECT_NAME.
--
--   RECORD_KEY = SOURCE_REF = SOURCE_SYSTEM_ID = the value written into Worker.dat as
--   SourceSystemId = the Worker TFM row's RECON_KEY. One key definition per object.
--
-- Verified live 2026-09-20 (loaded worker 10249RT-WKR-G1, run 309, prefix 10249):
--   Person          10249RT-WKR-G1      SURROGATE_ID 300000333822904 == PER_ALL_PEOPLE_F.PERSON_ID
--   PersonName      10249RT-WKR-G1_NME  SURROGATE_ID 300000333822907 == PER_PERSON_NAMES_F.PERSON_NAME_ID
--   PeriodOfService 10249RT-WKR-G1_POS  SURROGATE_ID 300000333822906 == PER_PERIODS_OF_SERVICE.PERIOD_OF_SERVICE_ID
--   PER_ALL_PEOPLE_F.PERSON_NUMBER == the Person SourceSystemId we wrote.
--
-- Keyset pagination by RECORD_KEY (P_AFTER_KEY); page size P_CHUNK_SIZE.
-- Assignment / WorkTerms branches are present for completeness but return zero rows
-- on this instance today (the WorkTerms generator emits a duplicate effective-date
-- change that fails those sections - objects/Workers/README.md).

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
    SELECT m.object_name                    AS object_type,
           m.source_system_id               AS record_key,
           'BASE'                           AS source_type,
           'SUCCESS'                        AS fusion_status,
           m.surrogate_id                   AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))     AS error_message,
           CAST(NULL AS VARCHAR2(60))       AS load_request_id,
           m.source_system_id               AS source_ref,
           CAST(NULL AS VARCHAR2(240))      AS dmt_reference
    FROM   hrc_integration_key_map m
    WHERE  :P_PREFIX IS NOT NULL
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.object_name IN ('Person','PersonName','PeriodOfService',
                             'Assignment','WorkTerms','WorkRelationship')
    AND    (
             (m.object_name = 'Person'
              AND EXISTS (SELECT 1 FROM per_all_people_f b
                          WHERE b.person_id = m.surrogate_id))
          OR (m.object_name = 'PersonName'
              AND EXISTS (SELECT 1 FROM per_person_names_f b
                          WHERE b.person_name_id = m.surrogate_id))
          OR (m.object_name IN ('PeriodOfService','WorkRelationship')
              AND EXISTS (SELECT 1 FROM per_periods_of_service b
                          WHERE b.period_of_service_id = m.surrogate_id))
          OR (m.object_name IN ('Assignment','WorkTerms')
              AND EXISTS (SELECT 1 FROM per_all_assignments_m b
                          WHERE b.assignment_id = m.surrogate_id))
           )
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
