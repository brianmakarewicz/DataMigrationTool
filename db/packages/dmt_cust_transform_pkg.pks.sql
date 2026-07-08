-- PACKAGE DMT_CUST_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_CUST_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_CUST_TRANSFORM_PKG
-- Transforms staged Customer records into the transformed tables.
-- Applies run prefix to PARTY_NUMBER, ACCOUNT_NUMBER, and
-- ORIG_SYSTEM_REFERENCE values.
--
-- Customer FBDI is a single zip with 7 CSVs. All share the
-- same BATCH_ID and ORIG_SYSTEM_REFERENCE linkage.
--
-- One procedure per object type, called sequentially.
-- ============================================================

    PROCEDURE TRANSFORM_PARTIES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_LOCATIONS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_PARTY_SITES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_PARTY_SITE_USES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_ACCOUNTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_ACCT_SITES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

    PROCEDURE TRANSFORM_ACCT_SITE_USES (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    );

END DMT_CUST_TRANSFORM_PKG;
/
