💡 สรุป Logic การคำนวณ OEE และการเชื่อมโยงกับ Database
Logic การคำนวณ OEE ของคุณมีความชัดเจนและเป็นไปตามมาตรฐานการคำนวณ OEE แบบพื้นฐาน (Six Big Losses) แต่ใช้ชื่อเรียกที่ปรับให้เข้ากับบริบทการผลิตของคุณ:

1. ⏱️ Availability (เวลาการทำงาน)
ตัวแปร,ที่มาใน Logic,การเชื่อมโยงกับ Database Design
Total Time,totalTime (min),Master Data: มาจากตาราง Shifts (ผลรวมชั่วโมงในกะ) หรือตาราง PerformanceTargets (กำหนด Target Time)
Planned Downtime (PL),"totalPlanTime (min) (รวม: รอโปรแกรม, ทำความสะอาด, เปลี่ยน FILM)",Master Data/Transaction: ข้อมูลเหล่านี้ควรถูกบันทึกในตาราง ProblemRecords โดยมี ProblemTypeID ที่กำหนดเป็นกิจกรรมที่ ไม่ใช่ Downtime จริง (Loss Code: Planned Stop)
Loading Time,totalTime - totalPlanTime,Calculated: คำนวณจาก Master Data และ Planned Stop
Unplanned Downtime (UNPL),"totalDowntime (min) (รวม: เครื่องจักรเสีย, ปรับ Seal/Bagging/Ink Jet/อื่นๆ)",Transaction Data: มาจากตาราง ProblemRecords โดยมี IsMachineDowntime = 1 และ ProblemTypeID ที่กำหนดเป็น Downtime จริง (Loss Code: Downtime)
Operation Time,Loading Time - totalDowntime,Calculated: เวลาการทำงานจริงของเครื่องจักร

2. 🚀 Performance (ประสิทธิภาพความเร็ว)
ตัวแปร,ที่มาใน Logic,การเชื่อมโยงกับ Database Design
Ideal Cycle Time,60/RPM (min/bag) หรือ this.cycleTime,"Master Data: มาจากตาราง MachineParameters (เก็บ RPM, Speed Max)"
Actual Bags,productionKg/BAG_WEIGHT,Transaction Data: มาจากตาราง ProductionRecords (คอลัมน์ BagOutActualMT แปลงเป็นถุง)
Operation Time,operationTime,ใช้ค่าที่คำนวณได้จาก Availability