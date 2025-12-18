CREATE PROCEDURE CalculateAllMachinesOeeSummary
    @ShiftDate DATE,
    @BaggingCode VARCHAR(10) = NULL,  -- คำนวณเฉพาะ Bagging ไหน
    @UnitId INT = NULL,               -- คำนวณเฉพาะ Unit ไหน
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MachineId INT;
    DECLARE @MachineName VARCHAR(10);
    DECLARE @Results TABLE (
        MachineId INT,
        MachineName VARCHAR(10),
        Status VARCHAR(20),
        OEE DECIMAL(5,2),
        Message NVARCHAR(500)
    );
    
    -- Get machines to calculate
    DECLARE MachineCursor CURSOR FOR
        SELECT m.MachineId, m.MachineName
        FROM Machines m
        INNER JOIN UnitPLBG u ON m.UnitId = u.UnitId
        WHERE m.MachineActive = 1
          AND (@BaggingCode IS NULL OR u.BaggingCode = @BaggingCode)
          AND (@UnitId IS NULL OR m.UnitId = @UnitId);
    
    OPEN MachineCursor;
    FETCH NEXT FROM MachineCursor INTO @MachineId, @MachineName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Call individual calculation
            EXEC CalculateDailyOeeSummary 
                @ShiftDate = @ShiftDate,
                @MachineId = @MachineId,
                @DebugMode = @DebugMode;
            
            INSERT INTO @Results VALUES (@MachineId, @MachineName, 'SUCCESS', NULL, 'Calculated successfully');
        END TRY
        BEGIN CATCH
            -- Log error but continue with other machines
            DECLARE @ErrorMsg NVARCHAR(500) = ERROR_MESSAGE();
            INSERT INTO @Results VALUES (@MachineId, @MachineName, 'ERROR', NULL, @ErrorMsg);
            
            IF @DebugMode = 1
                PRINT 'Error calculating for machine ' + @MachineName + ' (' + CAST(@MachineId AS VARCHAR) + '): ' + @ErrorMsg;
        END CATCH
        
        FETCH NEXT FROM MachineCursor INTO @MachineId, @MachineName;
    END
    
    CLOSE MachineCursor;
    DEALLOCATE MachineCursor;
    
    -- Return summary
    SELECT 
        COUNT(*) AS TotalMachines,
        SUM(CASE WHEN Status = 'SUCCESS' THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN Status = 'ERROR' THEN 1 ELSE 0 END) AS ErrorCount
    FROM @Results;
    
    -- Show detailed results if debug mode
    IF @DebugMode = 1
    BEGIN
        SELECT * FROM @Results ORDER BY Status, MachineId;
    END
END
GO

# Function สำหรับดูข้อมูล OEE Summary (เรียกใช้ง่าย)
CREATE FUNCTION dbo.GetOeeSummary
(
    @StartDate DATE,
    @EndDate DATE,
    @MachineId INT = NULL,
    @UnitId INT = NULL,
    @BaggingCode VARCHAR(10) = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        ds.ShiftDate,
        ds.MachineID,
        m.MachineName,
        m.MachineLine,
        ds.UnitId,
        u.UnitName,
        u.BaggingCode,
        bl.BaggingName,
        
        -- OEE Components
        ds.Target_OEE_Pct,
        ds.Availability_Pct,
        ds.Performance_Pct,
        ds.Quality_Pct,
        ds.OEE_Percentage,
        ds.OEE_TargetMet,
        
        -- Production Data
        ds.ActualOutputMT,
        ds.GoodBags,
        ds.WasteBags,
        
        -- Time Analysis
        ds.TotalTimeMin,
        ds.PlannedProductionTimeMin,
        ds.OperatingTimeMin,
        ds.PlannedLossMin,
        ds.UnplannedLossMin,
        ds.SpeedLossMin,
        
        -- Downtime Info
        ds.Top_Downtime_Reason,
        ds.TotalDowntimeEvents,
        
        -- Status
        ds.DataStatus,
        ds.LastCalculated
        
    FROM DailyProductionSummary ds
    INNER JOIN Machines m ON ds.MachineID = m.MachineId
    INNER JOIN UnitPLBG u ON ds.UnitId = u.UnitId
    INNER JOIN BaggingLocations bl ON u.BaggingCode = bl.BaggingCode
    WHERE ds.ShiftDate BETWEEN @StartDate AND @EndDate
      AND (@MachineId IS NULL OR ds.MachineID = @MachineId)
      AND (@UnitId IS NULL OR ds.UnitId = @UnitId)
      AND (@BaggingCode IS NULL OR u.BaggingCode = @BaggingCode)
);
GO