-- PROCEDURE DMT_RENDER_VIEW

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_RENDER_VIEW" (
  p_view_name IN VARCHAR2,
  p_title     IN VARCHAR2
) IS
  l_cur      INTEGER;
  l_col_cnt  INTEGER;
  l_desc     DBMS_SQL.DESC_TAB;
  l_val      VARCHAR2(4000);
  l_rows     INTEGER := 0;
  l_status   INTEGER;
  l_is_link  BOOLEAN;
  l_sql      VARCHAR2(4000);
  l_scenario NUMBER;
  l_prefix   VARCHAR2(100);
  l_has_where BOOLEAN := FALSE;
BEGIN
  l_sql := 'SELECT * FROM ' || DBMS_ASSERT.SIMPLE_SQL_NAME(p_view_name);
  BEGIN
    l_scenario := TO_NUMBER(V('P0_SCENARIO_ID'));
  EXCEPTION WHEN OTHERS THEN l_scenario := NULL;
  END;
  l_prefix := V('P0_PREFIX');

  IF l_scenario IS NOT NULL THEN
    l_sql := l_sql || ' WHERE SCENARIO_ID = :scenario_id';
    l_has_where := TRUE;
  END IF;
  IF l_prefix IS NOT NULL THEN
    IF l_has_where THEN
      l_sql := l_sql || ' AND PREFIX = :prefix_val';
    ELSE
      l_sql := l_sql || ' WHERE PREFIX = :prefix_val';
    END IF;
  END IF;

  l_cur := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(l_cur, l_sql, DBMS_SQL.NATIVE);
  IF l_scenario IS NOT NULL THEN
    DBMS_SQL.BIND_VARIABLE(l_cur, ':scenario_id', l_scenario);
  END IF;
  IF l_prefix IS NOT NULL THEN
    DBMS_SQL.BIND_VARIABLE(l_cur, ':prefix_val', l_prefix);
  END IF;
  DBMS_SQL.DESCRIBE_COLUMNS(l_cur, l_col_cnt, l_desc);

  FOR i IN 1..l_col_cnt LOOP
    DBMS_SQL.DEFINE_COLUMN(l_cur, i, l_val, 4000);
  END LOOP;

  l_status := DBMS_SQL.EXECUTE(l_cur);

  WHILE DBMS_SQL.FETCH_ROWS(l_cur) > 0 LOOP
    l_rows := l_rows + 1;
    IF l_rows = 1 THEN
      htp.p('<div style="overflow-x:auto;">');
      htp.p('<table style="width:100%;border-collapse:collapse;font-size:14px;">');
      htp.p('<thead><tr style="background:#f1f5f9;">');
      FOR i IN 1..l_col_cnt LOOP
        IF l_desc(i).col_name = 'FUSION_LINK' THEN
          htp.p('<th style="padding:10px 12px;text-align:center;border-bottom:2px solid #e2e8f0;color:#475569;font-weight:600;white-space:nowrap;">View in Fusion</th>');
        ELSE
          htp.p('<th style="padding:10px 12px;text-align:left;border-bottom:2px solid #e2e8f0;color:#475569;font-weight:600;white-space:nowrap;">'
                || REPLACE(l_desc(i).col_name, '_', ' ') || '</th>');
        END IF;
      END LOOP;
      htp.p('</tr></thead><tbody>');
    END IF;

    IF MOD(l_rows, 2) = 0 THEN
      htp.p('<tr style="background:#f8fafc;">');
    ELSE
      htp.p('<tr>');
    END IF;
    FOR i IN 1..l_col_cnt LOOP
      DBMS_SQL.COLUMN_VALUE(l_cur, i, l_val);
      l_is_link := (l_desc(i).col_name = 'FUSION_LINK');

      IF l_is_link AND l_val IS NOT NULL THEN
        htp.p('<td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;text-align:center;">'
              || '<a href="' || l_val || '" target="_blank" '
              || 'class="t-Button t-Button--tiny t-Button--link" '
              || 'title="Open in Oracle Fusion">'
              || '<span class="fa fa-external-link"></span> View</a></td>');
      ELSIF l_is_link AND l_val IS NULL THEN
        htp.p('<td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;">&nbsp;</td>');
      ELSE
        htp.p('<td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;color:#334155;">'
              || NVL(apex_escape.html(l_val), '&ndash;') || '</td>');
      END IF;
    END LOOP;
    htp.p('</tr>');
  END LOOP;

  DBMS_SQL.CLOSE_CURSOR(l_cur);

  IF l_rows > 0 THEN
    htp.p('</tbody></table></div>');
    htp.p('<div style="padding:8px 12px;color:#94a3b8;font-size:12px;">' || l_rows || ' row(s)</div>');
  ELSE
    htp.p('<div style="text-align:center;padding:48px 20px;color:#94a3b8;">');
    htp.p('<div style="font-size:36px;margin-bottom:12px;">&#128203;</div>');
    htp.p('<div style="font-size:16px;font-weight:500;">No ' || apex_escape.html(p_title) || ' data yet</div>');
    htp.p('<div style="font-size:13px;margin-top:4px;">Data will appear here after migration runs</div>');
    htp.p('</div>');
  END IF;
END;
/
