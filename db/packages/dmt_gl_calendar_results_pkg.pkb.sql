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

        -- Do NOT mark rows LOADED — there is no automated load path.
        -- Rows remain in GENERATED status. After manual setup in Fusion,
        -- a future enhancement could verify via REST GET and mark LOADED.
        NULL;

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
