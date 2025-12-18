WITH MachineLossSummary AS (
    -- 1. รวมเวลาหยุดแยกตามเครื่องจักรและประเภทปัญหา
    SELECT 
        m.MachineName,
        lt.TypeNameTH,
        SUM(pr.CalculatedDowntimeMin) AS TotalLossMinutes,
        COUNT(pr.ProblemRecordID) AS OccurrenceCount
    FROM ProblemRecords pr
    JOIN ProductionRecords head ON pr.ProductionRecordID = head.ProductionRecordID
    JOIN Machines m ON head.MachineId = m.MachineId
    JOIN OeeLossTypes lt ON pr.ProblemTypeID = lt.ProblemTypeID
    WHERE lt.CategoryID = 20 -- เน้นที่ Unplanned Downtime
      AND head.ShiftDate BETWEEN '2025-12-01' AND '2025-12-31' -- ระบุช่วงวันที่ต้องการ
    GROUP BY m.MachineName, lt.TypeNameTH
),
RankedLosses AS (
    -- 2. จัดอันดับ Top 5 ของแต่ละเครื่องจักร
    SELECT 
        MachineName,
        TypeNameTH,
        TotalLossMinutes,
        OccurrenceCount,
        DENSE_RANK() OVER (PARTITION BY MachineName ORDER BY TotalLossMinutes DESC) AS LossRank
    FROM MachineLossSummary
)
-- 3. เลือกเฉพาะ 5 อันดับแรก
SELECT 
    MachineName,
    LossRank,
    TypeNameTH AS [Downtime Reason],
    TotalLossMinutes AS [Total Minutes],
    OccurrenceCount AS [Times Occurred]
FROM RankedLosses
WHERE LossRank <= 5
ORDER BY MachineName, LossRank;