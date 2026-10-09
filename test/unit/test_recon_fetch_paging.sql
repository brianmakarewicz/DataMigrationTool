-- ============================================================
-- test_recon_fetch_paging.sql - unit tests for the reconciliation fetch
-- paging rules in DMT_RECON_CONTRACT_PKG (backlog #680).
--
-- Self-contained SQLcl/SQL*Plus script (NOT a database object).
-- Run as DMT_OWNER against a full DMT2 install:
--   sql dmt_owner/...@//localhost:1523/FREEPDB1 @test/unit/test_recon_fetch_paging.sql
--
-- What is proven (design section 5, "Reconciliation fetches page on header
-- boundaries", owner decision 2026-10-09):
--   * A page is the next N headers plus every row of those headers. The page
--     size counts headers, so a page with fewer headers than N is the last
--     page however many rows it holds.
--   * The cursor sent for the next page is the last HEADER key (PAGE_KEY),
--     never a row key, so a document is never split across two pages.
--   * There is no page-count cap: 300 one-header pages are all read.
--   * A page that does not advance past the cursor, or a full page with no
--     key to continue from, fails with an error; it never returns success.
--   * A single-grain report (no PAGE_KEY) still pages by RECORD_KEY.
--
-- How: ACCEPT_PAGE is the parse half of FETCH_ROWS (the transport half is
-- the BIP call). This script plays the BIP report itself: fake_page() builds
-- the page XML a header-paged data model returns for (P_AFTER_KEY,
-- P_CHUNK_SIZE) from an in-memory fixture, and run_fetch() drives ACCEPT_PAGE
-- with exactly the loop FETCH_ROWS uses. No Fusion call is made. The only
-- table written is the activity log (ACCEPT_PAGE logs each page), under the
-- test-only run id -680; those rows are deleted at the end.
-- ============================================================

whenever sqlerror exit failure
set serveroutput on size unlimited
set feedback off
set define off

declare
    c_run      constant number := -680;
    l_passed   pls_integer := 0;

    -- Fixture. g_hdrs = the header (document) keys in ascending order; g_rows =
    -- one entry per report row (its header and its row key). Row keys sort
    -- AFTER every header key ('R...' > 'H...') and in the opposite order to
    -- their headers, so a fetch that sent a row key as the cursor would skip
    -- every remaining document (test 2 catches that).
    type t_row  is record (hdr varchar2(100), rec varchar2(100));
    type t_rows is table of t_row index by pls_integer;
    type t_keys is table of varchar2(100) index by pls_integer;
    g_hdrs     t_keys;
    g_rows     t_rows;
    g_with_hdr boolean;              -- false = a single-grain report (no PAGE_KEY)

    -- What one fetch saw.
    l_rows     dmt_recon_contract_pkg.t_recon_tbl;
    l_pages    pls_integer;          -- report pages that returned rows
    l_calls    pls_integer;          -- report calls made (an empty last call counts)
    l_err      number;
    l_cursors  varchar2(32767);      -- the cursors sent after page 1, '|'-joined
    type t_map is table of pls_integer index by varchar2(100);
    l_hdr_page t_map;                -- header -> the page it was first seen on
    l_split    pls_integer;          -- headers seen on more than one page

    l_xml      xmltype;
    l_next     varchar2(1000);
    l_last     varchar2(1);
    l_cnt      pls_integer;

    procedure assert (p_cond boolean, p_num pls_integer, p_name varchar2) is
    begin
        if p_cond then
            l_passed := l_passed + 1;
            dbms_output.put_line('PASS  ' || lpad(p_num, 2) || '  ' || p_name);
        else
            raise_application_error(-20999, 'FAIL test ' || p_num || ': ' || p_name);
        end if;
    end assert;

    -- Build a fixture: p_children(i) rows under header i. Header keys are
    -- 'H' || lpad(i, 4, '0'), so their text order is their numeric order.
    procedure fixture (p_children sys.odcinumberlist, p_with_hdr boolean) is
        l_h varchar2(100);
        n   pls_integer;
    begin
        g_hdrs.delete;
        g_rows.delete;
        g_with_hdr := p_with_hdr;
        for i in 1 .. p_children.count loop
            l_h := 'H' || lpad(i, 4, '0');
            g_hdrs(i) := l_h;
            for c in 1 .. p_children(i) loop
                n := g_rows.count + 1;
                g_rows(n).hdr := l_h;
                g_rows(n).rec := 'R' || lpad(10000 - i, 5, '0') || ':' || c;
            end loop;
        end loop;
    end fixture;

    -- The report: the next p_chunk headers after p_after and EVERY row of them,
    -- grouped by header; NULL when nothing qualifies (as RUN_BIP_REPORT returns
    -- for an empty report). A single-grain report emits each row as its own
    -- header (one row per header) and no PAGE_KEY element. p_ignore_after
    -- plays a broken report that always restarts from the beginning.
    function fake_page (p_after varchar2, p_chunk pls_integer,
                        p_ignore_after boolean default false) return xmltype is
        l_doc  clob := '<DATA_DS>';
        l_took pls_integer := 0;
        l_any  boolean := false;
    begin
        for i in 1 .. g_hdrs.count loop
            exit when l_took >= p_chunk;
            if p_ignore_after or p_after is null or g_hdrs(i) > p_after then
                l_took := l_took + 1;
                for r in 1 .. g_rows.count loop
                    if g_rows(r).hdr = g_hdrs(i) then
                        l_any := true;
                        l_doc := l_doc || '<G_1><OBJECT_TYPE>T</OBJECT_TYPE>'
                              || '<RECORD_KEY>'
                              || case when g_with_hdr then g_rows(r).rec else g_hdrs(i) end
                              || '</RECORD_KEY><SOURCE_TYPE>BASE</SOURCE_TYPE>'
                              || '<FUSION_STATUS>SUCCESS</FUSION_STATUS><FUSION_ID>' || r
                              || '</FUSION_ID>'
                              || case when g_with_hdr
                                      then '<PAGE_KEY>' || g_hdrs(i) || '</PAGE_KEY>' end
                              || '</G_1>';
                    end if;
                end loop;
            end if;
        end loop;
        if not l_any then
            return null;
        end if;
        return xmltype(l_doc || '</DATA_DS>');
    end fake_page;

    -- The FETCH_ROWS loop, with fake_page in place of RUN_BIP_REPORT.
    procedure run_fetch (p_chunk pls_integer) is
        l_after varchar2(1000);
        l_before pls_integer;
    begin
        l_rows.delete;
        l_hdr_page.delete;
        l_pages := 0; l_calls := 0; l_split := 0; l_cursors := null;
        l_err := dmt_util_pkg.c_success;
        loop
            l_calls := l_calls + 1;
            l_xml := fake_page(l_after, p_chunk);
            exit when l_xml is null;
            l_pages  := l_pages + 1;
            l_before := l_rows.count;
            dmt_recon_contract_pkg.accept_page(
                p_page_xml   => l_xml,
                p_chunk_size => p_chunk,
                p_after_key  => l_after,
                x_rows       => l_rows,
                x_next_key   => l_next,
                x_last_page  => l_last,
                x_error_code => l_err,
                p_run_id     => c_run,
                p_cemli_code => 'UNIT_TEST_680',
                p_page_no    => l_pages);
            if l_err <> dmt_util_pkg.c_success then
                l_rows.delete;
                return;
            end if;
            -- Which page each document's rows arrived on (FUSION_ID = fixture row).
            for i in l_before + 1 .. l_rows.count loop
                if l_hdr_page.exists(g_rows(to_number(l_rows(i).fusion_id)).hdr) then
                    if l_hdr_page(g_rows(to_number(l_rows(i).fusion_id)).hdr) <> l_pages then
                        l_split := l_split + 1;
                    end if;
                else
                    l_hdr_page(g_rows(to_number(l_rows(i).fusion_id)).hdr) := l_pages;
                end if;
            end loop;
            exit when l_last = 'Y';
            l_after   := l_next;
            l_cursors := l_cursors || '|' || l_next;
        end loop;
    end run_fetch;
begin
    -- 1-4. Header paging: 5 documents with 2, 1, 3, 1 and 4 rows (11 rows),
    --      page size 2 headers.
    fixture(sys.odcinumberlist(2, 1, 3, 1, 4), true);
    run_fetch(2);
    assert(l_err = dmt_util_pkg.c_success and l_rows.count = 11 and l_hdr_page.count = 5,
           1, 'multi-page header fetch returns all 11 rows of all 5 documents');
    assert(l_cursors = '|H0002|H0004',
           2, 'the cursor sent for each next page is the last header key (H0002, H0004)');
    assert(l_split = 0 and l_hdr_page('H0001') = 1 and l_hdr_page('H0003') = 2
           and l_hdr_page('H0005') = 3,
           3, 'no document is split: every row of a document arrives on one page');
    -- Page 3 holds one header with 4 rows (rows >= page size 2) and is still
    -- the last page: the page size counts headers, so no 4th call is made.
    assert(l_pages = 3 and l_calls = 3,
           4, 'a page with fewer headers than the page size ends the fetch, however many rows it has');

    -- 5. A document with more rows than the page size, on a full page, is
    --    neither cut nor ends the fetch early: 3 documents of 5 rows, size 1.
    fixture(sys.odcinumberlist(5, 5, 5), true);
    run_fetch(1);
    assert(l_err = dmt_util_pkg.c_success and l_rows.count = 15 and l_split = 0
           and l_pages = 3 and l_calls = 4,
           5, 'size-1 pages of 5-row documents: 15 rows, 3 pages, then an empty call ends it');

    -- 6. No page-count cap: 300 documents read one per page.
    declare
        l_list sys.odcinumberlist := sys.odcinumberlist();
    begin
        l_list.extend(300);
        for i in 1 .. 300 loop
            l_list(i) := 1 + mod(i, 3);
        end loop;
        fixture(l_list, true);
    end;
    run_fetch(1);
    assert(l_err = dmt_util_pkg.c_success and l_hdr_page.count = 300 and l_split = 0
           and l_pages = 300 and l_rows.count = 600,
           6, 'no page cap: 300 one-document pages are all read (600 rows)');

    -- 7. A report that ignores the cursor (it restarts from the first
    --    document) fails the fetch with an error instead of looping or
    --    returning success.
    fixture(sys.odcinumberlist(2, 1, 3), true);
    l_rows.delete;
    l_xml := fake_page(null, 2);
    dmt_recon_contract_pkg.accept_page(
        p_page_xml => l_xml, p_chunk_size => 2, p_after_key => null,
        x_rows => l_rows, x_next_key => l_next, x_last_page => l_last,
        x_error_code => l_err, p_run_id => c_run, p_cemli_code => 'UNIT_TEST_680',
        p_page_no => 1);
    assert(l_err = dmt_util_pkg.c_success and l_next = 'H0002' and l_last = 'N',
           7, 'first page accepted: cursor H0002, more pages to come');
    l_xml := fake_page(l_next, 2, p_ignore_after => true);
    dmt_recon_contract_pkg.accept_page(
        p_page_xml => l_xml, p_chunk_size => 2, p_after_key => l_next,
        x_rows => l_rows, x_next_key => l_next, x_last_page => l_last,
        x_error_code => l_err, p_run_id => c_run, p_cemli_code => 'UNIT_TEST_680',
        p_page_no => 2);
    assert(l_err = dmt_util_pkg.c_error and l_next is null and l_last = 'Y',
           8, 'a page that starts at or before the cursor fails the fetch (no progress)');
    select count(*) into l_cnt
    from   dmt_log_tbl
    where  run_id = c_run
    and    log_type = dmt_util_pkg.c_log_error
    and    instr(sqlerrm_text, 'ORA-20681') > 0;
    assert(l_cnt >= 1, 9, 'the no-progress failure is logged as an ERROR carrying ORA-20681');

    -- 10. Single-grain report (no PAGE_KEY): pages by RECORD_KEY, the page size
    --     counts rows, and every row is read.
    fixture(sys.odcinumberlist(1, 1, 1, 1, 1), false);
    run_fetch(2);
    assert(l_err = dmt_util_pkg.c_success and l_rows.count = 5 and l_pages = 3
           and l_cursors = '|H0002|H0004',
           10, 'single-grain report pages by record key: 5 rows in 3 pages');

    -- 11. Single-grain report that does not advance fails too.
    l_rows.delete;
    l_xml := fake_page(null, 2);
    dmt_recon_contract_pkg.accept_page(
        p_page_xml => l_xml, p_chunk_size => 2, p_after_key => 'H0002',
        x_rows => l_rows, x_next_key => l_next, x_last_page => l_last,
        x_error_code => l_err, p_run_id => c_run, p_cemli_code => 'UNIT_TEST_680',
        p_page_no => 2);
    assert(l_err = dmt_util_pkg.c_error,
           11, 'a single-grain page that does not advance past its cursor fails');

    -- 12. A full page whose cursor column is empty cannot be continued from
    --     (a NULL cursor would restart the report): it fails.
    l_rows.delete;
    l_xml := xmltype('<DATA_DS><G_1><OBJECT_TYPE>T</OBJECT_TYPE><RECORD_KEY>A</RECORD_KEY>'
                     || '</G_1><G_1><OBJECT_TYPE>T</OBJECT_TYPE></G_1></DATA_DS>');
    dmt_recon_contract_pkg.accept_page(
        p_page_xml => l_xml, p_chunk_size => 2, p_after_key => null,
        x_rows => l_rows, x_next_key => l_next, x_last_page => l_last,
        x_error_code => l_err, p_run_id => c_run, p_cemli_code => 'UNIT_TEST_680',
        p_page_no => 1);
    assert(l_err = dmt_util_pkg.c_error,
           12, 'a full page with an empty last key fails (no cursor to continue from)');

    -- 13. FETCH_ROWS no longer carries a page-count cap.
    select count(*) into l_cnt
    from   user_source
    where  name = 'DMT_RECON_CONTRACT_PKG'
    and    type = 'PACKAGE BODY'
    and    (upper(text) like '%L_MAX_PAGES%' or upper(text) like '%PAGE CAP (%');
    assert(l_cnt = 0, 13, 'FETCH_ROWS has no page-count cap left');

    delete from dmt_log_tbl where run_id = c_run;
    commit;

    dbms_output.put_line('TEST_RECON_FETCH_PAGING: ' || l_passed || ' passed, 0 failed');
end;
/

exit success
