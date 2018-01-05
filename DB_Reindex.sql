USE [DBName]
GO
--EXEC sp_MSforeachtable @command1="PRINT '?' DBCC DBREINDEX ('?', ' ', 80)" -- Used in SQL 2000, ALTER INDEX is 'more robust' and offers more options for reindexing.
EXEC sp_MSforeachtable @command1="PRINT '?' ALTER INDEX ALL ON ? REBUILD WITH (ONLINE=OFF, FILLFACTOR=80)"
GO
EXEC sp_updatestats
GO