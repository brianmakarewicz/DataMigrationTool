-- =============================================================================
-- 05_dmt_lkp_mapping.sql
-- Run as DMT_LOOKUP
-- Maps EBS values to Fusion values. Managed via APEX UI.
-- No FK constraints — UI LOVs constrain selection from EBS/Fusion tables.
-- =============================================================================

begin
  execute immediate q'[
CREATE TABLE DMT_LKP_MAPPING (
    MAPPING_ID          NUMBER GENERATED ALWAYS AS IDENTITY,
    LOOKUP_TYPE         VARCHAR2(150)  NOT NULL,
    EBS_VALUE           VARCHAR2(500)  NOT NULL,
    FUSION_VALUE        VARCHAR2(500)  NOT NULL,
    ACTIVE_FLAG         VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    NOTES               VARCHAR2(500),
    CREATED_BY          VARCHAR2(100),
    CREATED_DATE        DATE           DEFAULT SYSDATE,
    LAST_UPDATE_BY      VARCHAR2(100),
    LAST_UPDATE_DATE    DATE,
    CONSTRAINT DMT_LKP_MAP_PK PRIMARY KEY (MAPPING_ID),
    CONSTRAINT DMT_LKP_MAP_UK UNIQUE (LOOKUP_TYPE, EBS_VALUE)
)]';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX DMT_LKP_MAP_TYPE_N1 ON DMT_LKP_MAPPING (LOOKUP_TYPE)';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
