;WITH JobHistory AS (
	SELECT
		 j.job_id
		,j.name AS [job_name]
		,DATENAME(WEEKDAY, a.run_requested_date) AS [run_requested_dayofweek]
		,a.job_history_id
		,a.session_id
		,a.queued_date
		,a.run_requested_date
		,a.run_requested_source
		,a.last_executed_step_id
		,a.last_executed_step_date
		,a.start_execution_date
		,a.stop_execution_date
		,CONVERT(TIME, DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, a.start_execution_date, a.stop_execution_date), 0)) AS [execution_duration]
		,a.next_scheduled_run_date
	FROM msdb.dbo.sysjobs j
	JOIN msdb.dbo.sysjobactivity a ON a.job_id = j.job_id
)

SELECT *
FROM JobHistory
WHERE run_requested_dayofweek = 'Friday'
ORDER BY
	 start_execution_date DESC