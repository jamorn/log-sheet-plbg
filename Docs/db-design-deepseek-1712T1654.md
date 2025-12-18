
# 1. BAGGING & UNIT STRUCTURE
-- 1.1 Bagging Locations
CREATE TABLE BaggingLocations (
    BaggingCode VARCHAR(10) PRIMARY KEY,
    BaggingName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(500) NULL,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE()
);

-- Initial Data
INSERT INTO BaggingLocations (BaggingCode, BaggingName, Description) VALUES
('PL', 'Bagging PL', 'Bagging PL Location - PolyLine Units'),
('SA', 'Bagging SASB', 'Bagging SASB Location');

-- 1.2 Production Units (UnitPLBG)
CREATE TABLE UnitPLBG (
    UnitId INT PRIMARY KEY,
    UnitName NVARCHAR(50) NOT NULL,
    CostCenterCode VARCHAR(10) NOT NULL,
    BaggingCode VARCHAR(10) NOT NULL,
    IsActive BIT DEFAULT 1,
    
    CONSTRAINT FK_UnitPLBG_Bagging FOREIGN KEY (BaggingCode)
        REFERENCES BaggingLocations(BaggingCode)
);

-- Initial Data (ตามข้อมูลจริง)
INSERT INTO UnitPLBG (UnitId, UnitName, CostCenterCode, BaggingCode) VALUES
(1, 'PP1&2', '10111203', 'PL'),
(2, 'HDPE', '10111202', 'PL'),
(3, 'PP3', '10111204', 'PL'),
(4, 'PPE', '10111205', 'PL'),
(5, 'PPC', '10111206', 'PL'),
(6, 'SASB', '10126300', 'SA');

# 2. MACHINES WITH REAL CONFIGURATION
CREATE TABLE Machines (
    MachineId INT PRIMARY KEY,
    MachineName VARCHAR(10) NOT NULL,
    MachineClass VARCHAR(5) NULL DEFAULT 'g1',
    MachineActive BIT NOT NULL DEFAULT 1,
    MachineLine VARCHAR(1) NULL,
    
    -- Link to Unit (สำคัญ!)
    UnitId INT NOT NULL,
    
    -- OEE Configuration (ตามข้อมูลจริง)
    StandardRPM INT NOT NULL,
    BagWeightKG DECIMAL(5,2) NOT NULL DEFAULT 25.00,
    
    -- Computed Columns for Performance
    IdealCycleTimeSec AS (60.0 / NULLIF(StandardRPM, 0)) PERSISTED,
    IdealOutputPerHour AS (StandardRPM * 60 * BagWeightKG / 1000.0) PERSISTED, -- KG per hour
    
    -- Maintenance Info
    InstallationDate DATE NULL,
    LastMaintenanceDate DATE NULL,
    
    -- Audit
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT FK_Machines_UnitPLBG FOREIGN KEY (UnitId)
        REFERENCES UnitPLBG(UnitId),
    CONSTRAINT CHK_StandardRPM CHECK (StandardRPM > 0),
    CONSTRAINT CHK_BagWeight CHECK (BagWeightKG > 0 AND BagWeightKG <= 50),
    CONSTRAINT UQ_MachineName UNIQUE (MachineName)
);

-- Initial Data (ตามข้อมูลจริง + StandardRPM)
INSERT INTO Machines (MachineId, MachineName, MachineClass, MachineActive, MachineLine, UnitId, StandardRPM) VALUES
-- Unit 1: PP1&2
(1, 'PP12/A', 'g1', 1, 'A', 1, 1800),  -- พิเศษ: 1800 RPM
(2, 'PP12/C', 'g1', 1, 'C', 1, 1200),  -- ปกติ: 1200 RPM

-- Unit 2: HDPE  
(9, 'HDPE/A', 'g1', 1, 'A', 2, 1200),

-- Unit 3: PP3
(3, 'PP3/A', 'g1', 1, 'A', 3, 1200),
(4, 'PP3/B', 'g1', 1, 'B', 3, 1200),

-- Unit 4: PPE
(5, 'PPE/C', 'g1', 1, 'C', 4, 1200),
(6, 'PPE/D', 'g1', 1, 'D', 4, 1200),

-- Unit 5: PPC
(7, 'PPC/A', 'g1', 1, 'A', 5, 1200),
(8, 'PPC/B', 'g1', 1, 'B', 5, 1200);

-- Note: Unit 6 (SASB) ยังไม่มีเครื่อง (เตรียมไว้สำหรับอนาคต)
# 3. KPI TARGETS (ตามข้อมูลจริงทั้งหมด)
CREATE TABLE KpiTargets (
    TargetId INT IDENTITY(1,1) PRIMARY KEY,  -- Auto-increment แทน Item
    [Year] INT NOT NULL,
    UnitId INT NOT NULL,
    
    -- OEE Target (หลัก)
    Oee_Target DECIMAL(5, 2) NOT NULL,
    
    -- Additional KPI Targets (สำหรับ dashboard)
    Waste_Pellet_Target DECIMAL(5,3) NULL,    -- 0.025
    Waste_Film_Target DECIMAL(5,3) NULL,      -- 0.005
    GiveAway_Target DECIMAL(6,3) NULL,        -- 25.1
    GiveAwayMin DECIMAL(6,3) NULL,            -- 25.1
    GiveAwayMax DECIMAL(6,3) NULL,            -- 25.115
    
    -- Audit
    CreatedAt DATETIME DEFAULT GETDATE(),
    CreatedBy NVARCHAR(128) NULL,
    
    -- Constraints
    CONSTRAINT FK_KpiTargets_UnitPLBG FOREIGN KEY (UnitId)
        REFERENCES UnitPLBG(UnitId),
    CONSTRAINT UQ_YearUnit UNIQUE ([Year], UnitId),  -- ห้ามซ้ำปี+unit
    CONSTRAINT CHK_OeeTarget_Range CHECK (Oee_Target >= 0 AND Oee_Target <= 100)
);

-- Initial Data (แปลงจาก JSON)
INSERT INTO KpiTargets ([Year], UnitId, Oee_Target, Waste_Pellet_Target, Waste_Film_Target, GiveAway_Target, GiveAwayMin, GiveAwayMax) VALUES
-- 2024 Targets
(2024, 1, 88.87, 0.025, 0.005, 25.100, 25.100, 25.115),
(2024, 2, 90.17, 0.005, 0.590, 25.160, 25.100, 25.115),
(2024, 5, 92.53, 0.005, 0.250, 25.160, 25.100, 25.115),
(2024, 4, 89.10, 0.006, 0.250, 25.160, 25.100, 25.115),
(2024, 3, 89.68, 0.006, 0.250, 25.160, 25.100, 25.115),
(2024, 6, 92.69, 0.008, 0.590, 25.170, 25.100, 25.115),

-- 2025 Targets
(2025, 1, 88.87, 0.025, 0.005, 25.115, 25.100, 25.115),
(2025, 2, 90.17, 0.005, 0.590, 25.115, 25.100, 25.115),
(2025, 5, 92.53, 0.005, 0.250, 25.115, 25.100, 25.115),
(2025, 4, 89.10, 0.006, 0.250, 25.115, 25.100, 25.115),
(2025, 3, 89.68, 0.006, 0.250, 25.115, 25.100, 25.115),
(2025, 6, 92.69, 0.008, 0.590, 25.175, 25.100, 25.115);

# 4. MACHINE STATUS (สำหรับแจ้งสถานะเครื่อง)
CREATE TABLE MachineStatus (
    StatusId INT IDENTITY(1,1) PRIMARY KEY,
    MachineId INT NOT NULL,
    RecordDate DATE NOT NULL,  -- วันที่สถานะนี้มีผล
    StatusTime TIME NULL DEFAULT CAST(GETDATE() AS TIME),  -- เวลาที่บันทึก
    
    -- Status Information
    IsOperational BIT NOT NULL DEFAULT 1,  -- 1=ปกติ, 0=เสีย/หยุด
    StatusType VARCHAR(20) DEFAULT 'OPERATIONAL'  -- OPERATIONAL, BREAKDOWN, MAINTENANCE, PLANNED_STOP
        CHECK (StatusType IN ('OPERATIONAL', 'BREAKDOWN', 'MAINTENANCE', 'PLANNED_STOP', 'OTHER')),
    StatusNote NVARCHAR(500) NULL,
    
    -- Expected Duration (ถ้ารู้)
    ExpectedRestoreTime DATETIME NULL,
    
    -- Personnel
    ReportedBy NVARCHAR(128) NULL,
    AcknowledgedBy NVARCHAR(128) NULL,
    
    -- Audit
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),
    
    -- Foreign Keys
    CONSTRAINT FK_MachineStatus_Machine FOREIGN KEY (MachineId)
        REFERENCES Machines(MachineId),
    CONSTRAINT FK_MachineStatus_ReportedBy FOREIGN KEY (ReportedBy)
        REFERENCES EmployeeDetails(WindowsLogin),
    CONSTRAINT FK_MachineStatus_AcknowledgedBy FOREIGN KEY (AcknowledgedBy)
        REFERENCES EmployeeDetails(WindowsLogin),
    
    -- Unique Constraint (หนึ่งเครื่องต่อวัน)
    CONSTRAINT UQ_MachineDate UNIQUE (MachineId, RecordDate)
);

-- Index for quick lookup
CREATE INDEX IX_MachineStatus_Date_Operational 
ON MachineStatus(RecordDate, IsOperational, MachineId);

# 5. FUNCTION สำหรับหา KPI Target (ตาม logic ที่ต้องการ)
CREATE FUNCTION dbo.GetKpiTargetForUnit (@UnitId INT, @ForDate DATE)
RETURNS @Result TABLE (
    Oee_Target DECIMAL(5,2),
    Waste_Pellet_Target DECIMAL(5,3),
    Waste_Film_Target DECIMAL(5,3),
    GiveAway_Target DECIMAL(6,3),
    GiveAwayMin DECIMAL(6,3),
    GiveAwayMax DECIMAL(6,3),
    TargetYear INT
)
AS
BEGIN
    DECLARE @TargetYear INT = YEAR(@ForDate);
    DECLARE @FoundTarget BIT = 0;
    
    -- 1. ลองหาปีที่ตรงกัน
    INSERT INTO @Result
    SELECT TOP 1 
        Oee_Target,
        Waste_Pellet_Target,
        Waste_Film_Target,
        GiveAway_Target,
        GiveAwayMin,
        GiveAwayMax,
        [Year] AS TargetYear
    FROM KpiTargets
    WHERE UnitId = @UnitId AND [Year] = @TargetYear;
    
    SET @FoundTarget = @@ROWCOUNT;
    
    -- 2. ถ้าไม่เจอปีนั้น ให้ใช้ปีล่าสุดที่มี
    IF @FoundTarget = 0
    BEGIN
        INSERT INTO @Result
        SELECT TOP 1 
            Oee_Target,
            Waste_Pellet_Target,
            Waste_Film_Target,
            GiveAway_Target,
            GiveAwayMin,
            GiveAwayMax,
            [Year] AS TargetYear
        FROM KpiTargets
        WHERE UnitId = @UnitId AND [Year] < @TargetYear
        ORDER BY [Year] DESC;
        
        SET @FoundTarget = @@ROWCOUNT;
    END
    
    -- 3. ถ้ายังไม่มีเลย (unit ใหม่) ใช้ default values
    IF @FoundTarget = 0
    BEGIN
        INSERT INTO @Result VALUES (
            85.00,  -- Default OEE
            0.010,  -- Default Waste Pellet
            0.100,  -- Default Waste Film
            25.000, -- Default Giveaway
            24.900, -- Default Min
            25.100, -- Default Max
            @TargetYear
        );
    END
    
    RETURN;
END
GO

----------------------- view ------------------------
6. VIEW สำหรับ Dashboard (รวม KPI Targets)
CREATE VIEW vw_MachineDashboard AS
SELECT 
    m.MachineId,
    m.MachineName,
    m.MachineLine,
    m.StandardRPM,
    m.BagWeightKG,
    
    -- Unit Information
    u.UnitId,
    u.UnitName,
    u.CostCenterCode,
    u.BaggingCode,
    bl.BaggingName,
    
    -- Current Status (ล่าสุด)
    ms.IsOperational,
    ms.StatusType,
    ms.StatusNote,
    ms.RecordDate AS LastStatusDate,
    
    -- Current KPI Targets (ของปีนี้)
    kt.Oee_Target,
    kt.Waste_Pellet_Target,
    kt.Waste_Film_Target,
    kt.GiveAway_Target,
    kt.GiveAwayMin,
    kt.GiveAwayMax,
    kt.[Year] AS TargetYear,
    
    -- Computed Fields
    CASE 
        WHEN m.StandardRPM = 1800 THEN 'HIGH_SPEED'
        WHEN m.StandardRPM = 1200 THEN 'STANDARD'
        ELSE 'OTHER'
    END AS SpeedCategory,
    
    -- Bagging Info
    CASE u.BaggingCode
        WHEN 'PL' THEN 'PolyLine Production'
        WHEN 'SA' THEN 'SASB Production'
        ELSE 'Other'
    END AS ProductionLine
    
FROM Machines m
INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
INNER JOIN BaggingLocations bl ON u.BaggingCode = bl.BaggingCode
LEFT JOIN (
    -- Latest Machine Status
    SELECT ms1.*
    FROM MachineStatus ms1
    INNER JOIN (
        SELECT MachineId, MAX(RecordDate) AS MaxDate
        FROM MachineStatus
        GROUP BY MachineId
    ) ms2 ON ms1.MachineId = ms2.MachineId AND ms1.RecordDate = ms2.MaxDate
) ms ON m.MachineId = ms.MachineId
OUTER APPLY dbo.GetKpiTargetForUnit(u.UnitId, GETDATE()) kt;

# 7. STORED PROCEDURE สำหรับ Daily OEE Calculation (ปรับปรุงใหม่)
CREATE PROCEDURE CalculateDailyOeeSummary
    @ShiftDate DATE,
    @MachineId INT,
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    DECLARE @TransactionName VARCHAR(32) = 'CalculateDailyOeeSummary';
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @CalculationId BIGINT;
    
    BEGIN TRY
        -- ============================================
        -- 1. VALIDATION AND INITIALIZATION
        -- ============================================
        IF @MachineId IS NULL OR @ShiftDate IS NULL
        BEGIN
            RAISERROR('Invalid parameters: MachineId and ShiftDate are required', 16, 1);
            RETURN;
        END
        
        -- Log calculation start
        INSERT INTO CalculationLogs (
            CalculationDate, MachineId, ShiftDate, 
            CalculationType, CalculationStatus
        ) VALUES (
            GETDATE(), @MachineId, @ShiftDate,
            'DAILY', 'IN_PROGRESS'
        );
        
        SET @CalculationId = SCOPE_IDENTITY();
        
        -- ============================================
        -- 2. GET MACHINE CONFIGURATION
        -- ============================================
        DECLARE @UnitId INT;
        DECLARE @StandardRPM INT;
        DECLARE @BagWeightKG DECIMAL(5,2);
        DECLARE @MachineName VARCHAR(10);
        DECLARE @MachineLine VARCHAR(1);
        
        SELECT 
            @UnitId = m.UnitId,
            @StandardRPM = m.StandardRPM,
            @BagWeightKG = m.BagWeightKG,
            @MachineName = m.MachineName,
            @MachineLine = m.MachineLine
        FROM Machines m
        WHERE m.MachineId = @MachineId;
        
        IF @UnitId IS NULL
        BEGIN
            UPDATE CalculationLogs 
            SET CalculationStatus = 'ERROR',
                ErrorMessage = 'Machine configuration not found'
            WHERE LogId = @CalculationId;
            
            RAISERROR('Machine configuration not found for MachineId: %d', 16, 1, @MachineId);
            RETURN;
        END
        
        -- ============================================
        -- 3. GET KPI TARGET FOR THIS DATE
        -- ============================================
        DECLARE @OeeTarget DECIMAL(5,2);
        DECLARE @WastePelletTarget DECIMAL(5,3);
        DECLARE @WasteFilmTarget DECIMAL(5,3);
        DECLARE @GiveAwayTarget DECIMAL(6,3);
        DECLARE @GiveAwayMin DECIMAL(6,3);
        DECLARE @GiveAwayMax DECIMAL(6,3);
        DECLARE @TargetYear INT;
        
        SELECT 
            @OeeTarget = Oee_Target,
            @WastePelletTarget = Waste_Pellet_Target,
            @WasteFilmTarget = Waste_Film_Target,
            @GiveAwayTarget = GiveAway_Target,
            @GiveAwayMin = GiveAwayMin,
            @GiveAwayMax = GiveAwayMax,
            @TargetYear = TargetYear
        FROM dbo.GetKpiTargetForUnit(@UnitId, @ShiftDate);
        
        -- ============================================
        -- 4. CHECK MACHINE STATUS
        -- ============================================
        DECLARE @IsOperational BIT = 1;
        DECLARE @StatusNote NVARCHAR(500);
        
        SELECT 
            @IsOperational = IsOperational,
            @StatusNote = StatusNote
        FROM MachineStatus
        WHERE MachineId = @MachineId 
          AND RecordDate = @ShiftDate;
        
        -- ถ้าเครื่องเสียทั้งวัน ให้ OEE = 0
        IF @IsOperational = 0
        BEGIN
            -- Calculate minimal data for logging
            DECLARE @TotalTimeMin INT = 480; -- Assume 8 hours shift
            DECLARE @ActualOutputMT DECIMAL(10,3) = 0;
            DECLARE @GoodBags INT = 0;
            DECLARE @WasteBags INT = 0;
            
            -- Insert/Update with zero OEE
            MERGE DailyProductionSummary AS target
            USING (SELECT @ShiftDate, @MachineId) AS source (ShiftDate, MachineId)
            ON target.ShiftDate = source.ShiftDate AND target.MachineID = source.MachineId
            WHEN MATCHED THEN
                UPDATE SET 
                    UnitId = @UnitId,
                    Target_OEE_Pct = @OeeTarget,
                    Availability_Pct = 0,
                    Performance_Pct = 0,
                    Quality_Pct = 0,
                    OEE_Percentage = 0,
                    OEE_TargetMet = 0,
                    TotalTimeMin = @TotalTimeMin,
                    PlannedProductionTimeMin = @TotalTimeMin,
                    OperatingTimeMin = 0,
                    PlannedLossMin = @TotalTimeMin, -- All time is planned loss
                    UnplannedLossMin = 0,
                    SpeedLossMin = 0,
                    ActualOutputMT = 0,
                    IdealOutputMT = 0,
                    GoodBags = 0,
                    WasteBags = 0,
                    Top_Downtime_Reason = ISNULL(@StatusNote, 'Machine Not Operational'),
                    TotalDowntimeEvents = 0,
                    LastCalculated = GETDATE(),
                    DataStatus = 'CALCULATED'
            WHEN NOT MATCHED THEN
                INSERT (
                    ShiftDate, MachineID, UnitId, Target_OEE_Pct,
                    Availability_Pct, Performance_Pct, Quality_Pct,
                    OEE_Percentage, OEE_TargetMet,
                    TotalTimeMin, PlannedProductionTimeMin, OperatingTimeMin,
                    PlannedLossMin, UnplannedLossMin, SpeedLossMin,
                    ActualOutputMT, IdealOutputMT, GoodBags, WasteBags,
                    Top_Downtime_Reason, TotalDowntimeEvents,
                    LastCalculated, DataStatus
                ) VALUES (
                    @ShiftDate, @MachineId, @UnitId, @OeeTarget,
                    0, 0, 0, 0, 0,
                    @TotalTimeMin, @TotalTimeMin, 0,
                    @TotalTimeMin, 0, 0,
                    0, 0, 0, 0,
                    ISNULL(@StatusNote, 'Machine Not Operational'), 0,
                    GETDATE(), 'CALCULATED'
                );
            
            -- Log calculation
            UPDATE CalculationLogs 
            SET 
                TotalTimeMin = @TotalTimeMin,
                PlannedLossMin = @TotalTimeMin,
                UnplannedLossMin = 0,
                ActualOutputMT = 0,
                GoodBags = 0,
                WasteBags = 0,
                Availability = 0,
                Performance = 0,
                Quality = 0,
                OEE = 0,
                TargetOEE = @OeeTarget,
                TopDowntimeReason = ISNULL(@StatusNote, 'Machine Not Operational'),
                CalculationStatus = 'SUCCESS',
                CalculationDurationMs = DATEDIFF(MILLISECOND, @StartTime, GETDATE()),
                RecordsProcessed = 0,
                WarningMessage = 'Machine was not operational on this date'
            WHERE LogId = @CalculationId;
            
            RETURN;
        END
        
        -- ============================================
        -- 5. CALCULATE OEE USING CTE (OPTIMIZED)
        -- ============================================
        -- 5.1 Production Data CTE
        WITH ProductionCTE AS (
            SELECT 
                PR.ProductionRecordID,
                PR.SegmentStartDateTime,
                PR.SegmentEndDateTime,
                PR.BagOutActualMT,
                DATEDIFF(MINUTE, PR.SegmentStartDateTime, PR.SegmentEndDateTime) AS SegmentMinutes
            FROM ProductionRecords PR
            WHERE PR.MachineId = @MachineId 
              AND PR.ShiftDate = @ShiftDate
              AND PR.RecordStatus = 'CLOSED'
        ),
        -- 5.2 Problem Data CTE
        ProblemCTE AS (
            SELECT 
                PRB.ProductionRecordID,
                PRB.ProblemTypeID,
                PRB.StopDateTime,
                PRB.StartDateTime,
                DATEDIFF(MINUTE, PRB.StopDateTime, PRB.StartDateTime) AS DowntimeMinutes,
                OLT.CategoryID,
                OLT.TypeNameTH,
                DC.OeeFactor
            FROM ProblemRecords PRB
            INNER JOIN ProductionCTE PC ON PRB.ProductionRecordID = PC.ProductionRecordID
            INNER JOIN OeeLossTypes OLT ON PRB.ProblemTypeID = OLT.ProblemTypeID
            INNER JOIN DowntimeCategories DC ON OLT.CategoryID = DC.CategoryID
            WHERE OLT.IsActive = 1
        ),
        -- 5.3 Quality Data CTE
        QualityCTE AS (
            SELECT 
                LCD.ProductionRecordID,
                ISNULL(LCD.TotalBags, 0) AS TotalBags,
                ISNULL(LCD.GoodBags, 0) AS GoodBags,
                ISNULL(LCD.WasteRejectBags, 0) AS WasteBags,
                ISNULL(LCD.WasteRejectKG, 0) AS WasteKG
            FROM ProductionCTE PC
            LEFT JOIN LotCompletionDetails LCD ON PC.ProductionRecordID = LCD.ProductionRecordID
        ),
        -- 5.4 Aggregate Data
        AggregatedData AS (
            SELECT 
                -- Time Totals
                SUM(PC.SegmentMinutes) AS TotalTimeMin,
                SUM(PC.BagOutActualMT) AS ActualOutputMT,
                
                -- Downtime by Category
                SUM(CASE WHEN PC.OeeFactor = 'A' AND DC.CategoryLevel = 10 THEN PC.DowntimeMinutes ELSE 0 END) AS PlannedLossMin,
                SUM(CASE WHEN PC.OeeFactor = 'A' AND DC.CategoryLevel = 20 THEN PC.DowntimeMinutes ELSE 0 END) AS UnplannedLossMin,
                SUM(CASE WHEN PC.OeeFactor = 'P' THEN PC.DowntimeMinutes ELSE 0 END) AS SpeedLossMin,
                
                -- Quality Data
                SUM(QC.TotalBags) AS TotalBags,
                SUM(QC.GoodBags) AS GoodBags,
                SUM(QC.WasteBags) AS WasteBags,
                SUM(QC.WasteKG) AS WasteKG,
                
                -- Top Downtime Reason
                (SELECT TOP 1 TypeNameTH FROM ProblemCTE 
                 WHERE OeeFactor = 'A' 
                 ORDER BY DowntimeMinutes DESC) AS TopDowntimeReason,
                 
                -- Downtime Events Count
                COUNT(DISTINCT CASE WHEN PC.OeeFactor = 'A' THEN PRB.ProblemRecordID END) AS DowntimeEvents
            FROM ProductionCTE PC
            LEFT JOIN ProblemCTE PRB ON PC.ProductionRecordID = PRB.ProductionRecordID
            LEFT JOIN DowntimeCategories DC ON PRB.CategoryID = DC.CategoryID
            LEFT JOIN QualityCTE QC ON PC.ProductionRecordID = QC.ProductionRecordID
        )
        
        -- 5.5 Get Aggregated Values
        SELECT 
            @TotalTimeMin = TotalTimeMin,
            @ActualOutputMT = ActualOutputMT,
            @PlannedLossMin = PlannedLossMin,
            @UnplannedLossMin = UnplannedLossMin,
            @SpeedLossMin = SpeedLossMin,
            @GoodBags = GoodBags,
            @WasteBags = WasteBags,
            @TopDowntimeReason = TopDowntimeReason,
            @DowntimeEvents = DowntimeEvents
        FROM AggregatedData;
        
        -- Set defaults for NULL values
        SET @TotalTimeMin = ISNULL(@TotalTimeMin, 480); -- Default 8 hours
        SET @ActualOutputMT = ISNULL(@ActualOutputMT, 0);
        SET @PlannedLossMin = ISNULL(@PlannedLossMin, 0);
        SET @UnplannedLossMin = ISNULL(@UnplannedLossMin, 0);
        SET @SpeedLossMin = ISNULL(@SpeedLossMin, 0);
        SET @GoodBags = ISNULL(@GoodBags, 0);
        SET @WasteBags = ISNULL(@WasteBags, 0);
        SET @TopDowntimeReason = ISNULL(@TopDowntimeReason, N'ไม่มีเวลาหยุดเครื่องบันทึก');
        SET @DowntimeEvents = ISNULL(@DowntimeEvents, 0);
        
        -- ============================================
        -- 6. OEE CALCULATION
        -- ============================================
        DECLARE @Availability DECIMAL(5,2);
        DECLARE @Performance DECIMAL(5,2);
        DECLARE @Quality DECIMAL(5,2);
        DECLARE @OEE_Final DECIMAL(5,2);
        DECLARE @OEE_TargetMet BIT;
        
        DECLARE @PlannedProductionTime DECIMAL(10,2);
        DECLARE @OperatingTime DECIMAL(10,2);
        DECLARE @IdealProductionTime DECIMAL(10,2);
        DECLARE @IdealOutputPerMin DECIMAL(10,4);
        DECLARE @TotalBags DECIMAL(10,2);
        
        -- Calculate Ideal Output per Minute
        SET @IdealOutputPerMin = (@StandardRPM * 60 * @BagWeightKG) / 1000000.0; -- MT per minute
        
        -- Availability Calculation
        SET @PlannedProductionTime = @TotalTimeMin - @PlannedLossMin;
        SET @OperatingTime = @PlannedProductionTime - @UnplannedLossMin;
        
        SET @Availability = CASE 
            WHEN @PlannedProductionTime > 0 
            THEN ROUND((@OperatingTime / @PlannedProductionTime) * 100.0, 2)
            ELSE 0.0 
        END;
        
        -- Performance Calculation (รวม Speed Loss)
        SET @IdealProductionTime = CASE 
            WHEN @IdealOutputPerMin > 0 
            THEN @ActualOutputMT / @IdealOutputPerMin 
            ELSE 0 
        END;
        
        DECLARE @NetOperatingTime DECIMAL(10,2) = @OperatingTime - @SpeedLossMin;
        
        SET @Performance = CASE 
            WHEN @NetOperatingTime > 0 
            THEN ROUND((@IdealProductionTime / @NetOperatingTime) * 100.0, 2)
            ELSE 0.0 
        END;
        
        -- Quality Calculation
        SET @TotalBags = @GoodBags + @WasteBags;
        SET @Quality = CASE 
            WHEN @TotalBags > 0 
            THEN ROUND((@GoodBags / @TotalBags) * 100.0, 2)
            ELSE 0.0 
        END;
        
        -- Overall OEE
        SET @OEE_Final = ROUND((@Availability * @Performance * @Quality) / 10000.0, 2);
        
        -- Check if target met
        SET @OEE_TargetMet = CASE WHEN @OEE_Final >= @OeeTarget THEN 1 ELSE 0 END;
        
        -- Calculate Ideal Output (for reporting)
        DECLARE @IdealOutputMT DECIMAL(10,3);
        SET @IdealOutputMT = @IdealOutputPerMin * @NetOperatingTime;
        
        -- ============================================
        -- 7. DEBUG OUTPUT (OPTIONAL)
        -- ============================================
        IF @DebugMode = 1
        BEGIN
            SELECT 
                'DEBUG INFO' AS InfoType,
                @MachineId AS MachineId,
                @MachineName AS MachineName,
                @ShiftDate AS ShiftDate,
                @TotalTimeMin AS TotalTimeMin,
                @PlannedLossMin AS PlannedLossMin,
                @UnplannedLossMin AS UnplannedLossMin,
                @SpeedLossMin AS SpeedLossMin,
                @PlannedProductionTime AS PlannedProductionTime,
                @OperatingTime AS OperatingTime,
                @NetOperatingTime AS NetOperatingTime,
                @ActualOutputMT AS ActualOutputMT,
                @IdealOutputMT AS IdealOutputMT,
                @GoodBags AS GoodBags,
                @WasteBags AS WasteBags,
                @Availability AS Availability,
                @Performance AS Performance,
                @Quality AS Quality,
                @OEE_Final AS OEE,
                @OeeTarget AS TargetOEE,
                @OEE_TargetMet AS TargetMet,
                @TopDowntimeReason AS TopDowntimeReason;
        END
        
        -- ============================================
        -- 8. SAVE/UPDATE DAILY SUMMARY
        -- ============================================
        BEGIN TRANSACTION @TransactionName;
        
        IF EXISTS (SELECT 1 FROM DailyProductionSummary 
                  WHERE ShiftDate = @ShiftDate AND MachineID = @MachineId)
        BEGIN
            -- Update existing record
            UPDATE DailyProductionSummary
            SET
                UnitId = @UnitId,
                Target_OEE_Pct = @OeeTarget,
                Availability_Pct = @Availability,
                Performance_Pct = @Performance,
                Quality_Pct = @Quality,
                OEE_Percentage = @OEE_Final,
                OEE_TargetMet = @OEE_TargetMet,
                
                -- Time Analysis
                TotalTimeMin = @TotalTimeMin,
                PlannedProductionTimeMin = @PlannedProductionTime,
                OperatingTimeMin = @OperatingTime,
                PlannedLossMin = @PlannedLossMin,
                UnplannedLossMin = @UnplannedLossMin,
                SpeedLossMin = @SpeedLossMin,
                
                -- Production Output
                ActualOutputMT = @ActualOutputMT,
                IdealOutputMT = @IdealOutputMT,
                GoodBags = @GoodBags,
                WasteBags = @WasteBags,
                
                -- Downtime Analysis
                Top_Downtime_Reason = @TopDowntimeReason,
                TotalDowntimeEvents = @DowntimeEvents,
                
                -- Metadata
                LastCalculated = GETDATE(),
                CalculationVersion = '2.0',
                DataStatus = 'CALCULATED'
            WHERE ShiftDate = @ShiftDate AND MachineID = @MachineId;
        END
        ELSE
        BEGIN
            -- Insert new record
            INSERT INTO DailyProductionSummary (
                ShiftDate, MachineID, UnitId,
                Target_OEE_Pct, Availability_Pct, Performance_Pct, Quality_Pct,
                OEE_Percentage, OEE_TargetMet,
                TotalTimeMin, PlannedProductionTimeMin, OperatingTimeMin,
                PlannedLossMin, UnplannedLossMin, SpeedLossMin,
                ActualOutputMT, IdealOutputMT, GoodBags, WasteBags,
                Top_Downtime_Reason, TotalDowntimeEvents,
                LastCalculated, CalculationVersion, DataStatus
            )
            VALUES (
                @ShiftDate, @MachineId, @UnitId,
                @OeeTarget, @Availability, @Performance, @Quality,
                @OEE_Final, @OEE_TargetMet,
                @TotalTimeMin, @PlannedProductionTime, @OperatingTime,
                @PlannedLossMin, @UnplannedLossMin, @SpeedLossMin,
                @ActualOutputMT, @IdealOutputMT, @GoodBags, @WasteBags,
                @TopDowntimeReason, @DowntimeEvents,
                GETDATE(), '2.0', 'CALCULATED'
            );
        END
        
        COMMIT TRANSACTION @TransactionName;
        
        -- ============================================
        -- 9. LOG SUCCESS
        -- ============================================
        UPDATE CalculationLogs 
        SET 
            TotalTimeMin = @TotalTimeMin,
            PlannedLossMin = @PlannedLossMin,
            UnplannedLossMin = @UnplannedLossMin,
            SpeedLossMin = @SpeedLossMin,
            ActualOutputMT = @ActualOutputMT,
            GoodBags = @GoodBags,
            WasteBags = @WasteBags,
            Availability = @Availability,
            Performance = @Performance,
            Quality = @Quality,
            OEE = @OEE_Final,
            TargetOEE = @OeeTarget,
            TopDowntimeReason = @TopDowntimeReason,
            CalculationStatus = 'SUCCESS',
            CalculationDurationMs = DATEDIFF(MILLISECOND, @StartTime, GETDATE()),
            RecordsProcessed = (
                SELECT COUNT(*) FROM ProductionRecords 
                WHERE MachineId = @MachineId AND ShiftDate = @ShiftDate
            )
        WHERE LogId = @CalculationId;
        
        -- ============================================
        -- 10. RETURN SUCCESS
        -- ============================================
        SELECT 
            'SUCCESS' AS Status,
            @MachineId AS MachineId,
            @MachineName AS MachineName,
            @ShiftDate AS ShiftDate,
            @Availability AS Availability,
            @Performance AS Performance,
            @Quality AS Quality,
            @OEE_Final AS OEE,
            @OeeTarget AS TargetOEE,
            @OEE_TargetMet AS TargetMet,
            @TopDowntimeReason AS TopDowntimeReason;
        
    END TRY
    BEGIN CATCH
        -- ============================================
        -- ERROR HANDLING
        -- ============================================
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION @TransactionName;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Log Error
        UPDATE CalculationLogs 
        SET 
            CalculationStatus = 'ERROR',
            ErrorMessage = @ErrorMessage,
            CalculationDurationMs = DATEDIFF(MILLISECOND, @StartTime, GETDATE())
        WHERE LogId = @CalculationId;
        
        -- Re-throw for calling application
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO