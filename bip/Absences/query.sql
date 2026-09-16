-- DMT_ABSENCES_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_ABSENCES_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the Absences HDL load: one row per migrated absence
-- entry positively confirmed in the HCM absence-entry base table
-- ANC_PER_ABS_ENTRIES, with the real Fusion PER_ABSENCE_ENTRY_ID as FUSION_ID.
-- HDL per-record failures are captured separately (RECONCILE_HDL tags
-- [FUSION_ERROR] before this report runs), so this report returns BASE/SUCCESS
-- rows only; the shared parser marks an Absence LOADED only from a
-- BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the SourceSystemId written into PersonAbsenceEntry.dat =
--   PERSON_NUMBER || '_ABS' (DMT_ABSENCE_HDL_GEN_PKG) = the Absence TFM row's
--   RECON_KEY. An absence entry has NO business column on ANC_PER_ABS_ENTRIES, so
--   the tie from our written SourceSystemId to the base row is the HCM
--   integration key map. Verified live 2026-09-16 (fin_impl):
--     HRC_INTEGRATION_KEY_MAP has 8701 rows for OBJECT_NAME='PersonAbsenceEntry',
--       == COUNT(*) of ANC_PER_ABS_ENTRIES (8701).
--     SURROGATE_ID       == ANC_PER_ABS_ENTRIES.PER_ABSENCE_ENTRY_ID (8701 joined).
--     SOURCE_SYSTEM_ID   == the SourceSystemId we wrote (LIKE <prefix>||'%').
-- Base-tier matching is by run prefix (P_PREFIX) on SOURCE_SYSTEM_ID; keyset
-- pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'Absences'                      AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(e.per_absence_entry_id)     AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    JOIN   anc_per_abs_entries e
           ON e.per_absence_entry_id = m.surrogate_id
    WHERE  m.object_name = 'PersonAbsenceEntry'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
