USE RCCSOK
GO
/* Generate ALTER INDEX scripts to REBUILD or REORGANIZE all indexes in a specified DB.
--Resource citations:
--	Detect fragmentation:	https://msdn.microsoft.com/en-us/library/ms189858.aspx#Fragmentation
--	t-sql Syntax on alter index: https://msdn.microsoft.com/en-us/library/ms189858.aspx#TsqlProcedureReorg
*/
DECLARE @DBNAME NVARCHAR(128), @RebuildAll BIT, @SQL NVARCHAR(MAX)
SELECT 
	 @DBNAME = 'RCCSOK'
	,@RebuildAll = 0


IF @RebuildAll = 1
BEGIN
	SET @SQL = N'USE ['+@DBNAME+']'+CHAR(13)
			   +'GO'+CHAR(13)
			   +'EXEC sp_MSforeachtable @command1="PRINT ''?'' ALTER INDEX ALL ON ? REBUILD-- WITH (ONLINE=OFF, FILLFACTOR=80)"'+CHAR(13)
			   +'GO'+CHAR(13)
			   +'EXEC sp_updatestats'+CHAR(13)
			   +'GO'+CHAR(13)
END
ELSE
BEGIN
	SET @SQL = N'USE ['+@DBNAME+'];'+CHAR(13)--+'GO'+CHAR(13)

	;WITH CorrectiveActions AS (
		SELECT
			 sc.schema_id
			,sc.name AS [SchemaName]
			,o.object_id
			,o.name AS [TableName]
			,s.index_id
			,'['+x.name+']' AS [IndexName]
			,s.avg_fragmentation_in_percent
			,CASE 
				WHEN s.avg_fragmentation_in_percent > 5 AND avg_fragmentation_in_percent <= 30 THEN 'REORGANIZE'
				WHEN s.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
				--WHEN s.avg_fragmentation_in_percent > 30 AND offl.object_id IS NOT NULL THEN 'REBUILD' 
				--WHEN s.avg_fragmentation_in_percent > 30 AND offl.object_id IS NULL THEN 'REBUILD WITH(ONLINE = ON)' 
			 END AS [CorrectiveStatement]
			,'['+@DBNAME+'].['+sc.name+'].['+o.name+']' AS [FullTableName]
	
			--,*
		FROM sys.dm_db_index_physical_stats(DB_ID(@DBNAME), 0, -1, 0, NULL) s
		JOIN sys.objects o ON o.object_id = s.object_id
		JOIN sys.schemas sc ON sc.schema_id = o.schema_id
		JOIN sys.indexes x ON x.object_id = s.object_id AND x.index_id = s.index_id
		LEFT JOIN (
			SELECT 
				 xc.object_id
				,index_id
			FROM sys.index_columns xc
			JOIN sys.columns col ON col.object_id = xc.object_id AND col.column_id = xc.column_id
			JOIN sys.types t ON t.system_type_id = col.system_type_id AND t.user_type_id = col.user_type_id
			WHERE t.name IN ('text', 'ntext', 'image', 'varbinary')
			GROUP BY
				 xc.object_id
				,index_id
		) offl ON offl.object_id = x.object_id AND offl.index_id = x.index_id
		--WHERE s.avg_fragmentation_in_percent > 0
		WHERE s.avg_fragmentation_in_percent > 5 -- Fragmentation should be > 5% in order to take action.
		AND s.index_id > 0 -- Total Fragmentation for the object_id.
	)


	SELECT @SQL = @SQL + 'ALTER INDEX '+a.IndexName+' ON '+a.FullTableName+CHAR(13)+a.CorrectiveStatement+';'+CHAR(13)+CHAR(13)
	FROM CorrectiveActions a

	SET @SQL += 'EXEC sp_updatestats;'
END


SELECT @SQL