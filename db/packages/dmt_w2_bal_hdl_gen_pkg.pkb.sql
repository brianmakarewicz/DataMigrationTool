-- PACKAGE BODY DMT_W2_BAL_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_W2_BAL_HDL_GEN_PKG"
AS
-- ============================================================
-- DMT_W2_BAL_HDL_GEN_PKG body
-- Balance Initialization HDL DAT generation.
--
-- CORRECTED MODEL (2026-09-17) -- verified against Oracle docs and live on
-- this pod (HRC_INTEGRATION_KEY_MAP: InitializeBalanceBatchHeader = 7 keys,
-- InitializeBalanceBatchLine = 13 keys; base table PAY_BAL_BATCH_HEADERS):
--
--   Two HDL business objects in one zip:
--     InitializeBalanceBatchHeader.dat  METADATA:
--       BatchName|UploadDate|LegislativeDataGroupName
--     InitializeBalanceBatchLine.dat    METADATA:
--       LegislativeDataGroupName|BatchName|LineSequence|
--       PayrollRelationshipNumber|TermNumber|AssignmentNumber|PayrollName|
--       TaxUnitName|BalanceName|DimensionName|Value|ContextOneName|
--       ContextOneValue|AreaOne
--
--   One run = ONE batch. BatchName = <run prefix> || '_W2BAL'. The line
--   references the header purely by BatchName -- no worker record is repeated
--   and no SourceSystemId person-FK chain is emitted (batch objects are keyed
--   by BatchName, a user key, not by SourceSystemId).
--
--   Reconciliation matches PAY_BAL_BATCH_HEADERS.BATCH_NAME = the BatchName
--   and captures BATCH_ID as the Fusion id (see bip/W2Balances/query.sql).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_W2_BAL_HDL_GEN_PKG';

    -- METADATA column list for InitializeBalanceBatchHeader
    C_HEADER_OBJECT CONSTANT VARCHAR2(60) := 'InitializeBalanceBatchHeader';
    C_HEADER_COLS   CONSTANT VARCHAR2(4000) :=
        'BatchName|UploadDate|LegislativeDataGroupName';

    -- METADATA column list for InitializeBalanceBatchLine
    C_LINE_OBJECT CONSTANT VARCHAR2(60) := 'InitializeBalanceBatchLine';
    C_LINE_COLS   CONSTANT VARCHAR2(4000) :=
        'LegislativeDataGroupName|BatchName|LineSequence|PayrollRelationshipNumber|'
        || 'TermNumber|AssignmentNumber|PayrollName|TaxUnitName|BalanceName|'
        || 'DimensionName|Value|ContextOneName|ContextOneValue|AreaOne';

    -- HDL file names -- each named after its business object (HDL requirement).
    C_HEADER_FILE CONSTANT VARCHAR2(60) := 'InitializeBalanceBatchHeader.dat';
    C_LINE_FILE   CONSTANT VARCHAR2(60) := 'InitializeBalanceBatchLine.dat';

    -- BatchName suffix -- one batch per run.
    C_BATCH_SUFFIX CONSTANT VARCHAR2(10) := '_W2BAL';


    FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB IS
        l_blob         BLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(
            dest_lob     => l_blob,
            src_clob     => p_clob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_offset,
            src_offset   => l_src_offset,
            blob_csid    => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_context,
            warning      => l_warning);
        RETURN l_blob;
    END clob_to_blob;

    FUNCTION pv(p_val IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(p_val, '');
    END pv;

    -- Run prefix (drives the BatchName) -- one batch name per run.
    FUNCTION get_prefix(p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX INTO l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    FUNCTION has_rows(p_tbl VARCHAR2, p_iid NUMBER) RETURN BOOLEAN IS
        l_cnt NUMBER := 0;
    BEGIN
        -- Static SQL (code-standard #46: no runtime EXECUTE IMMEDIATE outside the
        -- 3 sanctioned catalog-driven dispatch sites). The table is a compile-time
        -- constant at each call site, so a static CASE dispatch is equivalent.
        CASE p_tbl
            WHEN 'DMT_W2_BAL_TFM_TBL' THEN
                SELECT COUNT(*) INTO l_cnt FROM DMT_W2_BAL_TFM_TBL
                 WHERE RUN_ID = p_iid AND TFM_STATUS = 'STAGED' AND ROWNUM = 1;
            WHEN 'DMT_W2_BAL_DTL_TFM_TBL' THEN
                SELECT COUNT(*) INTO l_cnt FROM DMT_W2_BAL_DTL_TFM_TBL
                 WHERE RUN_ID = p_iid AND TFM_STATUS = 'STAGED' AND ROWNUM = 1;
            ELSE
                RAISE_APPLICATION_ERROR(-20001,
                    'has_rows: unexpected table ' || p_tbl);
        END CASE;
        RETURN l_cnt > 0;
    END has_rows;


    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    )
    IS
        l_hdr_dat     CLOB;
        l_line_dat    CLOB;
        l_zip         BLOB;
        l_csv_id      NUMBER;
        l_now         DATE := SYSDATE;
        l_row_count   NUMBER := 0;
        l_line_seq    NUMBER := 0;
        l_vals        VARCHAR2(32767);
        l_prefix      VARCHAR2(30);
        l_batch_name  VARCHAR2(100);
        l_upload_date VARCHAR2(20);
        l_ldg         VARCHAR2(240);
        l_combined    CLOB;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL start.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

        x_filename := 'W2Balances_' || TO_CHAR(p_run_id) || '.zip';

        l_prefix      := get_prefix(p_run_id);
        l_batch_name  := l_prefix || C_BATCH_SUFFIX;      -- reconciliation key
        l_upload_date := TO_CHAR(l_now, 'YYYY/MM/DD');

        DBMS_LOB.CREATETEMPORARY(l_hdr_dat, TRUE);
        DBMS_LOB.CREATETEMPORARY(l_line_dat, TRUE);


        -- ============================================================
        -- 1. InitializeBalanceBatchHeader -- ONE header row for the run.
        -- LegislativeDataGroupName is taken from the header TFM rows (all
        -- rows of a batch share one LDG); fall back to the detail TFM.
        -- ============================================================
        IF has_rows('DMT_W2_BAL_TFM_TBL', p_run_id) THEN
            BEGIN
                SELECT MAX(LEGISLATIVE_DATA_GROUP_NAME) INTO l_ldg
                FROM   DMT_W2_BAL_TFM_TBL
                WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';
            EXCEPTION WHEN NO_DATA_FOUND THEN l_ldg := NULL;
            END;

            DBMS_LOB.WRITEAPPEND(l_hdr_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_HEADER_OBJECT, C_HEADER_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_HEADER_OBJECT, C_HEADER_COLS));

            l_vals := pv(l_batch_name)  || '|' ||
                      pv(l_upload_date) || '|' ||
                      pv(l_ldg);
            DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_hdr_dat, l_vals,
                p_discriminator => C_HEADER_OBJECT);
            l_row_count := l_row_count + 1;
        END IF;


        -- ============================================================
        -- 2. InitializeBalanceBatchLine -- one line per detail TFM row.
        -- Each line references the header by BatchName (no worker record
        -- repeated). LineSequence is a per-batch running number.
        -- ============================================================
        IF has_rows('DMT_W2_BAL_DTL_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_line_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_LINE_OBJECT, C_LINE_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_LINE_OBJECT, C_LINE_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_W2_BAL_DTL_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                l_line_seq := l_line_seq + 1;
                l_vals := pv(r.LEGISLATIVE_DATA_GROUP_NAME)  || '|' ||  -- LegislativeDataGroupName
                          pv(l_batch_name)                   || '|' ||  -- BatchName (FK to header)
                          TO_CHAR(l_line_seq)                || '|' ||  -- LineSequence
                          pv(r.PAYROLL_RELATIONSHIP_NUMBER)  || '|' ||  -- PayrollRelationshipNumber
                          ''                                 || '|' ||  -- TermNumber (not sourced)
                          ''                                 || '|' ||  -- AssignmentNumber (not sourced)
                          ''                                 || '|' ||  -- PayrollName (line-level not sourced)
                          ''                                 || '|' ||  -- TaxUnitName (not sourced)
                          pv(r.BALANCE_NAME)                 || '|' ||  -- BalanceName
                          pv(r.DIMENSION_NAME)               || '|' ||  -- DimensionName
                          pv(r.VALUE)                        || '|' ||  -- Value
                          pv(r.CONTEXT_NAME)                 || '|' ||  -- ContextOneName
                          pv(r.CONTEXT_VALUE)                || '|' ||  -- ContextOneValue
                          '';                                          -- AreaOne (not sourced)
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_line_dat, l_vals,
                    p_discriminator => C_LINE_OBJECT);
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- ZIP the two DAT files (each named after its business object).
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_hdr_dat) > 0 THEN
            UTL_ZIP.add1file(l_zip, C_HEADER_FILE, clob_to_blob(l_hdr_dat));
        END IF;
        IF DBMS_LOB.GETLENGTH(l_line_dat) > 0 THEN
            UTL_ZIP.add1file(l_zip, C_LINE_FILE, clob_to_blob(l_line_dat));
        END IF;
        UTL_ZIP.finish_zip(l_zip);


        -- ============================================================
        -- Store in DMT_FBDI_CSV_TBL + DMT_FBDI_ZIP_TBL.
        -- CSV_CONTENT holds the combined DAT text (header then lines) so the
        -- generated content is inspectable in one place.
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_combined, TRUE);
        IF DBMS_LOB.GETLENGTH(l_hdr_dat) > 0 THEN
            DBMS_LOB.APPEND(l_combined, l_hdr_dat);
        END IF;
        IF DBMS_LOB.GETLENGTH(l_line_dat) > 0 THEN
            DBMS_LOB.APPEND(l_combined, l_line_dat);
        END IF;

        SELECT DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;

        INSERT INTO DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'W2Balances',
            C_HEADER_FILE || '+' || C_LINE_FILE, l_row_count, l_combined, l_now
        );

        INSERT INTO DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'W2Balances', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID.
        -- ============================================================
        UPDATE DMT_W2_BAL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';

        UPDATE DMT_W2_BAL_DTL_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';


        DBMS_LOB.FREETEMPORARY(l_hdr_dat);
        DBMS_LOB.FREETEMPORARY(l_line_dat);
        DBMS_LOB.FREETEMPORARY(l_combined);

        x_hdl_zip := l_zip;
        x_csv_id  := l_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL complete. BatchName: ' || l_batch_name ||
                                ' | Total data lines: ' || l_row_count ||
                                ' | Zip size: ' || DBMS_LOB.GETLENGTH(l_zip) || ' bytes.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'GENERATE_HDL failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'GENERATE_HDL');
            RAISE;
    END GENERATE_HDL;

END DMT_W2_BAL_HDL_GEN_PKG;
/
