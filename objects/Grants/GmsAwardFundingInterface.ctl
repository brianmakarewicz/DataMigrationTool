		 --  This control file loads funding data from a CSV file into a staging/interface table GMS_AWARD_FUNDING_INT. 
         --  The csv can be generated using the ImportAwardsTemplate.xlsm file. The sequence of columns in CSV is 
         --  defined as per following order. Please do not modify the column order.
         --  For local testing, you need to comment out some of the columns. Please refer below for more info.

LOAD DATA
	INFILE GmsAwardFundingInterface.csv
   	APPEND
   	INTO TABLE GMS_AWARD_FUNDING_INT
	FIELDS TERMINATED BY ','
	OPTIONALLY ENCLOSED BY '"'
   	TRAILING NULLCOLS
		( 	AWARD_FUNDING_INTERFACE_ID			expression "GMS_AWARD_FUNDING_INTERFACE_S.nextval",
			AWARD_NUMBER char(300),
			BUDGET_PERIOD_NAME,
			FUNDING_SOURCE_NAME char(360),			
			ISSUE_TYPE,			
			ISSUE_NUMBER,
			ISSUE_DATE					"to_date(:ISSUE_DATE,'MM/DD/YYYY')",			
			ISSUE_DESCRIPTION,
			DIRECT_FUNDING_AMOUNT,
			INDIRECT_FUNDING_AMOUNT,
                        FUNDING_SOURCE_NUMBER,
                        LOAD_REQUEST_ID              CONSTANT  '#LOADREQUESTID#',
			OBJECT_VERSION_NUMBER        CONSTANT  1,
			CREATION_DATE                expression "systimestamp"         ,  
			LAST_UPDATE_DATE             expression "systimestamp",
			CREATED_BY                constant    '#CREATEDBY#' ,
			LAST_UPDATED_BY           constant    '#LASTUPDATEDBY#',
			LAST_UPDATE_LOGIN         constant    '#LASTUPDATELOGIN#'
		)
