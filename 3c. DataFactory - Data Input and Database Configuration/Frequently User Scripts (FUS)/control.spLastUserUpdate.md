### Snippet for POST_PDTV
after END CATCH

����SQL

-----------------------------------------------------------------------------------------------------------------------------
-- #### CUSTOMIZATION ########
	IF @FactoryID <> 'ZT'
		BEGIN
			EXEC control.spLastUserUpdate @TransactUsername,@FactoryID ,@ProductLineID,@ProductID			
		END

-----------------------------------------------------------------------------------------------------------------------------

����