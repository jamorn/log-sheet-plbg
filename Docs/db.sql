-- ####################################################################
-- 1. DDL: การลบตารางเดิม (ถ้ามี) และการสร้างตารางใหม่
-- ####################################################################

-- DROP ตารางทั้งหมดในลำดับที่ถูกต้องเพื่อหลีกเลี่ยงข้อจำกัด Foreign Key (ถ้ามีการรันซ้ำ)
IF OBJECT_ID('DailyProductionSummary', 'U') IS NOT NULL DROP TABLE DailyProductionSummary;
IF OBJECT_ID('LotCompletionDetails', 'U') IS NOT NULL DROP TABLE LotCompletionDetails;
IF OBJECT_ID('ProblemRecords', 'U') IS NOT NULL DROP TABLE ProblemRecords;
IF OBJECT_ID('ProductionRecords', 'U') IS NOT NULL DROP TABLE ProductionRecords;
IF OBJECT_ID('MachineStatus', 'U') IS NOT NULL DROP TABLE MachineStatus;
IF OBJECT_ID('BaggingLocations', 'U') IS NOT NULL DROP TABLE BaggingLocations;
IF OBJECT_ID('EmployeeDetails', 'U') IS NOT NULL DROP TABLE EmployeeDetails;
IF OBJECT_ID('OeeLossTypes', 'U') IS NOT NULL DROP TABLE OeeLossTypes;
IF OBJECT_ID('DowntimeCategories', 'U') IS NOT NULL DROP TABLE DowntimeCategories;
IF OBJECT_ID('Shifts', 'U') IS NOT NULL DROP TABLE Shifts;
IF OBJECT_ID('KpiTargets', 'U') IS NOT NULL DROP TABLE KpiTargets;
IF OBJECT_ID('Machines', 'U') IS NOT NULL DROP TABLE Machines;
IF OBJECT_ID('UnitPLBG', 'U') IS NOT NULL DROP TABLE UnitPLBG;
IF OBJECT_ID('CostCenter', 'U') IS NOT NULL DROP TABLE CostCenter;
GO

-- 1. CostCenter
CREATE TABLE CostCenter (
    CostCenterCode VARCHAR(10) PRIMARY KEY,
    CostCenterName NVARCHAR(50) NOT NULL
);

-- 2. UnitPLBG
CREATE TABLE UnitPLBG (
    UnitId INT PRIMARY KEY,
    UnitName NVARCHAR(50) NOT NULL,
    CostCenterCode VARCHAR(10) NOT NULL,
    CONSTRAINT FK_UnitPLBG_CostCenter FOREIGN KEY (CostCenterCode)
        REFERENCES CostCenter(CostCenterCode)
);

-- 3. Machines (เพิ่ม StandardRPM และ BagWeightKG)
CREATE TABLE Machines (
    MachineId INT PRIMARY KEY,
    MachineName VARCHAR(10) NOT NULL,
    MachineClass VARCHAR(5) NULL,
    MachineActive BIT NOT NULL,
    MachineLine VARCHAR(1) NULL,
    CostCenterCode VARCHAR(10) NOT NULL,
    UnitId INT NOT NULL,
    StandardRPM INT NOT NULL, 
    BagWeightKG DECIMAL(5, 2) NOT NULL, 

    CONSTRAINT FK_Machines_CostCenter FOREIGN KEY (CostCenterCode)
        REFERENCES CostCenter(CostCenterCode),
    CONSTRAINT FK_Machines_UnitPLBG FOREIGN KEY (UnitId)
        REFERENCES UnitPLBG(UnitId)
);

-- 4. KpiTargets (เป้าหมาย KPI)
CREATE TABLE KpiTargets (
    Item INT PRIMARY KEY,
    [Year] INT NOT NULL,
    UnitId INT NOT NULL,
    Waste_Pellet_Target DECIMAL(5, 4) NOT NULL,
    Waste_Film_Target DECIMAL(5, 4) NOT NULL,
    GiveAway_Target DECIMAL(6, 3) NOT NULL,
    Oee_Target DECIMAL(5, 2) NOT NULL,
    GiveAwayMin DECIMAL(6, 3) NULL,
    GiveAwayMax DECIMAL(6, 3) NULL,

    CONSTRAINT FK_KpiTargets_UnitPLBG FOREIGN KEY (UnitId)
        REFERENCES UnitPLBG(UnitId)
);

-- 5. Shifts (ตารางกะทำงาน)
CREATE TABLE Shifts (
    ShiftID INT PRIMARY KEY,
    ShiftName VARCHAR(20) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL
);

-- 6. DowntimeCategories (หมวดหมู่ Downtime OEE: 10, 20, 30)
CREATE TABLE DowntimeCategories (
    CategoryID INT PRIMARY KEY,
    CategoryNameTH NVARCHAR(50) NOT NULL,
    CategoryLevel INT NOT NULL 
    -- 1=Planned (A), 2=Minor Stop/Speed (P, A), 3=Quality Loss (Q)
); 

-- 7. OeeLossTypes (รายการปัญหา OEE ที่สมบูรณ์)
CREATE TABLE OeeLossTypes (
    ProblemTypeID INT PRIMARY KEY,
    TypeNameTH NVARCHAR(100) NOT NULL,
    CategoryID INT NOT NULL, 
    IsActive BIT NOT NULL DEFAULT 1, 
    DisplayOrder INT NOT NULL, 
    CONSTRAINT FK_OeeLossTypes_DCat FOREIGN KEY (CategoryID)
        REFERENCES DowntimeCategories(CategoryID)
);

-- 8. EmployeeDetails
CREATE TABLE EmployeeDetails (
    EmpId VARCHAR(10) PRIMARY KEY,
    EmpName NVARCHAR(100) NOT NULL,
    EmpRole VARCHAR(50) NULL 
);

-- 9. BaggingLocations (ตารางสถานที่ Bagging)
CREATE TABLE BaggingLocations (
    BaggingCode VARCHAR(10) PRIMARY KEY,
    BaggingName NVARCHAR(100) NOT NULL
);

-- 10. MachineStatus (สถานะเครื่องจักรปัจจุบัน)
CREATE TABLE MachineStatus (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    MachineId INT NOT NULL,
    RecordDate DATE NOT NULL,
    IsOperational BIT NOT NULL, 
    StatusNote NVARCHAR(255) NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_MS_Machines FOREIGN KEY (MachineId)
        REFERENCES Machines(MachineId)
);

-- 11. ProductionRecords (ตาราง Transaction แม่)
CREATE TABLE ProductionRecords (
    ProductionRecordID INT IDENTITY(1,1) PRIMARY KEY,
    
    MachineId INT NOT NULL,
    ShiftID INT NOT NULL,
    ShiftDate DATE NOT NULL,
    SegmentStartDateTime DATETIME NOT NULL,
    SegmentEndDateTime DATETIME NOT NULL,
    BagOutActualMT DECIMAL(10, 3) NOT NULL,
    
    RecordStatus VARCHAR(20) NOT NULL DEFAULT 'OPEN', 
    
    CONSTRAINT FK_PR_Machines FOREIGN KEY (MachineId)
        REFERENCES Machines(MachineId),
    CONSTRAINT FK_PR_Shifts FOREIGN KEY (ShiftID)
        REFERENCES Shifts(ShiftID)
);

-- 12. ProblemRecords (บันทึกการหยุด/Loss Time)
CREATE TABLE ProblemRecords (
    ProblemRecordID INT IDENTITY(1,1) PRIMARY KEY,
    ProductionRecordID INT NOT NULL,
    
    ProblemTypeID INT NOT NULL, 
    StopDateTime DATETIME NOT NULL,
    StartDateTime DATETIME NOT NULL,
    CalculatedDowntimeMin DECIMAL(5, 2) NOT NULL,
    
    IsMachineDowntime BIT NOT NULL, 
    OperatorEmpId VARCHAR(10) NULL, 
    
    CONSTRAINT FK_PRec_PR FOREIGN KEY (ProductionRecordID)
        REFERENCES ProductionRecords(ProductionRecordID),
    CONSTRAINT FK_PRec_OeePType FOREIGN KEY (ProblemTypeID) 
        REFERENCES OeeLossTypes(ProblemTypeID)
);

-- 13. LotCompletionDetails (บันทึก Quality Loss และรายละเอียดงาน)
CREATE TABLE LotCompletionDetails (
    LotDetailID INT IDENTITY(1,1) PRIMARY KEY,
    ProductionRecordID INT NOT NULL,
    
    PCCQCKG DECIMAL(10, 3) NULL, 
    MetalDetectionLossKG DECIMAL(10, 3) NULL,
    TailBag1KG DECIMAL(10, 3) NULL,
    TailBag2KG DECIMAL(10, 3) NULL,
    WasteRejectBags INT NULL, 
    BaggingCode VARCHAR(10) NULL, 

    CONSTRAINT FK_LCD_PR FOREIGN KEY (ProductionRecordID)
        REFERENCES ProductionRecords(ProductionRecordID),
    CONSTRAINT FK_LCD_BaggingCode FOREIGN KEY (BaggingCode)
        REFERENCES BaggingLocations(BaggingCode)
);

-- 14. DailyProductionSummary (ตารางสรุป OEE รายวัน)
CREATE TABLE DailyProductionSummary (
    ShiftDate DATE NOT NULL,
    MachineID INT NOT NULL,
    UnitId INT NOT NULL,
    
    Target_OEE_Pct DECIMAL(5, 2) NOT NULL,
    
    Availability_Pct DECIMAL(5, 2) NOT NULL,
    Performance_Pct DECIMAL(5, 2) NOT NULL,
    Quality_Pct DECIMAL(5, 2) NOT NULL,
    OEE_Percentage DECIMAL(5, 2) NOT NULL,
    
    OEE_TargetMet BIT NOT NULL, 
    Top_Downtime_Reason NVARCHAR(255),
    Supervisor_Review_Time DATETIME NULL,
    Supervisor_Final_Remark NVARCHAR(MAX) NULL,

    CONSTRAINT PK_DailySummary PRIMARY KEY (ShiftDate, MachineID),
    CONSTRAINT FK_DS_Machines FOREIGN KEY (MachineID)
        REFERENCES Machines(MachineId),
    CONSTRAINT FK_DS_UnitPLBG FOREIGN KEY (UnitId)
        REFERENCES UnitPLBG(UnitId)
);
GO


-- ####################################################################
-- 2. DML: ข้อมูลเริ่มต้น (Init Data)
-- ####################################################################

-- 1. CostCenter
INSERT INTO CostCenter (CostCenterCode, CostCenterName) VALUES
('10111203', N'โรงงาน PP 1&2'), ('10111204', N'โรงงาน PP 3&4'),
('10111205', N'โรงงาน PPE'), ('10111206', N'โรงงาน PPC'),
('10111202', N'โรงงาน HDPE'), ('10126300', N'โรงงาน SASB');

-- 2. UnitPLBG
INSERT INTO UnitPLBG (UnitId, UnitName, CostCenterCode) VALUES
(1, N'PP1&2', '10111203'), (2, N'HDPE', '10111202'),
(3, N'PP3', '10111204'), (4, N'PPE', '10111205'),
(5, N'PPC', '10111206'), (6, N'SASB', '10126300');

-- 3. Machines
INSERT INTO Machines (MachineId, MachineName, MachineClass, MachineActive, MachineLine, CostCenterCode, UnitId, StandardRPM, BagWeightKG) VALUES
(1, 'PP12/A', 'g1', 1, 'A', '10111203', 1, 1800, 25.00),
(2, 'PP12/C', 'g1', 1, 'C', '10111203', 1, 1200, 25.00),
(3, 'PP3/A', 'g1', 1, 'A', '10111204', 3, 1200, 25.00),
(4, 'PP3/B', 'g1', 1, 'B', '10111204', 3, 1200, 25.00),
(5, 'PPE/C', 'g1', 1, 'C', '10111205', 4, 1200, 25.00),
(6, 'PPE/D', 'g1', 1, 'D', '10111205', 4, 1200, 25.00),
(7, 'PPC/A', 'g1', 1, 'A', '10111206', 5, 1200, 25.00),
(8, 'PPC/B', 'g1', 1, 'B', '10111206', 5, 1200, 25.00),
(9, 'HDPE/A', 'g1', 1, 'A', '10111202', 2, 1200, 25.00);

-- 4. KpiTargets
INSERT INTO KpiTargets (Item, [Year], UnitId, Waste_Pellet_Target, Waste_Film_Target, GiveAway_Target, Oee_Target, GiveAwayMin, GiveAwayMax) VALUES
(1, 2024, 1, 0.0250, 0.0050, 25.100, 88.87, 25.100, 25.115), (2, 2024, 2, 0.0050, 0.5900, 25.160, 90.17, 25.100, 25.115),
(3, 2024, 5, 0.0050, 0.2500, 25.160, 92.53, 25.100, 25.115), (4, 2024, 4, 0.0060, 0.2500, 25.160, 89.10, 25.100, 25.115),
(5, 2024, 3, 0.0060, 0.2500, 25.160, 89.68, 25.100, 25.115), (6, 2024, 6, 0.0080, 0.5900, 25.170, 92.69, 25.100, 25.115);

-- 5. Shifts
INSERT INTO Shifts (ShiftID, ShiftName, StartTime, EndTime) VALUES
(1, 'Morning Shift', '06:00:00', '14:00:00'),
(2, 'Evening Shift', '14:00:00', '22:00:00'),
(3, 'Night Shift', '22:00:00', '06:00:00');

-- 6. DowntimeCategories (อัปเดต CategoryID และ Level)
INSERT INTO DowntimeCategories (CategoryID, CategoryNameTH, CategoryLevel) VALUES
(10, N'Planned Loss (A - Schedule)', 1), 
(20, N'Minor Stop/Speed Loss (P, A - Downtime)', 2), 
(30, N'Quality Loss (Q - Rejects)', 3); 


-- 7. OeeLossTypes (อัปเดต CategoryID และ ProblemTypeID ให้สอดคล้อง)
INSERT INTO OeeLossTypes (ProblemTypeID, TypeNameTH, CategoryID, IsActive, DisplayOrder) VALUES
-- CategoryID 10: Planned Loss (A - Schedule) -> ProblemTypeID 1xx
(101, N'ช่างทำการ PM', 10, 1, 1),
(102, N'ประชุม', 10, 1, 2),
(103, N'รอโปรแกรม', 10, 1, 3),
(104, N'ทำความสะอาด', 10, 1, 4),
(105, N'เปลี่ยน FILM', 10, 1, 5), 

-- CategoryID 20: Minor Stop/Speed Loss -> ProblemTypeID 2xx
(201, N'เครื่องจักรเสีย', 20, 1, 0), -- Breakdown (เวลาหยุดหลัก)
(202, N'ปรับ Teflon Top Seal', 20, 1, 1),
(203, N'ปรับ Teflon Bottom Seal', 20, 1, 2), 
(204, N'ปรับ condition Bagging', 20, 1, 3),
(205, N'ล้าง ink jet และปรับแต่ง', 20, 1, 4), 
(206, N'ปรับ condition Palletizer', 20, 1, 5), 
(299, N'อื่นๆ (Time Loss)', 20, 1, 99), 

-- CategoryID 30: Quality Loss -> ProblemTypeID 3xx
(301, N'จำนวน Film Test', 30, 1, 1), 
(302, N'Bottom Seal ทำถุงเสีย', 30, 1, 2), 
(303, N'Conner ทำถุงเสีย', 30, 1, 3), 
(304, N'Bagging ปล่อยถุงเปล่า', 30, 1, 4), 
(305, N'Clamp Jaw จับถุงหลุด', 30, 1, 5), 
(306, N'Holding Tong เกี่ยวแตก', 30, 1, 6), 
(307, N'Top Seal ทำถุงเสีย', 30, 1, 7), 
(308, N'Reject จากน้ำหนัก', 30, 1, 8),
(309, N'Ink Jet ทำถุงเสีย', 30, 1, 9), 
(310, N'palletizer ทำถุงเสีย', 30, 1, 10), 
(399, N'อื่นๆ (bag)', 30, 1, 99); 

-- 9. BaggingLocations
INSERT INTO BaggingLocations (BaggingCode, BaggingName) VALUES
('PL', N'Bagging PL'), ('SA', N'Bagging SASB');

-- (ส่วนข้อมูล MachineStatus, ProductionRecords, ProblemRecords และ LotCompletionDetails จะใส่เมื่อมี Transaction เกิดขึ้น)

GO