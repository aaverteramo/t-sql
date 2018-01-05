USE eXpediteOR
GO
/*====================================================================
| RESEED TABLE
====================================================================*/
DECLARE
	 @TABLE_SCHEMA SYSNAME = 'dbo'
	,@TABLE_NAME SYSNAME = 'SearchTable'
--====================================================================
DECLARE
	 @COLUMN_NAME SYSNAME
SELECT
	 @COLUMN_NAME = c.name
FROM sys.schemas s
JOIN sys.tables t ON t.schema_id = s.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
WHERE s.name = @TABLE_SCHEMA
AND t.name = @TABLE_NAME
AND c.is_identity = 1

DECLARE
	 @Seed INT
	,@SQLParams NVARCHAR(MAX) = N'
		@Seed INT OUTPUT'
	,@SQL NVARCHAR(MAX) = N'
SELECT
	 @Seed = ISNULL(MAX('+@COLUMN_NAME+'), 0)
FROM '+@TABLE_NAME

EXEC sp_executesql
	 @SQL
	,@Params = @SQLParams
	,@Seed = @Seed OUTPUT

SET @SQL = N'
DBCC CHECKIDENT ('''+@TABLE_SCHEMA+'.'+@TABLE_NAME+''', RESEED, '+CAST(@Seed AS VARCHAR)+')
'
EXEC sp_executesql @SQL