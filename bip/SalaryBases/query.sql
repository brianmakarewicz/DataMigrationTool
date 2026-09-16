-- DMT_SALARYBASES_RECON_DM query (Contract v1, design section 5).
-- Mirror of the CDATA SQL in DMT_SALARYBASES_RECON_DM.xdm, kept here for review and
-- for running the query standalone against live Fusion (bind the six parameters).
--
-- Returns the BASE tier for the SalaryBases HDL load: one row per migrated salary
-- basis positively confirmed in the HCM compensation setup base table
-- CMP_SALARY_BASES, with the real Fusion SALARY_BASIS_ID as FUSION_ID. HDL per-record
-- failures are captured separately (RECONCILE_HDL tags [FUSION_ERROR] before this
-- report runs), so this report returns BASE/SUCCESS rows only; the shared parser
-- marks a SalaryBases row LOADED only from a BASE / SUCCESS / FUSION_ID-not-null row.
--
-- RECORD_KEY = the prefixed SALARY_BASIS_NAME = the SourceSystemId written into
-- SalaryBasis.dat = the SalaryBases TFM row's RECON_KEY. Verified live 2026-09-16:
--   CMP_SALARY_BASES.NAME             == the SourceSystemId / SalaryBasisName we wrote
--   CMP_SALARY_BASES.SALARY_BASIS_ID  == the Fusion-assigned salary basis id
-- Base-tier matching is by run prefix (P_PREFIX); keyset pagination by RECORD_KEY.

SELECT object_type, record_key, source_type, fusion_status,
       fusion_id, error_message, load_request_id
FROM (
    SELECT 'SalaryBases'                    AS object_type,
           b.name                           AS record_key,
           'BASE'                           AS source_type,
           'SUCCESS'                        AS fusion_status,
           MAX(b.salary_basis_id)           AS fusion_id,
           CAST(NULL AS VARCHAR2(4000))     AS error_message,
           :P_LOAD_REQUEST_ID               AS load_request_id
    FROM   cmp_salary_bases b
    WHERE  b.name LIKE :P_PREFIX || '%'
    AND    (:P_AFTER_KEY IS NULL OR b.name > :P_AFTER_KEY)
    GROUP BY b.name
    ORDER BY b.name
)
WHERE ROWNUM <= :P_CHUNK_SIZE;
