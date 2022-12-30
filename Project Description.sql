
SELECT        
	a.JCCo, 
	a.JCCo AS HQKey, 
	RTRIM(a.Job) AS Job, 
	CAST(a.JCCo AS varchar) + ',' + RTRIM(CAST(a.Job AS varchar)) AS JKey, 
	a.Description,
/*Start Date*/ 
	CASE WHEN b.StartDate IS NULL THEN CAST(b.StartMonth AS date) END AS StartDate, 
/*Completion Date*/ 
	CASE WHEN b.CompletionDate IS NULL THEN CAST(b.ProjCloseDate AS date) END AS EndDate, 
/*CurrentMOS*/ 
	CASE WHEN b.CompletionDate IS NULL AND b.ProjCloseDate IS NULL AND b.StartDate IS NULL THEN DATEDIFF(Month, b.StartMonth, GETDATE()) 
		WHEN b.CompletionDate IS NULL AND b.ProjCloseDate IS NULL AND b.StartMonth IS NULL THEN DATEDIFF(Month, b.StartDate, GETDATE()) 
		ELSE b.TotalDuration END AS CurrMOS, 
/*Status*/ 
	CASE WHEN b.CompletionDate IS NULL AND b.ProjCloseDate IS NULL THEN 'Ongoing' ELSE 'Completed' END AS Status, 
/*Contact*/ 
	a.MailAddress, 
	a.MailCity, 
	a.MailState, 
	a.MailZip, 
/*Duration*/ 
	b.TotalDuration AS Duration, 
/*GSF*/ 
	b.GSF, 
	b.SuspendedSlab AS SuspSlab, 
	UPPER(LEFT(b.Material, 1)) + SUBSTRING(b.Material, 2, LEN(b.Material)) AS Material, 
	UPPER(LEFT(b.Use, 1)) + SUBSTRING(b.Use, 2, LEN(b.Use)) AS JobUse, 
CASE WHEN b.Floors >= 1 AND b.Floors < 16 THEN 'Midrise (1-15)' 
	WHEN b.Floors > 15 AND b.Floors < 36 THEN 'Typical (16-35)' 
	WHEN b.Floors > 35 THEN 'Tall Tower (35+)' ELSE NULL END AS TowerType, 
	b.Apt

FROM [HQ-DB-1].Viewpoint.dbo.JCJM AS a 
LEFT OUTER JOIN
[HQ-DB-1].Viewpoint.dbo.JCCM AS b 
ON a.JCCo = b.JCCo AND a.Job = b.Contract