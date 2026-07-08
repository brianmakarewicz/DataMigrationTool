CREATE OR REPLACE PACKAGE BODY DMT_LOOKUP.DMT_COA_MAP_PKG AS
-- =============================================================================
-- DMT_COA_MAP_PKG body
-- =============================================================================

    -- =========================================================================
    -- GET_SEGMENT — extract segment N from a delimited string
    -- =========================================================================
    FUNCTION GET_SEGMENT (
        p_concat    IN VARCHAR2,
        p_delimiter IN VARCHAR2,
        p_seg_num   IN NUMBER
    ) RETURN VARCHAR2 DETERMINISTIC
    IS
    BEGIN
        RETURN REGEXP_SUBSTR(p_concat, '[^' || p_delimiter || ']+', 1, p_seg_num);
    END GET_SEGMENT;


    -- =========================================================================
    -- GENERATE_MAPPINGS
    -- Core generation procedure. Reads segment rules and value maps, then
    -- for each source combo derives the target string segment by segment.
    --
    -- CUSTOMIZATION POINT: If a migration needs special derivation logic
    -- (e.g. account-range-dependent segment swaps), modify the segment
    -- processing loop in this procedure. Everything else stays untouched.
    -- =========================================================================
    FUNCTION GENERATE_MAPPINGS (
        p_config_code   IN VARCHAR2
    ) RETURN NUMBER
    IS
        v_config_id     NUMBER;
        v_src_set_id    NUMBER;
        v_tgt_set_id    NUMBER;
        v_src_delim     VARCHAR2(5);
        v_tgt_delim     VARCHAR2(5);
        v_tgt_num_segs  NUMBER;
        v_count         NUMBER := 0;

        -- Segment rule cache
        TYPE t_seg_rule IS RECORD (
            segment_map_id     NUMBER,
            source_segment_num NUMBER,
            target_segment_num NUMBER,
            mapping_rule       VARCHAR2(30),
            default_value      VARCHAR2(100),
            pad_length         NUMBER,
            pad_char           VARCHAR2(1)
        );
        TYPE t_seg_rules IS TABLE OF t_seg_rule INDEX BY PLS_INTEGER;
        v_rules t_seg_rules;

        -- Value map cache: v_val_maps(segment_map_id)(source_value) = target_value
        TYPE t_value_map IS TABLE OF VARCHAR2(100) INDEX BY VARCHAR2(100);
        TYPE t_value_maps IS TABLE OF t_value_map INDEX BY PLS_INTEGER;
        v_val_maps t_value_maps;

        -- Working variables
        v_src_segments  DBMS_SQL.VARCHAR2_TABLE;
        v_tgt_segments  DBMS_SQL.VARCHAR2_TABLE;
        v_tgt_concat    VARCHAR2(500);
        v_src_val       VARCHAR2(100);
        v_tgt_val       VARCHAR2(100);
        v_rule          t_seg_rule;
        v_map_id        NUMBER;

    BEGIN
        -- Load config
        SELECT mc.map_config_id, mc.source_coa_set_id, mc.target_coa_set_id,
               src.segment_delimiter, tgt.segment_delimiter, tgt.num_segments
          INTO v_config_id, v_src_set_id, v_tgt_set_id,
               v_src_delim, v_tgt_delim, v_tgt_num_segs
          FROM DMT_COA_MAP_CONFIG mc
          JOIN DMT_COA_SET src ON src.coa_set_id = mc.source_coa_set_id
          JOIN DMT_COA_SET tgt ON tgt.coa_set_id = mc.target_coa_set_id
         WHERE mc.config_code = p_config_code
           AND mc.active_flag = 'Y';

        -- Load segment rules into cache (ordered by target segment)
        DECLARE
            v_idx PLS_INTEGER := 0;
        BEGIN
            FOR rec IN (
                SELECT segment_map_id, source_segment_num, target_segment_num,
                       mapping_rule, default_value, pad_length, pad_char
                  FROM DMT_COA_SEGMENT_MAP
                 WHERE map_config_id = v_config_id
                   AND active_flag = 'Y'
                 ORDER BY target_segment_num
            ) LOOP
                v_idx := v_idx + 1;
                v_rules(v_idx).segment_map_id     := rec.segment_map_id;
                v_rules(v_idx).source_segment_num := rec.source_segment_num;
                v_rules(v_idx).target_segment_num := rec.target_segment_num;
                v_rules(v_idx).mapping_rule       := rec.mapping_rule;
                v_rules(v_idx).default_value      := rec.default_value;
                v_rules(v_idx).pad_length         := rec.pad_length;
                v_rules(v_idx).pad_char           := rec.pad_char;
            END LOOP;
        END;

        -- Load all segment value maps into nested cache
        FOR rec IN (
            SELECT sv.segment_map_id, sv.source_value, sv.target_value
              FROM DMT_COA_SEGMENT_VALUES sv
              JOIN DMT_COA_SEGMENT_MAP sm ON sm.segment_map_id = sv.segment_map_id
             WHERE sm.map_config_id = v_config_id
               AND sv.active_flag = 'Y'
               AND sv.suggested_flag = 'N'
        ) LOOP
            v_val_maps(rec.segment_map_id)(rec.source_value) := rec.target_value;
        END LOOP;

        -- Delete previous GENERATED rows (leave MANUAL and IMPORTED untouched)
        DELETE FROM DMT_COA_MAPPING
         WHERE map_config_id = v_config_id
           AND source_type = 'GENERATED';

        -- Process each source combo
        FOR combo IN (
            SELECT concat_segments,
                   segment1, segment2, segment3, segment4, segment5,
                   segment6, segment7, segment8, segment9, segment10
              FROM DMT_COA_SOURCE_COMBOS
             WHERE coa_set_id = v_src_set_id
               AND enabled_flag = 'Y'
        ) LOOP
            -- Load source segments into array
            v_src_segments(1)  := combo.segment1;
            v_src_segments(2)  := combo.segment2;
            v_src_segments(3)  := combo.segment3;
            v_src_segments(4)  := combo.segment4;
            v_src_segments(5)  := combo.segment5;
            v_src_segments(6)  := combo.segment6;
            v_src_segments(7)  := combo.segment7;
            v_src_segments(8)  := combo.segment8;
            v_src_segments(9)  := combo.segment9;
            v_src_segments(10) := combo.segment10;

            -- Initialize target segments
            FOR i IN 1..10 LOOP
                v_tgt_segments(i) := NULL;
            END LOOP;

            -- Apply each rule
            FOR r IN 1..v_rules.COUNT LOOP
                v_rule := v_rules(r);

                -- Get source value (NULL if no source segment)
                IF v_rule.source_segment_num IS NOT NULL
                   AND v_rule.source_segment_num BETWEEN 1 AND 10 THEN
                    v_src_val := v_src_segments(v_rule.source_segment_num);
                ELSE
                    v_src_val := NULL;
                END IF;

                -- ============================================================
                -- CUSTOMIZATION POINT: Add migration-specific logic here.
                -- Example: if v_src_segments(4) IN ('6500','6501') then
                --          use a different value map for this target segment.
                -- ============================================================

                CASE v_rule.mapping_rule
                    WHEN 'PASS_THROUGH' THEN
                        v_tgt_val := v_src_val;

                    WHEN 'CONSTANT' THEN
                        v_tgt_val := v_rule.default_value;

                    WHEN 'PAD_LEFT' THEN
                        v_tgt_val := LPAD(NVL(v_src_val, v_rule.default_value),
                                         v_rule.pad_length,
                                         NVL(v_rule.pad_char, '0'));

                    WHEN 'PAD_RIGHT' THEN
                        v_tgt_val := RPAD(NVL(v_src_val, v_rule.default_value),
                                         v_rule.pad_length,
                                         NVL(v_rule.pad_char, '0'));

                    WHEN 'VALUE_MAP' THEN
                        v_tgt_val := NULL;
                        v_map_id := v_rule.segment_map_id;
                        -- Look up in cached value map
                        IF v_src_val IS NOT NULL
                           AND v_val_maps.EXISTS(v_map_id)
                           AND v_val_maps(v_map_id).EXISTS(v_src_val) THEN
                            v_tgt_val := v_val_maps(v_map_id)(v_src_val);
                        END IF;
                        -- Fallback to default, then pass-through
                        IF v_tgt_val IS NULL THEN
                            v_tgt_val := NVL(v_rule.default_value, v_src_val);
                        END IF;

                    ELSE
                        v_tgt_val := v_src_val;
                END CASE;

                v_tgt_segments(v_rule.target_segment_num) := v_tgt_val;
            END LOOP;

            -- Concatenate target segments
            v_tgt_concat := v_tgt_segments(1);
            FOR i IN 2..v_tgt_num_segs LOOP
                v_tgt_concat := v_tgt_concat || v_tgt_delim || NVL(v_tgt_segments(i), '');
            END LOOP;

            -- Insert (skip if MANUAL or IMPORTED row already exists for this source combo)
            BEGIN
                INSERT INTO DMT_COA_MAPPING (
                    map_config_id, source_concat, target_concat,
                    target_segment1, target_segment2, target_segment3, target_segment4,
                    target_segment5, target_segment6, target_segment7, target_segment8,
                    target_segment9, target_segment10,
                    source_type, active_flag, suggested_flag,
                    created_by, created_date
                ) VALUES (
                    v_config_id, combo.concat_segments, v_tgt_concat,
                    v_tgt_segments(1), v_tgt_segments(2), v_tgt_segments(3), v_tgt_segments(4),
                    v_tgt_segments(5), v_tgt_segments(6), v_tgt_segments(7), v_tgt_segments(8),
                    v_tgt_segments(9), v_tgt_segments(10),
                    'GENERATED', 'Y', 'N',
                    'DMT_COA_MAP_PKG', SYSDATE
                );
                v_count := v_count + 1;
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    NULL; -- MANUAL or IMPORTED row exists, skip
            END;
        END LOOP;

        COMMIT;
        RETURN v_count;
    END GENERATE_MAPPINGS;


    -- =========================================================================
    -- CLEAR_GENERATED
    -- =========================================================================
    PROCEDURE CLEAR_GENERATED (
        p_config_code   IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM DMT_COA_MAPPING
         WHERE map_config_id = (
             SELECT map_config_id FROM DMT_COA_MAP_CONFIG WHERE config_code = p_config_code
         )
           AND source_type = 'GENERATED';
        COMMIT;
    END CLEAR_GENERATED;


    -- =========================================================================
    -- VALIDATE_MAPPINGS
    -- =========================================================================
    FUNCTION VALIDATE_MAPPINGS (
        p_config_code   IN VARCHAR2
    ) RETURN NUMBER
    IS
        v_config_id   NUMBER;
        v_tgt_set_id  NUMBER;
        v_invalid     NUMBER;
    BEGIN
        SELECT mc.map_config_id, mc.target_coa_set_id
          INTO v_config_id, v_tgt_set_id
          FROM DMT_COA_MAP_CONFIG mc
         WHERE mc.config_code = p_config_code;

        -- Mark valid
        UPDATE DMT_COA_MAPPING m
           SET notes = 'VALID'
         WHERE m.map_config_id = v_config_id
           AND m.active_flag = 'Y'
           AND EXISTS (
               SELECT 1 FROM DMT_COA_TARGET_COMBOS tc
                WHERE tc.coa_set_id = v_tgt_set_id
                  AND tc.concat_segments = m.target_concat
                  AND tc.enabled_flag = 'Y'
           );

        -- Mark invalid
        UPDATE DMT_COA_MAPPING m
           SET notes = 'INVALID: target combo not in Fusion'
         WHERE m.map_config_id = v_config_id
           AND m.active_flag = 'Y'
           AND NOT EXISTS (
               SELECT 1 FROM DMT_COA_TARGET_COMBOS tc
                WHERE tc.coa_set_id = v_tgt_set_id
                  AND tc.concat_segments = m.target_concat
                  AND tc.enabled_flag = 'Y'
           );

        v_invalid := SQL%ROWCOUNT;
        COMMIT;
        RETURN v_invalid;
    END VALIDATE_MAPPINGS;

END DMT_COA_MAP_PKG;
/
