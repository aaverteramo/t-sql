--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--CREATE PROCEDURE [dbo].[GenerateAuditTrail]
DECLARE
	 @TableName SYSNAME = 'Code'
	,@Schema SYSNAME = 'dbo'
	,@AuditNameExtention SYSNAME = 'Audit'
	,@UseTriggers BIT = 1
	,@Commit BIT = 1
--AS
--BEGIN
	DECLARE
		 @AuditName SYSNAME = @TableName+@AuditNameExtention	
		,@AuditExists BIT

	SELECT @AuditExists =
		CASE WHEN (EXISTS (
					SELECT TOP 1 NULL
					FROM dbo.sysobjects
					WHERE id = object_id(N'['+@Schema+'].['+@AuditName+']')
					AND OBJECTPROPERTY(id, N'IsUserTable') = 1))
			 THEN 1 ELSE 0 END

	IF (NOT EXISTS (SELECT TOP 1 NULL FROM dbo.sysobjects WHERE id = object_id(N'['+@Schema+'].['+@TableName+']') AND OBJECTPROPERTY(id, N'IsUserTable') = 1))
		THROW 51404, 'ERROR: Table does not exist', 1;
	IF (NULLIF(REPLACE(@AuditNameExtention, ' ', ''), '') IS NULL)
		THROW 51404, 'ERROR: @AuditNameExtention cannot be null', 1;
	-- Drop audit table if it exists.
	IF (@AuditExists = 1)
	BEGIN
		PRINT 'Dropping audit table [' + @Schema + '].[' + @AuditName + ']'
		EXEC ('DROP TABLE ' + @AuditName)
	END

	DECLARE
		 @Exists BIT
		,@SQL NVARCHAR(MAX)
		,@ColumnDefinitions NVARCHAR(MAX) = N''
		,@Fields NVARCHAR(MAX) = N''
			
	;WITH Fields AS (
		SELECT
			 c.COLUMN_NAME
			--,c.DATA_TYPE
			,'['+c.DATA_TYPE+']'
			 +(CASE WHEN c.CHARACTER_MAXIMUM_LENGTH IS NULL THEN ''
					ELSE '('+(CASE WHEN c.CHARACTER_MAXIMUM_LENGTH = -1 THEN 'max' ELSE CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR) END)+')'
					END)
			 +(CASE WHEN c.NUMERIC_PRECISION IS NULL THEN ''
					WHEN c.NUMERIC_PRECISION IS NOT NULL AND c.DATA_TYPE IN ('decimal', 'numeric') THEN '('+CAST(c.NUMERIC_PRECISION AS VARCHAR)+','+CAST(c.NUMERIC_SCALE AS VARCHAR)+')'
					ELSE '' END)
			 +(CASE WHEN c.COLLATION_NAME IS NULL THEN ''
					ELSE ' COLLATE '+c.COLLATION_NAME END)
			 +(' '+CASE WHEN c.IS_NULLABLE = 'NO' THEN 'NOT ' ELSE '' END+'NULL') AS [DATA_TYPE]
			,c.IS_NULLABLE
			,c.COLLATION_SCHEMA
			,c.COLLATION_NAME
			,c.DATETIME_PRECISION
			,c.NUMERIC_PRECISION
			,c.NUMERIC_PRECISION_RADIX
			,c.NUMERIC_SCALE
		FROM INFORMATION_SCHEMA.TABLES t
		JOIN INFORMATION_SCHEMA.COLUMNS c ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
		WHERE t.TABLE_SCHEMA = @Schema
		AND t.TABLE_NAME = @TableName
		AND c.DATA_TYPE NOT IN ('text', 'ntext', 'image', 'timestamp')
	)

	SELECT
		 @ColumnDefinitions += CHAR(9)+',['+COLUMN_NAME+'] '+DATA_TYPE+CHAR(13)
		,@Fields += '['+COLUMN_NAME+'], '
	FROM Fields

	-- Create SQL Script
	SET @SQL =
		'CREATE TABLE ['+@Schema+'].['+@AuditName+'] ('+CHAR(13)
			+CHAR(9)+' [AuditId] [bigint] IDENTITY (1,1) NOT NULL'+CHAR(13)
			+@ColumnDefinitions
			+CHAR(9)+',[AuditAction] [CHAR] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL'+CHAR(13)
			+CHAR(9)+',[AuditDate] [DATETIME] NOT NULL CONSTRAINT [DF_'+@AuditName+'_AuditDate] DEFAULT(GETUTCDATE())'+CHAR(13)
			+CHAR(9)+',[AuditUser] [VARCHAR] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_'+@AuditName+'_AuditUser] DEFAULT(SUSER_SNAME())'+CHAR(13)
			+CHAR(9)+',[AuditApp] [VARCHAR](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_'+@AuditName+'_AuditApp] DEFAULT(''App=(''+RTRIM(ISNULL(APP_NAME(),''''))+'')'')'+CHAR(13)
			+CHAR(9)+',CONSTRAINT [PK_'+@AuditName+'] PRIMARY KEY CLUSTERED ([AuditId])'+CHAR(13)
		+')'+CHAR(13)

	IF (@UseTriggers = 1)
	BEGIN
		;WITH ActionNames AS (
			SELECT 'Insert' AS [Name] UNION
			SELECT 'Update' UNION
			SELECT 'Delete'
		),
		AuditActions AS (
			SELECT
				 [Name]
				,LEFT([Name], 1) AS [Abbreviation]
				,N'['+@Schema+'].[tr_'+@TableName+'_'+[Name]+']' AS [Trigger]
			FROM ActionNames
		)
		SELECT
			 @SQL +='IF (EXISTS (SELECT TOP 1 NULL FROM dbo.sysobjects WHERE id = object_id('''+[Trigger]+''') AND OBJECTPROPERTY(id, N''IsTrigger'') = 1))'+CHAR(13)
				   +'BEGIN'+CHAR(13)
				   +CHAR(9)+'PRINT ''Dropping trigger '+[Trigger]+''''+CHAR(13)
				   +CHAR(9)+'DROP TRIGGER '+[Trigger]+CHAR(13)
				   +'END'+CHAR(13)
				   +'PRINT ''Creating trigger '+[Trigger]+''''+CHAR(13)
				   +'EXEC (''CREATE TRIGGER '+[Trigger]+' ON ['+@Schema+'].['+@TableName+'] FOR '+[Name]+' AS INSERT INTO '+@AuditName+'('+@Fields+'AuditAction) SELECT '+@Fields+''''''+[Abbreviation]+''''' FROM Inserted'')'+CHAR(13)
		FROM AuditActions
	END

	SELECT @SQL AS [Script]

	IF (@Commit = 1)
	BEGIN
		EXEC (@SQL)
	END
--END