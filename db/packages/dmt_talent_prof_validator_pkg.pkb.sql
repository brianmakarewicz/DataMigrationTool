-- PACKAGE BODY DMT_TALENT_PROF_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_TALENT_PROF_VALIDATOR_PKG" 
AS
-- ============================================================
-- DMT_TALENT_PROF_VALIDATOR_PKG body
-- Pre-transform: profile item section rules (backlog #451). Post-transform: stub.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_TALENT_PROF_VALIDATOR_PKG';

    -- ============================================================
    -- FLAG_STG_FAILED — STANDARD helper (design §7). Marks every STG row FAILED
    -- (status only, no message) that has a DMT_STG_TFM_ERROR_TBL row for this run.
    -- The pre-validation checks above record WHY in the error table; this sets the
    -- STG status so FAILED-mode reruns select on it. Byte-identical across validator
    -- packages except the STG table name(s) and the SUB_OBJECT filter (tagged EDIT
    -- regions), like SWEEP_UNACCOUNTED. Does NOT commit — the caller owns the txn.
    -- ============================================================
    PROCEDURE FLAG_STG_FAILED (p_run_id IN NUMBER, p_scenario_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        -- <<EDIT-TABLE — the object's STG table. Repeat this whole UPDATE block
        --   (EDIT-TABLE through the ';') once per STG table the object owns.>>
        UPDATE DMT_TALENT_PROF_STG_TBL
        -- <<END EDIT-TABLE — everything below is FIXED until EDIT-SCOPE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE — this table's SUB_OBJECT>>
                                   AND SUB_OBJECT = 'Talent Profiles'
        -- <<END EDIT-SCOPE — nothing below this changes>>
                                  );

        -- <<EDIT-TABLE>>
        UPDATE DMT_TALENT_PROF_ITEM_STG_TBL
        -- <<END EDIT-TABLE>>
        SET    STG_STATUS = 'FAILED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_STATUS IN ('NEW','TRANSFORMED')
        AND    (p_scenario_id IS NULL OR SCENARIO_ID = p_scenario_id)
        AND    STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_STG_TFM_ERROR_TBL
                                   WHERE RUN_ID = p_run_id
        -- <<EDIT-SCOPE>>
                                   AND SUB_OBJECT = 'Profile Items'
        -- <<END EDIT-SCOPE>>
                                  );
    END FLAG_STG_FAILED;

    -- --------------------------------------------------------
    -- VALIDATE_PRE_TRANSFORM (Profile Items)
    --   Fusion identifies a profile item's section only by SectionId, and a
    --   section NAME repeats across profile types ('Languages' exists for the
    --   person, job, position and organization profile types). The transform
    --   resolves SectionId from the PROFILE_SECTION_NAME_TO_SECTION_ID lookup,
    --   keyed <profile type code>~<section name> and refreshed from Fusion's
    --   profile-section setup at pipeline preflight (backlog #451). These rules
    --   fail a row before the transform rather than letting DMT guess an id:
    --   R1  SECTION_NAME is required.
    --   R2  the lookup has no row for the key: no section of that name exists
    --       for the profile type in this Fusion instance.
    --   R3  the lookup row has no id: the instance has more than one section of
    --       that name for the profile type, so the id cannot be chosen.
    --   R2/R3 read DMT_LOOKUP_TBL set-based (GET_LOOKUP resolves one value and
    --   halts the run on a miss, which is right for the transform but not for a
    --   per-row rejection).
    -- --------------------------------------------------------
    PROCEDURE VALIDATE_PRE_TRANSFORM (
        p_run_id IN NUMBER,
        p_scenario_id     IN NUMBER   DEFAULT NULL,
        p_run_mode        IN VARCHAR2 DEFAULT 'NEW'
    )
    IS
        C_SECTION_TYPE CONSTANT VARCHAR2(100) := 'PROFILE_SECTION_NAME_TO_SECTION_ID';
        l_ptype        CONSTANT VARCHAR2(30)  := DMT_TALENT_PROF_TRANSFORM_PKG.C_PROFILE_TYPE_CODE;
        l_bad          PLS_INTEGER := 0;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');

        -- R1: section name required.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'TalentProfiles', 'Profile Items', s.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] SECTION_NAME is required: Fusion needs the profile section of every profile item.'
        FROM   DMT_TALENT_PROF_ITEM_STG_TBL s
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_ITEM_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id)
        AND    s.SECTION_NAME IS NULL;
        l_bad := l_bad + SQL%ROWCOUNT;

        -- R2: no section of that name for the profile type.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'TalentProfiles', 'Profile Items', s.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Profile section ''' || s.SECTION_NAME ||
               ''' does not exist for profile type ' || l_ptype ||
               ' in this Fusion instance (no ' || C_SECTION_TYPE || ' lookup row for ''' ||
               l_ptype || '~' || s.SECTION_NAME || ''').'
        FROM   DMT_TALENT_PROF_ITEM_STG_TBL s
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_ITEM_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id)
        AND    s.SECTION_NAME IS NOT NULL
        AND    NOT EXISTS (SELECT 1 FROM DMT_LOOKUP_TBL l
                           WHERE  l.LOOKUP_TYPE  = C_SECTION_TYPE
                           AND    l.LOOKUP_VALUE = l_ptype || '~' || s.SECTION_NAME);
        l_bad := l_bad + SQL%ROWCOUNT;

        -- R3: more than one section of that name for the profile type.
        INSERT INTO DMT_STG_TFM_ERROR_TBL
               (RUN_ID, CEMLI_CODE, SUB_OBJECT, STG_SEQUENCE_ID, ERROR_TEXT)
        SELECT p_run_id, 'TalentProfiles', 'Profile Items', s.STG_SEQUENCE_ID,
               '[PRE_VALIDATION] Profile section ''' || s.SECTION_NAME ||
               ''' is ambiguous for profile type ' || l_ptype ||
               ': this Fusion instance has more than one section with that name, so DMT will not choose a SectionId.'
        FROM   DMT_TALENT_PROF_ITEM_STG_TBL s
        WHERE  DMT_UTIL_PKG.STG_ROW_SELECTED(p_run_mode, s.STG_STATUS, p_run_id, 'DMT_TALENT_PROF_ITEM_STG_TBL', s.STG_SEQUENCE_ID) = 'Y'
        AND    (p_scenario_id IS NULL OR s.SCENARIO_ID = p_scenario_id)
        AND    EXISTS (SELECT 1 FROM DMT_LOOKUP_TBL l
                       WHERE  l.LOOKUP_TYPE  = C_SECTION_TYPE
                       AND    l.LOOKUP_VALUE = l_ptype || '~' || s.SECTION_NAME
                       AND    l.RETURN_VALUE IS NULL);
        l_bad := l_bad + SQL%ROWCOUNT;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_PRE_TRANSFORM complete. Profile item rows tagged FAILED: ' || l_bad,
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_PRE_TRANSFORM');


        -- Standard final step: flag the STG rows FAILED from the recorded error
        -- rows (status only, no message) so FAILED-mode reruns select on them (§7).
        FLAG_STG_FAILED(p_run_id, p_scenario_id);
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;


    PROCEDURE VALIDATE_POST_TRANSFORM (
        p_run_id IN NUMBER
    )
    IS
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM start. (stub)',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

        NULL;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'VALIDATE_POST_TRANSFORM complete. (stub)',
            p_package        => C_PKG,
            p_procedure      => 'VALIDATE_POST_TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;

END DMT_TALENT_PROF_VALIDATOR_PKG;
/
