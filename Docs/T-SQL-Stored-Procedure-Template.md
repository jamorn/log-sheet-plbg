# 💾 Stored Procedure Template สำหรับการบันทึกข้อมูล Transaction (T-SQL)
ตามที่คุณต้องการสร้าง Stored Procedure Template สำหรับการบันทึกข้อมูล Transaction เพื่อรองรับระบบของคุณในอนาคต ผมขอเสนอโครงสร้าง Stored Procedure InsertShiftProductionRecord ซึ่งจะทำหน้าที่:

สร้าง ProductionRecords (รายการแม่)

สร้าง ProblemRecords (รายการ Downtime/Loss)

สร้าง LotCompletionDetails (รายการ Quality Loss/Waste)

-- ####################################################################
-- Stored Procedure: InsertShiftProductionRecord
-- คำอธิบาย: บันทึกข้อมูลการผลิต การหยุดเครื่อง และของเสียทั้งหมดในรอบกะ
-- ####################################################################

IF OBJECT_ID('InsertShiftProductionRecord', 'P') IS NOT NULL DROP PROCEDURE InsertShiftProductionRecord;
GO

CREATE PROCEDURE InsertShiftProductionRecord
    -- ข้อมูล ProductionRecords (Header)
    @MachineId INT,
    @ShiftID INT,
    @ShiftDate DATE,
    @SegmentStartDateTime DATETIME,
    @SegmentEndDateTime DATETIME,
    @BagOutActualMT DECIMAL(10, 3), 
    
    -- ข้อมูล Downtime/Loss Time (JSON Input)
    -- ใช้ JSON เพื่อรองรับการส่งข้อมูล Loss Time หลายรายการพร้อมกัน
    @ProblemRecordsJson NVARCHAR(MAX), 
    
    -- ข้อมูล Quality Loss (LotCompletionDetails)
    @PCCQCKG DECIMAL(10, 3) = NULL, 
    @MetalDetectionLossKG DECIMAL(10, 3) = NULL,
    @TailBag1KG DECIMAL(10, 3) = NULL,
    @TailBag2KG DECIMAL(10, 3) = NULL,
    @WasteRejectBags INT = NULL, 
    @BaggingCode VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NewProductionRecordID INT;

    -- 1. ตรวจสอบเงื่อนไขการทำงานและข้อมูลเบื้องต้น
    IF @BagOutActualMT < 0 
    BEGIN
        RAISERROR(N'BagOutActualMT ต้องไม่น้อยกว่า 0', 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- 2. INSERT ProductionRecords (รายการแม่)
        INSERT INTO ProductionRecords (
            MachineId, ShiftID, ShiftDate, SegmentStartDateTime, SegmentEndDateTime, BagOutActualMT, RecordStatus
        )
        VALUES (
            @MachineId, @ShiftID, @ShiftDate, @SegmentStartDateTime, @SegmentEndDateTime, @BagOutActualMT, 'OPEN'
        );

        SET @NewProductionRecordID = SCOPE_IDENTITY();

        -- 3. INSERT ProblemRecords (รายการ Loss/Downtime)
        -- ใช้ OPENJSON เพื่อแยกและแทรกข้อมูล Loss Time หลายรายการ
        INSERT INTO ProblemRecords (
            ProductionRecordID, ProblemTypeID, StopDateTime, StartDateTime, CalculatedDowntimeMin, IsMachineDowntime, OperatorEmpId
        )
        SELECT
            @NewProductionRecordID,
            CAST(j.ProblemTypeID AS INT),
            CAST(j.StopDateTime AS DATETIME),
            CAST(j.StartDateTime AS DATETIME),
            DATEDIFF(MINUTE, CAST(j.StopDateTime AS DATETIME), CAST(j.StartDateTime AS DATETIME)) AS CalculatedDowntimeMin, -- คำนวณ Downtime เป็นนาที
            CAST(j.IsMachineDowntime AS BIT),
            j.OperatorEmpId
        FROM OPENJSON(@ProblemRecordsJson)
        WITH (
            ProblemTypeID INT '$.ProblemTypeID',
            StopDateTime VARCHAR(50) '$.StopDateTime',
            StartDateTime VARCHAR(50) '$.StartDateTime',
            IsMachineDowntime BIT '$.IsMachineDowntime',
            OperatorEmpId VARCHAR(10) '$.OperatorEmpId'
        ) AS j;

        -- 4. INSERT LotCompletionDetails (รายการ Quality Loss/Waste)
        IF @PCCQCKG IS NOT NULL OR @WasteRejectBags IS NOT NULL
        BEGIN
            INSERT INTO LotCompletionDetails (
                ProductionRecordID, PCCQCKG, MetalDetectionLossKG, TailBag1KG, TailBag2KG, WasteRejectBags, BaggingCode
            )
            VALUES (
                @NewProductionRecordID, @PCCQCKG, @MetalDetectionLossKG, @TailBag1KG, @TailBag2KG, @WasteRejectBags, @BaggingCode
            );
        END

        COMMIT TRANSACTION;
        SELECT @NewProductionRecordID AS ProductionRecordID; -- ส่ง ProductionRecordID ที่สร้างขึ้นกลับไป

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- ส่งข้อผิดพลาดกลับไป
        THROW;
        RETURN;
    END CATCH
END
GO

📋 ตัวอย่างการเรียกใช้งาน (Example Usage)
สมมติว่าคุณต้องการบันทึกการผลิตสำหรับเครื่อง PP3/A (MachineId 3) ในกะ 1 (ShiftID 1) และมีรายการหยุด 2 รายการ (PM 60 นาที และ Breakdown 15 นาที)

JSON สำหรับ Downtime/Loss Time (@ProblemRecordsJson)
[
  {
    "ProblemTypeID": 101, 
    "StopDateTime": "2025-12-16 06:00:00",
    "StartDateTime": "2025-12-16 07:00:00",
    "IsMachineDowntime": 0, 
    "OperatorEmpId": "12345" 
  },
  {
    "ProblemTypeID": 201, 
    "StopDateTime": "2025-12-16 09:30:00",
    "StartDateTime": "2025-12-16 09:45:00",
    "IsMachineDowntime": 1, 
    "OperatorEmpId": "12345"
  }
]