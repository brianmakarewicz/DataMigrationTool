-- DMT_TAXCARDS_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_TAXCARDS_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the TaxCards HDL load. TaxCards loads via HDL as TWO
-- objects out of one .dat submission: CalculationCard (the tax/deduction card) and
-- CalculationCardComponents (its components). One report serves both tiers by
-- OBJECT_TYPE (design section 5: OBJECT_TYPE is the sub-object discriminator that
-- "lets one report serve headers/lines/children"). Each tier is one row per
-- migrated record positively confirmed in the Fusion HR calculation-card base
-- tables, with the real Fusion base-table id as FUSION_ID:
--   CalculationCard            -> PAY_DIR_CARDS_F.DIR_CARD_ID
--   CalculationCardComponents  -> PAY_DIR_CARD_COMPONENTS_F.DIR_CARD_COMP_ID
-- Matching uses HRC_INTEGRATION_KEY_MAP (the same pattern as Salaries): the HDL
-- load records one map row per loaded record whose SOURCE_SYSTEM_ID is the
-- SourceSystemId we wrote and whose SURROGATE_ID is the base-table id. HDL
-- per-record failures are captured separately (RECONCILE_HDL tags [FUSION_ERROR]
-- before this report runs), so this report returns BASE/SUCCESS rows only; the
-- shared parser marks a TaxCards row LOADED only from a BASE / SUCCESS /
-- FUSION_ID-not-null row.
--
-- RECORD_KEY = the SourceSystemId written into the .dat = the TFM row's RECON_KEY.
-- For CalculationCard that is (prefixed PERSON_NUMBER) || '_TAXCARD'; for
-- CalculationCardComponents it is (prefixed PERSON_NUMBER) || '_TAXCOMP'.
-- Verified live 2026-09-16 (fin_impl):
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME = 'CalculationCard'           -> 5508 rows
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME = 'CalculationCardComponents' -> 16563 rows
--   all CalculationCard surrogate_ids join PAY_DIR_CARDS_F.DIR_CARD_ID (5508/5508)
--   all Component surrogate_ids join PAY_DIR_CARD_COMPONENTS_F.DIR_CARD_COMP_ID (16562/16563)
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    -- CalculationCard tier: SourceSystemId ends in '_TAXCARD'.
    SELECT 'CalculationCard'                AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'CalculationCard'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_TAXCARD' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    UNION ALL
    -- CalculationCardComponents tier: SourceSystemId ends in '_TAXCOMP'.
    SELECT 'CalculationCardComponents'     AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id
    FROM   hrc_integration_key_map m
    WHERE  m.object_name = 'CalculationCardComponents'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    m.source_system_id LIKE '%\_TAXCOMP' ESCAPE '\'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.source_system_id
    ORDER BY record_key
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
