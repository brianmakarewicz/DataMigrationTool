-- Drop CONFIDENCE and PROVEN_ON_RUN from DMT_REF_CARRIER_CFG_TBL (backlog #131/#132,
-- 2026-09-30, owner sign-off). They were audit/status annotation columns read by no
-- package, generator, or reconciler (grep-verified); the end-to-end round-trip status
-- they recorded now lives only in the per-row NOTES prose. The slimmed create-table
-- script (db/tables/dmt_ref_carrier_cfg_tbl.sql) no longer defines them and carries
-- the same guarded DROP so a fresh install is already slim; this migration removes them
-- from any instance created before the change. Idempotent/re-runnable: each DROP is
-- guarded on USER_TAB_COLUMNS, so re-running is a no-op (column simply absent).
DECLARE
    PROCEDURE drop_col(p_col VARCHAR2) IS
        n NUMBER;
    BEGIN
        SELECT COUNT(*) INTO n FROM user_tab_columns
         WHERE table_name = 'DMT_REF_CARRIER_CFG_TBL' AND column_name = p_col;
        IF n > 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE "DMT_REF_CARRIER_CFG_TBL" DROP COLUMN "'||p_col||'"';
        END IF;
    END;
BEGIN
    drop_col('CONFIDENCE');
    drop_col('PROVEN_ON_RUN');
END;
/

prompt == Log migration (idempotent) ==
merge into DMT_MIGRATION_LOG t
using (select '2026-09-30_drop_carrier_cfg_confidence_proven.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'dropconfproven', USER);

commit;
