-- ============================================================
-- TaxConfig BIP reconciliation query — BIP reconciliation
-- report contract v1 (nine columns, keyset pagination).
-- Data source: ApplicationDB_FSCM. This mirrors the SQL embedded
-- in DMT_ZX_RECON_DM.xdm for review; the .xdm is authoritative.
-- Regenerate this file from the .xdm whenever the DM changes — the
-- mirror must never drift.
--
-- NINE columns, in contract order:
--   OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
--   FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF,
--   DMT_REFERENCE
--
-- SIX parameters: P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
--   P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY. No P_OFFSET / P_LIMIT.
--
-- Keyset: ORDER BY RECORD_KEY, only rows whose RECORD_KEY sorts
-- after :P_AFTER_KEY, at most :P_CHUNK_SIZE per page.
--
-- TaxConfig is a REST-loaded, two-tier CONFIGURATION object (no
-- FBDI/ESS load job, no interface table). Reconciliation is a
-- read-back over the two Fusion BASE tables; a row present is
-- positive proof the config record was created. OBJECT_TYPE
-- discriminates the tiers (TaxRegime / TaxRate); they are UNION
-- ALLed and paged together by RECORD_KEY.
--
-- Scoping: a REST config table has no ESS load-request or run
-- column, so the run is identified by the DMT reference written to
-- ATTRIBUTE1. :P_PREFIX restricts read-back to this run's rows
-- (ATTRIBUTE1 LIKE :P_PREFIX || '%'); empty :P_PREFIX = all rows.
-- :P_LOAD_REQUEST_ID is echoed into LOAD_REQUEST_ID.
--
-- FUSION_STATUS is SUCCESS on every row (base-table presence =
-- proof); ERROR_MESSAGE is always NULL. Records that never landed
-- are absent here and handled by the REST reconciler.
--
-- Keys:
--   RECORD_KEY / SOURCE_REF = TAX_REGIME_CODE / TAX_RATE_CODE
--   DMT_REFERENCE           = ATTRIBUTE1 (DMT run reference)
--   FUSION_ID               = TAX_REGIME_ID / TAX_RATE_ID
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    SELECT
        'TaxRegime'                          AS object_type,
        b.tax_regime_code                    AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        b.tax_regime_id                      AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        b.tax_regime_code                    AS source_ref,
        b.attribute1                         AS dmt_reference
    FROM   zx_regimes_b b
    WHERE  (:P_PREFIX IS NULL OR b.attribute1 LIKE :P_PREFIX || '%')

    UNION ALL

    SELECT
        'TaxRate'                            AS object_type,
        r.tax_rate_code                      AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        r.tax_rate_id                        AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        r.tax_rate_code                      AS source_ref,
        r.attribute1                         AS dmt_reference
    FROM   zx_rates_b r
    WHERE  (:P_PREFIX IS NULL OR r.attribute1 LIKE :P_PREFIX || '%')
)
-- Keyset predicate. Empty P_AFTER_KEY (first page) binds to NULL in BIP,
-- so treat NULL as "from the start". On later pages it carries the
-- previous page's last RECORD_KEY; only greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
