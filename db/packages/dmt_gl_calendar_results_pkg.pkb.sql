-- PACKAGE BODY DMT_GL_CALENDAR_RESULTS_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_CALENDAR_RESULTS_PKG" AS
-- ============================================================
-- DMT_GL_CALENDAR_RESULTS_PKG Body
-- GL Calendar cannot be loaded via REST or FBDI. Calendars
-- must be configured via Setup and Maintenance > Manage
-- Accounting Calendars. The generated FBL file serves as a
-- reference for manual setup. Rows remain at GENERATED status.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_CALENDAR_RESULTS_PKG';

    -- --------------------------------------------------------
    -- PROMOTE_LOADED (standard LOADED-promotion shape -- STUB)
    -- Every results package carries one dedicated LOADED-promotion procedure of the
    -- standard shape (design: "Standard LOADED-promotion shape"; conformant reference
    -- DMT_CUST_RESULTS_PKG). This one is a STUB.
    -- STUB: GL Calendar has no reachable Fusion surrogate id and no automated load
    -- path -- accounting calendars are configured manually in Setup and Maintenance >
    -- Manage Accounting Calendars, never loaded via REST/FBDI. There is no base table
    -- to reconcile against and no FUSION_*_ID to capture, so no row is ever promoted
    -- to LOADED here (rows stay GENERATED; see RECONCILE_BATCH). Present so the shape
    -- reads identically package-to-package and the reviewer sees an explicit stub,
    -- never a missing proc.
    -- --------------------------------------------------------
    PROCEDURE PROMOTE_LOADED (
        p_run_id IN NUMBER
    ) IS
    BEGIN
        NULL; -- STUB: no Fusion surrogate id, no automated load path; nothing to promote.
    END PROMOTE_LOADED;

    PROCEDURE RECONCILE_BATCH (
        p_run_id IN NUMBER
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'RECONCILE_BATCH';
        l_gen_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_gen_count
        FROM   DMT_GL_CALENDAR_TFM_TBL
        WHERE  RUN_ID = p_run_id
        AND    TFM_STATUS = 'GENERATED';

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GL Calendar cannot be loaded via REST or FBDI on this instance. '
                                || 'Calendars must be configured via Setup and Maintenance > '
                                || 'Manage Accounting Calendars. The generated FBL file can be '
                                || 'used as a reference for manual setup. '
                                || l_gen_count || ' rows left at GENERATED status.',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        -- LOADED promotion goes through the one standard per-package procedure.
        -- For GL Calendar it is a stub (no Fusion surrogate id, no automated load
        -- path), so nothing is promoted and rows remain GENERATED. After manual
        -- setup in Fusion, a future enhancement could verify via REST GET.
        PROMOTE_LOADED(p_run_id => p_run_id);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'RECONCILE_BATCH failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END RECONCILE_BATCH;

END DMT_GL_CALENDAR_RESULTS_PKG;
/
