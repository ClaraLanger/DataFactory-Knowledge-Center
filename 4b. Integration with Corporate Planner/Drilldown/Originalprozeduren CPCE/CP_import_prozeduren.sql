USE [connectivityexpress]
GO
/****** Object:  StoredProcedure [dbo].[pCP_DrilldownFiBu]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Drilldown in die Finanzbuchhaltung
				--                Für den Drilldown auf Perioden (IsPeriodFilter=1) wird in den Parametern PeriodFrom und PerodTo das Datum in der Form yyyy-pp 
				--                übergeben, wobei yyyy das Geschäftsjahr und pp der Periode entspricht.
				--                Beim Drilldown auf Tagesbasis (IsPeriodFilter=0) wird in den Parametern PeriodFrom und PeriodTo das Datum in der Form yyyymmdd 
				--                übergeben, wobei yyyy das Kalenderjahr, mm deMonat und dd dem Tag entspricht.
				-- In Parameter:  Client: Der Mandant, für den die Werte abgefragt werden.
				--				  CompanyCode: Der Buchungskreis, für den die Werte abgefragt werden.
				--				  Account: Das Konto, für das die Werte abgefragt werden sollen.	
				--				  PeriodForm: Anfangsperiode / Anfangsdatum
				--			      PeriodTo: Endperiode / Enddatum
				--				  IsPeriodFilter: Legt fest, ob auf Perioden oder Buchungsdatum gefiltert werden soll.
				-- Out Parameter: 
				-- Resultset 1:   Kann frei definiert werden.
				-- Resultset 2:	  KumuliertesSoll: Die Summe der Sollwerte der Abfrage
				--                KumuliertesHaben: Die Summe der Habenwerte der Abfrage
				--                KumuliertesSaldo: Die Summe der Salden der Abfrage
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_DrilldownFiBu] 
				@Client varchar(255),
				@CompanyCode varchar(255),
				@Account varchar(255),
				@PeriodFrom varchar(10),
				@PeriodTo varchar(10),
				@IsPeriodFilter tinyint

				AS
				BEGIN
					SET NOCOUNT ON;
		
				-- Abfrage der Buchungssätze
					SELECT 
					dP.PeriodenKalenderjahr AS Kalenderjahr 
					,dP.PeriodenMonatsmapping AS Monat
					,cast(f.Saldovortrag AS Money) / 100 AS Saldovortrag
					,cast(f.Soll AS Money) / 100 AS Soll
					,cast(f.Haben AS Money) / 100  AS Haben
					,dZ1.Datum AS Buchungsdatum
					,dZ2.Datum AS Belegdatum
					,f.Belegnummer 
					,f.Buchungstext
					,f.Kundenattribut0 AS ICPartner
					,f.Kundenattribut1 AS Segment1
					,f.Kundenattribut2 AS Segment2
					
					FROM  sx_dwh_fFiBuBuchungsjournal f
					inner join sx_dwh_dMandanten dMdt ON f.Mandanten_ID = dMdt.Mandanten_ID
					inner join sx_dwh_dZeit_Tage dZ1 ON f.Buchungsdatum_Key = dZ1.Tages_Key
					inner join sx_dwh_dZeit_Tage dZ2 ON f.Belegdatum_Key = dZ2.Tages_Key
					inner join sx_dwh_dKonten dK1 ON f.Konten_Key = dk1.Konten_Key
					inner join sx_dwh_dKonten dK2 ON f.Gegenkonten_Key = dk2.Konten_Key
					inner join sx_dwh_dPerioden dP ON f.Perioden_Key = dP.Perioden_Key
					WHERE f.Mandanten_ID = @Client AND  
	       				  --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						  --dMdt.Mandant_Lokal = @ClientId AND
						  [Buchungskreis] = @CompanyCode AND 
							--Vorbereitung Buchungskreiszusammenlegung Datev Pro
							--WHERE (case
							--            when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
							--            when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
							--            when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
							--            when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
							--            else Buchungskreis 
							--        end = @CompanyCode) AND
						  REPLICATE('0',8-LEN(f.Konten_ID)) + f.Konten_ID = @Account AND 
						  CASE
							WHEN @IsPeriodFilter = 1 AND LEFT([PeriodenFinanzjahr],4) *100 + dP.Periode BETWEEN 
												 (CAST(LEFT(@PeriodFrom, 4) AS INT) *100 + CAST(RIGHT(@PeriodFrom, 2) AS INT)) AND 
												 (CAST(LEFT(@PeriodTo,   4) AS INT) *100 + CAST(RIGHT(@PeriodTo,   2) AS INT)) THEN 1
							WHEN @IsPeriodFilter = 0 AND dZ1.Datum BETWEEN @PeriodFrom AND @PeriodTo THEN 1
							ELSE 0
						  END = 1
					ORDER BY [Kalenderjahr], [Periode]
					

					-- Abfrage der kumulierten Werte
					SELECT 	CAST(SUM([Soll]) as money) / 100 AS [KumuliertesSoll], 
							CAST(SUM([Haben]) as money) / 100 AS [KumuliertesHaben],
							CAST((SUM([Saldovortrag]) + SUM([Soll]) + SUM([Haben])) as money) / 100 AS [KumuliertesSaldo]
					FROM  sx_dwh_fFiBuBuchungsjournal f
					inner join sx_dwh_dMandanten dMdt ON f.Mandanten_ID = dMdt.Mandanten_ID
					inner join sx_dwh_dZeit_Tage dZ1 ON f.Buchungsdatum_Key = dZ1.Tages_Key
					inner join sx_dwh_dZeit_Tage dZ2 ON f.Belegdatum_Key = dZ2.Tages_Key
					inner join sx_dwh_dKonten dK1 ON f.Konten_Key = dk1.Konten_Key
					inner join sx_dwh_dKonten dK2 ON f.Gegenkonten_Key = dk2.Konten_Key
					inner join sx_dwh_dPerioden dP ON f.Perioden_Key = dP.Perioden_Key
					WHERE f.Mandanten_ID = @Client AND  
	       				  --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						  --dMdt.Mandant_Lokal = @ClientId AND
						  [Buchungskreis] = @CompanyCode AND 
							--Vorbereitung Buchungskreiszusammenlegung Datev Pro
							--WHERE (case
							--            when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
							--            when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
							--            when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
							--            when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
							--            else Buchungskreis 
							--        end = @CompanyCode) AND
						  REPLICATE('0',8-LEN(f.Konten_ID)) + f.Konten_ID = @Account AND 
						  CASE
							WHEN @IsPeriodFilter = 1 AND LEFT([PeriodenFinanzjahr],4) *100 + dP.Periode BETWEEN 
												 (CAST(LEFT(@PeriodFrom, 4) AS INT) *100 + CAST(RIGHT(@PeriodFrom, 2) AS INT)) AND 
												 (CAST(LEFT(@PeriodTo,   4) AS INT) *100 + CAST(RIGHT(@PeriodTo,   2) AS INT)) THEN 1
							WHEN @IsPeriodFilter = 0 AND dZ1.Datum BETWEEN @PeriodFrom AND @PeriodTo THEN 1
							ELSE 0
						  END = 1	
				END
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_DrilldownKoRe]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Drilldown in die Kostenrechnung
				--                Für den Drilldown auf Perioden (IsPeriodFilter=1) wird in den Parametern PeriodFrom und PerodTo das Datum in der Form yyyy-pp 
				--                übergeben, wobei yyyy das Geschäftsjahr und pp der Periode entspricht.
				--                Beim Drilldown auf Tagesbasis (IsPeriodFilter=0) wird in den Parametern PeriodFrom und PeriodTo das Datum in der Form yyyymmdd 
				--                übergeben, wobei yyyy das Kalenderjahr, mm deMonat und dd dem Tag entspricht.
				-- In Parameter:  Client: Der Mandant, für den die Werte abgefragt werden.
				--				  CompanyCode: Der Buchungskreis, für den die Werte abgefragt werden.
				--				  CostType: Die Kostenart, für das die Werte abgefragt werden sollen.	
				--                KoReTypeId: Die Kostenstelle oder der Kostenträger, für den die Werte abgefragt werden sollen (Ist abhängig von KoReType).
				--				  PeriodForm: Anfangsperiode / Anfangsdatum
				--			      PeriodTo: Endperiode / Enddatum
				--                KoReType: 0 = Kostenstelle
				--						    1 = Kostensräger
				--				  IsPeriodFilter: Legt fest, ob auf Perioden oder Buchungsdatum gefiltert werden soll.
				-- Out Parameter: 
				-- Resultset 1:   Kann frei definiert werden.
				-- Resultset 2:	  KumuliertesSoll: Die Summe der Sollwerte der Abfrage
				--                KumuliertesHaben: Die Summe der Habenwerte der Abfrage
				--                KumuliertesSaldo: Die Summe der Salden der Abfrage
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_DrilldownKoRe] 
				@Client varchar(255),
				@CompanyCode varchar(255),
				@CostType varchar(255),
				@KoreTypeId varchar(255),
				@PeriodFrom varchar(10),
				@PeriodTo varchar(10),
				@KoReType tinyint,
				@IsPeriodFilter tinyint

				AS
				BEGIN
					SET NOCOUNT ON;

					-- Abfrage der Buchungssätze
					SELECT 
					dP.PeriodenKalenderjahr AS Kalenderjahr 
					,dP.PeriodenMonatsmapping AS Monat
					,dKs.Kostenstellen_ID AS Kostenstelle
					,dKs.KostenstellenName AS Kostenstellenbezeichnung
					,cast(f.Saldovortrag AS Money) / 100 AS Saldovortrag
					,cast(f.Soll AS Money) / 100 AS Soll
					,cast(f.Haben AS Money) / 100  AS Haben
					,dZ1.Datum AS Buchungsdatum
					,dZ2.Datum AS Belegdatum
					,f.Belegnummer 
					,f.Buchungstext
					,dKt.Kostentraeger_ID AS [Kostenträger]
					,dKt.KostentraegerName AS [Kostenträgerbezeichnung]
					,f.Kundenattribut0 AS ICPartner
					,f.Kundenattribut1 AS Segment1
					,f.Kundenattribut2 AS Segment2

					FROM  sx_dwh_fKoReBuchungsjournal f
					inner join sx_dwh_dMandanten dMdt ON f.Mandanten_ID = dMdt.Mandanten_ID
					inner join sx_dwh_dZeit_Tage dZ1 ON f.Buchungsdatum_Key = dZ1.Tages_Key
					inner join sx_dwh_dZeit_Tage dZ2 ON f.Belegdatum_Key = dZ2.Tages_Key
					inner join sx_dwh_dKonten dK1 ON f.Konten_Key = dk1.Konten_Key
					left join sx_dwh_dKonten dK2 ON f.Kundenattribut4 = dk2.Konten_Key
					inner join sx_dwh_dKostenstellen dKs ON f.Kostenstellen_Key = dKs.Kostenstellen_Key
					inner join sx_dwh_dKostentraeger dKt ON f.Kostentraeger_Key = dKt.Kostentraeger_Key
					inner join sx_dwh_dPerioden dP ON f.Perioden_Key = dP.Perioden_Key
					WHERE f.Mandanten_ID = @Client AND  
	       				  --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						  --dMdt.Mandant_Lokal = @ClientId AND
						  [Buchungskreis] = @CompanyCode AND 
							--Vorbereitung Buchungskreiszusammenlegung Datev Pro
							--WHERE (case
							--            when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
							--            when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
							--            when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
							--            when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
							--            else Buchungskreis 
							--        end = @CompanyCode) AND
						  REPLICATE('0',8-LEN(f.Konten_ID)) + f.Konten_ID = @CostType AND  
						  CASE 
							WHEN @KoReType=0 AND dKs.Kostenstellen_ID = @KoReTypeId THEN 1
							WHEN @KoReType=1 AND dKt.Kostentraeger_ID = @KoReTypeId THEN 1
							ELSE 0
						  END = 1 and					  
						  CASE
							WHEN @IsPeriodFilter = 1 AND LEFT([PeriodenFinanzjahr],4) *100 + dP.Periode BETWEEN 
												 (CAST(LEFT(@PeriodFrom, 4) AS INT) *100 + CAST(RIGHT(@PeriodFrom, 2) AS INT)) AND 
												 (CAST(LEFT(@PeriodTo,   4) AS INT) *100 + CAST(RIGHT(@PeriodTo,   2) AS INT)) THEN 1
							WHEN @IsPeriodFilter = 0 AND dZ1.Datum BETWEEN @PeriodFrom AND @PeriodTo THEN 1
							ELSE 0
						  END = 1 
					ORDER BY [Kalenderjahr], [Periode]
					

					-- Abfrage der kumulierten Werte
					SELECT 	CAST(SUM([Soll]) as money) / 100 AS [KumuliertesSoll], 
							CAST(SUM([Haben]) as money) / 100 AS [KumuliertesHaben],
							CAST((SUM([Saldovortrag]) + SUM([Soll]) + SUM([Haben])) as money) / 100 AS [KumuliertesSaldo]
					FROM  sx_dwh_fKoReBuchungsjournal f
					inner join sx_dwh_dMandanten dMdt ON f.Mandanten_ID = dMdt.Mandanten_ID
					inner join sx_dwh_dZeit_Tage dZ1 ON f.Buchungsdatum_Key = dZ1.Tages_Key
					inner join sx_dwh_dZeit_Tage dZ2 ON f.Belegdatum_Key = dZ2.Tages_Key
					inner join sx_dwh_dKonten dK1 ON f.Konten_Key = dk1.Konten_Key
					left join sx_dwh_dKonten dK2 ON f.Kundenattribut4 = dk2.Konten_Key
					inner join sx_dwh_dKostenstellen dKs ON f.Kostenstellen_Key = dKs.Kostenstellen_Key
					inner join sx_dwh_dKostentraeger dKt ON f.Kostentraeger_Key = dKt.Kostentraeger_Key
					inner join sx_dwh_dPerioden dP ON f.Perioden_Key = dP.Perioden_Key
					WHERE f.Mandanten_ID = @Client AND  
	       				  --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						  --dMdt.Mandant_Lokal = @ClientId AND
						  [Buchungskreis] = @CompanyCode AND 
							--Vorbereitung Buchungskreiszusammenlegung Datev Pro
							--WHERE (case
							--            when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
							--            when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
							--            when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
							--            when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
							--            else Buchungskreis 
							--        end = @CompanyCode) AND
						  REPLICATE('0',8-LEN(f.Konten_ID)) + f.Konten_ID = @CostType AND  
						  CASE 
							WHEN @KoReType=0 AND dKs.Kostenstellen_ID = @KoReTypeId THEN 1
							WHEN @KoReType=1 AND dKt.Kostentraeger_ID = @KoReTypeId THEN 1
							ELSE 0
						  END = 1 and					  
						  CASE
							WHEN @IsPeriodFilter = 1 AND LEFT([PeriodenFinanzjahr],4) *100 + dP.Periode BETWEEN 
												 (CAST(LEFT(@PeriodFrom, 4) AS INT) *100 + CAST(RIGHT(@PeriodFrom, 2) AS INT)) AND 
												 (CAST(LEFT(@PeriodTo,   4) AS INT) *100 + CAST(RIGHT(@PeriodTo,   2) AS INT)) THEN 1
							WHEN @IsPeriodFilter = 0 AND dZ1.Datum BETWEEN @PeriodFrom AND @PeriodTo THEN 1
							ELSE 0
						  END = 1 
				END
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectAccountsFiBu]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage von Konten, die zu den übergebenen Mandanten gehören.
				-- In Parameter:  KontenType: 0 = nur GuV Konten
				--							  1 = nur Bilanzkonten
				--				 			  3 = Bilanz und GuV Konten
				--				  Clients: Ein Xml Dokument, das die Mandanten enthält.
				-- Out Parameter: Konten_ID
				--                KontenName
				--				  Mandanten_ID
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectAccountsFiBu]
					@KontenType TINYINT,
					@Clients NVARCHAR(max)
					
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @xml XML = @Clients;
					 
					CREATE TABLE #clients(ClientId VARCHAR(255));
					
					insert into #clients(ClientId)
					SELECT T.c.value('.', 'VARCHAR(255)') AS ClientId
					FROM @xml.nodes('declare namespace x="http://tempuri.org/FiBuDataSet.xsd";/x:FiBuDataSet/x:tblClient/x:Id') T(c);
					
					IF @KontenType = 0
						SELECT Konten_ID,
							   KontenName,
							   k.Mandanten_ID
							 --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							 --m.Mandant_Lokal AS Mandanten_ID,
						FROM [dbo].[sx_dwh_dKonten] k
						INNER JOIN #clients c ON c.ClientId=k.Mandanten_ID
						--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						--INNER JOIN sx_dwh_dMandanten m ON m.Mandanten_ID = k.Mandanten_ID
						--INNER JOIN #clients c ON c.ClientId = m.Mandant_Lokal
						WHERE ([KontenHerkunft] IN ('FIBU','ALL')) AND 
							  ([FiBuBebuchtFlag] = 1) AND
							  (KontenTyp = 'GuV');
								  
					ELSE IF @KontenType = 1
						SELECT Konten_ID,
							   KontenName,
							   k.Mandanten_ID
							 --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							 --m.Mandant_Lokal AS Mandanten_ID,
						FROM [dbo].[sx_dwh_dKonten] k
						INNER JOIN #clients c ON c.ClientId=k.Mandanten_ID
						--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						--INNER JOIN sx_dwh_dMandanten m ON m.Mandanten_ID = k.Mandanten_ID
						--INNER JOIN #clients c ON c.ClientId = m.Mandant_Lokal
						WHERE ([KontenHerkunft] IN ('FIBU','ALL')) AND 
							  ([FiBuBebuchtFlag] = 1) AND
							  (KontenTyp = 'Bilanz');

					ELSE 
						SELECT Konten_ID,
							   KontenName,
							   k.Mandanten_ID
							 --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							 --m.Mandant_Lokal AS Mandanten_ID,
						FROM [dbo].[sx_dwh_dKonten] k
						INNER JOIN #clients c ON c.ClientId=k.Mandanten_ID
						--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						--INNER JOIN sx_dwh_dMandanten m ON m.Mandanten_ID = k.Mandanten_ID
						--INNER JOIN #clients c ON c.ClientId = m.Mandant_Lokal
						WHERE ([KontenHerkunft] IN ('FIBU','ALL')) AND 
							  ([FiBuBebuchtFlag] = 1) AND
							  (KontenTyp IN ('GuV', 'Bilanz'))
				END

			
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectAccountsKoRe]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage von Konten, die zu den übergebenen Mandanten gehören.
				-- In Parameter:  Clients: Ein Xml Dokument, das die Mandanten enthält.			  
				-- Out Parameter: Konten_ID
				--                KontenName
				--				  Mandanten_ID
				-- =============================================

				CREATE PROCEDURE [dbo].[pCP_SelectAccountsKoRe]
					@Clients NVARCHAR(max)
					
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @xml XML = @Clients;
					 
					CREATE TABLE #clients(ClientId VARCHAR(255));
					
					insert into #clients(ClientId)
					SELECT T.c.value('.', 'VARCHAR(255)') AS ClientId
					FROM @xml.nodes('declare namespace x="http://tempuri.org/KoReDataSet.xsd";/x:KoReDataSet/x:tblClient/x:Id') T(c);
					
					SELECT	Konten_ID, 
							KontenName, 
							Mandanten_Id
							--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							--m.Mandant_Lokal AS Mandanten_ID,
					FROM [dbo].[sx_dwh_dKonten] k
					INNER JOIN #clients c ON c.ClientId=k.Mandanten_ID
					--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
					--INNER JOIN sx_dwh_dMandanten m ON m.Mandanten_ID = k.Mandanten_ID
					--INNER JOIN #clients c ON c.ClientId = m.Mandant_Lokal
					WHERE   ([KontenHerkunft] IN ('KORE','ALL')) AND
					-- Falls nicht der Kontenstamm der Kostenrechnung verwendet werden soll, sondern die FiBu-Sachkonten,
					-- muss die KontenHerkunft 'FIBU' selektiert werden
					-- WHERE ([KontenHerkunft] IN ('FIBU','ALL'))
							(KontenTyp = 'GuV') AND
							(KoReBebuchtFlag = 1)
				END
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectClients]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage aller Mandanten.
				-- Out Parameter: Mandanten_ID
				--                MandantenName
				--				  MandantenGeschaeftsjahresbeginn
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectClients] 

				AS
				BEGIN
					SET NOCOUNT ON;

					SELECT   
							 Mandanten_ID, 
							 --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							 --Mandant_Lokal AS Mandanten_ID,
							 MandantenName, 
							 MandantenGeschaeftsjahresbeginn
					FROM     dbo.sx_dwh_dMandanten
					ORDER BY MandantenName
				END
			
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectCompanyCodesFiBu]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage aller Buchungskreise.
				-- Out Parameter: Buchungskreis
				--                Mandanten_ID
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectCompanyCodesFiBu] 

				AS
				BEGIN
					SET NOCOUNT ON;

					SELECT DISTINCT	Buchungskreis, 
									Mandanten_ID
					FROM			dbo.sx_dwh_fFiBu_kP
					ORDER BY		Buchungskreis
					
	 --				  Vorbereitung Buchungskreiszusammenlegung Datev Pro
	 --				  SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fFiBu_kP
     --               where Buchungskreis in ('1','6','7')
     
	 --               union

     --               SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fFiBu_kP
     --               where Buchungskreis in ('1','6','8')
     
	 --               union

     --               SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fFiBu_kP
     --               where Buchungskreis in ('1','6','9')

	 --               union

     --               SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fFiBu_kP
     --               where Buchungskreis in ('1','6','10')

     --               union

     --               SELECT DISTINCT  Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fFiBu_kP
     --               where Buchungskreis not in ('1','6','7','8','9','10')
     --               order by 1,2					
					
						
				END
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectCompanyCodesKoRe]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage aller Buchungskreise.
				-- Out Parameter: Buchungskreis
				--                Mandanten_ID
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectCompanyCodesKoRe] 

				AS
				BEGIN
					SET NOCOUNT ON;

					SELECT DISTINCT	Buchungskreis, 
									Mandanten_ID
					FROM			dbo.sx_dwh_fKoRe_P
					ORDER BY		Buchungskreis
					
	 --				  Vorbereitung Buchungskreiszusammenlegung Datev Pro
	 --				  SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fKoRe_P
     --               where Buchungskreis in ('1','6','7')
     
	 --               union

     --               SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fKoRe_P
     --               where Buchungskreis in ('1','6','8')
     
	 --               union

     --               SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fKoRe_P
     --               where Buchungskreis in ('1','6','9')

	 --               union

     --               SELECT DISTINCT    replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS') as Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fKoRe_P
     --               where Buchungskreis in ('1','6','10')

     --               union

     --               SELECT DISTINCT  Buchungskreis, 
     --                               Mandanten_ID
     --               FROM            dbo.sx_dwh_fKoRe_P
     --               where Buchungskreis not in ('1','6','7','8','9','10')
     --               order by 1,2					
					
						
				END
   			
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectCostCenterKoRe]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage aller Kostenstellen die zu den übergebenen Mandanten gehören.
				-- In Parameter:  Clients: Ein Xml Dokument, das die Mandanten enthält.
				-- Out Parameter: Kostenstellen_ID
				--	              KostenstellenName
				--                Mandanten_ID
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectCostCenterKoRe]
					@Clients NVARCHAR(max)
					
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @xml XML = @Clients;
					 
					CREATE TABLE #clients(ClientId VARCHAR(255));
					
					insert into #clients(ClientId)
					SELECT T.c.value('.', 'VARCHAR(255)') AS ClientId
					FROM @xml.nodes('declare namespace x="http://tempuri.org/KoReDataSet.xsd";/x:KoReDataSet/x:tblClient/x:Id') T(c);
					
					SELECT	Kostenstellen_ID, 
							KostenstellenName, 
							Mandanten_Id
							--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							--m.Mandant_Lokal AS Mandanten_ID,
					FROM    [dbo].[sx_dwh_dKostenstellen] k
					--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
					--INNER JOIN sx_dwh_dMandanten m ON m.Mandanten_ID = k.Mandanten_ID
					--INNER JOIN #clients c ON c.ClientId = m.Mandant_Lokal
					INNER JOIN #clients c ON c.ClientId=k.Mandanten_ID
					WHERE LetztesBuchungsdatum IS NOT NULL
					OR Kostenstellen_Key < 0
				END
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectCostUnitKoRe]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage aller Kostenträger die zu den übergebenen Mandanten gehören.
				-- In Parameter:  Clients: Ein Xml Dokument, das die Mandanten enthält.
				-- Out Parameter: Kostentraeger_ID
				--	              KostentraegerName
				--                Mandanten_ID
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectCostUnitKoRe]
					@Clients NVARCHAR(max)
					
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @xml XML = @Clients;
					 
					CREATE TABLE #clients(ClientId VARCHAR(255));
					
					insert into #clients(ClientId)
					SELECT T.c.value('.', 'VARCHAR(255)') AS ClientId
					FROM @xml.nodes('declare namespace x="http://tempuri.org/KoReDataSet.xsd";/x:KoReDataSet/x:tblClient/x:Id') T(c);
					
					SELECT	Kostentraeger_ID, 
							KostentraegerName, 
							Mandanten_Id
							--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							--m.Mandant_Lokal AS Mandanten_ID,
					FROM    [dbo].[sx_dwh_dKostentraeger] k
					--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
					--INNER JOIN sx_dwh_dMandanten m ON m.Mandanten_ID = k.Mandanten_ID
					--INNER JOIN #clients c ON c.ClientId = m.Mandant_Lokal
					INNER JOIN #clients c ON c.ClientId=k.Mandanten_ID
					WHERE LetztesBuchungsdatum IS NOT NULL
					OR Kostentraeger_Key < 0		
				END			
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectValuesFiBu]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage FiBu Salden.
				-- In Parameter:  CompanyCode: Der Buchungskreis, für den die Werte abgefragt werden.
				--				  ClientId: Der Mandant, für den die Werte abgefragt werden.	
				--				  PeriodForm: Anfangsperiode
				--			      PeriodTo: Endperiode
				-- Out Parameter: Mandanten_ID
				--	              Konten_ID
				--	              ICPartner_ID
				--	              Segment1_ID
				--	              Segment2_ID
				--                Perioden_Key
				--				  Saldovortrag
				--				  Soll
				--				  Haben
				--				  Saldo_Periode
				--				  Soll_kum
				--				  Haben_kum
				--				  Saldo
				--				  KontenTyp
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectValuesFiBu] 
					@CompanyCode VARCHAR(255), 
					@ClientId VARCHAR(255),
					@PeriodFrom INT,
					@PeriodTo INT
				AS
				BEGIN
					SET NOCOUNT ON;

					SELECT
						   K.[Mandanten_ID],
				  		   --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
			  			   --M.Mandant_Lokal AS Mandanten_ID,
						   K.[Konten_ID],
						   V.Kundenattribut0 AS ICPartner_ID,
						   V.Kundenattribut1 AS Segment1_ID,
						   V.Kundenattribut2 AS Segment2_ID,
						   [Perioden_Key],
						   [Saldovortrag],
						   [Soll],
						   [Haben],
						   [Saldo_Periode],
						   [Soll_kum],
						   [Haben_kum],
						   [Saldo],
						   K.[KontenTyp]
					FROM [dbo].[sx_dwh_fFiBu_kP] V
					INNER JOIN [dbo].[sx_dwh_dKonten] K ON (K.[Konten_Key] = V.[Konten_Key])
					--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
					--INNER JOIN sx_dwh_dMandanten M ON M.Mandanten_ID = V.Mandanten_ID
					WHERE   (Buchungskreis = @CompanyCode) AND 
					--Vorbereitung Buchungskreiszusammenlegung Datev Pro
                    --WHERE (case
                    --            when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
                    --            when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
                    --            when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
                    --            when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
                    --            else Buchungskreis 
                    --        end = @CompanyCode) AND
						  (K.[Mandanten_ID] = @ClientId) AND 
	       				  --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						  --M.Mandant_Lokal = @ClientId AND
						  ([Perioden_Key] BETWEEN @PeriodFrom and @PeriodTo)
				END
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectValuesFiBuD]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage FiBu Tagessalden.
				-- In Parameter:  CompanyCode: Der Buchungskreis, für den die Werte abgefragt werden.
				--				  ClientId: Der Mandant, für den die Werte abgefragt werden.	
				--				  PeriodForm: Anfangsperiode
				--			      PeriodTo: Endperiode
				-- Out Parameter: Mandanten_ID
				--	              Konten_ID
				--                Perioden_Key
				--	              ICPartner_ID
				--	              Segment1_ID
				--	              Segment2_ID
				--				  Saldovortrag
				--				  Soll
				--				  Haben
				--				  Saldo_Periode
				--				  Soll_kum
				--				  Haben_kum
				--				  Saldo
				--				  KontenTyp
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectValuesFiBuD] 
					@CompanyCode VARCHAR(255), 
					@ClientId VARCHAR(255),
					@PeriodFrom INT,
					@PeriodTo INT
				AS
				BEGIN
					SET NOCOUNT ON;
					WITH vCP_SelectValuesFiBuD
					AS
					(
					SELECT
						   [Konten_Key]
						  ,[Konten_ID]
						   ,aaa.Kundenattribut0 AS ICPartner_ID
						   ,aaa.Kundenattribut1 AS Segment1_ID
						   ,aaa.Kundenattribut2 AS Segment2_ID
						  ,[Buchungskreis]
						  ,[Jahr]
						  ,sum([Saldo_Buchung]) as [Saldo_Buchung]
						  ,[Buchungsdatum_Key]
						  ,sum([Saldovortrag]) as [Saldovortrag]
						  ,sum([Haben]) as [Haben]
						  ,[Mandanten_ID]
						  ,sum([Soll]) as [Soll]
					  FROM (
						SELECT
							   [Konten_Key]
							  ,[Konten_ID]
							  ,f.Kundenattribut0 
							  ,f.Kundenattribut1 
							  ,f.Kundenattribut2 
							  ,[Buchungskreis]
								--	   Vorbereitung Buchungskreiszusammenlegung Datev Pro
								--	   case
								--     when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
								--     when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
								--     when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
								--     when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
								--	   else Buchungskreis 
								--     end as Buchungskreis						  
							  ,f.[Perioden_Key]/10000 AS Jahr
							  ,[Saldo_Buchung]
             				  ,CASE WHEN [Buchungsdatum_Key] < 0 THEN dP.PeriodenKalenderjahr * 10000 + dP.PeriodenMonatsmapping * 100 + 1 ELSE [Buchungsdatum_Key] END AS [Buchungsdatum_Key]	
							  ,[Saldovortrag]
							  ,[Haben]
							  ,[Mandanten_ID]
				  			   --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
			  				   --f.Mandant_Lokal AS Mandanten_ID,
							  ,[Soll]
						  FROM [dbo].[sx_dwh_fFiBuBuchungsjournal] f
						  LEFT JOIN [dbo].[sx_dwh_dPerioden] dP ON f.Perioden_Key = dP.Perioden_Key
							--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
							--INNER JOIN sx_dwh_dMandanten M ON M.Mandanten_ID = f.Mandanten_ID
						  ) aaa
					  GROUP BY [Konten_Key]
						  ,[Konten_ID]
						  ,[Buchungskreis]
						  ,[Jahr]
						  ,[Buchungsdatum_Key]
						  ,[Mandanten_ID]
						  ,Kundenattribut0
						  ,Kundenattribut1
						  ,Kundenattribut2
					)
					SELECT 
						   summe.[Mandanten_ID]
						  ,summe.[Konten_ID]
						  ,dKto.[KontenName]
						  ,dKto.[KontenTyp]
						  ,summe.[Buchungskreis]
						  ,summe.ICPartner_ID
						  ,summe.Segment1_ID
						  ,summe.Segment2_ID
						  ,max(summe.[Saldo_Buchung]) AS [Saldo_Periode]
						  ,summe.[Buchungsdatum_Key] AS [Perioden_Key]
						  ,max(summe.[Saldovortrag]) AS [Saldovortrag]
						  ,max(summe.[Haben]) AS [Haben]
						  ,max(summe.[Soll]) AS [Soll]
						  ,summe.[Jahr]
						  ,0 AS [Haben_kum]
						  ,0 AS [Soll_kum]
						  ,0 AS Saldo
				--		  ,sum(kummulation.[Haben]) AS [Haben_kum]
				--		  ,sum(kummulation.[Soll]) AS [Soll_kum]
				--		  ,sum(kummulation.[Saldo_Buchung]) AS Saldo
					FROM [dbo].[vCP_SelectValuesFiBuD] summe
					LEFT JOIN [dbo].[vCP_SelectValuesFiBuD] kummulation
					ON summe.[Konten_Key] = kummulation.[Konten_Key]
					AND summe.[Buchungskreis] = kummulation.[Buchungskreis]
					AND summe.[Jahr] = kummulation.[Jahr]
					AND summe.[Buchungsdatum_Key] >= kummulation.[Buchungsdatum_Key]
					LEFT JOIN [dbo].[sx_dwh_dKonten] dKto
					ON summe.[Konten_Key] = dKto.[Konten_Key]
					WHERE summe.[Buchungskreis] = @CompanyCode
					  AND summe.[Mandanten_ID] = @ClientId
	       				--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						--M.Mandant_Lokal = @ClientId AND
					  AND summe.[Buchungsdatum_Key] BETWEEN @PeriodFrom AND @PeriodTo
					GROUP BY summe.[Mandanten_ID]
						  ,summe.[Konten_Key]
						  ,summe.[Konten_ID]
						  ,dKto.[KontenName]
						  ,dKto.[KontenTyp]
						  ,summe.[Buchungskreis]
						  ,summe.ICPartner_ID
						  ,summe.Segment1_ID
						  ,summe.Segment2_ID
						  ,summe.[Buchungsdatum_Key]
						  ,summe.[Jahr]
				END
			
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectValuesKoRe]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage Kore Salden.
				-- In Parameter:  CompanyCode: Der Buchungskreis, für den die Werte abgefragt werden.
				--				  ClientId: Der Mandant, für den die Werte abgefragt werden.	
				--				  PeriodForm: Anfangsperiode
				--			      PeriodTo: Endperiode
				-- Out Parameter: Mandanten_ID
				--                Kostenstellen_ID
				--                Kostentraeger_ID
				--	              Konten_ID
				--	              ICPartner_ID
				--	              Segment1_ID
				--	              Segment2_ID
				--                Perioden_Key
				--				  Soll
				--				  Haben
				--				  Saldo_Periode
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectValuesKoRe]
					@CompanyCode VARCHAR(255), 
					@ClientId VARCHAR(255),
					@PeriodFrom INT,
					@PeriodTo INT
				AS
				BEGIN
					SET NOCOUNT ON;

					SELECT	Mandanten_ID,
				  		   --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
			  			   --M.Mandant_Lokal AS Mandanten_ID,
							Kostenstellen_ID,
							Kostentraeger_ID,
							Konten_ID,
							V.Kundenattribut0 AS ICPartner_ID,
							V.Kundenattribut1 AS Segment1_ID,
							V.Kundenattribut2 AS Segment2_ID,
							Perioden_Key,
							Soll,
							Haben,
							Saldo_Periode
					FROM	dbo.sx_dwh_fKoRe_P V
					--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
					--INNER JOIN sx_dwh_dMandanten M ON M.Mandanten_ID = V.Mandanten_ID
					WHERE   (Buchungskreis = @CompanyCode) AND 
					--Vorbereitung Buchungskreiszusammenlegung Datev Pro
                    --WHERE (case
                    --            when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
                    --            when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
                    --            when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
                    --            when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
                    --            else Buchungskreis 
                    --        end = @CompanyCode) AND
						  (V.[Mandanten_ID] = @ClientId) AND 
	       				  --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
						  --M.Mandant_Lokal = @ClientId AND
							(Perioden_Key BETWEEN @PeriodFrom AND @PeriodTo)
				END
    		
    	
GO
/****** Object:  StoredProcedure [dbo].[pCP_SelectValuesKoReD]    Script Date: 01.07.2016 11:29:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

    		
				-- =============================================
				-- Author:		  CP Corporate Planning AG, Saxess Software GmbH
				-- Create date:   2016-05-31
				-- Description:	  Abfrage KoRe Tagessalden.
				-- In Parameter:  CompanyCode: Der Buchungskreis, für den die Werte abgefragt werden.
				--				  ClientId: Der Mandant, für den die Werte abgefragt werden.	
				--				  PeriodForm: Anfangsperiode
				--			      PeriodTo: Endperiode
				-- Out Parameter: Mandanten_ID
				--                Kostenstellen_ID
				--                Kostentraeger_ID
				--	              Konten_ID
				--	              ICPartner_ID
				--	              Segment1_ID
				--	              Segment2_ID
				--                Perioden_Key
				--				  Soll
				--				  Haben
				--				  Saldo_Periode
				-- =============================================
				CREATE PROCEDURE [dbo].[pCP_SelectValuesKoReD] 
					@CompanyCode VARCHAR(255), 
					@ClientId VARCHAR(255),
					@PeriodFrom INT,
					@PeriodTo INT
				AS
				BEGIN
					SET NOCOUNT ON;
					SELECT 
						   kore.[Mandanten_ID]
						  ,kore.[Konten_ID]
						  ,dKto.[KontenName]
						  ,dKto.[KontenTyp]
						  ,kore.[Kostenstellen_ID]
						  ,dKst.[KostenstellenName]
						  ,kore.[Kostentraeger_ID]
						  ,dKtr.[KostentraegerName]
						  ,kore.[Buchungskreis]
						  ,kore.ICPartner_ID
						  ,kore.Segment1_ID
						  ,kore.Segment2_ID
						  ,sum(kore.[Saldo_Buchung]) AS [Saldo_Periode]
						  ,CASE WHEN [Buchungsdatum_Key] < 0 THEN dP.PeriodenKalenderjahr * 10000 + dP.PeriodenMonatsmapping * 100 + 1 ELSE [Buchungsdatum_Key] END AS [Buchungsdatum_Key]
						  ,sum(kore.[Haben]) AS [Haben]
						  ,sum(kore.[Soll]) AS [Soll]
						  ,dP.PeriodenKalenderjahr AS Jahr
					FROM (SELECT 
						   [Mandanten_ID]
				  		   --Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
			  			   --M.Mandant_Lokal AS Mandanten_ID,
						  ,[Konten_Key]
						  ,[Konten_ID]
						  ,[Kostenstellen_Key]
						  ,[Kostenstellen_ID]
						  ,[Kostentraeger_Key]
						  ,[Kostentraeger_ID]
						  ,Kundenattribut0 AS ICPartner_ID
						  ,Kundenattribut1 AS Segment1_ID
						  ,Kundenattribut2 AS Segment2_ID
						  ,[Buchungskreis]
							--	   Vorbereitung Buchungskreiszusammenlegung Datev Pro
							--	   case
							--     when '1-HGB' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-HGB'),'6','1-HGB'),'7','1-HGB') 
							--     when '1-Steuerbilanz' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Steuerbilanz'),'6','1-Steuerbilanz'),'8','1-Steuerbilanz')
							--     when '1-Kalkulatorisch' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-Kalkulatorisch'),'6','1-Kalkulatorisch'),'9','1-Kalkulatorisch')
							--     when '1-IFRS' = @CompanyCode then replace(replace(replace(Buchungskreis,'1','1-IFRS'),'6','1-IFRS'),'10','1-IFRS')
							--	   else Buchungskreis 
							--     end as Buchungskreis						  
						  ,[Saldo_Buchung]
						  ,[Perioden_Key]
						  ,[Buchungsdatum_Key]
						  ,[Haben]
						  ,[Soll]
					FROM  [dbo].[sx_dwh_fKoReBuchungsjournal] f
					--Kommentar entfernen, falls die Mandantennummer aus dem Vorsystem verwendet werden soll
					--INNER JOIN sx_dwh_dMandanten M ON M.Mandanten_ID = f.Mandanten_ID
					) kore
					LEFT JOIN [dbo].[sx_dwh_dKonten] dKto
					ON kore.[Konten_Key] = dKto.[Konten_Key]
					LEFT JOIN [dbo].[sx_dwh_dKostenstellen] dKst
					ON kore.[Kostenstellen_Key] = dKst.[Kostenstellen_Key]
					LEFT JOIN [dbo].[sx_dwh_dKostentraeger] dKtr
					ON kore.[Kostentraeger_Key] = dKtr.[Kostentraeger_Key]
					LEFT JOIN [dbo].[sx_dwh_dPerioden] dP
					ON kore.Perioden_Key = dP.Perioden_Key
					WHERE kore.[Buchungskreis] = @CompanyCode
					  AND kore.[Mandanten_ID] = @ClientId
					  AND CASE WHEN [Buchungsdatum_Key] < 0 THEN dP.PeriodenKalenderjahr * 10000 + dP.PeriodenMonatsmapping * 100 + 1 ELSE [Buchungsdatum_Key] END BETWEEN @PeriodFrom AND @PeriodTo
					GROUP BY kore.[Mandanten_ID]
						  ,kore.[Konten_Key]
						  ,kore.[Konten_ID]
						  ,dKto.[KontenName]
						  ,dKto.[KontenTyp]
						  ,kore.[Kostenstellen_ID]
						  ,dKst.[KostenstellenName]
						  ,kore.[Kostentraeger_ID]
						  ,dKtr.[KostentraegerName]
						  ,kore.[Buchungskreis]
						  ,kore.ICPartner_ID
						  ,kore.Segment1_ID
						  ,kore.Segment2_ID
						  ,kore.[Buchungsdatum_Key]
						  ,dP.PeriodenKalenderjahr
						  ,dP.PeriodenMonatsmapping
				END
    		
    	
GO
