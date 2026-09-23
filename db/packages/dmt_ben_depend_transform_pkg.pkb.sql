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
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
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
        --     <prefixed PERSON_NUMBER>_<prefixed DEPENDENT_PERSON_NUMBER>_<LINE_NO>_BENDEP
        -- LINE_NO is the dependent's position within the participant.
        --
        -- LINE_NO WINDOW MUST MATCH THE GENERATOR EXACTLY (defect fixed 2026-09-22):
        -- the generator ranks with ROW_NUMBER() OVER (PARTITION BY PERSON_NUMBER
        -- ORDER BY TFM_SEQUENCE_ID) over ALL of the run's STAGED rows. This MERGE
        -- ranks over the SAME population (RUN_ID = p_run_id AND TFM_STATUS = 'STAGED')
        -- -- it does NOT restrict the windowed row set to RECON_KEY IS NULL, which
        -- was the prior bug: on a retry some rows already had a RECON_KEY, so the
        -- transform ranked only the not-yet-keyed subset while the generator ranked
        -- the full set, producing different LINE_NO values and a key that no longer
        -- matched the emitted SourceSystemId. Both windows now cover the identical
        -- rows, so LINE_NO agrees on every run. PERSON_NUMBER and
        -- DEPENDENT_PERSON_NUMBER already carry the run prefix (set in the INSERT).
        MERGE INTO DMT_BEN_DEPEND_TFM_TBL tgt
        USING (
            SELECT TFM_SEQUENCE_ID,
                   PERSON_NUMBER || '_' ||
                       DEPENDENT_PERSON_NUMBER || '_' ||
                       TO_CHAR(ROW_NUMBER() OVER (
                           PARTITION BY PERSON_NUMBER
                           ORDER BY TFM_SEQUENCE_ID)) ||
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
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS) = 'Y'
            /* #44: NEW->NEW, FAILED->FAILED, ALL->whole scenario; RETRY retired */
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_DEPENDENTENROLLMENTS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_DEPENDENTENROLLMENTS');

    EXCEPTION
        WHEN OTHERS THEN
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
