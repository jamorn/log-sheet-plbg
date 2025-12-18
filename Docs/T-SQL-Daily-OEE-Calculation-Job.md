Stored Procedure CalculateDailyOeeSummary ทุกวัน เวลา 06:30 น. โดยจะคำนวณข้อมูลสำหรับ วันก่อนหน้า (Yesterday) ตามความต้องการของระบบสรุปผลกะดึก

กะ	ช่วงเวลาตามจริง	วันที่บันทึกใน ProductionRecords
เช้า	06:00 - 14:00 น.	วันที่สรุปผล (@ShiftDate)
บ่าย	14:00 - 22:00 น.	วันที่สรุปผล (@ShiftDate)
ดึก	22:00 - 06:00 น.	วันที่สรุปผล (@ShiftDate)



-- เปลี่ยนชื่อฐานข้อมูลของคุณในส่วนนี้
USE msdb;
GO

-- =================================================================
-- 1. กำหนดตัวแปรสำหรับ Job
-- =================================================================
DECLARE @JobName SYSNAME = N'OEE_Daily_Summary_Calculation';
DECLARE @StepName SYSNAME = N'Run OEE Calculation for Yesterday';
DECLARE @ScheduleName SYSNAME = N'Daily_0630_Schedule';
DECLARE @DatabaseName SYSNAME = N'ชื่อฐานข้อมูลของคุณ'; -- *** แก้ไขชื่อฐานข้อมูลของคุณที่นี่ ***
DECLARE @MachineId INT = 1; -- กำหนด MachineId เริ่มต้น (อาจต้องวนลูปถ้ามีหลายเครื่อง)
DECLARE @JobId UNIQUEIDENTIFIER;

-- =================================================================
-- 2. การสร้าง SQL Server Agent Job
-- =================================================================

-- ลบ Job เก่าออกก่อนถ้ามีอยู่แล้ว เพื่อหลีกเลี่ยงข้อผิดพลาด
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
END

-- สร้าง Job ใหม่
EXEC msdb.dbo.sp_add_job
    @job_name = @JobName,
    @enabled = 1, -- เปิดใช้งาน Job ทันที
    @description = N'Job สำหรับเรียก Stored Procedure CalculateDailyOeeSummary เพื่อสรุปผล OEE ประจำวันก่อนหน้า',
    @category = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa', -- หรือชื่อ Login ที่มีสิทธิ์ DBA
    @job_id = @JobId OUTPUT;

-- =================================================================
-- 3. การสร้าง Job Step (ขั้นตอนการทำงาน)
-- =================================================================

-- T-SQL Command สำหรับเรียก SP
-- DATEDIFF(day, 1, GETDATE()) คือการคำนวณวันที่ของ "วันก่อนหน้า" (Yesterday)
-- โค้ดนี้ถูกออกแบบมาเพื่อรองรับการมีหลาย MachineID โดยใช้ Cursor หรือ LOOP
DECLARE @Command NVARCHAR(MAX) = N'
DECLARE @Yesterday DATE = DATEADD(day, -1, CAST(GETDATE() AS DATE));
DECLARE @CurrentMachineId INT;
DECLARE @MachineIds TABLE (MachineId INT PRIMARY KEY);
INSERT INTO @MachineIds (MachineId)
SELECT MachineId FROM [dbo].[Machines] WHERE IsActive = 1; -- ดึงทุกเครื่องที่ Active

-- วนลูปเพื่อเรียก SP สำหรับทุก MachineID
DECLARE MachineCursor CURSOR FOR 
SELECT MachineId FROM @MachineIds ORDER BY MachineId;

OPEN MachineCursor;
FETCH NEXT FROM MachineCursor INTO @CurrentMachineId;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC ' + QUOTENAME(@DatabaseName) + N'.[dbo].[CalculateDailyOeeSummary] 
        @ShiftDate = @Yesterday, 
        @MachineId = @CurrentMachineId;
    
    FETCH NEXT FROM MachineCursor INTO @CurrentMachineId;
END

CLOSE MachineCursor;
DEALLOCATE MachineCursor;';

EXEC msdb.dbo.sp_add_jobstep
    @job_id = @JobId,
    @step_name = @StepName,
    @step_id = 1,
    @cmdexec_success_code = 0,
    @on_success_action = 1, -- ทำงานสำเร็จ -> ออกจาก Job
    @on_fail_action = 2,    -- ทำงานล้มเหลว -> หยุด Job และรายงาน
    @subsystem = N'TSQL',
    @command = @Command,
    @database_name = @DatabaseName,
    @flags = 0;

-- =================================================================
-- 4. การสร้าง Job Schedule (ตารางเวลา)
-- =================================================================

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = @ScheduleName,
    @enabled = 1,
    @freq_type = 4,             -- 4 = Daily (ทำงานทุกวัน)
    @freq_interval = 1,         -- ทำงานทุก 1 วัน
    @active_start_time = 063000, -- เวลาเริ่มต้น: 06:30:00 AM (HHMMSS)
    @schedule_id = @JobId OUTPUT;

-- ผูก Job กับ Schedule
EXEC msdb.dbo.sp_attach_schedule
    @job_name = @JobName,
    @schedule_name = @ScheduleName;

-- =================================================================
-- 5. การตั้งค่า Job Server (Finalize)
-- =================================================================

EXEC msdb.dbo.sp_add_jobserver
    @job_name = @JobName,
    @server_name = N'(local)'; -- รันบนเซิร์ฟเวอร์ปัจจุบัน

GO

-- =================================================================
-- 6. การตรวจสอบ (Verification)
-- =================================================================
SELECT name, is_enabled, date_created, date_modified 
FROM msdb.dbo.sysjobs 
WHERE name = N'OEE_Daily_Summary_Calculation';
GO