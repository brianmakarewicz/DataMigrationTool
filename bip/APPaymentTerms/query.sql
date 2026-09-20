-- ============================================================
-- APPaymentTerms BIP reconciliation query — BIP reconciliation
-- report contract v1 (nine columns, keyset pagination). Data source:
-- ApplicationDB_FSCM. This MIRRORS the SQL embedded in
-- bip/APPaymentTerms/DMT_APTERMS_RECON_DM.xdm for review; the .xdm is
-- authoritative. Regenerate this file from the .xdm whenever the data
-- model changes — the mirror must never drift.
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
-- OBJECT / TRANSPORT: AP Payment Terms is a REST object (POST to the
-- standardTerms resource), so there is no interface table and no
-- Fusion load-request id. :P_LOAD_REQUEST_ID / :P_IMPORT_ESS_ID /
-- :P_PREFIX are declared for contract symmetry but do NOT select rows;
-- run-scoping is by :P_RUN_ID stamped into AP_TERMS_B.ATTRIBUTE1 at
-- load time, exactly as GLBalances scopes by GROUP_ID = :P_RUN_ID.
--
-- Base tables (confirmed live 2026-09-20, term 10134 "Net 30"):
--   Header AP_TERMS_B  (surrogate TERM_ID == REST TermId, ATTRIBUTE1);
--          the NAME is on the translation table AP_TERMS_TL (key NAME).
--   Line   AP_TERMS_LINES (natural key TERM_ID + SEQUENCE_NUM).
--
-- Key parts / nine-column mapping:
--   RECORD_KEY / SOURCE_REF = header: AP_TERMS_TL.NAME;
--                             line:   TERM_ID || '-' || SEQUENCE_NUM
--   FUSION_ID               = TERM_ID (real Fusion surrogate id)
--   DMT_REFERENCE           = AP_TERMS_B.ATTRIBUTE1 (DMT run reference)
--   FUSION_STATUS           = 'SUCCESS' (a base-table row is proof of
--                             load; REST rejections never reach the
--                             base table, so no ERROR rows appear here)
-- ============================================================
SELECT
    object_type, record_key, source_type, fusion_status,
    fusion_id, error_message, load_request_id, source_ref, dmt_reference
FROM (
    -- Tier: BASE — one row per AP_TERMS_B header stamped with this run
    -- in ATTRIBUTE1. NAME comes from the translation table.
    SELECT
        'PaymentTerms'                       AS object_type,
        tl.name                              AS record_key,
        'BASE'                               AS source_type,
        'SUCCESS'                            AS fusion_status,
        b.term_id                            AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))         AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)        AS load_request_id,
        tl.name                              AS source_ref,
        b.attribute1                         AS dmt_reference
    FROM   ap_terms_b  b
    JOIN   ap_terms_tl tl ON tl.term_id = b.term_id
                         AND tl.language = USERENV('LANG')
    WHERE  b.attribute1 = TO_CHAR(:P_RUN_ID)

    UNION ALL

    -- Tier: BASE_LINE — one row per AP_TERMS_LINES installment whose
    -- parent header belongs to this run. Keyed TERM_ID-SEQUENCE_NUM.
    SELECT
        'PaymentTerms'                                    AS object_type,
        TO_CHAR(l.term_id) || '-' || TO_CHAR(l.sequence_num)
                                                          AS record_key,
        'BASE_LINE'                                       AS source_type,
        'SUCCESS'                                         AS fusion_status,
        l.term_id                                         AS fusion_id,
        CAST(NULL AS VARCHAR2(4000))                      AS error_message,
        TO_NUMBER(:P_LOAD_REQUEST_ID)                     AS load_request_id,
        TO_CHAR(l.term_id) || '-' || TO_CHAR(l.sequence_num)
                                                          AS source_ref,
        b.attribute1                                      AS dmt_reference
    FROM   ap_terms_lines l
    JOIN   ap_terms_b     b ON b.term_id = l.term_id
    WHERE  b.attribute1 = TO_CHAR(:P_RUN_ID)
)
-- Keyset predicate. Empty P_AFTER_KEY (first page) binds NULL -> from the
-- start. Later pages carry the previous page's last RECORD_KEY; only
-- greater keys are returned.
WHERE  (:P_AFTER_KEY IS NULL OR record_key > :P_AFTER_KEY)
ORDER BY record_key
FETCH FIRST :P_CHUNK_SIZE ROWS ONLY
;
