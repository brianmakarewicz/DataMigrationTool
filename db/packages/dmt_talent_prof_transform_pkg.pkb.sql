-- PACKAGE BODY DMT_TALENT_PROF_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_TALENT_PROF_TRANSFORM_PKG" 
AS
-- ============================================================
-- DMT_TALENT_PROF_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_TALENT_PROF_TRANSFORM_PKG';

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


    PROCEDURE TRANSFORM_TALENTPROFILES (
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
            p_message        => 'TRANSFORM_TALENTPROFILES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TALENTPROFILES');

        l_prefix := get_prefix(p_run_id);

        -- TalentProfile
        INSERT INTO DMT_TALENT_PROF_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            PERSON_NUMBER,
            PROFILE_CODE,
            PROFILE_TYPE_CODE,
            PROFILE_STATUS_CODE,
            PROFILE_USAGE_CODE,
            DESCRIPTION,
            RECON_KEY,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_TALENT_PROF_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            DMT_XREF_PKG.PERSON_NUMBER(s.PERSON_NUMBER),
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROFILE_CODE, 30),  -- run-prefixed business key (#451): a profile code is unique in Fusion
            s.PROFILE_TYPE_CODE,
            s.PROFILE_STATUS_CODE,
            s.PROFILE_USAGE_CODE,
            s.DESCRIPTION,
            -- RECON_KEY = the parent TalentProfile.dat SourceSystemId = prefixed
            -- PERSON_NUMBER || '_TPROF' (see DMT_TALENT_PROF_HDL_GEN_PKG). This is
            -- the business key the Contract v1 report returns as RECORD_KEY and the
            -- shared parser matches on (design section 5, one key per object).
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30) || '_TPROF',
            'STAGED',
            SYSDATE
        FROM DMT_TALENT_PROF_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_TALENT_PROF_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        UPDATE DMT_TALENT_PROF_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_TALENT_PROF_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS, p_run_id, 'DMT_TALENT_PROF_STG_TBL', STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        -- ProfileItem
        -- SectionId per row (#451). A row whose section cannot be resolved -- no
        -- PROFILE_SECTION_NAME_TO_SECTION_ID lookup row for <profile type>~<section
        -- name>, or a row with no id because the name is ambiguous for that profile
        -- type -- fails ON ITS OWN with a [TRANSFORM_ERROR]; it never halts the work
        -- item, so the other rows still go to Fusion. The validator normally catches
        -- these first with a [PRE_VALIDATION] error; in ALL mode the transform still
        -- sees those STG rows, so rows that already carry an error in this run are
        -- skipped here and below.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'TalentProfiles', 'Profile Items', s.STG_SEQUENCE_ID,
               '[TRANSFORM_ERROR] No unique profile section id for profile type ' ||
               C_PROFILE_TYPE_CODE || ' and section ''' || s.SECTION_NAME ||
               ''' (PROFILE_SECTION_NAME_TO_SECTION_ID lookup missing or ambiguous).'
        FROM   DMT_TALENT_PROF_ITEM_STG_TBL s
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_ITEM_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL
                OR s.SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    NOT EXISTS (SELECT 1 FROM DMT_LOOKUP_TBL l
                           WHERE  l.LOOKUP_TYPE  = 'PROFILE_SECTION_NAME_TO_SECTION_ID'
                           AND    l.LOOKUP_VALUE = C_PROFILE_TYPE_CODE || '~' || s.SECTION_NAME
                           AND    l.RETURN_VALUE IS NOT NULL)
        AND    NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                           WHERE  e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                           AND    e.SUB_OBJECT = 'Profile Items');

        INSERT INTO DMT_TALENT_PROF_ITEM_TFM_TBL (
            TFM_SEQUENCE_ID,
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            PERSON_NUMBER,
            CONTENT_TYPE_NAME,
            CONTENT_ITEM_NAME,
            DATE_FROM,
            DATE_TO,
            RATING,
            PROFILE_CODE,
            INTEREST_LEVEL,
            SECTION_NAME,
            SECTION_ID,
            RECON_KEY,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            DMT_TALENT_PROF_ITEM_TFM_SEQ.NEXTVAL,
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            DMT_XREF_PKG.PERSON_NUMBER(s.PERSON_NUMBER),
            s.CONTENT_TYPE_NAME,
            s.CONTENT_ITEM_NAME,
            s.DATE_FROM,
            s.DATE_TO,
            s.RATING,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROFILE_CODE, 30),  -- run-prefixed business key (#451): a profile code is unique in Fusion
            s.INTEREST_LEVEL,
            s.SECTION_NAME,
            -- SectionId for the HDL line (#451): the instance's section id for this
            -- profile type and section name, from the lookup refreshed at preflight.
            -- Unresolvable rows were errored above and are excluded below, so this
            -- read always finds exactly one non-null id.
            (SELECT TO_NUMBER(l.RETURN_VALUE) FROM DMT_LOOKUP_TBL l
             WHERE  l.LOOKUP_TYPE  = 'PROFILE_SECTION_NAME_TO_SECTION_ID'
             AND    l.LOOKUP_VALUE = C_PROFILE_TYPE_CODE || '~' || s.SECTION_NAME),
            -- RECON_KEY = the child ProfileItem.dat SourceSystemId = prefixed
            -- PERSON_NUMBER || '_TPITM' (see DMT_TALENT_PROF_HDL_GEN_PKG). Stamped
            -- for consistency and future child base-tier proof; the current
            -- Contract v1 reconciler promotes only the parent TalentProfile row.
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30) || '_TPITM',
            'STAGED',
            SYSDATE
        FROM DMT_TALENT_PROF_ITEM_STG_TBL s
        WHERE (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_ITEM_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_TALENT_PROF_ITEM_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_STG_TFM_ERROR_TBL e
            WHERE  e.RUN_ID = p_run_id
            AND    e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    e.SUB_OBJECT = 'Profile Items'
        );

        l_ok_count := l_ok_count + SQL%ROWCOUNT;

        -- Rows rejected in this run (pre-validation or the section check above)
        -- end FAILED, so FAILED-mode reruns select them.
        UPDATE DMT_TALENT_PROF_ITEM_STG_TBL
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Profile Items')
        AND    STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        UPDATE DMT_TALENT_PROF_ITEM_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_TALENT_PROF_ITEM_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, STG_STATUS, p_run_id, 'DMT_TALENT_PROF_ITEM_STG_TBL', STG_SEQUENCE_ID) = 'Y'
            /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
          )
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_TALENTPROFILES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_TALENTPROFILES');

    EXCEPTION
        WHEN OTHERS THEN
            -- Record [TRANSFORM_ERROR] for this proc's in-scope STG rows so the
            -- record-detail anti-join surfaces them as FAILED instead of leaving
            -- the object unaccounted. SQLERRM captured to a local first (not a
            -- valid SQL identifier inside INSERT..SELECT). Backlog #14.
            DECLARE
                l_errm VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 3900);
            BEGIN
                -- tier 1: Talent Profiles
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'TalentProfiles', 'Talent Profiles', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_TALENT_PROF_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
                        /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_TALENT_PROF_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Talent Profiles');
                UPDATE DMT_TALENT_PROF_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Talent Profiles')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
                -- tier 2: Profile Items
                INSERT INTO DMT_STG_TFM_ERROR_TBL
                       (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
                SELECT p_run_id, 'TalentProfiles', 'Profile Items', s.STG_SEQUENCE_ID,
                       '[TRANSFORM_ERROR] ' || l_errm
                FROM   DMT_TALENT_PROF_ITEM_STG_TBL s
                WHERE  (
                        DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_ITEM_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
                        /* #44/#310: NEW->STG NEW; FAILED->latest earlier attempt failed (DMT_UTIL_PKG.FAILED_RETRY_SELECTED); ALL->whole scenario */
                      )
                AND (p_scenario_id IS NULL
                     OR s.SCENARIO_ID = p_scenario_id
                     OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
                AND NOT EXISTS (SELECT 1 FROM DMT_TALENT_PROF_ITEM_TFM_TBL t
                                WHERE t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID AND t.RUN_ID = p_run_id)
                AND NOT EXISTS (SELECT 1 FROM DMT_STG_TFM_ERROR_TBL e
                                WHERE e.RUN_ID = p_run_id AND e.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
                                AND e.SUB_OBJECT = 'Profile Items');
                UPDATE DMT_TALENT_PROF_ITEM_STG_TBL
                SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
                WHERE  STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                           WHERE RUN_ID = p_run_id AND SUB_OBJECT = 'Profile Items')
                AND    STG_STATUS IN ('NEW','TRANSFORMED')
                AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id
                        OR (p_include_untagged = 'Y' AND SCENARIO_ID IS NULL));
            EXCEPTION WHEN OTHERS THEN NULL;  -- fail-path diagnostics must never throw
            END;
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_TALENTPROFILES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_TALENTPROFILES');
            RAISE;
    END TRANSFORM_TALENTPROFILES;

END DMT_TALENT_PROF_TRANSFORM_PKG;
/
