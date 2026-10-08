-- PACKAGE BODY DMT_BEN_DEPEND_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_DEPEND_TRANSFORM_PKG" 
AS
-- ============================================================
-- DMT_BEN_DEPEND_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BEN_DEPEND_TRANSFORM_PKG';

    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;


    PROCEDURE TRANSFORM_DEPENDENTENROLLMENTS (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N', p_run_mode IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_prefix     VARCHAR2(30);
        l_ok_count   NUMBER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_DEPENDENTENROLLMENTS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_DEPENDENTENROLLMENTS');

        l_prefix := get_prefix(p_run_id);

        -- DependentEnrollment
        INSERT INTO DMT_BEN_DEPEND_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            PERSON_NUMBER,
            DEPENDENT_PERSON_NUMBER,
            BENEFIT_RELATIONSHIP_NAME,
            PROGRAM_NAME,
            PLAN_NAME,
            OPTION_NAME,
            DESIGNATION_DATE,
            DESIGNATION_END_DATE,
            LEGAL_EMPLOYER_NAME,
            RECON_KEY,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_BEN_DEPEND_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            DMT_XREF_PKG.PERSON_NUMBER(s.PERSON_NUMBER),
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.DEPENDENT_PERSON_NUMBER, 30),
            s.BENEFIT_RELATIONSHIP_NAME,
            s.PROGRAM_NAME,
            s.PLAN_NAME,
            s.OPTION_NAME,
            s.DESIGNATION_DATE,
            s.DESIGNATION_END_DATE,
            s.LEGAL_EMPLOYER_NAME,
            -- RECON_KEY (Contract v1, design section 5): the DesignateDependent
            -- child SourceSystemId the generator writes and that the BIP recon
            -- report returns as RECORD_KEY. It is finalized in the MERGE right
            -- after this INSERT (once TFM_SEQUENCE_ID exists, so the per-person
            -- line number can be computed). Left NULL here.
            NULL,
            'STAGED',
            SYSDATE
        FROM DMT_BEN_DEPEND_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_BEN_DEPEND_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_BEN_DEPEND_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        -- Finalize RECON_KEY = the DesignateDependent child SourceSystemId that
        -- DMT_BEN_DEPEND_HDL_GEN_PKG emits:
        --     <prefixed PERSON_NUMBER>_<prefixed DEPENDENT_PERSON_NUMBER>_<TFM_SEQUENCE_ID>_BENDEP
        -- Backlog #288 (2026-10-07): the third segment is the row's own TFM id, no
        -- longer a per-person LINE_NO window. The window had to match the
        -- generator's window exactly on every run (a retry that ranked a different
        -- row set produced a key that no longer matched the emitted SourceSystemId);
        -- the TFM id is fixed per row, so the transform, the generator and the
        -- reconciler can never disagree. PERSON_NUMBER and DEPENDENT_PERSON_NUMBER
        -- already carry the run prefix (set in the INSERT).
        MERGE INTO DMT_BEN_DEPEND_TFM_TBL tgt
        USING (
            SELECT TFM_SEQUENCE_ID,
                   PERSON_NUMBER || '_' ||
                       DEPENDENT_PERSON_NUMBER || '_' ||
                       TO_CHAR(TFM_SEQUENCE_ID) ||
                       '_BENDEP' AS NEW_RECON_KEY
            FROM   DMT_BEN_DEPEND_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS = 'STAGED'
        ) src
        ON (tgt.TFM_SEQUENCE_ID = src.TFM_SEQUENCE_ID)
        WHEN MATCHED THEN
            UPDATE SET tgt.RECON_KEY = src.NEW_RECON_KEY
            WHERE tgt.RECON_KEY IS NULL;

        UPDATE DMT_BEN_DEPEND_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_BEN_DEPEND_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS, p_run_id, 'DMT_BEN_DEPEND_STG_TBL', STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_DEPENDENTENROLLMENTS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_DEPENDENTENROLLMENTS');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'BenDependent', 'Dependent Enrollment', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_BEN_DEPEND_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_BEN_DEPEND_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
                        /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
                      )
                AND (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_BEN_DEPEND_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Dependent Enrollment');
                UPDATE DMT_BEN_DEPEND_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Dependent Enrollment')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_DEPENDENTENROLLMENTS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_DEPENDENTENROLLMENTS');
            RAISE;
    END TRANSFORM_DEPENDENTENROLLMENTS;

END DMT_BEN_DEPEND_TRANSFORM_PKG;
/
