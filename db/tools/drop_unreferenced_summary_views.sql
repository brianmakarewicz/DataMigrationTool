-- Drop 22 summary views: invalid on both stacks (INTEGRATION_ID drift), referenced by
-- nothing (APEX export f155 checked 2026-07-08, DB code grep checked). Guarded, idempotent.
begin
  execute immediate 'drop view "DMT_ABSENCES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_ASSIGNMENTS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_BENEFITS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_BILLING_EVENTS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_CFG_LOOKUP_TYPES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_CFG_LOOKUP_VALUES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_FA_ASSETS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_GL_BALANCES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_OTC_AR_INVOICES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_OTC_CUSTOMERS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_OTC_RECEIPTS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_P2P_AP_INVOICES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_P2P_PO_HEADERS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_P2P_REQUISITIONS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_P2P_SUPPLIERS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_PROJECTS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_PROJECT_BUDGETS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_PROJECT_EXPENDITURES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_PROJECT_TASKS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_SALARIES_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_TIMECARDS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
begin
  execute immediate 'drop view "DMT_WORKERS_V"';
exception when others then
  if sqlcode != -942 then raise; end if;
end;
/
