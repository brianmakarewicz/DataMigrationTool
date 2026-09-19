-- ============================================================
-- APPaymentTerms BIP reconciliation query -- MIRROR of the deployed
-- data model bip/APPaymentTerms/DMT_APTERMS_RECON_DM.xdm (deploy target
-- /Custom/DMT2/APPaymentTerms/). The two SELECTs below are the byte-exact
-- CDATA bodies of that .xdm's two datasets; regenerate this file from the
-- .xdm whenever the data model changes -- the mirror must never drift.
--
-- New reconciliation standard (DMT_DESIGN.html, PROPOSED 2026-09):
-- reconciliation is a BIP report over the Fusion BASE tables, returning the
-- base-table surrogate id. A REST load-call HTTP 200 is NOT reconciliation.
-- For AP Payment Terms the header base table is AP_TERMS (surrogate TERM_ID,
-- == the standardTerms REST TermId) and the installment-line base table is
-- AP_TERMS_LINES (natural key TERM_ID + SEQUENCE_NUM).
--
-- Data source: ApplicationDB_FSCM
-- Parameters:
--   :P_TERM_NAMES = comma-delimited list of the header term names this run sent
--                   (e.g. 'Net 30,DMT2 recon BAD term'). Names are NOT run-
--                   prefixed, so the reconciler matches on the exact NAME values.
--   :P_TERM_IDS   = comma-delimited list of the base-table-confirmed header
--                   TERM_IDs (e.g. '10134'), used to confirm the installment
--                   lines that belong to those terms.
-- The comma-boundary INSTR match avoids substring false positives.
--
-- G_1 (BASE):      a row present in AP_TERMS is positive proof the term was
--                  created; FUSION_ID = TERM_ID.
-- G_2 (BASE_LINE): a row present in AP_TERMS_LINES for a confirmed TERM_ID is
--                  positive proof the installment line exists; the reconciler
--                  matches it to its TFM line by (confirmed TERM_ID, SEQUENCE_NUM).
-- Rows not returned were not created and are handled by the reconciler (FAILED
-- with the real REST error, else left unaccounted).
-- ============================================================

-- G_1: header confirmation over AP_TERMS by NAME
SELECT
    b.name                               AS record_key,
    'SUCCESS'                            AS import_status,
    'BASE'                               AS source_type,
    b.term_id                            AS fusion_id,
    CAST(NULL AS VARCHAR2(4000))         AS error_message
FROM   ap_terms b
WHERE  INSTR(',' || :P_TERM_NAMES || ',', ',' || b.name || ',') > 0
;

-- G_2: installment-line confirmation over AP_TERMS_LINES by confirmed TERM_ID
SELECT
    TO_CHAR(l.term_id) || '-' || TO_CHAR(l.sequence_num)   AS record_key,
    'SUCCESS'                                              AS import_status,
    'BASE_LINE'                                            AS source_type,
    l.term_id                                              AS fusion_id,
    l.sequence_num                                         AS sequence_num,
    CAST(NULL AS VARCHAR2(4000))                           AS error_message
FROM   ap_terms_lines l
WHERE  INSTR(',' || :P_TERM_IDS || ',', ',' || TO_CHAR(l.term_id) || ',') > 0
;
