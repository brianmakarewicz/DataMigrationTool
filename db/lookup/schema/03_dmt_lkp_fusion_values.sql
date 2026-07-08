-- =============================================================================
-- 03_dmt_lkp_fusion_values.sql
-- Run as DMT_LOOKUP
-- Fusion reference values populated by BIP reports.
-- Will be reused for broader Fusion validation lookups in future.
-- =============================================================================

begin
  execute immediate q'[
CREATE TABLE DMT_LKP_FUSION_VALUES (
    FUSION_VALUE_ID     NUMBER GENERATED ALWAYS AS IDENTITY,
    LOOKUP_TYPE         VARCHAR2(150)  NOT NULL,
    FUSION_VALUE        VARCHAR2(500)  NOT NULL,
    FUSION_DESCRIPTION  VARCHAR2(500),
    FUSION_ID           NUMBER,
    ACTIVE_FLAG         VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    LAST_REFRESH_DATE   DATE,
    CREATED_DATE        DATE           DEFAULT SYSDATE,
    CONSTRAINT DMT_LKP_FV_PK PRIMARY KEY (FUSION_VALUE_ID),
    CONSTRAINT DMT_LKP_FV_UK UNIQUE (LOOKUP_TYPE, FUSION_VALUE)
)]';
exception when others then
  if sqlcode not in (-955) then raise; end if;
end;
/

begin
  execute immediate 'CREATE INDEX DMT_LKP_FV_TYPE_N1 ON DMT_LKP_FUSION_VALUES (LOOKUP_TYPE)';
exception when others then
  if sqlcode not in (-955,-1408) then raise; end if;
end;
/
