DECLARE @Identities TABLE (
	 [DBName] NVARCHAR(200)
	,[TableName] NVARCHAR(200)
	,[Identity] NVARCHAR(200)
)
DECLARE
	 @SQL NVARCHAR(MAX) =N'
SELECT
	 ''[@DBNameExpedite]''
	,dbo.GetFormattedTableNames(s.name+''.''+t.name)
	,i.name
FROM [@DBNameExpedite].sys.schemas s
JOIN [@DBNameExpedite].sys.tables t ON t.schema_id = s.schema_id
JOIN [@DBNameExpedite].sys.identity_columns i ON i.object_id = t.object_id
UNION
SELECT
	 ''[@DBNameOther]''
	,dbo.GetFormattedTableNames(s.name+''.''+t.name)
	,i.name
FROM [@DBNameOther].sys.schemas s
JOIN [@DBNameOther].sys.tables t ON t.schema_id = s.schema_id
JOIN [@DBNameOther].sys.identity_columns i ON i.object_id = t.object_id'
SELECT
	 @SQL = REPLACE(@SQL, '[@DBName'+t.Name+']', e.DatabaseName)
FROM dbo.[Endpoint] e
JOIN dbo.[EndpointType] t ON t.EndpointTypeID = e.EndpointTypeID

INSERT INTO @Identities (
	 [DBName]
	,[TableName]
	,[Identity]
)
EXEC sp_executesql @SQL



SELECT *
FROM dbo.[Endpoint] e
JOIN dbo.[EndpointType] t ON t.EndpointTypeID = e.EndpointTypeID
LEFT JOIN [EndpointTable] et ON et.EndpointID = e.EndpointID
LEFT JOIN [TableType] tt ON tt.TableTypeID = et.TableTypeID
LEFT JOIN @Identities i ON i.DBName = e.DatabaseName AND i.TableName = dbo.GetFormattedTableNames(et.Name)