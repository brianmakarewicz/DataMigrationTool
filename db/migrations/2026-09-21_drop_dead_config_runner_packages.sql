-- ----------------------------------------------------------------------
-- Migration 2026-09-21: drop three dead orchestration runner packages
-- (backlog #15). These *_RUNNER_PKG packages are the retired stand-alone
-- config orchestration path. None is queue-wired (no EXEC_PROC row in
-- DMT_PIPELINE_DEF_TBL references them) and none has any caller in db/,
-- scripts/, apex/, or test/ (grep-verified). Their .pks/.pkb files are
-- removed from db/packages and their @@ lines removed from db/install.sql
-- in the same change, so the database converges to git by dropping them.
--
--   * DMT_EGP_ITEM_RUNNER_PKG      -- Items are driven by DMT_LOADER_PKG.RUN_ITEMS
--   * DMT_EGP_ITEM_CAT_RUNNER_PKG  -- Item Categories are bundled into the Items token
--   * DMT_GL_CALENDAR_RUNNER_PKG   -- GLCalendar is deferred, not queue-wired (unproven)
--
-- The support packages these runners called (validator / transform /
-- fbdi_gen|fbl_gen / results) are RETAINED: the Items support packages are
-- still called by the live DMT_LOADER_PKG.RUN_ITEMS path, and the
-- GL_CALENDAR support packages are the deferred GLCalendar object's own
-- implementation. Only the dead runners are dropped here.
--
-- Idempotent: guarded so a re-run on a database where they are already gone
-- is a no-op (ORA-04043 "object does not exist" is swallowed).
-- ----------------------------------------------------------------------
BEGIN
    FOR r IN (
        SELECT column_value AS pkg FROM TABLE(sys.odcivarchar2list(
            'DMT_EGP_ITEM_RUNNER_PKG',
            'DMT_EGP_ITEM_CAT_RUNNER_PKG',
            'DMT_GL_CALENDAR_RUNNER_PKG'))
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PACKAGE ' || r.pkg;
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -4043 THEN NULL;  -- already gone
                ELSE RAISE;
                END IF;
        END;
    END LOOP;
END;
/
