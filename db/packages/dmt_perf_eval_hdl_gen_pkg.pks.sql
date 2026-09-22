-- PACKAGE DMT_PERF_EVAL_HDL_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_PERF_EVAL_HDL_GEN_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_PERF_EVAL_HDL_GEN_PKG
-- Generates the PerformanceDocument HDL DAT file from TFM staging records.
--
-- Fusion business object: PerformanceDocument (HDL discriminator PerfDocComplete),
-- with its ratings/comments child RatingsAndComments. This is the Oracle-documented
-- object for creating performance documents and loading section/overall ratings and
-- comments (Oracle Talent Management: "HCM Data Loader and Performance Document
-- Business Objects"; Oracle HCM: "Examples of Loading Performance Documents").
--
-- One HDL zip carries ONE DAT file (PerfDocComplete.dat) holding two business object
-- components: PerfDocComplete (the document) and RatingsAndComments (section + overall
-- ratings and comments). OBJECT_TYPE = 'PerfEvaluations'.
--
-- NOT GoalPlan: the prior version emitted GoalPlan / GoalPlanGoal (Goal Management),
-- which is a separate future object, not performance evaluations. Re-modelled to
-- PerformanceDocument 2026-09 (see PR "HCM re-model: PerfEvaluations -> PerformanceDocument").
-- ============================================================

    PROCEDURE GENERATE_HDL (
        p_run_id  IN  NUMBER,
        x_hdl_zip         OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_csv_id          OUT NUMBER
    );

END DMT_PERF_EVAL_HDL_GEN_PKG;
/
