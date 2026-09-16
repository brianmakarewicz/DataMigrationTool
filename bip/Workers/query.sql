-- DMT_WORKERS_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_WORKERS_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the Workers HDL load: one row per migrated worker
-- positively confirmed in the HCM person base table PER_ALL_PEOPLE_F, with the
-- real Fusion PERSON_ID as FUSION_ID. HDL per-record failures are captured
-- separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so this
-- report returns BASE/SUCCESS rows only; the shared parser marks a Worker LOADED
-- only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed PERSON_NUMBER = the SourceSystemId written into
-- Worker.dat = the Worker TFM row's RECON_KEY. Verified live 2026-09-16:
--   PER_ALL_PEOPLE_F.PERSON_NUMBER          == the SourceSystemId we wrote
--   HRC_INTEGRATION_KEY_MAP.SURROGATE_ID    == PER_ALL_PEOPLE_F.PERSON_ID
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'Workers'                       AS object_type,
           p.person_number                 AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(p.person_id)                AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   per_all_people_f p
    WHERE  p.person_number LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR p.person_number > :P_AFTER_KEY)
    GROUP BY p.person_number
    ORDER BY p.person_number
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
