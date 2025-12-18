// Database Design for Bagging Logsheet / OEE System (Final Corrected Update: 14 Tables)

// ***************************************************************
// 1. ตาราง Master และ Lookup (5 + 2 Tables)
// ***************************************************************

Table Machines {
  MachineID int [pk]
  MachineName varchar(10) [unique, not null]
  MachineLine varchar(1)
  CostCenterCode varchar(10)
  MachineActive boolean
}

Table Shifts {
  ShiftID int [pk]
  ShiftCode varchar(1) [unique, not null] // M, E, N
  ShiftTimeStart time
  ShiftTimeEnd time
}

Table EmployeeDetails {
  EmpId varchar(10) [pk]
  FullNameTH nvarchar(100)
  FullNameEN varchar(100)
  Email varchar(100)
  ThPosition nvarchar(100)
  EnPosition varchar(100)
  Role varchar(50)
}

Table OrderStatusLookup {
  StatusID int [pk]
  StatusNameTH nvarchar(50) [not null]
  IsComplete boolean
}

Table ProblemTypes {
  ProblemTypeID int [pk]
  TypeNameTH nvarchar(50) [not null]
  IsDowntime boolean
}

// ตารางใหม่: DowntimeCategories (Multi-Level Hierarchy)
Table DowntimeCategories {
  CategoryID int [pk]
  ParentCategoryID int [null] // FK defined in Ref
  CategoryNameTH nvarchar(100) [not null]
  CategoryLevel int [not null]
  IsActive boolean
}

// ตารางใหม่: User Roles (สำหรับ Security)
Table UserRoles {
  RoleID int [pk]
  RoleName varchar(50) [not null]
  CanEdit boolean
  CanApprove boolean
  CanDelete boolean
}


// ***************************************************************
// 2. ตาราง Transaction หลัก (5 Tables)
// ***************************************************************

// ตาราง ProductionOrders (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table ProductionOrders {
  LotNo varchar(20) [pk]
  OrderDate date
  PlannedQuantityMT decimal(10, 3)
  CurrentStatusID int

  // Planning & Audit Fields
  ProductCode varchar(20)
  CustomerCode varchar(20)
  PlannedStartDate date
  PlannedEndDate date
  Priority int
  CreatedBy varchar(10)
  CreatedDate datetime
  LastModifiedBy varchar(10)
  LastModifiedDate datetime
  ActualCompletionDate datetime [null]
}

// ตาราง ProductionRecords (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table ProductionRecords {
  ProductionRecordID int [pk, increment]
  LotNo varchar(20) [not null]
  SegmentSequence int [not null]
  MachineID int [not null]
  ShiftDate date [not null]
  ShiftID int [not null]
  
  BagOutActualMT decimal(10, 3)
  TransferToWHAggregateMT decimal(10, 3)
  DepositedInBaggingMT decimal(10, 3)
  
  SegmentStartDateTime datetime [not null]
  SegmentEndDateTime datetime [null]
  IsCompleted boolean

  // Computed Column
  SegmentDurationMin int [note: 'DATEDIFF(MINUTE, Start, End)']

  Indexes {
    (LotNo, SegmentSequence) [unique]
  }
}

// ตาราง LotCompletionDetails
Table LotCompletionDetails {
  ProductionRecordID int [pk]
  PCCQCKG decimal(10, 2)
  MetalDetectionLossKG decimal(10, 2)
  TailBag1KG decimal(10, 2)
  TailBag2KG decimal(10, 2)
  Remark nvarchar(MAX)
}

// ตาราง ProblemRecords (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table ProblemRecords {
  ProblemRecordID int [pk, increment]
  ProductionRecordID int [not null]
  ProblemTypeID int [not null]
  DowntimeCategoryID int [null] // New: Detailed Category
  
  StopDateTime datetime [not null]
  StartDateTime datetime [not null]
  CalculatedDowntimeMin decimal(5, 2) [not null]
  ShiftDate date [not null]
  CalculatedShiftID int [not null]
  IsMachineDowntime boolean
  
  // Problem Solving & Audit
  RootCauseCode varchar(20)
  ActionTaken nvarchar(500)
  ResponsibleDept varchar(50)
  IsVerified boolean
  VerifiedBy varchar(10)
  VerifiedDate datetime
  OperatorEmpId varchar(10)
}

// ตาราง InventoryCutoff (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table InventoryCutoff {
  CutoffID int [pk, increment]
  CutoffTypeID int [not null]
  CutoffDateTime datetime [not null]
  LotNo varchar(20) [not null]
  FilmLotNo varchar(20)
  EndingFilmInventoryKG decimal(10, 2)
  ShiftDate date [not null]
  ShiftID int [not null]
  OperatorEmpId varchar(10)
}


// ***************************************************************
// 3. ตารางใหม่สำหรับการวิเคราะห์และ Audit (7 Tables)
// ***************************************************************

// ตารางใหม่: AuditLog (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table AuditLog {
  AuditID int [pk, increment]
  TableName varchar(100) [not null]
  RecordID varchar(100) [not null]
  Action char(1) [not null] // I/U/D
  OldValues nvarchar(MAX)
  NewValues nvarchar(MAX)
  ChangedBy varchar(10) [not null]
  ChangedDateTime datetime
}

// ตารางใหม่: ProductionOrderStatusHistory (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table ProductionOrderStatusHistory {
  HistoryID int [pk, increment]
  LotNo varchar(20) [not null]
  FromStatusID int [null]
  ToStatusID int [not null]
  ChangedBy varchar(10)
  ChangedDateTime datetime
  Remark nvarchar(500)
}

// ตารางใหม่: MachineParameters (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table MachineParameters {
  ParameterID int [pk, increment]
  MachineID int [not null]
  ParameterName nvarchar(100) [not null]
  ParameterValue decimal(10,3)
  UOM varchar(10)
  ValidFrom datetime [not null]
  ValidTo datetime [null]
}

// ตารางใหม่: PerformanceTargets (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table PerformanceTargets {
  TargetID int [pk, increment]
  MachineID int
  ShiftID int
  ProductCode varchar(20)
  EffectiveDate date [not null]
  TargetOEE decimal(5,2)
  TargetOutput decimal(10,3)
  TargetDowntime decimal(5,2)
  IsActive boolean
}

// ตารางใหม่: DailyProductionSummary (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table DailyProductionSummary {
    SummaryDate date [pk]
    MachineID int [pk]
    ShiftID int [pk]
    TotalBagsOut decimal(10,3)
    TotalDowntimeMin decimal(10,2)
    OEE decimal(5,2)
    FilmConsumptionKG decimal(10,2)
    LastUpdated datetime
}

// ตารางใหม่: UserPermissions (ปรับปรุง: ไม่มี [fk] ในคอลัมน์)
Table UserPermissions {
    PermissionID int [pk, increment]
    EmpId varchar(10) [not null]
    RoleID int [not null]
    MachineAccess varchar(MAX) // JSON or comma-separated machine IDs
}


// ***************************************************************
// 4. ความสัมพันธ์ (Relationships) - กำหนด FK ทั้งหมดที่นี่
// ***************************************************************

// ProductionOrders
Ref: ProductionOrders.CurrentStatusID > OrderStatusLookup.StatusID
Ref: ProductionOrders.CreatedBy > EmployeeDetails.EmpId
Ref: ProductionOrders.LastModifiedBy > EmployeeDetails.EmpId

// ProductionRecords
Ref: ProductionRecords.LotNo > ProductionOrders.LotNo
Ref: ProductionRecords.MachineID > Machines.MachineID
Ref: ProductionRecords.ShiftID > Shifts.ShiftID

// LotCompletionDetails
Ref: LotCompletionDetails.ProductionRecordID <> ProductionRecords.ProductionRecordID

// ProblemRecords
Ref: ProblemRecords.ProductionRecordID > ProductionRecords.ProductionRecordID
Ref: ProblemRecords.ProblemTypeID > ProblemTypes.ProblemTypeID
Ref: ProblemRecords.DowntimeCategoryID > DowntimeCategories.CategoryID
Ref: ProblemRecords.CalculatedShiftID > Shifts.ShiftID
Ref: ProblemRecords.OperatorEmpId > EmployeeDetails.EmpId
Ref: ProblemRecords.VerifiedBy > EmployeeDetails.EmpId

// InventoryCutoff
Ref: InventoryCutoff.ShiftID > Shifts.ShiftID
Ref: InventoryCutoff.OperatorEmpId > EmployeeDetails.EmpId

// DowntimeCategories (Self-Referencing)
Ref: DowntimeCategories.ParentCategoryID > DowntimeCategories.CategoryID

// AuditLog
Ref: AuditLog.ChangedBy > EmployeeDetails.EmpId

// ProductionOrderStatusHistory
Ref: ProductionOrderStatusHistory.LotNo > ProductionOrders.LotNo
Ref: ProductionOrderStatusHistory.FromStatusID > OrderStatusLookup.StatusID
Ref: ProductionOrderStatusHistory.ToStatusID > OrderStatusLookup.StatusID
Ref: ProductionOrderStatusHistory.ChangedBy > EmployeeDetails.EmpId

// MachineParameters
Ref: MachineParameters.MachineID > Machines.MachineID

// PerformanceTargets
Ref: PerformanceTargets.MachineID > Machines.MachineID
Ref: PerformanceTargets.ShiftID > Shifts.ShiftID

// DailyProductionSummary
Ref: DailyProductionSummary.MachineID > Machines.MachineID
Ref: DailyProductionSummary.ShiftID > Shifts.ShiftID

// UserPermissions
Ref: UserPermissions.EmpId > EmployeeDetails.EmpId
Ref: UserPermissions.RoleID > UserRoles.RoleID