 --  This control file loads projects data from a CSV file into a staging/interface table GMS_AWD_PRJ_FND_SRC_INT. 
           --  The csv can be generated using the ImportAwardsTemplate.xlsm file. The sequence of columns in CSV is 
           --  defined as per following order. Please do not modify the column order.
           --  For local testing, you need to comment out some of the columns. Please refer below for more info.
  
  LOAD DATA
  	INFILE GmsAwardPrjFundSrcInterface.csv
     	APPEND
     	INTO TABLE GMS_AWD_PRJ_FND_SRC_INT
   	FIELDS TERMINATED BY ','
   	OPTIONALLY ENCLOSED BY '"'
      	TRAILING NULLCOLS
   		( 	AWD_PRJ_FND_SRC_INTERFACE_ID 	expression "GMS_AWD_PRJ_FND_SRC_INT_S.nextval",
   			AWARD_NUMBER char(300),
   			PROJECT_NUMBER,
   			FUNDING_SOURCE_NAME char(360),
   			FUNDING_SOURCE_NUMBER,
                        ENABLE_BURDENING_FLAG,
                        LOAD_REQUEST_ID              CONSTANT  '#LOADREQUESTID#',
   			OBJECT_VERSION_NUMBER        CONSTANT  1,
   			CREATION_DATE                expression "systimestamp"         ,  
   			LAST_UPDATE_DATE             expression "systimestamp",
   			CREATED_BY                constant    '#CREATEDBY#' ,
   			LAST_UPDATED_BY           constant    '#LASTUPDATEDBY#',
   			LAST_UPDATE_LOGIN         constant    '#LASTUPDATELOGIN#'
   		)
