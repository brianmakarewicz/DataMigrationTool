-- =============================================================================
-- 02_dmt_lkp_type_config.sql
-- Run as DMT_LOOKUP
-- Registry of all supported lookup types with BIP catalog paths.
-- =============================================================================

CREATE TABLE DMT_LKP_TYPE_CONFIG (
    LOOKUP_TYPE         VARCHAR2(150)  NOT NULL,
    DESCRIPTION         VARCHAR2(500),
    BIP_CATALOG_PATH    VARCHAR2(500),
    BIP_REPORT_PATH     VARCHAR2(500),
    MODULE              VARCHAR2(50),
    ACTIVE_FLAG         VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    CONSTRAINT DMT_LKP_TC_PK PRIMARY KEY (LOOKUP_TYPE)
);
