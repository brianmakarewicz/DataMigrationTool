CREATE OR REPLACE PACKAGE BODY DMT_LOOKUP.DMT_COA_SUGGEST_PKG AS
-- =============================================================================
-- DMT_COA_SUGGEST_PKG body
-- =============================================================================

    -- Helper: get distinct source values for a segment from source combos
    -- by looking at the segment_map's source_segment_num and config's source COA set.
    FUNCTION get_source_vals(p_segment_map_id NUMBER) RETURN SYS_REFCURSOR
    IS
        v_src_seg_num  NUMBER;
        v_src_set_id   NUMBER;
        v_rc           SYS_REFCURSOR;
    BEGIN
        SELECT sm.source_segment_num, mc.source_coa_set_id
          INTO v_src_seg_num, v_src_set_id
          FROM DMT_COA_SEGMENT_MAP sm
          JOIN DMT_COA_MAP_CONFIG mc ON mc.map_config_id = sm.map_config_id
         WHERE sm.segment_map_id = p_segment_map_id;

        OPEN v_rc FOR
            SELECT DISTINCT
                CASE v_src_seg_num
                    WHEN 1 THEN segment1 WHEN 2 THEN segment2
                    WHEN 3 THEN segment3 WHEN 4 THEN segment4
                    WHEN 5 THEN segment5 WHEN 6 THEN segment6
                    WHEN 7 THEN segment7 WHEN 8 THEN segment8
                    WHEN 9 THEN segment9 WHEN 10 THEN segment10
                END AS seg_val
            FROM DMT_COA_SOURCE_COMBOS
            WHERE coa_set_id = v_src_set_id
              AND enabled_flag = 'Y'
            ORDER BY 1;
        RETURN v_rc;
    END;

    -- Helper: get distinct target values for a segment from target combos
    FUNCTION get_target_vals(p_segment_map_id NUMBER) RETURN SYS_REFCURSOR
    IS
        v_tgt_seg_num  NUMBER;
        v_tgt_set_id   NUMBER;
        v_rc           SYS_REFCURSOR;
    BEGIN
        SELECT sm.target_segment_num, mc.target_coa_set_id
          INTO v_tgt_seg_num, v_tgt_set_id
          FROM DMT_COA_SEGMENT_MAP sm
          JOIN DMT_COA_MAP_CONFIG mc ON mc.map_config_id = sm.map_config_id
         WHERE sm.segment_map_id = p_segment_map_id;

        OPEN v_rc FOR
            SELECT DISTINCT
                CASE v_tgt_seg_num
                    WHEN 1 THEN segment1 WHEN 2 THEN segment2
                    WHEN 3 THEN segment3 WHEN 4 THEN segment4
                    WHEN 5 THEN segment5 WHEN 6 THEN segment6
                    WHEN 7 THEN segment7 WHEN 8 THEN segment8
                    WHEN 9 THEN segment9 WHEN 10 THEN segment10
                END AS seg_val
            FROM DMT_COA_TARGET_COMBOS
            WHERE coa_set_id = v_tgt_set_id
              AND enabled_flag = 'Y'
            ORDER BY 1;
        RETURN v_rc;
    END;


    FUNCTION AUTO_MAP_EXACT (
        p_segment_map_id IN NUMBER
    ) RETURN NUMBER
    IS
        v_count NUMBER := 0;
        v_src_rc SYS_REFCURSOR;
        v_tgt_rc SYS_REFCURSOR;
        v_src_val VARCHAR2(100);

        TYPE t_vals IS TABLE OF VARCHAR2(100);
        v_tgt_vals t_vals := t_vals();
        v_tgt_idx  PLS_INTEGER;
        v_tgt_val  VARCHAR2(100);

        -- Hash for fast target lookup
        TYPE t_val_set IS TABLE OF VARCHAR2(100) INDEX BY VARCHAR2(100);
        v_tgt_set t_val_set;
    BEGIN
        -- Load all target values into hash
        v_tgt_rc := get_target_vals(p_segment_map_id);
        LOOP
            FETCH v_tgt_rc INTO v_tgt_val;
            EXIT WHEN v_tgt_rc%NOTFOUND;
            IF v_tgt_val IS NOT NULL THEN
                v_tgt_set(UPPER(v_tgt_val)) := v_tgt_val;
            END IF;
        END LOOP;
        CLOSE v_tgt_rc;

        -- For each source value, if exact match exists in target, insert
        v_src_rc := get_source_vals(p_segment_map_id);
        LOOP
            FETCH v_src_rc INTO v_src_val;
            EXIT WHEN v_src_rc%NOTFOUND;
            IF v_src_val IS NOT NULL AND v_tgt_set.EXISTS(UPPER(v_src_val)) THEN
                BEGIN
                    INSERT INTO DMT_COA_SEGMENT_VALUES (
                        segment_map_id, source_value, target_value,
                        active_flag, suggested_flag, notes,
                        created_by, created_date
                    ) VALUES (
                        p_segment_map_id, v_src_val, v_tgt_set(UPPER(v_src_val)),
                        'Y', 'N', 'Auto-mapped (exact match)',
                        'DMT_COA_SUGGEST_PKG', SYSDATE
                    );
                    v_count := v_count + 1;
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;
            END IF;
        END LOOP;
        CLOSE v_src_rc;

        COMMIT;
        RETURN v_count;
    END AUTO_MAP_EXACT;


    FUNCTION SUGGEST_SEGMENT_VALUES (
        p_segment_map_id IN NUMBER,
        p_min_jw         IN NUMBER DEFAULT 85,
        p_min_ed         IN NUMBER DEFAULT 50
    ) RETURN NUMBER
    IS
        v_count NUMBER := 0;

        TYPE t_val_list IS TABLE OF VARCHAR2(100);
        v_src_list t_val_list := t_val_list();
        v_tgt_list t_val_list := t_val_list();

        v_src_rc SYS_REFCURSOR;
        v_tgt_rc SYS_REFCURSOR;
        v_val    VARCHAR2(100);

        v_best_tgt   VARCHAR2(100);
        v_best_score NUMBER;
        v_jw         NUMBER;
        v_ed         NUMBER;
        v_score      NUMBER;
    BEGIN
        -- Delete previous unaccepted suggestions for this segment
        DELETE FROM DMT_COA_SEGMENT_VALUES
         WHERE segment_map_id = p_segment_map_id
           AND suggested_flag = 'Y'
           AND active_flag = 'N';

        -- Collect source values
        v_src_rc := get_source_vals(p_segment_map_id);
        LOOP
            FETCH v_src_rc INTO v_val;
            EXIT WHEN v_src_rc%NOTFOUND;
            IF v_val IS NOT NULL THEN
                v_src_list.EXTEND;
                v_src_list(v_src_list.COUNT) := v_val;
            END IF;
        END LOOP;
        CLOSE v_src_rc;

        -- Collect target values
        v_tgt_rc := get_target_vals(p_segment_map_id);
        LOOP
            FETCH v_tgt_rc INTO v_val;
            EXIT WHEN v_tgt_rc%NOTFOUND;
            IF v_val IS NOT NULL THEN
                v_tgt_list.EXTEND;
                v_tgt_list(v_tgt_list.COUNT) := v_val;
            END IF;
        END LOOP;
        CLOSE v_tgt_rc;

        -- For each source value, find best fuzzy match in target
        FOR s IN 1..v_src_list.COUNT LOOP
            -- Skip if already mapped
            DECLARE
                v_exists NUMBER;
            BEGIN
                SELECT COUNT(*) INTO v_exists
                  FROM DMT_COA_SEGMENT_VALUES
                 WHERE segment_map_id = p_segment_map_id
                   AND source_value = v_src_list(s)
                   AND active_flag = 'Y';
                IF v_exists > 0 THEN
                    CONTINUE;
                END IF;
            END;

            v_best_tgt := NULL;
            v_best_score := 0;

            FOR t IN 1..v_tgt_list.COUNT LOOP
                -- Skip exact matches (handled by AUTO_MAP_EXACT)
                IF UPPER(v_src_list(s)) = UPPER(v_tgt_list(t)) THEN
                    CONTINUE;
                END IF;

                v_jw := UTL_MATCH.JARO_WINKLER_SIMILARITY(
                    UPPER(v_src_list(s)), UPPER(v_tgt_list(t)));
                v_ed := UTL_MATCH.EDIT_DISTANCE_SIMILARITY(
                    UPPER(v_src_list(s)), UPPER(v_tgt_list(t)));

                IF v_jw >= p_min_jw AND v_ed >= p_min_ed THEN
                    v_score := v_jw + v_ed;
                    IF v_score > v_best_score THEN
                        v_best_score := v_score;
                        v_best_tgt := v_tgt_list(t);
                    END IF;
                END IF;
            END LOOP;

            IF v_best_tgt IS NOT NULL THEN
                BEGIN
                    INSERT INTO DMT_COA_SEGMENT_VALUES (
                        segment_map_id, source_value, target_value,
                        active_flag, suggested_flag, match_score,
                        notes, created_by, created_date
                    ) VALUES (
                        p_segment_map_id, v_src_list(s), v_best_tgt,
                        'N', 'Y', v_best_score,
                        'Fuzzy match: JW+ED=' || v_best_score,
                        'DMT_COA_SUGGEST_PKG', SYSDATE
                    );
                    v_count := v_count + 1;
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;
            END IF;
        END LOOP;

        COMMIT;
        RETURN v_count;
    END SUGGEST_SEGMENT_VALUES;


    PROCEDURE ACCEPT_SUGGESTIONS (p_value_ids IN VARCHAR2)
    IS
    BEGIN
        UPDATE DMT_COA_SEGMENT_VALUES
           SET active_flag    = 'Y',
               suggested_flag = 'N',
               last_update_date = SYSDATE
         WHERE suggested_flag = 'Y'
           AND active_flag = 'N'
           AND INSTR(':' || p_value_ids || ':', ':' || SEGMENT_VALUE_ID || ':') > 0;
        COMMIT;
    END ACCEPT_SUGGESTIONS;


    PROCEDURE REJECT_SUGGESTIONS (p_value_ids IN VARCHAR2)
    IS
    BEGIN
        DELETE FROM DMT_COA_SEGMENT_VALUES
         WHERE suggested_flag = 'Y'
           AND active_flag = 'N'
           AND INSTR(':' || p_value_ids || ':', ':' || SEGMENT_VALUE_ID || ':') > 0;
        COMMIT;
    END REJECT_SUGGESTIONS;

END DMT_COA_SUGGEST_PKG;
/
