# 🎯 ข้อเสนอแนะการปรับปรุง database
1. เพิ่มตาราง Audit Log
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
        REFERENCES [EmployeeDetails]([EmpId])
);

2. ปรับปรุงตาราง ProductionOrders
-- เพิ่มข้อมูลสำคัญสำหรับการวางแผน
ALTER TABLE [dbo].[ProductionOrders]
ADD 
    [ProductCode] VARCHAR(20),
    [CustomerCode] VARCHAR(20),
    [PlannedStartDate] DATE,
    [PlannedEndDate] DATE,
    [Priority] INT DEFAULT 5,
    [CreatedBy] VARCHAR(10),
    [CreatedDate] DATETIME DEFAULT GETDATE(),
    [LastModifiedBy] VARCHAR(10),
    [LastModifiedDate] DATETIME;

3. เพิ่มตาราง MachineParameters สำหรับเก็บ Spec เครื่องจักร
CREATE TABLE [dbo].[MachineParameters] (
    [ParameterID] INT IDENTITY(1,1) PRIMARY KEY,
    [MachineID] INT NOT NULL,
    [ParameterName] NVARCHAR(100) NOT NULL,
    [ParameterValue] DECIMAL(10,3),
    [UOM] VARCHAR(10),
    [ValidFrom] DATETIME NOT NULL,
    [ValidTo] DATETIME NULL,
    
    CONSTRAINT [FK_MachineParams_Machine] FOREIGN KEY ([MachineID]) 
        REFERENCES [Machines]([MachineID])
);

4. ปรับปรุงตาราง ProblemRecords
-- เพิ่มความละเอียดในการวิเคราะห์ปัญหา
ALTER TABLE [dbo].[ProblemRecords]
ADD 
    [RootCauseCode] VARCHAR(20),
    [ActionTaken] NVARCHAR(500),
    [ResponsibleDept] VARCHAR(50),
    [IsVerified] BIT DEFAULT 0,
    [VerifiedBy] VARCHAR(10),
    [VerifiedDate] DATETIME;

5. เพิ่มตารางสำหรับ Performance Targets
CREATE TABLE [dbo].[PerformanceTargets] (
    [TargetID] INT IDENTITY(1,1) PRIMARY KEY,
    [MachineID] INT,
    [ShiftID] INT,
    [ProductCode] VARCHAR(20),
    [EffectiveDate] DATE NOT NULL,
    [TargetOEE] DECIMAL(5,2),
    [TargetOutput] DECIMAL(10,3),
    [TargetDowntime] DECIMAL(5,2),
    [IsActive] BIT DEFAULT 1
);

🔄 ปรับปรุงความสัมพันธ์ (Relationships)
6. เพิ่มตาราง ProductionOrderHistory สำหรับ Tracking สถานะ
CREATE TABLE [dbo].[ProductionOrderStatusHistory] (
    [HistoryID] INT IDENTITY(1,1) PRIMARY KEY,
    [LotNo] VARCHAR(20) NOT NULL,
    [FromStatusID] INT,
    [ToStatusID] INT NOT NULL,
    [ChangedBy] VARCHAR(10),
    [ChangedDateTime] DATETIME DEFAULT GETDATE(),
    [Remark] NVARCHAR(500)
);

7. แยกตาราง Downtime Category ออกเป็นหลาย Level
CREATE TABLE [dbo].[DowntimeCategories] (
    [CategoryID] INT PRIMARY KEY,
    [ParentCategoryID] INT NULL,
    [CategoryNameTH] NVARCHAR(100) NOT NULL,
    [CategoryLevel] INT NOT NULL, -- 1: Major, 2: Sub, 3: Detail
    [IsActive] BIT DEFAULT 1,
    
    CONSTRAINT [FK_DowntimeCategories_Parent] FOREIGN KEY ([ParentCategoryID]) 
        REFERENCES [DowntimeCategories]([CategoryID])
);
📊 Optimization เพิ่มเติม
8. สร้าง Partitioned Tables สำหรับข้อมูล Transaction ใหญ่
-- Partition ProductionRecords ตามเดือน
CREATE PARTITION FUNCTION [pf_ProductionRecords_Date] (DATE)
AS RANGE RIGHT FOR VALUES (
    '2024-01-01', '2024-02-01', '2024-03-01'
);

CREATE PARTITION SCHEME [ps_ProductionRecords_Date]
AS PARTITION [pf_ProductionRecords_Date]
TO ([PRIMARY], [FG1], [FG2], [FG3]);
9. เพิ่ม Index สำหรับ Query ประสิทธิภาพสูง
-- สำหรับการหา Production Efficiency
CREATE NONCLUSTERED INDEX [IX_ProductionRecords_Efficiency] 
ON [dbo].[ProductionRecords] 
([ShiftDate], [MachineID], [ShiftID]) 
INCLUDE ([BagOutActualMT], [SegmentStartDateTime], [SegmentEndDateTime]);

-- สำหรับ Downtime Analysis
CREATE NONCLUSTERED INDEX [IX_ProblemRecords_Analysis] 
ON [dbo].[ProblemRecords] 
([ProductionRecordID], [ProblemTypeID], [CalculatedShiftID]) 
INCLUDE ([CalculatedDowntimeMin], [StopDateTime], [StartDateTime]);

10. สร้าง Computed Columns สำหรับข้อมูลที่ใช้บ่อย
ALTER TABLE [dbo].[ProductionRecords]
ADD 
    [SegmentDurationMin] AS 
        DATEDIFF(MINUTE, SegmentStartDateTime, 
        ISNULL(SegmentEndDateTime, GETDATE())) PERSISTED,
    
    [ProductionHourlyRate] AS 
        CASE 
            WHEN DATEDIFF(HOUR, SegmentStartDateTime, 
                   ISNULL(SegmentEndDateTime, GETDATE())) > 0 
            THEN BagOutActualMT / 
                 NULLIF(DATEDIFF(HOUR, SegmentStartDateTime, 
                        ISNULL(SegmentEndDateTime, GETDATE())), 0)
            ELSE 0 
        END PERSISTED;

🛡️ Security & Data Integrity
11. สร้างตาราง User Roles และ Permissions
CREATE TABLE [dbo].[UserRoles] (
    [RoleID] INT PRIMARY KEY,
    [RoleName] VARCHAR(50) NOT NULL,
    [CanEdit] BIT DEFAULT 0,
    [CanApprove] BIT DEFAULT 0,
    [CanDelete] BIT DEFAULT 0
);

CREATE TABLE [dbo].[UserPermissions] (
    [PermissionID] INT IDENTITY(1,1) PRIMARY KEY,
    [EmpId] VARCHAR(10) NOT NULL,
    [RoleID] INT NOT NULL,
    [MachineAccess] VARCHAR(MAX) -- JSON or comma-separated machine IDs
);
12. เพิ่ม Constraints และ Defaults
-- Ensure chronological order
ALTER TABLE [dbo].[ProblemRecords]
ADD CONSTRAINT [CHK_ProblemRecords_TimeOrder] 
CHECK (StartDateTime > StopDateTime);

-- Ensure positive values
ALTER TABLE [dbo].[ProductionRecords]
ADD CONSTRAINT [CHK_ProductionRecords_Positive] 
CHECK (BagOutActualMT >= 0 AND TransferToWHAggregateMT >= 0);

📈 Reporting & Analytics Enhancement
13. สร้าง Summary Tables สำหรับ Reporting
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
    PRIMARY KEY ([SummaryDate], [MachineID], [ShiftID])
);
14. เพิ่ม Column สำหรับ Calculated Metrics
ALTER TABLE [dbo].[ProductionRecords]
ADD 
    [Availability] AS 
        CASE 
            WHEN DATEDIFF(MINUTE, SegmentStartDateTime, 
                   ISNULL(SegmentEndDateTime, GETDATE())) > 0 
            THEN 1 - (SELECT SUM(CalculatedDowntimeMin) 
                     FROM ProblemRecords pr 
                     WHERE pr.ProductionRecordID = ProductionRecords.ProductionRecordID
                     AND pr.IsMachineDowntime = 1) 
                   / DATEDIFF(MINUTE, SegmentStartDateTime, 
                     ISNULL(SegmentEndDateTime, GETDATE()))
            ELSE 1 
        END,
    
    [QualityRate] AS 
        CASE 
            WHEN BagOutActualMT > 0 
            THEN 1 - (ISNULL((SELECT MetalDetectionLossKG 
                            FROM LotCompletionDetails lcd 
                            WHERE lcd.ProductionRecordID = ProductionRecords.ProductionRecordID), 0)
                     / BagOutActualMT)
            ELSE 1 
        END;

🚀 แนะนำ Implementation Priority
Phase 1: Critical (ควรทำทันที)
Audit Log table

Additional indexes

Data validation constraints

Status history tracking

Phase 2: Important (ภายใน 1-3 เดือน)
Partitioning strategy

Performance targets

Machine parameters

User roles & permissions

Phase 3: Enhancement (ภายใน 6 เดือน)
Downtime categorization hierarchy

Summary tables for reporting

Advanced calculated columns

Product/customer dimension tables

💡 Best Practices เพิ่มเติม
ใช้ Stored Procedures สำหรับทุก Data Modification

Implement Row Versioning สำหรับ Critical Tables

สร้าง Data Retention Policy (Purge ข้อมูลเก่า)

ใช้ Temporal Tables สำหรับต้องการ Track History

สร้าง Standardized Naming Convention

Document Foreign Key Relationships

การออกแบบของคุณดีอยู่แล้ว การปรับปรุงเหล่านี้จะช่วยให้ระบบ:

Scalable - รองรับข้อมูลที่เพิ่มขึ้น

Maintainable - บำรุงรักษาง่าย

Secure - ควบคุมการเข้าถึงได้

Performant - Query เร็วแม้ข้อมูลมาก

Flexible - เพิ่มฟีเจอร์ใหม่ได้ง่าย
