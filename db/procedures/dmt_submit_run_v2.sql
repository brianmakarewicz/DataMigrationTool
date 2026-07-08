-- PROCEDURE DMT_SUBMIT_RUN_V2

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_SUBMIT_RUN_V2" (
    p_pipeline_codes IN VARCHAR2,
    p_scenario_name  IN VARCHAR2 DEFAULT NULL,
    p_run_mode       IN VARCHAR2 DEFAULT 'NEW',
    p_on_failure     IN VARCHAR2 DEFAULT 'HALT',
    p_submitted_by   IN VARCHAR2 DEFAULT NULL,
    x_run_id         OUT NUMBER
) IS
    l_remaining    VARCHAR2(4000);
    l_pipeline     VARCHAR2(30);
    l_pos          PLS_INTEGER;
    l_sort         PLS_INTEGER := 0;
    l_deps         VARCHAR2(4000);
    l_cemli        VARCHAR2(60);
    l_cemli_csv    VARCHAR2(4000);
    l_prefix       VARCHAR2(20);
    l_is_split     NUMBER;
    l_seq          VARCHAR2(4000);
    l_seq_remaining VARCHAR2(4000);
    l_seq_pos      PLS_INTEGER;
BEGIN
    SELECT TO_CHAR(DMT_RUN_PREFIX_SEQ.NEXTVAL) INTO l_prefix FROM DUAL;

    -- Build CEMLI CSV for the run record
    l_remaining := REPLACE(p_pipeline_codes, ' ', '') || ',';
    LOOP
        l_pos := INSTR(l_remaining, ',');
        EXIT WHEN NVL(l_pos, 0) = 0;
        l_pipeline := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
        l_remaining := SUBSTR(l_remaining, l_pos + 1);
        IF l_pipeline IS NULL THEN CONTINUE; END IF;
        IF l_pipeline LIKE 'STANDALONE:%' THEN
            l_cemli_csv := CASE WHEN l_cemli_csv IS NOT NULL THEN l_cemli_csv || ',' END || SUBSTR(l_pipeline, 12);
        ELSE
            l_seq := DMT_SCHEDULER_PKG.GET_CEMLI_SEQUENCE(l_pipeline);
            IF l_seq IS NOT NULL THEN
                l_cemli_csv := CASE WHEN l_cemli_csv IS NOT NULL THEN l_cemli_csv || ',' END || l_seq;
            END IF;
        END IF;
    END LOOP;

    INSERT INTO DMT_PIPELINE_RUN_TBL (
        PIPELINE_CODES, RUN_TYPE, SUBMITTED_BY, CEMLI_SEQUENCE,
        SCENARIO_NAME, RUN_MODE, PREFIX, ON_FAILURE_POLICY
    ) VALUES (
        p_pipeline_codes, 'PIPELINE', p_submitted_by, l_cemli_csv,
        p_scenario_name, NVL(p_run_mode, 'NEW'), l_prefix, NVL(p_on_failure, 'HALT')
    ) RETURNING RUN_ID INTO x_run_id;

    -- Create queue rows
    l_sort := 0;
    l_remaining := REPLACE(p_pipeline_codes, ' ', '') || ',';
    LOOP
        l_pos := INSTR(l_remaining, ',');
        EXIT WHEN NVL(l_pos, 0) = 0;
        l_pipeline := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
        l_remaining := SUBSTR(l_remaining, l_pos + 1);
        IF l_pipeline IS NULL THEN CONTINUE; END IF;

        IF l_pipeline LIKE 'STANDALONE:%' THEN
            l_cemli := SUBSTR(l_pipeline, 12);
            l_sort := l_sort + 1;
            l_deps := DMT_SCHEDULER_PKG.GET_CEMLI_DEPENDENCIES('STANDALONE', l_cemli);
            SELECT COUNT(*) INTO l_is_split FROM DMT_CEMLI_SPLIT_CFG WHERE CEMLI_CODE = l_cemli;
            INSERT INTO DMT_WORK_QUEUE_TBL (RUN_ID, PIPELINE, CEMLI_CODE, SORT_ORDER, DEPENDS_ON, WORK_STATUS, PARTITION_KEY, PARTITION_LABEL)
            VALUES (x_run_id, 'STANDALONE', l_cemli, l_sort, l_deps,
                CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END,
                CASE WHEN l_is_split > 0 THEN 'ALL' END,
                CASE WHEN l_is_split > 0 THEN 'All Groups' END);
            CONTINUE;
        END IF;

        l_seq := DMT_SCHEDULER_PKG.GET_CEMLI_SEQUENCE(l_pipeline);
        IF l_seq IS NULL THEN CONTINUE; END IF;

        l_seq_remaining := l_seq || ',';
        LOOP
            l_seq_pos := INSTR(l_seq_remaining, ',');
            EXIT WHEN NVL(l_seq_pos, 0) = 0;
            l_cemli := TRIM(SUBSTR(l_seq_remaining, 1, l_seq_pos - 1));
            l_seq_remaining := SUBSTR(l_seq_remaining, l_seq_pos + 1);
            IF l_cemli IS NULL THEN CONTINUE; END IF;
            l_sort := l_sort + 1;
            l_deps := DMT_SCHEDULER_PKG.GET_CEMLI_DEPENDENCIES(l_pipeline, l_cemli);
            SELECT COUNT(*) INTO l_is_split FROM DMT_CEMLI_SPLIT_CFG WHERE CEMLI_CODE = l_cemli;
            INSERT INTO DMT_WORK_QUEUE_TBL (RUN_ID, PIPELINE, CEMLI_CODE, SORT_ORDER, DEPENDS_ON, WORK_STATUS, PARTITION_KEY, PARTITION_LABEL)
            VALUES (x_run_id, UPPER(l_pipeline), l_cemli, l_sort, l_deps,
                CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END,
                CASE WHEN l_is_split > 0 THEN 'ALL' END,
                CASE WHEN l_is_split > 0 THEN 'All Groups' END);
        END LOOP;
    END LOOP;

    COMMIT;
    DMT_UTIL_PKG.LOG(x_run_id,
        'Pipeline submitted via APEX: ' || p_pipeline_codes || ' prefix=' || l_prefix,
        'INFO', 'DMT_SUBMIT_RUN_V2', 'DMT_SUBMIT_RUN_V2');
END;
/
