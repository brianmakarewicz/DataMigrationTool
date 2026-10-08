-- TalentProfiles profile item: add SECTION_ID to the transform table (backlog #451).
--
-- Fusion's V2 ProfileItem identifies the profile section by SectionId, and it
-- rejected the section name ("You need to enter a valid value for the SectionId
-- attribute. The current values are Languages."). A section name alone is
-- ambiguous: 'Languages' exists once per profile type (person, job, position,
-- organization). The transform now resolves the id at run time through the
-- PROFILE_SECTION_NAME_TO_SECTION_ID lookup (profile type code ~ section name,
-- refreshed from Fusion setup at pipeline preflight) and stores it here; the
-- generator sends it as SectionId.
-- The create-table script already includes the column for fresh installs; this
-- converges an existing database. Guarded and idempotent: adds the column only
-- when it is missing (re-run is a no-op). Run as the schema owner.

set serveroutput on
declare
  l_n number;
begin
  select count(*) into l_n from user_tab_columns
  where  table_name = 'DMT_TALENT_PROF_ITEM_TFM_TBL' and column_name = 'SECTION_ID';
  if l_n = 0 then
    execute immediate 'alter table DMT_TALENT_PROF_ITEM_TFM_TBL add (SECTION_ID number)';
    dbms_output.put_line('added SECTION_ID to DMT_TALENT_PROF_ITEM_TFM_TBL');
  end if;
end;
/

merge into DMT_MIGRATION_LOG t
using (select '2026-10-08_talent_prof_item_section_id.sql' migration_name from dual) s
on (t.migration_name = s.migration_name)
when not matched then
  insert (migration_name, checksum, applied_by)
  values (s.migration_name, 'tpitemsectid', USER);

commit;
