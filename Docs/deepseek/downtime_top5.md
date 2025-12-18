# **SQL Queries สำหรับดึง Top 5 Downtime Reports**

## **1. รายงาน Top 5 Downtime รายเครื่อง (Daily)**

```sql
-- 1.1 Top 5 Downtime รายเครื่อง รายวัน
SELECT 
    m.MachineName,
    m.MachineLine,
    u.UnitName,
    dc.CategoryNameTH AS DowntimeCategory,
    olt.TypeNameTH AS DowntimeReason,
    COUNT(pr.ProblemRecordID) AS TotalIncidents,
    SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS TotalDowntimeMinutes,
    AVG(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS AvgDowntimeMinutes
FROM ProblemRecords pr
INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
INNER JOIN Machines m ON prod.MachineId = m.MachineId
INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
WHERE prod.ShiftDate = @TargetDate  -- กำหนดวันที่
    AND prod.RecordStatus = 'CLOSED'
    AND olt.IsActive = 1
GROUP BY 
    m.MachineId, 
    m.MachineName, 
    m.MachineLine, 
    u.UnitName,
    dc.CategoryNameTH,
    olt.TypeNameTH
ORDER BY 
    m.MachineName,
    TotalDowntimeMinutes DESC;
```

## **2. Top 5 Downtime รายเครื่อง (ช่วงวันที่)**

```sql
-- 2.1 Top 5 Downtime Reasons สำหรับแต่ละเครื่อง (ช่วงวันที่)
WITH RankedDowntime AS (
    SELECT 
        m.MachineName,
        m.MachineLine,
        u.UnitName,
        dc.CategoryNameTH AS Category,
        olt.TypeNameTH AS DowntimeReason,
        COUNT(pr.ProblemRecordID) AS IncidentCount,
        SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS TotalDowntimeMinutes,
        ROW_NUMBER() OVER (
            PARTITION BY m.MachineId 
            ORDER BY SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) DESC
        ) AS RankNumber
    FROM ProblemRecords pr
    INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
    INNER JOIN Machines m ON prod.MachineId = m.MachineId
    INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
    INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
    INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
    WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
        AND prod.RecordStatus = 'CLOSED'
        AND olt.IsActive = 1
        AND dc.CategoryLevel IN (10, 20)  -- Planned และ Unplanned เท่านั้น
    GROUP BY 
        m.MachineId, 
        m.MachineName, 
        m.MachineLine, 
        u.UnitName,
        dc.CategoryNameTH,
        olt.TypeNameTH
)
SELECT 
    MachineName,
    MachineLine,
    UnitName,
    Category,
    DowntimeReason,
    IncidentCount,
    TotalDowntimeMinutes,
    ROUND(CAST(TotalDowntimeMinutes AS FLOAT) * 100.0 / 
        SUM(TotalDowntimeMinutes) OVER (PARTITION BY MachineName), 2) AS PercentageOfTotal
FROM RankedDowntime
WHERE RankNumber <= 5
ORDER BY 
    UnitName,
    MachineName,
    TotalDowntimeMinutes DESC;
```

## **3. Top 5 Downtime รายเครื่อง พร้อมเวลาเฉลี่ย**

```sql
-- 3.1 Top 5 Downtime พร้อมข้อมูลเวลา
SELECT 
    m.MachineName,
    m.MachineLine,
    u.UnitName,
    u.BaggingCode,
    dc.CategoryNameTH,
    olt.TypeNameTH,
    -- สถิติ
    COUNT(pr.ProblemRecordID) AS TotalOccurrences,
    SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS TotalMinutes,
    AVG(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS AvgMinutes,
    MIN(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS MinMinutes,
    MAX(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS MaxMinutes,
    -- ข้อมูลเวลา
    MIN(pr.StopDateTime) AS FirstOccurrence,
    MAX(pr.StopDateTime) AS LastOccurrence,
    -- Personnel
    STRING_AGG(DISTINCT ed.DisplayName, ', ') AS ReportedByOperators
FROM ProblemRecords pr
INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
INNER JOIN Machines m ON prod.MachineId = m.MachineId
INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
LEFT JOIN EmployeeDetails ed ON pr.OperatorLogin = ed.WindowsLogin
WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
    AND prod.RecordStatus = 'CLOSED'
    AND olt.IsActive = 1
GROUP BY 
    m.MachineId, 
    m.MachineName, 
    m.MachineLine, 
    u.UnitName,
    u.BaggingCode,
    dc.CategoryNameTH,
    olt.TypeNameTH
HAVING COUNT(pr.ProblemRecordID) > 0
ORDER BY 
    u.UnitName,
    m.MachineName,
    TotalMinutes DESC;
```

## **4. Top 5 Downtime รายเครื่อง แบบ Pivot (เหมาะสำหรับ Excel)**

```sql
-- 4.1 Pivot Report: Top 5 Downtime Reasons ต่อเครื่อง
WITH MachineDowntime AS (
    SELECT 
        m.MachineName,
        olt.TypeNameTH AS DowntimeReason,
        dc.CategoryNameTH AS Category,
        SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS DowntimeMinutes,
        ROW_NUMBER() OVER (
            PARTITION BY m.MachineId 
            ORDER BY SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) DESC
        ) AS RankNumber
    FROM ProblemRecords pr
    INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
    INNER JOIN Machines m ON prod.MachineId = m.MachineId
    INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
    INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
    WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
        AND prod.RecordStatus = 'CLOSED'
        AND olt.IsActive = 1
    GROUP BY m.MachineId, m.MachineName, olt.TypeNameTH, dc.CategoryNameTH
),
Top5PerMachine AS (
    SELECT 
        MachineName,
        DowntimeReason,
        Category,
        DowntimeMinutes,
        RankNumber
    FROM MachineDowntime
    WHERE RankNumber <= 5
)
-- Pivot Results
SELECT 
    MachineName,
    MAX(CASE WHEN RankNumber = 1 THEN DowntimeReason END) AS Top1_Reason,
    MAX(CASE WHEN RankNumber = 1 THEN DowntimeMinutes END) AS Top1_Minutes,
    MAX(CASE WHEN RankNumber = 1 THEN Category END) AS Top1_Category,
    
    MAX(CASE WHEN RankNumber = 2 THEN DowntimeReason END) AS Top2_Reason,
    MAX(CASE WHEN RankNumber = 2 THEN DowntimeMinutes END) AS Top2_Minutes,
    MAX(CASE WHEN RankNumber = 2 THEN Category END) AS Top2_Category,
    
    MAX(CASE WHEN RankNumber = 3 THEN DowntimeReason END) AS Top3_Reason,
    MAX(CASE WHEN RankNumber = 3 THEN DowntimeMinutes END) AS Top3_Minutes,
    MAX(CASE WHEN RankNumber = 3 THEN Category END) AS Top3_Category,
    
    MAX(CASE WHEN RankNumber = 4 THEN DowntimeReason END) AS Top4_Reason,
    MAX(CASE WHEN RankNumber = 4 THEN DowntimeMinutes END) AS Top4_Minutes,
    MAX(CASE WHEN RankNumber = 4 THEN Category END) AS Top4_Category,
    
    MAX(CASE WHEN RankNumber = 5 THEN DowntimeReason END) AS Top5_Reason,
    MAX(CASE WHEN RankNumber = 5 THEN DowntimeMinutes END) AS Top5_Minutes,
    MAX(CASE WHEN RankNumber = 5 THEN Category END) AS Top5_Category,
    
    SUM(DowntimeMinutes) AS TotalTop5Minutes
FROM Top5PerMachine
GROUP BY MachineName
ORDER BY MachineName;
```

## **5. Top 5 Downtime แบบรายสัปดาห์**

```sql
-- 5.1 Weekly Top 5 Downtime Report
WITH WeeklyData AS (
    SELECT 
        m.MachineName,
        u.UnitName,
        olt.TypeNameTH AS DowntimeReason,
        dc.CategoryNameTH AS Category,
        DATEPART(WEEK, prod.ShiftDate) AS WeekNumber,
        MIN(prod.ShiftDate) AS WeekStartDate,
        MAX(prod.ShiftDate) AS WeekEndDate,
        SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS WeeklyDowntimeMinutes
    FROM ProblemRecords pr
    INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
    INNER JOIN Machines m ON prod.MachineId = m.MachineId
    INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
    INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
    INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
    WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
        AND prod.RecordStatus = 'CLOSED'
        AND olt.IsActive = 1
    GROUP BY 
        m.MachineId, 
        m.MachineName, 
        u.UnitName,
        olt.TypeNameTH,
        dc.CategoryNameTH,
        DATEPART(WEEK, prod.ShiftDate),
        DATEPART(YEAR, prod.ShiftDate)
),
RankedWeekly AS (
    SELECT 
        MachineName,
        UnitName,
        WeekNumber,
        WeekStartDate,
        WeekEndDate,
        DowntimeReason,
        Category,
        WeeklyDowntimeMinutes,
        ROW_NUMBER() OVER (
            PARTITION BY MachineName, WeekNumber 
            ORDER BY WeeklyDowntimeMinutes DESC
        ) AS WeeklyRank
    FROM WeeklyData
)
SELECT 
    MachineName,
    UnitName,
    WeekNumber,
    CONVERT(VARCHAR, WeekStartDate, 103) + ' - ' + CONVERT(VARCHAR, WeekEndDate, 103) AS WeekRange,
    DowntimeReason,
    Category,
    WeeklyDowntimeMinutes,
    ROUND(CAST(WeeklyDowntimeMinutes AS FLOAT) * 100.0 / 
        SUM(WeeklyDowntimeMinutes) OVER (PARTITION BY MachineName, WeekNumber), 2) AS WeeklyPercentage
FROM RankedWeekly
WHERE WeeklyRank <= 5
ORDER BY 
    MachineName,
    WeekNumber,
    WeeklyDowntimeMinutes DESC;
```

## **6. Top 5 Downtime แบบกราฟพร้อมข้อมูลสรุป**

```sql
-- 6.1 Dashboard Data สำหรับแสดงกราฟ
WITH MachineSummary AS (
    SELECT 
        m.MachineId,
        m.MachineName,
        m.MachineLine,
        u.UnitName,
        u.BaggingCode,
        -- Total Downtime
        SUM(CASE WHEN dc.CategoryLevel = 10 THEN DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime) ELSE 0 END) AS PlannedDowntime,
        SUM(CASE WHEN dc.CategoryLevel = 20 THEN DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime) ELSE 0 END) AS UnplannedDowntime,
        SUM(CASE WHEN dc.CategoryLevel = 21 THEN DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime) ELSE 0 END) AS SpeedLoss,
        SUM(CASE WHEN dc.CategoryLevel = 30 THEN DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime) ELSE 0 END) AS QualityLoss,
        -- Total Production Time
        SUM(DATEDIFF(MINUTE, prod.SegmentStartDateTime, prod.SegmentEndDateTime)) AS TotalProductionTime
    FROM ProductionRecords prod
    LEFT JOIN ProblemRecords pr ON prod.ProductionRecordID = pr.ProductionRecordID
    LEFT JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
    LEFT JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
    INNER JOIN Machines m ON prod.MachineId = m.MachineId
    INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
    WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
        AND prod.RecordStatus = 'CLOSED'
    GROUP BY m.MachineId, m.MachineName, m.MachineLine, u.UnitName, u.BaggingCode
),
TopDowntimeReasons AS (
    SELECT 
        m.MachineId,
        olt.TypeNameTH AS Reason,
        dc.CategoryNameTH AS Category,
        COUNT(pr.ProblemRecordID) AS Occurrences,
        SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS TotalMinutes,
        ROW_NUMBER() OVER (
            PARTITION BY m.MachineId 
            ORDER BY SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) DESC
        ) AS RankNumber
    FROM ProblemRecords pr
    INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
    INNER JOIN Machines m ON prod.MachineId = m.MachineId
    INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
    INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
    WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
        AND prod.RecordStatus = 'CLOSED'
        AND olt.IsActive = 1
    GROUP BY m.MachineId, olt.TypeNameTH, dc.CategoryNameTH
)
SELECT 
    ms.MachineName,
    ms.MachineLine,
    ms.UnitName,
    ms.BaggingCode,
    -- Summary Statistics
    ms.TotalProductionTime,
    ms.PlannedDowntime,
    ms.UnplannedDowntime,
    ms.SpeedLoss,
    ms.QualityLoss,
    ms.PlannedDowntime + ms.UnplannedDowntime + ms.SpeedLoss + ms.QualityLoss AS TotalDowntime,
    -- Downtime Percentage
    ROUND(CAST((ms.PlannedDowntime + ms.UnplannedDowntime) * 100.0 / 
        NULLIF(ms.TotalProductionTime, 0) AS DECIMAL(5,2)), 2) AS DowntimePercentage,
    -- Top 5 Reasons
    STRING_AGG(CASE WHEN tdr.RankNumber = 1 THEN tdr.Reason END, ', ') AS Top1_Reason,
    MAX(CASE WHEN tdr.RankNumber = 1 THEN tdr.TotalMinutes END) AS Top1_Minutes,
    STRING_AGG(CASE WHEN tdr.RankNumber = 2 THEN tdr.Reason END, ', ') AS Top2_Reason,
    MAX(CASE WHEN tdr.RankNumber = 2 THEN tdr.TotalMinutes END) AS Top2_Minutes,
    STRING_AGG(CASE WHEN tdr.RankNumber = 3 THEN tdr.Reason END, ', ') AS Top3_Reason,
    MAX(CASE WHEN tdr.RankNumber = 3 THEN tdr.TotalMinutes END) AS Top3_Minutes,
    STRING_AGG(CASE WHEN tdr.RankNumber = 4 THEN tdr.Reason END, ', ') AS Top4_Reason,
    MAX(CASE WHEN tdr.RankNumber = 4 THEN tdr.TotalMinutes END) AS Top4_Minutes,
    STRING_AGG(CASE WHEN tdr.RankNumber = 5 THEN tdr.Reason END, ', ') AS Top5_Reason,
    MAX(CASE WHEN tdr.RankNumber = 5 THEN tdr.TotalMinutes END) AS Top5_Minutes
FROM MachineSummary ms
LEFT JOIN TopDowntimeReasons tdr ON ms.MachineId = tdr.MachineId AND tdr.RankNumber <= 5
GROUP BY 
    ms.MachineId, 
    ms.MachineName, 
    ms.MachineLine, 
    ms.UnitName, 
    ms.BaggingCode,
    ms.TotalProductionTime,
    ms.PlannedDowntime,
    ms.UnplannedDowntime,
    ms.SpeedLoss,
    ms.QualityLoss
ORDER BY 
    ms.UnitName,
    ms.MachineName;
```

## **7. Stored Procedure สำหรับดึง Top 5 Downtime Report**

```sql
-- 7.1 Create Stored Procedure for Top 5 Downtime Report
CREATE PROCEDURE GetTop5DowntimeReport
    @StartDate DATE,
    @EndDate DATE,
    @MachineId INT = NULL,
    @UnitId INT = NULL,
    @BaggingCode VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    WITH RankedDowntime AS (
        SELECT 
            m.MachineId,
            m.MachineName,
            m.MachineLine,
            u.UnitName,
            u.BaggingCode,
            dc.CategoryNameTH AS Category,
            olt.TypeNameTH AS DowntimeReason,
            COUNT(pr.ProblemRecordID) AS IncidentCount,
            SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS TotalMinutes,
            AVG(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS AvgMinutes,
            MIN(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS MinMinutes,
            MAX(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS MaxMinutes,
            ROW_NUMBER() OVER (
                PARTITION BY m.MachineId 
                ORDER BY SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) DESC
            ) AS RankNumber
        FROM ProblemRecords pr
        INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
        INNER JOIN Machines m ON prod.MachineId = m.MachineId
        INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
        INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
        INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
        WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
            AND prod.RecordStatus = 'CLOSED'
            AND olt.IsActive = 1
            AND (@MachineId IS NULL OR m.MachineId = @MachineId)
            AND (@UnitId IS NULL OR m.UnitId = @UnitId)
            AND (@BaggingCode IS NULL OR u.BaggingCode = @BaggingCode)
        GROUP BY 
            m.MachineId, 
            m.MachineName, 
            m.MachineLine, 
            u.UnitName,
            u.BaggingCode,
            dc.CategoryNameTH,
            olt.TypeNameTH
    )
    SELECT 
        MachineName,
        MachineLine,
        UnitName,
        BaggingCode,
        Category,
        DowntimeReason,
        IncidentCount,
        TotalMinutes,
        AvgMinutes,
        MinMinutes,
        MaxMinutes,
        RankNumber,
        ROUND(CAST(TotalMinutes AS FLOAT) * 100.0 / 
            SUM(TotalMinutes) OVER (PARTITION BY MachineId), 2) AS PercentageOfMachineTotal
    FROM RankedDowntime
    WHERE RankNumber <= 5
    ORDER BY 
        UnitName,
        MachineName,
        RankNumber;
END
GO

-- 7.2 Usage Example
EXEC GetTop5DowntimeReport 
    @StartDate = '2024-01-01',
    @EndDate = '2024-01-31',
    @MachineId = NULL,  -- ทุกเครื่อง
    @UnitId = 1,        -- เฉพาะ Unit PP1&2
    @BaggingCode = 'PL'; -- เฉพาะ Bagging PL
```

## **8. View สำหรับใช้งานง่าย**

```sql
-- 8.1 Create View สำหรับ Top Downtime
CREATE VIEW vw_TopDowntimeSummary AS
WITH MonthlyDowntime AS (
    SELECT 
        m.MachineId,
        m.MachineName,
        u.UnitName,
        olt.TypeNameTH AS DowntimeReason,
        dc.CategoryNameTH AS Category,
        YEAR(prod.ShiftDate) AS ReportYear,
        MONTH(prod.ShiftDate) AS ReportMonth,
        SUM(DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime)) AS MonthlyMinutes
    FROM ProblemRecords pr
    INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
    INNER JOIN Machines m ON prod.MachineId = m.MachineId
    INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
    INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
    INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
    WHERE prod.RecordStatus = 'CLOSED'
        AND olt.IsActive = 1
    GROUP BY 
        m.MachineId, 
        m.MachineName, 
        u.UnitName,
        olt.TypeNameTH,
        dc.CategoryNameTH,
        YEAR(prod.ShiftDate),
        MONTH(prod.ShiftDate)
),
Ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY MachineId, ReportYear, ReportMonth 
            ORDER BY MonthlyMinutes DESC
        ) AS MonthlyRank
    FROM MonthlyDowntime
)
SELECT 
    MachineName,
    UnitName,
    DowntimeReason,
    Category,
    ReportYear,
    ReportMonth,
    DATENAME(MONTH, DATEFROMPARTS(ReportYear, ReportMonth, 1)) AS MonthName,
    MonthlyMinutes,
    MonthlyRank
FROM Ranked
WHERE MonthlyRank <= 5;
GO

-- 8.2 Query จาก View
SELECT * FROM vw_TopDowntimeSummary
WHERE ReportYear = 2024 AND ReportMonth = 1
ORDER BY UnitName, MachineName, MonthlyRank;
```

## **9. Export ไป Excel/Power BI**

```sql
-- 9.1 Query สำหรับ Export
SELECT 
    m.MachineName,
    m.MachineLine,
    u.UnitName,
    u.BaggingCode,
    FORMAT(prod.ShiftDate, 'yyyy-MM-dd') AS ShiftDate,
    FORMAT(pr.StopDateTime, 'HH:mm') AS StopTime,
    FORMAT(pr.StartDateTime, 'HH:mm') AS StartTime,
    DATEDIFF(MINUTE, pr.StopDateTime, pr.StartDateTime) AS DowntimeMinutes,
    dc.CategoryNameTH AS Category,
    olt.TypeNameTH AS DowntimeReason,
    pr.ProblemDescription,
    pr.RootCause,
    pr.ActionTaken,
    operator_ed.DisplayName AS OperatorName,
    maintenance_ed.DisplayName AS MaintenanceName,
    CASE pr.ProblemStatus 
        WHEN 'OPEN' THEN 'เปิด'
        WHEN 'IN_PROGRESS' THEN 'กำลังดำเนินการ'
        WHEN 'RESOLVED' THEN 'แก้ไขแล้ว'
        ELSE 'อื่นๆ'
    END AS StatusThai
FROM ProblemRecords pr
INNER JOIN ProductionRecords prod ON pr.ProductionRecordID = prod.ProductionRecordID
INNER JOIN Machines m ON prod.MachineId = m.MachineId
INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
INNER JOIN OeeLossTypes olt ON pr.ProblemTypeID = olt.ProblemTypeID
INNER JOIN DowntimeCategories dc ON olt.CategoryID = dc.CategoryID
LEFT JOIN EmployeeDetails operator_ed ON pr.OperatorLogin = operator_ed.WindowsLogin
LEFT JOIN EmployeeDetails maintenance_ed ON pr.MaintenanceLogin = maintenance_ed.WindowsLogin
WHERE prod.ShiftDate BETWEEN @StartDate AND @EndDate
    AND prod.RecordStatus = 'CLOSED'
    AND olt.IsActive = 1
ORDER BY 
    u.UnitName,
    m.MachineName,
    prod.ShiftDate,
    pr.StopDateTime;
```

## **10. สรุป: แนะนำ Query ที่ใช้บ่อย**

| วัตถุประสงค์ | Query ที่แนะนำ | เหมาะสำหรับ |
|------------|--------------|------------|
| **Daily Report** | Query 1.1 | รายงานประจำวัน |
| **Weekly Summary** | Query 5.1 | สรุปรายสัปดาห์ |
| **Dashboard** | Query 6.1 | แสดงใน Dashboard |
| **Excel Export** | Query 4.1 หรือ 9.1 | ส่งออก Excel |
| **Power BI** | Query 8.1 (View) | Connection Power BI |
| **Flexible Report** | Stored Procedure 7.1 | รายงานที่ปรับได้ |

**ตัวอย่างการเรียกใช้งาน:**
```sql
-- ดึง Top 5 Downtime เดือนมกราคม 2024
EXEC GetTop5DowntimeReport 
    @StartDate = '2024-01-01',
    @EndDate = '2024-01-31';

-- หรือใช้ View สำหรับรายเดือน
SELECT * FROM vw_TopDowntimeSummary
WHERE ReportYear = 2024 AND ReportMonth = 1
ORDER BY UnitName, MachineName, MonthlyRank;
```

ทุก Query ออกแบบมาให้ใช้งานกับ Database Schema ที่เราออกแบบไว้ครับ! 🎯