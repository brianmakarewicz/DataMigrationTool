CREATE OR REPLACE PACKAGE BODY DMT_LOOKUP.DMT_LKP_SUGGEST_PKG AS
-- =============================================================================
-- DMT_LKP_SUGGEST_PKG body
-- =============================================================================

    FUNCTION SUGGEST_MAPPINGS (
        p_lookup_type   IN VARCHAR2,
        p_min_jw        IN NUMBER DEFAULT 85,
        p_min_ed        IN NUMBER DEFAULT 50,
        p_max_per_type  IN NUMBER DEFAULT 500
    ) RETURN NUMBER
    IS
        v_count NUMBER;
    BEGIN
        -- Delete any previous unaccepted suggestions for this type
        DELETE FROM DMT_LKP_MAPPING
         WHERE lookup_type     = p_lookup_type
           AND suggested_flag  = 'Y'
           AND active_flag     = 'N';

        -- Insert best fuzzy match per EBS value.
        -- Only considers EBS values that:
        --   (a) have no exact Fusion match
        --   (b) have no existing active mapping
        INSERT INTO DMT_LKP_MAPPING (
            lookup_type, ebs_value, fusion_value,
            active_flag, suggested_flag, match_score,
            notes, created_by, created_date
        )
        SELECT lookup_type, ebs_value, fusion_value,
               'N', 'Y', combined_score,
               'Fuzzy match: JW=' || jw_score || ' ED=' || ed_score,
               'DMT_LKP_SUGGEST_PKG', SYSDATE
        FROM (
            SELECT e.lookup_type,
                   e.ebs_value,
                   f.fusion_value,
                   UTL_MATCH.JARO_WINKLER_SIMILARITY(
                       UPPER(e.ebs_value), UPPER(f.fusion_value)
                   ) AS jw_score,
                   UTL_MATCH.EDIT_DISTANCE_SIMILARITY(
                       UPPER(e.ebs_value), UPPER(f.fusion_value)
                   ) AS ed_score,
                   UTL_MATCH.JARO_WINKLER_SIMILARITY(
                       UPPER(e.ebs_value), UPPER(f.fusion_value)
                   ) + UTL_MATCH.EDIT_DISTANCE_SIMILARITY(
                       UPPER(e.ebs_value), UPPER(f.fusion_value)
                   ) AS combined_score,
                   ROW_NUMBER() OVER (
                       PARTITION BY e.ebs_value
                       ORDER BY UTL_MATCH.JARO_WINKLER_SIMILARITY(
                                    UPPER(e.ebs_value), UPPER(f.fusion_value))
                              + UTL_MATCH.EDIT_DISTANCE_SIMILARITY(
                                    UPPER(e.ebs_value), UPPER(f.fusion_value)) DESC
                   ) AS rn
            FROM DMT_LKP_EBS_VALUES e
            JOIN DMT_LKP_FUSION_VALUES f
              ON f.lookup_type = e.lookup_type
             AND f.active_flag = 'Y'
            WHERE e.lookup_type = p_lookup_type
              AND e.active_flag = 'Y'
              -- No exact Fusion match
              AND NOT EXISTS (
                  SELECT 1 FROM DMT_LKP_FUSION_VALUES f2
                   WHERE f2.lookup_type = e.lookup_type
                     AND UPPER(f2.fusion_value) = UPPER(e.ebs_value)
                     AND f2.active_flag = 'Y'
              )
              -- No existing active mapping
              AND NOT EXISTS (
                  SELECT 1 FROM DMT_LKP_MAPPING m
                   WHERE m.lookup_type = e.lookup_type
                     AND m.ebs_value   = e.ebs_value
                     AND m.active_flag = 'Y'
              )
              -- Meet minimum thresholds
              AND UTL_MATCH.JARO_WINKLER_SIMILARITY(
                      UPPER(e.ebs_value), UPPER(f.fusion_value)) >= p_min_jw
              AND UTL_MATCH.EDIT_DISTANCE_SIMILARITY(
                      UPPER(e.ebs_value), UPPER(f.fusion_value)) >= p_min_ed
        )
        WHERE rn = 1
        ORDER BY combined_score DESC
        FETCH FIRST p_max_per_type ROWS ONLY;

        v_count := SQL%ROWCOUNT;
        COMMIT;
        RETURN v_count;
    END SUGGEST_MAPPINGS;


    FUNCTION SUGGEST_ALL_MAPPINGS (
        p_min_jw        IN NUMBER DEFAULT 85,
        p_min_ed        IN NUMBER DEFAULT 50,
        p_max_per_type  IN NUMBER DEFAULT 500
    ) RETURN NUMBER
    IS
        v_total NUMBER := 0;
        v_cnt   NUMBER;
    BEGIN
        FOR rec IN (
            SELECT lookup_type
              FROM DMT_LKP_TYPE_CONFIG
             WHERE active_flag = 'Y'
             ORDER BY lookup_type
        ) LOOP
            v_cnt := SUGGEST_MAPPINGS(
                p_lookup_type  => rec.lookup_type,
                p_min_jw       => p_min_jw,
                p_min_ed       => p_min_ed,
                p_max_per_type => p_max_per_type
            );
            v_total := v_total + v_cnt;
        END LOOP;
        RETURN v_total;
    END SUGGEST_ALL_MAPPINGS;


    PROCEDURE ACCEPT_SUGGESTIONS (
        p_mapping_ids   IN VARCHAR2
    ) IS
    BEGIN
        UPDATE DMT_LKP_MAPPING
           SET active_flag      = 'Y',
               suggested_flag   = 'N',
               last_update_by   = SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
               last_update_date = SYSDATE
         WHERE suggested_flag = 'Y'
           AND active_flag    = 'N'
           AND INSTR(':' || p_mapping_ids || ':', ':' || MAPPING_ID || ':') > 0;
        COMMIT;
    END ACCEPT_SUGGESTIONS;


    PROCEDURE REJECT_SUGGESTIONS (
        p_mapping_ids   IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM DMT_LKP_MAPPING
         WHERE suggested_flag = 'Y'
           AND active_flag    = 'N'
           AND INSTR(':' || p_mapping_ids || ':', ':' || MAPPING_ID || ':') > 0;
        COMMIT;
    END REJECT_SUGGESTIONS;


    PROCEDURE ACCEPT_ALL_FOR_TYPE (
        p_lookup_type   IN VARCHAR2
    ) IS
    BEGIN
        UPDATE DMT_LKP_MAPPING
           SET active_flag      = 'Y',
               suggested_flag   = 'N',
               last_update_by   = SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
               last_update_date = SYSDATE
         WHERE lookup_type    = p_lookup_type
           AND suggested_flag = 'Y'
           AND active_flag    = 'N';
        COMMIT;
    END ACCEPT_ALL_FOR_TYPE;


    PROCEDURE REJECT_ALL_FOR_TYPE (
        p_lookup_type   IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM DMT_LKP_MAPPING
         WHERE lookup_type    = p_lookup_type
           AND suggested_flag = 'Y'
           AND active_flag    = 'N';
        COMMIT;
    END REJECT_ALL_FOR_TYPE;


    PROCEDURE CLEAR_ALL_SUGGESTIONS IS
    BEGIN
        DELETE FROM DMT_LKP_MAPPING
         WHERE suggested_flag = 'Y'
           AND active_flag    = 'N';
        COMMIT;
    END CLEAR_ALL_SUGGESTIONS;

END DMT_LKP_SUGGEST_PKG;
/
