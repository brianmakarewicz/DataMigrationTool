-- DMT_ABSENCES_RECON_DM query (Contract v1, design section 5, nine-column keyset).
-- Mirror of the CDATA SQL in DMT_ABSENCES_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- BASE-tier-only HDL report: one row per migrated absence entry positively
-- confirmed in the HCM absence-entry base table ANC_PER_ABS_ENTRIES, with the
-- real Fusion PER_ABSENCE_ENTRY_ID as FUSION_ID. HDL per-record failures are
-- captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this report
-- runs), so this report returns BASE/SUCCESS rows only; the shared parser marks
-- an Absence LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- Nine response columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS, FUSION_ID,
--   ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF, DMT_REFERENCE.
-- ERROR_MESSAGE, LOAD_REQUEST_ID and DMT_REFERENCE are null on every
-- BASE/SUCCESS row; SOURCE_REF echoes the SourceSystemId.
--
-- RECORD_KEY = HRC_INTEGRATION_KEY_MAP.SOURCE_SYSTEM_ID = the exact
-- SourceSystemId written into PersonAbsenceEntry.dat (DMT_ABSENCE_HDL_GEN_PKG)
-- = the Absence TFM row's RECON_KEY. An absence entry has NO business column on
-- ANC_PER_ABS_ENTRIES, so the tie from our written SourceSystemId to the base
-- row is the HCM integration key map. Verified live 2026-09-20 (fin_impl):
--   HRC_INTEGRATION_KEY_MAP OBJECT_NAME='PersonAbsenceEntry' has 8701 rows,
--     every one joining SURROGATE_ID = ANC_PER_ABS_ENTRIES.PER_ABSENCE_ENTRY_ID.
--   DMT-migrated entries present with SourceSystemId LIKE
--     '<numeric-prefix>DMTABS<seq>' (e.g. 15886DMTABS001), each joining to a
--     real PER_ABSENCE_ENTRY_ID (e.g. 300000331553437).
-- Base-tier matching is by run prefix (P_PREFIX) on SOURCE_SYSTEM_ID; keyset
-- pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT 'Absences'                      AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(e.per_absence_entry_id)     AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           CAST(NULL AS NUMBER)            AS load_request_id,
           m.source_system_id              AS source_ref,
           CAST(NULL AS VARCHAR2(240))     AS dmt_reference
    FROM   hrc_integration_key_map m
    JOIN   anc_per_abs_entries e
           ON e.per_absence_entry_id = m.surrogate_id
    WHERE  m.object_name = 'PersonAbsenceEntry'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    GROUP BY m.source_system_id
)
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY;
