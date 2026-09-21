-- PACKAGE BODY DMT_RUN_SUMMARY_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_RUN_SUMMARY_PKG" AS
-- ============================================================
-- DMT_RUN_SUMMARY_PKG body — see the spec for the contract.
--
-- Every statement is static against DMT_RUN_RECORDS_V and compile-time-known
-- tables. There is NO EXECUTE IMMEDIATE. The live audit reuses
-- DMT_RECON_CONTRACT_PKG.FETCH_ROWS verbatim for the BIP transport, copies its
-- returned rows into the sanctioned SQL collection DMT_RECON_ROW_TBL, and joins
-- that collection to the view with a TABLE() cast — the same drop-in pattern
-- DMT_GL_RESULTS_PKG uses for its set-based apply.
-- ============================================================

    -- --------------------------------------------------------
    -- GET_RUN_ROLLUP
    -- --------------------------------------------------------
    PROCEDURE GET_RUN_ROLLUP (
        p_run_id IN  NUMBER,
        x_cursor OUT SYS_REFCURSOR
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'GET_RUN_ROLLUP';
    BEGIN
        OPEN x_cursor FOR
            SELECT r.RUN_ID,
                   h.RUN_STATUS,
                   h.PIPELINE_CODES,
                   h.PREFIX,
                   h.SCENARIO_NAME,
                   h.SUBMITTED_DATE,
                   h.COMPLETED_DATE,
                   r.OBJECT_TYPE,
                   r.CEMLI_CODE,
                   COUNT(*)                                            AS TOTAL_ROWS,
                   -- LOADED: positively confirmed in a base table (real Fusion id).
                   SUM(CASE WHEN r.TFM_STATUS = 'LOADED' THEN 1 ELSE 0 END)
                                                                       AS LOADED_ROWS,
                   -- FAILED: a real Fusion error captured. A FAILED row with NO
                   -- error text is NOT a clean failure — it is unaccounted (the
                   -- derived UNRECONCILED state), counted below, never here.
                   SUM(CASE WHEN r.TFM_STATUS = 'FAILED'
                             AND r.ERROR_TEXT IS NOT NULL THEN 1 ELSE 0 END)
                                                                       AS FAILED_ROWS,
                   -- UNACCOUNTED: the stored terminal UNACCOUNTED status, PLUS a
                   -- FAILED row carrying no error text (unexplained).
                   SUM(CASE WHEN r.TFM_STATUS = 'UNACCOUNTED'
                              OR (r.TFM_STATUS = 'FAILED' AND r.ERROR_TEXT IS NULL)
                            THEN 1 ELSE 0 END)                         AS UNACCOUNTED_ROWS,
                   -- GENERATED: still in flight (not yet settled). The TFM
                   -- lifecycle is STAGED -> GENERATED -> LOADED/FAILED, so both
                   -- non-terminal statuses (STAGED and GENERATED) count here as
                   -- one "in flight" bucket; this makes the four buckets
                   -- (LOADED + FAILED + UNACCOUNTED + GENERATED) partition TOTAL
                   -- exactly.
                   SUM(CASE WHEN r.TFM_STATUS IN ('GENERATED','STAGED')
                            THEN 1 ELSE 0 END)                         AS GENERATED_ROWS
            FROM   DMT_RUN_RECORDS_V r
            JOIN   DMT_PIPELINE_RUN_TBL h
              ON   h.RUN_ID = r.RUN_ID
            WHERE  r.RUN_ID = p_run_id
            GROUP  BY r.RUN_ID, h.RUN_STATUS, h.PIPELINE_CODES, h.PREFIX,
                      h.SCENARIO_NAME, h.SUBMITTED_DATE, h.COMPLETED_DATE,
                      r.OBJECT_TYPE, r.CEMLI_CODE
            ORDER  BY r.OBJECT_TYPE;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed for run ' || p_run_id || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END GET_RUN_ROLLUP;

    -- --------------------------------------------------------
    -- GET_RUN_RECORDS
    -- --------------------------------------------------------
    PROCEDURE GET_RUN_RECORDS (
        p_run_id IN  NUMBER,
        p_object IN  VARCHAR2 DEFAULT NULL,
        p_status IN  VARCHAR2 DEFAULT NULL,
        x_cursor OUT SYS_REFCURSOR
    ) IS
        C_PROC CONSTANT VARCHAR2(30) := 'GET_RUN_RECORDS';
    BEGIN
        OPEN x_cursor FOR
            SELECT r.RUN_ID,
                   r.WORK_QUEUE_ID,
                   r.CEMLI_CODE,
                   r.OBJECT_TYPE,
                   r.SUB_OBJECT,
                   r.TFM_SEQUENCE_ID,
                   r.RECON_KEY,
                   r.TFM_STATUS,
                   r.FUSION_ID,
                   r.ERROR_TEXT,
                   r.DMT_REFERENCE,
                   -- Deep link: built by the shared helper, the single
                   -- source of truth for deep-link construction (correct
                   -- '{ID}' token, Fusion base URL and hcmUI/fscmUI path).
                   -- It returns NULL when the object has no template, no
                   -- Fusion URL is configured, or the row has no Fusion id
                   -- — never a fabricated or broken link.
                   DMT_UTIL_PKG.GET_DEEP_LINK(
                       r.CEMLI_CODE, TO_CHAR(r.FUSION_ID)
                   )                                          AS FUSION_DEEP_LINK
            FROM   DMT_RUN_RECORDS_V r
            WHERE  r.RUN_ID = p_run_id
            AND    (p_object IS NULL OR r.OBJECT_TYPE = p_object)
            AND    (p_status IS NULL OR r.TFM_STATUS  = p_status)
            ORDER  BY r.OBJECT_TYPE, r.TFM_SEQUENCE_ID;
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed for run ' || p_run_id
                               || ', object ' || NVL(p_object, '(all)') || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END GET_RUN_RECORDS;

    -- --------------------------------------------------------
    -- AUDIT_IN_FUSION
    -- --------------------------------------------------------
    PROCEDURE AUDIT_IN_FUSION (
        p_run_id     IN  NUMBER,
        p_cemli_code IN  VARCHAR2,
        x_cursor     OUT SYS_REFCURSOR,
        x_error_code OUT NUMBER
    ) IS
        C_PROC          CONSTANT VARCHAR2(30) := 'AUDIT_IN_FUSION';
        l_contract_ver  NUMBER;
        l_fetch_rows    DMT_RECON_CONTRACT_PKG.T_RECON_TBL;
        l_fetch_code    NUMBER;
        l_sql_rows      DMT_RECON_ROW_TBL := DMT_RECON_ROW_TBL();
        l_load_ess_id   NUMBER;
        l_row_cap       NUMBER;
    BEGIN
        x_error_code := DMT_UTIL_PKG.C_ERROR;

        -- Gate: the live audit only supports the Contract v1 report shape.
        BEGIN
            SELECT CONTRACT_VERSION
              INTO l_contract_ver
              FROM DMT_BIP_REPORT_TBL
             WHERE CEMLI_CODE = p_cemli_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_contract_ver := NULL;
        END;

        IF l_contract_ver IS NULL OR l_contract_ver <> 1 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': object ' || p_cemli_code
                               || ' is not registered as Contract v1 (CONTRACT_VERSION='
                               || NVL(TO_CHAR(l_contract_ver), '(none)')
                               || '); live audit not supported. Returning empty cursor.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            -- Honest empty result, with the error code set.
            OPEN x_cursor FOR
                SELECT CAST(NULL AS VARCHAR2(100)) AS OBJECT_TYPE,
                       CAST(NULL AS VARCHAR2(1000)) AS RECORD_KEY,
                       CAST(NULL AS VARCHAR2(20))  AS SOURCE_TYPE,
                       CAST(NULL AS VARCHAR2(20))  AS FUSION_STATUS,
                       CAST(NULL AS NUMBER)        AS FUSION_ID,
                       CAST(NULL AS VARCHAR2(4000))AS ERROR_MESSAGE,
                       CAST(NULL AS VARCHAR2(100)) AS LOAD_REQUEST_ID,
                       CAST(NULL AS NUMBER)        AS TFM_SEQUENCE_ID,
                       CAST(NULL AS VARCHAR2(240)) AS DMT_REFERENCE,
                       CAST(NULL AS VARCHAR2(30))  AS TFM_STATUS,
                       CAST(NULL AS NUMBER)        AS STORED_FUSION_ID
                FROM   DUAL
                WHERE  1 = 0;
            RETURN;
        END IF;

        -- Row cap for the shared fetch's keyset paging = this run's record count
        -- for the object (from the view, static).
        SELECT COUNT(*)
          INTO l_row_cap
          FROM DMT_RUN_RECORDS_V
         WHERE RUN_ID = p_run_id
           AND CEMLI_CODE = p_cemli_code;

        -- The load ESS job id for this object/run (best available; NULL is fine —
        -- FETCH_ROWS treats it as the Contract v1 P_LOAD_REQUEST_ID). LOAD_ESS_JOB_ID
        -- is a VARCHAR2 column, so convert deliberately: take the numeric-only
        -- values and MAX those as numbers (a lexical MAX on the raw string would
        -- order "9" above "10", and an implicit TO_NUMBER would raise on a
        -- non-numeric id). A non-numeric or absent id yields NULL.
        BEGIN
            SELECT MAX(TO_NUMBER(REGEXP_SUBSTR(LOAD_ESS_JOB_ID, '^\d+$')))
              INTO l_load_ess_id
              FROM DMT_WORK_QUEUE_TBL
             WHERE RUN_ID = p_run_id
               AND CEMLI_CODE = p_cemli_code;
        EXCEPTION
            WHEN OTHERS THEN
                l_load_ess_id := NULL;
        END;

        -- Reuse the shared Contract v1 fetch verbatim (owns all BIP transport,
        -- no dynamic SQL, never touches a TFM table).
        DMT_RECON_CONTRACT_PKG.FETCH_ROWS(
            p_cemli_code  => p_cemli_code,
            p_run_id      => p_run_id,
            p_load_ess_id => l_load_ess_id,
            p_row_cap     => l_row_cap,
            x_rows        => l_fetch_rows,
            x_error_code  => l_fetch_code);

        IF l_fetch_code <> DMT_UTIL_PKG.C_SUCCESS THEN
            -- The fetch already logged the failure detail. Return honest empty.
            DMT_UTIL_PKG.LOG(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ': live fetch failed for ' || p_cemli_code
                               || ' (detail in DMT_LOG_TBL); returning empty cursor.',
                p_log_type  => DMT_UTIL_PKG.C_LOG_WARN,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            OPEN x_cursor FOR
                SELECT r.OBJECT_TYPE, r.RECORD_KEY, r.SOURCE_TYPE, r.FUSION_STATUS,
                       r.FUSION_ID,
                       CAST(r.ERROR_MESSAGE AS VARCHAR2(4000)) AS ERROR_MESSAGE,
                       CAST(TO_CHAR(r.LOAD_REQUEST_ID) AS VARCHAR2(100)) AS LOAD_REQUEST_ID,
                       CAST(NULL AS NUMBER) AS TFM_SEQUENCE_ID,
                       CAST(NULL AS VARCHAR2(240)) AS DMT_REFERENCE,
                       CAST(NULL AS VARCHAR2(30)) AS TFM_STATUS,
                       CAST(NULL AS NUMBER) AS STORED_FUSION_ID
                FROM   TABLE(l_sql_rows) r
                WHERE  1 = 0;
            RETURN;
        END IF;

        -- Copy the shared fetch's PL/SQL rows into the sanctioned SQL collection
        -- so a single static SQL can TABLE()-join them to the view. SOURCE_REF /
        -- DMT_REFERENCE are not carried by the shared fetch's record type, so
        -- they are left NULL here and the join falls back to the view's own
        -- DMT_REFERENCE (NVL(DMT_REFERENCE, SOURCE_REF)).
        FOR i IN 1 .. l_fetch_rows.COUNT LOOP
            l_sql_rows.EXTEND;
            l_sql_rows(l_sql_rows.LAST) := DMT_RECON_ROW_OBJ(
                OBJECT_TYPE     => l_fetch_rows(i).OBJECT_TYPE,
                RECORD_KEY      => l_fetch_rows(i).RECORD_KEY,
                SOURCE_TYPE     => l_fetch_rows(i).SOURCE_TYPE,
                FUSION_STATUS   => l_fetch_rows(i).FUSION_STATUS,
                FUSION_ID       => l_fetch_rows(i).FUSION_ID,
                ERROR_MESSAGE   => l_fetch_rows(i).ERROR_MESSAGE,
                LOAD_REQUEST_ID => TO_NUMBER(
                                       REGEXP_SUBSTR(l_fetch_rows(i).LOAD_REQUEST_ID,
                                                     '^\d+$')),
                SOURCE_REF      => NULL,
                DMT_REFERENCE   => NULL);
        END LOOP;

        -- Return each returned base row joined to its TFM record of this run. The
        -- Contract v1 report returns the record's business key (RECORD_KEY), which
        -- is the run-scoped RECON_KEY the view exposes, so the join is on
        -- RECON_KEY -- the only key the report carries. The TFM_SEQUENCE_ID output
        -- column is then derived from the matched record's reference with the
        -- design's exact parse expression:
        --   TO_NUMBER(REGEXP_SUBSTR(NVL(DMT_REFERENCE, SOURCE_REF), '[^:]+', 1, 4))
        -- DMT_REFERENCE comes from the view (the 'DMT:run:wq:tfm' string we stamped
        -- on the record); SOURCE_REF is any reference the report itself carried
        -- (NULL for Contract v1 today). A report row that matches no TFM record of
        -- this run still appears, with the TFM columns NULL -- we return exactly
        -- what Fusion gave us and never fabricate a match.
        OPEN x_cursor FOR
            SELECT src.OBJECT_TYPE,
                   src.RECORD_KEY,
                   src.SOURCE_TYPE,
                   src.FUSION_STATUS,
                   src.FUSION_ID,
                   CAST(src.ERROR_MESSAGE AS VARCHAR2(4000)) AS ERROR_MESSAGE,
                   CAST(TO_CHAR(src.LOAD_REQUEST_ID) AS VARCHAR2(100)) AS LOAD_REQUEST_ID,
                   TO_NUMBER(REGEXP_SUBSTR(
                       NVL(v.DMT_REFERENCE, src.SOURCE_REF), '[^:]+', 1, 4))
                                                   AS TFM_SEQUENCE_ID,
                   v.DMT_REFERENCE,
                   v.TFM_STATUS,
                   v.FUSION_ID                     AS STORED_FUSION_ID
            FROM   TABLE(l_sql_rows) src
            LEFT   JOIN DMT_RUN_RECORDS_V v
              ON   v.RUN_ID     = p_run_id
             AND   v.CEMLI_CODE = p_cemli_code
             AND   v.RECON_KEY  = src.RECORD_KEY
            ORDER  BY src.SOURCE_TYPE, src.RECORD_KEY;

        x_error_code := DMT_UTIL_PKG.C_SUCCESS;

    EXCEPTION
        WHEN OTHERS THEN
            x_error_code := DMT_UTIL_PKG.C_ERROR;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id    => p_run_id,
                p_message   => C_PROC || ' failed for run ' || p_run_id
                               || ', object ' || p_cemli_code || '.',
                p_sqlerrm   => SQLERRM,
                p_package   => C_PKG,
                p_procedure => C_PROC);
            RAISE;
    END AUDIT_IN_FUSION;

END DMT_RUN_SUMMARY_PKG;
/
