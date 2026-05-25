USE AdventureWorksLT2025
go
IF (
SELECT  local_tcp_port 
FROM sys.dm_exec_connections 
WHERE session_id = @@SPID) = 1999
BEGIN
-- lets make a change on source db
	CREATE TABLE ThisIsANewTableForFlywayDemo
	(TestColumn INT)
END
ELSE
BEGIN
	PRINT 'Connection is not SOURCE... Please check that you are logged into the correct SQL Server (SOURCE: localhost,1999)'
END


