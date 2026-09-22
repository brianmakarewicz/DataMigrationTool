-- PACKAGE BODY DMT_BEN_PARTIC_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_BEN_PARTIC_HDL_GEN_PKG"
AS
-- ============================================================
-- DMT_BEN_PARTIC_HDL_GEN_PKG body
-- ParticipantEnrollment HDL DAT generation.
--
-- HCM re-model (2026-09-17): this object loads through HCM Data Loader as the
-- ParticipantEnrollment business object -- NOT PersonBenefitBalance. The prior
-- version emitted the discriminator/header/file name 'PersonBenefitBalance',
-- which is the benefit-BALANCE object, not participant enrollment, and it
-- collided with the two other benefit generators (BeneficiaryDesignation,
-- DependentEnrollment) that also emitted PersonBenefitBalance.dat. Corrected to
-- the object verified in the Oracle HCM Data Loader guide ("Example of Loading
-- Participant Enrollments") and probed live on this pod.
--
-- Verified from Oracle docs (docs.oracle.com/.../fahbo/example-of-loading-
-- participant-enrollments.html):
--   * Business object / DAT discriminator : ParticipantEnrollment
--   * File name                           : ParticipantEnrollment.dat
--   * METADATA attribute list (in order)  :
--       PersonNumber|ParticipantLastName|ParticipantFirstName|
--       BenefitRelationship|LifeEvent|LifeEventOccuredDate|EffectiveDate
--   * Required attributes: PersonNumber, BenefitRelationship, LifeEvent,
--     LifeEventOccuredDate, EffectiveDate.
--   * Create-only object (no SourceSystemId key; the worker is referenced by its
--     PersonNumber, which is already the prefixed number the Workers pipeline
--     loaded -- so no worker record is repeated here).
--
-- Verified live 2026-09-17 (fusion_bip_query --cred fin_impl):
--   * Benefits IS configured on the pod: BEN_PGM_F has 24 programs,
--     BEN_PRTT_ENRT_RSLT has 38,411 enrollment results, BEN_LER_F lists real
--     life events including 'New Hire'.
--   * 'ParticipantEnrollment' is create-only and does NOT register a
--     SourceSystemId row in HRC_INTEGRATION_KEY_MAP (confirmed absent), so
--     reconciliation matches the base table BEN_PRTT_ENRT_RSLT by PersonNumber
--     (see DMT_BENPARTICIPANT_RECON_DM.xdm), not by SourceSystemId.
--
-- Defaults for attributes with no dedicated TFM column:
--   * BenefitRelationship : the TFM BENEFIT_RELATIONSHIP_NAME, else 'Default'.
--   * LifeEvent           : 'New Hire' (valid on this pod) when TFM has none.
--   * LifeEventOccuredDate: the enrollment start date.
--   * ParticipantLastName / ParticipantFirstName: informational-only per the
--     guide; left blank (the worker is already loaded with a name).
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_BEN_PARTIC_HDL_GEN_PKG';

    -- HDL business object / DAT discriminator and file name for this object.
    C_BUSINESS_OBJECT CONSTANT VARCHAR2(30) := 'ParticipantEnrollment';
    C_DAT_FILENAME    CONSTANT VARCHAR2(40) := 'ParticipantEnrollment.dat';

    -- METADATA column list for ParticipantEnrollment (Oracle HDL guide order).
    C_PARTICIPANTENROLLMENT_COLS CONSTANT VARCHAR2(4000) :=
        'PersonNumber|ParticipantLastName|ParticipantFirstName|'
        || 'BenefitRelationship|LifeEvent|LifeEventOccuredDate|EffectiveDate';

    -- Defaults when the TFM row carries no value for a required attribute.
    C_DEFAULT_BEN_REL   CONSTANT VARCHAR2(30) := 'Default';
    C_DEFAULT_LIFE_EVENT CONSTANT VARCHAR2(30) := 'New Hire';


    FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB IS
        l_blob         BLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        l_warning      INTEGER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(
            dest_lob     => l_blob,
            src_clob     => p_clob,
            amount       => DBMS_LOB.LOBMAXSIZE,
            dest_offset  => l_dest_offset,
            src_offset   => l_src_offset,
            blob_csid    => DBMS_LOB.DEFAULT_CSID,
            lang_context => l_lang_context,
            warning      => l_warning);
        RETURN l_blob;
    END clob_to_blob;

    FUNCTION pv(p_val IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(p_val, '');
    END pv;

    FUNCTION nvl_val(p_val IN VARCHAR2, p_default IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(p_val, p_default);
    END nvl_val;

    FUNCTION has_rows(p_tbl VARCHAR2, p_iid NUMBER) RETURN BOOLEAN IS
        l_cnt NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_tbl ||
            ' WHERE RUN_ID = :1 AND TFM_STATUS = ''STAGED'' AND ROWNUM = 1'
            INTO l_cnt USING p_iid;
        RETURN l_cnt > 0;
    END has_rows;


    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    )
    IS
        l_dat         CLOB;
        l_zip         BLOB;
        l_csv_id      NUMBER;
        l_now         DATE := SYSDATE;
        l_row_count   NUMBER := 0;
        l_vals        VARCHAR2(32767);
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL start.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

        x_filename := 'ParticipantEnrollments_' || TO_CHAR(p_run_id) || '.zip';

        DBMS_LOB.CREATETEMPORARY(l_dat, TRUE);


        -- ============================================================
        -- 1. ParticipantEnrollment
        -- ============================================================
        IF has_rows('DMT_BEN_PARTIC_TFM_TBL', p_run_id) THEN
            DBMS_LOB.WRITEAPPEND(l_dat,
                LENGTH(DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_BUSINESS_OBJECT, C_PARTICIPANTENROLLMENT_COLS)),
                DMT_HDL_UTIL_PKG.BUILD_DAT_HEADER(C_BUSINESS_OBJECT, C_PARTICIPANTENROLLMENT_COLS));

            FOR r IN (
                SELECT t.*
                FROM   DMT_BEN_PARTIC_TFM_TBL t
                WHERE  t.RUN_ID = p_run_id
                AND    t.TFM_STATUS = 'STAGED'
                ORDER BY t.TFM_SEQUENCE_ID
            ) LOOP
                -- PersonNumber references the already-loaded worker (prefixed
                -- number); no worker record is repeated. Last/first name are
                -- informational-only per the HDL guide and left blank.
                l_vals := pv(r.PERSON_NUMBER)                                    || '|' ||
                          ''                                                     || '|' ||  -- ParticipantLastName
                          ''                                                     || '|' ||  -- ParticipantFirstName
                          nvl_val(r.BENEFIT_RELATIONSHIP_NAME, C_DEFAULT_BEN_REL) || '|' ||
                          C_DEFAULT_LIFE_EVENT                                   || '|' ||
                          pv(r.ENROLLMENT_START_DATE)                           || '|' ||  -- LifeEventOccuredDate
                          pv(r.ENROLLMENT_START_DATE);                                     -- EffectiveDate
                DMT_HDL_UTIL_PKG.APPEND_DAT_LINE(l_dat, l_vals, p_discriminator => C_BUSINESS_OBJECT);
                l_row_count := l_row_count + 1;
            END LOOP;
        END IF;


        -- ============================================================
        -- ZIP the DAT CLOB
        -- ============================================================
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF DBMS_LOB.GETLENGTH(l_dat) > 0 THEN
            UTL_ZIP.add1file(l_zip, C_DAT_FILENAME,
                clob_to_blob(l_dat));
        END IF;
        UTL_ZIP.finish_zip(l_zip);

        -- ============================================================
        -- Store in DMT_FBDI_CSV_TBL + DMT_FBDI_ZIP_TBL
        -- ============================================================
        SELECT DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;

        INSERT INTO DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'ParticipantEnrollments',
            C_DAT_FILENAME, l_row_count, l_dat, l_now
        );

        INSERT INTO DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, p_run_id,
            'ParticipantEnrollments', x_filename,
            DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- ============================================================
        -- Update TFM table(s) to GENERATED and stamp FBDI_CSV_ID
        -- ============================================================
        UPDATE DMT_BEN_PARTIC_TFM_TBL
        SET    TFM_STATUS = 'GENERATED', FBDI_CSV_ID = l_csv_id, LAST_UPDATED_DATE = l_now
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED';


        DBMS_LOB.FREETEMPORARY(l_dat);

        x_hdl_zip := l_zip;
        x_csv_id  := l_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'GENERATE_HDL complete. Total data lines: ' || l_row_count ||
                                ' | Zip size: ' || DBMS_LOB.GETLENGTH(l_zip) || ' bytes.',
            p_package        => C_PKG,
            p_procedure      => 'GENERATE_HDL');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'GENERATE_HDL failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'GENERATE_HDL');
            RAISE;
    END GENERATE_HDL;

END DMT_BEN_PARTIC_HDL_GEN_PKG;
/
