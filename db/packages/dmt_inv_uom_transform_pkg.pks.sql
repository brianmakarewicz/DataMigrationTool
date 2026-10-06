-- PACKAGE DMT_INV_UOM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_INV_UOM_TRANSFORM_PKG" AUTHID DEFINER AS
-- ============================================================
-- DMT_INV_UOM_TRANSFORM_PKG
-- Transforms Units of Measure from STG to TFM.
-- Standalone object, no parent/child relationship.
-- ============================================================

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    );

    -- --------------------------------------------------------
    -- DERIVE_UOM_CODE  (run-prefix form for a 3-character key)
    -- Every DMT data object applies the run PREFIX to its user-facing
    -- unique key so a scenario can be re-loaded run after run without
    -- colliding with what earlier runs created. The Fusion UOM code is
    -- limited to 3 characters (unitsOfMeasure REST describe: UOMCode
    -- maxLength 3; INV_UNITS_OF_MEASURE_B holds only 1-3 char codes), so
    -- the full numeric prefix can never be prepended and must NOT be
    -- truncated into a collision. Instead the code is derived
    -- deterministically from (prefix, ordinal of the row in this run):
    --
    --   n    = MOD(prefix * C_UOM_SLOTS + (ordinal - 1), 8 * 1296)
    --   code = LEAD(TRUNC(n / 1296)) || BASE36(TRUNC(MOD(n,1296) / 36))
    --                                || BASE36(MOD(n, 36))
    --   LEAD = '12345679' -- leading digits NOT used by any seeded Fusion
    --          UOM code (the pod has codes starting 0 and 8 only), so a
    --          derived code never collides with seeded data.
    --
    -- Guarantees: unique within a run for up to 10,368 UOMs; unique
    -- across consecutive prefixes while a run carries <= C_UOM_SLOTS (4)
    -- UOMs, i.e. the code space wraps only after 2,592 prefixes. A
    -- collision past those bounds is never silent: Fusion rejects the
    -- duplicate code and the row lands FAILED with that real error.
    -- The UOM NAME (25 chars) carries the full prefix, so the run that
    -- created a UOM stays identifiable. NULL prefix (production cutover)
    -- returns the source code unchanged.
    -- --------------------------------------------------------
    FUNCTION DERIVE_UOM_CODE (
        p_prefix      IN VARCHAR2,
        p_ordinal     IN NUMBER,
        p_source_code IN VARCHAR2
    ) RETURN VARCHAR2 DETERMINISTIC;

END DMT_INV_UOM_TRANSFORM_PKG;
/
