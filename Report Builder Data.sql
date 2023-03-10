
CREATE PROCEDURE RBJCCDGC
AS

--Create CTE of the Raw Data

WITH ActualTable AS (

SELECT        
	CAST(a.JCCo AS VARCHAR) + ',' + RTRIM(CAST(a.Job AS VARCHAR)) AS JKey, 
	a.JCCo,
	a.Job,
	CAST(a.JCCo AS VARCHAR) + ',' + RTRIM(CAST(a.Job AS VARCHAR)) + ',' + CAST(a.PhaseGroup AS VARCHAR) + ',' + CAST(a.Phase AS VARCHAR) AS PCKey,
	CAST(a.PhaseGroup AS VARCHAR) + ',' + CAST(a.CostType AS VARCHAR) AS CTKey, 
	CAST(a.VendorGroup AS VARCHAR) + ',' + CAST(ISNULL(CAST(a. Vendor AS VARCHAR), CAST(a.Source AS VARCHAR)) AS VARCHAR) AS VKey, 
	CAST(a.GLCo AS VARCHAR) + ',' + CAST(a.GLTransAcct AS VARCHAR) AS GLKey,
	ISNULL(a.JCCo, a.APCo) AS HQKey, 
	DENSE_RANK() OVER(PARTITION BY JKey ORDER BY JKey,a.Mth) AS MthIndex,
	CAST(a.Mth AS Date) AS Mth, 
	a.ActualCost,
	
--Determine if previous month has a value to populate

CASE WHEN (SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b 
	WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -1, a.Mth)) IS NULL 
	THEN 0 
ELSE (CAST(1 AS Float) / CAST(COUNT(a.Phase) OVER (PARTITION BY a.JCCo, a.Job, a.Mth, a.Phase ORDER BY a.JCCo, a.Job, a.Mth) AS Float)) 
	*
	ISNULL((SELECT SUM(ActualCost)  FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -1, a.Mth)), 0) 
END AS PrevAmount,

--Difference from previous value

	a.ActualCost
	-
CASE WHEN (SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b 
	WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -1, a.Mth)) IS NULL 
	THEN 0 
ELSE (CAST(1 AS Float) / CAST(COUNT(a.Phase) OVER (PARTITION BY a.JCCo, a.Job, a.Mth, a.Phase ORDER BY a.JCCo, a.Job, a.Mth) AS Float)) 
	*
	ISNULL((SELECT SUM(ActualCost)  FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -1, a.Mth)), 0) 
END AS Diff,
	a.EstCost, 
	SUM(a.EstCost) OVER (PARTITION BY a.JCCo, a.Job ORDER BY a.JCCo, a.Job, a.Mth) AS EstCostRT, 
	 
CASE WHEN a.ActualCost = 0 OR b.GSF = 0 OR b.GSF IS NULL THEN 0 
ELSE a.ActualCost / b.GSF END AS GSFMOS, 
	b.Duration, 
	b.GSF, 
	b.SuspSlab, 

--Total Monthly cost by each row of the month

	(CAST(1 AS Float) / CAST(COUNT(a.Phase) OVER (PARTITION BY a.JCCo, a.Job, a.Mth ORDER BY a.JCCo, a.Job, a.Mth) AS Float)) 
	* 
	(CASE WHEN (SUM(a.EstCost) OVER (PARTITION BY a.JCCo, a.Job ORDER BY a.JCCo, a.Job, a.Mth)) = 0 OR b.Duration = 0 THEN 0 
	ELSE (SUM(a.EstCost) OVER (PARTITION BY a.JCCo, a.Job ORDER BY a.JCCo, a.Job, a.Mth)) / b.Duration END) AS ESTCostMOS 
	
FROM        
[HQ-DB-1].Viewpoint.dbo.JCCD AS a LEFT OUTER JOIN
                         dbo.JCJMD AS b ON a.JCCo = b.JCCo AND a.Job = b.Job
WHERE        (a.Phase LIKE '01%') ),

--Create CTE to add extra row with the previous month cost if needed

LastMthCost AS
	(
SELECT 
	CAST(a.JCCo AS VARCHAR) + ',' + RTRIM(CAST(a.Job AS VARCHAR)) AS JKey, 
	a.JCCo,
	a.Job,
	CAST(a.JCCo AS VARCHAR) + ',' + RTRIM(CAST(a.Job AS VARCHAR)) + ',' + CAST(a.PhaseGroup AS VARCHAR) + ',' + CAST(a.Phase AS VARCHAR) AS PCKey, 
	CAST(a.PhaseGroup AS VARCHAR) + ',' + CAST(a.CostType AS VARCHAR) AS CTKey, 
	CAST(a.VendorGroup AS VARCHAR) + ',' + CAST(ISNULL(CAST(a. Vendor AS VARCHAR), CAST(a.Source AS VARCHAR)) AS VARCHAR) AS VKey, 
	CAST(a.GLCo AS VARCHAR) + ',' + CAST(a.GLTransAcct AS VARCHAR) AS GLKey,
	ISNULL(a.JCCo, a.APCo) AS HQKey, 
	DENSE_RANK() OVER(PARTITION BY a.JCCo, a.Job ORDER BY a.JCCo, a.Job,a.Mth) AS MthIndex,
	CAST(DATEADD(Month, -1, a.Mth) AS Date) AS Mth, 

--Previous 1 month cost

CASE WHEN (SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -1, a.Mth)) IS NULL 
THEN 0
END AS ActualCost,

--Previous 2 month cost

CASE WHEN (SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -2, a.Mth)) IS NULL 
THEN 0
ELSE (CAST(1 AS Float) / CAST(COUNT(a.Phase) OVER (PARTITION BY a.JCCo, a.Job, a.Mth, a.Phase ORDER BY a.JCCo, a.Job, a.Mth) AS Float)) 
	*
	ISNULL((SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -2, a.Mth)), 0)  
END AS PrevCost,

--Difference between previous 1 month and previous 2 month cost

CASE WHEN (SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -1, a.Mth)) IS NULL 
THEN 0 END
	-
CASE WHEN (SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -2, a.Mth)) IS NULL 
THEN 0
ELSE (CAST(1 AS Float) / CAST(COUNT(a.Phase) OVER (PARTITION BY a.JCCo, a.Job, a.Mth, a.Phase ORDER BY a.JCCo, a.Job, a.Mth) AS Float)) 
	*
	ISNULL((SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, -2, a.Mth)), 0)  
END	AS Diff,

	NULL AS EstCost, 
	NULL AS EstCostRT, 
	NULL AS GSFMOS, 
	b.Duration, 
	b.GSF, 
	b.SuspSlab, 
	NULL AS ESTCostMOS 
FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS a 
LEFT OUTER JOIN dbo.JCJMD AS b ON a.JCCo = b.JCCo AND a.Job = b.Job
WHERE        (a.Phase LIKE '01%')) ,

--Create CTE to add extra row with the next month cost if needed

NextMonth AS (

SELECT 
	CAST(a.JCCo AS VARCHAR) + ',' + RTRIM(CAST(a.Job AS VARCHAR)) AS JKey, 
	a.JCCo,
	a.Job,
	CAST(a.JCCo AS VARCHAR) + ',' + RTRIM(CAST(a.Job AS VARCHAR)) + ',' + CAST(a.PhaseGroup AS VARCHAR) + ',' + CAST(a.Phase AS VARCHAR) AS PCKey, 
	CAST(a.PhaseGroup AS VARCHAR) + ',' + CAST(a.CostType AS VARCHAR) AS CTKey, 
	CAST(a.VendorGroup AS VARCHAR) + ',' + CAST(ISNULL(CAST(a. Vendor AS VARCHAR), CAST(a.Source AS VARCHAR)) AS VARCHAR) AS VKey, 
	CAST(a.GLCo AS VARCHAR) + ',' + CAST(a.GLTransAcct AS VARCHAR) AS GLKey,
	ISNULL(a.JCCo, a.APCo) AS HQKey, 
	DENSE_RANK() OVER(PARTITION BY a.JCCo, a.Job ORDER BY a.JCCo, a.Job,a.Mth) AS MthIndex,
	CAST(DATEADD(Month, 1, a.Mth) AS Date) AS Mth, 

--Next 1 month cost

CASE WHEN (SELECT SUM(ActualCost)  
	FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, 1, a.Mth)) = 0 
THEN ISNULL((SELECT SUM(ActualCost)  FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS b WHERE a.JCCo=b.JCCo AND a.Job=b.Job AND a.PhaseGroup=b.PhaseGroup AND a.Phase=b.Phase AND b.Mth=DATEADD(Month, 1, a.Mth)), 0) 
END AS ActualCost,

	NULL AS PrevCost,
	NULL AS Diff,
	NULL AS EstCost, 
	NULL AS EstCostRT, 
	NULL AS GSFMOS, 
	b.Duration, 
	b.GSF, 
	b.SuspSlab, 
	NULL AS ESTCostMOS 
FROM [HQ-DB-1].Viewpoint.dbo.JCCD AS a 
LEFT OUTER JOIN dbo.JCJMD AS b ON a.JCCo = b.JCCo AND a.Job = b.Job
WHERE        (a.Phase LIKE '01%') )

--Bring all the CTEs together

SELECT * FROM ActualTable
UNION ALL
SELECT * FROM NextMonth
UNION ALL
SELECT * FROM LastMthCost

