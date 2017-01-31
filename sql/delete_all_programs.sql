
Declare @program_name varchar(100), @program_count int


Declare @program_names table(ID varchar(max))
insert into @program_names values ('Automation_Single_Session_Segment')
insert into @program_names values ('Automation_Session_Full')
insert into @program_names values ('Automation_Wait_List_Session')
insert into @program_names values ('Automation_Multi_Segment_Session')
insert into @program_names values ('Automation_scholarship_enable_Session')
insert into @program_names values ('Automation_Restrict_Duplicate_Reg')
insert into @program_names values ('Automation_Schedule_Payments')
insert into @program_names values ('Automation_Schedule_Payments_No_Fee')


Set @program_name = (Select Top 1 ID from @program_names)
Select @program_count = count(*) from @program_names

While(@program_count > 0 )
BEGIN 
	SELECT CONCAT('Deleting ==> ', @program_name)
	DECLARE @program_id INT = (SELECT TOP 1 ProgramID FROM mstProgramsTBL WHERE ProgramName = @program_name)

	SELECT GUID
	INTO #Yaks
	FROM dbo.mstProgramRegistrationTBL
	WHERE ProgramID = @program_id

	SELECT * FROM #Yaks

	DELETE FROM dbo.mstProgramRegistrationTBL WHERE GUID IN (SELECT GUID FROM #Yaks);
	DELETE FROM dbo.mstSysRegistrationDetailsTBL WHERE GUID IN (SELECT GUID FROM #Yaks);
	DELETE FROM dbo.mstSysRegistrationsTBL WHERE GUID IN (SELECT GUID FROM #Yaks);
	DELETE FROM dbo.mstProgramsTBL WHERE ProgramID = @program_id
	DROP TABLE #Yaks


	Delete from @program_names where ID = @program_name

	Select @program_count = count(*) from @program_names
	IF(@program_count > 0) 
	BEGIN
		Set @program_name = (Select Top 1 ID from @program_names)
	END
END
