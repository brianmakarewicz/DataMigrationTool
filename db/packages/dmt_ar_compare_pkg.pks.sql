CREATE OR REPLACE PACKAGE DMT_AR_COMPARE_PKG AS
    -- Post-run comparison for AR Invoices (invoice LINE grain, AutoInvoice).
    -- Returns one DMT_CMP_ROW_OBJ for the run: staged vs transform-errors vs
    -- live Fusion successes. Read-only; never queries Fusion by prefix.
    --
    -- Scoping (docs/superpowers/specs/discovery/ARInvoices.md, proven on run
    -- 132): grain is the invoice LINE (DMT_RA_LINES_TFM_TBL). STG has no
    -- RUN_ID, so the run's record set is the TFM line rows for the run.
    -- Money = the line AMOUNT (AR invoices are monetary; summed at line
    -- grain, per the discovery doc's rationale).
    --
    -- Key path: the import/load ESS request id list this run submitted for
    -- ARInvoices (DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID / LOAD_ESS_JOB_ID) --
    -- NEVER the prefix, even though a committed recon DM elsewhere
    -- (bip/ARInvoices/DMT_AR_RECON_DM.xdm) filters base lines with
    -- interface_line_attribute1 LIKE :P_PREFIX || '%'. The discovery doc
    -- explicitly flags that prefix filter as wrong (INTERFACE_LINE_ATTRIBUTE1
    -- round-trips UNPREFIXED live, so a prefix LIKE filter would silently
    -- miss every real row); this package does not replicate that mistake.
    -- The BIP report here filters RA_CUSTOMER_TRX_LINES_ALL/RA_CUSTOMER_TRX_ALL
    -- by the header REQUEST_ID list (the AutoInvoice job's own request id(s)),
    -- which is the production-valid key path used by every other object in
    -- this family. AR Invoices can be loaded under more than one ESS request
    -- id per run (BU + batch-source grouping splits one FBDI into several
    -- loads), so the batch list carries every id, not just one.
    --
    -- Run 132 is env-blocked (AutoInvoice job-level abort, 0 rows loaded to
    -- base); the Fusion side honestly returns 0 successes and the object
    -- still balances on count (0 + 3 FAILED = 3 STG).
    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
END DMT_AR_COMPARE_PKG;
/
