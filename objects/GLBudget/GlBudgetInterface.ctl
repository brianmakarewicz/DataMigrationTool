LOAD DATA
append

INTO TABLE gl_budget_interface
fields terminated by ',' optionally enclosed by '"' trailing nullcols
(CREATION_DATE                  expression "systimestamp"
,LAST_UPDATE_DATE               expression "systimestamp"
,OBJECT_VERSION_NUMBER          constant 1
,CREATED_BY                     constant '#CREATEDBY#'
,LAST_UPDATED_BY                constant '#LASTUPDATEDBY#'
,LAST_UPDATE_LOGIN              constant '#LASTUPDATELOGIN#'
,LOAD_REQUEST_ID                constant '#LOADREQUESTID#'
,RUN_NAME
,STATUS
,LEDGER_ID                      "fun_load_interface_utils_pkg.replace_decimal_char(:LEDGER_ID)"
,BUDGET_NAME
,PERIOD_NAME
,CURRENCY_CODE
,SEGMENT1
,SEGMENT2
,SEGMENT3
,SEGMENT4
,SEGMENT5
,SEGMENT6
,SEGMENT7
,SEGMENT8
,SEGMENT9
,SEGMENT10
,SEGMENT11
,SEGMENT12
,SEGMENT13
,SEGMENT14
,SEGMENT15
,SEGMENT16
,SEGMENT17
,SEGMENT18
,SEGMENT19
,SEGMENT20
,SEGMENT21
,SEGMENT22
,SEGMENT23
,SEGMENT24
,SEGMENT25
,SEGMENT26
,SEGMENT27
,SEGMENT28
,SEGMENT29
,SEGMENT30
,BUDGET_AMOUNT                  "fun_load_interface_utils_pkg.replace_decimal_char(:BUDGET_AMOUNT)"
,LEDGER_NAME
)
