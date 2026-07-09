-- PACKAGE BODY DMT_UPLOAD_DICT_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_UPLOAD_DICT_PKG" 
AS
-- ============================================================
-- DMT_UPLOAD_DICT_PKG body
-- ============================================================

    -- Known admin (infrastructure) columns on staging tables.
    -- These are never supplied by users in CSV uploads.
    C_ADMIN_COLUMNS CONSTANT VARCHAR2(4000) :=
        ',STG_SEQUENCE_ID,SOURCE_ID,STAGE_DATE,STG_STATUS,ERROR_TEXT,LAST_UPDATED_DATE,';

    -- --------------------------------------------------------
    -- Map Oracle data type to simplified display type
    -- --------------------------------------------------------
    FUNCTION map_data_type (p_oracle_type IN VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        IF p_oracle_type IN ('NUMBER', 'FLOAT', 'BINARY_DOUBLE', 'BINARY_FLOAT') THEN
            RETURN 'Number';
        ELSIF p_oracle_type IN ('DATE') THEN
            RETURN 'Date';
        ELSIF p_oracle_type LIKE 'TIMESTAMP%' THEN
            RETURN 'Date';
        ELSE
            RETURN 'Text';
        END IF;
    END map_data_type;

    -- --------------------------------------------------------
    -- Determine if a column is an admin/infrastructure column
    -- --------------------------------------------------------
    FUNCTION is_admin (p_column_name IN VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        IF INSTR(C_ADMIN_COLUMNS, ',' || p_column_name || ',') > 0 THEN
            RETURN 'Y';
        END IF;
        RETURN 'N';
    END is_admin;

    -- --------------------------------------------------------
    -- SEED_DICTIONARY
    -- --------------------------------------------------------
    PROCEDURE SEED_DICTIONARY
    IS
        l_count      PLS_INTEGER := 0;
        l_data_type  VARCHAR2(30);
        l_is_admin   VARCHAR2(1);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_message   => 'Starting dictionary seed',
            p_package   => 'DMT_UPLOAD_DICT_PKG',
            p_procedure => 'SEED_DICTIONARY'
        );

        -- Clear existing dictionary
        DELETE FROM DMT_UPLOAD_DICT_TBL;

        -- Insert one row per column per registered staging table
        FOR obj IN (
            SELECT OBJECT_CODE, DISPLAY_NAME, PAGE_NUMBER, STAGING_TABLE
            FROM   DMT_UPLOAD_OBJECT_TBL
            WHERE  IS_ACTIVE = 'Y'
            ORDER BY PAGE_NUMBER, DISPLAY_ORDER
        ) LOOP
            FOR col IN (
                SELECT COLUMN_NAME,
                       COLUMN_ID,
                       DATA_TYPE,
                       NULLABLE
                FROM   USER_TAB_COLUMNS
                WHERE  TABLE_NAME = obj.STAGING_TABLE
                ORDER BY COLUMN_ID
            ) LOOP
                l_data_type := map_data_type(col.DATA_TYPE);
                l_is_admin  := is_admin(col.COLUMN_NAME);

                INSERT INTO DMT_UPLOAD_DICT_TBL (
                    OBJECT_CODE, DISPLAY_NAME, PAGE_NUMBER, STAGING_TABLE,
                    COLUMN_NAME, COLUMN_ORDER, DATA_TYPE, NULLABLE,
                    IS_ADMIN_COLUMN
                ) VALUES (
                    obj.OBJECT_CODE,
                    obj.DISPLAY_NAME,
                    obj.PAGE_NUMBER,
                    obj.STAGING_TABLE,
                    col.COLUMN_NAME,
                    col.COLUMN_ID,
                    l_data_type,
                    col.NULLABLE,
                    l_is_admin
                );

                l_count := l_count + 1;
            END LOOP;
        END LOOP;

        COMMIT;

        DMT_UTIL_PKG.LOG(
            p_message   => 'Dictionary seed complete — ' || l_count || ' column entries created',
            p_package   => 'DMT_UPLOAD_DICT_PKG',
            p_procedure => 'SEED_DICTIONARY'
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'Dictionary seed failed',
                p_sqlerrm   => SQLERRM,
                p_package   => 'DMT_UPLOAD_DICT_PKG',
                p_procedure => 'SEED_DICTIONARY'
            );
            RAISE;
    END SEED_DICTIONARY;

    -- --------------------------------------------------------
    -- REFRESH_DICTIONARY
    -- --------------------------------------------------------
    PROCEDURE REFRESH_DICTIONARY
    IS
        l_added      PLS_INTEGER := 0;
        l_removed    PLS_INTEGER := 0;
        l_updated    PLS_INTEGER := 0;
        l_data_type  VARCHAR2(30);
        l_is_admin   VARCHAR2(1);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_message   => 'Starting dictionary refresh',
            p_package   => 'DMT_UPLOAD_DICT_PKG',
            p_procedure => 'REFRESH_DICTIONARY'
        );

        FOR obj IN (
            SELECT OBJECT_CODE, DISPLAY_NAME, PAGE_NUMBER, STAGING_TABLE
            FROM   DMT_UPLOAD_OBJECT_TBL
            WHERE  IS_ACTIVE = 'Y'
        ) LOOP

            -- Add new columns
            FOR col IN (
                SELECT c.COLUMN_NAME, c.COLUMN_ID, c.DATA_TYPE, c.NULLABLE
                FROM   USER_TAB_COLUMNS c
                WHERE  c.TABLE_NAME = obj.STAGING_TABLE
                AND    NOT EXISTS (
                    SELECT 1 FROM DMT_UPLOAD_DICT_TBL d
                    WHERE  d.OBJECT_CODE  = obj.OBJECT_CODE
                    AND    d.COLUMN_NAME  = c.COLUMN_NAME
                )
            ) LOOP
                l_data_type := map_data_type(col.DATA_TYPE);
                l_is_admin  := is_admin(col.COLUMN_NAME);

                INSERT INTO DMT_UPLOAD_DICT_TBL (
                    OBJECT_CODE, DISPLAY_NAME, PAGE_NUMBER, STAGING_TABLE,
                    COLUMN_NAME, COLUMN_ORDER, DATA_TYPE, NULLABLE,
                    IS_ADMIN_COLUMN
                ) VALUES (
                    obj.OBJECT_CODE,
                    obj.DISPLAY_NAME,
                    obj.PAGE_NUMBER,
                    obj.STAGING_TABLE,
                    col.COLUMN_NAME,
                    col.COLUMN_ID,
                    l_data_type,
                    col.NULLABLE,
                    l_is_admin
                );
                l_added := l_added + 1;
            END LOOP;

            -- Remove dropped columns
            DELETE FROM DMT_UPLOAD_DICT_TBL d
            WHERE  d.OBJECT_CODE  = obj.OBJECT_CODE
            AND    NOT EXISTS (
                SELECT 1 FROM USER_TAB_COLUMNS c
                WHERE  c.TABLE_NAME  = obj.STAGING_TABLE
                AND    c.COLUMN_NAME = d.COLUMN_NAME
            );
            l_removed := l_removed + SQL%ROWCOUNT;

            -- Update data types and nullable that have changed
            FOR col IN (
                SELECT c.COLUMN_NAME, c.COLUMN_ID, c.DATA_TYPE, c.NULLABLE
                FROM   USER_TAB_COLUMNS c
                WHERE  c.TABLE_NAME = obj.STAGING_TABLE
            ) LOOP
                l_data_type := map_data_type(col.DATA_TYPE);
                UPDATE DMT_UPLOAD_DICT_TBL
                SET    DATA_TYPE          = l_data_type,
                       NULLABLE           = col.NULLABLE,
                       COLUMN_ORDER       = col.COLUMN_ID,
                       LAST_UPDATED_DATE  = SYSTIMESTAMP
                WHERE  OBJECT_CODE  = obj.OBJECT_CODE
                AND    COLUMN_NAME  = col.COLUMN_NAME
                AND    (DATA_TYPE != l_data_type
                        OR NULLABLE != col.NULLABLE
                        OR COLUMN_ORDER != col.COLUMN_ID);
                l_updated := l_updated + SQL%ROWCOUNT;
            END LOOP;

        END LOOP;

        COMMIT;

        DMT_UTIL_PKG.LOG(
            p_message   => 'Dictionary refresh complete — added: ' || l_added
                           || ', removed: ' || l_removed
                           || ', updated: ' || l_updated,
            p_package   => 'DMT_UPLOAD_DICT_PKG',
            p_procedure => 'REFRESH_DICTIONARY'
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DMT_UTIL_PKG.LOG_ERROR(
                p_message   => 'Dictionary refresh failed',
                p_sqlerrm   => SQLERRM,
                p_package   => 'DMT_UPLOAD_DICT_PKG',
                p_procedure => 'REFRESH_DICTIONARY'
            );
            RAISE;
    END REFRESH_DICTIONARY;

END DMT_UPLOAD_DICT_PKG;
/
