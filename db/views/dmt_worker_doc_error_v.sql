-- DMT_WORKER_DOC_ERROR_V
-- Backlog #289 (design section 5, "Whole-document rejection carries the real
-- error to every grain"). HCM Data Loader rejects a whole Worker logical object
-- (the person with its name, email, phone, address, national identifier,
-- legislative data, work relationship and assignments, all in one Worker.dat)
-- when any one of its records fails, but writes the error only on the record that
-- failed. This view gives, per run, HDL request and person, the quoted error every
-- other record of that person must carry: the FIRST staged HDL error message (in
-- file and line order) whose SourceSystemId is one of that person's records,
-- formatted by DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR as
--   [FUSION_ERROR] Rejected with document: <business object> <SourceSystemId>: <message>
--
-- The person's SourceSystemIds are exactly the ones DMT_WORKER_HDL_GEN_PKG writes:
--   Worker <PERSON_NUMBER>; WorkRelationship <worker TFM id>;
--   PersonName/Email/Phone/Address/NationalIdentifier/LegislativeData
--   <PERSON_NUMBER>_NME/_EML/_PHN/_ADR/_NID/_LEG;
--   WorkTerms <assignment TFM id>_TRM; Assignment <ASSIGNMENT_NUMBER>_ASG.
-- The messages come from the session table DMT_HDL_MESSAGE_GTT, staged by
-- DMT_HDL_UTIL_PKG.STAGE_HDL_MESSAGES, so the view only returns rows in the
-- session that staged them. Read by DMT_WORKER_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS.
CREATE OR REPLACE EDITIONABLE VIEW "DMT_WORKER_DOC_ERROR_V" ("RUN_ID", "REQUEST_ID", "PERSON_NUMBER", "QUOTED_ERROR") AS
  SELECT d.RUN_ID,
         d.REQUEST_ID,
         d.PERSON_NUMBER,
         d.QUOTED_ERROR
  FROM  (SELECT k.RUN_ID,
                m.REQUEST_ID,
                k.PERSON_NUMBER,
                DMT_UTIL_PKG.FORMAT_DOCUMENT_ERROR(
                    m.BUSINESS_OBJECT, m.SOURCE_SYSTEM_ID, m.MESSAGE_TEXT) AS QUOTED_ERROR,
                ROW_NUMBER() OVER (
                    PARTITION BY k.RUN_ID, m.REQUEST_ID, k.PERSON_NUMBER
                    ORDER BY m.DAT_FILE_NAME, m.FILE_LINE, m.MESSAGE_LINE_ID) AS RN
         FROM  (SELECT RUN_ID, PERSON_NUMBER, PERSON_NUMBER AS SSID
                FROM   DMT_WORKER_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, TO_CHAR(TFM_SEQUENCE_ID)
                FROM   DMT_WORKER_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, PERSON_NUMBER || '_NME'
                FROM   DMT_PERSON_NAME_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, PERSON_NUMBER || '_EML'
                FROM   DMT_PERSON_EMAIL_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, PERSON_NUMBER || '_PHN'
                FROM   DMT_PERSON_PHONE_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, PERSON_NUMBER || '_ADR'
                FROM   DMT_PERSON_ADDR_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, PERSON_NUMBER || '_NID'
                FROM   DMT_PERSON_NID_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, PERSON_NUMBER || '_LEG'
                FROM   DMT_PERSON_LEGISL_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, TO_CHAR(TFM_SEQUENCE_ID) || '_TRM'
                FROM   DMT_ASSIGNMENT_TFM_TBL
                UNION ALL
                SELECT RUN_ID, PERSON_NUMBER, ASSIGNMENT_NUMBER || '_ASG'
                FROM   DMT_ASSIGNMENT_TFM_TBL) k
         JOIN   DMT_HDL_MESSAGE_GTT m
           ON   m.SOURCE_SYSTEM_ID = k.SSID) d
  WHERE  d.RN = 1
/
