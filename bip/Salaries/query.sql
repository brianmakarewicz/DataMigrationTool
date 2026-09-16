-- DMT_SALARIES_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_SALARIES_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the Salary HDL load: one row per migrated salary
-- positively confirmed in the HCM compensation base table (CMP_SALARY), with the
-- real Fusion SALARY_ID as FUSION_ID. HDL per-record failures are captured
-- separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs), so this
-- report returns BASE/SUCCESS rows only; the shared parser marks a Salary LOADED
-- only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed PERSON_NUMBER || '_SAL' = the SourceSystemId written
-- into Salary.dat = the Salary TFM row's RECON_KEY. Verified live 2026-09-16:
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME  = 'Salary' (one map row per loaded salary)
--   HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID == the SourceSystemId we wrote
--   HRC_INTEGRATION_KEY_MAP.SURROGATE_ID     == CMP_SALARY.SALARY_ID (base-table id)
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'Salaries'                      AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'Salary'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_SAL' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
