-- PACKAGE BODY DMT_WORKER_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_WORKER_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_WORKER_TRANSFORM_PKG Body
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_WORKER_TRANSFORM_PKG';

    -- --------------------------------------------------------
    -- Private: read run prefix from CONVERSION_MASTER
    -- --------------------------------------------------------
    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    -- --------------------------------------------------------
    -- Private: read dependent prefix from CONVERSION_MASTER
    -- --------------------------------------------------------
    FUNCTION get_dep_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_dep_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_dep_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_dep_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_dep_prefix;


    -- ============================================================
    -- TRANSFORM_WORKERS
    -- ============================================================
    PROCEDURE TRANSFORM_WORKERS (
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
            p_message        => 'TRANSFORM_WORKERS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_WORKERS');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_WORKER_TFM_TBL (
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            DATE_OF_BIRTH,
            ACTION_CODE,
            START_DATE,
            LEGAL_ENTITY_NAME,
            CATEGORY_CODE,
            PROJECTED_TERMINATION_DATE,
            BLOOD_TYPE,
            CORRESPONDENCE_LANGUAGE,
            TOWN_OF_BIRTH,
            REGION_OF_BIRTH,
            COUNTRY_OF_BIRTH,
            DATE_OF_DEATH,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.DATE_OF_BIRTH,
            s.ACTION_CODE,
            s.START_DATE,
            s.LEGAL_ENTITY_NAME,
            s.CATEGORY_CODE,
            s.PROJECTED_TERMINATION_DATE,
            s.BLOOD_TYPE,
            s.CORRESPONDENCE_LANGUAGE,
            s.TOWN_OF_BIRTH,
            s.REGION_OF_BIRTH,
            s.COUNTRY_OF_BIRTH,
            s.DATE_OF_DEATH,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_WORKER_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_WORKER_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so TFM_SEQUENCE_ID (identity) is assigned in staging order.
        -- The HDL generator emits sections ORDER BY TFM_SEQUENCE_ID, so this
        -- makes the .dat line order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_WORKER_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_WORKER_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_WORKERS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_WORKERS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_WORKERS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_WORKERS');
            RAISE;
    END TRANSFORM_WORKERS;


    -- ============================================================
    -- TRANSFORM_PERSON_NAMES
    -- ============================================================
    PROCEDURE TRANSFORM_PERSON_NAMES (
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
            p_message        => 'TRANSFORM_PERSON_NAMES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_NAMES');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_PERSON_NAME_TFM_TBL (
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            LEGISLATION_CODE,
            NAME_TYPE,
            LAST_NAME,
            FIRST_NAME,
            MIDDLE_NAMES,
            TITLE,
            SUFFIX,
            PRE_NAME_ADJUNCT,
            KNOWN_AS,
            DISPLAY_NAME,
            ORDER_NAME,
            LIST_NAME,
            FULL_NAME,
            NAME_INFORMATION1, NAME_INFORMATION2, NAME_INFORMATION3, NAME_INFORMATION4, NAME_INFORMATION5,
            NAME_INFORMATION6, NAME_INFORMATION7, NAME_INFORMATION8, NAME_INFORMATION9, NAME_INFORMATION10,
            NAME_INFORMATION11, NAME_INFORMATION12, NAME_INFORMATION13, NAME_INFORMATION14, NAME_INFORMATION15,
            NAME_INFORMATION16, NAME_INFORMATION17, NAME_INFORMATION18, NAME_INFORMATION19, NAME_INFORMATION20,
            NAME_INFORMATION21, NAME_INFORMATION22, NAME_INFORMATION23, NAME_INFORMATION24, NAME_INFORMATION25,
            NAME_INFORMATION26, NAME_INFORMATION27, NAME_INFORMATION28, NAME_INFORMATION29, NAME_INFORMATION30,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.LEGISLATION_CODE,
            s.NAME_TYPE,
            s.LAST_NAME,
            s.FIRST_NAME,
            s.MIDDLE_NAMES,
            s.TITLE,
            s.SUFFIX,
            s.PRE_NAME_ADJUNCT,
            s.KNOWN_AS,
            s.DISPLAY_NAME,
            s.ORDER_NAME,
            s.LIST_NAME,
            s.FULL_NAME,
            s.NAME_INFORMATION1, s.NAME_INFORMATION2, s.NAME_INFORMATION3, s.NAME_INFORMATION4, s.NAME_INFORMATION5,
            s.NAME_INFORMATION6, s.NAME_INFORMATION7, s.NAME_INFORMATION8, s.NAME_INFORMATION9, s.NAME_INFORMATION10,
            s.NAME_INFORMATION11, s.NAME_INFORMATION12, s.NAME_INFORMATION13, s.NAME_INFORMATION14, s.NAME_INFORMATION15,
            s.NAME_INFORMATION16, s.NAME_INFORMATION17, s.NAME_INFORMATION18, s.NAME_INFORMATION19, s.NAME_INFORMATION20,
            s.NAME_INFORMATION21, s.NAME_INFORMATION22, s.NAME_INFORMATION23, s.NAME_INFORMATION24, s.NAME_INFORMATION25,
            s.NAME_INFORMATION26, s.NAME_INFORMATION27, s.NAME_INFORMATION28, s.NAME_INFORMATION29, s.NAME_INFORMATION30,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PERSON_NAME_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_PERSON_NAME_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so TFM_SEQUENCE_ID (identity) is assigned in staging order.
        -- The HDL generator emits sections ORDER BY TFM_SEQUENCE_ID, so this
        -- makes the .dat line order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PERSON_NAME_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PERSON_NAME_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PERSON_NAMES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_NAMES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PERSON_NAMES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PERSON_NAMES');
            RAISE;
    END TRANSFORM_PERSON_NAMES;


    -- ============================================================
    -- TRANSFORM_PERSON_EMAILS
    -- ============================================================
    PROCEDURE TRANSFORM_PERSON_EMAILS (
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
            p_message        => 'TRANSFORM_PERSON_EMAILS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_EMAILS');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_PERSON_EMAIL_TFM_TBL (
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            EMAIL_TYPE,
            EMAIL_ADDRESS,
            PRIMARY_FLAG,
            FROM_DATE,
            TO_DATE,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.EMAIL_TYPE,
            s.EMAIL_ADDRESS,
            s.PRIMARY_FLAG,
            s.FROM_DATE,
            s.TO_DATE,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PERSON_EMAIL_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_PERSON_EMAIL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so TFM_SEQUENCE_ID (identity) is assigned in staging order.
        -- The HDL generator emits sections ORDER BY TFM_SEQUENCE_ID, so this
        -- makes the .dat line order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PERSON_EMAIL_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PERSON_EMAIL_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PERSON_EMAILS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_EMAILS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PERSON_EMAILS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PERSON_EMAILS');
            RAISE;
    END TRANSFORM_PERSON_EMAILS;


    -- ============================================================
    -- TRANSFORM_PERSON_PHONES
    -- ============================================================
    PROCEDURE TRANSFORM_PERSON_PHONES (
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
            p_message        => 'TRANSFORM_PERSON_PHONES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_PHONES');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_PERSON_PHONE_TFM_TBL (
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            PHONE_TYPE,
            COUNTRY_CODE_NUMBER,
            AREA_CODE,
            PHONE_NUMBER,
            EXTENSION,
            PRIMARY_FLAG,
            FROM_DATE,
            TO_DATE,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.PHONE_TYPE,
            s.COUNTRY_CODE_NUMBER,
            s.AREA_CODE,
            s.PHONE_NUMBER,
            s.EXTENSION,
            s.PRIMARY_FLAG,
            s.FROM_DATE,
            s.TO_DATE,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PERSON_PHONE_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_PERSON_PHONE_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so TFM_SEQUENCE_ID (identity) is assigned in staging order.
        -- The HDL generator emits sections ORDER BY TFM_SEQUENCE_ID, so this
        -- makes the .dat line order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PERSON_PHONE_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PERSON_PHONE_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PERSON_PHONES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_PHONES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PERSON_PHONES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PERSON_PHONES');
            RAISE;
    END TRANSFORM_PERSON_PHONES;


    -- ============================================================
    -- TRANSFORM_PERSON_ADDRESSES
    -- ============================================================
    PROCEDURE TRANSFORM_PERSON_ADDRESSES (
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
            p_message        => 'TRANSFORM_PERSON_ADDRESSES start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_ADDRESSES');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_PERSON_ADDR_TFM_TBL (
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            ADDRESS_TYPE,
            ADDRESS_LINE_1,
            ADDRESS_LINE_2,
            ADDRESS_LINE_3,
            ADDRESS_LINE_4,
            TOWN_OR_CITY,
            REGION_1,
            REGION_2,
            REGION_3,
            POSTAL_CODE,
            COUNTRY,
            PRIMARY_FLAG,
            FROM_DATE,
            TO_DATE,
            ADD_INFORMATION13, ADD_INFORMATION14, ADD_INFORMATION15, ADD_INFORMATION16,
            ADD_INFORMATION17, ADD_INFORMATION18, ADD_INFORMATION19, ADD_INFORMATION20,
            ADD_INFORMATION21, ADD_INFORMATION22, ADD_INFORMATION23, ADD_INFORMATION24,
            ADD_INFORMATION25, ADD_INFORMATION26, ADD_INFORMATION27, ADD_INFORMATION28,
            ADD_INFORMATION29, ADD_INFORMATION30,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.ADDRESS_TYPE,
            s.ADDRESS_LINE_1,
            s.ADDRESS_LINE_2,
            s.ADDRESS_LINE_3,
            s.ADDRESS_LINE_4,
            s.TOWN_OR_CITY,
            s.REGION_1,
            s.REGION_2,
            s.REGION_3,
            s.POSTAL_CODE,
            s.COUNTRY,
            s.PRIMARY_FLAG,
            s.FROM_DATE,
            s.TO_DATE,
            s.ADD_INFORMATION13, s.ADD_INFORMATION14, s.ADD_INFORMATION15, s.ADD_INFORMATION16,
            s.ADD_INFORMATION17, s.ADD_INFORMATION18, s.ADD_INFORMATION19, s.ADD_INFORMATION20,
            s.ADD_INFORMATION21, s.ADD_INFORMATION22, s.ADD_INFORMATION23, s.ADD_INFORMATION24,
            s.ADD_INFORMATION25, s.ADD_INFORMATION26, s.ADD_INFORMATION27, s.ADD_INFORMATION28,
            s.ADD_INFORMATION29, s.ADD_INFORMATION30,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PERSON_ADDR_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_PERSON_ADDR_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so TFM_SEQUENCE_ID (identity) is assigned in staging order.
        -- The HDL generator emits sections ORDER BY TFM_SEQUENCE_ID, so this
        -- makes the .dat line order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PERSON_ADDR_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PERSON_ADDR_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PERSON_ADDRESSES complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_ADDRESSES');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PERSON_ADDRESSES failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PERSON_ADDRESSES');
            RAISE;
    END TRANSFORM_PERSON_ADDRESSES;


    -- ============================================================
    -- TRANSFORM_PERSON_NIDS
    -- ============================================================
    PROCEDURE TRANSFORM_PERSON_NIDS (
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
            p_message        => 'TRANSFORM_PERSON_NIDS start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_NIDS');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_PERSON_NID_TFM_TBL (
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            LEGISLATION_CODE,
            NATIONAL_IDENTIFIER_TYPE,
            NATIONAL_IDENTIFIER_NUMBER,
            ISSUE_DATE,
            EXPIRATION_DATE,
            PLACE_OF_ISSUE,
            PRIMARY_FLAG,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.LEGISLATION_CODE,
            s.NATIONAL_IDENTIFIER_TYPE,
            s.NATIONAL_IDENTIFIER_NUMBER,
            s.ISSUE_DATE,
            s.EXPIRATION_DATE,
            s.PLACE_OF_ISSUE,
            s.PRIMARY_FLAG,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PERSON_NID_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_PERSON_NID_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so TFM_SEQUENCE_ID (identity) is assigned in staging order.
        -- The HDL generator emits sections ORDER BY TFM_SEQUENCE_ID, so this
        -- makes the .dat line order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PERSON_NID_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PERSON_NID_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PERSON_NIDS complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_NIDS');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PERSON_NIDS failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PERSON_NIDS');
            RAISE;
    END TRANSFORM_PERSON_NIDS;


    -- ============================================================
    -- TRANSFORM_PERSON_LEGISL
    -- ============================================================
    PROCEDURE TRANSFORM_PERSON_LEGISL (
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
            p_message        => 'TRANSFORM_PERSON_LEGISL start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_LEGISL');

        l_prefix := get_prefix(p_run_id);

        INSERT INTO DMT_OWNER.DMT_PERSON_LEGISL_TFM_TBL (
            STG_SEQUENCE_ID,
            RUN_ID,
            FBDI_CSV_ID,
            EFFECTIVE_START_DATE,
            EFFECTIVE_END_DATE,
            PERSON_NUMBER,
            LEGISLATION_CODE,
            SEX,
            MARITAL_STATUS,
            HIGHEST_EDUCATION_LEVEL,
            ETHNICITY,
            VETERAN_SELF_IDENT_FLAG,
            TOBACCO_USER,
            DISABLED_FLAG,
            PER_INFORMATION1, PER_INFORMATION2, PER_INFORMATION3, PER_INFORMATION4, PER_INFORMATION5,
            PER_INFORMATION6, PER_INFORMATION7, PER_INFORMATION8, PER_INFORMATION9, PER_INFORMATION10,
            PER_INFORMATION11, PER_INFORMATION12, PER_INFORMATION13, PER_INFORMATION14, PER_INFORMATION15,
            PER_INFORMATION16, PER_INFORMATION17, PER_INFORMATION18, PER_INFORMATION19, PER_INFORMATION20,
            PER_INFORMATION21, PER_INFORMATION22, PER_INFORMATION23, PER_INFORMATION24, PER_INFORMATION25,
            PER_INFORMATION26, PER_INFORMATION27, PER_INFORMATION28, PER_INFORMATION29, PER_INFORMATION30,
            TFM_STATUS,
            LAST_UPDATED_DATE
        )
        SELECT
            s.STG_SEQUENCE_ID,
            p_run_id,
            NULL,
            s.EFFECTIVE_START_DATE,
            s.EFFECTIVE_END_DATE,
            DMT_UTIL_PKG.PREFIXED(l_prefix, s.PERSON_NUMBER, 30),
            s.LEGISLATION_CODE,
            s.SEX,
            s.MARITAL_STATUS,
            s.HIGHEST_EDUCATION_LEVEL,
            s.ETHNICITY,
            s.VETERAN_SELF_IDENT_FLAG,
            s.TOBACCO_USER,
            s.DISABLED_FLAG,
            s.PER_INFORMATION1, s.PER_INFORMATION2, s.PER_INFORMATION3, s.PER_INFORMATION4, s.PER_INFORMATION5,
            s.PER_INFORMATION6, s.PER_INFORMATION7, s.PER_INFORMATION8, s.PER_INFORMATION9, s.PER_INFORMATION10,
            s.PER_INFORMATION11, s.PER_INFORMATION12, s.PER_INFORMATION13, s.PER_INFORMATION14, s.PER_INFORMATION15,
            s.PER_INFORMATION16, s.PER_INFORMATION17, s.PER_INFORMATION18, s.PER_INFORMATION19, s.PER_INFORMATION20,
            s.PER_INFORMATION21, s.PER_INFORMATION22, s.PER_INFORMATION23, s.PER_INFORMATION24, s.PER_INFORMATION25,
            s.PER_INFORMATION26, s.PER_INFORMATION27, s.PER_INFORMATION28, s.PER_INFORMATION29, s.PER_INFORMATION30,
            'STAGED',
            SYSDATE
        FROM DMT_OWNER.DMT_PERSON_LEGISL_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL')
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1
            FROM   DMT_OWNER.DMT_PERSON_LEGISL_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        )
        -- Deterministic identity assignment: order the INSERT..SELECT by the
        -- STG PK so TFM_SEQUENCE_ID (identity) is assigned in staging order.
        -- The HDL generator emits sections ORDER BY TFM_SEQUENCE_ID, so this
        -- makes the .dat line order reproducible (byte-stable golden compare).
        ORDER BY s.STG_SEQUENCE_ID;

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_PERSON_LEGISL_STG_TBL
        SET    STG_STATUS = 'TRANSFORMED', LAST_UPDATED_DATE = SYSDATE
        WHERE  STG_SEQUENCE_ID IN (
            SELECT STG_SEQUENCE_ID
            FROM   DMT_OWNER.DMT_PERSON_LEGISL_TFM_TBL
            WHERE  RUN_ID = p_run_id
        )
        AND (
            (p_run_mode = 'NEW' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM_PERSON_LEGISL complete. Rows transformed: ' || l_ok_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM_PERSON_LEGISL');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM_PERSON_LEGISL failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM_PERSON_LEGISL');
            RAISE;
    END TRANSFORM_PERSON_LEGISL;

END DMT_WORKER_TRANSFORM_PKG;
/
