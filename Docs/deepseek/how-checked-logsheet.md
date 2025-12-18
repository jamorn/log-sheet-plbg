# Q : ผมสงสัยการ desin database ครับ ขอถามว่า กะเช้า การดึงข้อมูลทั้งหมด ของการทำงาน เพื่อตรวจสอบว่า ลงข้อมูลครบหรือยัง ของ operator การดึงข้อมูล ใช้ logic อะไรครับ
# A :
# **Logic การตรวจสอบว่าลงข้อมูลครบหรือยัง สำหรับแต่ละกะ**

## **ปัญหาที่ต้องแก้:**
1. ต้องรู้ว่า Operator ในกะเช้าลงข้อมูลการผลิตครบทุกเครื่องหรือยัง
2. ต้องรู้ว่าเครื่องไหนยังไม่ได้บันทึกข้อมูล
3. ต้องรู้ว่าข้อมูลที่บันทึกครบตามเงื่อนไขหรือไม่

## **Solution: ใช้ Logic "Expected vs Actual"**

### **1. ก่อนอื่นต้องรู้ว่า "ควรมีข้อมูลเท่าไร"**
```sql
-- 1.1 หาว่าแต่ละกะควรมีเครื่องที่ทำงานกี่เครื่อง
-- สมมติ: กะเช้า (ShiftID = 1) เวลา 06:00-14:00

-- ดูว่าเครื่องไหน Active และควรทำงานในกะนี้
SELECT 
    m.MachineId,
    m.MachineName,
    m.UnitId,
    u.UnitName,
    -- ตรวจสอบว่าเครื่องมีสถานะ Operational หรือไม่ (จาก MachineStatus)
    ISNULL(ms.IsOperational, 1) AS ShouldBeOperating
FROM Machines m
INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
LEFT JOIN MachineStatus ms ON m.MachineId = ms.MachineId 
    AND ms.RecordDate = @TargetDate  -- วันที่ต้องการตรวจสอบ
WHERE m.MachineActive = 1
    AND ISNULL(ms.IsOperational, 1) = 1  -- เครื่องควรทำงานปกติ
ORDER BY u.UnitName, m.MachineName;
```

### **2. Logic ตรวจสอบความครบถ้วน**

```sql
-- 2.1 ตรวจสอบว่ามี Production Records ครบทุกเครื่องหรือไม่
DECLARE @ShiftDate DATE = '2024-01-15';
DECLARE @ShiftID INT = 1;  -- กะเช้า

WITH ExpectedMachines AS (
    -- เครื่องที่ควรมีข้อมูล (เครื่อง Active + ไม่เสีย)
    SELECT 
        m.MachineId,
        m.MachineName,
        u.UnitName
    FROM Machines m
    INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
    LEFT JOIN MachineStatus ms ON m.MachineId = ms.MachineId 
        AND ms.RecordDate = @ShiftDate
    WHERE m.MachineActive = 1
        AND ISNULL(ms.IsOperational, 1) = 1
),
ActualRecords AS (
    -- เครื่องที่มีข้อมูลจริงในกะเช้าวันนั้น
    SELECT 
        pr.MachineId,
        COUNT(pr.ProductionRecordID) AS RecordCount,
        SUM(DATEDIFF(MINUTE, pr.SegmentStartDateTime, pr.SegmentEndDateTime)) AS TotalMinutes,
        SUM(pr.BagOutActualMT) AS TotalProductionMT
    FROM ProductionRecords pr
    WHERE pr.ShiftDate = @ShiftDate
        AND pr.ShiftID = @ShiftID
        AND pr.RecordStatus IN ('CLOSED', 'IN_PROGRESS')  -- ข้อมูลที่บันทึกแล้ว
    GROUP BY pr.MachineId
)
SELECT 
    em.MachineId,
    em.MachineName,
    em.UnitName,
    CASE 
        WHEN ar.MachineId IS NULL THEN '❌ ไม่มีข้อมูล'
        WHEN ar.TotalMinutes < 480 THEN '⚠️ ข้อมูลไม่ครบ (น้อยกว่า 8 ชม.)'
        WHEN ar.RecordCount = 0 THEN '❌ ไม่มี Record'
        ELSE '✅ ครบถ้วน'
    END AS Status,
    ISNULL(ar.RecordCount, 0) AS RecordCount,
    ISNULL(ar.TotalMinutes, 0) AS TotalMinutes,
    ISNULL(ar.TotalProductionMT, 0) AS TotalProductionMT,
    -- ตรวจสอบว่า TotalMinutes ใกล้เคียง 480 นาที (8 ชม.) หรือไม่
    CASE 
        WHEN ISNULL(ar.TotalMinutes, 0) >= 470 THEN '✅ ครบเวลา'
        WHEN ISNULL(ar.TotalMinutes, 0) >= 400 THEN '⚠️ ขาดเล็กน้อย'
        ELSE '❌ ขาดมาก'
    END AS TimeCompleteness
FROM ExpectedMachines em
LEFT JOIN ActualRecords ar ON em.MachineId = ar.MachineId
ORDER BY em.UnitName, em.MachineName;
```

### **3. ตรวจสอบรายละเอียดเพิ่มเติม**

```sql
-- 3.1 ตรวจสอบความครบถ้วนแบบละเอียด
DECLARE @ShiftDate DATE = '2024-01-15';
DECLARE @ShiftID INT = 1;

WITH ShiftInfo AS (
    SELECT 
        ShiftID,
        StartTime,
        EndTime,
        DATEDIFF(MINUTE, StartTime, 
            CASE 
                WHEN EndTime > StartTime THEN EndTime
                ELSE DATEADD(HOUR, 24, EndTime)  -- กรณีข้ามเที่ยงคืน
            END) AS ShiftDurationMinutes
    FROM Shifts
    WHERE ShiftID = @ShiftID
),
MachineCompleteness AS (
    SELECT 
        m.MachineId,
        m.MachineName,
        u.UnitName,
        -- Expected Time (นาที)
        si.ShiftDurationMinutes AS ExpectedMinutes,
        -- Actual Time
        ISNULL(SUM(DATEDIFF(MINUTE, pr.SegmentStartDateTime, pr.SegmentEndDateTime)), 0) AS ActualMinutes,
        -- Record Count
        ISNULL(COUNT(pr.ProductionRecordID), 0) AS RecordCount,
        -- Gap Analysis
        ISNULL(SUM(DATEDIFF(MINUTE, pr.SegmentStartDateTime, pr.SegmentEndDateTime)), 0) 
            - si.ShiftDurationMinutes AS TimeGap,
        -- Coverage Percentage
        ROUND(CAST(ISNULL(SUM(DATEDIFF(MINUTE, pr.SegmentStartDateTime, pr.SegmentEndDateTime)), 0) * 100.0 
            / NULLIF(si.ShiftDurationMinutes, 0), 2), 2) AS CoveragePercentage,
        -- Last Update
        MAX(pr.EnteredAt) AS LastUpdated
    FROM Machines m
    CROSS JOIN ShiftInfo si
    INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
    LEFT JOIN ProductionRecords pr ON m.MachineId = pr.MachineId
        AND pr.ShiftDate = @ShiftDate
        AND pr.ShiftID = @ShiftID
        AND pr.RecordStatus IN ('CLOSED', 'IN_PROGRESS')
    LEFT JOIN MachineStatus ms ON m.MachineId = ms.MachineId 
        AND ms.RecordDate = @ShiftDate
    WHERE m.MachineActive = 1
        AND ISNULL(ms.IsOperational, 1) = 1
    GROUP BY 
        m.MachineId, 
        m.MachineName, 
        u.UnitName,
        si.ShiftDurationMinutes
)
SELECT 
    MachineId,
    MachineName,
    UnitName,
    ExpectedMinutes,
    ActualMinutes,
    RecordCount,
    TimeGap,
    CoveragePercentage,
    CASE 
        WHEN CoveragePercentage >= 95 THEN '✅ ดีมาก'
        WHEN CoveragePercentage >= 85 THEN '⚠️ พอใช้'
        WHEN CoveragePercentage >= 70 THEN '⚠️ ต้องปรับปรุง'
        ELSE '❌ ตกสำรวจ'
    END AS Rating,
    LastUpdated,
    -- ตรวจสอบเวลา Gap
    CASE 
        WHEN ActualMinutes = 0 THEN 'ยังไม่เริ่มบันทึก'
        WHEN TimeGap >= 60 THEN 'ขาดข้อมูลมาก (>1 ชม.)'
        WHEN TimeGap >= 30 THEN 'ขาดข้อมูลปานกลาง'
        WHEN TimeGap >= 0 AND TimeGap < 30 THEN 'เกือบครบ'
        ELSE 'ข้อมูลเกินเวลา'  -- กรณีบันทึกเกิน
    END AS GapDescription
FROM MachineCompleteness
ORDER BY 
    CoveragePercentage,  -- เรียงจากน้อยไปมาก (ให้เห็นเครื่องที่ขาดข้อมูลก่อน)
    UnitName,
    MachineName;
```

### **4. ตรวจสอบตามช่วงเวลา (Time Slots)**

```sql
-- 4.1 ตรวจสอบว่าแต่ละช่วงเวลา (ทุก 2 ชม.) มีข้อมูลหรือไม่
DECLARE @ShiftDate DATE = '2024-01-15';
DECLARE @ShiftID INT = 1;
DECLARE @TimeSlots TABLE (
    SlotNumber INT,
    StartTime TIME,
    EndTime TIME
);

-- สร้าง Time Slots ทุก 2 ชม. สำหรับกะเช้า (06:00-14:00)
INSERT INTO @TimeSlots VALUES
(1, '06:00', '08:00'),
(2, '08:00', '10:00'),
(3, '10:00', '12:00'),
(4, '12:00', '14:00');

SELECT 
    m.MachineName,
    u.UnitName,
    ts.SlotNumber,
    ts.StartTime,
    ts.EndTime,
    -- ตรวจสอบว่ามีข้อมูลใน Slot นี้หรือไม่
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM ProductionRecords pr
            WHERE pr.MachineId = m.MachineId
                AND pr.ShiftDate = @ShiftDate
                AND pr.ShiftID = @ShiftID
                AND (
                    (CAST(pr.SegmentStartDateTime AS TIME) BETWEEN ts.StartTime AND ts.EndTime)
                    OR (CAST(pr.SegmentEndDateTime AS TIME) BETWEEN ts.StartTime AND ts.EndTime)
                    OR (ts.StartTime BETWEEN CAST(pr.SegmentStartDateTime AS TIME) AND CAST(pr.SegmentEndDateTime AS TIME))
                )
        ) THEN '✅'
        ELSE '❌'
    END AS HasData,
    -- ข้อมูลใน Slot นี้
    ISNULL((
        SELECT SUM(DATEDIFF(MINUTE, 
            CASE WHEN CAST(pr.SegmentStartDateTime AS TIME) < ts.StartTime THEN ts.StartTime ELSE CAST(pr.SegmentStartDateTime AS TIME) END,
            CASE WHEN CAST(pr.SegmentEndDateTime AS TIME) > ts.EndTime THEN ts.EndTime ELSE CAST(pr.SegmentEndDateTime AS TIME) END
        ))
        FROM ProductionRecords pr
        WHERE pr.MachineId = m.MachineId
            AND pr.ShiftDate = @ShiftDate
            AND pr.ShiftID = @ShiftID
            AND pr.RecordStatus IN ('CLOSED', 'IN_PROGRESS')
            AND pr.SegmentStartDateTime < DATEADD(DAY, 1, CAST(@ShiftDate AS DATETIME))  -- ไม่เกิน 24:00
            AND pr.SegmentEndDateTime > CAST(@ShiftDate AS DATETIME)
            AND (
                (CAST(pr.SegmentStartDateTime AS TIME) < ts.EndTime)
                AND (CAST(pr.SegmentEndDateTime AS TIME) > ts.StartTime)
            )
    ), 0) AS MinutesInSlot
FROM Machines m
INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
CROSS JOIN @TimeSlots ts
LEFT JOIN MachineStatus ms ON m.MachineId = ms.MachineId 
    AND ms.RecordDate = @ShiftDate
WHERE m.MachineActive = 1
    AND ISNULL(ms.IsOperational, 1) = 1
ORDER BY 
    u.UnitName,
    m.MachineName,
    ts.SlotNumber;
```

### **5. Dashboard View สำหรับ Supervisor**

```sql
-- 5.1 สร้าง View สำหรับตรวจสอบความครบถ้วน
CREATE VIEW vw_ShiftCompleteness AS
WITH ShiftCompleteness AS (
    SELECT 
        pr.ShiftDate,
        pr.ShiftID,
        s.ShiftName,
        m.MachineId,
        m.MachineName,
        u.UnitName,
        u.BaggingCode,
        -- Expected Time
        DATEDIFF(MINUTE, s.StartTime, 
            CASE 
                WHEN s.EndTime > s.StartTime THEN s.EndTime
                ELSE DATEADD(HOUR, 24, s.EndTime)
            END) AS ExpectedMinutes,
        -- Actual Time
        SUM(DATEDIFF(MINUTE, pr.SegmentStartDateTime, pr.SegmentEndDateTime)) AS ActualMinutes,
        -- Record Count
        COUNT(pr.ProductionRecordID) AS RecordCount,
        -- Last Update
        MAX(pr.EnteredAt) AS LastUpdated,
        -- Operator
        STRING_AGG(DISTINCT pr.EnteredBy, ', ') AS Operators
    FROM ProductionRecords pr
    INNER JOIN Shifts s ON pr.ShiftID = s.ShiftID
    INNER JOIN Machines m ON pr.MachineId = m.MachineId
    INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
    WHERE pr.RecordStatus IN ('CLOSED', 'IN_PROGRESS')
    GROUP BY 
        pr.ShiftDate,
        pr.ShiftID,
        s.ShiftName,
        m.MachineId,
        m.MachineName,
        u.UnitName,
        u.BaggingCode,
        s.StartTime,
        s.EndTime
)
SELECT 
    ShiftDate,
    ShiftID,
    ShiftName,
    MachineId,
    MachineName,
    UnitName,
    BaggingCode,
    ExpectedMinutes,
    ActualMinutes,
    RecordCount,
    -- Completeness Metrics
    ROUND(CAST(ActualMinutes * 100.0 / NULLIF(ExpectedMinutes, 0) AS DECIMAL(5,2)), 2) AS CompletenessPercentage,
    CASE 
        WHEN ActualMinutes = 0 THEN 'MISSING'
        WHEN ActualMinutes >= ExpectedMinutes * 0.95 THEN 'COMPLETE'
        WHEN ActualMinutes >= ExpectedMinutes * 0.80 THEN 'PARTIAL'
        ELSE 'INCOMPLETE'
    END AS CompletenessStatus,
    -- Gap Analysis
    ExpectedMinutes - ActualMinutes AS MissingMinutes,
    -- Time Analysis
    LastUpdated,
    Operators,
    DATEDIFF(MINUTE, LastUpdated, GETDATE()) AS MinutesSinceLastUpdate
FROM ShiftCompleteness;
GO

-- 5.2 ใช้งาน View
-- หาว่ากะเช้าวันนี้ขาดข้อมูลอะไรบ้าง
SELECT 
    MachineName,
    UnitName,
    CompletenessPercentage,
    CompletenessStatus,
    MissingMinutes,
    Operators,
    LastUpdated
FROM vw_ShiftCompleteness
WHERE ShiftDate = CAST(GETDATE() AS DATE)
    AND ShiftID = 1  -- กะเช้า
    AND CompletenessStatus != 'COMPLETE'
ORDER BY MissingMinutes DESC;
```

### **6. Alert System สำหรับข้อมูลไม่ครบ**

```sql
-- 6.1 Stored Procedure สำหรับตรวจสอบและแจ้งเตือน
CREATE PROCEDURE CheckShiftCompleteness
    @ShiftDate DATE = NULL,
    @ShiftID INT = 1,
    @AlertThreshold DECIMAL(5,2) = 80.0  -- ถ้าน้อยกว่า 80% แจ้งเตือน
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ShiftDate IS NULL
        SET @ShiftDate = CAST(GETDATE() AS DATE);
    
    -- หาเครื่องที่ข้อมูลไม่ครบ
    WITH MachineCompleteness AS (
        SELECT 
            m.MachineId,
            m.MachineName,
            u.UnitName,
            s.ShiftName,
            -- Expected
            DATEDIFF(MINUTE, s.StartTime, 
                CASE 
                    WHEN s.EndTime > s.StartTime THEN s.EndTime
                    ELSE DATEADD(HOUR, 24, s.EndTime)
                END) AS ExpectedMinutes,
            -- Actual
            ISNULL(SUM(DATEDIFF(MINUTE, pr.SegmentStartDateTime, pr.SegmentEndDateTime)), 0) AS ActualMinutes,
            -- Operator
            STRING_AGG(DISTINCT pr.EnteredBy, ', ') AS RecordedBy
        FROM Machines m
        INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
        CROSS JOIN Shifts s
        LEFT JOIN ProductionRecords pr ON m.MachineId = pr.MachineId
            AND pr.ShiftDate = @ShiftDate
            AND pr.ShiftID = s.ShiftID
            AND pr.RecordStatus IN ('CLOSED', 'IN_PROGRESS')
        LEFT JOIN MachineStatus ms ON m.MachineId = ms.MachineId 
            AND ms.RecordDate = @ShiftDate
        WHERE s.ShiftID = @ShiftID
            AND m.MachineActive = 1
            AND ISNULL(ms.IsOperational, 1) = 1
        GROUP BY 
            m.MachineId,
            m.MachineName,
            u.UnitName,
            s.ShiftName,
            s.StartTime,
            s.EndTime
    )
    SELECT 
        MachineName,
        UnitName,
        ShiftName,
        ExpectedMinutes,
        ActualMinutes,
        ROUND(CAST(ActualMinutes * 100.0 / NULLIF(ExpectedMinutes, 0) AS DECIMAL(5,2)), 2) AS CompletenessPercentage,
        ExpectedMinutes - ActualMinutes AS MissingMinutes,
        RecordedBy,
        CASE 
            WHEN ActualMinutes = 0 THEN 'ALERT: ไม่มีข้อมูลใดๆ'
            WHEN ActualMinutes < ExpectedMinutes * (@AlertThreshold / 100.0) 
                THEN CONCAT('ALERT: ข้อมูลไม่ครบ (น้อยกว่า ', @AlertThreshold, '%)')
            ELSE 'OK'
        END AS AlertMessage,
        CASE 
            WHEN ActualMinutes = 0 THEN 'CRITICAL'
            WHEN ActualMinutes < ExpectedMinutes * (@AlertThreshold / 100.0) THEN 'WARNING'
            ELSE 'NORMAL'
        END AS AlertLevel
    FROM MachineCompleteness
    WHERE ActualMinutes < ExpectedMinutes * (@AlertThreshold / 100.0)
        OR ActualMinutes = 0
    ORDER BY 
        AlertLevel DESC,
        MissingMinutes DESC;
END
GO

-- 6.2 เรียกใช้งาน
-- ตรวจสอบกะเช้าวันนี้
EXEC CheckShiftCompleteness 
    @ShiftDate = NULL,  -- วันนี้
    @ShiftID = 1,       -- กะเช้า
    @AlertThreshold = 85;  -- แจ้งเตือนถ้าน้อยกว่า 85%
```

## **สรุป Logic ที่ใช้:**

### **Core Logic:**
1. **Expected Data**: หาว่าเครื่องไหนควรทำงาน (MachineActive = 1, IsOperational = 1)
2. **Actual Data**: ดูว่ามีข้อมูล ProductionRecords เท่าไร
3. **Compare**: เปรียบเทียบ Expected vs Actual

### **เงื่อนไขการตรวจสอบ:**
```sql
-- ถ้าไม่มีข้อมูลเลย
WHEN ActualMinutes = 0 THEN '❌ ไม่มีข้อมูล'

-- ถ้ามีข้อมูลแต่ไม่ครบเวลา
WHEN ActualMinutes < ExpectedMinutes * 0.95 THEN '⚠️ ข้อมูลไม่ครบ'

-- ถ้าข้อมูลเกือบครบ
WHEN ActualMinutes >= ExpectedMinutes * 0.95 THEN '✅ ครบถ้วน'
```

### **ปัจจัยที่ต้องพิจารณา:**
1. **Machine Status**: เครื่องเสียหรือไม่ (จาก MachineStatus)
2. **Shift Hours**: กะละกี่ชั่วโมง
3. **Time Coverage**: ข้อมูลครอบคลุมเวลาทั้งกะหรือไม่
4. **Data Gaps**: มีช่วงเวลาที่ขาดหายไปหรือไม่
5. **Operator Assignment**: ใครเป็นผู้บันทึกข้อมูล

## **ตัวอย่างการใช้งานจริง:**

**ตอน 10:00 น. (กลางกะเช้า):**
```sql
-- ตรวจสอบว่าข้อมูลตอนนี้ควรมีประมาณ 4 ชม. (06:00-10:00)
EXEC CheckShiftCompleteness 
    @ShiftDate = '2024-01-15',
    @ShiftID = 1,
    @AlertThreshold = 50;  -- ตอนกลางกะ 50% = 4 ชม.
```

**ตอนสิ้นกะ (14:00 น.):**
```sql
-- ตรวจสอบว่าข้อมูลครบ 8 ชม. หรือไม่
EXEC CheckShiftCompleteness 
    @ShiftDate = '2024-01-15',
    @ShiftID = 1,
    @AlertThreshold = 95;  -- ตอนสิ้นกะ 95% = 7.6 ชม.
```

**ระบบนี้จะช่วยให้ Supervisor รู้ว่า:**
1. เครื่องไหน Operator ยังไม่ได้บันทึกข้อมูล
2. เครื่องไหนบันทึกข้อมูลไม่ครบเวลา
3. ใครเป็นผู้บันทึกข้อมูลแต่ละเครื่อง
4. ข้อมูลอัพเดตล่าสุดเมื่อไร

**เหมาะสำหรับการทำ Daily Check และ Performance Monitoring ครับ!** 🎯