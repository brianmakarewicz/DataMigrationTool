CREATE OR REPLACE PACKAGE DMT_AP_COMPARE_PKG AS
    -- Post-run comparison for AP Invoices (header grain). Returns one
    -- DMT_CMP_ROW_OBJ for the run: staged vs transform-errors vs live Fusion
    -- successes. Read-only; never queries Fusion by prefix -- keys off the
    -- run's import ESS request id(s) from DMT_WORK_QUEUE_TBL.
    --
    -- Scoping (docs/superpowers/specs/discovery/APInvoices.md, proven on run
    -- 132): grain is the invoice HEADER (DMT_AP_INVOICES_INT_TFM_TBL carries
    -- RUN_ID, TFM_STATUS, FUSION_INVOICE_ID at header grain). STG has no
    -- RUN_ID/CEMLI column, so STG is scoped only by joining STG to TFM on
    -- STG_SEQUENCE_ID where TFM.RUN_ID = the run. Money = header
    -- INVOICE_AMOUNT (the only header-grain amount present and comparable
    -- across STG, TFM, and Fusion AP_INVOICES_ALL.INVOICE_AMOUNT). Fusion
    -- successes are keyed on the import ESS request id (never the prefix),
    -- which maps to AP_INVOICES_ALL.REQUEST_ID.
    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
END DMT_AP_COMPARE_PKG;
/
