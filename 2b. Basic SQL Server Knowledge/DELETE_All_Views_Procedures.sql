/*
Cleanup Script f�r API Wechsel

- �ndert KEINE Tabellen 

- l�scht alle Views
- l�scht alle Prozeduren
- l�scht alle Funktionen

*/


-- alle Views l�schen
DECLARE  @sql VARCHAR(MAX) = ''
        ,@crlf VARCHAR(2) = CHAR(13) + CHAR(10) ;

SELECT @sql = @sql + 'DROP VIEW ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(v.name) +';' + @crlf
FROM   sys.views v

PRINT @sql;
EXEC(@sql);


-- alle Prozeduren l�schen
SELECT @sql = @sql + 'DROP PROCEDURE ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(v.name) +';' + @crlf
FROM   sys.procedures v

PRINT @sql;
EXEC(@sql);


-- alle Funktionen l�schen
SELECT @sql = @sql + 'DROP FUNCTION ' + QUOTENAME(SCHEMA_NAME(schema_id)) + '.' + QUOTENAME(v.name) +';' + @crlf
FROM   sys.objects v WHERE type_desc LIKE '%FUNCTION%' 

PRINT @sql;
EXEC(@sql)

GO

