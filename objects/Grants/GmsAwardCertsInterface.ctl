		 --  This control file loads projects data from a CSV file into a staging/interface table GMS_AWARD_CERTS_INT. 
         --  The csv can be generated using the ImportAwardsTemplate.xlsm file. The sequence of columns in CSV is 
         --  defined as per following order. Please do not modify the column order.
         --  For local testing, you need to comment out some of the columns. Please refer below for more info.

LOAD DATA
	INFILE GmsAwardCertsInterface.csv
   	APPEND
   	INTO TABLE GMS_AWARD_CERTS_INT
	FIELDS TERMINATED BY ','
	OPTIONALLY ENCLOSED BY '"'
   	TRAILING NULLCOLS
		( 	AWARD_CERT_INTERFACE_ID 	expression "GMS_AWARD_CERTS_INTERFACE_S.nextval",
			AWARD_NUMBER char(300),
			PROJECT_NUMBER,
			CERTIFICATION_NAME,
			CERTIFICATION_DATE 			"to_date(:CERTIFICATION_DATE,'MM/DD/YYYY')",
			CERTIFIED_BY,
			STATUS,
			APPROVAL_DATE				"to_date(:APPROVAL_DATE,'MM/DD/YYYY')",
			EXPIRATION_DATE				"to_date(:EXPIRATION_DATE,'MM/DD/YYYY')",
			EXPEDITED_REVIEW,
			FULL_REVIEW,
			ASSURANCE_NUMBER,
			EXEMPTION_NUMBER,
			COMMENTS char(4000),
                        LOAD_REQUEST_ID              CONSTANT  '#LOADREQUESTID#',
			OBJECT_VERSION_NUMBER        CONSTANT  1,
			CREATION_DATE                expression "systimestamp"         ,  
			LAST_UPDATE_DATE             expression "systimestamp",
			CREATED_BY                constant    '#CREATEDBY#' ,
			LAST_UPDATED_BY           constant    '#LASTUPDATEDBY#',
			LAST_UPDATE_LOGIN         constant    '#LASTUPDATELOGIN#'
		)
