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
        FROM DMT_PIPELINE_RUN_TBL
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
      FROM DMT_OBJECT_DETAIL_V
      WHERE CEMLI_CODE = p_cemli_code
        AND RUN_ID     = p_run_id
      GROUP BY SUB_OBJECT, SUB_ORDER
      ORDER BY SUB_ORDER
    ) LOOP
      v_has_rows := TRUE;
      HTP.P('<tr>');
      HTP.P('<td>' || APEX_ESCAPE.HTML(rec.SUB_OBJECT) || '</td>');

      -- Staged
      v_href := drill_url(57, 'P57_RUN_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',STAGED');
      HTP.P('<td class="num">' || count_cell(rec.STAGED_ROWS, 'staged', v_href) || '</td>');

      -- Generated
      v_href := drill_url(57, 'P57_RUN_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',GENERATED');
      HTP.P('<td class="num">' || count_cell(rec.GENERATED_ROWS, 'generated', v_href) || '</td>');

      -- Loaded
      v_href := drill_url(57, 'P57_RUN_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',LOADED');
      HTP.P('<td class="num">' || count_cell(rec.LOADED_ROWS, 'loaded', v_href) || '</td>');

      -- Failed
      v_href := drill_url(57, 'P57_RUN_ID,P57_SUB_OBJECT,P57_STATUS',
                           p_run_id || ',' || rec.SUB_OBJECT || ',FAILED');
      HTP.P('<td class="num">' || count_cell(rec.FAILED_ROWS, 'failed', v_href) || '</td>');

      -- Total (links to all records, no status filter)
      v_href := drill_url(57, 'P57_RUN_ID,P57_SUB_OBJECT',
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
        v_href := drill_url(53, 'P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE',
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
        FROM DMT_WORK_QUEUE_TBL
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
          FROM DMT_RECORD_DETAIL_V
         WHERE RUN_ID = p_run_id
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
      HTP.P('<a href="' || drill_url(52, 'P52_RUN_ID,P52_CEMLI_CODE',
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
      SELECT TFM_SEQUENCE_ID, DISPLAY_KEY, LOOKUP_KEY, TFM_STATUS,
             RECONCILIATION_STATUS, ERROR_CATEGORY, ERROR_TEXT,
             TO_CHAR(RESULTS_UPDATED_DATE, 'YYYY-MM-DD HH24:MI') UPD
      FROM DMT_RECORD_DETAIL_V
      WHERE RUN_ID = p_run_id
        AND SUB_OBJECT     = p_sub_object
        AND (p_status IS NULL OR TFM_STATUS = p_status)
      ORDER BY TFM_SEQUENCE_ID
    ) LOOP
      l_cnt := l_cnt + 1;
      HTP.P('<tr>');
      HTP.P('<td>' || rec.TFM_SEQUENCE_ID || '</td>');
      HTP.P('<td>' || APEX_ESCAPE.HTML(rec.DISPLAY_KEY) || '</td>');

      -- Status with badge
      HTP.P('<td><span class="dmt-badge dmt-badge-' || LOWER(rec.TFM_STATUS) || '">'
            || APEX_ESCAPE.HTML(rec.TFM_STATUS) || '</span></td>');

      HTP.P('<td>' || NVL(APEX_ESCAPE.HTML(rec.ERROR_CATEGORY), '&mdash;') || '</td>');
      HTP.P('<td style="max-width:400px;word-wrap:break-word;">'
            || NVL(APEX_ESCAPE.HTML(SUBSTR(rec.ERROR_TEXT, 1, 500)), '&mdash;') || '</td>');
      HTP.P('<td style="white-space:nowrap;">' || NVL(rec.UPD, '&mdash;') || '</td>');

      -- Verify button (LOADED only)
      IF rec.TFM_STATUS = 'LOADED' THEN
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

  -- ================================================================
  -- Page 82: Run Detail status tiles (folded from DMT_RUN_DETAIL_TILES, #41)
  -- HTML preserved byte-for-byte from the former standalone procedure.
  -- ================================================================
  PROCEDURE RENDER_RUN_TILES(p_run_id IN NUMBER) IS
    l_pp   VARCHAR2(30) := '***';
    l_bg   VARCHAR2(30);
    l_app  VARCHAR2(10) := V('APP_ID');
    l_ses  VARCHAR2(30) := V('APP_SESSION');
    l_has_queue NUMBER;
    l_phase   VARCHAR2(10);
    l_failerr NUMBER;
    l_part_keys VARCHAR2(4000);   -- partition column name(s) for a parent coordinator tile
    l_run_status VARCHAR2(30);
    l_run_active BOOLEAN := FALSE;   -- TRUE while the parent run has not reached a terminal status

    -- ------------------------------------------------------------------
    -- Outcome-based tile palette (DMT_DESIGN.html section 9, decided
    -- 2026-07-06). ONE decision, called by both render paths below, so
    -- the queue path and the sync path can never diverge again.
    --
    -- p_phase is the object's lifecycle state, normalised by each caller:
    --   PENDING  queued, not started         -> White
    --   RUNNING  in progress                 -> Blue
    --   SKIPPED  no rows / dependency-skipped -> Grey
    --   ERRORED  did NOT finish (uncaught exception, API error, dead
    --            loader, BIP failure, DB error - any unexpected failure)
    --                                         -> Red
    --   DONE     finished normally -> colour by rolled-up record counts.
    --
    -- Counts are the rolled-up per-object outcome numbers:
    --   p_loaded     records confirmed in Fusion base tables (LOADED)
    --   p_failed_err records FAILED with a reportable error
    --   p_unacc      records unaccounted (FAILED, no Fusion id, no error)
    --   p_total      = loaded + failed_err + unacc
    -- Among finished objects the counts decide the colour; every-row-
    -- unaccounted is treated as Red (the doc's systemic-failure signature).
    -- ------------------------------------------------------------------
    FUNCTION tile_bg(p_phase VARCHAR2, p_total NUMBER, p_loaded NUMBER,
                     p_failed_err NUMBER, p_unacc NUMBER) RETURN VARCHAR2 IS
    BEGIN
      IF p_phase = 'PENDING' THEN RETURN '#ffffff'; END IF;   -- White: queued
      IF p_phase = 'RUNNING' THEN RETURN '#e8f0fe'; END IF;   -- Blue: in progress
      IF p_phase = 'ERRORED' AND NVL(p_total,0) = 0 THEN RETURN '#f5b8b1'; END IF;   -- Red: true infra break, no rows processed (finished-with-counts ERRORED falls through to the outcome logic below)
      IF NVL(p_total,0) = 0 OR p_phase = 'SKIPPED' THEN RETURN '#f0f0f0'; END IF; -- Grey
      -- In-flight: while the run is still active, an object that FINISHED NORMALLY
      -- (phase DONE) with NO real failures but is not yet fully loaded is still
      -- working -- its records are generated / awaiting load / awaiting reconciliation
      -- (loaded, failed and unaccounted can all still be 0). That is in progress, not a
      -- failure. Colour it Blue until the run reaches a terminal status; only then do
      -- not-loaded rows count as failure. Scoped to DONE so an item whose own work
      -- status already resolved to FAILED (phase ERRORED) is NOT masked as in-progress
      -- -- it keeps falling through to the outcome logic and reds out.
      IF p_phase = 'DONE' AND l_run_active AND NVL(p_failed_err,0) = 0 AND NVL(p_loaded,0) < NVL(p_total,0) THEN RETURN '#e8f0fe'; END IF;
      IF NVL(p_unacc,0)  >= p_total THEN RETURN '#f5b8b1'; END IF;  -- Red: all unaccounted
      IF NVL(p_loaded,0) >= p_total THEN RETURN '#5fbf4f'; END IF;  -- Pure green: 100% loaded
      IF NVL(p_unacc,0) > 0 OR NVL(p_loaded,0) = 0 THEN RETURN '#fce8e6'; END IF; -- Light red
      RETURN '#c2e58f';                                       -- Light green (Option B): some failed but all accounted (distinct from the pure full-loaded green above)
    END tile_bg;

    -- Status line HTML, consistent with the colour the palette chose.
    FUNCTION tile_status(p_phase VARCHAR2, p_total NUMBER, p_loaded NUMBER,
                         p_failed_err NUMBER, p_unacc NUMBER) RETURN VARCHAR2 IS
    BEGIN
      IF p_phase = 'PENDING' THEN RETURN '<span style="color:#888">Queued</span>'; END IF;
      IF p_phase = 'RUNNING' THEN RETURN '<span style="color:#0b5cc0">In progress</span>'; END IF;
      IF p_phase = 'ERRORED' AND NVL(p_total,0) = 0 THEN RETURN '<span style="color:#b3261e">&#10007; Failed</span>'; END IF;
      IF NVL(p_total,0) = 0 OR p_phase = 'SKIPPED' THEN RETURN '<span style="color:#888">No rows</span>'; END IF;
      -- In-flight: during an active run, an object that finished normally (phase DONE)
      -- with no real failures but is not yet fully loaded is still working (generating /
      -- loading / reconciling), not a failure. Show a clock with the in-progress count,
      -- not a red X. Scoped to DONE so an ERRORED item is not masked as in-progress.
      IF p_phase = 'DONE' AND l_run_active AND NVL(p_failed_err,0) = 0 AND NVL(p_loaded,0) < NVL(p_total,0) THEN
        RETURN '<span style="color:#0b5cc0">&#128337; ' ||
               CASE WHEN NVL(p_loaded,0) > 0 THEN p_loaded || ' loaded &middot; ' END ||
               (NVL(p_total,0) - NVL(p_loaded,0) - NVL(p_failed_err,0)) || ' in progress</span>';
      END IF;
      IF NVL(p_unacc,0) >= p_total THEN
        RETURN '<span style="color:#b3261e">' || p_unacc || ' unaccounted</span>';
      END IF;
      IF NVL(p_loaded,0) >= p_total THEN
        RETURN '<span style="color:#000">&#10003; ' || p_loaded || ' loaded</span>';  -- black: reads on the deeper full-loaded green
      END IF;
      -- only a genuine failure (rows FAILED with a reportable error) shows a red X;
      -- never render "0 failed" as a failure (e.g. a terminal run with rows stuck
      -- un-loaded but not failed falls through to the neutral mixed line below).
      IF NVL(p_loaded,0) = 0 AND NVL(p_unacc,0) = 0 AND NVL(p_failed_err,0) > 0 THEN
        RETURN '<span style="color:#b3261e">&#10007; ' || p_failed_err || ' failed</span>';
      END IF;
      -- mixed: show every non-zero bucket
      RETURN '<span style="color:#1a7d33">' || p_loaded || ' loaded</span>'
          || CASE WHEN NVL(p_failed_err,0) > 0 THEN ' &middot; <span style="color:#b3261e">' || p_failed_err || ' failed</span>' END
          || CASE WHEN NVL(p_unacc,0) > 0 THEN ' &middot; <span style="color:#c47a00">' || p_unacc || ' unaccounted</span>' END;
    END tile_status;

    -- Normalise the async work-queue status into a palette phase.
    FUNCTION phase_from_work(p_work_status VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      RETURN CASE p_work_status
               WHEN 'DONE'    THEN 'DONE'      -- finished + fully accounted -> counts decide
               WHEN 'FAILED'  THEN 'ERRORED'   -- work item broke -> Red
               WHEN 'SKIPPED' THEN 'SKIPPED'
               WHEN 'PENDING' THEN 'PENDING'
               ELSE 'RUNNING'
             END;
    END phase_from_work;

    -- Normalise the sync summary object status into a palette phase.
    FUNCTION phase_from_object(p_object_status VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      RETURN CASE p_object_status
               WHEN 'FAILED'      THEN 'ERRORED'
               WHEN 'SKIPPED'     THEN 'SKIPPED'
               WHEN 'IN_PROGRESS' THEN 'RUNNING'
               ELSE 'DONE'   -- COMPLETED / COMPLETED_ERRORS / UNRECONCILED -> counts decide
             END;
    END phase_from_object;

    -- For a partition PARENT: the distinct partition-key COLUMN name(s) its
    -- children were split on, e.g. 'BATCH_ID' or 'DOCUMENT_NAME, USER_TRANSACTION_SOURCE'.
    -- Each child's PARTITION_KEY is a flat JSON object ({"COL":"val"} per the
    -- DMT_WORK_QUEUE_TBL.PARTITION_KEY column comment). We enumerate the key NAMES
    -- with the structured JSON parser JSON_OBJECT_T.get_keys() -- never regex offset
    -- arithmetic over the payload (DMT_DESIGN.html section 7: structured parsing over
    -- string arithmetic, JSON with JSON_VALUE / JSON_OBJECT_T). Returns the distinct
    -- names comma-joined, or NULL when the parent has no JSON-keyed children.
    FUNCTION part_key_names(p_parent_queue_id NUMBER) RETURN VARCHAR2 IS
      l_seen  VARCHAR2(4000) := '';   -- '|COL|' membership set, keeps first-seen order
      l_out   VARCHAR2(4000) := '';
      l_obj   JSON_OBJECT_T;
      l_keys  JSON_KEY_LIST;
    BEGIN
      FOR c IN (SELECT PARTITION_KEY FROM DMT_WORK_QUEUE_TBL
                 WHERE PARENT_QUEUE_ID = p_parent_queue_id
                   AND PARTITION_KEY IS NOT NULL
                   AND PARTITION_KEY <> 'ALL') LOOP
        BEGIN
          l_obj  := JSON_OBJECT_T.parse(c.PARTITION_KEY);
          l_keys := l_obj.get_keys();
          FOR i IN 1 .. l_keys.COUNT LOOP
            IF INSTR(l_seen, '|' || l_keys(i) || '|') = 0 THEN
              l_seen := l_seen || '|' || l_keys(i) || '|';
              l_out  := l_out || CASE WHEN l_out IS NOT NULL AND LENGTH(l_out) > 0 THEN ', ' END || l_keys(i);
            END IF;
          END LOOP;
        EXCEPTION WHEN OTHERS THEN NULL;  -- a non-JSON key (defensive) contributes no column name
        END;
      END LOOP;
      RETURN CASE WHEN LENGTH(l_out) > 0 THEN l_out END;
    END part_key_names;
BEGIN
    -- Parent run status: the tiles branch on whether the run is still active,
    -- so an object with unaccounted-but-not-failed records shows in progress
    -- mid-run and only turns to a failure once the run is terminal.
    BEGIN
        SELECT RUN_STATUS INTO l_run_status FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
    EXCEPTION WHEN NO_DATA_FOUND THEN l_run_status := NULL;
    END;
    l_run_active := NVL(l_run_status,'IN_PROGRESS')
                    NOT IN ('COMPLETED','COMPLETED_ERRORS','FAILED','NO_ROWS_PROCESSED');

    -- Check if work queue has rows for this run
    SELECT COUNT(*) INTO l_has_queue
    FROM DMT_WORK_QUEUE_TBL WHERE RUN_ID = p_run_id AND ROWNUM = 1;

    IF l_has_queue > 0 THEN
        -- Async path: render one tile per work item.
        --
        -- Partitioned objects (backlog #70): an object that partitions spawns a
        -- PARENT placeholder work item (the partition coordinator) plus one CHILD
        -- work item per partition key (e.g. Items/Customers by BATCH_ID, GL by
        -- Ledger). The parent does NOT submit an ESS load/import -- those belong to
        -- the children -- so the parent tile must show NO load/import request id and
        -- must be visibly marked as a coordinator, showing WHAT it partitioned on.
        -- Each child ran its OWN ESS load + import job, so each child tile must show
        -- its own DISTINCT request ids and WHICH partition it ran.
        --
        -- Load/import ids come ONLY from the work item's own LOAD_ESS_JOB_ID /
        -- IMPORT_ESS_JOB_ID columns (stamped per work item by the loader). The old
        -- COALESCE fallback to MAX(REQUEST_ID) keyed on RUN_ID+CEMLI_CODE was the
        -- root of the defect: DMT_ESS_JOB_TBL carries no partition discriminator, so
        -- that fallback fabricated the SAME id onto the parent and every child. It is
        -- removed. A parent (IS_PARENT) is forced to null ids; a child with no stamped
        -- id honestly shows no id rather than a shared fabricated one.
        --
        -- NOTE (still open, separate item): DMT_V_CEMLI_STATUS aggregates counts per
        -- object, so a partition child shows object-level counts. Per-partition counts
        -- need a partition-aware status view (tracked separately).
        FOR rec IN (
            SELECT QUEUE_ID, PIPELINE, CEMLI_CODE, WORK_STATUS, PARTITION_LABEL, PARTITION_KEY,
                   q.QUEUE_ID AS OWN_QUEUE_ID,
                   q.PARENT_QUEUE_ID,
                   -- A work item is a partition PARENT (coordinator) if it has children.
                   CASE WHEN EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                                     WHERE c.PARENT_QUEUE_ID = q.QUEUE_ID) THEN 1 ELSE 0 END AS IS_PARENT,
                   -- A work item is a partition CHILD if it was spawned from a parent.
                   CASE WHEN q.PARENT_QUEUE_ID IS NOT NULL THEN 1 ELSE 0 END AS IS_CHILD,
                   -- Own load/import ids only; a parent coordinator never exposes an id.
                   -- The old COALESCE fallback to MAX(REQUEST_ID) keyed on RUN_ID+CEMLI_CODE
                   -- is removed: DMT_ESS_JOB_TBL has no partition discriminator, so it
                   -- fabricated the SAME id onto the parent and every child. Per-child ids
                   -- are now stamped on the work item by the loader (#413), so the honest
                   -- source is the row's own column.
                   CASE WHEN EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                                     WHERE c.PARENT_QUEUE_ID = q.QUEUE_ID)
                        THEN NULL ELSE q.LOAD_ESS_JOB_ID END AS LOAD_ESS_JOB_ID,
                   CASE WHEN EXISTS (SELECT 1 FROM DMT_WORK_QUEUE_TBL c
                                     WHERE c.PARENT_QUEUE_ID = q.QUEUE_ID)
                        THEN NULL ELSE q.IMPORT_ESS_JOB_ID END AS IMPORT_ESS_JOB_ID,
                   ERROR_MESSAGE, RUN_ID,
                   -- Rolled-up outcome counts for the palette (loaded / failed / unaccounted).
                   (SELECT NVL(SUM(cs.ROW_COUNT),0) FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS TOT_ROWS,
                   (SELECT NVL(SUM(CASE WHEN cs.TFM_STATUS = 'LOADED' THEN cs.ROW_COUNT END),0)
                      FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS LOADED_ROWS,
                   (SELECT NVL(SUM(CASE WHEN cs.TFM_STATUS = 'FAILED' THEN cs.ROW_COUNT END),0)
                      FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS FAILED_ROWS,
                   (SELECT NVL(SUM(cs.UNRECONCILED_COUNT),0) FROM DMT_V_CEMLI_STATUS cs
                     WHERE cs.RUN_ID = q.RUN_ID AND cs.CEMLI_CODE = q.CEMLI_CODE) AS UNACC_ROWS,
                   TO_CHAR(STARTED_AT, 'HH24:MI:SS') STARTED,
                   TO_CHAR(COMPLETED_AT, 'HH24:MI:SS') COMPLETED
            FROM DMT_WORK_QUEUE_TBL q WHERE RUN_ID = p_run_id
            -- Group each partition parent with its children: order by the
            -- coordinating item's slot (a child borrows its parent's SORT_ORDER
            -- via the self-join), render the parent first, then its children by id.
            ORDER BY PIPELINE,
                     NVL((SELECT p.SORT_ORDER FROM DMT_WORK_QUEUE_TBL p
                           WHERE p.QUEUE_ID = q.PARENT_QUEUE_ID), q.SORT_ORDER),
                     NVL(q.PARENT_QUEUE_ID, q.QUEUE_ID),
                     CASE WHEN q.PARENT_QUEUE_ID IS NULL THEN 0 ELSE 1 END,
                     q.QUEUE_ID
        ) LOOP
            IF rec.PIPELINE != l_pp THEN
                IF l_pp != '***' THEN HTP.P('</div>'); END IF;
                HTP.P('<h3 style="margin:20px 0 8px;font-size:14px;color:#555;text-transform:uppercase;letter-spacing:1px">'
                    || rec.PIPELINE || '</h3><div style="display:flex;flex-wrap:wrap;gap:12px">');
                l_pp := rec.PIPELINE;
            END IF;

            l_phase   := phase_from_work(rec.WORK_STATUS);
            l_failerr := GREATEST(NVL(rec.FAILED_ROWS,0) - NVL(rec.UNACC_ROWS,0), 0);
            -- A parent coordinator processed no records of its own; do not colour it by
            -- the object's rolled-up counts (that would double-report the children).
            -- It is a neutral placeholder. Children and normal items keep the palette.
            IF rec.IS_PARENT = 1 THEN
                l_bg := '#eef2f7';   -- neutral slate: a coordinator, not a load
            ELSE
                l_bg := tile_bg(l_phase, rec.TOT_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNACC_ROWS);
            END IF;
              HTP.P('<div style="background:' || l_bg
                  || CASE WHEN rec.IS_PARENT = 1 THEN ';border:1px dashed #9aa7b8' ELSE ';border:1px solid #ddd' END
                  || CASE WHEN rec.IS_CHILD = 1 THEN ';border-left:4px solid #9aa7b8' END
                  || ';border-radius:8px;padding:14px;min-width:200px;max-width:280px;flex:1">');
              HTP.P('<div style="font-weight:bold;font-size:14px;margin-bottom:4px">');
              -- Title. A child tile is annotated with its partition value so it is not
              -- confused with the parent or with a sibling partition.
              IF rec.IS_PARENT = 1 THEN
                  -- Parent placeholder: name + a coordinator badge; NOT a drill link
                  -- (it holds no records of its own).
                  HTP.P('<span style="color:#33475b">' || rec.CEMLI_CODE || '</span>'
                      || ' <span style="font-weight:normal;font-size:10px;background:#9aa7b8;color:#fff;'
                      || 'border-radius:3px;padding:1px 5px;vertical-align:middle">PARTITION PARENT</span>');
              ELSIF NVL(rec.TOT_ROWS,0) = 0 THEN
                  HTP.P('<span style="color:#999">' || rec.CEMLI_CODE || '</span>');
                  IF rec.IS_CHILD = 1 AND rec.PARTITION_LABEL IS NOT NULL THEN
                      HTP.P(' <span style="font-weight:normal;font-size:11px;color:#555">&#9656; '
                          || rec.PARTITION_LABEL || '</span>');
                  END IF;
              ELSE
                  HTP.P('<a href="f?p=' || l_app || ':52:' || l_ses || '::NO::P52_RUN_ID,P52_CEMLI_CODE:'
                      || rec.RUN_ID || ',' || rec.CEMLI_CODE
                      || '" style="color:inherit;text-decoration:none;border-bottom:1px dashed #999">'
                      || rec.CEMLI_CODE || '</a>');
                  IF rec.IS_CHILD = 1 AND rec.PARTITION_LABEL IS NOT NULL THEN
                      HTP.P(' <span style="font-weight:normal;font-size:11px;color:#555">&#9656; '
                          || rec.PARTITION_LABEL || '</span>');
                  END IF;
              END IF;
              HTP.P('</div><div style="font-size:12px;color:#555">');
            IF rec.IS_PARENT = 1 THEN
                -- Parent placeholder line (backlog #70): state what it split on. No
                -- counts, no load/import ids (those live on the children). The partition
                -- COLUMN name(s) come from the structured JSON parser (part_key_names);
                -- the friendly "(split into N partition(s))" text sits in PARTITION_LABEL.
                l_part_keys := part_key_names(rec.OWN_QUEUE_ID);
                HTP.P('<span style="color:#33475b">Coordinator &mdash; '
                    || NVL(rec.PARTITION_LABEL, 'partitioned') || '</span>');
                IF l_part_keys IS NOT NULL THEN
                    HTP.P('<br>Partitioned on: <b>' || l_part_keys || '</b>');
                END IF;
            ELSE
                HTP.P(tile_status(l_phase, rec.TOT_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNACC_ROWS));
                -- Item #74: surface the partition value as a first-class labelled field.
                -- A genuine spawn-per-partition child carries a real partition value --
                -- its PARTITION_KEY is a JSON object, e.g. {"BATCH_ID":"8102"} or
                -- {"BOOK_TYPE_CODE":"US CORP"} (per DMT_WORK_QUEUE_TBL.PARTITION_KEY comment);
                -- the scalar already lives in PARTITION_LABEL. Show it as "Partition: <value>".
                -- The in-zip FBDI split sentinel (PARTITION_KEY 'ALL', label 'All Groups')
                -- and any un-partitioned item keep the lighter inline suffix instead.
                IF rec.PARTITION_KEY IS NOT NULL AND rec.PARTITION_KEY <> 'ALL'
                   AND rec.PARTITION_LABEL IS NOT NULL THEN
                    HTP.P('<br><span style="color:#555">Partition: </span>'
                        || '<strong>' || rec.PARTITION_LABEL || '</strong>');
                ELSIF rec.PARTITION_LABEL IS NOT NULL THEN
                    HTP.P(' &middot; <span style="color:#888">' || rec.PARTITION_LABEL || '</span>');
                END IF;
            END IF;
            IF rec.STARTED IS NOT NULL THEN
                HTP.P('<br>' || rec.STARTED || CASE WHEN rec.COMPLETED IS NOT NULL THEN ' &rarr; ' || rec.COMPLETED END);
            END IF;
            IF rec.LOAD_ESS_JOB_ID IS NOT NULL THEN
                HTP.P('<br>Load: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.LOAD_ESS_JOB_ID || ',' || rec.RUN_ID || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.LOAD_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.IMPORT_ESS_JOB_ID IS NOT NULL THEN
                HTP.P(' &middot; Import: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.IMPORT_ESS_JOB_ID || ',' || rec.RUN_ID || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.IMPORT_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.ERROR_MESSAGE IS NOT NULL THEN
                HTP.P('<br><span style="color:#c42b1c;font-size:11px">' || SUBSTR(rec.ERROR_MESSAGE, 1, 120) || '</span>');
            END IF;
            HTP.P('</div></div>');
        END LOOP;
        IF l_pp != '***' THEN HTP.P('</div>'); END IF;
    ELSE
        -- Sync path: derive tiles from CEMLI_SEQUENCE via DMT_PIPELINE_SUMMARY_V
        FOR rec IN (
            SELECT v.OBJECT_TYPE AS CEMLI_CODE,
                   v.PIPELINE,
                   v.OBJECT_STATUS,
                   v.TOTAL_ROWS,
                   v.LOADED_ROWS,
                   v.FAILED_ROWS,
                   v.UNRECONCILED_ROWS,
                   v.LOAD_ESS_JOB_ID,
                   v.IMPORT_ESS_JOB_ID,
                   v.SORT_ORDER
            FROM DMT_PIPELINE_SUMMARY_V v
            WHERE v.RUN_ID = p_run_id
            AND   v.OBJECT_TYPE != '__PIPELINE__'
            ORDER BY
                CASE v.PIPELINE
                    WHEN 'Configuration' THEN 0 WHEN 'MasterData' THEN 1
                    WHEN 'P2P' THEN 2 WHEN 'O2C' THEN 3
                    WHEN 'Financials' THEN 4 WHEN 'Projects' THEN 5
                    WHEN 'Standalone' THEN 6 WHEN 'HCM' THEN 7 ELSE 9
                END,
                v.SORT_ORDER
        ) LOOP
            IF rec.PIPELINE != l_pp THEN
                IF l_pp != '***' THEN HTP.P('</div>'); END IF;
                HTP.P('<h3 style="margin:20px 0 8px;font-size:14px;color:#555;text-transform:uppercase;letter-spacing:1px">'
                    || rec.PIPELINE || '</h3><div style="display:flex;flex-wrap:wrap;gap:12px">');
                l_pp := rec.PIPELINE;
            END IF;

            l_phase   := phase_from_object(rec.OBJECT_STATUS);
            l_failerr := GREATEST(NVL(rec.FAILED_ROWS,0) - NVL(rec.UNRECONCILED_ROWS,0), 0);
            l_bg := tile_bg(l_phase, rec.TOTAL_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNRECONCILED_ROWS);
              HTP.P('<div style="background:' || l_bg || ';border:1px solid #ddd;border-radius:8px;padding:14px;min-width:200px;max-width:280px;flex:1">');
              HTP.P('<div style="font-weight:bold;font-size:14px;margin-bottom:4px">');
              IF NVL(rec.TOTAL_ROWS, 0) = 0 THEN
                  HTP.P('<span style="color:#999">' || rec.CEMLI_CODE || '</span>');
              ELSE
                  HTP.P('<a href="f?p=' || l_app || ':52:' || l_ses || '::NO::P52_RUN_ID,P52_CEMLI_CODE:'
                      || p_run_id || ',' || rec.CEMLI_CODE
                      || '" style="color:inherit;text-decoration:none;border-bottom:1px dashed #999">'
                      || rec.CEMLI_CODE || '</a>');
              END IF;
              HTP.P('</div><div style="font-size:12px;color:#555">');
            HTP.P(tile_status(l_phase, rec.TOTAL_ROWS, rec.LOADED_ROWS, l_failerr, rec.UNRECONCILED_ROWS));

            IF rec.LOAD_ESS_JOB_ID IS NOT NULL THEN
                HTP.P('<br>Load: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.LOAD_ESS_JOB_ID || ',' || p_run_id || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.LOAD_ESS_JOB_ID || '</a>');
            END IF;
            IF rec.IMPORT_ESS_JOB_ID IS NOT NULL THEN
                HTP.P(' &middot; Import: <a href="f?p=' || l_app || ':53:' || l_ses
                    || '::NO::P53_ESS_JOB_ID,P53_RUN_ID,P53_CEMLI_CODE:'
                    || rec.IMPORT_ESS_JOB_ID || ',' || p_run_id || ',' || rec.CEMLI_CODE
                    || '" style="color:#0070d2">' || rec.IMPORT_ESS_JOB_ID || '</a>');
            END IF;

            HTP.P('</div></div>');
        END LOOP;
        IF l_pp != '***' THEN HTP.P('</div>'); END IF;
    END IF;
  END RENDER_RUN_TILES;

  -- ================================================================
  -- Page 82: Run Detail header bar (folded from DMT_RUN_DETAIL_HEADER, #41)
  -- ================================================================
  PROCEDURE RENDER_RUN_HEADER(p_run_id IN NUMBER) IS
    l_rec DMT_PIPELINE_RUN_TBL%ROWTYPE;
    l_d NUMBER; l_t NUMBER; l_f NUMBER; l_sc VARCHAR2(100);
  BEGIN
    SELECT * INTO l_rec FROM DMT_PIPELINE_RUN_TBL WHERE RUN_ID = p_run_id;
    SELECT COUNT(*), SUM(CASE WHEN WORK_STATUS='DONE' THEN 1 ELSE 0 END),
           SUM(CASE WHEN WORK_STATUS='FAILED' THEN 1 ELSE 0 END)
    INTO l_t, l_d, l_f FROM DMT_WORK_QUEUE_TBL WHERE RUN_ID = p_run_id;
    l_sc := CASE l_rec.RUN_STATUS
        WHEN 'COMPLETED' THEN 'color:#1a9c3e' WHEN 'COMPLETED_ERRORS' THEN 'color:#e07600'
        WHEN 'FAILED' THEN 'color:#c42b1c' WHEN 'IN_PROGRESS' THEN 'color:#0070d2'
        WHEN 'QUEUED' THEN 'color:#6b48c9' ELSE 'color:#333' END;
    HTP.P('<div style="display:flex;gap:24px;flex-wrap:wrap;align-items:center;padding:8px 0">');
    HTP.P('<span style="font-size:20px;font-weight:bold">Run #' || l_rec.RUN_ID || '</span>');
    HTP.P('<span style="' || l_sc || ';font-weight:bold;font-size:16px">' || l_rec.RUN_STATUS || '</span>');
    HTP.P('<span>' || l_rec.PIPELINE_CODES || '</span> <span>Prefix: ' || l_rec.PREFIX || '</span>');
    HTP.P('<span>' || NVL(l_rec.SCENARIO_NAME, 'All rows') || '</span> <span>' || l_rec.RUN_MODE || '</span>');
    HTP.P('<span>' || l_d || '/' || l_t || CASE WHEN l_f > 0 THEN ' (' || l_f || ' failed)' END || '</span>');
    HTP.P('<a href="' || APEX_PAGE.GET_URL(p_page=>54, p_items=>'P54_RUN_ID', p_values=>TO_CHAR(p_run_id))
        || '" style="color:#0070d2;text-decoration:none;font-weight:600">View Activity Log &rarr;</a></div>');
  EXCEPTION WHEN NO_DATA_FOUND THEN HTP.P('<p>Run not found.</p>');
  END RENDER_RUN_HEADER;

  -- ================================================================
  -- Pages 52/53: detail breadcrumb (folded from DMT_OBJECT_DETAIL_BREADCRUMB, #41)
  -- ================================================================
  PROCEDURE RENDER_DETAIL_BREADCRUMB(p_run_id IN NUMBER, p_cemli_code IN VARCHAR2) IS
    v_cemli VARCHAR2(200) := NVL(p_cemli_code, 'Unknown');
  BEGIN
    HTP.P('<nav style="font-size:13px;padding:4px 0 12px 0;color:#888;">');
    HTP.P('<a href="' || APEX_PAGE.GET_URL(p_page => 80) || '" class="dmt-link">Run History</a>');
    HTP.P(' &rsaquo; ');
    HTP.P('<a href="' || APEX_PAGE.GET_URL(p_page => 82, p_items => 'P82_RUN_ID', p_values => TO_CHAR(p_run_id)) || '" class="dmt-link">Run #' || p_run_id || '</a>');
    HTP.P(' &rsaquo; ');
    HTP.P('<span>' || HTF.ESCAPE_SC(v_cemli) || '</span>');
    HTP.P('</nav>');
  END RENDER_DETAIL_BREADCRUMB;

  -- ================================================================
  -- ESS job tree + files (folded from DMT_ESS_JOB_DETAIL, #41)
  -- ================================================================
  PROCEDURE RENDER_ESS_JOB_DETAIL(p_ess_job_id IN VARCHAR2, p_run_id IN NUMBER, p_cemli_code IN VARCHAR2) IS
    l_app VARCHAR2(10) := V('APP_ID');
    l_ses VARCHAR2(30) := V('APP_SESSION');
    v_cnt PLS_INTEGER := 0;
  BEGIN
    HTP.P('<h3 style="margin:0 0 12px">ESS Job Tree</h3>');
    HTP.P('<table class="t-Report-report" style="width:100%"><thead><tr>');
    HTP.P('<th>Request ID</th><th>Parent</th><th>Job</th><th>State</th><th>Submit</th><th>Start</th><th>End</th></tr></thead><tbody>');

    FOR rec IN (
        SELECT REQUEST_ID, PARENT_REQUEST_ID, JOB_SHORT_NAME, STATE,
               TO_CHAR(SUBMIT_TIME, 'HH24:MI:SS') AS SUB_T,
               TO_CHAR(START_TIME, 'HH24:MI:SS') AS START_T,
               TO_CHAR(END_TIME, 'HH24:MI:SS') AS END_T
        FROM DMT_ESS_JOB_TBL
        WHERE RUN_ID = p_run_id
        AND (REQUEST_ID = TO_NUMBER(p_ess_job_id) OR PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id)
             OR PARENT_REQUEST_ID IN (SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL WHERE PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id) AND RUN_ID = p_run_id))
        ORDER BY REQUEST_ID
    ) LOOP
        v_cnt := v_cnt + 1;
        HTP.P('<tr>');
        HTP.P('<td>' || rec.REQUEST_ID || '</td>');
        HTP.P('<td>' || NVL(TO_CHAR(rec.PARENT_REQUEST_ID), '-') || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(rec.JOB_SHORT_NAME) || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(rec.STATE) || '</td>');
        HTP.P('<td>' || rec.SUB_T || '</td>');
        HTP.P('<td>' || rec.START_T || '</td>');
        HTP.P('<td>' || rec.END_T || '</td>');
        HTP.P('</tr>');
    END LOOP;

    IF v_cnt = 0 THEN
        HTP.P('<tr><td colspan="7" style="text-align:center;padding:16px;color:#888">No ESS job records found.</td></tr>');
    END IF;
    HTP.P('</tbody></table>');

    -- ESS Job Files
    HTP.P('<h3 style="margin:20px 0 12px">ESS Job Files</h3>');
    v_cnt := 0;
    HTP.P('<table class="t-Report-report" style="width:100%"><thead><tr>');
    HTP.P('<th>Request ID</th><th>File Name</th><th>Type</th><th>Download</th></tr></thead><tbody>');

    FOR frec IN (
        SELECT f.ESS_FILE_ID, f.REQUEST_ID, f.FILE_NAME, f.CONTENT_TYPE
        FROM DMT_ESS_JOB_FILE_TBL f
        WHERE f.REQUEST_ID IN (
            SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL
            WHERE RUN_ID = p_run_id
            AND (REQUEST_ID = TO_NUMBER(p_ess_job_id) OR PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id)
                 OR PARENT_REQUEST_ID IN (SELECT REQUEST_ID FROM DMT_ESS_JOB_TBL WHERE PARENT_REQUEST_ID = TO_NUMBER(p_ess_job_id) AND RUN_ID = p_run_id))
        )
        ORDER BY f.REQUEST_ID, f.FILE_NAME
    ) LOOP
        v_cnt := v_cnt + 1;
        HTP.P('<tr>');
        HTP.P('<td>' || frec.REQUEST_ID || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(frec.FILE_NAME) || '</td>');
        HTP.P('<td>' || HTF.ESCAPE_SC(frec.CONTENT_TYPE) || '</td>');
        HTP.P('<td><a href="f?p=' || l_app || ':58:' || l_ses || '::NO::P58_REQUEST_ID:' || frec.REQUEST_ID || '">View</a></td>');
        HTP.P('</tr>');
    END LOOP;

    IF v_cnt = 0 THEN
        HTP.P('<tr><td colspan="4" style="text-align:center;padding:16px;color:#888">No files captured.</td></tr>');
    END IF;
    HTP.P('</tbody></table>');
  END RENDER_ESS_JOB_DETAIL;

  -- ================================================================
  -- Page 8 (Admin): generic view renderer (folded from DMT_RENDER_VIEW, #41)
  -- ================================================================
  PROCEDURE RENDER_VIEW(p_view_name IN VARCHAR2, p_title IN VARCHAR2) IS
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
  END RENDER_VIEW;

  -- ================================================================
  -- Page 84: execution-plan preview (folded from DMT_PLAN_PREVIEW_HTML, #41)
  -- ================================================================
  PROCEDURE RENDER_PLAN_PREVIEW(p_codes IN VARCHAR2) IS
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
  END RENDER_PLAN_PREVIEW;

END DMT_APEX_PAGE_PKG;
/
