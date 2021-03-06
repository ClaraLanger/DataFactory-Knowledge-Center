Every Table should have a primary Key - a primary key is always an unique Index
Setting an index on non-numeric columns has strong limits due to 

## Clustered Index
* one table can have only one clusterd Index, this index depends the physical order of rows
* Size of the index column is maximum 900 kB (so FactoryID, ProductlineID in combination is not possible 255 * 2 (NVARCHAR) * 2 = 1020)
* index can be unique (enforces PrimaryKey), or not
* this index don't need additional space, as this index is the table

## Non-Clusterd Index
* one table can have many non-clusterd Index, the index is represented as separate table
* Size of the index column is maximum 900 kB up to SQL 2014 / 1700 Bytes from SQL 2016 on
* index can be unique (enforces PrimaryKey), or not



## COLUMNSTORE Index
* results in very high perfomance when quering star-schema like table
* recommend to use for fact tables


### COLUMNSTORE Index Clusterd
* not possible if tables containing columns of type NVARCHAR(MAX), you must change NVARCHAR(MAX) to NVARCHAR(4000)
* Index is updateable
* up to SQL 2014 only in Enterprise Edition, from 2016 on also in Express Edition
* always all columns included
* no other index for this table possible
* index is not an additional index for the table, it replaces the table
* there CAN'T be a Trigger on Table with Column Store Index
* THERORIE: use this for the sx_pf_fValues  Table if its not hold as in Memory OLTP

### COLUMNSTORE Index Non-Clusterd
* the table is no longer updateable, you must delete and recreate the index before table changes
* in all Editions from SQL 2012 on
* can be combined with other indexes
* RULE: use it for big read-only Tables, where you need nearly all rows -> much better I/O Performance

### Create a clusterd columnstore index on sx_pf_fValues (needs SQL Server 2014 Enterprise or 2016 Express+)
````SQL
-- delete exising Constraints for NVARCHAR(MAX) Column

-- manually

-- Change NVARCHAR(MAX) columns to NVARCHAR(4000)

ALTER TABLE sx_pf_fValues ALTER COLUMN ValueText NVARCHAR(4000) NOT NULL

ALTER TABLE sx_pf_fValues ALTER COLUMN ValueComment NVARCHAR(4000) NOT NULL

ALTER TABLE sx_pf_fValues ALTER COLUMN ValueFormula NVARCHAR(4000) NOT NULL

-- delete existing Primary Key Index
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[sx_pf_fValues]') AND name = N'PK_sx_pf_fValues_PK')
ALTER TABLE [dbo].[sx_pf_fValues] DROP CONSTRAINT [PK_sx_pf_fValues_PK] WITH ( ONLINE = OFF )
GO

-- create COLUMNSTORE Index
CREATE CLUSTERED COLUMNSTORE INDEX csifV ON sx_pf_fValues WITH (DROP_EXISTING = ON);

````
