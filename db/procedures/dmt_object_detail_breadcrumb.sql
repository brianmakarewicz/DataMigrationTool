-- PROCEDURE DMT_OBJECT_DETAIL_BREADCRUMB

  CREATE OR REPLACE EDITIONABLE PROCEDURE "DMT_OBJECT_DETAIL_BREADCRUMB" (p_run_id IN NUMBER, p_cemli_code IN VARCHAR2) IS
    v_cemli VARCHAR2(200) := NVL(p_cemli_code, 'Unknown');
BEGIN
    HTP.P('<nav style="font-size:13px;padding:4px 0 12px 0;color:#888;">');
    HTP.P('<a href="' || APEX_PAGE.GET_URL(p_page => 80) || '" class="dmt-link">Run History</a>');
    HTP.P(' &rsaquo; ');
    HTP.P('<a href="' || APEX_PAGE.GET_URL(p_page => 82, p_items => 'P82_RUN_ID', p_values => TO_CHAR(p_run_id)) || '" class="dmt-link">Run #' || p_run_id || '</a>');
    HTP.P(' &rsaquo; ');
    HTP.P('<span>' || HTF.ESCAPE_SC(v_cemli) || '</span>');
    HTP.P('</nav>');
END;
/
