USE eXpediteOR
GO

DECLARE
	 @TARGET_DB SYSNAME = 'Ascend_OR_Demo'
	,@TARGET_SCHEMA SYSNAME = 'eXpedite'
	,@CONSTRAINT_DB SYSNAME = 'eXpediteOR'
	,@COLUMN_NAME SYSNAME = 'LanguageGenId'
	,@PRIMARY_ONLY BIT = 1

;WITH CONSTRAINT_KEYS AS (
	SELECT
		 k.CONSTRAINT_CATALOG
		,k.CONSTRAINT_SCHEMA
		,k.CONSTRAINT_NAME
		,k.TABLE_CATALOG
		,k.TABLE_SCHEMA
		,k.TABLE_NAME
	FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE k
	JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS c ON c.CONSTRAINT_CATALOG = k.CONSTRAINT_CATALOG AND c.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA AND c.CONSTRAINT_NAME = k.CONSTRAINT_NAME
	WHERE k.CONSTRAINT_CATALOG = @CONSTRAINT_DB
	AND k.COLUMN_NAME = @COLUMN_NAME
	AND (@PRIMARY_ONLY = 0 OR c.CONSTRAINT_TYPE = 'PRIMARY KEY')
),
CONSTRAINT_KEY_FIELDS AS (
	SELECT
		 k.*
		,STUFF(( 
			SELECT ','+ cast(ky.COLUMN_NAME AS SYSNAME) 
			FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE ky
			WHERE ky.CONSTRAINT_CATALOG = k.CONSTRAINT_CATALOG
			AND ky.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
			AND ky.CONSTRAINT_NAME = k.CONSTRAINT_NAME
			ORDER BY
				 ORDINAL_POSITION
			FOR XML PATH('') 
			) 
			,1,1,'') AS [Fields]
	FROM CONSTRAINT_KEYS k
),
CONSTRAINT_SCRIPT AS (
	SELECT
'ALTER TABLE ['+@TARGET_DB+'].['+@TARGET_SCHEMA+'].['+f.TABLE_NAME+']
DROP CONSTRAINT ['+f.CONSTRAINT_NAME+']
ALTER TABLE ['+@TARGET_DB+'].['+@TARGET_SCHEMA+'].['+f.TABLE_NAME+']
ADD CONSTRAINT ['+f.CONSTRAINT_NAME+'] PRIMARY KEY ('+f.Fields+')
' AS [Script]
	FROM CONSTRAINT_KEY_FIELDS f
)

SELECT *
FROM CONSTRAINT_SCRIPT

--ALTER TABLE [Ascend_OR_Demo].[eXpedite].[NonBinaryGridData]
--DROP CONSTRAINT [PK_NonBinaryGridData]
--ALTER TABLE [Ascend_OR_Demo].[eXpedite].[NonBinaryGridData]
--ADD CONSTRAINT [PK_NonBinaryGridData] PRIMARY KEY (TaskGenId, DeviceGenId, BindingVariableGenId, RowNumber, LanguageGenId)