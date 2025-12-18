📝 สรุป Case Study และ Logic การจัดการในระบบ
1. Case Study หลักที่ระบบรองรับ

Case Study,ปัญหาที่ต้องแก้ไข,ตารางหลักที่เกี่ยวข้อง,Logic การจัดการใน DB
A. การใช้ Film ต่อกะ,คำนวณปริมาณ Film ที่ใช้ไปในกะนั้น ๆ,"InventoryCutoff, Shifts",ใช้ผลต่างของ EndingFilmInventoryKG ณ จุดเริ่มต้นและสิ้นสุดกะ โดยอ้างอิง CutoffDateTime ที่ตรงกับขอบเขตกะ
B. Downtime/OEE ต่อกะ,คำนวณ Loss Time ของเครื่องจักรและจัดสรรเข้ากะที่รับผิดชอบ,"ProblemRecords, Shifts",ใช้ Logic Shift Boundary Split เพื่อสร้าง Multiple Rows ที่มีการกำหนด CalculatedShiftID และ CalculatedDowntimeMin ที่แม่นยำ
C. การบันทึก Empty Lot,"ปิดยอดการผลิต, บัญชี Film, และบันทึก Loss (PC/ท้ายถุง) พร้อมกัน","ProductionOrders, ProductionRecords, InventoryCutoff, LotCompletionDetails",Trigger Transaction เดียวเพื่ออัพเดท 3 ตาราง: (1) อัพเดท BagOutActualMT (2) บันทึก EndingFilmInventoryKG (3) อัพเดท CurrentStatusID เป็น 'Completed'
D. การคำนวณ Downtime ทันที,คำนวณ Loss Time ระหว่าง Lot เก่าจบ กับ Lot ใหม่เริ่ม (Gap Time),ProblemRecords,ใช้ LastMachineStopTime จากระบบ/DB ลบด้วย Time Start ที่ Operator กรอกเพื่อหา Gap และ INSERT รายการ Downtime ประเภท 'WAIT' ทันที
E. การจัดการ Status,"แสดงสถานะปัจจุบันของ Lot (Hold, Completed, In Progress)","ProductionOrders, OrderStatusLookup",ใช้ Field CurrentStatusID ใน ProductionOrders ที่ถูกอัพเดทโดย Transaction ต่างๆ (เช่น Completed โดย Empty Lot)

2. Worst-Case Scenario: การย้ายการผลิตไปยังเครื่องจักรใหม่ (Changeover/Interruption)
นี่คือสถานการณ์ที่ซับซ้อนที่สุด ซึ่งเกิดขึ้นเมื่อการผลิต Lot หนึ่งถูก ขัดจังหวะ (Interrupt) และจำเป็นต้องย้ายไปทำต่อบนเครื่องจักรอื่น หรือกลับมาทำใหม่ในภายหลัง การออกแบบของเราสามารถรองรับได้ 100% โดยใช้ Logic "Segment"

Logic การจัดการ:
ขั้นตอนที่ 1: การปิด Segment เดิม (Machine 1)
เมื่อ Operator ตัดสินใจหยุด Lot ชั่วคราวบนเครื่องจักรเดิม (สมมติ PP3/A):

Stop Time: บันทึก StopDateTime ของ Segment ปัจจุบันใน ProductionRecords

ปัญหา: บันทึก ProblemRecords (เช่น ประเภท 'BREAKDOWN' หรือ 'MAINTENANCE') ที่เกิดขึ้นกับ PP3/A

ปิด Segment: อัพเดท ProductionRecords (Segment 1):

ตั้งค่า SegmentEndDateTime = เวลาหยุด

บันทึกยอด BagOutActualMT ที่ทำได้จนถึงจุดหยุด (ถ้ามีการบันทึกย่อย)

สถานะ Lot ใน ProductionOrders จะถูกตั้งเป็น 'HOLD' ชั่วคราว

ขั้นตอนที่ 2: การเริ่มต้น Segment ใหม่ (Machine 2)
เมื่อ Lot ถูกย้ายไปเริ่มทำงานต่อบนเครื่องจักรใหม่ (สมมติ PP3/B):

New Segment: ระบบสร้าง Row ใหม่ใน ProductionRecords (Segment 2)

New Data:

LotNo เดิม

SegmentSequence = 2

MachineID = PP3/B

SegmentStartDateTime = เวลาที่เริ่มทำงานบน PP3/B

Downtime Gap: ระบบจะคำนวณ Downtime ที่เกิดขึ้นระหว่าง SegmentEndDateTime ของ Segment 1 กับ SegmentStartDateTime ของ Segment 2 (Loss Time สำหรับการย้าย) และ INSERT เข้าไปใน ProblemRecords เป็นประเภท 'WAIT/SETUP'

การคำนวณยอดรวม (Summary)
เมื่อ Lot นี้ถึงจุด Empty Lot จริง ๆ ยอดผลิตรวมทั้งหมดจะมาจากการรวมค่า BagOutActualMT ของทุก Segment ที่เกี่ยวข้อง (Segment 1 + Segment 2 + ...) ในตาราง ProductionRecords ครับ