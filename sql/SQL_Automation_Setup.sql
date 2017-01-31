--Creates a program and tag. This will work on client 9991, IF you use a different client you will need to update the @program_fee_group_id_'foo'  found below
--This script requires you manually change the SSO db name the first time it is run against a new environment Daxko_SSO_'foo'.dob.users (search for '--> --> --> -->' to find the lines to be changed)

--Helper variables
DECLARE @member_fee_id int
DECLARE @join_fee_id int

--------------------************************ CLIENT SETUP ****************************----------------------------------------------------------
BEGIN --General Client Setup

	DECLARE @client_id int = 9991
	DECLARE @branch_id int
	DECLARE @branch_name varchar(200) = 'Automation_Branch'
	DECLARE @address_id int
	DECLARE @phone_id int
	DECLARE @user_name varchar(200) = 'automation_user'
	DECLARE @admin_id bigint

	DECLARE @bankaccountid int = (select top 1 BankAccountID from memClientBankAccountsTBL where clientid = @client_id)
	DECLARE @program_fee_group_id int = (select Top 1 ProgramFeeGroupID from memClientProgramFeeGroupsTBL where clientid = @client_id and IsPrimary = 1)
	DECLARE @membership_type_category_id int = (select Top 1 MembershipTypeCategoryID from memClientMembershipTypeCategoriesTBL where clientid = @client_id)
	DECLARE @cash_asset_account_id int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id and RealAccountType = 'Asset')
	DECLARE @write_off_expense_account_id int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id and RealAccountType = 'Expense')
	DECLARE @credit_due_member_account_id int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id and RealAccountType = 'Liability' and CommonName = 'Credits Due to Member Liability Account')
	DECLARE @bad_check_account_id int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id and RealAccountType = 'Revenue' and CommonName = 'Bad Check Charge')
	DECLARE @role_id INT = (SELECT top 1 RoleID FROM dbo.memRolesTBL where RoleName = 'Administrator' AND ClientID = @client_id)

	--Programs and Childcare fee groups
	DECLARE @program_fee_group_id_community_participant int = (select Top 1 ProgramFeeGroupID from memClientProgramFeeGroupsTBL where  clientid = @client_id and ProgramFeeGroupName = 'Community Participant')
	DECLARE @program_fee_group_id_facility_member int = (select Top 1 ProgramFeeGroupID from memClientProgramFeeGroupsTBL where  clientid = @client_id and ProgramFeeGroupName = 'Facility Member')
	DECLARE @program_fee_group_id_program_member int = (select Top 1 ProgramFeeGroupID from memClientProgramFeeGroupsTBL where  clientid = @client_id and ProgramFeeGroupName = 'Program Member')

	--Enables online permission: Block Program Registration When a Balance is Due
	IF NOT EXISTS(select * from memClientsTBL where clientID = @client_id and block_online_reg_has_due = 1)
	BEGIN
		UPDATE dbo.memClientsTBL
		SET block_online_reg_has_due = 1
		WHERE ClientID = @client_id
	END

  --Enables online permission: View Program Registrations
  IF NOT EXISTS(select * from memClientMemberTypesTBL where clientID = @client_id and OnlinePermission = 4091)
    BEGIN
      UPDATE dbo.memClientMemberTypesTBL
      SET OnlinePermission = 4091
      WHERE ClientID = @client_id
    END

	--Creating a New Branch called Automation_Branch on client specified
	IF NOT EXISTS(select * from memClientBranchesTBL where Branch = @branch_name and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientBranchesTBL (ClientID, BranchCode, Branch, SalesTaxEnabled, SalesTaxRate, SalesTaxDescriptionPrefix, BranchAdminEmail, OnlineEnabled)
		VALUES (/*ClientID*/ @client_id, /*BranchCode*/ 'Auto', /*Branch*/ @branch_name, /*SalesTaxEnabled*/ 0, /*SalesTaxRate*/ 0.0000, /*SalesTaxDescriptionPrefix*/ '', /*BranchAdminEmail*/ '', /*OnlineEnabled*/ 1);
		SET @branch_id = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO memSysAddressesTBL (tblName, ColumnName, ID, AddressName, Address1, Address2, City, Zip, Country, state)
		VALUES (/*tblName*/ 'memClientBranchesTBL', /*ColumnName*/ 'Location', /*ID*/ @branch_id, /*AddressName*/ 'Branch Address', /*Address1*/ '509 yorkshire Dr.', /*Address2*/ '', /*City*/ 'Homewood', /*Zip*/ '35209', /*Country*/ '', /*state*/ 'AL');
		SET @address_id = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO memSysPhonesTBL (TblName, ColumnName, PhoneName, ID, CountryCode, AreaCode, Phone, Ext)
		VALUES (/*TblName*/ 'memClientBranchesTBL', /*ColumnName*/ 'BranchPhone', /*PhoneName*/ 'Branch Phone', /*ID*/ @branch_id, /*CountryCode*/ '', /*AreaCode*/ '999', /*Phone*/ '555-5555', /*Ext*/ '');
		SET @phone_id = CAST(SCOPE_IDENTITY() AS INT);

		UPDATE memClientBranchesTBL
		SET Location = @address_id, BranchPhone = @phone_id
		WHERE BranchID = @branch_id

		INSERT INTO ClientMerchantAccounts (BankAccountID, ClientID, BranchID, UserID, Password, Description)
		VALUES (/*BankAccountID*/ @bankaccountid, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*UserID*/ 'daxkollc', /*Password*/ 'Batman334', /*Description*/ 'New Merchant Account for My branch name');

		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, is_system_fee)
		VALUES (/*ClientID*/ @client_id, /*PricingType*/ 'Join Fee', /*Price*/ 0.0000, /*OrgGL*/ 1, /*GLID*/ 0, /*FeeType*/ '0', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*is_system_fee*/ 1);
		SET @join_fee_id = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, is_system_fee)
		VALUES (/*ClientID*/ @client_id, /*PricingType*/ 'Membership Due', /*Price*/ 0.0000, /*OrgGL*/ 1, /*GLID*/ 0, /*FeeType*/ '1', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*is_system_fee*/ 1);
		SET @member_fee_id = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO memClientMembershipTypesTBL (ClientID, BranchID, MembershipType, Term, JoinFeeID, JoinFeeSpreadMonth, MemberFeeID, ProgramFeeGroupID, Enabled, AllowDiscount, ShortDesc, MemberLimit, Online, AutoRenew, DefaultActive, MembershipTypeCategoryID, enable_reciprocity, created, created_by, last_modified, last_modified_by, apply_changes_to_existing_group_members)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*MembershipType*/ 'Non-Member', /*Term*/ '2', /*JoinFeeID*/ @join_fee_id, /*JoinFeeSpreadMonth*/ '1', /*MemberFeeID*/ @member_fee_id, /*ProgramFeeGroupID*/ @program_fee_group_id, /*Enabled*/ 1, /*AllowDiscount*/ 0, /*ShortDesc*/ 'N', /*MemberLimit*/ '-1', /*Online*/ 1, /*AutoRenew*/ 0, /*DefaultActive*/ 1, /*MembershipTypeCategoryID*/ @membership_type_category_id, /*enable_reciprocity*/ 0, /*created*/ '2014-10-13T15:53:38', /*created_by*/ 'stgwilli', /*last_modified*/ '2014-10-13T15:53:38', /*last_modified_by*/ 'stgwilli', /*apply_changes_to_existing_group_members*/ 1);

		IF NOT EXISTS(select * from memBranchAccountsTBL where BranchID = @branch_id)
		BEGIN
			INSERT INTO memBranchAccountsTBL (BranchID, Cash, Swipe, CMD, BadCheck, WriteOffAccount)
			VALUES (/*BranchID*/ @branch_id, /*Cash*/ @cash_asset_account_id, /*Swipe*/ @cash_asset_account_id, /*CMD*/ @credit_due_member_account_id, /*BadCheck*/ @bad_check_account_id, /*WriteOffAccount*/ @write_off_expense_account_id);
		END
		ELSE
		BEGIN
			UPDATE memBranchAccountsTBL
			SET Cash = @cash_asset_account_id, Swipe = @cash_asset_account_id, CMD = @credit_due_member_account_id, BadCheck = @bad_check_account_id, WriteOffAccount = @write_off_expense_account_id
			WHERE BranchID = @branch_id
		END
	END

	IF @branch_id is null
	BEGIN
		select @branch_id = BranchID from memClientBranchesTBL where Branch = @branch_name and ClientID = @client_id
	END

	-- Create user
	IF NOT EXISTS(SELECT * FROM dbo.memClientAdminTBL WHERE UserName = @user_name AND ClientID = @client_id)
	BEGIN
		INSERT INTO dbo.memClientAdminTBL (ClientID, UserName, FirstName, MiddleName, LastName, Title, BranchID, MultiBranch, Email, AccessCode, ChangPSNextLogon, Solicitor, Display, Locked)
		VALUES (/*ClientID*/ @client_id, /*UserName*/ @user_name, /*FirstName*/ 'Automation', /*MiddleName*/ '', /*LastName*/ 'User', /*Title*/ '', /*BranchID*/ @branch_id, /*MultiBranch*/ 1, /*Email*/ '', /*AccessCode*/ 0, /*ChangPSNextLogon*/ 0, /*Solicitor*/ 0, /*Display*/ 1, /*Locked*/ 0);
		SET @admin_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.memRoleAdminLinkTBL (RoleID, AdminID)
		VALUES (/*RoleID*/ @role_id, /*AdminID*/ @admin_id);

		--> --> --> --> THIS IS WHERE YOU HAVE TO MANUALLY SET THE DAXKO_SSO_'foo' NAME <-- <-- <-- <--
		INSERT INTO Daxko_SSO_beta.dbo.users (ops_user_id, client_id, user_name, password, email, password_question, password_answer, is_locked_out, create_date, create_by, last_update_date, last_update_by, last_password_changed_date, failed_password_attempt_count, change_password_next_logon, is_active)
		VALUES (/*ops_user_id*/ @admin_id, /*client_id*/ @client_id, /*user_name*/ @user_name, /*password*/ 'bqGdjYOfgCHtnn+ZTG7Khw==', /*email*/ 'automation@daxko.com', /*password_question*/ 'Place of birth', /*password_answer*/ 'Daxko', /*is_locked_out*/ 0, /*create_date*/ getdate(), /*create_by*/ 'Auto Mation', /*last_update_date*/ getdate(), /*last_update_by*/ 'Auto Mation', /*last_password_changed_date*/ '2040-07-20 08:21:50.037', /*failed_password_attempt_count*/ 0, /*change_password_next_logon*/ 0, /*is_active*/ 1)
	END

	--Setup the 28th as Draft Date
	IF NOT EXISTS(select * from memClientTPDateOptionsTBL where ClientID = @client_id and ProcessDateOption = 28)
	BEGIN
		INSERT INTO dbo.memClientTPDateOptionsTBL (ClientID, ProcessDateOption)
		VALUES (/*ClientID*/ @client_id, /*ProcessDateOption*/ '28');
	END

	--Setup the memClientBankAccountsTBL and Processor Time so we can test Credit cards
	IF NOT EXISTS(select * from memClientBankAccountsTBL where ClientID = @client_id and SettlementTime ='2100-01-01 00:30:00.000' and NameOnAccount = 'Test Client 1' and UserID = 'daxkollc' and Password = 'Batman334')
	BEGIN
		UPDATE dbo.memClientBankAccountsTBL
		SET SettlementTime = '2100-01-01T00:30:00',  NameOnAccount = 'Test Client 1', UserID = 'daxkollc', Password = 'Batman334', AllowVISA = 1, AllowMasterCard = 1, AllowDiscover = 1, AllowSwipe = 1, AVSAddress = 1, AVSZip = 1, Bankserv = 0, ExternalACH = 1, AllowNewEFT = 1, INVNUM = 1, AllowCVV = 1, AllowNewOlgEFT = 1, AllowEft = 1
		WHERE Clientid = @client_id
	END

	--Setup sales tax for test client
	IF NOT EXISTS(select * from dbo.Operations_ClientTaxRates where client_id = @client_id)
	BEGIN
		INSERT INTO [dbo].[Operations_ClientTaxRates]
		([name],[description] ,[current_rate] ,[client_id] ,[date_created] ,[created_by] ,[last_updated_date] ,[updated_by] ,[is_active])
		VALUES (/*name*/'HST',	/*description*/'Harmonized sales tax rate 10%', /*current_rate*/ 0.1000, /*client_id*/@client_id,	/*date_created*/getdate(),	/*created_by*/'Butch Mayhew', /*last_updated_date*/getdate(),	/*updated_by*/'Butch Mayhew',/*is_active*/1),
			(/*name*/'GST',	/*description*/'Goods and Services sales tax rate 3%', /*current_rate*/ 0.0300,	/*client_id*/@client_id,	/*date_created*/getdate(),	/*created_by*/'Butch Mayhew',	/*last_updated_date*/getdate(),	/*updated_by*/'Butch Mayhew', /*is_active*/	1),
			(/*name*/'PST',	/*description*/'Provincial sales tax rate 7%', /*current_rate*/ 0.0700,	/*client_id*/@client_id,	/*date_created*/getdate(),	/*created_by*/'Butch Mayhew',	/*last_updated_date*/getdate(),	/*updated_by*/'Butch Mayhew',	/*is_active*/1)
	END
END

--------------------************************ AGE GROUPS - Setup alternate client & branch for testing Age Groups & Limit Members  ****************************----------------------------------------------------------
BEGIN --AGE GROUPS

	DECLARE @client_id_for_age_groups int = 2021
	DECLARE @admin_id_for_age_groups bigint
	DECLARE @branch_id_for_age_groups int
	DECLARE @branch_name_for_age_groups varchar(200) = 'Automation_Branch'
	DECLARE @address_id_for_age_groups int
	DECLARE @phone_id_for_age_groups int
	DECLARE @user_name_for_age_groups varchar(200) = 'automation_age_groups_user'
	DECLARE @rev_gl_id_for_age_groups int
	DECLARE @rev_gl_name_for_age_groups varchar(200) = '99-9999-00000-0000-1'
	DECLARE @membership_type_id_for_age_groups int
	DECLARE @membership_type_name_for_age_groups varchar(200) = 'Automation_50_Monthly'

	DECLARE @bankaccountid_for_age_groups int = (select top 1 BankAccountID from memClientBankAccountsTBL where clientid = @client_id_for_age_groups)
	DECLARE @program_fee_group_id_for_age_groups int = (select Top 1 ProgramFeeGroupID from memClientProgramFeeGroupsTBL where clientid = @client_id_for_age_groups and IsPrimary = 1)
	DECLARE @membership_type_category_id_for_age_groups int = (select Top 1 MembershipTypeCategoryID from memClientMembershipTypeCategoriesTBL where clientid = @client_id_for_age_groups)
	DECLARE @cash_asset_account_id_for_age_groups int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id_for_age_groups and RealAccountType = 'Asset')
	DECLARE @write_off_expense_account_id_for_age_groups int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id_for_age_groups and RealAccountType = 'Expense')
	DECLARE @credit_due_member_account_id_for_age_groups int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id_for_age_groups and RealAccountType = 'Liability' and CommonName = 'Credits Due to Member Liability Account')
	DECLARE @bad_check_account_id_for_age_groups int = (select top 1 glid from memClientJournalEntryAccountsTBL where clientID = @client_id_for_age_groups and RealAccountType = 'Revenue' and CommonName = 'Bad Check Charge')
	DECLARE @role_id_for_age_groups INT = (SELECT top 1 RoleID FROM dbo.memRolesTBL where RoleName = 'Administrator' AND ClientID = @client_id_for_age_groups)
	DECLARE @prog_fee_group_id_for_age_groups int = (select top 1 ProgramFeeGroupID from memClientProgramFeeGroupsTBL where clientid = @client_id_for_age_groups and ProgramFeeGroupName = 'Facility Member')
	DECLARE @mem_type_category_id_for_age_groups int = (select top 1 MembershipTypeCategoryID from memClientMembershipTypeCategoriesTBL where clientid = @client_id_for_age_groups and Name = 'Facility Member')
	DECLARE @ar_gl_id_for_age_groups int  = (select top 1 GLID from memClientJournalEntryAccountsTBL where clientid = @client_id_for_age_groups and CommonName ='A/R')
	DECLARE @def_gl_id_for_age_groups int = (select top 1 GLID from memClientJournalEntryAccountsTBL where clientid = @client_id_for_age_groups and CommonName ='Deferred Revenue')
	DECLARE @pr_gl_id_for_age_groups int  = (select top 1 GLID from memClientJournalEntryAccountsTBL where clientid = @client_id_for_age_groups and CommonName ='P/R')

	--Creating a New Branch called Automation_Branch on client specified
	IF NOT EXISTS(select * from memClientBranchesTBL where Branch = @branch_name_for_age_groups and ClientID = @client_id_for_age_groups)
	BEGIN
		INSERT INTO memClientBranchesTBL (ClientID, BranchCode, Branch, SalesTaxEnabled, SalesTaxRate, SalesTaxDescriptionPrefix, BranchAdminEmail, OnlineEnabled)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*BranchCode*/ 'Auto', /*Branch*/ @branch_name_for_age_groups, /*SalesTaxEnabled*/ 0, /*SalesTaxRate*/ 0.0000, /*SalesTaxDescriptionPrefix*/ '', /*BranchAdminEmail*/ '', /*OnlineEnabled*/ 1);
		SET @branch_id_for_age_groups = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO memSysAddressesTBL (tblName, ColumnName, ID, AddressName, Address1, Address2, City, Zip, Country, state)
		VALUES (/*tblName*/ 'memClientBranchesTBL', /*ColumnName*/ 'Location', /*ID*/ @branch_id_for_age_groups, /*AddressName*/ 'Branch Address', /*Address1*/ '509 yorkshire Dr.', /*Address2*/ '', /*City*/ 'Homewood', /*Zip*/ '35209', /*Country*/ '', /*state*/ 'AL');
		SET @address_id_for_age_groups = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO memSysPhonesTBL (TblName, ColumnName, PhoneName, ID, CountryCode, AreaCode, Phone, Ext)
		VALUES (/*TblName*/ 'memClientBranchesTBL', /*ColumnName*/ 'BranchPhone', /*PhoneName*/ 'Branch Phone', /*ID*/ @branch_id_for_age_groups, /*CountryCode*/ '', /*AreaCode*/ '999', /*Phone*/ '555-5555', /*Ext*/ '');
		SET @phone_id_for_age_groups = CAST(SCOPE_IDENTITY() AS INT);

		UPDATE memClientBranchesTBL
		SET Location = @address_id_for_age_groups, BranchPhone = @phone_id_for_age_groups
		WHERE BranchID = @branch_id_for_age_groups

		INSERT INTO ClientMerchantAccounts (BankAccountID, ClientID, BranchID, UserID, Password, Description)
		VALUES (/*BankAccountID*/ @bankaccountid_for_age_groups, /*ClientID*/ @client_id_for_age_groups, /*BranchID*/ @branch_id_for_age_groups, /*UserID*/ 'daxkollc', /*Password*/ 'Batman334', /*Description*/ 'New Merchant Account for My branch name');

		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, is_system_fee)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*PricingType*/ 'Join Fee', /*Price*/ 0.0000, /*OrgGL*/ 1, /*GLID*/ 0, /*FeeType*/ '0', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*is_system_fee*/1);
		SET @join_fee_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, is_system_fee)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*PricingType*/ 'Membership Due', /*Price*/ 0.0000, /*OrgGL*/ 1, /*GLID*/ 0, /*FeeType*/ '1', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*is_system_fee*/1);
		SET @member_fee_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memClientMembershipTypesTBL (ClientID, BranchID, MembershipType, Term, JoinFeeID, JoinFeeSpreadMonth, MemberFeeID, ProgramFeeGroupID, Enabled, AllowDiscount, ShortDesc, MemberLimit, Online, AutoRenew, DefaultActive, MembershipTypeCategoryID, enable_reciprocity, created, created_by, last_modified, last_modified_by, apply_changes_to_existing_group_members)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*BranchID*/ @branch_id_for_age_groups, /*MembershipType*/ 'Non-Member', /*Term*/ '2', /*JoinFeeID*/ @join_fee_id, /*JoinFeeSpreadMonth*/ '1', /*MemberFeeID*/ @member_fee_id, /*ProgramFeeGroupID*/ @program_fee_group_id_for_age_groups, /*Enabled*/ 1, /*AllowDiscount*/ 0, /*ShortDesc*/ 'N', /*MemberLimit*/ '-1', /*Online*/ 1, /*AutoRenew*/ 0, /*DefaultActive*/ 1, /*MembershipTypeCategoryID*/ @membership_type_category_id_for_age_groups, /*enable_reciprocity*/ 0, /*created*/ '2014-10-13T15:53:38', /*created_by*/ 'stgwilli', /*last_modified*/ '2014-10-13T15:53:38', /*last_modified_by*/ 'stgwilli', /*apply_changes_to_existing_group_members*/ 1);

		IF NOT EXISTS(select * from memBranchAccountsTBL where BranchID = @branch_id_for_age_groups)
		BEGIN
			INSERT INTO memBranchAccountsTBL (BranchID, Cash, Swipe, CMD, BadCheck, WriteOffAccount)
			VALUES (/*BranchID*/ @branch_id_for_age_groups, /*Cash*/ @cash_asset_account_id_for_age_groups, /*Swipe*/ @cash_asset_account_id_for_age_groups, /*CMD*/ @credit_due_member_account_id_for_age_groups, /*BadCheck*/ @bad_check_account_id_for_age_groups, /*WriteOffAccount*/ @write_off_expense_account_id_for_age_groups);
		END
		ELSE
		BEGIN
			UPDATE memBranchAccountsTBL
			SET Cash = @cash_asset_account_id_for_age_groups, Swipe = @cash_asset_account_id_for_age_groups, CMD = @credit_due_member_account_id_for_age_groups, BadCheck = @bad_check_account_id_for_age_groups, WriteOffAccount = @write_off_expense_account_id_for_age_groups
			WHERE BranchID = @branch_id_for_age_groups
		END
	END

	IF @branch_id_for_age_groups is null
	BEGIN
		select @branch_id_for_age_groups = BranchID from memClientBranchesTBL where Branch = @branch_name_for_age_groups and ClientID = @client_id_for_age_groups
	END
	
	-- Create user ****** UPDATE FOR AGE GROUPS
	IF NOT EXISTS(SELECT * FROM dbo.memClientAdminTBL WHERE UserName = @user_name_for_age_groups AND ClientID = @client_id_for_age_groups)
	BEGIN
		INSERT INTO dbo.memClientAdminTBL (ClientID, UserName, FirstName, MiddleName, LastName, Title, BranchID, MultiBranch, Email, AccessCode, ChangPSNextLogon, Solicitor, Display, Locked)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*UserName*/ @user_name_for_age_groups, /*FirstName*/ 'Automation', /*MiddleName*/ '', /*LastName*/ 'User', /*Title*/ '', /*BranchID*/ @branch_id_for_age_groups, /*MultiBranch*/ 1, /*Email*/ '', /*AccessCode*/ 0, /*ChangPSNextLogon*/ 0, /*Solicitor*/ 0, /*Display*/ 1, /*Locked*/ 0);
		SET @admin_id_for_age_groups = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.memRoleAdminLinkTBL (RoleID, AdminID)
		VALUES (/*RoleID*/ @role_id_for_age_groups, /*AdminID*/ @admin_id_for_age_groups);

		--> --> --> --> THIS IS WHERE YOU HAVE TO MANUALLY SET THE DAXKO_SSO_'foo' NAME <-- <-- <-- <--
		INSERT INTO Daxko_SSO_beta.dbo.users (ops_user_id, client_id, user_name, password, email, password_question, password_answer, is_locked_out, create_date, create_by, last_update_date, last_update_by, last_password_changed_date, failed_password_attempt_count, change_password_next_logon, is_active)
		VALUES (/*ops_user_id*/ @admin_id_for_age_groups, /*client_id*/ @client_id_for_age_groups, /*user_name*/ @user_name_for_age_groups, /*password*/ 'bqGdjYOfgCHtnn+ZTG7Khw==', /*email*/ 'automation@daxko.com', /*password_question*/ 'Place of birth', /*password_answer*/ 'Daxko', /*is_locked_out*/ 0, /*create_date*/ getdate(), /*create_by*/ 'Auto Mation', /*last_update_date*/ getdate(), /*last_update_by*/ 'Auto Mation', /*last_password_changed_date*/ '2040-07-20 08:21:50.037', /*failed_password_attempt_count*/ 0, /*change_password_next_logon*/ 0, /*is_active*/ 1)
	END

	--Setup the memClientBankAccountsTBL and Processor Time so we can test Credit cards
	IF NOT EXISTS(select * from memClientBankAccountsTBL where ClientID = @client_id_for_age_groups and SettlementTime ='2100-01-01 00:30:00.000' and NameOnAccount = 'Test Client 1' and UserID = 'daxkollc' and Password = 'Batman334')
	BEGIN
		UPDATE dbo.memClientBankAccountsTBL
		SET SettlementTime = '2100-01-01T00:30:00',  NameOnAccount = 'Test Client 1', UserID = 'daxkollc', Password = 'Batman334', AllowVISA = 1, AllowMasterCard = 1, AllowDiscover = 1, AllowSwipe = 1, AVSAddress = 1, AVSZip = 1, Bankserv = 0, ExternalACH = 1, AllowNewEFT = 1, INVNUM = 1, AllowCVV = 1, AllowNewOlgEFT = 1, AllowEft = 1
		WHERE Clientid = @client_id_for_age_groups
	END

	--Add new GL for Revenue
	IF NOT EXISTS(select * from memClientJournalEntryAccountsTBL where AccountName = @rev_gl_name_for_age_groups and BranchID = @branch_id_for_age_groups and ClientID = @client_id_for_age_groups)
	BEGIN
		INSERT INTO memClientJournalEntryAccountsTBL (GLNo, ClientID, AccountName, BranchID, Deferred, ShowMembership, ShowProgram, ShowFundraising, ShowFeeSetup, Display, ShowAllBranch, EntryDateTimeStamp, ARGLID, DeferredGLID, PRGLID, RealAccountType)
		VALUES (/*GLNo*/ 'Merchandise Sales', /*ClientID*/ @client_id_for_age_groups, /*AccountName*/ @rev_gl_name_for_age_groups, /*BranchID*/ @branch_id_for_age_groups, /*Deferred*/ 0, /*ShowMembership*/ 1, /*ShowProgram*/ 1, /*ShowFundraising*/ 0, /*ShowFeeSetup*/ 1, /*Display*/ 1, /*ShowAllBranch*/ 1, /*EntryDateTimeStamp*/ '2014-10-13T14:10:51.363', /*ARGLID*/ @ar_gl_id_for_age_groups, /*DeferredGLID*/ @def_gl_id_for_age_groups, /*PRGLID*/ @pr_gl_id_for_age_groups, /*RealAccountType*/ 'Revenue');
		SET @rev_gl_id_for_age_groups = CAST(SCOPE_IDENTITY() AS int);
	END

	IF @rev_gl_id_for_age_groups is null
	BEGIN
		select @rev_gl_id_for_age_groups = GLID from memClientJournalEntryAccountsTBL where AccountName = @rev_gl_name_for_age_groups and BranchID = @branch_id_for_age_groups and ClientID = @client_id_for_age_groups
	END

	--Add New Membership Type 50.00 Monthly with 75.00 Join fee
	IF NOT EXISTS (select * from memClientMembershipTypesTBL where Membershiptype = @membership_type_name_for_age_groups and BranchID = @branch_id_for_age_groups and ClientID = @client_id_for_age_groups)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent, is_system_fee)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*PricingType*/ 'Join Fee', /*Price*/ 75.0000, /*OrgGL*/ 1, /*GLID*/ @rev_gl_id_for_age_groups, /*FeeType*/ '0', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0, /*is_system_fee*/1);
		SET @join_fee_id= CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent, is_system_fee)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*PricingType*/ 'Membership Due', /*Price*/ 50.0000, /*OrgGL*/ 1, /*GLID*/ @rev_gl_id_for_age_groups, /*FeeType*/ '1', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0, /*is_system_fee*/1);
		SET @member_fee_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memClientMembershipTypesTBL (ClientID, BranchID, MembershipType, Term, JoinFeeID, JoinFeeSpreadMonth, MemberFeeID, ProgramFeeGroupID, Enabled, AllowDiscount, ShortDesc, MemberLimit, Online, AutoRenew, DefaultActive, MembershipTypeCategoryID, enable_reciprocity, created, created_by, last_modified, last_modified_by, apply_changes_to_existing_group_members)
		VALUES (/*ClientID*/ @client_id_for_age_groups, /*BranchID*/ @branch_id_for_age_groups, /*MembershipType*/ @membership_type_name_for_age_groups, /*Term*/ '0', /*JoinFeeID*/ @join_fee_id, /*JoinFeeSpreadMonth*/ '1', /*MemberFeeID*/ @member_fee_id, /*ProgramFeeGroupID*/ @prog_fee_group_id_for_age_groups, /*Enabled*/ 1, /*AllowDiscount*/ 1, /*ShortDesc*/ 'Auto_50', /*MemberLimit*/ '-1', /*Online*/ 1, /*AutoRenew*/ 1, /*DefaultActive*/ 1, /*MembershipTypeCategoryID*/ @mem_type_category_id_for_age_groups, /*enable_reciprocity*/ 0, /*created*/ '2014-10-13T14:35:43', /*created_by*/ 'bmayhew', /*last_modified*/ '2014-10-13T14:35:43', /*last_modified_by*/ 'bmayhew', /*apply_changes_to_existing_group_members*/ 1);
		SET @membership_type_id_for_age_groups = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memMembershipBranchAccessTBL (BranchId, MembershipTypeId)
		VALUES (/*BranchId*/ @branch_id_for_age_groups, /*MembershipTypeId*/ @membership_type_id_for_age_groups);
	END

END

--------------------************************ CLIENT TAX AND GL SETUP ****************************----------------------------------------------------------
BEGIN --Client Tax and GL Setup

	DECLARE @sales_tax_gl_id int
	DECLARE @sales_tax_glno varchar(200) = '99-9999-00000-15221-1'
	DECLARE @rev_gl_id int
	DECLARE @rev_glno varchar(200) = '99-9999-00000-0000-1'
	DECLARE @rev_pledge_gl_id int
	DECLARE @rev_pledge_glno varchar(200) = '99-9999-00000-0001-1'
	DECLARE @asset_cash_gl_id int
	DECLARE @asset_cash_glno varchar(200) = '99-9999-99999-9999-1'

	DECLARE @ar_gl_id int  = (select top 1 GLID from memClientJournalEntryAccountsTBL where clientid = @client_id and CommonName ='A/R')
	DECLARE @def_gl_id int = (select top 1 GLID from memClientJournalEntryAccountsTBL where clientid = @client_id and CommonName ='Deferred Revenue')
	DECLARE @pr_gl_id int  = (select top 1 GLID from memClientJournalEntryAccountsTBL where clientid = @client_id and CommonName ='P/R')

	--Add new GL for Pledge Revenue
	IF NOT EXISTS(select * from memClientJournalEntryAccountsTBL where GLNo = @sales_tax_glno and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientJournalEntryAccountsTBL (GLNo, ClientID, AccountName, CommonName, BranchID, Deferred, ShowMembership, ShowProgram, ShowFundraising, ShowFeeSetup, Display, ShowAllBranch, EntryDateTimeStamp, ARGLID, DeferredGLID, PRGLID, RealAccountType)
		VALUES (/*GLNo*/ @sales_tax_glno, /*ClientID*/ @client_id, /*AccountName*/ 'Automation Sales Tax GL', /*CommonName*/'Sales Tax', /*BranchID*/ @branch_id, /*Deferred*/ 0, /*ShowMembership*/ 0, /*ShowProgram*/ 0, /*ShowFundraising*/ 1, /*ShowFeeSetup*/ 1, /*Display*/ 1, /*ShowAllBranch*/ 1, /*EntryDateTimeStamp*/ '2014-10-13T14:10:51.363', /*ARGLID*/ @ar_gl_id, /*DeferredGLID*/ null, /*PRGLID*/ null, /*RealAccountType*/ 'Liability');
		SET @sales_tax_gl_id = CAST(SCOPE_IDENTITY() AS int);
	END

	IF @sales_tax_gl_id is null
	BEGIN
		select @sales_tax_gl_id = GLID from memClientJournalEntryAccountsTBL where GLNo = @sales_tax_glno and BranchID = @branch_id and ClientID = @client_id
	END

	IF NOT EXISTS(select * from Operations_TaxRates where branch_id = @branch_id and client_id = @client_id)
	BEGIN
		MERGE dbo.Operations_TaxRates AS target
		USING (select  client_tax.client_tax_rate_id, tax.tax_rate_id, client_tax.client_id, tax.branch_id,
						 isNull(tax.current_rate, client_tax.current_rate) as current_rate, client_tax.current_rate as client_current_rate,
						 isNull(tax.name, client_tax.name) as name, isNull(tax.description, client_tax.description) as description,
						 isNull(tax.tax_account, @sales_tax_gl_id) as tax_account, isNull(tax.is_active, 1) as is_active
					 from (select * from dbo.Operations_ClientTaxRates (nolock) where is_active = 1 And client_id = @client_id) client_tax
						 left join (select * from dbo.Operations_TaxRates (nolock) where branch_id = @branch_id) tax on tax.client_tax_rate_id = client_tax.client_tax_rate_id ) AS source
		ON target.client_tax_rate_id = source.client_tax_rate_id and target.tax_rate_id = source.tax_rate_id
		WHEN MATCHED
		THEN UPDATE
			SET target.is_active = source.is_active,
				target.current_rate = source.current_rate,
				target.tax_account = source.tax_account,
				target.last_updated_date = getdate()

		WHEN NOT MATCHED BY TARGET THEN
		INSERT (name, description, current_rate, client_id, branch_id, tax_account, created_by, updated_by, client_tax_rate_id, is_active, date_created, last_updated_date)
			VALUES (source.name, source.description, source.current_rate, @client_id, @branch_id, source.tax_account, @user_name, @user_name,
							source.client_tax_rate_id, source.is_active, getdate(), getdate());
	END

	--Add new GL for Revenue
	IF NOT EXISTS(select * from memClientJournalEntryAccountsTBL where GLNo = @rev_glno and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientJournalEntryAccountsTBL (GLNo, ClientID, AccountName, BranchID, Deferred, ShowMembership, ShowProgram, ShowFundraising, ShowFeeSetup, Display, ShowAllBranch, EntryDateTimeStamp, ARGLID, DeferredGLID, PRGLID, RealAccountType)
		VALUES (/*GLNo*/ @rev_glno, /*ClientID*/ @client_id, /*AccountName*/ 'Merchandise Sales', /*BranchID*/ @branch_id, /*Deferred*/ 0, /*ShowMembership*/ 1, /*ShowProgram*/ 1, /*ShowFundraising*/ 0, /*ShowFeeSetup*/ 1, /*Display*/ 1, /*ShowAllBranch*/ 1, /*EntryDateTimeStamp*/ '2014-10-13T14:10:51.363', /*ARGLID*/ @ar_gl_id, /*DeferredGLID*/ @def_gl_id, /*PRGLID*/ @pr_gl_id, /*RealAccountType*/ 'Revenue');
		SET @rev_gl_id = CAST(SCOPE_IDENTITY() AS int);
	END

	IF @rev_gl_id is null
	BEGIN
		select @rev_gl_id = GLID from memClientJournalEntryAccountsTBL where GLNo = @rev_glno and BranchID = @branch_id and ClientID = @client_id
	END

	--Add new GL for Pledge Revenue
	IF NOT EXISTS(select * from memClientJournalEntryAccountsTBL where GLNo = @rev_pledge_glno and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientJournalEntryAccountsTBL (GLNo, ClientID, AccountName, BranchID, Deferred, ShowMembership, ShowProgram, ShowFundraising, ShowFeeSetup, Display, ShowAllBranch, EntryDateTimeStamp, ARGLID, DeferredGLID, PRGLID, RealAccountType)
		VALUES (/*GLNo*/ @rev_pledge_glno, /*ClientID*/ @client_id, /*AccountName*/ 'Automation Pledge Revenue GL', /*BranchID*/ @branch_id, /*Deferred*/ 0, /*ShowMembership*/ 0, /*ShowProgram*/ 0, /*ShowFundraising*/ 1, /*ShowFeeSetup*/ 1, /*Display*/ 1, /*ShowAllBranch*/ 1, /*EntryDateTimeStamp*/ '2014-10-13T14:10:51.363', /*ARGLID*/ @ar_gl_id, /*DeferredGLID*/ @def_gl_id, /*PRGLID*/ @pr_gl_id, /*RealAccountType*/ 'Revenue');
		SET @rev_pledge_gl_id = CAST(SCOPE_IDENTITY() AS int);
	END

	IF @rev_pledge_gl_id is null
	BEGIN
		select @rev_pledge_gl_id = GLID from memClientJournalEntryAccountsTBL where GLNo = @rev_pledge_glno and BranchID = @branch_id and ClientID = @client_id
	END

	--Add new Asset Cash Account
	IF NOT EXISTS(select * from memClientJournalEntryAccountsTBL where GLNo = @asset_cash_glno and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientJournalEntryAccountsTBL (GLNo, ClientID, AccountName, CommonName, BranchID, Deferred, ShowMembership, ShowProgram, ShowFundraising, ShowFeeSetup, Display, ShowAllBranch, EntryDateTimeStamp, ARGLID, IsAssetAccount, RealAccountType)
		VALUES (/*GLNo*/ @asset_cash_glno, /*ClientID*/ @client_id, /*AccountName*/ 'Automation_Cash_Account', /*CommonName*/ 'Cash Account', /*BranchID*/ @branch_id, /*Deferred*/ 0, /*ShowMembership*/ 0, /*ShowProgram*/ 0, /*ShowFundraising*/ 0, /*ShowFeeSetup*/ 0, /*Display*/ 1, /*ShowAllBranch*/ 1, /*EntryDateTimeStamp*/ '2014-10-13T14:10:51.363', /*ARGLID*/ @ar_gl_id, /*IsAssetAccount*/ 0, /*RealAccountType*/ 'Asset');
		SET @asset_cash_gl_id = CAST(SCOPE_IDENTITY() AS INT);
	END

	IF @asset_cash_gl_id is null
	BEGIN
		select @asset_cash_gl_id = GLID from memClientJournalEntryAccountsTBL where GLNo = @asset_cash_glno and BranchID = @branch_id and ClientID = @client_id
	END
END

--------------------************************ FEES ****************************----------------------------------------------------------
BEGIN --FEES
	DECLARE @fee_with_20_tax_id int
	DECLARE @fee_10_with_20p_tax_name varchar(250) = 'Automation_10.00_with_20%_3_tax'
	DECLARE @fee_with_10_tax_id int
	DECLARE @fee_10_with_10p_tax_name varchar(250) = 'Automation_10.00_with_10%_1_tax'
	DECLARE @fee_5_name varchar(250) = 'Automation_5.00'
	DECLARE @fee_10_recurring_name varchar(250) = 'Automation_Recurring_Fee_10.00'
	DECLARE @fee_custom_recurring_name varchar(250) = 'Automation_Recurring_Fee_Custom'
	DECLARE @fee_custom_name varchar(250) = 'Automation_Custom_Amount'
	DECLARE @fast_fee_21_name varchar(250) = 'Automation_Fast_Fee'
	DECLARE @fast_fee_custom_name varchar(250) = 'Automation_Fast_Fee_Custom'

	--Add new 10.00 fee with 20% 3_tax tied to the merchant account
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @fee_10_with_20p_tax_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fee_10_with_20p_tax_name, /*Price*/ 10.0000, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '3', /*MaxQty*/ '0', /*Description*/ '$10.00 Fee with 20% 3 tax for Automation tests to use', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 1, /*affects_tax*/ 0, /*discount_percent*/ 0);
		SET @fee_with_20_tax_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO [dbo].[Operations_FeeTaxRates]
					 ([tax_rate_id],[pricing_type_id],[date_created],[created_by],[last_updated_date],[updated_by])
		select tax_rate_id, @fee_with_20_tax_id, getdate(), @user_name,  getdate(), @user_name
		from Operations_TaxRates
		where client_id = @client_id and branch_id = @branch_id
	END

	--Add new 10.00 fee with 10% 1_tax tied to the merchant account
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @fee_10_with_10p_tax_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fee_10_with_10p_tax_name, /*Price*/ 10.0000, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '3', /*MaxQty*/ '0', /*Description*/ '$10.00 Fee with 10% 1 tax for Automation tests to use', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 1, /*affects_tax*/ 0, /*discount_percent*/ 0);
		SET @fee_with_10_tax_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO [dbo].[Operations_FeeTaxRates]
					 ([tax_rate_id],[pricing_type_id],[date_created],[created_by],[last_updated_date],[updated_by])
		select tax_rate_id, @fee_with_10_tax_id, getdate(), @user_name,  getdate(), @user_name
		from Operations_TaxRates
		where client_id = @client_id and branch_id = @branch_id and current_rate = 0.1000
	END

	--Add new 5.00 fee tied to the merchant account
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @fee_5_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fee_5_name, /*Price*/ 5.0000, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '3', /*MaxQty*/ '0', /*Description*/ '$5.00 Fee for Automation tests to use', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add new 10.00 Recurring Fee
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @fee_10_recurring_name and clientid = @client_id and branchID = @branch_id )
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fee_10_recurring_name, /*Price*/ 10.00, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '1', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add new custom Recurring Fee
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @fee_custom_recurring_name and clientid = @client_id and branchID = @branch_id )
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fee_custom_recurring_name, /*Price*/ 0.00, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '4', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add new custom fee
	IF NOT EXISTS (select * from memClientPricingTypesTBL where PricingType = @fee_custom_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fee_custom_name, /*Price*/ 0.0000, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '3', /*MaxQty*/ '0', /*Description*/ 'Automation Fee with custom amount.', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add Fast Feeing Fee
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @fast_fee_21_name and clientid = @client_id and branchID = @branch_id )
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fast_fee_21_name, /*Price*/ 21.00, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '0', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 1, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add Fast Feeing Fee with custom amount
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @fast_fee_custom_name and clientid = @client_id and branchID = @branch_id )
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @fast_fee_custom_name, /*Price*/ 0.00, /*OrgGL*/ 0, /*GLID*/ @rev_gl_id, /*FeeType*/ '3', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 1, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END
END

--------------------************************ ADJUSTMENTS ****************************----------------------------------------------------------
BEGIN --Adjustments
	DECLARE @adjustment_2_recurring_name VARCHAR(250) = 'Automation_Recurring_Adjustment_2.00'
	DECLARE @adjustment_custom_recurring_name VARCHAR(250) = 'Automation_Recurring_Adjustment_Custom'
	DECLARE @adjustment_1_name VARCHAR(250) = 'Automation_1.00_Adjustment'
	DECLARE @adjustment_custom_name VARCHAR(250) = 'Automation_Custom_Adjustment'
	DECLARE @adjustment_another_custom_name VARCHAR(250) = 'Automation_Another_Custom_Adjustment'

	--Add new 2.00 recurring adjustment tied to original GL
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @adjustment_2_recurring_name and clientid = @client_id and branchID = @branch_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @adjustment_2_recurring_name, /*Price*/ 2.00, /*OrgGL*/ 1, /*FeeType*/ '1', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 1, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add new custom recurring adjustment tied to original GL
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @adjustment_custom_recurring_name and clientid = @client_id and branchID = @branch_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @adjustment_custom_recurring_name, /*Price*/ 0.00, /*OrgGL*/ 1, /*FeeType*/ '4', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 1, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add new 1.00 adjustment tied to the merchant account
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @adjustment_1_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @adjustment_1_name, /*Price*/ 1.0000, /*OrgGL*/ 1, /*FeeType*/ '0', /*MaxQty*/ '0', /*Description*/ '$1.00 off Adjustment for Automation tests to use', /*Discount*/ 1, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add new custom adjustment
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @adjustment_custom_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @adjustment_custom_name, /*Price*/ 0.0000, /*OrgGL*/ 1, /*FeeType*/ '0', /*MaxQty*/ '0', /*Description*/ 'Custom amount off Adjustment for Automation tests to use', /*Discount*/ 1, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--Add another custom adjustment
	IF NOT EXISTS(select * from memClientPricingTypesTBL where PricingType = @adjustment_another_custom_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @adjustment_another_custom_name, /*Price*/ 0.0000, /*OrgGL*/ 1, /*FeeType*/ '0', /*MaxQty*/ '0', /*Description*/ 'Custom amount off Adjustment for Automation tests to use', /*Discount*/ 1, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0);
	END

	--set up program scholarship pricing type
	INSERT INTO memClientPricingTypesTBL
	(ClientID, PricingType,  Price,  GLID, FeeType, [Description] , MaxQty, Discount, BranchID, OrgGL, SalesTaxApplies, IsFastFee, Display, discount_percent, affects_tax, is_system_fee)
		select ClientID, 'Program scholarship' as PricingType, 0 as Price, null as GLID, 11 as FeeType, 'Programs scholarship' as [Description], 0 as MaxQty, 1 as Discount, null as BranchID, 0 as OrgGL, 0 as SalesTaxApplies, 0 as IsFastFee, 0 as Display, 1 as discount_percent, 0 as affects_tax, 1 as is_system_fee
		from memClientsTBL
		where ClientID not in (select ClientID from memClientPricingTypesTBL where PricingType = 'Programs scholarship' and is_system_fee = 1)
					and ClientID = @client_id

	INSERT INTO memClientPricingTypesTBL
	(ClientID, PricingType,  Price,  GLID, FeeType, [Description] , MaxQty, Discount, BranchID, OrgGL, SalesTaxApplies, IsFastFee, Display, discount_percent, affects_tax, is_system_fee)
		select ClientID, 'Child Care scholarship' as PricingType, 0 as Price, null as GLID, 12 as FeeType, 'Child Care scholarship' as [Description], 0 as MaxQty, 1 as Discount, null as BranchID, 0 as OrgGL, 0 as SalesTaxApplies, 0 as IsFastFee, 0 as Display, 1 as discount_percent, 0 as affects_tax, 1 as is_system_fee
		from memClientsTBL
		where ClientID not in (select ClientID from memClientPricingTypesTBL where PricingType = 'Child Care scholarship' and is_system_fee = 1)
					and ClientID = @client_id

	INSERT INTO memClientPricingTypesTBL
	(ClientID, PricingType,  Price,  GLID, FeeType, [Description] , MaxQty, Discount, BranchID, OrgGL, SalesTaxApplies, IsFastFee, Display, discount_percent, affects_tax, is_system_fee)
		select ClientID, 'Camp scholarship' as PricingType, 0 as Price, null as GLID, 13 as FeeType, 'Camp scholarship' as [Description], 0 as MaxQty, 1 as Discount, null as BranchID, 0 as OrgGL, 0 as SalesTaxApplies, 0 as IsFastFee, 0 as Display, 1 as discount_percent, 0 as affects_tax, 1 as is_system_fee
		from memClientsTBL
		where ClientID not in (select ClientID from memClientPricingTypesTBL where PricingType = 'Camp scholarship' and is_system_fee = 1)
					and ClientID = @client_id
END

--------------------************************ PROGRAMS ****************************----------------------------------------------------------
BEGIN --Programs
	DECLARE @program_template_id int
	DECLARE @program_template_name varchar(50) = 'Automation_Programs_Static'
	DECLARE @program_template_no_fee_id int
	DECLARE @program_template_no_fee_name varchar(50) = 'Automation_Programs_No_Fee_Static'
	DECLARE @tag_id int
	DECLARE @tag_name varchar(50) = 'Automation_Regression'
	DECLARE @secondary_tag_id int
	DECLARE @secondary_tag_name varchar(50) = 'Automation_Bacon'
	DECLARE @program_id int
	DECLARE @static_session_name varchar(50) = 'Automation_Single_Session_Segment'
	DECLARE @static_session_full varchar(50) = 'Automation_Session_Full'
	DECLARE @static_wait_list_session varchar(50) = 'Automation_Wait_List_Session'
	DECLARE @static_multi_segment_session varchar(50) = 'Automation_Multi_Segment_Session'
	DECLARE @static_scholarship_enable_session varchar(50) = 'Automation_scholarship_enable_Session'
	DECLARE @static_restrict_duplicate_online_registrations_session_name varchar(50) = 'Automation_Restrict_Duplicate_Reg'
	DECLARE @static_schedule_payments_session_name varchar(50) = 'Automation_Schedule_Payments'
	DECLARE @static_schedule_payments_no_fee_session_name varchar(50) = 'Automation_Schedule_Payments_No_Fee'
	DECLARE @registration_group_id int
	DECLARE @registration_group_id_1 int
	DECLARE @registration_group_id_2 int

	DECLARE @program_reg_fee_gl_id int = (select Top 1 GLID from memClientJournalEntryAccountsTBL where ClientID = @client_id and BranchID = @branch_id and ShowProgram = 1)
	DECLARE @fee_gl_id int = (select Top 1 GLID from memClientJournalEntryAccountsTBL where ClientID = @client_id and BranchID = @branch_id and ShowProgram = 1)

	--Creates Program Tag as specified in variable at top of file
	IF NOT EXISTS(select * from mstProgramTagsTBL where tag = @tag_name and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramTagsTBL (ClientID, Tag, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ClientID*/ @client_id, /*Tag*/ @tag_name, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T12:52:25.953', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T12:52:25.953');
		SET @tag_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO Tag_Settings (tag_id, active, show_online)
		VALUES (/*tag_id*/ @tag_id, /*active*/ 1, /*show_online*/ 1);
	END

	IF @tag_id is null
	BEGIN
		select top 1 @tag_id = TagID from mstProgramTagsTBL where clientid = @client_id and tag = @tag_name
	END

	--Creates Secondary Program Tag as specified in variable at top of file
	IF NOT EXISTS(select * from mstProgramTagsTBL where tag = @secondary_tag_name and ClientID = @client_id)
		BEGIN
			INSERT INTO mstProgramTagsTBL (ClientID, Tag, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
			VALUES (/*ClientID*/ @client_id, /*Tag*/ @secondary_tag_name, /*CreatedBy*/ 'SQL Setup', /*CreationTimeStamp*/ '2016-01-13T12:52:25.953', /*UpdatedBy*/ 'SQL Setup', /*UpdateTimeStamp*/ '2016-01-13T12:52:25.953');
			SET @secondary_tag_id = CAST(SCOPE_IDENTITY() AS int);

			INSERT INTO Tag_Settings (tag_id, active, show_online)
			VALUES (/*tag_id*/ @secondary_tag_id, /*active*/ 1, /*show_online*/ 1);
		END

	IF @secondary_tag_id is null
		BEGIN
			select top 1 @secondary_tag_id = TagID from mstProgramTagsTBL where clientid = @client_id and tag = @secondary_tag_name
		END

	-- Program with registration fee
	IF NOT EXISTS(select * from mstProgramTemplatesTBL where templateName = @program_template_name)
	BEGIN
		INSERT INTO mstProgramTemplatesTBL (ClientID, TemplateName, RegistrationFee, RegistrationFeeGLID, AdminName, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ClientID*/ @client_id, /*TemplateName*/ @program_template_name, /*RegistrationFee*/ 10.0000, /*RegistrationFeeGLID*/ @program_reg_fee_gl_id, /*AdminName*/ 'Butch Mayhew', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T12:52:52.517', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T12:52:52.517');
		SET @program_template_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTemplateTagLinksTBL (TagID, TemplateID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*TemplateID*/ @program_template_id, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T12:52:52.797', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T12:52:52.797');

		INSERT INTO mstProgramTemplateTagLinksTBL (TagID, TemplateID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*TagID*/ @secondary_tag_id, /*TemplateID*/ @program_template_id, /*CreatedBy*/ 'SQL Setup', /*CreationTimeStamp*/ '2016-01-13T12:52:25.953', /*UpdatedBy*/ 'SQL Setup', /*UpdateTimeStamp*/ '2016-01-13T12:52:25.953');
	END

	IF @program_template_id is null
	BEGIN
		select top 1 @program_template_id = TemplateID from mstProgramTemplatesTBL where clientid = @client_id and templateName = @program_template_name
	END

	-- Program without registration fee
	IF NOT EXISTS(select * from mstProgramTemplatesTBL where templateName = @program_template_no_fee_name)
	BEGIN
		INSERT INTO mstProgramTemplatesTBL (ClientID, TemplateName, RegistrationFee, RegistrationFeeGLID, AdminName, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ClientID*/ @client_id, /*TemplateName*/ @program_template_no_fee_name, /*RegistrationFee*/ 0.0000, /*RegistrationFeeGLID*/ null, /*AdminName*/ 'Butch Mayhew', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T12:52:52.517', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T12:52:52.517');
		SET @program_template_no_fee_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTemplateTagLinksTBL (TagID, TemplateID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*TemplateID*/ @program_template_no_fee_id, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T12:52:52.797', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T12:52:52.797');

		INSERT INTO mstProgramTemplateTagLinksTBL (TagID, TemplateID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*TagID*/ @secondary_tag_id, /*TemplateID*/ @program_template_id, /*CreatedBy*/ 'SQL Setup', /*CreationTimeStamp*/ '2016-01-13T12:52:25.953', /*UpdatedBy*/ 'SQL Setup', /*UpdateTimeStamp*/ '2016-01-13T12:52:25.953');
	END

	IF @program_template_no_fee_id is null
	BEGIN
		select top 1 @program_template_no_fee_id = TemplateID from mstProgramTemplatesTBL where clientid = @client_id and templateName = @program_template_no_fee_name
	END

	--Create Static Session
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_session_name and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, BEGINSessionTime, EndSessionTime, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_id, /*ProgramName*/ @static_session_name, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 0, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*BEGINSessionTime*/ '1900-01-01T00:00:00', /*EndSessionTime*/ '1900-01-01T13:00:00', /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:55.617', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:55.617', /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 1);
		SET @program_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2014-10-20T13:14:55.903');

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @secondary_tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2016-01-13T12:52:25.953');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.027');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.133', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.133');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.113');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.197', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.197');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.123');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.207', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.207');

		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2014-08-01T00:00:00', /*EndDate*/ '2030-08-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 0, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO memSysEventLogsTBL (DateTimeStamp, EventType, AdminName, AdminID, ClientID, MemUnitID, MemID, Description)
		VALUES (/*DateTimeStamp*/ '2014-10-20T13:14:56.447', /*EventType*/ 'Program - Create Session', /*AdminName*/ 'Butch Mayhew', /*AdminID*/ 30168, /*ClientID*/ @client_id, /*MemUnitID*/ 0, /*MemID*/ 0, /*Description*/ 'Added New Program: Automation_Single Session_Segment<br />Program Tags: Automation_Regression <br />: In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; : In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; : In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; ');

		UPDATE mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = '2014-08-01T00:00:00', RegistrationEndDate = '2030-08-01T23:59:00', MinRegistrationGroupStartDate = '2014-08-01T00:00:00', MaxRegistrationGroupEndDate = '2030-08-01T00:00:00', MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = '2014-08-01T00:00:00', OnlineRegistrationEndDate = '2030-08-01T23:59:00'
		WHERE ProgramID = @program_id

		UPDATE mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 0, NumGroupWaitList = 0, MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000
		WHERE RegistrationGroupID = @registration_group_id
	END

	-- Creates session that allows scheduled payments
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_schedule_payments_session_name and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, BEGINSessionTime, EndSessionTime, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations, allow_program_scholarship, scholarship_gl_id)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_id, /*ProgramName*/ @static_schedule_payments_session_name, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 1, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*BEGINSessionTime*/ '1900-01-01T00:00:00', /*EndSessionTime*/ '1900-01-01T13:00:00', /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:55.617', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:55.617', /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 1, /*allow_program_scholarship*/ 1, /*scholarship_gl_id*/ @fee_gl_id );
		SET @program_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2014-10-20T13:14:55.903');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.027');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.133', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.133');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.113');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.197', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.197');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.123');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.207', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.207');

		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, DueDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2029-08-01T00:00:00', /*EndDate*/ '2030-08-01T00:00:00', /*DueDate*/ '2029-08-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 0, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO memSysEventLogsTBL (DateTimeStamp, EventType, AdminName, AdminID, ClientID, MemUnitID, MemID, Description)
		VALUES (/*DateTimeStamp*/ '2014-10-20T13:14:56.447', /*EventType*/ 'Program - Create Session', /*AdminName*/ 'Butch Mayhew', /*AdminID*/ 30168, /*ClientID*/ @client_id, /*MemUnitID*/ 0, /*MemID*/ 0, /*Description*/ 'Added New Program: Automation_Single Session_Segment<br />Program Tags: Automation_Regression <br />: In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; : In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; : In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; ');

		UPDATE mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = '2014-08-01T00:00:00', RegistrationEndDate = '2030-08-01T23:59:00', MinRegistrationGroupStartDate = '2014-08-01T00:00:00', MaxRegistrationGroupEndDate = '2030-08-01T00:00:00', MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = '2014-08-01T00:00:00', OnlineRegistrationEndDate = '2030-08-01T23:59:00'
		WHERE ProgramID = @program_id

		UPDATE mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 0, NumGroupWaitList = 0, MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000
		WHERE RegistrationGroupID = @registration_group_id
	END

	-- Creates session that restricts duplicate registrations online
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_restrict_duplicate_online_registrations_session_name and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, BEGINSessionTime, EndSessionTime, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_id, /*ProgramName*/ @static_restrict_duplicate_online_registrations_session_name, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 0, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*BEGINSessionTime*/ '1900-01-01T00:00:00', /*EndSessionTime*/ '1900-01-01T13:00:00', /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:55.617', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:55.617', /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 0);
		SET @program_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2014-10-20T13:14:55.903');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.027');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.133', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.133');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.113');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.197', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.197');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.123');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.207', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.207');

		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2014-08-01T00:00:00', /*EndDate*/ '2030-08-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 0, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 0.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 0.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 0.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		UPDATE mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = '2014-08-01T00:00:00', RegistrationEndDate = '2030-08-01T23:59:00', MinRegistrationGroupStartDate = '2014-08-01T00:00:00', MaxRegistrationGroupEndDate = '2030-08-01T00:00:00', MinFeeAmount = 0.0000, MaxFeeAmount = 0.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = '2014-08-01T00:00:00', OnlineRegistrationEndDate = '2030-08-01T23:59:00'
		WHERE ProgramID = @program_id

		UPDATE mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 0, NumGroupWaitList = 0, MinFeeAmount = 0.0000, MaxFeeAmount = 0.0000
		WHERE RegistrationGroupID = @registration_group_id
	END

	-- Creates session that is full
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_session_full and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, BEGINSessionTime, EndSessionTime, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_id, /*ProgramName*/ @static_session_full, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 0, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*BEGINSessionTime*/ '1900-01-01T00:00:00', /*EndSessionTime*/ '1900-01-01T13:00:00', /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:55.617', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:55.617', /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 0);
		SET @program_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2014-10-20T13:14:55.903');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @rev_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.027');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.133', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.133');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @rev_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.113');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.197', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.197');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @rev_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.123');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.207', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.207');

		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2014-08-01T00:00:00', /*EndDate*/ '2030-08-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 1, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 0.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 0.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 0.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		UPDATE mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = '2014-08-01T00:00:00', RegistrationEndDate = '2030-08-01T23:59:00', MinRegistrationGroupStartDate = '2014-08-01T00:00:00', MaxRegistrationGroupEndDate = '2030-08-01T00:00:00', MinFeeAmount = 0.0000, MaxFeeAmount = 0.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = '2014-08-01T00:00:00', OnlineRegistrationEndDate = '2030-08-01T23:59:00'
		WHERE ProgramID = @program_id

		UPDATE mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 1, NumGroupWaitList = 0, MinFeeAmount = 0.0000, MaxFeeAmount = 0.0000
		WHERE RegistrationGroupID = @registration_group_id
	END

	--Create Wait List Session
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_wait_list_session and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, BEGINSessionTime, EndSessionTime, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations, allow_program_scholarship, scholarship_gl_id)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_id, /*ProgramName*/ @static_wait_list_session, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 0, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*BEGINSessionTime*/ '1900-01-01T00:00:00', /*EndSessionTime*/ '1900-01-01T13:00:00', /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:55.617', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:55.617', /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 1, /*allow_program_scholarship*/ 1, /*scholarship_gl_id*/ @fee_gl_id );
		SET @program_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2014-10-20T13:14:55.903');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @rev_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.027');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.133', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.133');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @rev_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.113');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.197', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.197');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @rev_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.123');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.207', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.207');

		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2014-08-01T00:00:00', /*EndDate*/ '2030-08-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 1, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '2', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		UPDATE mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = '2014-08-01T00:00:00', RegistrationEndDate = '2030-08-01T23:59:00', MinRegistrationGroupStartDate = '2014-08-01T00:00:00', MaxRegistrationGroupEndDate = '2030-08-01T00:00:00', MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = '2014-08-01T00:00:00', OnlineRegistrationEndDate = '2030-08-01T23:59:00'
		WHERE ProgramID = @program_id

		UPDATE mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 1, NumGroupWaitList = 0, MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000
		WHERE RegistrationGroupID = @registration_group_id
	END

	--Create Multi-Segment Session
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_multi_segment_session and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, BEGINSessionTime, EndSessionTime, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations, allow_program_scholarship, scholarship_gl_id)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_id, /*ProgramName*/ @static_multi_segment_session, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 0, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*BEGINSessionTime*/ '1900-01-01T00:00:00', /*EndSessionTime*/ '1900-01-01T13:00:00', /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:55.617', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:55.617', /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 1, /*allow_program_scholarship*/ 1, /*scholarship_gl_id*/ @fee_gl_id );
		SET @program_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2014-10-20T13:14:55.903');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.027');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.133', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.133');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.113');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.197', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.197');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.123');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.207', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.207');

		--segment 1
		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2014-08-01T00:00:00', /*EndDate*/ '2030-08-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 0, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id_1 = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id_1, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 45.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id_1, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id_1, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 35.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		--segment 2
		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2014-09-01T00:00:00', /*EndDate*/ '2030-09-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 0, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id_2 = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id_2, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 45.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id_2, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id_2, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 35.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		UPDATE mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = '2014-08-01T00:00:00', RegistrationEndDate = '2030-08-01T23:59:00', MinRegistrationGroupStartDate = '2014-08-01T00:00:00', MaxRegistrationGroupEndDate = '2030-08-01T00:00:00', MinFeeAmount = 25.0000, MaxFeeAmount = 45.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = '2014-09-01T00:00:00', OnlineRegistrationEndDate = '2030-09-01T23:59:00'
		WHERE ProgramID = @program_id

		UPDATE mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 0, NumGroupWaitList = 0, MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000
		WHERE RegistrationGroupID = @registration_group_id
	END

	-- Creates session that allows scheduled payments
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_schedule_payments_no_fee_session_name and ClientID = @client_id)
	BEGIN
		INSERT INTO mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, BEGINSessionTime, EndSessionTime, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations, allow_program_scholarship, scholarship_gl_id)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_no_fee_id, /*ProgramName*/ @static_schedule_payments_no_fee_session_name, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 1, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*BEGINSessionTime*/ '1900-01-01T00:00:00', /*EndSessionTime*/ '1900-01-01T13:00:00', /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:55.617', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:55.617', /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 1, /*allow_program_scholarship*/ 1, /*scholarship_gl_id*/ @fee_gl_id );
		SET @program_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2014-10-20T13:14:55.903');

		INSERT INTO mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @secondary_tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ '2016-01-13T12:52:25.953');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.027');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.133', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.133');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.113');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.197', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.197');

		INSERT INTO mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.123');

		INSERT INTO mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ '2014-08-01T00:00:00', /*InHouseEndDate*/ '2030-08-01T23:59:00', /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ '2014-08-01T00:00:00', /*OnlineEndDate*/ '2030-08-01T23:59:00', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.207', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.207');

		INSERT INTO mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, DueDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ '2029-08-01T00:00:00', /*EndDate*/ '2030-08-01T00:00:00', /*DueDate*/ '2029-08-01T00:00:00', /*MinDeposit*/ 0.0000, /*MaxEnrollment*/ 0, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.223', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.223');
		SET @registration_group_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 25.0000, /*CreatedBy*/ 'Butch Mayhew', /*CreationTimeStamp*/ '2014-10-20T13:14:56.383', /*UpdatedBy*/ 'Butch Mayhew', /*UpdateTimeStamp*/ '2014-10-20T13:14:56.383');

		INSERT INTO memSysEventLogsTBL (DateTimeStamp, EventType, AdminName, AdminID, ClientID, MemUnitID, MemID, Description)
		VALUES (/*DateTimeStamp*/ '2014-10-20T13:14:56.447', /*EventType*/ 'Program - Create Session', /*AdminName*/ 'Butch Mayhew', /*AdminID*/ 30168, /*ClientID*/ @client_id, /*MemUnitID*/ 0, /*MemID*/ 0, /*Description*/ 'Added New Program: Automation_Single Session_Segment<br />Program Tags: Automation_Regression <br />: In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; : In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; : In-house Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM], Online Registration = Yes[8/1/2014 12:00:00 AM - 8/1/2030 11:59:00 PM]; ');

		UPDATE mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = '2014-08-01T00:00:00', RegistrationEndDate = '2030-08-01T23:59:00', MinRegistrationGroupStartDate = '2014-08-01T00:00:00', MaxRegistrationGroupEndDate = '2030-08-01T00:00:00', MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = '2014-08-01T00:00:00', OnlineRegistrationEndDate = '2030-08-01T23:59:00'
		WHERE ProgramID = @program_id

		UPDATE mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 0, NumGroupWaitList = 0, MinFeeAmount = 25.0000, MaxFeeAmount = 25.0000
		WHERE RegistrationGroupID = @registration_group_id
	END

	-- Creates session with scholarship enable
	IF NOT EXISTS(select * from mstProgramsTBL where ProgramName = @static_scholarship_enable_session and ClientID = @client_id)
	BEGIN
		INSERT INTO dbo.mstProgramsTBL (ClientID, BranchID, TemplateID, ProgramName, ProgramDescription, ProgramRequirements, ReturnUrl, AllowInvoice, PrePayDiscount, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, ContactName, ContactPhone, ContactEMail, InstructorName, InstructorPhone, InstructorEMail, NotificationBCCEMail, WaiverID, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp, TaxEnabled, UseFeeGroups, UseMultipleRegDate, EnableAgeRestriction, AgeRestrictionType, allow_duplicate_registrations, allow_program_scholarship, scholarship_gl_id)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*TemplateID*/ @program_template_id, /*ProgramName*/ @static_scholarship_enable_session, /*ProgramDescription*/ 'Bacon ipsum dolor sit amet kielbasa shankle veni50n andouille pork bacon 75 rubsomebacononit', /*ProgramRequirements*/ '', /*ReturnUrl*/ '', /*AllowInvoice*/ 0, /*PrePayDiscount*/ 0.0000, /*Monday*/ 1, /*Tuesday*/ 0, /*Wednesday*/ 1, /*Thursday*/ 0, /*Friday*/ 1, /*Saturday*/ 0, /*Sunday*/ 0, /*ContactName*/ 'Contact Name', /*ContactPhone*/ '5555555555', /*ContactEMail*/ 'Contact@email.com', /*InstructorName*/ 'Instructor Name', /*InstructorPhone*/ '4444444444', /*InstructorEMail*/ 'Instructor@email.com', /*NotificationBCCEMail*/ '', /*WaiverID*/ 0, /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate(), /*TaxEnabled*/ 0, /*UseFeeGroups*/ 0, /*UseMultipleRegDate*/ 0, /*EnableAgeRestriction*/ 0, /*AgeRestrictionType*/ 'AGE', /*allow_duplicate_registrations*/ 1, /*allow_program_scholarship*/ 1, /*scholarship_gl_id*/ @fee_gl_id);
		SET @program_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.mstProgramTagLinksTBL (TagID, ProgramID, UpdateTimeStamp)
		VALUES (/*TagID*/ @tag_id, /*ProgramID*/ @program_id, /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ dateadd(dd,-1,getdate()), /*InHouseEndDate*/ dateadd(yy,10,getdate()), /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ dateadd(dd,-1,getdate()), /*OnlineEndDate*/ dateadd(yy,10,getdate()), /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ dateadd(dd,-1,getdate()), /*InHouseEndDate*/ dateadd(yy,10,getdate()), /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ dateadd(dd,-1,getdate()), /*OnlineEndDate*/ dateadd(yy,10,getdate()), /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramFeeGLsTBL (ProgramID, ProgramFeeGroupID, FeeGLID, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeGLID*/ @fee_gl_id, /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/Getdate());

		INSERT INTO dbo.mstProgramRegistrationCriteriaTBL (ProgramFeeGroupID, ProgramID, AllowInHouseRegistration, InHouseStartDate, InHouseEndDate, AllowOnlineRegistration, OnlineStartDate, OnlineEndDate, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*ProgramID*/ @program_id, /*AllowInHouseRegistration*/ 1, /*InHouseStartDate*/ dateadd(dd,-1,getdate()), /*InHouseEndDate*/ dateadd(yy,10,getdate()), /*AllowOnlineRegistration*/ 1, /*OnlineStartDate*/ dateadd(dd,-1,getdate()), /*OnlineEndDate*/ dateadd(yy,10,getdate()), /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramRegistrationGroupsTBL (ProgramID, ClientID, BranchID, StartDate, EndDate, MinDeposit, MaxEnrollment, MinEnrollment, GoalEnrollment, WaitingListStatus, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*ProgramID*/ @program_id, /*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*StartDate*/ dateadd(dd,-1,getdate()), /*EndDate*/ dateadd(yy,10,getdate()), /*MinDeposit*/ 50.0000, /*MaxEnrollment*/ 0, /*MinEnrollment*/ 0, /*GoalEnrollment*/ 0, /*WaitingListStatus*/ '0', /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());
		SET @registration_group_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO dbo.mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*FeeAmount*/ 100.0000, /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*FeeAmount*/ 100.0000, /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.mstProgramRegistrationGroupFeesTBL (RegistrationGroupID, ProgramFeeGroupID, FeeAmount, CreatedBy, CreationTimeStamp, UpdatedBy, UpdateTimeStamp)
		VALUES (/*RegistrationGroupID*/ @registration_group_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*FeeAmount*/ 100.0000, /*CreatedBy*/ 'Automation User', /*CreationTimeStamp*/ Getdate(), /*UpdatedBy*/ 'Automation User', /*UpdateTimeStamp*/ Getdate());

		INSERT INTO dbo.memSysEventLogsTBL (DateTimeStamp, EventType, AdminName, AdminID, ClientID, MemUnitID, MemID, Description)
		VALUES (/*DateTimeStamp*/ Getdate(), /*EventType*/ 'Program - Create Session', /*AdminName*/ 'Automation User', /*AdminID*/ 33073, /*ClientID*/ @client_id, /*MemUnitID*/ 0, /*MemID*/ 0, /*Description*/ 'Added New Program: Automation_Single Session_Segment<br />Program Tags: Automation_Regression <br />: In-house Registration = Yes[10/21/2015 12:00:00 AM - 2/29/2030 11:59:00 PM], Online Registration = Yes[10/21/2015 12:00:00 AM - 2/29/2030 11:59:00 PM]; Facility Member: In-house Registration = Yes[10/21/2015 12:00:00 AM - 2/29/2030 11:59:00 PM], Online Registration = Yes[10/21/2015 12:00:00 AM - 2/29/2016 11:59:00 PM]; Program Member: In-house Registration = Yes[10/21/2015 12:00:00 AM - 2/29/2016 11:59:00 PM], Online Registration = Yes[10/21/2015 12:00:00 AM - 2/29/2016 11:59:00 PM]; ');

		UPDATE dbo.mstProgramsTBL
		SET DayOfWeek = 'Mon. Wed. Fri.', SessionTime = '12:00 AM - 1:00 PM', RegistrationStartDate = Getdate(), RegistrationEndDate = dateadd(yy,10,getdate()), MinRegistrationGroupStartDate = Getdate(), MaxRegistrationGroupEndDate = dateadd(yy,10,getdate()), MinFeeAmount = 100.0000, MaxFeeAmount = 100.0000, BranchSite = 'B' + convert(varchar,@branch_id) + ':S0', OnlineRegistrationStartDate = Getdate(), OnlineRegistrationEndDate = dateadd(yy,10,getdate())
		WHERE ProgramID = @program_id

		UPDATE dbo.mstProgramRegistrationGroupsTBL
		SET NumGroupRegistration = 0, NumGroupWaitList = 0, MinFeeAmount = 100.0000, MaxFeeAmount = 100.0000
		WHERE RegistrationGroupID = @registration_group_id
	END
END

------------------------*************************** CHILDCARE ****************************----------------------------------------------------------
BEGIN -- CHILDCARE
	DECLARE @cc_category_id int
	DECLARE @rate_plan_id int
	DECLARE @rate_plan_name varchar(70) = 'Automation_CC_Weekly_Rate_Plan'
	DECLARE @higher_rate_plan_id int
	DECLARE @higher_rate_plan_name varchar(70) = 'Automation_Higher_CC_Weekly_Rate_Plan'
	DECLARE @cc_program_id int
	DECLARE @cc_program_name varchar(70) = 'Automation_CC_Program'
	DECLARE @cc_program_name_no_reg_fee varchar(70) = 'Automation_CC_Program_No_Reg_Fee'
	DECLARE @cc_age_restricted_program_name varchar(70) = 'Automation_CC_Program_Age_Restricted'
	DECLARE @questionnaire_id int
	DECLARE @cc_category_name varchar(70) = 'Automation_Category'

  --Childcare Categories
	IF NOT EXISTS (SELECT * FROM dbo.ChildCare_Categories WHERE ClientID = @client_id AND Name = @cc_category_name)
		BEGIN
			INSERT INTO dbo.ChildCare_Categories (Name, ClientID)
			VALUES (/*Name*/ @cc_category_name, /*ClientID*/ @client_id);
			SET @cc_category_id = CAST(SCOPE_IDENTITY() AS INT);
		END

	IF @cc_category_id is null
		BEGIN
			SELECT @cc_category_id = ID FROM dbo.ChildCare_Categories WHERE ClientID = @client_id AND Name = @cc_category_name
		END

	--Childcare Rate Plans
	IF NOT EXISTS (SELECT * FROM dbo.ChildCare_RatePlans WHERE ClientID = @client_id AND Name = @rate_plan_name)
	BEGIN
		INSERT INTO dbo.ChildCare_RatePlans (ClientID, Name, CategoryID, Active, EffectiveStartDate, EffectiveEndDate, SalesTaxApplies, DueAtType, DaysDueBeforeOrAfterStartDate, Frequency, MondayEnabled, TuesdayEnabled, WednesdayEnabled, ThursdayEnabled, FridayEnabled, SaturdayEnabled, SundayEnabled, Type, DaysPerWeek)
		VALUES (/*ClientID*/ @client_id, /*Name*/ @rate_plan_name, /*CategoryID*/ @cc_category_id, /*Active*/ 1, /*EffectiveStartDate*/ '2015-01-01T00:00:00', /*EffectiveEndDate*/ '2050-06-01T00:00:00', /*SalesTaxApplies*/ 0, /*DueAtType*/ 1, /*DaysDueBeforeOrAfterStartDate*/ 0, /*Frequency*/ 2, /*MondayEnabled*/ 1, /*TuesdayEnabled*/ 1, /*WednesdayEnabled*/ 1, /*ThursdayEnabled*/ 1, /*FridayEnabled*/ 1, /*SaturdayEnabled*/ 0, /*SundayEnabled*/ 0, /*Type*/ 1, /*DaysPerWeek*/ 5);
		SET @rate_plan_id = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, WeeklyStartDayOfWeek, WeeklyAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*RatePlanID*/ @rate_plan_id, /*RateType*/ 'WeeklyRatePlanRate', /*WeeklyStartDayOfWeek*/ 1, /*WeeklyAmount*/ 50.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, WeeklyStartDayOfWeek, WeeklyAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*RatePlanID*/ @rate_plan_id, /*RateType*/ 'WeeklyRatePlanRate', /*WeeklyStartDayOfWeek*/ 1, /*WeeklyAmount*/ 30.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, WeeklyStartDayOfWeek, WeeklyAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*RatePlanID*/ @rate_plan_id, /*RateType*/ 'WeeklyRatePlanRate', /*WeeklyStartDayOfWeek*/ 1, /*WeeklyAmount*/ 40.0000);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_program_member);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_facility_member);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_community_participant);
	END

	IF @rate_plan_id is null
	BEGIN
		SELECT @rate_plan_id = ID FROM dbo.ChildCare_RatePlans WHERE ClientID = @client_id AND Name = @rate_plan_name
	END

	--Childcare Rate Plans
	IF NOT EXISTS (SELECT * FROM dbo.ChildCare_RatePlans WHERE ClientID = @client_id AND Name = @higher_rate_plan_name)
		BEGIN
			INSERT INTO dbo.ChildCare_RatePlans (ClientID, Name, CategoryID, Active, EffectiveStartDate, EffectiveEndDate, SalesTaxApplies, DueAtType, DaysDueBeforeOrAfterStartDate, Frequency, MondayEnabled, TuesdayEnabled, WednesdayEnabled, ThursdayEnabled, FridayEnabled, SaturdayEnabled, SundayEnabled, Type, DaysPerWeek)
			VALUES (/*ClientID*/ @client_id, /*Name*/ @higher_rate_plan_name, /*CategoryID*/ @cc_category_id, /*Active*/ 1, /*EffectiveStartDate*/ '2015-01-01T00:00:00', /*EffectiveEndDate*/ '2050-06-01T00:00:00', /*SalesTaxApplies*/ 0, /*DueAtType*/ 1, /*DaysDueBeforeOrAfterStartDate*/ 0, /*Frequency*/ 2, /*MondayEnabled*/ 1, /*TuesdayEnabled*/ 1, /*WednesdayEnabled*/ 1, /*ThursdayEnabled*/ 1, /*FridayEnabled*/ 1, /*SaturdayEnabled*/ 0, /*SundayEnabled*/ 0, /*Type*/ 1, /*DaysPerWeek*/ 5);
			SET @higher_rate_plan_id = CAST(SCOPE_IDENTITY() AS INT);

			INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, WeeklyStartDayOfWeek, WeeklyAmount)
			VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*RatePlanID*/ @higher_rate_plan_id, /*RateType*/ 'WeeklyRatePlanRate', /*WeeklyStartDayOfWeek*/ 1, /*WeeklyAmount*/ 100.0000);

			INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, WeeklyStartDayOfWeek, WeeklyAmount)
			VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*RatePlanID*/ @higher_rate_plan_id, /*RateType*/ 'WeeklyRatePlanRate', /*WeeklyStartDayOfWeek*/ 1, /*WeeklyAmount*/ 60.0000);

			INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, WeeklyStartDayOfWeek, WeeklyAmount)
			VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*RatePlanID*/ @higher_rate_plan_id, /*RateType*/ 'WeeklyRatePlanRate', /*WeeklyStartDayOfWeek*/ 1, /*WeeklyAmount*/ 80.0000);

			INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
			VALUES (/*RatePlanID*/ @higher_rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_program_member);

			INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
			VALUES (/*RatePlanID*/ @higher_rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_facility_member);

			INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
			VALUES (/*RatePlanID*/ @higher_rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_community_participant);
		END

	IF @higher_rate_plan_id is null
		BEGIN
			SELECT @higher_rate_plan_id = ID FROM dbo.ChildCare_RatePlans WHERE ClientID = @client_id AND Name = @higher_rate_plan_name
		END

	--Childcare Program Creation
	IF NOT EXISTS (SELECT * FROM dbo.ChildCare_Programs WHERE ClientID = @client_id AND Name = @cc_program_name)
		BEGIN
			INSERT INTO dbo.ChildCare_Programs (ClientID, BranchID, CategoryID, IsDraft, Name, Description, ReturnUrl, NotificationEmailAddresses, UseOverridingRegistrationDates, ChargeLateFee, AllowPartialTimeframe, RestrictByAge, AllowMale, AllowFemale, BEGINningDate, EndingDate, InHouseRegistrationEnabled, OnlineRegistrationEnabled, Type, AllowMassScheduleChange, IsTaxDeductible, IsScholarshipEnable, ScholarshipGLID)
			VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*CategoryID*/ @cc_category_id, /*IsDraft*/ 1, /*Name*/ @cc_program_name, /*Description*/ '', /*ReturnUrl*/ '', /*NotificationEmailAddresses*/ '', /*UseOverridingRegistrationDates*/ 0, /*ChargeLateFee*/ 0, /*AllowPartialTimeframe*/ 0, /*RestrictByAge*/ 0, /*AllowMale*/ 0, /*AllowFemale*/ 0, /*BEGINningDate*/ '2030-01-01T00:00:00', /*EndingDate*/ '2030-06-01T00:00:00', /*InHouseRegistrationEnabled*/ 0, /*OnlineRegistrationEnabled*/ 0, /*Type*/ 1, /*AllowMassScheduleChange*/ 0, /*IsTaxDeductible*/ 1, /*IsScholarshipEnable*/ 1, /*ScholarshipGLID*/ @fee_gl_id);
			SET @cc_program_id = CAST(SCOPE_IDENTITY() AS INT);

			UPDATE dbo.ChildCare_Programs
			SET InHouseRegistrationStart = '2015-06-01T00:00:00', InHouseRegistrationEnd = '2050-06-01T00:00:00', OnlineRegistrationStart = '2015-06-01T00:00:00', OnlineRegistrationEnd = '2050-06-01T00:00:00', RegistrationFeeAmount = 15.0000, AllowMale = 1, AllowFemale = 1, InHouseRegistrationEnabled = 1, OnlineRegistrationEnabled = 1, ShowAndRequireDaysAttending = 1, SignInTemplateID = 0
			WHERE ID = @cc_program_id

			INSERT INTO dbo.ChildCare_ProgramLocations (ClientID, ProgramID, RegistrationFeeGLID, QuestionFeeGLID, GeneralFeeGLID, AllowsWaitlist, Max, Min, BranchID, CapturePeriod, DefaultAMEnd, DefaultPMStart)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*RegistrationFeeGLID*/ @rev_gl_id, /*QuestionFeeGLID*/ @rev_gl_id, /*GeneralFeeGLID*/ @rev_gl_id, /*AllowsWaitlist*/ 0, /*Max*/ 999, /*Min*/ 0, /*BranchID*/ @branch_id, /*CapturePeriod*/ '4', /*DefaultAMEnd*/ '08:00:00', /*DefaultPMStart*/ '15:30:00');

			INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
			VALUES (/*ProgramID*/ @cc_program_id, /*RatePlanID*/ @rate_plan_id, /*DisplayOrder*/ 0);

			INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
			VALUES (/*ProgramID*/ @cc_program_id, /*RatePlanID*/ @higher_rate_plan_id, /*DisplayOrder*/ 1);

			INSERT INTO dbo.ChildCare_Questionnaires (ClientID, Title, Description)
			VALUES (/*ClientID*/ @client_id, /*Title*/ 'Questionnaire title', /*Description*/ 'Please complete this questionnaire.  This information helps us to provide the best possible care for your child.');
			SET @questionnaire_id = CAST(SCOPE_IDENTITY() AS INT);

			UPDATE dbo.ChildCare_Programs
			SET QuestionnaireID = @questionnaire_id
			WHERE ID = @cc_program_id

			UPDATE dbo.ChildCare_Programs
			SET IsDraft = 0, PublishDate = '2015-06-25T15:26:59'
			WHERE ID = @cc_program_id

			INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '2', /*StartDate*/ '2015-06-01T00:00:00', /*EndDate*/ '2050-06-01T00:00:00');

			INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '1', /*StartDate*/ '2015-06-01T00:00:00', /*EndDate*/ '2050-06-01T00:00:00');
		END


	--Childcare Program Creation Without Registration Fee
	IF NOT EXISTS (SELECT * FROM dbo.ChildCare_Programs WHERE ClientID = @client_id AND Name = @cc_program_name_no_reg_fee)
		BEGIN
			INSERT INTO dbo.ChildCare_Programs (ClientID, BranchID, CategoryID, IsDraft, Name, Description, ReturnUrl, NotificationEmailAddresses, UseOverridingRegistrationDates, ChargeLateFee, AllowPartialTimeframe, RestrictByAge, AllowMale, AllowFemale, BEGINningDate, EndingDate, InHouseRegistrationEnabled, OnlineRegistrationEnabled, Type, AllowMassScheduleChange, IsTaxDeductible, IsScholarshipEnable, ScholarshipGLID)
			VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*CategoryID*/ @cc_category_id, /*IsDraft*/ 1, /*Name*/ @cc_program_name_no_reg_fee, /*Description*/ '', /*ReturnUrl*/ '', /*NotificationEmailAddresses*/ '', /*UseOverridingRegistrationDates*/ 0, /*ChargeLateFee*/ 0, /*AllowPartialTimeframe*/ 0, /*RestrictByAge*/ 0, /*AllowMale*/ 0, /*AllowFemale*/ 0, /*BEGINningDate*/ '2030-01-01T00:00:00', /*EndingDate*/ '2030-06-01T00:00:00', /*InHouseRegistrationEnabled*/ 0, /*OnlineRegistrationEnabled*/ 0, /*Type*/ 1, /*AllowMassScheduleChange*/ 0, /*IsTaxDeductible*/ 1, /*IsScholarshipEnable*/ 1, /*ScholarshipGLID*/ @fee_gl_id );
			SET @cc_program_id = CAST(SCOPE_IDENTITY() AS INT);

			UPDATE dbo.ChildCare_Programs
			SET InHouseRegistrationStart = '2015-06-01T00:00:00', InHouseRegistrationEnd = '2050-06-01T00:00:00', OnlineRegistrationStart = '2015-06-01T00:00:00', OnlineRegistrationEnd = '2050-06-01T00:00:00', RegistrationFeeAmount = '', AllowMale = 1, AllowFemale = 1, InHouseRegistrationEnabled = 1, OnlineRegistrationEnabled = 1, ShowAndRequireDaysAttending = 1, SignInTemplateID = 0
			WHERE ID = @cc_program_id

			INSERT INTO dbo.ChildCare_ProgramLocations (ClientID, ProgramID, RegistrationFeeGLID, QuestionFeeGLID, GeneralFeeGLID, AllowsWaitlist, Max, Min, BranchID, CapturePeriod, DefaultAMEnd, DefaultPMStart)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*RegistrationFeeGLID*/ @rev_gl_id, /*QuestionFeeGLID*/ @rev_gl_id, /*GeneralFeeGLID*/ @rev_gl_id, /*AllowsWaitlist*/ 0, /*Max*/ 999, /*Min*/ 0, /*BranchID*/ @branch_id, /*CapturePeriod*/ '4', /*DefaultAMEnd*/ '08:00:00', /*DefaultPMStart*/ '15:30:00');

			INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
			VALUES (/*ProgramID*/ @cc_program_id, /*RatePlanID*/ @rate_plan_id, /*DisplayOrder*/ 0);

			INSERT INTO dbo.ChildCare_Questionnaires (ClientID, Title, Description)
			VALUES (/*ClientID*/ @client_id, /*Title*/ 'Questionnaire title', /*Description*/ 'Please complete this questionnaire.  This information helps us to provide the best possible care for your child.');
			SET @questionnaire_id = CAST(SCOPE_IDENTITY() AS INT);

			UPDATE dbo.ChildCare_Programs
			SET QuestionnaireID = @questionnaire_id
			WHERE ID = @cc_program_id

			UPDATE dbo.ChildCare_Programs
			SET IsDraft = 0, PublishDate = '2015-06-25T15:26:59'
			WHERE ID = @cc_program_id

			INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '2', /*StartDate*/ '2015-06-01T00:00:00', /*EndDate*/ '2050-06-01T00:00:00');

			INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '1', /*StartDate*/ '2015-06-01T00:00:00', /*EndDate*/ '2050-06-01T00:00:00');
		END


	--Childcare with Age Group restriction
	IF NOT EXISTS (SELECT * FROM dbo.ChildCare_Programs WHERE ClientID = @client_id AND Name = @cc_age_restricted_program_name)
		BEGIN
			INSERT INTO dbo.ChildCare_Programs (ClientID, BranchID, CategoryID, IsDraft, Name, Description, ReturnUrl, NotificationEmailAddresses, UseOverridingRegistrationDates, ChargeLateFee, AllowPartialTimeframe, RestrictByAge, AllowMale, AllowFemale, BEGINningDate, EndingDate, InHouseRegistrationEnabled, OnlineRegistrationEnabled, Type, AllowMassScheduleChange, IsTaxDeductible)
			VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*CategoryID*/ @cc_category_id, /*IsDraft*/ 1, /*Name*/ @cc_age_restricted_program_name, /*Description*/ '', /*ReturnUrl*/ '', /*NotificationEmailAddresses*/ '', /*UseOverridingRegistrationDates*/ 0, /*ChargeLateFee*/ 0, /*AllowPartialTimeframe*/ 0, /*RestrictByAge*/ 0, /*AllowMale*/ 0, /*AllowFemale*/ 0, /*BEGINningDate*/ '2030-01-01T00:00:00', /*EndingDate*/ '2030-06-01T00:00:00', /*InHouseRegistrationEnabled*/ 0, /*OnlineRegistrationEnabled*/ 0, /*Type*/ 1, /*AllowMassScheduleChange*/ 0, /*IsTaxDeductible*/ 1);
			SET @cc_program_id = CAST(SCOPE_IDENTITY() AS INT);

			UPDATE dbo.ChildCare_Programs
			SET InHouseRegistrationStart = '2015-06-01T00:00:00', InHouseRegistrationEnd = '2050-06-01T00:00:00', OnlineRegistrationStart = '2015-06-01T00:00:00', OnlineRegistrationEnd = '2050-06-01T00:00:00', RegistrationFeeAmount = 15.0000, AllowMale = 1, AllowFemale = 1, InHouseRegistrationEnabled = 1, OnlineRegistrationEnabled = 1, ShowAndRequireDaysAttending = 1, SignInTemplateID = 0, RestrictByAge = 1, StartBirthDate = '2000-01-01T00:00:00', EndBirthDate = '2030-01-01T00:00:00'
			WHERE ID = @cc_program_id

			INSERT INTO dbo.ChildCare_ProgramLocations (ClientID, ProgramID, RegistrationFeeGLID, QuestionFeeGLID, GeneralFeeGLID, AllowsWaitlist, Max, Min, BranchID, CapturePeriod, DefaultAMEnd, DefaultPMStart)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*RegistrationFeeGLID*/ @rev_gl_id, /*QuestionFeeGLID*/ @rev_gl_id, /*GeneralFeeGLID*/ @rev_gl_id, /*AllowsWaitlist*/ 0, /*Max*/ 999, /*Min*/ 0, /*BranchID*/ @branch_id, /*CapturePeriod*/ '4', /*DefaultAMEnd*/ '08:00:00', /*DefaultPMStart*/ '15:30:00');

			INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
			VALUES (/*ProgramID*/ @cc_program_id, /*RatePlanID*/ @rate_plan_id, /*DisplayOrder*/ 0);

			INSERT INTO dbo.ChildCare_Questionnaires (ClientID, Title, Description)
			VALUES (/*ClientID*/ @client_id, /*Title*/ 'Questionnaire title', /*Description*/ 'Please complete this questionnaire.  This information helps us to provide the best possible care for your child.');
			SET @questionnaire_id = CAST(SCOPE_IDENTITY() AS INT);

			UPDATE dbo.ChildCare_Programs
			SET QuestionnaireID = @questionnaire_id
			WHERE ID = @cc_program_id

			UPDATE dbo.ChildCare_Programs
			SET IsDraft = 0, PublishDate = '2015-06-25T15:26:59'
			WHERE ID = @cc_program_id

			INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '2', /*StartDate*/ '2015-06-01T00:00:00', /*EndDate*/ '2050-06-01T00:00:00');

			INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
			VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @cc_program_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '1', /*StartDate*/ '2015-06-01T00:00:00', /*EndDate*/ '2050-06-01T00:00:00');
		END
END

------------------------*************************** CAMP  ****************************----------------------------------------------------------
BEGIN -- CAMP
	DECLARE @camp_rate_plan_name varchar(75) = 'Automation_Camp_Flat_Rate_Plan'
	DECLARE @camp_rate_plan_id bigint
	DECLARE @camp_rate_plan_diff_fee_amount_per_reg_group_name VARCHAR(75) = 'Automation_camp_unique_amounts'
	DECLARE @camp_rate_plan_diff_fee_amount_per_reg_group_id BIGINT
	DECLARE @camp_rate_plan_higher_fee_amount_per_reg_group_name VARCHAR(75) = 'Automation_camp_higher_amounts'
	DECLARE @camp_rate_plan_higher_fee_amount_per_reg_group_id BIGINT
	DECLARE @camp_id int
	DECLARE @camp_name varchar(75) = 'Automation_Camp_Program'
	DECLARE @camp_multi_instance_name VARCHAR(75) = 'Automation_Camp_Multi_Instance'
  DECLARE @camp_waiting_list VARCHAR(75) = 'Automation_Camp_Wait_List'
	DECLARE @camp_questionnaire_id bigint

	-- Childcare Camp Rate Plan Rates and Registration Groups
	IF NOT EXISTS(select * from dbo.Childcare_RatePlans where ClientID = @client_id and Name = @camp_rate_plan_name)
	BEGIN
		INSERT INTO dbo.ChildCare_RatePlans (ClientID, Name, CategoryID, Active, EffectiveStartDate, EffectiveEndDate, SalesTaxApplies, DueAtType, DaysDueBeforeOrAfterStartDate, Frequency, MondayEnabled, TuesdayEnabled, WednesdayEnabled, ThursdayEnabled, FridayEnabled, SaturdayEnabled, SundayEnabled, Type, DaysPerWeek, AttendancePeriod)
		VALUES (/*ClientID*/ @client_id, /*Name*/ @camp_rate_plan_name, /*CategoryID*/ @cc_category_id, /*Active*/ 1, /*EffectiveStartDate*/ '2015-01-01T00:00:00', /*EffectiveEndDate*/ '2030-01-01T00:00:00', /*SalesTaxApplies*/ 0, /*DueAtType*/ 0, /*DaysDueBeforeOrAfterStartDate*/ 0, /*Frequency*/ 5, /*MondayEnabled*/ 1, /*TuesdayEnabled*/ 1, /*WednesdayEnabled*/ 1, /*ThursdayEnabled*/ 1, /*FridayEnabled*/ 1, /*SaturdayEnabled*/ 0, /*SundayEnabled*/ 0, /*Type*/ 2, /*DaysPerWeek*/ 0, /*AttendancePeriod*/ 3);
		SET @camp_rate_plan_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*RatePlanID*/ @camp_rate_plan_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 500.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*RatePlanID*/ @camp_rate_plan_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 500.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*RatePlanID*/ @camp_rate_plan_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 500.0000);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_community_participant);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_facility_member);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_id, /*RegistrationGroupID*/ @program_fee_group_id_program_member);
	END

	IF @camp_rate_plan_id is null
	BEGIN
		SELECT @camp_rate_plan_id = ID FROM dbo.ChildCare_RatePlans WHERE ClientID = @client_id AND Name = @camp_rate_plan_name
	END

  -- Camp Rate Plan w/ unique fee amount per registration group
	IF NOT EXISTS(SELECT * FROM dbo.Childcare_RatePlans WHERE ClientID = @client_id AND Name = @camp_rate_plan_diff_fee_amount_per_reg_group_name)
	BEGIN
		INSERT INTO dbo.ChildCare_RatePlans (ClientID, Name, CategoryID, Active, EffectiveStartDate, EffectiveEndDate, SalesTaxApplies, DueAtType, DaysDueBeforeOrAfterStartDate, Frequency, MondayEnabled, TuesdayEnabled, WednesdayEnabled, ThursdayEnabled, FridayEnabled, SaturdayEnabled, SundayEnabled, Type, DaysPerWeek, AttendancePeriod)
		VALUES (/*ClientID*/ @client_id, /*Name*/ @camp_rate_plan_diff_fee_amount_per_reg_group_name, /*CategoryID*/ @cc_category_id, /*Active*/ 1, /*EffectiveStartDate*/ '2015-09-01T00:00:00', /*EffectiveEndDate*/ '2040-09-30T00:00:00', /*SalesTaxApplies*/ 0, /*DueAtType*/ 0, /*DaysDueBeforeOrAfterStartDate*/ 0, /*Frequency*/ 5, /*MondayEnabled*/ 1, /*TuesdayEnabled*/ 1, /*WednesdayEnabled*/ 1, /*ThursdayEnabled*/ 1, /*FridayEnabled*/ 1, /*SaturdayEnabled*/ 0, /*SundayEnabled*/ 0, /*Type*/ 2, /*DaysPerWeek*/ 0, /*AttendancePeriod*/ 3);
		SET @camp_rate_plan_diff_fee_amount_per_reg_group_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 300.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 100.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 200.0000);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id, /*RegistrationGroupID*/ @program_fee_group_id_community_participant);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id, /*RegistrationGroupID*/ @program_fee_group_id_facility_member);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id, /*RegistrationGroupID*/ @program_fee_group_id_program_member);
	END

	IF @camp_rate_plan_diff_fee_amount_per_reg_group_id is null
	BEGIN
		SELECT @camp_rate_plan_diff_fee_amount_per_reg_group_id = ID FROM dbo.ChildCare_RatePlans WHERE ClientID = @client_id AND Name = @camp_rate_plan_diff_fee_amount_per_reg_group_name
	END

	-- Camp Rate Plan w/ Higher fee amount per registration group
	IF NOT EXISTS(SELECT * FROM dbo.Childcare_RatePlans WHERE ClientID = @client_id AND Name = @camp_rate_plan_higher_fee_amount_per_reg_group_name)
	BEGIN
		INSERT INTO dbo.ChildCare_RatePlans (ClientID, Name, CategoryID, Active, EffectiveStartDate, EffectiveEndDate, SalesTaxApplies, DueAtType, DaysDueBeforeOrAfterStartDate, Frequency, MondayEnabled, TuesdayEnabled, WednesdayEnabled, ThursdayEnabled, FridayEnabled, SaturdayEnabled, SundayEnabled, Type, DaysPerWeek, AttendancePeriod)
		VALUES (/*ClientID*/ @client_id, /*Name*/ @camp_rate_plan_higher_fee_amount_per_reg_group_name, /*CategoryID*/ @cc_category_id, /*Active*/ 1, /*EffectiveStartDate*/ '2015-09-01T00:00:00', /*EffectiveEndDate*/ '2040-09-30T00:00:00', /*SalesTaxApplies*/ 0, /*DueAtType*/ 0, /*DaysDueBeforeOrAfterStartDate*/ 0, /*Frequency*/ 5, /*MondayEnabled*/ 1, /*TuesdayEnabled*/ 1, /*WednesdayEnabled*/ 1, /*ThursdayEnabled*/ 1, /*FridayEnabled*/ 1, /*SaturdayEnabled*/ 0, /*SundayEnabled*/ 0, /*Type*/ 2, /*DaysPerWeek*/ 0, /*AttendancePeriod*/ 3);
		SET @camp_rate_plan_higher_fee_amount_per_reg_group_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_community_participant, /*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 600.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_facility_member, /*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 200.0000);

		INSERT INTO dbo.ChildCare_RatePlanRates (ClientID, ProgramFeeGroupID, RatePlanID, RateType, FlatAmount)
		VALUES (/*ClientID*/ @client_id, /*ProgramFeeGroupID*/ @program_fee_group_id_program_member, /*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id, /*RateType*/ 'FlatRatePlanRate', /*FlatAmount*/ 400.0000);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id, /*RegistrationGroupID*/ @program_fee_group_id_community_participant);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id, /*RegistrationGroupID*/ @program_fee_group_id_facility_member);

		INSERT INTO dbo.ChildCare_RatePlanToRegistrationGroups (RatePlanID, RegistrationGroupID)
		VALUES (/*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id, /*RegistrationGroupID*/ @program_fee_group_id_program_member);
	END

	IF @camp_rate_plan_higher_fee_amount_per_reg_group_id is null
	BEGIN
		SELECT @camp_rate_plan_higher_fee_amount_per_reg_group_id = ID FROM dbo.ChildCare_RatePlans WHERE ClientID = @client_id AND Name = @camp_rate_plan_higher_fee_amount_per_reg_group_name
	END

	-- Childcare Camp Program
	IF NOT EXISTS(select * from dbo.Childcare_Programs where ClientID = @client_id and Name = @camp_name)
	BEGIN
		INSERT INTO dbo.ChildCare_Programs (ClientID, BranchID, CategoryID, IsDraft, Name, Description, ReturnUrl, NotificationEmailAddresses, UseOverridingRegistrationDates, ChargeLateFee, AllowPartialTimeframe, RestrictByAge, AllowMale, AllowFemale, BEGINningDate, EndingDate, InHouseRegistrationEnabled, OnlineRegistrationEnabled, Type, AllowMassScheduleChange, IsTaxDeductible, IsScholarshipEnable, ScholarshipGLID)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*CategoryID*/ @cc_category_id, /*IsDraft*/ 1, /*Name*/ @camp_name, /*Description*/ '', /*ReturnUrl*/ '', /*NotificationEmailAddresses*/ '', /*UseOverridingRegistrationDates*/ 0, /*ChargeLateFee*/ 0, /*AllowPartialTimeframe*/ 0, /*RestrictByAge*/ 0, /*AllowMale*/ 0, /*AllowFemale*/ 0, /*BEGINningDate*/ '2015-01-01T00:00:00', /*EndingDate*/ '2030-01-01T00:00:00', /*InHouseRegistrationEnabled*/ 0, /*OnlineRegistrationEnabled*/ 0, /*Type*/ 2, /*AllowMassScheduleChange*/ 0, /*IsTaxDeductible*/ 1, /*IsScholarshipEnable*/ 1, /*ScholarshipGLID*/ @fee_gl_id);
		SET @camp_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		UPDATE dbo.ChildCare_Programs
		SET InHouseRegistrationStart = '2015-01-01T00:00:00', InHouseRegistrationEnd = '2030-01-01T00:00:00', OnlineRegistrationStart = '2015-01-01T00:00:00', OnlineRegistrationEnd = '2030-01-01T00:00:00', RegistrationFeeAmount = 15.0000, AllowMale = 1, AllowFemale = 1, InHouseRegistrationEnabled = 1, OnlineRegistrationEnabled = 1, SignInTemplateID = 0
		WHERE ID = @camp_id

		INSERT INTO dbo.ChildCare_ProgramLocations (ClientID, ProgramID, RegistrationFeeGLID, QuestionFeeGLID, GeneralFeeGLID, AllowsWaitlist, BranchID, CapturePeriod, DefaultAMEnd, DefaultPMStart,ScholarshipFeeGLID)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*RegistrationFeeGLID*/ @rev_gl_id, /*QuestionFeeGLID*/ @rev_gl_id, /*GeneralFeeGLID*/ @rev_gl_id, /*AllowsWaitlist*/ 0, /*BranchID*/ @branch_id, /*CapturePeriod*/ '3', /*DefaultAMEnd*/ '08:00:00', /*DefaultPMStart*/ '15:30:00', /*ScholarshipFeeGLID*/ @fee_gl_id);

		INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
		VALUES (/*ProgramID*/ @camp_id, /*RatePlanID*/ @camp_rate_plan_id, /*DisplayOrder*/ 0);

		INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Automation_Camp_Instance', /*Description*/ '', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2030-01-01T00:00:00', /*RatePlanID*/ @camp_rate_plan_id);

		INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID)
 		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Automation_Camp_Instance_2', /*Description*/ '', /*StartDate*/ '2015-01-08T00:00:00', /*EndDate*/ '2030-01-01T00:00:00', /*RatePlanID*/ @camp_rate_plan_id);

		INSERT INTO dbo.ChildCare_Questionnaires (ClientID, Title, Description)
		VALUES (/*ClientID*/ @client_id, /*Title*/ 'Questionnaire title', /*Description*/ 'Please complete this questionnaire.  This information helps us to provide the best possible care for your child.');
		SET @camp_questionnaire_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		UPDATE dbo.ChildCare_Programs
		SET QuestionnaireID = @camp_questionnaire_id
		WHERE ID = @camp_id

		UPDATE dbo.ChildCare_Programs
		SET IsDraft = 0, PublishDate = '2015-06-29T14:20:17'
		WHERE ID = @camp_id

		INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '2', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2030-01-01T00:00:00');

		INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '1', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2030-01-01T00:00:00');
	END

	-- Camp Multi Instance program
	IF NOT EXISTS(SELECT * FROM dbo.Childcare_Programs where ClientID = @client_id and Name = @camp_multi_instance_name)
	BEGIN
		INSERT INTO dbo.ChildCare_Programs (ClientID, BranchID, CategoryID, IsDraft, Name, Description, ReturnUrl, NotificationEmailAddresses, UseOverridingRegistrationDates, ChargeLateFee, AllowPartialTimeframe, RestrictByAge, AllowMale, AllowFemale, BEGINningDate, EndingDate, InHouseRegistrationEnabled, OnlineRegistrationEnabled, Type, AllowMassScheduleChange, IsTaxDeductible, IsScholarshipEnable, ScholarshipGLID, ChangeCampFeeAmount, ChangeCampFeeGLID, WeekThreshold, AllowOnlineCampMoves)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*CategoryID*/ @cc_category_id, /*IsDraft*/ 1, /*Name*/ @camp_multi_instance_name, /*Description*/ '', /*ReturnUrl*/ '', /*NotificationEmailAddresses*/ '', /*UseOverridingRegistrationDates*/ 0, /*ChargeLateFee*/ 0, /*AllowPartialTimeframe*/ 0, /*RestrictByAge*/ 0, /*AllowMale*/ 0, /*AllowFemale*/ 0, /*BEGINningDate*/ '2015-09-01T00:00:00', /*EndingDate*/ '2040-09-30T00:00:00', /*InHouseRegistrationEnabled*/ 0, /*OnlineRegistrationEnabled*/ 0, /*Type*/ 2, /*AllowMassScheduleChange*/ 0, /*IsTaxDeductible*/ 1, /*IsScholarshipEnable*/ 0, /*ScholarshipGLID*/ @fee_gl_id, /*ChangeCampFeeAmount*/ 10.00, /*ChangeCampFeeGLID*/ @fee_gl_id, /*WeekThreshold*/ 0, /*AllowOnlineCampMoves*/ 1);
		SET @camp_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		UPDATE dbo.ChildCare_Programs
		SET InHouseRegistrationStart = '2015-09-01T00:00:00', InHouseRegistrationEnd = '2040-09-30T00:00:00', OnlineRegistrationStart = '2015-09-01T00:00:00', OnlineRegistrationEnd = '2040-09-30T00:00:00', RegistrationFeeAmount = 10.0000, AllowMale = 1, AllowFemale = 1, InHouseRegistrationEnabled = 1, OnlineRegistrationEnabled = 1, SignInTemplateID = 0
		WHERE ID = @camp_id

		INSERT INTO dbo.ChildCare_ProgramLocations (ClientID, ProgramID, RegistrationFeeGLID, QuestionFeeGLID, GeneralFeeGLID, AllowsWaitlist, BranchID, CapturePeriod, DefaultAMEnd, DefaultPMStart)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*RegistrationFeeGLID*/ @rev_gl_id, /*QuestionFeeGLID*/ @rev_gl_id, /*GeneralFeeGLID*/ @rev_gl_id, /*AllowsWaitlist*/ 0, /*BranchID*/ @branch_id, /*CapturePeriod*/ '3', /*DefaultAMEnd*/ '08:00:00', /*DefaultPMStart*/ '15:30:00');

		INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
		VALUES (/*ProgramID*/ @camp_id, /*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id, /*DisplayOrder*/ 0);

		INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
		VALUES (/*ProgramID*/ @camp_id, /*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id, /*DisplayOrder*/ 1);

		INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Camp Instance #1', /*Description*/ '', /*StartDate*/ '2040-07-01T00:00:00', /*EndDate*/ '2040-07-31T00:00:00', /*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id);

		INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Camp Instance #2', /*Description*/ '', /*StartDate*/ '2040-08-01T00:00:00', /*EndDate*/ '2040-08-31T00:00:00', /*RatePlanID*/ @camp_rate_plan_diff_fee_amount_per_reg_group_id);

		INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Higher Amount camp Instance #1', /*Description*/ '', /*StartDate*/ '2040-09-01T00:00:00', /*EndDate*/ '2040-09-30T00:00:00', /*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id);

		INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Higher Amount camp Instance #2', /*Description*/ '', /*StartDate*/ '2040-09-01T00:00:00', /*EndDate*/ '2040-09-30T00:00:00', /*RatePlanID*/ @camp_rate_plan_higher_fee_amount_per_reg_group_id);

		INSERT INTO dbo.ChildCare_Questionnaires (ClientID, Title, Description)
		VALUES (/*ClientID*/ @client_id, /*Title*/ 'Questionnaire title', /*Description*/ 'Please complete this questionnaire.  This information helps us to provide the best possible care for your child.');
		SET @camp_questionnaire_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		UPDATE dbo.ChildCare_Programs
		SET QuestionnaireID = @camp_questionnaire_id
		WHERE ID = @camp_id

		UPDATE dbo.ChildCare_Programs
		SET IsDraft = 0, PublishDate = '2015-09-30T14:20:17'
		WHERE ID = @camp_id

		INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '2', /*StartDate*/ '2015-09-01T00:00:00', /*EndDate*/ '2040-09-30T00:00:00');

		INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
		VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '1', /*StartDate*/ '2015-09-01T00:00:00', /*EndDate*/ '2040-09-30T00:00:00');
	END

  -- Child Care Camp w/ waiting list instance and move process instance
  IF NOT EXISTS(select * from dbo.Childcare_Programs where ClientID = @client_id and Name = @camp_waiting_list)
  BEGIN
      INSERT INTO dbo.ChildCare_Programs (ClientID, BranchID, CategoryID, IsDraft, Name, Description, ReturnUrl, NotificationEmailAddresses, UseOverridingRegistrationDates, ChargeLateFee, AllowPartialTimeframe, RestrictByAge, AllowMale, AllowFemale, BeginningDate, EndingDate, InHouseRegistrationEnabled, OnlineRegistrationEnabled, Type, AllowMassScheduleChange, IsTaxDeductible,ChangeCampFeeAmount,ChangeCampFeeGLID,WeekThreshold,AllowOnlineCampMoves,IsScholarshipEnable, ScholarshipGLID)
      VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*CategoryID*/ @cc_category_id, /*IsDraft*/ 1, /*Name*/ @camp_waiting_list, /*Description*/ '', /*ReturnUrl*/ '', /*NotificationEmailAddresses*/ '', /*UseOverridingRegistrationDates*/ 0, /*ChargeLateFee*/ 0, /*AllowPartialTimeframe*/ 0, /*RestrictByAge*/ 0, /*AllowMale*/ 0, /*AllowFemale*/ 0, /*BeginningDate*/ '2015-01-01T00:00:00', /*EndingDate*/ '2030-01-01T00:00:00', /*InHouseRegistrationEnabled*/ 0, /*OnlineRegistrationEnabled*/ 0, /*Type*/ 2, /*AllowMassScheduleChange*/ 0, /*IsTaxDeductible*/ 1,/*ChangeCampFeeAmount*/ 10.00,/*ChangeCampFeeGLID*/ @rev_gl_id,/*WeekThreshold*/ 0,/*AllowOnlineCampMoves*/ 1,/*IsScholarshipEnable*/ 1, /*ScholarshipGLID*/ @fee_gl_id);
      SET @camp_id = CAST(SCOPE_IDENTITY() AS BIGINT);

      UPDATE dbo.ChildCare_Programs
      SET InHouseRegistrationStart = '2015-01-01T00:00:00', InHouseRegistrationEnd = '2030-01-01T00:00:00', OnlineRegistrationStart = '2015-01-01T00:00:00', OnlineRegistrationEnd = '2030-01-01T00:00:00', RegistrationFeeAmount = 15.0000, AllowMale = 1, AllowFemale = 1, InHouseRegistrationEnabled = 1, OnlineRegistrationEnabled = 1, SignInTemplateID = 0
      WHERE ID = @camp_id

      INSERT INTO dbo.ChildCare_ProgramLocations (ClientID, ProgramID, RegistrationFeeGLID, QuestionFeeGLID, GeneralFeeGLID, AllowsWaitlist,BranchID, CapturePeriod, DefaultAMEnd, DefaultPMStart, ScholarshipFeeGLID)
      VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*RegistrationFeeGLID*/ @rev_gl_id, /*QuestionFeeGLID*/ @rev_gl_id, /*GeneralFeeGLID*/ @rev_gl_id, /*AllowsWaitlist*/ 1,/*BranchID*/ @branch_id, /*CapturePeriod*/ '3', /*DefaultAMEnd*/ '08:00:00', /*DefaultPMStart*/ '15:30:00', /*ScholarshipFeeGLID*/ @fee_gl_id);

      INSERT INTO dbo.ChildCare_ProgramsToRatePlans (ProgramID, RatePlanID, DisplayOrder)
      VALUES (/*ProgramID*/ @camp_id, /*RatePlanID*/ @camp_rate_plan_id, /*DisplayOrder*/ 0);

      INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID,Min,Max,Goal,AllowsWaitlist)
      VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Waiting list instance', /*Description*/ '', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2030-01-01T00:00:00', /*RatePlanID*/ @camp_rate_plan_id,/*Min*/1,/*Max*/1,/*Goal*/1,/*AllowsWaitlist*/1);

      INSERT INTO dbo.ChildCare_ProgramInstances (ClientID, ProgramID, Name, Description, StartDate, EndDate, RatePlanID)
      VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*Name*/ 'Move Camp process instances', /*Description*/ '', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2030-01-01T00:00:00', /*RatePlanID*/ @camp_rate_plan_id);

      INSERT INTO dbo.ChildCare_Questionnaires (ClientID, Title, Description)
      VALUES (/*ClientID*/ @client_id, /*Title*/ 'Questionnaire title', /*Description*/ 'Please complete this questionnaire.  This information helps us to provide the best possible care for your child.');
      SET @camp_questionnaire_id = CAST(SCOPE_IDENTITY() AS BIGINT);

      UPDATE dbo.ChildCare_Programs
      SET QuestionnaireID = @camp_questionnaire_id
      WHERE ID = @camp_id

      UPDATE dbo.ChildCare_Programs
      SET IsDraft = 0, PublishDate = '2015-06-29T14:20:17'
      WHERE ID = @camp_id

      INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
      VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '2', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2030-01-01T00:00:00');

      INSERT INTO dbo.ChildCare_ProgramRegistrationDatesViewModel (ClientID, ProgramID, CategoryID, BranchID, RegistrationType, StartDate, EndDate)
      VALUES (/*ClientID*/ @client_id, /*ProgramID*/ @camp_id, /*CategoryID*/ @cc_category_id, /*BranchID*/ @branch_id, /*RegistrationType*/ '1', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2030-01-01T00:00:00');
  END
END

------------------------*************************** FUNDRAISING  ****************************----------------------------------------------------------
BEGIN -- FUNDRAISING

	DECLARE @template_name varchar(max) = 'Automation_Template'
	DECLARE @template_id INT
	DECLARE @season_id INT
	DECLARE @season_name varchar(max) = 'Automation_Season'
	DECLARE @campaign_id INT
	DECLARE @designation_id bigint

	--Add a Fundraising Template to use for creating a Fundraising Campaign
	IF NOT EXISTS (SELECT * FROM memFRCampaignTemplatesTBL WHERE ClientID = @client_id and TemplateName = @template_name)
	BEGIN
		INSERT INTO memFRCampaignTemplatesTBL (ClientID, TemplateName, Description, CampaignTypeID, TemplateCode, Slogan)
		VALUES (/*ClientID*/ @client_id, /*TemplateName*/ @template_name, /*Description*/ '', /*CampaignTypeID*/ 1, /*TemplateCode*/ 'Auto', /*Slogan*/ '');
		SET @template_id = CAST(SCOPE_IDENTITY() AS INT);
	END

	--Add a Fundraising Season to use for creating a Fundraising Campaign
	IF NOT EXISTS (SELECT * FROM memFRCampaignSeasonsTBL  WHERE ClientID = @client_id and SeasonName = @season_name)
	BEGIN
		INSERT INTO memFRCampaignSeasonsTBL (ClientID, SeasonName, SeasonCode, StartDate, EndDate)
		VALUES (/*ClientID*/ @client_id, /*SeasonName*/ @season_name, /*SeasonCode*/ 'Auto', /*StartDate*/ '2015-01-01T00:00:00', /*EndDate*/ '2050-12-31T00:00:00');
		SET @season_id = CAST(SCOPE_IDENTITY() AS INT);
	END

	--Add a Fundraising Campaign to use for creating Pledges
	IF @template_id is null
	BEGIN
		select @template_id = TemplateID from memFRCampaignTemplatesTBL where TemplateName = @template_name and ClientID = @client_id
	END

	IF @season_id is null
	BEGIN
		select @season_id = SeasonID from memFRCampaignSeasonsTBL where SeasonName = @season_name and ClientID = @client_id
	END

	IF NOT EXISTS (SELECT * FROM memFRCampaignsTBL WHERE ClientID = @client_id AND BranchID = @branch_id AND CampaignName ='Automation_Campaign')
	BEGIN
		INSERT INTO memFRCampaignsTBL (ClientID, TemplateID, SeasonID, BranchID, CampaignCode, CampaignName, GoalAmount, GLID, AllowOnlineGiving, GenerateOnlineThankYouEachPayment, GenerateOnlineThankYouNewPledges, GenerateOnlineThankYouPledgeCompletion, OnlineCampaignName, ConfirmationEmails, cash_gl_account)
		VALUES (/*ClientID*/ @client_id, /*TemplateID*/ @template_id, /*SeasonID*/ @season_id, /*BranchID*/ @branch_id, /*CampaignCode*/ 'Auto', /*CampaignName*/ 'Automation_Campaign', /*GoalAmount*/ 250000.0000, /*GLID*/ @rev_gl_id, /*AllowOnlineGiving*/ 1, /*GenerateOnlineThankYouEachPayment*/ 0, /*GenerateOnlineThankYouNewPledges*/ 0, /*GenerateOnlineThankYouPledgeCompletion*/ 1, /*OnlineCampaignName*/ 'Automation_Campaign', /*ConfirmationEmails*/ 'test@daxko.com', /*cash_gl_account*/ @cash_asset_account_id);
		SET @campaign_id = CAST(SCOPE_IDENTITY() AS INT);

		UPDATE memClientJournalEntryAccountsTBL
		SET PRGLID = 0, IsAssetAccount = 0
		WHERE GLID = @rev_gl_id
	END

	IF NOT EXISTS (SELECT * FROM memFundraisingDesignationsTBL WHERE ClientID = @client_id AND DesignationName = 'Automation Designation')
	BEGIN
		INSERT INTO dbo.memFundraisingDesignationsTBL (DesignationName, ClientID, DesignationCode)
		VALUES (/*DesignationName*/ 'Automation Designation', /*ClientID*/ @client_id, /*DesignationCode*/ 'AUTO');
		SET @designation_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.memFundraisingDesignationGLLinksTBL (DesignationID, GLID, BranchID)
		VALUES (/*DesignationID*/ @designation_id, /*GLID*/ @rev_pledge_gl_id, /*BranchID*/ @branch_id);
	END
END

------------------------*************************** ORGANIZATIONS  ****************************----------------------------------------------------------
BEGIN -- ORGANIZATIONS
	DECLARE @mem_id INT
	DECLARE @mem_unit_id INT
	DECLARE @name_id INT
	DECLARE @phone_id_for_org INT
	DECLARE @address_id_for_org INT
	DECLARE @organization_name VARCHAR(250) = 'Automation_Organization'
	DECLARE @org_member_type_id INT = (select  top 1 membertypeid from [memClientMemberTypesTBL] where clientid = @client_id and MemberType = 'Adult')

		--Adding a new Organization
	IF NOT EXISTS(select * from memMembershipUnitsTBL where MemberUnitName = @organization_name and ClientID = @client_id)
	BEGIN

		INSERT INTO dbo.memSysAddressesTBL (tblName, ColumnName, ID, AddressName, Address1, Address2, City, Zip, Country, state)
		VALUES (/*tblName*/ '', /*ColumnName*/ '', /*ID*/ 0, /*AddressName*/ '', /*Address1*/ '555 Neverland ave', /*Address2*/ '', /*City*/ 'Birmingham', /*Zip*/ '35124', /*Country*/ 'US', /*state*/ 'AL');
		SET @address_id_for_org = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO dbo.memMembershipUnitsTBL (MemberUnitID, MemberUnitName, MemberStatus, ClientID, HomeBranchID, Address, BillCycle, ProcessStatus, EFTProcessDate, RecordCreatedDate, UnitJoinDate, ProspectList, RecurringFeesStartDay, AllowThirdPartyBilling, PromptToRenew, OrganizationWebsite)
		VALUES (/*MemberUnitID*/ '000000', /*MemberUnitName*/ @organization_name, /*MemberStatus*/ '5', /*ClientID*/ @client_id, /*HomeBranchID*/ @branch_id, /*Address*/ @address_id_for_org, /*BillCycle*/ '0', /*ProcessStatus*/ '0', /*EFTProcessDate*/ '1', /*RecordCreatedDate*/ '2015-08-12T00:00:00', /*UnitJoinDate*/ '2015-08-12T00:00:00', /*ProspectList*/ 0, /*RecurringFeesStartDay*/ '0', /*AllowThirdPartyBilling*/ 1, /*PromptToRenew*/ 0, /*OrganizationWebsite*/ '');
		SET @mem_unit_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.memMembersTBL (MemUnitID, MemberID, Barcode, MemberTypeID, EMail, Business_Name, Job_Title, Gender, Marital_Status, Race, YMCA_Employee, Volunteer, Program_Volunteer, Donors, Campaigner, Mail_List, Newsletter, Active, Board_Member, Towel_Service, Medical_Release, Limited_Use, Age_Group, HomeOwner, Program_Scholarship, Allow_Email, MemberName, SearchableNumber, SearchableAreaCode, Womens_Health_Club3, Mens_Health_Club3, Womens_Health_Club, Mens_Health_Club, Heritage_Club, Nursery, Photo_Release, Childcare_Parent, Deceased, EmployerMatchesGifts, MemClientID, IsPossibleDuplicate, EnableReciprocity, date_created, mark_as_deceased)
		VALUES (/*MemUnitID*/ @mem_unit_id, /*MemberID*/ '0000000-0', /*Barcode*/ '', /*MemberTypeID*/ @org_member_type_id, /*EMail*/ '', /*Business_Name*/ '', /*Job_Title*/ '', /*Gender*/ 'U', /*Marital_Status*/ 'U', /*Race*/ 'U', /*YMCA_Employee*/ 0, /*Volunteer*/ 0, /*Program_Volunteer*/ 0, /*Donors*/ 0, /*Campaigner*/ 0, /*Mail_List*/ 0, /*Newsletter*/ 0, /*Active*/ 0, /*Board_Member*/ 0, /*Towel_Service*/ 0, /*Medical_Release*/ 0, /*Limited_Use*/ 0, /*Age_Group*/ '', /*HomeOwner*/ 0, /*Program_Scholarship*/ '0', /*Allow_Email*/ 0, /*MemberName*/ 'Rufio, Rufio', /*SearchableNumber*/ '', /*SearchableAreaCode*/ '', /*Womens_Health_Club3*/ 0, /*Mens_Health_Club3*/ 0, /*Womens_Health_Club*/ 0, /*Mens_Health_Club*/ 0, /*Heritage_Club*/ 0, /*Nursery*/ 0, /*Photo_Release*/ 0, /*Childcare_Parent*/ 0, /*Deceased*/ 0, /*EmployerMatchesGifts*/ 0, /*MemClientID*/ 9991, /*IsPossibleDuplicate*/ 0, /*EnableReciprocity*/ 1, /*date_created*/ '2015-08-12T09:51:20.823', /*mark_as_deceased*/ 0);
		SET @mem_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.memSysNamesTBL (TblName, ColumnName, ID, Prefix, First_Name, Middle_Name, Last_Name, Suffix)
		VALUES (/*TblName*/ 'memMembersTBL', /*ColumnName*/ 'NameID', /*ID*/ @mem_id, /*Prefix*/ '', /*First_Name*/ 'Rufio', /*Middle_Name*/ 'Rufio', /*Last_Name*/ 'Rufio', /*Suffix*/ '');
		SET @name_id = CAST(SCOPE_IDENTITY() AS BIGINT);

		INSERT INTO dbo.memSysPhonesTBL (TblName, ColumnName, PhoneName, ID, AreaCode, Phone, Ext)
		VALUES (/*TblName*/ 'memMembersTBL', /*ColumnName*/ 'Business_Phone', /*PhoneName*/ 'Business Phone', /*ID*/ @mem_id, /*AreaCode*/ '', /*Phone*/ '', /*Ext*/ '');
		SET @phone_id_for_org = CAST(SCOPE_IDENTITY() AS BIGINT);

		UPDATE dbo.memSysAddressesTBL
		SET tblName = 'memMembershipUnitsTBL', ColumnName = 'Address', ID = @mem_unit_id
		WHERE AddressID = @address_id_for_org

		UPDATE dbo.memMembershipUnitsTBL
		SET PrimaryMemID = @mem_id
		WHERE MemUnitID = @mem_unit_id

		UPDATE dbo.memMembersTBL
		SET NameID = @name_id, Business_Phone = @phone_id_for_org
		WHERE MemID = @mem_id

	END
END

------------------------*************************** MEMBERSHIPS AND DISCOUNT GROUPS  ****************************----------------------------------------------------------
BEGIN --MEMBERSHIPS AND DISCOUNT GROUPS
	DECLARE @membership_type_id int
	DECLARE @membership_type_name VARCHAR(250) = 'Automation_50_Monthly'
	DECLARE @discount_group_id int
	DECLARE @discount_group_name VARCHAR(250) = 'Discount_Group_Automation_10%'
	DECLARE @question_id INT
	DECLARE @question_name VARCHAR(250) = 'Discount Group Rate Question'
	DECLARE @answer_id_10 INT

	DECLARE @prog_fee_group_id int = (select top 1 ProgramFeeGroupID from memClientProgramFeeGroupsTBL where clientid = @client_id and ProgramFeeGroupName = 'Facility Member')
	DECLARE @mem_type_category_id int = (select top 1 MembershipTypeCategoryID from memClientMembershipTypeCategoriesTBL where clientid = @client_id and Name = 'Facility Member')

	--Add New Membership Type 50.00 Monthly with 75.00 Join fee
	IF NOT EXISTS (select * from memClientMembershipTypesTBL where Membershiptype = @membership_type_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent, is_system_fee)
		VALUES (/*ClientID*/ @client_id, /*PricingType*/ 'Join Fee', /*Price*/ 75.0000, /*OrgGL*/ 1, /*GLID*/ @rev_gl_id, /*FeeType*/ '0', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0, /*is_system_fee*/1);
		SET @join_fee_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memClientPricingTypesTBL (ClientID, PricingType, Price, OrgGL, GLID, FeeType, MaxQty, Discount, Display, SalesTaxApplies, IsFastFee, affects_tax, discount_percent, is_system_fee)
		VALUES (/*ClientID*/ @client_id, /*PricingType*/ 'Membership Due', /*Price*/ 50.0000, /*OrgGL*/ 1, /*GLID*/ @rev_gl_id, /*FeeType*/ '1', /*MaxQty*/ '1', /*Discount*/ 0, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*affects_tax*/ 0, /*discount_percent*/ 0, /*is_system_fee*/1);
		SET @member_fee_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memClientMembershipTypesTBL (ClientID, BranchID, MembershipType, Term, JoinFeeID, JoinFeeSpreadMonth, MemberFeeID, ProgramFeeGroupID, Enabled, AllowDiscount, ShortDesc, MemberLimit, Online, AutoRenew, DefaultActive, MembershipTypeCategoryID, enable_reciprocity, created, created_by, last_modified, last_modified_by, apply_changes_to_existing_group_members)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*MembershipType*/ @membership_type_name, /*Term*/ '0', /*JoinFeeID*/ @join_fee_id, /*JoinFeeSpreadMonth*/ '1', /*MemberFeeID*/ @member_fee_id, /*ProgramFeeGroupID*/ @prog_fee_group_id, /*Enabled*/ 1, /*AllowDiscount*/ 1, /*ShortDesc*/ 'Auto_50', /*MemberLimit*/ '-1', /*Online*/ 1, /*AutoRenew*/ 1, /*DefaultActive*/ 1, /*MembershipTypeCategoryID*/ @mem_type_category_id, /*enable_reciprocity*/ 0, /*created*/ '2014-10-13T14:35:43', /*created_by*/ 'bmayhew', /*last_modified*/ '2014-10-13T14:35:43', /*last_modified_by*/ 'bmayhew', /*apply_changes_to_existing_group_members*/ 1);
		SET @membership_type_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO memMembershipBranchAccessTBL (BranchId, MembershipTypeId)
		VALUES (/*BranchId*/ @branch_id, /*MembershipTypeId*/ @membership_type_id);

		INSERT INTO memSysEventLogsTBL (DateTimeStamp, EventType, AdminName, AdminID, ClientID, Description)
		VALUES (/*DateTimeStamp*/ '2014-10-13T14:35:44.767', /*EventType*/ 'Add Membership Type', /*AdminName*/ 'Butch Mayhew', /*AdminID*/ 30168, /*ClientID*/ @client_id, /*Description*/ 'Automation_50_Monthly. Branch: Automation_Branch. Join Fee: $75.00. Rate: $50.00. Term: 0. Category: Facility Member. Allow Online: yes. Auto Renew: yes. Enable Reciprocity: no. Allow Discount: yes. Join Fee Spread Months: 1. Join Fee GL: Merchandise Sales, 99-9999-00000-0000-1. Member Fee GL: Merchandise Sales, 99-9999-00000-0000-1.');
	END

	IF @membership_type_id is null
	BEGIN
		SELECT @membership_type_id = MembershipTypeID FROM dbo.memClientMembershipTypesTBL WHERE MembershipType = @membership_type_name AND ClientID = @client_id AND BranchID = @branch_id
	END

	--Add New Discount Group for 10%
	IF NOT EXISTS (select * from memClientDiscountGroupsTBL where DiscountGroup = @discount_group_name and BranchID = @branch_id and ClientID = @client_id)
	BEGIN
		INSERT INTO memClientDiscountGroupsTBL (ClientID, BranchID, DiscountGroup, Contact, BillAddress, BillCity, BillState, BillZip, ShowPercent, DiscountFor, Display, PercentDiscount, PercentSubsidy, PercentJoinFee, created, created_by, last_modified, last_modified_by, round_up_to_whole_dollar, apply_changes_to_existing_group_members)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*DiscountGroup*/ @discount_group_name, /*Contact*/ 'Coach Tucker', /*BillAddress*/ '1720 2nd Ave South', /*BillCity*/ 'Birmingham', /*BillState*/ 'AL', /*BillZip*/ '35294', /*ShowPercent*/ 0, /*DiscountFor*/ 'Discount', /*Display*/ 1, /*PercentDiscount*/ 10, /*PercentSubsidy*/ 0, /*PercentJoinFee*/ 10, /*created*/ '2014-12-22T14:58:48', /*created_by*/ 'bmayhew', /*last_modified*/ '2014-12-22T14:58:48', /*last_modified_by*/ 'bmayhew', /*round_up_to_whole_dollar*/ 0, /*apply_changes_to_existing_group_members*/ 1);
		SET @discount_group_id = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO memClientDiscountGroupMembershipTypeLinkTBL (DiscountGroupID, MembershipTypeID, JoinFee, Discount, Subsidy, MemberPay)
		VALUES (/*DiscountGroupID*/ @discount_group_id, /*MembershipTypeID*/ @membership_type_id, /*JoinFee*/ 67.5000, /*Discount*/ 5.0000, /*Subsidy*/ 0.0000, /*MemberPay*/ 45.0000);

		INSERT INTO Operations_DiscountGroupExpirationSettings (discount_group_id, expiration_months, expiration_action, client_id)
		VALUES (/*discount_group_id*/ @discount_group_id, /*expiration_months*/ -1, /*expiration_action*/ 'no_action', /*client_id*/ @client_id);

		INSERT INTO Operations_DiscountGroupApprovalSettings (discount_group_id, days_for_approval, unapproved_action, start_expiration_from, client_id)
		VALUES (/*discount_group_id*/ @discount_group_id, /*days_for_approval*/ -1, /*unapproved_action*/ 'no_action', /*start_expiration_from*/ 'sign_up_date', /*client_id*/ @client_id);
	END

	DECLARE @rate_dg_id int = (select DiscountGroupID from memClientDiscountGroupsTBL where DiscountGroup = @discount_group_name and BranchID = @branch_id and ClientID = @client_id)

	--Add new Rate Questions Tied to Discount Group above
	IF NOT EXISTS (select * from operations_rate_question where question = @question_name and client_id = @client_id)
	BEGIN
		INSERT INTO dbo.operations_rate_question (client_id, question, created, created_by, modified, modified_by, description, display_order)
		VALUES (/*client_id*/ @client_id, /*question*/ @question_name, /*created*/ '2015-06-16T09:37:00', /*created_by*/ 'Butch Mayhew', /*modified*/ '2015-06-16T09:37:00', /*modified_by*/ 'Butch Mayhew', /*description*/ 'Be sure you have required documents to present upon arriving at facility', /*display_order*/ 1);
		SET @question_id = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO dbo.operations_rate_question_possible_answer (client_id, question_id, value, display_order, created, created_by, modified, modified_by)
		VALUES (/*client_id*/ @client_id, /*question_id*/ @question_id, /*value*/ '10', /*display_order*/ 1, /*created*/ '2015-06-16T09:37:00', /*created_by*/ 'Butch Mayhew', /*modified*/ '2015-06-16T09:37:00', /*modified_by*/ 'Butch Mayhew');
		SET @answer_id_10 = CAST(SCOPE_IDENTITY() AS INT);

		INSERT INTO dbo.operations_rate_question_possible_answer (client_id, question_id, value, display_order, created, created_by, modified, modified_by)
		VALUES (/*client_id*/ @client_id, /*question_id*/ @question_id, /*value*/ 'none', /*display_order*/ 2, /*created*/ '2015-06-16T09:37:00', /*created_by*/ 'Butch Mayhew', /*modified*/ '2015-06-16T09:37:00', /*modified_by*/ 'Butch Mayhew');

		INSERT INTO dbo.operations_rate_question_discount_group_link (answer_id, discount_group_id, branch_id, client_id, created, created_by)
		VALUES (/*answer_id*/ @answer_id_10, /*discount_group_id*/ @rate_dg_id, /*branch_id*/ @branch_id, /*client_id*/ @client_id, /*created*/ '2015-06-16T09:37:00', /*created_by*/ 'bmayhew');
	END
END

------------------------***************************  PROMOTIONS  ********************************----------------------------------------------------------
BEGIN --PROMOTIONS

	DECLARE @promotion_id INT
	DECLARE @promotion_name VARCHAR(250) = 'Automation 10% off Promotion'
	DECLARE @promotion_adustment_pricing_type_id INT
	DECLARE @promotion_adjustment_name varchar(max) = 'Promotion Adjustment'
	DECLARE @promotion_adjustment_percentage_based_name varchar(max) = 'Promotion Adjustment Percentage Based'
	DECLARE @promo_code_feature_guid varchar(36) = '4D0D968E-6832-43BC-90B3-48AE61954D84'

	/* PROMOTIONS */
	--Add promotion permission

  --Turn on the promotion feature
	IF NOT EXISTS (SELECT * FROM dbo.Operations_ClientFeatureMap WHERE client_id = @client_id AND feature_guid = @promo_code_feature_guid)
	BEGIN
		INSERT INTO dbo.Operations_ClientFeatureMap (feature_guid, client_id) VALUES (@promo_code_feature_guid, @client_id)
	END

	--Add a basic fixed amount adjustment to use for the promotion
	IF NOT EXISTS (SELECT * FROM dbo.memClientPRicingTYpesTBL where ClientID = @client_id and BranchID = @branch_id and PricingType = @promotion_adjustment_name)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, discount_percent, affects_tax)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @promotion_adjustment_name, /*Price*/ 1.0000, /*OrgGL*/ 1, /*FeeType*/ '0', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 1, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*discount_percent*/ 0, /*affects_tax*/ 0);
	END

	--Add a basic percentage-based adjustment to use for the promotion
	IF NOT EXISTS (SELECT * FROM dbo.memClientPricingTypesTBL where ClientID = @client_id and BranchID = @branch_id and PricingType = @promotion_adjustment_percentage_based_name)
	BEGIN
		INSERT INTO memClientPricingTypesTBL (ClientID, BranchID, PricingType, Price, OrgGL, FeeType, MaxQty, Description, Discount, Display, SalesTaxApplies, IsFastFee, discount_percent, affects_tax)
		VALUES (/*ClientID*/ @client_id, /*BranchID*/ @branch_id, /*PricingType*/ @promotion_adjustment_percentage_based_name, /*Price*/ 0.0000, /*OrgGL*/ 1, /*FeeType*/ '3', /*MaxQty*/ '0', /*Description*/ '', /*Discount*/ 1, /*Display*/ 1, /*SalesTaxApplies*/ 0, /*IsFastFee*/ 0, /*discount_percent*/ 10, /*affects_tax*/ 0);
		SET @promotion_adustment_pricing_type_id = CAST(SCOPE_IDENTITY() AS INT);
	END

	IF @promotion_adustment_pricing_type_id is null
	BEGIN
		SET @promotion_adustment_pricing_type_id = (select PricingTypeID from memClientPricingTypesTBL where PricingType = @promotion_adjustment_percentage_based_name and ClientId = @client_id and BranchID = @branch_id)
	END

	--Create the promo
	IF NOT EXISTS(select * from dbo.Promotions where name = @promotion_name and client_id = @client_id)
	BEGIN
		INSERT INTO dbo.Promotions (name, client_id, start_date, end_date, created_by, created_date, is_coupon)
		VALUES (/*name*/ @promotion_name, /*client_id*/ @client_id, /*start_date*/ '2015-10-21T00:00:00', /*end_date*/ '2030-10-21T23:59:59', /*created_by*/ 'Butch Mayhew', /*created_date*/ '2015-10-21T14:34:16', /*is_coupon*/ 0);
		SET @promotion_id = CAST(SCOPE_IDENTITY() AS int);

		INSERT INTO dbo.PromotionCodes (promotion_id, promo_code, client_id)
		VALUES (/*promotion_id*/ @promotion_id, /*promo_code*/ '10', /*client_id*/ @client_id);

		INSERT INTO dbo.Promotion_Branch_Adjustments (promotion_id, branch_id, pricing_type_id)
		VALUES (/*promotion_id*/ @promotion_id, /*branch_id*/ @branch_id, /*pricing_type_id*/ @promotion_adustment_pricing_type_id);

		INSERT INTO dbo.Promotion_Fee_Types_Link (promotion_id, promotion_fee_type_id)
		VALUES (/*promotion_id*/ @promotion_id, /*promotion_fee_type_id*/ '2');

		INSERT INTO dbo.Promotion_Fee_Types_Link (promotion_id, promotion_fee_type_id)
		VALUES (/*promotion_id*/ @promotion_id, /*promotion_fee_type_id*/ '3');

		INSERT INTO dbo.Promotion_Fee_Types_Link (promotion_id, promotion_fee_type_id)
		VALUES (/*promotion_id*/ @promotion_id, /*promotion_fee_type_id*/ '4');

		INSERT INTO dbo.Promotion_Fee_Types_Link (promotion_id, promotion_fee_type_id)
		VALUES (/*promotion_id*/ @promotion_id, /*promotion_fee_type_id*/ '5');

		INSERT INTO dbo.Promotion_Fee_Types_Link (promotion_id, promotion_fee_type_id)
		VALUES (/*promotion_id*/ @promotion_id, /*promotion_fee_type_id*/ '6');

		INSERT INTO dbo.Promotion_Fee_Types_Link (promotion_id, promotion_fee_type_id)
		VALUES (/*promotion_id*/ @promotion_id, /*promotion_fee_type_id*/ '7');
	END
END

