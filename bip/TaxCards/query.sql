-- DMT_TAX_CARD_RECON_DM query (Contract v1) for TaxCards (US tax-withholding
-- calculation cards, loaded via HCM Data Loader).
-- Mirror of the CDATA SQL in DMT_TAX_CARD_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the TaxCards HDL load: one row per migrated
-- calculation-card object positively confirmed in a Fusion HCM payroll base table,
-- with the real Fusion base-table id as FUSION_ID. HDL per-record failures are
-- captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this report runs),
-- so this report returns BASE/SUCCESS rows only; the shared parser marks a TaxCards
-- TFM row LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- The generator (DMT_TAX_CARD_HDL_GEN_PKG) emits two DAT discriminators; the loader
-- records each under its own OBJECT_NAME with its own SourceSystemId suffix:
--   HDL discriminator  OBJECT_NAME in map          SourceSystemId              base table / PK
--   CalculationCard    CalculationCard             PERSON_NUMBER||'_TAXCARD'   PAY_DIR_CARDS_F.DIR_CARD_ID
--   CardComponent      CalculationCardComponents   PERSON_NUMBER||'_TAXCOMP'   PAY_DIR_CARD_COMPONENTS_F.DIR_CARD_COMP_ID
-- Both tiers are surfaced with distinct OBJECT_TYPE so a multi-component card
-- reconciles per component.
--
-- Verified live 2026-09-20 (fin_impl, ApplicationDB_FSCM):
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME='CalculationCard'
--     SURROGATE_ID == PAY_DIR_CARDS_F.DIR_CARD_ID (base-table PK; round-trip proven)
--   HRC_INTEGRATION_KEY_MAP.OBJECT_NAME='CalculationCardComponents'
--     SURROGATE_ID == PAY_DIR_CARD_COMPONENTS_F.DIR_CARD_COMP_ID (base-table PK; round-trip proven)
-- Base-tier matching is by run prefix (P_PREFIX) scoped to SOURCE_SYSTEM_OWNER
-- 'HRC_SQLLOADER'; keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT m.object_name                   AS object_type,
           m.source_system_id              AS record_key,
           'BASE'                          AS source_type,
           'SUCCESS'                       AS fusion_status,
           MAX(m.surrogate_id)             AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))    AS error_message,
           :P_LOAD_REQUEST_ID              AS load_request_id,
           m.source_system_id              AS source_ref,
           CAST(NULL AS VARCHAR2(4000))    AS dmt_reference
    FROM   hrc_integration_key_map m
    WHERE  m.object_name IN ('CalculationCard', 'CalculationCardComponents')
    AND    m.source_system_owner = 'HRC_SQLLOADER'
    AND    m.source_system_id LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR m.source_system_id > :P_AFTER_KEY)
    GROUP BY m.object_name, m.source_system_id
    ORDER BY m.source_system_id
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
