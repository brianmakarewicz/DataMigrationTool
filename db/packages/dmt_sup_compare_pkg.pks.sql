CREATE OR REPLACE PACKAGE DMT_SUP_COMPARE_PKG AS
    -- Post-run comparison for the five independent supplier-family objects
    -- (Suppliers, SupplierAddresses, SupplierSites, SupplierSiteAssignments,
    -- SupplierContacts). Each function returns one DMT_CMP_ROW_OBJ for the
    -- run, mirroring DMT_PO_COMPARE_PKG.GET_COMPARISON's shape: staged vs
    -- transform-errors vs live Fusion successes. Read-only; never queries
    -- Fusion by prefix -- keys off the run's LOAD ESS job id(s) from
    -- DMT_WORK_QUEUE_TBL (KEY_TYPE = 'LOAD_ID', per discovery run 132:
    -- docs/superpowers/specs/discovery/{Suppliers,SupplierAddresses,
    -- SupplierSites,SupplierSiteAssignments,SupplierContacts}.md).
    --
    -- All five objects are COUNT-ONLY: no money column exists anywhere in
    -- the family, so FUSION_MONEY_AVAILABLE is always 'N' and every *_AMOUNT
    -- column is NULL; balance is decided on count alone, mirroring the PO
    -- function's l_money_ok='N' branch.
    --
    -- STG has no RUN_ID for any of these five tables -- the run's record set
    -- is always the object's TFM rows for the run (STG is reached only
    -- through the TFM row's STG_SEQUENCE_ID pointer per object, never by
    -- business key or prefix).
    FUNCTION GET_SUPPLIERS_CMP(p_run_id IN NUMBER)      RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_SUP_ADDR_CMP(p_run_id IN NUMBER)       RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_SUP_SITES_CMP(p_run_id IN NUMBER)      RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_SUP_SITE_ASSN_CMP(p_run_id IN NUMBER)  RETURN DMT_CMP_ROW_OBJ;
    FUNCTION GET_SUP_CONTACTS_CMP(p_run_id IN NUMBER)   RETURN DMT_CMP_ROW_OBJ;
END DMT_SUP_COMPARE_PKG;
/
