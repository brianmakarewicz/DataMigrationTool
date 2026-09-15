-- =============================================================================
-- 01_create_dmt_lookup.sql
-- Run as ADMIN
-- Creates the DMT_LOOKUP schema for EBS-to-Fusion value mapping management.
--
-- Owning schema (owns DMT_CONFIG_TBL / DMT_LOG_TBL and consumes the lookup
-- tables) is passed in at deploy time as the first argument, so this script
-- installs against any owner (DMT_OWNER on the original single-owner ATP,
-- DMT2_OWNER on the shared queryapp ATP, etc.). Because this script runs as
-- ADMIN, cross-schema object names MUST be qualified with the owner -- an
-- unqualified name would resolve against ADMIN's own schema and fail.
--   Example:  sql admin/pw@atp @01_create_dmt_lookup.sql DMT2_OWNER
-- SQL*Plus / SQLcl prompts for the value if the argument is omitted.
-- =============================================================================
SET VERIFY OFF
DEFINE owner_schema = &1

begin
  execute immediate q'[
CREATE USER DMT_LOOKUP IDENTIFIED BY "<SET_PASSWORD_HERE>"
    DEFAULT TABLESPACE DATA
    TEMPORARY TABLESPACE TEMP]';
exception when others then
  if sqlcode not in (-1920) then raise; end if;  -- ORA-01920: user exists
end;
/

-- Basic privileges
GRANT CREATE SESSION TO DMT_LOOKUP;
GRANT CREATE TABLE TO DMT_LOOKUP;
GRANT CREATE SEQUENCE TO DMT_LOOKUP;
GRANT CREATE PROCEDURE TO DMT_LOOKUP;
GRANT CREATE VIEW TO DMT_LOOKUP;
GRANT CREATE SYNONYM TO DMT_LOOKUP;
GRANT UNLIMITED TABLESPACE TO DMT_LOOKUP;

-- Required for BIP SOAP calls
GRANT EXECUTE ON SYS.UTL_HTTP TO DMT_LOOKUP;
GRANT EXECUTE ON SYS.UTL_RAW TO DMT_LOOKUP;
GRANT EXECUTE ON SYS.DBMS_LOB TO DMT_LOOKUP;

-- Cross-schema access to the owner (credentials + logging). Qualified with the
-- owner because this runs as ADMIN (an unqualified name would hit ADMIN's schema).
GRANT SELECT ON &owner_schema..DMT_CONFIG_TBL TO DMT_LOOKUP;
GRANT SELECT ON &owner_schema..DMT_LOG_TBL TO DMT_LOOKUP;
GRANT INSERT ON &owner_schema..DMT_LOG_TBL TO DMT_LOOKUP;

-- Owner access to DMT_LOOKUP tables (for EBS DB link pass-through)
GRANT SELECT, INSERT, UPDATE, DELETE ON DMT_LOOKUP.DMT_LKP_EBS_VALUES TO &owner_schema.;
GRANT SELECT ON DMT_LOOKUP.DMT_LKP_MAPPING TO &owner_schema.;
GRANT SELECT ON DMT_LOOKUP.DMT_LKP_FUSION_VALUES TO &owner_schema.;
GRANT SELECT ON DMT_LOOKUP.DMT_LKP_TYPE_CONFIG TO &owner_schema.;
