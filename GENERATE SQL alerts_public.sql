-----------------------------------------------------------------------------------------------------------------------
--                                      DATABASE BACKUP JOBS
----------------------------------------------------------------------------------------------------------------
--
-- The script will delete any alerts with the naming convention DBname + Transaction Log Full.
-- 
-- The script will create a alert for every database 
--         - DB's with full recovery model will have an automatic log backup fire 
--                - The script will only execute and create the Alert if there is a valid 
--                  Log Backup Job already in existence
--         - DB's with simple recovery model will only send out a notification
----------------------------------------------------------------------------------------------------------------
USE [msdb]
GO
--cycle the error log so do not get spammed with old errors, added 8/7/15 tmp
EXEC sp_Cycle_ErrorLog
GO

/*create operator
USE [msdb]
GO

/****** Object:  Operator [Data Services]    Script Date: 5/30/2017 8:37:13 AM ******/
EXEC msdb.dbo.sp_add_operator @name=N'Data Services', 
		@enabled=1, 
		@weekday_pager_start_time=0, 
		@weekday_pager_end_time=235959, 
		@saturday_pager_start_time=0, 
		@saturday_pager_end_time=235959, 
		@sunday_pager_start_time=0, 
		@sunday_pager_end_time=235959, 
		@pager_days=127, 
		@email_address=N'DL-DataServices@', 
		@pager_address=N'DL-DataServices@', 
		@category_name=N'[Uncategorized]'
*/


-- declare variables
--------------------
DECLARE @sql_cmd			VARCHAR(MAX),
	@sql_server_version 	NUMERIC(18,10),
	@sql_server_name		VARCHAR(200),
    @database_name  		VARCHAR(250),
    @db_name        		VARCHAR(100),
    @db_log_name    		VARCHAR(100),
    @enable_diff_backups	VARCHAR(1),
    @error					INT,
	@error_message			VARCHAR(200),		
    @db_backup_start_time   VARCHAR(12),
	@compress				VARCHAR(1),
	@db_backup_verify_enabled 	VARCHAR(1),
    @retention_policy_landscape	VARCHAR(25),
    @enable_archive_bit_flag	VARCHAR(1),
	@email_address			VARCHAR(100),
	@email_pager_address	VARCHAR(100)
        
-- initialize variables
------------------------
	SET @sql_server_name	= UPPER(@@SERVERNAME)
    SET @database_name		= ''	-- Leave @database_name blank as it is used for the script creation loop.
    SET @db_name			= ''	-- Leave @db_name blank as it is used for the script creation loop.
    SET @db_log_name		= ''
    SET @error				= 0
    SET @sql_server_version	= CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)))),'.','') AS NUMERIC(18,10))
	SET @email_address		= '' 
	SET @email_pager_address	= '' 


--2008 Add Alert
----------------

SELECT  a.sql_command   as [SET NOCOUNT ON]
FROM    
(
SELECT  1       as alert_order, name,
'-------------------------------------------------------------------'                                                           			+ CHAR(10) +
'-- CREATING ' + name + ' Full Transaction Log ALERT (FULL RECOVERY)'                                                           			+ CHAR(10) +
'-------------------------------------------------------------------'                                                           			+ CHAR(10) +
'IF(EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N''Transaction Log Full - ' + name + '''))'                        			+ CHAR(10) +
'-- Delete the alert with the same name'                                                                                        			+ CHAR(10) +
'--------------------------------------'                                                                                        			+ CHAR(10) +
'	BEGIN'                                                                                                          						+ CHAR(10) +
'       		EXECUTE msdb.dbo.sp_delete_alert @name = N''Transaction Log Full - ' + name + ''''              							+ CHAR(10) +
'		PRINT ''DELETED Previous Alert ''''Transaction Log Full - ' + name + ''''''''                   									+ CHAR(10) +
'	END'                                                                                                            						+ CHAR(10) +
                                                                                                                                			+ CHAR(10) +
'IF(EXISTS (select * from msdb..sysjobs where enabled = 1 and name = ''DatabaseBackup - USER_DATABASES - LOG''))'                           + CHAR(10) +
'BEGIN'                                                                                                                         			+ CHAR(10) +
'       EXEC msdb.dbo.sp_add_alert              @name                           = N''Transaction Log Full - ' + name + ''','    			+ CHAR(10) +
'                                               @message_id                     = 9002,'                                        			+ CHAR(10) +
'                                               @severity                       = 0,'                                           			+ CHAR(10) +
'                                               @enabled                        = 1,'                                           			+ CHAR(10) +
'                                               @delay_between_responses        = 300,'                                         			+ CHAR(10) +
'                                               @include_event_description_in   = 3,'                                           			+ CHAR(10) +
'                                               @database_name                  = N''' + name + ''','                           			+ CHAR(10) +
'                                               @notification_message           = N''' + name + ' - Log Backup Running'','      			+ CHAR(10) +
'                                               @category_name                  = N''[Uncategorized]'','                        			+ CHAR(10) +
'                                               @job_name                       = N''DatabaseBackup - USER_DATABASES - LOG'''      			+ CHAR(10) +
                                                                                     														+ CHAR(10) +
'       EXEC msdb.dbo.sp_add_notification       @alert_name                     = N''Transaction Log Full - ' + name + ''','    			+ CHAR(10) +
'                                               @operator_name                  = N''Data Services'','                               				+ CHAR(10) +
'                                               @notification_method            = 3'                                            			+ CHAR(10) +
'END'																																		+ CHAR(10) +
                                                                                                                                			+ CHAR(10)      as sql_command
FROM    master..sysdatabases
WHERE   DATABASEPROPERTYEX(name, 'RECOVERY')    <> 'SIMPLE'   

UNION ALL

SELECT 2       as alert_order, name,
'---------------------------------------------------------------------'                                                         			+ CHAR(10) +
'-- CREATING ' + name + ' Full Transaction Log ALERT (SIMPLE RECOVERY)'                                                         			+ CHAR(10) +
'---------------------------------------------------------------------'                                                         			+ CHAR(10) +
'IF(EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N''Transaction Log Full - ' + name + '''))'                        			+ CHAR(10) +
'-- Delete the alert with the same name'                                                                                        			+ CHAR(10) +
'--------------------------------------'                                                                                        			+ CHAR(10) +
'	BEGIN'                                                                                                          				+ CHAR(10) +
'       		EXECUTE msdb.dbo.sp_delete_alert @name = N''Transaction Log Full - ' + name + ''''              				+ CHAR(10) +
'		PRINT ''DELETED Previous Alert ''''Transaction Log Full - ' + name + ''''''''                   					+ CHAR(10) +
'       END'                                                                                                            				+ CHAR(10) +
                                                                                                                                			+ CHAR(10) +
'       EXEC msdb.dbo.sp_add_alert              @name                           = N''Transaction Log Full - ' + name + ''','    			+ CHAR(10) +
'                                               @message_id                     = 9002,'                                        			+ CHAR(10) +
'                                               @severity                       = 0,'                                           			+ CHAR(10) +
'                                               @enabled                        = 1,'                                           			+ CHAR(10) +
'                                               @delay_between_responses        = 300,'                                         			+ CHAR(10) +
'                                               @include_event_description_in   = 3,'                                           			+ CHAR(10) +
'                                               @database_name                  = N''' + name + ''','                           			+ CHAR(10) +
'                                               @notification_message           = N''Transaction Log For ' + name + 
                                                ' Has Filled On ' + @@SERVERNAME  + 
                                                ', DB Is Currently Set To Simple Recovery Mode'','                              			+ CHAR(10) +
'                                               @category_name                  = N''[Uncategorized]'''                         			+ CHAR(10) +
                                                                                                                                			+ CHAR(10) +
'       EXEC msdb.dbo.sp_add_notification       @alert_name                     = N''Transaction Log Full - ' + name + ''','    			+ CHAR(10) +
'                                               @operator_name                  = N''Data Services'','                               			+ CHAR(10) +
'                                               @notification_method            = 3'                                            			+ CHAR(10) +
                                                                                                                                			+ CHAR(10) +
                                                                                                                                			+ CHAR(10)      as sql_command
FROM    master.dbo.sysdatabases
WHERE   DATABASEPROPERTYEX(name, 'RECOVERY')    = 'SIMPLE' 

UNION ALL

SELECT 3       as alert_order, name,
'USE [msdb]'                                                                                                                    			+ CHAR(10) +
'GO'                                                                                                                            			+ CHAR(10) +
''                                                                                                                              			+ CHAR(10) +
'------------------------------------------------------------'                                                                  			+ CHAR(10) +
'-- CREATING ' + name + ' ALERT FOR FULL PRIMARY FILE GROUP  '                                                                  			+ CHAR(10) +
'------------------------------------------------------------'                                                                  			+ CHAR(10) +
''                                                                                                                              			+ CHAR(10) +
'IF  EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N''Primary Filegroup is Full - ' + name + ''')'                   			+ CHAR(10) +
'       BEGIN'                                                                                                                  			+ CHAR(10) +
'		EXEC msdb.dbo.sp_delete_alert @name=N''Primary Filegroup is Full - ' + name + ''''                              			+ CHAR(10) +
'		PRINT ''Deleting Previous Full Primary FileGroup Alert For ' + name + ''''                                      			+ CHAR(10) +
'       END'                                                                                                                    			+ CHAR(10) +
'GO'                                                                                                                            			+ CHAR(10) +
''                                                                                                                              			+ CHAR(10) +
'	EXEC msdb.dbo.sp_add_alert	@name                           = N''Primary Filegroup is Full - ' 						+ 
										name + ''', '                                   			+ CHAR(10) +
'       					@message_id                     = 1105, '                                       			+ CHAR(10) +
'       					@severity                       = 0,'                                           			+ CHAR(10) +
'       					@enabled                        = 1,'                                           			+ CHAR(10) +
'       					@delay_between_responses        = 300,'                                         			+ CHAR(10) +
'       					@include_event_description_in   = 3, '                                          			+ CHAR(10) +
'       					@database_name                  = N''' + name + ''', '                          			+ CHAR(10) +
'       					@notification_message           = N''The Primary File Group is FULL for ' 				+ 
										name + '.  Please Investigate!'', '         				+ CHAR(10) +
'       					@category_name                  = N''[Uncategorized]'''                         			+ CHAR(10) +
'GO'                                                                                                                            			+ CHAR(10) +
''                                                                                                                              			+ CHAR(10) +
'	EXEC msdb.dbo.sp_add_notification	
					@alert_name                     = N''Primary Filegroup is Full - ' 						+ 
										name + ''','                                    			+ CHAR(10) +
'       					@operator_name                  = N''Data Services'','                               			+ CHAR(10) +
'       					@notification_method            = 3'                                            			+ CHAR(10) +
''                                                                                                                              			+ CHAR(10)      as sql_command
FROM    master.dbo.sysdatabases
)       as a
ORDER BY alert_order, name


/*
----------------------------------------------------------------
--KICK OFF THE JOB CHECK TABLE REFRESH JOB TO POPULATE THE TABLE
----------------------------------------------------------------
IF @error = 0 and (SELECT COUNT(*) FROM msdb.dbo.sysjobs WHERE name = 'DB_UTILS - Job Check Table Refresh') > 0
BEGIN
	SET NOCOUNT ON
	SELECT 
	'USE msdb'																	+ CHAR(10) +
	'GO'																		+ CHAR(10) +
	''																		+ CHAR(10) +
	'EXEC sp_start_job @job_name = ''DB_UTILS - Job Check Table Refresh'''										+ CHAR(10) +
	'GO'																		+ CHAR(10) +
	'EXEC sp_start_job @job_name = ''DB_UTILS - SQL Server Alerts Check Refresh'''									+ CHAR(10) +
	'GO'																		+ CHAR(10)

	SET NOCOUNT OFF
END
*/


----------------------------------------------------------------------------------------------------
-- exit code: used to exit out of the script
----------------------------------------------------------------------------------------------------
exit_code:
IF @error <> 0 
	BEGIN
		PRINT 'script unsuccessful'
	END


/*----------------------------------------------------------------
--Add the default alerts
----------------------------------------------------------------
--EXEC msdb.dbo.sp_delete_alert @name=N'Fatal Error in Resource 19'
--GO
EXEC msdb.dbo.sp_add_alert @name=N'Non-Fatal Error 17: Insufficient Resources',
		@message_id=0, 
		@severity=17, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Non-Fatal Error 17: Insufficient Resources', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO

EXEC msdb.dbo.sp_add_alert @name=N'Non-Fatal Error 18: Internal',
		@message_id=0, 
		@severity=18, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Non-Fatal Error 18: Internal', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO

EXEC msdb.dbo.sp_add_alert @name=N'Fatal Error 19: Resource',
		@message_id=0, 
		@severity=19, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Fatal Error 19: Resource', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO

EXEC msdb.dbo.sp_add_alert @name=N'Fatal Error 20: Current Process', 
		@message_id=0, 
		@severity=20, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Fatal Error 20: Current Process', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO


EXEC msdb.dbo.sp_add_alert @name=N'Fatal Error 21: Database Process', 
		@message_id=0, 
		@severity=21, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Fatal Error 21: Database Process', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO


EXEC msdb.dbo.sp_add_alert @name=N'Fatal Error 22: Table Integrity', 
		@message_id=0, 
		@severity=22, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Fatal Error 22: Table Integrity', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO


EXEC msdb.dbo.sp_add_alert @name=N'Fatal Error 23: Database Integrity', 
		@message_id=0, 
		@severity=23, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Fatal Error 23: Database Integrity', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO

EXEC msdb.dbo.sp_add_alert @name=N'Fatal Error 24: Hardware Error', 
		@message_id=0, 
		@severity=24, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Fatal Error 24: Hardware Error', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO


EXEC msdb.dbo.sp_add_alert @name=N'Fatal Error 25', 
		@message_id=0, 
		@severity=25, 
		@enabled=1, 
		@delay_between_responses=300, 
		@include_event_description_in=3, 
		@category_name=N'[Uncategorized]'
GO

EXEC dbo.sp_add_notification @alert_name = N'Fatal Error 25', 
	@operator_name = N'DBAs', 
	@notification_method = 7
GO
*/


