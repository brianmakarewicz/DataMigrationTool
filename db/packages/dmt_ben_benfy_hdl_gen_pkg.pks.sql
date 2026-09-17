-- PACKAGE DMT_BEN_BENFY_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BEN_BENFY_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_BEN_BENFY_HDL_GEN_PKG
-- Generates the BeneficiaryEnrollment.dat HDL file from TFM staging records.
--
-- Beneficiary designation loads via the BeneficiaryEnrollment HDL business
-- object with its child component DesignateBeneficiary. ONE zip containing ONE
-- DAT file named for the business object: BeneficiaryEnrollment.dat.
--
-- OBJECT_TYPE = 'BeneficiaryEnrollment'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_BEN_BENFY_HDL_GEN_PKG;
/
