-- PACKAGE BODY DMT_PIPELINE_INIT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_PIPELINE_INIT_PKG" AS

    PROCEDURE INIT_RUN (
        p_orchestration_code IN  VARCHAR2,
        p_scenario_name      IN  VARCHAR2 DEFAULT NULL,
        p_source_filename    IN  VARCHAR2 DEFAULT 'manual_run',
        p_instance_id        IN  VARCHAR2 DEFAULT 'MANUAL',
        x_integration_id     OUT NUMBER,
        x_prefix             OUT VARCHAR2
    ) IS
        l_use_prefix    VARCHAR2(10);
    BEGIN
        -- Prefix configuration (default Y: always use prefix)
        SELECT NVL(MAX(config_value), 'Y') INTO l_use_prefix
        FROM   DMT_OWNER.DMT_CONFIG_TBL
        WHERE  config_key = 'USE_PREFIX';

        -- Generate prefix (unless explicitly disabled).
        -- One prefix per run, assigned here at run creation from the
        -- single sequence DMT_RUN_PREFIX_SEQ (design section 6) —
        -- same semantics as DMT_SCHEDULER_PKG.create_run_and_queue.
        IF l_use_prefix = 'Y' THEN
            SELECT TO_CHAR(DMT_OWNER.DMT_RUN_PREFIX_SEQ.NEXTVAL)
            INTO   x_prefix
            FROM   DUAL;
        ELSE
            x_prefix := NULL;
        END IF;

        -- Create the run row directly in DMT_PIPELINE_RUN_TBL.
        -- (2026-07-08 fix: the previous body inserted into the
        -- DMT_CONVERSION_MASTER_TBL compatibility VIEW — not insertable
        -- (constant/virtual columns), STATUS 'OPEN' violates
        -- DMT_PIPELINE_RUN_STATUS_CK, CEMLI_SEQUENCE NOT NULL was missing,
        -- and DMT_INTEGRATION_ID_SEQ does not exist in the rebuilt schema.
        -- RUN_ID comes from the column default DMT_PIPELINE_RUN_SEQ.)
        INSERT INTO DMT_OWNER.DMT_PIPELINE_RUN_TBL (
            PIPELINE_CODES, RUN_TYPE, SUBMITTED_BY,
            CEMLI_SEQUENCE, SCENARIO_NAME, PREFIX
        ) VALUES (
            p_orchestration_code, 'STANDALONE',
            SUBSTR(p_instance_id || ':' || p_source_filename, 1, 100),
            p_orchestration_code, p_scenario_name, x_prefix
        ) RETURNING RUN_ID INTO x_integration_id;
        COMMIT;

        DMT_UTIL_PKG.LOG(x_integration_id,
            'INIT_RUN: orchestration=' || p_orchestration_code ||
            ' | prefix=' || NVL(x_prefix, 'NONE') ||
            ' | scenario=' || NVL(p_scenario_name, 'none'),
            'INFO', 'DMT_PIPELINE_INIT_PKG', 'INIT_RUN');

    END INIT_RUN;


    FUNCTION INIT_RUN_F (
        p_orchestration_code IN  VARCHAR2,
        p_scenario_name      IN  VARCHAR2 DEFAULT NULL,
        p_source_filename    IN  VARCHAR2 DEFAULT 'manual_run',
        p_instance_id        IN  VARCHAR2 DEFAULT 'MANUAL'
    ) RETURN NUMBER IS
        l_id     NUMBER;
        l_prefix VARCHAR2(20);
    BEGIN
        INIT_RUN(
            p_orchestration_code => p_orchestration_code,
            p_scenario_name      => p_scenario_name,
            p_source_filename    => p_source_filename,
            p_instance_id        => p_instance_id,
            x_integration_id     => l_id,
            x_prefix             => l_prefix
        );
        RETURN l_id;
    END INIT_RUN_F;

END DMT_PIPELINE_INIT_PKG;
/
