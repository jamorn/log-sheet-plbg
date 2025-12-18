Q: จำลองเหตุการณ์ กะเช้า ลงรายงานเสร็จแล้ว แต่ลืมว่า ไม่ได้ลงรายงาน เปลี่ยน film จำนวน 1 ม้วน การเพิ่มเข้าไปทีสุด sequence ลำดับเหตุการณ์ ในหน้าแสดงผลผ่าน เว็บจะแสดงถูกไหมครับ การ query order จาก อะไร ครับ
A: 🔍 การจำลองเหตุการณ์และการวิเคราะห์ผลกระทบ
1. สถานะเดิม: ข้อมูลถูกบันทึกสมบูรณ์ (ก่อนแก้ไข)
สมมติว่ากะเช้า (Shift A) ทำงานเสร็จแล้ว และมี Production Record (PR) ดังนี้:
[
  {
    "ตาราง": "ProductionRecords",
    "Record ID": "100",
    "LotNo": "L2025001",
    "SegmentSequence": "1",
    "SegmentStartDateTime": "08:00",
    "SegmentEndDateTime": "16:00",
    "BagOutActualMT": "5,000",
    "Total Downtime Logged (ProblemRecords)": "20 นาที (Unplanned Stop)"
  }
]

# ผลลัพธ์ OEE ก่อนแก้ไข (สมมติ):Total Time: 480 นาที (8 ชั่วโมง)Planned Loss (PL): 60 นาที (ทำความสะอาด)Loading Time: $480 - 60 = 420$ นาทีUnplanned Downtime (UNPL): 20 นาทีAvailability: $(420 - 20) / 420 = 95.24\%$2. การเพิ่มรายการ "เปลี่ยน Film" เข้าไปภายหลังคุณต้องการเพิ่มรายการ "เปลี่ยน FILM" (ซึ่งถือเป็น Planned Loss - PL) 1 ม้วน เข้าไปในกะเช้านี้ สมมติใช้เวลา 5 นาทีคำสั่งที่ใช้ในการเพิ่มข้อมูล (T-SQL Insertion):

SQL: 
INSERT INTO [dbo].[ProblemRecords] (
    ProductionRecordID, ProblemTypeID, DowntimeCategoryID, 
    StopDateTime, StartDateTime, CalculatedDowntimeMin, 
    ShiftDate, CalculatedShiftID, IsMachineDowntime, OperatorEmpId
)
VALUES (
    100, 
    (SELECT ProblemTypeID FROM ProblemTypes WHERE TypeNameTH = N'เปลี่ยน FILM'), -- สมมติ ID เป็น 10
    (SELECT CategoryID FROM DowntimeCategories WHERE CategoryNameTH = N'Planned Changeover'), -- สมมติ ID เป็น 5
    '2025-12-15 10:00:00', 
    '2025-12-15 10:05:00', 
    5, -- 5 นาที
    '2025-12-15', 
    1, -- Shift A
    0, -- IsMachineDowntime = 0 เพราะเป็น Planned Loss
    'OPR001'
);

3. ผลกระทบต่อการแสดงผลและการคำนวณ OEE
การเพิ่มรายการเข้าไปในตาราง ProblemRecords จะ ไม่ส่งผลกระทบต่อ ProductionRecords (ซึ่งมี Segment Start/End Time บันทึกอยู่แล้ว) แต่จะส่งผลต่อการคำนวณ OEE ในครั้งถัดไป อย่างถูกต้อง
[
  {
    "ตัวแปร": "Planned Loss (PL)",
    "ผลกระทบ": "เพิ่มขึ้น 5 นาที",
    "ค่าใหม่": "60+5=**65** นาที"
  },
  {
    "ตัวแปร": "Unplanned Downtime (UNPL)",
    "ผลกระทบ": "ไม่เปลี่ยนแปลง",
    "ค่าใหม่": "20 นาที"
  },
  {
    "ตัวแปร": "Loading Time",
    "ผลกระทบ": "ลดลง (เพราะ PL เพิ่มขึ้น)",
    "ค่าใหม่": "480−65=**415** นาที"
  },
  {
    "ตัวแปร": "Operation Time",
    "ผลกระทบ": "ลดลง (เพราะ Loading Time ลดลง)",
    "ค่าใหม่": "415−20=**395** นาที"
  },
  {
    "ตัวแปร": "Availability",
    "ผลกระทบ": "ลดลง",
    "ค่าใหม่": "(415−20)/415=**95.18%**"
  },
  {
    "ตัวแปร": "ลำดับเหตุการณ์ในเว็บ",
    "ผลกระทบ": "ถูกต้อง",
    "ค่าใหม่": "รายการ \"เปลี่ยน Film 5 นาที\" จะถูกแทรกตามลำดับเวลา StopDateTime ('2025-12-15 10:00:00')"
  }
]

3.1 text only
ตัวแปร,ผลกระทบ,ค่าใหม่
Planned Loss (PL),เพิ่มขึ้น 5 นาที,60+5=∗∗65∗∗ นาที
Unplanned Downtime (UNPL),ไม่เปลี่ยนแปลง,20 นาที
Loading Time,ลดลง (เพราะ PL เพิ่มขึ้น),480−65=∗∗415∗∗ นาที
Operation Time,ลดลง (เพราะ Loading Time ลดลง),415−20=∗∗395∗∗ นาที
Availability,ลดลง,(415−20)/415=∗∗95.18%∗∗
ลำดับเหตุการณ์ในเว็บ,ถูกต้อง,"รายการ ""เปลี่ยน Film 5 นาที"" จะถูกแทรกตามลำดับเวลา StopDateTime ('2025-12-15 10:00:00')"

สรุป: การเพิ่มรายการ Planned Loss เข้าไปภายหลังจะทำให้การคำนวณ OEE โดยรวม ยังคงถูกต้อง เนื่องจากคุณได้แยกประเภท Downtime ด้วยคอลัมน์ IsMachineDowntime และ DowntimeCategoryID อย่างชัดเจนในตาราง ProblemRecords

# 🔑 การ Query ลำดับเหตุการณ์ (Timeline) สำหรับหน้าเว็บ
การแสดงผลเหตุการณ์ที่ถูกต้องในหน้าเว็บ (Timeline/Logsheet) ต้องดึงข้อมูลจากหลายตารางและจัดเรียงตามเวลาที่เกิดขึ้นจริง คุณจะต้องใช้ JOIN และ UNION ALL (หรือ CTE) บน Field ที่เป็น ตัวบอกลำดับเหตุการณ์ (Timestamp)

1. การ Query (T-SQL Logic)
หน้าเว็บจะแสดงลำดับเหตุการณ์ทั้งหมดที่เกิดขึ้นระหว่าง SegmentStartDateTime และ SegmentEndDateTime ของ Lot/Segment นั้น ๆ โดยมีเงื่อนไขดังนี้:

Production: ProductionRecords ใช้ SegmentStartDateTime และ SegmentEndDateTime เป็นจุดเริ่มต้น/จุดสิ้นสุด

Downtime/Loss: ProblemRecords ใช้ StopDateTime เป็นตัวกำหนดลำดับ

Inventory: InventoryCutoff ใช้ CutoffDateTime เป็นตัวกำหนดลำดับ

2. T-SQL Pseudo-Code สำหรับ Timeline
นี่คือโครงสร้าง Logic การ Query ที่จำเป็นสำหรับการแสดงผลหน้า Logsheet/Timeline ที่ถูกต้อง:
SQL
-- 1. เลือกข้อมูล Production Time
SELECT
    PR.SegmentStartDateTime AS TimeStamp,
    'START' AS EventType,
    'Production Started' AS Details
FROM 
    ProductionRecords PR
WHERE 
    PR.LotNo = @TargetLotNo AND PR.SegmentSequence = @TargetSequence

UNION ALL

-- 2. เลือกข้อมูล Downtime และ Planned Loss
SELECT
    P.StopDateTime AS TimeStamp,
    'DOWNTIME' AS EventType,
    PType.TypeNameTH + ' (' + CONVERT(VARCHAR, P.CalculatedDowntimeMin) + ' min)' AS Details
FROM 
    ProblemRecords P
INNER JOIN 
    ProblemTypes PType ON P.ProblemTypeID = PType.ProblemTypeID
WHERE 
    P.ProductionRecordID = @TargetPRID

UNION ALL

-- 3. เลือกข้อมูล Inventory Cutoff (ถ้ามี)
SELECT
    IC.CutoffDateTime AS TimeStamp,
    'CUTOFF' AS EventType,
    'Film Inventory Cutoff' AS Details
FROM 
    InventoryCutoff IC
WHERE 
    IC.LotNo = @TargetLotNo 
    -- และเงื่อนไขเวลาอื่น ๆ

UNION ALL

-- 4. เลือกข้อมูล End Time
SELECT
    PR.SegmentEndDateTime AS TimeStamp,
    'END' AS EventType,
    'Production Ended' AS Details
FROM 
    ProductionRecords PR
WHERE 
    PR.ProductionRecordID = @TargetPRID

-- จัดเรียงผลลัพธ์ทั้งหมดตามเวลาที่เกิดขึ้น
ORDER BY 
    TimeStamp;

 การ Query Order ที่สำคัญที่สุดคือการใช้ ORDER BY TimeStamp จากทุกตารางที่ถูก UNION ALL เพื่อให้หน้าเว็บแสดงผลลำดับเหตุการณ์ที่ถูกต้องตามเวลาจริง แม้ว่าข้อมูลจะถูกบันทึกย้อนหลังก็ตาม

💡 สิ่งที่ควรทำต่อไป
คุณควรตรวจสอบว่าในตาราง ProblemTypes ของคุณได้กำหนด ProblemTypeID สำหรับรายการที่อยู่ในกลุ่ม Planned Loss (PL) เช่น "เปลี่ยน FILM" และ "ทำความสะอาด" ไว้ชัดเจนแล้ว และกำหนดให้ IsMachineDowntime = 0 ใน ProblemRecords สำหรับรายการเหล่านั้น   