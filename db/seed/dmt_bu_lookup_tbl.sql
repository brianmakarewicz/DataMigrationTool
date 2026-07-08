-- Seed data for DMT_BU_LOOKUP_TBL (177 rows, snapshot 2026-07-03)
-- Idempotent: duplicate-key inserts are skipped.
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('AU Council Business Unit','300000219208529',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000219190442');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Algeria Business Unit','300000124184209',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Aquisition Business Unit','300000247752461',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Argentina Business Unit','300000123913057',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Australia Business Unit','300000047826661',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000129460415');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Austria Business Unit','300000116771530',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Bahrain Business Unit','300000116771630',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Banco del Bienestar_ S.N.C_, I.B.D.','300000275081847',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000274882476');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Belgium Business Unit','300000105578322',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000107570320');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Brazil Business Unit','300000103055704',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Canada Business Unit','300000049671153',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000085666101');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Chile Business Unit','300000123650589',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('China Business Unit','300000047826657',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000074983539');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Colombia Business Unit','300000123774676',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Czech Business Unit','300000124171704',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Denmark Business Unit','300000105492815',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Estonia Business Unit','300000116771680',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Federal US Business Unit','300000217229393',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000216960831');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Fin Svcs UK Business Unit','300000132179374',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000117449147');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Fin Svcs US Business Unit','300000132179348',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000117449137');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Finland Business Unit','300000105647741',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('France Business Unit','300000047568131',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000047488121');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Gemeente Burgerdam','300000257521670',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000257519761');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Germany Business Unit','300000048608425',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000130210397');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Greece Business Unit','300000124181993',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Healthcare US Business Unit','300000078974743',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000101474319');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Hong Kong Business Unit','300000047902202',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Hungary Business Unit','300000116771655',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('India Business Unit','300000047826665',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000184410368');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Indonesia Business Unit','300000123998588',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Instituto para el Desarrollo Tecnico de las Haciendas Publicas','300000275081844',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000274882476');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Ireland Business Unit','300000103055365',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000293563972');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Israel Business Unit','300000126234057',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Italy Business Unit','300000048608417',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000110509153');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Italy Public Sector BU','300000257645577',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000257520101');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Japan Business Unit','300000047826669',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000100509325');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Kazakhstan Business Unit','300000105647677',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Kuwait Business Unit','300000116771555',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Latvia Business Unit','300000116771705',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Liechtenstein Business Unit','300000116771730',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Lithuania Business Unit','300000116771755',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Luxembourg Business Unit','300000126298397',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Malaysia Business Unit','300000105647550',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Mexico Business Unit','300000079037580',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000195964379');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Military US Business Unit','300000268207653',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Morocco Business Unit','300000129610421',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Netherlands Business Unit','300000048608429',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000131552112');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('New Zealand Business Unit','300000105006286',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000129460424');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Norway Business Unit','300000116771580',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Oman Business Unit','300000116771780',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Pakistan Business Unit','300000126317911',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Philippines Business Unit','300000126304804',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Poland Business Unit','300000048716580',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000172606735');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Portugal Business Unit','300000123786588',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Professional Services US BU','300000255090817',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000261593561');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Progress CA Business Unit','300000250518753',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000303436149');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Progress UK Business Unit','300000078974768',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000217507763');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Progress US Business Unit','300000075888561',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000075887689');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Qatar Business Unit','300000116771805',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Romania Business Unit','300000126304829',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Russia Business Unit','300000048608421',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SA PS Business Unit','300000257522698',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000257519801');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG AD Commercial US','300000292537242',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG AD Defense US','300000292537245',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG AD Infrastructure US','300000292537248',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Audit Tax Advisory Services US','300000292537254',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto Aftermarket CA','300000299832471',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535859');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto Aftermarket MX','300000299832503',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535860');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto Aftermarket US','300000302217886',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto OEM Production CA','300000292537278',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535859');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto OEM Production MX','300000292537281',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535860');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto OEM Production US','300000297903584',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto Services CA','300000299832487',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535859');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto Services MX','300000299832519',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535860');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Auto Services US','300000299829367',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Business Services US','300000292537266',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Construction & Engineering NL','300000292537323',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535863');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Distribution North DE','300000292537329',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535863');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Distribution South FR','300000292537332',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535863');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction CA','300000312704807',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535859');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction Development US','300000323747857',NULL,NULL,to_date('2026-05-05 15:50:11','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction Equipment US','300000312710831',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction GB','300000312711770',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535872');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction IN','300000312705946',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535880');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction SA','300000312712830',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535874');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction Self Perform US','300000312704791',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Engineering Construction US','300000312710847',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG European HQ CH','300000292537317',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535862');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Facility Development NL','300000324258823',NULL,NULL,to_date('2026-05-05 15:50:11','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535863');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Financial Services US','300000292537269',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Government Contractor Services US','300000292537263',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Holding Inc. US','300000292810862',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Industrial Manufacturing DE','300000292537338',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535867');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Legal Services US','300000292537257',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing AE','300000292537308',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535873');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing AU','300000292537284',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535881');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing BR','300000292537275',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535861');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing CN','300000292537287',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535879');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing GB','300000292537305',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535872');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing IL','300000292537311',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535876');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing IN','300000292537290',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535880');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing JP','300000292537293',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535883');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing MY','300000292537296',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535878');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing SA','300000292537314',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535874');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing SE','300000292537341',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535868');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing SG','300000292537299',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535877');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing TW','300000292537302',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535882');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Manufacturing US','300000292537272',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Pharma Research US','300000299522341',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Production RO','300000292537320',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535875');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail AE','300000317661685',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535873');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail BH','300000317662681',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000317547674');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail CA','300000317662785',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535859');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail DE','300000317661653',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535867');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail ES','300000317661669',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535869');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail FR','300000317662817',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000297591397');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail GB','300000317662737',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535872');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail IT','300000317662833',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535871');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail KW','300000317662684',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000317547675');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail MX','300000317662769',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535860');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail NL','300000317662801',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535863');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail OM','300000317662687',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000317547676');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail PL','300000317662690',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000317547677');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail QA','300000317662693',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000317547678');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail SA','300000317662753',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535874');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail US','300000317661637',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Retail ZA','300000317662696',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000317547679');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services BE','300000292537344',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535864');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services CH','300000292537371',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535862');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services DE','300000292537353',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535867');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services DK','300000292537347',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535865');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services ES','300000292537365',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535869');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services FI','300000292537350',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535866');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services FR','300000297571822',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000297591397');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services IT','300000292537356',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535871');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services NL','300000292537359',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535863');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services NO','300000292537362',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535870');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Sales & Services SE','300000292537368',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535868');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Shared Service Center NL','300000292537326',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535863');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Smart Manufacturing DE','300000292537335',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535867');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Staffing Services US','300000292537260',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Technical Consulting Services US','300000292537251',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Wholesale Distribution CA','300000308597299',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535859');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Wholesale Distribution MX','300000308598919',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535860');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('SG Wholesale Distribution US','300000304238758',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000292535858');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Saudi Arabia Business Unit','300000048608413',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000157698798');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Singapore Business Unit','300000047902198',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('South Africa Business Unit','300000123795674',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('South Korea Business Unit','300000103055995',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Spain Business Unit','300000048716576',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000117819959');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Subsecretaría de Hacienda y Crédito Público','300000275081850',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000274882476');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Supremo CH Business Unit','300000186345961',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000107691109');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Supremo Energy BR BU','300000255085399',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000255143676');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Supremo Energy CA BU','300000255085393',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000255143674');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Supremo Energy GB BU','300000255085396',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000255143675');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Supremo Energy US BU','300000255085390',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000255143673');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Supremo US Business Unit','300000180010546',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000046975971');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Sweden Business Unit','300000048716584',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000137440136');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Switzerland Business Unit','300000105578390',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000107691109');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Taiwan Business Unit','300000105431848',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Thailand Business Unit','300000126313049',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Turkey Business Unit','300000123827898',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000141993058');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('UAE Business Unit','300000116771605',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000150998360');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('UAE PS BU','300000264691201',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000264722879');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('UK Business Unit','300000047498175',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000047488112');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('US INS Business Unit','300000136439946',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000136437848');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('US1 Business Unit','300000046987012','300000047340498','300000046987012',to_date('2026-04-02 18:25:35','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000046975971');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('US1 External Learning','300000176102880',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('US2 Business Unit','300000087957781',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000046975971');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Ukraine Business Unit','300000105647613',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('University AU Business Unit','300000186845781',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('University US Business Unit','300000093962136',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000094024319');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Venezuela Business Unit','300000126322020',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Viet Nam Business Unit','300000126317723',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Vision E and C Business Unit','300000124087100',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000216960831');
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('Vision Retail Business Unit','300000111055917',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),NULL);
exception when dup_val_on_index then null;
end;
/
begin
  insert into "DMT_BU_LOOKUP_TBL" ("BU_NAME","FUSION_BU_ID","DEFAULT_BUYER_ID","DEFAULT_REQ_BU_ID","CREATED_DATE","LAST_UPDATED_DATE","PRIMARY_LEDGER_ID") values ('zzzzProgress UK BU','300000217435697',NULL,NULL,to_date('2026-04-24 17:22:33','YYYY-MM-DD HH24:MI:SS'),to_date('2026-05-21 00:59:44','YYYY-MM-DD HH24:MI:SS'),'300000217507763');
exception when dup_val_on_index then null;
end;
/
commit;
