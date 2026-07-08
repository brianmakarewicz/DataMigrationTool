-- PACKAGE DMT_TALENT_PROF_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_TALENT_PROF_HDL_GEN_PKG" 
AUTHID DEFINER
AS
-- ============================================================
-- DMT_TALENT_PROF_HDL_GEN_PKG
-- Generates the TalentProfile.dat HDL file from TFM staging records.
--
-- TalentProfile HDL is ONE zip containing ONE DAT file with 2 business object(s):
--   TalentProfile, ProfileItem.
--
-- OBJECT_TYPE = 'TalentProfiles'.
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_TALENT_PROF_HDL_GEN_PKG;
/
