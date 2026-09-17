-- PACKAGE DMT_BEN_DEPEND_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_BEN_DEPEND_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_BEN_DEPEND_HDL_GEN_PKG
-- Generates the DependentEnrollment.dat HDL file from TFM staging records.
--
-- Dependent benefit enrollment loads through the HCM Data Loader as the
-- DependentEnrollment business object (NOT PersonBenefitBalance). The single
-- zip contains ONE DAT file (DependentEnrollment.dat) with two components of
-- that one business object:
--   * DependentEnrollment  (parent) — participant benefit-relationship context.
--   * DesignateDependent   (child)  — one row per designated dependent.
-- Both components are source-keyed (SourceSystemOwner/SourceSystemId); the
-- participant is referenced by SourceSystemId, never repeated as a worker record.
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
