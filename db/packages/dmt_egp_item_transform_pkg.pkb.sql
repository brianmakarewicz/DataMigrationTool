-- PACKAGE BODY DMT_EGP_ITEM_TRANSFORM_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_TRANSFORM_PKG" AS
-- ============================================================
-- DMT_EGP_ITEM_TRANSFORM_PKG Body
-- All ~130 business columns copied from STG to TFM.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_TRANSFORM_PKG';

    FUNCTION get_prefix (p_run_id IN NUMBER) RETURN VARCHAR2 IS
        l_prefix VARCHAR2(30);
    BEGIN
        SELECT PREFIX
        INTO   l_prefix
        FROM   DMT_OWNER.DMT_PIPELINE_RUN_TBL
        WHERE  RUN_ID = p_run_id;
        RETURN l_prefix;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'RUN_ID ' || p_run_id || ' not found in DMT_PIPELINE_RUN_TBL');
    END get_prefix;

    PROCEDURE TRANSFORM (
        p_run_id   IN NUMBER,
        p_reprocess_errors IN BOOLEAN DEFAULT FALSE,
        p_scenario_id      IN NUMBER DEFAULT NULL,
        p_include_untagged IN VARCHAR2 DEFAULT 'N',
        p_run_mode         IN VARCHAR2 DEFAULT 'NEW'
    ) IS
        l_ok_count   NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_prefix     VARCHAR2(30);
    BEGIN
        l_prefix := get_prefix(p_run_id);
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM start.',
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

        IF p_reprocess_errors THEN
            UPDATE DMT_OWNER.DMT_EGP_ITEM_STG_TBL
            SET    ERROR_TEXT = NULL, LAST_UPDATED_DATE = SYSDATE
            WHERE  STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED');
        END IF;

        INSERT INTO DMT_OWNER.DMT_EGP_ITEM_TFM_TBL (
                    STG_SEQUENCE_ID,
                    RUN_ID,
                    -- Identity
                    TRANSACTION_TYPE,
                    BATCH_ID,
                    BATCH_NUMBER,
                    ORGANIZATION_CODE,
                    ITEM_NUMBER,
                    DESCRIPTION,
                    LONG_DESCRIPTION,
                    PRIMARY_UOM_CODE,
                    SECONDARY_UOM_CODE,
                    ITEM_TYPE,
                    ITEM_CLASS_NAME,
                    INVENTORY_ITEM_STATUS_CODE,
                    STYLE_ITEM_FLAG,
                    CURRENT_PHASE_CODE,
                    -- Source System
                    SOURCE_SYSTEM_CODE,
                    SOURCE_SYSTEM_REFERENCE,
                    TEMPLATE_NAME,
                    -- Physical
                    UNIT_WEIGHT,
                    WEIGHT_UOM_CODE,
                    UNIT_VOLUME,
                    VOLUME_UOM_CODE,
                    DIMENSION_UOM_CODE,
                    UNIT_LENGTH,
                    UNIT_WIDTH,
                    UNIT_HEIGHT,
                    -- Purchasing
                    PURCHASING_ITEM_FLAG,
                    PURCHASING_ENABLED_FLAG,
                    MUST_USE_APPROVED_VENDOR_FLAG,
                    ALLOW_ITEM_DESC_UPDATE_FLAG,
                    QTY_RCV_TOLERANCE,
                    QTY_RCV_EXCEPTION_CODE,
                    RECEIPT_DAYS_EXCEPTION_CODE,
                    RECEIVING_ROUTING_ID,
                    ENFORCE_SHIP_TO_LOCATION_CODE,
                    INVOICE_CLOSE_TOLERANCE,
                    RECEIVE_CLOSE_TOLERANCE,
                    PRICE_TOLERANCE_PERCENT,
                    MATCH_APPROVAL_LEVEL,
                    INVOICE_MATCH_OPTION,
                    PURCHASING_TAX_CODE,
                    OUTSIDE_OPERATION_FLAG,
                    ALLOW_SUBSTITUTE_RECEIPTS_FLAG,
                    ALLOW_UNORDERED_RECEIPTS_FLAG,
                    DAYS_EARLY_RECEIPT_ALLOWED,
                    DAYS_LATE_RECEIPT_ALLOWED,
                    -- Inventory
                    INVENTORY_ITEM_FLAG,
                    INVENTORY_ASSET_FLAG,
                    MTL_TRANSACTIONS_ENABLED_FLAG,
                    STOCK_ENABLED_FLAG,
                    RESERVABLE_TYPE,
                    LOT_CONTROL_CODE,
                    SERIAL_NUMBER_CONTROL_CODE,
                    SHELF_LIFE_CODE,
                    SHELF_LIFE_DAYS,
                    REVISION_QTY_CONTROL_CODE,
                    LOCATION_CONTROL_CODE,
                    RESTRICT_SUBINVENTORIES_CODE,
                    RESTRICT_LOCATORS_CODE,
                    CHECK_SHORTAGES_FLAG,
                    CYCLE_COUNT_ENABLED_FLAG,
                    INDIVISIBLE_FLAG,
                    GRADE_CONTROL_FLAG,
                    LOT_DIVISIBLE_FLAG,
                    CHILD_LOT_FLAG,
                    DUAL_UOM_CONTROL,
                    DUAL_UOM_DEVIATION_HIGH,
                    DUAL_UOM_DEVIATION_LOW,
                    -- Order Management
                    CUSTOMER_ORDER_FLAG,
                    CUSTOMER_ORDER_ENABLED_FLAG,
                    INTERNAL_ORDER_FLAG,
                    INTERNAL_ORDER_ENABLED_FLAG,
                    SHIPPABLE_ITEM_FLAG,
                    RETURNABLE_FLAG,
                    DEFAULT_SHIPPING_ORG,
                    OVER_SHIPMENT_TOLERANCE,
                    UNDER_SHIPMENT_TOLERANCE,
                    OVER_RETURN_TOLERANCE,
                    UNDER_RETURN_TOLERANCE,
                    BACK_ORDERABLE_FLAG,
                    -- Planning
                    MRP_PLANNING_CODE,
                    PLANNING_MAKE_BUY_CODE,
                    INVENTORY_PLANNING_CODE,
                    PLANNER_CODE,
                    MIN_MINMAX_QUANTITY,
                    MAX_MINMAX_QUANTITY,
                    MINIMUM_ORDER_QUANTITY,
                    MAXIMUM_ORDER_QUANTITY,
                    FIXED_ORDER_QUANTITY,
                    FIXED_LOT_MULTIPLIER,
                    FIXED_DAYS_SUPPLY,
                    SAFETY_STOCK_BUCKET_DAYS,
                    SHRINKAGE_RATE,
                    -- Lead Times
                    FULL_LEAD_TIME,
                    FIXED_LEAD_TIME,
                    VARIABLE_LEAD_TIME,
                    PREPROCESSING_LEAD_TIME,
                    POSTPROCESSING_LEAD_TIME,
                    CUM_MANUFACTURING_LEAD_TIME,
                    CUMULATIVE_TOTAL_LEAD_TIME,
                    LEAD_TIME_LOT_SIZE,
                    -- Costing
                    COSTING_ENABLED_FLAG,
                    LIST_PRICE_PER_UNIT,
                    MARKET_PRICE,
                    -- Billing
                    INVOICEABLE_ITEM_FLAG,
                    INVOICE_ENABLED_FLAG,
                    ACCOUNTING_RULE_NAME,
                    INVOICING_RULE_NAME,
                    PAYMENT_TERMS_NAME,
                    TAX_CODE,
                    -- WIP
                    BUILD_IN_WIP_FLAG,
                    WIP_SUPPLY_TYPE,
                    WIP_SUPPLY_SUBINVENTORY,
                    -- Service
                    SERVICEABLE_PRODUCT_FLAG,
                    CONTRACT_ITEM_TYPE_CODE,
                    SERVICE_DURATION,
                    SERVICE_DURATION_PERIOD_CODE,
                    -- Buyer / Hazard / ATP
                    BUYER_NAME,
                    HAZARD_CLASS_CODE,
                    UN_NUMBER_CODE,
                    ATP_FLAG,
                    PICKING_RULE_NAME,
                    -- Accounts
                    SALES_ACCOUNT,
                    EXPENSE_ACCOUNT,
                    ASSET_CATEGORY_ID,
                    -- Flexfields
                    ATTRIBUTE_CATEGORY,
                    ATTRIBUTE1,
                    ATTRIBUTE2,
                    ATTRIBUTE3,
                    ATTRIBUTE4,
                    ATTRIBUTE5,
                    ATTRIBUTE6,
                    ATTRIBUTE7,
                    ATTRIBUTE8,
                    ATTRIBUTE9,
                    ATTRIBUTE10,
                    ATTRIBUTE11,
                    ATTRIBUTE12,
                    ATTRIBUTE13,
                    ATTRIBUTE14,
                    ATTRIBUTE15,
                    ATTRIBUTE_NUMBER1,
                    ATTRIBUTE_NUMBER2,
                    ATTRIBUTE_NUMBER3,
                    ATTRIBUTE_NUMBER4,
                    ATTRIBUTE_NUMBER5,
                    ATTRIBUTE_DATE1,
                    ATTRIBUTE_DATE2,
                    ATTRIBUTE_DATE3,
                    ATTRIBUTE_DATE4,
                    ATTRIBUTE_DATE5,
                    GLOBAL_ATTRIBUTE_CATEGORY,
                    GLOBAL_ATTRIBUTE1,
                    GLOBAL_ATTRIBUTE2,
                    GLOBAL_ATTRIBUTE3,
                    GLOBAL_ATTRIBUTE4,
                    GLOBAL_ATTRIBUTE5,
                    GLOBAL_ATTRIBUTE6,
                    GLOBAL_ATTRIBUTE7,
                    GLOBAL_ATTRIBUTE8,
                    GLOBAL_ATTRIBUTE9,
                    GLOBAL_ATTRIBUTE10,
                    GLOBAL_ATTRIBUTE11,
                    GLOBAL_ATTRIBUTE12,
                    GLOBAL_ATTRIBUTE13,
                    GLOBAL_ATTRIBUTE14,
                    GLOBAL_ATTRIBUTE15,
                    GLOBAL_ATTRIBUTE16,
                    GLOBAL_ATTRIBUTE17,
                    GLOBAL_ATTRIBUTE18,
                    GLOBAL_ATTRIBUTE19,
                    GLOBAL_ATTRIBUTE20,
                    -- Pipeline columns
                    TFM_STATUS,
                    LAST_UPDATED_DATE
        )
        SELECT
                    s.STG_SEQUENCE_ID,
                    p_run_id,
                    -- Identity
                    s.TRANSACTION_TYPE,
                    NVL(s.BATCH_ID, DMT_LOADER_PKG.g_work_queue_id),  -- work-queue-ID core: user's BATCH_ID (ESS arg1 + partition key); work-queue-item id as fallback (never the prefix)
                    s.BATCH_NUMBER,
                    s.ORGANIZATION_CODE,
                    DMT_UTIL_PKG.PREFIXED(l_prefix, s.ITEM_NUMBER),
                    s.DESCRIPTION,
                    s.LONG_DESCRIPTION,
                    s.PRIMARY_UOM_CODE,
                    s.SECONDARY_UOM_CODE,
                    s.ITEM_TYPE,
                    s.ITEM_CLASS_NAME,
                    s.INVENTORY_ITEM_STATUS_CODE,
                    s.STYLE_ITEM_FLAG,
                    s.CURRENT_PHASE_CODE,
                    -- Source System
                    s.SOURCE_SYSTEM_CODE,
                    s.SOURCE_SYSTEM_REFERENCE,
                    s.TEMPLATE_NAME,
                    -- Physical
                    s.UNIT_WEIGHT,
                    s.WEIGHT_UOM_CODE,
                    s.UNIT_VOLUME,
                    s.VOLUME_UOM_CODE,
                    s.DIMENSION_UOM_CODE,
                    s.UNIT_LENGTH,
                    s.UNIT_WIDTH,
                    s.UNIT_HEIGHT,
                    -- Purchasing
                    s.PURCHASING_ITEM_FLAG,
                    s.PURCHASING_ENABLED_FLAG,
                    s.MUST_USE_APPROVED_VENDOR_FLAG,
                    s.ALLOW_ITEM_DESC_UPDATE_FLAG,
                    s.QTY_RCV_TOLERANCE,
                    s.QTY_RCV_EXCEPTION_CODE,
                    s.RECEIPT_DAYS_EXCEPTION_CODE,
                    s.RECEIVING_ROUTING_ID,
                    s.ENFORCE_SHIP_TO_LOCATION_CODE,
                    s.INVOICE_CLOSE_TOLERANCE,
                    s.RECEIVE_CLOSE_TOLERANCE,
                    s.PRICE_TOLERANCE_PERCENT,
                    s.MATCH_APPROVAL_LEVEL,
                    s.INVOICE_MATCH_OPTION,
                    s.PURCHASING_TAX_CODE,
                    s.OUTSIDE_OPERATION_FLAG,
                    s.ALLOW_SUBSTITUTE_RECEIPTS_FLAG,
                    s.ALLOW_UNORDERED_RECEIPTS_FLAG,
                    s.DAYS_EARLY_RECEIPT_ALLOWED,
                    s.DAYS_LATE_RECEIPT_ALLOWED,
                    -- Inventory
                    s.INVENTORY_ITEM_FLAG,
                    s.INVENTORY_ASSET_FLAG,
                    s.MTL_TRANSACTIONS_ENABLED_FLAG,
                    s.STOCK_ENABLED_FLAG,
                    s.RESERVABLE_TYPE,
                    s.LOT_CONTROL_CODE,
                    s.SERIAL_NUMBER_CONTROL_CODE,
                    s.SHELF_LIFE_CODE,
                    s.SHELF_LIFE_DAYS,
                    s.REVISION_QTY_CONTROL_CODE,
                    s.LOCATION_CONTROL_CODE,
                    s.RESTRICT_SUBINVENTORIES_CODE,
                    s.RESTRICT_LOCATORS_CODE,
                    s.CHECK_SHORTAGES_FLAG,
                    s.CYCLE_COUNT_ENABLED_FLAG,
                    s.INDIVISIBLE_FLAG,
                    s.GRADE_CONTROL_FLAG,
                    s.LOT_DIVISIBLE_FLAG,
                    s.CHILD_LOT_FLAG,
                    s.DUAL_UOM_CONTROL,
                    s.DUAL_UOM_DEVIATION_HIGH,
                    s.DUAL_UOM_DEVIATION_LOW,
                    -- Order Management
                    s.CUSTOMER_ORDER_FLAG,
                    s.CUSTOMER_ORDER_ENABLED_FLAG,
                    s.INTERNAL_ORDER_FLAG,
                    s.INTERNAL_ORDER_ENABLED_FLAG,
                    s.SHIPPABLE_ITEM_FLAG,
                    s.RETURNABLE_FLAG,
                    s.DEFAULT_SHIPPING_ORG,
                    s.OVER_SHIPMENT_TOLERANCE,
                    s.UNDER_SHIPMENT_TOLERANCE,
                    s.OVER_RETURN_TOLERANCE,
                    s.UNDER_RETURN_TOLERANCE,
                    s.BACK_ORDERABLE_FLAG,
                    -- Planning
                    s.MRP_PLANNING_CODE,
                    s.PLANNING_MAKE_BUY_CODE,
                    s.INVENTORY_PLANNING_CODE,
                    s.PLANNER_CODE,
                    s.MIN_MINMAX_QUANTITY,
                    s.MAX_MINMAX_QUANTITY,
                    s.MINIMUM_ORDER_QUANTITY,
                    s.MAXIMUM_ORDER_QUANTITY,
                    s.FIXED_ORDER_QUANTITY,
                    s.FIXED_LOT_MULTIPLIER,
                    s.FIXED_DAYS_SUPPLY,
                    s.SAFETY_STOCK_BUCKET_DAYS,
                    s.SHRINKAGE_RATE,
                    -- Lead Times
                    s.FULL_LEAD_TIME,
                    s.FIXED_LEAD_TIME,
                    s.VARIABLE_LEAD_TIME,
                    s.PREPROCESSING_LEAD_TIME,
                    s.POSTPROCESSING_LEAD_TIME,
                    s.CUM_MANUFACTURING_LEAD_TIME,
                    s.CUMULATIVE_TOTAL_LEAD_TIME,
                    s.LEAD_TIME_LOT_SIZE,
                    -- Costing
                    s.COSTING_ENABLED_FLAG,
                    s.LIST_PRICE_PER_UNIT,
                    s.MARKET_PRICE,
                    -- Billing
                    s.INVOICEABLE_ITEM_FLAG,
                    s.INVOICE_ENABLED_FLAG,
                    s.ACCOUNTING_RULE_NAME,
                    s.INVOICING_RULE_NAME,
                    s.PAYMENT_TERMS_NAME,
                    s.TAX_CODE,
                    -- WIP
                    s.BUILD_IN_WIP_FLAG,
                    s.WIP_SUPPLY_TYPE,
                    s.WIP_SUPPLY_SUBINVENTORY,
                    -- Service
                    s.SERVICEABLE_PRODUCT_FLAG,
                    s.CONTRACT_ITEM_TYPE_CODE,
                    s.SERVICE_DURATION,
                    s.SERVICE_DURATION_PERIOD_CODE,
                    -- Buyer / Hazard / ATP
                    s.BUYER_NAME,
                    s.HAZARD_CLASS_CODE,
                    s.UN_NUMBER_CODE,
                    s.ATP_FLAG,
                    s.PICKING_RULE_NAME,
                    -- Accounts
                    s.SALES_ACCOUNT,
                    s.EXPENSE_ACCOUNT,
                    s.ASSET_CATEGORY_ID,
                    -- Flexfields
                    s.ATTRIBUTE_CATEGORY,
                    s.ATTRIBUTE1,
                    s.ATTRIBUTE2,
                    s.ATTRIBUTE3,
                    s.ATTRIBUTE4,
                    s.ATTRIBUTE5,
                    s.ATTRIBUTE6,
                    s.ATTRIBUTE7,
                    s.ATTRIBUTE8,
                    s.ATTRIBUTE9,
                    s.ATTRIBUTE10,
                    s.ATTRIBUTE11,
                    s.ATTRIBUTE12,
                    s.ATTRIBUTE13,
                    s.ATTRIBUTE14,
                    s.ATTRIBUTE15,
                    s.ATTRIBUTE_NUMBER1,
                    s.ATTRIBUTE_NUMBER2,
                    s.ATTRIBUTE_NUMBER3,
                    s.ATTRIBUTE_NUMBER4,
                    s.ATTRIBUTE_NUMBER5,
                    s.ATTRIBUTE_DATE1,
                    s.ATTRIBUTE_DATE2,
                    s.ATTRIBUTE_DATE3,
                    s.ATTRIBUTE_DATE4,
                    s.ATTRIBUTE_DATE5,
                    s.GLOBAL_ATTRIBUTE_CATEGORY,
                    s.GLOBAL_ATTRIBUTE1,
                    s.GLOBAL_ATTRIBUTE2,
                    s.GLOBAL_ATTRIBUTE3,
                    s.GLOBAL_ATTRIBUTE4,
                    s.GLOBAL_ATTRIBUTE5,
                    s.GLOBAL_ATTRIBUTE6,
                    s.GLOBAL_ATTRIBUTE7,
                    s.GLOBAL_ATTRIBUTE8,
                    s.GLOBAL_ATTRIBUTE9,
                    s.GLOBAL_ATTRIBUTE10,
                    s.GLOBAL_ATTRIBUTE11,
                    s.GLOBAL_ATTRIBUTE12,
                    s.GLOBAL_ATTRIBUTE13,
                    s.GLOBAL_ATTRIBUTE14,
                    s.GLOBAL_ATTRIBUTE15,
                    s.GLOBAL_ATTRIBUTE16,
                    s.GLOBAL_ATTRIBUTE17,
                    s.GLOBAL_ATTRIBUTE18,
                    s.GLOBAL_ATTRIBUTE19,
                    s.GLOBAL_ATTRIBUTE20,

                    'STAGED',
                    SYSDATE
        FROM DMT_OWNER.DMT_EGP_ITEM_STG_TBL s
        WHERE (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        -- Scenario scoping: only transform rows for the active scenario (and, when requested,
        -- untagged rows). Without this the run sweeps the entire staging table regardless of
        -- scenario — mirrors the predicate used by the supplier/customer transforms.
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND NOT EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_EGP_ITEM_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        l_ok_count := SQL%ROWCOUNT;

        UPDATE DMT_OWNER.DMT_EGP_ITEM_STG_TBL s
        SET    s.STG_STATUS            = 'TRANSFORMED',
               s.LAST_UPDATED_DATE = SYSDATE
        WHERE  (
            (p_run_mode = 'NEW' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_run_mode = 'FAILED' AND s.STG_STATUS = 'FAILED')
            OR (p_run_mode = 'ALL' AND s.STG_STATUS IN ('NEW', 'RETRY'))
            OR (p_reprocess_errors AND s.STG_STATUS IN ('FAILED', 'TRANSFORM_FAILED'))
          )
        AND (p_scenario_id IS NULL
             OR s.SCENARIO_ID = p_scenario_id
             OR (p_include_untagged = 'Y' AND s.SCENARIO_ID IS NULL))
        AND    EXISTS (
            SELECT 1 FROM DMT_OWNER.DMT_EGP_ITEM_TFM_TBL t
            WHERE  t.STG_SEQUENCE_ID = s.STG_SEQUENCE_ID
            AND    t.RUN_ID  = p_run_id
        );

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'TRANSFORM complete. OK: ' || l_ok_count
                                || ', FAILED: ' || l_fail_count,
            p_package        => C_PKG,
            p_procedure      => 'TRANSFORM');

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'TRANSFORM');
            RAISE;
    END TRANSFORM;

END DMT_EGP_ITEM_TRANSFORM_PKG;
/
