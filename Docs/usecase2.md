Q : การ หา OEE รวม ทั้ง 3 กะรวมกัน ใน 1 วันทำได้ไหมครับ ผมกังวล กะดึก ที่มีการทำงานข้ามวัน จะหาค่าอย่างไร
A: 🧐 การวิเคราะห์ปัญหา: OEE รวม 3 กะข้ามวัน (Shift Crossover)
การคำนวณ OEE รวมทั้ง 3 กะ ใน 1 วัน (24 ชั่วโมง) จำเป็นต้องมีการกำหนด "วันทางธุรกิจ" (Business Day) หรือ "วันทางบัญชี" (Accounting Day) ที่ชัดเจน

ปัญหาที่เกิดขึ้น:
กะ,เวลาเริ่มต้น (ปกติ),เวลาสิ้นสุด (ปกติ),ปัญหา
A (เช้า),08:00,16:00,ไม่มีปัญหา
B (บ่าย),16:00,24:00,ไม่มีปัญหา
C (ดึก),24:00 (เที่ยงคืน),08:00 (เช้าวันใหม่),กิจกรรมส่วนใหญ่ (8 ชั่วโมง) อยู่ในวันถัดไป แต่ผลผลิตเป็นของวันรายงานเมื่อวาน

🔑 วิธีแก้ปัญหา: การกำหนด ShiftDate เป็นหลัก
ในโครงสร้างฐานข้อมูลที่คุณออกแบบไว้ ตาราง ProductionRecords และ ProblemRecords มีคอลัมน์สำคัญคือ ShiftDate และ ShiftID

แนวทางที่ถูกต้องสำหรับการจัดการกะดึก:

กำหนดเกณฑ์การรายงาน (Reporting Date): ระบบจะต้องกำหนดให้ผลผลิตและ Downtime ทั้งหมดของ กะดึก (Shift C) ที่เริ่มทำงานในวันที่ 15 ธ.ค. เวลา 24:00 (หรือ 00:00 วันที่ 16 ธ.ค.) ถูกรายงานว่าอยู่ใน ShiftDate ของวันที่ 15 ธ.ค. .

Logic การบันทึกข้อมูล:

Shift A (08:00 - 16:00): ShiftDate = วันที่ผลิตจริง

Shift B (16:00 - 24:00): ShiftDate = วันที่ผลิตจริง

Shift C (24:00 - 08:00): ShiftDate = วันที่ทำงานส่วนใหญ่ (วันที่เริ่มทำงาน)

ตัวอย่าง: หากกะ C เริ่ม 00:00 ของวันที่ 16 ธ.ค. ข้อมูลทั้งหมดจะถูกบันทึกด้วย ShiftDate เป็น 15 ธ.ค.

🎯 การหา OEE รวม 3 กะใน 1 วัน (T-SQL Logic)
เมื่อข้อมูลถูกบันทึกตามแนวทางข้างต้นแล้ว การหา OEE รวม 3 กะในวันใดวันหนึ่งจะง่ายมาก โดยการใช้ GROUP BY ShiftDate

1. การกำหนด Total Time สำหรับ 24 ชั่วโมง
สำหรับการคำนวณ OEE รวมรายวัน, Total Time (Potential Time) คือ 24 ชั่วโมง (1440 นาที)

2. Logic การ Query สำหรับ OEE รายวัน
คุณต้องใช้ Aggregate Functions (SUM) เพื่อรวมข้อมูลจากทุกกะในวันนั้น:
SQL :
-- Pseudo-code Logic สำหรับ OEE รายวัน (24 ชั่วโมง)
SELECT
    PR.ShiftDate,
    1440 AS Total_Time_Min, -- 24 hours * 60 min
    
    -- 1. Calculated Loading Time (Total Time - Planned Loss)
    SUM(CASE WHEN DC.CategoryLevel = 1 AND DC.CategoryNameTH = N'Planned Loss' THEN P.CalculatedDowntimeMin ELSE 0 END) AS Total_Planned_Loss,
    
    -- 2. Calculated Operation Time
    SUM(CASE WHEN P.IsMachineDowntime = 1 THEN P.CalculatedDowntimeMin ELSE 0 END) AS Total_Unplanned_Downtime,

    -- 3. Calculated Production & Quality
    SUM(PR.BagOutActualMT) AS Total_Production_KG,
    SUM(LCD.PCCQCKG + LCD.MetalDetectionLossKG) AS Total_Waste_KG -- ต้องรวม Waste ทั้งหมด

-- จากตารางหลักของ Transaction
FROM
    ProductionRecords PR
INNER JOIN
    ProblemRecords P ON PR.ProductionRecordID = P.ProductionRecordID
LEFT JOIN
    DowntimeCategories DC ON P.DowntimeCategoryID = DC.CategoryID
LEFT JOIN
    LotCompletionDetails LCD ON PR.ProductionRecordID = LCD.ProductionRecordID
    
-- กำหนดวันรายงาน
WHERE
    PR.ShiftDate = '2025-12-15' -- หรือช่วงวันที่ที่ต้องการ
    
-- จัดกลุ่มผลลัพธ์
GROUP BY
    PR.ShiftDate

 # สูตรคำนวณใน Stored Procedure/View:$$\text{Loading Time} = 1440 - \text{Total Planned Loss}$$$$\text{Operation Time} = \text{Loading Time} - \text{Total Unplanned Downtime}$$$$\text{Availability} = \frac{\text{Operation Time}}{\text{Loading Time}}$$$$\text{Performance} = \frac{(\text{Total Production KG} / \text{BAG WEIGHT}) \times \text{Ideal Cycle Time}}{Operation Time}$$$$\text{Quality} = \frac{\text{Total Production KG} - \text{Total Waste KG}}{\text{Total Production KG}}$$$$\text{OEE} = \text{Availability} \times \text{Performance} \times \text{Quality}$$ด้วยการใช้ ShiftDate เป็นตัวควบคุมหลักในการจัดกลุ่มข้อมูล คุณสามารถคำนวณ OEE รวม 3 กะได้อย่างสมบูรณ์ โดยไม่ต้องกังวลเรื่องการทำงานข้ามวันของกะดึกครับ   

 เมื่อผมแสดง "สูตรคำนวณ" ให้คุณดู นั่นคือการแสดง Logic และสมการทางคณิตศาสตร์ ที่คุณจะต้องนำไปประยุกต์ใช้ในการเขียนโค้ด SQL Server เพื่อคำนวณ OEE .

คำตอบคือ: คุณสามารถใช้ได้ทั้ง 2 รูปแบบ แต่ VIEW และ STORED PROCEDURE มีวัตถุประสงค์ต่างกันครับ

1. 💾 การใช้ SQL View (แนะนำสำหรับ OEE Components)
วัตถุประสงค์: ใช้สำหรับการสร้าง Virtual Table ที่คำนวณ Metrics พื้นฐาน (เช่น Loading Time, Operation Time, Total Good Bags) เพื่อให้สามารถนำไปใช้ใน Report หรือ Dashboard ได้อย่างรวดเร็ว

ข้อดี:

Real-time: คำนวณใหม่ทุกครั้งที่มีการเรียกใช้ (ถ้าไม่ใช้ Indexed View)

ง่ายต่อการนำไปใช้: สามารถ SELECT * FROM OEECalculationView ได้เหมือนเป็นตารางปกติ

ตัวอย่าง Logic ใน View: คุณจะเขียน CASE WHEN และ SUM() ใน View เพื่อคำนวณหา Total Planned Loss และ Total Unplanned Downtime สำหรับแต่ละ ShiftDate และ MachineID

2. ⚙️ การใช้ Stored Procedure (แนะนำสำหรับ Reporting Layer)
วัตถุประสงค์: ใช้สำหรับการคำนวณ Metrics ที่ซับซ้อนมาก และ นำผลลัพธ์ไปบันทึก (Materialize) ในตารางสรุป (Reporting Table) ที่คุณได้ออกแบบไว้ เช่น DailyProductionSummary

ข้อดี:

ประสิทธิภาพสูง: เมื่อมีการคำนวณและบันทึกผลลัพธ์ลงตารางสรุปแล้ว การเรียกดู Report จะเร็วมาก (ไม่ต้องคำนวณซ้ำ)

จัดการ Logic ได้ดีกว่า: สามารถจัดการการทำงานข้ามกะ, การจัดการค่า Null, และการ Insert/Update ข้อมูลในตารางสรุปได้ครบถ้วน

🎯 สรุป: สิ่งที่คุณควรทำ
สร้าง Calculation Logic (VIEW): เริ่มต้นด้วยการสร้าง SQL View เพื่อทดสอบ Logic การคำนวณ Availability, Performance และ Quality โดยใช้สมการที่ผมได้นำเสนอไป

Materialize ผลลัพธ์ (STORED PROCEDURE): จากนั้น ให้สร้าง Stored Procedure เพื่อเรียกใช้ Logic ใน View นั้น แล้วนำผลลัพธ์สุดท้าย (OEE%) ไป INSERT หรือ UPDATE ลงในตาราง DailyProductionSummary เป็นประจำ (เช่น ทุก 1 ชั่วโมง หรือทุกสิ้นกะ)

📝 Pseudo-Code View (เพื่อเป็นแนวทาง)
ผมขอนำเสนอ Pseudo-Code สำหรับการคำนวณ Availability โดยใช้ Logic ที่เราสรุป เพื่อเป็นแนวทางในการเขียน SQL View ของคุณครับ

# SQL
CREATE VIEW OEE_Availability_Calculation_V AS
SELECT
    PR.ShiftDate,
    PR.MachineID,
    PR.ShiftID,
    
    -- 1. Total Time (สมมติ 480 นาทีต่อกะ)
    480 AS Total_Shift_Time_Min,

    -- 2. Total Planned Loss (PL)
    SUM(CASE 
        WHEN DC.CategoryLevel = 1 AND DC.CategoryNameTH = N'Planned Loss' 
        THEN P.CalculatedDowntimeMin 
        ELSE 0 
    END) AS Total_Planned_Loss_Min,
    
    -- 3. Total Unplanned Downtime (UNPL)
    SUM(CASE 
        WHEN P.IsMachineDowntime = 1 
        THEN P.CalculatedDowntimeMin 
        ELSE 0 
    END) AS Total_Unplanned_Downtime_Min,

    -- 4. Calculated Loading Time
    (480 - SUM(CASE 
        WHEN DC.CategoryLevel = 1 AND DC.CategoryNameTH = N'Planned Loss' 
        THEN P.CalculatedDowntimeMin 
        ELSE 0 
    END)) AS Loading_Time_Min,

    -- 5. Calculated Operation Time
    (
        (480 - SUM(CASE WHEN DC.CategoryLevel = 1 AND DC.CategoryNameTH = N'Planned Loss' THEN P.CalculatedDowntimeMin ELSE 0 END)) 
        - SUM(CASE WHEN P.IsMachineDowntime = 1 THEN P.CalculatedDowntimeMin ELSE 0 END)
    ) AS Operation_Time_Min,

    -- 6. Final Availability %
    (
        (Operation_Time_Min / NULLIF(Loading_Time_Min, 0)) * 100 
    ) AS Availability_Percentage

FROM
    ProductionRecords PR
INNER JOIN
    ProblemRecords P ON PR.ProductionRecordID = P.ProductionRecordID
LEFT JOIN
    DowntimeCategories DC ON P.DowntimeCategoryID = DC.CategoryID

GROUP BY
    PR.ShiftDate, PR.MachineID, PR.ShiftID;