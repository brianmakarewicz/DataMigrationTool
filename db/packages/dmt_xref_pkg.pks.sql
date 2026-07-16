-- PACKAGE DMT_XREF_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE "DMT_XREF_PKG"
AUTHID DEFINER
AS
-- ============================================================
-- DMT_XREF_PKG  -- shared cross-reference resolver
-- ============================================================
-- One resolver FUNCTION per referenceable upstream business KEY.
-- Every resolver has the IDENTICAL signature; only the name differs:
--
--     FUNCTION <key_name>(p_source_value IN VARCHAR2) RETURN VARCHAR2;
--
-- Purpose:
--   A transformer that carries an upstream object's keyed value into a
--   reference / child column must translate the source value into the
--   value that value actually has IN FUSION. If the referenced record was
--   migrated by this tool it now carries a run prefix (e.g. '10051' || key);
--   if it pre-existed in Fusion it is unchanged. These resolvers answer
--   "what is this key's value in Fusion?" for both cases, uniformly.
--
-- Behavior (identical for every resolver):
--   1. p_source_value IS NULL            -> RETURN NULL.
--   2. Find the MOST RECENT LOADED transformed row for that object whose
--      linked staging row's key column = p_source_value:
--        - join the object's STG table to its TFM table on STG_SEQUENCE_ID
--        - filter TFM_STATUS = 'LOADED'   (equality, never LIKE)
--        - NO scenario filter -- search all history
--        - order by RUN_ID DESC, tie-break TFM_SEQUENCE_ID DESC
--        - take the first row.
--   3. Found     -> RETURN the TFM row's value of that key column (the exact
--                   value loaded into Fusion -- already prefixed or not).
--   4. Not found -> RETURN p_source_value unchanged (never migrated by this
--                   tool => it pre-exists in Fusion under its original value).
--
-- Notes:
--   * Static SQL only (one SELECT ... FETCH FIRST 1 ROW ONLY per function).
--   * NOT marked DETERMINISTIC -- these functions read tables.
--   * NULL-safe by contract (step 1).
--   * The STG column is matched on; the TFM column of the same name is
--     returned. Where a TFM key column name differs from the STG name it is
--     handled inside that resolver (match STG col, return TFM col).
--
-- Standard (DMT_DESIGN.html section 7): any transformer carrying an upstream
-- object's keyed value into a reference / child column MUST resolve it via
-- DMT_XREF_PKG.<key>(). This supersedes manual PREFIXED() /
-- get_upstream_prefix() / get_dep_prefix() on cross-object references.
-- ============================================================

    -- ---- Projects -------------------------------------------
    FUNCTION PROJECT_NUMBER            (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION PROJECT_NAME              (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Project Tasks --------------------------------------
    FUNCTION TASK_NUMBER               (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Contracts (purchasing) -----------------------------
    FUNCTION CONTRACT_NUMBER           (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Purchase Orders ------------------------------------
    FUNCTION PO_NUMBER                 (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Requisitions ---------------------------------------
    FUNCTION REQUISITION_NUMBER        (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Suppliers ------------------------------------------
    FUNCTION SUPPLIER_NAME             (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION SUPPLIER_NUMBER           (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION SUPPLIER_SITE             (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Customers ------------------------------------------
    FUNCTION PARTY_NUMBER              (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION CUSTOMER_ACCOUNT_NUMBER   (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- AP Invoices ----------------------------------------
    FUNCTION INVOICE_NUMBER            (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- AR Invoices ----------------------------------------
    FUNCTION TRANSACTION_NUMBER        (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Items ----------------------------------------------
    FUNCTION ITEM_NUMBER               (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Assets ---------------------------------------------
    FUNCTION ASSET_NUMBER              (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Grants ---------------------------------------------
    FUNCTION AWARD_NUMBER              (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- GL Journals ----------------------------------------
    FUNCTION GL_JOURNAL_REFERENCE      (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- GL Budgets -----------------------------------------
    FUNCTION BUDGET_NAME               (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Workers / HCM persons ------------------------------
    FUNCTION PERSON_NUMBER             (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Payment Terms --------------------------------------
    FUNCTION PAYMENT_TERM_NAME         (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Units of Measure -----------------------------------
    FUNCTION UOM_CODE                  (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- GL Calendar ----------------------------------------
    FUNCTION PERIOD_SET_NAME           (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Lookups --------------------------------------------
    FUNCTION LOOKUP_TYPE               (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Value Sets -----------------------------------------
    FUNCTION VALUE_SET_CODE            (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Tax Config -----------------------------------------
    FUNCTION TAX_REGIME_CODE           (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION TAX_RATE_CODE             (p_source_value IN VARCHAR2) RETURN VARCHAR2;
    -- ---- Banks ----------------------------------------------
    FUNCTION BANK_NAME                 (p_source_value IN VARCHAR2) RETURN VARCHAR2;

END DMT_XREF_PKG;
/
