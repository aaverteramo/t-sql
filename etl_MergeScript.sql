DECLARE
	 @DBName SYSNAME = 'Ascend_OR_Demo'
	,@SchemaName SYSNAME = 'Provider'
	,@TableName SYSNAME = 'NonCompliance'
	,@UseSourceDB SYSNAME = NULL
	,@UseTableParam BIT = 1
	,@UpdateWhenChanged BIT = 0
	,@IncludeDelete BIT = 0
	,@UpdatePK BIT = 1

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
--Check DBName
SET @DBName = ISNULL(NULLIF(@DBName, ''''), DB_NAME())

DECLARE
	 @Result NVARCHAR(MAX)
	,@TargetTable SYSNAME
	,@HasIdentity BIT
	,@SourceColumnsSelect NVARCHAR(MAX)
	,@ColumnsJoin NVARCHAR(MAX)
	,@ColumnsInsert NVARCHAR(MAX)
	,@ColumnsUpdate NVARCHAR(MAX)
	,@ColumnsChanged NVARCHAR(MAX)
	,@ColumnsTargetInsert NVARCHAR(MAX)
	,@ColumnsOutputInsert NVARCHAR(MAX)
	,@ColumnsOutputDelete NVARCHAR(MAX)
	,@ColumnsOutput NVARCHAR(MAX)
	,@SQLParam NVARCHAR(MAX) = N'
	 @ResultOUT NVARCHAR(MAX) OUTPUT
	,@TargetTable SYSNAME OUTPUT
    ,@HasIdentity BIT OUTPUT
	,@SourceColumnsSelect NVARCHAR(MAX) OUTPUT
	,@ColumnsJoin NVARCHAR(MAX) OUTPUT
	,@ColumnsInsert NVARCHAR(MAX) OUTPUT
	,@ColumnsUpdate NVARCHAR(MAX) OUTPUT
	,@ColumnsChanged NVARCHAR(MAX) OUTPUT
	,@ColumnsTargetInsert NVARCHAR(MAX) OUTPUT
	,@ColumnsOutputInsert NVARCHAR(MAX) OUTPUT
	,@ColumnsOutputDelete NVARCHAR(MAX) OUTPUT
	,@ColumnsOutput NVARCHAR(MAX) OUTPUT'
	,@SQL NVARCHAR(MAX) = N'DECLARE
	 --Params
	 @Execute BIT = 0
	,@SchemaName SYSNAME = '''+@SchemaName+'''
	,@TableName SYSNAME = '''+@TableName+'''
	,@UseTableParam BIT = 1
	,@UpdateWhenChanged BIT = 1
	,@IncludeDelete BIT = 0
	 --Variables
	,@SQL NVARCHAR(MAX) = ''BEGIN TRANSACTION;''+CHAR(13)
SELECT
	 @TargetTable = ''''
	,@SourceColumnsSelect = ''''
	,@ColumnsTargetInsert = ''''
	,@ColumnsInsert = ''''
	,@ColumnsUpdate = ''''
	,@ColumnsJoin = ''''
	,@ColumnsChanged = ''''
	,@ColumnsOutputInsert = ''''
	,@ColumnsOutputDelete = ''''
	,@ColumnsOutput = ''''

;WITH rawData AS (
	SELECT
		 s.schema_id
		,t.object_id
		,c.column_id
		,s.name AS [SchemaName]
		,t.name AS [TableName]
		,''['+@DBName+']''+''.''+QUOTENAME(s.name)+''.''+QUOTENAME(t.name) AS [FullTableName]
		,c.name AS [ColumnName]
		,c.is_nullable AS [Nullable]
		--,CASE WHEN pk.object_id IS NOT NULL THEN 1 ELSE 0 END AS [IsIdentity]
		,CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 1 ELSE 0 END AS [PKColumn]
		,CASE WHEN i.object_id IS NOT NULL THEN 1 ELSE 0 END AS [HasIdentity]
		,(CASE
			--0
			  WHEN ct.name IN (
			  ''bigint''
			 ,''binary''
			 ,''bit''
			 ,''date''
			 ,''datetime''
			 ,''datetime2''
			 ,''decimal''
			 ,''float''
			 ,''int''
			 ,''money''
			 ,''numeric''
			 ,''real''
			 ,''smalldatetime''
			 ,''smallint''
			 ,''smallmoney''
			 ,''sql_variant''
			 ,''time''
			 ,''timestamp''
			 ,''tinyint''
			 ,''uniqueidentifier''
			 ,''varbinary'') THEN ''0''
			--''''
			  WHEN ct.name IN (
			  ''char''
			 ,''nchar''
			 ,''ntext''
			 ,''nvarchar''
			 ,''sysname''
			 ,''text''
			 ,''varchar''
			 ,''xml'') THEN ''''''''''''
			--NULL
			  WHEN ct.name IN (
			  ''datetimeoffset''
			 ,''geography''
			 ,''geometry''
			 ,''hierarchyid''
			 ,''image'') THEN ''NULL''
			  ELSE ''NULL'' END) AS [DefaultValue]
	FROM ['+@DBName+'].sys.schemas s
	JOIN ['+@DBName+'].sys.tables t ON t.schema_id = s.schema_id
	JOIN ['+@DBName+'].sys.columns c ON c.object_id = t.object_id
	JOIN ['+@DBName+'].sys.types ct ON ct.user_type_id = c.user_type_id
	LEFT JOIN (
		SELECT
			 tc.TABLE_SCHEMA
			,tc.TABLE_NAME
			,kc.COLUMN_NAME
		FROM ['+@DBName+'].INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
		JOIN ['+@DBName+'].INFORMATION_SCHEMA.KEY_COLUMN_USAGE kc ON kc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
		WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''
	) pk ON pk.TABLE_NAME = t.name AND pk.COLUMN_NAME = c.name
	LEFT JOIN (
		SELECT
			 c.object_id
		FROM ['+@DBName+'].sys.identity_columns c
		GROUP BY
			 c.object_id
	) i ON i.object_id = t.object_id
)

SELECT
	 @TargetTable = FullTableName
    ,@HasIdentity = HasIdentity
	,@SourceColumnsSelect += CHAR(13)+CHAR(9)+ColumnName+'',''
	,@ColumnsJoin += (CASE WHEN PKColumn = 1 THEN ''SOURCE.[''+ColumnName+''] = TARGET.[''+ColumnName+''] AND '' ELSE '''' END)
	,@ColumnsInsert += '+(CASE WHEN @UpdatePK = 1 THEN 'CHAR(13)+CHAR(9)+CHAR(9)+''SOURCE.[''+ColumnName+''],''' ELSE '(CASE WHEN PKColumn = 0 THEN CHAR(13)+CHAR(9)+CHAR(9)+''SOURCE.[''+ColumnName+''],'' ELSE '''' END)' END)+'
	,@ColumnsUpdate += (CASE WHEN PKColumn = 0 THEN CHAR(13)+CHAR(9)+ColumnName+'' = SOURCE.[''+ColumnName+''],'' ELSE '''' END)
	,@ColumnsChanged +=
		(CASE WHEN @UpdateWhenChanged = 1 AND PKColumn = 0 THEN
			(CASE WHEN [Nullable] = 1 THEN ''ISNULL('' ELSE '''' END)+''TARGET.[''+ColumnName+'']''+(CASE WHEN [Nullable] = 1 THEN '', ''+[DefaultValue]+'')'' ELSE '''' END)+'' != SOURCE.[''+ColumnName+''] OR ''
		 ELSE '''' END)
	,@ColumnsTargetInsert += '+(CASE WHEN @UpdatePK = 1 THEN 'CHAR(13)+CHAR(9)+CHAR(9)+ColumnName+'',''' ELSE '(CASE WHEN PKColumn = 0 THEN CHAR(13)+CHAR(9)+CHAR(9)+ColumnName+'','' ELSE '''' END)' END)+'
	,@ColumnsOutputInsert += CHAR(13)+CHAR(9)+'',INSERTED.[''+ColumnName+''] AS [INSERTED_''+ColumnName+'']''
	,@ColumnsOutputDelete += CHAR(13)+CHAR(9)+'',DELETED.[''+ColumnName+''] AS [DELETED_''+ColumnName+'']''
FROM rawData
WHERE SchemaName = @SchemaName
AND TableName = @TableName'

EXEC sp_executesql
	 @SQL
	,@SQLParam
	,@ResultOUT = @Result OUTPUT
	,@TargetTable = @TargetTable OUTPUT
    ,@HasIdentity = @HasIdentity OUTPUT
	,@SourceColumnsSelect = @SourceColumnsSelect OUTPUT
	,@ColumnsJoin = @ColumnsJoin OUTPUT
	,@ColumnsInsert = @ColumnsInsert OUTPUT
	,@ColumnsUpdate = @ColumnsUpdate OUTPUT
	,@ColumnsChanged = @ColumnsChanged OUTPUT
	,@ColumnsTargetInsert = @ColumnsTargetInsert OUTPUT
	,@ColumnsOutputInsert = @ColumnsOutputInsert OUTPUT
	,@ColumnsOutputDelete = @ColumnsOutputDelete OUTPUT
	,@ColumnsOutput = @ColumnsOutput OUTPUT

SELECT
	 @SQL = N'
DECLARE
     @Execute BIT = 0

BEGIN TRANSACTION;'+CHAR(13)+CHAR(13)
	,@SourceColumnsSelect = LEFT(@SourceColumnsSelect, LEN(@SourceColumnsSelect) - 1)
	,@ColumnsJoin = LEFT(@ColumnsJoin, LEN(@ColumnsJoin) - 4)
    ,@ColumnsInsert = LEFT(@ColumnsInsert, LEN(@ColumnsInsert) - 1)
	,@ColumnsUpdate = LEFT(@ColumnsUpdate, LEN(@ColumnsUpdate) - 1)
	,@ColumnsTargetInsert = LEFT(@ColumnsTargetInsert, LEN(@ColumnsTargetInsert) - 1)
	,@ColumnsOutput = @ColumnsOutputInsert+@ColumnsOutputDelete
	,@ColumnsChanged = (CASE WHEN @UpdateWhenChanged = 1 THEN LEFT(@ColumnsChanged, LEN(@ColumnsChanged) - 3) ELSE @ColumnsChanged END)

SET @SQL += (CASE WHEN @HasIdentity = 1 THEN 'SET IDENTITY_INSERT '+@TargetTable+' ON;'+CHAR(13)+CHAR(13) ELSE '' END)
          + 'MERGE INTO '+@TargetTable+' AS TARGET'+CHAR(13)
		  + 'USING '
		  + (CASE WHEN NULLIF(@UseSourceDB, '') IS NOT NULL THEN REPLACE(@TargetTable, @DBName, @UseSourceDB) + ' AS SOURCE'
			 ELSE
		  +'('+CHAR(13)
		  + (CASE
				WHEN @UseTableParam = 1 THEN CHAR(9)+'SELECT'+@SourceColumnsSelect+CHAR(13)+CHAR(9)+'FROM @DataValues'
				ELSE CHAR(9)+CHAR(9)+'VALUES'+CHAR(13)+CHAR(9)+'[REPLACEWITHVALUE]'
				END)+CHAR(13)
		  + ') AS SOURCE ('+@SourceColumnsSelect+CHAR(13)+')'
			 END )+CHAR(13)
		  + 'ON '+@ColumnsJoin+CHAR(13)
		  + 'WHEN NOT MATCHED THEN'+CHAR(13)
		  + CHAR(9)+'INSERT ('+@ColumnsTargetInsert+CHAR(13)
          + CHAR(9)+')'+CHAR(13)
		  + CHAR(9)+'VALUES ('+@ColumnsInsert+CHAR(13)
          + CHAR(9)+')'+CHAR(13)
		  + 'WHEN MATCHED'+(CASE WHEN @UpdateWhenChanged = 1 THEN ' AND ('+@ColumnsChanged+')' ELSE '' END)+' THEN'+CHAR(13)
		  + 'UPDATE SET'+@ColumnsUpdate+CHAR(13)
		  + 'OUTPUT'+CHAR(13)+CHAR(9)+' $ACTION AS [Action]'+@ColumnsOutput+';'+CHAR(13)+CHAR(13)
          + (CASE WHEN @HasIdentity = 1 THEN 'SET IDENTITY_INSERT '+@TargetTable+' OFF;'+CHAR(13)+CHAR(13) ELSE '' END)
		  --TRANSACTION: END
		  + 'IF (@Execute = 1)'+CHAR(13)
          + 'BEGIN'+CHAR(13)
          + '  COMMIT TRANSACTION;'+CHAR(13)
          + 'END'+CHAR(13)
          + 'ELSE IF (@Execute = 0)'+CHAR(13)
          + 'BEGIN'+CHAR(13)
          + '  ROLLBACK TRANSACTION;'+CHAR(13)
          + 'END'+CHAR(13)

SELECT @SQL AS [Script]

COMPLETED: