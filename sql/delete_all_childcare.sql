
Declare @camp_id int, @camp_name varchar(100), @camp_questionnaire_id int, @cc_count int


Declare @cc_names table(ID varchar(max))
insert into @cc_names values ('Automation_CC_Program')
insert into @cc_names values ('Automation_CC_Program_No_Reg_Fee')
insert into @cc_names values ('Automation_CC_Program_Age_Restricted')
--camps
insert into @cc_names values ('Automation_Camp_Program')
insert into @cc_names values ('Automation_Camp_Multi_Instance')
insert into @cc_names values ('Automation_Camp_Wait_List')


Set @camp_name = (Select Top 1 ID from @cc_names)
Select @cc_count = count(*) from @cc_names

While(@cc_count > 0 )
BEGIN 
	SELECT CONCAT('Deleting ==> ', @camp_name)
	set @camp_id = (Select ID from ChildCare_Programs where name = @camp_name)
	set @camp_questionnaire_id = (Select QuestionnaireID from ChildCare_Programs where ID = @camp_id)

	--- Delete Registrations
	Declare @registration_ids dbo.IntTableType,  @registration_details_ids dbo.IntTableType, @debits dbo.IntTableType
	--resetting everything
	Delete from @registration_ids
	Delete from @registration_details_ids
	Delete from @debits

	insert into @registration_ids Select ID from ChildCare_Registrations where programid = @camp_id
	insert into @registration_details_ids Select ID from ChildCare_RegistrationDetails where RegistrationID in (Select * from @registration_ids)
	insert into @debits select DebitID from memMembershipUnitDebitsTBL where ChildCareRegistrationID in (Select * from @registration_ids)

	Delete from memMembershipUnitCredits_Promotions where cc_program_id = @camp_id
	Delete from Revenue where DebitID in (Select * from @debits)
	Delete from Adjustments where DebitID in (Select * from @debits)
	Delete from Payments where DebitID in (Select * from @debits)
	Delete from Cancellations where DebitID in (Select * from @debits)
	Delete from memPaymentScheduleTBL where DebitID in (Select * from @debits)
	Delete from memMembershipUnitDebitsTBL where DebitID in (Select * from @debits)

	Delete from ChildCare_RegistrationInstances_Promotion where registration_id in (Select * from @registration_ids)
	Delete from ChildCare_Registrations where id in (Select * from @registration_ids)
	Delete from ChildCare_RegistrationInstances where RegistrationDetailID in (Select * from @registration_details_ids)
	Delete from ChildCare_RegistrationEnrolledDays where RegistrationID in (Select * from @registration_ids)
	Delete from ChildCare_RegistrationDetails where RegistrationID in (Select * from @registration_ids)
  Delete from ChildCare_RegistrationEnrolledDays where RegistrationID in (Select * from @registration_ids)

	---Delete Program
	Delete from ChildCare_Registrations where programid = @camp_id
	Delete from ChildCare_ProgramInstances where programid = @camp_id
	Delete from ChildCare_ProgramLocations where programid = @camp_id
	Delete from ChildCare_ProgramsToRatePlans where programid = @camp_id
	Delete from ChildCare_ProgramsToWaivers where programid = @camp_id
	Delete from ChildCare_ProgramRegistrationDatesViewModel where programid = @camp_id
	Delete from ChildCare_Programs where id = @camp_id
	Delete from ChildCare_Questionnaires where id = @camp_questionnaire_id

	Delete from @cc_names where ID = @camp_name
	Select @cc_count = count(*) from @cc_names
	IF(@cc_count > 0) 
	BEGIN
		Set @camp_name = (Select Top 1 ID from @cc_names)
	END
END
