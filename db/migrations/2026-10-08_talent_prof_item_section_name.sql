-- TalentProfiles profile item: add SECTION_NAME (backlog #451).
--
-- Fusion's V2 ProfileItem requires the profile section ("You must supply a valid
-- value for the required attribute: SectionId", proof run 295). The generator now
-- sends SectionName (an attribute in the pod's HDL dictionary, e.g. 'Languages',
-- 'Competencies'), so the profile item staging and transform tables carry it.
-- The create-table scripts already include the column for fresh installs; this
-- converges an existing database. Guarded and idempotent: adds the column only
-- when it is missing (re-run is a no-op). Run as the schema owner.

set serveroutput on
declare
  procedure add_col(p_table in varchar2) is
    l_n number;
  begin
    select count(*) into l_n from user_tab_columns
    where  table_name = p_table and column_name = 'SECTION_NAME';
    if l_n = 0 then
      execute immediate 'alter table ' || p_table || ' add (SECTION_NAME varchar2(240))';
      dbms_output.put_line('added SECTION_NAME to ' || p_table);
    end if;
  end;
begin
  add_col('DMT_TALENT_PROF_ITEM_STG_TBL');
  add_col('DMT_TALENT_PROF_ITEM_TFM_TBL');
end;
/

merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_talent_prof_item_section_name.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'tpitemsect', USER);

commit;
