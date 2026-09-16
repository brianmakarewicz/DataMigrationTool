-- PACKAGE DMT_RECON_CONTRACT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_RECON_CONTRACT_PKG" AS
-- ============================================================
-- DMT_RECON_CONTRACT_PKG  —  the ONE shared Contract v1 reconciliation parser.
-- ============================================================
-- Written once; every Contract-v1 object's BIP data model conforms to it
-- (design section 5, "BIP reconciliation report contract - v1"). Given a CEMLI
-- code, it reads that object's registry row from DMT_BIP_REPORT_TBL, runs the
-- object's Contract v1 report over BIP (shared transport DMT_UTIL_PKG.RUN_BIP_
-- REPORT), pages through the result with keyset pagination (P_AFTER_KEY loops
-- until a short page), and applies the SEVEN standard response columns to the
-- object's TFM table:
--
--   OBJECT_TYPE   RECORD_KEY   SOURCE_TYPE('BASE'|'INTERFACE')
--   FUSION_STATUS('SUCCESS'|'ERROR')   FUSION_ID   ERROR_MESSAGE   LOAD_REQUEST_ID
--
-- Outcome rules (identical to the gold-standard GL reconciler, generalized):
--   * BASE / SUCCESS / FUSION_ID NOT NULL  -> the RECON_KEY-matched TFM row is
--     LOADED and FUSION_ID is stamped into the registry-named FUSION_ID_COLUMN.
--   * BASE (or INTERFACE) / ERROR with a real ERROR_MESSAGE -> FAILED, the
--     message appended as '[FUSION_ERROR] ' || message (never composed).
--   * Everything else is left as-is for the shared [UNACCOUNTED] sweep.
--   * Zero report rows is never success (logged warning; rows left unaccounted).
--   * A SOAP fault / transport failure raises immediately (never a silent retry).
--
-- The parser reads ONLY the seven standard columns and the per-object
-- registration (CONTRACT_VERSION, TFM_TABLE, FUSION_ID_COLUMN, RECON_KEY_SQL) —
-- so a new object is a registry row plus a conforming data model, no new code.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(30) := 'DMT_RECON_CONTRACT_PKG';

    -- --------------------------------------------------------
    -- RECONCILE — run the object's Contract v1 report and apply the response.
    --
    --   p_cemli_code    the object registered in DMT_BIP_REPORT_TBL with
    --                   CONTRACT_VERSION = 1 (else raises -20090).
    --   p_run_id        the pipeline run id (Contract v1 P_RUN_ID).
    --   p_load_ess_id   the load job's request id (P_LOAD_REQUEST_ID). For HDL
    --                   objects this is the HDL data set request id.
    --   p_import_ess_id the import job's request id (P_IMPORT_ESS_ID, nullable).
    --   x_loaded        OUT count of TFM rows marked LOADED this call.
    --   x_failed        OUT count of TFM rows marked FAILED this call.
    --
    -- Does NOT commit — the caller owns the transaction boundary.
    -- --------------------------------------------------------
    PROCEDURE RECONCILE (
        p_cemli_code    IN  VARCHAR2,
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER   DEFAULT NULL,
        p_import_ess_id IN  NUMBER   DEFAULT NULL,
        x_loaded        OUT NUMBER,
        x_failed        OUT NUMBER
    );

    -- Convenience overload (no OUT counts) for callers that only need the effect.
    PROCEDURE RECONCILE (
        p_cemli_code    IN  VARCHAR2,
        p_run_id        IN  NUMBER,
        p_load_ess_id   IN  NUMBER   DEFAULT NULL,
        p_import_ess_id IN  NUMBER   DEFAULT NULL
    );

END DMT_RECON_CONTRACT_PKG;
/
