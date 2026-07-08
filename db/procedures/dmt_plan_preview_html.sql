-- PROCEDURE DMT_PLAN_PREVIEW_HTML

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_PLAN_PREVIEW_HTML" (
    p_codes IN VARCHAR2
) IS
    l_remaining     VARCHAR2(4000);
    l_pipeline      VARCHAR2(30);
    l_pos           PLS_INTEGER;
    l_sort          PLS_INTEGER := 0;
    l_deps          VARCHAR2(4000);
    l_cemli         VARCHAR2(60);
    l_status        VARCHAR2(10);
    l_seq           VARCHAR2(4000);
    l_seq_remaining VARCHAR2(4000);
    l_seq_pos       PLS_INTEGER;
BEGIN
    IF p_codes IS NULL THEN
        HTP.P('<p style="color:red">ERROR: p_codes is NULL</p>');
        RETURN;
    END IF;

    HTP.P('<table class="plan-tbl">');
    HTP.P('<thead><tr><th>#</th><th>Pipeline</th><th>Object</th><th>Dependencies</th><th>Status</th></tr></thead>');
    HTP.P('<tbody>');

    l_remaining := REPLACE(p_codes, ' ', '') || ',';

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
            l_status := CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END;
            HTP.P('<tr><td>' || l_sort || '</td><td>STANDALONE</td><td style="font-weight:bold">'
                || l_cemli || '</td><td>' || NVL(l_deps, '-') || '</td><td class="st-'
                || LOWER(l_status) || '">' || l_status || '</td></tr>');
            CONTINUE;
        END IF;

        l_seq := DMT_SCHEDULER_PKG.GET_CEMLI_SEQUENCE(l_pipeline);

        IF l_seq IS NULL THEN
            l_sort := l_sort + 1;
            HTP.P('<tr><td>' || l_sort || '</td><td>' || UPPER(l_pipeline)
                || '</td><td colspan="3" style="color:red">Unknown pipeline</td></tr>');
            CONTINUE;
        END IF;

        l_seq_remaining := l_seq || ',';
        LOOP
            l_seq_pos := INSTR(l_seq_remaining, ',');
            EXIT WHEN NVL(l_seq_pos, 0) = 0;
            l_cemli := TRIM(SUBSTR(l_seq_remaining, 1, l_seq_pos - 1));
            l_seq_remaining := SUBSTR(l_seq_remaining, l_seq_pos + 1);
            IF l_cemli IS NULL THEN CONTINUE; END IF;
            l_sort := l_sort + 1;
            l_deps := DMT_SCHEDULER_PKG.GET_CEMLI_DEPENDENCIES(l_pipeline, l_cemli);
            l_status := CASE WHEN l_deps IS NULL THEN 'READY' ELSE 'PENDING' END;
            HTP.P('<tr><td>' || l_sort || '</td><td>' || UPPER(l_pipeline)
                || '</td><td style="font-weight:bold">' || l_cemli
                || '</td><td>' || NVL(l_deps, '-')
                || '</td><td class="st-' || LOWER(l_status) || '">' || l_status || '</td></tr>');
        END LOOP;
    END LOOP;

    HTP.P('</tbody></table>');
    HTP.P('<p style="margin-top:8px;color:#555;font-size:12px">' || l_sort || ' objects in execution plan</p>');
EXCEPTION
    WHEN OTHERS THEN
        HTP.P('<p style="color:red">ERROR: ' || SQLERRM || '</p>');
END;
/
