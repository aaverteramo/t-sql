DECLARE
	 @Query NVARCHAR(MAX) = N'DECLARE @Tables TABLE (Name VARCHAR(MAX), Records INT)
INSERT INTO @Tables (Name, Records)
'	,@Next NVARCHAR(10) = CHAR(13)+'UNION '

SELECT @Query = COALESCE(@Query + 'SELECT '''+t.Name+''' AS [Name], COUNT(*) AS [RowCount] FROM '+t.Name, '???') + @Next
FROM (
	SELECT '['+TABLE_CATALOG+'].['+TABLE_SCHEMA+'].['+TABLE_NAME+']' AS 'Name'
	FROM INFORMATION_SCHEMA.TABLES
) t

SET @Query = LEFT(@Query, LEN(@Query) - LEN(@Next)) +CHAR(13)+'SELECT *'+CHAR(13)+'FROM @Tables'

SELECT @Query
EXEC (@Query)