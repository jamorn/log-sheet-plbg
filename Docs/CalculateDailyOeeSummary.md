# 🎯 หลักการคำนวณที่ใช้ใน Stored ProcedureScope: คำนวณ OEE สำหรับ ShiftDate และ MachineId ที่กำหนดTotal Time (Total Time): รวมเวลาทั้งหมดของกะ (480 นาที/กะ) สำหรับวันนั้นLoss Time Gathering:Planned Loss (Category 10): นำไปหักจาก Total Time เพื่อหา Loading TimeUnplanned Loss (Category 20): นำไปหักจาก Loading Time เพื่อหา Operation TimeQuality Loss (Category 30): นำไปใช้หักออกจาก Actual Count เพื่อหา Good CountTarget RPM: ดึง StandardRPM และ BagWeightKG จากตาราง MachinesTarget OEE: ดึง Oee_Target จากตาราง KpiTargetsสูตรหลัก (T-SQL implementation):$A = \frac{\text{Operation Time}}{\text{Loading Time}}$$P = \frac{(\text{Cycle Time} \times \text{Actual Bags})}{\text{Operation Time}}$$Q = \frac{\text{Good Bags}}{\text{Actual Bags}}$$OEE = A \times P \times Q$💾 T-SQL Stored Procedure: CalculateDailyOeeSummary

# 💾 T-SQL Stored Procedure: CalculateDailyOeeSummary
-- ####################################################################
-- Stored Procedure: CalculateDailyOeeSummary
-- คำอธิบาย: คำนวณ OEE รายวัน/รายเครื่อง และบันทึกผลลัพธ์ลงใน DailyProductionSummary
-- ####################################################################

IF OBJECT_ID('CalculateDailyOeeSummary', 'P') IS NOT NULL DROP PROCEDURE CalculateDailyOeeSummary;
GO

CREATE PROCEDURE CalculateDailyOeeSummary
    @ShiftDate DATE,
    @MachineId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Declaration of Variables
    DECLARE @TotalTimeMin INT = 0;
    DECLARE @PlannedLossMin DECIMAL(10, 2) = 0;
    DECLARE @UnplannedLossMin DECIMAL(10, 2) = 0;
    
    DECLARE @StandardRPM INT;
    DECLARE @BagWeightKG DECIMAL(5, 2);
    DECLARE @CycleTimeSec DECIMAL(10, 4); -- 60 / RPM
    
    DECLARE @ActualBags DECIMAL(10, 2) = 0;
    DECLARE @WasteBags INT = 0;
    DECLARE @TargetOEE DECIMAL(5, 2);
    
    DECLARE @LoadingTime DECIMAL(10, 2);
    DECLARE @OperationTime DECIMAL(10, 2);
    DECLARE @IdealTime DECIMAL(10, 2);
    
    -- OEE Results
    DECLARE @Availability DECIMAL(5, 2);
    DECLARE @Performance DECIMAL(5, 2);
    DECLARE @Quality DECIMAL(5, 2);
    DECLARE @OEE_Final DECIMAL(5, 2);
    DECLARE @TopDowntime NVARCHAR(255);

    -- 2. Fetch Machine Configuration (RPM, Bag Weight)
    SELECT 
        @StandardRPM = M.StandardRPM,
        @BagWeightKG = M.BagWeightKG,
        @CycleTimeSec = 60.0 / M.StandardRPM -- Cycle time in minutes/bag (for Performance calculation)
    FROM Machines M
    WHERE M.MachineId = @MachineId;

    -- 3. Fetch Target OEE
    SELECT TOP 1 @TargetOEE = T.Oee_Target
    FROM KpiTargets T
    JOIN Machines M ON M.UnitId = T.UnitId
    WHERE M.MachineId = @MachineId AND T.[Year] = YEAR(@ShiftDate)
    ORDER BY T.Item DESC; -- ใช้เป้าหมายล่าสุดของปีนั้น

    -- 4. Calculate Total Available Time (Assuming 3 shifts/day = 24 hours * 60 min = 1440 min, or based on actual shifts)
    -- *** NOTE: ในตัวอย่าง JS ของคุณใช้ 480 นาทีต่อการคำนวณ (1 กะ) แต่ Daily Summary ควรใช้รวม 3 กะ ***
    -- เราจะใช้ Total Minutes จาก ProductionRecords ที่บันทึกไว้ในวันนั้น
    SELECT 
        @TotalTimeMin = SUM(DATEDIFF(MINUTE, PR.SegmentStartDateTime, PR.SegmentEndDateTime))
    FROM ProductionRecords PR
    WHERE PR.MachineId = @MachineId AND PR.ShiftDate = @ShiftDate;

    IF @TotalTimeMin IS NULL OR @TotalTimeMin = 0
    BEGIN
        -- ไม่มีข้อมูลการผลิตสำหรับวันนั้น
        RETURN;
    END

    -- 5. Calculate Loss Times (Grouped by Category ID)
    
    -- Planned Loss (Category 10)
    SELECT @PlannedLossMin = SUM(DATEDIFF(MINUTE, PRB.StopDateTime, PRB.StartDateTime))
    FROM ProblemRecords PRB
    JOIN ProductionRecords PR ON PRB.ProductionRecordID = PR.ProductionRecordID
    JOIN OeeLossTypes OLT ON PRB.ProblemTypeID = OLT.ProblemTypeID
    WHERE PR.MachineId = @MachineId 
      AND PR.ShiftDate = @ShiftDate 
      AND OLT.CategoryID = 10;
    SET @PlannedLossMin = ISNULL(@PlannedLossMin, 0);

    -- Unplanned/Minor Stop Loss (Category 20)
    SELECT @UnplannedLossMin = SUM(DATEDIFF(MINUTE, PRB.StopDateTime, PRB.StartDateTime))
    FROM ProblemRecords PRB
    JOIN ProductionRecords PR ON PRB.ProductionRecordID = PR.ProductionRecordID
    JOIN OeeLossTypes OLT ON PRB.ProblemTypeID = OLT.ProblemTypeID
    WHERE PR.MachineId = @MachineId 
      AND PR.ShiftDate = @ShiftDate 
      AND OLT.CategoryID = 20;
    SET @UnplannedLossMin = ISNULL(@UnplannedLossMin, 0);

    -- Actual Production Bags and Quality Loss Bags (Category 30)
    SELECT 
        @ActualBags = SUM(PR.BagOutActualMT * 1000 / @BagWeightKG), -- (MT * 1000 / KG_PER_BAG)
        @WasteBags = SUM(ISNULL(LCD.WasteRejectBags, 0))
    FROM ProductionRecords PR
    LEFT JOIN LotCompletionDetails LCD ON PR.ProductionRecordID = LCD.ProductionRecordID
    WHERE PR.MachineId = @MachineId AND PR.ShiftDate = @ShiftDate;
    SET @ActualBags = ISNULL(@ActualBags, 0);
    SET @WasteBags = ISNULL(@WasteBags, 0);
    
    -- 6. OEE Calculation (Based on your JS Logic)
    
    -- Loading Time (เวลาเดินเครื่องตามแผน)
    SET @LoadingTime = @TotalTimeMin - @PlannedLossMin;
    
    -- Operation Time (เวลาเดินเครื่องจริง)
    SET @OperationTime = @LoadingTime - @UnplannedLossMin;
    
    -- Availability (A)
    SET @Availability = 
        CASE WHEN @LoadingTime > 0 THEN (@OperationTime / @LoadingTime) * 100.0 ELSE 0.0 END;

    -- Performance (P)
    -- Ideal Time = Actual Bags * Cycle Time (min/bag)
    SET @IdealTime = (@ActualBags * (@CycleTimeSec / 60.0)); -- Conversion to Minutes
    
    SET @Performance = 
        CASE WHEN @OperationTime > 0 THEN (@IdealTime / @OperationTime) * 100.0 ELSE 0.0 END;
    
    -- Clamp Performance at 200% max, as per your JS
    IF @Performance > 200 SET @Performance = 200.0;
    
    -- Quality (Q)
    SET @Quality = 
        CASE WHEN @ActualBags > 0 THEN ((@ActualBags - @WasteBags) / @ActualBags) * 100.0 ELSE 0.0 END;
    
    -- Clamp Quality at 100% max, as per your JS
    IF @Quality > 100 SET @Quality = 100.0;

    -- Final OEE
    SET @OEE_Final = (@Availability / 100.0) * (@Performance / 100.0) * (@Quality / 100.0) * 100.0;

    -- 7. Determine Top Downtime Reason (Optional, but useful for summary)
    SELECT TOP 1 @TopDowntime = OLT.TypeNameTH
    FROM ProblemRecords PRB
    JOIN ProductionRecords PR ON PRB.ProductionRecordID = PR.ProductionRecordID
    JOIN OeeLossTypes OLT ON PRB.ProblemTypeID = OLT.ProblemTypeID
    WHERE PR.MachineId = @MachineId 
      AND PR.ShiftDate = @ShiftDate 
      AND OLT.CategoryID IN (10, 20) -- Focus on Time Loss
    GROUP BY OLT.TypeNameTH
    ORDER BY SUM(DATEDIFF(MINUTE, PRB.StopDateTime, PRB.StartDateTime)) DESC;

    -- 8. Save or Update Summary Table
    
    IF EXISTS (SELECT 1 FROM DailyProductionSummary WHERE ShiftDate = @ShiftDate AND MachineID = @MachineId)
    BEGIN
        -- Update existing record
        UPDATE DailyProductionSummary
        SET
            Target_OEE_Pct = @TargetOEE,
            Availability_Pct = ROUND(@Availability, 2),
            Performance_Pct = ROUND(@Performance, 2),
            Quality_Pct = ROUND(@Quality, 2),
            OEE_Percentage = ROUND(@OEE_Final, 2),
            OEE_TargetMet = CASE WHEN @OEE_Final >= @TargetOEE THEN 1 ELSE 0 END,
            Top_Downtime_Reason = @TopDowntime
        WHERE ShiftDate = @ShiftDate AND MachineID = @MachineId;
    END
    ELSE
    BEGIN
        -- Insert new record
        INSERT INTO DailyProductionSummary (
            ShiftDate, MachineID, UnitId, Target_OEE_Pct, Availability_Pct, Performance_Pct, 
            Quality_Pct, OEE_Percentage, OEE_TargetMet, Top_Downtime_Reason
        )
        SELECT
            @ShiftDate, 
            @MachineId, 
            M.UnitId, 
            @TargetOEE,
            ROUND(@Availability, 2),
            ROUND(@Performance, 2),
            ROUND(@Quality, 2),
            ROUND(@OEE_Final, 2),
            CASE WHEN @OEE_Final >= @TargetOEE THEN 1 ELSE 0 END,
            @TopDowntime
        FROM Machines M WHERE M.MachineId = @MachineId;
    END

    -- Return calculated values (Optional: for testing/logging)
    SELECT 
        @TotalTimeMin AS TotalTimeMin,
        @PlannedLossMin AS PlannedLossMin,
        @UnplannedLossMin AS UnplannedLossMin,
        @LoadingTime AS LoadingTimeMin,
        @OperationTime AS OperationTimeMin,
        @ActualBags AS ActualBags,
        @WasteBags AS WasteBags,
        ROUND(@Availability, 2) AS Availability,
        ROUND(@Performance, 2) AS Performance,
        ROUND(@Quality, 2) AS Quality,
        ROUND(@OEE_Final, 2) AS OEE_Result;

END
GO