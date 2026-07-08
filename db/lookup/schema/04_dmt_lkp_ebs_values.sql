-- =============================================================================
-- 04_dmt_lkp_ebs_values.sql
-- Run as DMT_LOOKUP
-- EBS reference values pushed from EBS via DB link.
-- =============================================================================

begin
  execute immediate q'[
CREATE TABLE DMT_LKP_EBS_VALUES (
    EBS_VALUE_ID        NUMBER GENERATED ALWAYS AS IDENTITY,
    LOOKUP_TYPE         VARCHAR2(150)  NOT NULL,
    EBS_VALUE           VARCHAR2(500)  NOT NULL,
    EBS_DESCRIPTION     VARCHAR2(500),
    EBS_ID              NUMBER,
    ACTIVE_FLAG         VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    LAST_REFRESH_DATE   DATE,
    CREATED_DATE        DATE           DEFAULT SYSDATE,
    CONSTRAINT DMT_LKP_EV_PK PRIMARY KEY (EBS_VALUE_ID),
    CONSTRAINT DMT_LKP_EV_UK UNIQUE (LOOKUP_TYPE, EBS_VALUE)
)]';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX DMT_LKP_EV_TYPE_N1 ON DMT_LKP_EBS_VALUES (LOOKUP_TYPE)';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
