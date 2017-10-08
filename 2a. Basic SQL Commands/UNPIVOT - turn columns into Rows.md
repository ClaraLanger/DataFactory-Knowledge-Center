-- Helpertable with Name of the Globalattributes in one Column

````SQL
SELECT
	FactoryID
	,ProductLineID
	,Globalattribute
	,COALESCE(TRY_CAST(Right(Globalattribute,2) AS INT), TRY_CAST(Right(Globalattribute,1) AS INT)) AS GlobalattributeNumber
	,Aliasname
FROM sx_pf_dProductLines
UNPIVOT
(
	Aliasname
	for Globalattribute IN (
			 GlobalattributeAlias1, GlobalattributeAlias2, GlobalattributeAlias3, GlobalattributeAlias4, GlobalattributeAlias5
			,GlobalattributeAlias6, GlobalattributeAlias7, GlobalattributeAlias8, GlobalattributeAlias9, GlobalattributeAlias10
			,GlobalattributeAlias11, GlobalattributeAlias12, GlobalattributeAlias13, GlobalattributeAlias14, GlobalattributeAlias15
			,GlobalattributeAlias16, GlobalattributeAlias17, GlobalattributeAlias18, GlobalattributeAlias19, GlobalattributeAlias20
			,GlobalattributeAlias21, GlobalattributeAlias22, GlobalattributeAlias23, GlobalattributeAlias24, GlobalattributeAlias25
			)
) unpiv
 ````