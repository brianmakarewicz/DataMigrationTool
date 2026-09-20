-- PACKAGE DMT_REF_ID_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_REF_ID_PKG" AS
-- ============================================================
-- DMT_REF_ID_PKG  (backlog #12 -- the shared id-writer)
--
-- Pure PL/SQL. No Fusion, no HTTP, no ESS. Two jobs:
--
--   1. BUILD_REF -- assemble the run-scoped per-record reference string
--      that the generator stamps into Slot C (and, where the format is
--      COMPACT, into a short native field):
--        FULL     ->  DMT:<run_id>:<work_queue_id>:<tfm_seq_id>
--        COMPACT  ->  DMT:<tfm_seq_id>
--
--   2. GET_CARRIER (+ per-slot getters) -- read the carrier configuration
--      for one TFM table from DMT_REF_CARRIER_CFG_TBL, so the generator
--      knows WHERE to stamp and the reconciler knows WHERE to read back.
--
-- The only SQL in the body is one sanctioned SELECT against the config
-- table (no dynamic SQL). Everything else is string assembly.
-- ============================================================

    -- Reference prefix and format tokens (single source of truth).
    C_PREFIX   CONSTANT VARCHAR2(4)  := 'DMT';
    C_FMT_FULL    CONSTANT VARCHAR2(12) := 'FULL';
    C_FMT_COMPACT CONSTANT VARCHAR2(12) := 'COMPACT';

    -- Record view of one carrier-config row.
    TYPE t_carrier IS RECORD (
        found            BOOLEAN,
        cemli_code       VARCHAR2(60),
        sub_object       VARCHAR2(200),
        tfm_table        VARCHAR2(128),
        slot_a_field     VARCHAR2(128),
        slot_a_base_col  VARCHAR2(128),
        slot_b_field     VARCHAR2(128),
        slot_c_attribute VARCHAR2(60),
        slot_c_maxlen    NUMBER,
        ref_format       VARCHAR2(12),
        confidence       VARCHAR2(12),
        active_flag      VARCHAR2(1)
    );

    -- --------------------------------------------------------
    -- BUILD_REF
    -- Assemble the reference string for one record.
    --   p_run_id        -- the pipeline run id (the batch)
    --   p_work_queue_id -- the work-queue id (provenance)
    --   p_tfm_seq_id    -- the TFM row id (the per-record key)
    --   p_format        -- 'FULL' (default) or 'COMPACT'
    -- FULL     -> 'DMT:'||run||':'||wq||':'||tfm
    -- COMPACT  -> 'DMT:'||tfm
    -- Any format other than COMPACT is treated as FULL.
    -- --------------------------------------------------------
    FUNCTION BUILD_REF (
        p_run_id        IN NUMBER,
        p_work_queue_id IN NUMBER,
        p_tfm_seq_id    IN NUMBER,
        p_format        IN VARCHAR2 DEFAULT 'FULL'
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- GET_CARRIER
    -- Return the carrier config for one TFM table. The record's
    -- FOUND flag is TRUE when an ACTIVE row exists, FALSE otherwise
    -- (all other fields NULL). Case-insensitive on p_tfm_table.
    -- --------------------------------------------------------
    FUNCTION GET_CARRIER (
        p_tfm_table IN VARCHAR2
    ) RETURN t_carrier;

    -- --------------------------------------------------------
    -- Convenience getters (for callers where a record is awkward).
    -- Each returns NULL when no active row exists for the TFM table.
    -- GET_REF_FORMAT defaults to 'FULL' when unset/absent so callers
    -- can pass it straight into BUILD_REF.
    -- --------------------------------------------------------
    FUNCTION GET_SLOT_A_FIELD     (p_tfm_table IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION GET_SLOT_A_BASE_COL  (p_tfm_table IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION GET_SLOT_B_FIELD     (p_tfm_table IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION GET_SLOT_C_ATTRIBUTE (p_tfm_table IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION GET_REF_FORMAT       (p_tfm_table IN VARCHAR2) RETURN VARCHAR2;

END DMT_REF_ID_PKG;
/
