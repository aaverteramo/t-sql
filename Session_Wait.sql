DECLARE @session_id INT = 60

-- Wait for the session to complete executing.
WHILE EXISTS (
	SELECT NULL
	FROM sys.dm_exec_sessions
	WHERE session_id = @session_id
	AND status = 'running')
BEGIN
	--Wait one more minute...
	WAITFOR DELAY '00:01:00.000'
END
PRINT 'Ready to run!'