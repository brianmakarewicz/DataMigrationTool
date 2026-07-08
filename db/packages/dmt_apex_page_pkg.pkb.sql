-- PACKAGE BODY DMT_APEX_PAGE_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_APEX_PAGE_PKG" AS
-- ============================================================
-- DMT_APEX_PAGE_PKG body
-- ============================================================

  -- Shared CSS injected once per page via a package variable
  g_css_emitted  BOOLEAN := FALSE;

  PROCEDURE emit_css IS
  BEGIN
    IF g_css_emitted THEN RETURN; END IF;
    g_css_emitted := TRUE;
    HTP.P('<style>');
    -- Breadcrumb
    HTP.P('.dmt-bc { font-size:13px; padding:0 0 16px 0; color:#888; display:flex; align-items:center; gap:6px; }');
    HTP.P('.dmt-bc a { color:#4a90d9; text-decoration:none; }');
    HTP.P('.dmt-bc a:hover { text-decoration:underline; }');
    HTP.P('.dmt-bc .sep { color:#ccc; }');
    HTP.P('.dmt-bc .current { color:#333; font-weight:600; }');
    -- Section headings
    HTP.P('.dmt-section { font-size:14px; font-weight:600; color:#333; margin:24px 0 12px 0; padding-bottom:6px; border-bottom:2px solid #e8e8e8; }');
    HTP.P('.dmt-section:first-child { margin-top:0; }');
    -- Tables
    HTP.P('.dmt-tbl { width:100%; border-collapse:collapse; font-size:13px; }');
    HTP.P('.dmt-tbl thead th { text-align:left; padding:10px 12px; font-weight:600; font-size:11px; text-transform:uppercase; letter-spacing:0.5px; color:#666; border-bottom:2px solid #ddd; }');
    HTP.P('.dmt-tbl thead th.num { text-align:right; }');
    HTP.P('.dmt-tbl tbody td { padding:8px 12px; border-bottom:1px solid #f0f0f0; vertical-align:top; }');
    HTP.P('.dmt-tbl tbody td.num { text-align:right; font-variant-numeric:tabular-nums; }');
    HTP.P('.dmt-tbl tbody tr:hover { background:#f8f9fa; }');
    -- Count links
    HTP.P('.dmt-count-link { text-decoration:none; font-weight:600; padding:2px 8px; border-radius:12px; font-size:12px; display:inline-block; min-width:28px; text-align:center; transition:opacity 0.15s; }');
    HTP.P('.dmt-count-link:hover { opacity:0.8; text-decoration:none; }');
    HTP.P('.dmt-count-link.loaded { background:#e8f5e9; color:#2e7d32; }');
    HTP.P('.dmt-count-link.failed { background:#ffebee; color:#c62828; }');
    HTP.P('.dmt-count-link.generated { background:#fff3e0; color:#e65100; }');
    HTP.P('.dmt-count-link.staged { background:#e3f2fd; color:#1565c0; }');
    HTP.P('.dmt-count-zero { color:#ccc; font-size:12px; padding:2px 8px; display:inline-block; min-width:28px; text-align:center; }');
    -- ESS chips
    HTP.P('.dmt-ess-chip { display:inline-flex; align-items:center; gap:6px; padding:6px 14px; border-radius:6px; font-size:13px; text-decoration:none; transition:all 0.15s; border:1px solid #ddd; background:#fff; color:#333; }');
    HTP.P('.dmt-ess-chip:hover { background:#f0f4ff; border-color:#4a90d9; color:#1a73e8; text-decoration:none; }');
    HTP.P('.dmt-ess-chip .ess-label { font-size:10px; text-transform:uppercase; letter-spacing:0.5px; color:#888; }');
    HTP.P('.dmt-ess-chip .ess-id { font-weight:600; }');
    HTP.P('.dmt-ess-pending { display:inline-flex; align-items:center; padding:6px 14px; border-radius:6px; font-size:12px; color:#aaa; border:1px dashed #ddd; }');
    -- Info bar (Page 57 header)
    HTP.P('.dmt-info-bar { display:flex; gap:32px; padding:12px 0; border-bottom:1px solid #e8e8e8; margin-bottom:20px; }');
    HTP.P('.dmt-info-item label { display:block; font-size:10px; text-transform:uppercase; letter-spacing:0.5px; color:#888; margin-bottom:2px; }');
    HTP.P('.dmt-info-item .val { font-size:15px; font-weight:600; color:#333; }');
    -- Status badge
    HTP.P('.dmt-badge { display:inline-block; padding:2px 10px; border-radius:10px; font-size:11px; font-weight:600; }');
    HTP.P('.dmt-badge-loaded { background:#e8f5e9; color:#2e7d32; }');
    HTP.P('.dmt-badge-failed { background:#ffebee; color:#c62828; }');
    HTP.P('.dmt-badge-generated { background:#fff3e0; color:#e65100; }');
    HTP.P('.dmt-badge-staged { background:#e3f2fd; color:#1565c0; }');
    -- Verify button
    HTP.P('.dmt-verify-btn { background:#1a73e8; color:#fff; border:none; border-radius:6px; padding:5px 14px; cursor:pointer; font-size:12px; font-weight:500; transition:background 0.15s; }');
    HTP.P('.dmt-verify-btn:hover { background:#1557b0; }');
    -- Empty state
    HTP.P('.dmt-empty { padding:24px; text-align:center; color:#999; font-size:13px; }');
    HTP.P('</style>');
  END emit_css;

  -- ----------------------------------------------------------------
  -- Helper: build a drill link URL
  -- ----------------------------------------------------------------
  FUNCTION drill_url(
    p_page   IN NUMBER,
    p_items  IN VARCHAR2,
    p_values IN VARCHAR2
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN 'f?p=' || V('APP_ID') || ':' || p_page || ':' || V('APP_SESSION')
           || '::NO::' || p_items || ':' || p_values;
  END drill_url;

  -- ----------------------------------------------------------------
  -- Helper: count link or zero placeholder
  -- ----------------------------------------------------------------
  FUNCTION count_cell(
    p_count     IN NUMBER,
    p_css_class IN VARCHAR2,
    p_href      IN VARCHAR2
  ) RETURN VARCHAR2 IS
  BEGIN
    IF p_count > 0 THEN
      RETURN '<a href="' || p_href || '" class="dmt-count-link ' || p_css_class || '">' || p_count || '</a>';
    ELSE
      RETURN '<span class="dmt-count-zero">0</span>';
    END IF;
  END count_cell;

  -- ================================================================
  -- Page 52: Breadcrumb
  -- Nav chain: Run History (80) â†’ Run Detail (82) â†’ Object Detail (52)
  -- ================================================================
  PROCEDURE RENDER_OBJECT_BREADCRUMB(
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  ) IS
    v_cemli VARCHAR2(200);
  BEGIN
    emit_css;

    -- Resolve CEMLI display name from pipeline run
    BEGIN
      SELECT PIPELINE_CODES INTO v_cemli
        FROM DMT_OWNER.DMT_PIPELINE_RUN_TBL
       WHERE RUN_ID = p_run_id;
    EXCEPTION WHEN OTHERS THEN
      v_cemli := NVL(p_cemli_code, 'Unknown');
    END;

    HTP.P('<nav class="dmt-bc">');
    HTP.P('<a href="' || drill_url(80, '', '') || '">Run History</a>');
    HTP.P('<span class="sep">&rsaquo;</span>');
    HTP.P('<a href="' || drill_url(82, 'P82_RUN_ID', TO_CHAR(p_run_id)) || '">Run #' || p_run_id || '</a>');
    HTP.P('<span class="sep">&rsaquo;</span>');
    HTP.P('<span class="current">' || APEX_ESCAPE.HTML(NVL(p_cemli_code, v_cemli)) || '</span>');
    HTP.P('</nav>');
  END RENDER_OBJECT_BREADCRUMB;

  -- ================================================================
  -- Page 52: Sub-Object Breakdown with clickable counts
  -- Uses DMT_OBJECT_DETAIL_V for pivoted counts per sub-object.
  -- Each non-zero count links to Page 57.
  -- ================================================================
  PROCEDURE RENDER_OBJECT_BREAKDOWN(
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  ) IS
    v_has_rows BOOLEAN := FALSE;
    v_href     VARCHAR2(1000);
  BEGIN
    emit_css;

    IF p_cemli_code IS NULL THEN
      HTP.P('<div class="dmt-empty">No CEMLI code specified.</div>');
      RETURN;
    END IF;

    HTP.P('<h3 class="dmt-section">Record Breakdown</h3>');
    HTP.P('<table class="dmt-tbl">');
    HTP.P('<thead><tr>');
    HTP.P('<th>Sub-Object</th>');
    HTP.P('<th class="num">Staged</th>');
    HTP.P('<th class="num">Generated</th>');
    HTP.P('<th class="num">Loaded</th>');
    HTP.P('<th class="num">Failed</th>');
    HTP.P('<th class="num">Total</th>');
    HTP.P('</tr></thead><tbody>');

    FOR rec IN (
      SELECT SUB_OBJECT, SUB_ORDER,
             SUM(TOTAL_ROWS)       AS TOTAL_ROWS,
             SUM(LOADED_ROWS)      AS LOADED_ROWS,
             SUM(FAILED_ROWS)      AS FAILED_ROWS,
             SUM(GENERATED_ROWS)   AS GENERATED_ROWS,
             SUM(TOTAL_ROWS) - SUM(LOADED_ROWS) - SUM(FAILED_ROWS) - SUM(GENERATED_ROWS)
                                   AS STAGED_ROWS
      FROM DMT_OWNER.DMT_OBJECT_DETAIL_V
      WHERE CEMLI_CODE = p_cemli_code
        AND RUN_ID     = p_run_id
      GROUP BY SUB_OBJECT, SUB_ORDER
      ORDER BY SUB_ORDER
    ) LOOP
      v_has_rows := TRUE;
      HTP.P('<tr>');
      HTP.P('<td>' || APEX_ESCAPE.HTML(rec.SUB_OBJECT) || '</td>');

      -- Staged
      v_href := drill_url(57, 'P57_INTEGRATION_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',STAGED');
      HTP.P('<td class="num">' || count_cell(rec.STAGED_ROWS, 'staged', v_href) || '</td>');

      -- Generated
      v_href := drill_url(57, 'P57_INTEGRATION_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',GENERATED');
      HTP.P('<td class="num">' || count_cell(rec.GENERATED_ROWS, 'generated', v_href) || '</td>');

      -- Loaded
      v_href := drill_url(57, 'P57_INTEGRATION_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',LOADED');
      HTP.P('<td class="num">' || count_cell(rec.LOADED_ROWS, 'loaded', v_href) || '</td>');

      -- Failed
      v_href := drill_url(57, 'P57_INTEGRATION_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',FAILED');
      HTP.P('<td class="num">' || count_cell(rec.FAILED_ROWS, 'failed', v_href) || '</td>');

      -- Total (links to all records, no status filter)
      v_href := drill_url(57, 'P57_INTEGRATION_ID,P57_SUB_OBJECT',
                           p_run_id || ',' || rec.SUB_OBJECT);
      HTP.P('<td class="num"><a href="' || v_href || '" style="font-weight:700;color:#333;text-decoration:none;">' || rec.TOTAL_ROWS || '</a></td>');

      HTP.P('</tr>');
    END LOOP;

    HTP.P('</tbody></table>');

    IF NOT v_has_rows THEN
      HTP.P('<div class="dmt-empty">No TFM records found for ' || APEX_ESCAPE.HTML(p_cemli_code) || ' in Run #' || p_run_id || '.</div>');
    END IF;
  END RENDER_OBJECT_BREAKDOWN;

  -- ================================================================
  -- Page 52: ESS Jobs
  -- Shows Load, Import, and Postrun ESS Job IDs as clickable chips.
  -- ================================================================
  PROCEDURE RENDER_ESS_JOBS(
    p_run_id      IN NUMBER,
    p_cemli_code  IN VARCHAR2
  ) IS
    v_load_id    NUMBER;
    v_import_id  NUMBER;
    v_postrun_id NUMBER;
    v_found      BOOLEAN := FALSE;

    PROCEDURE ess_chip(p_label IN VARCHAR2, p_ess_id IN NUMBER) IS
      v_href VARCHAR2(500);
    BEGIN
      IF p_ess_id IS NOT NULL THEN
        v_href := drill_url(53, 'P53_ESS_JOB_ID,P53_INTEGRATION_ID,P53_CEMLI_CODE',
                             p_ess_id || ',' || p_run_id || ',' || p_cemli_code);
        HTP.P('<a href="' || v_href || '" class="dmt-ess-chip">');
        HTP.P('<span class="ess-label">' || p_label || '</span>');
        HTP.P('<span class="ess-id">' || p_ess_id || '</span>');
        HTP.P('</a>');
      ELSE
        HTP.P('<span class="dmt-ess-pending">');
        HTP.P('<span class="ess-label">' || p_label || '</span>');
        HTP.P('&mdash;');
        HTP.P('</span>');
      END IF;
    END ess_chip;

  BEGIN
    emit_css;

    -- Get ESS IDs from work queue
    BEGIN
      SELECT LOAD_ESS_JOB_ID, IMPORT_ESS_JOB_ID, POSTRUN_ESS_JOB_ID
        INTO v_load_id, v_import_id, v_postrun_id
        FROM DMT_OWNER.DMT_WORK_QUEUE_TBL
       WHERE RUN_ID     = p_run_id
         AND CEMLI_CODE = p_cemli_code
         AND ROWNUM     = 1;
      v_found := TRUE;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      v_found := FALSE;
    END;

    IF NOT v_found THEN
      RETURN; -- No queue entry = no ESS jobs to show
    END IF;

    IF v_load_id IS NULL AND v_import_id IS NULL AND v_postrun_id IS NULL THEN
      RETURN; -- All NULL = pipeline hasn't reached ESS yet
    END IF;

    HTP.P('<h3 class="dmt-section">ESS Jobs</h3>');
    HTP.P('<div style="display:flex;gap:12px;flex-wrap:wrap;">');
    ess_chip('Load', v_load_id);
    ess_chip('Import', v_import_id);
    IF v_postrun_id IS NOT NULL THEN
      ess_chip('Post-Run', v_postrun_id);
    END IF;
    HTP.P('</div>');
  END RENDER_ESS_JOBS;

  -- ================================================================
  -- Page 57: Record Header with breadcrumb and info bar
  -- Nav: Run History (80) â†’ Run Detail (82) â†’ Object Detail (52) â†’ Record Detail (57)
  -- ================================================================
  PROCEDURE RENDER_RECORD_HEADER(
    p_run_id      IN NUMBER,
    p_sub_object  IN VARCHAR2,
    p_status      IN VARCHAR2 DEFAULT NULL,
    p_cemli_code  IN VARCHAR2 DEFAULT NULL
  ) IS
    v_cemli VARCHAR2(200) := p_cemli_code;
  BEGIN
    emit_css;

    IF p_run_id IS NULL THEN
      HTP.P('<div class="dmt-empty">No parameters specified.</div>');
      RETURN;
    END IF;

    -- Resolve CEMLI code if not passed
    IF v_cemli IS NULL THEN
      BEGIN
        SELECT CEMLI_CODE INTO v_cemli
          FROM DMT_OWNER.DMT_RECORD_DETAIL_V
         WHERE INTEGRATION_ID = p_run_id
           AND SUB_OBJECT     = p_sub_object
           AND ROWNUM = 1;
      EXCEPTION WHEN OTHERS THEN
        v_cemli := NULL;
      END;
    END IF;

    -- Breadcrumb
    HTP.P('<nav class="dmt-bc">');
    HTP.P('<a href="' || drill_url(80, '', '') || '">Run History</a>');
    HTP.P('<span class="sep">&rsaquo;</span>');
    HTP.P('<a href="' || drill_url(82, 'P82_RUN_ID', TO_CHAR(p_run_id)) || '">Run #' || p_run_id || '</a>');
    HTP.P('<span class="sep">&rsaquo;</span>');
    IF v_cemli IS NOT NULL THEN
      HTP.P('<a href="' || drill_url(52, 'P52_INTEGRATION_ID,P52_CEMLI_CODE',
                                      p_run_id || ',' || v_cemli) || '">'
             || APEX_ESCAPE.HTML(v_cemli) || '</a>');
      HTP.P('<span class="sep">&rsaquo;</span>');
    END IF;
    HTP.P('<span class="current">' || APEX_ESCAPE.HTML(p_sub_object) || '</span>');
    HTP.P('</nav>');

    -- Info bar
    HTP.P('<div class="dmt-info-bar">');
    HTP.P('<div class="dmt-info-item"><label>Sub-Object</label><span class="val">'
          || APEX_ESCAPE.HTML(p_sub_object) || '</span></div>');
    HTP.P('<div class="dmt-info-item"><label>Run ID</label><span class="val">'
          || p_run_id || '</span></div>');
    IF p_status IS NOT NULL THEN
      HTP.P('<div class="dmt-info-item"><label>Filter</label><span class="val dmt-badge dmt-badge-'
            || LOWER(p_status) || '">' || APEX_ESCAPE.HTML(p_status) || '</span></div>');
    END IF;
    HTP.P('</div>');

  END RENDER_RECORD_HEADER;

  -- ================================================================
  -- Page 57: Record Table with verify buttons and modal HTML
  -- ================================================================
  PROCEDURE RENDER_RECORD_TABLE(
    p_run_id      IN NUMBER,
    p_sub_object  IN VARCHAR2,
    p_status      IN VARCHAR2 DEFAULT NULL
  ) IS
    l_cnt PLS_INTEGER := 0;
  BEGIN
    emit_css;

    IF p_run_id IS NULL THEN RETURN; END IF;

    -- REST Verify Modal (dark overlay)
    HTP.P('<div id="restModal" style="display:none;position:fixed;top:0;left:0;width:100%;height:100%;'
       || 'background:rgba(0,0,0,0.5);z-index:10000;justify-content:center;align-items:center;">');
    HTP.P('<div style="background:#1e1e1e;border-radius:10px;padding:28px;width:640px;max-height:80vh;'
       || 'overflow-y:auto;color:#eee;box-shadow:0 12px 40px rgba(0,0,0,0.4);">');
    HTP.P('<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;">');
    HTP.P('<h3 id="restModalTitle" style="margin:0;font-size:16px;font-weight:600;">Fusion Record</h3>');
    HTP.P('<button type="button" onclick="closeRestModal()" '
       || 'style="background:none;border:none;color:#666;font-size:22px;cursor:pointer;'
       || 'width:32px;height:32px;border-radius:6px;display:flex;align-items:center;'
       || 'justify-content:center;transition:background 0.15s;"'
       || ' onmouseover="this.style.background=''#333''" onmouseout="this.style.background=''none''">&times;</button>');
    HTP.P('</div>');
    HTP.P('<div id="restModalBody" style="font-size:13px;">Loading...</div>');
    HTP.P('</div></div>');

    -- Records heading
    HTP.P('<h3 class="dmt-section">Records</h3>');

    -- Table
    HTP.P('<table class="dmt-tbl">');
    HTP.P('<thead><tr>');
    HTP.P('<th>TFM ID</th>');
    HTP.P('<th>Display Key</th>');
    HTP.P('<th>Status</th>');
    HTP.P('<th>Error Category</th>');
    HTP.P('<th>Error Text</th>');
    HTP.P('<th>Updated</th>');
    HTP.P('<th style="text-align:center;">Verify</th>');
    HTP.P('</tr></thead><tbody>');

    FOR rec IN (
      SELECT TFM_SEQUENCE_ID, DISPLAY_KEY, LOOKUP_KEY, STATUS,
             RECONCILIATION_STATUS, ERROR_CATEGORY, ERROR_TEXT,
             TO_CHAR(RESULTS_UPDATED_DATE, 'YYYY-MM-DD HH24:MI') UPD
      FROM DMT_OWNER.DMT_RECORD_DETAIL_V
      WHERE INTEGRATION_ID = p_run_id
        AND SUB_OBJECT     = p_sub_object
        AND (p_status IS NULL OR STATUS = p_status)
      ORDER BY TFM_SEQUENCE_ID
    ) LOOP
      l_cnt := l_cnt + 1;
      HTP.P('<tr>');
      HTP.P('<td>' || rec.TFM_SEQUENCE_ID || '</td>');
      HTP.P('<td>' || APEX_ESCAPE.HTML(rec.DISPLAY_KEY) || '</td>');

      -- Status with badge
      HTP.P('<td><span class="dmt-badge dmt-badge-' || LOWER(rec.STATUS) || '">'
            || APEX_ESCAPE.HTML(rec.STATUS) || '</span></td>');

      HTP.P('<td>' || NVL(APEX_ESCAPE.HTML(rec.ERROR_CATEGORY), '&mdash;') || '</td>');
      HTP.P('<td style="max-width:400px;word-wrap:break-word;">'
            || NVL(APEX_ESCAPE.HTML(SUBSTR(rec.ERROR_TEXT, 1, 500)), '&mdash;') || '</td>');
      HTP.P('<td style="white-space:nowrap;">' || NVL(rec.UPD, '&mdash;') || '</td>');

      -- Verify button (LOADED only)
      IF rec.STATUS = 'LOADED' THEN
        HTP.P('<td style="text-align:center;"><button type="button" class="dmt-verify-btn" onclick="openRestModal('
              || CHR(39) || APEX_ESCAPE.HTML(p_sub_object) || CHR(39) || ','
              || CHR(39) || APEX_ESCAPE.HTML(rec.DISPLAY_KEY) || CHR(39) || ','
              || rec.TFM_SEQUENCE_ID || ','
              || CHR(39) || APEX_ESCAPE.HTML(NVL(rec.LOOKUP_KEY, rec.DISPLAY_KEY)) || CHR(39)
              || ')">Verify</button></td>');
      ELSE
        HTP.P('<td style="text-align:center;">&mdash;</td>');
      END IF;

      HTP.P('</tr>');
    END LOOP;

    HTP.P('</tbody></table>');

    IF l_cnt = 0 THEN
      HTP.P('<div class="dmt-empty">No records found matching the specified criteria.</div>');
    END IF;

  END RENDER_RECORD_TABLE;

END DMT_APEX_PAGE_PKG;
/
