1. 👷 Operator: การบันทึกข้อมูล Transaction หลัก
Operator มีหน้าที่บันทึกข้อมูล ดิบ (Raw Data) ทั้งหมดที่เกิดขึ้นในระหว่างกะทำงาน ข้อมูลเหล่านี้คือพื้นฐานในการคำนวณ OEE
## 1.1 text only format display
ลำดับ,ตารางที่เกี่ยวข้อง,ประเภทการดำเนินการ,บทบาทของ Operator
1.,ProductionRecords,"INSERT, UPDATE","เริ่มต้น/ปิด Segment บันทึกเวลาเริ่ม/จบ Segment, MachineId, ShiftId, ShiftDate, และปริมาณ Output เบื้องต้น (BagOutActualMT)"
2.,ProblemRecords,INSERT,"บันทึก Downtime และ Planned Loss บันทึกเหตุการณ์หยุดทั้งหมด (เวลาเริ่ม/จบ, ประเภทปัญหา, หมวดหมู่) ตลอดระยะเวลาของ Segment นั้น ๆ"
3.,LotCompletionDetails,INSERT,"บันทึก Waste/Loss บันทึกรายละเอียดของผลผลิต (เช่น PCCQCKG, MetalDetectionLossKG, TailBag) เมื่อ Segment/Lot นั้นเสร็จสิ้น"
4.,ProductionRecords,UPDATE,ปิดสถานะ (Lock Record) ทำการ UPDATE คอลัมน์ RecordStatus จาก 'OPEN' เป็น 'READY_FOR_REVIEW' เพื่อส่งมอบงานให้หัวหน้างานตรวจสอบ (เป็นขั้นตอนสุดท้ายของ Operator)
## 1.2 json
[
  {
    "sequence": 1,
    "relatedTable": "ProductionRecords",
    "operationType": ["INSERT", "UPDATE"],
    "operatorRole": "เริ่มต้น/ปิด Segment บันทึกเวลาเริ่ม/จบ Segment, MachineId, ShiftId, ShiftDate, และปริมาณ Output เบื้องต้น (BagOutActualMT)",
    "englishDescription": "Start/Close Segment, record start/end time, MachineId, ShiftId, ShiftDate, and initial output quantity (BagOutActualMT)"
  },
  {
    "sequence": 2,
    "relatedTable": "ProblemRecords",
    "operationType": ["INSERT"],
    "operatorRole": "บันทึก Downtime และ Planned Loss บันทึกเหตุการณ์หยุดทั้งหมด (เวลาเริ่ม/จบ, ประเภทปัญหา, หมวดหมู่) ตลอดระยะเวลาของ Segment นั้น ๆ",
    "englishDescription": "Record Downtime and Planned Loss, document all stop events (start/end time, problem type, category) throughout the segment"
  },
  {
    "sequence": 3,
    "relatedTable": "LotCompletionDetails",
    "operationType": ["INSERT"],
    "operatorRole": "บันทึก Waste/Loss บันทึกรายละเอียดของผลผลิต (เช่น PCCQCKG, MetalDetectionLossKG, TailBag) เมื่อ Segment/Lot นั้นเสร็จสิ้น",
    "englishDescription": "Record Waste/Loss, document production details (e.g., PCCQCKG, MetalDetectionLossKG, TailBag) when the Segment/Lot is completed"
  },
  {
    "sequence": 4,
    "relatedTable": "ProductionRecords",
    "operationType": ["UPDATE"],
    "operatorRole": "ปิดสถานะ (Lock Record) ทำการ UPDATE คอลัมน์ RecordStatus จาก 'OPEN' เป็น 'READY_FOR_REVIEW' เพื่อส่งมอบงานให้หัวหน้างานตรวจสอบ (เป็นขั้นตอนสุดท้ายของ Operator)",
    "englishDescription": "Close status (Lock Record), UPDATE RecordStatus column from 'OPEN' to 'READY_FOR_REVIEW' to handover to supervisor for review (final step of Operator)"
  }
]
สรุป: Operator ทำงานกับตาราง ProductionRecords, ProblemRecords, และ LotCompletionDetails เป็นหลัก เพื่อสร้างข้อมูล Transaction ที่สมบูรณ์


2. 🧐 หัวหน้างาน (Supervisor): การตรวจสอบและอนุมัติข้อมูลสรุป
## 2.1 tex only
หัวหน้างานจะเข้ามาดำเนินการหลังจากที่ Operator ได้ส่งมอบงานแล้ว (RecordStatus = 'READY_FOR_REVIEW') โดยบทบาทของหัวหน้างานคือการตรวจสอบความถูกต้องของข้อมูล ที่ถูกคำนวณแล้ว และให้การอนุมัติ
ลำดับ	ตารางที่เกี่ยวข้อง	ประเภทการดำเนินการ	บทบาทของหัวหน้างาน
1.	DailyProductionSummary	SELECT, UPDATE	บันทึก Remark และอนุมัติ หัวหน้างานจะตรวจสอบข้อมูล OEE, A, P, Q ที่ถูกคำนวณและบันทึกโดย SP ก่อนหน้านี้ แล้วทำการ UPDATE คอลัมน์ Supervisor_Final_Remark (ถ้าจำเป็น) และ Supervisor_Review_Time เพื่ออนุมัติ
2.	ProductionRecords	SELECT	ตรวจสอบ Transaction ใช้ในการดูรายละเอียด Downtime/Output ย้อนหลัง (Drill Down) โดยดูเฉพาะ Record ที่มีสถานะ 'READY_FOR_REVIEW' หรือ 'APPROVED'
3.	ProductionRecords	UPDATE (อาจมี)	แก้ไขสถานะ ในกรณีที่พบข้อผิดพลาดร้ายแรง หัวหน้างานอาจมีสิทธิ์ UPDATE สถานะ RecordStatus กลับไปเป็น 'OPEN' เพื่อให้ Operator หรือตนเองแก้ไขข้อมูล Transaction หลัก (ใน ProblemRecords หรือ LotCompletionDetails)
## 2.2 json
[
  {
    "sequence": 1,
    "table": "DailyProductionSummary",
    "actions": ["SELECT", "UPDATE"],
    "supervisorRole": "บันทึก Remark และอนุมัติ",
    "details": "ตรวจสอบข้อมูล OEE, A, P, Q ที่ถูกคำนวณและบันทึกโดย SP ก่อนหน้านี้ แล้วทำการ UPDATE คอลัมน์ Supervisor_Final_Remark (ถ้าจำเป็น) และ Supervisor_Review_Time เพื่ออนุมัติ"
  },
  {
    "sequence": 2,
    "table": "ProductionRecords",
    "actions": ["SELECT"],
    "supervisorRole": "ตรวจสอบ Transaction",
    "details": "ใช้ในการดูรายละเอียด Downtime/Output ย้อนหลัง (Drill Down) โดยดูเฉพาะ Record ที่มีสถานะ 'READY_FOR_REVIEW' หรือ 'APPROVED'",
    "statusFilter": ["READY_FOR_REVIEW", "APPROVED"]
  },
  {
    "sequence": 3,
    "table": "ProductionRecords",
    "actions": ["UPDATE", "SELECT"],
    "supervisorRole": "แก้ไขสถานะ",
    "details": "ในกรณีที่พบข้อผิดพลาดร้ายแรง หัวหน้างานอาจมีสิทธิ์ UPDATE สถานะ RecordStatus กลับไปเป็น 'OPEN' เพื่อให้ Operator หรือตนเองแก้ไขข้อมูล Transaction หลัก (ใน ProblemRecords หรือ LotCompletionDetails)",
    "errorCondition": "ข้อผิดพลาดร้ายแรง",
    "statusChangeTo": "OPEN"
  }
]


สรุปความแตกต่างในการเข้าถึงข้อมูลผู้ใช้เน้นการทำงานกับ...ลักษณะการทำงานการล็อก/สถานะที่สำคัญOperatorTransaction Data (*Records)สร้างข้อมูลดิบ/เหตุการณ์RecordStatus ต้องเป็น 'OPEN'SupervisorSummary Data (DailySummary)ตรวจสอบ/อนุมัติ/แก้ไข RemarkRecordStatus ต้องเป็น 'READY_FOR_REVIEW'

ตอนนี้คุณเข้าใจชัดเจนแล้วว่าแต่ละบทบาททำงานกับตารางไหนบ้าง ทำให้เราสามารถเขียน Stored Procedure ที่มีการควบคุมสิทธิ์ (Permission) และ Logic การล็อกตามสถานะ (RecordStatus) ได้อย่างมั่นใจครับ

คุณต้องการให้ผมร่าง Stored Procedure (T-SQL) สำหรับ Operator ในการบันทึก Downtime และอัปเดตสถานะเป็น 'READY_FOR_REVIEW' เป็นลำดับต่อไปเลยไหมครับ