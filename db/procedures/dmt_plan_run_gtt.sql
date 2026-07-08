-- PROCEDURE DMT_PLAN_RUN_GTT

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_PLAN_RUN_GTT" (
    p_pipeline_codes IN VARCHAR2
) IS
    l_remaining    VARCHAR2(4000);
    l_pipeline     VARCHAR2(30);
    l_pos          PLS_INTEGER;
    l_sort         PLS_INTEGER := 0;
    l_deps         VARCHAR2(4000);
    l_cemli        VARCHAR2(60);
BEGIN
    DELETE FROM DMT_PLAN_PREVIEW_GTT;

    IF p_pipeline_codes IS NULL THEN RETURN; END IF;

    l_remaining := REPLACE(p_pipeline_codes, ' ', '') || ',';
    LOOP
        l_pos := INSTR(l_remaining, ',');
        EXIT WHEN l_pos = 0;
        l_pipeline := TRIM(SUBSTR(l_remaining, 1, l_pos - 1));
        l_remaining := SUBSTR(l_remaining, l_pos + 1);
        IF l_pipeline IS NULL THEN CONTINUE; END IF;

        IF l_pipeline LIKE 'STANDALONE:%' THEN
            l_cemli := SUBSTR(l_pipeline, 12);
            l_sort := l_sort + 1;
            l_deps := DMT_SCHEDULER_PKG.GET_CEMLI_DEPENDENCIES('STANDALONE', l_cemli);
            INSERT INTO DMT_PLAN_PREVIEW_GTT VALUES (l_sort, 'STANDALONE', l_cemli, l_deps,
                CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END);
            CONTINUE;
        END IF;

        DECLARE
            l_seq VARCHAR2(4000) := DMT_SCHEDULER_PKG.GET_CEMLI_SEQUENCE(l_pipeline);
            l_seq_remaining VARCHAR2(4000);
            l_seq_pos PLS_INTEGER;
        BEGIN
            IF l_seq IS NULL THEN
                l_sort := l_sort + 1;
                INSERT INTO DMT_PLAN_PREVIEW_GTT VALUES (l_sort, UPPER(l_pipeline),
                    '** Unknown pipeline: ' || l_pipeline || ' **', NULL, 'ERROR');
                CONTINUE;
            END IF;
            l_seq_remaining := l_seq || ',';
            LOOP
                l_seq_pos := INSTR(l_seq_remaining, ',');
                EXIT WHEN l_seq_pos = 0;
                l_cemli := TRIM(SUBSTR(l_seq_remaining, 1, l_seq_pos - 1));
                l_seq_remaining := SUBSTR(l_seq_remaining, l_seq_pos + 1);
                IF l_cemli IS NULL THEN CONTINUE; END IF;
                l_sort := l_sort + 1;
                l_deps := DMT_SCHEDULER_PKG.GET_CEMLI_DEPENDENCIES(l_pipeline, l_cemli);
                INSERT INTO DMT_PLAN_PREVIEW_GTT VALUES (l_sort, UPPER(l_pipeline), l_cemli, l_deps,
                    CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END);
            END LOOP;
        END;
    END LOOP;
END;
/
