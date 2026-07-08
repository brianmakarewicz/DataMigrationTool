-- +=========================================================================+
-- | CstIIncomingTxnCosts.ctl                                                |
-- +=========================================================================+
-- | Copyright (c) 2012 Oracle Corporation Redwood City, California, USA     |
-- | All rights reserved.                                                    |
-- |=========================================================================+
-- |                                                                         |
-- | DESCRIPTION                                                             |
-- |   Uploads CSV file data into CST_I_INCOMING_TXN_COSTS                   |
-- |                                                                         |
-- | Source: Oracle FBDI Template 25D                                        |
-- |   InventoryTransactionImportTemplate.xlsm                               |
-- |   Worksheet: CST_I_INCOMING_TXN_COSTS                                   |
-- |                                                                         |
-- | Column positions extracted from FBDI template row 4 (3 columns)         |
-- |                                                                         |
-- +=========================================================================+

LOAD DATA
APPEND
INTO TABLE CST_I_INCOMING_TXN_COSTS
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
 LAST_UPDATE_DATE             EXPRESSION "SYSTIMESTAMP",
 LAST_UPDATED_BY              CONSTANT   '#LASTUPDATEDBY#',
 CREATION_DATE                EXPRESSION "SYSTIMESTAMP",
 CREATED_BY                   CONSTANT   '#CREATEDBY#',
 LAST_UPDATE_LOGIN            CONSTANT   '#LASTUPDATELOGIN#',
 LOAD_REQUEST_ID              CONSTANT   '#LOADREQUESTID#',
 TRANSACTION_COST_IDENTIFIER             ,
 COST_COMPONENT_CODE                     ,
 COST                                    "fun_load_interface_utils_pkg.replace_decimal_char(:COST)",
 OBJECT_VERSION_NUMBER          CONSTANT  1
)
