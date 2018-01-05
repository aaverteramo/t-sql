DECLARE
	 @TABLE_SCHEMA SYSNAME = 'dbo'
	,@TABLE_NAME SYSNAME = 'Member'
	,@Fields_Request NVARCHAR(MAX) = N''
	,@Fields_Result NVARCHAR(MAX) = N'public string Action { get; set; }'+CHAR(13)
	,@Fields_Result_Inserted NVARCHAR(MAX) = N''
	,@Fields_Result_Deleted NVARCHAR(MAX) = N''
	,@Default_SharpType VARCHAR = ''

;WITH TypeConversion AS (
	SELECT *
	FROM (
		VALUES
		 ('bigint', 'long', 1)
		,('binary', 'byte[]', 1)
		,('bit', 'bool', 1)
		,('char', 'char', 0)
		,('date', 'DateTime', 1)
		,('datetime', 'DateTime', 1)
		,('datetime2', 'DateTime', 1)
		,('datetimeoffset', 'DateTimeOffset', 1)
		,('decimal', 'decimal', 1)
		,('float', 'double', 1)
		,('geography', @Default_SharpType, 0)
		,('geometry', @Default_SharpType, 0)
		,('hierarchyid', @Default_SharpType, 0)
		,('image', @Default_SharpType, 0)
		,('int', 'int', 1)
		,('money', 'decimal', 1)
		,('nchar', 'char', 0)
		,('ntext', 'string', 0)
		,('numeric', 'decimal', 1)
		,('nvarchar', 'string', 0)
		,('real', 'float', 1)
		,('smalldatetime', 'DateTime', 1)
		,('smallint', 'short', 1)
		,('smallmoney', 'decimal', 1)
		,('sql_variant', 'object', 0)
		,('sysname', 'string', 0)
		,('text', 'string', 0)
		,('time', 'TimeSpan', 1)
		,('timestamp', 'byte[]', 1)
		,('tinyint', 'byte', 1)
		,('uniqueidentifier', 'Guid', 1)
		,('varbinary', 'byte[]', 1)
		,('varchar', 'string', 0)
		,('xml', @Default_SharpType, 1)
	) AS [TypeConversion] (
		 SqlType
		,SharpType
		,IsValueType
	)
),
Fields AS (
	SELECT
		 t.TABLE_SCHEMA
		,t.TABLE_NAME
		,c.COLUMN_NAME
		,c.ORDINAL_POSITION
		,c.DATA_TYPE
		,c.IS_NULLABLE
		,tc.IsValueType
		,tc.SharpType
		,tc.SharpType+(CASE WHEN tc.IsValueType = 1 THEN '?' ELSE '' END) AS [SharpTypeNullable]
	FROM INFORMATION_SCHEMA.TABLES t
	JOIN INFORMATION_SCHEMA.COLUMNS c ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
	JOIN TypeConversion tc ON tc.SqlType = c.DATA_TYPE
	WHERE t.TABLE_SCHEMA = @TABLE_SCHEMA
	AND t.TABLE_NAME = @TABLE_NAME
)

SELECT
	 @Fields_Request += 'public '+(CASE WHEN IS_NULLABLE = 'YES' THEN SharpTypeNullable ELSE SharpType END)+' '+COLUMN_NAME+' { get; set; }'+CHAR(13)
	,@Fields_Result_Inserted += 'public '+SharpTypeNullable+' INSERTED_'+COLUMN_NAME+' { get; set; }'+CHAR(13)
	,@Fields_Result_Deleted += 'public '+SharpTypeNullable+' DELETED_'+COLUMN_NAME+' { get; set; }'+CHAR(13)
FROM Fields
ORDER BY
	 ORDINAL_POSITION

SET @Fields_Result += @Fields_Result_Inserted + @Fields_Result_Deleted

SELECT
	 @Fields_Request AS [@Fields_Request]
	,@Fields_Result AS [@Fields_Result]