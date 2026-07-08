-- SCHEDULER JOB DMT_QUEUE_POLLER — 60-second heartbeat (DMT_DESIGN.html section 2).
-- Guarded: skip if exists. Created DISABLED; install.sql enables it as the FINAL
-- install step (after seeds + recompile) so the heartbeat never ticks mid-install.
-- Greenfield DDL: no snapshot start_date / NLS_ENV (job runs with database defaults;
-- all date handling in DMT code carries explicit format masks per section 7).
declare l_cnt number;
begin
  select count(*) into l_cnt from user_scheduler_jobs where job_name='DMT_QUEUE_POLLER';
  if l_cnt = 0 then
    dbms_scheduler.create_job(
      job_name            => '"DMT_QUEUE_POLLER"',
      job_type            => 'PLSQL_BLOCK',
      job_action          => 'BEGIN DMT_OWNER.DMT_QUEUE_PKG.HEARTBEAT_TICK; END;',
      number_of_arguments => 0,
      start_date          => systimestamp,
      repeat_interval     => 'FREQ=SECONDLY;INTERVAL=60',
      end_date            => NULL,
      job_class           => '"DEFAULT_JOB_CLASS"',
      enabled             => FALSE,
      auto_drop           => FALSE);
    commit;
  end if;
end;
/
