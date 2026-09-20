-- ============================================================
-- Taxes BIP reconciliation query -- MIRROR of the deployed data model
-- bip/Taxes/DMT_ZX_RECON_DM.xdm (deploy target /Custom/DMT2/Taxes/). The two
-- SELECTs below are the byte-exact CDATA bodies of that .xdm's two datasets;
-- regenerate this file from the .xdm whenever the data model changes -- the
-- mirror must never drift.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation is a BIP report over the Fusion BASE tables, returning the
-- base-table surrogate id. A REST load-call HTTP 200 is NOT reconciliation.
-- Taxes is a two-tier config load:
--   Tier 1 (regimes): base table ZX_REGIMES_B, surrogate TAX_REGIME_ID,
--                      natural key TAX_REGIME_CODE (== the REST taxRegimes key).
--   Tier 2 (rates):   base table ZX_RATES_B, surrogate TAX_RATE_ID,
--                      natural key TAX_RATE_CODE (== the REST taxRates key).
--
-- Data source: ApplicationDB_FSCM
-- Parameters:
--   :P_REGIME_CODES = comma-delimited list of the regime codes this run sent
--                     (e.g. 'AU GST TAX,DMT2 recon BAD regime'). Codes are NOT
--                     run-prefixed, so the reconciler matches on the exact codes.
--   :P_RATE_CODES   = comma-delimited list of the rate codes this run sent.
-- The comma-boundary INSTR match avoids substring false positives.
--
-- G_1 (BASE_REGIME): a row present in ZX_REGIMES_B is positive proof the regime
--                    exists; FUSION_ID = TAX_REGIME_ID.
-- G_2 (BASE_RATE):   a row present in ZX_RATES_B is positive proof the rate
--                    exists; FUSION_ID = TAX_RATE_ID.
-- Rows not returned were not created and are handled by the reconciler (FAILED
-- with the real REST error, else left unaccounted).
-- ============================================================

-- G_1: regime confirmation over ZX_REGIMES_B by TAX_REGIME_CODE
SELECT
    b.tax_regime_code                    AS record_key,
    'SUCCESS'                            AS import_status,
    'BASE_REGIME'                        AS source_type,
    b.tax_regime_id                      AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   zx_regimes_b b
WHERE  INSTR(',' || :P_REGIME_CODES || ',', ',' || b.tax_regime_code || ',') > 0
;

-- G_2: rate confirmation over ZX_RATES_B by TAX_RATE_CODE
SELECT
    r.tax_rate_code                      AS record_key,
    'SUCCESS'                            AS import_status,
    'BASE_RATE'                          AS source_type,
    r.tax_rate_id                        AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   zx_rates_b r
WHERE  INSTR(',' || :P_RATE_CODES || ',', ',' || r.tax_rate_code || ',') > 0
;
