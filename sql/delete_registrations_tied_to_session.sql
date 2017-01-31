-- Delete all registrations tied to a session.
-- Just specifiy the Session Name on line:5 (ProgramName in the database)
-- The temp table name #Yaks is arbitrary. Just go with it.

DECLARE @program_id INT = (SELECT TOP 1 ProgramID FROM mstProgramsTBL WHERE ProgramName = 'Automation_Single_Session_Segment')

SELECT GUID
INTO #Yaks
FROM dbo.mstProgramRegistrationTBL
WHERE ProgramID = @program_id

SELECT * FROM #Yaks

DELETE FROM dbo.mstProgramRegistrationTBL WHERE GUID IN (SELECT GUID FROM #Yaks);
DELETE FROM dbo.mstSysRegistrationDetailsTBL WHERE GUID IN (SELECT GUID FROM #Yaks);
DELETE FROM dbo.mstSysRegistrationsTBL WHERE GUID IN (SELECT GUID FROM #Yaks);

DROP TABLE #Yaks