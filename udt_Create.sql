DECLARE
	 @DBName SYSNAME = 'Ascend_OR_demo'
	,@SchemaName SYSNAME = 'Provider'
	,@TargetDBName SYSNAME = 'eXpediteETLOR'
    ,@TableName SYSNAME = 'NonCompliance'
    ,@TargetSchemaName SYSNAME = 'ascend'

SET NOCOUNT ON;

--Check params
IF (NULLIF(REPLACE(@SchemaName, ' ', ''), '') IS NULL)
BEGIN
	RAISERROR('@SchemaName required.', 16, 1)
	GOTO COMPLETED
END
IF (NULLIF(REPLACE(@TableName, ' ', ''), '') IS NULL)
BEGIN
	RAISERROR('@TableName required.', 16, 1)
	GOTO COMPLETED
END
IF (NULLIF(REPLACE(@TargetSchemaName, ' ', ''), '') IS NULL)
BEGIN
	RAISERROR('@TargetSchemaName required.', 16, 1)
	GOTO COMPLETED
END
--Check DBName
SET @DBName = ISNULL(NULLIF(@DBName, ''''), DB_NAME())
--SELECT @DBName

DECLARE
     @SQL NVARCHAR(MAX)
--Check Schema
IF NOT EXISTS (SELECT TOP 1 NULL FROM sys.schemas WHERE name = @TargetSchemaName)
BEGIN
    SET @SQL = 'CREATE SCHEMA ['+@TargetSchemaName+'];'
    EXEC sp_executesql @SQL
END

DECLARE
	 @Result NVARCHAR(MAX) = N''
	,@Fields NVARCHAR(MAX) = N''
	,@SQLParam NVARCHAR(100) = N'@ResultOUT NVARCHAR(MAX) OUTPUT, @FieldsOUT NVARCHAR(MAX) OUTPUT'
SET @SQL = N'
DECLARE
     @TableName SYSNAME = '''+@TableName+'''
	,@SchemaName SYSNAME = '''+@SchemaName+'''
	,@TargetDBName SYSNAME = '''+@TargetDBName+'''
    ,@TargetSchemaName SYSNAME = '''+@TargetSchemaName+'''
    ,@SQL NVARCHAR(MAX) = N''''
	,@SQLDrop NVARCHAR(MAX) = N''''

SELECT
	 @SQL += N'','' + NCHAR(13) + NCHAR(10) + NCHAR(9) + N''['' + c.COLUMN_NAME + N''] ['' + DATA_TYPE + N'']''
           + CASE WHEN c.CHARACTER_MAXIMUM_LENGTH is not null THEN N''('' + CASE c.CHARACTER_MAXIMUM_LENGTH WHEN -1 THEN ''MAX'' ELSE cast(c.CHARACTER_MAXIMUM_LENGTH AS nvarchar(10)) end + N'')'' ELSE N'''' END
           + CASE WHEN c.DATA_TYPE = N''numeric'' THEN N''(''+CAST(NUMERIC_PRECISION AS nvarchar(10))+N'', ''+CAST(NUMERIC_SCALE AS NVARCHAR(10))+N'')'' ELSE N'''' END
           + CASE WHEN c.is_nullable <> N''NO'' THEN N'' NULL'' ELSE N'' NOT NULL''END
    ,@FieldsOUT += c.COLUMN_NAME+''|''+c.DATA_TYPE+''|''+c.IS_NULLABLE+'',''
FROM ['+@DBName+'].INFORMATION_SCHEMA.COLUMNS c
WHERE TABLE_NAME = @TableName AND TABLE_SCHEMA = @SchemaName
ORDER BY
	 ORDINAL_POSITION

SET @SQLDrop += ''USE [''+@TargetDBName+'']''+NCHAR(13)
			  + ''--GO''+CHAR(13)+Char(13)
			  + ''IF EXISTS (SELECT NULL FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N''''udt_'' + @TableName + N'''''' AND ss.name = ''''''+ @TargetSchemaName +'''''')''
			  + ''DROP TYPE ['' + @TargetSchemaName + N''].[udt_'' + @TableName + N''] ''+ NCHAR(13) + NCHAR(10)
			  + NCHAR(13) + NCHAR(10) + ''--GO''+ NCHAR(13) + NCHAR(10)
SET @SQL = STUFF(@SQL, 1, 1, N''CREATE TYPE ['' + @TargetSchemaName + N''].[udt_'' + @TableName + N''] AS TABLE('')
         + NCHAR(13) + NCHAR(10) + '')'' + NCHAR(13) + NCHAR(10) + ''--GO''

SET @ResultOUT = @SQLDrop + @SQL
SET @FieldsOUT = LEFT(@FieldsOUT, LEN(@FieldsOUT) - 1)
'
--SELECT @SQL
EXEC sp_executesql
	 @SQL
	,@SQLParam
	,@ResultOUT = @Result OUTPUT
    ,@FieldsOUT = @Fields OUTPUT

--SET @Result = N'USE ['+@DBName+']'+NCHAR(13)+NCHAR(10)+'--GO'+NCHAR(13)+NCHAR(10) + @Result

SELECT @Result AS [Script], @Fields AS [FieldsRaw]

COMPLETED: