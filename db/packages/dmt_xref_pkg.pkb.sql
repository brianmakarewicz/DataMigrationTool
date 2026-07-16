-- PACKAGE BODY DMT_XREF_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_XREF_PKG" AS
-- ============================================================
-- DMT_XREF_PKG Body -- cross-reference resolvers.
--
-- Every resolver is the SAME shape (see the spec for the full contract):
--   NULL in -> NULL out; else the most-recent LOADED transformed value for
--   the key across all history (RUN_ID DESC, TFM_SEQUENCE_ID DESC); else the
--   source value unchanged. One static SELECT ... FETCH FIRST 1 ROW ONLY per
--   function. Grouped by upstream object below.
-- ============================================================

    -- ========================================================
    -- Projects  (DMT_PJF_PROJECTS_*  -- key PROJECT_NUMBER / PROJECT_NAME)
    -- ========================================================
    FUNCTION PROJECT_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.PROJECT_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL s
        JOIN   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.PROJECT_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END PROJECT_NUMBER;

    FUNCTION PROJECT_NAME (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.PROJECT_NAME
        INTO   l_value
        FROM   DMT_OWNER.DMT_PJF_PROJECTS_STG_TBL s
        JOIN   DMT_OWNER.DMT_PJF_PROJECTS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.PROJECT_NAME = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END PROJECT_NAME;

    -- ========================================================
    -- Project Tasks  (DMT_PJF_TASKS_*  -- key TASK_NUMBER)
    -- ========================================================
    FUNCTION TASK_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.TASK_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_PJF_TASKS_STG_TBL s
        JOIN   DMT_OWNER.DMT_PJF_TASKS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.TASK_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END TASK_NUMBER;

    -- ========================================================
    -- Contracts (purchasing)  -- Contracts share the PO header table
    --   (DMT_PO_HEADERS_INT_*) keyed on DOCUMENT_NUM, filtered to the
    --   Contract Purchase Agreement style. Sales contracts referenced by
    --   BillingEvents/Expenditures are NOT migrated by this tool, so they
    --   fall through unchanged -- which is correct (they pre-exist).
    -- ========================================================
    FUNCTION CONTRACT_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.DOCUMENT_NUM
        INTO   l_value
        FROM   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL s
        JOIN   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.DOCUMENT_NUM = p_source_value
        AND    t.STYLE_DISPLAY_NAME = 'Contract Purchase Agreement'
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END CONTRACT_NUMBER;

    -- ========================================================
    -- Purchase Orders  (DMT_PO_HEADERS_INT_*  -- key DOCUMENT_NUM,
    --   filtered to the Purchase Order style)
    -- ========================================================
    FUNCTION PO_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.DOCUMENT_NUM
        INTO   l_value
        FROM   DMT_OWNER.DMT_PO_HEADERS_INT_STG_TBL s
        JOIN   DMT_OWNER.DMT_PO_HEADERS_INT_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.DOCUMENT_NUM = p_source_value
        AND    t.STYLE_DISPLAY_NAME = 'Purchase Order'
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END PO_NUMBER;

    -- ========================================================
    -- Requisitions  (DMT_POR_REQ_HEADERS_*  -- key REQUISITION_NUMBER)
    -- ========================================================
    FUNCTION REQUISITION_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.REQUISITION_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_POR_REQ_HEADERS_STG_TBL s
        JOIN   DMT_OWNER.DMT_POR_REQ_HEADERS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.REQUISITION_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END REQUISITION_NUMBER;

    -- ========================================================
    -- Suppliers  (Suppliers referenced three ways)
    --   name   -> DMT_POZ_SUPPLIERS_*.VENDOR_NAME
    --   number -> DMT_POZ_SUPPLIERS_*.SEGMENT1
    --   site   -> DMT_POZ_SUP_SITE_*.VENDOR_SITE_CODE (SupplierSites object)
    -- ========================================================
    FUNCTION SUPPLIER_NAME (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.VENDOR_NAME
        INTO   l_value
        FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
        JOIN   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.VENDOR_NAME = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END SUPPLIER_NAME;

    FUNCTION SUPPLIER_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.SEGMENT1
        INTO   l_value
        FROM   DMT_OWNER.DMT_POZ_SUPPLIERS_STG_TBL s
        JOIN   DMT_OWNER.DMT_POZ_SUPPLIERS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.SEGMENT1 = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END SUPPLIER_NUMBER;

    FUNCTION SUPPLIER_SITE (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.VENDOR_SITE_CODE
        INTO   l_value
        FROM   DMT_OWNER.DMT_POZ_SUP_SITE_STG_TBL s
        JOIN   DMT_OWNER.DMT_POZ_SUP_SITE_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.VENDOR_SITE_CODE = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END SUPPLIER_SITE;

    -- ========================================================
    -- Customers
    --   party   -> DMT_HZ_PARTIES_*.PARTY_NUMBER
    --   account -> DMT_HZ_ACCOUNTS_*.ACCOUNT_NUMBER
    -- ========================================================
    FUNCTION PARTY_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.PARTY_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_HZ_PARTIES_STG_TBL s
        JOIN   DMT_OWNER.DMT_HZ_PARTIES_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.PARTY_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END PARTY_NUMBER;

    FUNCTION CUSTOMER_ACCOUNT_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.ACCOUNT_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_HZ_ACCOUNTS_STG_TBL s
        JOIN   DMT_OWNER.DMT_HZ_ACCOUNTS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.ACCOUNT_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END CUSTOMER_ACCOUNT_NUMBER;

    -- ========================================================
    -- AP Invoices  (DMT_AP_INVOICES_INT_*  -- key INVOICE_NUM)
    -- ========================================================
    FUNCTION INVOICE_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.INVOICE_NUM
        INTO   l_value
        FROM   DMT_OWNER.DMT_AP_INVOICES_INT_STG_TBL s
        JOIN   DMT_OWNER.DMT_AP_INVOICES_INT_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.INVOICE_NUM = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END INVOICE_NUMBER;

    -- ========================================================
    -- AR Invoices  (DMT_RA_LINES_*  -- key TRX_NUMBER)
    -- ========================================================
    FUNCTION TRANSACTION_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.TRX_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_RA_LINES_STG_TBL s
        JOIN   DMT_OWNER.DMT_RA_LINES_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.TRX_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END TRANSACTION_NUMBER;

    -- ========================================================
    -- Items  (DMT_EGP_ITEM_*  -- key ITEM_NUMBER)
    -- ========================================================
    FUNCTION ITEM_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.ITEM_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_EGP_ITEM_STG_TBL s
        JOIN   DMT_OWNER.DMT_EGP_ITEM_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.ITEM_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END ITEM_NUMBER;

    -- ========================================================
    -- Assets  (DMT_FA_ASSET_HDR_*  -- key ASSET_NUMBER)
    -- ========================================================
    FUNCTION ASSET_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.ASSET_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_FA_ASSET_HDR_STG_TBL s
        JOIN   DMT_OWNER.DMT_FA_ASSET_HDR_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.ASSET_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END ASSET_NUMBER;

    -- ========================================================
    -- Grants  (DMT_GMS_AWD_HEADERS_*  -- key AWARD_NUMBER)
    -- ========================================================
    FUNCTION AWARD_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.AWARD_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_GMS_AWD_HEADERS_STG_TBL s
        JOIN   DMT_OWNER.DMT_GMS_AWD_HEADERS_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.AWARD_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END AWARD_NUMBER;

    -- ========================================================
    -- GL Journals  (DMT_GL_INTERFACE_*  -- business key REFERENCE1)
    -- ========================================================
    FUNCTION GL_JOURNAL_REFERENCE (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.REFERENCE1
        INTO   l_value
        FROM   DMT_OWNER.DMT_GL_INTERFACE_STG_TBL s
        JOIN   DMT_OWNER.DMT_GL_INTERFACE_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.REFERENCE1 = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END GL_JOURNAL_REFERENCE;

    -- ========================================================
    -- GL Budgets  (DMT_GL_BUDGET_INT_*  -- key BUDGET_NAME)
    -- ========================================================
    FUNCTION BUDGET_NAME (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.BUDGET_NAME
        INTO   l_value
        FROM   DMT_OWNER.DMT_GL_BUDGET_INT_STG_TBL s
        JOIN   DMT_OWNER.DMT_GL_BUDGET_INT_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.BUDGET_NAME = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END BUDGET_NAME;

    -- ========================================================
    -- Workers / HCM persons  (DMT_WORKER_*  -- key PERSON_NUMBER).
    --   Workers is the source of truth for a person number; every HCM child
    --   object (Assignments, Salaries, Absences, ...) references it.
    -- ========================================================
    FUNCTION PERSON_NUMBER (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.PERSON_NUMBER
        INTO   l_value
        FROM   DMT_OWNER.DMT_WORKER_STG_TBL s
        JOIN   DMT_OWNER.DMT_WORKER_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.PERSON_NUMBER = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END PERSON_NUMBER;

    -- ========================================================
    -- Payment Terms  (DMT_AP_PAY_TERM_HDR_*  -- key NAME)
    -- ========================================================
    FUNCTION PAYMENT_TERM_NAME (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.NAME
        INTO   l_value
        FROM   DMT_OWNER.DMT_AP_PAY_TERM_HDR_STG_TBL s
        JOIN   DMT_OWNER.DMT_AP_PAY_TERM_HDR_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.NAME = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END PAYMENT_TERM_NAME;

    -- ========================================================
    -- Units of Measure  (DMT_INV_UOM_*  -- key UOM_CODE)
    -- ========================================================
    FUNCTION UOM_CODE (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.UOM_CODE
        INTO   l_value
        FROM   DMT_OWNER.DMT_INV_UOM_STG_TBL s
        JOIN   DMT_OWNER.DMT_INV_UOM_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.UOM_CODE = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END UOM_CODE;

    -- ========================================================
    -- GL Calendar  (DMT_GL_CALENDAR_*  -- key PERIOD_SET_NAME)
    -- ========================================================
    FUNCTION PERIOD_SET_NAME (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.PERIOD_SET_NAME
        INTO   l_value
        FROM   DMT_OWNER.DMT_GL_CALENDAR_STG_TBL s
        JOIN   DMT_OWNER.DMT_GL_CALENDAR_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.PERIOD_SET_NAME = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END PERIOD_SET_NAME;

    -- ========================================================
    -- Lookups  (DMT_FND_LOOKUP_TYPE_*  -- key LOOKUP_TYPE)
    -- ========================================================
    FUNCTION LOOKUP_TYPE (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.LOOKUP_TYPE
        INTO   l_value
        FROM   DMT_OWNER.DMT_FND_LOOKUP_TYPE_STG_TBL s
        JOIN   DMT_OWNER.DMT_FND_LOOKUP_TYPE_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.LOOKUP_TYPE = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END LOOKUP_TYPE;

    -- ========================================================
    -- Value Sets  (DMT_FND_VS_SET_*  -- key VALUE_SET_CODE)
    -- ========================================================
    FUNCTION VALUE_SET_CODE (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.VALUE_SET_CODE
        INTO   l_value
        FROM   DMT_OWNER.DMT_FND_VS_SET_STG_TBL s
        JOIN   DMT_OWNER.DMT_FND_VS_SET_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.VALUE_SET_CODE = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END VALUE_SET_CODE;

    -- ========================================================
    -- Tax Config
    --   regime -> DMT_ZX_REGIME_*.TAX_REGIME_CODE
    --   rate   -> DMT_ZX_RATE_*.TAX_RATE_CODE
    -- ========================================================
    FUNCTION TAX_REGIME_CODE (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.TAX_REGIME_CODE
        INTO   l_value
        FROM   DMT_OWNER.DMT_ZX_REGIME_STG_TBL s
        JOIN   DMT_OWNER.DMT_ZX_REGIME_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.TAX_REGIME_CODE = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END TAX_REGIME_CODE;

    FUNCTION TAX_RATE_CODE (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.TAX_RATE_CODE
        INTO   l_value
        FROM   DMT_OWNER.DMT_ZX_RATE_STG_TBL s
        JOIN   DMT_OWNER.DMT_ZX_RATE_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.TAX_RATE_CODE = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END TAX_RATE_CODE;

    -- ========================================================
    -- Banks  (DMT_CE_BANK_*  -- key BANK_NAME)
    -- ========================================================
    FUNCTION BANK_NAME (p_source_value IN VARCHAR2) RETURN VARCHAR2 IS
        l_value VARCHAR2(4000);
    BEGIN
        IF p_source_value IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT t.BANK_NAME
        INTO   l_value
        FROM   DMT_OWNER.DMT_CE_BANK_STG_TBL s
        JOIN   DMT_OWNER.DMT_CE_BANK_TFM_TBL t
               ON t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
        WHERE  s.BANK_NAME = p_source_value
        AND    t.TFM_STATUS = 'LOADED'
        ORDER BY t.RUN_ID DESC, t.TFM_SEQUENCE_ID DESC
        FETCH FIRST 1 ROW ONLY;
        RETURN l_value;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_source_value;
    END BANK_NAME;

END DMT_XREF_PKG;
/
