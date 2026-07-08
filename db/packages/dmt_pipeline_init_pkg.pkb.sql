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
        l_scenario_id   NUMBER;
    BEGIN
        -- Get prefix configuration
        BEGIN
            SELECT config_value INTO l_use_prefix
            FROM DMT_OWNER.DMT_CONFIG_TBL
            WHERE config_key = 'USE_PREFIX';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_use_prefix := 'Y';  -- default: always use prefix
        END;

        -- Generate integration_id (always)
        SELECT DMT_OWNER.DMT_INTEGRATION_ID_SEQ.NEXTVAL
        INTO   x_integration_id
        FROM   DUAL;

        -- Generate prefix (unless explicitly disabled)
        IF l_use_prefix = 'Y' THEN
            SELECT TO_CHAR(DMT_OWNER.DMT_PREFIX_SEQ.NEXTVAL)
            INTO   x_prefix
            FROM   DUAL;
        ELSE
            x_prefix := NULL;
        END IF;

        -- Resolve scenario
        IF p_scenario_name IS NOT NULL THEN
            BEGIN
                SELECT scenario_id INTO l_scenario_id
                FROM DMT_OWNER.DMT_SCENARIO_TBL
                WHERE scenario_name = p_scenario_name
                AND   status = 'ACTIVE';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_scenario_id := NULL;
            END;
        END IF;

        -- Create master row
        INSERT INTO DMT_OWNER.DMT_CONVERSION_MASTER_TBL (
            INTEGRATION_ID, INSTANCE_ID, ORCHESTRATION_CODE, SOURCE_FILENAME,
            START_DATE, STATUS, PREFIX, DEPENDENT_PREFIX, SCENARIO_ID
        ) VALUES (
            x_integration_id, p_instance_id, p_orchestration_code, p_source_filename,
            SYSDATE, 'OPEN', x_prefix, x_prefix, l_scenario_id
        );
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
