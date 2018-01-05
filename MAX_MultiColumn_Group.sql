;WITH Tasks AS (
	SELECT
		 TaskGenId
		,DeviceGenId
		,CAST(MAX(u.Value) AS DATE) AS [ChangedDate]
	FROM Task
	UNPIVOT (
		Value
		FOR Field IN (
			 CreateDate
			,UpdateDate
			,DeletedDate
		)
	) u
	GROUP BY
		 TaskGenId
		,DeviceGenId
)


SELECT *
FROM Task t
JOIN Tasks tt ON tt.TaskGenId = t.TaskGenId AND tt.DeviceGenId = t.DeviceGenId
WHERE tt.ChangedDate > '10/10/2016'