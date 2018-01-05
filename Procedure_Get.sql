SELECT
	 o.object_id AS [PROC_ID]
	,dbo.FormatProcedureName(o.object_id) AS [PROCEDURE_NAME]
	,m.definition
FROM sys.objects o
JOIN sys.sql_modules m ON m.object_id = o.object_id
WHERE o.type = 'P'
AND m.definition LIKE '%starsleveltype%'