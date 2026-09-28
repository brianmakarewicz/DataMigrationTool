CREATE OR REPLACE PACKAGE DMT_PO_COMPARE_PKG AS
    -- Post-run comparison for Purchase Orders (STANDARD only). Returns one
    -- DMT_CMP_ROW_OBJ for the run: staged vs transform-errors vs live Fusion
    -- successes. Read-only; never queries Fusion by prefix — keys off the
    -- run's import ESS request id(s) from DMT_WORK_QUEUE_TBL.
    --
    -- Scoping (docs/superpowers/specs/discovery/PurchaseOrders.md, proven on
    -- run 132): DMT_PO_HEADERS_INT_TFM_TBL is shared by three objects split on
    -- DOCUMENT_TYPE_CODE (PurchaseOrders=STANDARD, BlanketPOs=BLANKET,
    -- Contracts=CONTRACT). Every query here filters
    -- NVL(DOCUMENT_TYPE_CODE,'STANDARD') = 'STANDARD' so BlanketPOs/Contracts
    -- lines never inflate the PurchaseOrders money. Money is on the lines
    -- (STANDARD lines carry QUANTITY*UNIT_PRICE; AMOUNT is null on STANDARD).
    FUNCTION GET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;

    -- BlanketPOs (BPA) — same shared tables, DOCUMENT_TYPE_CODE = 'BLANKET'.
    -- Money is sourced DMT-side only: the TFM line AMOUNT (per discovery,
    -- docs/superpowers/specs/discovery/BlanketPOs.md) does not round-trip to
    -- a populated Fusion column for a quantity-based blanket line, so
    -- FUSION_SUCCESS_AMOUNT is always NULL, FUSION_MONEY_AVAILABLE='N', and
    -- balance is decided on count only (no money variance computed).
    FUNCTION GET_BLANKET_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;

    -- Contracts (CPA) — same shared header table, DOCUMENT_TYPE_CODE =
    -- 'CONTRACT'. Header-only document, no money column anywhere in the DMT
    -- pipeline and no Fusion base amount column populated for this document
    -- type (per discovery, docs/superpowers/specs/discovery/Contracts.md).
    -- Count-only: FUSION_MONEY_AVAILABLE='N', all *_AMOUNT NULL, balance on
    -- count.
    FUNCTION GET_CONTRACT_COMPARISON(p_run_id IN NUMBER) RETURN DMT_CMP_ROW_OBJ;
END DMT_PO_COMPARE_PKG;
/
