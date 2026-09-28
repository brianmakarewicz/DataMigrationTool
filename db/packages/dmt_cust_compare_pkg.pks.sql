CREATE OR REPLACE PACKAGE DMT_CUST_COMPARE_PKG AS
    -- Post-run comparison for Customers (Accounts record type, account grain).
    -- Returns one DMT_CMP_ROW_OBJ for the run: staged vs transform-errors vs
    -- live Fusion successes. Count-only -- Customers.Accounts carries no
    -- monetary value.
    --
    -- Scoping (docs/superpowers/specs/discovery/Customers.md, proven on run
    -- 132): grain is the customer ACCOUNT (DMT_HZ_ACCOUNTS_TFM_TBL). STG has
    -- no RUN_ID, so the run's record set is the TFM rows for the run.
    --
    -- Key path (CRITICAL -- do NOT replace with a prefix wildcard filter):
    -- each LOADED TFM row's per-record CUST_ORIG_SYSTEM_REFERENCE (already
    -- run-prefixed by the transform) is matched, one row at a time, against
    -- HZ_ORIG_SYS_REFERENCES.ORIG_SYSTEM_REFERENCE for OWNER_TABLE_NAME =
    -- 'HZ_CUST_ACCOUNTS'. This is a per-record business-key join, not a LIKE
    -- '<prefix>%' scan of the whole base table -- a prefix scan is not a
    -- production-valid key (see docs/superpowers/specs/discovery/
    -- QUERY_MATRIX.md, "Key paths seen" -- prefix is explicitly forbidden).
    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
END DMT_CUST_COMPARE_PKG;
/
