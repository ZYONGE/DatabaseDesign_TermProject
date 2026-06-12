-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 샘플 데이터 (속성명 전역 유일 적용)
-- 삽입 순서 : FK 의존성 기준 (Region → … → Allocation)
-- 테스트 기준일 : 2026-05-11
-- ==============================================

SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------
-- 1. Region (지역) - 5개
-- -----------------------------------------------
INSERT INTO Region (region_name) VALUES
    ('은행동'),
    ('대야동'),
    ('신천동'),
    ('군자동'),
    ('능곡동');


-- -----------------------------------------------
-- 2. BicycleType (자전거 종류) - 3개
-- [변경] description → bicycletype_description
-- -----------------------------------------------
INSERT INTO BicycleType (bicycleType_name, max_passenger, inspection_cycle, bicycletype_description) VALUES
    ('일반',   1, 30, '성인 1인용 일반 자전거. 만 13세 이상 이용 가능'),
    ('어린이', 1, 30, '어린이 전용 소형 자전거. 만 13세 미만(초등학생 이하)만 대여 가능'),
    ('2인용',  2, 14, '2인 탑승 가능 커플·가족용 자전거. 점검 주기 14일');


-- -----------------------------------------------
-- 3. Station (대여소) - 5개
-- [변경] region_id → station_region_id
--        contactnumber → station_contactnumber
--        totaldocks → station_totaldocks
-- -----------------------------------------------
INSERT INTO Station (station_region_id, station_name, station_address, station_contactnumber, station_latitude, station_longitude, station_totaldocks, station_status) VALUES
    (1, '시흥시청 대여소',        '경기도 시흥시 시청로 10',    '031-310-2000', 37.3800000, 126.8025000, 20, '운영중'),
    (2, '시흥대야역 대여소',      '경기도 시흥시 대야로 210',   '031-310-2001', 37.3992000, 126.7995000, 15, '운영중'),
    (3, '신천동 주민센터 대여소', '경기도 시흥시 신천로 80',    NULL,           37.3850000, 126.7850000, 10, '운영중'),
    (4, '군자역 대여소',          '경기도 시흥시 군자로 140',   '031-310-2003', 37.4100000, 126.7900000, 12, '운영중'),
    (5, '능곡근린공원 대여소',    '경기도 시흥시 능곡로 50',    NULL,           37.3720000, 126.7760000,  8, '운영중');


-- -----------------------------------------------
-- 4. Bicycle (자전거) - 10개
-- [변경] type_id → bicycleType_id
--        station_id → bicycle_station_id
-- -----------------------------------------------
INSERT INTO Bicycle (bicycleType_id, bicycle_status, bicycle_station_id, bicycle_gps_latitude, bicycle_gps_longitude, bicycle_gps_updated_at) VALUES
    (1, '정상',   1,    NULL,          NULL,          NULL),
    (1, '대여중', NULL, 37.3810000,    126.8030000,   '2026-05-11 09:35:00'),
    (1, '정비중', NULL, NULL,          NULL,          NULL),
    (2, '정상',   2,    NULL,          NULL,          NULL),
    (2, '대여중', NULL, 37.3998000,    126.7990000,   '2026-05-11 10:20:00'),
    (3, '정상',   1,    NULL,          NULL,          NULL),
    (3, '정상',   3,    NULL,          NULL,          NULL),
    (1, '정상',   4,    NULL,          NULL,          NULL),
    (1, '회수중', NULL, 37.3955000,    126.7998000,   '2026-05-10 16:05:00'),
    (2, '정상',   5,    NULL,          NULL,          NULL);


-- -----------------------------------------------
-- 5. User (사용자) - 5명
-- 변경 없음
-- -----------------------------------------------
INSERT INTO User (user_name, user_birth_date, user_phone, user_address, user_status) VALUES
    ('김민준', '1990-03-15', '010-1234-5678', '경기도 시흥시 은행로 12', '정상'),
    ('이서연', '1995-07-22', '010-2345-6789', '경기도 시흥시 대야로 34', '정상'),
    ('박지훈', '1988-11-30', '010-3456-7890', '경기도 시흥시 신천로 56', '정지'),
    ('최다은', '2015-04-10', '010-4567-8901', '경기도 시흥시 군자로 78', '정상'),
    ('정우성', '1992-08-05', '010-5678-9012', '경기도 시흥시 능곡로 90', '정상');


-- -----------------------------------------------
-- 6. AdminStaff (운영 관리자) - 4명
-- [변경] station_id → staff_station_id
-- -----------------------------------------------
INSERT INTO AdminStaff (staff_name, staff_phone, staff_station_id, staff_is_active) VALUES
    ('홍길동', '010-6789-0123', 1,    1),
    ('김철수', '010-7890-1234', 2,    1),
    ('이영희', '010-8901-2345', 3,    1),
    ('박관리', '010-9012-3456', NULL, 1);


-- -----------------------------------------------
-- 7. Rental (대여 이력) - 5건
-- [변경] user_id → rental_user_id
--        bicycle_id → rental_bicycle_id
--        start_time → rental_start_time
--        end_time → rental_end_time
--        end_station_id → return_station_id
-- -----------------------------------------------
INSERT INTO Rental (rental_user_id, rental_bicycle_id, start_station_id, return_station_id, rental_start_time, rental_end_time, rental_status) VALUES
    (1, 2, 1, NULL, '2026-05-11 09:30:00', NULL,                    '대여중'),
    (4, 5, 2, NULL, '2026-05-11 10:15:00', NULL,                    '대여중'),
    (2, 1, 1, 2,    '2026-05-10 09:00:00', '2026-05-10 10:15:00',   '반납'),
    (3, 8, 4, NULL, '2026-05-01 14:00:00', NULL,                    '미반납'),
    (5, 7, 3, 3,    '2026-05-09 08:00:00', '2026-05-09 09:30:00',   '반납');


-- -----------------------------------------------
-- 8. IncidentReport (고장/민원 신고) - 2건
-- [변경] user_id → incident_user_id
--        bicycle_id → incident_bicycle_id
--        description → incident_description
--        reported_at → incident_reported_at
--        staff_id → incident_staff_id
--        resolved_at → incident_resolved_at
-- -----------------------------------------------
INSERT INTO IncidentReport (incident_user_id, incident_bicycle_id, incident_type, incident_description, incident_reported_at, incident_status, incident_staff_id, incident_resolved_at) VALUES
    (2, 3, '고장', '앞 브레이크가 작동하지 않아 위험합니다',      '2026-05-10 14:00:00', '처리중', 1, NULL),
    (1, 9, '방치', '시흥대야역 3번 출구 앞 인도에 방치되어 있음', '2026-05-10 16:00:00', '처리중', 2, NULL);


-- -----------------------------------------------
-- 9. Maintenance (정비 이력) - 2건
-- [변경] bicycle_id → maintenance_bicycle_id
--        incident_id → maintenance_incident_id
--        description → maintenance_description
--        started_at → maintenance_started_at
--        ended_at → maintenance_ended_at
-- -----------------------------------------------
INSERT INTO Maintenance (maintenance_bicycle_id, maintenance_incident_id, maintenance_type, maintenance_description, maintenance_started_at, maintenance_ended_at, maintenance_status) VALUES
    (3, 1,    '수리',     '앞 브레이크 패드 및 케이블 교체 외주 의뢰', '2026-05-10 15:00:00', NULL,                  '진행중'),
    (6, NULL, '정기점검', '2인용 자전거 30일 정기점검 외주 의뢰 완료', '2026-05-08 10:00:00', '2026-05-08 11:30:00', '완료');


-- -----------------------------------------------
-- 10. Retrieve (자전거 회수 이력) - 2건
-- [변경] bicycle_id → retrieve_bicycle_id
--        staff_id → retrieve_staff_id
--        incident_id → retrieve_incident_id
--        station_id → retrieve_station_id
--        completed_at → retrieve_completed_at
-- -----------------------------------------------
INSERT INTO Retrieve (retrieve_bicycle_id, retrieve_staff_id, retrieve_incident_id, retrieve_latitude, retrieve_longitude, retrieve_location, retrieve_station_id, retrieved_at, retrieve_completed_at, retrieve_reason, retrieve_status) VALUES
    (9, 3, 2,    37.3992000, 126.7995000, '경기도 시흥시 대야로 210 시흥대야역 3번 출구 앞', 2, '2026-05-10 16:30:00', NULL,                  '방치',   '진행중'),
    (8, 2, NULL, 37.4050000, 126.7920000, '경기도 시흥시 군자로 200 인근 골목',              4, '2026-05-06 10:00:00', '2026-05-07 09:00:00', '미반납', '완료');


-- -----------------------------------------------
-- 11. Penalty (패널티) - 1건
-- [변경] user_id → penalty_user_id
--        rental_id → penalty_rental_id
--        ban_start → penalty_ban_start
--        ban_end → penalty_ban_end
-- -----------------------------------------------
INSERT INTO Penalty (penalty_user_id, penalty_rental_id, penalty_days, penalty_ban_start, penalty_ban_end) VALUES
    (3, 4, 50, '2026-05-06', '2026-06-25');


-- -----------------------------------------------
-- 12. Allocation (자전거 배치 이력) - 2건
-- [변경] bicycle_id → allocation_bicycle_id
--        station_id → allocation_station_id
--        staff_id → allocation_staff_id
--        note → allocation_note
-- -----------------------------------------------
INSERT INTO Allocation (allocation_bicycle_id, allocation_station_id, allocation_staff_id, allocation_note) VALUES
    (1,  1, 4, '은행동 시흥시청 대여소 초기 배치'),
    (10, 5, 4, '능곡근린공원 대여소 어린이 자전거 수요 대응 배치');

SET FOREIGN_KEY_CHECKS = 1;