-- ***************************************************************
-- 1. ตาราง Master และ Lookup
-- ***************************************************************

-- ตาราง Machines
CREATE TABLE [dbo].[Machines] (
    [MachineID] INT PRIMARY KEY,
    [MachineName] VARCHAR(10) UNIQUE NOT NULL,
    [MachineLine] VARCHAR(1),
    [CostCenterCode] VARCHAR(10),
    [MachineActive] BIT NOT NULL DEFAULT 1
);

-- ตาราง Shifts
CREATE TABLE [dbo].[Shifts] (
    [ShiftID] INT PRIMARY KEY,
    [ShiftCode] VARCHAR(1) UNIQUE NOT NULL,
    [ShiftTimeStart] TIME NOT NULL,
    [ShiftTimeEnd] TIME NOT NULL
);

-- ตาราง EmployeeDetails
CREATE TABLE [dbo].[EmployeeDetails] (
    [EmpId] VARCHAR(10) PRIMARY KEY,
    [FullNameTH] NVARCHAR(100) NOT NULL,
    [FullNameEN] VARCHAR(100),
    [Email] VARCHAR(100),
    [ThPosition] NVARCHAR(100),
    [EnPosition] VARCHAR(100),
    [Role] VARCHAR(50)
);

-- ตาราง OrderStatusLookup
CREATE TABLE [dbo].[OrderStatusLookup] (
    [StatusID] INT PRIMARY KEY,
    [StatusNameTH] NVARCHAR(50) NOT NULL,
    [IsComplete] BIT NOT NULL
);

-- ตาราง ProblemTypes (ใช้สำหรับ Downtime/กิจกรรมหลัก)
-- *หมายเหตุ: หากต้องการใช้ DowntimeCategories ที่มี Parent/Child ต้องปรับตารางนี้ หรือใช้ร่วมกัน*
CREATE TABLE [dbo].[ProblemTypes] (
    [ProblemTypeID] INT PRIMARY KEY,
    [TypeNameTH] NVARCHAR(50) NOT NULL,
    [IsDowntime] BIT NOT NULL
);

-- ตาราง DowntimeCategories (ใหม่: สำหรับการวิเคราะห์ปัญหาแบบ Multi-Level)
CREATE TABLE [dbo].[DowntimeCategories] (
    [CategoryID] INT PRIMARY KEY,
    [ParentCategoryID] INT NULL,
    [CategoryNameTH] NVARCHAR(100) NOT NULL,
    [CategoryLevel] INT NOT NULL, -- 1: Major, 2: Sub, 3: Detail
    [IsActive] BIT DEFAULT 1,
    
    CONSTRAINT [FK_DowntimeCategories_Parent] FOREIGN KEY ([ParentCategoryID]) 
        REFERENCES [dbo].[DowntimeCategories]([CategoryID])
);


-- ***************************************************************
-- 2. ตาราง Transaction หลัก
-- ***************************************************************

-- ตาราง ProductionOrders (ปรับปรุง: เพิ่มข้อมูลการวางแผน)
CREATE TABLE [dbo].[ProductionOrders] (
    [LotNo] VARCHAR(20) PRIMARY KEY,
    [OrderDate] DATE,
    [PlannedQuantityMT] DECIMAL(10, 3),
    [CurrentStatusID] INT NOT NULL,
    [ActualCompletionDate] DATETIME NULL,
    
    -- ข้อมูลการวางแผนและ Audit
    [ProductCode] VARCHAR(20),
    [CustomerCode] VARCHAR(20),
    [PlannedStartDate] DATE,
    [PlannedEndDate] DATE,
    [Priority] INT DEFAULT 5,
    [CreatedBy] VARCHAR(10),
    [CreatedDate] DATETIME DEFAULT GETDATE(),
    [LastModifiedBy] VARCHAR(10),
    [LastModifiedDate] DATETIME,
    
    CONSTRAINT [FK_ProductionOrders_Status] FOREIGN KEY ([CurrentStatusID]) REFERENCES [dbo].[OrderStatusLookup]([StatusID]),
    CONSTRAINT [FK_ProductionOrders_CreatedBy] FOREIGN KEY ([CreatedBy]) REFERENCES [dbo].[EmployeeDetails]([EmpId]),
    CONSTRAINT [FK_ProductionOrders_ModifiedBy] FOREIGN KEY ([LastModifiedBy]) REFERENCES [dbo].[EmployeeDetails]([EmpId])
);

-- ตาราง ProductionRecords (ปรับปรุง: เพิ่ม Computed Columns)
CREATE TABLE [dbo].[ProductionRecords] (
    [ProductionRecordID] INT PRIMARY KEY IDENTITY(1,1),
    [LotNo] VARCHAR(20) NOT NULL,
    [SegmentSequence] INT NOT NULL,
    [MachineID] INT NOT NULL,
    [ShiftDate] DATE NOT NULL,
    [ShiftID] INT NOT NULL,
    
    [BagOutActualMT] DECIMAL(10, 3),
    [TransferToWHAggregateMT] DECIMAL(10, 3),
    [DepositedInBaggingMT] DECIMAL(10, 3),
    
    [SegmentStartDateTime] DATETIME NOT NULL,
    [SegmentEndDateTime] DATETIME NULL,
    [IsCompleted] BIT NOT NULL DEFAULT 0,

    -- Computed Columns (ต้องใช้ฟังก์ชัน/Logic ภายนอกในการคำนวณ Availability/Quality)
    -- *เนื่องจาก Computed Column ใน SQL ไม่สามารถใช้ Subquery ได้โดยตรง จึงต้องคำนวณใน Application/View*
    [SegmentDurationMin] AS DATEDIFF(MINUTE, SegmentStartDateTime, ISNULL(SegmentEndDateTime, GETDATE())) PERSISTED,
    
    CONSTRAINT [UQ_ProductionRecords_LotSegment] UNIQUE ([LotNo], [SegmentSequence]),
    CONSTRAINT [FK_PR_LotNo] FOREIGN KEY ([LotNo]) REFERENCES [dbo].[ProductionOrders]([LotNo]),
    CONSTRAINT [FK_PR_Machine] FOREIGN KEY ([MachineID]) REFERENCES [dbo].[Machines]([MachineID]),
    CONSTRAINT [FK_PR_Shift] FOREIGN KEY ([ShiftID]) REFERENCES [dbo].[Shifts]([ShiftID]),
    CONSTRAINT [CHK_ProductionRecords_Positive] CHECK ([BagOutActualMT] >= 0 AND [TransferToWHAggregateMT] >= 0)
);

-- ตาราง LotCompletionDetails
CREATE TABLE [dbo].[LotCompletionDetails] (
    [ProductionRecordID] INT PRIMARY KEY,
    [PCCQCKG] DECIMAL(10, 2),
    [MetalDetectionLossKG] DECIMAL(10, 2),
    [TailBag1KG] DECIMAL(10, 2),
    [TailBag2KG] DECIMAL(10, 2),
    [Remark] NVARCHAR(MAX),
    
    CONSTRAINT [FK_LCD_PR] FOREIGN KEY ([ProductionRecordID]) 
        REFERENCES [dbo].[ProductionRecords]([ProductionRecordID])
);

-- ตาราง ProblemRecords (ปรับปรุง: เพิ่มรายละเอียดการแก้ไขและ Verification)
CREATE TABLE [dbo].[ProblemRecords] (
    [ProblemRecordID] INT PRIMARY KEY IDENTITY(1,1),
    [ProductionRecordID] INT NOT NULL,
    [ProblemTypeID] INT NOT NULL,
    
    -- เพิ่ม FK สำหรับ Downtime Categories ที่ละเอียดขึ้น
    [DowntimeCategoryID] INT NULL, 

    [StopDateTime] DATETIME NOT NULL,
    [StartDateTime] DATETIME NOT NULL,
    [CalculatedDowntimeMin] DECIMAL(5, 2) NOT NULL,
    [ShiftDate] DATE NOT NULL,
    [CalculatedShiftID] INT NOT NULL,
    [IsMachineDowntime] BIT,

    -- รายละเอียดปัญหาและการแก้ไข
    [RootCauseCode] VARCHAR(20),
    [ActionTaken] NVARCHAR(500),
    [ResponsibleDept] VARCHAR(50),
    [IsVerified] BIT DEFAULT 0,
    [VerifiedBy] VARCHAR(10),
    [VerifiedDate] DATETIME,
    
    [OperatorEmpId] VARCHAR(10), 

    CONSTRAINT [FK_ProbRec_PR] FOREIGN KEY ([ProductionRecordID]) REFERENCES [dbo].[ProductionRecords]([ProductionRecordID]),
    CONSTRAINT [FK_ProbRec_ProbType] FOREIGN KEY ([ProblemTypeID]) REFERENCES [dbo].[ProblemTypes]([ProblemTypeID]),
    CONSTRAINT [FK_ProbRec_Shift] FOREIGN KEY ([CalculatedShiftID]) REFERENCES [dbo].[Shifts]([ShiftID]),
    CONSTRAINT [FK_ProbRec_Emp] FOREIGN KEY ([OperatorEmpId]) REFERENCES [dbo].[EmployeeDetails]([EmpId]),
    CONSTRAINT [FK_ProbRec_VerifiedBy] FOREIGN KEY ([VerifiedBy]) REFERENCES [dbo].[EmployeeDetails]([EmpId]),
    CONSTRAINT [FK_ProbRec_DTCat] FOREIGN KEY ([DowntimeCategoryID]) REFERENCES [dbo].[DowntimeCategories]([CategoryID]),
    CONSTRAINT [CHK_ProblemRecords_TimeOrder] CHECK (StartDateTime > StopDateTime)
);

-- ตาราง InventoryCutoff
CREATE TABLE [dbo].[InventoryCutoff] (
    [CutoffID] INT PRIMARY KEY IDENTITY(1,1),
    [CutoffTypeID] INT NOT NULL, -- 1: END_LOT, 2: SHIFT_END, 3: MIDNIGHT
    [CutoffDateTime] DATETIME NOT NULL,
    [LotNo] VARCHAR(20) NOT NULL,
    [FilmLotNo] VARCHAR(20),
    [EndingFilmInventoryKG] DECIMAL(10, 2),
    [ShiftDate] DATE NOT NULL,
    [ShiftID] INT NOT NULL,
    [OperatorEmpId] VARCHAR(10),

    CONSTRAINT [FK_IC_Shift] FOREIGN KEY ([ShiftID]) REFERENCES [dbo].[Shifts]([ShiftID]),
    CONSTRAINT [FK_IC_Emp] FOREIGN KEY ([OperatorEmpId]) REFERENCES [dbo].[EmployeeDetails]([EmpId])
);


-- ***************************************************************
-- 3. ตารางใหม่สำหรับการวิเคราะห์และ Audit
-- ***************************************************************

-- ตาราง AuditLog (ใหม่: สำหรับ Tracking การเปลี่ยนแปลงข้อมูล)
CREATE TABLE [dbo].[AuditLog] (
    [AuditID] INT IDENTITY(1,1) PRIMARY KEY,
    [TableName] VARCHAR(100) NOT NULL,
    [RecordID] VARCHAR(100) NOT NULL,
    [Action] CHAR(1) NOT NULL, -- I/U/D
    [OldValues] NVARCHAR(MAX),
    [NewValues] NVARCHAR(MAX),
    [ChangedBy] VARCHAR(10) NOT NULL,
    [ChangedDateTime] DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT [FK_AuditLog_Emp] FOREIGN KEY ([ChangedBy]) 
        REFERENCES [dbo].[EmployeeDetails]([EmpId])
);

-- ตาราง ProductionOrderStatusHistory (ใหม่: สำหรับ Tracking สถานะ Lot)
CREATE TABLE [dbo].[ProductionOrderStatusHistory] (
    [HistoryID] INT IDENTITY(1,1) PRIMARY KEY,
    [LotNo] VARCHAR(20) NOT NULL,
    [FromStatusID] INT,
    [ToStatusID] INT NOT NULL,
    [ChangedBy] VARCHAR(10),
    [ChangedDateTime] DATETIME DEFAULT GETDATE(),
    [Remark] NVARCHAR(500),

    CONSTRAINT [FK_StatusHist_LotNo] FOREIGN KEY ([LotNo]) REFERENCES [dbo].[ProductionOrders]([LotNo]),
    CONSTRAINT [FK_StatusHist_FromStatus] FOREIGN KEY ([FromStatusID]) REFERENCES [dbo].[OrderStatusLookup]([StatusID]),
    CONSTRAINT [FK_StatusHist_ToStatus] FOREIGN KEY ([ToStatusID]) REFERENCES [dbo].[OrderStatusLookup]([StatusID]),
    CONSTRAINT [FK_StatusHist_ChangedBy] FOREIGN KEY ([ChangedBy]) REFERENCES [dbo].[EmployeeDetails]([EmpId])
);

-- ตาราง MachineParameters (ใหม่: สำหรับเก็บ Spec เครื่องจักร)
CREATE TABLE [dbo].[MachineParameters] (
    [ParameterID] INT IDENTITY(1,1) PRIMARY KEY,
    [MachineID] INT NOT NULL,
    [ParameterName] NVARCHAR(100) NOT NULL,
    [ParameterValue] DECIMAL(10,3),
    [UOM] VARCHAR(10),
    [ValidFrom] DATETIME NOT NULL,
    [ValidTo] DATETIME NULL,
    
    CONSTRAINT [FK_MachineParams_Machine] FOREIGN KEY ([MachineID]) 
        REFERENCES [dbo].[Machines]([MachineID])
);

-- ตาราง PerformanceTargets (ใหม่: สำหรับเก็บ Target OEE/Output)
CREATE TABLE [dbo].[PerformanceTargets] (
    [TargetID] INT IDENTITY(1,1) PRIMARY KEY,
    [MachineID] INT,
    [ShiftID] INT,
    [ProductCode] VARCHAR(20),
    [EffectiveDate] DATE NOT NULL,
    [TargetOEE] DECIMAL(5,2),
    [TargetOutput] DECIMAL(10,3),
    [TargetDowntime] DECIMAL(5,2),
    [IsActive] BIT DEFAULT 1,

    CONSTRAINT [FK_Target_Machine] FOREIGN KEY ([MachineID]) REFERENCES [dbo].[Machines]([MachineID]),
    CONSTRAINT [FK_Target_Shift] FOREIGN KEY ([ShiftID]) REFERENCES [dbo].[Shifts]([ShiftID])
);

-- ตาราง DailyProductionSummary (ใหม่: สำหรับ Reporting Layer)
CREATE TABLE [dbo].[DailyProductionSummary] (
    [SummaryDate] DATE NOT NULL,
    [MachineID] INT NOT NULL,
    [ShiftID] INT NOT NULL,
    [TotalBagsOut] DECIMAL(10,3),
    [TotalDowntimeMin] DECIMAL(10,2),
    [OEE] DECIMAL(5,2),
    [FilmConsumptionKG] DECIMAL(10,2),
    [LastUpdated] DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT [PK_DailyProductionSummary] 
    PRIMARY KEY ([SummaryDate], [MachineID], [ShiftID]),
    CONSTRAINT [FK_Summary_Machine] FOREIGN KEY ([MachineID]) REFERENCES [dbo].[Machines]([MachineID]),
    CONSTRAINT [FK_Summary_Shift] FOREIGN KEY ([ShiftID]) REFERENCES [dbo].[Shifts]([ShiftID])
);