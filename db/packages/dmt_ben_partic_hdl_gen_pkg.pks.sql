-- PACKAGE DMT_BEN_PARTIC_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BEN_PARTIC_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_BEN_PARTIC_HDL_GEN_PKG
-- Generates the ParticipantEnrollment.dat HDL file from TFM staging records.
--
-- This object loads through HCM Data Loader as the ParticipantEnrollment
-- business object (verified in the Oracle HDL guide "Example of Loading
-- Participant Enrollments" and probed live on the pod). The HDL package is ONE
-- zip containing ONE DAT file (ParticipantEnrollment.dat) with 1 business
-- object: ParticipantEnrollment. This is distinct from the benefit-BALANCE
-- object PersonBenefitBalance; the prior version wrongly emitted that name.
--
-- OBJECT_TYPE = 'ParticipantEnrollments'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_BEN_PARTIC_HDL_GEN_PKG;
/
