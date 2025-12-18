🏭 SQL Server Database Design for Bagging Logsheet / OEE System
📋 Overview
การออกแบบฐานข้อมูลสำหรับระบบบันทึก Logsheet การผลิต การติดตาม Downtime (OEE) และบัญชีวัตถุดิบ Film ของสถานี Bagging โดยใช้ SQL Server

วัตถุประสงค์:

จัดเก็บข้อมูลการผลิตจริง และการสูญเสีย (Loss) แยกตาม Segment ของ Lot

ติดตามและคำนวณ Downtime (OEE) ที่แม่นยำ โดยจัดการ Logic การข้ามกะ

ติดตามบัญชีวัตถุดิบ Film ที่ใช้ไปในแต่ละกะและแต่ละ Lot

รองรับการวิเคราะห์ผลผลิต/ประสิทธิภาพแยกตาม Lot, เครื่องจักร, และกะการทำงาน

🏗️ Database Schema
Database Name: BaggingLogsheetDB

📊 Tables Design (10 Tables)
1. Machines (เครื่องจักร)
จัดเก็บข้อมูล Master เครื่องจักรที่ใช้ในการ Bagging

CREATE TABLE [dbo].[Machines] (
    [MachineID] INT PRIMARY KEY,
    [MachineName] VARCHAR(10) UNIQUE NOT NULL,
    [MachineLine] VARCHAR(1),
    [CostCenterCode] VARCHAR(10),
    [MachineActive] BIT NOT NULL DEFAULT 1
);
2. Shifts (กะการทำงาน)
จัดเก็บข้อมูล Master กะการทำงานและช่วงเวลามาตรฐาน
CREATE TABLE [dbo].[Shifts] (
    [ShiftID] INT PRIMARY KEY,
    [ShiftCode] VARCHAR(1) UNIQUE NOT NULL, -- M, E, N
    [ShiftTimeStart] TIME NOT NULL,
    [ShiftTimeEnd] TIME NOT NULL
);
3. EmployeeDetails (ข้อมูลพนักงาน)
จัดเก็บข้อมูลพนักงานที่เกี่ยวข้องกับการดำเนินงานและบันทึกข้อมูล
CREATE TABLE [dbo].[EmployeeDetails] (
    [EmpId] VARCHAR(10) PRIMARY KEY,
    [FullNameTH] NVARCHAR(100) NOT NULL,
    [FullNameEN] VARCHAR(100),
    [Email] VARCHAR(100),
    [ThPosition] NVARCHAR(100),
    [EnPosition] VARCHAR(100),
    [Role] VARCHAR(50)
);
4. OrderStatusLookup (สถานะใบสั่งผลิต)
ตาราง Lookup สำหรับสถานะของ Lot การผลิต
CREATE TABLE [dbo].[OrderStatusLookup] (
    [StatusID] INT PRIMARY KEY,
    [StatusNameTH] NVARCHAR(50) NOT NULL, -- วางแผน, กำลังผลิต, Hold, Completed
    [IsComplete] BIT NOT NULL
);
5. ProblemTypes (ประเภทปัญหา/กิจกรรม)
ตาราง Lookup สำหรับจัดหมวดหมู่ Downtime และกิจกรรมอื่น ๆ
CREATE TABLE [dbo].[ProblemTypes] (
    [ProblemTypeID] INT PRIMARY KEY,
    [TypeNameTH] NVARCHAR(50) NOT NULL, -- Change Film, Cleaning, Wait, Breakdown
    [IsDowntime] BIT NOT NULL -- ระบุว่านับเป็น Downtime ใน OEE หรือไม่
);
6. ProductionOrders (ใบสั่งผลิต Master)
จัดเก็บข้อมูล Master ของ Lot และสถานะการทำงานโดยรวม
CREATE TABLE [dbo].[ProductionOrders] (
    [LotNo] VARCHAR(20) PRIMARY KEY,
    [OrderDate] DATE,
    [PlannedQuantityMT] DECIMAL(10, 3),
    [CurrentStatusID] INT NOT NULL,
    [ActualCompletionDate] DATETIME NULL,
    
    CONSTRAINT [FK_ProductionOrders_Status] FOREIGN KEY ([CurrentStatusID]) 
        REFERENCES [OrderStatusLookup]([StatusID])
);
7. ProductionRecords (บันทึกการผลิตต่อ Segment)
บันทึกการผลิตจริงและยอดโอนย้าย ต่อช่วงการผลิต ที่เครื่องจักรทำ (Segment)
CREATE TABLE [dbo].[ProductionRecords] (
    [ProductionRecordID] INT IDENTITY(1,1) PRIMARY KEY,
    [LotNo] VARCHAR(20) NOT NULL,
    [SegmentSequence] INT NOT NULL, -- ลำดับการผลิตใน Lot (รองรับการเปลี่ยนเครื่องจักร)
    [MachineID] INT NOT NULL,
    [ShiftDate] DATE NOT NULL,
    [ShiftID] INT NOT NULL,
    
    [BagOutActualMT] DECIMAL(10, 3),
    [TransferToWHAggregateMT] DECIMAL(10, 3),
    [DepositedInBaggingMT] DECIMAL(10, 3),
    
    [SegmentStartDateTime] DATETIME NOT NULL,
    [SegmentEndDateTime] DATETIME NULL,
    [IsCompleted] BIT NOT NULL DEFAULT 0,

    CONSTRAINT [UQ_ProductionRecords_LotSegment] UNIQUE ([LotNo], [SegmentSequence]),
    CONSTRAINT [FK_PR_LotNo] FOREIGN KEY ([LotNo]) REFERENCES [ProductionOrders]([LotNo]),
    CONSTRAINT [FK_PR_Machine] FOREIGN KEY ([MachineID]) REFERENCES [Machines]([MachineID]),
    CONSTRAINT [FK_PR_Shift] FOREIGN KEY ([ShiftID]) REFERENCES [Shifts]([ShiftID])
);
8. LotCompletionDetails (รายละเอียดการปิด Lot)
บันทึกข้อมูลการสูญเสียและคุณภาพที่เกิดขึ้น ณ จุด Empty Lot
CREATE TABLE [dbo].[LotCompletionDetails] (
    [ProductionRecordID] INT PRIMARY KEY,
    [PCCQCKG] DECIMAL(10, 2),
    [MetalDetectionLossKG] DECIMAL(10, 2),
    [TailBag1KG] DECIMAL(10, 2),
    [TailBag2KG] DECIMAL(10, 2),
    [Remark] NVARCHAR(MAX),
    
    CONSTRAINT [FK_LCD_PR] FOREIGN KEY ([ProductionRecordID]) 
        REFERENCES [ProductionRecords]([ProductionRecordID])
);
9. ProblemRecords (บันทึก Downtime และกิจกรรม)
บันทึกช่วงเวลาหยุด, สาเหตุ, และ Downtime ที่คำนวณแล้ว (รองรับ Logic ข้ามกะ)
CREATE TABLE [dbo].[ProblemRecords] (
    [ProblemRecordID] INT IDENTITY(1,1) PRIMARY KEY,
    [ProductionRecordID] INT NOT NULL, -- Lot ที่ได้รับผลกระทบ
    [ProblemTypeID] INT NOT NULL,
    [StopDateTime] DATETIME NOT NULL,
    [StartDateTime] DATETIME NOT NULL,
    [CalculatedDowntimeMin] DECIMAL(5, 2) NOT NULL,
    [ShiftDate] DATE NOT NULL,
    [CalculatedShiftID] INT NOT NULL, -- กะที่เกิดปัญหา (ใช้คำนวณ OEE)
    [IsMachineDowntime] BIT,
    [OperatorEmpId] VARCHAR(10), 

    CONSTRAINT [FK_ProbRec_PR] FOREIGN KEY ([ProductionRecordID]) REFERENCES [ProductionRecords]([ProductionRecordID]),
    CONSTRAINT [FK_ProbRec_ProbType] FOREIGN KEY ([ProblemTypeID]) REFERENCES [ProblemTypes]([ProblemTypeID]),
    CONSTRAINT [FK_ProbRec_Shift] FOREIGN KEY ([CalculatedShiftID]) REFERENCES [Shifts]([ShiftID]),
    CONSTRAINT [FK_ProbRec_Emp] FOREIGN KEY ([OperatorEmpId]) REFERENCES [EmployeeDetails]([EmpId])
);
10. InventoryCutoff (บันทึกยอด Film คงเหลือ)
บันทึกการตัดยอด Film คงเหลือ เพื่อคำนวณ Film Consumption ต่อกะ/ต่อ Lot
CREATE TABLE [dbo].[InventoryCutoff] (
    [CutoffID] INT IDENTITY(1,1) PRIMARY KEY,
    [CutoffTypeID] INT NOT NULL, -- 1: END_LOT, 2: SHIFT_END, 3: MIDNIGHT
    [CutoffDateTime] DATETIME NOT NULL,
    [LotNo] VARCHAR(20) NOT NULL, -- Lot ที่กำลังใช้ Film อยู่
    [FilmLotNo] VARCHAR(20),
    [EndingFilmInventoryKG] DECIMAL(10, 2),
    [ShiftDate] DATE NOT NULL,
    [ShiftID] INT NOT NULL, 
    [OperatorEmpId] VARCHAR(10),

    CONSTRAINT [FK_IC_Shift] FOREIGN KEY ([ShiftID]) REFERENCES [Shifts]([ShiftID]),
    CONSTRAINT [FK_IC_Emp] FOREIGN KEY ([OperatorEmpId]) REFERENCES [EmployeeDetails]([EmpId])
);

# 🔧 Database Functions and Procedures (Example)
เนื่องจากระบบนี้เน้นการคำนวณ Downtime และ Consumption ใน Logic การบันทึก (Application Layer) Stored Procedure จึงมักใช้เพื่อจัดการ Transaction ที่ซับซ้อน เช่น การปิด Lot

1. Stored Procedure: RecordDowntimeEvent (ตัวอย่าง Logic ข้ามกะ)
Procedure สำหรับบันทึกรายการ Downtime ที่ซับซ้อน (Procedure ภายในจะมีการเรียกใช้ Logic Split Shift)
CREATE PROCEDURE [dbo].[RecordDowntimeEvent]
    @ProductionRecordID INT,
    @ProblemTypeID INT,
    @StopDateTime DATETIME,
    @StartDateTime DATETIME,
    @OperatorEmpId VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    -- [Logic: Calculate DowntimeMin and Split records if crossing Shift Boundaries (M: 14:00, E: 22:00)]
    -- [Logic: INSERT multiple rows into ProblemRecords if split occurs]
    
    -- Example for a single INSERT if no split:
    DECLARE @DowntimeMin DECIMAL(5, 2) = DATEDIFF(minute, @StopDateTime, @StartDateTime);
    
    INSERT INTO [ProblemRecords] 
        (ProductionRecordID, ProblemTypeID, StopDateTime, StartDateTime, CalculatedDowntimeMin, ShiftDate, CalculatedShiftID, IsMachineDowntime, OperatorEmpId)
    VALUES 
        (@ProductionRecordID, @ProblemTypeID, @StopDateTime, @StartDateTime, @DowntimeMin, CAST(@StopDateTime AS DATE), [dbo].GetShiftIDByTime(@StopDateTime), 1, @OperatorEmpId);

    SELECT 'Success' AS Result;
END

# 📈 Database Performance Optimization
1. Index Strategy
การสร้าง Non-Clustered Indexes เพื่อเพิ่มประสิทธิภาพการค้นหารายงาน
-- Index สำหรับการค้นหา Downtime ตามช่วงเวลา
CREATE NONCLUSTERED INDEX [IX_ProblemRecords_StopStartDateTime] 
ON [dbo].[ProblemRecords] (StopDateTime, StartDateTime) 
INCLUDE (CalculatedDowntimeMin, ProblemTypeID);

-- Index สำหรับการวิเคราะห์ตามกะ
CREATE NONCLUSTERED INDEX [IX_ProblemRecords_ShiftAnalysis] 
ON [dbo].[ProblemRecords] (ShiftDate, CalculatedShiftID) 
INCLUDE (CalculatedDowntimeMin);

CREATE NONCLUSTERED INDEX [IX_InventoryCutoff_ShiftAnalysis] 
ON [dbo].[InventoryCutoff] (ShiftDate, ShiftID) 
INCLUDE (EndingFilmInventoryKG, CutoffTypeID);

# 📚 สรุปโครงสร้างฐานข้อมูล Logsheet (10 ตาราง)
โครงสร้างฐานข้อมูลนี้ถูกออกแบบมาเพื่อรองรับการติดตาม การผลิต (Production), ประสิทธิภาพเครื่องจักร (OEE/Downtime), และ บัญชีวัตถุดิบ (Film Inventory) โดยมีความสัมพันธ์และ Logic ที่จัดการกรณีพิเศษ เช่น การข้ามกะ, การปิด Lot, และการบันทึก Loss Time

1. ตาราง Master และ Lookup (5 ตาราง)
ตารางเหล่านี้เก็บข้อมูลพื้นฐานที่ใช้ในการอ้างอิงและจำแนกประเภทข้อมูล Transaction
ลำดับ,ตาราง (Table Name),Primary Key,คำอธิบายและหน้าที่
1,Machines,MachineID,"ข้อมูลหลักของเครื่องจักร (เช่น ชื่อ, Line, Cost Center)"
2,Shifts,ShiftID,"ข้อมูลหลักของกะการทำงาน (M, E, N) และช่วงเวลาเริ่มต้น/สิ้นสุด"
3,EmployeeDetails,EmpId,ข้อมูลพนักงานและตำแหน่ง (ใช้ในการระบุผู้บันทึกข้อมูล)
4,OrderStatusLookup,StatusID,"ประเภทสถานะใบสั่งผลิต (เช่น In Progress, Hold, Completed)"
5,ProblemTypes,ProblemTypeID,"ประเภทของปัญหาหรือกิจกรรมที่ทำให้เครื่องหยุด (เช่น Breakdown, Change Film, Wait)"

2. ตาราง Transaction หลัก (5 ตาราง)
ตารางเหล่านี้บันทึกข้อมูลการดำเนินงานประจำวันทั้งหมด และเป็นศูนย์กลางของการวิเคราะห์

## 2.1 ตารางจัดการคำสั่งผลิต (Order & Production)
ลำดับ,ตาราง (Table Name),Primary Key,คำอธิบายและหน้าที่หลัก
6,ProductionOrders,LotNo,"Master ใบสั่งผลิต กำหนด Lot No., Quantity ตามแผน, และสถานะปัจจุบัน (ใช้ CurrentStatusID เป็น FK)"
7,ProductionRecords,ProductionRecordID,"บันทึกการผลิตต่อ Segment เก็บยอด Bag Out, Transfer, และยอดคงค้าง ต่อช่วงการผลิต (Segment) ที่เกิดขึ้นบนเครื่องจักรและกะนั้น ๆ"
8,LotCompletionDetails,"ProductionRecordID (PK, FK)","รายละเอียดการปิด Lot (บันทึก ณ Empty) ใช้เก็บข้อมูลคุณภาพและความสูญเสียสุดท้าย เช่น PC QC, เม็ดโลหะ, ท้ายถุง"
## 2.2 ตารางติดตาม Downtime และ Inventoryลำดับตาราง (Table Name)Primary Keyคำอธิบายและ Logic สำคัญ9ProblemRecordsProblemRecordIDบันทึก Downtime / กิจกรรม (Logsheet Section) โดยเฉพาะ Logic การแยก Row สำหรับ Downtime ข้ามกะ (ใช้ CalculatedDowntimeMin และ CalculatedShiftID)10InventoryCutoffCutoffIDบันทึกยอด Film คงเหลือ ณ จุดตัดยอด (Cutoff) หลัก 3 ประเภท ได้แก่ END_LOT (Empty), SHIFT_END, และ MIDNIGHT เพื่อใช้คำนวณ Film Consumption ต่อกะ

3. ความสัมพันธ์ที่สำคัญ (Key Relationships)
ความสัมพันธ์เหล่านี้ทำให้สามารถเชื่อมโยงข้อมูลจากหลายมิติเข้าด้วยกัน เช่น Downtime ที่เกิดขึ้นกับ Lot ใด และใครเป็นผู้บันทึกในกะใด

ProductionRecords ➡️ ProductionOrders (One Lot has multiple production segments)

ProblemRecords ➡️ ProductionRecords (One production segment can have multiple downtime records)

ProblemRecords ➡️ Shifts (ใช้ CalculatedShiftID เพื่อระบุผู้รับผิดชอบ Downtime ต่อกะ)

InventoryCutoff ➡️ Shifts (เพื่อวิเคราะห์การใช้ Film ต่อกะ)

ProblemRecords และ InventoryCutoff ➡️ EmployeeDetails (เพื่อระบุผู้บันทึกข้อมูล