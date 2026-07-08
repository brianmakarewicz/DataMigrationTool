-- SCHEDULER JOB DMT_QUEUE_POLLER (guarded: skip if exists)
declare l_cnt number;
begin
  select count(*) into l_cnt from user_scheduler_jobs where job_name='DMT_QUEUE_POLLER';
  if l_cnt = 0 then
    
      
    BEGIN 
    dbms_scheduler.create_job('"DMT_QUEUE_POLLER"',
    job_type=>'PLSQL_BLOCK', job_action=>
    'BEGIN DMT_OWNER.DMT_QUEUE_PKG.HEARTBEAT_TICK; END;'
    , number_of_arguments=>0,
    start_date=>TO_TIMESTAMP_TZ('28-MAY-2026 02.59.28.151333000 PM UTC','DD-MON-RRRR HH.MI.SSXFF AM TZR','NLS_DATE_LANGUAGE=english'), repeat_interval=> 
    'FREQ=SECONDLY;INTERVAL=60'
    , end_date=>NULL,
    job_class=>'"DEFAULT_JOB_CLASS"', enabled=>FALSE, auto_drop=>FALSE,comments=>
    NULL
    );
    sys.dbms_scheduler.set_attribute('"DMT_QUEUE_POLLER"','NLS_ENV','NLS_LANGUAGE=''AMERICAN'' NLS_TERRITORY=''AMERICA'' NLS_CURRENCY=''$'' NLS_ISO_CURRENCY=''AMERICA'' NLS_NUMERIC_CHARACTERS=''.,'' NLS_CALENDAR=''GREGORIAN'' NLS_DATE_FORMAT=''DD-MON-RR'' NLS_DATE_LANGUAGE=''AMERICAN'' NLS_SORT=''BINARY'' NLS_TIME_FORMAT=''HH.MI.SSXFF AM'' NLS_TIMESTAMP_FORMAT=''DD-MON-RR HH.MI.SSXFF AM'' NLS_TIME_TZ_FORMAT=''HH.MI.SSXFF AM TZR'' NLS_TIMESTAMP_TZ_FORMAT=''DD-MON-RR HH.MI.SSXFF AM TZR'' NLS_DUAL_CURRENCY=''$'' NLS_COMP=''BINARY'' NLS_LENGTH_SEMANTICS=''BYTE'' NLS_NCHAR_CONV_EXCP=''FALSE''');
    dbms_scheduler.enable('"DMT_QUEUE_POLLER"');
    COMMIT; 
    END;
  end if;
end;
/
