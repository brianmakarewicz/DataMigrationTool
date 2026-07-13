-- PACKAGE BODY DMT_EGP_ITEM_FBDI_GEN_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_EGP_ITEM_FBDI_GEN_PKG" AS
-- ============================================================
-- Items FBDI generator
-- Produces a single ZIP containing:
--   1. EgpSystemItemsInterface.csv  (items)
--   2. EgpItemCategoriesInterface.csv  (item categories, if any)
-- Both loaded by ItemImportJobDef in one ESS submission.
-- FBDI pattern: comma-delimited, no header row, quoted fields.
-- ============================================================

    C_PKG CONSTANT VARCHAR2(50) := 'DMT_EGP_ITEM_FBDI_GEN_PKG';

    -- Append a quoted field value followed by comma or newline
    PROCEDURE af (p_clob IN OUT NOCOPY CLOB, p_value IN VARCHAR2, p_last IN BOOLEAN DEFAULT FALSE) IS
        l_val VARCHAR2(32767);
    BEGIN
        l_val := '"' || REPLACE(NVL(p_value,''), '"', '""') || '"';
        DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(l_val), l_val);
        IF NOT p_last THEN DBMS_LOB.WRITEAPPEND(p_clob, 1, ',');
        ELSE DBMS_LOB.WRITEAPPEND(p_clob, 1, CHR(10)); END IF;
    END af;

    FUNCTION fmt_dt(p_date IN DATE) RETURN VARCHAR2 IS
    BEGIN
        IF p_date IS NULL THEN RETURN NULL; END IF;
        RETURN TO_CHAR(p_date, 'YYYY/MM/DD');
    END fmt_dt;

    FUNCTION fmt_num(p_num IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        IF p_num IS NULL THEN RETURN NULL; END IF;
        RETURN TO_CHAR(p_num);
    END fmt_num;

    FUNCTION gen_item_csv (p_run_id IN NUMBER, p_batch_id IN VARCHAR2 DEFAULT NULL) RETURN CLOB IS
        l_csv CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_csv, TRUE);

        -- No header row for FBDI
        -- Column order matches EgpSystemItemsInterface.ctl exactly (399 data columns)
        FOR r IN (
            SELECT *
            FROM   DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
            WHERE  RUN_ID = p_run_id
            AND    TFM_STATUS     = 'STAGED'
            AND    (p_batch_id IS NULL OR BATCH_ID = TO_NUMBER(p_batch_id))
            ORDER BY TFM_SEQUENCE_ID
        ) LOOP
            -- 1. TRANSACTION_TYPE (Identity)
            af(l_csv, r.TRANSACTION_TYPE);
            -- 2. BATCH_ID (Identity)
            af(l_csv, fmt_num(r.BATCH_ID));
            -- 3. BATCH_NUMBER (Identity)
            af(l_csv, r.BATCH_NUMBER);
            -- 4. ITEM_NUMBER (Identity)
            af(l_csv, r.ITEM_NUMBER);
            -- 5. OUTSIDE_PROCESS_SERVICE_FLAG (Identity)
            af(l_csv, NULL);
            -- 6. ORGANIZATION_CODE (Identity)
            af(l_csv, r.ORGANIZATION_CODE);
            -- 7. DESCRIPTION (Identity)
            af(l_csv, r.DESCRIPTION);
            -- 8. TEMPLATE_NAME (Identity)
            af(l_csv, r.TEMPLATE_NAME);
            -- 9. SOURCE_SYSTEM_CODE (Identity)
            af(l_csv, r.SOURCE_SYSTEM_CODE);
            -- 10. SOURCE_SYSTEM_REFERENCE (Identity)
            af(l_csv, r.SOURCE_SYSTEM_REFERENCE);
            -- 11. SOURCE_SYSTEM_REFERENCE_DESC (Identity)
            af(l_csv, NULL);
            -- 12. ITEM_CATALOG_GROUP_NAME (Identity)
            af(l_csv, NULL);
            -- 13. PRIMARY_UOM_NAME (Identity) -- TFM: PRIMARY_UOM_CODE
            af(l_csv, r.PRIMARY_UOM_CODE);
            -- 14. CURRENT_PHASE_CODE (Identity)
            af(l_csv, r.CURRENT_PHASE_CODE);
            -- 15. INVENTORY_ITEM_STATUS_CODE (Identity)
            af(l_csv, r.INVENTORY_ITEM_STATUS_CODE);
            -- 16. NEW_ITEM_CLASS_NAME (Identity) -- TFM: ITEM_CLASS_NAME
            af(l_csv, r.ITEM_CLASS_NAME);
            -- == Asset Management Attribute Group ==
            -- 17. ASSET_TRACKED_FLAG
            af(l_csv, NULL);
            -- 18. ALLOW_MAINTENANCE_ASSET_FLAG
            af(l_csv, NULL);
            -- 19. ENABLE_GENEALOGY_TRACKING_FLAG
            af(l_csv, NULL);
            -- 20. ASSET_CLASS
            af(l_csv, NULL);
            -- 21. EAM_ITEM_TYPE
            af(l_csv, NULL);
            -- 22. EAM_ACTIVITY_TYPE_CODE
            af(l_csv, NULL);
            -- 23. EAM_ACTIVITY_CAUSE_CODE
            af(l_csv, NULL);
            -- 24. EAM_ACT_NOTIFICATION_FLAG
            af(l_csv, NULL);
            -- 25. EAM_ACT_SHUTDOWN_STATUS
            af(l_csv, NULL);
            -- 26. EAM_ACTIVITY_SOURCE_CODE
            af(l_csv, NULL);
            -- == Costing Attribute Group ==
            -- 27. COSTING_ENABLED_FLAG
            af(l_csv, r.COSTING_ENABLED_FLAG);
            -- 28. STD_LOT_SIZE
            af(l_csv, NULL);
            -- 29. INVENTORY_ASSET_FLAG
            af(l_csv, r.INVENTORY_ASSET_FLAG);
            -- 30. DEFAULT_INCLUDE_IN_ROLLUP_FLAG
            af(l_csv, NULL);
            -- == General Planning Attribute Group ==
            -- 31. ORDER_COST
            af(l_csv, NULL);
            -- 32. VMI_MINIMUM_DAYS
            af(l_csv, NULL);
            -- 33. VMI_FIXED_ORDER_QUANTITY
            af(l_csv, NULL);
            -- 34. VMI_MINIMUM_UNITS
            af(l_csv, NULL);
            -- 35. ASN_AUTOEXPIRE_FLAG
            af(l_csv, NULL);
            -- 36. CARRYING_COST
            af(l_csv, NULL);
            -- 37. CONSIGNED_FLAG
            af(l_csv, NULL);
            -- 38. FIXED_DAYS_SUPPLY
            af(l_csv, fmt_num(r.FIXED_DAYS_SUPPLY));
            -- 39. FIXED_LOT_MULTIPLIER
            af(l_csv, fmt_num(r.FIXED_LOT_MULTIPLIER));
            -- 40. FIXED_ORDER_QUANTITY
            af(l_csv, fmt_num(r.FIXED_ORDER_QUANTITY));
            -- 41. FORECAST_HORIZON
            af(l_csv, NULL);
            -- 42. INVENTORY_PLANNING_CODE
            af(l_csv, fmt_num(r.INVENTORY_PLANNING_CODE));
            -- 43. SAFETY_STOCK_PLANNING_METHOD
            af(l_csv, NULL);
            -- 44. DEMAND_PERIOD
            af(l_csv, NULL);
            -- 45. DAYS_OF_COVER
            af(l_csv, NULL);
            -- 46. MIN_MINMAX_QUANTITY
            af(l_csv, fmt_num(r.MIN_MINMAX_QUANTITY));
            -- 47. MAX_MINMAX_QUANTITY
            af(l_csv, fmt_num(r.MAX_MINMAX_QUANTITY));
            -- 48. MINIMUM_ORDER_QUANTITY
            af(l_csv, fmt_num(r.MINIMUM_ORDER_QUANTITY));
            -- 49. MAXIMUM_ORDER_QUANTITY
            af(l_csv, fmt_num(r.MAXIMUM_ORDER_QUANTITY));
            -- 50. PLANNER_CODE
            af(l_csv, r.PLANNER_CODE);
            -- 51. PLANNING_MAKE_BUY_CODE
            af(l_csv, fmt_num(r.PLANNING_MAKE_BUY_CODE));
            -- 52. SOURCE_SUBINVENTORY
            af(l_csv, NULL);
            -- 53. SOURCE_TYPE
            af(l_csv, NULL);
            -- 54. SO_AUTHORIZATION_FLAG
            af(l_csv, NULL);
            -- 55. SUBCONTRACTING_COMPONENT
            af(l_csv, NULL);
            -- 56. VMI_FORECAST_TYPE
            af(l_csv, NULL);
            -- 57. VMI_MAXIMUM_UNITS
            af(l_csv, NULL);
            -- 58. VMI_MAXIMUM_DAYS
            af(l_csv, NULL);
            -- 59. SOURCE_ORGANIZATION_CODE
            af(l_csv, NULL);
            -- == Inventory Attribute Group ==
            -- 60. RESTRICT_SUBINVENTORIES_CODE
            af(l_csv, fmt_num(r.RESTRICT_SUBINVENTORIES_CODE));
            -- 61. RESTRICT_LOCATORS_CODE
            af(l_csv, fmt_num(r.RESTRICT_LOCATORS_CODE));
            -- 62. CHILD_LOT_FLAG
            af(l_csv, r.CHILD_LOT_FLAG);
            -- 63. CHILD_LOT_PREFIX
            af(l_csv, NULL);
            -- 64. CHILD_LOT_STARTING_NUMBER
            af(l_csv, NULL);
            -- 65. CHILD_LOT_VALIDATION_FLAG
            af(l_csv, NULL);
            -- 66. COPY_LOT_ATTRIBUTE_FLAG
            af(l_csv, NULL);
            -- 67. EXPIRATION_ACTION_CODE
            af(l_csv, NULL);
            -- 68. EXPIRATION_ACTION_INTERVAL
            af(l_csv, NULL);
            -- 69. STOCK_ENABLED_FLAG
            af(l_csv, r.STOCK_ENABLED_FLAG);
            -- 70. START_AUTO_LOT_NUMBER
            af(l_csv, NULL);
            -- 71. SHELF_LIFE_CODE
            af(l_csv, fmt_num(r.SHELF_LIFE_CODE));
            -- 72. SHELF_LIFE_DAYS
            af(l_csv, fmt_num(r.SHELF_LIFE_DAYS));
            -- 73. SERIAL_NUMBER_CONTROL_CODE
            af(l_csv, fmt_num(r.SERIAL_NUMBER_CONTROL_CODE));
            -- 74. SERIAL_STATUS_ENABLED
            af(l_csv, NULL);
            -- 75. REVISION_QTY_CONTROL_CODE
            af(l_csv, fmt_num(r.REVISION_QTY_CONTROL_CODE));
            -- 76. RETEST_INTERVAL
            af(l_csv, NULL);
            -- 77. AUTO_LOT_ALPHA_PREFIX
            af(l_csv, NULL);
            -- 78. AUTO_SERIAL_ALPHA_PREFIX
            af(l_csv, NULL);
            -- 79. BULK_PICKED_FLAG
            af(l_csv, NULL);
            -- 80. CHECK_SHORTAGES_FLAG
            af(l_csv, r.CHECK_SHORTAGES_FLAG);
            -- 81. CYCLE_COUNT_ENABLED_FLAG
            af(l_csv, r.CYCLE_COUNT_ENABLED_FLAG);
            -- 82. DEFAULT_GRADE
            af(l_csv, NULL);
            -- 83. GRADE_CONTROL_FLAG
            af(l_csv, r.GRADE_CONTROL_FLAG);
            -- 84. HOLD_DAYS
            af(l_csv, NULL);
            -- 85. LOT_DIVISIBLE_FLAG
            af(l_csv, r.LOT_DIVISIBLE_FLAG);
            -- 86. MATURITY_DAYS
            af(l_csv, NULL);
            -- 87. DEFAULT_LOT_STATUS_CODE
            af(l_csv, NULL);
            -- 88. DEFAULT_SERIAL_STATUS_CODE
            af(l_csv, NULL);
            -- 89. LOT_SPLIT_ENABLED
            af(l_csv, NULL);
            -- 90. LOT_MERGE_ENABLED
            af(l_csv, NULL);
            -- 91. INVENTORY_ITEM_FLAG
            af(l_csv, r.INVENTORY_ITEM_FLAG);
            -- 92. LOCATION_CONTROL_CODE
            af(l_csv, fmt_num(r.LOCATION_CONTROL_CODE));
            -- 93. LOT_CONTROL_CODE
            af(l_csv, fmt_num(r.LOT_CONTROL_CODE));
            -- 94. LOT_STATUS_ENABLED
            af(l_csv, NULL);
            -- 95. LOT_SUBSTITUTION_ENABLED
            af(l_csv, NULL);
            -- 96. LOT_TRANSLATE_ENABLED
            af(l_csv, NULL);
            -- 97. MTL_TRANSACTIONS_ENABLED_FLAG
            af(l_csv, r.MTL_TRANSACTIONS_ENABLED_FLAG);
            -- 98. POSITIVE_MEASUREMENT_ERROR
            af(l_csv, NULL);
            -- 99. NEGATIVE_MEASUREMENT_ERROR
            af(l_csv, NULL);
            -- 100. PARENT_CHILD_GENERATION_FLAG
            af(l_csv, NULL);
            -- 101. RESERVABLE_TYPE
            af(l_csv, fmt_num(r.RESERVABLE_TYPE));
            -- 102. START_AUTO_SERIAL_NUMBER
            af(l_csv, NULL);
            -- == Invoicing Attribute Group ==
            -- 103. INVOICING_RULE_NAME
            af(l_csv, r.INVOICING_RULE_NAME);
            -- 104. TAX_CODE
            af(l_csv, r.TAX_CODE);
            -- 105. SALES_ACCOUNT_KFFDISP -- TFM: SALES_ACCOUNT
            af(l_csv, r.SALES_ACCOUNT);
            -- 106. PAYMENT_TERMS_NAME
            af(l_csv, r.PAYMENT_TERMS_NAME);
            -- 107. INVOICE_ENABLED_FLAG
            af(l_csv, r.INVOICE_ENABLED_FLAG);
            -- 108. INVOICEABLE_ITEM_FLAG
            af(l_csv, r.INVOICEABLE_ITEM_FLAG);
            -- 109. ACCOUNTING_RULE_NAME
            af(l_csv, r.ACCOUNTING_RULE_NAME);
            -- == Item Structure Attribute Group ==
            -- 110. AUTO_CREATED_CONFIG_FLAG
            af(l_csv, NULL);
            -- 111. REPLENISH_TO_ORDER_FLAG
            af(l_csv, NULL);
            -- 112. PICK_COMPONENTS_FLAG
            af(l_csv, NULL);
            -- 113. BASE_ITEM_NUMBER
            af(l_csv, NULL);
            -- 114. EFFECTIVITY_CONTROL
            af(l_csv, NULL);
            -- 115. CONFIG_ORGS
            af(l_csv, NULL);
            -- 116. CONFIG_MATCH
            af(l_csv, NULL);
            -- 117. CONFIG_MODEL_TYPE
            af(l_csv, NULL);
            -- 118. BOM_ITEM_TYPE
            af(l_csv, NULL);
            -- == Lead Times Attribute Group ==
            -- 119. CUM_MANUFACTURING_LEAD_TIME
            af(l_csv, fmt_num(r.CUM_MANUFACTURING_LEAD_TIME));
            -- 120. PREPROCESSING_LEAD_TIME
            af(l_csv, fmt_num(r.PREPROCESSING_LEAD_TIME));
            -- 121. CUMULATIVE_TOTAL_LEAD_TIME
            af(l_csv, fmt_num(r.CUMULATIVE_TOTAL_LEAD_TIME));
            -- 122. FIXED_LEAD_TIME
            af(l_csv, fmt_num(r.FIXED_LEAD_TIME));
            -- 123. VARIABLE_LEAD_TIME
            af(l_csv, fmt_num(r.VARIABLE_LEAD_TIME));
            -- 124. FULL_LEAD_TIME
            af(l_csv, fmt_num(r.FULL_LEAD_TIME));
            -- 125. LEAD_TIME_LOT_SIZE
            af(l_csv, fmt_num(r.LEAD_TIME_LOT_SIZE));
            -- 126. POSTPROCESSING_LEAD_TIME
            af(l_csv, fmt_num(r.POSTPROCESSING_LEAD_TIME));
            -- == MPS and MRP Planning Attribute Group ==
            -- 127. ATO_FORECAST_CONTROL
            af(l_csv, NULL);
            -- 128. CRITICAL_COMPONENT_FLAG
            af(l_csv, NULL);
            -- 129. ACCEPTABLE_EARLY_DAYS
            af(l_csv, NULL);
            -- 130. CREATE_SUPPLY_FLAG
            af(l_csv, NULL);
            -- 131. DAYS_TGT_INV_SUPPLY
            af(l_csv, NULL);
            -- 132. DAYS_TGT_INV_WINDOW
            af(l_csv, NULL);
            -- 133. DAYS_MAX_INV_SUPPLY
            af(l_csv, NULL);
            -- 134. DAYS_MAX_INV_WINDOW
            af(l_csv, NULL);
            -- 135. DEMAND_TIME_FENCE_CODE
            af(l_csv, NULL);
            -- 136. DEMAND_TIME_FENCE_DAYS
            af(l_csv, NULL);
            -- 137. DRP_PLANNED_FLAG
            af(l_csv, NULL);
            -- 138. END_ASSEMBLY_PEGGING_FLAG
            af(l_csv, NULL);
            -- 139. EXCLUDE_FROM_BUDGET_FLAG
            af(l_csv, NULL);
            -- 140. MRP_CALCULATE_ATP_FLAG
            af(l_csv, NULL);
            -- 141. MRP_PLANNING_CODE
            af(l_csv, fmt_num(r.MRP_PLANNING_CODE));
            -- 142. PLANNED_INV_POINT_FLAG
            af(l_csv, NULL);
            -- 143. PLANNING_TIME_FENCE_CODE
            af(l_csv, NULL);
            -- 144. PLANNING_TIME_FENCE_DAYS
            af(l_csv, NULL);
            -- 145. PREPOSITION_POINT
            af(l_csv, NULL);
            -- 146. RELEASE_TIME_FENCE_CODE
            af(l_csv, NULL);
            -- 147. RELEASE_TIME_FENCE_DAYS
            af(l_csv, NULL);
            -- 148. REPAIR_LEADTIME
            af(l_csv, NULL);
            -- 149. REPAIR_YIELD
            af(l_csv, NULL);
            -- 150. REPAIR_PROGRAM
            af(l_csv, NULL);
            -- 151. ROUNDING_CONTROL_TYPE
            af(l_csv, NULL);
            -- 152. SHRINKAGE_RATE
            af(l_csv, fmt_num(r.SHRINKAGE_RATE));
            -- 153. SUBSTITUTION_WINDOW_CODE
            af(l_csv, NULL);
            -- 154. SUBSTITUTION_WINDOW_DAYS
            af(l_csv, NULL);
            -- == Main Attribute Group ==
            -- 155. TRADE_ITEM_DESCRIPTOR
            af(l_csv, NULL);
            -- 156. ALLOWED_UNITS_LOOKUP_CODE
            af(l_csv, NULL);
            -- 157. DUAL_UOM_DEVIATION_HIGH
            af(l_csv, fmt_num(r.DUAL_UOM_DEVIATION_HIGH));
            -- 158. DUAL_UOM_DEVIATION_LOW
            af(l_csv, fmt_num(r.DUAL_UOM_DEVIATION_LOW));
            -- 159. ITEM_TYPE
            af(l_csv, r.ITEM_TYPE);
            -- 160. LONG_DESCRIPTION
            af(l_csv, r.LONG_DESCRIPTION);
            -- 161. HTML_LONG_DESCRIPTION
            af(l_csv, NULL);
            -- 162. ONT_PRICING_QTY_SOURCE
            af(l_csv, NULL);
            -- 163. SECONDARY_DEFAULT_IND
            af(l_csv, NULL);
            -- 164. SECONDARY_UOM_NAME -- TFM: SECONDARY_UOM_CODE
            af(l_csv, r.SECONDARY_UOM_CODE);
            -- 165. TRACKING_QUANTITY_IND
            af(l_csv, NULL);
            -- 166. ENGINEERED_ITEM_FLAG
            af(l_csv, NULL);
            -- == Order Management Attribute Group ==
            -- 167. ATP_COMPONENTS_FLAG
            af(l_csv, NULL);
            -- 168. ATP_FLAG
            af(l_csv, r.ATP_FLAG);
            -- 169. OVER_SHIPMENT_TOLERANCE
            af(l_csv, fmt_num(r.OVER_SHIPMENT_TOLERANCE));
            -- 170. UNDER_SHIPMENT_TOLERANCE
            af(l_csv, fmt_num(r.UNDER_SHIPMENT_TOLERANCE));
            -- 171. OVER_RETURN_TOLERANCE
            af(l_csv, fmt_num(r.OVER_RETURN_TOLERANCE));
            -- 172. UNDER_RETURN_TOLERANCE
            af(l_csv, fmt_num(r.UNDER_RETURN_TOLERANCE));
            -- 173. DOWNLOADABLE_FLAG
            af(l_csv, NULL);
            -- 174. ELECTRONIC_FLAG
            af(l_csv, NULL);
            -- 175. INDIVISIBLE_FLAG
            af(l_csv, r.INDIVISIBLE_FLAG);
            -- 176. INTERNAL_ORDER_ENABLED_FLAG
            af(l_csv, r.INTERNAL_ORDER_ENABLED_FLAG);
            -- 177. ATP_RULE_ID
            af(l_csv, NULL);
            -- 178. CHARGE_PERIODICITY_NAME
            af(l_csv, NULL);
            -- 179. CUSTOMER_ORDER_ENABLED_FLAG
            af(l_csv, r.CUSTOMER_ORDER_ENABLED_FLAG);
            -- 180. DEFAULT_SHIPPING_ORG_CODE -- TFM: DEFAULT_SHIPPING_ORG
            af(l_csv, r.DEFAULT_SHIPPING_ORG);
            -- 181. DEFAULT_SO_SOURCE_TYPE
            af(l_csv, NULL);
            -- 182. ELIGIBILITY_COMPATIBILITY_RULE
            af(l_csv, NULL);
            -- 183. FINANCING_ALLOWED_FLAG
            af(l_csv, NULL);
            -- 184. INTERNAL_ORDER_FLAG
            af(l_csv, r.INTERNAL_ORDER_FLAG);
            -- 185. PICKING_RULE_NAME
            af(l_csv, r.PICKING_RULE_NAME);
            -- 186. RETURNABLE_FLAG
            af(l_csv, r.RETURNABLE_FLAG);
            -- 187. RETURN_INSPECTION_REQUIREMENT
            af(l_csv, NULL);
            -- 188. SALES_PRODUCT_TYPE
            af(l_csv, NULL);
            -- 189. BACK_TO_BACK_ENABLED
            af(l_csv, NULL);
            -- 190. SHIPPABLE_ITEM_FLAG
            af(l_csv, r.SHIPPABLE_ITEM_FLAG);
            -- 191. SHIP_MODEL_COMPLETE_FLAG
            af(l_csv, NULL);
            -- 192. SO_TRANSACTIONS_FLAG
            af(l_csv, NULL);
            -- 193. CUSTOMER_ORDER_FLAG
            af(l_csv, r.CUSTOMER_ORDER_FLAG);
            -- == Physical Attributes Group ==
            -- 194. UNIT_WEIGHT
            af(l_csv, fmt_num(r.UNIT_WEIGHT));
            -- 195. WEIGHT_UOM_NAME -- TFM: WEIGHT_UOM_CODE
            af(l_csv, r.WEIGHT_UOM_CODE);
            -- 196. UNIT_VOLUME
            af(l_csv, fmt_num(r.UNIT_VOLUME));
            -- 197. VOLUME_UOM_NAME -- TFM: VOLUME_UOM_CODE
            af(l_csv, r.VOLUME_UOM_CODE);
            -- 198. DIMENSION_UOM_NAME -- TFM: DIMENSION_UOM_CODE
            af(l_csv, r.DIMENSION_UOM_CODE);
            -- 199. UNIT_LENGTH
            af(l_csv, fmt_num(r.UNIT_LENGTH));
            -- 200. UNIT_WIDTH
            af(l_csv, fmt_num(r.UNIT_WIDTH));
            -- 201. UNIT_HEIGHT
            af(l_csv, fmt_num(r.UNIT_HEIGHT));
            -- 202. COLLATERAL_FLAG
            af(l_csv, NULL);
            -- 203. CONTAINER_ITEM_FLAG
            af(l_csv, NULL);
            -- 204. CONTAINER_TYPE_CODE
            af(l_csv, NULL);
            -- 205. EQUIPMENT_TYPE
            af(l_csv, NULL);
            -- 206. EVENT_FLAG
            af(l_csv, NULL);
            -- 207. INTERNAL_VOLUME
            af(l_csv, NULL);
            -- 208. MAXIMUM_LOAD_WEIGHT
            af(l_csv, NULL);
            -- 209. MINIMUM_FILL_PERCENT
            af(l_csv, NULL);
            -- 210. VEHICLE_ITEM_FLAG
            af(l_csv, NULL);
            -- == Process Manufacturing Attribute Group ==
            -- 211. CAS_NUMBER
            af(l_csv, NULL);
            -- 212. HAZARDOUS_MATERIAL_FLAG
            af(l_csv, NULL);
            -- 213. PROCESS_COSTING_ENABLED_FLAG
            af(l_csv, NULL);
            -- 214. PROCESS_EXECUTION_ENABLED_FLAG
            af(l_csv, NULL);
            -- 215. PROCESS_QUALITY_ENABLED_FLAG
            af(l_csv, NULL);
            -- 216. PROCESS_SUPPLY_LOCATOR_KFFDISP
            af(l_csv, NULL);
            -- 217. PROCESS_SUPPLY_SUBINVENTORY
            af(l_csv, NULL);
            -- 218. PROCESS_YIELD_LOCATOR_KFFDISP
            af(l_csv, NULL);
            -- 219. PROCESS_YIELD_SUBINVENTORY
            af(l_csv, NULL);
            -- 220. RECIPE_ENABLED_FLAG
            af(l_csv, NULL);
            -- == Purchasing Attribute Group ==
            -- 221. EXPENSE_ACCOUNT_KFFDISP -- TFM: EXPENSE_ACCOUNT
            af(l_csv, r.EXPENSE_ACCOUNT);
            -- 222. UN_NUMBER_CODE
            af(l_csv, r.UN_NUMBER_CODE);
            -- 223. UNIT_OF_ISSUE
            af(l_csv, NULL);
            -- 224. ROUNDING_FACTOR
            af(l_csv, NULL);
            -- 225. RECEIVE_CLOSE_TOLERANCE
            af(l_csv, fmt_num(r.RECEIVE_CLOSE_TOLERANCE));
            -- 226. PURCHASING_TAX_CODE
            af(l_csv, r.PURCHASING_TAX_CODE);
            -- 227. PURCHASING_ITEM_FLAG
            af(l_csv, r.PURCHASING_ITEM_FLAG);
            -- 228. PRICE_TOLERANCE_PERCENT
            af(l_csv, fmt_num(r.PRICE_TOLERANCE_PERCENT));
            -- 229. OUTSOURCED_ASSEMBLY
            af(l_csv, NULL);
            -- 230. OUTSIDE_OPERATION_UOM_TYPE
            af(l_csv, NULL);
            -- 231. NEGOTIATION_REQUIRED_FLAG
            af(l_csv, NULL);
            -- 232. MUST_USE_APPROVED_VENDOR_FLAG
            af(l_csv, r.MUST_USE_APPROVED_VENDOR_FLAG);
            -- 233. MATCH_APPROVAL_LEVEL
            af(l_csv, r.MATCH_APPROVAL_LEVEL);
            -- 234. INVOICE_MATCH_OPTION
            af(l_csv, r.INVOICE_MATCH_OPTION);
            -- 235. LIST_PRICE_PER_UNIT
            af(l_csv, fmt_num(r.LIST_PRICE_PER_UNIT));
            -- 236. INVOICE_CLOSE_TOLERANCE
            af(l_csv, fmt_num(r.INVOICE_CLOSE_TOLERANCE));
            -- 237. HAZARD_CLASS_CODE
            af(l_csv, r.HAZARD_CLASS_CODE);
            -- 238. BUYER_NAME
            af(l_csv, r.BUYER_NAME);
            -- 239. TAXABLE_FLAG
            af(l_csv, NULL);
            -- 240. PURCHASING_ENABLED_FLAG
            af(l_csv, r.PURCHASING_ENABLED_FLAG);
            -- 241. OUTSIDE_OPERATION_FLAG
            af(l_csv, r.OUTSIDE_OPERATION_FLAG);
            -- 242. MARKET_PRICE
            af(l_csv, fmt_num(r.MARKET_PRICE));
            -- 243. ASSET_CATEGORY_KFFDISP -- TFM: ASSET_CATEGORY_ID
            af(l_csv, fmt_num(r.ASSET_CATEGORY_ID));
            -- 244. ALLOW_ITEM_DESC_UPDATE_FLAG
            af(l_csv, r.ALLOW_ITEM_DESC_UPDATE_FLAG);
            -- == Receiving Attribute Group ==
            -- 245. ALLOW_EXPRESS_DELIVERY_FLAG
            af(l_csv, NULL);
            -- 246. ALLOW_SUBSTITUTE_RECEIPTS_FLAG
            af(l_csv, r.ALLOW_SUBSTITUTE_RECEIPTS_FLAG);
            -- 247. ALLOW_UNORDERED_RECEIPTS_FLAG
            af(l_csv, r.ALLOW_UNORDERED_RECEIPTS_FLAG);
            -- 248. DAYS_EARLY_RECEIPT_ALLOWED
            af(l_csv, fmt_num(r.DAYS_EARLY_RECEIPT_ALLOWED));
            -- 249. DAYS_LATE_RECEIPT_ALLOWED
            af(l_csv, fmt_num(r.DAYS_LATE_RECEIPT_ALLOWED));
            -- 250. RECEIVING_ROUTING_ID
            af(l_csv, fmt_num(r.RECEIVING_ROUTING_ID));
            -- 251. ENFORCE_SHIP_TO_LOCATION_CODE
            af(l_csv, r.ENFORCE_SHIP_TO_LOCATION_CODE);
            -- 252. QTY_RCV_EXCEPTION_CODE
            af(l_csv, r.QTY_RCV_EXCEPTION_CODE);
            -- 253. QTY_RCV_TOLERANCE
            af(l_csv, fmt_num(r.QTY_RCV_TOLERANCE));
            -- 254. RECEIPT_DAYS_EXCEPTION_CODE
            af(l_csv, r.RECEIPT_DAYS_EXCEPTION_CODE);
            -- == Service Attribute Group ==
            -- 255. ASSET_CREATION_CODE
            af(l_csv, NULL);
            -- 256. SERVICE_START_TYPE_CODE
            af(l_csv, NULL);
            -- 257. COMMS_NL_TRACKABLE_FLAG
            af(l_csv, NULL);
            -- 258. CSS_ENABLED_FLAG
            af(l_csv, NULL);
            -- 259. CONTRACT_ITEM_TYPE_CODE
            af(l_csv, r.CONTRACT_ITEM_TYPE_CODE);
            -- 260. STANDARD_COVERAGE
            af(l_csv, NULL);
            -- 261. DEFECT_TRACKING_ON_FLAG
            af(l_csv, NULL);
            -- 262. IB_ITEM_INSTANCE_CLASS
            af(l_csv, NULL);
            -- 263. MATERIAL_BILLABLE_FLAG
            af(l_csv, NULL);
            -- 264. RECOVERED_PART_DISP_CODE
            af(l_csv, NULL);
            -- 265. SERVICEABLE_PRODUCT_FLAG
            af(l_csv, r.SERVICEABLE_PRODUCT_FLAG);
            -- 266. SERVICE_STARTING_DELAY
            af(l_csv, NULL);
            -- 267. SERVICE_DURATION
            af(l_csv, fmt_num(r.SERVICE_DURATION));
            -- 268. SERVICE_DURATION_PERIOD_NAME -- TFM: SERVICE_DURATION_PERIOD_CODE
            af(l_csv, r.SERVICE_DURATION_PERIOD_CODE);
            -- 269. SERV_REQ_ENABLED_CODE
            af(l_csv, NULL);
            -- 270. ALLOW_SUSPEND_FLAG
            af(l_csv, NULL);
            -- 271. ALLOW_TERMINATE_FLAG
            af(l_csv, NULL);
            -- 272. REQUIRES_FULFILLMENT_LOC_FLAG
            af(l_csv, NULL);
            -- 273. REQUIRES_ITM_ASSOCIATION_FLAG
            af(l_csv, NULL);
            -- 274. SERVICE_START_DELAY
            af(l_csv, NULL);
            -- 275. SERVICE_DURATION_TYPE_CODE
            af(l_csv, NULL);
            -- 276. COMMS_ACTIVATION_REQD_FLAG
            af(l_csv, NULL);
            -- 277. SERV_BILLING_ENABLED_FLAG
            af(l_csv, NULL);
            -- == Web Store Attribute Group ==
            -- 278. ORDERABLE_ON_WEB_FLAG
            af(l_csv, NULL);
            -- 279. BACK_ORDERABLE_FLAG
            af(l_csv, r.BACK_ORDERABLE_FLAG);
            -- 280. WEB_STATUS
            af(l_csv, NULL);
            -- 281. MINIMUM_LICENSE_QUANTITY
            af(l_csv, NULL);
            -- == Work in Process Attribute Group ==
            -- 282. BUILD_IN_WIP_FLAG
            af(l_csv, r.BUILD_IN_WIP_FLAG);
            -- 283. CONTRACT_MANUFACTURING
            af(l_csv, NULL);
            -- 284. WIP_SUPPLY_LOCATOR_KFFDISP
            af(l_csv, NULL);
            -- 285. WIP_SUPPLY_TYPE
            af(l_csv, fmt_num(r.WIP_SUPPLY_TYPE));
            -- 286. WIP_SUPPLY_SUBINVENTORY
            af(l_csv, r.WIP_SUPPLY_SUBINVENTORY);
            -- 287. OVERCOMPLETION_TOLERANCE_TYPE
            af(l_csv, NULL);
            -- 288. OVERCOMPLETION_TOLERANCE_VALUE
            af(l_csv, NULL);
            -- 289. INVENTORY_CARRY_PENALTY
            af(l_csv, NULL);
            -- 290. OPERATION_SLACK_PENALTY
            af(l_csv, NULL);
            -- == Revision / Style / Version ==
            -- 291. REVISION
            af(l_csv, NULL);
            -- 292. STYLE_ITEM_FLAG
            af(l_csv, r.STYLE_ITEM_FLAG);
            -- 293. STYLE_ITEM_NUMBER
            af(l_csv, NULL);
            -- 294. VERSION_START_DATE
            af(l_csv, NULL);
            -- 295. VERSION_REVISION_CODE
            af(l_csv, NULL);
            -- 296. VERSION_LABEL
            af(l_csv, NULL);
            -- 297. START_UPON_MILESTONE_CODE
            af(l_csv, NULL);
            -- 298. SALES_PRODUCT_SUB_TYPE
            af(l_csv, NULL);
            -- == Global Attributes 1-10 ==
            -- 299. GLOBAL_ATTRIBUTE_CATEGORY
            af(l_csv, r.GLOBAL_ATTRIBUTE_CATEGORY);
            -- 300. GLOBAL_ATTRIBUTE1
            af(l_csv, r.GLOBAL_ATTRIBUTE1);
            -- 301. GLOBAL_ATTRIBUTE2
            af(l_csv, r.GLOBAL_ATTRIBUTE2);
            -- 302. GLOBAL_ATTRIBUTE3
            af(l_csv, r.GLOBAL_ATTRIBUTE3);
            -- 303. GLOBAL_ATTRIBUTE4
            af(l_csv, r.GLOBAL_ATTRIBUTE4);
            -- 304. GLOBAL_ATTRIBUTE5
            af(l_csv, r.GLOBAL_ATTRIBUTE5);
            -- 305. GLOBAL_ATTRIBUTE6
            af(l_csv, r.GLOBAL_ATTRIBUTE6);
            -- 306. GLOBAL_ATTRIBUTE7
            af(l_csv, r.GLOBAL_ATTRIBUTE7);
            -- 307. GLOBAL_ATTRIBUTE8
            af(l_csv, r.GLOBAL_ATTRIBUTE8);
            -- 308. GLOBAL_ATTRIBUTE9
            af(l_csv, r.GLOBAL_ATTRIBUTE9);
            -- 309. GLOBAL_ATTRIBUTE10
            af(l_csv, r.GLOBAL_ATTRIBUTE10);
            -- == DFF Attributes ==
            -- 310. ATTRIBUTE_CATEGORY
            af(l_csv, r.ATTRIBUTE_CATEGORY);
            -- 311. ATTRIBUTE1
            af(l_csv, r.ATTRIBUTE1);
            -- 312. ATTRIBUTE2
            af(l_csv, r.ATTRIBUTE2);
            -- 313. ATTRIBUTE3
            af(l_csv, r.ATTRIBUTE3);
            -- 314. ATTRIBUTE4
            af(l_csv, r.ATTRIBUTE4);
            -- 315. ATTRIBUTE5
            af(l_csv, r.ATTRIBUTE5);
            -- 316. ATTRIBUTE6
            af(l_csv, r.ATTRIBUTE6);
            -- 317. ATTRIBUTE7
            af(l_csv, r.ATTRIBUTE7);
            -- 318. ATTRIBUTE8
            af(l_csv, r.ATTRIBUTE8);
            -- 319. ATTRIBUTE9
            af(l_csv, r.ATTRIBUTE9);
            -- 320. ATTRIBUTE10
            af(l_csv, r.ATTRIBUTE10);
            -- 321. ATTRIBUTE11
            af(l_csv, r.ATTRIBUTE11);
            -- 322. ATTRIBUTE12
            af(l_csv, r.ATTRIBUTE12);
            -- 323. ATTRIBUTE13
            af(l_csv, r.ATTRIBUTE13);
            -- 324. ATTRIBUTE14
            af(l_csv, r.ATTRIBUTE14);
            -- 325. ATTRIBUTE15
            af(l_csv, r.ATTRIBUTE15);
            -- 326. ATTRIBUTE16
            af(l_csv, NULL);
            -- 327. ATTRIBUTE17
            af(l_csv, NULL);
            -- 328. ATTRIBUTE18
            af(l_csv, NULL);
            -- 329. ATTRIBUTE19
            af(l_csv, NULL);
            -- 330. ATTRIBUTE20
            af(l_csv, NULL);
            -- 331. ATTRIBUTE21
            af(l_csv, NULL);
            -- 332. ATTRIBUTE22
            af(l_csv, NULL);
            -- 333. ATTRIBUTE23
            af(l_csv, NULL);
            -- 334. ATTRIBUTE24
            af(l_csv, NULL);
            -- 335. ATTRIBUTE25
            af(l_csv, NULL);
            -- 336. ATTRIBUTE26
            af(l_csv, NULL);
            -- 337. ATTRIBUTE27
            af(l_csv, NULL);
            -- 338. ATTRIBUTE28
            af(l_csv, NULL);
            -- 339. ATTRIBUTE29
            af(l_csv, NULL);
            -- 340. ATTRIBUTE30
            af(l_csv, NULL);
            -- == Attribute Numbers ==
            -- 341. ATTRIBUTE_NUMBER1
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER1));
            -- 342. ATTRIBUTE_NUMBER2
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER2));
            -- 343. ATTRIBUTE_NUMBER3
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER3));
            -- 344. ATTRIBUTE_NUMBER4
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER4));
            -- 345. ATTRIBUTE_NUMBER5
            af(l_csv, fmt_num(r.ATTRIBUTE_NUMBER5));
            -- 346. ATTRIBUTE_NUMBER6
            af(l_csv, NULL);
            -- 347. ATTRIBUTE_NUMBER7
            af(l_csv, NULL);
            -- 348. ATTRIBUTE_NUMBER8
            af(l_csv, NULL);
            -- 349. ATTRIBUTE_NUMBER9
            af(l_csv, NULL);
            -- 350. ATTRIBUTE_NUMBER10
            af(l_csv, NULL);
            -- == Attribute Dates ==
            -- 351. ATTRIBUTE_DATE1
            af(l_csv, fmt_dt(r.ATTRIBUTE_DATE1));
            -- 352. ATTRIBUTE_DATE2
            af(l_csv, fmt_dt(r.ATTRIBUTE_DATE2));
            -- 353. ATTRIBUTE_DATE3
            af(l_csv, fmt_dt(r.ATTRIBUTE_DATE3));
            -- 354. ATTRIBUTE_DATE4
            af(l_csv, fmt_dt(r.ATTRIBUTE_DATE4));
            -- 355. ATTRIBUTE_DATE5
            af(l_csv, fmt_dt(r.ATTRIBUTE_DATE5));
            -- == Attribute Timestamps ==
            -- 356. ATTRIBUTE_TIMESTAMP1
            af(l_csv, NULL);
            -- 357. ATTRIBUTE_TIMESTAMP2
            af(l_csv, NULL);
            -- 358. ATTRIBUTE_TIMESTAMP3
            af(l_csv, NULL);
            -- 359. ATTRIBUTE_TIMESTAMP4
            af(l_csv, NULL);
            -- 360. ATTRIBUTE_TIMESTAMP5
            af(l_csv, NULL);
            -- == Global Attributes 11-20 ==
            -- 361. GLOBAL_ATTRIBUTE11
            af(l_csv, r.GLOBAL_ATTRIBUTE11);
            -- 362. GLOBAL_ATTRIBUTE12
            af(l_csv, r.GLOBAL_ATTRIBUTE12);
            -- 363. GLOBAL_ATTRIBUTE13
            af(l_csv, r.GLOBAL_ATTRIBUTE13);
            -- 364. GLOBAL_ATTRIBUTE14
            af(l_csv, r.GLOBAL_ATTRIBUTE14);
            -- 365. GLOBAL_ATTRIBUTE15
            af(l_csv, r.GLOBAL_ATTRIBUTE15);
            -- 366. GLOBAL_ATTRIBUTE16
            af(l_csv, r.GLOBAL_ATTRIBUTE16);
            -- 367. GLOBAL_ATTRIBUTE17
            af(l_csv, r.GLOBAL_ATTRIBUTE17);
            -- 368. GLOBAL_ATTRIBUTE18
            af(l_csv, r.GLOBAL_ATTRIBUTE18);
            -- 369. GLOBAL_ATTRIBUTE19
            af(l_csv, r.GLOBAL_ATTRIBUTE19);
            -- 370. GLOBAL_ATTRIBUTE20
            af(l_csv, r.GLOBAL_ATTRIBUTE20);
            -- == Global Attribute Numbers ==
            -- 371. GLOBAL_ATTRIBUTE_NUMBER1
            af(l_csv, NULL);
            -- 372. GLOBAL_ATTRIBUTE_NUMBER2
            af(l_csv, NULL);
            -- 373. GLOBAL_ATTRIBUTE_NUMBER3
            af(l_csv, NULL);
            -- 374. GLOBAL_ATTRIBUTE_NUMBER4
            af(l_csv, NULL);
            -- 375. GLOBAL_ATTRIBUTE_NUMBER5
            af(l_csv, NULL);
            -- == Global Attribute Dates ==
            -- 376. GLOBAL_ATTRIBUTE_DATE1
            af(l_csv, NULL);
            -- 377. GLOBAL_ATTRIBUTE_DATE2
            af(l_csv, NULL);
            -- 378. GLOBAL_ATTRIBUTE_DATE3
            af(l_csv, NULL);
            -- 379. GLOBAL_ATTRIBUTE_DATE4
            af(l_csv, NULL);
            -- 380. GLOBAL_ATTRIBUTE_DATE5
            af(l_csv, NULL);
            -- == Extended Fields ==
            -- 381. PRC_BU_NAME
            af(l_csv, NULL);
            -- 382. FORCE_PURCHASE_LEAD_TIME_FLAG
            af(l_csv, NULL);
            -- 383. REPLACEMENT_TYPE
            af(l_csv, NULL);
            -- 384. BUYER_EMAIL_ADDRESS
            af(l_csv, NULL);
            -- 385. DEFAULT_EXPENDITURE_TYPE
            af(l_csv, NULL);
            -- 386. HARD_PEGGING_LEVEL
            af(l_csv, NULL);
            -- 387. COMN_SUPPLY_PRJ_DEMAND_FLAG
            af(l_csv, NULL);
            -- 388. ENABLE_IOT_FLAG
            af(l_csv, NULL);
            -- 389. PACKAGING_STRING
            af(l_csv, NULL);
            -- 390. CREATE_SUPPLY_AFTER_DATE
            af(l_csv, NULL);
            -- 391. CREATE_FIXED_ASSET
            af(l_csv, NULL);
            -- 392. UNDER_COMPL_TOLERANCE_TYPE
            af(l_csv, NULL);
            -- 393. UNDER_COMPL_TOLERANCE_VALUE
            af(l_csv, NULL);
            -- 394. REPAIR_TRANSACTION_NAME
            af(l_csv, NULL);
            -- 395. NEW_PRIMARY_UOM_NAME
            af(l_csv, NULL);
            -- 396. NEW_SECONDARY_UOM_NAME
            af(l_csv, NULL);
            -- 397. PARTS_SOURCING_NAME
            af(l_csv, NULL);
            -- 398. ORDER_MODIFIER_START_QTY_FLAG
            af(l_csv, NULL);
            -- 399. EXPIRATION_DATE_CALC_BASIS (last column)
            af(l_csv, NULL, p_last => TRUE);
        END LOOP;

        RETURN l_csv;
    END gen_item_csv;

    -- ============================================================
    -- GENERATE_FBDI
    -- Produces a single ZIP with Items CSV + optional ItemCategories CSV.
    -- Both are loaded by ItemImportJobDef in one ESS submission.
    -- ============================================================
    PROCEDURE GENERATE_FBDI (
        p_run_id  IN  NUMBER,
        x_fbdi_zip        OUT BLOB,
        x_filename        OUT VARCHAR2,
        x_fbdi_csv_id     OUT NUMBER,
        p_batch_id        IN  VARCHAR2 DEFAULT NULL
    ) IS
        C_PROC          CONSTANT VARCHAR2(30) := 'GENERATE_FBDI';
        l_zip           BLOB;
        l_item_csv      CLOB;
        l_cat_csv       CLOB;
        l_csv_id        NUMBER;
        l_now           DATE := SYSDATE;
        l_item_count    NUMBER;
        l_cat_count     NUMBER;
    BEGIN
        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Items FBDI generation start (bundled with categories).',
            p_package        => C_PKG,
            p_procedure      => C_PROC);

        x_filename := 'EgpItem_' || TO_CHAR(p_run_id)
                      || CASE WHEN p_batch_id IS NULL THEN '' ELSE '_' || p_batch_id END
                      || '.zip';

        -- Count items rows (scoped to the batch when p_batch_id is passed)
        SELECT COUNT(*) INTO l_item_count
        FROM   DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = TO_NUMBER(p_batch_id));

        -- Count categories rows (may be 0 if no categories data)
        SELECT COUNT(*) INTO l_cat_count
        FROM   DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
        WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
        AND    (p_batch_id IS NULL OR BATCH_ID = TO_NUMBER(p_batch_id));

        IF l_item_count = 0 AND l_cat_count = 0 THEN
            DMT_UTIL_PKG.LOG(
                p_run_id => p_run_id,
                p_message        => 'No STAGED item or category rows found. Skipping zip generation.',
                p_log_type       => DMT_UTIL_PKG.C_LOG_WARN,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            x_fbdi_zip    := NULL;
            x_fbdi_csv_id := NULL;
            RETURN;
        END IF;

        -- Generate items CSV
        IF l_item_count > 0 THEN
            l_item_csv := gen_item_csv(p_run_id, p_batch_id);
        END IF;

        -- Generate categories CSV via the categories package
        IF l_cat_count > 0 THEN
            l_cat_csv := DMT_EGP_ITEM_CAT_FBDI_GEN_PKG.GENERATE_CSV(p_run_id, p_batch_id);
        END IF;

        -- Register items CSV in tracking table
        SELECT DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL INTO l_csv_id FROM DUAL;
        INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
            FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
            CSV_CONTENT, CREATED_DATE
        ) VALUES (
            l_csv_id, p_run_id, 'Items',
            'EgpSystemItemsInterface.csv', l_item_count, l_item_csv, l_now
        );

        -- Register categories CSV if present
        IF l_cat_count > 0 THEN
            INSERT INTO DMT_OWNER.DMT_FBDI_CSV_TBL (
                FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME, ROW_COUNT,
                CSV_CONTENT, CREATED_DATE
            ) VALUES (
                DMT_OWNER.DMT_FBDI_CSV_ID_SEQ.NEXTVAL, p_run_id, 'ItemCategories',
                'EgpItemCategoriesInterface.csv', l_cat_count, l_cat_csv, l_now
            );
        END IF;

        -- Build combined ZIP (standard pattern — no manifest file)
        DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);
        IF l_item_count > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'EgpSystemItemsInterface.csv',
                DMT_UTIL_PKG.CLOB_TO_BLOB(l_item_csv));
        END IF;
        IF l_cat_count > 0 THEN
            DMT_OWNER.UTL_ZIP.add1file(l_zip, 'EgpItemCategoriesInterface.csv',
                DMT_UTIL_PKG.CLOB_TO_BLOB(l_cat_csv));
        END IF;
        DMT_OWNER.UTL_ZIP.finish_zip(l_zip);

        -- Register ZIP
        INSERT INTO DMT_OWNER.DMT_FBDI_ZIP_TBL (
            FBDI_ZIP_ID, FBDI_CSV_ID, RUN_ID, OBJECT_TYPE, FILENAME,
            ZIP_SIZE_BYTES, ZIP_CONTENT, CREATED_DATE
        ) VALUES (
            DMT_OWNER.DMT_FBDI_ZIP_ID_SEQ.NEXTVAL, l_csv_id, p_run_id,
            'Items', x_filename, DBMS_LOB.GETLENGTH(l_zip), l_zip, l_now
        );

        -- Mark items TFM rows as GENERATED (only this batch's rows)
        IF l_item_count > 0 THEN
            UPDATE DMT_OWNER.DMT_EGP_ITEM_TFM_TBL
            SET    TFM_STATUS        = 'GENERATED',
                   FBDI_CSV_ID       = l_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR BATCH_ID = TO_NUMBER(p_batch_id));
        END IF;

        -- Mark categories TFM rows as GENERATED (only this batch's rows)
        IF l_cat_count > 0 THEN
            UPDATE DMT_OWNER.DMT_EGP_ITEM_CAT_TFM_TBL
            SET    TFM_STATUS        = 'GENERATED',
                   FBDI_CSV_ID       = l_csv_id,
                   LAST_UPDATED_DATE = l_now
            WHERE  RUN_ID = p_run_id AND TFM_STATUS = 'STAGED'
            AND    (p_batch_id IS NULL OR BATCH_ID = TO_NUMBER(p_batch_id));
        END IF;

        -- Free temporary CLOBs
        IF l_item_csv IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_item_csv); END IF;
        IF l_cat_csv  IS NOT NULL THEN DBMS_LOB.FREETEMPORARY(l_cat_csv);  END IF;

        x_fbdi_zip    := l_zip;
        x_fbdi_csv_id := l_csv_id;

        DMT_UTIL_PKG.LOG(
            p_run_id => p_run_id,
            p_message        => 'Items FBDI generation complete. Items: ' || l_item_count
                                || ' | Categories: ' || l_cat_count
                                || ' | File: ' || x_filename
                                || ' | Zip bytes: ' || DBMS_LOB.GETLENGTH(l_zip),
            p_package        => C_PKG,
            p_procedure      => C_PROC);

    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'Items FBDI generation failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => C_PROC);
            RAISE;
    END GENERATE_FBDI;

END DMT_EGP_ITEM_FBDI_GEN_PKG;
/
