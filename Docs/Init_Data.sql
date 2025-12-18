-- ####################################################################
-- 2. DML: ข้อมูลเริ่มต้น (Init Data)
-- ####################################################################

-- 1. CostCenter
INSERT INTO CostCenter (CostCenterCode, CostCenterName) VALUES
('10111203', N'โรงงาน PP 1&2'), ('10111204', N'โรงงาน PP 3&4'),
('10111205', N'โรงงาน PPE'), ('10111206', N'โรงงาน PPC'),
('10111202', N'โรงงาน HDPE'), ('10126300', N'โรงงาน SASB');

-- 2. UnitPLBG
INSERT INTO UnitPLBG (UnitId, UnitName, CostCenterCode) VALUES
(1, N'PP1&2', '10111203'), (2, N'HDPE', '10111202'),
(3, N'PP3', '10111204'), (4, N'PPE', '10111205'),
(5, N'PPC', '10111206'), (6, N'SASB', '10126300');

-- 3. Machines
INSERT INTO Machines (MachineId, MachineName, MachineClass, MachineActive, MachineLine, CostCenterCode, UnitId, StandardRPM, BagWeightKG) VALUES
(1, 'PP12/A', 'g1', 1, 'A', '10111203', 1, 1800, 25.00),
(2, 'PP12/C', 'g1', 1, 'C', '10111203', 1, 1200, 25.00),
(3, 'PP3/A', 'g1', 1, 'A', '10111204', 3, 1200, 25.00),
(4, 'PP3/B', 'g1', 1, 'B', '10111204', 3, 1200, 25.00),
(5, 'PPE/C', 'g1', 1, 'C', '10111205', 4, 1200, 25.00),
(6, 'PPE/D', 'g1', 1, 'D', '10111205', 4, 1200, 25.00),
(7, 'PPC/A', 'g1', 1, 'A', '10111206', 5, 1200, 25.00),
(8, 'PPC/B', 'g1', 1, 'B', '10111206', 5, 1200, 25.00),
(9, 'HDPE/A', 'g1', 1, 'A', '10111202', 2, 1200, 25.00);

-- 4. KpiTargets
INSERT INTO KpiTargets (Item, [Year], UnitId, Waste_Pellet_Target, Waste_Film_Target, GiveAway_Target, Oee_Target, GiveAwayMin, GiveAwayMax) VALUES
(1, 2024, 1, 0.0250, 0.0050, 25.100, 88.87, 25.100, 25.115), (2, 2024, 2, 0.0050, 0.5900, 25.160, 90.17, 25.100, 25.115),
(3, 2024, 5, 0.0050, 0.2500, 25.160, 92.53, 25.100, 25.115), (4, 2024, 4, 0.0060, 0.2500, 25.160, 89.10, 25.100, 25.115),
(5, 2024, 3, 0.0060, 0.2500, 25.160, 89.68, 25.100, 25.115), (6, 2024, 6, 0.0080, 0.5900, 25.170, 92.69, 25.100, 25.115);

-- 5. Shifts
INSERT INTO Shifts (ShiftID, ShiftName, StartTime, EndTime) VALUES
(1, 'Morning Shift', '06:00:00', '14:00:00'),
(2, 'Evening Shift', '14:00:00', '22:00:00'),
(3, 'Night Shift', '22:00:00', '06:00:00');

-- 6. DowntimeCategories (อัปเดต CategoryID และ Level)
INSERT INTO DowntimeCategories (CategoryID, CategoryNameTH, CategoryLevel) VALUES
(10, N'Planned Loss (A - Schedule)', 1), 
(20, N'Minor Stop/Speed Loss (P, A - Downtime)', 2), 
(30, N'Quality Loss (Q - Rejects)', 3); 


-- 7. OeeLossTypes (อัปเดต CategoryID และ ProblemTypeID ให้สอดคล้อง)
INSERT INTO OeeLossTypes (ProblemTypeID, TypeNameTH, CategoryID, IsActive, DisplayOrder) VALUES
-- CategoryID 10: Planned Loss (A - Schedule) -> ProblemTypeID 1xx
(101, N'ช่างทำการ PM', 10, 1, 1),
(102, N'ประชุม', 10, 1, 2),
(103, N'รอโปรแกรม', 10, 1, 3),
(104, N'ทำความสะอาด', 10, 1, 4),
(105, N'เปลี่ยน FILM', 10, 1, 5), 

-- CategoryID 20: Minor Stop/Speed Loss -> ProblemTypeID 2xx
(201, N'เครื่องจักรเสีย', 20, 1, 0), -- Breakdown (เวลาหยุดหลัก)
(202, N'ปรับ Teflon Top Seal', 20, 1, 1),
(203, N'ปรับ Teflon Bottom Seal', 20, 1, 2), 
(204, N'ปรับ condition Bagging', 20, 1, 3),
(205, N'ล้าง ink jet และปรับแต่ง', 20, 1, 4), 
(206, N'ปรับ condition Palletizer', 20, 1, 5), 
(299, N'อื่นๆ (Time Loss)', 20, 1, 99), 

-- CategoryID 30: Quality Loss -> ProblemTypeID 3xx
(301, N'จำนวน Film Test', 30, 1, 1), 
(302, N'Bottom Seal ทำถุงเสีย', 30, 1, 2), 
(303, N'Conner ทำถุงเสีย', 30, 1, 3), 
(304, N'Bagging ปล่อยถุงเปล่า', 30, 1, 4), 
(305, N'Clamp Jaw จับถุงหลุด', 30, 1, 5), 
(306, N'Holding Tong เกี่ยวแตก', 30, 1, 6), 
(307, N'Top Seal ทำถุงเสีย', 30, 1, 7), 
(308, N'Reject จากน้ำหนัก', 30, 1, 8),
(309, N'Ink Jet ทำถุงเสีย', 30, 1, 9), 
(310, N'palletizer ทำถุงเสีย', 30, 1, 10), 
(399, N'อื่นๆ (bag)', 30, 1, 99); 

-- 9. BaggingLocations
INSERT INTO BaggingLocations (BaggingCode, BaggingName) VALUES
('PL', N'Bagging PL'), ('SA', N'Bagging SASB');

-- (ส่วนข้อมูล MachineStatus, ProductionRecords, ProblemRecords และ LotCompletionDetails จะใส่เมื่อมี Transaction เกิดขึ้น)

GO