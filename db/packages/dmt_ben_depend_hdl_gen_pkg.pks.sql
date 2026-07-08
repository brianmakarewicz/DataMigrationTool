-- PACKAGE DMT_BEN_DEPEND_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BEN_DEPEND_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_BEN_DEPEND_HDL_GEN_PKG
-- Generates the BenefitParticipantEnrollment.dat HDL file from TFM staging records.
--
-- DependentEnrollment HDL is ONE zip containing ONE DAT file with 1 business object(s):
--   DependentEnrollment.
--
-- OBJECT_TYPE = 'DependentEnrollments'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_BEN_DEPEND_HDL_GEN_PKG;
/
