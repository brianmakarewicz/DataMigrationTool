-- DMT_PAYROLLRELATIONSHIPS_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_PAYROLLRELATIONSHIPS_RECON_DM.xdm, kept here for
-- review and for running the query standalone against live Fusion (bind the six
-- parameters).
--
-- Returns the BASE tier for the PayrollRelationship HDL load: one row per migrated
-- payroll relationship positively confirmed in the HCM payroll base table
-- (PAY_PAY_RELATIONSHIPS_F), with the real Fusion PAYROLL_RELATIONSHIP_ID as
-- FUSION_ID. HDL per-record failures are captured separately (RECONCILE_HDL tags
-- [FUSION_ERROR] before this report runs), so this report returns BASE/SUCCESS rows
-- only; the shared parser marks a PayrollRelationship LOADED only from a
-- BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed PERSON_NUMBER || '_PAYREL' = the SourceSystemId written
-- into PayrollRelationship.dat = the TFM row's RECON_KEY. Verified live 2026-09-16
-- against the demo instance (fin_impl):
--   HRC_INTEGRATION_KEY_MAP.SURROGATE_ID == PAY_PAY_RELATIONSHIPS_F.PAYROLL_RELATIONSHIP_ID
--     (join proven on live rows: SURROGATE_ID is a real base-table id).
--   HRC_SQLLOADER-owned map rows use the HDL metadata component name as OBJECT_NAME
--     (Salary, SalaryBasis, WorkPattern, PersonName, ...), so a PayrollRelationship
--     load registers OBJECT_NAME = 'PayrollRelationship'.
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'PayrollRelationships'          AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'PayrollRelationship'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_PAYREL' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
